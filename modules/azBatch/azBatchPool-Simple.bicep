
param batchAccountName string
param batchManagedIdentityId string 
param batchPoolObjects array


//--------------------------------------------

resource azBatch 'Microsoft.Batch/batchAccounts@2021-06-01' existing = {
  name: batchAccountName
}

@batchSize(1)
resource batchAccountPool 'Microsoft.Batch/batchAccounts/pools@2021-06-01' =  [ for batchPoolObject in batchPoolObjects: {
  name: batchPoolObject.poolName
  parent: azBatch
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${batchManagedIdentityId}' : {}
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
    mountConfiguration: contains(batchPoolObject,'mountConfiguration') ? batchPoolObject.mountConfiguration : ''
  }  
}]
