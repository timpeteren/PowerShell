# Any file (up to 100kilbytes-ish, can be BASE64 encoded and trasferred via Bastion copy/paste :-)

### for text / file ###

$filename = "toBeTransferred.zip"
$base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filename))
$base64string | Set-Clipboard

$filename = "file_reassembled.zip"
$base64string = "" # $base64string = Get-Content transfer.txt
[IO.File]::WriteAllBytes($filename, [System.Convert]::FromBase64String($base64string))


# Encode file
$myBytes = Get-Content -Path C:\CERTSRV\SCRIPTS\DeviceClientAuth.pfx -Encoding Byte
[System.Convert]::ToBase64String($myBytes) | Set-Clipboard

# Seems to be missing the conversion from byte array back to original form
# Decode file or string, use Out-File if suitable
[System.Convert]::FromBase64String($base64bytes) # | Out-File filename.txt



### for certificates ####

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate
$cert = ls cert:\LocalMachine\root | Where-Object {$_.Subject -match 'Root CA'} | Select-Object -First 1
$rawData = $rootCert.GetRawCertData()

$rootCert = [convert]::ToBase64String($rawData)

# (FromBas64 to decode)



### for binary ###

# Using Windows.Forms

## Encode
Function Get-FileName($initialDirectory)
{   
	 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = $initialDirectory
	$OpenFileDialog.filter = "All files (*.*)| *.*"
	$OpenFileDialog.ShowDialog() | Out-Null
	$FileName = $OpenFileDialog.filename
	$FileName

} #end function Get-FileName

$FileName = Get-FileName

$base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($FileName))

## Decode

$FileName = wheremyfileat.txt
[IO.File]::WriteAllBytes($FileName, [Convert]::FromBase64String($base64string))


# (local test

$base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filename))
$base64string | Set-Clipboard

$filename = "C:\DATA\Tools\file_reassembled.exe"
[IO.File]::WriteAllBytes($filename, [System.Convert]::FromBase64String($base64string))
# )