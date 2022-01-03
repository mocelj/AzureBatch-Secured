
param batchAccountName string
param batchManagedIdentity string
param batchSubnetId string


param preloadContainerImage string = 'acrdevsecb2azbatch.azurecr.io/kvsecretsmi:latest'
param containerRegistryServer string = 'acrdevsecb2azbatch.azurecr.io'

//--------------------------------------------

resource azBatch 'Microsoft.Batch/batchAccounts@2021-06-01' existing = {
  name: batchAccountName
}

resource azBatchManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'  existing = {
  name: batchManagedIdentity
}

var batchPoolObject  = {
  poolName: 'linux-dev-pool-auto-xx'
  vmSize: 'STANDARD_D4_V2'
  taskSlotsPerNode: 2
  taskSchedulingPolicy: {
    nodeFillType: 'Spread'
  }
  deploymentConfiguration: {
    virtualMachineConfiguration: {
      imageReference: {
        publisher: 'microsoft-azure-batch'
        offer: 'ubuntu-server-container'
        sku: '20-04-lts'
        version: 'latest'
      }
      nodeAgentSkuId: 'batch.node.ubuntu 20.04'
    }
  }
  scaleSettings: {
    fixedScale: {
      targetDedicatedNodes: 0
      targetLowPriorityNodes: 0
      resizeTimeout: 'PT5M'
    }
  }
  interNodeCommunication: 'Disabled'
  networkConfiguration: {
    subnetId: batchSubnetId
    publicIPAddressConfiguration: {
      provision: 'NoPublicIPAddresses'
    }
  }
}

// var batchPoolObject  = {
//   poolName: 'linux-dev-pool'
//   vmSize: 'STANDARD_D4_V2'
//   taskSlotsPerNode: 2
//   taskSchedulingPolicy: {
//     nodeFillType: 'Spread'
//   }
//   deploymentConfiguration: {
//     virtualMachineConfiguration: {
//       imageReference: {
//         publisher: 'microsoft-azure-batch'
//         offer: 'centos-container'
//         sku: '7-7'
//         version: 'latest'
//       }
//       nodeAgentSkuId: 'batch.node.centos 7'
//       containerConfiguration: {
//         type: 'DockerCompatible'
//         containerImageNames: [
//           preloadContainerImage
//         ]
//         containerRegistries: [
//           {
//             identityReference: {
//               resourceId: azBatchManagedIdentity.id
//             }
//             registryServer: containerRegistryServer
//           }  
//         ]
//       }
//     }
//   }
//   scaleSettings: {
//     fixedScale: {
//       targetDedicatedNodes: 0
//       targetLowPriorityNodes: 0
//       resizeTimeout: 'PT15M'
//     }
//   }
//   interNodeCommunication: 'Disabled'
//   networkConfiguration: {
//     subnetId: batchSubnetId
//   }
// }

resource batchAccountPool 'Microsoft.Batch/batchAccounts/pools@2021-06-01' = {
  name: batchPoolObject.poolName
  parent: azBatch
  // identity: {
  //   type: 'UserAssigned'
  //   userAssignedIdentities: {
  //     '${azBatchManagedIdentity.id}' : {}
  //   }
  // }
  properties: {
    displayName: batchPoolObject.poolName
    vmSize: batchPoolObject.vmSize
    taskSlotsPerNode: batchPoolObject.taskSlotsPerNode
    taskSchedulingPolicy: batchPoolObject.taskSchedulingPolicy
    deploymentConfiguration: batchPoolObject.deploymentConfiguration
    scaleSettings: batchPoolObject.scaleSettings
    interNodeCommunication: batchPoolObject.interNodeCommunication
    networkConfiguration: batchPoolObject.networkConfiguration
  }  
}
