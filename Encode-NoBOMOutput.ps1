# Encode-NoBOMOutput.ps1
#
# Remove BOM (Byte Order Mask) encoding
# BOM writes some extra bytes at the beginning of a text file to mark the encoding used to write the file.
#
# Unfortunately, BOM encoding wasn’t adopted well outside the Windows world. Today, when you save a text file on a Windows system and upload it to i.e. GitHub, the BOM encoding can corrupt the file or make it entirely unreadable.

# Example
$filePath = "bomaway.txt"
$text = 'This is the text to write to disk.' # text = Get-Content -Path <textfile>
$Utf8NoBomEncoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines($filePath, $text, $Utf8NoBomEncoding)
$filePath