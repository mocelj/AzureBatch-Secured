
param location string = resourceGroup().location
param scriptToExecute string = 'date' // will print current date & time on container
param subId string = subscription().id // defaults to current sub
param rgName string = resourceGroup().name // defaults to current rg
param uamiName string = 'id-dev-secb2-azbatch'

param currentTime string = utcNow()
param acrName string = 'acrdevsecb2azbatch'
param imageName string = 'testkvsecretsmi'

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: uamiName
}

//var uamiId = resourceId(subId, rgName, 'Microsoft.ManagedIdentity/userAssignedIdentities', uamiName)

resource stg 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: 'dscript${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource dScript 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'scriptWithStorage'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.30.0'
    storageAccountSettings: {
      storageAccountName: stg.name
      storageAccountKey: stg.listKeys().keys[0].value
    }
    //scriptContent: scriptToExecute
    arguments: ' ${acrName} ${imageName}'
    primaryScriptUri: 'https://raw.githubusercontent.com/mocelj/AzureBatch-Secured/main/artefacts/checkAkv/buildRemoteContainer.sh'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: currentTime // ensures script will run every time
  }
}

// print logs from script after template is finished deploying
output scriptLogs string = reference('${dScript.id}/logs/default', dScript.apiVersion, 'Full').properties.log

