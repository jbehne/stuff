<# SQL Permissions.ps1                                                            
###############################################################################
 This program does the following:                                              
   1) Displays a GUI to install SQL Server version 2012+                                        
###############################################################################
 INPUT PARMS:                                                                  
    None                                                                       
###############################################################################
 PROGRAM HISTORY                                                               
                                                                               
 NAME      DATE         DESCRIPTION                                            
 Jeremy    26JUN18      New program.    
 Jeremy    12AUG18      Added option to specify tempdb location
 Jeremy    16AUG18      Disabled E: selection for user data  
 Jeremy    21AUG18      Add check for pending reboot            
 Jeremy    29AUG18      Sending SERVINFO file to OLDSERVERS while new naming
                        standard cannot be inserted.     
 Jeremy    04SEP18      Added SSMS2016, SSDT2015, z_pmrwac account support
                        for all domains, and the ability to install components
                        individually without selecting the engine.
 Jeremy    04SEP18      Added function to handle copying SQL 2012 SP4 to
                        the local server and initiating install due to issues
                        with slipstream and network issues from share.                                                                  
################################################################################>


#region XAML Setup
$xmlWPF = [System.Xml.XmlDocument]@"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="SQL Server Installer" Height="590" Width="380">
    <Grid>
        <GroupBox Name="groupBox" Header="Version Info" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" Height="88" Width="350"/>
        <Label Name="label" Content="Version" HorizontalAlignment="Left" Margin="27,37,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbSQLVersion" HorizontalAlignment="Left" Margin="117,37,0,0" VerticalAlignment="Top" Width="230"/>
        <Label Name="label2" Content="Edition" HorizontalAlignment="Left" Margin="27,64,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbSQLEdition" HorizontalAlignment="Left" Margin="117,64,0,0" VerticalAlignment="Top" Width="230"/>

        <GroupBox Name="groupBox2" Header="Feature Selection" HorizontalAlignment="Left" Margin="10,103,0,0" VerticalAlignment="Top" Height="127" Width="350"/>
        <CheckBox Name="cbSSEngine" Content="SQL Engine" HorizontalAlignment="Left" Margin="27,130,0,0" VerticalAlignment="Top" IsChecked="True"/>
        <CheckBox Name="cbIS" Content="Integration Services" HorizontalAlignment="Left" Margin="202,130,0,0" VerticalAlignment="Top"/>
        <CheckBox Name="cbFT" Content="Fulltext Search" HorizontalAlignment="Left" Margin="27,153,0,0" VerticalAlignment="Top"/>
        <CheckBox Name="cbRS" Content="Reporting Services" HorizontalAlignment="Left" Margin="202,153,0,0" VerticalAlignment="Top"/>
        <CheckBox Name="cbAS" Content="Analysis Services" HorizontalAlignment="Left" Margin="27,176,0,0" VerticalAlignment="Top"/>
        <CheckBox Name="cbSSDT" Content="SQL Data Tools" HorizontalAlignment="Left" Margin="202,176,0,0" VerticalAlignment="Top"/>
        <CheckBox Name="cbSSMS2016" Content="SSMS 2016" HorizontalAlignment="Left" Margin="27,199,0,0" VerticalAlignment="Top"/>
        <CheckBox Name="cbSSMS2017" Content="SSMS 2017" HorizontalAlignment="Left" Margin="202,199,0,0" VerticalAlignment="Top"/>

        <GroupBox Name="groupBox1" Header="Directories" HorizontalAlignment="Left" Margin="10,235,0,0" VerticalAlignment="Top" Width="349" Height="150"/>
        <Label Name="label1" Content="System" HorizontalAlignment="Left" Margin="27,261,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbSystemDir" HorizontalAlignment="Left" Margin="117,261,0,0" VerticalAlignment="Top" Width="230"/>
        <Label Name="label4" Content="User Data" HorizontalAlignment="Left" Margin="27,288,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbUserDataDir" HorizontalAlignment="Left" Margin="117,288,0,0" VerticalAlignment="Top" Width="230"/>
        <Label Name="label5" Content="User Log" HorizontalAlignment="Left" Margin="27,315,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbUserLogDir" HorizontalAlignment="Left" Margin="117,315,0,0" VerticalAlignment="Top" Width="230"/>
        <Label Name="label5_Copy" Content="TempDB" HorizontalAlignment="Left" Margin="27,342,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbTempDBDir" HorizontalAlignment="Left" Margin="117,342,0,0" VerticalAlignment="Top" Width="230"/>

        <GroupBox Name="groupBox3" Header="Account Information" HorizontalAlignment="Left" Margin="10,390,0,0" VerticalAlignment="Top" Width="349" Height="118"/>
        <Label Name="label6" Content="Environment" HorizontalAlignment="Left" Margin="27,419,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbEnvironment" HorizontalAlignment="Left" Margin="117,419,0,0" VerticalAlignment="Top" Width="230"/>
        <Label Name="label9" Content="SVC Account Name" HorizontalAlignment="Left" Margin="27,446,0,0" VerticalAlignment="Top"/>
        <TextBox Name="txtSVCAccountName" HorizontalAlignment="Left" Height="23" Margin="163,446,0,0" VerticalAlignment="Top" Width="184"/>
        <Label Name="label10" Content="SVC Account Password" HorizontalAlignment="Left" Margin="27,472,0,0" VerticalAlignment="Top"/>
        <PasswordBox Name="txtSVCAccountPassword" HorizontalAlignment="Left" Height="23" Margin="163,472,0,0" VerticalAlignment="Top" Width="184"/>

        <CheckBox Name="cbSERVINFO" Content="Add to SERVINFO" Margin="10,525,218,10" IsChecked="True"/>
        <Button Name="btnInstall" Content="Install" HorizontalAlignment="Left" Margin="280,525,0,0" VerticalAlignment="Top" Width="75"/>
    </Grid>
</Window>
"@

try 
{
    Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms
} 

catch 
{
    Throw "Failed to load Windows Presentation Framework assemblies."
}

$xamGUI = [Windows.Markup.XamlReader]::Load((new-object System.Xml.XmlNodeReader $xmlWPF))
$xmlWPF.SelectNodes("//*[@Name]") | % { Set-Variable -Name ($_.Name) -Value $xamGUI.FindName($_.Name) -Scope Global }

$SQLConfigurationFile = "E:\INI\SQLConfig.cfg"
if ((Test-Path "E:\INI") -ne $true)
{
    New-Item -ItemType Directory -Path E:\INI | Out-Null
}

if (Test-Path $SQLConfigurationFile)
{
    Remove-Item $SQLConfigurationFile
}

$ButtonTypeOK = [System.Windows.MessageBoxButton]::OK
$ButtonTypeYesNo = [System.Windows.MessageBoxButton]::YesNo
$MessageIcon = [System.Windows.MessageBoxImage]::Error

$cbSQLVersion.Items.Add("SQL Server 2017") | Out-Null
$cbSQLVersion.Items.Add("SQL Server 2016") | Out-Null
$cbSQLVersion.Items.Add("SQL Server 2014") | Out-Null
$cbSQLVersion.Items.Add("SQL Server 2012") | Out-Null
#$cbSQLVersion.Items.Add("SQL Server 2008 R2") | Out-Null

$cbSQLEdition.Items.Add("Standard") | Out-Null
$cbSQLEdition.Items.Add("Enterprise") | Out-Null

$cbEnvironment.Items.Add("Production") | Out-Null
$cbEnvironment.Items.Add("Test/QA") | Out-Null

$drives = (Get-WmiObject Win32_LogicalDisk).DeviceID
foreach ($d in $drives)
{
    if ($d -ne "C:" -and $d -ne "D:" -and $d -ne "U:" -and $d -ne "A:")
    {
        $cbSystemDir.Items.Add($d + "\Data") | Out-Null

        if ($d -ne "E:")
        {
            $cbUserDataDir.Items.Add($d + "\Data") | Out-Null
            $cbUserLogDir.Items.Add($d + "\Data") | Out-Null
            $cbTempDBDir.Items.Add($d + "\Data") | Out-Null
        }
    }
}

$cbSystemDir.SelectedIndex = 0 | Out-Null
<#
$cbUserDataDir.SelectedIndex = 0 | Out-Null
$cbUserLogDir.SelectedIndex = 0 | Out-Null
#>
#endregion

#region functions
function Install-2012SP4
{
    Copy-Item "U:\SERVICEPACKS\SQL2012-SP4\SQLServer2012SP4-KB4018073-x64-ENU.exe" "C:\temp"
    Start-Process -FilePath 'C:\temp\SQLServer2012SP4-KB4018073-x64-ENU.exe' -ArgumentList "/IAcceptSQLServerLicenseTerms /qs /SkipRules=RebootRequiredCheck /Action=Patch /InstanceName=MSSQLSERVER" -Wait
}

function Test-PendingReboot
{
    if (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { return $true }
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") { return $true }
    if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations") { return $true }
    try 
    { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if(($status -ne $null) -and $status.RebootPending)
        {
            return $true
        }
    }
    
    catch{}

    return $false
}

function Create_SERVINFO_File ($log)
{
    "INF:     Creating new SERVINFO server file" | Out-File $log -Append

    $server = $env:ComputerName
    $version = (Invoke-SqlCmd -ServerInstance . -Query "select serverproperty('productversion') version").version
    $user = $env:USERNAME
    $file = "V:\" + $server

    $stmts = "INSERT INTO CCDB2.MDB_SRVR_DATA (SRVR_NM) VALUES ('" + $server + "');`r`n" 
    $stmts += "INSERT INTO CCDB2.MDB_DBMS_DATA (SRVR_NM, DBMS_INSTANCE_NM, DBMS, DBMS_TYP, DBMS_VER, INSTALL_DT, INSTALLER_USERID, COUNT_LICENSE, WEB_ENABLED_FLG) VALUES ('" + $server + "', 'SQL', 'SQL', 'SQL SERVER', '" + $version + "', current date, '" + $user + "', 'Y', 'N');`r`n" 
    $stmts += "UPDATE CCDB2.MDB_DBMS_DATA SET DBMS_VER = '" + $version + "', Install_dt = current date, INSTALLER_USERID = '" + $user + "' WHERE SRVR_NM = '" + $server + "' AND DBMS_INSTANCE_NM = 'SQL' AND DBMS = 'SQL' AND DBMS_TYP = 'SQL SERVER';" 

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($file, $stmts, $Utf8NoBomEncoding)

    "INF:     Completed Creating new SERVINFO server file at $file" | Out-File $log -Append
}

function CreateSQLADMIN ($log)
{
    "INF:     Creating SQLADMIN database" | Out-File $log -Append
    Invoke-SqlCmd -ServerInstance . -Database master -Query "CREATE DATABASE SQLADMIN;"
    Invoke-SqlCmd -ServerInstance . -Database master -Query "ALTER DATABASE [SQLADMIN] SET RECOVERY SIMPLE WITH NO_WAIT"
    Invoke-SqlCmd -ServerInstance . -Database master -Query "ALTER DATABASE [SQLADMIN] MODIFY FILE ( NAME = N'SQLADMIN', MAXSIZE = 5GB , FILEGROWTH = 100MB )"
    Invoke-SqlCmd -ServerInstance . -Database master -Query "ALTER DATABASE [SQLADMIN] MODIFY FILE ( NAME = N'SQLADMIN_log', MAXSIZE = 5GB , FILEGROWTH = 100MB )"
    Invoke-SqlCmd -ServerInstance . -Database master -Query "ALTER AUTHORIZATION ON DATABASE::[SQLADMIN] TO [CCSAID]"
    
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile 'U:\SQL monitor code\Instance Objects.sql'

    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_Blitz.sql                        
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_BlitzBackups.sql                    
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_BlitzCache.sql                      
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_BlitzFirst.sql                      
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_BlitzIndex.sql                      
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_BlitzLock.sql                       
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_BlitzWho.sql                        
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_DatabaseRestore.sql                 
    Invoke-SqlCmd -ServerInstance . -Database SQLADMIN -InputFile U:\FirstResponderKit\sp_foreachdb.sql   

    Copy-Item 'U:\SQL monitor code\PS_Perf_CollectCounters.ps1' E:\
    "INF:     Completed creating SQLADMIN database" | Out-File $log -Append
}

function SetNTFSSecurity($log)
{
    "INF:     Setting NTFS file permissions" | Out-File $log -Append
    Copy-Item "U:\SQL Permissions.ps1" C:\temp
    & "C:\temp\SQL Permissions.ps1"
    "INF:     Completed Setting NTFS file permissions" | Out-File $log -Append
}

function CleanUpCEIP($log)
{
    if ($cbSQLVersion.SelectedValue -eq "SQL Server 2016" -or $cbSQLVersion.SelectedValue -eq "SQL Server 2017")
    {
        "INF:     Remove CEIP/Telemetry objects and disable services" | Out-File $log -Append

        Get-Service |? name -Like "SQLTELEMETRY*" | ? status -eq "running" | Stop-Service
        Get-Service |? name -Like "SSASTELEMETRY*" | ? status -eq "running" | Stop-Service
        Get-Service |? name -Like "SSISTELEMETRY*" | ? status -eq "running" | Stop-Service

        Get-Service |? name -Like "SQLTELEMETRY*" | Set-Service -StartMode Disabled
        Get-Service |? name -Like "SSASTELEMETRY*" | Set-Service -StartMode Disabled
        Get-Service |? name -Like "SSISTELEMETRY*" | Set-Service -StartMode Disabled

        $Key = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server'
        $FoundKeys = Get-ChildItem $Key -Recurse | Where-Object -Property Property -eq 'EnableErrorReporting'
        foreach ($Sqlfoundkey in $FoundKeys)
        {
            $SqlFoundkey | Set-ItemProperty -Name EnableErrorReporting -Value 0
            $SqlFoundkey | Set-ItemProperty -Name CustomerFeedback -Value 0
        }

        $WowKey = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server"
        $FoundWowKeys = Get-ChildItem $WowKey | Where-Object -Property Property -eq 'EnableErrorReporting'
        foreach ($SqlFoundWowKey in $FoundWowKeys)
        {
            $SqlFoundWowKey | Set-ItemProperty -Name EnableErrorReporting -Value 0
            $SqlFoundWowKey | Set-ItemProperty -Name CustomerFeedback -Value 0
        }

		Invoke-Sqlcmd -ServerInstance . -Query "REVOKE CONNECT SQL TO [NT SERVICE\SQLTELEMETRY]"
		Invoke-Sqlcmd -ServerInstance . -Query "ALTER LOGIN [NT SERVICE\SQLTELEMETRY] DISABLE"
		Invoke-Sqlcmd -ServerInstance . -Query "DROP LOGIN [NT SERVICE\SQLTELEMETRY]"
        "INF:     Completed removal of CEIP/Telemetry objects and disable services" | Out-File $log -Append
    }
}

function EngineConfiguration($log)
{
    $SQLPSModule = (Get-ChildItem -Recurse -Path "C:\Program Files (x86)\Microsoft SQL Server" | Where {$_.Name -eq "SQLPS"} | Select FullName).FullName
    $SQLPSModule = $SQLPSModule.Replace("\SQLPS","")
    if ($SQLPSModule -eq $null)
    {
        "ERR:     SQLPS module not found after installation" | Out-File $log -Append
        [System.Windows.MessageBox]::Show("SQLPS module not found after installation","Installation Error",$ButtonTypeOK,$MessageIcon)        
        return;
    }
    
    "INF:     Loading SQLPS Module at $SQLPSModule" | Out-File $log -Append
    $env:PSModulePath = $env:PSModulePath + ";$SQLPSModule"
    Import-Module "sqlps" -DisableNameChecking
    "INF:     Completed Loading SQLPS Module" | Out-File $log -Append

    $ServerMemory = (Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum  / 1073741824
    $SQLMaxMemory = [Math]::Round(($ServerMemory * .80) * 1000)
    $tempdbCapacity = [Math]::Round((Get-WmiObject Win32_Volume | Where Name -eq $cbTempDBDir.SelectedValue.Substring(0,3) | Select Capacity).Capacity / 1073741824)
    $tempdbFileMax = [Math]::Round($tempdbCapacity * .30)
    $tempdbLogMax = [Math]::Round($tempdbCapacity * .40)

    "INF:     Total server memory is $ServerMemory" | Out-File $log -Append
    "INF:     SQL Max Memory to be set to $SQLMaxMemory" | Out-File $log -Append
    "INF:     TempDB drive capacity is $tempdbCapacity" | Out-File $log -Append
    "INF:     TempDB data file max to be set to $tempdbFileMax" | Out-File $log -Append
    "INF:     TempDB log file max to be set to $tempdbLogMax" | Out-File $log -Append

    Invoke-Sqlcmd -ServerInstance . -Query "exec sp_configure 'show advanced options', 1 "
    Invoke-Sqlcmd -ServerInstance . -Query "RECONFIGURE"
    Invoke-Sqlcmd -ServerInstance . -Query "EXEC sys.sp_configure N'max server memory (MB)', N'$SQLMaxMemory'"
    Invoke-Sqlcmd -ServerInstance . -Query "exec sp_configure 'database mail xps', 1"
    Invoke-Sqlcmd -ServerInstance . -Query "RECONFIGURE"
    Invoke-Sqlcmd -ServerInstance . -Query "EXEC msdb.dbo.sysmail_add_account_sp @account_name = 'DBA Alert Email Account', @description= 'Mail account for sending e-mail alerts.', @email_address = 'dbasupp@countryfinancial.com',@mailserver_name = 'inesg2.alliance.lan',@use_default_credentials = 1"
    Invoke-Sqlcmd -ServerInstance . -Query "EXEC msdb.dbo.sysmail_add_profile_sp @profile_name = 'DBA Alert Email Profile', @description= 'Profile used for alert mail.' "
    Invoke-Sqlcmd -ServerInstance . -Query "EXEC msdb.dbo.sysmail_add_profileaccount_sp @profile_name = 'DBA Alert Email Profile', @account_name = 'DBA Alert Email Account', @sequence_number =1"
    Invoke-Sqlcmd -ServerInstance . -Query "EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1"
    Invoke-Sqlcmd -ServerInstance . -Query "EXEC master.dbo.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', N'UseDatabaseMail', N'REG_DWORD', 1"
    Invoke-Sqlcmd -ServerInstance . -Query "EXEC master.dbo.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', N'DatabaseMailProfile', N'REG_SZ', N'DBA Alert Email Profile'"
    Invoke-Sqlcmd -ServerInstance . -Query "EXEC msdb.dbo.sysmail_add_principalprofile_sp @principal_name = 'public', @profile_name = 'DBA Alert Email Profile', @is_default = 1"
    Invoke-Sqlcmd -ServerInstance . -Query "exec msdb.dbo.sp_add_operator @name = 'DBASUPP', @enabled = 1, @email_address = 'DBASUPP@countryfinancial.com'"
    Invoke-Sqlcmd -ServerInstance . -Query "exec sp_configure 'show advanced options', 0"
    Invoke-Sqlcmd -ServerInstance . -Query "RECONFIGURE"
    Invoke-Sqlcmd -ServerInstance . -Query "ALTER LOGIN sa WITH NAME = CCsaid"
    Invoke-Sqlcmd -ServerInstance . -Query "ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', SIZE = 102400KB , FILEGROWTH = 102400KB )"
    Invoke-Sqlcmd -ServerInstance . -Query "ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', SIZE = 102400KB , FILEGROWTH = 102400KB )"

    Invoke-Sqlcmd -ServerInstance . -Query "ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', SIZE = 102400KB , FILEGROWTH = 102400KB , MAXSIZE = $tempdbFileMax`GB )"
    Invoke-Sqlcmd -ServerInstance . -Query "ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'templog', SIZE = 102400KB , FILEGROWTH = 102400KB , MAXSIZE = $tempdbLogMax`GB)"
    Invoke-Sqlcmd -ServerInstance . -Query "
        DECLARE @file nvarchar(max);
        SELECT @file = REPLACE(physical_name, '.mdf', '2.ndf') 
        FROM sys.master_files
        WHERE name = 'tempdev'

        SET @file = 'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdev2'', FILENAME = ''' + @file + ''', SIZE = 102400KB , FILEGROWTH = 102400KB , MAXSIZE = $tempdbFileMax`GB )'
        EXEC sp_executesql @file"

    if ($cbSQLVersion.SelectedValue -eq "SQL Server 2014" -or $cbSQLVersion.SelectedValue -eq "SQL Server 2012")
    {
        "INF:     Moving TempDB for 2012/2014" | Out-File $log -Append
        Invoke-Sqlcmd -ServerInstance . -Query "ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', FILENAME='$($cbTempDBDir.SelectedValue)\tempdev.mdf')"
        Invoke-Sqlcmd -ServerInstance . -Query "ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev2', FILENAME='$($cbTempDBDir.SelectedValue)\tempdev2.ndf')"
        Invoke-Sqlcmd -ServerInstance . -Query "ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'templog', FILENAME='$($cbTempDBDir.SelectedValue)\templog.ldf')"
        Get-Service -Name MSSQLSERVER | Restart-Service -Force
        Get-Service -Name SQLSERVERAGENT | Start-Service
        "INF:     Completed moving TempDB for 2012/2014" | Out-File $log -Append
    }

    Invoke-Sqlcmd -ServerInstance . -Query "DROP LOGIN ##MS_PolicyEventProcessingLogin##" 
    Invoke-Sqlcmd -ServerInstance . -Query "DROP LOGIN ##MS_PolicyTsqlExecutionLogin##" 

    $domain = (Get-WmiObject Win32_ComputerSystem).Domain
    "INF:     Domain is $domain" | Out-File $log -Append

    switch ($domain)
    {
        "alliancedev.lan" { $login = "[ALLIANCEDEV\z_pmrwac]" }
        "allianceqa.lan" { $login = "[ALLIANCEQA\z_pmrwac]" }
        "corp.alliance.tst" { $login = "[ALLIANCETCORP\z_pmrwac]" }
        "corp.alliance.lan" { $login = "[ALLIANCE\z_pmrwac]" }
        "fs.alliance.tst" { $login = "[FINANCIALDEV\z_pmrwac]" }
        "fs.alliance.lan" { $login = "[FINANCIAL\z_pmrwac]" }
    }

    Invoke-Sqlcmd -ServerInstance . -Query "CREATE LOGIN $login FROM WINDOWS"
    Invoke-Sqlcmd -ServerInstance . -Query "GRANT VIEW SERVER STATE TO $login"
    "INF:     Created login $login" | Out-File $log -Append
}

#endregion

#region event handlers
$btnInstall.add_Click({
    $btnInstall.IsEnabled = $false

    if ($cbSSEngine.IsChecked -and ($cbSystemDir.SelectedIndex -eq -1 -or $cbUserDataDir.SelectedIndex -eq -1 -or $cbUserLogDir.SelectedIndex -eq -1 -or $cbTempDBDir.SelectedIndex -eq -1))
    {
        [System.Windows.MessageBox]::Show("One or more directories are not set","Input Error",$ButtonTypeOK,$MessageIcon)
        $btnInstall.IsEnabled = $true
        return;
    }

    if ($cbSQLVersion.SelectedIndex -eq -1 -or $cbSQLEdition.SelectedIndex -eq -1 -or $cbEnvironment.SelectedIndex -eq -1)
    {
        [System.Windows.MessageBox]::Show("Version, Edition, or Environment not set","Input Error",$ButtonTypeOK,$MessageIcon)
        $btnInstall.IsEnabled = $true
        return;
    }

    if ($txtSVCAccountName.Text -eq "" -or $txtSVCAccountPassword.Password -eq "")
    {
        [System.Windows.MessageBox]::Show("Service account name or password not set","Input Error",$ButtonTypeOK,$MessageIcon)
        $btnInstall.IsEnabled = $true
        return;
    }

    Write-Host "Installation has started, do not close the window until completion!" -ForegroundColor DarkRed -BackgroundColor White

    $log = "E:\SQLInstallLog_" + $(Get-Date -Format yyyyMMdd-hhmmss) + ".log"
    "INF: Beginning SQL Server Installation " + $(Get-Date -Format yyyy/MM/dd-hh:mm:ss) | Out-File $log -Append
    "INF: Selections:" | Out-File $log -Append
    "INF:     Version: " + $cbSQLVersion.SelectedValue | Out-File $log -Append
    "INF:     Edition: " + $cbSQLEdition.SelectedValue | Out-File $log -Append

    if ($cbSSEngine.IsChecked)
    {
        "INF:     System Directory: " + $cbSystemDir.SelectedValue | Out-File $log -Append
        "INF:     Data Directory: " + $cbUserDataDir.SelectedValue | Out-File $log -Append
        "INF:     Log Directory: " + $cbUserLogDir.SelectedValue | Out-File $log -Append
        "INF:     TempDB Directory: " + $cbTempDBDir.SelectedValue | Out-File $log -Append
        "INF:     Environment: " + $cbEnvironment.SelectedValue | Out-File $log -Append
    }

    "INF:     Service Account: " + $txtSVCAccountName.Text | Out-File $log -Append
    "INF:     Selected Features: " | Out-File $log -Append

    if ($cbFT.IsChecked)
    {
        "INF:         FULLTEXT" | Out-File $log -Append
    }

    if ($cbIS.IsChecked)
    {
        "INF:         Integration Services" | Out-File $log -Append
    }

    if ($cbRS.IsChecked)
    {
        "INF:         Reporting Services" | Out-File $log -Append
    }

    if ($cbAS.IsChecked)
    {
        "INF:         Analysis Services" | Out-File $log -Append
    }

    if ($cbSSMS2016.IsChecked)
    {
        "INF:         SQL Management Studio 2016" | Out-File $log -Append
    }

    if ($cbSSMS2017.IsChecked)
    {
        "INF:         SQL Management Studio 2017" | Out-File $log -Append
    }

    if ($cbSSDT.IsChecked)
    {
        "INF:         SQL Server Data Tools" | Out-File $log -Append
    }

    
    if ($cbSSEngine.IsChecked)
    {
        "INF:         SQL Engine" | Out-File $log -Append

        if ((Get-WmiObject Win32_Volume | Where DriveLetter -eq $cbUserDataDir.SelectedItem.Substring(0,2) | Select BlockSize).BlockSize -ne 65536)
        {
            $result = [System.Windows.MessageBox]::Show("Block size not set to 64k on selected User Data Disk, continue?","Incorrect Block Size",$ButtonTypeYesNo,$MessageIcon)
            if ($result -eq "No")
            {
                "ERR: Block size not set to 64k on selected User Data Disk" | Out-File $log -Append
                $btnInstall.IsEnabled = $true
                return;
            }

            else
            {
                "WRN: Block size not set to 64k on selected User Data Disk" | Out-File $log -Append
            }
        }

        if ((Get-WmiObject Win32_Volume | Where DriveLetter -eq $cbUserLogDir.SelectedItem.Substring(0,2) | Select BlockSize).BlockSize -ne 65536)
        {
            $result = [System.Windows.MessageBox]::Show("Block size not set to 64k on selected User Log Disk, continue?","Incorrect Block Size",$ButtonTypeYesNo,$MessageIcon)
            if ($result -eq "No")
            {
                "ERR: Block size not set to 64k on selected User Log Disk" | Out-File $log -Append
                $btnInstall.IsEnabled = $true
                return;
            }

            else
            {
                "WRN: Block size not set to 64k on selected User Log Disk" | Out-File $log -Append
            }
        }

        if ((Get-WmiObject Win32_Volume | Where DriveLetter -eq $cbTempDBDir.SelectedItem.Substring(0,2) | Select BlockSize).BlockSize -ne 65536)
        {
            $result = [System.Windows.MessageBox]::Show("Block size not set to 64k on selected Temp DB Disk, continue?","Incorrect Block Size",$ButtonTypeYesNo,$MessageIcon)
            if ($result -eq "No")
            {
                "ERR: Block size not set to 64k on selected Temp DB Disk" | Out-File $log -Append
                $btnInstall.IsEnabled = $true
                return;
            }

            else
            {
                "WRN: Block size not set to 64k on selected Temp DB Disk" | Out-File $log -Append
            }
        }
    }

    if ($cbSSEngine.IsChecked -or $cbIS.IsChecked -or $cbAS.IsChecked -or $cbRS.IsChecked)
    {
        "INF: Creating SQL Configuration file $SQLConfigurationFile" | Out-File $log -Append

        $InstallString = ""
        '[OPTIONS]' | Out-File $SQLConfigurationFile -Append
    
        if ($cbSQLVersion.SelectedValue -eq "SQL SERVER 2008 R2" -or $cbSQLVersion.SelectedValue -eq "SQL SERVER 2012" -or $cbSQLVersion.SelectedValue -eq "SQL SERVER 2014")
        {
            $Features = "BC,Conn,SSMS,ADV_SSMS,"
            'ERRORREPORTING=0' | Out-File $SQLConfigurationFile -Append
        }

        else
        {
            $Features = ""
            'SQLTEMPDBFILECOUNT=1' | Out-File $SQLConfigurationFile -Append
            'SQLTEMPDBFILEGROWTH=100' | Out-File $SQLConfigurationFile -Append
            'SQLTEMPDBFILESIZE=100' | Out-File $SQLConfigurationFile -Append
            'SQLTEMPDBLOGFILEGROWTH=100' | Out-File $SQLConfigurationFile -Append
            'SQLTEMPDBLOGFILESIZE=100' | Out-File $SQLConfigurationFile -Append
            'SQLTEMPDBDIR=' + $cbTempDBDir.SelectedValue | Out-File $SQLConfigurationFile -Append
        }

        'Action="Install"' | Out-File $SQLConfigurationFile -Append
        'ENU="True"' | Out-File $SQLConfigurationFile -Append
        'QUIET="True"' | Out-File $SQLConfigurationFile -Append
        'UpdateEnabled="True"' | Out-File $SQLConfigurationFile -Append
        'UpdateSource="U:\SLIPSTREAM"' | Out-File $SQLConfigurationFile -Append
        'INDICATEPROGRESS="True"' | Out-File $SQLConfigurationFile -Append
        'INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"' | Out-File $SQLConfigurationFile -Append
        'INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"' | Out-File $SQLConfigurationFile -Append
        'INSTANCENAME="MSSQLSERVER"' | Out-File $SQLConfigurationFile -Append
        'SQMREPORTING="False"' | Out-File $SQLConfigurationFile -Append
        'INSTANCEID="MSSQLSERVER"' | Out-File $SQLConfigurationFile -Append
        'INSTANCEDIR="C:\Program Files\Microsoft SQL Server"' | Out-File $SQLConfigurationFile -Append
        'SECURITYMODE="SQL"' | Out-File $SQLConfigurationFile -Append
        'ADDCURRENTUSERASSQLADMIN="False"' | Out-File $SQLConfigurationFile -Append
        'SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"' | Out-File $SQLConfigurationFile -Append
        'BROWSERSVCSTARTUPTYPE="Disabled"' | Out-File $SQLConfigurationFile -Append
        'INSTALLSQLDATADIR=' + $cbSystemDir.SelectedValue | Out-File $SQLConfigurationFile -Append

        $SVCACCOUNTNAME = $txtSVCAccountName.Text
        $SVCACCOUNTPWD = $txtSVCAccountPassword.Password

        if ($cbSSEngine.IsChecked)
        {
            'SQLUSERDBDIR=' + $cbUserDataDir.SelectedValue | Out-File $SQLConfigurationFile -Append
            'SQLUSERDBLOGDIR=' + $cbUserLogDir.SelectedValue | Out-File $SQLConfigurationFile -Append
            'AGTSVCSTARTUPTYPE="Automatic"' | Out-File $SQLConfigurationFile -Append
            'SQLSVCSTARTUPTYPE="Automatic"' | Out-File $SQLConfigurationFile -Append
            'SQLSVCACCOUNT="' + $SVCACCOUNTNAME + '" ' | Out-File $SQLConfigurationFile -Append
            'AGTSVCACCOUNT="' + $SVCACCOUNTNAME + '" ' | Out-File $SQLConfigurationFile -Append

            if ($cbEnvironment.SelectedValue -eq "Production")
            {
                'SQLSYSADMINACCOUNTS="ALLIANCE\DBA Sensitive Server Users" "' + $SVCACCOUNTNAME + '" "ALLIANCE\Z_DWGATH" "ALLIANCE\z_PwMgtSql"'  | Out-File $SQLConfigurationFile -Append
            }

            else
            {
                'SQLSYSADMINACCOUNTS="ALLIANCE\DBA Sensitive Server Users" "' + $SVCACCOUNTNAME + '" "ALLIANCE\ZT_DWGATH" "ALLIANCE\z_PwMgtSql"'  | Out-File $SQLConfigurationFile -Append
            }

            $Features += "SQLEngine,Replication,"
            $InstallString += '/SAPWD="6d83WN+:U2hb>]c" '
            $InstallString += '/SQLSVCPASSWORD="' + $SVCACCOUNTPWD + '" '
            $InstallString += '/AGTSVCPASSWORD="' + $SVCACCOUNTPWD + '" '
        }

        if ($cbFT.IsChecked)
        {
            $Features += "FULLTEXT,"
        }

        if ($cbIS.IsChecked)
        {
            'ISSVCSTARTUPTYPE="Automatic"' | Out-File $SQLConfigurationFile -Append
            'ISSVCACCOUNT="' + $SVCACCOUNTNAME + '" ' | Out-File $SQLConfigurationFile -Append
            $Features += "IS,"
            $InstallString += '/ISSVCPASSWORD="' + $SVCACCOUNTPWD + '" '
        }

        if ($cbRS.IsChecked -and $cbSQLVersion.SelectedValue -ne "SQL Server 2017")
        {
            'RSSVCSTARTUPTYPE="Automatic"' | Out-File $SQLConfigurationFile -Append
            'RSINSTALLMODE="DefaultNativeMode"' | Out-File $SQLConfigurationFile -Append
            'RSSVCACCOUNT="' + $SVCACCOUNTNAME + '" ' | Out-File $SQLConfigurationFile -Append
            $Features += "RS,"
            $InstallString += '/RSSVCPASSWORD="' + $SVCACCOUNTPWD + '" '
        }

        if ($cbAS.IsChecked)
        {
            'ASDATADIR=' + $cbSystemDir.SelectedValue | Out-File $SQLConfigurationFile -Append
            'ASLOGDIR=' + $cbSystemDir.SelectedValue | Out-File $SQLConfigurationFile -Append
            'ASTEMPDIR=' + $cbSystemDir.SelectedValue | Out-File $SQLConfigurationFile -Append
            'ASSVCSTARTUPTYPE="Automatic"' | Out-File $SQLConfigurationFile -Append
            'ASSVCACCOUNT="' + $SVCACCOUNTNAME + '" ' | Out-File $SQLConfigurationFile -Append
            $Features += "AS,"
            $InstallString += '/ASSVCPASSWORD="' + $SVCACCOUNTPWD + '" '
        }

        if ($features.Substring($features.Length - 1, 1) -eq ',')
        {
            $Features = $Features.Substring(0,$Features.Length-1)
        }

        'FEATURES=' + $Features | Out-File $SQLConfigurationFile -Append

        "INF: Completed Creating SQL Configuration file" | Out-File $log -Append

        Switch ($cbSQLVersion.SelectedValue)
        {
            "SQL Server 2017" { $InstallExecutable = "U:\PRODUCTS\SQL2017" }
            "SQL Server 2016" { $InstallExecutable = "U:\PRODUCTS\SQL2016" }
            "SQL Server 2014" { $InstallExecutable = "U:\PRODUCTS\SQL2014" }
            "SQL Server 2012" { $InstallExecutable = "U:\PRODUCTS\SQL2012" }
            "SQL Server 2008 R2" { $InstallExecutable = "U:\PRODUCTS\SQL2008" }
        }

        Switch ($cbSQLEdition.SelectedValue)
        {
            "Enterprise" { $InstallExecutable += "-Enterprise" }
        }

        if ((Test-Path $InstallExecutable) -ne $true)
        {
            "ERR: SQL media not found at $InstallExecutable" | Out-File $log -Append
            [System.Windows.MessageBox]::Show("SQL Installation media not found at $InstallExecutable","Media Error",$ButtonTypeOK,$MessageIcon)
            return;
        }

        $InstallExecutable += "\Setup.exe "

        $InstallString += "/IACCEPTSQLSERVERLICENSETERMS /SkipRules=RebootRequiredCheck /ConfigurationFile=" + $SQLConfigurationFile
    
        "INF: Starting SQL Server Installation from $InstallExecutable" | Out-File $log -Append
    
        $FinalCheck = [System.Windows.MessageBox]::Show("Do you want to review the configuration?","Review Configuration?",$ButtonTypeYesNo,[System.Windows.MessageBoxImage]::Question)
        if ($FinalCheck -eq "Yes")
        {
            Start-Process -Wait -FilePath notepad.exe -ArgumentList $SQLConfigurationFile
        }

        "$InstallExecutable $InstallString" | Out-Host

        Start-Process -Wait -FilePath $InstallExecutable -ArgumentList $InstallString

        Start-Process -FilePath notepad.exe -ArgumentList (Get-ChildItem "C:\Program Files\Microsoft SQL Server\" -Recurse | Where {$_.Name -like "*Summary*.txt"} | Select FullName -Last 1).FullName

        "INF: Completed SQL Server Installation at  " + $(Get-Date -Format yyyy/MM/dd-hh:mm:ss) | Out-File $log -Append
    }

    if ($cbSSEngine.IsChecked)
    {
        if (@(Get-Service | Where Name -like "*MSSQLSERVER*").Count -eq 0)
        {
            "ERR: SQL server service not found after installation" | Out-File $log -Append
            [System.Windows.MessageBox]::Show("SQL server service not found after installation","Installation Error",$ButtonTypeOK,$MessageIcon)        
            return;
        }

        "INF: Starting SQL Server Default Configuration" | Out-File $log -Append

        EngineConfiguration $log
        CreateSQLADMIN $log

        if ($cbSERVINFO.IsChecked)
        {
            Create_SERVINFO_File $log
        }
    }

    if ($cbSSEngine.IsChecked -or $cbIS.IsChecked -or $cbAS.IsChecked -or $cbRS.IsChecked)
    {
        SetNTFSSecurity $log
        CleanUpCEIP $log

        "INF: Completed SQL Server Default Configuration" | Out-File $log -Append
    }

    if ($cbSSMS2016.IsChecked)
    {
        "INF: Installing SSMS 2016" | Out-File $log -Append
        Copy-Item 'U:\PRODUCTS\SSMS 2016\SSMS-Setup-ENU.exe' C:\Temp
        Start-Process -FilePath 'C:\Temp\SSMS-Setup-ENU.exe' -ArgumentList "/install /norestart /passive" -Wait
        Remove-Item 'C:\Temp\SSMS-Setup-ENU.exe' -Force
        "INF: Completed Installing SSMS 2016" | Out-File $log -Append
    }

    if ($cbSSMS2017.IsChecked)
    {
        "INF: Installing SSMS 2017" | Out-File $log -Append
        Copy-Item 'U:\PRODUCTS\SSMS 2017\SSMS-Setup-ENU.exe' C:\Temp
        Start-Process -FilePath 'C:\Temp\SSMS-Setup-ENU.exe' -ArgumentList "/install /norestart /passive" -Wait
        Remove-Item 'C:\Temp\SSMS-Setup-ENU.exe' -Force
        "INF: Completed Installing SSMS 2017" | Out-File $log -Append
    }

    if ($cbSSDT.IsChecked)
    {
        "INF: Installing SSDT for Visual Studio 2015" | Out-File $log -Append
        $mount = Mount-DiskImage 'U:\PRODUCTS\SSDT 2015\SSDT_14.0.61712.050_EN.iso' -PassThru
        Start-Process -FilePath "$(($mount | Get-Volume).DriveLetter):\SSDTSetup.exe" -ArgumentList "/install /norestart /passive" -Wait
        Dismount-DiskImage 'U:\PRODUCTS\SSDT 2015\SSDT_14.0.61712.050_EN.iso'
        "INF: Completed Installing SSDT for Visual Studio 2015" | Out-File $log -Append
    }

    if ($cbSQLVersion.Text -eq "SQL Server 2012" -and ($cbSSEngine.IsChecked -or $cbIS.IsChecked -or $cbAS.IsChecked -or $cbRS.IsChecked))
    {
        "INF: Installing Service Pack 4 for SQL 2012" | Out-File $log -Append
        Install-2012SP4
        "INF: Completed Installing Service Pack 4 for SQL 2012" | Out-File $log -Append
    }

    "INF: Completed SQL Server Installation and Configuration " + $(Get-Date -Format yyyy/MM/dd-hh:mm:ss) | Out-File $log -Append
    Start-Process -FilePath notepad.exe -ArgumentList $log

    net use U: /d /y | Out-Null
    net use V: /d /y | Out-Null

    [System.Windows.MessageBox]::Show("Installation has completed, you may now close powershell.","Installation Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information )
    #FIN
})

$cbSQLVersion.add_SelectionChanged({
    if ($cbSQLVersion.SelectedValue -eq "SQL Server 2016")
    {
        $cbSSMS2017.IsChecked = $false
        $cbSSMS2016.IsChecked = $true
    }

    elseif ($cbSQLVersion.SelectedValue -eq "SQL Server 2017")
    {
        $cbSSMS2016.IsChecked = $false
        $cbSSMS2017.IsChecked = $true
    }

    else
    {
        $cbSSMS2016.IsChecked = $false
        $cbSSMS2017.IsChecked = $false
    }
})

$cbEnvironment.add_SelectionChanged({
    if ($cbEnvironment.SelectedValue -eq "Production")
    {
        $txtSVCAccountName.Text = "ALLIANCE\z_sqlidk"
    }
    
    else
    {
        $txtSVCAccountName.Text = "ALLIANCE\zt_sqlidk"
    }
})
#endregion

#region program start
if (Test-PendingReboot)
{
    [System.Windows.MessageBox]::Show("Server must be rebooted prior to installation.","Reboot pending", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Exclamation )
    return;
}

if ((Test-Path "U:") -eq $true)
{
    net use U: /d /y | Out-Null
}

if ((Test-Path "V:") -eq $true)
{
    net use V: /d /y | Out-Null
}

net use U: \\dbafiles\E$\SQLServer | Out-Null
net use V: \\dbafiles\E$\OLDSERVERS | Out-Null

$xamGUI.ShowDialog()



#endregion