# DCfcm.ctl:565:Collects Oracle Hyperion Financial Close Management Information
# $Id: DCfcm.ctl,v 1.13 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/DCfcm.ctl,v 1.13 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:DCfcm - Collects Oracle Hyperion Financial Close Management information

=head1 DESCRIPTION

This module collects information for Oracle Hyperion Financial Close
Management. This module is applicable for Microsoft Windows only.

The following reports can be generated and are regrouped under
C<Financial Close Management>:

=cut

echo tput('bold'),'Processing BI.FCM module ...',tput('off')

# Initialization
var $EPM_HOME = ${GRP.EPM.D_HOME:${ENV.EPM_ORACLE_HOME:${ENV.HYPERION_HOME:''}}}
var $TAIL     = ${DFT.N_TAIL:1000}

var $PRE = setPrefix()
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

pretoc '1:Financial Close Management'

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Financial Close Management home
collection.

=cut

debug ' Inside FCM module, collecting defined home abbreviations'
report abbr
prefix
{write '---+ Financial Close Management Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 dbinfo - Generic Database Information

Collects generic information for Oracle Financial Close Management from the
Database.

=cut

if ${I_DB}
{var $tgt = last

 # Set the database and domain context
 run DB:DBinfo()
 var $dom = first(values(%{${GRP.EPM.D_DOMAINS}}))
 call setDbTarget({T_TYPE=>        'JDBC',\
                   T_USER=>        $tgt->get_first('T_USER'),\
                   T_SOURCE=>      $tgt->get_first('T_SOURCE'),\
                   D_DOMAIN_HOME=> $dom,\
                   B_SYSDBA=>      $tgt->get_first('B_SYSDBA')})

 # Test the database connection and collect information
 debug ' Inside FCM module, getting generic database information'
 report dbinfo
 write '---+!! Generic Database Information'
 toc '2:[[',getFile(),'][rda_report][Generic Database Information]]'

 if testDb()
 {echo ''
  echo tput('bold'),\
       'The schema containing FCM repository is not accessible.',tput('off')
  if $msg = getDbMessage()
   echo $msg
  echo ''
  write 'FCM repository not accessible (',$msg,')'
 }
 else
 {# Display database provider and version
  write '---+ Database Repository Provider and Version'
  write '|*Database Provider*|*Database Version*|'
  write '|',getDbProvider(),'|',getDbVersion(),'|'

=head2 schedule - Schedule Information

Collects schedule information from the database.

=cut

  debug ' Inside FCM module, getting schedule information'
  report schedule
  var $TTL = '---+!! Schedule Information'
  var @TTL = ('',\
             '---+ List of Schedules',\
             '---+ Schedule and Task Information')
  var @HDR = ()

  var ($HDR[1],$col1) = getDbColumns('CM','fcc_deployments',\
    'deployment_id','deployment_name','description','status',\
    'start_date','end_date','template_id')
  call clearDbColumns('CM')

  var ($HDR[2],$col2) = getDbView({d=>'fcc_deployments',t=>'fcc_tasks'},\
    't.source_id',\
    'd.deployment_name',\
    {fct=>'CNT',hdr=>' *Task Count*',tid=>'t',col=>'task_id'},\
    't.status_id')
  call clearDbColumns('d')
  call clearDbColumns('t')

  set $sql
  {# SQL1
   "SELECT :1
   " FROM fcc_deployments
   " ORDER BY deployment_name
   "/
   # MACRO separator(2)
   # SQL2
   "SELECT :2
   " FROM fcc_tasks t, fcc_deployments d
   " WHERE t.source_type = 'DEPLOYMENT'
   "   AND t.source_id = d.deployment_id
   " GROUP BY t.source_id, d.deployment_name, t.status_id
   " ORDER BY d.deployment_name
   "/
  }
  call separator(1)
  call writeDb(bindDb($sql,$col1,$col2))
  call separator(0,'Schedule Information')

=head2 integration - Integration Type Information

Collects integration type information from the database.

=cut

  debug ' Inside FCM module, getting integration type information'
  report integration
  var $TTL = '---+!! Integration Information'
  var @TTL = ('',\
              '---+ List of Integration Applications',\
              '---+ List of Integration Types')

  var @HDR = ()
  var ($HDR[1],$col1) = getDbColumns('CM','fcc_integration_apps',\
    'application_id','application_name','web_app','webservice')
  call clearDbColumns('CM')
  set $sql
  {# SQL1
   "SELECT :1
   " FROM fcc_integration_apps
   " ORDER BY application_name
   "/
  }

  call encodeDbColumns(["|[]<>\012\040",'LTRIM(%s)'],'CM',\
    'response_xsl_template')
  if getDbColumns('CM','fcc_integration_types','validation_error_msg_elem')
  {var ($HDR[2],$col2) = getDbColumns('CM','fcc_integration_types',\
     'integration_type_id','integration_type_code','user_created',\
     'application_id','deleted','execution_type','end_user_url',\
     'service_wsdl_loc','service_uri','service_port','service_name',\
     'soap_action','callback_port','callback_name','response_xsl_template',\
     'response_namespaces','validation_wsdl_loc','validation_uri',\
     'validation_port','validation_name','validation_soap_action',\
     'validation_response_elem','validation_param_code_elem',\
     'validation_error_msg_elem')
  }
  else
  {var ($HDR[2],$col2) = getDbColumns('CM','fcc_integration_types',\
     'integration_type_id','integration_type_code','user_created',\
     'application_id','deleted','execution_type','end_user_url',\
     'service_wsdl_loc','service_uri','service_port','service_name',\
     'soap_action','callback_port','callback_name','response_xsl_template',\
     'response_namespaces','response_uri','response_root_element',\
     'request_uri','request_namespace','root_element','sso_parameter',\
     'validation_status','validation_msg','validation_log_location',\
     'validation_report_location')
  }
  call clearDbColumns('CM')
  append $sql
  {# MACRO separator(2)
   # SQL2
   "SELECT :2
   " FROM fcc_integration_types
   " ORDER BY integration_type_code
   "/
  }
  call separator(1)
  call writeDb(bindDb($sql,$col1,$col2))
  call separator(0,'Integration Information')

=head2 tasktype - Task Type Information

Collects task type information from the database.

=cut

  debug ' Inside FCM module, getting task type information'
  report tasktype
  var @HDR = ()
  call encodeDbColumns("\012",'CM','description','task_type_name')
  var ($HDR[1],$col1) = getDbColumns('CM','fcc_task_types',\
    'task_type_id','task_type_name','description','integration_type_id',\
    'execution_type','user_created','aggregate_task','deleted',\
    'notification_msg_id','approver_msg_id','error_msg_id')
  call clearDbColumns('CM')
  set $sql
  {# SQL1
   "SELECT :1
   " FROM fcc_task_types
   " ORDER BY task_type_name
   "/
  }
  prefix
  {write '---+ Task Type Information'
   write $HDR[1]
  }
  call writeDb(bindDb($sql,$col1))
  call separator(0,'Task Type Information')

=head2 task - Task Information

Collects task information from the database.

=cut

  debug ' Inside FCM module, getting task information'
  report task
  var $TTL = '---+!! Task Information'
  var @TTL = ('',\
             '---+ Tasks with Errors',\
             '---+ Tasks and Predecessors with Errors')
  var @HDR = ()

  call encodeDbColumns(["|[]<>\012\040",'LTRIM(%s)'],'CM','error_msg')
  var ($HDR[1],$col1) = getDbColumns('CM','fcc_tasks',\
    'source_id','task_id','task_name','error_msg','description',\
    'task_type_id','aggregation_parent','actual_start_date','actual_end_date',\
    'start_date','end_date','scheduled_start_date','scheduled_end_date',\
    'duration','skip_flag','deleted')
  call clearDbColumns('CM')

  var ($HDR[2],$col2) = getDbView({p =>'fcc_task_predecessors',\
                                   t1=>'fcc_tasks',\
                                   t2=>'fcc_tasks'},\
    {fct=>'SEL',tid=>'t1',col=>'source_id',hdr=>' *Predecessor Source Id*'},\
    {fct=>'SEL',tid=>'t1',col=>'task_id',  hdr=>' *Predecessor Task Id*'},\
    {fct=>'SEL',tid=>'t1',col=>'task_name',hdr=>' *Predecessor Task Name*'},\
    {fct=>'SEL',tid=>'t1',col=>'status_id',hdr=>' *Predecessor Status Id*'},\
    'p.predecessor_task_type',\
    't2.source_id','t2.task_id','t2.task_name','t2.status_id')
  call clearDbColumns('p')
  call clearDbColumns('t1')
  call clearDbColumns('t2')

  set $sql
  {# SQL1
   "SELECT :1
   " FROM fcc_tasks
   " WHERE status_id IN (9, 13, 17, 33)
   "   AND source_type = 'DEPLOYMENT'
   " ORDER BY source_id,task_id
   "/
   # MACRO separator(2)
   # SQL2
   "SELECT :2
   " FROM fcc_tasks t1, fcc_task_predecessors p, fcc_tasks t2
   " WHERE p.predecessor_task_id = t1.task_id
   "   AND p.task_id = t2.task_id
   "   AND t1.source_type = 'DEPLOYMENT'
   "   AND t2.source_type = 'DEPLOYMENT'
   "   AND (t1.status_id IN (9, 13, 17, 33) OR t2.status_id IN (9, 13, 17, 33))
   " ORDER BY t1.source_id, t1.task_id
   "/
  }
  call separator(1)
  call writeDb(bindDb($sql,$col1,$col2))
  call separator(0,'Task Information')
 }
}

=head2 registry - Windows Registry Information

Collects Windows registry information.

=cut

debug ' Inside FCM module, gathering Windows registry information'
report registry
prefix
{write '---+!! Windows Registry Information'
 write $TOC
 write '---+ Hyperion Financial Close Management Product Information'
}
if hasRegOption()
{if writeRegistry64('HKLM\SOFTWARE\Hyperion Solutions')
  write $TOP
 if writeRegistry32('HKLM\SOFTWARE\Hyperion Solutions')
  write $TOP
 if writeRegistry64('HKCU\SOFTWARE\Hyperion Solutions')
  write $TOP
 if writeRegistry32('HKCU\SOFTWARE\Hyperion Solutions')
  write $TOP
}
else
{if writeRegistry('HKLM\SOFTWARE\Hyperion Solutions')
  write $TOP
 if writeRegistry('HKLM\SOFTWARE\Wow6432Node\Hyperion Solutions')
  write $TOP
 if writeRegistry('HKCU\SOFTWARE\Hyperion Solutions')
  write $TOP
 if writeRegistry('HKCU\SOFTWARE\Wow6432Node\Hyperion Solutions')
  write $TOP
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Windows Registry Information]]'

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
  toc '%INCLUDE("OFM_WREQ_BI_FCM_WH_TF.toc")%'
  toc '%POP2%'
  toc '%PUSH("%SPLIT%")%'
  toc '%PUSH("1+:',"'",$dom,"'",' Domain")%'
  toc '%INCLUDE("OFM_WREQ_BI_FCM_DOM_TF.toc")%'
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
  pretoc '%SPLIT%'
  pretoc "1+:'",basename($ins),"' Deployment"

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Financial Close Management
instance collection.

=cut

  debug ' Inside FCM module, collecting defined instance abbreviations'
  report abbr
  prefix
  {write '---+ Financial Close Management Instance Abbreviations'
   write '|*Abbreviation*|*Location*|'
  }
  var %hsh = getSymbols()
  loop $key (keys(%hsh))
   write '|',$key,' |',$hsh{$key},' |'
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 diaglogs - Diagnostic Log Files

Collects the diagnostic log files from F<$INSTANCE_HOME/diagnostics/logs>
directory.

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
   toc '2:[[',getFile(),'][rda_report][Diagnostic Log Files]]'

=head2 Oracle WebLogic Server Information

Includes the Oracle WebLogic reports generated by the
L<abr:WREQ|collect::OFM:DCwreq> module for the associated Oracle WebLogic
Server domain.

=cut

  if ${CUR.O_SETUP}->search(concat('^WREQ_BI_FCM_',replace($uid,'^OI','DOM')))
  {var ($req) = last
   var $dom = $req->get_first('I_DOMAIN')
   var $oid = $dom->get_first('I_WL_HOME')->get_oid
   var $nam = $dom->get_first('T_DOMAIN_NAME')
   toc '%PUSH("%SPLIT%")%'
   toc '%PUSH("1++:Oracle WebLogic Server Overview")%'
   toc '%INCLUDE("OFM_WREQ_BI_FCM_',$oid,'_TF.toc",1)%'
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

unpretoc

=head1 SEE ALSO

L<DB:DBinfo|collect::DB:DBinfo>,
L<OFM:DCwreq|collect::OFM:DCwreq>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
