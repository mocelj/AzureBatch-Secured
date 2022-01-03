
// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses?tabs=bicep

param pipName string 
param skuName string = 'Standard'
param publicIPAllocationMethod string = 'Static'
param tags object = {}

resource pipAddress 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: pipName
  location: resourceGroup().location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
  }
}

output pipId string = pipAddress.id
output pipIp string = pipAddress.properties.ipAddress
