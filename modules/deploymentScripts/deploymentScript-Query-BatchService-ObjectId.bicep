

param location string = resourceGroup().location
param managedIdentityName string
param tags object = {}

param azureCliVersion string = '2.30.0'
param currentTime string = utcNow()


resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'deployTestContainerToACR'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi.id}': {}
    }
  }
  properties: {
    azCliVersion: azureCliVersion
    //arguments: ''
    scriptContent: 'az ad sp show --id "MicrosoftAzureBatch" --query objectId -o tsv'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: currentTime // ensures script will run every time
  }
}

// print logs from script after template is finished deploying
output scriptLogs string = reference('${deploymentScript.id}/logs/default', deploymentScript.apiVersion, 'Full').properties.log
