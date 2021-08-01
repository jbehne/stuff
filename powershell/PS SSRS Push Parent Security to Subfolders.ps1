$ReportServerUri = "http://c1dbd712:5051/ReportServer/ReportService2010.asmx";
$credentials = Get-Credential
$proxy = New-WebServiceProxy -uri $ReportServerUri -Credential $credentials

$items = $Proxy.ListChildren("/", $true);
 
foreach($item in $items){
    if($item.TypeName -eq "Folder")
    {    
        write-host $item.Name     
        
        $inherited = $true
        $itempolicies = $Proxy.GetPolicies($item.Path,[ref]$inherited)
        if (-not $inherited){
            $Proxy.InheritParentSecurity($item.Path)
        }
    }  
   
}