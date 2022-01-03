
/*
Purpose : Deploy new resource group
Author  : Darko Mocelj
Date    : 25.11.2021
Update  : 
Comments: 
*/

targetScope = 'subscription'


param resourceGroupLocation string
param resourceTags object
param resourceGroupName string

resource newRG 'Microsoft.Resources/resourceGroups@2021-04-01' =  {
  name: resourceGroupName
  location: resourceGroupLocation
  tags: resourceTags
}
