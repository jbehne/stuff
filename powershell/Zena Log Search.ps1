$ID = "alliance\oc96322"; $pass = convertto-securestring "VcA69Kyr" -asplaintext -force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $ID,$pass 


$maintServer = "C1UTL209"
Invoke-Command -ComputerName $maintServer -credential $cred -ErrorAction Stop -ScriptBlock { Get-ChildItem e:\ccapplications\dba\dat | Select-String -pattern "CFAR-EMAIL-IF-BLOCKING" | group path | select name }

$maintServer = "C6UTL225"
Invoke-Command -ComputerName $maintServer -credential $cred -ErrorAction Stop -ScriptBlock { Get-ChildItem e:\ccapplications\dba\dat | Select-String -pattern "CFAR-EMAIL-IF-BLOCKING" | group path | select name }

$maintServer = "C1UTL232"
Invoke-Command -ComputerName $maintServer -credential $cred -ErrorAction Stop -ScriptBlock { Get-ChildItem e:\ccapplications\dba\dat | Select-String -pattern "CFAR-EMAIL-IF-BLOCKING" | group path | select name }