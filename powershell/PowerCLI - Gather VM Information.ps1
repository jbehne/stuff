
<#  Check to see if the PowerCLI module is installed and imported.  
 #  If not, install and import it.

    $pcli = Get-Module | Where Name -eq VMWare.PowerCLI
    if ($pcli -eq $null)
    {
        Install-Module -Name VMware.PowerCLI
        Import-Module VMware.PowerCLI
    }
#>

<#  Gets rid of the annoying customer experience message
    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false
#>

<#  Connect to the vsphere server
    Connect-VIServer -Server x1vsi061.countrylan.com -AllLinked -User ID67065 -Password xxx
#>


<#  Search all VM's by Name LIKE xxx
    $vmlist = @()
    $vmlist += Get-VM | Where Name -like "*DBD*" | Select Name, Guest, NumCpu, CoresPerSocket, MemoryGB, VMHost, PowerState, Folder
    $vmlist += Get-VM | Where Name -like "*DBS*" | Select Name, Guest, NumCpu, CoresPerSocket, MemoryGB, VMHost, PowerState, Folder
#>

<#  Help 
Log in to a vCenter Server or ESX host:              Connect-VIServer
To find out what commands are available, type:       Get-VICommand
To show searchable help for all PowerCLI commands:   Get-PowerCLIHelp
Once you've connected, display all virtual machines: Get-VM
#>

