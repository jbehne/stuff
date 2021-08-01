$xmlWPF = [System.Xml.XmlDocument]@"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="SQL Server Installer" Height="485" Width="380">
    <Grid>

        <GroupBox Name="groupBox" Header="Version Info" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" Height="88" Width="350"/>
        <Label Name="label" Content="Version" HorizontalAlignment="Left" Margin="27,34,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbSQLVersion" HorizontalAlignment="Left" Margin="117,37,0,0" VerticalAlignment="Top" Width="230"/>
        <Label Name="label2" Content="Edition" HorizontalAlignment="Left" Margin="27,60,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbSQLEdition" HorizontalAlignment="Left" Margin="117,64,0,0" VerticalAlignment="Top" Width="230"/>

        <GroupBox Name="groupBox2" Header="Feature Selection" HorizontalAlignment="Left" Margin="10,103,0,0" VerticalAlignment="Top" Height="79" Width="350"/>
        <CheckBox Name="cbSSEngine" Content="SQL Engine" HorizontalAlignment="Left" Margin="27,130,0,0" VerticalAlignment="Top" IsChecked="True"/>
        <CheckBox Name="cbAS" Content="Analysis Services" HorizontalAlignment="Left" Margin="27,151,0,0" VerticalAlignment="Top"/>
        <CheckBox Name="cbRS" Content="Reporting Services" HorizontalAlignment="Left" Margin="202,154,0,0" VerticalAlignment="Top"/>
        <CheckBox Name="cbIS" Content="Integration Services" HorizontalAlignment="Left" Margin="202,133,0,0" VerticalAlignment="Top"/>
        
        <GroupBox Name="groupBox1" Header="Directories" HorizontalAlignment="Left" Margin="10,187,0,0" VerticalAlignment="Top" Width="349" Height="118"/>
        <Label Name="label1" Content="System" HorizontalAlignment="Left" Margin="27,209,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbSystemDir" HorizontalAlignment="Left" Margin="117,213,0,0" VerticalAlignment="Top" Width="230"/>
        <Label Name="label4" Content="User Data" HorizontalAlignment="Left" Margin="27,236,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbUserDataDir" HorizontalAlignment="Left" Margin="117,240,0,0" VerticalAlignment="Top" Width="230"/>
        <Label Name="label5" Content="User Log" HorizontalAlignment="Left" Margin="27,263,0,0" VerticalAlignment="Top"/>
        <ComboBox Name="cbUserLogDir" HorizontalAlignment="Left" Margin="117,267,0,0" VerticalAlignment="Top" Width="230"/>

        <GroupBox Name="groupBox3" Header="Service Accounts" HorizontalAlignment="Left" Margin="10,310,0,0" VerticalAlignment="Top" Width="349" Height="87"/>
        <Label Name="label6" Content="Account Name" HorizontalAlignment="Left" Margin="27,337,0,0" VerticalAlignment="Top"/>
        <TextBox Name="textAccount" HorizontalAlignment="Left" Height="23" Margin="163,332,0,0" VerticalAlignment="Top" Width="184"/>
        <Label Name="label7" Content="Account Password" HorizontalAlignment="Left" Margin="27,357,0,0" VerticalAlignment="Top"/>
        <PasswordBox Name="txtPassword" HorizontalAlignment="Left" Height="23" Margin="163,360,0,0" VerticalAlignment="Top" Width="184"/>
        
        <Button Name="btnInstall" Content="Install" HorizontalAlignment="Left" Margin="150,410,0,0" VerticalAlignment="Top" Width="75"/>
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

$log = "E:\SQLInstallLog.log"

$cbSQLVersion.Items.Add("SQL Server 2016") | Out-Null
$cbSQLVersion.Items.Add("SQL Server 2014") | Out-Null
$cbSQLVersion.Items.Add("SQL Server 2012") | Out-Null
$cbSQLVersion.Items.Add("SQL Server 2008 R2") | Out-Null
$cbSQLVersion.SelectedIndex = 0 | Out-Null

$cbSQLEdition.Items.Add("Standard") | Out-Null
$cbSQLEdition.Items.Add("Enterprise") | Out-Null
$cbSQLEdition.SelectedIndex = 0 | Out-Null

$drives = (Get-WmiObject Win32_LogicalDisk).DeviceID
foreach ($d in $drives)
{
    if ($d -ne "C:")
    {
        $cbSystemDir.Items.Add($d + "\Data") | Out-Null
        $cbUserDataDir.Items.Add($d + "\Data") | Out-Null
        $cbUserLogDir.Items.Add($d + "\Data") | Out-Null
    }
}

$cbSystemDir.SelectedIndex = 0 | Out-Null
$cbUserDataDir.SelectedIndex = 0 | Out-Null
$cbUserLogDir.SelectedIndex = 0 | Out-Null

$btnInstall.add_Click({
    $groupBox3.Visibility = "Hidden"
<#
    if ((Get-WmiObject Win32_Volume | Where DriveLetter -eq $cbSystemDir.SelectedItem.Substring(0,2) | Select BlockSize).BlockSize -eq 4096)
    {
        "ERR: Block size not set to 64k on selected System Disk" | Out-File $log -Append
    }
#>
})



$xamGUI.ShowDialog()