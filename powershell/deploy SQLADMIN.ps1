$servers = @()
#$servers += 'C1DBD004'
$servers += 'C1DBD007'
$servers += 'C1DBD008'
$servers += 'C1DBD010'
$servers += 'C1DBD016'
$servers += 'C1DBD017'
$servers += 'C1DBD018'
$servers += 'C1DBD019'
$servers += 'C1DBD020'
$servers += 'C1DBD021'
$servers += 'C1DBD022'
$servers += 'C1DBD023'
$servers += 'C1DBD025'
$servers += 'C1DBD028'
$servers += 'C1DBD029'
$servers += 'C1DBD030'
$servers += 'C1DBD031'
$servers += 'C1DBD033'
$servers += 'C1DBD034'
$servers += 'C1DBD035'
$servers += 'C1DBD036'
$servers += 'C1DBD037'
$servers += 'C1DBD038'
$servers += 'C1DBD039'
$servers += 'C1DBD040'
$servers += 'C1DBD041'
$servers += 'C1DBD042'
$servers += 'C1DBD043'
$servers += 'C1DBD044'
$servers += 'C1DBD045'
$servers += 'C1DBD046'
$servers += 'C1DBD047'
$servers += 'C1DBD048'
$servers += 'C1DBD049'
$servers += 'C1DBD050'
$servers += 'C1DBD051'
$servers += 'C1DBD052'
$servers += 'C1DBD053'
#$servers += 'C1DBD054'
$servers += 'C1DBD055'
$servers += 'C1DBD056'
$servers += 'C1DBD057'
$servers += 'C1DBD058'
$servers += 'C1DBD059'
$servers += 'C1DBD061'
$servers += 'C1DBD062'
$servers += 'C1DBD063'
$servers += 'C1DBD066'
$servers += 'C1DBD070'
$servers += 'C1DBD071'
$servers += 'C1DBD088'
$servers += 'C1DBD089'
$servers += 'C1DBD102'
$servers += 'C1DBD105'
$servers += 'C1DBD106'
$servers += 'C1DBD120'
$servers += 'C1DBD121'
$servers += 'C1DBD122'
$servers += 'C1DBD123'
$servers += 'C1DBD124'
$servers += 'C1DBD136'
$servers += 'C1DBD191'
$servers += 'C1DBD202'
$servers += 'C1DBD212'
$servers += 'C1DBD214'
$servers += 'C1DBD215'
$servers += 'C1DBD216'
$servers += 'C1DBD222'
$servers += 'C1DBD302'
$servers += 'C1DBD307'
$servers += 'C1DBD309'
$servers += 'C1UTL019'
$servers += 'C2APP003'
$servers += 'C6DBD001'
$servers += 'C6DBD002'
$servers += 'C6DBD036'
$servers += 'C7DBD020'
$servers += 'C7DBD021'
$servers += 'MMDBD016'


foreach ($s in $servers)
{
    $s | Out-Host

    Invoke-SqlCmd -ServerInstance $s -Database master -Query "ALTER AUTHORIZATION ON DATABASE::[SQLADMIN] TO [CCSAID]"
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -Query 'ALTER DATABASE SQLADMIN SET RECOVERY SIMPLE'	
    
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile '\\c1utl209\e$\SQLServer\SQL monitor code\Instance Objects.sql'

    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_Blitz.sql                           
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_BlitzBackups.sql                    
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_BlitzCache.sql                      
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_BlitzFirst.sql                      
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_BlitzIndex.sql                      
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_BlitzLock.sql                       
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_BlitzWho.sql                        
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_DatabaseRestore.sql                 
    Invoke-SqlCmd -ServerInstance $s -Database SQLADMIN -InputFile \\c1utl209\e$\SQLServer\FirstResponderKit\sp_foreachdb.sql        
}