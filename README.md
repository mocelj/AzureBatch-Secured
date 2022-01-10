# AzureBatch-Secured
Example which demonstrates how to deploy Azure Batch in a "secured" way.

This is work in progress ...

Currently, the following resources are deployed to your Azure Subscription:

![Overview](./images/batch-private-cluster.png)


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmocelj%2FAzureBatch-Secured%2Fmain%2Fazuredeploy.json)


## Parameters

| Parameter Name | Type | Default Value | Possible Values | Description |
| :-- | :-- | :-- | :-- | :-- |
| `resourceGroupLocation` | string | `westeurope` | `[eastus,eastus2,westeurope]` |Optional. The region the resources will be deployed to. Default value will be applied in case nothing is provided|
| `environment` | string | `dev` | `3 character prefix` | Optional. Default value will be applied in case nothing is provided. |
| `prefix` | string | `unique string created by environment, Subscription Id and resourceGroupLocation` | `-<environment>-<guid>-` | Optional. Default value will be applied in case nothing is provided.  |
| ` deployHubSpoke` | bool | `true` | `true,false` | Optional. Indicate if Hub-Spoke Network should be deployed. Default value will be applied in case nothing is provided. |
| `ignoreDnsZoneNwLinks` | bool | `true` | `true,false` | Optional. Default value will be applied in case nothing is provided. |
| `eployJumpBoxVMs` | bool | `true` | `true,false` | Optional. Indicate if a Linux and Windows Jumpbox should be deployed. Default value will be applied in case nothing is provided.|
| `deployVPNGw` | bool | `false` | `true,false` | Optional. Indicate if a VPN Gateway should be deployed. Note: deployment may take up to 45 min addtional time. Certificate has to be added after creation. Default value will be applied in case nothing is provided.|
| `deploySecureBatch` | bool | `true` | `true,false` | Optional. Indicate if Azure Batch Demo should be deployed. Default value will be applied in case nothing is provided. |
| `adminUserName` | string | `localadmin` |  | Optional. Default value will be applied in case nothing is provided. |
| `adminPassword` | secure string |  |  | Required. |
| `resourceTags` | object | `{object}` |  | Optional. Tags of the resource. |
| `jumpboxLinuxVmSize` | string | `Standard_B1s` | `Standard_B1s,Standard_B2ms` | Optional. Size of the Linux Jumpbox. Default value will be applied in case nothing is provided. |
| `jumpboxWindowsVmSize` | string | `Standard_D4_v5` | `Standard_B2ms,Standard_B4ms,Standard_D4_v5` | Optional. Size of the Windows Jumpbox. Default value will be applied in case nothing is provided. |
| `batchServiceObjectId` | string | | az ad sp show --id "MicrosoftAzureBatch" --query objectId -o tsv' | Required. Objected Id of the the Azure Batch Service. Needed to grant contributor permissions in batch user subscription mode deployment. Execute the acli command to get the id. |
| `assignBatchServiceRoles` | bool | `true` | `true,false` | Optional. If Batch Service has already been granted contributor permissions to subscription, select false - otherwise, select true. Default value will be applied in case nothing is provided. |
| `batchNodeSku` | string | `Standard_D2s_v3` | `Standard_D2s_V3,Standard_D2s_V4,Standard_D2s_V5,Standard_F2s_v2,Standard_F4s_v2,Standard_F8s_v2,Standard_B2ms,Standard_B4ms,Standard_D4_v5` | Optional. Default value will be applied in case nothing is provided. |
