# BIr11.ctl: Defines Common Macros for Oracle Business Intelligence 11g
# $Id: BIr11.ctl,v 1.11 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/BIr11.ctl,v 1.9 2016/11/15 18:00:17 RDA Exp $
#
# Change History
# 20191204  PCW  Prevent overwrite of variable in collect_bi_generic.
# 20180301  PCW  Collect patching log files for OBIA in collect_bi_generic.
# 20161110  SJC  Collect xdo.cfg under config files in collect_bi_instance.

=head1 NAME

BI:BIr11 - Defines Common Macros for Oracle Business Intelligence 11g

=head1 DESCRIPTION

This persistent submodule regroups macros that are common to Oracle Business
Intelligence Enterprise Edition in Oracle Fusion Middleware 11g.

The following macro is available:

=cut

# Make the module persistent and share macros
keep $KEEP_BLOCK,@SHARE_MACROS
var @SHARE_MACROS = ('collect_bi_generic','collect_bi_instance',\
                     'collect_bi_repo_list')

# Load the common macros
run RDA:library()

=head2 S<collect_bi_generic($dir)>

This macro collects Oracle Business Intelligence Enterprise Edition version,
its executable, and its configuration files.

When requested, it analyzes core dump files (for UNIX only) and collects them
if the security filter is not enabled.

=cut

macro collect_bi_generic
{var ($dir) = @arg
 import $BI_TAIL,$ORACLE_HOME,$TOC,$TOP

 debug ' Inside BI module, getting version information'
 var $nam = 'version.txt'
 var $fil = catFile($dir,$nam)
 if ?testFile('f',$fil)
 {report bi_version
  write '---+ Display of ',encode($nam),' File'
  write '---## Information Taken from ',encode($fil)
  var $flg = writeFile($fil)
  if !$flg
  {write '**',encode($nam),' not readable.**%BR%\
         May be file permission problems.%BR%\
         Permissions are:%BR%'
   call statFile('b',$fil)
   write 'User: ',id(),'%BR%'
  }
  toc '2:[[',getFile(),'][rda_report][Version Information]]'
 }

 debug ' Inside BI module, listing Oracle BI Server executables'
 report bi_server_bin
 var $exe = catDir($dir,'server','bin')
 prefix
  write '---+ List of Files in ',encode($exe)
 call statDir('an',$exe)
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Executable List]]'

 debug ' Inside BI module, gathering configuration files'
 pretoc '2:Configuration Files'
 call cat_report(catDir($dir,'web','display'),'authenticationschemas.xml')
 unpretoc

 debug ' Inside BI module, gathering log files'
 pretoc '2:Log Files'
 call sort_files(3,$BI_TAIL,\
   grepDir(catDir($ORACLE_HOME,'upgrade','logs'),'^\.+$','npv'))
 unpretoc

 debug ' Inside BI module, gathering OBIA patch application logs'
 pretoc '2:Patching Log Files'
 if ${SET.BI.BI.B_PATCH_LOGS}
 {var $wkd = ${SET.BI.BI.D_PATCH_DIR}
  call sort_files(3,0,\
    grepDir($wkd,'^biappshiphome.+patches\.log$','np'),\
    catFile($wkd,'final_patching_report.log'),\
    catFile($wkd,'odi_generic_patches.log'),\
    catFile($wkd,'oracle_common_generic_patches.log'),\
    catFile($wkd,'weblogic_patching.log'))
 }
 unpretoc

 # Treat core dump collection
 if and(${SET.BI.BI.B_CORES},\
        @dmp = (grepDir(catDir($dir,'server'),'\.dmp$','ip'),\
                grepDir(catDir($dir,'web'),'\.dmp$','ip')))
 {# Collect the core dumps when not filtered
  if !isFiltered()
  {debug ' Inside BI module, gathering core dump files'
   report core_dump_files
   prefix
   {write '---+ Core Dump Files'
    write '   * Links point to files that have been collected in their \
                original format. Opening them directly in your browser can \
                present risks. To prevent them, access the file outside the \
                browser or use the link to save them and use an adequate \
                viewer.'
    write '|*File Name*| *Size*|*Last Modified Date*|'
   }
   loop $fil (@dmp)
   {var $nam = basename($fil)
    var $siz = getSize($fil)
    var $lnk = encode($fil)
    if $siz
    {var $rpt = $[OUT]->add_report('b',concat('c_',$nam),0,'.dmp')
     if $rpt->write_data($fil)
      var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
     end $rpt
    }
    write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
   }
   if isCreated(true)
   {write $TOP
    toc '2:[[',getFile(),'][rda_report][Core Dump Files]]'
   }
  }

  # Analyze core dump files for UNIX
  if isUnix()
  {# Include the core analyzer
   run OS:COREinfo()

   # When a debugger is found, analyze the core dumps
   if can_analyze_core()
   {var $dbg = last
    debug ' Inside BI module, analyzing core dump files'
    report core_analysis
    write '---+!! Core Dump Stack Trace Extraction'
    write '---## Using: ',$dbg
    write $TOC
    call analyze_core(@dmp)
    toc '2:[[',getFile(),'][rda_report][Core Dump Analysis]]'
   }
  }
 }
}

=head2 S<collect_bi_instance($pre,$top,\%cmp,\@rep)>

This macro collects Oracle Business Intelligence Enterprise Edition instance
information which includes configuration files, log files, DMS dump, and its
repositories.

=cut

macro collect_bi_instance
{var ($pre,$top,\%cmp,\@rep) = @arg
 import $BI_AGE,$BI_TAIL,$TOP

 # Collect the instance files
 debug ' - Getting Oracle Business Intelligence configuration and log files'
 loop $key (keys(%cmp))
 {var ($typ,$cmp) = split('\|',$key,2)
  next !match($typ,'^OracleBI(ClusterController|JavaHost|PresentationServices|\
                              Scheduler|Server)Component$',true)
  debug '   - ',$cmp,' component'
  call setPrefix(concat($pre,'_c_',$cmp))
  pretoc "2:'",$cmp,"' ",\
    replace(replace($typ,'^OracleBI'),'Component$'),' Component'

  # Collect the configuration files
  var @cfg = ()
  if match($typ,'^OracleBIServerComponent$',true)
   call push(@cfg,catFile($top,'config','OracleBIApplication',\
                          'coreapplication','ClusterConfig.xml'),\
                  catFile($top,'bifoundation','OracleBIApplication',\
                          'coreapplication','setup','bi-init.sh'),\
                  catFile($top,'bifoundation','OracleBIApplication',\
                          'coreapplication','setup','odbc.ini'))
  pretoc '3:Configuration Files'
  call sort_files(4,$BI_TAIL,@cfg,\
   grepDir(catDir($top,'config',$typ,$cmp),'\.(INI|xml)$','dir'),\
   grepDir(catDir($top,'config',$typ,$cmp),'^xdo.cfg$','p'))
  unpretoc

  # Collect the log files
  pretoc '3:Log Files'
  if match($typ,'^OracleBIJavaHostComponent$',true)
   var @tbl = grepDir(catDir($top,'diagnostics','logs',$typ,$cmp),\
                      '^(jhost0\.log\.|jh.*\.log$)',concat('ipm',$BI_AGE))
  elsif match($typ,'^OracleBIPresentationServicesComponent$',true)
  {var @tbl = grepDir(catDir($top,'diagnostics','logs',$typ,$cmp),\
                      '^sawlog.*\.log$',concat('ipm',$BI_AGE))
   call push(@tbl,catFile($top,'diagnostics','logs',$typ,\
                          'coreapplication_obips1','webcatupgrade.log'),\
                  catFile($top,'diagnostics','logs','OracleBIODBCComponent',\
                          'coreapplication_obips1','ODBC.log'))
  }
  else
   var @tbl = grepDir(catDir($top,'diagnostics','logs',$typ,$cmp),'log$','dir')
  if match($typ,'^OracleBIServerComponent$',true)
   call push(@tbl,catFile($top,'diagnostics','logs',$typ,\
                          'coreapplication_obis1','NQSUDMLExec.log'),\
                  catFile($top,'diagnostics','logs',$typ,\
                          'coreapplication_obis1','obieerpdmigrateutil.log'))
  call sort_files(4,$BI_TAIL,@tbl)
  unpretoc

  # Collect the DMS dump
  if $cmp{$key}
  {report dms_metrics
   var $cmd = concat(findCommand('opmnctl',false,catDir($top,'bin')),\
                     ' @instance:',quote($dsc),\
                     ' metric op=query PROCESS_UID=',quote($cmp{$key}),\
                     ' dmsarg="format=raw&nountype=opmn_process" 2>&1')
   prefix
   {write '---+ Display of DMS Dump Metrics'
    write '---## Using: ',encode($cmd)
   }
   call writeCommand($cmd)
   if isCreated(true)
   {write $TOP
    toc '3:[[',getFile(),'][rda_report][DMS Dump]]'
   }
  }

  # Collect the repositories
  next !match($typ,'^OracleBIServerComponent$',true)
  var @fil = ()
  loop $ref (@rep)
  {var ($dir,$nam,$rep) = @{$ref}
   if and(sameDir($dir,$top),compare('eq',$nam,$cmp))
    call push(@fil,catFile($top,'bifoundation',$typ,$cmp,'repository',$rep))
  }
  if @fil
   run BI:BIinfo(3,@fil)
  unpretoc
 }
 call setPrefix($pre)
}

=head2 S<collect_bi_repo_list(\@rep)>

This macro collects Oracle Business Intelligence Enterprise Edition repository
names chosen by the user.

=cut

macro collect_bi_repo_list
{var (\@rep) = @arg

 loop $rep (@{SET.BI.BI.T_REPOSITORY})
 {if match($rep,'^InsDir:(.*?),Comp:(.*?),Repo:(.*)$')
   call push(@rep,[last])
 }
}

=head1 SEE ALSO

L<BI:BIinfo|collect::BI:BIinfo>,
L<OS:COREinfo|collect::OS:COREinfo>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
