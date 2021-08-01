$AzCred = Get-Credential
az login -u $AzCred.UserName -p $AzCred.GetNetworkCredential().Password

$resource = Read-Host -Prompt "Enter resource name"

if ($resource.Split('-')[0] -eq "sb")
{
    $subscription = "COUNTRY Financial Sandbox"
    $rg = "SB-RG-Database-01"
}

elseif ($resource.Split('-')[0] -eq "np")
{
    $subscription = "COUNTRY Financial Non Prod"
    $rg = "NonProd-RG-Database-01"
}

elseif ($resource.Split('-')[0] -eq "qa")
{
    $subscription = "COUNTRY Financial QA"
    $rg = "QA-RG-Database-01"

}

elseif ($resource.Split('-')[0] -eq "prod")
{
    $subscription = "COUNTRY Financial Production"
    $rg = "Prod-RG-Database-01"

}

else
{
    return;
}

$resources = az resource list --subscription $subscription --resource-group $rg | ConvertFrom-Json
$resource = $resources | Where name -eq $resource

$alerts = Invoke-SqlCmd -ServerInstance V01DBSWIN057 -Database AZMONITOR -Query "SELECT * FROM AZ_AlertTemplate WHERE type = '$($resource.type)'"

if ($resource.type -eq "Microsoft.Sql/servers")
{
    $sqldbs = az sql db list --ids $resource.id | ConvertFrom-Json
    foreach ($sqldb in $sqldbs)
    {
        if ($sqldb.name -ne "master")
        {
            foreach ($alert in $alerts)
            {
                az monitor metrics alert create `
                --name "$($resource.name)_$($alert.name)" `
                --subscription "$subscription" `
                --resource-group $rg `
                --scopes $sqldb.id `
                --condition "$($alert.condition)" `
                --window-size "$($alert.window)" `
                --evaluation-frequency "$($alert.frequency)" `
                --action DBA-Notify `
                --description "$($alert.name): $($alert.condition)" `
                --auto-mitigate true | Out-Null

                "Added '$($alert.name)' to '$($sqldb.name)' on '$($resource.name)'"
            }
        }
    }
}

else
{
    foreach ($alert in $alerts)
    {
        az monitor metrics alert create `
        --name "$($resource.name)_$($alert.name)" `
        --subscription "$subscription" `
        --resource-group $rg `
        --scopes $resource.id `
        --condition "$($alert.condition)" `
        --window-size "$($alert.window)" `
        --evaluation-frequency "$($alert.frequency)" `
        --action DBA-Notify `
        --description "$($alert.name): $($alert.condition)" `
        --auto-mitigate true | Out-Null
    }
}