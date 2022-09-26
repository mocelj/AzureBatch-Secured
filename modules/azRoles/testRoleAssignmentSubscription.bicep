/**
  Subscription roles cannot be assigned in duplicate. This script tests for
  the presence of the role assignment so we can avoid assigning duplicates.
*/

@description('the principal id to check for the role assignment')
param principalId string

@description('built-in role definition id')
param roleDefinitionName string

@description('location where the deployment script will be executed')
param location string = resourceGroup().location

param currentTime string = utcNow()

var query = '[?principalId==\'${principalId}\' && roleDefinitionName==\'${roleDefinitionName}\'].{name:name}'
var scriptContent = 'az login -i > /dev/null 2>&1 && az role assignment list --scope ${subscription().id} -o json --query "${query}"'

// create an MI to execute the script deployment script
resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: uniqueString(principalId, subscription().id, roleDefinitionName)
  location: location
}

module mdlRoleAssignment 'roleAssignmentSubscription.bicep' = {
  scope: subscription()
  name: 'dpl-${uniqueString(deployment().name, location)}-miRoleAssignment'
  params: {
    builtInRoleType: 'Reader'
    principalId: mi.properties.principalId
  }
}

resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'testRoleAssignment'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi.id}': {}
    }
  }

  properties: {
    azCliVersion: '2.39.0'
    retentionInterval: 'P1D'
    scriptContent: '${scriptContent} 2>&1 | jq -c \'{"count": . | length }\' | tee $AZ_SCRIPTS_OUTPUT_PATH'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: currentTime // ensures script will run every time
  }
}

output result bool  = (script.properties.outputs.count > 0) ? true : false
