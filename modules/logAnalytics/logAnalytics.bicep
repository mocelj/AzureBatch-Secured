// https://docs.microsoft.com/en-us/azure/templates/microsoft.operationalinsights/workspaces?tabs=bicep

param logAnalyticsWorkspaceName string
param skuName string = 'Free'
param tags object


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: resourceGroup().location
  tags: tags
  properties: {
    sku: {
      name: skuName
    }
  }  
}

output id string = logAnalyticsWorkspace.id 
