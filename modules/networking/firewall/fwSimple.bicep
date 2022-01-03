
param azureFirewallName string
param publicIpAddressId string
param azureFirwallSubnetId string 
param tags object = {} 
param logAnalyticsWorkspaceId string = ''
param networkRuleCollection array = []
param applicationRuleCollection array = []

param fwSkuName string = 'AZFW_VNet'
param fwSkuTier string = 'Standard'
param threatIntelMode string = 'Alert'

resource firewall 'Microsoft.Network/azureFirewalls@2021-03-01' = {
  name: azureFirewallName
  location: resourceGroup().location
  tags: tags
  properties: {
    sku: {
      name: fwSkuName
      tier: fwSkuTier
    }
    threatIntelMode: threatIntelMode
    ipConfigurations: [
      {
        name: azureFirewallName
        properties: {
          publicIPAddress: {
            id: publicIpAddressId
          }
          subnet: {
            id:  azureFirwallSubnetId
          }
        }
      }
    ]
    networkRuleCollections: networkRuleCollection
    applicationRuleCollections: applicationRuleCollection
  }
}

output fwPrivateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress

resource diagFirewall 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = if (!empty( logAnalyticsWorkspaceId )) {
  name: 'diagFirewall'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
    ]
  }
}
