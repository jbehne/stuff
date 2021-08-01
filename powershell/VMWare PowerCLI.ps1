
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
    $pw = Read-Host -Prompt "Enter password" 
   # Connect-VIServer -Server v01vsiapl003.countrylan.com -AllLinked -User ID67065 -Password $pw
    Connect-VIServer -Server v01vsiapl007.countrylan.com -User ID93137 -Password $pw
#>
                      
                           

$server = "V01DBSWIN517"


<# Restart a VM
    Get-VM -Name $server | Restart-VM
    Get-VM -Name V01DBSWIN045 | Restart-VM
#>


<#  Create a snapshot (does not save memory by default)
    New-Snapshot -VM $server -Name "$server PreInstall $(Get-Date -Format yyyyMMdd)" -Description "Snapshot prior to SQL install"
#>


<#  List snapshots for servers
    Get-VM | Where Name -like "*DBD*" | Get-Snapshot | Select vm, name, description, created, sizegb
    Get-VM | Where Name -like "*DBS*" | Get-Snapshot | Select vm, name, description, created, sizegb
#>


<#  Remove all snapshots from specific machine
    Get-VM -Name $server | Get-Snapshot | Remove-Snapshot
#>


<#  Delete a snapshot from server
    $vm = Get-VM -Name $server
    $snapshot = $vm | Get-Snapshot
    $snapshot | Remove-Snapshot
#>


<#  Revert to snapshot
    $vm = Get-VM -Name $server
    $snapshot = $vm | Get-Snapshot
    Set-VM -VM $vm -Snapshot $snapshot
    $vm | Start-VM
#>


<# Set the network adapter to "connected" to allow access
    $vm | Get-NetworkAdapter | Set-NetworkAdapter -Connected:$true    
#>

<#  Search all VM's by Name LIKE xxx
    $vmlist = Get-VM | Where Name -like "*AWH*" | Select Name, Guest, NumCpu, CoresPerSocket, MemoryGB, VMHost
    $vmlist += Get-VM | Where Name -like "*DBD*" | Select Name, Guest, NumCpu, CoresPerSocket, MemoryGB, VMHost
    $vmlist += Get-VM | Where Name -like "*DBS*" | Select Name, Guest, NumCpu, CoresPerSocket, MemoryGB, VMHost
#>

<#  Help 
Log in to a vCenter Server or ESX host:              Connect-VIServer
To find out what commands are available, type:       Get-VICommand
To show searchable help for all PowerCLI commands:   Get-PowerCLIHelp
Once you've connected, display all virtual machines: Get-VM
#>

