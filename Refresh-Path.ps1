<#

# Refresh-Path.ps1
# 
# Refreshes the path variable in a Powershell session.
# Taken from http://stackoverflow.com/questions/14381650/how-to-update-windows-powershell-session-environment-variables-from-registry 

# Adding a folder to USER Path variable (remember prefix ';'), replace User with Machine to modify computer settings

#>

# Folder to add to PATH
$myPath = ";C:\Tools\binaries"
# Replace User with Machine to add to system PATH
$userEnv = [System.Environment]::GetEnvironmentVariable("Path", "User")
# Add $myPath to user environment, replace User with Machine to add to system PATH
[System.Environment]::SetEnvironmentVariable("PATH", $userEnv + "$myPath", "User")

# Walk through every PATH element
foreach ($level in "Machine", "User") {
    # List all environment variables for Machine and User, looking for Path$
    [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
        # For Path variables, append the new values, if they're not already in there
        if ($_.Name -match 'Path$') { 
            $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select-Object -unique) -join ';'
        }
        $_
        # Update current PATH variable to reload new PATH (including $myPath)
    } | Set-Content -Path { "Env:$($_.Name)" }
}