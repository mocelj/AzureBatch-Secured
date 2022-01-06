
param (
    # Your tenant id (in Azure Portal, under Azure Active Directory -> Overview )
    [string] $TenantID ,
    # Name of the manage identity
    [string] $DisplayNameOfMSI ,
    # Check the Microsoft Graph documentation for the permission you need for the operation    
    [string] $PermissionName = "Domain.Read.All" 
)

# Microsoft Graph App ID (DON'T CHANGE)
$GraphAppId = "00000003-0000-0000-c000-000000000000"


# Install the module (You need admin on the machine)
Install-Module AzureAD -Force

# First, give the managed identiy read permissions

Connect-AzureAD -TenantId $TenantID 

$MSI = (Get-AzureADServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'")

Start-Sleep -Seconds 10

$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"

$AppRole = $GraphServicePrincipal.AppRoles | `
Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}

New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId `
-ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id

# Second, get the ObjectId fo the Azure Batch Service Pricipal

$output = (Get-AzADServicePrincipal -ServicePrincipalName MicrosoftAzureBatch).Id

Write-Output $output
$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs[\'text\'] = $output