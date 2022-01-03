
param privateEndpointSubnetId string 
param storageAccountIpAllowAccess string
param tags object = {}
param rgHub string
param saDefinitions array
param kvName string = ''

// Create the Storage Accounts for the demo
// --------------------------------------------------------------------------------------------


module stgAzBatchGeneric '../../../modules/storage/storageAccount.bicep' = [ for saDefinition in saDefinitions:  {
    name: 'deplyStorageAccount-${saDefinition.storageAccountName}'
    params: {
      rgHub: rgHub
      storageAccountIpAllowAccess: storageAccountIpAllowAccess
      storageAccountName: saDefinition.storageAccountName
      privateLinkGroupIds: [
        saDefinition.privateLinkGroupIds
      ]
      privateEndpointSubnetId: privateEndpointSubnetId
      tags: tags
      kvName: kvName  
      storageAccountAccessTier: saDefinition.storageAccountAccessTier
      storageAccountKind: saDefinition.storageAccountKind
      largeFileSharesState: saDefinition.largeFileSharesState
      storageAccountSku: saDefinition.storageAccountSku
      supportsHttpsTrafficOnly: saDefinition.supportsHttpsTrafficOnly
      isHnsEnabled: saDefinition.isHnsEnabled
      isNfsV3Enabled: saDefinition.isNfsV3Enabled
      allowSharedKeyAccess: saDefinition.allowSharedKeyAccess
    }
  }]

  module stgAddContainer '../../../modules/storage/storageAccountAddContainers.bicep' = [ for saDefinition in saDefinitions: if (contains(saDefinition.privateLinkGroupIds,'blob')) {
    name: 'deployStorageContainer-${saDefinition.storageAccountName}'
    params: {
      storageAccountName: saDefinition.storageAccountName
      blobContainers: [
        'container'
      ]
    }
    dependsOn: [
      stgAzBatchGeneric
    ]
  }]  

  module stgAddFileShare '../../../modules/storage/storageAccountAddFileShare.bicep' = [ for saDefinition in saDefinitions: if (contains(saDefinition.privateLinkGroupIds,'file')) {
    name: 'deployStorageFileShare-${saDefinition.storageAccountName}'
    params: {
      storageAccountName: saDefinition.storageAccountName
      fileShareAccessTier: saDefinition.fileShareAccessTier
      fileShareEnabledProtocol: saDefinition.fileShareEnabledProtocol
      fileShares: [
        'share'
      ]
    }
    dependsOn: [
      stgAzBatchGeneric
    ]
  }]  
