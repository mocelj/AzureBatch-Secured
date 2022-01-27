


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

param utcShort string = utcNow('d')

param resourceTags object = {
  WorkloadName : 'Back Office Risk'
  BusinessUnit : 'Risk Managment'
  Owner: 'Darko Mocelj'
  Environment: environment
  CostCenter: 'Internal'
  LastDeployed: utcShort
}

param dnsSubnetName string = 'snet-dns'

param adminUserName string = 'localadmin'

@secure()
param adminPassword string

@allowed([
  'Standard_B1s'
  'Standard_B2ms'
])
param dnsLinuxVmSize string = 'Standard_B1s'


var vNetHubName        = 'vnet-${environment}-${prefix}-hub-01'
var vNetSpoke01        = 'vnet-${environment}-${prefix}-spoke-01'
var vNetSpoke02        = 'vnet-${environment}-${prefix}-spoke-02'

var azureFirewallName  = 'fw-${environment}-${prefix}-vnet-hub-01'

var rgHub              = 'rg-${environment}-${prefix}-vnet-hub-01'
var rgSpoke01          = 'rg-${environment}-${prefix}-vnet-spoke-01'
var rgSpoke02          = 'rg-${environment}-${prefix}-vnet-spoke-02'

var rgDNS              = 'rg-${environment}-${prefix}-dns'
var miName             = 'id-${environment}-${prefix}-dns-update'

//--------------------------- Deploy the Resource Groups ------------------------------------------------------------------ 

var resourceGroupNames = [
  rgDNS
]

@batchSize(1)
module rgModule '../../../modules/resourceGroup/resourceGroup.bicep' = [ for resourceGroupName in resourceGroupNames: {
  name: 'dpl-${uniqueString(deployment().name,deployment().location)}-Sub-${resourceGroupName}'
  params: {
    resourceGroupLocation: resourceGroupLocation
    resourceGroupName: resourceGroupName
    resourceTags: resourceTags
    }
}]

//--------------------------- Deploy DNS Server------------------------------------------------------------------------------ 

var dnsVMInitScript = loadFileAsBase64('./dns-vm-cloud-init.txt')

var vmObjectDNS  = {
  nicName: 'nic-dns-linux-'
  vmName: 'vm-dns-linux-'
  vmSize: dnsLinuxVmSize
  osProfile: {
    computerName: 'LinuxDNS'
    adminUserName: adminUserName
    adminPassword: adminPassword
    customData: dnsVMInitScript
  }
  imageReference: {
    publisher: 'canonical'
    offer: '0001-com-ubuntu-server-focal'
    sku: '20_04-lts-gen2'
    version: 'latest'
  }
}

// Get the Reference to the exisiting Hub Vnet

resource vNetHub 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vNetHubName
  scope: resourceGroup(rgHub)
}

module jumpboxVM '../../../modules/virtualMachines/vmSimple.bicep' = { 
  scope: resourceGroup(rgDNS)
  name: 'dpl-${uniqueString(deployment().name,resourceGroupLocation)}-dns-vm'
  params: {
    subnetId: '${vNetHub.id}/subnets/${dnsSubnetName}'
    vmObject: vmObjectDNS
    tags: resourceTags
  }
  dependsOn: [
    rgModule
  ]
}

//--------------------------- Modify the FireWall and Update DNS Server ---------------------------------------------------------

var dnsServerIp = jumpboxVM.outputs.nicDetail[0].privateIp 

module updateDNSconfig './deploymentScript-DNS-Update.bicep' = {
  scope: resourceGroup(rgDNS)
  name: 'dpl-${uniqueString(deployment().name,deployment().location)}-Update-DNS-Settings'
  params: {
    fwName: azureFirewallName
    dnsServerIp: dnsServerIp
    managedIdentityName: miName
    vNetHub: vNetHubName
    vNetSpoke01: vNetSpoke01
    vNetSpoke02: vNetSpoke02
    rgHub: rgHub
    rgSpoke01: rgSpoke01
    rgSpoke02: rgSpoke02
    tags: resourceTags 
  }
}
