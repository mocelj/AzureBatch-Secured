
param bastionName string = 'bastionhost'
param publicIpAddressId string
param bastionSubnetId string 
param tags object = {} 


resource bastionHostResource 'Microsoft.Network/bastionHosts@2020-06-01' = {
  name: bastionName
  location: resourceGroup().location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconf'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: publicIpAddressId
          }
        }
      }
    ]
  }
}
