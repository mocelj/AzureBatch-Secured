
param vnetSourceName string
param peeringName string
param vnetTargetId string

resource peerVnet1toVnet2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-06-01' = {
  name: '${vnetSourceName}/${peeringName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnetTargetId
    }
  }
}
