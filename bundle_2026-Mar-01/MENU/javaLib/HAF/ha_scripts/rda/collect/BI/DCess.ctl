# DCess.ctl:550:Collects Oracle Essbase Information
# $Id: DCess.ctl,v 1.17 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCess.ctl,v 1.17 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:DCess - Collects Oracle Essbase Information

=head1 DESCRIPTION

This module collects information for Oracle Essbase.

The following reports can be generated and are regrouped under C<Oracle
Essbase>:

=cut

use Type

echo tput('bold'),'Processing BI.ESS module ...',tput('off')

# Initialization
var $AGE      = ${R_AGE/T:15}
var $EPM_HOME = ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $TAIL     = ${DFT.N_TAIL:1000}

var $MOD = cond(isUnix(),'fx','fr')
var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Oracle Essbase'

call derivePassword('pseudo','host','essbase','ESSBASE_USER')
var $pwd = setPassword('pseudo','host','essbase',\
  askPassword('Enter password for Oracle Essbase:',''))

# Load the common macros
run RDA:library()

macro fmt_bit
{var ($val,$flg) = @arg

 var @bit = ('---','--x','-w-','-wx','r--','r-x','rw-','rwx',\
             '--S','--s','-wS','-ws','r-S','r-s','rwS','rws')
 if $flg
  incr $val,8
 return $bit[$val]
}

macro fmt_mode
{var ($mod) = @arg

 return concat(substr("?pc?d?b?-?l?s???",expr('&',expr('>>',$mod,12),15), 1),\
   fmt_bit(expr('&',expr('>>',$mod,6),7),expr('&',$mod,2048)),\
   fmt_bit(expr('&',expr('>>',$mod,3),7),expr('&',$mod,1024)),\
   fmt_bit(expr('&',$mod,7),             expr('&',$mod,512)))
}

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Oracle Essbase home collection.

=cut

debug ' Inside ESS module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Oracle Essbase Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 filetype - File Type Information

Collects the file type of executable files in several Oracle Essbase Information
program directories under F<EPM_HOME/products/Essbase> directory structure.

=cut

debug ' Inside ESS module, gathering file type information'
report filetype
title  '---+!! File Type Information'
title $TOC
if ?testDir('d',catDir($EPM_HOME,'products','Essbase','eas','server','bin'))
 call push(@dir,lastDir())
if ?testDir('d',catDir($EPM_HOME,'products','Essbase','eis','server','bin'))
 call push(@dir,lastDir())
if ?testDir('d',catDir($EPM_HOME,'products','Essbase','EssbaseServer','bin'))
 call push(@dir,lastDir())
if ?testDir('d',catDir($EPM_HOME,'products','Essbase','EssbaseServer-32','bin'))
 call push(@dir,lastDir())
if or(isWindows(),isCygwin())
 var ($pat,$opt) = ('\.(exe|dll)$','in')
else
 var ($pat,$opt) = ('^\.+$','inv')
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

=head1 PRODUCT REPORTS

Collects the following reports on version 11.1.2 and later:

=head2 Library Types

Collects library file types from the following directories
F<EPM_HOME/products/Essbase/EssbaseServer/bin> and
F<EPM_HOME/products/Essbase/EssbaseServer-32/bin>

=cut

if @ins = ${CUR.O_MODULE}->search('^OI')
{pretoc '2:Library Types'
 debug ' Inside ESS module, getting library types'
 var $cnt = 0
 loop $dir (catDir($EPM_HOME,'products','Essbase','EssbaseServer','bin'),\
            catDir($EPM_HOME,'products','Essbase','EssbaseServer-32','bin'))
 {if ?testDir('d',$dir)
  {report concat('libtyp',incr($cnt))
   if isUnix()
   {prefix
    {write '---+!! Shared Library Types'
     write '---## From ',$dir
     write '|*File*|*Type*|*Modified*|*Size*|*Mode*|'
    }
    var $pat = check(getOsName(),'aix','\.(a|so)$','\.(sl|so)$')
    loop $fil (grepDir($dir,$pat,'p'))
    {var @sta = getStat($fil)
     write '|',basename($fil),' |',file($fil,true),' |',\
           getLastModify($fil,'<UTC>'),' | ',\
           getSize($fil),'|',fmt_mode($sta[2]),' |'
    }
   }
   elsif or(isWindows(),isCygwin())
   {prefix
    {write '---+!! Executable and Library Version Information'
     write $TOC
    }
    loop $fil (grepDir($dir,'\.(dll|exe)$','ip'))
    {write '---+ Version Information from ',basename($fil)
     call statFile('p',$fil)
     write '%BR%'
     var $inf = getVersionInfo($fil)
     loop $key (keys($inf))
      write '|*',replace($key,'\012',' ',true),' *|',\
                 replace($inf->{$key},'\012','%BR%',true),' |'
     write $TOP
    }
   }
   if isCreated(true)
    toc '3:[[',getFile(),'][rda_report][',encode(addSymbol($dir)),']]'
  }
 }
 unpretoc

=head2 Client Library Types

Collects library file types from the following directories
F<EPM_HOME/products/Essbase/EssbaseClient/bin>
F<EPM_HOME/products/Essbase/EssbaseClient-32/bin>

=cut

 pretoc '2:Library Types'
 debug ' Inside ESS module, getting client library types'
 var $cnt = 0
 loop $dir (catDir($EPM_HOME,'products','Essbase','EssbaseClient','bin'),\
            catDir($EPM_HOME,'products','Essbase','EssbaseClient-32','bin'))
 {if ?testDir('d',$dir)
  {report concat('clnlibtyp',incr($cnt))
   var $dir = catDir($CLIENT_DIR,'bin')
   if isUnix()
   {prefix
    {write '---+!! Client Shared Library Types'
     write '---## From ',$dir
     write '|*File*|*Type*|*Modified*|*Size*|*Mode*|'
    }
    var $pat = check(getOsName(),'aix','\.(a|so)$','\.(sl|so)$')
    loop $fil (grepDir($dir,$pat,'p'))
     write '|',basename($fil),' |',file($fil,true),' |',\
           getLastModify($fil,'<UTC>'),' | ',\
           getSize($fil),'|',statFile($fil),' |'
   }
   elsif or(isWindows(),isCygwin())
   {prefix
    {write '---+!! Client Executable and Library Version Information'
     write $TOC
    }
    loop $fil (grepDir($dir,'\.(dll|exe)$','ip'))
    {write '---+ Version Information from ',basename($fil)
     call statFile('p',$fil)
     write '%BR%'
     var $inf = getVersionInfo($fil)
     loop $key (keys($inf))
      write '|*',replace($key,'\012',' ',true),' *|',\
                 replace($inf->{$key},'\012','%BR%',true),' |'
     write $TOP
    }
   }
   if isCreated(true)
    toc '3:[[',getFile(),'][rda_report][',encode(addSymbol($dir)),']]'
  }
 }
 unpretoc

=head2 diskspace - Disk Space

Collects free space on the Oracle Essbase database volume.

=cut

 debug ' Inside ESS module, getting diskspace'
 report diskspace
 prefix
  write '---+!! Disk Free on Hyperion Home Volume'
 if or(isUnix(),isCygwin())
 {if grepCommand(concat('df -k ',quote($EPM_HOME)),'\s\d+%\s','f')
  {var ($val) = match(last,'^.*\s(\d+)\s+\d+%\s')
   var $val = int(expr('/',$val,1024))
   write '|*Free Disk Space (in MiB)*| ',$val,'|'
  }
 }
 else
 {loop $lin (reverse(grepCommand(concat('cmd /C dir /-C ',quote($EPM_HOME)),\
                                 '^\s+\d+\s')))
  {if match($lin,'^\s+\d+\s.*\s(\d+)\s[^\d]+$')
   {var ($siz) = last
    var $siz = int(expr('/',$siz,1048576))
    write '|*Free Disk Space (in MiB)*| ',$siz,'|'
    break
   }
  }
 }
 if isCreated(true)
 {write $TOP
  toc '2:[[',getFile(),'][rda_report][Disk Space]]'
 }

=head2 Other Log Files

Collects other log files.

=cut

 pretoc '2:Other Log Files'
 debug ' Inside ESS module, getting other log files'
 var $opt = concat('irm',$AGE)
 call sort_files(3,$TAIL,grepDir(catDir($EPM_HOME,'logs'),'\.log$',$opt))
 unpretoc

=head1 DEPLOYMENT REPORTS

Available on version 11.1.2 and later.

=cut

 var $CNT = 0
 loop $itm (@ins)
 {var ($ins,$uid) = ($itm->get_first('D_HOME'),$itm->get_oid)
  pretoc '%SPLIT%'
  pretoc "1+:'",basename($ins),"' Deployment"
  var $ARBORPATH = $itm->get_first('D_ARBORPATH')
  var $HOST      = nvl($itm->get_first('T_HOST'),'LOCAL')
  var $USERID    = $itm->get_first('T_USER')
  var $APPNAME   = $itm->get_first('T_APPNAME')
  var $DBNAME    = $itm->get_first('T_DBNAME')
  call setSymbol('$EPM_INSTANCE',$ins)
  call setPrefix(concat($PRE,'i',incr($CNT)))

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Oracle Essbase instance
collection.

=cut

  debug ' Inside ESS module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Oracle Essbase Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 env - Environment Variables

Collects environment variables.

=cut

  debug ' Inside ESS module, getting environment variables'
  report env
  prefix
  {write '---+!! Essbase Environment Variables'
   write '|*Variable*|*Environment*|*',${AS.BAT:'setEssbaseEnv'},'*|'
  }
  var (@env,%env) = ()
  if isUnix()
   var $pat = '^\w+\='
  else
   var $pat = '^set\s+\w+\='
  loop $lin (grepFile(catFile($ARBORPATH,'bin',${AS.BAT:'setEssbaseEnv'}),\
                      $pat))
  {if isUnix()
    var $key = key($lin)
   else
    var $key = field('\s+',1,key($lin))
   if missing($env{$key})
    call push(@env,$key)
   var $env{$key} = value($lin)
  }
  loop $key ('ARBORPATH',\
             'EPM_ORACLE_HOME',\
             'ESSLANG',\
             'PATH',\
             'ESSBASE_PATH',\
             'DOMAIN_HOME',\
             @{CUR.W_SHLIB})
  {if missing($env{$key})
    var $env{$key} = undef
  }
  loop $key (keys(%env))
   write '|',$key,'|',\
     replace(getEnv($key),${RDA.T_SEPARATOR},'%BR%',true),' |',\
     replace($env{$key},${RDA.T_SEPARATOR},'%BR%',true),' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Environment Variables]]'

=head2 config - Configuration Parameters

Collects Oracle Essbase configuration parameters from
F<$ARBORPATH/bin/essbase.cfg> file.

=cut

  if ?testFile('r',catFile($ARBORPATH,'bin','essbase.cfg'))
  {debug ' Inside ESS module, getting configuration parameters'
   report config
   var ($fil,%tbl) = (lastFile())
   prefix
   {write '---+!! Configuration Parameters'
    write '---## Information Taken from ',$fil
    write '|*Parameter*|*Value*|'
   }
   loop $lin (grepFile($fil,'^[A-Za-z]+\s+\S'))
    var $tbl{lc($lin)} = replace($lin,'\s+',' |')
   loop $key (keys(%tbl))
    write '|',$tbl{$key},' |'
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Configuration Parameters]]'
  }

=head2 start - Start Script

Collects Oracle Essbase start script.

=cut

  debug ' Inside ESS module, getting start script'
  if ?$fil = testFile('r',catFile($ins,'bin',${AS.BAT:'startEssbase'}))
  {report start
   prefix
   {write '---+!! Start Script'
    write '---## Information Taken from ',$fil
   }
   call writeFile($fil)
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Start Script]]'
  }

=head2 version - Essbase Version

Collects Oracle Essbase full version.

=cut

  debug ' Inside ESS module, getting Essbase version'
  if ?testFile($MOD,catFile($ARBORPATH,'bin',${AS.BAT:'startEsscmd'}))
  {var ($ver) = grepCommand([lastCommand(),'exit 2>&1'],\
                            '\((ESB[.\d\w]+)\)','f1')
   if ?$ver
   {report version
    write '---+ Essbase Version'
    write '|*Essbase Full Version*|',$ver,'|'
    if isCreated(true)
     toc '2:[[',getFile(),'][rda_report][Essbase Version]]'
   }
  }

=for stopwords cron

=head2 dbinfo - Essbase Database Information

Collects Oracle Essbase database information. For C<batch>/C<cron> execution,
you can encode the password in the setup file using the pseudo user
C<ESSBASE_USER>.

=cut

  debug ' Inside ESS module, getting Essbase database information'
  var $ARBORBIN = catDir($ARBORPATH,'bin')
  if ?testFile($MOD,catFile($ARBORBIN,${AS.BAT:'startEsscmd'}))
  {var $out = getGroupFile('D_CWD',newTemp('out'))
   if isUnix()
   {var $job = createTemp('ESS','.bat',true)
    call writeTemp('ESS','cd "',$ARBORBIN,'"')
    call writeTemp('ESS',lastCommand(),' >',$out)
    call closeTemp('ESS')
    output | $job
    write 'LOGIN "',join('" "',$HOST,$USERID,$pwd),'";'
    if $APPNAME
    {write 'GETAPPINFO "',$APPNAME,'";'
     write 'GETAPPSTATE "',$APPNAME,'";'
    }
    else
    {write 'GETAPPINFO;'
     write 'GETAPPSTATE;'
    }
    if and($APPNAME,$DBNAME)
    {write 'GETDBINFO "',$APPNAME,'" "',$DBNAME,'";'
     write 'GETDBSTATE "',$APPNAME,'" "',$DBNAME,'";'
    }
    else
    {write 'GETDBINFO;'
     write 'GETDBSTATE;'
    }
    if and($APPNAME,$DBNAME)
    {write 'GETDBSTATS;'
     write $APPNAME
     write $DBNAME
    }
    write 'EXIT;'
    close
    report dbinfo
    prefix
     write '---+!! Essbase Database Information'
    call writeFile($out)
    call unlinkTemp('ESS')
    call unlinkTemp('out')
   }
   elsif or(isWindows(),isCygwin())
   {var $cmd = lastCommand()
    var $tmp = getGroupFile('D_CWD',createTemp('job','.SCR',true))
    call writeTemp('job','LOGIN "',join('" "',$HOST,$USERID,$pwd),'";')
    if $APPNAME
    {call writeTemp('job','GETAPPINFO "',$APPNAME,'";')
     call writeTemp('job','GETAPPSTATE "',$APPNAME,'";')
    }
    else
    {call writeTemp('job','GETAPPINFO;')
     call writeTemp('job','GETAPPSTATE;')
    }
    if and($APPNAME,$DBNAME)
    {call writeTemp('job','GETDBINFO "',$APPNAME,'" "',$DBNAME,'";')
     call writeTemp('job','GETDBSTATE "',$APPNAME,'" "',$DBNAME,'";')
    }
    else
    {call writeTemp('job','GETDBINFO;')
     call writeTemp('job','GETDBSTATE;')
    }
    if and($APPNAME,$DBNAME)
     call writeTemp('job','GETDBSTATS "',$APPNAME,'" "',$DBNAME,'";')
    call writeTemp('job','EXIT;')
    call closeTemp('job')
    report dbinfo
    prefix
     write '---+!! Essbase Database Information'
    call writeCommand(concat('(cd ',quote($ARBORBIN),' && ',$cmd,' ',\
                             quote($tmp),')'))
    call unlinkTemp('job')
   }
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Essbase Database Information]]'
  }

=head2 secfile - Security File

Exports the security file.

=cut

  debug ' Inside ESS module, getting Security File'
  if ?testFile($MOD,catFile($ARBORPATH,'bin',${AS.BAT:'startMaxl'}))
  {var $sec = getGroupFile('D_CWD',newTemp('sec'))
   if isUnix()
   {var $job = createTemp('ESS','.bat',true)
    call writeTemp('ESS','cd "',$ARBORBIN,'"')
    call writeTemp('ESS',lastCommand())
    call closeTemp('ESS')
    output | concat($job,' >/dev/null 2>&1')
    write 'LOGIN "',join('" "',$USERID,$pwd),'";'
    write 'Export security_file to data_file "',$sec,'";'
    write 'Exit;'
    report secfile
    prefix
     write '---+!! Essbase Security File'
    call writeFile($sec)
    call unlinkTemp('ESS')
   }
   elsif or(isWindows(),isCygwin())
   {var $cmd = lastCommand()
    var $tmp = getGroupFile('D_CWD',createTemp('job','.SCR',true))
    call writeTemp('job','LOGIN "',join('" "',$USERID,$pwd),'";')
    call writeTemp('job',"Export security_file to data_file '",$sec,"';")
    call writeTemp('job','Exit;')
    call closeTemp('job')
    report secfile
    prefix
     write '---+!! Essbase Security File'
    call loadCommand(concat('(cd ',quote($ARBORBIN),' && ',$cmd,' ',\
                            quote($tmp),' >/dev/null 2>&1)'))
    call writeFile($sec)
    call unlinkTemp('job')
   }
   call unlinkTemp('sec')
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Security File]]'
  }

=head2 otl_files - Essbase Outline Files

Collects the Essbase outline files from
F<$INSTANCE_HOME/diagnostics/EssbaseServer/essbaseserver1/app> directory.

=cut

  report otl_files
  var $app = catDir($ins,'EssbaseServer','essbaseserver1','app')
  prefix
  {write '---+!! Essbase Outline Files'
   write '---## From: ',$app
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $fil (grepDir($app,'\.otl$','dr',2))
  {var $lnk = encode($fil)
   var $siz = getSize($fil)
   if $siz
   {call $[OUT]->add_report('d',concat('O_',basename($fil,'.otl')),0,'.otl')
    if ${CUR.O_LAST}->write_data($fil)
     var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),'][_blank][',$lnk,']]')
    end ${CUR.O_LAST}
   }
   write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Essbase Outline Files]]'

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from
F<$INSTANCE_HOME/diagnostics/logs/essbase> directory.

=cut

  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  prefix
  {write '---+!! Diagnostic Log Files'
   write '---## From: ',$log
   write '   * Last ',$TAIL,' lines from the log files captured'
   write '   * Links point to files that have been collected in their original \
               format. Opening them directly in your browser can present \
               risks. To prevent them, access the file outside the browser or \
               use the link to save them and use an adequate viewer.'
   write '|*File Name*| *Size*|*Last Modified Date*|'
  }
  loop $sub ('essbase','EssbaseStudio')
  {loop $fil (grepDir(catDir($log,$sub),'\.(log|xcp)$','ird'))
   {var $lnk = encode($fil)
    var $siz = getSize($fil)
    if $siz
    {output => d,concat('L_',basename($fil))
     if ${CUR.O_LAST}->write_tail($fil,$TAIL)
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

Includes the Oracle WebLogic reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_ESS_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_ESS_',$oid,'_TF.toc",1)%'
   toc '%POP2%'
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:',"'",$nam,"'",' Domain")%'
   toc '%INCLUDE("OFM_',$req->get_oid,'_TF.toc",1)%'
   toc '%POP2%'
  }
  unpretoc 2

  # Restore module prefix
  call setPrefix($PRE)
 }
}

=head1 PRODUCT REPORTS

Collects the following reports on versions earlier than 11.1.2

=cut

else
{var $ARBORPATH = ${D_ARBORPATH:${ENV.ARBORPATH:''}}
 var $HOST      = ${T_HOST:'LOCAL'}
 var $USERID    = ${T_USER}
 var $APPNAME   = ${T_APPNAME}
 var $DBNAME    = ${T_DBNAME}

 # Adjust directories
 if $EPM_HOME
  var $EPM_HOME = catDir($EPM_HOME)
 if $ARBORPATH
  var $ARBORPATH = catDir($ARBORPATH)

 if ?testDir('d',catDir($ARBORPATH,upDir(),'EssbaseServer'))
 {var $SERVER_DIR = lastDir()
  if ?testDir('d',catDir($ARBORPATH,upDir(),'EssbaseClient'))
   var $CLIENT_DIR = lastDir()
 }
 elsif ?testDir('d',catDir($ARBORPATH,upDir(),'EssbaseClient'))
  var $CLIENT_DIR = lastDir()
 else
  var $SERVER_DIR = $ARBORPATH

=head2 env - Environment Variables

Collects environment variables.

=cut

 debug ' Inside ESS module, getting environment variables'
 report env
 prefix
 {write '---+!! Essbase Environment Variables'
  write '|*Variable*|*Environment*|*hyperionenv.doc*|'
 }
 var (@env,%env) = ()
 loop $lin (grepFile(catFile($ARBORPATH,'hyperionenv.doc'),'^\w+\='))
 {var $key = key($lin)
  if missing($env{$key})
   call push(@env,$key)
  var $env{$key} = value($lin)
 }
 loop $key ('ARBORPATH',\
            'HYPERION_HOME',\
            'ESSLANG',\
            'PATH',\
            @{CUR.W_SHLIB})
 {if missing($env{$key})
   var $env{$key} = undef
 }
 loop $key (keys(%env))
  write '|',$key,'|',replace(getEnv($key),${RDA.T_SEPARATOR},'%BR%',true),' |',\
                     replace($env{$key},${RDA.T_SEPARATOR},'%BR%',true),' |'
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Environment Variables]]'

=head2 config - Configuration Parameters

Collects Oracle Essbase configuration parameters from
F<$ARBORPATH/bin/essbase.cfg> file or F<EssbaseServer/bin/essbase.cfg> file.

=cut

 if ?testDir('d',$ARBORPATH)
 {if ?testFile('r',catFile($SERVER_DIR,'bin','essbase.cfg'))
  {debug ' Inside ESS module, getting configuration parameters'
   report config
   var ($fil,%tbl) = (lastFile())
   prefix
   {write '---+!! Configuration Parameters'
    write '---## Information Taken from ',$fil
    write '|*Parameter*|*Value*|'
   }
   loop $lin (grepFile($fil,'^[A-Za-z]+\s+\S'))
    var $tbl{lc($lin)} = replace($lin,'\s+',' |')
   loop $key (keys(%tbl))
    write '|',$tbl{$key},' |'
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Configuration Parameters]]'
  }

=head2 start - Start Script

Collects Oracle Essbase start script.

=cut

  debug ' Inside ESS module, getting start script'
  if ?$fil = testFile('r',catFile($SERVER_DIR,'bin',${AS.BAT:'startEssbase'}))
  {report start
   prefix
   {write '---+!! Start Script'
    write '---## Information Taken from ',$fil
   }
   call writeFile($fil)
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Start Script]]'
  }

=head2 libtyp - Library Types

Collects library file types from the F<ARBORPATH/bin> or F<EssbaseServer/bin>
directory.

=cut

  if $SERVER_DIR
  {debug ' Inside ESS module, getting library types'
   report libtyp
   var $dir = catDir($SERVER_DIR,'bin')
   if isUnix()
   {prefix
    {write '---+!! Shared Library Types'
     write '---## From ',$dir
     write '|*File*|*Type*|*Modified*|*Size*|*Mode*|'
    }
    var $pat = check(getOsName(),'aix','\.(a|so)$','\.(sl|so)$')
    loop $fil (grepDir($dir,$pat,'p'))
    {var @sta = getStat($fil)
     write '|',basename($fil),' |',file($fil,true),' |',\
           getLastModify($fil,'<UTC>'),' | ',\
           getSize($fil),'|',fmt_mode($sta[2]),' |'
    }
   }
   elsif or(isWindows(),isCygwin())
   {prefix
    {write '---+!! Executable and Library Version Information'
     write $TOC
    }
    loop $fil (grepDir($dir,'\.(dll|exe)$','ip'))
    {write '---+ Version Information from ',basename($fil)
     call statFile('p',$fil)
     write '%BR%'
     var $inf = getVersionInfo($fil)
     loop $key (keys($inf))
      write '|*',replace($key,'\012',' ',true),' *|',\
                 replace($inf->{$key},'\012','%BR%',true),' |'
     write $TOP
    }
   }
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Library Types]]'
  }

=head2 clnlibtyp - Client Library Types

Collects library file types from the F<EssbaseClient/bin> directory.

=cut

  if $CLIENT_DIR
  {debug ' Inside ESS module, getting library types'
   report clnlibtyp
   var $dir = catDir($CLIENT_DIR,'bin')
   if isUnix()
   {prefix
    {write '---+!! Client Shared Library Types'
     write '---## From ',$dir
     write '|*File*|*Type*|*Modified*|*Size*|*Mode*|'
    }
    var $pat = check(getOsName(),'aix','\.(a|so)$','\.(sl|so)$')
    loop $fil (grepDir($dir,$pat,'p'))
     write '|',basename($fil),' |',file($fil,true),' |',\
           getLastModify($fil,'<UTC>'),' | ',\
           getSize($fil),'|',statFile($fil),' |'
   }
   elsif or(isWindows(),isCygwin())
   {prefix
    {write '---+!! Client Executable and Library Version Information'
     write $TOC
    }
    loop $fil (grepDir($dir,'\.(dll|exe)$','ip'))
    {write '---+ Version Information from ',basename($fil)
     call statFile('p',$fil)
     write '%BR%'
     var $inf = getVersionInfo($fil)
     loop $key (keys($inf))
      write '|*',replace($key,'\012',' ',true),' *|',\
                 replace($inf->{$key},'\012','%BR%',true),' |'
     write $TOP
    }
   }
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Client Library Types]]'
  }

  # Set the enviroment variables for getting the database information
  var ($slk,%old) = (${CUR.W_SHLIB})
  loop $key (@env)
  {next compare('eq',$key,'ESSLANG')
   if ?$env{$key}
    var $old{$key} = setLocalEnv($key,replaceEnv($env{$key}))
  }
  if and($slk,missing($old{$slk}))
   var $old{$slk} = setLocalEnv($slk,\
     join(${RDA.T_SEPARATOR},catDir($SERVER_DIR,'bin'),getLocalEnv($slk)))
  if missing($old{'ARBORPATH'})
   var $old{'ARBORPATH'} = setLocalEnv('ARBORPATH',$SERVER_DIR)
  if missing($old{'ESSBASEPATH'})
   var $old{'ESSBASEPATH'} = setLocalEnv('ESSBASEPATH',$SERVER_DIR)
  var $old{'ESSLANG'} = \
    setLocalEnv('ESSLANG','English_UnitedStates.UTF-8@Binary')

=head2 dbinfo - Essbase Database Information

Collects Oracle Essbase database information. For C<batch>/C<cron> execution,
you can encode the password in the setup file using the pseudo user
C<ESSBASE_USER>.

=cut

  debug ' Inside ESS module, getting Essbase database information'
  if ?testFile($MOD,catFile($SERVER_DIR,'bin',${AS.EXE:'ESSCMD'}))
  {if isUnix()
   {var $out = newTemp('out')
    output | concat(lastCommand(),' >',$out)
    write 'LOGIN "',join('" "',$HOST,$USERID,$pwd),'";'
    if $APPNAME
    {write 'GETAPPINFO "',$APPNAME,'";'
     write 'GETAPPSTATE "',$APPNAME,'";'
    }
    else
    {write 'GETAPPINFO;'
     write 'GETAPPSTATE;'
    }
    if and($APPNAME,$DBNAME)
    {write 'GETDBINFO "',$APPNAME,'" "',$DBNAME,'";'
     write 'GETDBSTATE "',$APPNAME,'" "',$DBNAME,'";'
    }
    else
    {write 'GETDBINFO;'
     write 'GETDBSTATE;'
    }
    if and($APPNAME,$DBNAME)
    {write 'GETDBSTATS;'
     write $APPNAME
     write $DBNAME
    }
    write 'EXIT;'
    close
    report dbinfo
    prefix
    {write '---+!! Essbase Database Information'
     write '   * Environment variables have been set as following for getting \
                 the database information'
     loop $key (keys(%old))
      write '      * ',$key,' set to ',getLocalEnv($key)
    }
    call writeFile($out)
    call unlinkTemp('out')
   }
   elsif or(isWindows(),isCygwin())
   {var $cmd = lastCommand()
    var $tmp = createTemp('job','.SCR',true)
    call writeTemp('job','LOGIN "',join('" "',$HOST,$USERID,$pwd),'";')
    if $APPNAME
    {call writeTemp('job','GETAPPINFO "',$APPNAME,'";')
     call writeTemp('job','GETAPPSTATE "',$APPNAME,'";')
    }
    else
    {call writeTemp('job','GETAPPINFO;')
     call writeTemp('job','GETAPPSTATE;')
    }
    if and($APPNAME,$DBNAME)
    {call writeTemp('job','GETDBINFO "',$APPNAME,'" "',$DBNAME,'";')
     call writeTemp('job','GETDBSTATE "',$APPNAME,'" "',$DBNAME,'";')
    }
    else
    {call writeTemp('job','GETDBINFO;')
     call writeTemp('job','GETDBSTATE;')
    }
    if and($APPNAME,$DBNAME)
     call writeTemp('job','GETDBSTATS "',$APPNAME,'" "',$DBNAME,'";')
    call writeTemp('job','EXIT;')
    call closeTemp('job')
    report dbinfo
    prefix
    {write '---+!! Essbase Database Information'
     write '   * Environment variables have been set as following for getting \
                 the database information'
     loop $key (keys(%old))
      write '      * ',$key,' set to ',getLocalEnv($key)
    }
    call writeCommand(concat($cmd,' ',$tmp))
    call unlinkTemp('job')
   }
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Essbase Database Information]]'
  }

=head2 secfile - Security File

Exports the security file.

=cut

  debug ' Inside ESS module, getting Security File'
  if ?testFile($MOD,catFile($SERVER_DIR,'bin',${AS.EXE:'essmsh'}))
  {var $sec = getGroupFile('D_CWD',newTemp('sec'))
   if isUnix()
   {output | lastCommand()
    write 'LOGIN "',join('" "',$USERID,$pwd),'";'
    write 'Export security_file to data_file "',$sec,'";'
    write 'Exit;'
    report secfile
    prefix
    {write '---+!! Essbase Security File'
     write '   * Environment variables have been set as following for getting \
                 the security file'
     loop $key (keys(%old))
      write '      * ',$key,' set to ',getLocalEnv($key)
    }
    call writeFile($sec)
   }
   elsif or(isWindows(),isCygwin())
   {var $cmd = lastCommand()
    var $tmp = createTemp('job','.SCR',true)
    call writeTemp('job','LOGIN "',join('" "',$USERID,$pwd),'";')
    call writeTemp('job',"Export security_file to data_file '",$sec,"';")
    call writeTemp('job','Exit;')
    call closeTemp('job')
    report secfile
    prefix
    {write '---+!! Essbase Security File'
     write '   * Environment variables have been set as following for getting \
                 the security file'
     loop $key (keys(%old))
      write '      * ',$key,' set to ',getLocalEnv($key)
    }
    call loadCommand(concat($cmd,' ',$tmp))
    call writeFile($sec)
    call unlinkTemp('job')
   }
   call unlinkTemp('sec')
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Security File]]'
  }

  # Restore the initial environment
  loop $key (keys(%old))
   call setLocalEnv($key,$old{$key})
 }

=head2 diskspace - Disk Space

Collects free space on the Oracle Essbase database volume.

=cut

  debug ' Inside ESS module, getting diskspace'
  report diskspace
  prefix
   write '---+!! Disk Free on Hyperion Home Volume'
  if or(isUnix(),isCygwin())
  {if grepCommand(concat('df -k ',quote($EPM_HOME)),'\s\d+%\s','f')
   {var ($val) = match(last,'^.*\s(\d+)\s+\d+%\s')
    var $val = int(expr('/',$val,1024))
    write '|*Free Disk Space (in MiB)*| ',$val,'|'
   }
  }
  else
  {loop $lin (reverse(grepCommand(concat('cmd /C dir /-C ',quote($EPM_HOME)),\
                                  '^\s+\d+\s')))
   {if match($lin,'^\s+\d+\s.*\s(\d+)\s[^\d]+$')
    {var ($siz) = last
     var $siz = int(expr('/',$siz,1048576))
     write '|*Free Disk Space (in MiB)*| ',$siz,'|'
     break
    }
   }
  }
  if isCreated(true)
  {write $TOP
   toc '2:[[',getFile(),'][rda_report][Disk Space]]'
  }

=head2 applog - Application Log

Collects F<$EPM_HOME/AnalyticServices/app/appname/appname.log> file.

=cut

 if $APPNAME
 {debug ' Inside ESS module, gathering application log file'
  report applog
  call tail_file(catDir($EPM_HOME,'AnalyticServices','app',$APPNAME),\
                        concat($APPNAME,'.log'),$TAIL)
  if isCreated()
   toc '2:[[',getFile(),'][rda_report][Application Log]]'
 }

=head2 Other Log Files

Collects other log files.

=cut

 pretoc '2:Other Log Files'
 debug ' Inside ESS module, getting other log files'
 var $opt = concat('irm',$AGE)
 call sort_files(3,$TAIL,grepDir(catDir($EPM_HOME,'logs'),'\.log$',$opt),\
                         grepDir(catDir($ARBORPATH),'Essbase.log$',$opt))
 unpretoc

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain (on versions having a product registry).

=cut

 if ?${GRP.EPM.D_DOMAIN}
 {var $dom = basename(last)
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
  toc '%INCLUDE("OFM_WREQ_BI_ESS_WH_TF.toc")%'
  toc '%POP2%'
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
  toc '%INCLUDE("OFM_WREQ_BI_ESS_DOM_TF.toc")%'
  toc '%POP2%'
 }
 unpretoc
}

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
