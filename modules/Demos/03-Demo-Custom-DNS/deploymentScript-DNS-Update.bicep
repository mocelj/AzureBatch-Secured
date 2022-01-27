
param location string = resourceGroup().location
param tags object = {}

param vNetHub string
param vNetSpoke01 string
param vNetSpoke02 string

param rgHub     string
param rgSpoke01 string
param rgSpoke02 string

param managedIdentityName string

param fwName      string
param dnsServerIp string


param azureCliVersion string = '2.30.0'
param currentTime string = utcNow()

// -------------------------------- Create a Managed Indentiy and assign the required permissions -----------

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'  = {
  name: managedIdentityName
  location: resourceGroup().location
  tags: tags
}

// assign contributor permissons on RG level to be able to create the ACI for the script deployment

module assignRGContributorRoleMI '../../../modules/azRoles/roleAssignmentResourceGroup.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-RG-DNS-MI-Contrib'
  params: {
    builtInRoleType: 'Contributor'
    principalId: mi.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

// assign network contributor permissons on RG level for the Hub - needed to update VNETS AND NSG Objects

module assignRGNetworkContributorRoleHub01 '../../../modules/azRoles/roleAssignmentResourceGroup.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-RG-Hub01-MI-NwContrib'
  scope: resourceGroup(rgHub)
  params: {
    builtInRoleType: 'NetworkContributor'
    principalId: mi.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    assignRGContributorRoleMI
  ]
}

// assign network contributor permissons on RG level for the Spoke01 - needed to update VNETS AND NSG Objects

module assignRGNetworkContributorRoleSpoke01 '../../../modules/azRoles/roleAssignmentResourceGroup.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-RG-Spoke01-MI-NwContrib'
  scope: resourceGroup(rgSpoke01)
  params: {
    builtInRoleType: 'NetworkContributor'
    principalId: mi.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    assignRGNetworkContributorRoleHub01
  ]
}

// assign network contributor permissons on RG level for the Spoke01 - needed to update VNETS AND NSG Objects

module assignRGNetworkContributorRoleSpoke02 '../../../modules/azRoles/roleAssignmentResourceGroup.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-RG-Spoke02-MI-NwContrib'
  scope: resourceGroup(rgSpoke02)
  params: {
    builtInRoleType: 'NetworkContributor'
    principalId: mi.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    assignRGNetworkContributorRoleSpoke01
  ]
}

// -------------------------------- Execute the deployment script and Update DNS Settings ---------------

resource refFw 'Microsoft.Network/azureFirewalls@2021-05-01' existing = {
  name: fwName
  scope: resourceGroup(rgHub)
}

var ipFw = refFw.properties.ipConfigurations[0].properties.privateIPAddress

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'updateFwVnetDns'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi.id}': {}
    }
  }
  properties: {
    azCliVersion: azureCliVersion
    arguments: '${fwName} ${rgHub} ${dnsServerIp} ${ipFw} ${vNetHub} ${rgSpoke01} ${vNetSpoke01} ${rgSpoke02} ${vNetSpoke02}'
    scriptContent: '''
    az extension add --name azure-firewall
    az network firewall update --name $1 --resource-group $2 --dns-servers $3 --enable-dns-proxy true
    az network vnet update --resource-group $2 --name $5 --dns-servers $4
    az network vnet update --resource-group $6 --name $7 --dns-servers $4
    az network vnet update --resource-group $8 --name $9 --dns-servers $4
    '''
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: currentTime // ensures script will run every time
  }
  dependsOn: [
    assignRGContributorRoleMI
    assignRGNetworkContributorRoleHub01
    assignRGNetworkContributorRoleSpoke01
    assignRGNetworkContributorRoleSpoke02
  ]
}

// print logs from script after template is finished deploying
output scriptLogs string = reference('${deploymentScript.id}/logs/default', deploymentScript.apiVersion, 'Full').properties.log
