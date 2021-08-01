function ConnectIExplorer() 
{
    param($HWND)

    $objShellApp = New-Object -ComObject Shell.Application 
    
    try 
    {
        while ($objNewIE.busy)
        {
            Start-Sleep -Milliseconds 500
        }

        $EA = $ErrorActionPreference; $ErrorActionPreference = 'Stop'
        $objNewIE = $objShellApp.Windows() | ?{$_.HWND -eq $HWND}
        $objNewIE.Visible = $true
    } 

    catch 
    {
        #it may happen, that the Shell.Application does not find the window in a timely-manner, therefore quick-sleep and try again
        Write-Host "Waiting for page to be loaded ..." 
          
        while ($objNewIE.busy)
        {
            Start-Sleep -Milliseconds 500
        }

        try 
        {
            $objNewIE = $objShellApp.Windows() | ?{$_.HWND -eq $HWND}
            $objNewIE.Visible = $true
        } 
        
        catch 
        {
            Write-Host "Could not retreive the -com Object InternetExplorer. Aborting." -ForegroundColor Red
            $objNewIE = $null
        }     
    } 
        
    finally 
    { 
        $ErrorActionPreference = $EA
        $objShellApp = $null
    }

    return $objNewIE
} 




$HWND = ($objIE = New-Object -ComObject InternetExplorer.Application).HWND
$objIE.Navigate("https://myrequest.countrypassport.com/identityiq/home.jsf")
$objIE = ConnectIExplorer -HWND $HWND
while ($objIE.busy)
{
    Start-Sleep -Milliseconds 500
}
$doc = $objIE.Document

$CreateLink = $doc.getElementsByTagName("a") | Where HREF -Like "javascript:SailPoint.Quicklinks.chooseQuickLink('cfCreateDBAGroupQL'*"
$CreateLink.Click()

$ApplicationField = $doc.getElementsByTagName("input") | Where ID -Like "field-*-application"
$ApplicationField.focus()
$ApplicationField.value = "ALLIANCE"
$ApplicationField.keyup()

$GroupNameField = $doc.getElementsByTagName("input") | Where ID -Like "field-*-groupName"
$GroupNameField.focus()
$GroupNameField.value = "EnterprisePaperless_PROD_READ_TABVIEW"
$GroupNameField.keyup()

$OwnerField = $doc.getElementsByTagName("input") | Where ID -EQ "cfCreateDBAGroupF-form-groupOwner-field"
$OwnerField.focus()
$OwnerField.value = "Reed McAllister"
$OwnerField.keyup()

$DescriptionField = $doc.getElementsByTagName("textarea") | Where ID -Like "field-*-description"
$DescriptionField.focus()
$DescriptionField.value = "Production database EnterprisePaperless_PROD_READ_TABVIEW access Select/Read to all tables and views"
$DescriptionField.keyup()


$Btn = $doc.getElementsByTagName("button") | Where ID -EQ "Submit RequestBtn0"
$Btn.focus()
#$Btn.click()