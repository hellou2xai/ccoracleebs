# DCepm.ctl:545:Collects Enterprise Performance Management System Information
# $Id: DCepm.ctl,v 1.30 2016/08/17 12:48:18 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCepm.ctl,v 1.30 2016/08/17 12:48:18 RDA Exp $
#
# Change History
# 20160729  PCW  Execute ziplogs utility and collect output

=head1 NAME

BI:DCepm - Collects Enterprise Performance Management Information System

=head1 DESCRIPTION

This module collects common information for Oracle enterprise performance
management applications.

The following reports can be generated and are regrouped under C<Enterprise
Performance Management (Hyperion)>:

=cut

use Type

echo tput('bold'),'Processing BI.EPM module ...',tput('off')

# Initialization
var $AGE      = ${R_LOG_AGE/T:15}
var $EPM_HOME = ${D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $TAIL     = ${DFT.N_TAIL:1000}

var @req = ${CUR.O_SETUP}->search('^IREQ_BI_EPM_OI')
var $MOD = cond(isWindows(),'f',\
                isCygwin(), 'f',\
                            'fx')
var $PRE = setPrefix()
var $REG = ${AS.BAT:'epmsys_registry'}
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

if @req
{pretoc '0:   * Enterprise Performance Management (Hyperion)'
 pretoc '1+:Product Home'
}
else
 pretoc '1:Enterprise Performance Management (Hyperion)'

# Load the common macros
run BI:EPMlib()
run RDA:INVinfo()
run RDA:library()

# Limit password file request
var $EPM_VERSION = get_epm_version($EPM_HOME)
if and(compare('SAME',$EPM_VERSION,'11.1.2.2'),\
       compare('OLDER',$EPM_VERSION,'11.1.2.2.300'))
{var $epm = createTemp('EPMPWD','.tmp',false)
 call derivePassword('host','BI:EPM','epmsys_registry','EPM_REGISTRY')
 call writeTempPassword('EPMPWD',"%s\012",'host','BI:EPM','epmsys_registry',\
   'Enter Shared Services database password:','')
 call closeTemp('EPMPWD')
}

=head1 PRODUCT HOME REPORTS

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Enterprise Performance
Management home collection.

=cut

debug ' Inside EPM module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Enterprise Performance Management Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 product_info - Product Information

Gathers the product information when the product home has an F<inventory>
directory.

=cut

if ?testDir('d',catDir($EPM_HOME,'inventory'))
{debug ' Inside EPM module, processing Product Information (can take time)'
 report product_info
 write '---+!! EPM Oracle Home Product Information'
 write '---## From ',encode($EPM_HOME),' '
 write $TOC

 call inventory_details(lastDir(),true)
 toc '2:[[',getFile(),'][rda_report][Product Information]]'
}

=head2 registry - Windows Registry Information

Collects Windows registry information.

=cut

if or(isWindows(),isCygwin())
{debug ' Inside EPM module, gathering Windows registry information'
 report registry
 title '---+!! Windows Registry Information'
 title $TOC
 title '---+ Enterprise Performance Management Product Information'
 var %key = ()
 if hasRegOption()
 {if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions\FoundationServices0\\
                      HyS9FoundationServices')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions\FoundationServices0\\
                      HyS9FoundationServices')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions\RaFramework0\\
                      HyS9RaFramework')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions\RaFramework0\\
                      HyS9RaFramework')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions\RaFrameworkAgent\\
                      HyS9RaFrameworkAgent')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions\RaFrameworkAgent\\
                      HyS9RaFrameworkAgent')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\Hyperion Java Service')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Java Service')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\Hyperion Java Services\Hyperion Solutions')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\Hyperion Java Services\Hyperion Solutions')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\ODBC\ODBC.INI')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\ODBC\ODBC.INI')
   write $TOP
  if writeRegistry64('HKLM\SOFTWARE\ODBC\ODBCINST.INI')
   write $TOP
  if writeRegistry32('HKLM\SOFTWARE\ODBC\ODBCINST.INI')
   write $TOP
  loop $key (grepReg64Value('HKLM\SOFTWARE\ORACLE','ORACLE_HOME_NAME'),\
             grepReg32Value('HKLM\SOFTWARE\ORACLE','ORACLE_HOME_NAME'))
   var $key{field('\\',-1,$key)} = $key
  loop $key (keys(%key))
  {if writeRegistry64(concat('HKLM\SOFTWARE\ORACLE\',$key))
    write $TOP
   if writeRegistry32(concat('HKLM\SOFTWARE\ORACLE\',$key))
    write $TOP
  }
 }
 else
 {if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions\FoundationServices0\\
                    HyS9FoundationServices')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\\
                    FoundationServices0\HyS9FoundationServices')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions\RaFramework0\\
                    HyS9RaFramework')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\RaFramework0\\
                    HyS9RaFramework')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions\RaFrameworkAgent\\
                    HyS9RaFrameworkAgent')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions\\
                    RaFrameworkAgent\HyS9RaFrameworkAgent')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Hyperion Java Service')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Java Service')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Hyperion Java Services\Hyperion Solutions')
   write $TOP
  if writeRegistry(\
    'HKLM\SOFTWARE\Wow6432Node\Hyperion Java Services\Hyperion Solutions')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\ODBC\ODBC.INI')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\ODBC\ODBC.INI')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\ODBC\ODBCINST.INI')
   write $TOP
  if writeRegistry('HKLM\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI')
   write $TOP
  loop $key (\
    grepRegValue('HKLM\SOFTWARE\ORACLE','ORACLE_HOME_NAME'),\
    grepRegValue('HKLM\SOFTWARE\Wow6432Node\ORACLE','ORACLE_HOME_NAME'))
   var $key{field('\\',-1,$key)} = $key
  loop $key (keys(%key))
  {if writeRegistry(concat('HKLM\SOFTWARE\ORACLE\',$key))
    write $TOP
   if writeRegistry(concat('HKLM\SOFTWARE\Wow6432Node\ORACLE\',$key))
    write $TOP
  }
 }
 if writeRegistry(\
   'HKLM\SYSTEM\CurrentControlSet\Services\HyS9FoundationServices')
  write $TOP
 if writeRegistry('HKLM\SYSTEM\CurrentControlSet\Services\HyS9RaFramework')
  write $TOP
 if writeRegistry('HKLM\SYSTEM\CurrentControlSet\Services\HyS9RaFrameworkAgent')
  write $TOP
 if writeRegistry('HKLM\SOFTWARE\Brio Software')
  write $TOP
 var %key = ()
 loop $key (grepRegValue('HKLM\SYSTEM\CurrentControlSet\Services','ImagePath'))
 {var $sub = field('\\',-1,$key)
  next !match($sub,'^Oracle')
  var $key{$sub} = $key
 }
 loop $key (keys(%key))
 {if writeRegistry(concat('HKLM\SYSTEM\CurrentControlSet\Services\',$key))
   write $TOP
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Windows Registry Information]]'

=for stopwords eventx

=head2 eventx - EPM Events

Extracts Enterprise Performance Management System events from the application
event log using the F<wevtutil> command (only available for Windows Vista,
Windows Server 2008, and Windows 7).

=cut

 debug ' Inside EPM module, gathering event log information'
 var $osv = cond(hasRegOption(),\
   nvl(getReg64Value('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',\
                     'CurrentVersion'),\
       getReg32Value('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',\
                     'CurrentVersion')),\
   nvl(getRegValue('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',\
                   'CurrentVersion'),\
       getRegValue('HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows NT\\
                    CurrentVersion','CurrentVersion')))
 if compare('valid',$osv,'6')
 {if ?findCommand('wevtutil')
  {var $evt = last
   var $msc = expr('*',$AGE,86400000)
   var $tmp = getTemp('dat')
   call command(concat($evt,' qe Application ',\
         '"/q:*[System[TimeCreated[timediff(@SystemTime) <= ',$msc,\
         ']]]" /f:xml >',$tmp))
   code write_data
   {loop $lin (parseBuffer())
     write replace(replace($lin,'&lt;','<',true),'&gt;','>',true)
   }
   report eventx
    write '---+!! Enterprise Performance Management System Events'
   prefix
    call beginBlock(true)
   if createBuffer('EVT','R',$tmp)
   {call parseReset()
    call parseBegin('TOP','^<Event.*<System>\
       <Provider Name=.*?(ASP\.NET\s\d+\.\d+\.\d{5}\.\d+|\
                          HyperionService|\
                          HyS9FoundationServices|\
                          HyS9RaFramework|\
                          HyS9RaFrameworkAgent).*/>','Event')
    call parseEnd('Event','.*</Event>$')
    call parseInfo('Event','buf',-1)
    call parseInfo('Event','end',&write_data)
    call parseInfo('Event','llp',false)
    call parse('EVT')
    call deleteBuffer('EVT')
   }
   if hasOutput(true)
    call endBlock(['C','wevtutil qe Application | grep -i \
      ASP.NET|\
      HyperionService|\
      HyS9FoundationServices|\
      HyS9RaFramework|\
      HyS9RaFrameworkAgent'])
   else
    write '**No Enterprise Performance Management System events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][EPM Events]]'
   call unlinkTemp('dat')
  }
 }

=head2 events - EPM Events

Extracts Enterprise Performance Management System events from the application
event log (only available for Windows NT, Windows 2000, Windows XP, and
Windows 2003).

=cut

 else
 {# Get the event file
  var $fil = replaceEnv(\
    getRegValue('HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application',\
                'File'))

  # If the file is not readable try to copy to a temporary file
  var $flg = false
  if ?testFile('r',$fil)
   var $evt = $fil
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

  # Extract the Enterprise Performance Management System events
  if ?testFile('r',$evt)
  {report events
   write '---+ Application Events'
   if !writeEvents($evt,'(ASP\.NET\s\d+\.\d+\.\d{5}\.\d+|\
                          HyperionService|\
                          HyS9FoundationServices|\
                          HyS9RaFramework|\
                          HyS9RaFrameworkAgent)',$AGE)
    write '**No Enterprise Performance Management System events found.**%BR%'
   toc '2:[[',getFile(),'][rda_report][EPM Events]]'
  }
  if $flg
   call unlinkTemp('evt')
 }
}

=head2 Configuration Files

Gets configuration files.

=cut

debug ' Inside EPM module, gathering configuration files'
pretoc '2:Configuration Files'
call sort_files(3,0,\
  catFile($EPM_HOME,'common','config','11.1.2.0','configTool-logging.xml'),\
  catFile($EPM_HOME,'common','ODBC-64','Merant','7.0','odbc.ini'),\
  catFile($EPM_HOME,'common','raframeworkrt','11.1.2.0','lib',\
          'default-domain.cfg'),\
  catFile($EPM_HOME,'common','validation','11.1.2.0',\
          'validationTool-logging.xml'),\
  catFile($EPM_HOME,'uninstall','uninstall-logging.xml'),\
  catFile($EPM_HOME,'oraInst.loc'),\
  catFile($EPM_HOME,'.oracle.products'),\
  catFile(cond(${RDA.B_CYGWIN}, ${ENV.USERPROFILE},\
               ${RDA.B_WINDOWS},${ENV.USERPROFILE},\
                                ${ENV.HOME}),'.oracle.instances'))
unpretoc

=head2 filetype - File Type Information

Collects the file type of executable files in F<$MW_HOME/jdk*/bin> and in
several Enterprise Performance Management program directories inside the
F<$EPM_ORACLE_HOME/EPMSystem11R1*> directory structure.

=cut

debug ' Inside EPM module, gathering file type information'

report filetype
title  '---+!! File Type Information'
title $TOC
var ($top,@dir) = (cleanPath([$EPM_HOME,upDir(),''],true))
loop $dir (findDir($top,'^jdk\d+','pd'))
{if ?testDir('d',catDir($dir,'bin'))
  call push(@dir,lastDir())
}
if ?testDir('d',catDir($EPM_HOME,'bin'))
 call push(@dir,lastDir())
if or(isWindows(),isCygwin())
{var ($pat,$opt) = ('\.(exe|dll)$','in')
 if ?testDir('d',catDir($EPM_HOME,'bin-32'))
  call push(@dir,lastDir())
}
else
{var ($pat,$opt) = ('^\.+$','nv')
 if ?testDir('d',catDir($EPM_HOME,'lib'))
  call push(@dir,lastDir())
}
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
the F<$EPM_ORACLE_HOME/common> or F<$HYPERION_HOME/common> directory
structure.

When F<unzip> is available, it extracts the manifest from Java archives.

=cut

debug ' Inside EPM module, gathering file versions'
pretoc '2:Executable, Library, and Java Archive Versions'

macro dsp_versions
{var ($rpt,$lvl,$dir,$opt,$dpt) = @arg
 import $EPM_HOME,$TOC,$TOP,$UNZIP
 keep $EPM_HOME,$TOC,$TOP,$UNZIP

 call $[OUT]->add_report('C',$rpt,0)
 prefix
 {write '---+!! Version Information from ',encode($dir),' Directory'
  write $TOC
 }
 loop $fil (grepDir(catDir($EPM_HOME,$dir),\
                '\.(a|dll|exe|jar|asp|ass|css|cs|js|so|xml|xslt)$',$opt,$dpt))
 {write '---+ Version Information from ',encode(basename($fil))
  call statFile('p',$fil)
  write '%BR%'
  if or(isWindows(),isCygwin())
  {var $inf = getVersionInfo($fil)
   loop $key (keys($inf))
    write '|*',$key,' *|',replace($inf->{$key},'\012','%BR%',true),' |'
  }
  write $TOP
  if and(match($fil,'\.jar$',true),$UNZIP)
  {prefix
    write '---++ Manifest Information'
   var $cmd = concat($UNZIP,' -p ',quote($fil),' META-INF/MANIFEST.MF')
   call writeCommand($cmd)
   if hasOutput(true)
    write $TOP
  }
 }
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][In ',encode($dir),']]'
}

var $UNZIP = findCommand('unzip')

pretoc '3:$EPM_HOME/common'
var $cnt = 0
call dsp_versions('ver_com',4,'common','dip')
loop $sub (grepDir(catDir($EPM_HOME,'common'),'^\.+$','nv'))
{if ?testDir('d',catDir($EPM_HOME,'common',$sub))
  call dsp_versions(concat('ver_com',incr($cnt)),4,\
                    catDir('common',$sub),'dir')
}
unpretoc 2

=head2 epmsys_registry - EPM Registry

Exports the enterprise performance management system registry using
F<$HYPERION_HOME/common/config/9.5.0.0/epmsys_registry.sh> or
F<$HYPERION_HOME/common/config/9.5.0.0/epmsys_registry.bat> (on versions
earlier than 11.1.2).

=cut

macro write_epm_reg
{var ($fil) = @arg
 import $TOC,$TOP
 keep $TOC,$TOP

 var $top = htmlLoadFile($fil,\
   htmlFilter(htmlDisable(htmlParser(),'DR'),'A','B','DIV','TD','TH'))

 report epmsys_registry
 title '---+!! EPM Registry'
 title $TOC

 var $flg = false
 loop $blk (htmlContent($top,'T'))
 {var $tag = htmlName($blk)
  if compare('eq',$tag,'div')
  {var ($itm,@tbl,@val) = htmlContent($blk)
   var $tag = htmlName($itm)
   if compare('eq',$tag,'a')
   {var ($ttl,$typ) = htmlContent($itm)
    if isCreated()
     write $TOP
    write '#EPM',replace(htmlValue($itm,'name'),'\W','_',true)
    write '---+ ',encode(trim(htmlText($ttl))),' ',\
                  encode(trim(htmlText($typ),"\240"))
   }
   elsif compare('eq',$tag,'b')
   {var $key = trim(htmlText($itm))
    loop $itm (@tbl)
    {if match(htmlValue($itm,'href'),'^\#(.*)')
      call push(@val,concat('[[#EPM',replace(last,'\W','_',true),'][',\
        encode(trim(htmlText($itm))),']]'))
     elsif and(length($val = trim(htmlText($itm),"\240")),\
               compare('ne',$val,'None'))
      call push(@val,replace(encode($val),"&#xA0;","%BR%",true))
    }
    if @val
    {if delete($flg)
      write '| ||'
     write '|*',encode($key),'* |',join('%BR%',@val),' |'
    }
   }
  }
  elsif compare('eq',$tag,'table')
  {var ($hdr,%tbl) = ('|*Name* |*Value* |')
   loop $rec (htmlContent($blk,'T'))
   {var ($key,$val) = htmlContent($rec,'T')
    var $key = trim(htmlText($key))
    var $val = trim(htmlText($val))
    if compare('eq',htmlValue($rec,'class'),'header')
     var $hdr = concat('|*',$key,'* |*',encode($val),'* |')
    else
     var $tbl{$key} = check($key,\
       'Password',cond(length($val),'%R:PASSWORD%',''),\
       'Template',replace(encode(replace($val,';',";\012",true)),\
                          '\012','%BR%',true),\
                  encode($val))
   }
   prefix
    write $hdr
   loop $key (keys(%tbl))
    write '|',encode($key),' |',$tbl{$key},' |'
   var $flg = hasOutput(true)
  }
 }
 if isCreated(true)
 {write $TOP
  toc '2:[[',getFile(),'][rda_report][EPM Registry]]'
 }
}

if !@req
{if ?testFile($MOD,catFile(catDir($EPM_HOME,'common','config','9.5.0.0'),$REG))
 {var $dir = lastDir()
  var $cmd = lastCommand()

  debug ' Inside EPM module, getting the EPM registry'
  if ?testFile($MOD,catFile($dir,${AS.BAT:'setEnv'}))
   call sourceContext(getNativePath(lastFile()))
  if grepCommand(concat($cmd,' view SYSTEM9'),'FOUNDATION_SERVICES_PRODUCT','f')
  {if grepCommand($cmd,'^File location .*','f')
   {var ($loc) = match(last,'^File location (.*)')
    if ?testFile('fr',catFile($loc,'registry.html'))
     call write_epm_reg(lastFile())
   }
   elsif ?testFile('fr',catFile($dir,'registry.html'))
    call write_epm_reg(lastFile())
  }
 }
}

=head1 DEPLOYMENT REPORTS

Available on version 11.1.2 and later.

=cut

else
{var $CNT = 0
 loop $req (@req)
 {var $ins = \
    $req->get_first('I_ORACLE_INSTANCE')->get_first('D_ORACLE_INSTANCE')
  var $bas = basename($ins)
  call setSymbol('$EPM_INSTANCE',$ins)
  call setPrefix(concat($PRE,'i',incr($CNT)))
  toc '%SPLIT%'
  toc "1+:'",$bas,"' Deployment"

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Enterprise Performance
Management instance collection.

=cut

  debug ' Inside EPM module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Enterprise Performance Management Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 EPM Registry

Exports the enterprise performance management system registry using
F<$INSTANCE_HOME/bin/epmsys_registry.sh> or
F<$INSTANCE_HOME/bin/epmsys_registry.bat>.

=cut

  if ?testFile($MOD,catFile(catDir($ins,'bin'),$REG))
  {var ($cmd,$tmp) = (lastCommand(),'EPMSYS_REG')
   if ?create_epm_script($tmp,lastFile(),$epm)
    var $cmd = quote(last)
   else
    var $tmp = undef

   debug ' Inside EPM module, getting the EPM registry for ',$bas
   if ?testFile($MOD,catFile(lastDir(),${AS.BAT:'setEnv'}))
    call sourceContext(getNativePath(lastFile()))
   if grepCommand(concat($cmd,' view SYSTEM9'),'FOUNDATION_SERVICES_PRODUCT',\
                  'f')
   {if loadCommand($cmd)
    {loop $pat ('^File location (.*)',\
                '^The report.*?generated at\s+(.*?)\.\s+Please',\
                '^The report.*?saved to\s+(.*?)registry\.html\.\s+Please')
      break @dir = grepLastFile($pat,'f1')
     if ?cond(@dir,testFile('fr',catFile(@dir,'registry.html')))
      call write_epm_reg(lastTestFile())
    }
   }
   elsif ?nvl(testFile('fr',catFile($ins,'diagnostics','logs','reports',\
                                    'registry.html')),\
              testFile('fr',catFile($ins,'diagnostics','reports',\
                                    'registry.html')))
    call write_epm_reg(last)

   # Unlink the temporary file
   if ?$tmp
    call unlinkTemp($tmp)
  }

=head2 EPM Deployment Report

Generates the enterprise performance management system deployment report using
C<$INSTANCE_HOME/bin/epmsys_registry.sh report deployment> or
C<$INSTANCE_HOME/bin/epmsys_registry.bat report deployment>
for 11.1.2.2 and later versions.

=cut

  # Create a tweaked empsys_registry script copy
  macro create_deploy_script
  {var ($nam,$fil) = @arg
   if !loadFile($fil)
    return (quote($fil))
   var $job = createTemp($nam,cond(isUnix(),'.sh','.bat'),true)
   loop $lin (getLines())
   {if match($lin,'^(set\s+)?SCRIPT_DIR=')
     var $lin = replace($lin,'SCRIPT_DIR=.*$',\
       concat('SCRIPT_DIR=',\
              cond(isUnix(),quote(dirname($fil)),\
                            concat(getShortPath(dirname($fil)),'\'))))
    call writeTemp($nam,$lin)
   }
   call closeTemp($nam)
   return (catCommand(${CFG.D_CWD},$job),$nam)
  }

  # Extract information from the Hyperion report
  macro write_deploy_data
  {var ($fil) = @arg
   import $TOP
   keep $TOP

   if ?testFile('f',$fil)
   {var $htm = htmlLoadFile($fil,\
      htmlFilter(htmlDisable(htmlParser(),'DR'),'B','BR','DIV','LI','TD','TH'))

    loop $row (htmlContent($htm,'T'))
    {next !?$sct = htmlValue($row,'class')

     # Process an info section
     if compare('eq',$sct,'info')
     {var ($hdr,@det) = htmlContent($row)
      if !?htmlName($hdr)
      {prefix
        write '&nbsp;'
       if match($hdr,'\S')
        call unshift(@det,$hdr)
       loop $det (@det)
       {if !?htmlName($det)
        {next !length($txt = trim(replace(htmlText($det),"\240", ' ',true)))
         write '|&nbsp;&nbsp;&nbsp;&nbsp;',encode($txt),' |'
        }
        elsif compare('eq',last,'b')
         write '|*',encode(trim(htmlText($det))),'*|'
       }
       if hasOutput(true)
        write $TOP
      }
      elsif compare('eq',last,'b')
      {write '---++ ',encode(htmlText($hdr))
       loop $det (@det)
       {if !?htmlName($det)
         write encode(htmlText($det)),'%BR%'
        elsif compare('eq',last,'ul')
        {loop $lin (htmlContent($det))
          write '   * ',encode(trim(htmlText($lin)))
        }
       }
      }
     }

     # Process a history report table
     elsif compare('eq',$sct,'confighistorydata')
     {var ($hdr,@tbl) = htmlTable($row, 2, true)
      prefix
       write s($hdr,'^(---\++ )\*([^\*]*)\*(.*)',"$1$2\012$3%BR%&nbsp;")
      loop $lin (@tbl)
       write $lin
      if hasOutput(true)
       write $TOP
     }

     # Process a title
     elsif compare('eq',$sct,'title')
     {loop $itm (htmlContent($row))
      {next !compare('eq',htmlName($itm),'b')
       if trim(htmlText($itm))
        write '---+ ',encode(last)
      }
     }
    }
   }
  }

  # Generate Hyperion report and extract its content
  debug ' Inside EPM module, getting the EPM deployment report for ',$bas
  report epmsys_deploy
  title '---+!! EPM Deployment Report'
  title $TOC
  if compare('valid',$EPM_VERSION,'11.1.2.1')
  {if ?testFile($MOD,catFile(catDir($ins,'bin'),$REG))
   {var ($cmd,$tmp) = create_deploy_script('EPMSYS_DEP',lastFile())
    if loadCommand(concat($cmd,' report deployment'),false,5)
    {var ($fil) = grepLastFile('^The report.*?saved to\s+\
                               (.*?deployment_report_\d{8}_\d{6}\.html)\
                               \.\s+Please','f1')
     if ?testFile('fr',$fil)
      call write_deploy_data($fil)
     else
     {write '   * Deployment report was not generated successfully.'
      if compare('SAME',$EPM_VERSION,'11.1.2.1')
       write '   * There is no deployment report in EPM 11.1.2.1 unless Shared \
                   Services patch 13530721 is installed.'
     }
    }
   }
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][EPM Deployment Report]]'
  if ?$tmp
   call unlinkTemp($tmp)

=head2 Java - Java Version Information

Collects the Java versions available under Oracle Middleware home.
For Windows, collects Services-related Registry Java information.

=cut

  report java
  prefix
  {write '---+!! Java Version Information'
   write $TOC
  }
  if $top = cleanPath([${GRP.EPM.I_OH}->get_prime('D_ORACLE_HOME'),upDir(),''],\
                      true)
  {if ?testDir('d',$top)
   {debug ' Inside EPM module, gathering Middleware home Java versions'
    loop $dir (findDir($top,'^(jdk\d+|jrockit_\d+)','p'))
    {if ?testFile($MOD,catFile($dir,'bin',${AS.EXE:'java'}))
     {var $cmd = concat(lastTestFile(),' -version 2>&1')
      write '---##  Version Information from ',encode(lastTestFile())
      call writeCommand($cmd)
     }
    }
   }
   if hasOutput(true)
    write $TOP
   if isCreated(true)
    toc '2:[[',getFile(),'][rda_report][Java Version Information]]'

   if or(isWindows(),isCygwin())
   {debug ' Inside EPM module, gathering EPM registry Java information'
    macro write_reg
    {var ($apl,$abr,$key,$opt,$mem) = @arg
     for $cnt (hex2int(check($opt,'64',getReg64Value($key,'JVMOptionCount'),\
                                  '32',getReg32Value($key,'JVMOptionCount'),\
                                       getRegValue($key,'JVMOptionCount'))),\
               1,-1)
     {var $val = check($opt,'64',getReg64Value($key,concat('JVMOption',$cnt)),\
                            '32',getReg32Value($key,concat('JVMOption',$cnt)),\
                                 getRegValue($key,concat('JVMOption',$cnt)))
      if match($val,'^-Xmx\d+')
       break $mem = $val
     }
     write '|',$apl,'|',$abr,'|',check($opt,'64',getReg64Value($key,'JavaDll'),\
                                            '64',getReg32Value($key,'JavaDll'),\
                                                 getRegValue($key,'JavaDll')),\
           ' |',$mem,' |'
    }

    report registry
    prefix
    {write '---+!! Services Registry Java Information'
     write $TOC
     write '|*Application*|*Abbreviation*|*Java Dll*|*Memory*|'
    }
    if hasRegOption()
    {loop $key (grepReg64Value('HKLM\SOFTWARE\Hyperion Solutions','JavaDll'))
     {if match($key,'^.* Solutions\\(\w+)\\(\w+)$')
       call write_reg(first,second,$key,'64')
     }
     loop $key (grepReg32Value('HKLM\SOFTWARE\Hyperion Solutions','JavaDll'))
     {if match($key,'^.* Solutions\\(\w+)\\(\w+)$')
       call write_reg(first,second,$key,'32')
     }
    }
    else
    {loop $key (grepRegValue('HKLM\SOFTWARE\Hyperion Solutions','JavaDll'))
     {if match($key,'^.* Solutions\\(\w+)\\(\w+)$')
       call write_reg(first,second,$key)
     }
     loop $key (grepRegValue('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions',\
                                'JavaDll'))
     {if match($key,'^.* Solutions\\(\w+)\\(\w+)$')
       call write_reg(first,second,$key)
     }
    }
    if hasOutput(true)
     write $TOP
    if isCreated(true)
     toc '2:[[',getFile(),'][rda_report][Services Registry Java Information]]'
   }
  }

=head2 Start Scripts

Collects the start scripts from the F<$INSTANCE_HOME/bin> directory.

=cut

  debug ' Inside EPM module, getting instance start scripts'
  pretoc '2:Start Scripts'
  call sort_files(3,0,\
    catFile($ins,'bin','deploymentScripts',\
            ${AS.BAT:'setCustomParamsFoundationServices'}),\
    catFile($ins,'bin','deploymentScripts',\
            ${AS.BAT:'setCustomParamsRaFramework'}))
  unpretoc

=head2 Configuration Files

Collects the logging configuration files from the F<$INSTANCE_HOME/config>
directory.

=cut

  debug ' Inside EPM module, getting the logging configuration files'
  pretoc '2:Configuration Files'
  call sort_files(3,0,\
    catFile($ins,'config','config.xml'),\
    catFile($ins,'config','foundation','11.1.2.0','epm.xml'),\
    catFile($ins,'config','foundation','11.1.2.0','instance.version'),\
    catFile($ins,'config','FoundationServices',\
            'LCMRegistryDisplay.properties'),\
    catFile($ins,'config','FoundationServices','logging.xml'),\
    catFile($ins,'config','ReportingAnalysis','logging','logging_agent.xml'),\
    catFile($ins,'config','ReportingAnalysis','logging','logging_ra.xml'),\
    catFile($ins,'config','ReportingAnalysis','JobUtilities','logging_ju.xml'),\
    catFile($ins,'config','ReportingAnalysis','SDK','logging.xml'),\
    catFile($ins,'config','ReportingAnalysis','validation','logging.xml'),\
    catFile($ins,'config','ReportingAnalysis','Converter','logging.xml'),\
    catFile($ins,'config','ReportingAnalysis','MigrationUtility',\
            'logging.xml'),\
    catFile($ins,'config','starter','EISServer.properties'),\
    catFile($ins,'config','starter','EPMServer.properties'),\
    catFile($ins,'config','starter','Essbase.properties'),\
    catFile($ins,'config','starter','EssbaseStudio.properties'),\
    catFile($ins,'config','starter','OHS.properties'),\
    catFile($ins,'config','starter','RaFrameworkAgent.properties'),\
    catFile($ins,'config','starter','RMI.properties'),\
    catFile($ins,'ReportingAnalysis','RAFrameworkWebapp','WEB-INF',\
            'logging.properties'),\
    catFile($ins,'ReportingAnalysis','RAFrameworkWebapp','WEB-INF',\
            'logging.xml'),\
    catFile($ins,'httpConfig','autogenerated','ohs',\
            'HYSL-WebLogic-autogenerated.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'httpd.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'mod_wl_ohs.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'mime.types'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component','ssl.conf'),\
    catFile($ins,'httpConfig','ohs','config','OHS','ohs_component',\
            'epm_online_help.conf'),\
    catFile($ins,'httpConfig','ant-properties','add-alias.properties'),\
    catFile($ins,'BPMS','bpms1','bin','logging_upgrade.xml'),\
    catFile($ins,'BPMS','bpms1','bin','logging.xml'))
  unpretoc

=for stopwords diaglogs

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from the F<$INSTANCE_HOME/diagnostics/logs>
directory.

=cut

  debug ' Inside EPM module, getting the diagnostic log files'
  report diaglogs
  var $log = catDir($ins,'diagnostics','logs')
  var %pat = (\
    config => [\
      'configtool-appdeployment','configtool','configtool_summary',\
      'configTool-stdout','configtool-http-ant','iis_configuration',\
      'registry','SharedServices_Security','SharedServices_Security_Client',\
      'configTool-stderr','configtool-wasdeployment','listener','ocm-config',\
      'EssBaseExternalizationTask','SharedServices_CMSClient','cmcconfig'],\
    catDir('essbase','lcm') => ['essbaseplugin'],\
    install  => [\
      'StopStartServices','common-install','common-ohs-install',\
      'common-ohs-oui-out','common-opmn-install',\
      'common-opmn-patchset-oui-out','common-oracle-common-install',\
      'common-oracle-common-oui-out','common-product-install',\
      'common-staticcontent-install','common-wl-install','dotNetInstall',\
      'dotNet35Install','dotNetInstall64','dotNetRegister','dotNetRegister64',\
      'wl_install_err','wl_install_out'],\
    ReportingAnalysis => [\
      'stdout_console_RAF_AGENT_MODULE','server_messages_ServiceBroker',\
      'server_messages','stdout_console_agent','agent',\
      'server_messages_SearchMonitor','velocity',\
      'server_messages_SearchIndexing','server_messages_SearchKeywordProvider',\
      'server_messages_SessionManager','server_messages_UsageService',\
      'server_messages_JobService','server_messages_EventService',\
      'server_messages_LoggingService','server_messages_PublisherService',\
      'server_messages_RepositoryService',\
      'server_messages_AnalyticBridgeService',\
      'server_messages_AuthorizationService','server_messages_CommonServices',\
      'server_messages_LSM','logwriter_messages_RAF_AGENT_MODULE',\
      'configuration_messages_.*?','eiengine','logwriter_messages_.*?',\
      'JobUtilities','migrator','server_messages_GSM',\
      'server_messages_AuthenticationService',\
      '0_RAF_AGENT_MODULE_workspace_.*?_stdout',\
      'configuration_messages_RAF_AGENT_MODULE',\
      '0_RAF_AGENT_MODULE_workspace_.*?_stderr',\
      'server_messages_TransformerService','server_messages_SearchMonitor',\
      'stdout_console_default'],\
    catDir('ReportingAnalysis','SDK') => ['sdk'],\
    services => [\
      'HyS9aps-syserr','HyS9aps-sysout',\
      'HyS9Foundationservices-syserr','HyS9Foundationservices-sysout',\
      'HyS9RaFrameworkAgentErr','HyS9RaFrameworkAgentOut',\
      'HyS9RaFramework-syserr','HyS9RaFramework-sysout'],\
    starter => [\
      'starter-services.*?','starter-events.*?','starter.*?',\
      'start-AnalyticProviderServices0-out',\
      'stop-AnalyticProviderServices0-out',\
      'start_BPMS_bpms1_Server\.bat','starter-services.*?','stopper-events.*?',\
      'stopper-services.*?','stopper.*?','stopAgent\.bat',\
      'stop-HyS9RaFramework-out','stop-HyperionRMIRegistry-out',\
      'stop_BPMS_bpms1_Server\.bat','start-HyperionStudioBPMSbpms1-out',\
      'start-HyS9FoundationServices-out','start-HyS9RaFrameworkAgent-out',\
      'start-HyS9RaFramework-out','start-opmn_EPM_epmsystem1-out',\
      'start-OracleProcessManager_ohsInstance.*?-out',\
      'start-HyperionStudioServiceBPMSbpms1-out',\
      'stop-HyperionStudioServiceBPMSbpms1-out',\
      'stop-HyS9FoundationServices-out','stop-HyS9RaFrameworkAgent-out',\
      'stop-HyS9RaFramework-out','stop-opmn_EPM_epmsystem1-out',\
      'stop-OracleProcessManager_ohsInstance.*?-out'],\
    validation => [\
      'hat.output','validation','validationTool-stdout','velocity',\
      'validationTool-stderr','validation-\d+'])
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
  loop $sub ([catFile($log,'hat.output'),\
              catFile($log,'validationTool-stderr.log')],\
             'config',catDir('essbase','lcm'),'install','ReportingAnalysis',\
             catDir('ReportingAnalysis','SDK'),'services','starter',\
             'validation')
  {loop $fil (cond(ref($sub),@{$sub},grepDir(catDir($log,$sub),\
     cond(exists($pat{$sub}),concat('^(',join("|",@{$pat{$sub}}),')\.log$'),\
                             '\.log$'),'pt')))
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

=head2 ziplogs - Ziplogs Utility Output File

Runs the EPM ziplogs utility and collects the output file from the
F<$INSTANCE_HOME/diagnostics/ziplogs> directory.

=cut

  debug ' Inside EPM module, getting the ziplogs output file'
  report ziplogs

# Run ziplogs.sh / ziplogs.bat for the current value of $ins.
# (This entire module is within a loop on the one or more Instance
#   names found in the user_projects folder under MW_HOME).

# Check that we can find the ziplogs executable (.sh or .bat) in
#  the 'common/config/11.1.2.0' folder under the current EPM_ORACLE_HOME,
#  fall through to the next main heading if not.

  debug ' Ziplogs :  Current value of EPM Instance is :  ',$ins

  if or(isWindows(),isCygwin())
   var $cmd = catFile($EPM_HOME,'common','config','11.1.2.0','ziplogs.bat')
  else
   var $cmd = catFile($EPM_HOME,'common','config','11.1.2.0','ziplogs.sh')

  if ?testFile('x',$cmd)
  {var $tmp = newTemp('ziplogs','.txt')
   var $cmd = concat($cmd,' -EOI ',$ins,' >',quote($tmp),' 2>&1')
   debug ' Inside EPM module - found ziplogs executable'
   debug ' Ziplogs command is :  ',$cmd

   call command($cmd)

   if grepFile($tmp,'Logs will be zip to ')
   {debug ' Ziplogs executed successfully'
    prefix
 {write '---+ EPM Functional Server Logs (' ,$bas,' - ziplogs output)'
  write '   * Links point to files that have been collected in their original \
              format. Opening them directly in your browser can present \
              risks. To prevent them, access the file outside the browser or \
              use the link to save them and use an adequate viewer.'
  write '|*File*| *Size*|*Last Modified*|'
 }
    var $fil = first(grepDir(catDir($ins,'diagnostics','ziplogs'),\
                             '^EPM_logs_.*_\S+\.zip$','pt'))
    if ?testFile('f',$fil)
    {var $lnk = encode(basename($fil))
     var $siz = getSize($fil)
     if $siz
     {output b,basename($fil)
      if ${CUR.O_LAST}->write_data($fil)
       var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                         '][_blank][',$lnk,']]')
      end ${CUR.O_LAST}
     }
     write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
    }
   }
   else
    debug ' Ziplogs did not execute for Instance :  ',$ins
   call unlinkTemp('ziplogs')
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Ziplogs Utility Output]]'


=head2 Web Tier Information

Includes the reports generated by the L<abr:IREQ|collect::OFM:DCireq> module
about the Oracle instance and its associated Oracle home.

=cut

  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("0:         * Oracle WebTier Instance")%'
  toc '%PUSH("1+++:Associated Oracle Home")%'
  toc '%INCLUDE("OFM_',replace($tid = $req->get_oid,'_OI','_OH'),'_TF.toc",2)%'
  toc '%POP%'
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+++:Instance Home")%'
  toc '%INCLUDE("OFM_',$tid,'_TF.toc",1)%'
  toc '%POP4%'

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${B_PRIMARY}
  {var ($num) = match($tid,'(\d+)$')
   if ${CUR.O_SETUP}->search(concat('^WREQ_BI_EPM_DOM_T',$num))
   {var ($req) = last
    var $dom = $req->get_first('I_DOMAIN')
    var $oid = $dom->get_first('I_WL_HOME')->get_oid
    var $nam = $dom->get_first('T_DOMAIN_NAME')
    toc '%PUSH("%SPLIT%")%'
    toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
    toc '%INCLUDE("OFM_WREQ_BI_EPM_',$oid,'_TF.toc",1)%'
    toc '%POP2%'
    toc '%PUSH("%SPLIT%")%'
    toc '%PUSH("1++:',"'",$nam,"'",' Domain")%'
    toc '%INCLUDE("OFM_',$req->get_oid,'_TF.toc",1)%'
    toc '%POP2%'
   }
  }

  # Restore module prefix
  call setPrefix($PRE)
 }
}

# Unlink the temporary password file
if ?$epm
 call unlinkTemp('EPMPWD')

unpretoc 2

=head1 SEE ALSO

L<BI:EPMlib|collect::BI:EPMlib>,
L<OFM:DCireq|collect::OFM:DCireq>,
L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:INVinfo|collect::RDA:INVinfo>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
