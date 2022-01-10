


// This Template will orchestrate a Azure Batch in private mode deployment

param rgAzureBatch string
param prefix string
param environment string
param rgHub string
param rgSpoke string
param tags object = {}
param vNetObject object

// Storage Accounts

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

param appInsightsInstrumentKey string
param appInsightsAppId string

param location string = resourceGroup().location

//------------------------------------------------------------------------
//  This Demo will deploy an Azure Batch account with 3 pools in a secured
//  environment.
//  - Grant the Batch API Service contributor permissions to the subscription (see)
//    https://docs.microsoft.com/en-us/azure/batch/batch-account-create-portal#additional-configuration-for-user-subscription-mode
//  - Managed Identity (will be assigned to the pool)
//  - AKV 
//  - Storage account(s)
//  - ACR
//  - Grant the Batch API Service permissions to the pre-provisioned Key Vaults
//  - Grant the managed Identity ACR Push and Storage Account permissions (to avoid configuration of sa keys)
//  - Batch Account
//  - Pools
//------------------------------------------------------------------------


// Generic References used in the deployment script
//------------------------------------------------------------------------

module deployBatchRoleAssignment '../../../modules/azRoles/roleAssignmentSubscription.bicep' = if (assignBatchServiceRoles) {
  name: 'dpl-${uniqueString(deployment().name,location)}-batchRoleAssignment'
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

var privateEndpointSubnetId      = '${refVNetSpoke.id}/subnets/${vNetObject.subnets[vNetObject.positionEndpointSubnet].subnetName}'
var batchPoolSubnetId_Linux      = '${refVNetSpoke.id}/subnets/${vNetObject.subnets[vNetObject.positionLinuxSubnet].subnetName}'
var batchPoolSubnetId_LinuxNoSsh = '${refVNetSpoke.id}/subnets/${vNetObject.subnets[vNetObject.positionLinuxNoSshSubnet].subnetName}'
var batchPoolSubnetId_Windows    = '${refVNetSpoke.id}/subnets/${vNetObject.subnets[vNetObject.positionWindowsSubnet].subnetName}'


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

module deployAzBatchKV '../../../modules/azureKeyVault/azureKeyVault.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-batchKeyVault'
  params: {
    keyVaultName: kvName
    privateEndpointSubnetId: privateEndpointSubnetId
    deployPrivateKeyVault: deployPrivateAKV
    enablePurgeProtection: true
    enableSoftDelete: true
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
  name: 'dpl-${uniqueString(deployment().name,location)}-batchKV-Policy-MI-add'
  params: {
    accessPolicy: array(kvAccessPolicyMI)
    accessPolicyAction: 'add'
    kvName: kvName
  }
  dependsOn: [
    deployAzBatchKV
  ]
}

// Create required storage accounts
//------------------------------------------------------------------------

module deployBatchDemoStorageAccounts '../../../modules/Demos/Demo-Batch-Secured/demoAzureBatch-Secured-Storage.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-batchStorageAccounts'
  params: {
    rgHub: rgHub
    kvName: kvName
    privateEndpointSubnetId: privateEndpointSubnetId
    saDefinitions: saDefinitions 
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


module assignStorageAccountRole '../../../modules/storage/roleAssignmentStorage.bicep' = [ for (saDefinition,index) in saDefinitions: {
  name: 'dpl-${uniqueString(deployment().name,location)}-batchStorageRoleAssignment-${index}'
  params: {
    builtInRoleType: 'StorageBlobDataContributor'
    principalId: azBatchManagedIdentity.properties.principalId
    saName: saDefinition.storageAccountName
  }
  dependsOn: [
    deployBatchDemoStorageAccounts
  ]
}]

// Create the Azure Container Registry
//------------------------------------------------------------------------

// Create a 'build' ACR to build the containers, outside of the locked down vNet
// Import the built containers to the batch ACR through Azure Trusted Servcies enabled
// delete the temp 'build' ACR in the external build script

var acrBuildName = 'tempacrbuild'
module deployBatchDemoBuildACR '../../../modules/containerRegistry/acr.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-batchBuildAcr'
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
    principalType: 'ServicePrincipal'
  }
]

module deployBatchDemoACR '../../../modules/containerRegistry/acr.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-batchAcr'
  params: {
    name: acrName
    acrAdminUserEnabled: acrAdminUserEnabled
    privateEndpoints: acrPrivateEndpoints
    acrSku: acrSku
    publicNetworkAccess: acrPublicNetworkAccess
    tags: tags
    roleAssignments: acrRoleAssignments
  }
  dependsOn: [
    deployBatchDemoBuildACR
  ]
}

// Deploy a test image to the ACR
//------------------------------------------------------------------------

var acrImageName = 'kvsecretsmi'

// assign contributor permissons on RG level to be able to create the temp ACI / ACR for script deployment

module assignRGContributorRoleMI '../../../modules/azRoles/roleAssignmentResourceGroup.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-RG-Contrib-MI'
  params: {
    builtInRoleType: 'Contributor'
    principalId: azBatchManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

module deployCheckKVImage '../../../modules/deploymentScripts/deploymentScript-MI-ACR.bicep'  = {
  name: 'dpl-${uniqueString(deployment().name,location)}-Check-KV-Image'
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

// Create the Azure Batch account
//------------------------------------------------------------------------

module deployAzureBatchAccount '../../../modules/azBatch/azBatchAccount-MI.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-batchAccount'
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

    startTask: {
      commandLine: '/bin/bash -c \'wget  -O - https://raw.githubusercontent.com/Azure/batch-insights/master/scripts/run-linux.sh | bash\''
      environmentSettings: [
          {
              name: 'APP_INSIGHTS_INSTRUMENTATION_KEY'
              value: appInsightsInstrumentKey
          }
          {
              name: 'APP_INSIGHTS_APP_ID'
              value: appInsightsAppId
          }
          {
              name: 'BATCH_INSIGHTS_DOWNLOAD_URL'
              value: 'https://github.com/Azure/batch-insights/releases/download/v1.3.0/batch-insights'
          }
      ]
      maxTaskRetryCount: 1
      userIdentity: {
          autoUser: {
              elevationLevel: 'Admin'
              scope: 'Pool'
          }
      }
       waitForSuccess: true
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
    
    
      //fixedScale: {
      //  targetDedicatedNodes: 0
      //  targetLowPriorityNodes: 0
      //  resizeTimeout: 'PT15M'
      //}
    
      autoScale: {
        evaluationInterval: 'PT5M'
        formula: '''
        startingNumberOfVMs = 0;
        maxNumberofVMs = 2;
        pendingTaskSamplePercent = $PendingTasks.GetSamplePercent(180 * TimeInterval_Second);
        pendingTaskSamples = pendingTaskSamplePercent < 70 ? startingNumberOfVMs : avg($PendingTasks.GetSample(180 *   TimeInterval_Second));
        $TargetDedicatedNodes=min(maxNumberofVMs, pendingTaskSamples);
        $NodeDeallocationOption=taskcompletion 
        '''
      }
      
    }

    startTask: {
      commandLine: '/bin/bash -c \'wget  -O - https://raw.githubusercontent.com/Azure/batch-insights/master/scripts/run-linux.sh | bash\''
      environmentSettings: [
        {
          name: 'APP_INSIGHTS_INSTRUMENTATION_KEY'
          value: appInsightsInstrumentKey
        }
        {
          name: 'APP_INSIGHTS_APP_ID'
          value: appInsightsAppId
        }
        {
          name: 'BATCH_INSIGHTS_DOWNLOAD_URL'
          value: 'https://github.com/Azure/batch-insights/releases/download/v1.3.0/batch-insights'
        }
      ]
      maxTaskRetryCount: 1
      userIdentity: {
        autoUser: {
          elevationLevel: 'Admin'
          scope: 'Pool'
        }
      }
      waitForSuccess: true
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
          sku: 'datacenter-core-20h2-with-containers-smalldisk-gs'
          version: 'latest'
        }
      
        nodeAgentSkuId: 'batch.node.windows amd64'

        windowsConfiguration: {
          enableAutomaticUpdates: true
        }

        containerConfiguration: {
          type: 'DockerCompatible'
          containerImageNames: []
        
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
  
    startTask: {
      commandLine: 'cmd /c @"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString(\'https://raw.githubusercontent.com/Azure/batch-insights/master/scripts/run-windows.ps1\'))"'
      environmentSettings: [
        {
          name: 'APP_INSIGHTS_INSTRUMENTATION_KEY'
          value: appInsightsInstrumentKey
        }
        {
          name: 'APP_INSIGHTS_APP_ID'
          value: appInsightsAppId
        }
        {
          name: 'BATCH_INSIGHTS_DOWNLOAD_URL'
          value: 'https://github.com/Azure/batch-insights/releases/download/v1.3.0/batch-insights.exe'
        }
      ]
      maxTaskRetryCount: 1
      userIdentity: {
        autoUser: {
          elevationLevel: 'Admin'
          scope: 'Pool'
        }
      }
      waitForSuccess: true
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
  name: 'dpl-${uniqueString(deployment().name,location)}-batchPool-${batchPoolObject.poolName}'
  params: {
    batchAccountName: batchAccountName
    batchManagedIdentity: batchManagedIdentity
    batchPoolObject: batchPoolObject
  }
  dependsOn: [
    deployAzureBatchAccount
  ]
}]






