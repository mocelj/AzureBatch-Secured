//https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments?tabs=bicep

param principalId string
param location string = resourceGroup().location

@allowed([
  'Owner'
  'Contributor'
  'Reader'
  'NetworkContributor'
])
@description('Built-in role to assign')
param builtInRoleType string

@description('A new GUID used to identify the role assignment')
// Had to add location and resource group name, to make the guid unique if the same role is granted for several resource groups
// e.g. Network Contributor on rg1, rg2, ... etc.
param roleNameGuid string = guid(principalId, builtInRoleType, subscription().displayName,location,resourceGroup().name)

@allowed([
  'User'
  'ServicePrincipal'
  'ForeignGroup'
  'Group'
])
param principalType string = 'ServicePrincipal'

var role = {
  Owner: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
  NetworkContributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
}

resource roleAssignSub 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleNameGuid
  properties: {
    roleDefinitionId: role[builtInRoleType]
    principalId: principalId
    principalType: principalType
  }
}
