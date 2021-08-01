$Name = "Bruce Badner"
$Searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(displayname=$Name))"
[void]$Searcher.PropertiesToLoad.Add("sAMAccountName")
$Results = $Searcher.FindAll()
ForEach ($User In $Results)
{
    $NTName = $User.Properties.Item("sAMAccountName")
    $NTName
}


Get-ADGroup -Filter "Name -like 'OCG*UPDATE*'" | Select Name





# Turn on the Feature
Add-WindowsFeature RSAT-AD-PowerShell

# Import module
Import-Module -Name ActiveDirectory

# Query members of a group
Get-ADGroup -Filter "Name -like 'Admins-V01DBSWIN706'" | Get-ADGroupMember | Select name

