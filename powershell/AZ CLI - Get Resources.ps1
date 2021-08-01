$AzCred = Get-Credential
az login -u $AzCred.UserName -p $AzCred.GetNetworkCredential().Password

$subscriptions = az account list | ConvertFrom-Json | foreach { $_.name }

foreach ($subscription in $subscriptions)
{
    $resources = az resource list --subscription "$subscription" | ConvertFrom-Json 
    $resources = $resources | where resourceGroup -Like "*database*"
    foreach ($resource in $resources)
    {
        $query = "INSERT AZ_Resource (resourcegroupid, id, name, location, type, tags, sku) 
                    SELECT resourcegroupid, '$($resource.id)', '$($resource.name)', '$($resource.location)', '$($resource.type)', '$($resource.tags)', '$($resource.sku)'
                    FROM AZ_ResourceGroup WHERE name = '$($resource.resourceGroup)'"

        Invoke-Sqlcmd -ServerInstance V01DBSWIN057 -Database AZMONITOR -Query $query
    }

    $alerts = az monitor metrics alert list --subscription "$subscription" | ConvertFrom-Json
    $alerts = $alerts | Where resourcegroup -Like "*database*" | Select id

    foreach ($alert in $alerts)
    {
        $alertinfo = az monitor metrics alert show --ids "$($alert.id)" | ConvertFrom-Json
        $query = "INSERT AZ_Alert (resourceid, name, enabled, automitigate, windowsize, frequency, severity, description, condition)
                    SELECT resourceid, '$($($alertinfo.name).split("_")[1])', 
                    '$($alertinfo.enabled)', '$($alertinfo.automitigate)', '$($alertinfo.windowSize)', '$($alertinfo.evaluationFrequency)', '$($alertinfo.severity)', '$($alertinfo.description)', 
                    '$($($alertinfo.criteria.allOf).timeaggregation) $($($alertinfo.criteria.allOf).metricname) $($($alertinfo.criteria.allOf).operator) $($($alertinfo.criteria.allOf).threshold)'
                    FROM AZ_Resource WHERE name = '$($($alertinfo.name).split("_")[0])'"

        Invoke-SqlCmd -ServerInstance V01DBSWIN057 -Database AZMONITOR -Query $query
    }
}

<# avg cpu_percent > 95
alertid bigint IDENTITY
	, resourceid bigint
	, name varchar(256)
	, enabled bit
	, automitigate bit
	, windowsize varchar(24)
	, frequency varchar(24)
	, severity tinyint
	, description varchar(512)
	, condition varchar(512)
#>