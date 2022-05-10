param Location string
param StorageAccount_Name string
param LogAnalytics_Workspace_Name string
param AppInsights_Name string
param ContainerApps_Environment_Name string
param ContainerApps_HttpApi_CurrentRevisionName string
param ContainerApps_HttpApi_NewRevisionName string

var StorageAccount_ApiVersion = '2018-07-01'
var StorageAccount_Queue_Name = 'demoqueue'
var ContainerApps_Environment_Id = ContainerApps_Environment_Name_resource.id
var Workspace_Resource_Id = LogAnalytics_Workspace_resource.id

resource StorageAccount_resource 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  name: StorageAccount_Name
  location: Location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource LogAnalytics_Workspace_resource 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: LogAnalytics_Workspace_Name
  location: Location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource AppInsights_Name_resource 'Microsoft.Insights/Components@2020-02-02-preview' = {
  name: AppInsights_Name
  location: Location
  properties: {
    ApplicationId: AppInsights_Name
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    Request_Source: 'CustomDeployment'
  }
}

resource ContainerApps_Environment_Name_resource 'Microsoft.App/managedEnvironments@2022-01-01-preview' = {
  name: ContainerApps_Environment_Name
  location: Location
  tags: {}
  properties: {
    type: 'managed'
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(Workspace_Resource_Id, '2015-11-01-preview').customerId
        sharedKey: listKeys(Workspace_Resource_Id, '2015-03-20').primarySharedKey
      }
    }
    containerAppsConfiguration: {
      daprAIInstrumentationKey: reference(AppInsights_Name_resource.id, '2020-02-02', 'Full').properties.InstrumentationKey
    }
  }
  dependsOn: [
    Workspace_Resource_Id
    StorageAccount_resource
  ]
}

resource queuereader 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: 'queuereader'
  kind: 'containerapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Id
    configuration: {
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount_Name};AccountKey=${listKeys(StorageAccount_resource.id, StorageAccount_ApiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
      dapr: {
        enabled: false
      }
    }
    template: {
      containers: [
        {
          image: 'kevingbb/queuereader:v1'
          name: 'queuereader'
          env: [
            {
              name: 'QueueName'
              value: 'demoqueue'
            }
            {
              name: 'QueueConnectionString'
              secretRef: 'queueconnection'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
        rules: [
          {
            name: 'myqueuerule'
            azureQueue: {
              queueName: 'demoqueue'
              queueLength: 10
              auth: [
                {
                  secretRef: 'queueconnection'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    ContainerApps_Environment_Id
  ]
}

resource storeapp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: 'storeapp'
  kind: 'containerapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
      }
      dapr: {
        enabled: true
        appPort: 3000
      }
    }
    template: {
      containers: [
        {
          image: 'kevingbb/storeapp:v1'
          name: 'storeapp'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: []
      }
    }
  }
  dependsOn: [
    ContainerApps_Environment_Id
  ]
}

resource httpapi 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: 'httpapi'
  kind: 'containerapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Id
    configuration: {
      activeRevisionsMode: 'multiple'
      ingress: {
        external: true
        targetPort: 80
      }
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount_Name};AccountKey=${listKeys(StorageAccount_resource.id, StorageAccount_ApiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
      dapr: {
        enabled: false
      }
    }
    template: {
      revisionSuffix: ContainerApps_HttpApi_CurrentRevisionName
      containers: [
        {
          image: 'kevingbb/httpapiapp:v1'
          name: 'httpapi'
          env: [
            {
              name: 'QueueName'
              value: 'demoqueue'
            }
            {
              name: 'QueueConnectionString'
              secretRef: 'queueconnection'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
        rules: [
          {
            name: 'httpscalingrule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    ContainerApps_Environment_Id
  ]
}
