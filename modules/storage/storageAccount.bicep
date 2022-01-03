// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/privateendpoints?tabs=bicep
// https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts/fileservices/shares?tabs=bicep

param rgHub string
param storageAccountName string 
param location string = resourceGroup().location
param storageAccountIpAllowAccess string
param kvName string

param tags object = {}

param privateEndpointSubnetId string = ''
param privateLinkGroupIds array = []

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param storageAccountSku string = 'Standard_LRS'

@allowed([
  'FileStorage'
  'StorageV2'
])
param storageAccountKind string = 'StorageV2'

@allowed([
  'Cool'
  'Hot'
])
param storageAccountAccessTier string = 'Hot'

// NfsV3 over blob requieres Hierarchical Namespace to be enabled
param isHnsEnabled bool = false 
param isNfsV3Enabled bool = false


@allowed([
  'Enabled'
  'Disabled'
])
param largeFileSharesState string = 'Disabled'

// if NFS protocol is used, this has to be disabled
param supportsHttpsTrafficOnly bool = true

param allowBlobPublicAccess bool = false

param allowSharedKeyAccess bool = false

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageAccountSku
  }
  kind: storageAccountKind
  properties: {
    supportsHttpsTrafficOnly: supportsHttpsTrafficOnly
    accessTier: storageAccountAccessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    minimumTlsVersion: 'TLS1_2'
    isNfsV3Enabled: isNfsV3Enabled
    largeFileSharesState: largeFileSharesState
    isHnsEnabled: isHnsEnabled
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules:  (storageAccountIpAllowAccess == '') ? null : [
        {
          action: 'Allow'
          value: storageAccountIpAllowAccess
        }
      ]
    }
  }
}

output saName string = storageAccount.name
output saId string = storageAccount.id

// if a KV name is provided, add the storage account keys to the KV

var secretName = 'sa-connection-${storageAccount.name}'

// Determine our connection string
var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'


resource secret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = if (kvName != '') {
  //parent: kv
  name: '${kvName}/${secretName}'
  tags: tags
  properties: {
    value: storageAccountConnectionString
  }
  dependsOn: []
}

// Create a privat endpoint if provided with a SubnetId

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = if (privateEndpointSubnetId != '') {
  name: '${storageAccount.name}-pl'
  tags: tags
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccount.name}-pl'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: privateLinkGroupIds
        }
      }
    ]
  }
  dependsOn: []
}

output privateEndpointIp string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
output privateEndpointFqdn string = privateEndpoint.properties.customDnsConfigs[0].fqdn

// Add an A Entry in the Global DNS Zone

var filePrivateDnsZoneName = 'privatelink.file.${az.environment().suffixes.storage}'
var blobPrivateDnsZoneName = 'privatelink.blob.${az.environment().suffixes.storage}'

var privateDnsZoneName = contains(privateLinkGroupIds,'blob') ? blobPrivateDnsZoneName : filePrivateDnsZoneName

module deployEndpointAEntry '../../modules/networking/dnsZones/privateDnsZoneAEntry.bicep' = if (privateEndpointSubnetId != '') {
  name: 'deployEndpointAEntry-${storageAccount.name}'
  params: {
    ipAddress: privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
    privateDnsZoneName: privateDnsZoneName
    serviceName: storageAccountName
  }
  dependsOn: []
  scope: resourceGroup(rgHub)
}
