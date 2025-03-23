<# .SYNOPSIS #>

Param (
    [switch]$h,
    $link,
    $outputFolder,
    $ffmpegLocation = "C:\Program Files\FFmpeg\bin\ffmpeg.exe",
    $encoderSpeedup, # Amd, Intel, Nvidia
    $bitrate,
    $encoder,
    [switch]$hevc # whether or not to make a h264 or h265 file
)

# initizing variables
$outputFilePath
$outputFileName
$videoFile
$audioFile
$subtitleFile
$temp
$youtubeValidationRegex = "(https:\/\/youtu\.be\/.[^&?]+)|(https:\/\/www\.youtube\.com\/watch\?v=.[^&?]+)"
$username = whoami
$tempFolder
$encoderList = @(
    @( # every computer can use these
        "libx264",
        "libx265"
    ),
    @( # just for Amd gpus
        "h264_amf",
        "hevc_amf"
    )
    @( # just for Intel gpus
        "h264_qsv",
        "hevc_qsv"
    )
    @( # just for Nvidia nvenc
        "h264_nvenc",
        "hevc_nvenc"
    )
)

# help
if($h) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# assuming non inputted variables
if ($outputFolder) {
    $outputFolder = "C:\Users\$username\youtube downloads"
}

$tempFolder = Join-Path -Path $outputFolder -ChildPath "\temp"

# check if the folders exist, otherwise create them
New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

if ($hevc) {
    $hevc = 1
}
else {
    $hevc = 0
}

if ($encoder) {
    switch ($encoderSpeedup) {
        "amd" { $encoder = $encoderList[$hevc][1] }
        "intel" { $encoder = $encoderList[$hevc][2] }
        "nvidia" { $encoder = $encoderList[$hevc][3] }
        Default { $encoder = $encoderList[$hevc][0] }
    }
}

# error and exit the program if an invalid url in inputted
if($link -match $youtubeValidationRegex) {
    while ($link) {
        $link = Read-Host -Prompt "Type in the Youtube Link You Want To Download: "
        if ($link) {
            Write-Error "The link entered is invalid"
        }
    }
}

# if the user typed in an invalid bitrate then default it to 1600k and send an error
if($bitrate -as [UInt32] -eq $null -or $bitrate -ne "") {
    while ($bitrate -as [UInt32] -eq $null) {
        $bitrate = Read-Host -Prompt "Type in the bitrate (in kbps) you want the video to be encoded in: "
        if ($bitrate) {
            Write-Error "The bitrate entered is invalid"
        }
    }
}
$bitrate = $bitrate + "k"

Write-Host "`n"

# download the video, audio, and subtitle files seperately for maximum quality
yt-dlp -q --progress -f ba -x --audio-format mp3 -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link # download the audio file as it's best quality
yt-dlp -q --progress -f bv --embed-thumbnail --remux-video mp4 -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link # downlaod the video with subtitles at it's best quality
yt-dlp -q --progress --write-auto-sub --sub-lang en --skip-download -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link

Get-ChildItem -Path $tempFolder | ForEach-Object {
    $newName = $_.Name -replace '\s', '-'
    Rename-Item -Path $_.FullName -NewName $newName -Force
}

# Sanitize filenames
Get-ChildItem -Path $tempFolder | Rename-Item -NewName { $_.Name -replace '[^a-zA-Z0-9_.-]', '-' } -Force

# Wait for downloads to finish
Start-Sleep -Seconds 3

# get the file paths of all three files that were downloaded
$videoFile = Get-ChildItem -Path $tempFolder -Filter *.mp4 -File | Select-Object -First 1
$audioFile = Get-ChildItem -Path $tempFolder -Filter *.mp3 -File | Select-Object -First 1
$subtitleFile = Get-ChildItem -Path $tempFolder -Filter *.* -File | Where-Object { $_.Extension -in ".vtt", ".srt" } | Select-Object -First 1

# check if the files actually exist
if (-not $videoFile -or -not $audioFile -or -not $subtitleFile) {
    Write-Error "`n`nError: Missing required files!"
    Write-Error "Video exists: $($videoFile -ne $null)"
    Write-Error "Audio exists: $($audioFile -ne $null)"
    Write-Error "Subtitle exists: $($subtitleFile -ne $null)`n`n"
    exit
}

# ffmpeg -i vidFile.mp4 -i audioFile.mp3 -i subtitleFile.vtt -c:s mov_text output.mp4
$outputFileName = "$($videoFile.BaseName)_combined.mp4"
$outputFilePath = Join-Path -Path $outputFolder -ChildPath $outputFileName

& "$ffmpegLocation" -v quiet -stats -i "`"$($videoFile.FullName)`"" -i "`"$($audioFile.FullName)`"" -i "`"$($subtitleFile.FullName)`"" -c:v $(if($hasNvidiaGpu) { "hevc_nvenc"; "-spatial-aq"; "1" } else { "libx265" }) -b:v $bitrate -c:a aac -b:a 192k -c:s mov_text -map 0:v:0 -map 1:a:0 -map 2:s:0 "`"$outputFilePath`""

if (Test-Path -Path $outputFilePath) {
    Write-Host "Output file created Successfully"
}
else {
    Write-Host "Output file failed to be created"
    exit
}

Remove-Item -Path "$tempFolder/*" -Force