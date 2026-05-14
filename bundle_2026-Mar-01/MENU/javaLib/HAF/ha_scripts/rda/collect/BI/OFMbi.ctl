# OFMbi.ctl: Collects Oracle Fusion Middleware Plug-in Information
# $Id: OFMbi.ctl,v 1.21 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/OFMbi.ctl,v 1.19 2017/08/18 08:55:10 RDA Exp $
#
# Change History
# 20181219  PCW  Collect additional FDM Server Log files.
# 20181121  PCW  Allow for FDM ErpIntegrator{x} file names.
# 20170721  PCW  Added files to BI_BI srvlog plugin for OBIA.

=head1 NAME

BI:OFMbi - Collects Oracle Fusion Middleware Plug-in Information

=head1 DESCRIPTION

This module collects Oracle Fusion Middleware Plug-in-related information.

=head1 REPORTS

=cut

keep $KEEP_BLOCK

return

# --- begin section -----------------------------------------------------------
section begin

# Load the common macros
run RDA:library()

# -----------------------------------------------------------------------------
# Section Init: Define the plugin capabilities
# -----------------------------------------------------------------------------

section Init

# Define the plugin capabilities
var $plg = $arg[0]
var $ctl = {WLS => {domlog => {BI_BI     => 'BI:OFMbi-WLS_BI_DomLog_Log',\
                               BI_EXLTCS => 'BI:OFMbi-WLS_EXLTCS_DomLog_Log'},\
                    domprd => {BI_BIPL   => 'BI:OFMbi-WLS_BIPL_Config',\
                               BI_EPM    => 'BI:OFMbi-WLS_EPM_Config',\
                               BI_ESST   => 'BI:OFMbi-WLS_ESST_Config',\
                               BI_EXLTCS => 'BI:OFMbi-WLS_EXLTCS_Config',\
                               BI_HDM    => 'BI:OFMbi-WLS_HDM_Config',\
                               BI_HFM    => 'BI:OFMbi-WLS_HFM_Config',\
                               BI_HFR    => 'BI:OFMbi-WLS_HFR_Config',\
                               BI_HIR    => 'BI:OFMbi-WLS_HIR_Config',\
                               BI_HSF    => 'BI:OFMbi-WLS_HSF_Config',\
                               BI_HSS    => 'BI:OFMbi-WLS_HSS_Config',\
                               BI_HWA    => 'BI:OFMbi-WLS_HWA_Config'},\
                    srvlog => {BI_BI     => 'BI:OFMbi-WLS_BI_Log',\
                               BI_BIPL   => 'BI:OFMbi-WLS_BIPL_Log',\
                               BI_EAS    => 'BI:OFMbi-WLS_EAS_Log',\
                               BI_EPM    => 'BI:OFMbi-WLS_EPM_Log',\
                               BI_EPMA   => 'BI:OFMbi-WLS_EPMA_Log',\
                               BI_ESS    => 'BI:OFMbi-WLS_ESS_Log',\
                               BI_ESST   => 'BI:OFMbi-WLS_ESST_Log',\
                               BI_EXLTCS => 'BI:OFMbi-WLS_EXLTCS_Log',\
                               BI_FCM    => 'BI:OFMbi-WLS_FCM_Log',\
                               BI_FDM    => 'BI:OFMbi-WLS_FDM_Log',\
                               BI_HCM    => 'BI:OFMbi-WLS_HCM_Log',\
                               BI_HDM    => 'BI:OFMbi-WLS_HDM_Log',\
                               BI_HFM    => 'BI:OFMbi-WLS_HFM_Log',\
                               BI_HFR    => 'BI:OFMbi-WLS_HFR_Log',\
                               BI_HIR    => 'BI:OFMbi-WLS_HIR_Log',\
                               BI_HPC    => 'BI:OFMbi-WLS_HPC_Log',\
                               BI_HSF    => 'BI:OFMbi-WLS_HSF_Log',\
                               BI_HSS    => 'BI:OFMbi-WLS_HSS_Log',\
                               BI_HWA    => 'BI:OFMbi-WLS_HWA_Log'},\
                    srvprd => {BI_EAS    => 'BI:OFMbi-WLS_EAS_SrvCfg_Config',\
                               BI_EPM    => 'BI:OFMbi-WLS_EPM_SrvCfg_Config',\
                               BI_ESST   => 'BI:OFMbi-WLS_ESST_SrvCfg_Config',\
                               BI_HDM    => 'BI:OFMbi-WLS_HDM_SrvCfg_Config',\
                               BI_HFM    => 'BI:OFMbi-WLS_HFM_SrvCfg_Config',\
                               BI_HFR    => 'BI:OFMbi-WLS_HFR_SrvCfg_Config',\
                               BI_HIR    => 'BI:OFMbi-WLS_HIR_SrvCfg_Config',\
                               BI_HSF    => 'BI:OFMbi-WLS_HSF_SrvCfg_Config',\
                               BI_HSS    => 'BI:OFMbi-WLS_HSS_SrvCfg_Config',\
                               BI_HWA    => 'BI:OFMbi-WLS_HWA_SrvCfg_Config'}}}
loop $key (keys($ctl,'*'))
 var $plg->{@{$key}} = $ctl->{@{$key}}

# -----------------------------------------------------------------------------
# Section WLS_BIPL_Config: Collect BIPL config files for Oracle WebLogic Domain
# -----------------------------------------------------------------------------

section WLS_BIPL_Config

=head2 Oracle Business Intelligence Publisher Configuration Files

Collects the Oracle Business Intelligence Publisher-related configuration
files for Oracle WebLogic Domain.

=cut

var ($dir) = @arg

var $dir = catDir($dir,'config','bipublisher','repository','Admin')
debug '   - Inside OFMbi module, gathering BIPL configuration files'
pretoc '2:BI Publisher Configuration Files'
var %flt = (\
  'datasources.xml',       ['i', '<password>','</password>'],\
  'principals.xml',        ['is','user\s+username=".*?"\s+password="','"'],\
  'xmlp-server-config.xml',['i', 'property\s+name=".*password"\s+value="','"'])
loop $fil (catFile($dir,'Configuration','principals.xml'),\
           catFile($dir,'Configuration','security.xml'),\
           catFile($dir,'Configuration','xmlp-server-config.xml'),\
           catFile($dir,'DataSource','datasources.xml'))
{if ?testFile('r',$fil)
 {var $nam = basename($fil)
  report $nam
  prefix
  {write '---+ Display of ',encode($nam),' File'
   write '---## Information Taken from ',encode($fil)
  }
  call statFile('b',$fil)
  if !exists($flt{$nam})
   call writeFile($fil)
  elsif createBuffer('XML','F',$fil)
  {call filterBuffer('XML','%R:PASSWORD%',@{$flt{$nam}})
   call writeBuffer('XML')
   call deleteBuffer('XML')
  }
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][',encode($nam),']]'
 }
}
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EAS_SrvCfg_Config: Collect EAS server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_EAS_SrvCfg_Config

=head2 EAS Domain Server Configuration Files

Collects the Oracle Essbase Administration Services-related configuration files
for Oracle WebLogic Server and attributes of the Login Wallet file.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering EAS configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:EAS Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))

# Report attributes of the cwallet.sso file
report cwallet
write '---+ Cwallet.sso File Attributes'
call statFile('b',catFile($top,'config','fmwconfig','bootstrap','cwallet.sso'))
if isCreated()
 toc '3:[[',getFile(),'][rda_report][cwallet]]'
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EPM_Config: Collect EPM config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_EPM_Config

=head2 EPM Domain Configuration Files

Gathers domain-wide Enterprise Performance Management System-related Oracle
WebLogic Server configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering EPM domain configuration files'
pretoc '2:EPM Domain Configuration Files'
call sort_files(3,0,\
  catFile($dir,'config','config.xml'),\
  catFile($dir,'config','fmwconfig','system-jazn-data.xml'),\
  catFile($dir,'init-info','config-groups.xml'),\
  catFile($dir,'init-info','domain-info.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EPM_SrvCfg_Config: Collect EPM server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_EPM_SrvCfg_Config

=head2 EPM Domain Server Configuration Files

Collects the Enterprise Performance Management System-related configuration
files for Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering EPM configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:EPM Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'),\
                    catFile($cfg,'was','logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_ESST_Config: Collect ESST config files from Oracle WebLogic
#                          Server
# -----------------------------------------------------------------------------

section WLS_ESST_Config

=head2 ESST Domain Configuration Files

Gathers domain-wide Oracle Essbase Studio-related Oracle WebLogic Server
configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering ESST domain configuration files'
pretoc '2:ESST Domain Configuration Files'
call sort_files(3,0,catFile($dir,'config','config.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_ESST_SrvCfg_Config: Collect ESST server config files from Oracle
#                                 WebLogic Server
# -----------------------------------------------------------------------------

section WLS_ESST_SrvCfg_Config

=head2 ESST Domain Server Configuration Files

Collects the Oracle Essbase Studio-related configuration files for
Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering ESST configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:ESST Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EXLTCS_Config: Collect EXLTCS config files from Oracle WebLogic
#                            Server
# -----------------------------------------------------------------------------

section WLS_EXLTCS_Config

=head2 EXLTCS Domain Configuration Files

Gathers domain-wide Oracle Exalytics-related Oracle WebLogic Server
configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering EXLTCS domain configuration files'
pretoc '2:EXLTCS Domain Configuration Files'
call sort_files(3,0,\
  catFile($dir,'config','config.xml'),\
  catFile($dir,'config','bipublisher','xmlp-server-config.xml'),\
  catFile($dir,'config','bipublisher','repository','Admin','Configuration',\
          'xmlp-server-config.xml'),\
  catFile($dir,'config','fmwconfig','config.xml'),\
  catFile($dir,'config','fmwconfig','biee-domain.xml'),\
  catFile($dir,'config','fmwconfig','jps-config.xml'),\
  catFile($dir,'config','fmwconfig','system-jazn-data.xml'),\
  catFile($dir,'opmn','topology.xml'),\
  catFile($dir,'sysman','state','target.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HDM_Config: Collect HDM config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HDM_Config

=head2 HDM Domain Configuration Files

Gathers domain-wide Oracle Hyperion Disclosure Management-related Oracle
WebLogic Server configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering HDM domain configuration files'
pretoc '2:HDM Domain Configuration Files'
call sort_files(3,0,catFile($dir,'plans','discman.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HDM_SrvCfg_Config: Collect HDM server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HDM_SrvCfg_Config

=head2 HDM Domain Server Configuration Files

Collects the Oracle Hyperion Disclosure Management-related configuration files
for Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering HDM configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:HDM Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HFM_Config: Collect HFM config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HFM_Config

=head2 HFM Domain Configuration Files

Gathers domain-wide Oracle Hyperion Financial Management-related Oracle
WebLogic Server configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering HFM domain configuration files'
pretoc '2:HFM Domain Configuration Files'
call sort_files(3,0,catFile($dir,'config','config.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HFM_SrvCfg_Config: Collect HFM server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HFM_SrvCfg_Config

=head2 HFM Domain Server Configuration Files

Collects the Oracle Hyperion Financial Management-related configuration files
for Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering HFM configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:HFM Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HFR_Config: Collect HFR config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HFR_Config

=head2 HFR Domain Configuration Files

Gathers domain-wide Oracle Hyperion Financial Reporting-related Oracle WebLogic
Server configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering HFR domain configuration files'
pretoc '2:HFR Domain Configuration Files'
call sort_files(3,0,catFile($dir,'config','config.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HFR_SrvCfg_Config: Collect HFR server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HFR_SrvCfg_Config

=head2 HFR Domain Server Configuration Files

Collects the Oracle Hyperion Financial Reporting-related configuration files
for Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering HFR configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:HFR Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HIR_Config: Collect HIR config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HIR_Config

=head2 HIR Domain Configuration Files

Gathers domain-wide Oracle Hyperion Interactive Reporting-related Oracle
WebLogic Server configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering HIR domain configuration files'
pretoc '2:HIR Domain Configuration Files'
call sort_files(3,0,\
  catFile($dir,'config','config.xml'),\
  catFile($dir,'config','fmwconfig','system-jazn-data.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HIR_SrvCfg_Config: Collect HIR server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HIR_SrvCfg_Config

=head2 HIR Domain Server Configuration Files

Collects the Oracle Hyperion Interactive Reporting-related configuration
files for Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering HIR configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:HIR Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HSF_Config: Collect HSF config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HSF_Config

=head2 HSF Domain Configuration Files

Gathers domain-wide Oracle Hyperion Strategic Finance-related Oracle WebLogic
Server configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering HSF domain configuration files'
pretoc '2:HSF Domain Configuration Files'
call sort_files(3,0,catFile($dir,'config','config.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HSF_SrvCfg_Config: Collect HSF server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HSF_SrvCfg_Config

=head2 HSF Domain Server Configuration Files

Collects the Oracle Hyperion Strategic Finance-related configuration files
for Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering HSF configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:HSF Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HSS_Config: Collect HSS config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HSS_Config

=head2 HSS Domain Configuration Files

Gathers domain-wide Oracle Hyperion Shared Services-related Oracle WebLogic
Server configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering HSS domain configuration files'
pretoc '2:HSS Domain Configuration Files'
call sort_files(3,0,\
  catFile($dir,'fileRealm.properties'),\
  catFile($dir,'config','config.xml'),\
  catFile($dir,'config','fmwconfig','cwallet.sso'),\
  catFile($dir,'config','jdbc','EPMSystemRegistry-jdbc.xml'),\
  catFile($dir,'config','jdbc','raframework_datasource-jdbc.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HSS_SrvCfg_Config: Collect HSS server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HSS_SrvCfg_Config

=head2 HSS Domain Server Configuration Files

Collects the Oracle Hyperion Shared Services-related configuration files for
Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering HSS configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers','FoundationServices0')
pretoc '2:HSS Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HWA_Config: Collect HWA config files from Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HWA_Config

=head2 HWA Domain Configuration Files

Gathers domain-wide Oracle Hyperion Web Analysis-related Oracle WebLogic Server
configuration files.

=cut

var ($dir) = @arg

debug '   - Inside OFMbi module, gathering HWA domain configuration files'
pretoc '2:HWA Domain Configuration Files'
call sort_files(3,0,catFile($dir,'config','config.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HWA_SrvCfg_Config: Collect HWA server config files from Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HWA_SrvCfg_Config

=head2 HWA Domain Server Configuration Files

Collects the Oracle Hyperion Web Analysis-related configuration files for
Oracle WebLogic Server.

=cut

var ($dir,$top,$srv) = @arg

debug '   - Inside OFMbi module, gathering HWA configuration files'
var $cfg = catDir($top,'config','fmwconfig','servers',$srv)
pretoc '2:HWA Domain Server Configuration Files'
call sort_files(3,0,catFile($cfg,'logging.xml'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_BI_DomLog_Log: Collect BI domain log files by executing
#                            Diagnostic Dump for the current Domain
# -----------------------------------------------------------------------------

section WLS_BI_DomLog_Log

=head2 Diagnostic Dump log file collection for BI

Collects the Oracle Business Intelligence-related local log files for Oracle
WebLogic Server.

=cut

var ($dir,$lim) = @arg

if or(isWindows(),isCygwin())
 var $prg = 'diagnostic_dump.cmd'
else
 var $prg = 'diagnostic_dump.sh'

debug ' Inside BI module, diagdump command is : ',$prg

var $cmd = catCommand($dir,'bitools','bin',$prg)

if ?testFile('x',$cmd)
{report diag_dump
 var $box = cleanBox()
 var $zip = catFile($box,'diagdump.zip')
 var $out = catFile($box,'diagdump.out')
 $cmd = concat($cmd,' ',$zip,' >',$out,' 2>&1')
 call command($cmd)
 prefix
 {write '---+ Diagnostic Dump Output'
  write '---## Using : ',encode($cmd)
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Size*|*Last Modified Date*|'
 }
 var $bas = basename($zip)
 var $lnk = encode($bas)
 var $siz = getSize($zip)
 if $siz
 {output d,concat('BI_',basename($zip))
  if ${CUR.O_LAST}->write_data($zip)
   var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
  end ${CUR.O_LAST}
 }
 write '|',$lnk,' | ',$siz,'|',getLastModify($zip,'<UTC>'),' |'

 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Diagnostic Dump Output]]'
}

# -----------------------------------------------------------------------------
# Section WLS_BI_Log: Collect BI log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_BI_Log

=head2 BI Local Log Files

Collects the Oracle Business Intelligence-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering BI log files'
pretoc '3:BI Local Log Files'
call sort_files(4,$lim,\
  catFile($dir,'logs','bipublisher','bipublisher.log'),\
  grepDir(catDir($dir,'logs'),\
   '(.+query|.+XmlGen|.+DMLGen|^webcat.+|^upgrade.+|^sawlog.+)\.log$','np'),\
  grepDir(catDir($dir,'logs'),\
   '(^nqsched.+|^nqclus.+|.+AdminTool|^jh|^jbips)\.log$','np'),\
  grepDir(catDir($dir,'logs','catalogmanager'),'^catalogmanager.*\.log$','np'),\
  grepDir(catDir($dir,'logs','biacm'),'^biacm.*\.log$','np'),\
  grepDir(catDir($dir,'logs','oracledi'),'^odiagent.*\.log$','np'),\
  grepDir(catDir($dir,'logs','cloudrep'),'^cloudrep.*\.log$','np'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_BIPL_Log: Collect BIPL log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_BIPL_Log

=head2 BI Publisher Local Log Files

Collects the Oracle Business Intelligence Publisher-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering BIPL log files'
pretoc '3:BI Publisher Local Log Files'
call sort_files(4,$lim,\
 catFile($dir,'logs','bipublisher','bipublisher.log'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EAS_Log: Collect EAS log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_EAS_Log

=head2 EAS Local Log Files

Collects the Oracle Essbase Administration Services-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering EAS log files'
pretoc '3:EAS Local Log Files'
call sort_files(4,$lim,\
  catFile($dir,'logs','easserver.log'),\
  catFile($dir,'logs','SharedServices_SecurityClient.log'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EPM_Log: Collect EPM log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_EPM_Log

=head2 EPM Local Log Files

Collects the Enterprise Performance Management System-related local log files
for Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering EPM log files'
pretoc '3:EPM Local Log Files'
call sort_files(4,$lim,\
  catFile($dir,'logs','epm-foundation-webservices.log'),\
  catFile($dir,'logs','Framework.log'),\
  catFile($dir,'logs','registry.log'),\
  catFile($dir,'logs','Workspace.log'),\
  catFile($dir,'logs','FCM','lcm','CMplugin.log'),\
  catFile($dir,'logs','FCM','lcm','FCMplugin.log'),\
  grepDir(catDir($dir,'logs'),'^(SharedServices|RaFramework)_.*?\.log$','np'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EPMA_Log: Collect EPMA log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_EPMA_Log

=head2 EPMA Local Log Files

Collects the Oracle Hyperion Enterprise Performance Management Architect-
related local log files for Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering EPMA log files'
pretoc '3:EPMA Local Log Files'
call sort_files(4,$lim,\
  catFile($dir,'logs','essconn.log'),\
  catFile($dir,'logs','registry.log'),\
  grepDir(catDir($dir,'logs'),'^(datasync|epma)(-\d+)?\.log$','ip'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_ESS_Log: Collect ESS log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_ESS_Log

=head2 ESS Local Log Files

Collects the Oracle Hyperion Essbase-related local log files for Oracle
WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering ESS log files'
pretoc '3:ESS Local Log Files'
call sort_files(4,$lim,catFile($dir,'logs','easserver.log'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_ESST_Log: Collect ESST log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_ESST_Log

=head2 ESST Local Log Files

Collects the Oracle Essbase Studio-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering ESST log files'
pretoc '3:ESST Local Log Files'
call sort_files(4,$lim,grepDir(catDir($dir,'logs'),\
                        '^(registry|SharedServices_.*?|Workspace)\.log$','np'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EXLTCS_DomLog_Log: Collect EXLTCS domain log files for Oracle
#                                WebLogic Server
# -----------------------------------------------------------------------------

section WLS_EXLTCS_DomLog_Log

=head2 EXLTCS Local Log Files

Collects the Oracle Exalytics-related domain local log files for Oracle
WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering EXLTCS domain log files'
pretoc '2:EXLTCS Local Log Files'
call sort_files(3,$lim,catFile($dir,'logs','bipublisher','bipublisher.log'),\
                       catFile($dir,'sysman','log','emoms.log'),\
                       catFile($dir,'sysman','log','emoms.trc'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_EXLTCS_Log: Collect EXLTCS log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_EXLTCS_Log

=head2 EXLTCS Local Log Files

Collects the Oracle Exalytics-related local log files for Oracle WebLogic
Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering EXLTCS log files'
pretoc '3:EXLTCS Local Log Files'
call sort_files(4,$lim,catFile($dir,'sysman','log','emoms.log'),\
                       catFile($dir,'sysman','log','emoms.trc'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_FCM_Log: Collect FCM log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_FCM_Log

=head2 FCM Local Log Files

Collects the Oracle Hyperion Financial Close Management-related local log files
for Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering FCM log files'
pretoc '3:FCM Local Log Files'
call sort_files(4,$lim,catFile($dir,'logs','FinancialClose.log'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_FDM_Log: Collect FDM log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_FDM_Log

=head2 FDM Local Log Files

Collects the Oracle Hyperion Financial Data Management related local log files
for Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg
var $int = \
  basename(grepDir(catDir($dir,'logs'),'^ErpIntegrator\d+\.log$','f'),'.log')

debug '   - Inside OFMbi module, gathering FDM log files'
pretoc '3:FDM Local Log Files'
call sort_files(4,${SET.BI.FDM.N_TAIL:$lim},\
  grepDir(catDir($dir,'logs'),\
    '^((datasource|ErpIntegrator\d+)\.log([\d]+)?|\
       (aif-(apsserver|CalcManager|HfmAdmDriver|Planning_WebApp|WebApp)|\
        Framework|listener|registry|SharedServices_SecurityClient|\
        Planning_WebApp)\.log)$','np'),\
  grepDir(catDir($dir,'logs','diagnostic_images'),'.+','np'),\
  catFile($dir,'logs','jmsServers',\
          concat('JRFWSAsyncJmsServer_',$int,'_auto_1'),\
          'jms.messages.log'),\
  grepDir(catDir($dir,'logs','metrics',''),\
    '^metricdump-[\d]{8}\.[\d]+\.gz$','np'),\
  catFile($dir,'logs','oracledi','odiagent.log'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HCM_Log: Collect HCM log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HCM_Log

=head2 HCM Local Log Files

Collects the Oracle Hyperion Calculation Manager-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HCM log files'
pretoc '3:HCM Local Log Files'
call sort_files(4,$lim,grepDir(catDir($dir,'logs'),\
  '^(apsserver|CalcManager|datasource|listener|Planning_Adf|ProxyFilter|\
     registry)\.log$','p'))
unpretoc


# -----------------------------------------------------------------------------
# Section WLS_HDM_Log: Collect HDM log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HDM_Log

=head2 HDM Local Log Files

Collects the Oracle Hyperion Disclosure Management related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HDM log files'
pretoc '3:HDM Local Log Files'
call sort_files(4,${SET.BI.HDM.N_TAIL:$lim},\
  grepDir(catDir($dir,'logs'),\
    '^(DisclosureManagement0\.log([\d]+)?|\
     (DiscMan((Auditservice|MappingTool|Perf|ReportService|\
               Repository(Service)?)?|SessionServices|XPF)|\
     registry(-[\d]+)?|SharedServices_SecurityClient)\.log)$','np'),\
  grepDir(catDir($dir,'logs','diagnostic_images'),'.+','np'),\
  grepDir(catDir($dir,'logs','metrics',''),\
    '^metricdump-[\d]{8}\.[\d]+\.gz$','np'),\
  catFile($dir,'data','ldap','log','EmbeddedLDAPAccess.log'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HFM_Log: Collect HFM log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HFM_Log

=head2 HFM Local Log Files

Collects the Oracle Hyperion Financial Management-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HFM log files'
pretoc '3:HFM Local Log Files'
call sort_files(4,$lim,\
  catFile($dir,'oracle-epm-fm.log'),\
  catFile($dir,'logs','hfm','oracle-epm-fm.log'),\
  catFile($dir,'logs','hfm','epm-fm-webservices.log'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HFR_Log: Collect HFR log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HFR_Log

=head2 HFR Local Log Files

Collects the Oracle Hyperion Financial Reporting-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HFR log files'
pretoc '3:HFR Local Log Files'
call sort_files(4,${SET.BI.HFR.N_TAIL:$lim},grepDir(\
  catDir($dir,'logs'),'^(audit_client|datasource|Framework|FRLogging|listener|\
                         RaFramework_.*?|registry|SharedServices_.*?|\
                         Workspace)\.log$','np'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HIR_Log: Collect HIR log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HIR_Log

=head2 HIR Local Log Files

Collects the Oracle Hyperion Interactive Reporting-related local log files
for Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HIR log files'
pretoc '3:HIR Local Log Files'
call sort_files(4,$lim,\
  grepDir(catDir($dir,'logs'),'^(Framework|RaFramework_.*?|registry(-\d)?|\
                                 SharedServices_.*?|Workspace)\.log$','np'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HPC_Log: Collect HPC log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HPC_Log

=head2 HPC Local Log Files

Collects the Oracle Hyperion Profitability and Cost Management-related local
log files for Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HPC log files'
pretoc '3:HPC Local Log Files'
call sort_files(4,${SET.BI.HPC.N_TAIL:$lim},grepDir(\
  catDir($dir,'logs'),'\.log(\d+)?$','np'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HSF_Log: Collect HSF log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HSF_Log

=head2 HSF Local Log Files

Collects the Oracle Hyperion Strategic Finance-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HSF log files'
pretoc '3:HSF Local Log Files'
call sort_files(4,${SET.BI.HSF.N_TAIL:$lim},grepDir(\
  catDir($dir,'logs'),'^(HsfWeb0|HpsWebReports0|registry|\
                         SharedServices_SecurityClient)\.log$','np'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HSS_Log: Collect HSS log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HSS_Log

=head2 HSS Local Log Files

Collects the Oracle Hyperion Shared Services-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HSS log files'
pretoc '3:HSS Local Log Files'
call sort_files(4,${SET.BI.HSS.N_TAIL:$lim},\
  grepDir(catDir($dir,'logs'),'^(SharedServices.*|epm-foundation-webservices|\
                                 audit_client|Framework|\
                                 Planning_WebApp)\.log$','rt'))
unpretoc

# -----------------------------------------------------------------------------
# Section WLS_HWA_Log: Collect HWA log files for Oracle WebLogic Server
# -----------------------------------------------------------------------------

section WLS_HWA_Log

=head2 HWA Local Log Files

Collects the Oracle Hyperion Web Analysis-related local log files for
Oracle WebLogic Server.

=cut

var ($dir,$lim) = @arg

debug '   - Inside OFMbi module, gathering HWA log files'
pretoc '3:HWA Local Log Files'
call sort_files(4,$lim,\
  grepDir(catDir($dir,'logs'),'^(adm|Adm(Aps|Performance)|registry|\
                                 SharedServices_.*?|WebAnalysis(Atf|Audit)?|\
                                 Workspace)\.log$','np'))
unpretoc

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
