<#
.SYNOPSIS
    PowerShell script that replaces (server)nameA with (server)nameB
    Set a root folder and the script will run through all files of the configured type
.DESCRIPTION
    Script loops through files in the provided directory and subdirectories
    It looks for files with a certain filename extension
    If 'stringA' is found in a file it will replace it with 'stringB'
    Finally, it will output the result
    Script window will not automatically close to allow the user to view the summary
.EXAMPLE
    If script doesn't run, run the command below first (only required to do once)
    PS C:\> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

    PS C:\> Set-StringInFiletype.ps1
    Executes the script (remember, variables must be configured prior to execution)
.INPUTS
    All inputs can be defined in the script
    If $folder variable is not set in the script it will be prompted for
    In the current iteration, input parameters are not supported
.OUTPUTS
    Outputs status to console
.NOTES
    Date of origin 17.11.21
    Idea by Tim Peter Edstrøm

    Modified 19.11.21 - Tim Peter Edstrøm
    Reorganized output in a summary once the script is done processing files and folders
    Added a Read-Host | Out-Null to stop script window from closing once run is complete

    Feel free to re-use and modify to suit your requirements.
#>

# Variables required to successfully execute script
$folder = ""
$fileExtension = ""
$stringA = ""
$stringB = ""
[System.Collections.ArrayList] $emptyDirs = @()
[System.Collections.ArrayList] $filesModified = @()

# Ask for folder if the $folder variable is not set
if ([System.String]::IsNullOrEmpty($folder) ) {
    $folder = Read-Host -Prompt "Enter source folder"
    Write-Host "Is this folder correct: $($folder) ?" -ForegroundColor Yellow
    Write-Host "Press ENTER to continue or CTRL+C to abort execution and start script again..."
    Read-Host | Out-Null
}

# Set up a try / catch
try {
    # Test for existence of path provided and abort if the folder is missing on inaccessible
    if (-not (Test-Path $folder)) {
        Write-Host "Can't find or access directory '$($folder)', please try again! Aborting..." -ForegroundColor Red
        return
    }else {
        # Create an (re-sizeable) array list of directories
        [System.Collections.ArrayList] $directories = @()
        (Get-ChildItem -Path $folder -Attributes Directory -Recurse).FullName | ForEach-Object { $directories.Add($_) } | Out-Null
        # Add the initial directory ($folder) to the list
        $directories.Add($folder) | Out-Null
    }
    
    # Loop through all directories discovered below named path
    foreach ($directory in $directories | Where-Object { -not [System.String]::IsNullOrEmpty($_) } ) {

        # Inspect final character of directory path and add backslash "\" if not present
        if ( ($directory.ToString())[-1] -ne "\") { $directory = $directory + "\" }

        # Run through a folder and populate variable if file(s) match file extension regex
        $files = (Get-ChildItem -File -Path $directory).Name | Where-Object { $_ -match $fileExtension }
        # Check if any files matching regex were found
        if (-not ($null -eq $files)) {
            # Loop over each file found, look for $stringA and replace it with $stringB if found in file content
            foreach ($file in $files | Where-Object { (Get-Content -Path ($directory + $_)) -match $stringA } ) {
                $content = (Get-Content -Path ($directory + $file)).Replace($stringA, $stringB)
                Set-Content -Value $content -Path ($directory + $file)
                $filesModified.Add($($directory + $file)) | Out-Null
                $successNumber++
            }
        }else {
            $emptyDirs.Add($directory) | Out-Null
        }
    }
}
# Catch errors that may occur and output exception message
catch {
    Write-Host "An error occurred.`n$($_.Exception.Message)" -ForegroundColor Red
    return
}

#region Issue a summary
#
if (-not [System.String]::IsNullOrEmpty($successNumber)) { 
    # Output all directories run through without files that were modified (yellow)
    foreach ($dir in $emptyDirs) {
        Write-Host "No files found in directory $dir" -ForegroundColor Yellow
    }
    # Output all files, with full filepath, that were modified (green)
    foreach ($modified in $filesModified) {
        Write-Host "Successfully replaced '$stringA' with '$stringB' in file $modified" -ForegroundColor Green
    }
    
    Write-Host "`nA total of $($successNumber) entries were replaced during this run." -ForegroundColor Green
}else {
    Write-Host "No changes were made..." -ForegroundColor Yellow
}

Write-Host "`nScript execution complete. Press ENTER or CTRL+C to finish." -ForegroundColor Cyan
Read-Host | Out-Null
#endregion

# Cleanup
$folder, $fileExtension, $stringA, $stringB, $directories, $directory, $files, $file, $successNumber, $emptyDirs, $filesModified = $null