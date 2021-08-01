<#
1.  C:\Program files*\Microsoft SQL Server\MSSQL*.MSSQLSERVER\MSSQL\Bin*
    C:\Program files*\Microsoft SQL Server\*\Tools\Bin* 
    C:\Program files*\Microsoft SQL Server\*\COM
    a.	FULL Control
        i.	Builtin/Administrators
        ii.	CREATOR OWNER
        iii.	NT AUTHORITY\SYSTEM
        iv.	NT SERVICE\TrustedInstaller
    b.	Read and Execute
        i.	ServerName\SQLServerDTSUser$ServerName
        ii.	ServerName\SQLServerMSSQLUser$ServerName$MSSQLSERVER
        iii.	ServerName\SQLServerReportServerUser$ServerName$MSRS*.MSSQLSERVER
        iv.	MSSQLFDLauncher
2.	C:\Program Files*\Microsoft SQL Server
    a.	Read, Write, Special
        i.	ServerName\SQLServerReportServerUser$ServerName$MSRS*.MSSQLSERVER
    b.	FULL Control
        i.	Builtin\Administrators
        ii.	NT AUTHORITY\SYSTEM
3.	E: (and greater)\Data\MSSQL* 
    a.	Full Control
        i.	Builtin/Administrators
        ii.	CREATOR OWNER
        iii.	NT AUTHORITY\SYSTEM
        iv.	NT SERVICE\TrustedInstaller
        v.	NT Service\MSSQLFDLauncher
        vi.	ServerName\SQLServerMSSQLUser$ServerName$MSSQLSERVER

#>

$servername = $env:COMPUTERNAME

# 1
((Get-ChildItem "C:\Program files*\Microsoft SQL Server\MSSQL*.MSSQLSERVER\MSSQL\Bin*").GetAccessControl('Access')).Access | Where AccessControlType -eq "Allow" | Select IdentityReference, FileSystemRights

# 2
$paths = (Get-ChildItem "C:\Program Files*\Microsoft SQL Server")
foreach ($path in $paths)
{
    $path.Fullname

    $acl = Get-Acl $path.FullName
    $acl.SetAccessRuleProtection($true,$true)
    Set-Acl -Path $path -AclObject $acl

    $acl = Get-Acl $path
    $acl.Access | %{$acl.RemoveAccessRule($_)} | Out-Null

    $ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Builtin\Administrators", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($ar)

    $ar = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($ar)
    <#
    if ($path.FullName -like '*Shared*')
    {
        $ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Builtin\Users", 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($ar)
    }
    #>
    Set-Acl -Path $path -AclObject $acl
}

#((Get-ChildItem "C:\Program Files*\Microsoft SQL Server").GetAccessControl('Access')).Access | Where AccessControlType -eq "Allow" | Select IdentityReference, FileSystemRights

# 3
Get-WmiObject Win32_LogicalDisk | Select DeviceID | Foreach {
    $path = $_.DeviceID + "\Data\MSSQL*"
    If (Test-Path $path) {
        $path
        ((Get-ChildItem $path).GetAccessControl('Access')).Access | Where AccessControlType -eq "Allow" | Select IdentityReference, FileSystemRights
    }
}
<#
Get-Acl "C:\Program files*\Microsoft SQL Server\MSSQL*.MSSQLSERVER\MSSQL\Bin*" | Select AccessToString -ExpandProperty AccessToString
Get-Acl "C:\Program Files*\Microsoft SQL Server" | Select AccessToString -ExpandProperty AccessToString
Get-WmiObject Win32_LogicalDisk | Select DeviceID | Foreach {
    $path = $_.DeviceID + "\Data\MSSQL*"
    If (Test-Path $path) {
        $path
        $path | Get-Acl | Select AccessToString -ExpandProperty AccessToString
    }
}
#>    