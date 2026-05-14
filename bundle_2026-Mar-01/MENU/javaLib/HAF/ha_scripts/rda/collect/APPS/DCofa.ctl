# DCofa.ctl:600:Collects Oracle Fusion Applications Information
# $Id: DCofa.ctl,v 1.9 2015/07/03 11:32:26 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCofa.ctl,v 1.9 2015/07/03 11:32:26 RDA Exp $
#
# Change History
# 20150703  MSC  Improve the documentation.

=head1 NAME

APPS:DCofa - Collects Oracle Fusion Applications Information

=head1 DESCRIPTION

This module collects Oracle Fusion Applications-related information. The
following reports can be generated and are regrouped under C<Oracle Fusion
Applications>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing APPS.OFA module ...',tput('off')

# Initialization
var $ROOT = ${D_ROOT:''}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Oracle Fusion Applications'

# Load the common macros
run RDA:library()

=head1 ESS SERVER INFORMATION

=head2 Configuration Files

Gathers Oracle Fusion Applications-related ESS server configuration files.

=cut

debug ' Inside OFA module, gathering ess server configuration files'
pretoc '2:ESS Server Information'
pretoc '3:Configuration Files'
call sort_files(4,0,\
  catFile($ROOT,'fusionapps','atgpf','ess','archives','ess-app','APP-INF',\
          'classes','META-INF','ess-config.xml'),\
  catFile($ROOT,'fusionapps','atgpf','ess','wsdl','ESSTypes.xsd'),\
  catFile($ROOT,'instance','ess','config','environment.properties'),\
  catFile($ROOT,'instance','ess','tnsadmin','tnsnames.ora'),\
  catFile($ROOT,'instance','ess','tnsadmin','sqlnet.ora'))
unpretoc 2

=head1 APPLICATIONS FILES

=head2 Configuration Files

Gathers all C<txt> and C<xml> configuration files from
F<$MW_HOME/applications/$PRODUCT_FAMILY/deploy> and
F<$MW_HOME/applications/$PRODUCT_FAMILY/deploy/$PRODUCT/adf/META-INF> directory
structures.

=cut

# Identify the relevant deployed applications
var (%clu,%fam) = ()
loop $req (@req = ${CUR.O_SETUP}->search('^WREQ_APPS_OFA_DOM'))
{var $tgt = $req->get_first('I_DOMAIN')
 call addTarget($tgt)
 var $top = $tgt->get_first('D_DOMAIN_HOME')
 var $dom = $tgt->get_first('T_DOMAIN_NAME')
 if ?testFile('fr',catFile($top,'config','config.xml'))
 {var $obj = xmlLoadFile(lastFile(),xmlDisable(xmlParser(),'BCDEPR'))
  next !match(xmlData(xmlFind($obj,'domain/name')),\
              concat('^',verbatim($dom),'$'),true)
  var $lst = join('|',map($req->get_value('T_SERVERS'),code(verbatim(last))))
  loop $xml (xmlFind($obj,\
    concat('domain/server|name *="^(',replace($lst,'"','\042',true),')$"')))
  {if xmlFind($xml,'cluster')
    var $clu{xmlData(last)} = true
  }
  loop $xml (xmlFind($obj,'domain/app-deployment'))
  {loop $clu (keys(%clu))
   {next !match(xmlData(xmlFind($xml,'target')),\
                concat('\b',verbatim($clu),'\b'))
    var $pth = xmlData(xmlFind($xml,'source-path'))
    var @dir = splitDir($pth)
    if compare('eq',$dir[-2],'deploy')
     var $fam{$dir[-3],$pth} = xmlData(xmlFind($xml,'name'))
   }
  }
 }
}

# Report the application specific files per product family
debug ' Inside OFA module, gathering deployed application related config files'
loop $fam (keys(%fam))
{if isTocCreated()
  toc '%SPLIT%'
 pretoc "1+:'",$fam,"' Family"
 var $flg = true
 loop $pth (keys($fam{$fam}))
 {if $flg
  {var (@dir,@tbl) = (splitDir($pth))
   call pop(@dir)
   loop $fil (grepDir(catDir(@dir),'\.(txt|xml)$','ip'))
   {next match($fil,'(_|Cred)DeployPlan\.xml$',true)
    call push(@tbl,$fil)
   }
   pretoc '2:Configuration Files'
   call sort_files(3,0,@tbl)
   var $flg = false
   unpretoc
  }
  pretoc "2:'",field('\#',0,$fam{$fam,$pth}),"' Application"
  pretoc '3:Configuration Files'
  call sort_files(4,0,\
   grepDir(catDir($pth,'adf','META-INF'),'\.(txt|xml)$','ip'))
  unpretoc 2
 }
 unpretoc
}

=head1 ORACLE WEBLOGIC SERVER DOMAIN COLLECTIONS

It includes all reports produced by the L<abr:WREQ|collect::OFM:DCwreq> module
for the specified Oracle WebLogic Server domains.

=cut

# Analyze the domain requests
var %tbl = ()
loop $req (@req)
{var $dom = $req->get_first('I_DOMAIN')
 if ?$dom->get_first('I_WL_HOME')
  var $tbl{last->get_oid,$req->get_oid} = $dom->get_first('T_DOMAIN_NAME')
 else
  var $tbl{'WH',$req->get_oid} = $dom->get_first('T_DOMAIN_NAME')
}

# Include the table of content files produced by WREQ
loop $oid (keys(%tbl))
{if $orp = compare('eq',$oid,'WH')
  toc '%PUSH("0:   * Orphan Domains")%'
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
 toc '%INCLUDE("OFM_WREQ_APPS_OFA_',$oid,'_TF.toc")%'
 toc '%POP2%'
 loop $tid (keys($tbl = $tbl{$oid}))
 {toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$tbl->{$tid},"'",' Domain")%'
  toc '%INCLUDE("OFM_',$tid,'_TF.toc")%'
  toc '%POP2%'
 }
 if $orp
  toc '%POP%'
}

unpretoc

=head1 SEE ALSO

L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
