// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks?tabs=bicep

param vNetObject object
param tags object = {}

// Create first the vNet with bare subnets

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' =  {
  name: vNetObject.vnetName
  location: resourceGroup().location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetObject.vNetAddressSpace
      ]
    }
    enableDdosProtection: false
    subnets: [for subnet in vNetObject.subnets: {
      name: subnet.SubnetName
      properties: {
        addressPrefix: subnet.SubnetAddressSpace
        privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
      }
    }]
  }
}

output vNetName string = vnet.name
output vNetId string = vnet.id

