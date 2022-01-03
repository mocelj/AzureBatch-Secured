


// This Template will orchestrate a Azure Batch in private mode deployment

param rgAzureBatch string
param prefix string
param environment string
param rgHub string
param rgSpoke string
param tags object = {}
param vNetObject object

// Storage Accounts

param storageAccountIpAllowAccess string
param saDefinitions array
param saNameAzBatch string

// ACR

param acrName string 
param acrPublicNetworkAccess string
param acrSku string
param acrAdminUserEnabled bool
param deployPrivateACR bool 
param primaryScriptBuildKvTestImage string 

// AKV
// we are hitting the kv naming convention limit with with name. Be careful if you change it.
var kvName = 'kv-${environment}-${prefix}-ba'
param deployPrivateAKV bool = true

// Azure Batch
// az ad sp show --id "MicrosoftAzureBatch" --query objectId -o tsv
param batchServiceObjectId string
param assignBatchServiceRoles bool

param batchAccountName string

param batchNodeSku string

// To-do: Can we run a deployment script and query the batchObject ID? Take this as an output?
//

//------------------------------------------------------------------------
//  This Demo will deploy an Azure Batch account with 3 pools in a secured
//  environment.
//  - Grant the Batch API Service contributor permissions to the subscription (see)
//    https://docs.microsoft.com/en-us/azure/batch/batch-account-create-portal#additional-configuration-for-user-subscription-mode
//  - Managed Identity (will be assigned to the pool)
//  - AKV 
//  - ACR
//  - Storage account(s)
//  - Grant the Batch API Service permissions to the pre-provisioned Key Vaults
//  - Grant the managed Identity ACR Push and Storage Account permissions (to avoid configuration of sa keys)
//  - Batch Account
//  - Pools
//------------------------------------------------------------------------


// Generic References used in the deployment script
//------------------------------------------------------------------------

module deployBatchRoleAssignment '../../../modules/azRoles/roleAssignmentSubscription.bicep' = if (assignBatchServiceRoles) {
  name: 'deployBatchRoleAssignment'
  params: {
    builtInRoleType: 'Contributor'
    principalId: batchServiceObjectId
  }
  scope: subscription()
}

resource refVNetSpoke 'Microsoft.Network/virtualNetworks@2021-03-01' existing = {
  scope: resourceGroup(rgSpoke)
  name: vNetObject.vNetName
}


resource refDNSzone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name:  'privatelink${az.environment().suffixes.acrLoginServer}'
  scope: resourceGroup(rgHub)
}


var privateEndpointSubnetId = '${refVNetSpoke.id}/subnets/${vNetObject.subnets[vNetObject.positionEndpointSubnet].subnetName}'

var batchPoolSubnetId_Linux = '${refVNetSpoke.id}/subnets/${vNetObject.subnets[vNetObject.positionLinuxSubnet].subnetName}'
var batchPoolSubnetId_LinuxNoSsh = '${refVNetSpoke.id}/subnets/${vNetObject.subnets[vNetObject.positionLinuxNoSshSubnet].subnetName}'
var batchPoolSubnetId_Windows = '${refVNetSpoke.id}/subnets/${vNetObject.subnets[vNetObject.positionWindowsSubnet].subnetName}'


// Create a managed identity which will be added to the batch pool
//------------------------------------------------------------------------

var batchManagedIdentity = 'id-${environment}-${prefix}-azbatch'

resource azBatchManagedIdentity  'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: batchManagedIdentity
  location: resourceGroup().location
  tags: tags
}

// Create a key vault to store secrets and connections strings
//------------------------------------------------------------------------

// TO-DO: check if connections strings are required, or if everything could be handled
// by the managed identity

module deployAzBatchKV '../../../modules/azureKeyVault/azureKeyVault.bicep' = {
  name: 'deployAzBatchKV'
  params: {
    keyVaultName: kvName
    privateEndpointSubnetId: privateEndpointSubnetId
    deployPrivateKeyVault: deployPrivateAKV
    rgDNSZone: rgHub 
    tags: tags
  }
  dependsOn: [
    azBatchManagedIdentity
  ]
}

// Add initial access policies for the managed identiy and Batch Service

var kvAccessPolicyMI = [
  {
    objectId: azBatchManagedIdentity.properties.principalId
    permissions: {
      secrets: [
        'get'
        'list'
        'set'
        'delete'
        'recover'
      ]
    }
    tenantId: subscription().tenantId
  }
  {
    objectId: batchServiceObjectId
    permissions: {
      secrets: [
        'get'
        'list'
        'set'
        'delete'
        'recover'
      ]
    }
    tenantId: subscription().tenantId
  }
]

// Allow the MI to access the KV

module kvPolicyManagedIdentity '../../../modules/azureKeyVault/azureKeyVaultAddAccessPolicy.bicep' = {
  name: 'kvPolicyManagedIdentiy-add'
  params: {
    accessPolicy: array(kvAccessPolicyMI)
    accessPolicyAction: 'add'
    kvName: kvName
  }
  dependsOn: [
    deployAzBatchKV
  ]
}

// Create the Azure Container Registry
//------------------------------------------------------------------------

// Create a 'build' ACR to build the containers, outside of the locked down vNet
// Import the built containers to the batch ACR through Azure Trusted Servcies enabled
// delete the temp 'build' ACR in the external build script

var acrBuildName = 'tempacrbuild'
module deployBatchDemoBuildACR '../../../modules/containerRegistry/acr.bicep' = {
  name: 'deployBuildACR'

  params: {
    name: acrBuildName
  }

}

var acrPrivateEndpoints_tmp  = [
  {
    name: '${acrName}-pl' 
    subnetResourceId: privateEndpointSubnetId
    service: 'registry'
    privateDnsZoneResourceIds: [ 
      refDNSzone.id
    ]
  }
]

var acrPrivateEndpoints = deployPrivateACR ? acrPrivateEndpoints_tmp : []

var acrRoleAssignments = [
  {
    roleDefinitionIdOrName: 'AcrPush'
    principalIds: [
      azBatchManagedIdentity.properties.principalId
    ]
  }
]

module deployBatchDemoACR '../../../modules/containerRegistry/acr.bicep' = {
  name: 'deployBatchACR'
  params: {
    name: acrName
    acrAdminUserEnabled: acrAdminUserEnabled
    privateEndpoints: acrPrivateEndpoints
    acrSku: acrSku
    publicNetworkAccess: acrPublicNetworkAccess
    tags: tags
    roleAssignments: acrRoleAssignments
  }
  dependsOn: []
}


// Create required storage accounts
//------------------------------------------------------------------------

module deployBatchDemoStorageAccounts '../../../modules/Demos/Demo-Batch-Secured/demoAzureBatch-Secured-Storage.bicep' = {
  name: 'deployBatchDemoStorageAccounts'
  params: {
    rgHub: rgHub
    kvName: kvName
    privateEndpointSubnetId: privateEndpointSubnetId
    saDefinitions: saDefinitions 
    storageAccountIpAllowAccess: storageAccountIpAllowAccess
    tags: tags
  }
  scope: resourceGroup(rgAzureBatch)
  dependsOn: [
    deployAzBatchKV
  ]
}

// Grant the managed Identity Contributor permissions to the storage accounts
// https://docs.microsoft.com/en-us/azure/batch/resource-files?utm_source=pocket_mylist
// Storage Blob Data Reader is minium role for MI


module assignStorageAccountRole '../../../modules/storage/roleAssignmentStorage.bicep' = [ for saDefinition in saDefinitions: {
  name: 'deployStorageRoleMI-${saDefinition.storageAccountName}'
  params: {
    builtInRoleType: 'StorageBlobDataContributor'
    principalId: azBatchManagedIdentity.properties.principalId
    saName: saDefinition.storageAccountName
  }
  dependsOn: [
    deployBatchDemoStorageAccounts
  ]
}]


// Deploy a test image to the ACR
//------------------------------------------------------------------------

var acrImageName = 'kvsecretsmi'

// assign contributor permissons on RG level to be able to create the temp ACI / ACR for script deployment

module assignRGContributorRoleMI '../../../modules/azRoles/roleAssignmentResourceGroup.bicep' = {
  name: 'deployAssignRGContributorRoleMI'
  params: {
    builtInRoleType: 'Contributor'
    principalId: azBatchManagedIdentity.properties.principalId
  }
  dependsOn: []
}

module deployCheckKVImage '../../../modules/deploymentScripts/deploymentScript-MI-ACR.bicep'  = {
  name: 'deployCheckKVImage'
  params: {
    acrBuildName: acrBuildName
    acrName: acrName
    acrImageName: acrImageName
    managedIdentityName: batchManagedIdentity
    primaryScriptUri: primaryScriptBuildKvTestImage
    tags: tags
  }
  dependsOn: [
    azBatchManagedIdentity
    assignRGContributorRoleMI
  ]
}


// // module getAzureBatchObjectId '../../../modules/deploymentScripts/deploymentScript-Query-BatchService-ObjectId.bicep' = {
// //   name: 'getAzureBatchObjectId'
// //   params: {
// //     managedIdentityName: batchManagedIdentity
// //     tags: tags
// //   }
// //   dependsOn: [
// //     azBatchManagedIdentity
// //   ]
// // }

// //output scriptLogs string = getAzureBatchObjectId.outputs.scriptLogs



// Create the Azure Batch account
//------------------------------------------------------------------------

module deployAzureBatchAccount '../../../modules/azBatch/azBatchAccount-MI.bicep' = {
  name: 'deployAzureBatchAccount'
  params: {
    batchAccountName: batchAccountName
    batchKeyVault: kvName
    batchManagedIdentity: batchManagedIdentity
    batchStorageAccount: saNameAzBatch
    privateEndpointSubnetId: privateEndpointSubnetId
    rgDNSZone: rgHub
    tags: tags
  }
  dependsOn: [
    azBatchManagedIdentity
    deployAzBatchKV
    kvPolicyManagedIdentity
    deployBatchDemoStorageAccounts
    assignStorageAccountRole
    deployBatchRoleAssignment
  ]
}

// Create the Azure Batch Pools
//------------------------------------------------------------------------

var preloadContainerImage = '${acrName}.azurecr.io/${acrImageName}:latest'
var containerRegistryServer = '${acrName}.azurecr.io'

// Connect to ACR through MI
// Connect to AKV through MI
// Deploy Linux Pool in allowed-to-log-in mode
// Deploy Linux Pool in not-allowed-log-in mode (handled by NSG)
// Deploy Windows Pool in allowed-to-log-in mode


var batchPoolObjects  = [
  {
    poolName: 'linux-dev-pool'
    vmSize: batchNodeSku
    taskSlotsPerNode: 2
    taskSchedulingPolicy: {
      nodeFillType: 'Pack'
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

        containerConfiguration: {
          type: 'DockerCompatible'
          containerImageNames: [
            preloadContainerImage
          ]
        
          containerRegistries: [
            {
              identityReference: {
                resourceId: azBatchManagedIdentity.id
              }
              registryServer: containerRegistryServer
            }  
          ]
        }

      }
    }
  
    scaleSettings: {
      fixedScale: {
        targetDedicatedNodes: 0
        targetLowPriorityNodes: 0
        resizeTimeout: 'PT15M'
      }
    }
  
    interNodeCommunication: 'Disabled'
    networkConfiguration: {
      subnetId: batchPoolSubnetId_Linux
      publicIPAddressConfiguration: {
        provision: 'NoPublicIPAddresses'
      }
    }
  }
  {
    poolName: 'linux-prod-pool'
    vmSize: batchNodeSku
    taskSlotsPerNode: 2
    taskSchedulingPolicy: {
      nodeFillType: 'Pack'
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

        containerConfiguration: {
          type: 'DockerCompatible'
          containerImageNames: [
            preloadContainerImage
          ]
        
          containerRegistries: [
            {
              identityReference: {
                resourceId: azBatchManagedIdentity.id
              }
              registryServer: containerRegistryServer
            }  
          ]
        }

      }
    }
  
    scaleSettings: {
      fixedScale: {
        targetDedicatedNodes: 0
        targetLowPriorityNodes: 0
        resizeTimeout: 'PT15M'
      }
    }
  
    interNodeCommunication: 'Disabled'
    networkConfiguration: {
      subnetId: batchPoolSubnetId_LinuxNoSsh
      publicIPAddressConfiguration: {
        provision: 'NoPublicIPAddresses'
      }
    }
  }
  {
    poolName: 'windows-dev-pool'
    vmSize: batchNodeSku
    taskSlotsPerNode: 2
    taskSchedulingPolicy: {
      nodeFillType: 'Pack'
    }
    deploymentConfiguration: {
      virtualMachineConfiguration: {
        imageReference: {
          publisher: 'microsoftwindowsserver'
          offer: 'windowsserver'
          sku: '2019-datacenter-core-with-containers-smalldisk'
          version: 'latest'
        }
      
        nodeAgentSkuId: 'batch.node.windows amd64'

        windowsConfiguration: {
          enableAutomaticUpdates: true
        }

        containerConfiguration: {
          type: 'DockerCompatible'
          containerImageNames: [
            preloadContainerImage
          ]
        
          containerRegistries: [
            {
              identityReference: {
                resourceId: azBatchManagedIdentity.id
              }
              registryServer: containerRegistryServer
            }  
          ]
        }

      }
    }
  
    scaleSettings: {
      fixedScale: {
        targetDedicatedNodes: 0
        targetLowPriorityNodes: 0
        resizeTimeout: 'PT15M'
      }
    }
  
    interNodeCommunication: 'Disabled'
    networkConfiguration: {
      subnetId: batchPoolSubnetId_Windows
      publicIPAddressConfiguration: {
        provision: 'NoPublicIPAddresses'
      }
    }
  }
]

@batchSize(1)
module deployBatchPool '../../../modules/azBatch/azBatchPool.bicep' = [ for batchPoolObject in batchPoolObjects:  {
  name: 'deployBatchPool-${batchPoolObject.poolName}'
  params: {
    batchAccountName: batchAccountName
    batchManagedIdentity: batchManagedIdentity
    batchPoolObject: batchPoolObject
  }
  dependsOn: [
    deployAzureBatchAccount
  ]
}]






