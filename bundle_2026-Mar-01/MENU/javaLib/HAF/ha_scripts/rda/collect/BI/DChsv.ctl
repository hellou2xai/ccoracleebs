# DChsv.ctl:573:Collects Oracle Hyperion Smart View for Office Information
# $Id: DChsv.ctl,v 1.10 2015/07/03 11:49:17 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DChsv.ctl,v 1.10 2015/07/03 11:49:17 RDA Exp $
#
# Change History
# 20150703  MSC  Improve the documentation.

=head1 NAME

BI:DChsv - Collects Oracle Hyperion Smart View for Office information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Smart View for Office. This
module is applicable for Microsoft Windows only.

The following reports can be generated and are regrouped under C<Hyperion
Smart View for Office>:

=cut

echo tput('bold'),'Processing BI.HSV module ...',tput('off')

# Initialization
var $EPM_HOME = ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}

var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

toc '1:Hyperion Smart View for Office'

# Define common macros
macro write_version
{var ($hom,$dll,$lvl,$lnk) = @arg

 loop $fil (grepDir($hom,$dll,'ir'))
 {if $inf = getVersionInfo($fil)
  {output F,concat('v_',basename($fil))
   write '---+ ',$lnk,' Version Information'
   write '---## From ',encode($fil)
   loop $key (keys($inf))
    write '|*',$key,' *|',$inf->{$key},' |'
   toc nvl($lvl,4),':[[',getFile(),'][rda_report][',$lnk,']]'
  }
 }
}

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Hyperion Smart View home
collection.

=cut

debug ' Inside HSV module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Hyperion Smart View Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Product Version Information

Gathers product version information.

=cut

debug ' Inside HSV module, gathering version information'
pretoc '2:Product Version Information'
if getRegValue('HKCU\Software\Hyperion Solutions\HyperionSmartView','LOCATION')
 call write_version(catDir(last,'Bin'),'^HsAddin\.dll$',3,'HsAddin.dll')
elsif ?nvl(testDir('r',catDir($EPM_HOME,'SmartView','Bin')),\
           testDir('r',catDir($EPM_HOME,'Products','SmartView','Bin')),\
           testDir('r',catDir('C:\Oracle\SmartView')))
 call write_version(last,'^HsAddin\.dll$',3,'HsAddin.dll')
unpretoc

=head2 Microsoft Office Versions

Gathers the version of various Microsoft Office products.

=cut

# Macro to get the Office version
macro get_office_ver
{var ($app,$pth) = @arg
 if compare('eq',$app,'Excel')
  call write_version($pth,'^excel\.exe$',3,'Excel')
 elsif compare('eq',$app,'Outlook')
  call write_version($pth,'^outlook\.exe$',3,'Outlook')
 elsif compare('eq',$app,'PowerPoint')
  call write_version($pth,'^powerpnt\.exe$',3,'PowerPoint')
 elsif compare('eq',$app,'Word')
  call write_version($pth,'^winword\.exe$',3,'Word')
}

debug ' Inside HSV module, gathering the Microsoft Office versions'
pretoc '2:Microsoft Office Versions'
if hasRegOption()
{if grepReg64Value('HKLM\SOFTWARE\Microsoft\Office','Path')
 {loop $key (last)
  {if match($key,'\\(Excel|Outlook|PowerPoint|Word)\\InstallRoot$')
    call get_office_ver(first(last),getReg64Value($key,'Path'))
  }
 }
 elsif grepReg32Value('HKLM\SOFTWARE\Microsoft\Office','Path')
 {loop $key (last)
  {if match($key,'\\(Excel|Outlook|PowerPoint|Word)\\InstallRoot$')
    call get_office_ver(first(last),getReg32Value($key,'Path'))
  }
 }
}
else
{if grepRegValue('HKLM\SOFTWARE\Microsoft\Office','Path')
 {loop $key (last)
  {if match($key,'\\(Excel|Outlook|PowerPoint|Word)\\InstallRoot$')
    call get_office_ver(first(last),getRegValue($key,'Path'))
  }
 }
 elsif grepRegValue('HKLM\SOFTWARE\Wow6432Node\Microsoft\Office','Path')
 {loop $key (last)
  {if match($key,'\\(Excel|Outlook|PowerPoint|Word)\\InstallRoot$')
    call get_office_ver(first(last),getRegValue($key,'Path'))
  }
 }
}
unpretoc

=head2 ieversion - Internet Explorer Version

Gathers the Internet Explorer version.

=cut

debug ' Inside HSV module, gathering the Internet Explorer version'
report ieversion
prefix
 write '---+!! Internet Explorer Version'
var $key = 'HKLM\SOFTWARE\Microsoft\Internet Explorer'
write '|*Version*|',nvl(getRegValue($key,'Version'),'NA'),'|'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Internet Explorer Version]]'

=head2 ietimeout - Internet Explorer Timeout

Gathers the Internet Explorer timeout settings, when defined in
C<HKLM\Software\Microsoft\Windows\CurrentVersion\Internet Settings>.

=cut

debug ' Inside HSV module, gathering the Internet Explorer timeout settings'
report ietimeout
var $key = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
prefix
{write '---+!! Internet Explorer Timeout'
 write '---++ From [',$key,']'
 write '|*Name*|*Value*|'
}
loop $nam ('ReceiveTimeout','KeepAliveTimeout','ServerInfoTimeout')
{if ?getRegValue($key,$nam)
  write '|',$nam,'|',last,' |'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Internet Explorer Timeout]]'

=head2 aspnet - ASP.NET Version

Gathers ASP.NET version. It reports the C<RootVer> value from
C<HKLM\SOFTWARE\Microsoft\ASP.NET> and the versions extracted from the keys.

=cut

debug ' Inside HSV module, gathering ASP.NET version'
report aspnet
prefix
{write '---+!! ASP.NET Version'
 write '|*Key*|*Name*|*Version*|'
}
var $reg = 'HKLM\SOFTWARE\Microsoft\ASP.NET'
if ?getRegValue($reg,'RootVer')
 write '|',$reg,' |RootVer |',last,' |'
loop $key (grepRegValue($reg,'Path'))
 write '|',$key,' | - |',field('\\',-1,$key),' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][ASP.NET Version]]'

=head2 msxml - MSXML Version

Gathers MSXML version information.

=cut

debug ' Inside HSV module, gathering MSXML version'
report msxml
prefix
{write '---+!! MSXML Version'
 write '|*Key*|*Name*|*Version*|'
}
loop $key (grepRegValue('HKLM\SOFTWARE\Microsoft','PatchLevel'))
{if match($key,'MSXML')
  write '|',$key,' |PatchLevel |',getRegValue($key,'PatchLevel'),' |'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][MSXML Version]]'

=head2 registry - Registry Information

Collects Hyperion Smart View-related Registry information.

=cut

debug ' Inside HSV module, gathering HSV registry information'
report registry
prefix
{write '---+!! Hyperion Smart View Registry Information'
 write $TOC
}
if writeRegistry('HKCU\Software\Hyperion Solutions\HyperionSmartView')
 write $TOP
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Registry Information]]'

=head2 svusers - Smart View Windows Users

Collects Hyperion Smart View-related Windows users.

=cut

debug ' Inside HSV module, gathering HSV users'
var @usr = ()
if hasRegOption()
{loop $pth (grepReg64Value('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\\
                            ProfileList','ProfileImagePath'))
 {if match($pth,'\\S-1-5-21-')
   call push(@usr,match(getReg64Value($pth,'ProfileImagePath'),'(\w+)$'))
 }
 if !@usr
 {loop $pth (grepReg32Value('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\\
                             ProfileList','ProfileImagePath'))
  {if match($pth,'\\S-1-5-21-')
    call push(@usr,match(getReg32Value($pth,'ProfileImagePath'),'(\w+)$'))
  }
 }
}
else
{loop $pth (grepRegValue('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\\
                          ProfileList','ProfileImagePath'))
 {if match($pth,'\\S-1-5-21-')
   call push(@usr,match(getRegValue($pth,'ProfileImagePath'),'(\w+)$'))
 }
 if !@usr
 {loop $pth (grepRegValue('HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows NT\\
                           CurrentVersion\ProfileList','ProfileImagePath'))
  {if match($pth,'\\S-1-5-21-')
    call push(@usr,match(getRegValue($pth,'ProfileImagePath'),'(\w+)$'))
  }
 }
}

report svusers
prefix
{write '---+!! Smart View Windows Users'
 write '|*User Name*|*SmartView User*|'
}
loop $usr (@usr)
{var $flg = 'NO'
 if hasRegOption()
 {if or(grepReg64Value('HKCU\SOFTWARE\Microsoft\Office\Outlook\Addins\\
                        Hyperion.CommonAddin','LoadBehavior'),\
        grepReg32Value('HKCU\SOFTWARE\Microsoft\Office\Outlook\Addins\\
                        Hyperion.CommonAddin','LoadBehavior'))
   var $flg = 'YES'
 }
 else
 {if or(grepRegValue('HKCU\SOFTWARE\Microsoft\Office\Outlook\Addins\\
                      Hyperion.CommonAddin','LoadBehavior'),\
        grepRegValue('HKCU\SOFTWARE\Wow6432Node\Microsoft\Office\Outlook\\
                      Addins\Hyperion.CommonAddin','LoadBehavior'))
   var $flg = 'YES'
 }
 write '|',$usr,' | ',$flg,' |'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Smart View Windows Users]]'

=head1 DEPLOYMENT REPORTS

Available on version 11.1.2 and later.

=cut

if @ins = ${CUR.O_MODULE}->search('^OI')
{var $CNT = 0
 loop $itm (@ins)
 {var ($ins,$uid) = ($itm->get_first('D_HOME'),$itm->get_oid)
  call setSymbol('$EPM_INSTANCE',$ins)
  call setPrefix(concat($PRE,'i',incr($CNT)))
  toc '%SPLIT%'
  toc "1+:'",basename($ins),"' Deployment"

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Hyperion Smart View instance
collection.

=cut

  debug ' Inside HSV module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Hyperion Smart View Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_HSV_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_HSV_',$oid,'_TF.toc",1)%'
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

=head1 PRODUCT REPORTS

Collects the following reports on versions earlier than 11.1.2:

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain (on versions having a product registry).

=cut

elsif ?${GRP.EPM.D_DOMAIN}
{var $dom = basename(last)
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
 toc '%INCLUDE("OFM_WREQ_BI_HSV_WH_TF.toc")%'
 toc '%POP2%'
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
 toc '%INCLUDE("OFM_WREQ_BI_HSV_DOM_TF.toc")%'
 toc '%POP2%'
}

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
