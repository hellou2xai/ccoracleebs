# BRMr7.ctl: Collects Oracle Communication BRM 7.x Information
# $Id: BRMr7.ctl,v 1.19 2015/08/21 16:15:16 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/BRMr7.ctl,v 1.19 2015/08/21 16:15:16 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

CGBU:BRMr7 - Collect Oracle Communication Billing and Revenue Management
7.0, 7.2, 7.3, 7.4, or 7.5 Information.

=head1 DESCRIPTION

This module collects information about Oracle Communications Billing and
Revenue Management or Pipeline Manager-based systems.

=cut

# Initialization
var $BRM_AGE     = ${R_AGE/T:7}
var $BRM_TAIL    = ${N_TAIL:5000}
var $BRM_VERSION = $arg[0]

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

var %DUP

echo tput('bold'),'Processing Oracle Communication BRM ',$BRM_VERSION,\
     ' module ...',tput('off')

# --- Data collection macros --------------------------------------------------

# Collect information for BRM Base
macro run_portal
{var ($ctl) = @arg
 import $TOP

 # Check the presence of required environment variables
 var $hom = testDir('d',${ENV.PIN_HOME})
 var $log = testDir('d',${ENV.PIN_LOG:${ENV.PIN_LOG_DIR}})
 if !and($hom,$log)
  return 'PIN_HOME and PIN_LOG/PIN_LOG_DIR must be set'

 # Get the components and the applications
 debug ' Inside BRMr7 module, discovering components'
 if analyze_pin_ctl($ctl,$hom,$log)
 {call find_elements($ctl->{'app'},$hom,$log,'sys',\
                     {config=>1,data=>1,dd=>1,msgs=>1})
  call find_elements($ctl->{'sys'},$hom,$log,'apps',{})
 }

 # Process all components
 debug ' Inside BRMr7 module, processing all components (can take time)'
 pretoc '2:Components'
 prefix
 {write '---++ Components'
  write '<verbatim>'
 }
 loop $nam (keys($ctl->{'sys'}))
 {debug '    ',$nam,' ...'
  pretoc "3:Component '",$nam,"'"
  write "Component '",$nam,"'"
  var $rec = $ctl->{'sys',$nam}
  var $typ = $rec->{'typ'}
  if match($typ,'^(cm$|dm_oracle)')
   call send_sigusr1($rec)
  elsif compare('eq',$typ,'dm_timos')
  {if process_timos($rec)
   {write last
    echo last
   }
   next
  }
  call process_element('sys',$rec)
  if compare('eq',$typ,'dm_ifw_sync')
   call copy_file('f',catDir($hom,'sys','dm_ifw_sync'),'ifw_sync_queuenames')
  unpretoc
 }
 if hasOutput(true)
 {write '</verbatim>'
  write $TOP
 }
 unpretoc

 # Process all applications
 debug ' Inside BRMr7 module, processing all applications (can take time)'
 pretoc '2:Applications'
 prefix
 {write '---++ Applications'
  write '<verbatim>'
 }
 loop $nam (keys($ctl->{'app'}))
 {debug '    ',$nam,' ...'
  pretoc "3:Application '",$nam,"'"
  write "Application '",$nam,"'"
  call process_element('apps',$ctl->{'app',$nam})
  unpretoc
 }
 if hasOutput(true)
 {write '</verbatim>'
  write $TOP
 }
 unpretoc

 # Indicate a successful completion
 return ''
}

# Collect the pipeline information
macro run_program
{var ($reg,$int) = @arg
 var $nam = basename($reg,'.reg')
 var $pgm = "ifw"
 import $TOP
 keep $TOP

 debug ' Inside BRMr7 module, gathering pipeline information for ',$nam
 write '---+ Registry ',encode($nam),' from ',encode($int)
 write '<verbatim>'

 # Check the presence of required environment variables
 var $hom = $int
 if !$hom
  return 'IFW_HOME or INT_HOME is not set'
 pretoc "2:Registry '",encode($nam),"'"," from '",encode($int),"'"

 # Read the registry
 debug " Inside BRMr7 module, reading registry '",$reg,"'"
 write "Reading registry '",encode($reg),"'"
 var $inf = extern('PrRegRd','read_registry',$reg)
 if !ref($inf)
 {write 'Cannot read registry:'
  return getDataError()
 }
 write 'Registry read done'

 # Copy registries
 pretoc '3:Registry'
 debug ' Inside BRMr7 module, copying registries'
 write
 write 'Copying registries ...'
 var $pre = concat('reg_',$nam)
 call copy_file($pre,$hom,$reg)
 loop $pth (info2file($hom,$inf->{'Info'}))
  call copy_file($pre,$hom,$pth)
 write 'Registry copy done'
 unpretoc

 # Copy descriptions
 pretoc '3:Descriptions'
 debug ' Inside BRMr7 module, copying descriptions'
 write
 write 'Copying descriptions ...'
 var $pre = concat('dsc_',$nam)
 call copy_file($pre,$hom,$inf->{'Alias'})
 loop $pth (keys($inf->{'FormatDescs'}))
  call copy_file($pre,$hom,$pth)
 write 'Description files copy done'
 unpretoc

 # Collect log files
 pretoc '3:Log Files'
 debug ' Inside BRMr7 module, collecting log files'
 write
 write 'Collecting log file newest entries ...'
 write '(only 10 newest Stream-Logs/Format)'
 var $pre = concat('log_',$nam)
 loop $pth (find_logs($hom,$inf))
  call tail_file($pre,$hom,$pth)
 write 'Log File copy done ...'
 unpretoc

 # Collect other log files
 pretoc '3:Other Log Files'
 debug ' Inside BRMr7 module, collecting other log files'
 write
 write 'Collecting other log files ...'
 var $pre = concat('log_',$nam)
 loop $pth (grepDir(catDir($hom,'log'),'\.log$','np'))
  call tail_file($pre,$hom,$pth,true)
 write 'Log File copy done ...'
 unpretoc

 # Copy trace files
 pretoc '3:Trace Files'
 debug ' Inside BRMr7 module, collecting trace files'
 write
 write 'Copying trace files ...'
 var $pre = concat('trc_',$nam)
 loop $pth (grepDir($hom,'trace','np'))
  call copy_file($pre,$hom,$pth)
 write 'Trace file copy done'
 unpretoc

 # Get Pipeline Manager information
 if ?testFile('x',catFile($hom,'bin',$pgm))
 {# Include lib directory in the shared library path
  var $bkp = undef
  if ${CUR.W_SHLIB}
  {var $key = last
   if ?testDir('d',catDir($hom,'lib'))
    var $bkp = setContext({\
      $key => join(${RDA.T_SEPARATOR},last,@{SYS.${VAR.key}})})
  }

  # Gather Pipeline Manager information
  debug ' Inside BRMr7 module, collecting pipeline information'
  write
  write 'Collecting pipeline information ...'

  var $cmd = concat(lastTestCommand(),' -v')
  suspend log
  report concat('ifw_',$nam,'_',$int)
  write '---+ Pipeline Information'
  write '---++ Using: ',encode($cmd)
  var $rpt = getFile()
  var $tmp = getTemp('ifw')
  call command(concat($cmd,' 2>',$tmp))
  call writeFile($tmp)
  call unlinkTemp('ifw')
  suspend rpt
  resume log
  write "  '",$cmd,"' -> ",cond(expr('>>',status(),8),'failed',$rpt)

  var $cmd = concat($cmd,' -r ',quote($reg))
  suspend log
  resume rpt
  write '---++ Using: ',encode($cmd)
  var $tmp = getTemp('ifw')
  call command(concat($cmd,' 2>',$tmp))
  call writeFile($tmp)
  call unlinkTemp('ifw')
  toc '3:[[',$rpt,'][rda_report][Pipeline Information]]'
  resume log
  write "  '",$cmd,"' -> ",cond(expr('>>',status(),8),'failed',$rpt)

  # Restore the initial environment
  if ?$bkp
   call restoreContext($bkp)
 }

 write 'Collect done'
 write '</verbatim>'
 write $TOP
 unpretoc
 return ''
}

# --- Internal collection macros ----------------------------------------------

# Analyze the pin_ctl.conf file
macro analyze_pin_ctl
{var ($ctl,$hom,$log) = @arg
 var ($flg,%hom,%log,%reg) = (true)

 # Collect the pin_ctl.conf file
 var $cfg = ${F_PINCTL:catFile($hom,'bin','pin_ctl.conf')}
 suspend log
 report pinctl
 prefix
 {write '---+ Display of pin_ctl.conf File'
  write '---## Information Taken from ',encode($cfg)
  call statFile('b',$cfg)
 }
 call writeFile($cfg)
 if isCreated(true)
 {toc '2:Configuration'
  toc '3:[[',getFile(),'][rda_report][pin_ctl.conf]]'
 }
 resume log

 # Parse the pin_ctl.conf file
 loop $lin (grepFile($cfg,\
                     '(^\d+\s+\w|^settings\s|\senv_variable:\w+REGISTRY\s)'))
 {if match($lin,'^\d+\s+(\w+)(=(\w+))?(:.*)?')
  {var ($flg,$grp,$nam,undef,$typ,$str) = (false,'sys',last)
   var $pip = compare('eq',nvl($typ,$nam),'dm_timos')
   loop $arg (split(':',$str))
   {if compare('eq',$arg,'app')
     var $grp = 'app'
    elsif compare('eq',$arg,'pipeline')
     var $pip = true
   }
   var $ctl->{$grp,$nam} = {nam=>$nam,\
                            hom=>nvl($hom{$nam},$hom),\
                            log=>nvl($log{$nam},$log),\
                            reg=>cond($pip,$reg{$nam}),\
                            typ=>nvl($typ,$nam)}
  }
  elsif match($lin,'^settings\s+(.*)')
  {var ($nam,@arg) = split('\s+',last)
   loop $arg (@arg)
   {if match($arg,'^pin_home_dir:(.*)')
     var $hom{$nam} = catDir(replaceEnv(last))
    if match($arg,'^pin_log_dir:(.*)')
     var $log{$nam} = catDir(replaceEnv(last))
   }
  }
  elsif match($lin,'\senv_variable:\w+REGISTRY\s')
  {var ($nam,@arg) = split('\s+',$lin)
   loop $arg (@arg)
   {if match($arg,'^env_val:(.*)')
     var $reg{$nam} = catFile(replaceEnv(last))
   }
  }
 }

 # Indicate when a directory scan must be done
 return $flg
}

# Collect the core dumps
macro collect_core
{var ($dir) = @arg
 import $TOC
 keep $TOC

 if grepDir($dir,'(^core\.\d+$|core$)','pt')
 {var @dmp = last

  write '  ',scalar(@dmp),' core dump(s) found'
  suspend log
  output F,core

  # Include the core analyzer on first use
  if !isImplemented('can_analyze_core')
   run OS:COREinfo()

  # When a debugger is found, analyze the core dumps
  if can_analyze_core()
  {var $dbg = last
   write '---+!! Core Dump Stack Trace Extraction'
   write '---## Using: ',encode($dbg)
   title $TOC
   call analyze_core(@dmp)
  }
  else
  {prefix
   {write '---+!! Core Dumps'
    write '---## From ',$dir
    write '   * Links point to binary files. Use the link to save them.'
    write '|*Core File*| *Size*|*Last Modified Date*|'
   }
   loop $dmp (@dmp)
   {var $lnk = encode($bas = basename($dmp))
    var $siz = getSize($dmp)
    if $siz
    {output d,concat('c_',$bas)
     if ${CUR.O_LAST}->write_data($dmp)
      var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                        '][_blank][',$lnk,']]')
     end ${CUR.O_LAST}
    }
    write '|',$lnk,' | ',$siz,'|',getLastModify($dmp,'<UTC>'),' |'
   }
  }
  if isCreated(true)
   toc '4:[[',getFile(),'][rda_report][Core Dumps]]'
  resume log
 }
}

# Collect log and pinlog files
macro collect_logs
{var ($log,$sub,$nam,$dir,$cfg,$pat) = @arg

 # Initialisation
 var $cnt = 0
 var $pat = concat($pat,'\s*(.*)$')

 # Read start script
 if createBuffer('PIN','R',catFile($dir,$cfg))
 {while getLine('PIN')
  {var $lin = chomp(last)
   next match($lin,'^#')
   if match($lin,$pat)
    incr $cnt,tail_file('t',$dir,replaceEnv(trim(last)),true)
    #incr $cnt,tail_file('t',$dir,replaceEnv(trim(substr(last,1))),true)
  }
  call deleteBuffer('PIN')
 }
 else
  write 'Cannot open ',encode($cfg)

 # Copy log file if exists
 if compare('eq',$nam,'batch_controller')
  var $fil = 'BatchController.log'
 else
  var $fil = concat($nam,'.log')
 if ?nvl(testFile('e',catFile($log,$nam,$fil)),\
         testFile('e',catFile($dir,$fil)))
  incr $cnt,tail_file('t',$dir,last,true)

 # Copy pid file if exists
 if compare('eq',$nam,'batch_controller')
  var $fil = 'BatchController.pid'
 else
  var $fil = concat($nam,'.pid')
 if ?nvl(testFile('e',catFile($log,$nam,$fil)),\
         testFile('e',catFile($dir,$fil)))
  incr $cnt,copy_file('f',$dir,last)

 # Copy pinlog file if exists
 var $fil = concat($nam,'.pinlog')
 if ?nvl(testFile('e',catFile($log,$nam,$fil)),\
         testFile('e',catFile($dir,$fil)))
  incr $cnt,tail_file('t',$dir,last,true)

 # Return the number of files found
 return $cnt
}

# Find all the components for collecting logs
macro find_elements
{var ($ctl,$hom,$log,$sub,$skp) = @arg

 var $cnt = 0
 var $dir = catDir($hom,$sub)
 loop $nam (grepDir($dir,'^\.\.?$','nv'))
 {next !?testDir('d',catDir($dir,$nam))
  next exists($skp->{$nam})
  var $ctl->{$nam} = {hom=>$hom,log=>$log,nam=>$nam,typ=>$nam}
  incr $cnt
 }
 if !$cnt
  debug 'There are no elements available in ',$dir
 return $cnt
}

# Find all log file names and verify their existence
macro find_logs
{var ($dir,$inf) = @arg
 var %tbl = ()

 # Search for logs
 if $inf
 {# Examine process log
  loop $pth (info2file($dir,$inf->{'Process'}))
  {if ?testFile('fr',$pth)
    var $tbl{$pth} = 1
  }

  # Examine format logs
  if exists($inf->{'FormatLogs'})
  {loop $itm (@{$inf->{'FormatLogs'}})
   {loop $pth (info2file($dir,$itm))
    {if ?testFile('fr',$pth)
      var $tbl{$pth} = 1
    }
   }
  }

  # Examine stream logs
  if exists($inf->{'StreamLogs'})
  {loop $itm (@{$inf->{'StreamLogs'}})
   {var $cnt = 10
    var $pth = $itm->{'Path'}
    if !isAbsolute($pth)
     var $pth = catFile($dir,$pth)
    loop $pth (grepDir($pth,concat('^',verbatim($itm->{'Prefix'}),'.*',\
                                       verbatim($itm->{'Suffix'}),'$'),'pt'))
    {var $tbl{$pth} = 1
     decr $cnt
     break !$cnt
    }
   }
  }
 }

 # Report all logs found
 loop $nam (keys(%tbl))
  write '  ',$nam

 return keys(%tbl)
}

# Derive the file path from the data structure
macro info2file
{var ($dir,$inf) = @arg
 import $BRM_AGE
 keep $BRM_AGE

 if !?$inf
  return ()
 if !isAbsolute($pth = $inf->{'Path'})
  var $pth = catFile($dir,$pth)
 if ?$inf->{'Name'}
  return (catFile($pth,concat($inf->{'Prefix'},last,$inf->{'Suffix'})))
 return grepDir($pth,\
   concat('^',verbatim($inf->{'Prefix'}),'.*',verbatim($inf->{'Suffix'}),'$'),\
   concat('ptm',$BRM_AGE))
}

# Collect logs for each component
macro process_element
{var ($sub,$rec) = @arg

 # Initialisation
 var $hom = $rec->{'hom'}
 var $log = $rec->{'log'}
 var $nam = $rec->{'nam'}
 var $dir = catDir($hom,$sub,$nam)

 # Copy pinlog and log files when pin.conf exists
 var $fil = 'pin.conf'
 if and(testFile('e',catFile($dir,$fil)),\
        collect_logs($log,$sub,$nam,$dir,$fil,'logfile'))
  call copy_file('f',$dir,$fil)

 # Check for Infranet.properties only for applications
 var $fil = 'Infranet.properties'
 if and(testFile('e',catFile($dir,$fil)),\
        collect_logs($log,$sub,$nam,$dir,$fil,'infranet.log.file'))
  call copy_file('f',$dir,$fil)

 # Copy default.pinlog when exists
 var $fil = 'default.pinlog'
 if ?testFile('e',catFile($dir,$fil))
 {call tail_file('t',$dir,$fil)
  if compare('eq',$nam,'test')
   call copy_file('f',$dir,'pin.conf')
 }

 # Copy core dumps when exists
 call collect_core($dir)
}

# Process timos component
macro process_timos
{var ($rec) = @arg

 # Copy the registry file
 var $dir = catDir($rec->{'hom'},'sys',$rec->{'nam'})
 var $reg = nvl($rec->{'reg'},catFile($dir,'timos.reg'))
 call copy_file('timos_',$dir,$reg)

 # Read the registry
 write "  Reading registry '",$reg,"'"
 var $inf = extern('PrRegRd','read_timos',$reg)
 if !ref($inf)
 {write 'Cannot read registry:'
  return getDataError()
 }
 write '  Registry read done'

 # Copy registry files
 call copy_file('timos_',$dir,$inf->{'PinLog'})
 loop $pth (info2file($dir,$inf->{'LogServer'}))
  call copy_file('timos_',$dir,$pth)
 call copy_file('timos_',$dir,'pin.conf')
 return ''
}

# Send SIGUSR1 signal to dm_oracle and cm processes
macro send_sigusr1
{var ($rec) = @arg

 # Get process id from PID_FILE
 var $nam = $rec->{'nam'}
 var $fil = catFile($rec->{'log'},$nam,concat($nam,'.pid'))
 var ($pid) = grepFile($fil,'(\d+)','f1')
 if !$pid
 {write "Cannot open ",$fil
  return 1
 }

 # Check the process existence before sending SIGUSR1
 if !kill(0,$pid)
 {write '  ',$nam,' process (',$pid,') is not in running state'
  return 1
 }
 if !kill('USR1',$pid)
 {write '  Successfully sent the signal SIGUSR1 to ',$pid
  return 1
 }
 write '  Failed to send signal SIGUSR1 to ',$pid
 return 0
}

# --- File copy macros --------------------------------------------------------

# Copy a core file
macro copy_core
{var ($pre,$dir,$fil) = @arg

 if length($fil)
 {if !isAbsolute($fil)
   var $fil = catFile($dir,$fil)
  if ?testFile('e',$fil)
  {suspend log
   data concat($pre,$fil)
   var $nam = basename($fil)
   var $ret = writeData($fil)
   var $rpt = getFile()
   if isCreated(true)
    toc '4:[[',$rpt,'][rda_report][',$nam,']]'
   resume log
   write '  ',$fil,' -> ',cond($ret,$rpt,'failed')
  }
 }
}

# Copy a file
macro copy_file
{var ($pre,$dir,$fil) = @arg

 var $inc = 0
 if ??$fil
 {if !isAbsolute($fil)
   var $fil = catFile($dir,$fil)
  if ?testFile('e',$fil)
  {suspend log
   report concat($pre,$fil)
   prefix
   {write '---+ Display of ',encode($nam),' File'
    write '---## Information Taken from ',encode($fil)
    call statFile('b',$fil)
   }
   var $nam = basename($fil)
   var $ret = writeFile($fil)
   var $rpt = getFile()
   if isCreated(true)
   {var $inc = 1
    toc '4:[[',$rpt,'][rda_report][',$nam,']]'
   }
   resume log
   write '  ',$fil,' -> ',cond($ret,$rpt,'failed')
  }
 }
 return $inc
}

# Tail a file
macro tail_file
{var ($pre,$dir,$fil,$flg) = @arg
 import $BRM_TAIL,%DUP
 keep $BRM_TAIL,%DUP

 if !??$fil
  return 0

 if !isAbsolute($fil)
  var $fil = catFile($dir,$fil)
 if and($flg,exists($DUP{$fil}))
  return 0

 var $inc = 0
 if ?testFile('e',$fil)
 {suspend log
  report concat($pre,$fil)
  prefix
  {if $BRM_TAIL
    write '---+ Last ',$BRM_TAIL,' Lines of ',encode($nam),' File'
   else
    write '---+ Display of ',encode($nam),' File'
   write '---## Information Taken from ',encode($fil)
   call statFile('b',$fil)
  }
  var $nam = basename($fil)
  var $ret = cond($BRM_TAIL,writeTail($fil,$BRM_TAIL),\
                            writeFile($fil))
  var $rpt = getFile()
  if isCreated(true)
  {var $inc = 1
   toc '4:[[',$rpt,'][rda_report][',$nam,']]'
  }
  resume log
  write '  ',$fil,' -> ',cond($ret,$rpt,'failed')
 }
 return $DUP{$fil} = $inc
}

=head1 BRM BASE

The following reports can be generated and are regrouped under C<BRM Base>:

=head2 pin_log - Collection Log

Provides the collection details.

=for stopwords pinlog

=head2 Pin and log files

Collects all log and pinlog files of all components and all applications.

=cut

var $ctl = {app=>{},sys=>{}}
if ${B_PORTAL}
{debug ' Inside BRMr7 module, gathering BRM Base information'
 toc '1:BRM Base (',$BRM_VERSION,')'
 report pin_log
 write '---+!! BRM Base Information'
 write $TOC
 toc '2:[[',getFile(),'][rda_report][Collection Log]]'
 if run_portal($ctl)
 {write last
  echo last
 }
 pretoc '2:Extra Files'
 prefix
 {write '---++ Extra Files'
  write '<verbatim>'
 }
 if ?testDir('d',${ENV.HOME})
  call copy_file('x',last,'vpd.properties')
 if ?testDir('d',${ENV.PIN_HOME})
 {var ($dir,$opt) = (last,'pt')
  call copy_file('x',catDir($dir,'bin'),'pinrev.dat')
  loop $fil (grepDir(catDir($dir,'setup'),'\.(log|values)$',$opt),\
             grepDir(catDir($dir,'setup','scripts'),'\.log$',$opt))
   call copy_file('x',$dir,$fil)
 }
 if ?testDir('d',${ENV.PIN_LOG:${ENV.PIN_LOG_DIR}})
  call copy_file('x',last,'portal_patchlog')
 if ?testDir('d',${ENV.PIN_TMP:${ENV.PIN_TMP_DIR:${ENV.PIN_TEMP_DIR}}})
 {loop $fil (grepDir($dir = last,'\.log$','pt'))
   call copy_file('x',$dir,$fil)
 }
 if hasOutput(true)
 {write '</verbatim>'
  write $TOP
 }
 unpretoc
}

=head1 PIPELINE BASED SYSTEM

The following reports can be generated and are regrouped under C<Pipeline
Manager>:

=head2 ifw_log - Collection Log

Provides the collection details.

=head2 Registry, description, log and trace files.

Reads the specified registry files and collects information such as
description, diagnostic, log, and trace files for each of the registry
files. It captures the pipeline information also.

=cut

var (@reg,%reg,%dir) = ()
if ${B_EXTRACT}
{loop $itm (values($ctl->{'sys'}),values($ctl->{'app'}))
 {next compare('eq',$itm->{'typ'},'dm_timos')
  if ?$itm->{'reg'}
   var $reg{last} = 1
 }
 var @reg = keys(%reg)
}
elsif ?@{F_REGISTRY}
 var @reg = last

if @reg
{debug ' Inside BRMr7 module, gathering Pipeline Manager information'
 if isTocCreated(true)
  toc '%SPLIT%'

 toc '1:Pipeline Manager (',$BRM_VERSION,')'
 report ifw_log
 write '---+!! Pipeline Manager Information'
 write $TOC
 toc '2:[[',getFile(),'][rda_report][Collection Log]]'
 if ${B_ONE_HOME}
 {var $dir = nvl(testDir('d',${D_INT_HOME}),\
                 testDir('d',${ENV.IFW_HOME}),\
                 testDir('d',${ENV.INT_HOME}))
  var $dir{$dir} = 1
  loop $reg (@reg)
  {if run_program($reg,$dir)
   {write last
    echo last
    write '</verbatim>'
    write $TOP
   }
  }
 }
 elsif ?@{W_REG_SETS}
 {loop $set (last)
  {var $dir = ${D_INT_${VAR.set}}
   var $dir{$dir} = 1
   if run_program(${F_REG_${VAR.set}},$dir)
   {write last
    echo last
    write '</verbatim>'
    write $TOP
   }
  }
 }

 debug ' Inside BRMr7 module, gathering ifw_nomalloc process mappings'
 if ?testFile('fx',${AS.EXE:'/usr/bin/pmap'})
  var $pgm = concat(last,' -x ')
 elsif ?testFile('fx',${AS.EXE:'/usr/bin/procmap'})
  var $pgm = concat(last,' ')
 else
  var $pgm = undef
 if ?$pgm
 {output c,ifw_nomalloc
  var $rpt = ${CUR.O_LAST}
  var $lnk = $rpt->get_report
  prefix
  {write '---+ ifw_nomalloc Process Mappings'
   write '<verbatim>'
  }
  prefix $rpt
   write {$rpt} '---+!! ifw_nomalloc Process Mappings'
  var $cmd = concat('ps -u ',quote(${RDA.T_USER}))
  loop $lin (grepCommand($cmd,'\bifw_nomalloc\b'))
  {var $cmd = concat($pgm,quote(field('\s+',0,$lin)))
   write {$rpt} '---## Using: ',encode($cmd)
   call writeCommand($rpt,$cmd)
   write "  '",$cmd,"' -> ",$lnk
  }
  if $rpt->is_created(true)
   toc '2:[[',$lnk,'][rda_report][ifw_nomalloc Process Mappings]]'
  call $[OUT]->end_report($rpt)
  if hasOutput(true)
  {write '</verbatim>'
   write $TOP
  }
 }

 debug ' Inside BRMr7 module, gathering diagnostic files'
 output c,diag_files
 var $rpt = ${CUR.O_LAST}
 pretoc '2:Diagnostic Files'
 prefix
 {write '---+ Diagnostic Files'
  write '<verbatim>'
 }
 var $opt = concat('ptm',$BRM_AGE)
 loop $dir (keys(%dir))
 {loop $fil (grepDir(catDir($dir,'log'),'(^diagnostic\.dat\.|\.log$)',$opt))
   call copy_file('d',$dir,$fil)
 }
 if hasOutput(true)
 {write '</verbatim>'
  write $TOP
 }
 unpretoc

 debug ' Inside BRMr7 module, gathering extra files'
 pretoc '2:Extra Files'
 prefix
 {write '---+ Extra Files'
  write '<verbatim>'
 }
 if ?testDir('d',${ENV.HOME})
  call copy_file('x',last,'vpd.properties')
 loop $dir (keys(%dir))
  call copy_file('x',catDir($dir,'bin'),'piperev.dat')
 if hasOutput(true)
 {write '</verbatim>'
  write $TOP
 }
 unpretoc
}

=head1 SEE ALSO

L<CGBU:DCbrm|collect::CGBU:DCbrm>,
L<OS:COREinfo|collect::OS:COREinfo>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
