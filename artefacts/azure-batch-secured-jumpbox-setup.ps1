param (
    [string] $BatchExplorerURL   = "https://github.com/Azure/BatchExplorer/releases/download/v2.11.0-stable.541/BatchExplorer.Setup.2.11.0-stable.541.exe",
    [string] $StorageExplorerURL = "https://github.com/microsoft/AzureStorageExplorer/releases/download/v1.22.0/Windows_StorageExplorer.exe",
    [string] $AzCliURL           = "https://azcliprod.blob.core.windows.net/msi/azure-cli-2.31.0.msi"
)

# File to write logs
$timeStamp = $(get-date -f MM-dd-yyyy) + " " + $(get-date -f HH_mm_ss)
$OutputFile = ".\$($env:COMPUTERNAME)" + $($timeStamp) + ".log"

# Removing log file if exists
if (Test-Path $OutputFile)
{
    Remove-Item $OutputFile
}

try {
    
    # Get the Download URLs from the input parameters
    
    ">> Starting the Software download ..." | Out-File $OutputFile -Append
    ">> Downloading Batch Explorer from: $($BatchExplorerURL)" | Out-File $OutputFile -Append
    
    # Download BatchExplorer
    $BatchExplorerOutFile = ".\BatchExplorerSetup.exe"
    Invoke-WebRequest -Uri $BatchExplorerURL -OutFile $BatchExplorerOutFile
    
    ">> Download finished..." | Out-File $OutputFile -Append

    # Download Storage Explorer

    ">> Downloading Storage Explorer from: $($StorageExplorerURL)" | Out-File $OutputFile -Append
    $StorageExplorerOutFile = ".\Windows_StorageExplorer.exe"
    Invoke-WebRequest -Uri $StorageExplorerURL -OutFile $StorageExplorerOutFile
    
    ">> Download finished..." | Out-File $OutputFile -Append

    # Download Azure CLI

    ">> Downloading AzCli from: $($AzCliURL)" | Out-File $OutputFile -Append
    $AzCliOutFile = ".\AzCli.msi"
    Invoke-WebRequest -Uri $AzCliURL -OutFile $AzCliOutFile


    ">> Download finished..." | Out-File $OutputFile -Append

    # Install the executables

    ">> Start the installation process..." | Out-File $OutputFile -Append

    Start-Process -Wait -FilePath $BatchExplorerOutFile -ArgumentList "/S" -PassThru
    ">> Batch Explorer installed..." | Out-File $OutputFile -Append

    Start-Process -Wait -FilePath $StorageExplorerOutFile -ArgumentList "/VERYSILENT /NORESTART /ALLUSERS" -PassThru
    ">> Storage Explorer installed..." | Out-File $OutputFile -Append

    
    Start-Process msiexec.exe -Wait -ArgumentList '/I AzCli.msi /quiet'
    ">> Azure CLI installed..." | Out-File $OutputFile -Append
    
    ">> Finished Software installation." | Out-File $OutputFile -Append
} catch {
    ">> ERROR:" | Out-File $OutputFile -Append
    $_ | Out-File $OutputFile -Append
}
