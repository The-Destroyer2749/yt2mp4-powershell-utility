Param (
    $link = "https://www.youtube.com/watch?v=YPMUh_Pezlw",
    $tempFolder = "E:\Users\phili\YouTube\temp",
    $outputFolder = "E:\Users\phili\YouTube",
    $ffmpegLocation = "C:\Program Files\FFmpeg\bin\ffmpeg.exe",
    $fileExtensionToRemove = (".mp3", ".mp4"),
    $videoFileName,
    $subtitleFile,
    $temp
)

# $link = Read-Host -Prompt "Type in the Youtube Link You Want To Download: "

# Write-Host $link

yt-dlp -f ba -x --audio-format mp3 -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link # download the audio file as it's best quality
yt-dlp -f bv --embed-thumbnail -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link # downlaod the video with subtitles at it's best quality
yt-dlp --write-auto-sub --sub-lang en --skip-download -o "$tempFolder/%(title)s by %(creator)s on %(upload_date>%Y-%m-%d)s.%(ext)s" --ffmpeg-location $ffmpegLocation $link

$videoFileName = (Get-ChildItem -Path $tempFolder -Filter *.mp4 -File | Select-Object -First 1).Name # gets the file name of the first file in the folder that has the file extension .mp4
$videoFileName = $videoFileName.Substring(0, ($videoFileName.Length - $fileExtensionToRemove[0].Length)) # removes the file extension from the file so i can get the name of both the mp3 and mp4 files and store it as a value
$subtitleFile = Get-ChildItem -Path $tempFolder -Filter "*.vtt" -File | Select-Object -First 1

if ($subtitleFile -and $subtitleFile.Length -gt 0 -and $subtitleFile.Extension -eq ".vtt") {
    # Properly handle spaces and special characters by ensuring the full path is quoted correctly
    $inputFile = "`"$($subtitleFile.FullName)`""  # Escape quotes around the full file path
    $outputFile = "`"$tempFolder\$($subtitleFile.BaseName).srt`""  # Escape quotes for output path

    # Run ffmpeg with properly quoted file paths
    & "$ffmpegLocation" -i $inputFile -c:s subrip $outputFile
}


# Write-Host "& $ffmpegLocation -i `"$tempFolder\$videoFileName.mp4`" -i `"$tempFolder\$videoFileName.mp3`" -map 0:v:0 -map 0:s:0 -map 1:a:0 `"$tempFolder\$videoFileName`2.mp4`""

& "$ffmpegLocation" -i "`"$tempFolder\$videoFileName.mp4`"" -i "`"$tempFolder\$videoFileName.mp3`"" -map 0:v:0 -map 0:s:0 -map 1:a:0 "`"$tempFolder\$videoFileName`2.mp4`""

# ffmpeg -i "$videoFileName.mp4" -i "$videoFileName.mp3" -map 0:v:0 -map 0:s:0 -map 1:a:0 "$videoFileName2.mp4" # combines the mp3 and mp4 files into one mp4

# Move-Item -Path "$tempFolder/$videoFileName2.mp4" -Destination "$outputFolder/$videoFileName.mp4"
# Remove-Item -Path "$tempFolder/*" -Force

$temp = Read-Host -Prompt "Press enter to exit powershell"