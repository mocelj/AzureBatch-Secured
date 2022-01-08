

param rgHub string 
param tags object = {}
param pipFirewallName string
param pipBastionName string
param vNetHubObject object
param logAnalyticsWorkspaceId string
param fwNetworkRuleCollections array = []
param fwApplicationRuleCollections array = []
param azureFirewallName string
param bastionName string
param location string = resourceGroup().location

// Create the public IPs for Bastion and the Firewall

module pipFirewall '../../modules/networking/publicIp/publicIp.bicep' = {
  scope: resourceGroup(rgHub)
  name: 'dpl-${uniqueString(deployment().name,location)}-pip-fw'
  params: {
    pipName: pipFirewallName
    tags: tags
  }
} 

output fwPublicIpAddress string = pipFirewall.outputs.pipIp

module pipBastion '../../modules/networking/publicIp/publicIp.bicep' = {
  scope: resourceGroup(rgHub)
  name: 'dpl-${uniqueString(deployment().name,location)}-pip-bastion'
  params: {
    pipName: pipBastionName
    tags: tags
  }
}

// Create the Hub Network Structure (incl. Subnets) first, since other resources depend on it

module vNetHub '../../modules/networking/vNet/vNet.bicep' = {
  name: 'dpl-${uniqueString(deployment().name,location)}-vNet-Hub'  
  params: {
    vNetObject: vNetHubObject
    tags: tags
    }
  scope: resourceGroup(rgHub)
  dependsOn: []
  }

output vNetName string = vNetHub.outputs.vNetName
output vNetId string = vNetHub.outputs.vNetId

  
// now that we have setup the basic network structure, add the other components

// Firewall

module firewall '../../modules/networking/firewall/fwSimple.bicep' = {
  scope: resourceGroup(rgHub)
  name: 'dpl-${uniqueString(deployment().name,location)}-fw'
  params: {
    applicationRuleCollection: fwApplicationRuleCollections
    networkRuleCollection: fwNetworkRuleCollections 
    azureFirewallName: azureFirewallName
    azureFirwallSubnetId: '${vNetHub.outputs.vNetId}/subnets/${vNetHubObject.subnets[vNetHubObject.positionFirewall].subnetName}'
    publicIpAddressId: pipFirewall.outputs.pipId
  }
  dependsOn: [
    vNetHub
    pipFirewall
  ]
}

output fwPrivateIpAddress string = firewall.outputs.fwPrivateIpAddress

// Bastion

  module bastionHost '../../modules/networking/bastion/main.bicep' = {
    scope: resourceGroup(rgHub)
    name: 'dpl-${uniqueString(deployment().name,location)}-bastion'
    params: {
      bastionSubnetId: '${vNetHub.outputs.vNetId}/subnets/${vNetHubObject.subnets[vNetHubObject.positionBastion].subnetName}'
      publicIpAddressId: pipBastion.outputs.pipId 
      bastionName: bastionName
      tags: tags
    }
    dependsOn: [
      vNetHub
      pipBastion
    ]
  }


// Create default routes to the FW instance

var fwRoutes = [
  {
    name: 'Default'
    properties: {
      addressPrefix: '0.0.0.0/0'
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: firewall.outputs.fwPrivateIpAddress
    }
  }
]

// Create the Routing Tables
  
module vNetHubRT '../../modules/networking/vNet/routetable.bicep' = [ for subnet in vNetHubObject.subnets: if (subnet.rtToAttach != 'None') {
  name: 'dpl-${uniqueString(deployment().name,location)}-RT-vNet-Hub-${subnet.subnetName}'
  params: {
    rtName: subnet.rtToAttach
    routes: empty(fwRoutes) ? subnet.routes : union(subnet.routes,fwRoutes)
    tags: tags 
  }
  scope: resourceGroup(rgHub)
  dependsOn: [
    vNetHub
  ]
}]

// Create the NSGs

module vNetHubNSG '../../modules/networking/vNet/networksecuritygroup.bicep' = [ for subnet in vNetHubObject.subnets: if (subnet.nsgToAttach != 'None') {
  name: 'dpl-${uniqueString(deployment().name,location)}-NSG-vNet-Hub-${subnet.subnetName}'
  params: {
    nsgName: subnet.nsgToAttach
    secRules: subnet.securityRules
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
scope: resourceGroup(rgHub)
dependsOn: [
  vNetHub
  vNetHubRT
]
}]

// Attach the RT and NSG to the subnet
@batchSize(1)
module vNetHubNsgRtAttach '../../modules/networking/vNet/subnet-attach-nsg-rt.bicep' = [ for subnet in vNetHubObject.subnets: {
  name: 'dpl-${uniqueString(deployment().name,location)}-Attach-vNet-Hub-${subnet.subnetName}'
  params: {
    vnetName: subnet.vNetName
    subnetName: subnet.subnetName
    subnetAddressPrefix: subnet.SubnetAddressSpace
    rtToAttach: subnet.rtToAttach
    nsgToAttach: subnet.nsgToAttach
    privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
    privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
    serviceEndpoints: subnet.serviceEndpoints
  }
  scope: resourceGroup(rgHub)
  dependsOn: [
    vNetHub
    vNetHubNSG
    vNetHubRT
  ]
}]

