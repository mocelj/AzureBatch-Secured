
// https://docs.microsoft.com/en-us/azure/templates/microsoft.batch/batchaccounts/pools?tabs=bicep

param batchAccountName string
param batchManagedIdentity string
param acrName string
param acrImageName string

param batchNodeSku string
param appInsightsInstrumentKey string 
param appInsightsAppId string
param batchPoolSubnetId_Linux string
param batchPoolSubnetId_LinuxNoSsh string
param batchPoolSubnetId_Windows string

param saNameStorageSMB string
param saNameStorageNFS string


param location string = resourceGroup().location


// Get the information to build the bigger batchPool Object configuration

resource refSMBStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: saNameStorageSMB
}

resource azBatchManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'  existing = {
  name: batchManagedIdentity
}

var preloadContainerImage = '${acrName}.azurecr.io/${acrImageName}:latest'
var containerRegistryServer = '${acrName}.azurecr.io'

var smbShareAccountKey = listKeys(refSMBStorageAccount.id, refSMBStorageAccount.apiVersion).keys[0].value
var smbShareName = 'share'
var smbShareURL = 'https://${saNameStorageSMB}.file.${az.environment().suffixes.storage}/${smbShareName}'

var nfsShareName = 'container'
var nfsShareSource = '${saNameStorageNFS}.blob.${az.environment().suffixes.storage}:/${saNameStorageNFS}/${nfsShareName}'
var nfsMountOptions = '-o sec=sys,vers=3,nolock,proto=tcp'

// Build the batchPoolObject

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
   
    mountConfiguration: [
      {
        nfsMountConfiguration: {
          source: nfsShareSource
          relativeMountPath: 'shared'
          mountOptions: nfsMountOptions
        }
      }
    ]

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

    mountConfiguration: [
      {
        nfsMountConfiguration: {
          source: nfsShareSource
          relativeMountPath: 'shared'
          mountOptions: nfsMountOptions
        }
      }
    ]

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
          sku: '2022-datacenter-smalldisk'
          version: 'latest'
        }
      
        nodeAgentSkuId: 'batch.node.windows amd64'

        windowsConfiguration: {
          enableAutomaticUpdates: true
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
  
    mountConfiguration: [
      {
        azureFileShareConfiguration: {
        accountKey: smbShareAccountKey
        accountName: saNameStorageSMB
        azureFileUrl: smbShareURL
        relativeMountPath: 'S'
        }
      }
    ]

    startTask: {
      commandLine: 'cmd /c @"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString(\'https://raw.githubusercontent.com/Azure/batch-insights/master/scripts/run-windows.ps1\'))" & python-3.10.1-amd64.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0'
      resourceFiles: [
        {
          httpUrl: 'https://raw.githubusercontent.com/mocelj/AzureBatch-Secured/main/artefacts/Python/python-3.10.1-amd64.exe'
          filePath: 'python-3.10.1-amd64.exe'
        }
      ]
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



//--------------------------------------------

// Need to encapsulate this in a module, since the batchPoolObject loop can't resolve the link to the storage account key 
// (needed for smb shares) at runtime

module createBatchPools './azBatchPool-Simple.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-batchPoolCollection'
  params: {
    batchAccountName: batchAccountName
    batchPoolObjects: batchPoolObjects
    batchManagedIdentityId: azBatchManagedIdentity.id
  }
}
