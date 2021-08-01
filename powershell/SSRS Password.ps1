$reportWebService = 'http://c1dbd069/ReportServer/ReportService2010.asmx'
$credentials = Get-Credential
$reportproxy = New-WebServiceProxy -uri $reportWebService -Credential $credentials
#$ssrsproxy = New-SSRSProxy -reportWebService $reportWebService -Credentials $credentials
#$proxyNameSpace = $ssrsproxy.gettype().Namespace

$datasourcepath = $reportproxy.ListChildren("/", $true) | Where Name -EQ "Production Repository"
$datasource = $reportproxy.GetDataSourceContents($datasourcepath.Path)
$datasource.Password = ""
$reportproxy.SetDataSourceContents($datasourcepath.Path, $datasource)