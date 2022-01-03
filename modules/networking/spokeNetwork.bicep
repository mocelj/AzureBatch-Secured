

 param rgVnet string 
 param tags object = {}


 param vNetObject object
 param logAnalyticsWorkspaceId string


param fwRouteNextHopIpAddress string


// Create the Hub Network Structure (incl. Subnets) first, since other resources depend on it

module vNet '../../modules/networking/vNet/vNet.bicep' = {
    name: 'deployvNet'
    params: {
      vNetObject: vNetObject
      tags: tags
      }
    scope: resourceGroup(rgVnet)
    dependsOn: []
  }

  output vNetName string = vNet.outputs.vNetName
  output vNetId string = vNet.outputs.vNetId

// Create default routes to the FW instance

var fwRoutes = [
  {
    name: 'Default'
    properties: {
      addressPrefix: '0.0.0.0/0'
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: fwRouteNextHopIpAddress
    }
  }
]

// Create the Routing Tables
  
module vNetRT '../../modules/networking/vNet/routetable.bicep' = [ for subnet in vNetObject.subnets: if (subnet.rtToAttach != 'None') {
  name: 'deployvNetRT-${subnet.subnetName}'
  params: {
    rtName: subnet.rtToAttach
    routes: empty(fwRoutes) ? subnet.routes : union(subnet.routes,fwRoutes)
    tags: tags 
  }
  scope: resourceGroup(rgVnet)
  dependsOn: [
    vNet
  ]
}]

// Create the NSGs

module vNetNSG '../../modules/networking/vNet/networksecuritygroup.bicep' = [ for subnet in vNetObject.subnets: if (subnet.nsgToAttach != 'None') {
  name: 'deployvNetNSG-${subnet.subnetName}'
  params: {
    nsgName: subnet.nsgToAttach
    secRules: subnet.securityRules
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
scope: resourceGroup(rgVnet)
dependsOn: [
  vNet
  vNetRT
]
}]

// Attach the RT and NSG to the subnet
@batchSize(1)
module vNetNsgRtAttach '../../modules/networking/vNet/subnet-attach-nsg-rt.bicep' = [ for subnet in vNetObject.subnets: {
  name: 'deployvNetNsgRtAttach-${subnet.subnetName}'
  params: {
    vnetName: subnet.vNetName
    subnetName: subnet.subnetName
    subnetAddressPrefix: subnet.SubnetAddressSpace
    privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
    rtToAttach: subnet.rtToAttach
    nsgToAttach: subnet.nsgToAttach
    privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
    serviceEndpoints: subnet.serviceEndpoints
  }
  scope: resourceGroup(rgVnet)
  dependsOn: [
    vNet
    vNetNSG
    vNetRT
  ]
}]

