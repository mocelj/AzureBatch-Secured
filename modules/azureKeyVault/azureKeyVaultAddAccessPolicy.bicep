
// https://docs.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/accesspolicies?tabs=bicep

param kvName string

@allowed([
  'add'
  'remove'
  'replace'
])

param accessPolicyAction string
param accessPolicy array

resource kvAddAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-06-01-preview' = {
  name: '${kvName}/${accessPolicyAction}'
  properties: {
    accessPolicies: accessPolicy
  }
}
