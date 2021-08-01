select 'backup log ' + name + ' to disk=N''\\blm-bak-10-dd\sql_prod\C1DBD120\' + name + '\' + name + '_emergencylog.trn''' from sys.databases

backup log cpsdyn to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\cpsdyn\cpsdyn_emergencylog.trn'
backup log LcsCDR to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\LcsCDR\LcsCDR_emergencylog.trn'
backup log LcsLog to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\LcsLog\LcsLog_emergencylog.trn'
backup log lis to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\lis\lis_emergencylog.trn'
backup log QoEMetrics to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\QoEMetrics\QoEMetrics_emergencylog.trn'
backup log rgsconfig to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\rgsconfig\rgsconfig_emergencylog.trn'

backup log rgsdyn to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\rgsdyn\rgsdyn_emergencylog.trn'
backup log rtcab to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\rtcab\rtcab_emergencylog.trn'
backup log rtcshared to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\rtcshared\rtcshared_emergencylog.trn'
--backup log rtcxds to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\rtcxds\rtcxds_emergencylog.trn'
backup log xds to disk=N'\\blm-bak-10-dd\sql_prod\C1DBD120\xds\xds_emergencylog.trn'