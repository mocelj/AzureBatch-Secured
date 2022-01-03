// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/privateendpoints?tabs=bicep
// https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts/fileservices/shares?tabs=bicep

param storageAccountName string 
param rootName string = 'default'



// For Blob Storage
param blobContainers array = []

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = [for blobContainer in blobContainers: {
  name: '${storageAccountName}/${rootName}/${blobContainer}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: []
}]


