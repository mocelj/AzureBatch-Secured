// https://docs.microsoft.com/en-us/azure/templates/microsoft.batch/batchaccounts?tabs=bicep


param batchAccountName string 
param location string = resourceGroup().location
param tags object = {}

param batchManagedIdentity string
param batchStorageAccount string
param batchKeyVault string

param privateEndpointSubnetId string
param rgDNSZone string

// ---------------------------------

resource azBatchManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'  existing = {
  name: batchManagedIdentity
}

resource azBatchStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: batchStorageAccount
}

resource azBatchKeyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: batchKeyVault
}

resource azBatch 'Microsoft.Batch/batchAccounts@2021-06-01' = {
  name:batchAccountName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${azBatchManagedIdentity.id}' : {}
    }
  }
  properties: {
    allowedAuthenticationModes: [
      'AAD'
      'TaskAuthenticationToken'
      
    ]
    autoStorage: {
      storageAccountId: azBatchStorageAccount.id
      authenticationMode: 'BatchAccountManagedIdentity'
      nodeIdentityReference: {
        resourceId: azBatchManagedIdentity.id
      }
    }
    poolAllocationMode: 'UserSubscription'
    publicNetworkAccess: 'Disabled'
    keyVaultReference: {
      url: azBatchKeyVault.properties.vaultUri
      id: azBatchKeyVault.id
    }
  }
}

// Add private Endpoint


// Create the Batch Account Private Endpoint

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' =  {
  name: '${azBatch.name}-pl'
  tags: tags
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${azBatch.name}-pl'
        properties: {
          privateLinkServiceId: azBatch.id
          groupIds: [
            'batchAccount'
          ]
        }
      }
    ]
  }
  dependsOn: []
}

output privateEndpointIp string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
output privateEndpointFqdn string = privateEndpoint.properties.customDnsConfigs[0].fqdn

// Add an A Entry in the Global DNS Zone

var batchPrivateDnsZoneName = 'privatelink.${location}.batch.azure.com' 

module deployEndpointAEntry '../../modules/networking/dnsZones/privateDnsZoneAEntry.bicep' = {
  name: 'deployEndpointAEntry-${azBatch.name}'
  params: {
    ipAddress: privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
    privateDnsZoneName: batchPrivateDnsZoneName
    serviceName: azBatch.name
  }
  dependsOn: []
  scope: resourceGroup(rgDNSZone)
}

