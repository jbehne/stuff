Get-ADUser -Filter "UserPrincipalName -eq 'Ashwin.D''Souza@countryfinancial.com'" 
Get-ADUser -Filter "UserPrincipalName -eq 'Saurav.Yadav@countryfinancial.com'" 

Get-ADUser -Filter "UserPrincipalName -eq 'robert.bedeker@countryfinancial.com'" 
Get-ADUser -Filter "UserPrincipalName -eq 'bill.meaney@middleoak.com'" 
Get-ADUser -Filter "Name -eq 'ID25044'" 

Get-ADPrincipalGroupMembership -Identity ID36762 | Out-GridView
Get-ADPrincipalGroupMembership -Identity ID66644 | Out-GridView

Get-ADGroup -Filter "Name -like '*V50*'" | Select name


Get-ADGroupMember EnterprisePaperless_PROD_READ_TABVIEW | select name
Get-ADGroupMember EnterprisePaperless_QA_UPDATE_TABVIEW | select name



Get-ADGroupMember Admins-V01DBSWIN508 | select name
Get-ADGroupMember v50cosmosdbaas501_reader | select name


Get-ADGroupMember V50DBSWIN501_AZURE_FIREWALL  | select name
#Get-ADGroupMember V50DBCAMI500_AZURE_FIREWALL  | select name  
#Get-ADGroupMember V50COSMOSDBAAS501_READER     | select name  
#Get-ADGroupMember V50COSMOSDBAAS502_READER     | select name 
Get-ADGroupMember V50COSMOSDBAAS503_READER     | select name