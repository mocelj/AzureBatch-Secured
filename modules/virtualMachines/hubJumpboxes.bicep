


//param rgJumpbox string

param vNetHubObject object
param vmObjectJumpbox object
param vmObjectJumpboxWindows object
param deployJumpboxWindowsAddOns bool
param vmExtensionWindowsJumpboxUri string
param rgHub string
param tags object = {}


// Reference to the Hub VNET

resource vNetHub 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  scope: resourceGroup(rgHub)
  name: vNetHubObject.vNetName
}

// Create the Jumpbox in the Hub Network

module jumpboxVM '../../modules/virtualMachines/vmSimple.bicep' = { 
  //scope: resourceGroup(rgJumpbox)
  name: 'deployJumpBoxVM'
  params: {
    subnetId: '${vNetHub.id}/subnets/${vNetHubObject.subnets[vNetHubObject.positionJumpBox].subnetName}'
    vmObject: vmObjectJumpbox
    tags: tags
  }
  dependsOn: []
}

module jumpboxWindowsVM '../../modules/virtualMachines/vmSimple.bicep' = { 
  //scope: resourceGroup(rgJumpbox)
  name: 'deployJumpBoxWindowsVM'
  params: {
    subnetId: '${vNetHub.id}/subnets/${vNetHubObject.subnets[vNetHubObject.positionJumpBox].subnetName}'
    vmObject: vmObjectJumpboxWindows
    vmCount: 1
    tags: tags
  }
  dependsOn: []
}

// Install additonal software on the Windows Jumpbox
module deployVMExtension '../../modules/virtualMachines/virtualMachineExtensions-Powershell.bicep' = if (deployJumpboxWindowsAddOns) {
  //scope: resourceGroup(rgJumpbox)
  name: 'depoyWindowsJumpboxVMExtension'
  params: {
    virtualMachineExtensionCustomScriptUri: vmExtensionWindowsJumpboxUri
    vmExtensionName: 'addJumpboxSoftware'
    vmName: '${vmObjectJumpboxWindows.vmName}1'
    tags: tags
  }
  dependsOn: [
    jumpboxWindowsVM
  ]
}
