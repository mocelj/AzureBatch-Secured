// https://docs.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults?tabs=bicep

param tags object = {}
param location string = resourceGroup().location

param keyVaultName string
param keyVaultFamily string = 'A'

@allowed([
  'standard'
  'premium'
])
param keyVaultSkuName string = 'standard'


param enablePurgeProtection bool = true
param enabledForDeployment bool = true
param enabledForDiskEncryption bool = true
param enabledForTemplateDeployment bool = true
param enableSoftDelete bool = true


@allowed([
  'disabled'
  'enabled'
])
param publicNetworkAccess string = 'disabled'


param deployPrivateKeyVault bool = true
param privateEndpointSubnetId string

param kvAccessPolicies array = []

// Needed for DNS A-Entry add
param rgDNSZone string

//---------------------------------------------------------------------

resource keyVaultResource 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    accessPolicies: kvAccessPolicies
    sku: {
      family: keyVaultFamily
      name: keyVaultSkuName
    }
    tenantId: subscription().tenantId
    enablePurgeProtection: enablePurgeProtection
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption:enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableSoftDelete: enableSoftDelete
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      // ipRules: [
        
      // ]
      // virtualNetworkRules: [
        
      // ]
    }
    publicNetworkAccess: publicNetworkAccess
  }
}

// if in private deployment mode, deploy a private endpoint


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = if (deployPrivateKeyVault) {
  name: '${keyVaultResource.name}-pl'
  tags: tags
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultResource.name}-pl'
        properties: {
          privateLinkServiceId: keyVaultResource.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
  dependsOn: []
}

output privateEndpointIp string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
output privateEndpointFqdn string = privateEndpoint.properties.customDnsConfigs[0].fqdn


// ... and add an A-Entry to the DNS Zone

//var kvPrivateDnsZoneName = 'privatelink${az.environment().suffixes.keyvaultDns}'

var kvPrivateDnsZoneName = 'privatelink.vaultcore.azure.net'

module deployEndpointAEntry '../../modules/networking/dnsZones/privateDnsZoneAEntry.bicep' = if (deployPrivateKeyVault) {
  name: 'deployEndpointAEntry-${keyVaultResource.name}'
  params: {
    ipAddress: privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
    privateDnsZoneName: kvPrivateDnsZoneName
    serviceName: keyVaultName
  }
  dependsOn: []
  scope: resourceGroup(rgDNSZone)
}
