<# This form was created using POSHGUI.com  a free online gui designer for PowerShell
.NAME
    Untitled
#>

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

#region begin GUI{ 

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = '300,200'
$Form.text                       = "Form"
$Form.TopMost                    = $false

$lblUser                         = New-Object system.Windows.Forms.Label
$lblUser.text                    = "User"
$lblUser.AutoSize                = $true
$lblUser.width                   = 25
$lblUser.height                  = 10
$lblUser.location                = New-Object System.Drawing.Point(10,10)
$lblUser.Font                    = 'Microsoft Sans Serif,10'

$txtUser                         = New-Object system.Windows.Forms.TextBox
$txtUser.multiline               = $false
$txtUser.width                   = 150
$txtUser.height                  = 20
$txtUser.location                = New-Object System.Drawing.Point(90,10)
$txtUser.Font                    = 'Microsoft Sans Serif,10'
$txtUser.Text                    = "ALLIANCE\OC96322"

$Label1                          = New-Object system.Windows.Forms.Label
$Label1.text                     = "Password"
$Label1.AutoSize                 = $true
$Label1.width                    = 25
$Label1.height                   = 10
$Label1.location                 = New-Object System.Drawing.Point(10,35)
$Label1.Font                     = 'Microsoft Sans Serif,10'

$txtPassword                     = New-Object system.Windows.Forms.MaskedTextBox
$txtPassword.multiline           = $false
$txtPassword.width               = 150
$txtPassword.height              = 20
$txtPassword.location            = New-Object System.Drawing.Point(90,35)
$txtPassword.Font                = 'Microsoft Sans Serif,10'
$txtPassword.PasswordChar        = '*'

$btnMapDrive                     = New-Object system.Windows.Forms.Button
$btnMapDrive.text                = "Map Drives"
$btnMapDrive.width               = 150
$btnMapDrive.height              = 30
$btnMapDrive.location            = New-Object System.Drawing.Point(90,60)
$btnMapDrive.Font                = 'Microsoft Sans Serif,10'

$btnSSMS                         = New-Object system.Windows.Forms.Button
$btnSSMS.text                    = "SSMS"
$btnSSMS.width                   = 150
$btnSSMS.height                  = 30
$btnSSMS.location                = New-Object System.Drawing.Point(90,90)
$btnSSMS.Font                    = 'Microsoft Sans Serif,10'

$Form.controls.AddRange(@($lblUser,$txtUser,$Label1,$txtPassword,$btnMapDrive,$btnSSMS))

#region gui events {
$btnMapDrive.Add_Click({  
    net use y: \\alliance\dfs\DBA
    net use z: \\alliance\dfs\dbdoc

    $user = $txtUser.Text
    $pw = $txtPassword.Text

    net use m: \\c1utl209\e$ $pw /user:$user
    net use n: \\c6utl225\e$ $pw /user:$user
    net use o: \\c1utl232\e$ $pw /user:$user
    net use q: \\c1utl777\e$ $pw /user:$user
    net use v: \\c1utl209\f$ $pw /user:$user
})


$btnSSMS.Add_Click({  
    $user = $txtUser.Text
    $pw = ConvertTo-SecureString $txtPassword.Text -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $pw)
    Start-Process "C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\ManagementStudio\Ssms.exe" -Credential $cred

})
#endregion events }

#endregion GUI }


#Write your logic code here

[void]$Form.ShowDialog()