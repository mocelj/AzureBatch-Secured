// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/privatednszones?tabs=bicep


param privateDnsZoneName string = ''
param tags object = {}

// Create the Global DNS Zone

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' =  {
  name: privateDnsZoneName
  tags: tags
  location: 'global'
}



