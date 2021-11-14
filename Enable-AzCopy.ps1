# Definer variabler
$lagringssti = "C:\temp\AzCopy"

# Last ned AzCopy.zip, men aktiver først Tls12 i tilfelle dette ikke kjører som standard
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocol]::Tls12
Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile AzCopy.zip -UseBasicParsing
 
# Pakk opp arkiv (.zip fil)
Expand-Archive ./AzCopy.zip ./AzCopy -Force
 
# Flytt azcopy.exe til ønsket mappe, bestemt av variabel $lagringssti
if (-not (Test-Path $lagringssti) ) { New-Item -Type Directory $lagringssti }
Get-ChildItem ./AzCopy/*/azcopy.exe | Move-Item -Destination "$lagringssti\AzCopy.exe"
 
# Rydd bort mappen som ble opprettet ved utpakking av arkiv fil
Remove-Item -Path .\AzCopy -Recurse -Force

# VALGFRITT – Legg til mappen med AzCopy til Windows PATH ved bruk av PowerShell
$userenv = [System.Environment]::GetEnvironmentVariable("Path", "User")
[System.Environment]::SetEnvironmentVariable("PATH", $userenv + "$lagringssti", "User")

# Laster inn den oppdaterte PATH stien så man kan begynne med azcopy i kjørende vindu
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")