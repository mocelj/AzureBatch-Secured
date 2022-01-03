// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks/subnets?tabs=bicep

param vnetName string
param subnetName string
param subnetAddressPrefix string
param nsgToAttach string = 'None'
param rtToAttach string = 'None'
param privateEndpointNetworkPolicies string = 'Enabled' 
param privateLinkServiceNetworkPolicies string
param serviceEndpoints array

resource nsgAttachment 'Microsoft.Network/virtualNetworks/subnets@2021-03-01'  =  {
  name: '${vnetName}/${subnetName}'
  properties: {
    addressPrefix: subnetAddressPrefix
    privateEndpointNetworkPolicies: privateEndpointNetworkPolicies
    privateLinkServiceNetworkPolicies: privateLinkServiceNetworkPolicies
    serviceEndpoints: serviceEndpoints
    networkSecurityGroup: contains(nsgToAttach,'None') ? null : {
      id: resourceId('Microsoft.Networking/networkSecurityGroups', nsgToAttach)
    }
    routeTable: contains(rtToAttach,'None') ? null : {
      id: resourceId('Microsoft.Networking/routeTables', rtToAttach)
    }
  }
}

