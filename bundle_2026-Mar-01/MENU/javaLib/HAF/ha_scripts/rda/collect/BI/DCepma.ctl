# DCepma.ctl:572:Collects Enterprise Performance Management Architect Info.
# $Id: DCepma.ctl,v 1.16 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCepma.ctl,v 1.16 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:DCepma - Collects Oracle Hyperion Enterprise Performance Management
Architect Information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Enterprise Performance
Management Architect (EPMA).

The following reports can be generated and is regrouped under C<Performance
Management Architect>, where C<$BPMA> represents
F<$EPM_HOME/products/Foundation/BPMA>:

=cut

use Type
use Xml

echo tput('bold'),'Processing BI.EPMA module ...',tput('off')

# Initialization
var $AGE      = ${R_LOG_AGE/T:15}
var $EPM_HOME = ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $TAIL     = ${N_TAIL:5000}

var $BPMA = catDir($EPM_HOME,'products','Foundation','BPMA')

var $MOD = cond(isWindows(),'f',\
                isCygwin(), 'f',\
                            'fx')
var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Performance Management Architect'

# Validate the time settings
var $START_TIME = trim(${T_START_TIME:''},'-')
var $END_TIME = trim(${T_END_TIME:''},'-')
var $pat = '^([0-3]\d\-[A-Za-z]{3}\-[12]\d{3}_[0-2]\d:[0-5]\d)?$'
if !match($START_TIME,$pat)
{echo 'Start time format should be DD-Mon-YYYY_HH24:MI. Task audit and \
       HsvEventLog information information will be gathered for the last 14 \
       days.'
 var $START_TIME = ''
}
if !match($END_TIME,$pat)
{echo 'End time format should be DD-Mon-YYYY_HH24:MI. Task audit and \
       HsvEventLog information information will be gathered from ',\
       nvl($START_TIME,'last 14 days'),' to the current time'
 var $END_TIME = ''
}

# Load the common library
run RDA:INVinfo()
run RDA:library()

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Performance Management Architect
home collection.

=cut

debug ' Inside EPMA module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Performance Management Architect Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=for stopwords dbver

=head2 dbver - Generic Database Information

Collects generic information for Enterprise Performance Management Architect
from an Oracle Database.

=cut

if ${B_DB}
{# Load the common macros
 run DB:DBinfo()

 # Change the database context
 call setDbTarget(${I_DB})

 # Test the database connection and collect information
 debug ' Inside EPMA module, getting generic database information'
 report epma
 write '---+!! Generic Database Information'
 toc '2:[[',getFile(),'][rda_report][Generic Database Information]]'

 if testDb()
 {echo ''
  echo tput('bold'),\
       'The schema containing EPMA repository is not accessible.',tput('off')
  if $msg = getDbMessage()
  {echo $msg
  }
  echo ''
  write 'EPMA repository not accessible (',$msg,')'
 }
 else
 {# Display Oracle version
  set $sql
  {# SQL1
  "SELECT '|' || v.banner || '|'
  " FROM v$version v
  "/
  }
  prefix
  {write '---+ Oracle Database Versions from V$Version'
   write '|*Banner*|'
  }
  call writeDb($sql)

=for stopwords xmldocs

=head2 xmldocs - XML Documents

Collects XML documents from an Oracle Database for a specified time period. When
the time period is not correctly specified, it collects XML documents from the
last 14 days.

=cut

  debug ' Inside EPMA module, getting XML documents'
  report xmldocs
  set $sql
  {# PLSQL1
  "SET serveroutput on size 1000000
  "SET LONG 100000000
  "DECLARE
  " l_lgt NUMBER;
  " l_off NUMBER;
  " CURSOR C1 IS
  "  SELECT job_id,
  "         start_date,
  "         attachment_id,
  "         name,
  "         sequence_id,
  "         REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
  "           LTRIM(attachment_value),
  "           '|','&#124;'),
  "           ']','&#93;'),
  "           '[','&#91;'),
  "           '<','&lt;'),
  "           '>','&gt;'),
  "           CHR(10),'%BR%'),
  "           ' ','&nbsp;') attachment_value
  "   FROM (SELECT job.i_job_id job_id,
  "                to_char(job.d_started,'DD-Mon-YYYY HH24:MI:SS') start_date,
  "                attach.i_attachment_id attachment_id,
  "                attach.c_name name,
  "                batch.i_batch_sequence_id sequence_id,
  "                batch.x_attachment_value attachment_value
  "          FROM jm_job job,
  "               jm_attachment attach,
  "               jm_batch batch
  "          WHERE job.i_job_id = attach.i_job_id
  "            AND job.i_job_id = batch.i_job_id
  "            AND attach.i_attachment_id = batch.i_attachment_id
  "            AND job.d_started >= :1
  "            AND job.d_started <= :2
  "          ORDER BY job.d_started DESC);
  "BEGIN
  " FOR data IN c1 LOOP
  "  l_lgt := DBMS_LOB.GETLENGTH(data.attachment_value);
  "  l_off := 1;
  "  DBMS_OUTPUT.PUT_LINE('[[[' || CHR(10) ||
  "       '|' ||
  "       data.job_id || '|' ||
  "       data.start_date || ' | ' ||
  "       data.attachment_id || '|' ||
  "       data.name || ' | ' ||
  "       data.sequence_id || '|');
  "  LOOP
  "   EXIT WHEN l_off > l_lgt;
  "   DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(data.attachment_value,255,l_off));
  "   l_off := l_off + 255;
  "  END LOOP;
  "  DBMS_OUTPUT.PUT_LINE('|' || CHR(10) || ']]]');
  " END LOOP;
  "END;
  "/
  }
  prefix
  {write '---+ XML Documents'
   write $txt
   write '| *Job ID*|*Start Date*| *Attachment ID*|*Name*| *Sequence ID*|\
           *Attachment Value*|'
  }
  if $START_TIME
  {var $beg = concat("TO_DATE('",$START_TIME,"','DD-Mon-YYYY_HH24:MI')")
   if $END_TIME
   {var $end = concat("TO_DATE('",$END_TIME,"','DD-Mon-YYYY_HH24:MI')")
    var $txt = concat('   * Start time: ``',$START_TIME,\
                "``\012   * End time: ``",$END_TIME,'``')
   }
   else
   {var $end = 'SYSDATE'
    var $txt = concat('   * Start time: ``',$START_TIME,\
                "``\012   * End time: Current time")
   }
  }
  else
  {var $beg = 'SYSDATE - 14'
   var $end = 'SYSDATE'
   var $txt = '   * From last day'
  }
  call writeDb(bindDb($sql,$beg,$end),4)
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][XML Documents]]'
  }
 }
}

=for stopwords serverconfig

=head2 serverconfig - Server Configuration

Collect server configuration file F<BPMA_Server_Config.xml>.

=cut

var $fil = catFile($BPMA,'AppServer','DimensionServer','ServerEngine','bin',\
                   'BPMA_Server_Config.xml')
if ?testFile('r',$fil)
{report serverconfig
 prefix
 {write '---+ Server Configuration'
  write '---## Information Taken from: ',$fil
 }
 call writeFile($fil)
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Server Configuration]]'
}

=for stopwords deployconfig

=head2 deployconfig - Deployment Configuration

Collect deployment configuration file F<FinishedDeploymentDocument.xml>.

=cut

var $fil = catFile($BPMA,'AppServer','DimensionServer','ServerEngine',\
                   'Transformations','FinishedDeploymentDocument.xml')
if ?testFile('r',$fil)
{report deployconfig
 prefix
 {write '---+ Deployment Configuration'
  write '---## Information Taken from: ',encode($fil)
 }
 call writeFile($fil)
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Deployment Configuration]]'
}

=for stopwords webconfig

=head2 webconfig - Web Configuration

Collect web configuration file F<web.config>

=cut

var $fil = catFile($BPMA,'AppServer','DimensionServer','WebService',\
                   'web.config')
if ?testFile('r',$fil)
{report webconfig
 prefix
 {write '---+ Web Configuration'
  write '---## Information taken from: ',encode($fil)
 }
 call writeFile($fil)
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Web Configuration]]'
}

=head2 filetype - File Type Information

Collects the file type of executable files in several Hyperion Enterprise
Performance Management Architect Information program directories under
F<$EPM_HOME/products/Foundation/BPMA> directory structure.

=cut

debug ' Inside EPMA module, gathering file type information'
report filetype
title  '---+!! File Type Information'
title $TOC
var @dir = ()
if ?testDir('d',catDir($BPMA,'AppServer','DimensionServer','ServerEngine',\
                       'bin'))
 call push(@dir,lastDir())
if ?testDir('d',catDir($BPMA,'EPMAFileGenerator','bin'))
 call push(@dir,lastDir())
if or(isWindows(),isCygwin())
 var ($pat,$opt) = ('\.(exe|dll)$','in')
else
 var ($pat,$opt) = ('^\.+$','nv')
loop $dir (@dir)
{prefix
 {write '---+ Files from ',encode($dir)
  write '|*File Name*|*Type*|'
 }
 loop $fil (grepDir($dir,$pat,$opt))
 {if ?testFile($MOD,catFile($dir,$fil))
   write '|',$fil,'|',nvl(file(lastTestFile(),true),'N/A'),' |'
 }
 write $TOP
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][File Type Information]]'

=head2 Executable, Library, and Java Archive Versions

For Windows, collects the executable, library, and Java archive versions from
F<$BPMA/AppServer/DimensionServer/ServerEngine/bin>. When F<unzip> is
available, it extracts the manifest from Java archives.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside EPMA module, gathering file versions'
 pretoc '2:Executable, Library, and Java Archive Versions'

 macro dsp_versions
 {var ($rpt,$dir,$lnk,$opt) = @arg
  import $TOC,$TOP,$UNZIP
  keep $TOC,$TOP,$UNZIP

  call $[OUT]->add_report('C',$rpt,0)
  prefix
  {write '---+!! Version Information from ',$lnk,' Directory'
   write $TOC
  }
  loop $fil (grepDir($dir,'\.(dll|exe|jar)$',$opt))
  {write '---+ Version Information from ',encode(basename($fil))
   call statFile('p',$fil)
   write '%BR%'
   var $inf = getVersionInfo($fil)
   loop $key (keys($inf))
    write '|*',$key,' *|',replace($inf->{$key},'\012','%BR%',true),' |'
   write $TOP
   if and(match($fil,'\.jar$',true),$UNZIP)
   {prefix
     write '---++ Manifest Information'
    call writeCommand(concat($UNZIP,' -p ',quote($fil),' META-INF/MANIFEST.MF'))
    if hasOutput(true)
     write $TOP
   }
  }
  if isCreated(true)
   toc '4:[[',getFile(),'][rda_report][In ',$lnk,']]'
 }

 macro rpt_versions
 {var ($rpt,$top,$sub) = @arg

  var $cnt = 0
  call dsp_versions($rpt,\
                    $top,$sub,'dip')
  loop $fil (grepDir($top,'^\.+$','nv'))
  {if ?testDir('d',$dir = catDir($top,$fil))
    call dsp_versions(concat($rpt,incr($cnt)),\
                      $dir,encode(catDir($sub,$fil)),'dir')
  }
 }

 var $UNZIP = findCommand('unzip')

 pretoc '3:',catDir('$BPMA','AppServer','DimensionServer','ServerEngine')
 call rpt_versions('ver_epma_srv',\
   catDir($BPMA,'AppServer','DimensionServer','ServerEngine','bin'),'bin')
 unpretoc
 pretoc '3:',catDir('$BPMA','AppServer','DimensionServer','WebService')
 call rpt_versions('ver_epma_web',\
   catDir($BPMA,'AppServer','DimensionServer','WebService','bin'),'bin')
 unpretoc 2
}

=head2 metadata - Metadata Information

Collects all files from
F<$BPMA/AppServer/DimensionServer/ServerEngine/metadataOnly> directory.

=cut

report metadata
debug ' Inside EPMA, getting metadata information'
prefix
{write '---+ Metadata Information'
 write '   * Links point to files that have been collected in their original \
             format. Opening them directly in your browser can present \
             risks. To prevent them, access the file outside the browser or \
             use the link to save them and use an adequate viewer.'
 write '|*File Name*| *Size*|*Last Modified Date*|'
}
loop $fil (grepDir(catDir($BPMA,'AppServer','DimensionServer','ServerEngine',\
                          'metadataOnly'),'^[^\.]','dr'))
{if ?testFile('fr',$fil)
 {output d,'system.log'
  if ${CUR.O_LAST}->write_data($fil)
  {write '|[[',${CUR.O_LAST}->get_raw(true),'][_blank][',encode($fil),']]| ',\
         getSize($fil),'|',getLastModify($fil,'<UTC>'),' |'
  }
  end ${CUR.O_LAST}
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Metadata Information]]'

=head2 transform - Transformation Information

Collect F<*.xsl>, F<FinishedDeploymentDocument*.xml> and
F<GenericDeploymentDocument*.xml> from
F<$BPMA/AppServer/DimensionServer/ServerEngine/Transformations> directory.

=cut

report transform
debug ' Inside EPMA, getting transformation information'
prefix
{write '---+ Transformation Information'
 write '   * Links point to files that have been collected in their original \
             format. Opening them directly in your browser can present \
             risks. To prevent them, access the file outside the browser or \
             use the link to save them and use an adequate viewer.'
 write '|*File Name*| *Size*|*Last Modified Date*|'
}
loop $fil (grepDir(catDir($BPMA,'AppServer','DimensionServer','ServerEngine',\
                          'Transformations'),\
           '(\.xsl$|^DeploymentMapping\.xml$|\
             ^FinishedDeploymentDocument.*\.xml$|\
             ^GenericDeploymentDocument.*\.xml)','dr'))
{if ?testFile('fr',$fil)
 {output d,'system.log'
  if ${CUR.O_LAST}->write_data($fil)
  {write '|[[',${CUR.O_LAST}->get_raw(true),'][_blank][',encode($fil),']]| ',\
         getSize($fil),'|',getLastModify($fil,'<UTC>'),' |'
  }
  end ${CUR.O_LAST}
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Transformation Information]]'

=for stopwords eventx

=head2 eventx - EPMA Events

Extracts Enterprise Performance Management Architect events from the
application event log using the F<wevtutil> command. (Only available for
Windows Vista, Windows Server 2008, and Windows 7)

=cut

if or(isWindows(),isCygwin())
{debug ' Inside EPMA module, getting event log information'
 var $osv = getRegValue('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',\
                        'CurrentVersion')
 if compare('ge',$osv,'6')
 {if ?findCommand('wevtutil')
  {var $evt = last
   var $msc = expr('*',$AGE,86400000)
   var $tmp = getTemp('dat')
   call command(concat($evt,' qe Application ',\
         '"/q:*[System[TimeCreated[timediff(@SystemTime) <= ',$msc,\
         ']]]" /f:xml >',$tmp))
   code write_data
   {loop $lin (parseBuffer())
     write $lin
   }
   report eventx
    write '---+!! Enterprise Performance Management Architect Events'
   prefix
    call beginBlock(true)
   if createBuffer('EVT','R',$tmp)
   {call parseReset()
    call parseBegin('TOP',\
        '^<Event.*<System><Provider Name=.*?[BbEe][Pp][Mm][Aa].*/>','Event')
    call parseEnd('Event','.*</Event>$')
    call parseInfo('Event','buf',-1)
    call parseInfo('Event','end',&write_data)
    call parseInfo('Event','llp',false)
    call parse('EVT')
    call deleteBuffer('EVT')
   }
   if hasOutput(true)
    call endBlock(['C','wevtutil qe Application | grep -i [EB]PMA'])
   else
    write '**No Enterprise Performance Management Architect events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][EPMA Events]]'
   call unlinkTemp('dat')
  }
 }

=head2 events - EPMA Events

Extracts Enterprise Performance Management Architect events from the
application event log. (Only available for Windows NT, Windows 2000, Windows
XP, and Windows 2003)

=cut

 else
 {# Get the event file
  var $fil = replaceEnv(getRegValue(\
                'HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application',\
                'File'))

  # If the file is not readable try to copy to a temporary file
  var $flg = false
  if ?testFile('r',$fil)
  {var $evt = $fil
  }
  else
  {if ?testFile('f',$cmd = getGroupFile('D_CWD','cmd.exe'))
   {var $cmd = quote($cmd)
    if grepCommand(concat($cmd,' /c if exist mode.com echo 32to64'),'^32to64')
    {var $flg = true
     var $evt = getTemp('evt','.evt')
     call system(concat($cmd,' /c copy ',quote($fil),' ',$evt,' >NUL 2>NUL'))
    }
   }
  }

  # Extract the Performance Management Architect events
  if ?testFile('r',$evt)
  {report events
   write '---+ Application Events'
   if !writeEvents($evt,'[EeBb][Pp][Mm][Aa]',$AGE)
    write '**No Enterprise Performance Management Architect events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][EPMA Events]]'
  }
  if $flg
   call unlinkTemp('evt')
 }
}

=for stopwords synclogs

=head2 synclogs - Synchronization Log Files

Collects the synchronization log files from F<$EPM_HOME/logs/services>
directory.

=cut

report synclogs
var $log = catDir($EPM_HOME,'logs','services')
prefix
{write '---+!! Web and Data Synchronization Log Files'
 write '---## From: ',$log
 write '   * Last ',$TAIL,' lines from the log files captured'
 write '   * Links point to files that have been collected in their original \
             format. Opening them directly in your browser can present \
             risks. To prevent them, access the file outside the browser or \
             use the link to save them and use an adequate viewer.'
 write '|*File Name*| *Size*|*Last Modified Date*|'
}
loop $fil (grepDir($log,'\.log$','irt'))
{var $lnk = encode($fil)
 var $siz = getSize($fil)
 if $siz
 {output => d,concat('L_',basename($fil))
  if ${CUR.O_LAST}->write_tail($fil,$TAIL)
   var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
  end ${CUR.O_LAST}
 }
 write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Synchronization Log Files]]'

=head2 EPMA Log Files

Gathers Enterprise Performance Management Architect log files.

=cut

debug ' Inside EPMA module, gathering EPMA log files'
pretoc '2:EPMA Log Files'
call sort_files(3,$TAIL,\
  catFile($EPM_HOME,'logs','epma.log'),\
  catFile($EPM_HOME,'logs','epma_err.log'),\
  catFile($EPM_HOME,'logs','epma','epma.log'),\
  catFile($EPM_HOME,'logs','epma','epma_err.log'),\
  catFile($EPM_HOME,'logs','Shared_Services_Client.log'),\
  catFile($EPM_HOME,'logs','services',\
          'HyS9EPMADataSynchronizer-syserr.log'),\
  catFile($EPM_HOME,'logs','services',\
          'HyS9EPMADataSynchronizer-sysout.log'),\
  catFile($EPM_HOME,'logs','services','HyS9EPMAWebTier-syserr.log'),\
  catFile($EPM_HOME,'logs','services','HyS9EPMAWebTier-sysout.log'))
unpretoc

=head2 IIS Log Files

For Windows, gathers recent Internet Information Services (IIS) log files. This
is applicable for IIS version 6 or 7 only.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside EPMA module, gathering recent IIS log files'

 # Get SystemRoot
 if getEnv('SYSTEMROOT')
  var $dir = last
 else
  var ($dir) = command('echo %SystemRoot%')

 # Get IIS version
 if hasRegOption()
 {if getReg64Value('HKLM\SOFTWARE\Microsoft\InetMgr\Parameters','MajorVersion')
   var $ver = hex2dec(last)
  elsif getReg32Value('HKLM\SOFTWARE\Microsoft\InetMgr\Parameters',\
                      'MajorVersion')
   var $ver = hex2dec(last)
 }
 elsif getRegValue('HKLM\SOFTWARE\Microsoft\InetMgr\Parameters','MajorVersion')
  var $ver = hex2dec(last)
 elsif getRegValue('HKLM\SOFTWARE\Wow6432Node\Microsoft\InetMgr\Parameters',\
                   'MajorVersion')
  var $ver = hex2dec(last)

 # Determine the IIS log directory
 var $log
 if expr('==',$ver,6)
 {if ?nvl(testFile('r',catFile($dir,'system32','inetsrv','MetaBase.xml')),\
          testFile('r',catFile($dir,'Sysnative','inetsrv','MetaBase.xml')))
  {var $xml = xmlLoadFile(last,xmlDisable(xmlParser(),'DR'))
   if $xml->find('.../IIsWebServer')->get_value('LogFileDirectory')
    var $log = catDir(last,'W3SVC1')
   elsif $xml->find('.../IIsWebService')->get_value('LogFileDirectory')
    var $log = catDir(last,'W3SVC1')
  }
  elsif ?testFile('f',$cmd = getGroupFile('D_CWD','cmd.exe'))
  {var $fil = catFile($dir,'system32','inetsrv','MetaBase.xml')
   var $xml = xmlLoadCommand(concat(quote($cmd),' /c type ',quote($fil)),\
              xmlDisable(xmlParser(),'DR'))
   if $xml->find('.../IIsWebServer')->get_value('LogFileDirectory')
    var $log = catDir(last,'W3SVC1')
   elsif $xml->find('.../IIsWebService')->get_value('LogFileDirectory')
    var $log = catDir(last,'W3SVC1')
  }
  if !$log
  {if ?nvl(testDir('d',catDir($dir,'system32','LogFiles','W3SVC1')),\
           testDir('d',catDir($dir,'Sysnative','LogFiles','W3SVC1')))
   var $log = last
  }
 }
 elsif expr('==',$ver,7)
 {if ?nvl(testFile('r',catFile($dir,'system32','inetsrv',\
                               'Applicationhost.config')),\
          testFile('r',catFile($dir,'Sysnative','inetsrv',\
                               'Applicationhost.config')),\
          testFile('r',catFile($dir,'system32','inetsrv','config',\
                               'Applicationhost.config')),\
          testFile('r',catFile($dir,'Sysnative','inetsrv','config',\
                               'Applicationhost.config')))
  {var $xml = xmlLoadFile(last,xmlDisable(xmlParser(),'DR'))
   if $xml->find('.../logFile')->get_value('directory')
    var $log = catDir(replaceEnv(last))
   elsif $xml->find('.../log/centralW3CLogFile')->get_value('directory')
    var $log = catDir(replaceEnv(last))
   if ?testDir('d',catDir($log,'W3SVC1'))
    var $log = lastDir()
  }
  elsif ?testFile('f',$cmd = getGroupFile('D_CWD','cmd.exe'))
  {loop $fil (catFile($dir,'system32','inetsrv','Applicationhost.config'),\
     catFile($dir,'system32','inetsrv','config','Applicationhost.config'))
   {var $xml = xmlLoadCommand(concat(quote($cmd),' /c type ',quote($fil)),\
               xmlDisable(xmlParser(),'DR'))
    next xmlStatCommand()
    if $xml->find('.../log/centralW3CLogFile')->get_value('directory')
     var $log = catDir(replaceEnv(last))
    elsif $xml->find('.../logFile')->get_value('directory')
     var $log = catDir(replaceEnv(last))
    if ?testDir('d',catDir($log,'W3SVC1'))
     var $log = lastDir()
    break
   }
  }
  if !$log
  {if ?nvl(testDir('d',catDir($dir,'system32','inetpub','logs','LogFiles')),\
           testDir('d',catDir($dir,'Sysnative','inetpub','logs','LogFiles')))
   var $log = last
  }
 }

 # Collect recent log files
 if $log
 {report iislog
  prefix
  {write '---+!! IIS Log Files'
   write '---## From: ',$log
   write '   * Limited to last ',$AGE,' days'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $fil (grepDir($log,'\.log$','ipt'))
  {break isOlder($fil,$AGE)
   var $lnk = encode($fil)
   var $siz = getSize($fil)
   if $siz
   {output => d,basename($fil)
    if ${CUR.O_LAST}->write_tail($fil,$TAIL)
     var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
    end ${CUR.O_LAST}
   }
   write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][IIS Log Files]]'
 }
}

=head2 Application Server Log Files

Gathers application server log files.

=cut

debug ' Inside EPMA module, gathering Application Server log files'
pretoc '2:Application Server Log Files'
call sort_files(3,$TAIL,\
  grepDir(catDir($EPM_HOME,'deployments','WebSphere6','profile',\
                 'logs','EPMAWebServer'),'\.log$','p'),\
  grepDir(catDir($EPM_HOME,'deployments','WebSphere6','profile',\
                 'logs','EPMADataSynchronizer'),'\.log$','p'),\
  grepDir(catDir($EPM_HOME,'deployments','WebLogic9','servers',\
                 'EPMADataSynchronizer','logs'),'\.log$','p'),\
  grepDir(catDir($EPM_HOME,'deployments','WebLogic9','servers',\
                 'EPMAWebServer','logs'),'\.log$','p'),\
  grepDir(catDir($EPM_HOME,'deployment','Tomcat5','EPMAWebServer',\
                 'logs'),'\.log$','p'),\
  grepDir(catDir($EPM_HOME,'deployment','Tomcat5',\
                 'EPMADataSynchronizer','logs'),'\.log$','p'),\
  grepDir(catDir($EPM_HOME,'deployments','Oracle10g','EPMAWebServer',\
                 'applicationdeployments','EPMAWebServer'),\
          '^application\.log$','r'),\
  grepDir(catDir($EPM_HOME,'deployments','Oracle10g','dataSynchronizer',\
                 'applicationdeployments','EPMAdataSynchronizer'),\
          '^application\.log$','p'))
unpretoc

=head1 PRODUCT REPORTS

Collects the following reports on versions earlier than 11.1.2:

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain (on versions earlier than 11.1.2 having a product registry).

=cut

if !@ins = ${CUR.O_MODULE}->search('^OI')
{if ?${GRP.EPM.D_DOMAIN}
 {var $dom = basename(last)
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
  toc '%INCLUDE("OFM_WREQ_BI_EPMA_WH_TF.toc")%'
  toc '%POP2%'
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
  toc '%INCLUDE("OFM_WREQ_BI_EPMA_DOM_TF.toc")%'
  toc '%POP2%'
 }
}

=head1 DEPLOYMENT REPORTS

Available on version 11.1.2 and later.

=cut

else
{var $CNT = 0
 loop $itm (@ins)
 {var ($ins,$uid) = ($itm->get_first('D_HOME'),$itm->get_oid)
  call setSymbol('$EPM_INSTANCE',$ins)
  call setPrefix(concat($PRE,'i',incr($CNT)))
  toc '%SPLIT%'
  toc "1+:'",basename($ins),"' Deployment"

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Performance Management Architect
instance collection.

=cut

  debug ' Inside EPMA module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Performance Management Architect Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Start Scripts

Collects the start scripts from the F<$INSTANCE_HOME/bin> directory.

=cut

  debug ' Inside EPMA module, getting instance start scripts'
  pretoc '2:Start Scripts'
  call sort_files(3,0,\
    catFile($ins,'bin','deploymentScripts',\
            ${AS.BAT:'setCustomParamsEpmaDataSync'}),\
    catFile($ins,'bin','deploymentScripts',\
            ${AS.BAT:'setCustomParamsEpmaWebReports'}))
  unpretoc

=head2 Configuration Files

Collects the logging configuration files from the F<$INSTANCE_HOME/config>
directory.

=cut

  debug ' Inside EPMA module, getting the logging configuration files'
  pretoc '2:Configuration Files'
  call sort_files(3,0,\
    catFile($ins,'config','EPMA','DataSync','dme.properties'),\
    catFile($ins,'config','EPMA','DataSync','essbase.properties'),\
    catFile($ins,'config','EPMA','DimensionServer','logging.xml'),\
    catFile($ins,'config','EPMA','WebTier','AwbConfig.properties'))
  unpretoc

=for stopwords diaglogs

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from F<$INSTANCE_HOME/diagnostics/logs>
directory.

=cut

  debug ' Inside EPMA module, getting the diagnostic log files'
  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  var %pat = (\
    epma     => '\.log$',\
    services => '^HyS9EPMA.*-sys(err|out)\.log$',\
    starter  => '^(start|stop)-HyS9EPMA.*-out\.log$')
  prefix
  {write '---+!! Diagnostic Log Files'
   write '---## From: ',$log
   if $TAIL
    write '   * Last ',$TAIL,' lines from the log files captured'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $sub ('epma','services','starter')
  {loop $fil (grepDir(catDir($log,$sub),nvl($pat{$sub},'\.log$'),'pt'))
   {var $lnk = encode($fil)
    var $siz = getSize($fil)
    if $siz
    {output => d,concat('L_',basename($fil))
     if cond($TAIL,${CUR.O_LAST}->write_tail($fil,$TAIL),\
                   ${CUR.O_LAST}->write_data($fil))
      var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                        '][_blank][',$lnk,']]')
     end ${CUR.O_LAST}
    }
    write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
   }
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Diagnostic Log Files]]'

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_EPMA_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_EPMA_',$oid,'_TF.toc",1)%'
   toc '%POP2%'
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:',"'",$nam,"'",' Domain")%'
   toc '%INCLUDE("OFM_',$req->get_oid,'_TF.toc",1)%'
   toc '%POP2%'
  }

  # Restore module prefix
  call setPrefix($PRE)
 }
}

=head1 SEE ALSO

L<DB:DBinfo|collect::DB:DBinfo>,
L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:INVinfo|collect::RDA:INVinfo>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
