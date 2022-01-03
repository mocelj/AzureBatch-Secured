//https://docs.microsoft.com/en-us/azure/templates/microsoft.network/privatednszones/a?tabs=bicep

param privateDnsZoneName string
param serviceObjects array

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
}

resource symbolicname 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [ for serviceObject in serviceObjects: {
  name: serviceObject.name
  parent: privateDnsZone
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: serviceObject.ipAddress
      }
    ]
  }
 } ]
