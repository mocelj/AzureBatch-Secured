
// https://docs.microsoft.com/en-us/azure/templates/microsoft.batch/batchaccounts/pools?tabs=bicep

param batchAccountName string
param batchManagedIdentity string
param batchPoolObject object


//--------------------------------------------

resource azBatch 'Microsoft.Batch/batchAccounts@2021-06-01' existing = {
  name: batchAccountName
}

resource azBatchManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'  existing = {
  name: batchManagedIdentity
}

//--------------------------------------------


resource batchAccountPool 'Microsoft.Batch/batchAccounts/pools@2021-06-01' = {
  name: batchPoolObject.poolName
  parent: azBatch
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${azBatchManagedIdentity.id}' : {}
    }
  }
  properties: {
    displayName: batchPoolObject.poolName
    vmSize: batchPoolObject.vmSize
    taskSlotsPerNode: batchPoolObject.taskSlotsPerNode
    taskSchedulingPolicy: batchPoolObject.taskSchedulingPolicy
    deploymentConfiguration: batchPoolObject.deploymentConfiguration
    scaleSettings: batchPoolObject.scaleSettings
    interNodeCommunication: batchPoolObject.interNodeCommunication
    networkConfiguration: batchPoolObject.networkConfiguration
    startTask: contains(batchPoolObject,'startTask') ? batchPoolObject.startTask : ''
  }  
}
