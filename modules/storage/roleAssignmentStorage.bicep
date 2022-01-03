// https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments?tabs=bicep

param saName string
param principalId string


@allowed([
  'Owner'
  'Contributor'
  'Reader'
  'StorageBlobDataOwner'
  'StorageBlobDataReader'
  'StorageBlobDataContributor'
])
@description('Built-in role to assign')
param builtInRoleType string

var role = {
  Owner: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
  StorageBlobDataOwner: '/subscriptions/{subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  StorageBlobDataReader: '/subscriptions/{subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  StorageBlobDataContributor: '/subscriptions/{subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

// Keep the GUID fixed, to make the template idempotent
// https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-template
@description('A new GUID used to identify the role assignment')
param roleNameGuid string = guid(saName, builtInRoleType, resourceGroup().name)


resource st 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: saName
}

resource  assignStorageRoles 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleNameGuid
  scope: st
  properties: {
    description: 'Assign storage Role'
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: role[builtInRoleType]
  }
}
