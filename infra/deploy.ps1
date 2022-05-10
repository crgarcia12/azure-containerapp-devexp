
$environment = "ephemeral"

# Set variables for the rest of the demo

$resourceGroup="crgar-contapp-$environment-rg"
$location = "westeurope"
$containerAppEnv="crgar-contapp-$environment-appenv"
$logAnalytics="crgar-contapp-$environment-la"
$appInsights="crgar-contapp-$environment-ai"
$storageAccount="crgarcontapp$environmentsa"

az group create --name $resourceGroup --location $location -o table

az deployment group create \
  -g $resourceGroup \
  --template-file v1_template.json \
  --parameters @v1_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount