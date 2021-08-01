$AzCred = Get-Credential
az login -u $AzCred.UserName -p $AzCred.GetNetworkCredential().Password

$databasegroups = @()
$postgresservers = @()
$sqlservers = @()
$sqldatabases = @()

$subscriptions = az account list | ConvertFrom-Json | foreach { $_.name }

foreach ($subcription in $subscriptions)
{
    $groups = @()
    $groups += az group list --subscription $subcription | ConvertFrom-Json | foreach { $_.name }
    $group = $groups -match "database"
    $databasegroups += $group

    $postgresservers += az postgres server list --subscription $subscription --resource-group $group | ConvertFrom-Json
    $sqlservers += az sql server list --subscription $subscription --resource-group $group | ConvertFrom-Json
}

foreach ($sqlserver in $sqlservers)
{
    $sqldataabses += az sql db list --server $sqlserver.name
}

az monitor action-group list --subscription "COUNTRY Financial Sandbox" | ConvertFrom-Json | foreach { $_.name }
az monitor action-group list --subscription "COUNTRY Financial Non Prod" | ConvertFrom-Json | foreach { $_.name }
az monitor action-group list --subscription "COUNTRY Financial QA" | ConvertFrom-Json | foreach { $_.name }
az monitor action-group list --subscription "COUNTRY Financial Production" | ConvertFrom-Json | foreach { $_.name }


az monitor metrics alert list --subscription "COUNTRY Financial Non Prod" --resource-group "NonProd-RG-Database-01" | ConvertFrom-Json 

$postgresservers = az postgres server list | ConvertFrom-Json

az monitor metrics alert create `
    --name "PSQL High CPU" `
    --resource-group NonProd-RG-Database-01 `
    --scopes $postgresservers[1].id `
    --condition "avg cpu_percent > 90" `
    --window-size 15m `
    --evaluation-frequency 1m `
    --action DBA-Notify `
    --description "High CPU" `
    --auto-mitigate true

$resources = az resource list --location northcentralus | convertfrom-json 
$resources | where resourceGroup -Like "*database*"

<#
METRICS:
    storage_percent
    cpu_percent
    connections_failed
    io_consumption_percent
    memory_percent
#>

<#
az monitor metrics alert create --help

az monitor metrics alert create --condition
                                --name
                                --resource-group
                                --scopes
                                [--action]
                                [--auto-mitigate {false, true}]
                                [--description]
                                [--disabled {false, true}]
                                [--evaluation-frequency]
                                [--region]
                                [--severity]
                                [--subscription]
                                [--tags]
                                [--target-resource-type]
                                [--window-size]
#>