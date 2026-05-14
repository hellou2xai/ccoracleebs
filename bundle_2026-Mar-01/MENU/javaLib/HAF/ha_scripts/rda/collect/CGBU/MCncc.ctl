# MCncc.ctl:130:Performs Network Charging and Control Multi-run Collections
# $Id: MCncc.ctl,v 1.11 2015/08/21 16:15:16 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/MCncc.ctl,v 1.11 2015/08/21 16:15:16 RDA Exp $
#
# Change History
# 20150529  KRA  Improve the documentation.

=head1 NAME

CGBU:MCncc - Performs Network Charging and Control Multi-run Collections

=head1 DESCRIPTION

This module regroups multi-run collections specific to the Network Charging and
Control.

=cut

use Mrc

# Initialization
var @COMMON_SECTIONS = (\
  'NCC_app_version','NCC_app1_overview','NCC_app2_soft_links',\
  'NCC_app3_config','NCC_app4_acs_controlplan','NCC_app4_acs_provinfo',\
  'NCC_app5_ccs_provinfo','NCC_app6_svc_pkg','NCC_cron','NCC_dev','NCC_etc',\
  'NCC_html','NCC_nagios','NCC_profiles','NCC_sys','NCC_usr')
keep @COMMON_SECTIONS

var $HOME = ${SET.CGBU.NCC.D_HOME:'/IN/service_packages'}
var $LOG  = ${SET.CGBU.NCC.B_COLLECT_LOG:false}

var %DUP = ()
var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
keep $HOME,$LOG,$PRE,$TOC,$TOP,%DUP

# --- begin section -----------------------------------------------------------
section begin

# Load the common macros
run CGBU:NCClib()
run RDA:library()

# Set the NCC symbols
call setSymbol('$NCC_BASE','/IN')
call setSymbol('$NCC_HOME',$HOME)

# Set the environment for SMS server
var %env = ()
if and(testFile('fx',catFile($HOME,'SMS','bin','smsMaster')),\
       testFile('fx',catFile($HOME,'SMS','bin','smsDumpRepConfig')))
{var $lib = getLocalEnv($key = ${CUR.W_SHLIB})
 call setLocalEnv($key,join(':',$lib,catDir($HOME,'SMS','lib')))
 var $env{$key} = $lib
}

# --- end section -------------------------------------------------------------
section end

# Restore the initial environment
loop $key (keys(%env))
 call setLocalEnv($key,$env{$key})

=head1 NETWORK CHARGING AND CONTROL MULTI-RUN COLLECTIONS

=head2 version - Version

Collects the output of the F</IN/bin/ocncc> command.

=cut

section NCC_app_version

debug ' Inside NCC module, getting OCNCC version information'
report version
var $cmd = '/IN/bin/ocncc'
prefix
{write '---+ OCNCC Version'
 write '---## Using: ',encode($cmd)
}
call writeCommand($cmd)
if isCreated(true)
{call validate(true)
 write $TOP
 toc '2:[[',getFile(),'][rda_report][Version]]'
}

=head2 overview - Service Package Overview

Lists the content of the F<$HOME> directory.

=cut

section NCC_app1_overview

debug ' Inside NCC module, listing the files in ',$HOME,' directory'
report overview
prefix
{write '---+ Service Package Overview'
 write '---## Information Taken from ',encode($HOME)
}
call statDir('an',$HOME)
if isCreated(true)
{call validate(true)
 write $TOP
 toc '2:[[',getFile(),'][rda_report][Service Package Overview]]'
}

=head2 soft_links - Service Package Soft Links

Lists all soft link files present in the F<$HOME> directory.

=cut

section NCC_app2_soft_links

debug ' Inside NCC module, listing the soft link files in ',$HOME,' directory'
report soft_links
prefix
{write '---+ Service Package Soft Links'
 write '---## Information Taken from ',encode($HOME)
}
var @fil = ()
loop $fil (grepDir($HOME,'^\.+$','drv'))
{if ?testFile('l',$fil)
  call push(@fil,$fil)
}
call statFile('p',@fil)
if isCreated(true)
{call validate(true)
 write $TOP
 toc '2:[[',getFile(),'][rda_report][Service Package Soft Links]]'
}

=head2 Configuration Files

Collects the F<eserv.config> configuration file from known locations.

=cut

section NCC_app3_config

debug ' Inside NCC module, gathering eserv.config configuration file'
pretoc '2:Configuration Files'
var %fil = ()
var $fil{catFile($HOME,'eserv.config')} = 1
var $fil{catFile($HOME,'eserv.config.scs')} = 1
var $fil{catFile($HOME,'mmx.config')} = 1
loop $nam (grepDir($HOME,'^\.+$','n'))
{if ?testDir('d',catDir($HOME,$nam,'bin'))
 {loop $fil (grepDir(lastDir(),'\.sh$','np'))
  {if grepFile($fil,'^ESERV_CONFIG_FILE=(.*)$','f1')
    var $fil{first(last)} = 1
  }
 }
}
loop $fil (grepDir($HOME,'\beserv\b','np'))
{next ?testFile('d',$fil)
 next match($fil,'(example|\.sh$)')
 var $fil{$fil} = 1
}
loop $fil (keys(%fil))
{report concat('cfg_',$nam = basename($fil))
 if createBuffer('NCC','R',$fil)
 {prefix
  {write '---+ Display of ',encode($nam),' File'
   write '---## Information Taken from ',encode($fil)
   write '<verbatim>'
  }
  while ?getLine('NCC')
  {var $lin = chomp(last)
   if and($skp,match($lin,'^\s*\]'))
    var $skp = false
   next $skp
   if match($lin,'(origAddress|destAddress|callingPartyNumber|\
                   destinationSubscriberNumber)\s*=\s*\[')
   {write substr($lin,0,expr('+',index($lin,'['),1))
    write ' ##### CONFIDENTIAL DATA - NUMBERS HAVE BEEN REMOVED FROM \
                  SUPPORT_AUDIT #####'
    var $skp = true
   }
   if !$skp
    write $lin
   elsif match($lin,'\]')
   {if match($lin,'origAddress')
     write substr($lin,0,index($lin,'origAddress')),' ]'
    elsif match($lin,'destAddress')
     write substr($lin,0,index($lin,'destAddress')),' ]'
    elsif match($lin,'callingPartyNumber')
     write substr($lin,0,index($lin,'callingPartyNumber')),' ]'
    elsif match($lin,'destinationSubscriberNumber')
     write substr($lin,0,index($lin,'destinationSubscriberNumber')),' ]'
    var $skp = false
   }
  }
  if isCreated(true)
  {write '</verbatim>'
   write $TOP
   toc '3:[[',getFile(),'][rda_report][',encode($nam),']]'
  }
  call deleteBuffer('NCC')
 }
}
unpretoc
call validate(true)

=head2 acs_controlplan - ACS Control Plan Information

Collects ACS control plan information using the
F<$HOME/ACS/bin/acsDumpControlPlan> command.

=cut

section NCC_app4_acs_controlplan

debug ' Inside NCC module, gathering ACS control plan information'
if and(${SET.CGBU.NCC.B_DB},\
       testFile('fx',$cmd = catFile($HOME,'ACS','bin','acsDumpControlPlan')))
{var $box = cleanBox()
 var ($sid,$usr) = (${SET.CGBU.NCC.T_ORACLE_SID/P},${SET.CGBU.NCC.T_USER/P})
 var $PWD = ['Oracle',$sid,$usr,"Enter '${VAR.usr}' at '${VAR.sid}' user \
                                 password for collecting ACS control plan:",'']
 if loadCommand(\
   {cmd => concat(lastTestCommand(),' -u ',quote($usr),'/%s -S -d ',$box),\
    pwd => $PWD})
 {report acs_controlplan
  prefix
  {write '---+ ACS Control Plan Information'
   write '---## Using: ',encode($cmd)
   write '   * Links point to files that have been collected in their \
               original format. Opening them directly in your browser \
               can present risks. To prevent them, access the file \
               outside the browser or use the link to save them and use \
               an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $fil (grepDir($box,'\.cpl$','np'))
  {if ?testFile('fr',$fil)
   {var $lnk = encode($nam = basename($fil))
    if $siz = getSize($fil)
    {output d,concat('cpl_',$nam)
     if ${CUR.O_LAST}->write_data($fil)
      var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                        '][_blank][',$lnk,']]')
     end ${CUR.O_LAST}
    }
    write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
   }
  }
  if isCreated(true)
  {call validate(true)
   write $TOP
   toc '2:[[',getFile(),'][rda_report][ACS Control Plan Information]]'
  }
 }
}

=head2 acs_prov_info - ACS Provisioning Information

Collects the ACS Provisioning information using the
F<$HOME/SUPPORT/bin/acsTableRowCounts.sh> command.

=cut

section NCC_app4_acs_provinfo

debug ' Inside NCC module, gathering ACS provisioning information'
report acs_prov_info
if ?testFile('fx',$cmd = catFile($HOME,'SUPPORT','bin','acsTableRowCounts.sh'))
{if grepCommand('/usr/bin/pkginfo -l acsSms',\
               '^\s*STATUS:\s*completely installed','fi')
 {prefix
  {write '---+ ACS Provisioning Information'
   write '---## Using: ',encode($cmd)
  }
  call writeCommand(quote($cmd))
  if isCreated(true)
  {call validate(true)
   write $TOP
   toc '2:[[',getFile(),'][rda_report][ACS Provisioning Information]]'
  }
 }
}

=head2 ccs_prov_info - CCS Provisioning Information

Collects the CCS Provisioning information using the
F<$HOME/SUPPORT/bin/ccsTableRowCounts.sh> command.

=cut

section NCC_app5_ccs_provinfo

debug ' Inside NCC module, gathering CCS provisioning information'
report ccs_prov_info
if ?testFile('fx',$cmd = catFile($HOME,'SUPPORT','bin','ccsTableRowCounts.sh'))
{if grepCommand('/usr/bin/pkginfo -l ccsSms',\
  '^\s*STATUS:\s*completely installed','fi')
 {prefix
  {write '---+ CCS Provisioning Information'
   write '---## Using: ',encode($cmd)
  }
  call writeCommand(quote($cmd))
  if isCreated(true)
  {call validate(true)
   write $TOP
   toc '2:[[',getFile(),'][rda_report][CCS Provisioning Information]]'
  }
 }
}

=head1 SERVICE PACKAGE FILES

Performs the following collections on all the subdirectories present in the
F<$HOME> directory:

=head2 sp_<pkg>_overview - Overview

Lists the content of the F<$HOME/E<lt>pkgE<gt>> directory.

=cut

section NCC_app6_svc_pkg

loop $sub (findDir($HOME,concat('^(',join('|','\.+',\
  map(@{SET.CGBU.NCC.T_EXCLUDE_LIST:'RAS_SERVER'},code(verbatim(last)))),\
  ')$'),'nv'))
{var $top = catDir($HOME,$sub)
 call setPrefix($pre = concat($PRE,'sp_',lc($sub)))
 pretoc '%SPLIT%'
 pretoc '1+:',$sub,' Files'
 debug ' Inside NCC module, analyzing ',$top,' directory'

 # Collect patch information
 if compare('eq',$sub,'PATCH')
 {report overview
  prefix
  {write "---+ '",$sub,"' Overview"
   write '---## Information Taken from ',encode($top)
  }
  loop $dir ($top,findDir($top,'^\.+$','drv'))
   call statDir('an',$dir)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Overview]]'
  }
 }
 else
 {# Get the overview
  report overview
  prefix
  {write "---+ '",$sub,"' Overview"
   write '---## Information Taken from ',encode($top)
  }
  call statDir('n',$top)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Overview]]'
  }

=head2 Generic Files

Collects the environment files from the F<$HOME/E<lt>pkgE<gt>> directory.

=cut

  pretoc '2:Generic Files'
  call sort_all_files(3,0,catFile($top,'.inventory'),\
                          catFile($top,'.rhosts'),\
                          grepDir($top,'\.profile','np'))
  unpretoc

=head3 sp_<pkg>_chksum - Check Sum Information

Collects the check sum information from the F<$HOME/E<lt>pkgE<gt>> directory.

=cut

  call get_chksum($top,3,$sub)

=head2 <pkg>/bin Files

=cut

  call setPrefix(concat($pre,'_bin'))
  var ($bin,$ttl) = (catDir($top,'bin'),concat($sub,'/bin'))
  pretoc '2:',$ttl,' Files'

=head3 sp_<pkg>_bin_overview - Overview

Lists the content of the F<$HOME/E<lt>pkgE<gt>/bin> directory.

=cut

  report overview
  prefix
  {write "---+ '",$ttl,"' Overview"
   write '---## Information Taken from ',encode($bin)
  }
  call statDir('n',$bin)
  if isCreated(true)
  {write $TOP
   toc '3:[[',getFile(),'][rda_report][Overview]]'
  }

=head3 Script Files

Collects the script files from the F<$HOME/E<lt>pkgE<gt>/bin> directory.

=cut

  pretoc '3:Script Files'
  call sort_all_files(4,0,get_scripts($bin,false))
  unpretoc

=head3 sp_<pkg>_bin_chksum - Check Sum Information

Collects the check sum information from the F<$HOME/E<lt>pkgE<gt>/bin>
directory.

=cut

  call get_chksum($bin,3,$ttl)
  unpretoc

=head2 <pkg>/etc Files

=cut

  call setPrefix(concat($pre,'_etc'))
  var ($etc,$ttl) = (catDir($top,'etc'),concat($sub,'/etc'))
  pretoc '2:',$ttl,' Files'

=head3 sp_<pkg>_etc_overview - Overview

Lists the content of the F<$HOME/E<lt>pkgE<gt>/etc> directory.

=cut

  report overview
  prefix
  {write "---+ '",$ttl,"' Overview"
   write '---## Information Taken from ',encode($etc)
  }
  call stat_tree($etc)
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][Overview]]'

=head3 Configuration Files

Collects the configuration files from the F<$HOME/E<lt>pkgE<gt>/etc> directory.

=cut

  pretoc '3:Configuration Files'
  call sort_all_files(4,0,get_files($etc))
  unpretoc 2

=head2 <pkg>/lib Files

=cut

  call setPrefix(concat($pre,'_lib'))
  var ($lib,$ttl) = (catDir($top,'lib'),concat($sub,'/lib'))
  pretoc '2:',$ttl,' Files'

=head3 sp_<pkg>_lib_overview - Overview

Lists the content of the F<$HOME/E<lt>pkgE<gt>/lib> directory.

=cut

  report overview
  prefix
  {write "---+ '",$ttl,"' Overview"
   write '---## Information Taken from ',encode($lib)
  }
  call stat_tree($lib)
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][Overview]]'

=head3 sp_<pkg>_lib_chksum - Check Sum Information

Collects the check sum information from the F<$HOME/E<lt>pkgE<gt>/lib>
directory.

=cut

  call get_chksum($lib,3,$ttl)
  unpretoc

=head2 <pkg>/tmp Files

=cut

  call setPrefix(concat($pre,'_tmp'))
  var ($tmp,$ttl) = (catDir($top,'tmp'),concat($sub,'/tmp'))
  pretoc '2:',$ttl,' Files'

=head3 sp_<pkg>_tmp_overview - Overview

Lists the content of the F<$HOME/E<lt>pkgE<gt>/tmp> directory.

=cut

  report overview
  prefix
  {write "---+ '",$ttl,"' Overview"
   write '---## Information Taken from ',encode($tmp)
  }
  call stat_tree($tmp)
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][Overview]]'

=head3 Log Files

Collects the C<*.log> files from the F<$HOME/E<lt>pkgE<gt>/tmp> directory.

=cut

  if $LOG
  {pretoc '3:Log Files'
   call sort_all_files(4,0,grepDir($tmp,'\.log$','inp'))
   unpretoc
  }
  unpretoc

=head2 <pkg>/db/install Files

=cut

  call setPrefix(concat($pre,'_db'))
  var ($db,$ttl) = (catDir($top,'db','install'),concat($sub,'/db/install'))
  pretoc '2:',$ttl,' Files'

=head3 sp_<pkg>_db_overview - Overview

Lists the content of the F<$HOME/E<lt>pkgE<gt>/db/install> directory.

=cut

  report overview
  prefix
  {write "---+ '",$ttl,"' Overview"
   write '---## Information Taken from ',encode($db)
  }
  call statDir('n',$db)
  if isCreated(true)
  {write $TOP
   toc '3:[[',getFile(),'][rda_report][Overview]]'
  }

=head3 sp_<pkg>_db_chksum - Check Sum Information

Collects the check sum information from the F<$HOME/E<lt>pkgE<gt>/db/install>
directory.

=cut

  call get_chksum($db,3,$ttl)

=head3 Script Files

Collects the script files from the F<$HOME/E<lt>pkgE<gt>/db/install> directory.

=cut

  pretoc '3:Script Files'
  call sort_all_files(4,0,grepDir($db,'\.sh$','np'))
  unpretoc 2
  call setPrefix($pre)

=head2 Log Data Extracted

Extracts C<ACS> and C<CCS> related-data from the F<$HOME/SUPPORT/tmp/acsT*.log>
and F<$HOME/SUPPORT/tmp/ccsT*.log> files in C<.csv> format.

=cut

  if match($sub,'^[AC]CS$')
  {pretoc '2:Log Data Extracted'
   if grepDir(catDir(\
    $HOME,'SUPPORT','tmp'),concat('^',lc($sub),'T.*\.log$'),'pt')
   {var ($fil) = last
    var ($rec,$csv,$dat,$hdr,$tim) = (false)
    if createBuffer('LOG','R',$fil)
    {var $rpt = $[OUT]->add_report('D',$nam = basename($fil,'.log'),0,'.csv')
     while ?getLine('LOG')
     {var $lin = chomp(last)
      next match($lin,'^(\s*$|-+|\s+,-+|\d+\s+rows)')
      if match($lin,'^(\d{4}(\/\d{2}){2})\s+(\d{2}:\d{2})')
      {var ($dat,undef,$tim) = last
       var $tim = concat($tim,':00')
      }
      elsif match($lin,'^[AC]CS\s')
      {if !?$hdr
       {var $hdr = concat("Date      ,Time    ,",$lin)
        prefix $rpt
        {write {$rpt} $hdr
         var $csv = concat('[[',$rpt->get_raw(true),'][_blank][',\
                           concat($nam,'.csv'),']]')
        }
       }
       var $rec = true
      }
      elsif $rec
      {write {$rpt} $dat,",",$tim,",",$lin
       if match($lin,'^Total')
        var $rec = false
      }
     }
     end $rpt
     report $bas = basename($fil)
     prefix
     {write "---+ '",$sub,"' Extracted Data"
      write '---## Information Extracted from ',encode($fil)
      write '   * Links point to files that have been collected in their \
                  original format. Opening them directly in your browser can \
                  present risks. To prevent them, access the file outside the \
                  browser or use the link to save them and use an adequate \
                  viewer.'
      write '|*CSV File*|'
     }
     if ?$csv
      write '|',$csv,' |'
     if isCreated(true)
      toc '3:[[',getFile(),'][rda_report][',encode($bas),']]'
     call deleteBuffer('LOG')
    }
   }
   unpretoc
  }

=for stopwords MFile

=head2 CCS/MFile Files

=cut

  if and(compare('eq',$sub,'CCS'),testDir('d',$mfil = catDir($top,'MFile')))
  {call setPrefix(concat($pre,'_mfil'))
   var $ttl = concat($sub,'/MFile')
   pretoc '2:',$ttl,' Files'

=head3 sp_ccs_mfil_overview - Overview

Lists the content of the F<$HOME/CCS/MFile> directory.

=cut

   report overview
   prefix
   {write "---+ '",$ttl,"' Overview"
    write '---## Information Taken from ',encode($mfil)
   }
   call statDir('n',$mfil)
   if isCreated(true)
   {write $TOP
    toc '3:[[',getFile(),'][rda_report][Overview]]'
   }
   unpretoc
  }

=head2 DRS/backup Files

=cut

  elsif and(compare('eq',$sub,'DRS'),testDir('d',$bkp = catDir($top,'backup')))
  {call setPrefix(concat($pre,'_bkp'))
   var $ttl = concat($sub,'/backup')
   pretoc '2:',$ttl,' Files'

=head3 sp_drs_bkp_overview - Overview

Lists the content of the F<$HOME/DRS/backup> directory.

=cut

   report overview
   prefix
   {write "---+ '",$ttl,"' Overview"
    write '---## Information Taken from ',encode($bkp)
   }
   call stat_tree($bkp)
   if isCreated(true)
    toc '3:[[',getFile(),'][rda_report][Overview]]'

=head3 Script Files

Collects the script files from the F<$HOME/DRS/backup> directory.

=cut

   pretoc '3:Script Files'
   call sort_all_files(4,0,grepDir($bkp,'\.sh$','np'))
   unpretoc 2
  }

=head2 KPN_SERVICES/<svc> Files

Performs the following collections on all subdirectories present in the
F<$HOME/KPN_SERVICES/E<lt>svcE<gt>> directory:

=cut

  elsif compare('eq',$sub,'KPN_SERVICES')
  {loop $svc (findDir($top,'^\.+$','nv'))
   {var $dir = catDir($top,$svc)
    call setPrefix(concat($pre,'_',$svc))
    var $ttl = concat($sub,'/',$svc)
    pretoc '2:',$ttl,' Files'

=head3 sp_kpn_services_<svc>_overview - Overview

Lists the content of the F<$HOME/KPN_SERVICES/E<lt>svcE<gt>> directory.

=cut

    report overview
    prefix
    {write "---+ '",$ttl,"' Overview"
     write '---## Information Taken from ',encode($dir)
    }
    call statDir('n',$dir)
    if isCreated(true)
    {write $TOP
     toc '3:[[',getFile(),'][rda_report][Overview]]'
    }

=head3 sp_kpn_services_<svc>_chksum - Check Sum Information

Collects the check sum information from the F<$HOME/KPN_SERVICES/E<lt>svcE<gt>>
directory.

=cut

    call get_chksum($dir,3,$ttl)

=head2 KPN_SERVICES/<svc>/bin Files

=cut

    call setPrefix(concat($pre,'_',$svc,'_bin'))
    var ($bin,$ttl) = (catDir($dir,'bin'),concat($sub,'/',$svc,'/bin'))
    pretoc '3:',$ttl,' Files'

=head3 sp_kpn_services_<svc>_bin_overview - Overview

Lists the content of the F<$HOME/KPN_SERVICES/E<lt>svcE<gt>/bin> directory.

=cut

    report overview
    prefix
    {write "---+ '",$ttl,"' Overview"
     write '---## Information Taken from ',encode($bin)
    }
    call statDir('n',$bin)
    if isCreated(true)
    {write $TOP
     toc '4:[[',getFile(),'][rda_report][Overview]]'
    }

=head3 Script Files

Collects the script files from the F<$HOME/KPN_SERVICES/E<lt>svcE<gt>/bin>
directory.

=cut

    pretoc '4:Script Files'
    call sort_all_files(5,0,grepDir($bin,'\.sh$','np'))
    unpretoc 2

=head2 KPN_SERVICES/<svc>/etc Files

=cut

    call setPrefix(concat($pre,'_',$svc,'_etc'))
    var ($etc,$ttl) = (catDir($dir,'etc'),concat($sub,'/',$svc,'/etc'))
    pretoc '3:',$ttl,' Files'

=head3 sp_kpn_services_<svc>_etc_overview - Overview

Lists the content of the F<$HOME/KPN_SERVICES/E<lt>svcE<gt>/etc> directory.

=cut

    report overview
    prefix
    {write "---+ '",$ttl,"' Overview"
     write '---## Information Taken from ',encode($etc)
    }
    call stat_tree($etc)
    if isCreated(true)
     toc '4:[[',getFile(),'][rda_report][Overview]]'

=head3 Configuration Files

Collects the configuration files from the
F<$HOME/KPN_SERVICES/E<lt>svcE<gt>/etc> directory.

=cut

    pretoc '4:Configuration Files'
    call sort_all_files(5,0,get_files($etc))
    unpretoc 2

=head2 KPN_SERVICES/<svc>/lib Files

=cut

    call setPrefix(concat($pre,'_',$svc,'_lib'))
    var ($lib,$ttl) = (catDir($dir,'lib'),concat($sub,'/',$svc,'/lib'))
    pretoc '3:',$ttl,' Files'

=head3 sp_kpn_services_<svc>_lib_overview - Overview

Lists the content of the F<$HOME/KPN_SERVICES/E<lt>svcE<gt>/lib> directory.

=cut

    report overview
    prefix
    {write "---+ '",$ttl,"' Overview"
     write '---## Information Taken from ',encode($lib)
    }
    call stat_tree($lib)
    if isCreated(true)
     toc '4:[[',getFile(),'][rda_report][Overview]]'

=head3 sp_kpn_services_<svc>_lib_chksum - Check Sum Information

Collects the check sum information from the
F<$HOME/KPN_SERVICES/E<lt>svcE<gt>/lib> directory.

=cut

    call get_chksum($lib,4,$ttl)
    unpretoc 2

=head2 KPN_SERVICES/<svc>/tmp Files

=cut

    call setPrefix(concat($pre,'_',$svc,'_tmp'))
    var ($tmp,$ttl) = (catDir($dir,'tmp'),concat($sub,'/',$svc,'/tmp'))
    pretoc '3:',$ttl,' Files'

=head3 sp_kpn_services_<svc>_tmp_overview - Overview

Lists the content of the F<$HOME/KPN_SERVICES/E<lt>svcE<gt>/tmp> directory.

=cut

    report overview
    prefix
    {write "---+ '",$ttl,"' Overview"
     write '---## Information Taken from ',encode($tmp)
    }
    call stat_tree($tmp)
    if isCreated(true)
     toc '4:[[',getFile(),'][rda_report][Overview]]'
    unpretoc 2

=head2 Additional Locations

Collects additional configuration files from the F</home/admin> directory and
its subdirectories.

=cut

    pretoc '2:Additional Locations'
    call sort_all_files(3,0,'/home/admin/Env_Check/checkconf.sh',\
                            '/home/admin/Env_Check/getconf.sh',\
                            get_files('/home/admin/tools/bin',\
                                      '/home/admin/tools/cfg',\
                                      '/home/admin/clean/bin',\
                                      '/home/admin/clean/cfg',\
                                      '/home/admin/info/cfg',\
                                      '/home/admin/menu/bin',\
                                      '/home/admin/menu/cfg',\
                                      '/home/admin/kloon/bin',\
                                      '/home/admin/kloon/cfg'))
    unpretoc
   }
  }

=for stopwords msgs

=head2 SLEE/msgs Files

=head3 Configuration Files

Collects the configuration files from the F<$HOME/SLEE/msgs> directory.

=cut

  elsif and(compare('eq',$sub,'SLEE'),testDir('d',$msg = catDir($top,'msgs')))
  {call setPrefix(concat($pre,'_msgs'))
   pretoc '2:',$sub,'/msgs Files'
   pretoc '3:Configuration Files'
   call sort_all_files(4,0,grepDir($msg,'^\.+$','drv'))
   unpretoc 2
  }

=head2 SMS Files

=for stopwords smsDumpRepConfig

=head3 sp_sms_repconfig - smsDumpRepConfig

Collects smsDumpRepConfig information using the
F<$HOME/SMS/bin/smsDumpRepConfig> command.

=cut

  elsif compare('eq',$sub,'SMS')
  {if ?testFile('fx',$cmd = catFile($top,'bin','smsDumpRepConfig'))
   {report repconfig
    prefix
    {write '---+ smsDumpRepConfig Information'
     write '---## Using: ',encode($cmd)
    }
    call writeCommand(concat(quote($cmd),' 2>&1'))
    if isCreated(true)
    {write $TOP
     toc '2:[[',getFile(),'][rda_report][smsDumpRepConfig]]'
    }
   }

=head2 SMS/input Files

=cut

   if ?testDir('d',$inp = catDir($top,'input'))
   {call setPrefix(concat($pre,'_inp'))
    var $ttl = concat($sub,'/input')
    pretoc '2:',$ttl,' Files'

=head3 sp_sms_inp_overview - Overview

Lists the content of the F<$HOME/SMS/input> directory.

=cut

    report overview
    prefix
    {write "---+ '",$ttl,"' Overview"
     write '---## Information Taken from ',encode($inp)
    }
    call stat_tree($inp)
    if isCreated(true)
     toc '3:[[',getFile(),'][rda_report][Overview]]'

=head3 Configuration Files

Collects the configuration files from the F<$HOME/SMS/input> directory.

=cut

    pretoc '3:Configuration Files'
    call sort_all_files(4,0,grepDir($inp,'\.(sh|sql|pl|cfg|conf|awk)$','dr'))
    unpretoc 2
   }
  }
 }
 unpretoc 2

 # Restore module prefix
 call setPrefix($PRE)
}
call validate(true)

=head1 SYSTEM FILES

Collects the following system related files:

=head2 crontabs Files

Collects crontabs-related files.

=cut

section NCC_cron

debug ' Inside NCC module, gathering crontab files'
var ($top,@fil) = ('/var/spool/cron/crontabs')
call setPrefix(concat($PRE,'s_crontabs'))
pretoc '%SPLIT%'
pretoc '1+:crontabs Files'
if loadFile('/etc/passwd')
{loop $nam (grepDir($top,'^\.+$','nv'))
 {if grepLastFile(concat('^',verbatim($nam),':'),'f')
   call push(@fil,catFile($top,$nam))
 }
}
loop $fil ('/etc/cron.d/cron.allow','/etc/cron.d/cron.deny')
{if ?testFile('fr',$fil)
  call push(@fil,$fil)
}
call sort_all_files(2,0,@fil)
call validate(true)
unpretoc 2

# Restore module prefix
call setPrefix($PRE)

=head2 dev Files

=head3 s_dev_rdsk_overview - Overview

Lists the content of the F</dev/rdsk> directory.

=cut

section NCC_dev

debug ' Inside NCC module, listing files present in /dev/rdsk directory'
call setPrefix(concat($PRE,'s_dev_rdsk'))
pretoc '%SPLIT%'
pretoc '1+:dev Files'
var $dir = '/dev/rdsk'
report overview
prefix
 write "---+ '/dev/rdsk' Overview"
call statDir('n',$dir)
if isCreated(true)
{call validate(true)
 write $TOP
 toc '2:[[',getFile(),'][rda_report][Overview]]'
}
unpretoc 2

# Restore module prefix
call setPrefix($PRE)

=head2 etc Files

=cut

section NCC_etc

pretoc '%SPLIT%'
pretoc '1+:etc Files'

=head3 Configuration Files

Collects the configuration files from the F</etc> directory.

=cut

debug ' Inside NCC module, gathering files from /etc directory'
pretoc '2:Configuration Files'
call setPrefix($pre = concat($PRE,'s_etc'))
var @fil = ()
loop $dir (findDir('/etc/net','^tic','np'))
 call push(@fil,grepDir($dir,'^\.+$','drv'))
call sort_all_files(3,0,\
  '/etc/auto_master',\
  '/etc/coreadm.conf',\
  '/etc/defaultdomain',\
  '/etc/defaultrouter',\
  '/etc/filelist.txt',\
  '/etc/fstab',\
  '/etc/group',\
  '/etc/hosts',\
  '/etc/logadm.conf',\
  '/etc/inet/netmasks',\
  '/etc/inetd.conf',\
  '/etc/inittab',\
  '/etc/nodename',\
  '/etc/nsswitch.conf',\
  '/etc/oratab',\
  '/etc/path_to_inst',\
  '/etc/passwd',\
  '/etc/power.conf',\
  '/etc/profile',\
  '/etc/project',\
  '/etc/release',\
  '/etc/resolv.conf',\
  '/etc/routes.conf',\
  '/etc/services',\
  '/etc/syslog.conf',\
  '/etc/TIMEZONE',\
  grepDir('/etc','^(hostname\.|system|ssh.*_config$|vfstab)','p'),\
  grepDir('/etc/init.d','^\.+$','pv'),\
  grepDir('/usr/local/etc','^ssh.*_config','p'),\
  '/usr/local/etc/sudoers',\
  @fil)
unpretoc

=for stopwords init

=head3 s_etc_initd_overview - /etc/init.d Overview

Lists the content of the F</etc/init.d> directory.

=cut

debug ' Inside NCC module, gathering contents of /etc/init.d directory'
call setPrefix(concat($pre,'_initd'))
report overview
prefix
 write "---+ '/etc/init.d' Overview"
call statDir('n','/etc/init.d')
if isCreated(true)
{write $TOP
 toc '2:[[',getFile(),'][rda_report][/etc/init.d Overview]]'
}

=for stopwords rc

=head3 s_etc_rcd_overview - /etc/rc?.d Overview

Lists the content of the F</etc/rc?.d> directory.

=cut

debug ' Inside NCC module, gathering contents of /etc/rc?.d directory'
call setPrefix(concat($pre,'_rcd'))
report overview
prefix
 write "---+ '/etc/rc?.d' Overview"
loop $dir (findDir('/etc','^rc.\.d$','np'))
 call statDir('n',$dir)
if isCreated(true)
{write $TOP
 toc '2:[[',getFile(),'][rda_report][/etc/rc?.d Overview]]'
}
call validate(true)
unpretoc 2

# Restore module prefix
call setPrefix($PRE)

=for stopwords html

=head2 html Files

=cut

section NCC_html

var ($sub,$top) = ('html','/IN/html')
call setPrefix(concat($PRE,'s_',$sub))
pretoc '%SPLIT%'
pretoc '1+:',$sub,' Files'
debug ' Inside NCC module, gathering contents from ',$top,' directory'

=head3 s_html_overview - Overview

Lists the content of the F</IN/html> directory.

=cut

report overview
prefix
{write "---+ '",$sub,"' Overview"
 write '---## Information Taken from ',encode($top)
}
call stat_tree($top)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Overview]]'

=head3 s_html_chksum - Check Sum Information

Collects the check sum information from the F</IN/html> directory.

=cut

call get_chksum($top,2,$sub)

=head3 s_html_chksum - Check Sum Information

Collects the check sum information from the F</IN/html> directory.

=cut

call get_chksum($top,2,$sub)

=head3 Configuration Files

Collects the configuration files from the F</IN/html> directory.

=cut

pretoc '2:Configuration Files'
var @fil = ()
loop $dir (findDir($top,'^PlugInPanels$','dr',1))
 call push(@fil,grepDir($dir,'\.pix$','np'))
call sort_all_files(3,0,\
  catFile($top,'Ccs_Service','cdr','cdrDetailsConfig.conf'),\
  grepDir($top,'\.html$','np'),\
  @fil)
unpretoc 3
call validate(true)

# Restore module prefix
call setPrefix($PRE)

=head2 nagios Files

Collects the following nagios related files from either server or client
machine:

=cut

section NCC_nagios

var $top = '/usr/local/nagios'
call setPrefix($pre = concat($PRE,'s_nagios'))
pretoc '%SPLIT%'
pretoc '1+:nagios Files'
debug ' Inside NCC module, gathering contents from ',$top,' directory'
if ?testFile('fr',catFile($top,'bin','nagios'))
 pretoc '2:Server Files'
else
 pretoc '2:Client Files'

=head3 nagios/bin Script Files

Collects the script files from the F</usr/local/nagios/bin> directory.

=cut

call setPrefix(concat($pre,'_bin'))
pretoc '3:nagios/bin Files'
pretoc '4:Script Files'
call sort_all_files(5,0,get_scripts(catDir($top,'bin'),true))
unpretoc 2

=for stopwords libexec

=head3 nagios/libexec Script Files

Collects the script files from the F</usr/local/nagios/libexec> directory.

=cut

call setPrefix(concat($pre,'_libexec'))
pretoc '3:nagios/libexec Files'
pretoc '4:Script Files'
call sort_all_files(5,0,get_scripts(catDir($top,'libexec'),true))
unpretoc 2

=for stopwords nagios

=head3 nagios/etc Configuration Files

Collects the configuration files from the F</usr/local/nagios/etc> directory.

=cut

call setPrefix(concat($pre,'_etc'))
pretoc '3:nagios/etc Files'
pretoc '4:Configuration Files'
call sort_all_files(5,0,get_files(catDir($top,'etc')))
unpretoc 2

=head3 nagios/share/reports/specs Configuration Files

Collects the configuration files from the
F</usr/local/nagios/share/reports/specs> directory.

=cut

if ?testDir('d',catDir($top,'share','reports','specs'))
{call setPrefix(concat($pre,'_shr_rep_spec'))
 pretoc '3:nagios/share/reports/specs Files'
 pretoc '4:Configuration Files'
 var @fil = ()
 loop $fil (grepDir(lastDir(),'^\.+$','npv'))
 {if grepFile($fil,'period\s+[1-9]','f')
   call push(@fil,$fil)
 }
 call sort_all_files(5,0,@fil)
 unpretoc 2
}
unpretoc 3
call validate(true)

# Restore module prefix
call setPrefix($PRE)

=head2 profiles Files

=head3 <usr> User

Collects profile files from the eServ specific user home directory.

=cut

section NCC_profiles

call setPrefix(concat($PRE,'s_profiles'))
pretoc '%SPLIT%'
pretoc '1+:profiles Files'
debug ' Inside NCC module, gathering files related to user profiles'
loop $lin (grepFile('/etc/passwd','_oper|root|oracle'))
{pretoc '2:',field(':',0,$lin),' User'
 if ?testDir('d',$hom = field(':',5,$lin))
  call sort_all_files(3,0,grepDir($hom,'^\.profile','np'))
 unpretoc
}
unpretoc 2
call validate(true)

# Restore module prefix
call setPrefix($PRE)

=head2 system_info Files

=cut

section NCC_sys

=head3 s_system_info_svm_mirror - SVM Mirror Information

Collects SVM mirror information on Oracle Solaris.

=cut

call setPrefix(concat($PRE,'s_system_info'))
pretoc '%SPLIT%'
pretoc '1+:system_info Files'
debug ' Inside NCC module, gathering system information'
var $SCSTAT =  findCommand('scstat',true)
if ${OS.solaris}
{# SVM mirror details
 if ?testFile('fx',$cmd = findCommand('metadb',true))
 {var $cmd = quote($cmd)
  report svm_mirror
  title '---+!! SVM Mirror Information'
  title $TOC

  # metadb output
  prefix
   write '---+ metadb'
  call writeCommand($cmd)
  if hasOutput(true)
   write $TOP

  # metadb -i output
  prefix
   write '---+ metadb -i'
  call writeCommand(concat($cmd,' -i'))
  if hasOutput(true)
   write $TOP

  # metastat output
  prefix
   write '---+ metastat'
  call writeCommand('metastat')
  if hasOutput(true)
   write $TOP

  # metastat -p output
  prefix
   write '---+ metastat -p'
  call writeCommand('metastat -p')
  if hasOutput(true)
   write $TOP
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][SVM Mirror Information]]'
 }

=head3 s_system_info_vxvm_mirror - Veritas Information

Collects Veritas information on Oracle Solaris.

=cut

 if ?testFile('fx',$cmd = '/usr/sbin/vxprint')
 {report vxvm_mirror
  title '---+!! Veritas Information'
  title '---## Using: ',encode($cmd)
  title $TOC

  # vxprint output
  prefix
   write '---+ vxprint'
  call writeCommand($cmd)
  if hasOutput(true)
   write $TOP

  # vxprint -ahl output
  prefix
   write '---+ vxprint -ahl'
  call writeCommand(concat($cmd,' -ahl'))
  if hasOutput(true)
   write $TOP
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Veritas Information]]'
 }

=head3 s_system_info_veritas_license - Veritas Licensing Information

Collects Veritas licensing information on Oracle Solaris.

=cut

 if ?testFile('fx',$cmd = '/opt/VRTSvlic/sbin/vxlicrep')
 {var $cmd = concat($cmd,' -g')
  report veritas_license
  prefix
  {write '---+ Veritas Licensing Information'
   write '---## Using: ',encode($cmd)
  }
  call writeCommand($cmd)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Veritas Licensing Information]]'
  }
 }

=head3 s_system_info_act_prc_sta - Active Process Statistics

Collects active process statistics information on Oracle Solaris.

=cut

 if ?testFile('fx',$cmd = '/usr/bin/prstat')
 {var $cmd = concat($cmd,' -s rss -n 1000 1 1')
  report act_prc_sta
  prefix
  {write '---+ Active Process Statistics Information'
   write '---## Using: ',encode($cmd)
  }
  call writeCommand($cmd)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Active Process Statistics]]'
  }
 }

=head3 s_system_info_suncluster_status - Sun Cluster Status

Collects Sun cluster status information on Oracle Solaris.

=cut

 if ?testFile('fx',$SCSTAT)
 {report suncluster_status
  prefix
  {write '---+ Sun Cluster Status Information'
   write '---## Using: ',encode($SCSTAT)
  }
  call writeCommand(quote($SCSTAT))
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Sun Cluster Status]]'
  }
 }

=head3 s_system_info_booting_info - EEPROM Settings

Collects EEPROM settings information on Oracle Solaris.

=cut

 if ?testFile('fx',$cmd = '/usr/sbin/eeprom')
 {report booting_info
  prefix
  {write '---+ EEPROM Settings Information'
   write '---## Using: ',encode($cmd)
  }
  call writeCommand($cmd)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][EEPROM Settings]]'
  }
 }

=head3 s_system_info_service_status - Service Status Information

Collects service status information on Oracle Solaris.

=cut

 if ?testFile('fx',$cmd = '/usr/bin/svcs')
 {var $cmd = concat($cmd,' -a -o state,stime,fmri,desc')
  report service_status
  prefix
  {write '---+ Service Management Facility (SMF) Information'
   write '---## Using: ',encode($cmd)
  }
  call writeCommand($cmd)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Service Status Information]]'
  }
 }
}

=for stopwords eSG eServ Pslist

=head3 s_system_info_esg_pslist_stats - eSG Pslist Stats

Collects eServ process resource usage statistics information.

=cut

var $dir = catDir($HOME,'SUPPORT','bin')
if ?testFile('fx',catFile($dir,'ps_list.sh'))
{var $cmd = lastTestCommand()
 report esg_pslist_stats
 title '---+!! eServ Process Resource Usage Statistics'
 title '---## Using: ',$cmd
 title $TOC

 # ps_list.sh -v output
 prefix
  write '---+ ps_list.sh -v'
 call writeCommand(concat($cmd,' -v'))
 if hasOutput(true)
  write $TOP

 var ($str) = command(concat($cmd,' -R'))
 if and(compare('valid',field('\s+',2,$str),'1.104'),\
        testFile('fx',$SCSTAT))
 {# ps_list.sh output
  prefix
   write '---+ ps_list.sh'
  call writeCommand($cmd)
  if hasOutput(true)
   write $TOP

  # ps_list.sh -r output
  prefix
   write '---+ ps_list.sh -r'
  call writeCommand(concat($cmd,' -r'))
  if hasOutput(true)
   write $TOP
 }
 else
 {var $opt = cond(testDir('d',catDir($HOME,'SLEE')),'s','')

  # ps_list.sh -i -s -u _oper output
  var $arg = concat(' -i',$opt,' -u _oper')
  prefix
   write '---+ ps_list.sh',$arg
  call writeCommand(concat($cmd,$arg))
  if hasOutput(true)
   write $TOP

  # ps_list.sh -i -s -u _oper -r output
  var $arg = concat(' -i',$opt,' -u _oper -r')
  prefix
   write '---+ ps_list.sh',$arg
  call writeCommand(concat($cmd,$arg))
  if hasOutput(true)
   write $TOP
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][eSG Pslist Stats]]'
}
unpretoc 2
call validate(true)

# Restore module prefix
call setPrefix($PRE)

=head2 usr Files

=cut

section NCC_usr

call setPrefix(concat($PRE,'s_usr'))
pretoc '%SPLIT%'
pretoc '1+:usr Files'
debug ' Inside NCC module, gathering usr files'

=head3 RMAN Scripts

Collects RMAN-related scripts from the F</usr/sbin> directory and
the F</usr/local/oracle/admin/RMAN/scripts> directory.

=cut

pretoc '2:RMAN Scripts'
call sort_all_files(3,0,\
  '/usr/sbin/nsrnmo',\
  grepDir('/usr/sbin','^nsrnmo_','np'),\
  grepDir('/usr/local/oracle/admin/RMAN/scripts','^\.+$','npv'))
unpretoc

=head3 Flash Archive Script

Collects the flash archive script from the F</usr/local/bin> directory.

=cut

pretoc '2:Flash Archive Script'
call sort_all_files(3,0,'/usr/local/bin/flash_create.sh')
unpretoc

=head2 /usr/lib/secure Files

=head3 s_usr_overview - Overview

Lists the content of the F</usr/lib/secure> directory.

=cut

var $dir = '/usr/lib/secure'
pretoc '2:',$dir,' Files'
report overview
prefix
{write '---+ Overview'
 write '---## Information Taken from ',encode($dir)
}
call statDir('an',$dir)
if isCreated(true)
{write $TOP
 toc '3:[[',getFile(),'][rda_report][Overview]]'
}

=head3 s_usr_chksum - Check Sum Information

Collects the check sum information from the F</usr/lib/secure> directory.

=cut

call get_chksum($dir,3,$dir)

=head3 s_usr_chksum - Check Sum Information

Collects the check sum information from the F</usr/lib/secure> directory.

=cut

call get_chksum($dir,3,$dir)

unpretoc 3
call validate(true)

# Restore module prefix
call setPrefix($PRE)

=head1 SEE ALSO

L<CGBU:DCncc|collect::CGBU:DCncc>,
L<CGBU:NCClib|collect::CGBU:NCClib>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
