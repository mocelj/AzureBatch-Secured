
// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/privateendpoints?tabs=bicep
// https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts/fileservices/shares?tabs=bicep

param storageAccountName string 
param rootName string = 'default'
param fileShareQuota int = 100


@allowed([
  'Cool'
  'Hot'
  'Premium'
  'TransactionOptimized'
])
param fileShareAccessTier string = 'Hot'

@allowed([
  'NFS'
  'SMB'
])
param fileShareEnabledProtocol string = 'NFS'

param fileShares array = []

// Create a file share if a file share name is provided

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-06-01' =  [for fileShareName in fileShares : {
  name: '${storageAccountName}/${rootName}/${fileShareName}'
  properties: {
    accessTier: fileShareAccessTier
    enabledProtocols: fileShareEnabledProtocol
    shareQuota: fileShareQuota
    //rootSquash: 'NoRootSquash'
    

  }
  dependsOn: []
}]
