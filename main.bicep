/*
Purpose : Main Deployment File
Author  : Darko Mocelj
Date    : 25.11.2021
Update  : 27.01.2022
Comments: 
-- 12.01.2022: Initial Release
-- 27.01.2022: Added Demo 3: Depoly own DNS Server and Update FW as DNS Proxy for VNets
*/


// Set the target Scope

targetScope = 'subscription'

// Global Parameters
//-------------------------------------------------------
@description('Resource Group deployment region')
// https://docs.microsoft.com/en-us/azure/batch/batch-pool-no-public-ip-address
// as of Jan, 13th, 2022
@allowed( [
  'eastus'
  'eastus2'
  'southcentralus'
  'westus2'
  // 'westus3'
  'australiaeast'
  // 'southeastasia'
  'northeurope'
  // 'swedencentral'
  // 'uksouth'
  'westeurope'
  'centralus'
  'northcentralus'
  'westus'
  // 'southafricanorth'
  // 'centralindia'
  'eastasia'
  'japaneast'
  // 'jioindiawest'
  // 'koreacentral'
  // 'canadacentral'
   'francecentral'
  // 'germanywestcentral'
  // 'norwayeast'
  // 'switzerlandnorth'
  // 'uaenorth'
  // 'brazilsouth'
  // 'centralusstage'
  // 'eastusstage'
  // 'eastus2stage'
  // 'northcentralusstage'
  // 'southcentralusstage'
  // 'westusstage'
  // 'westus2stage'
  // 'asia'
  // 'asiapacific'
  // 'australia'
  // 'brazil'
  // 'canada'
  // 'europe'
  // 'france'
  // 'germany'
  // 'global'
  // 'india'
  // 'japan'
  // 'korea'
  // 'norway'
  // 'southafrica'
  // 'switzerland'
  // 'uae'
  // 'uk'
  // 'unitedstates'
  // 'eastasiastage'
  // 'southeastasiastage'
  // 'centraluseuap'
  // 'eastus2euap'
   'westcentralus'
  // 'southafricawest'
  // 'australiacentral'
  // 'australiacentral2'
  // 'australiasoutheast'
  'japanwest'
  // 'jioindiacentral'
  // 'koreasouth'
  // 'southindia'
  // 'westindia'
  // 'canadaeast'
  // 'francesouth'
  // 'germanynorth'
  // 'norwaywest'
  // 'switzerlandwest'
  // 'ukwest'
  // 'uaecentral'
  // 'brazilsoutheast'
])
param resourceGroupLocation string = 'westeurope'

@maxLength(3)
param environment string = 'dev'

@maxLength(13)
param prefix string = uniqueString(environment,subscription().id,resourceGroupLocation)

@description('Indicate if Hub-Spoke Network should be deployed.')
param deployHubSpoke bool = true

@description('Indicate if a Linux and Windows Jumpbox should be deployed.')
param deployJumpBoxVMs bool = true

param deployJumpboxWindowsAddOns bool = true
param vmExtensionWindowsJumpboxUri  string = 'https://raw.githubusercontent.com/mocelj/AzureBatch-Secured/main/artefacts/VM-Extensions-Windows/azure-batch-secured-jumpbox-setup.ps1'

param ignoreDnsZoneNwLinks bool = false

@description('Indicate if a VPN Gateway should be deployed. Note: deployment may take up to 45 min addtional time. Certificate has to be added after creation.')
param deployVPNGw bool = false

@description('Indicate if Azure Batch Demo should be deployed.')
param deploySecureBatch bool = true

param utcShort string = utcNow('d')

param resourceTags object = {
  WorkloadName : 'Back Office Risk'
  BusinessUnit : 'Risk Managment'
  Owner: 'Darko Mocelj'
  Environment: environment
  CostCenter: 'Internal'
  LastDeployed: utcShort
}

param adminUserName string = 'localadmin'

@secure()
param adminPassword string 

@allowed([
  'Standard_B1s'
  'Standard_B2ms'
])
param jumpboxLinuxVmSize string = 'Standard_B1s'

@allowed([
  'Standard_B2ms'
  'Standard_B4ms'
  'Standard_D4_v5'
])
param jumpboxWindowsVmSize string = 'Standard_D4_v5'

@description('Get the Batch Service Object Id: az ad sp show --id "MicrosoftAzureBatch" --query objectId -o tsv')
param batchServiceObjectId string 

@allowed([ 
  'Standard_D2s_V3'
  'Standard_D2s_V4'
  'Standard_D2s_V5'
  'Standard_F2s_v2'
  'Standard_F4s_v2'
  'Standard_F8s_v2'
]) 
param batchNodeSku  string = 'Standard_D2s_V3'

// Hub Spoke Parameters
//-------------------------------------------------------

var pipFirewallName  = 'pip-${environment}-${prefix}-fw-vnet-hub-01'
var pipBastionName   = 'pip-${environment}-${prefix}-bas-vnet-hub-01'

var vNetHubObject  = {
  vNetName: 'vnet-${environment}-${prefix}-hub-01'
  vNetRG:   'rg-${environment}-${prefix}-vnet-hub-01'
  NetworkType: 'Hub'
  vNetAddressSpace: '10.1.0.0/16'
  positionGateway: 0
  positionFirewall: 1
  positionBastion: 2
  positionJumpBox: 3
  positionDNS: 4
  subnets: [
    {
      vNetName: 'vnet-${environment}-${prefix}-hub-01'
      subnetName: 'GatewaySubnet'
      SubnetAddressSpace: '10.1.1.0/24'
      serviceEndpoints: []
      nsgToAttach: 'None'
      securityRules: []
      rtToAttach: 'None'
      routes: []
      privateEndpointNetworkPolicies: 'Enabled'
      PrivateLinkServiceNetworkPolicies: 'Enabled'
    }
    {
      vNetName: 'vnet-${environment}-${prefix}-hub-01'
      subnetName: 'AzureFirewallSubnet'
      SubnetAddressSpace: '10.1.2.0/24'
      serviceEndpoints: []
      nsgToAttach: 'None'
      securityRules: []
      rtToAttach: 'None'
      routes: []
      privateEndpointNetworkPolicies: 'Enabled'
      PrivateLinkServiceNetworkPolicies: 'Enabled'
    }
    {
      vNetName: 'vnet-${environment}-${prefix}-hub-01'
      subnetName: 'AzureBastionSubnet'
      SubnetAddressSpace: '10.1.3.0/24'
      serviceEndpoints: []
      nsgToAttach: 'vnet-${environment}-${prefix}-hub-01-AzureBastionSubnet-nsg'
      securityRules: [
        {
          name: 'bastion-in-allow'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            sourceAddressPrefix: 'Internet'
            destinationPortRange: '443'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 100
            direction: 'Inbound'
          }
        }
        {
          name: 'bastion-control-in-allow'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            sourceAddressPrefix: 'GatewayManager'
            destinationPortRange: '443'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 120
            direction: 'Inbound'
          }
        }
        {
          name: 'bastion-in-host'
          properties: {
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRanges: [
              '8080'
              '5701'
            ]
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 130
            direction: 'Inbound'
          }
        }
        {
          name: 'bastion-vnet-out-allow'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            sourceAddressPrefix: '*'
            destinationPortRanges: [
              '22'
              '3389'
            ]
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 100
            direction: 'Outbound'
          }
        }
        {
          name: 'bastion-azure-out-allow'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            sourceAddressPrefix: '*'
            destinationPortRange: '443'
            destinationAddressPrefix: 'AzureCloud'
            access: 'Allow'
            priority: 120
            direction: 'Outbound'
          }
        }
        {
          name: 'bastion-out-host'
          properties: {
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRanges: [
              '8080'
              '5701'
            ]
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 130
            direction: 'Outbound'
          }
        }
        {
          name: 'bastion-out-deny'
          properties: {
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Deny'
            priority: 1000
            direction: 'Outbound'
          }
        }
      ]
      rtToAttach: 'None'
      routes: []
      privateEndpointNetworkPolicies: 'Enabled'
      PrivateLinkServiceNetworkPolicies: 'Enabled'
    }
    {
      vNetName: 'vnet-${environment}-${prefix}-hub-01'
      subnetName: 'snet-Jumpbox'
      SubnetAddressSpace: '10.1.4.0/24'
      serviceEndpoints: []
      nsgToAttach: 'vnet-${environment}-${prefix}-hub-01-snetJumpbox-nsg'
      securityRules: [
        {
          name: 'bastion-in-vnet'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            sourceAddressPrefix:  '10.1.3.0/24'
            destinationPortRanges: [
              '22'
              '3389'
            ]
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 100
            direction: 'Inbound'
          }
        }
        {
          name: 'DenyAllInBound'
          properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            sourceAddressPrefix: '*'
            destinationPortRange: '443'
            destinationAddressPrefix: '*'
            access: 'Deny'
            priority: 1000
            direction: 'Inbound'
          }
        }
      ]
      rtToAttach: 'vnet-${environment}-${prefix}-hub-01-snetJumpbox-rt'
      routes: []
      privateEndpointNetworkPolicies: 'Enabled'
      PrivateLinkServiceNetworkPolicies: 'Enabled'
    }
    {
      vNetName: 'vnet-${environment}-${prefix}-hub-01'
      subnetName: 'snet-dns'
      SubnetAddressSpace: '10.1.5.0/24'
      serviceEndpoints: []
      nsgToAttach: 'vnet-${environment}-${prefix}-hub-01-dns-nsg'
      securityRules: []
      rtToAttach: 'None'
      routes: []
      privateEndpointNetworkPolicies: 'Enabled'
      PrivateLinkServiceNetworkPolicies: 'Enabled'
    } 
  ]
}

var vNetSpoke01Param = {
  vNetName: 'vnet-${environment}-${prefix}-spoke-01'
  vNetRG:   'rg-${environment}-${prefix}-vnet-spoke-01'
  NetworkType: 'Spoke'
  vNetAddressSpace: '10.2.0.0/16'
  positionEndpointSubnet: 3
  positionLinuxSubnet: 0
  positionWindowsSubnet: 1
  positionLinuxNoSshSubnet: 2
  subnets: [
      {
        vNetName: 'vnet-${environment}-${prefix}-spoke-01'
        subnetName: 'snet-grid-linux'
        SubnetAddressSpace: '10.2.1.0/24'
        serviceEndpoints: []
        nsgToAttach: 'vnet-${environment}-${prefix}-spoke-01-snet-grid-linux-nsg'
        securityRules: [
          {
            name: 'BatchServiceRule'
            properties: {
                protocol: 'tcp'
                sourcePortRange: '*'
                destinationPortRange: '29876-29877'
                sourceAddressPrefix: 'BatchNodeManagement.${resourceGroupLocation}'
                destinationAddressPrefix: '*'
                access: 'Allow'
                priority: 120
                direction: 'Inbound'
                sourcePortRanges: []
                destinationPortRanges: []
                sourceAddressPrefixes: []
                destinationAddressPrefixes: []
            }
          }
        ]
        rtToAttach: 'vnet-${environment}-${prefix}-spoke-01-snet-grid-linux-rt'
        routes: []
        privateEndpointNetworkPolicies: 'Disabled'
        PrivateLinkServiceNetworkPolicies: 'Disabled'
      }
      {
        vNetName: 'vnet-${environment}-${prefix}-spoke-01'
        subnetName: 'snet-grid-win'
        SubnetAddressSpace: '10.2.2.0/24'
        serviceEndpoints: []
        nsgToAttach: 'vnet-${environment}-${prefix}-spoke-01-snet-grid-win-nsg'
        securityRules: [
          {
            name: 'BatchServiceRule'
            properties: {
                protocol: 'tcp'
                sourcePortRange: '*'
                destinationPortRange: '29876-29877'
                sourceAddressPrefix: 'BatchNodeManagement.${resourceGroupLocation}'
                destinationAddressPrefix: '*'
                access: 'Allow'
                priority: 120
                direction: 'Inbound'
                sourcePortRanges: []
                destinationPortRanges: []
                sourceAddressPrefixes: []
                destinationAddressPrefixes: []
            }
          }
        ]
        rtToAttach: 'vnet-${environment}-${prefix}-spoke-01-snet-grid-win-rt'
        routes: []
        privateEndpointNetworkPolicies: 'Disabled'
        PrivateLinkServiceNetworkPolicies: 'Disabled'
      }
      {
        vNetName: 'vnet-${environment}-${prefix}-spoke-01'
        subnetName: 'snet-generic'
        SubnetAddressSpace: '10.2.3.0/24'
        serviceEndpoints: []
        nsgToAttach: 'vnet-${environment}-${prefix}-spoke-01-snet-generic-nsg'
        securityRules: [
          {
            name: 'BatchServiceRule'
            properties: {
                protocol: 'tcp'
                sourcePortRange: '*'
                destinationPortRange: '29876-29877'
                sourceAddressPrefix: 'BatchNodeManagement.${resourceGroupLocation}'
                destinationAddressPrefix: '*'
                access: 'Allow'
                priority: 120
                direction: 'Inbound'
                sourcePortRanges: []
                destinationPortRanges: []
                sourceAddressPrefixes: []
                destinationAddressPrefixes: []
            }
          }
          {
            name: 'Deny-RDP'
            properties: {
                description: 'Denies the ability to remote desktop onto Azure batch nodes'
                protocol: '*'
                sourcePortRange: '*'
                destinationPortRange: '3389'
                sourceAddressPrefix: '*'
                destinationAddressPrefix: '*'
                access: 'Deny'
                priority: 100
                direction: 'Inbound'
            }
          }
          {
            name: 'Deny-SSH'
            properties: {
                description: 'Denies the ability to ssh onto Azure batch nodes'
                protocol: '*'
                sourcePortRange: '*'
                destinationPortRange: '22'
                sourceAddressPrefix: '*'
                destinationAddressPrefix: '*'
                access: 'Deny'
                priority: 101
                direction: 'Inbound'
            }
          }
        ]
        rtToAttach: 'vnet-${environment}-${prefix}-spoke-01-snet-generic-rt'
        routes: []
        privateEndpointNetworkPolicies: 'Disabled'
        PrivateLinkServiceNetworkPolicies: 'Disabled'
      }
      {
        vNetName: 'vnet-${environment}-${prefix}-spoke-01'
        subnetName: 'snet-priv-ep'
        SubnetAddressSpace: '10.2.4.0/24'
        serviceEndpoints: []
        nsgToAttach: 'vnet-${environment}-${prefix}-spoke-01-snet-priv-ep-nsg'
        securityRules: []
        rtToAttach: 'vnet-${environment}-${prefix}-spoke-01-snet-priv-ep-rt'
        routes: []
        privateEndpointNetworkPolicies: 'Disabled'
        PrivateLinkServiceNetworkPolicies: 'Disabled'
      }
  ]
}

var vNetSpoke02Param  = {
  vNetName: 'vnet-${environment}-${prefix}-spoke-02'
  vNetRG:   'rg-${environment}-${prefix}-vnet-spoke-02'
  vNetLocation: resourceGroupLocation
  NetworkType: 'Spoke'
  vNetAddressSpace: '10.3.0.0/16'
  positionEndpointSubnet: 3
  positionTestVM: 0
  subnets: [
    
      {
        vNetName: 'vnet-${environment}-${prefix}-spoke-02'
        subnetName: 'snet-front-calc'
        SubnetAddressSpace: '10.3.1.0/24'
        serviceEndpoints: []
        nsgToAttach: 'vnet-${environment}-${prefix}-spoke-02-snet-front-calc-nsg'
        securityRules: []
        rtToAttach: 'vnet-${environment}-${prefix}-spoke-02-snet-front-calc-rt'
        routes: []
        privateEndpointNetworkPolicies: 'Enabled'
        PrivateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        vNetName: 'vnet-${environment}-${prefix}-spoke-02'
        subnetName: 'snet-calc-nodes'
        SubnetAddressSpace: '10.3.2.0/24'
        serviceEndpoints: []
        nsgToAttach: 'vnet-${environment}-${prefix}-spoke-02-snet-calc-nodes-nsg'
        securityRules: []
        rtToAttach: 'vnet-${environment}-${prefix}-spoke-02-snet-calc-nodes-rt'
        routes: []
        privateEndpointNetworkPolicies: 'Enabled'
        PrivateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        vNetName: 'vnet-${environment}-${prefix}-spoke-02'
        subnetName: 'snet-storage'
        SubnetAddressSpace: '10.3.3.0/24'
        serviceEndpoints: []
        nsgToAttach: 'vnet-${environment}-${prefix}-spoke-02-snet-storage-nsg'
        securityRules: []
        rtToAttach: 'vnet-${environment}-${prefix}-spoke-02-snet-storage-rt'
        routes: []
        privateEndpointNetworkPolicies: 'Enabled'
        PrivateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        vNetName: 'vnet-${environment}-${prefix}-spoke-02'
        subnetName: 'snet-priv-ep'
        SubnetAddressSpace: '10.3.4.0/24'
        serviceEndpoints: []
        nsgToAttach: 'vnet-${environment}-${prefix}-spoke-02-snet-priv-ep-nsg'
        securityRules: []
        rtToAttach: 'vnet-${environment}-${prefix}-spoke-02-snet-priv-ep-rt'
        routes: []
        privateEndpointNetworkPolicies: 'Disabled'
        PrivateLinkServiceNetworkPolicies: 'Disabled'
      }
  ]
}

var fwNetworkRuleCollections  = [
  {
    name: 'nrcIntraSpokeConnectivity'
    properties: {
        priority: 110
        action: {
            type: 'Allow'
        }
        rules: [
            {
                name: 'Spoke01-to-Spoke02'
                protocols: [
                    'Any'
                ]
                sourceAddresses: [
                  vNetSpoke01Param.vNetAddressSpace
                ]
                destinationAddresses: [
                  vNetSpoke02Param.vNetAddressSpace
                ]
                sourceIpGroups: []
                destinationIpGroups: []
                destinationFqdns: []
                destinationPorts: [
                    '*'
                ]
            }
            {
              name: 'Spoke02-to-Spoke01'
              protocols: [
                  'Any'
              ]
              sourceAddresses: [
                vNetSpoke02Param.vNetAddressSpace
              ]
              destinationAddresses: [
                vNetSpoke01Param.vNetAddressSpace
              ]
              sourceIpGroups: []
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                  '*'
              ]
          }
          {
            name: 'SMTP'
            protocols: [
                'Any'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            sourceIpGroups: []
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
                25
            ]
          }
          {
            name: 'NTP'
            protocols: [
                'UDP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            sourceIpGroups: []
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
                123
            ]
          }
          {
            name: 'Dev-Jumpboxes'
            protocols: [
                'Any'
            ]
            sourceAddresses: [
              '10.1.4.4'
              '10.1.4.5'
            ]
            destinationAddresses: [
              '*'
            ]
            sourceIpGroups: []
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '*'
            ]
          }
        ]
    }
  }
]

var fwApplicationRuleCollections = [
  {
    name: 'applicationRuleCollectionAllow'
    properties: {
        priority: 100
        action: {
            type: 'Allow'
        }
        rules: [
          {
            name: 'web-Microsoft'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: []
            targetFqdns: [
                '*aka.ms'
                '*azure.com'
                '*azure.net'
                '*azure-automation.net'
                '*azuredatabricks.net'
                '*${az.environment().suffixes.azureDatalakeStoreFileSystem}'
                '*${az.environment().suffixes.acrLoginServer}'
                '*${az.environment().suffixes.sqlServerHostname}'
                '*azureedge.net'
                '*azurewebsites.net'
                '*bing.com'
                '*gfx.ms'
                '*microsoft.com'
                '*microsoftonline.com'
                '*microsoftonline-p.com'
                '*msappproxy.net'
                '*msauth.net'
                '*msecnd.net'
                '*msftauth.net'
                '*msocsp.com'
                '*oneget.org'
                '*powershellgallery.com'
                '*visualstudio.com'
                '*vsassets.io'
                '*windows.net'
                '*windows.com'
                '*loganalytics.io'
                '*applicationinsights.io'
                '*microsofttranslator.com'
                '*clouddatahub.net'
                '*cloudsimple.com'
                '*cloudsimple.io'
                '*api.videoindexer.ai'
                '*azurecr.io'
                '*.azure.ai'
                '*.aether.ms'
                '*azureml.net'
                '*finnhub.io'
            ]
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }
        {
            name: 'web-LinuxRepos'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: []
            targetFqdns: [
                '*redhat.com'
                '*snapcraft.io'
                '*trafficmanager.net'
                '*ubuntu.com'
            ]
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }
        {
            name: 'web-DevOps'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: []
            targetFqdns: [
                '*github.com'
                '*github.io'
                '*cloudflare.com'
                '*fedoraproject.org'
                '*githubusercontent.com'
                '*hashicorp.com'
                '*mongodb.com'
                '*mongodb.org'
                '*terraform.io'
                '*python.org'
                '*pythonhosted.org'
                '*pypi.org'
                '*accuweather.com'
                '*openweathermap.org'
                'avwx.rest'
                '*bintray.com'
                '*pypa.io'
            ]
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }
        {
            name: 'web-Google'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: []
            targetFqdns: [
                '*gcr.io'
                '*google.com'
                '*googleapis.com'
            ]
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }
        {
            name: 'web-AKS'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: []
            targetFqdns: [
                '*amazonaws.com'
                '*azmk8s.io'
                '*azurecr.io'
                '*cloudapp.net'
                '*cloudfront.net'
                '*docker.com'
                '*docker.io'
                '*pivotal.io'
                '*quay.io'
                '*nvidia.github.io'
                '*apt.dockerproject.org'
                '*cdn.mscr.io'
            ]
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }
        {
            name: 'web-Misc'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: []
            targetFqdns: [
                '*aspnetcdn.com'
                '*bootstrapcdn.com'
                '*nvidia.com'
                '*sentinelone.net'
                '*metrics.nsatc.net'
            ]
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }
        {
            name: 'web-VirtualDesktop'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: []
            targetFqdns: [
                '*cloud.com'
                '*citrixdata.com'
                '*nssvc.net'
                '*xendesktop.net'
                '*netscalergateway.net'
                '*citrixnetworkapi.net'
                '*citrixworkspacesapi.net'
                '*service-now.com'
                '*citrix.com'
                '*netscalermgmt.net'
            ]
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }
        {
            name: 'AzureBackup'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: [
                'AzureBackup'
            ]
            targetFqdns: []
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }
        {
            name: 'WindowsUpdate'
            priority: 0
            direction: 'Inbound'
            protocols: [
                {
                    protocolType: 'Http'
                    port: 80
                }
                {
                    protocolType: 'Https'
                    port: 443
                }
            ]
            fqdnTags: [
                'WindowsUpdate'
            ]
            targetFqdns: []
            actions: []
            sourceAddresses: [
                '*'
            ]
            sourceIpGroups: []
        }

        ]
    }
  }
]


// VM Configurations (Jumpbox and Test VMs)
//-------------------------------------------------------

var linuxVmInitScriptRaw = loadTextContent('./modules/virtualMachines/linux-vm-init-script.sh')
var linuxVmInitScript = format(linuxVmInitScriptRaw,saNameStorageNFS,'container')

var vmObjectJumpbox  = {
  nicName: 'nic-jumpbox-linux-'
  vmName: 'vm-jumpbox-linux-'
  vmSize: jumpboxLinuxVmSize
  osProfile: {
    computerName: 'LinuxJumpbox'
    adminUserName: adminUserName
    adminPassword: adminPassword
    customData: base64(linuxVmInitScript)
  }
  imageReference: {
    publisher: 'canonical'
    offer: '0001-com-ubuntu-server-focal'
    sku: '20_04-lts-gen2'
    version: 'latest'
  }
}

var vmObjectJumpboxWindows  = {
  nicName: 'nic-jumpbox-windows-'
  vmName: 'vm-jumpbox-windows-'
  vmSize: jumpboxWindowsVmSize
  osProfile: {
    computerName: 'WindowsJumpbox'
    adminUserName: adminUserName
    adminPassword: adminPassword
  }
  imageReference: {
    publisher: 'microsoftwindowsdesktop'
    offer: 'windows-11'
    sku: 'win11-21h2-pro'
    version: 'latest'
  }
}

// DNZ Parameters
//-------------------------------------------------------

var privateDnsZoneNamesBase = [
  'privatelink.blob.${az.environment().suffixes.storage}'
  'privatelink.file.${az.environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
  'privatelink.${resourceGroupLocation}.batch.azure.com' 
]


var privateDnsZoneNameACR  = [
  'privatelink${az.environment().suffixes.acrLoginServer}'
]

var privateDnsZoneNames = deployPrivateACR ? union(privateDnsZoneNamesBase,privateDnsZoneNameACR) : privateDnsZoneNamesBase

// Storage Parameters
//-------------------------------------------------------

var saNameAzBatch = 'sa${prefix}azbatch'
var saNameStorageSMB = 'sa${prefix}blobsmb'
var saNameStorageNFS = 'sa${prefix}blobnfs'
var saNameAzBatchApplication = 'sa${prefix}baapp'


var saDefinitions = [
  {
    storageAccountName: saNameAzBatch
    privateLinkGroupIds: 'blob'
    storageAccountAccessTier: 'Hot'
    storageAccountKind: 'StorageV2'
    largeFileSharesState: 'Disabled'
    storageAccountSku: 'Standard_LRS'
    supportsHttpsTrafficOnly: false
    isHnsEnabled: false
    isNfsV3Enabled: false
    allowSharedKeyAccess: true
    }
    {
      storageAccountName: saNameStorageSMB
      privateLinkGroupIds: 'file'
      storageAccountAccessTier: 'Hot'
      storageAccountKind: 'StorageV2'
      largeFileSharesState: 'Enabled'
      storageAccountSku: 'Standard_LRS'
      supportsHttpsTrafficOnly: false
      isHnsEnabled: false
      isNfsV3Enabled: false
      fileShareEnabledProtocol: 'SMB'
      fileShareAccessTier: 'TransactionOptimized'
      allowSharedKeyAccess: true
    }
    {
      storageAccountName: saNameStorageNFS
      privateLinkGroupIds: 'blob'
      storageAccountAccessTier: 'Hot'
      storageAccountKind: 'StorageV2'
      largeFileSharesState: 'Disabled'
      storageAccountSku: 'Standard_LRS'
      supportsHttpsTrafficOnly: false
      isHnsEnabled: true
      isNfsV3Enabled: true
      allowSharedKeyAccess: true
    }
    {
      storageAccountName: saNameAzBatchApplication
      privateLinkGroupIds: 'blob'
      storageAccountAccessTier: 'Hot'
      storageAccountKind: 'StorageV2'
      largeFileSharesState: 'Disabled'
      storageAccountSku: 'Standard_LRS'
      supportsHttpsTrafficOnly: false
      isHnsEnabled: false
      isNfsV3Enabled: false
      allowSharedKeyAccess: true
      }
  ]


// Global Variables 
//-------------------------------------------------------

var rgHub = 'rg-${environment}-${prefix}-vnet-hub-01'
var rgSpoke01 = 'rg-${environment}-${prefix}-vnet-spoke-01'
var rgSpoke02 = 'rg-${environment}-${prefix}-vnet-spoke-02'
var rgJumpbox = 'rg-${environment}-${prefix}-jumpbox' 
var rgAzureBatch  = 'rg-${environment}-${prefix}-azbatch' 

var azureFirewallName  = 'fw-${environment}-${prefix}-vnet-hub-01'
var bastionName = 'bas-${environment}-${prefix}-vnet-hub-01'

var resourceGroupNames = [
  rgHub
  rgSpoke01
  rgSpoke02
  rgJumpbox
  rgAzureBatch
]

// ACR Parameters
//-------------------------------------------------------

var acrName = 'acr${environment}${prefix}azbatch'

@allowed([
  'Enabled'
  'Disabled'
])
@description('Private access (Recommended) is only available for Premium SKU.')
param acrPublicNetworkAccess string = 'Disabled'

@allowed([
  'Basic'
  'Classic'
  'Premium'
  'Standard'
  ])
param acrSku string = 'Premium'

param acrAdminUserEnabled bool = true

param deployPrivateACR bool = true

param primaryScriptBuildKvTestImage string = 'https://raw.githubusercontent.com/mocelj/AzureBatch-Secured/main/artefacts/checkAkv/buildRemoteContainer.sh'

// Azure Batch Parameters

var batchAccountName = 'ba${environment}${prefix}01'

//--------------------------- Deploy the Resource Groups ------------------------------------------------------------------ 

@batchSize(1)
module rgModule './modules/resourceGroup/resourceGroup.bicep' = [ for resourceGroupName in resourceGroupNames: {
  name: 'dpl-${uniqueString(deployment().name,deployment().location)}-Sub-${resourceGroupName}'
  params: {
    resourceGroupLocation: resourceGroupLocation
    resourceGroupName: resourceGroupName
    resourceTags: resourceTags
    }
}]

//--------------------------- Deploy Log Analytics Workspace -------------------------------------------------------------- 

var logAnalyticsWorkspaceName = 'log-${environment}-${prefix}-${uniqueString(subscription().subscriptionId,('rg-${prefix}-vnet-hub-01'))}'

module logAnalyticsWorkspace './modules/logAnalytics/logAnalytics.bicep' = {
  scope: resourceGroup(rgHub)
  name: 'dpl-${uniqueString(deployment().name,deployment().location)}-logAnalytics'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    tags: resourceTags
  }
  dependsOn: [
    rgModule
  ]
}

//--------------------------- Deploy Application Insights -------------------------------------------------------------- 

var appInsightsName = 'appi-${environment}-${prefix}-${uniqueString(subscription().subscriptionId,('rg-${prefix}-vnet-hub-01'))}'

module appInsights './modules/appInsights/deploy.bicep' = {
  scope: resourceGroup(rgHub)
  name: 'dpl-${uniqueString(deployment().name,deployment().location)}-appInsights'
  params: {
    appInsightsWorkspaceResourceId: logAnalyticsWorkspace.outputs.id
    name: appInsightsName
    tags:resourceTags
  }
  dependsOn: [
    rgModule
  ]
}

//--------------------------- Deploy the Hub-Spoke VNET (incl. FW, Log Analytics Workspace, Bastion) -------------------

module hubSpokeNetwork './modules/networking/hubSpokeNetwork.bicep' = if (deployHubSpoke) {
  scope: subscription()
  name: 'dpl-${uniqueString(deployment().name,deployment().location)}-hubSpoke'
  params: {
    pipBastionName: pipBastionName
    pipFirewallName: pipFirewallName
    rgHub: rgHub
    rgSpoke01: rgSpoke01
    rgSpoke02: rgSpoke02
    vNetHubObject: vNetHubObject
    vNetSpoke01Object: vNetSpoke01Param
    vNetSpoke02Object: vNetSpoke02Param
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    azureFirewallName: azureFirewallName
    bastionName: bastionName
    fwNetworkRuleCollections: fwNetworkRuleCollections
    fwApplicationRuleCollections: fwApplicationRuleCollections
    privateDnsZoneNames: privateDnsZoneNames
    ignoreDnsZoneNwLinks: ignoreDnsZoneNwLinks
    tags: resourceTags
  }
  dependsOn: [
    rgModule
    logAnalyticsWorkspace
  ]
}

//---------------------------  Deploy the VPN Gateway to the Hub Network --------------------------------------------------

resource vNetHub 'Microsoft.Network/virtualNetworks@2021-05-01' existing = if (deployVPNGw){
  scope: resourceGroup(rgHub)
  name: vNetHubObject.vNetName
}

var vpnGwName = 'vpnGw${environment}${prefix}01'
var vpnClientAddressPoolPrefix = '172.16.25.0/24'

module deployVPNGwToHub './modules/networking/vpnGateway/deploy.bicep' = if (deployVPNGw) {
  scope: resourceGroup(rgHub)
  name: 'dpl-${uniqueString(deployment().name,deployment().location)}-vpnGw'
  params: {
    name: vpnGwName
    virtualNetworkGatewaySku: 'VpnGw2'
    virtualNetworkGatewayType: 'Vpn'
    vNetResourceId: vNetHub.id
    activeActive: false
    enableBgp: false
    vpnType: 'RouteBased'
    vpnClientAddressPoolPrefix: vpnClientAddressPoolPrefix
  }

  dependsOn: [
    hubSpokeNetwork
  ]
}


//---------------------------  Deploy the Azure Batch Demo to Spoke 01------------------------------------------------------

module deployDemoAzureBatchSecured './modules/Demos/Demo-Batch-Secured/demoAzureBatch-Secured.bicep' = if (deploySecureBatch) {
  scope: resourceGroup(rgAzureBatch)
  name: 'dpl-${uniqueString(deployment().name,deployment().location)}-azBatchSecured'
  params: {
    rgAzureBatch: rgAzureBatch
    rgHub: rgHub
    rgSpoke: rgSpoke01
    prefix: prefix
    environment: environment
    appInsightsName: appInsightsName
    vNetObject: vNetSpoke01Param
    saDefinitions: saDefinitions
    saNameAzBatch: saNameAzBatch
    acrName: acrName
    acrPublicNetworkAccess: acrPublicNetworkAccess
    acrSku: acrSku
    acrAdminUserEnabled: acrAdminUserEnabled
    deployPrivateACR: deployPrivateACR
    primaryScriptBuildKvTestImage: primaryScriptBuildKvTestImage
    batchAccountName: batchAccountName
    batchServiceObjectId: batchServiceObjectId
    batchNodeSku: batchNodeSku
    saNameStorageNFS: saNameStorageNFS
    saNameStorageSMB: saNameStorageSMB
    tags: resourceTags
  }
  dependsOn: [
    hubSpokeNetwork
    appInsights
  ]
}

//--------------------------- Deploy Hub Jumpboxes (Windows & Linux) ---------------------------------------------------

// Dependency to Azure Batch Deployment, since the NFS (blob) Share will be mounted to the Linux Jumpbox

module hubJumpboxes './modules/virtualMachines/hubJumpboxes.bicep' = if (deployJumpBoxVMs) { 
  scope: resourceGroup(rgJumpbox)
  name:  'dpl-${uniqueString(deployment().name,deployment().location)}-jumpbox'
  params: {
    vmExtensionWindowsJumpboxUri: vmExtensionWindowsJumpboxUri
    vmObjectJumpboxWindows: vmObjectJumpboxWindows
    vmObjectJumpbox: vmObjectJumpbox
    vNetHubObject: vNetHubObject
    deployJumpboxWindowsAddOns: deployJumpboxWindowsAddOns
    rgHub: rgHub
    tags: resourceTags
  }
  dependsOn: [
    rgModule
    hubSpokeNetwork
    deployDemoAzureBatchSecured
  ]
 }
