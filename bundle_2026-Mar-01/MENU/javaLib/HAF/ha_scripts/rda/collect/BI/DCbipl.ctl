# DCbipl.ctl:399:Collects Oracle Business Intelligence Publisher Information
# $Id: DCbipl.ctl,v 1.7 2015/07/03 11:49:17 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCbipl.ctl,v 1.7 2015/07/03 11:49:17 RDA Exp $
#
# Change History
# 20150703  MSC  Improve the documentation.

=head1 NAME

BI:DCbipl - Collects Oracle Business Intelligence Publisher Information

=head1 DESCRIPTION

This module collects information about Oracle Business Intelligence Publisher.
The following reports can be generated and are regrouped under
C<Oracle Business Intelligence Publisher>:

=cut

echo tput('bold'),'Processing BI.BIPL module ...',tput('off')

# Initialization
var $ORACLE_HOME = ${SET.RDA.BEGIN.D_ORACLE_HOME:''}

# Load the common macros
run RDA:library()

pretoc '1:Oracle Business Intelligence Publisher'
if !or(${B_REQ_IREQ},\
       ${B_REQ_WREQ},\
       testDir('d',catDir($ORACLE_HOME,'bifoundation')))
{# Initialization
 var $BIPL_AGE  = ${R_LOG_AGE/T:5}
 var $BIPL_HOME = ${D_HOME:''}
 var $BIPL_TAIL = ${N_TAIL:5000}
 var $AS_TYPE   = ${W_WAS}

 var $TOC = '%TOC%'
 var $TOP = '[[#Top][Back to top]]'

=head1 BUSINESS INTELLIGENCE PUBLISHER 10g INFORMATION

=head2 Configuration Files

Gets Oracle Business Intelligence Publisher configuration files.

=cut

 if !isFiltered()
 {var $dir = catDir($BIPL_HOME,'xmlp','XMLP','Admin')
  pretoc '2: Configuration Files'
  var %flt = (\
    'database-config.xml',   ['i','<password>','</password>'],\
    'datasources.xml',       ['i','<password>','</password>'],\
    'principals.xml',        ['is','user\s+username=".*?"\s+password="','"'],\
    'xmlp-server-config.xml',['i','property\s+name=".*password"\s+value="','"'])
  loop $fil (\
    catFile($dir,'Configuration','xmlp-server-config.xml'),\
    catFile($dir,'Security','principals.xml'),\
    catFile($dir,'Security','security.xml'),\
    catFile($dir,'DataSource','datasources.xml'),\
    catFile($dir,'Scheduler','database-config.xml'))
  {if ?testFile('r',$fil)
   {var $nam = basename($fil)
    report $nam
    prefix
    {write '---+ Display of ',encode($nam),' File'
     write '---## Information Taken from ',encode($fil)
    }
    call statFile('b',$fil)
    if !exists($flt{$nam})
     call writeFile($fil)
    elsif createBuffer('XML','F',$fil)
    {call filterBuffer('XML','%R:PASSWORD%',@{$flt{$nam}})
     call writeBuffer('XML')
     call deleteBuffer('XML')
    }
    if isCreated(true)
     toc '3:[[',getFile(),'][rda_report][',encode($nam),']]'
   }
  }
  unpretoc
 }

=head2 Log Files

Gets Oracle Business Intelligence Publisher log files.

=cut

 pretoc '2:Log Files'
 if ?testFile('r',\
   catFile($BIPL_HOME,'oc4j_bi','j2ee','home','log','oc4j','log.xml'))
  call sort_files(3,$BIPL_TAIL,lastFile())
 unpretoc

=head2 Oracle Application Server Information

Collects the F<log.xml> files found in the F<oc4j> subdirectories.

=cut

 if match($AS_TYPE,'OAS')
 {pretoc '2:Oracle Application Server Information'
  var @fil
  var $dir = catDir(${D_OAS_HOME},'j2ee')
  loop $hom (findDir($dir,'oc4j','r',3))
  {if ?testFile('r',catFile($hom,'log.xml'))
    call push(@fil,lastFile())
  }
  call sort_files(3,$BIPL_TAIL,@fil)
  unpretoc
 }

=head2 Apache Tomcat Log Files

Collects recent log files from the Apache Tomcat installation logs directory.

=cut

 elsif match($AS_TYPE,'TOM')
 {pretoc '2:Apache Tomcat Log Files'
  var $dir = catDir(${D_TOMCAT_HOME},'logs')
  call sort_files(3,$BIPL_TAIL,grepDir($dir,'\.log$',concat('ipm',$BIPL_AGE)))
  unpretoc
 }

=head2 IBM WebSphere Log Files

Collects recent log files from the IBM WebSphere installation logs directory.

=cut

 elsif match($AS_TYPE,'WSP')
 {pretoc '2:IBM WebSphere Log Files'
  var $dir = catDir(${D_WSP_HOME},'logs')
  call sort_files(3,$BIPL_TAIL,grepDir($dir,'\.log$',concat('ipm',$BIPL_AGE)))
  unpretoc
 }
}

=head1 BUSINESS INTELLIGENCE PUBLISHER 11g INFORMATION

=head2 Configuration Files

Gets Oracle Business Intelligence Publisher configuration files.

=cut

else
{if !isFiltered()
 {var $dir = catDir($ORACLE_HOME,'clients','bipublisher','repository',\
                    'Admin','Security')
  pretoc '2: Configuration Files'
  loop $fil (grepDir($dir,'\.xml','np'))
  {if compare('ne',basename($fil),'principals.xml')
    call push(@fil,$fil)
  }
  call sort_files(3,0,grepDir($dir,'\.(xsd|product|instance)','np'),@fil)
  if ?testFile('r',catFile($dir,'principals.xml'))
  {var $fil = lastFile()
   var $nam = basename($fil)
   report $nam
   prefix
   {write '---+ Display of ',encode($nam),' File'
    write '---## Information Taken from ',encode($fil)
   }
   call statFile('b',$fil)
   if createBuffer('XML','F',$fil)
   {call filterBuffer('XML','%R:PASSWORD%','is',\
                      'user\s+username=".*?"\s+password="','"')
    call writeBuffer('XML')
    call deleteBuffer('XML')
   }
   if isCreated(true)
    toc '4:[[',getFile(),'][rda_report][',encode($nam),']]'
  }
  unpretoc
 }

=head1 ORACLE INSTANCE INFORMATION

Includes the reports generated by the L<abr:IREQ|collect::OFM:DCireq> module
about the Oracle instances and their associated Oracle homes.

=cut

 # Analyze the instance requests
 var %tbl = ()
 loop $req (${CUR.O_SETUP}->search('^IREQ_BI_BIPL_OI'))
 {var $ins = $req->get_first('I_ORACLE_INSTANCE')
  if ?$ins->get_first('I_ORACLE_HOME')->get_prime('I_COMMON_HOME')
   var $tbl{last->get_oid,$req->get_oid} = $ins->get_first('D_ORACLE_INSTANCE')
  else
   var $tbl{'CH',$req->get_oid} = $ins->get_first('D_ORACLE_INSTANCE')
 }

 # Collect the BIPL 11g information
 loop $oid (keys(%tbl))
 {toc '%PUSH("1+:Common Product Home")%'
  toc '%INCLUDE("OFM_IREQ_BI_BIPL_',$oid,'_TF.toc")%'
  toc '%POP%'
  loop $tid (keys($tbl = $tbl{$oid}))
  {toc '%PUSH("0:      * ',"'",basename($tbl->{$tid}),"'",' Instance")%'
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Associated Oracle Home")%'
   toc '%INCLUDE("OFM_',replace($tid,'_OI','_OH'),'_TF.toc",1)%'
   toc '%POP2%'
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Instance Home")%'
   toc '%INCLUDE("OFM_',$tid,'_TF.toc")%'
   toc '%POP3%'
  }
 }

=head1 ORACLE WEBLOGIC SERVER INFORMATION

Includes the Oracle WebLogic Server reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:Oracle WebLogic Server Overview")%'
 toc '%INCLUDE("OFM_WREQ_BI_BIPL_WH_TF.toc")%'
 toc '%POP2%'
 toc '%PUSH("%SPLIT%")%'
 toc '%PUSH("1+:Oracle WebLogic Server Domain")%'
 toc '%INCLUDE("OFM_WREQ_BI_BIPL_DOM_TF.toc")%'
 toc '%POP2%'
}
unpretoc

=head1 SEE ALSO

L<OFM:DCireq|collect::OFM:DCireq>,
L<OFM:DCwreq|collect::OFM:DCwreq>,
L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
