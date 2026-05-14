# TLsiebel.ctl: Collects Siebel Crash Information
# $Id: TLsiebel.ctl,v 1.22 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/TLsiebel.ctl,v 1.21 2015/08/21 15:33:37 RDA Exp $
#
# Change History
# 20230314  DXM  Remove jar and zip extensions from add_report specifications.
# 20150821  MSC  Improve time consistency.

=head1 NAME

APPS:TLsiebel - Collects Siebel Crash Information

=head1 DESCRIPTION

This tool collects information about a specific Siebel crash. It may include
the Enterprise log file, a core dump analysis, crash files, component log
files, and Flight Data Recorder files.

See the following My Oracle Support documents for more details on the
collection approach:

=over 2

=item o

477520.1 I<How To Troubleshoot Siebel Server Component Crashes on UNIX>

=item o

477511.1 I<How to troubleshoot Siebel component crashes on Microsoft Windows>

=back

=head1 USAGE

This tool can be used in two ways:

=over 3

=item a)

Runs interactively. It requests the user to enter the required information.

 <rda> -vT siebel

 <sdci> -v run siebel

=item b)

Runs from the command line. The input can be given in the command line using
the following syntax:

 <rda> -vT siebel:<home>|<enterprise>|<server>|<advanced>|<pid>|<core>

 <sdci> -v run siebel <home> <enterprise> <server> <advanced> <pid>
        <core>

Where:

=over 16

=item B<  E<lt>homeE<gt>>

Is the full path of Siebel Server home

=item B<  E<lt>enterpriseE<gt>>

Is the Application Enterprise name

=item B<  E<lt>serverE<gt>>

Is the Application Server name

=item B<  E<lt>advancedE<gt>>

Is the advanced mode (accepts Boolean value) for detailed report collection

=item B<  E<lt>pidE<gt>>

Is the process identifier of the crashed application

=item B<  E<lt>coreE<gt>>

Is the core file on AIX, HP-UX, Linux, Solaris and the dump file on Windows

=back

=back

The reports can be viewed in the C<External Data Collections> submenu of the
final RDA output package also. If it is not disabled, you can refresh that
section by the following command:

 <rda> -vCRP LOAD

 <sdci> -v collect -RP LOAD

=cut

section tool

echo tput('bold'),'Collecting Siebel crash data ...',tput('off')

# Initialization
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

# Get the arguments
if match($arg[0],'\|')
 call unshift(@arg,split('\|',shift(@arg)))
if @arg
{var ($dir,$ent,$srv,$ALL,$pid,$dmp) = @arg
 if ?testDir('d',catDir($dir,'siebsrvr'))
 {var $HOM = $dir
  if ?testDir('d',catDir($HOM,'siebsrvr','enterprises',$ent,$srv))
   var ($ENT,$SRV) = ($ent,$srv)
  elsif isUnix()
   echo "The directory '",lastDir(),"' does not exist.\n\
         Information will not be collected fully.\n"
  else
   var ($ENT,$SRV) = ($ent,$srv)
 }
 else
  echo "The directory '",$dir,"' does not exist or does not have a \
        'siebsrvr' subdirectory.\n\
        Information will not be collected fully.\n"

 if match($pid,'^(\d+)$')
  var $PID = first
 if ?testFile('fr',$dmp)
 {var $DMP = last
  if and(${OS.hpux},not(defined($PID)))
   var ($PID) = match($DMP,'\.(\d+)$')
 }
 elsif match(${RDA.T_OS},'(aix|hpux|linux|solaris)')
  echo 'Missing core dump'
 if !?$PID
  echo 'Missing process identifier'
}
else
{call requestInput('TLsiebel')
 var $ENT = ${RUN.REQUEST.T_ENTERPRISE}
 var $DMP = ${RUN.REQUEST.F_CORE}
 var $HOM = ${RUN.REQUEST.D_HOME}
 var $PID = ${RUN.REQUEST.N_PID}
 var $SRV = ${RUN.REQUEST.T_SERVER}
 var $ALL = ${RUN.REQUEST.B_ADVANCED:0}
}

# Purge old reports
call setAbbr('APPS_SIEBEL_')
call purge('C','.',15,0)

# Set the abbreviation
var $cnt = 0
loop $fil (grepDir(${OUT.C},concat(${CUR.W_PREFIX},'c\d+_crash\.txt')))
 var $cnt = max($cnt,match($fil,'APPS_SIEBEL_c(\d+)_crash\.txt$'))
call setPrefix(sprintf('c%02d',incr($cnt)))

# Set the required environment
var $bkp = setContext({PERL5LIB => ${ENV.PERL5LIB},\
                       PERL5OPT => ${ENV.PERL5OPT}})

var $ARC = cond(isUnix(),\
                catDir($HOM,'siebsrvr','enterprises',$ENT,$SRV,'logarchive'),\
                catDir($HOM,'siebsrvr','logarchive'))
var $BIN = catDir($HOM,'siebsrvr','bin')
var $LOG = cond(isUnix(),\
                catDir($HOM,'siebsrvr','enterprises',$ENT,$SRV,'log'),\
                catDir($HOM,'siebsrvr','log'))
var $RPT = $[OUT]->add_report('c','exec_log',0)

# Collect the Enterprise log file
var $dmp = cond(defined($DMP),encode($dmp),'')
report crash
title '<!-- CRASH:|',encode($HOM),'|',$ENT,'|',$SRV,'|',$PID,'|',\
      cond(defined($DMP),encode($DMP)),'| -->'
title '---+!! Siebel Crash Data Collection'
title $TOC
title '---+ Input Parameters'
title '|*Name*|*Value*|'

if $HOM
 title '|*Siebel Server Home*|',encode($HOM),' |'
if $ENT
 title '|*Application Enterprise Name*|',$ENT,' |'
if $SRV
 title '|*Application Server Name*|',$SRV,' |'
if $PID
 title '|*Process Identifier*|',$PID,' |'
if $DMP
 title '|*Core Dump File (Last Modified Date and Size)*|',encode($DMP),' (',\
       getLastModify($DMP,'<UTC>'),'&nbsp;',getSize($DMP),') |'
title '|*Advanced collection enabled?*|',cond($ALL,'Yes','No'),' |'
title $TOP

write {$RPT} '---+!! Siebel Crash Data Collection (Execution Log)'
write {$RPT} $TOC
if $ALL
{# Collect the EVT report
 if ?testFile('x',catFile($BIN,${AS.EXE:'evt'}))
 {var $pgm = \
    concat(lastTestCommand(),' -r ',quote($HOM),' -e ',quote($ENT),' -s ',\
           quote($SRV),' -d SHOWERRORS -o TEXT -f ',catCommand($BIN,'evt.ini'))
  if isUnix()
   var $env = sourceContext(catFile($HOM,'siebsrvr','siebenv.sh'))
  var $out = newTemp('EVT')
  call command(concat($pgm,' >',$out))
  var $rpt = $[OUT]->add_report('c','evt_summary',0)
  write {$RPT} '---+ Environment Verification Summary'
  write {$RPT} '---## Using: ',encode($pgm)
  prefix $rpt
  {write {$rpt} '---+ Environment Verification Summary'
   write {$rpt} '---## Using: ',encode($pgm)
  }
  call $rpt->write_file($out)
  if $rpt->is_created(true)
  {write {$rpt} $TOP
   call $rpt->render
   write {$RPT} '   * Successfully collected EVT summary'
  }
  else
   write {$RPT} '   * Unable to collect EVT summary'
  write {$RPT} $TOP
  write '---+ EVT Summary Report'
  write '|*Summary*|[[',$rpt->get_html(true),'][_blank][Report]] |'
  write $TOP
  call unlinkTemp('EVT')
  end $rpt
 }

 # Collect the Siebel server log files
 write {$RPT} '---+ Siebel Server Logs'
 write {$RPT} '---## Information Taken from ',encode($LOG)
 prefix
 {write '---+ Siebel Server Logs'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Size*|*Last Modified Date*|'
 }
 if grepDir($LOG,'\.log$','inp')
 {loop $fil (last)
  {next compare('eq',basename($fil),concat($ENT,'.',$SRV,'.log'))
   write {$RPT} '   * Searching for ',$PID,' inside ',encode($fil)
   if grepFile($fil,concat('\s+',$PID,'\s+'),'f',0,1,1)
   {write {$RPT} '      * Found'
    var $lnk = encode($fil)
    var $nam = basename($fil)
    var $rpt = $[OUT]->add_report('d',concat('log_',$nam),0,'.log')
    if $rpt->write_data($fil)
     var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
    end $rpt
    write '|',$lnk,' | ',getSize($fil),'|',getLastModify($fil,'<UTC>'),' |'
   }
   else
    write {$RPT} '      * Not Found'
  }
 }
 else
  write {$RPT} '   * No *.log files found'
 if hasOutput(true)
  write $TOP
 write {$RPT} $TOP
}

# Collect the Enterprise log file
prefix
{write '---+ Enterprise Log File'
 write '   * Links point to files that have been collected in their original \
             format. Opening them directly in your browser can present \
             risks. To prevent them, access the file outside the browser or \
             use the link to save them and use an adequate viewer.'
 write '|*File Name*| *Size*|*Last Modified Date*|'
}
var $fil = catFile($LOG,concat($ENT,'.',$SRV,'.log'))
write {$RPT} '---+ Enterprise Log File'
write {$RPT} '---## Information Taken from ',encode($fil)
if ?testFile('fr',$fil)
{var $siz = getSize($fil)
 var $lnk = encode($fil)
 if $siz
 {output d,"log.log"
  if ${CUR.O_LAST}->write_data($fil)
   var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
  end ${CUR.O_LAST}
 }
 write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
}
if hasOutput(true)
{write $TOP
 write {$RPT} '   * Successfully collected the file'
}
else
 write {$RPT} '   * Unable to collect the file'
write {$RPT} $TOP

# Collect the core dump file
if $ALL
{write {$RPT} '---+ Core / Dump Files'
 write {$RPT} '---## Information Taken from ',encode($DMP)
 if ?testFile('fr',$DMP)
 {prefix
  {write '---+ Core / Dump Files'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  var $nam = basename($DMP)
  var $siz = getSize($DMP)
  var $lnk = encode($DMP)
  if $siz
  {var $rpt = $[OUT]->add_report('d',concat('c_',$nam),0,'.dmp')
   if $rpt->write_data($DMP)
    var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
   end $rpt
  }
  write '|',$lnk,' | ',$siz,'|',getLastModify($DMP,'<UTC>'),' |'
  var $pat = cond(or(isWindows(),isCygwin()),'\.dmp$',\
                                    isUnix(),'^core.*')
  loop $fil (grepDir(dirname($DMP),$pat,'inp'))
  {next sameFile($fil,$DMP)
   write '|',encode($fil),' | ',getSize($fil),'|',\
         getLastModify($fil,'<UTC>'),' |'
  }
  if hasOutput(true)
  {write $TOP
   write {$RPT} '   * Successfully collected the file'
  }
  else
   write {$RPT} '   * Unable to collect the file'
  write {$RPT} $TOP

  # Check for FDR data in dump file
  write {$RPT} '---++ FDR Data Extracted from Core / Dump File'
  write {$RPT} '---### Information Extracted from ',encode($DMP)
  prefix
  {write '---++ FDR Data Extracted from Core / Dump File'
   write '---### Information Extracted from ',encode($DMP)
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*FDR File*|*Converted CSV File*|'
  }
  var $fdr = $[OUT]->add_report('b',concat('b_',$nam),0,'.log')
  if $fdr->write_extract($DMP,'(FDR  SV)',5000028)
  {var $lnk = concat('[[',$fdr->get_raw(true),'][_blank][FDR File]]')
   var $src = $fdr->get_file(true)
   end $fdr
   write {$RPT} '   * Successfully extracted FDR data'
   var $csv = 'CSV File'
   var $out = newTemp('FDR')
   call command(concat(catCommand($BIN,${AS.EXE:'sarmanalyzer'}),\
                       ' -o ',$out,' -x -f ',quote($src)))
   var $rpt = $[OUT]->add_report('d',concat('d_',$nam),0,'.csv')
   if $rpt->write_data($out)
   {var $csv = concat('[[',$rpt->get_raw(true),'][_blank][',$csv,']]')
    write {$RPT} '   * Successfully converted FDR data into CSV'
   }
   else
    write {$RPT} '   * Unable to convert the FDR data into CSV'
   end $rpt
   call unlinkTemp('FDR')
   write '|',$lnk,' |',$csv,' |'
  }
  else
  {end $fdr
   write {$RPT} '   * No FDR data found'
  }
  if hasOutput(true)
   write $TOP
 }
 else
  write {$RPT} '   * Unable to read the file'
 write {$RPT} $TOP

 # Collect the core dump logs
 if or(isWindows(),isCygwin())
 {var $log = dirname($DMP)
  write {$RPT} '---+ Core / Dump Logs'
  write {$RPT} '---## Information Taken from ',encode($log)
  prefix
  {write '---+ Core / Dump Logs'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $fil (grepDir($log,'\.(log|txt)$','inp'))
  {var $nam = basename($fil)
   var $siz = getSize($fil)
   var $lnk = encode($fil)
   if $siz
   {var $rpt = $[OUT]->add_report('d',concat('l_',$nam),0)
    if $rpt->write_data($fil)
     var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
    end $rpt
   }
   write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
  }
  if hasOutput(true)
  {write $TOP
   write {$RPT} '   * Successfully collected the files'
  }
  else
   write {$RPT} '   * Unable to collect the files'
  write {$RPT} $TOP
 }
}

# List the call stack files
write {$RPT} '---+ Call Stack Files'
write {$RPT} '---## Information Taken from ',encode($BIN)
if grepDir($BIN,'^callstack','inp')
{prefix
 {write '---+ Call Stack Files'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Size*|*Last Modified Date*|'
 }
 loop $fil (last)
 {write {$RPT} '   * Found file ',encode($fil)
  var $siz = getSize($fil)
  var $lnk = encode($fil)
  if and(defined($PID),\
    match($nam = basename($fil),concat('^callstack.*',$PID),true))
  {if $siz
   {var $rpt = $[OUT]->add_report('d',$nam,0,'.log')
    if $rpt->write_data($fil)
    {var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
     write {$RPT} '      * Successfully gathered the file'
    }
    else
     write {$RPT} '      * Unable to get the file'
    end $rpt
   }
   else
    write {$RPT} '      * Unable to read the file'
  }
  write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
 }
 if hasOutput(true)
  write $TOP
}
else
 write {$RPT} '   * No callstack*.* files found'
write {$RPT} $TOP

# Analyze the core dump
if or(${OS.aix},${OS.hpux},${OS.linux},${OS.solaris})
{if ?testFile('fr',$DMP)
 {# Try to extract the program name that produced the core
  var $pgm = field(cond(${OS.aix},",\s*","'"),1,\
                   command(concat('file ',quote($DMP))))

  # Extract the stack trace and the threat identifier
  write {$RPT} '---+ Stack Trace Extraction'
  write '---+ Stack Trace Extraction'
  write '|*Core file*|',encode($DMP),'|'
  write '|*Program*|',encode($pgm),'|'
  if ${OS.aix}
  {write {$RPT} '---++ dbx Output'
   if ?findCommand('dbx',true)
   {var $dbg = last
    write '|*Debugger*|',$dbg,'|'
    if isAbsolute($pgm)
     var $pgm = catCommand($pgm)
    else
     var $pgm = catCommand($BIN,$pgm)
    if createBuffer('DMP','R',$DMP)
    {if unpack('N',getBytes('DMP',4,0xdc))
     {var ($PID) = last
      write '|*Process Identifier from Core Dump*|',$PID,' |'
     }
     deleteBuffer('DMP')
    }
    prefix
     write '---++ dbx Output'
    var $inp = createTemp('debug')
    call writeTemp('debug','th')
    call writeTemp('debug','quit')
    call closeTemp('debug')
    loop $lin (grepCommand(concat(quote($dbg),' ',$pgm,' ',quote($DMP),\
                                  ' <',$inp),'^>\$t\d+'))
    {if match($lin,'^>\$t(\d+)')
      call push(@thr,last)
    }
    call unlinkTemp('debug')
    var $inp = createTemp('debug')
    write {$RPT} '---### Using: ',encode($dbg),' ',encode($pgm),' ',encode($DMP)
    if @thr
    {loop $thr (last)
     {write {$RPT} '---### Thread Info ',$thr
      write {$RPT} '   * Executing ``th info ',$thr,'``'
      call writeTemp('debug','print "</verbatim>"')
      call writeTemp('debug','print "---### Thread Info ',$thr,'"')
      call writeTemp('debug','print "<verbatim>"')
      call writeTemp('debug','th info ',$thr)
     }
    }
    else
     write {$RPT} '   * No thread information'
    call writeTemp('debug','print "</verbatim>"')
    write {$RPT} '---### Registers'
    write {$RPT} '   * Executing ``registers``'
    call writeTemp('debug','print "---### Registers"')
    call writeTemp('debug','print "<verbatim>"')
    call writeTemp('debug','registers')
    call writeTemp('debug','print "</verbatim>"')
    write {$RPT} '---### Stack'
    write {$RPT} '   * Executing ``where``'
    call writeTemp('debug','print "---### Stack"')
    call writeTemp('debug','print "<verbatim>"')
    call writeTemp('debug','where')
    call writeTemp('debug','quit')
    call closeTemp('debug')
    call loadCommand(concat(quote($dbg),' ',$pgm,' ',quote($DMP),' <',$inp))
    loop $lin (grepLastFile('^\s+pthread_t\s+=\s'))
     call push(@tid,hex2int(value($lin)))
    call writeLastFile()
    if hasOutput(true)
     write $TOP
    call unlinkTemp('debug')
   }
   else
    write {$RPT} '   * No dbx found'
   write {$RPT} $TOP

   # Bundle the core file along with its related libraries
   if $ALL
   {write {$RPT} '---+ Core Package'
    if ?findCommand('snapcore')
    {var $cmd = last
     var $box = getGroupDir('D_CWD',cleanBox())
     write {$RPT} '---## Using: ',encode($cmd),' -d ',encode($box),\
                  ' ',encode($DMP)
     call command(concat($cmd,' -d ',quote($box),' ',quote($DMP)))
     if grepDir($box,'^snapcore[_\.]\d+\.pax\.Z$','ft')
     {var ($src) = last
      if $siz = getSize($fil = catFile($box,$src))
      {var $rpt = $[OUT]->add_report('b',basename($src,'.Z'),0)
       if $rpt->write_data($fil)
       {write {$RPT} '   * Core package gathered'
        write '---+ Core Package'
        write '   * Links point to files that have been collected in their \
                    original format. Opening them directly in your browser \
                    can present risks. To prevent them, access the file \
                    outside the browser or use the link to save them and use \
                    an adequate viewer.'
        write '|*File Name*| *Size*|*Last Modified Date*|'
        write '|[[',$rpt->get_raw(true),'][_blank][',$src,']] | ',$siz,'|',\
              getLastModify($fil,'<UTC>'),' |'
        write $TOP
       }
       else
        write {$RPT} '   * Unable to get the core package'
       end $rpt
      }
      else
       write {$RPT} '   * Unable to read the core package'
     }
     else
      write {$RPT} '   * Core package not found'
    }
    else
     write {$RPT} '   * No snapcore found'
    write {$RPT} $TOP
   }
  }
  elsif ${OS.hpux}
  {write {$RPT} '---++ gdb Output'
   if ?findCommand('gdb',true)
   {var $dbg = last
    write '|*Debugger*|',$dbg,'|'
    if isAbsolute($pgm)
     var $pgm = catCommand($pgm)
    else
     var $pgm = catCommand($BIN,$pgm)
    prefix
     write '---++ gdb Output'
    var $inp = createTemp('debug')
    write {$RPT} '---## Using: ',encode($dbg),' ',encode($pgm),' ',encode($DMP)
    write {$RPT} '---### Thread'
    write {$RPT} '   * Executing ``x $mpsfu_high + 0x9c``'
    call writeTemp('debug','echo \n</verbatim>\n---### Thread\n<verbatim>\n')
    call writeTemp('debug','x $mpsfu_high + 0x9c')
    write {$RPT} '---### Stack'
    write {$RPT} '   * Executing ``where``'
    call writeTemp('debug','echo \n</verbatim>\n---### Stack\n<verbatim>\n')
    call writeTemp('debug','where')
    write {$RPT} '---### Registers'
    write {$RPT} '   * Executing ``info all-registers``'
    call writeTemp('debug','echo \n</verbatim>\n---### Registers\n<verbatim>\n')
    call writeTemp('debug','info all-registers')
    call writeTemp('debug','q')
    call closeTemp('debug')
    call loadCommand(concat(quote($dbg),' ',$pgm,' ',quote($DMP),' <',$inp))
    var $flg = false
    loop $lin (grepLastFile('---###|0x'))
    {if match($lin,'^---###\sThread')
      var $flg = true
     elsif match($lin,'^---###\s')
      break
     elsif $flg
     {call push(@tid,hex2int(field(':\s+',1,$lin)))
      break
     }
    }
    call writeLastFile()
    if hasOutput(true)
     write $TOP
    call unlinkTemp('debug')
    write {$RPT} $TOP

    # Bundle the core file along with its related libraries
    if $ALL
    {write {$RPT} '---+ Core Package'
     write {$RPT} '---## Using: ',encode($dbg),' ',encode($pgm),' ',encode($DMP)
     write {$RPT} '   * Executing ``packcore``'
     var $inp = createTemp('debug')
     call writeTemp('debug','packcore')
     call writeTemp('debug','q')
     call closeTemp('debug')
     call command(concat(quote($dbg),' ',$pgm,' ',quote($DMP),' <',$inp))
     if grepDir(${CFG.D_RDA},'^.*\.tar\.Z$','ft')
     {var ($src) = last
      if $siz = getSize($fil = catFile(${CFG.D_RDA},$src))
      {var $rpt = $[OUT]->add_report('b',basename($src,'.Z'),0)
       if $rpt->write_data($fil)
       {write {$RPT} '   * Core package gathered'
        write '---+ Core Package'
        write '   * Links point to files that have been collected in their \
                    original format. Opening them directly in your browser \
                    can present risks. To prevent them, access the file \
                    outside the browser or use the link to save them and use \
                    an adequate viewer.'
        write '|*File Name*| *Size*|*Last Modified Date*|'
        write '|[[',$rpt->get_raw(true),'][_blank][',$src,']] | ',$siz,'|',\
              getLastModify($fil,'<UTC>'),' |'
        write $TOP
       }
       else
        write {$RPT} '   * Unable to get the core package'
       end $rpt
      }
      else
       write {$RPT} '   * Unable to read the core package'
     }
     else
      write {$RPT} '   * Core package not found'
     call unlinkTemp('debug')
     write {$RPT} $TOP
    }
   }
   else
   {write {$RPT} '   * No gdb found'
    write {$RPT} $TOP
   }
  }
  elsif ${OS.linux}
  {# Extract information from the core file
   loop $typ ('gdb','mdb','adb','sdb','dbx')
   {if ?findCommand($typ,true)
    {var $typ = last
     if ?testFile('x',$typ)
     {var $dbg = last
      write '|*Debugger*|',$dbg,'|'
      break
     }
    }
   }

   # Try to extract the stack trace
   if ?$dbg
   {prefix
    {write '---++ ',basename($dbg),' Output'
     write '---## Using: ',encode($dbg),' ',encode($pgm),' ',encode($DMP)
    }
    write {$RPT} '---++ ',basename($dbg),' Output'
    write {$RPT} '---## Using: ',encode($dbg),' ',encode($pgm),' ',encode($DMP)

    # Initialize the debugger input file
    var $inp = createTemp('debug')
    if match($dbg,'gdb$')
    {write {$RPT} '---### Stack'
     write {$RPT} '   * Executing ``thread apply all where``'
     call writeTemp('debug','echo \n</verbatim>\n---### Stack\n<verbatim>\n')
     call writeTemp('debug','thread apply all where')
     write {$RPT} '---### Registers'
     write {$RPT} '   * Executing ``info all-registers``'
     call writeTemp('debug',\
       'echo \n</verbatim>\n---### Registers\n<verbatim>\n')
     call writeTemp('debug','info all-registers')
     call writeTemp('debug','q')
    }
    elsif match($dbg,'mdb$')
    {write {$RPT} '---### Version and Status'
     write {$RPT} '   * Executing ``::version``'
     write {$RPT} '   * Executing ``::status``'
     call writeTemp('debug','!echo "</verbatim>"')
     call writeTemp('debug','!echo "---### Version and Status"')
     call writeTemp('debug','!echo "<verbatim>"')
     call writeTemp('debug','::version')
     call writeTemp('debug','::status')
     call writeTemp('debug','!echo "</verbatim>"')
     write {$RPT} '---### Stack'
     write {$RPT} '   * Executing ``::walk thread | ::findstack``'
     call writeTemp('debug','!echo "---### Stack"')
     call writeTemp('debug','!echo "<verbatim>"')
     call writeTemp('debug','::walk thread | ::findstack')
     call writeTemp('debug','!echo "</verbatim>"')
     write {$RPT} '---### Registers'
     write {$RPT} '   * Executing ``::regs``'
     call writeTemp('debug','!echo "---### Registers"')
     call writeTemp('debug','!echo "<verbatim>"')
     call writeTemp('debug','::regs')
    }
    elsif match($dbg,'adb$')
    {write {$RPT} '---### Stack'
     write {$RPT} '   * Executing ``$c``'
     call writeTemp('debug','!echo "</verbatim>"')
     call writeTemp('debug','!echo "---### Stack"')
     call writeTemp('debug','!echo "<verbatim>"')
     call writeTemp('debug','$c')
     call writeTemp('debug','!echo "</verbatim>"')
     write {$RPT} '---### Registers'
     write {$RPT} '   * Executing ``$r``'
     write {$RPT} '   * Executing ``$f``'
     call writeTemp('debug','!echo "---### Registers"')
     call writeTemp('debug','!echo "<verbatim>"')
     call writeTemp('debug','$r')
     call writeTemp('debug','$f')
     call writeTemp('debug','!echo "</verbatim>"')
     write {$RPT} '---### Memory Map'
     write {$RPT} '   * Executing ``$m``'
     call writeTemp('debug','!echo "---### Memory Map"')
     call writeTemp('debug','!echo "<verbatim>"')
     call writeTemp('debug','$m')
     call writeTemp('debug','!echo "</verbatim>"')
     write {$RPT} '---### Variables'
     write {$RPT} '   * Executing ``$v``'
     call writeTemp('debug','!echo "---### Variables"')
     call writeTemp('debug','!echo "<verbatim>"')
     call writeTemp('debug','$v')
     call writeTemp('debug','$q')
    }
    elsif match($dbg,'sdb$')
    {call writeTemp('debug','t')
     call writeTemp('debug','quit')
    }
    elsif match($dbg,'dbx$')
    {write {$RPT} '---### Stack'
     write {$RPT} '   * Executing ``where``'
     call writeTemp('debug','print "</verbatim>"')
     call writeTemp('debug','print "---### Stack"')
     call writeTemp('debug','print "<verbatim>"')
     call writeTemp('debug','where')
     call writeTemp('debug','print "</verbatim>"')
     write {$RPT} '---### Registers'
     write {$RPT} '   * Executing ``registers``'
     call writeTemp('debug','print "---### Registers"')
     call writeTemp('debug','print "<verbatim>"')
     call writeTemp('debug','registers')
     call writeTemp('debug','quit')
    }
    call closeTemp('debug')

    # Try them individually to extract a stack trace.
    if isAbsolute($pgm)
     var $pgm = catCommand($pgm)
    else
     var $pgm = catCommand($BIN,$pgm)
    call writeCommand(concat(quote($dbg),' ',$pgm,' ',quote($DMP),' <',$inp))
    if hasOutput(true)
     write $TOP

    # Remove the temporary debug file
    call unlinkTemp('debug')
    write {$RPT} $TOP
   }
   else
   {write {$RPT} '   * No debugger found'
    write {$RPT} $TOP
   }

   # Bundle the core file along with its related libraries
   if $ALL
   {var $fil = catFile($BIN,'lingrabcore.sh')
    write {$RPT} '---+ Core Package'
    write {$RPT} '---## Using: ',encode($fil),' ',encode($DMP)
    if ?testFile('x',$fil)
    {var $job = createTemp('CORE','.sh',true)
     call writeTemp('CORE','cd "',$BIN,'"')
     call writeTemp('CORE','./lingrabcore.sh ',quote($DMP))
     call closeTemp('CORE')
     call command($job)
     call unlinkTemp('CORE')
     if grepDir($BIN,'^core_diag_?\d{14}\.tar\.gz$','ft')
     {var ($src) = last
      if $siz = getSize($fil = catFile($BIN,$src))
      {var $rpt = $[OUT]->add_report('b',basename($src,'.gz'),0)
       if $rpt->write_data($fil)
       {write {$RPT} '   * Core package gathered'
        write '---+ Core Package'
        write '   * Links point to files that have been collected in their \
                    original format. Opening them directly in your browser can \
                    present risks. To prevent them, access the file outside \
                    the browser or use the link to save them and use an \
                    adequate viewer.'
        write '|*File Name*| *Size*|*Last Modified Date*|'
        write '|[[',$rpt->get_raw(true),'][_blank][',$src,']] | ',$siz,'|',\
              getLastModify($fil,'<UTC>'),' |'
        write $TOP
       }
       else
        write {$RPT} '   * Unable to get the core package'
       end $rpt
      }
      else
       write {$RPT} '   * Unable to read the core package'
     }
     else
      write {$RPT} '   * Core package not found'
    }
    else
     write {$RPT} '   * ',encode($fil),' is not with execute permission'
    write {$RPT} $TOP
   }
  }
  elsif ${OS.solaris}
  {# When we find pstack, use it to extract information from the core file
   write {$RPT} '---++ pstack Output'
   if ?findCommand('pstack',true)
   {var $dbg = last
    write '|*Debugger*|',$dbg,'|'
    write {$RPT} '---### Using: ',encode($dbg),' ',encode($DMP)
    call loadCommand(concat(quote($dbg),' ',quote($DMP)))
    var ($lin) = grepLastFile('^core.* of \d+:','f')
    if match($lin,'^core.* of (\d+):')
    {var ($PID) = last
     write '|*Process Identifier from Core Dump*| ',$PID,'|'
    }
    loop $lin (grepLastFile('(thread|signal)'))
    {if match ($lin,'---.*thread\#\s+(\d+)\s+----')
     {var ($tid) = last
      call push(@tid,$tid)
     }
    }
    prefix
     write '---++ pstack Output'
    call writeLastFile()
    if hasOutput(true)
    {write $TOP
     write {$RPT} '   * Command successful'
    }
    else
     write {$RPT} '   * Command failed'
   }
   else
    write {$RPT} '   * No pstack found'
   write {$RPT} $TOP

   # When we find pmap, run it
   write {$RPT} '---++ pmap Output'
   if ?findCommand('pmap')
   {var $cmd = last
    prefix
     write '---++ pmap Output'
    write {$RPT} '---### Using: ',encode($cmd),' ',encode($DMP)
    call writeCommand(concat($cmd,' ',quote($DMP)))
    if hasOutput(true)
    {write $TOP
     write {$RPT} '   * Command successful'
    }
    else
     write {$RPT} '   * Command failed'
   }
   else
    write {$RPT} '   * No pmap found'
   write {$RPT} $TOP

   # When we find pflags, run it
   write {$RPT} '---++ pflags Output'
   if ?findCommand('pflags')
   {var $cmd = last
    prefix
     write '---++ pflags Output'
    write {$RPT} '---### Using: ',encode($cmd),' -r ',encode($DMP)
    call writeCommand(concat($cmd,' -r ',quote($DMP)))
    if hasOutput(true)
    {write $TOP
     write {$RPT} '   * Command successful'
    }
    else
     write {$RPT} '   * Command failed'
   }
   else
    write {$RPT} '   * No pflags found'
   write {$RPT} $TOP

   # When we find pldd, run it
   write {$RPT} '---++ pldd Output'
   if ?findCommand('pldd')
   {var $cmd = last
    prefix
     write '---++ pldd Output'
    write {$RPT} '---### Using: ',encode($cmd),' ',encode($DMP)
    call writeCommand(concat($cmd,' ',quote($DMP)))
    if hasOutput(true)
    {write $TOP
     write {$RPT} '   * Command successful'
    }
    else
     write {$RPT} '   * Command failed'
   }
   else
    write {$RPT} '   * No pldd found'
   write {$RPT} $TOP

   # Bundle the core file along with its related libraries
   if $ALL
   {var $fil = catFile($BIN,'solgrabcore.sh')
    write {$RPT} '---+ Core Package'
    write {$RPT} '---## Using: ',encode($fil),' ',encode($DMP)
    if ?testFile('x',$fil)
    {var $job = createTemp('CORE','.sh',true)
     call writeTemp('CORE','cd "',$BIN,'"')
     call writeTemp('CORE','./solgrabcore.sh ',quote($DMP))
     call closeTemp('CORE')
     call command($job)
     call unlinkTemp('CORE')
     if grepDir($BIN,'^core_diag_\d{14}\.tar\.Z$','ft')
     {var ($src) = last
      if $siz = getSize($fil = catFile($BIN,$src))
      {var $rpt = $[OUT]->add_report('b',basename($src,'.Z'),0)
       if $rpt->write_data($fil)
       {write {$RPT} '   * Core package gathered'
        write '---+ Core Package'
        write '   * Links point to files that have been collected in their \
                    original format. Opening them directly in your browser \
                    can present risks. To prevent them, access the file \
                    outside the browser or use the link to save them and use \
                    an adequate viewer.'
        write '|*File Name*| *Size*|*Last Modified Date*|'
        write '|[[',$rpt->get_raw(true),'][_blank][',$src,']] | ',$siz,'|',\
              getLastModify($fil,'<UTC>'),' |'
        write $TOP
       }
       else
        write {$RPT} '   * Unable to get the core package'
       end $rpt
      }
      else
       write {$RPT} '   * Unable to read the core package'
     }
     else
      write {$RPT} '   * Core package not found'
    }
    else
     write {$RPT} '   * ',encode($fil),' is not with execute permission'
    write {$RPT} $TOP
   }
  }
 }
}

# Collect the process identifier-related information
if ?$PID
{# Collect the crash files
 if ${OS.hpux}
 {var $pat = '^Process\s+(\d+)\,\s+thread\s+(.*)$'
  code set_ids
  {var ($pid,$tid) = last
   return ($pid,hex2int($tid))
  }
 }
 elsif isUnix()
 {var $pat = '^PROCESS\s+(\d+)\s+CRASHED.*THREAD\s+(\d+)'
  code set_ids
   return last
 }
 else
 {var $pat = '^Thread\:\s+(.*)\,\s+Process\s+(.*)$'
  code set_ids
  {var ($tid,$pid) = last
   return (hex2int($pid),hex2int($tid))
  }
 }
 write {$RPT} '---+ Crash Files'
 write {$RPT} '---## Information Taken from ',encode($BIN)
 prefix
 {write '---+ Crash Files'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Size*|*Last Modified Date*|'
 }
 if grepDir($BIN,'^crash.*\.txt$','inp')
 {loop $fil (last)
  {write {$RPT} '   * Found file ',encode($fil)
   if $ALL
   {loop $lin (grepFile($fil,$pat))
    {var ($pid,$tid) = eval(&set_ids(match($lin,$pat)))
     if expr('==',$pid,$PID)
      call push(@tid,$tid)
    }
    var $siz = getSize($fil)
    var $lnk = encode($fil)
    if $siz
    {var $rpt = $[OUT]->add_report('d',basename($fil),0,'.log')
     if $rpt->write_data($fil)
     {var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
      write {$RPT} '      * Successfully gathered the file'
     }
     else
      write {$RPT} '      * Unable to get the file'
     end $rpt
    }
    else
     write {$RPT} '      * Unable to read the file'
    write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
   }
   else
   {if grepFile($fil,$pat)
    {loop $lin (last)
     {write {$RPT} '   * Found pattern ',$pat,' inside file ',encode($fil)
      var ($pid,$tid) = eval(&set_ids(match($lin,$pat)))
      if expr('==',$pid,$PID)
      {call push(@tid,$tid)
       var $siz = getSize($fil)
       var $lnk = encode($fil)
       if $siz
       {output d,"crash.log"
        if ${CUR.O_LAST}->write_data($fil)
        {var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                           '][_blank][',$lnk,']]')
         write {$RPT} '      * Successfully gathered the file'
        }
        else
         write {$RPT} '      * Unable to get the file'
        end ${CUR.O_LAST}
       }
       else
        write {$RPT} '      * Unable to read the file'
       write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
      }
      else
       write {$RPT} '   * PID ',$pid,\
                    ' found inside file does not match the setup PID ',$PID
     }
    }
    else
     write {$RPT} '   * Pattern ',$pat,' inside file ',encode($fil),' not found'
   }
  }
  if ${OS.solaris}
  {var $fil = catFile($BIN,concat('callstack_',$PID))
   var $siz = getSize($fil)
   var $lnk = encode($fil)
   if $siz
   {output d,"callstack.log"
    if ${CUR.O_LAST}->write_data($fil)
     var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
    end ${CUR.O_LAST}
   }
   write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
  }
  if hasOutput(true)
   write $TOP
 }
 else
  write {$RPT} '   * No crash*.txt files found'
 write {$RPT} $TOP

 # Collect the component log files
 write {$RPT} '---+ Component Log Files'
 if @tid
 {prefix
  {write '---+ Component Log Files'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  var $pat = concat('\b',$PID,'\s+(',join('|',@tid),')\b')
  loop $fil (grepDir($LOG,'\.log$','inp'),grepDir($ARC,'\.log$','dir'))
  {if grepFile($fil,$pat,'f',0,1,1)
   {write {$RPT} '   * Found pattern ',$pat,' inside file ',encode($fil)
    var $siz = getSize($fil)
    var $lnk = encode($fil)
    if $siz
    {output d,"component.log"
     if ${CUR.O_LAST}->write_data($fil)
     {var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                        '][_blank][',$lnk,']]')
      write {$RPT} '      * Successfully gathered the file'
     }
     else
      write {$RPT} '      * Unable to get the file'
     end ${CUR.O_LAST}
    }
    else
     write {$RPT} '      * Unable to read the file'
    write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
   }
   else
    write {$RPT} '   * Pattern ',$pat,' inside file ',encode($fil),' not found'
  }
  if hasOutput(true)
   write $TOP
  else
   write {$RPT} '   * No *.log files found from ',encode($LOG),' and ',\
                encode($ARC)
 }
 else
  write {$RPT} '   * No thread ids found'
 write {$RPT} $TOP
}

# Collect the assert files
if $ALL
{write {$RPT} '---+ Assert Files'
 write {$RPT} '---## Information Taken from ',encode($BIN)
 prefix
 {write '---+ Assert Files'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File Name*| *Size*|*Last Modified Date*|'
 }
 loop $fil (grepDir($BIN,'assert.*\.txt$','inp'))
 {var $siz = getSize($fil)
  var $lnk = encode($fil)
  write {$RPT} '   * Found ',encode($fil),' file'
  if $siz
  {var $rpt = $[OUT]->add_report('d',basename($fil),0,'.log')
   if $rpt->write_data($fil)
   {var $lnk = concat('[[',$rpt->get_raw(true),'][_blank][',$lnk,']]')
    write {$RPT} '      * Successfully gathered the file'
   }
   else
    write {$RPT} '      * Unable to get the file'
   end $rpt
  }
  else
   write {$RPT} '      * Unable to read the file'
  write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
 }
 if hasOutput(true)
  write $TOP
 else
  write {$RPT} '   * No assert*.txt files found'
 write {$RPT} $TOP
}

# Collect the FDR files
if !isFiltered()
{write {$RPT} '---+ Siebel Flight Data Recorder (FDR) Files'
 write {$RPT} '---## Information Taken from ',encode($BIN)
 title '---+ Siebel Flight Data Recorder (FDR) Files'
 title '   * The system log files are binary files and are captured only when \
             RDA is able to read the files. Use the link to save it and use \
             an adequate viewer.'
 if $ALL
 {var $pgm = catCommand($BIN,${AS.EXE:'sarmanalyzer'})
  prefix
   write '|*File Name*| *Size*|*Last Modified Date*|*Converted CSV File*|'
  if grepDir($BIN,concat('P0*',$PID,'\.fdr$'),'inp')
  {loop $fil (last)
   {write {$RPT} '   * Found file ',encode($fil)
    if ?testFile('f',$fil)
    {var $lnk = encode($fil)
     var $siz = getSize($fil)
     if and($siz,testFile('fr',$fil))
     {var $nam = basename($fil)
      var $fdr = $[OUT]->add_report('b',concat('b_',$nam),0,'.log')
      if $fdr->write_data($fil)
      {var $lnk = concat('[[',$fdr->get_raw(true),'][_blank][',$lnk,']]')
       end $fdr
       write {$RPT} '      * Successfully gathered FDR data'
       var $csv = 'CSV File'
       var $out = newTemp('FDR')
       call command(concat($pgm,' -o ',$out,' -x -f ',quote($fil)))
       var $rpt = $[OUT]->add_report('d',concat('d_',$nam),0,'.csv')
       if $rpt->write_data($out)
       {var $csv = concat('[[',$rpt->get_raw(true),'][_blank][',$csv,']]')
        write {$RPT} '      * Successfully converted FDR data into CSV'
       }
       else
        write {$RPT} '      * Unable to convert the FDR data into CSV'
       call unlinkTemp('FDR')
       end $rpt
      }
      else
      {end $fdr
       write {$RPT} '      * Unable to get the FDR data'
      }
     }
     else
      write {$RPT} '      * Unable to read the file'
     write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |',$csv,' |'
    }
    else
     write {$RPT} '      * Not a plain file'
   }
  }
  else
   write {$RPT} '   * No P0*',$PID,'.fdr files found'
 }
 else
 {prefix
   write '|*File Name*| *Size*|*Last Modified Date*|'
  if grepDir($BIN,concat('P0*',$PID,'\.fdr$'),'inp')
  {loop $fil (last)
   {write {$RPT} '   * Found file ',encode($fil)
    if ?testFile('f',$fil)
    {var $lnk = encode($fil)
     var $siz = getSize($fil)
     if and($siz,testFile('fr',$fil))
     {output b,"fdr.log"
      if ${CUR.O_LAST}->write_data($fil)
      {var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                         '][_blank][',$lnk,']]')
       write {$RPT} '      * Successfully gathered FDR data'
      }
      else
       write {$RPT} '      * Unable to get the FDR data'
      end ${CUR.O_LAST}
     }
     else
      write {$RPT} '      * Unable to read the file'
     write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
    }
    else
     write {$RPT} '      * Not a plain file'
   }
  }
  else
   write {$RPT} '   * No P0*',$PID,'.fdr files found'
 }
 if hasOutput(true)
  write $TOP
 write {$RPT} $TOP
}

# Add the RDA execution log
if $RPT->is_created
{call $RPT->render
 write '---+ RDA Execution Log'
 write '|*RDA Execution Log*|[[',$RPT->get_html(true),'][_blank][Log]] |'
 write $TOP
}
else
 end $RPT

# Render the report
if isCreated()
{call renderFile()
 echo 'Result file: ',last
}

# Restore the previous environment
call restoreContext($bkp)

=head1 SEE ALSO

L<RDA:DCload|collect::RDA:DCload>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
