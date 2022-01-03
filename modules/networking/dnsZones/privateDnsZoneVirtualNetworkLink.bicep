


param privateDnsZoneName string
param virtualNetworkLinks array
param tags object = {}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
}

resource privateDnsVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [ for virtualNetworkLink in virtualNetworkLinks: {
  name: virtualNetworkLink.vNetName
  location: 'global'
  tags: tags
  parent: privateDnsZone
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkLink.vNetId
    }
  }
} ]
