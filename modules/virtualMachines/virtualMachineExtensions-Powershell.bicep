// https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/2020-06-01/virtualmachines/extensions?tabs=bicep

param vmName string
param vmExtensionName string
param virtualMachineExtensionCustomScriptUri string

param tags object = {}
param location string = resourceGroup().location
param currentTime string = utcNow()


// Virtual Machine Extensions - Custom Script
var virtualMachineExtensionCustomScript = {
  name: '${vmName}/${vmExtensionName}'
  location: location
  fileUris: [
    virtualMachineExtensionCustomScriptUri
  ]
  commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ./${last(split(virtualMachineExtensionCustomScriptUri, '/'))}'
}

resource vmext 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: virtualMachineExtensionCustomScript.name
  location: virtualMachineExtensionCustomScript.location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: virtualMachineExtensionCustomScript.fileUris
      commandToExecute: virtualMachineExtensionCustomScript.commandToExecute
    }
    protectedSettings: {}
    forceUpdateTag: currentTime // ensures script will run every time
  }
}
