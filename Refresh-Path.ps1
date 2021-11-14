# Refresh-Path.ps1
# 
# Refreshes the path variable in a Powershell session.
# Taken from http://stackoverflow.com/questions/14381650/how-to-update-windows-powershell-session-environment-variables-from-registry 

<# 
# Adding a folder to USER Path variable (remember prefix ';'), replace User with Machine to modify computer settings
$lagringssti = ""
$userenv = [System.Environment]::GetEnvironmentVariable("Path", "User")
[System.Environment]::SetEnvironmentVariable("PATH", $userenv + "$lagringssti", "User")
#>

foreach ($level in "Machine", "User") {
    [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
        # For Path variables, append the new values, if they're not already in there
        if ($_.Name -match 'Path$') { 
            $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select-Object -unique) -join ';'
        }
        $_
    } | Set-Content -Path { "Env:$($_.Name)" }
}