@description('Environment of the web app')
param environment string = 'dev'

@description('Location of services')
//param location string = resourceGroup().location
@allowed([
  'eastus'
  'westus'
  'westeurope'
  'northeurope'
  'southeastasia'
  'eastasia'
  'australiaeast'
  'australiasoutheast'
  'brazilsouth'
  'centralus'
  'japaneast'
  'japanwest'
  'koreacentral'
  'koreasouth'
  'southindia'
  'centralindia'
  'canadacentral'
  'canadaeast'
  'uksouth'
  'ukwest'
  'westcentralus'
  'westus2'
  'southafricanorth'
  'uaenorth'
])
param location string = 'westeurope'


var webAppName = '${uniqueString(resourceGroup().id)}-${environment}'
var appServicePlanName = '${uniqueString(resourceGroup().id)}-mpnp-asp'
var logAnalyticsName = '${uniqueString(resourceGroup().id)}-mpnp-la'
var appInsightsName = '${uniqueString(resourceGroup().id)}-mpnp-ai'
var sku = 'S1'
var registryName = '${uniqueString(resourceGroup().id)}mpnpreg'
var registrySku = 'Standard'
var imageName = 'techexcel/dotnetcoreapp'
var startupCommand = ''
var redisCacheName = '${uniqueString(resourceGroup().id)}-mpnp-redis'
var redisCacheSku = 'Basic'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: registryName
  location: location
  sku: {
    name: registrySku
  }
  properties: {
    adminUserEnabled: true
  }
}

resource appServicePlan 'Microsoft.Web/serverFarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    name: sku
  }
}

resource appServiceApp 'Microsoft.Web/sites@2020-12-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.name}.azurecr.io/${uniqueString(resourceGroup().id)}/${imageName}'
      http20Enabled: true
      minTlsVersion: '1.2'
      appCommandLine: startupCommand
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.name}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.name
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        ]
      }
    }
}

resource redisCache 'Microsoft.Cache/Redis@2023-08-01' = {
  name: redisCacheName
  location: location
  properties: {
    sku: {
      name: redisCacheSku
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'volatile-lru'
    }
  }
}
output application_name string = appServiceApp.name
output application_url string = appServiceApp.properties.hostNames[0]
output container_registry_name string = containerRegistry.name
