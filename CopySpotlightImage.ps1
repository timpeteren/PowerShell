Function Get-FileMetaData 
{ 
Param([string[]]$folder) 
foreach($sFolder in $folder) 
    { 
    $a = 0 
    $objShell = New-Object -ComObject Shell.Application 
    $objFolder = $objShell.namespace($sFolder) 

    foreach ($File in $objFolder.items()) 
    {  
    $FileMetaData = New-Object PSOBJECT 
        for ($a ; $a  -le 266; $a++) 
        {  
        if($objFolder.getDetailsOf($File, $a)) 
            { 
            $hash += @{$($objFolder.getDetailsOf($objFolder.items, $a))  = 
                    $($objFolder.getDetailsOf($File, $a)) } 
            $FileMetaData | Add-Member $hash 
            $hash.clear()  
            } #end if 
        } #end for  
    $a=0 
    $FileMetaData 
    } #end foreach $file 
    } #end foreach $sfolder 
} #end Get-FileMetaData


### kopierer filer fra $assetPath til $tempPath og omdøper dem ved å legge til .jpg endelse
## COPY .JPG from FOLDER A TO FOLDER B! ###
## Errorcheck -> user locale (!) ###

$assetPath = $env:USERPROFILE + "\" + 'AppData\Local\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets\'
$tempPath  = $env:OneDrive + "\" + 'Skrivebord\Temp\'
$spotPath = $env:OneDrive + "\" + 'Skrivebord\Spotlight\'
$spotVertPath = $env:OneDrive + "\" + 'Skrivebord\Spotlight vertical\'

# $tempPath  = $env:USERPROFILE + "\" + 'Desktop\Temp\'
# $spotPath = $env:USERPROFILE + "\" + 'Desktop\Spotlight\'
# $spotVertPath = $env:USERPROFILE + "\" + 'Desktop\Spotlight vertical\'
$assetImgs = @(Get-ChildItem -Path $assetPath)

for ($i = 0; $i -lt $assetImgs.Count; $i++) 
    {
    if ($assetImgs[$i].CreationTime -gt (Get-Date).AddDays(-21))
        {
        Copy-item $assetImgs[$i].FullName -Destination ($tempPath +  $assetImgs[$i] + ".jpg")
        }
    }

$landPictures = Get-FileMetaData -folder $tempPath | Where-Object {$_.Bredde -like "*1920*"}
$portPictures = Get-FileMetaData -folder $tempPath | Where-Object {$_.Bredde -like "*1080*"}
foreach ($pic in $landPictures) { Copy-Item -Path ($tempPath + $pic.Filnavn + ".jpg") -Destination ($spotPath + $pic.Filnavn + ".jpg") -Force }
foreach ($pic in $portPictures) { Copy-Item -Path ($tempPath + $pic.Filnavn + ".jpg") -Destination ($spotVertPath + $pic.Filnavn + ".jpg") -Force }