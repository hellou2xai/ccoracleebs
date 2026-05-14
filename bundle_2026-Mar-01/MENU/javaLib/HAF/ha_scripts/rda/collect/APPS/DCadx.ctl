# DCadx.ctl:510:Collects AutoConfig and Rapid Clone Information
# $Id: DCadx.ctl,v 1.5 2015/08/21 15:33:37 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCadx.ctl,v 1.5 2015/08/21 15:33:37 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

APPS:DCadx - Collects Oracle Applications AutoConfig and Rapid Clone Information

=head1 DESCRIPTION

This module collects the AutoConfig files and Rapid Clone logs from an Oracle
Applications environment. To further assist in problem analysis, it can gather
Oracle Applications configuration files also.

You can restrict data collection to the applications tier, database tier, or
both tiers. However, the data collection is limited to the local host.

=cut

echo tput('bold'),'Processing APPS.ADX module ...',tput('off')

# Initialization
var $ADX_TOOL = ${W_TOOL}
var $REL12    = ${B_R12}

var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
var $TTL
pretoc '1:AutoConfig and Rapid Clone'

# Define a macro to retrieve the AutoConfig logs, scripts, and templates.
macro get_autoconfig
{var ($lvl,$appl,$db,$sid,$hom,$top) = @arg
 import $REL12

 if $appl
  call get_autoconfig_appl($lvl,$sid,$top)
 if $db
  call get_autoconfig_db($lvl,$sid,$hom)
}

macro get_autoconfig_appl
{var ($lvl,$sid,$top) = @arg
 import $REL12,$TOP

 pretoc $lvl,':Applications Tier'
 incr $lvl

 # Initialisation
 if $REL12
 {var $dir = catDir($top,'admin','log')
  var $xml = catFile($top,'appl','admin',concat($sid,'_',${RDA.T_NODE},'.xml'))
 }
 else
 {var $dir = catDir($top,'admin',concat($sid,'_',${RDA.T_NODE}),'log')
  var $xml = catFile($top,'admin',concat($sid,'_',${RDA.T_NODE},'.xml'))
 }

 # Treat adconfig.log
 var ($adc) = grepDir($dir,'^adconfig\.log$','rt')
 if createBuffer('ADC','F',$adc)
 {# Report adconfig.log
  debug ' In ADX module, collecting applications tier adconfig.log'
  report adc_aplog
  prefix
  {write '---+ adconfig.log'
   write '---## Content Taken from ',encode($adc)
  }
  call writeBuffer('ADC')
  if isCreated(true)
  {write $TOP
   toc $lvl,':[[',getFile(),'][rda_report][adconfig.log]]'
  }

  # Analyze adconfig.log
  debug ' In ADX module, collecting applications tier clone failures'
  report adc_apfail
  call write_failures('adc_aps_','adc_apt_')
  if isCreated(true)
   toc $lvl,':[[',getFile(),'][rda_report][Scripts in Error]]'
  call deleteBuffer('ADC')
 }

 # Report the context file
 call write_xmlap($lvl,$xml)

 # Don't create an empty index
 unpretoc
}

macro get_autoconfig_db
{var ($lvl,$sid,$hom) = @arg
 import $TOP

 pretoc $lvl,':Database Tier'
 incr $lvl

 # Initialisation
 var $dir = catDir($hom,'appsutil','log',concat($sid,'_',${RDA.T_NODE}))
 var $xml = catFile($hom,'appsutil',concat($sid,'_',${RDA.T_NODE},'.xml'))

 # Treat adconfig.log
 debug ' In ADX module, collecting database tier adconfig.log'
 var ($adc) = grepDir($dir,'^adconfig\.log$','rt')
 if createBuffer('ADC','F',$adc)
 {# Report adconfig.log
  report adc_dblog
  prefix
  {write '---+ adconfig.log'
   write '---## Content Taken from ',encode($adc)
  }
  call writeBuffer('ADC')
  if isCreated(true)
  {write $TOP
   toc $lvl,':[[',getFile(),'][rda_report][adconfig.log]]'
  }

  # Analyze adconfig.log
  debug ' In ADX module, collecting database tier scripts in error'
  report adc_dbfail
  call write_failures('adc_dbs_','adc_dbt_')
  if isCreated(true)
   toc $lvl,':[[',getFile(),'][rda_report][Scripts in Error]]'
  call deleteBuffer('ADC')
 }

 # Report the context file
 call write_xmldb($lvl,$xml)

 # Don't create an empty index
 unpretoc
}

# Define macros to retrieve the cloning source logs
macro get_clone_source_appl
{var ($lvl,$top) = @arg
 import $TTL

 report src_cln_ap
 var $TTL = '---+!! Applications Tier Logs'
 debug ' In ADX module, collecting source StageAppsTier logs'
 call write_files('---+ StageAppsTier Log Files',5,'src_cld_',\
                  grepDir(catDir($top,'admin'),'^StageAppsTier.*\.log$','rt'))
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][Applications Tier Logs]]'
}

macro get_clone_source_db
{var ($lvl,$hom) = @arg
 import $TTL

 report src_cln_db
 var $TTL = '---+!! Database Tier Logs'
 debug ' In ADX module, collecting source StageDBTier logs'
 var $dir = catDir($hom,'appsutil','log')
 call write_files('---+ StageDBTier Log Files',5,'src_cld_',\
                  grepDir($dir,'^StageDBTier.*\.log$','rt'))
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][Database Tier Logs]]'
}

# Define macros to retrieve the cloning target logs
macro get_clone_target_appl
{var ($lvl,$top,$com) = @arg
 import $REL12,$TTL

 report tgt_cln_ap
 var $TTL = '---+!! Applications Tier Logs'
 debug ' In ADX module, collecting target applications tier CloneContext logs'
 var $dir = catDir($com,'clone','bin')
 call write_files('---+ CloneContext Log Files',5,'tgt_cla_',\
                  grepDir($dir,'^CloneContext.*\.log$','rt'))
 debug ' In ADX module, collecting target ApplyAppsTier logs'
 if $REL12
  var $dir = catDir($top,'admin','log')
 else
  var $dir = catDir($top,'admin')
 call write_files('---+ ApplyAppsTier Log Files',5,'tgt_cla_',\
                  grepDir($dir,'^ApplyAppsTier.*\.log$','rt'))
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][Applications Tier Logs]]'
}

macro get_clone_target_db
{var ($lvl,$hom) = @arg
 import $TTL

 report tgt_cln_db
 var $TTL = '---+!! Database Tier Logs'
 debug ' In ADX module, collecting target database tier CloneContext logs'
 var $dir = catDir($hom,'appsutil','clone','bin')
 call write_files('---+ CloneContext Log Files',5,'tgt_cld_',\
                  grepDir($dir,'^CloneContext.*\.log$','rt'))
 debug ' In ADX module, collecting target ApplyDBTier logs'
 var $dir = catDir($hom,'appsutil','log')
 call write_files('---+ ApplyDBTier Log Files',5,'tgt_cld_',\
                  grepDir($dir,'^ApplyDBTier.*\.log$','rt'))
 debug ' In ADX module, collecting target database tier OracleHomeCloner logs'
 if or(isWindows(),isCygwin())
  var $inv = getRegValue('HKLM\SOFTWARE\Oracle','inst_loc')
 elsif isUnix()
 {if ?testFile('e','/etc/oraInst.loc')
   var $loc = '/etc/oraInst.loc'
  elsif ?testFile('e','/var/opt/oracle/oraInst.loc')
   var $loc = '/var/opt/oracle/oraInst.loc'
  else
   var $loc = ''
  var $inv = value(grepFile($loc,'^[^#]*inventory_loc','if'))
 }
 else
  var $inv = ''
 if $inv
 {call write_files('---+ OracleHomeCloner Log Files',10,'tgt_cld_',\
                   grepDir(catDir($inv,'logs'),\
                           '^(OracleHomeCloner|apps).*\.log$','pt'))
 }
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][Database Tier Logs]]'
}

# Define a macro to retrieve configuration files
macro get_config_files
{var ($lvl,$appl,$db,$sid,$hom,$top,$app,$com,$mid,$web) = @arg

 if $appl
  call get_config_appl($lvl,$sid,$top,$app,$com,$mid,$web)
 if $db
  call get_config_db($lvl,$sid,$hom)
}

macro get_config_appl
{var ($lvl,$sid,$top,$app,$com,$mid,$web) = @arg
 import $REL12,$TOP,$TOC,$TTL

 pretoc $lvl,':Applications Tier'
 incr $lvl

 # Collect INST_TOP/APPL_TOP information
 report cfg_top
 var $ttl = cond($REL12,'INST_TOP and APPL_TOP','APPL_TOP and COMMON_TOP')
 var $TTL = concat('---+!! ',$ttl)
 debug ' In ADX module, collecting applications tier environment files'
 call write_pwd_files('---+ Environment Files','cfae_',\
                      grepDir($app,'\.env$','ip'),\
                      grepDir(catDir($app,'admin'),'\.env$','ip'))
 debug ' In ADX module, collecting applications tier DBC file'
 if $REL12
  var $dir = catDir($top,'appl','fnd','12.0.0','secure')
 else
  var $dir = catDir($top,'fnd','11.5.0','secure')
 call write_pwd_files('---+ Database Connectivity Files','cfac_',\
                      grepDir($dir,'\.dbc$','ir'))
 debug ' In ADX module, collecting applications tier scripts'
 if $REL12
  var $dir = catDir($top,'admin')
 else
  var $dir = catDir($com,'admin')
 var $pat = cond(isWindows(),'\.cmd$',\
                 isCygwin(), '\.cmd$',\
                             '\.sh$')
 call write_files('---+ Scripts',0,'cfas_',\
                  grepDir(catDir($dir,'install'),$pat,'ir'),\
                  grepDir(catDir($dir,'scripts'),$pat,'ir'))
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][',$ttl,']]'

 # Collect Tools Oracle Home information
 report cfg_tools
 var $TTL = concat("---+!! Tools Oracle Home\012---## From ",encode($mid))
 debug ' In ADX module, collecting tools environment files'
 call write_files('---+ Environment Files',0,'cfte_',\
                  grepDir($mid,'\.env$','ip'))
 debug ' In ADX module, collecting tools *.ora files'
 call write_ora_files('---+ *.ora Files','cfto_',\
                      grepDir(catDir($mid,'network','admin'),'\.ora$','idr'))
 if isCreated(true)
  toc $lvl,':[[',getFile(),\
            '][rda_report][Tools Oracle Home (',encode(basename($mid)),')]]'

 # Collect Web Oracle home information
 report cfg_web
 var $TTL = concat("---+!! Web Oracle Home\012---## From ",encode($web))
 debug ' In ADX module, collecting web environment files'
 call write_files('---+ Environment Files',0,'cfwe_',\
                  grepDir($web,'\.env$','ip'))
 debug ' In ADX module, collecting web *.conf files'
 call write_files('---+ *.conf Files',0,'cfwc_',\
                  grepDir($web,'\.conf$','idr'))
 debug ' In ADX module, collecting web *.properties files'
 call write_files('---+ *.properties Files',0,'cfwp_',\
                  grepDir($web,'\.properties$','idr'))
 debug ' In ADX module, collecting web *.ora files'
 call write_ora_files('---+ *.ora Files','cfwo_',\
                      grepDir(catDir($web,'network','admin'),'\.ora$','idr'))
 if !$REL12
 {debug ' In ADX module, collecting web *.app files'
  call write_app_files('---+ *.app Files','cfwa_',\
                       grepDir($web,'\.app$','idr'))
 }
 if isCreated(true)
  toc $lvl,':[[',getFile(),\
            '][rda_report][Web Oracle Home (',encode(basename($web)),')]]'

 # Add the context file if not yet collected
 if match($ADX_TOOL,'CFA')
 {if $REL12
   var $dir = catDir($top,'appl','admin')
  else
   var $dir = catDir($top,'admin')
  call write_xmlap($lvl,catFile($dir,concat($sid,'_',${RDA.T_NODE},'.xml')))
 }

 # Don't create an empty index
 unpretoc
}

macro get_config_db
{var ($lvl,$sid,$hom) = @arg
 import $TTL

 pretoc $lvl,':Database Tier'
 incr $lvl

 # Collect the database Oracle home information
 report cfg_db
 var $TTL = '---+!! Database Oracle Home'
 debug ' In ADX module, collecting database tier environment files'
 call write_files('---+ Environment Files',0,'cfde_',\
                  grepDir($hom,'\.env$','ip'))
 debug ' In ADX module, collecting database tier scripts'
 var $pat = cond(isWindows(),'\.cmd$',\
                 isCygwin(), '\.cmd$',\
                             '\.sh$')
 call write_files('---+ Scripts',0,'cfds_',\
                  grepDir(catDir($hom,'appsutil','scripts'),$pat,'idr'))
 debug ' In ADX module, collecting database tier *.ora files'
 call write_ora_files('---+ *.ora Files','cfdo_',\
                      grepDir(catDir($hom,'dbs'),'\.ora$','idr'),\
                      grepDir(catDir($hom,'network','admin'),'\.ora$','idr'))
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][Database Oracle Home]]'

 # Add the context file if not yet collected
 if match($ADX_TOOL,'CFA')
  call write_xmldb($lvl,\
    catFile($hom,'appsutil',concat($sid,'_',${RDA.T_NODE},'.xml')))

 # Don't create an empty index
 unpretoc
}

# Define a macro to retrieve the autoconfig scripts which errored out.
macro get_scripts
{var %tbl = ()
 call setPos('ADC')
 while getLine('ADC')
 {var $lin = chomp(last)
  if match($lin,\
           'AutoConfig could not successfully execute the following scripts:')
  {while getLine('ADC')
   {var $lin = chomp(last)
    break match($lin,'The log file for this session is located at')
    if match($lin,'Directory:')
    {var @tbl = split('\s+',$lin)
     var ($dir) = reverse(@tbl)
     if match($dir,'sqlfile=')
      var $dir = value($dir)
    }
    elsif match($lin,'INSTE8_(SETUP|PRF|APPLY)')
    {var $nam = field('\s+',0,$lin)
     var $tbl{catFile($dir,$nam)} = 1
    }
   }
   break
  }
 }
 return keys(%tbl)
}

# Define a macro to retrieve the autoconfig template corresponding to a script
macro get_template
{var ($fil,$pos) = @arg

 var $prv = ''
 call setPos('ADC',$pos)
 while getLine('ADC')
 {var $lin = chomp(last)
  break match($lin,'(AutoConfig Setup Phase|\
                     The log file for this session is located at)')
  if match($lin,verbatim($fil))
  {var (undef,undef,$hit) = split('\s+',trim($prv),3)
   return $hit
  }
  var $prv = $lin
 }
 return undef
}

# Define a macro to report AutoConfig failures
macro write_failures
{var ($pr1,$pr2) = @arg
 import $TOP

 # Define a macro to find the template section
 macro find_templates
 {call setPos('ADC')
  while getLine('ADC')
  {var $lin = chomp(last)
   if match($lin,'Configuring templates')
    return getPos('ADC')
  }
  return undef
 }

 # Look for failures
 if get_scripts()
 {var @tbl = last

  # Find the template section
  var $pos = find_templates()

  # Report the scripts in error
  prefix
  {write '---+ Scripts in Error'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               security risks. To prevent them, access the file outside the \
               browser or use the link to save them and use an adequate viewer.'
   write '|*Script*|*Template*|'
  }
  loop $fil (@tbl)
  {var $rf1 = encode($fil)
   var $tpl = cond($pos,get_template($fil,$pos))
   var $rf2 = encode($tpl)
   output d,concat($pr1,$fil)
   if ${CUR.O_LAST}->write_data($fil)
    var $rf1 = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$rf1,']]')
   end ${CUR.O_LAST}
   output d,concat($pr2,$tpl)
   if ${CUR.O_LAST}->write_data($tpl)
    var $rf2 = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$rf2,']]')
   end ${CUR.O_LAST}
   write '|',$rf1,' |',$rf2,' |'
  }
  if hasOutput(true)
   write $TOP
 }
}

# Define macros to report data files
macro write_files
{var ($ttl,$cnt,$pre,@fil) = @arg
 import $TOC,$TOP,$TTL

 prefix
 {if $TTL
  {write $TTL
   write $TOC
   var $TTL = undef
  }
  write $ttl
  if $cnt
   write 'Limited to ',$cnt,' most recent files%BR%&nbsp;'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              security risks. To prevent them, access the file outside the \
              browser or use the link to save them and use an adequate viewer.'
  write '|*File*| *Size*|*Last Modification*|'
 }
 loop $fil (@fil)
 {var $lnk = encode($fil)
  output d,concat($pre,$fil)
  if ${CUR.O_LAST}->write_data($fil)
   var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
  end ${CUR.O_LAST}
  write '|',$lnk,' | ',getSize($fil),'|',getLastModify($fil,'<UTC>'),' |'
  decr $cnt
  break !$cnt
 }
 if hasOutput(true)
  write $TOP
}

macro write_app_files
{var ($ttl,$pre,@fil) = @arg
 import $TOC,$TOP,$TTL

 prefix
 {if $TTL
  {write $TTL
   write $TOC
   var $TTL = undef
  }
  write $ttl
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              security risks. To prevent them, access the file outside the \
              browser or use the link to save them and use an adequate viewer.'
  write '|*File*| *Size*|*Last Modification*|'
 }
 loop $fil (@fil)
 {var $lnk = encode($fil)
  suspend report
  report concat($pre,$fil)
  if writeFilter($fil,'^(password\s*=).*$','%R:PASSWORD%')
   var $lnk = concat('[[',getHtmlLink(true),'][_blank][',$lnk,']]')
  resume report
  write '|',$lnk,' | ',getSize($fil),'|',getLastModify($fil,'<UTC>'),' |'
 }
 if hasOutput(true)
  write $TOP
}

macro write_ora_files
{var ($ttl,$pre,@fil) = @arg
 import $TOC,$TOP,$TTL

 prefix
 {if $TTL
  {write $TTL
   write $TOC
   var $TTL = undef
  }
  write $ttl
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              security risks. To prevent them, access the file outside the \
              browser or use the link to save them and use an adequate viewer.'
  write '|*File*| *Size*|*Last Modification*|'
 }
 loop $fil (@fil)
 {var $lnk = encode($fil)
  suspend report
  report concat($pre,$fil)
  if writeFilter($fil,'^(PASSWORDS_\w*\s*=).*$','%R:PASSWORD%')
   var $lnk = concat('[[',getHtmlLink(true),'][_blank][',$lnk,']]')
  resume report
  write '|',$lnk,' | ',getSize($fil),'|',getLastModify($fil,'<UTC>'),' |'
 }
 if hasOutput(true)
  write $TOP
}

macro write_pwd_files
{var ($ttl,$pre,@fil) = @arg
 import $TOC,$TOP,$TTL

 prefix
 {if $TTL
  {write $TTL
   write $TOC
   var $TTL = undef
  }
  write $ttl
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              security risks. To prevent them, access the file outside the \
              browser or use the link to save them and use an adequate viewer.'
  write '|*File*| *Size*|*Last Modification*|'
 }
 loop $fil (@fil)
 {var $lnk = encode($fil)
  suspend report
  report concat($pre,$fil)
  if createBuffer('PWD','F',$fil)
  {call filterBuffer('PWD','%R:PASSWORD%','si',\
                    'GUEST_USER_PWD=GUEST/','\s+',\
                    'GWYUID=APPLSYSPUB/','\s+',\
                    'GWYUID="APPLSYSPUB/','"')
   call writeBuffer('PWD')
   call deleteBuffer('PWD')
   if isCreated()
    var $lnk = concat('[[',getHtmlLink(true),'][_blank][',$lnk,']]')
  }
  resume report
  write '|',$lnk,' | ',getSize($fil),'|',getLastModify($fil,'<UTC>'),' |'
 }
 if hasOutput(true)
  write $TOP
}

# Define macros to report context files
macro write_xmlap
{var ($lvl,$fil) = @arg
 import $TOP

 debug ' In ADX module, collecting applications tier context file'
 if ?testFile('fr',$fil)
 {report xmlap
  write '---+ Context File'
  write '---## Content Taken from ',encode($fil)
  call createBuffer('XML','F',$fil)
  call filterBuffer('XML','%R:PASSWORD%','si',\
                    's_guest_pass">','</password>',\
                    's_gwyuid_pass">','</password>',\
                    's_gwyuid">APPLSYSPUB/','</GWYUID>')
  call writeBuffer('XML')
  call deleteBuffer('XML')
  if isCreated(true)
  {write $TOP
   toc $lvl,':[[',getFile(),'][rda_report][Context File]]'
  }
 }
}

macro write_xmldb
{var ($lvl,$fil) = @arg
 import $TOP

 debug ' In ADX module, collecting database tier context file'
 if ?testFile('fr',$fil)
 {report xmldb
  write '---+ Context File'
  write '---## Content Taken from ',encode($fil)
  call writeFile($fil)
  if isCreated(true)
  {write $TOP
   toc $lvl,':[[',getFile(),'][rda_report][Context File]]'
  }
 }
}

# Determine the selection
var $sel = $ADX_TOOL
if match($sel,'CLX')
{var $typ = ${W_CLONE}
 var $sel = replace($sel,'X',$typ,true)

 if match($typ,'S')
 {var $src = ${W_SRC_TIER}
  var $SRC_SID = ${T_SRC_SID}
  if match($src,'A')
  {var $src_appl = true
   var $SRC_TOP = ${D_SRC_TOP}
   var $SRC_ATP = $SRC_TOP
   if $REL12
    var $xml = catFile($SRC_TOP,'appl','admin',\
                       concat($SRC_SID,'_',${RDA.T_NODE},'.xml'))
   else
    var $xml = catFile($SRC_TOP,'admin',\
                       concat($SRC_SID,'_',${RDA.T_NODE},'.xml'))
   if ?testFile('f',$xml)
   {var $loc = xmlLoadFile($xml)
    if $REL12
     var $SRC_ATP = xmlData(xmlFind($loc,\
                            '.../oa_environments/adconfig/APPL_TOP'))
    var $SRC_COM = xmlData(xmlFind($loc,\
                           '.../oa_environment/COMMON_TOP'))
    var $SRC_MID = xmlData(xmlFind($loc,\
                           '.../oa_environment type="tools_home" /ORACLE_HOME'))
    var $SRC_WEB = xmlData(xmlFind($loc,\
                           '.../oa_environment type="web_home" /ORACLE_HOME'))
   }
  }
  else
   var $src_appl = false
  if match($src,'D')
  {var $SRC_HOM = ${D_SRC_ORACLE_HOME}
   var $src_db = true
  }
  else
   var $src_db = false
 }
 if match($typ,'T')
 {var $trg = ${W_TGT_TIER}
  var $TGT_SID = ${T_TGT_SID}
  if match($trg,'A')
  {var $tgt_appl = true
   var $TGT_TOP = ${D_TGT_TOP}
   var $TGT_ATP = $TGT_TOP
   if $REL12
    var $xml = catFile($TGT_TOP,'appl','admin',\
                       concat($TGT_SID,'_',${RDA.T_NODE},'.xml'))
   else
    var $xml = catFile($TGT_TOP,'admin',\
                       concat($TGT_SID,'_',${RDA.T_NODE},'.xml'))
   if ?testFile('f',$xml)
   {var $loc = xmlLoadFile($xml)
    if $REL12
     var $TGT_ATP = xmlData(xmlFind($loc,\
                            '.../oa_environments/adconfig/APPL_TOP'))
    var $TGT_COM = xmlData(xmlFind($loc,\
                           '.../oa_environment/COMMON_TOP'))
    var $TGT_MID = xmlData(xmlFind($loc,\
                           '.../oa_environment type="tools_home" /ORACLE_HOME'))
    var $TGT_WEB = xmlData(xmlFind($loc,\
                           '.../oa_environment type="web_home" /ORACLE_HOME'))
   }
  }
  else
   var $tgt_appl = false
  if match($trg,'D')
  {var $TGT_HOM = ${D_TGT_ORACLE_HOME}
   var $tgt_db = true
  }
  else
   var $tgt_db = false
 }
}
else
{var $typ = ${W_TIER}
 var $ADX_SID = ${T_SID}
 if match($typ,'A')
 {var $appl = true
  var $ADX_TOP = ${D_TOP}
  var $ADX_ATP = $ADX_TOP
  if $REL12
   var $xml = catFile($ADX_TOP,'appl','admin',\
                      concat($ADX_SID,'_',${RDA.T_NODE},'.xml'))
  else
   var $xml = catFile($ADX_TOP,'admin',\
                      concat($ADX_SID,'_',${RDA.T_NODE},'.xml'))
  if ?testFile('f',$xml)
  {var $obj = xmlLoadFile($xml)
   if $REL12
    var $ADX_ATP = xmlData(xmlFind($obj,\
                           '.../oa_environments/adconfig/APPL_TOP'))
   var $ADX_COM = xmlData(xmlFind($obj,\
                          '.../oa_environment/COMMON_TOP'))
   var $ADX_MID = xmlData(xmlFind($obj,\
                          '.../oa_environment type="tools_home" /ORACLE_HOME'))
   var $ADX_WEB = xmlData(xmlFind($obj,\
                          '.../oa_environment type="web_home" /ORACLE_HOME'))
  }
 }
 if match($typ,'D')
 {var $db = true
  var $ADX_HOM = ${D_ORACLE_HOME}
  var $xml = catFile($ADX_HOM,'appsutil',\
                     concat($ADX_SID,'_',${RDA.T_NODE},'.xml'))
 }
}

=head2 Rapid Clone

Collects the Rapid Clone logs and the context files.

=cut

if match($sel,'CL[ST]')
{pretoc '2:Rapid Clone'
 if match($sel,'CL\w*S')
 {pretoc '3:Source'
  if $src_appl
   call get_clone_source_appl(4,$SRC_TOP)
  if $src_db
   call get_clone_source_db(4,$SRC_HOM)
  unpretoc
 }
 if match($sel,'CL\w*T')
 {pretoc '3:Target'
  if $tgt_appl
   call get_clone_target_appl(4,$TGT_TOP,$TGT_COM)
  if $tgt_db
   call get_clone_target_db(4,$TGT_HOM)
  unpretoc
 }
 unpretoc
}

=head2 AutoConfig

Collects AutoConfig logs, the scripts that error out, and the corresponding
template files.

=cut

if match($sel,'AD[CST]')
{pretoc '2:AutoConfig'
 if match($sel,'ADC')
  call get_autoconfig(3,$appl,$db,$ADX_SID,$ADX_HOM,$ADX_TOP)
 if match($sel,'AD\w*S')
 {pretoc '3:Source'
  call setPrefix(concat($PRE,'src'))
  call get_autoconfig(4,$src_appl,$src_db,$SRC_SID,$SRC_HOM,$SRC_TOP)
  call setPrefix($PRE)
  unpretoc
 }
 if match($sel,'AD\w*T')
 {pretoc '3:Target'
  call setPrefix(concat($PRE,'tgt'))
  call get_autoconfig(4,$tgt_appl,$tgt_db,$TGT_SID,$TGT_HOM,$TGT_TOP)
  call setPrefix($PRE)
  unpretoc
 }
 unpretoc
}

=head2  Configuration

Collects Oracle Applications environment and configuration files.

=cut

if match($sel,'CF[AGST]')
{pretoc '2:Configuration'
 if match($sel,'CF[AG]')
  call get_config_files(3,$appl,$db,$ADX_SID,$ADX_HOM,\
                        $ADX_TOP,$ADX_ATP,$ADX_COM,$ADX_MID,$ADX_WEB)
 if match($sel,'CF\w*S')
 {pretoc '3:Source'
  call setPrefix(concat($PRE,'src'))
  call get_config_files(4,$src_appl,$src_db,$SRC_SID,$SRC_HOM,\
                        $SRC_TOP,$SRC_ATP,$SRC_COM,$SRC_MID,$SRC_WEB)
  call setPrefix($PRE)
  unpretoc
 }
 if match($sel,'CF\w*T')
 {pretoc '3:Target'
  call setPrefix(concat($PRE,'tgt'))
  call get_config_files(4,$tgt_appl,$tgt_db,$TGT_SID,$TGT_HOM,\
                        $TGT_TOP,$TGT_ATP,$TGT_COM,$TGT_MID,$TGT_WEB)
  call setPrefix($PRE)
  unpretoc
 }
 unpretoc
}
unpretoc

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
