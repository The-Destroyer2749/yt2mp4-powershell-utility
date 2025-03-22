Param (
    $link,
    $tempFolder = "E:\Users\phili\YouTube\temp",
    $outputFolder = "E:\Users\phili\YouTube",
    $ffmpegLocation = "C:\Program Files\FFmpeg\bin\ffmpeg.exe",
    $outputFilePath,
    $outputFileName,
    $videoFile,
    $audioFile,
    $subtitleFile,
    $temp,
    $bitrate,
    $hasNvidiaGpu = $true
)

$link = Read-Host -Prompt "Type in the Youtube Link You Want To Download: "
$bitrate = Read-Host -Prompt "Type in the bitrate (in kbps) you want the video to be encoded in: "
$bitrate = $bitrate + "k"

# error and exit the program if an invalid url in inputted
if($link -eq "") {
    Write-Error "The link entered is invalid"
    exit
}

# if the user typed in an invalid bitrate then default it to 1600k and send an error
if($bitrate -eq "") {
    $bitrate = "1600k"
    Write-Error "The bitrate entered is invalid"
}

Write-Host "`n"

# check if the tempFolder exists, otherwise create one
New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

# download the video, audio, and subtitle files seperately for maximum quality
yt-dlp -q --progress -f ba -x --audio-format mp3 -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link # download the audio file as it's best quality
yt-dlp -q --progress -f bv --embed-thumbnail --remux-video mp4 -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link # downlaod the video with subtitles at it's best quality
yt-dlp -q --progress --write-auto-sub --sub-lang en --skip-download -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link

Get-ChildItem -Path $tempFolder | ForEach-Object {
    $newName = $_.Name -replace '\s', '-'
    Rename-Item -Path $_.FullName -NewName $newName
}

# Sanitize filenames
Get-ChildItem -Path $tempFolder | Rename-Item -NewName { $_.Name -replace '[^a-zA-Z0-9_.-]', '-' }

# Wait for downloads to finalize
Start-Sleep -Seconds 3

# get the file paths of all three files downloaded
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

$temp = Read-Host -Prompt "Press enter to exit powershell"