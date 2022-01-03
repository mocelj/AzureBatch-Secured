

// Deploy to Multiple Resource Groups
targetScope = 'subscription'

// Generic

param tags object = {}
param logAnalyticsWorkspaceId string

// Hub

param rgHub string 
param pipFirewallName string
param pipBastionName string
param vNetHubObject object
param fwNetworkRuleCollections array = []
param fwApplicationRuleCollections array = []
param azureFirewallName string 
param bastionName string 
param rgJumpbox string
param vmObjectJumpbox object
param vmObjectJumpboxWindows object
param deployJumpboxWindowsAddOns bool = true
param vmExtensionWindowsJumpboxUri  string

// Spoke01

param rgSpoke01 string
param vNetSpoke01Object object

// Spoke02

param rgSpoke02 string
param vNetSpoke02Object object

// DNS Zones

param privateDnsZoneNames array = []
param ignoreDnsZoneNwLinks bool = false

//---------------------------------------------------

// Deploy the Hub Network 

module deployHubVnet '../../modules/networking/hubNetwork.bicep' = {
  name: 'deployHubVnet'
  scope: resourceGroup(rgHub)
  params: {
    vNetHubObject: vNetHubObject
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    pipBastionName: pipBastionName
    pipFirewallName: pipFirewallName
    fwNetworkRuleCollections: fwNetworkRuleCollections
    fwApplicationRuleCollections: fwApplicationRuleCollections
    azureFirewallName: azureFirewallName
    bastionName: bastionName
    rgHub: rgHub
    rgJumpbox: rgJumpbox
    vmObjectJumpbox: vmObjectJumpbox
    vmObjectJumpboxWindows: vmObjectJumpboxWindows
    deployJumpboxWindowsAddOns: deployJumpboxWindowsAddOns
    vmExtensionWindowsJumpboxUri: vmExtensionWindowsJumpboxUri
    tags: tags
  }
}

output fwPrivateIpAddress string = deployHubVnet.outputs.fwPrivateIpAddress
output fwPublicIpAddress string = deployHubVnet.outputs.fwPublicIpAddress

// Deploy the first Spoke Network

module deploySpoke1Vnet '../../modules/networking/spokeNetwork.bicep' = {
  scope: resourceGroup(rgSpoke01)
  name: 'deploySpoke1Vnet'
  params: {
    fwRouteNextHopIpAddress: deployHubVnet.outputs.fwPrivateIpAddress
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    rgVnet: rgSpoke01
    vNetObject: vNetSpoke01Object
    tags: tags
  }
  dependsOn: [
    deployHubVnet
  ]
}

// Deploy the 2nd Spoke Network

module deploySpoke2Vnet '../../modules/networking/spokeNetwork.bicep' = {
  scope: resourceGroup(rgSpoke02)
  name: 'deploySpoke2Vnet'
  params: {
    fwRouteNextHopIpAddress: deployHubVnet.outputs.fwPrivateIpAddress
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    rgVnet: rgSpoke02
    vNetObject: vNetSpoke02Object
    tags: tags
  }
  dependsOn: [
    deployHubVnet
  ]
}

// Create the network peerings

module peerHubToSpoke01 '../../modules/networking/vNet/vNetPeering.bicep' = {
  name: 'deployHubToSpoke01Peering'
  params: {
    vnetSourceName: deployHubVnet.outputs.vNetName
    peeringName: '${deployHubVnet.outputs.vNetName}-to-${deploySpoke1Vnet.outputs.vNetName}'
    vnetTargetId: deploySpoke1Vnet.outputs.vNetId
  }
  scope: resourceGroup(rgHub)
  dependsOn: [
    deployHubVnet
    deploySpoke1Vnet
  ]
}

module peerSpoke01ToHub '../../modules/networking/vNet/vNetPeering.bicep' = {
  name: 'deploySpoke01ToHubPeering'
  params: {
    vnetSourceName: deploySpoke1Vnet.outputs.vNetName
    peeringName: '${deploySpoke1Vnet.outputs.vNetName}-to-${deployHubVnet.outputs.vNetName}'
    vnetTargetId: deployHubVnet.outputs.vNetId
  }
  scope: resourceGroup(rgSpoke01)
  dependsOn: [
    deployHubVnet
    deploySpoke1Vnet
  ]
}

module peerHubToSpoke02 '../../modules/networking/vNet/vNetPeering.bicep' = {
  name: 'deployHubToSpoke02Peering'
  params: {
    vnetSourceName: deployHubVnet.outputs.vNetName
    peeringName: '${deployHubVnet.outputs.vNetName}-to-${deploySpoke2Vnet.outputs.vNetName}'
    vnetTargetId: deploySpoke2Vnet.outputs.vNetId
  }
  scope: resourceGroup(rgHub)
  dependsOn: [
    deployHubVnet
    deploySpoke2Vnet
  ]
}

module peerSpoke02ToHub '../../modules/networking/vNet/vNetPeering.bicep' = {
  name: 'deploySpoke02ToHubPeering'
  params: {
    vnetSourceName: deploySpoke2Vnet.outputs.vNetName
    peeringName: '${deploySpoke2Vnet.outputs.vNetName}-to-${deployHubVnet.outputs.vNetName}'
    vnetTargetId: deployHubVnet.outputs.vNetId
  }
  scope: resourceGroup(rgSpoke02)
    dependsOn: [
      deployHubVnet
      deploySpoke2Vnet
    ]
}

// Deploy the private DNZ Zones

module privateDnsZones '../../modules/networking/dnsZones/privateDnsZone.bicep' = [for dnsZoneName in privateDnsZoneNames: if (!ignoreDnsZoneNwLinks) {
  scope: resourceGroup(rgHub)
  name: 'deployDNSZone-${dnsZoneName}'
  params: {
    privateDnsZoneName: dnsZoneName
    tags: tags
  }
  dependsOn: [
    peerHubToSpoke01
    peerHubToSpoke02
    peerSpoke01ToHub
    peerSpoke02ToHub
  ]
}]

// Create the virtual Network Links for all VNets in all Zones

var virtualNwLinkNetworks = [
  {
    vNetName: deployHubVnet.outputs.vNetName
    vNetId: deployHubVnet.outputs.vNetId
  }
  {
    vNetName: deploySpoke1Vnet.outputs.vNetName
    vNetId: deploySpoke1Vnet.outputs.vNetId
  }
  {
    vNetName: deploySpoke2Vnet.outputs.vNetName
    vNetId: deploySpoke2Vnet.outputs.vNetId
  }
]

module privateDnsVirtualNwLink '../../modules/networking/dnsZones/privateDnsZoneVirtualNetworkLink.bicep' = [ for privateDnsZoneName in privateDnsZoneNames: if (!ignoreDnsZoneNwLinks) {
  scope: resourceGroup(rgHub)
  name: 'deployDNSZoneNwLink-${privateDnsZoneName}'
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkLinks: virtualNwLinkNetworks
    tags: tags
  }
  dependsOn: [
    privateDnsZones
  ]
}]
