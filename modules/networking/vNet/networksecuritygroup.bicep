// ------------------------------------------------------------
// networkSecurityGroups -
//  The securityRules object is an array of rules
//   [
//     {
//       name: 'default-allow-rdp'
//       properties: {
//         priority: 1010
//         access: 'Allow'
//         direction: 'Inbound'
//         protocol: 'Tcp'
//         sourcePortRange: '*'
//         sourceAddressPrefix: 'VirtualNetwork'
//         destinationAddressPrefix: '*'
//         destinationPortRange: '3389'
//       }
//     }
//   ]
// See
//  https://docs.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups/securityrules?tabs=json#securityrulepropertiesformat-object
// for more information
// ------------------------------------------------------------
param nsgName string
param secRules array
param tags object = {}
param logAnalyticsWorkspaceId string = ''

resource nsg  'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: nsgName
  location: resourceGroup().location
  properties: {
    securityRules: secRules
  }
  tags: tags
}

output id string = nsg.id

// Enable Diagnostics on the NSG if LogAnalytics Id is provided

resource diahVnetHub 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = if (!empty( logAnalyticsWorkspaceId )) {
  name: 'diagNSG'
  scope: nsg
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}
