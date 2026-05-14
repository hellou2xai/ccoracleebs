REM HEADER
REM   $Header: atg_supp_wf_email_notifications.sql v3.0 GGGRANT $
REM   
REM MODIFICATION LOG:
REM	
REM 26-JUN-2009	GGGRANT	Added query for Application Framework Agent and WF: Workflow Mailer Framework Web Agent
REM			Site Profiles.
REM
REM 03-MAY-2010	GGGRANT	Changed AQ queries to remove hard coded APPLSYS.
REM			
REM	
REM			
REM   atg_supp_wf_email_notifications.sql
REM     
REM   	This script was created to collect information about the number of email notification events
REM   	on the AQ used to send notifications by email.
REM   
REM
REM   How to run it?
REM   
REM   	sqlplus apps/<password>
REM
REM   	@atg_supp_wf_email_notifications.sql
REM
REM  Parameter:
REM
REM   
REM   
REM   Output file 
REM   
REM	wf_email_notifications.html
REM
REM
REM     Created: Jun 1st, 2009
REM     Last Updated: May 3rd, 2010
REM
REM

set arraysize 1
set heading off
set feedback off  
set verify off
SET CONCAT ON
SET CONCAT .

set lines 120
set pages 9999

def outputfile = "wf_email_notifications.html"
spool &&outputfile

prompt <FONT SIZE=3 FACE=ARIAL>

prompt </FONT>

prompt <HTML>
prompt <HEAD>
prompt <TITLE>Workflow Email Notifications</TITLE>
prompt <STYLE TYPE="text/css">
prompt <!-- TD {font-size: 8pt; font-family: arial; font-style: normal} -->
prompt </STYLE>
prompt </HEAD>
prompt <BODY>


prompt <P><P>
prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=6 BGCOLOR==BLUE><FONT COLOR=WHITE FACE=ARIAL>
prompt <B>Workflow Email Notifications 
prompt <BR>Quick Links to Tables</B></TD></TR>
prompt <TR>
prompt <TD><A HREF="#wfd">WF_DEFERRED</A></TD>
prompt <TD><A HREF="#wfno">WF_NOTIFICATION_OUT</A></TD>
prompt <TD><A HREF="#wfni">WF_NOTIFICATION_IN</A></TD>
prompt <TD><A HREF="#wfnevgrp">Workflow Email Notifications Event Groups</A></TD>
prompt <TD><A HREF="#fndnode">Ebusiness Suite Node Information</A></TD>
prompt <TD><A HREF="#fndprofaa">Current FND Profile Values Set in Instance</A></TD>
prompt </TR>
prompt </TABLE><P><P>




prompt </FONT>


REM
REM ******* WF_DEFERRED *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="wfd">WF_DEFERRED - Email Notification Events and Their States</A></B></TD></TR>
prompt <TR>
prompt <TD>CORRID</TD>
prompt <TD>STATE</TD>
prompt <TD>COUNT(*)</TD>
select  
'<TR><TD>'||wfd.corrid||'</TD>'||chr(10)||
'<TD>'||decode(wfd.state,
                          0, '0 = Ready',
                          1, '1 = Delayed',
                          2, '2 = Retained',
                          3, '3 = Exception/Expired',
                          to_char(substr(wfd.state,1,12)))||'</TD>'||chr(10)||
'<TD>'||count(*)||'</TD></TR>'
from wf_deferred wfd
where wfd.user_data.event_name like 'oracle.apps.wf.notification.%'
group by wfd.corrid, wfd.state;
prompt </TABLE><P><P>



REM
REM ******* WF_NOTIFICATION_OUT *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="wfno">WF_NOTIFICATION_OUT - All Messages and Their States</A></B></TD></TR>
prompt <TR>
prompt <TD>CORRID</TD>
prompt <TD>STATE</TD>
prompt <TD>COUNT(*)</TD>
select  
'<TR><TD>'||wfno.corrid||'</TD>'||chr(10)||
'<TD>'||decode(wfno.state,
                          0, '0 = Ready',
                          1, '1 = Delayed',
                          2, '2 = Retained',
                          3, '3 = Exception/Expired',
                          to_char(substr(wfno.state,1,12)))||'</TD>'||chr(10)||
'<TD>'||count(*)||'</TD></TR>'
from wf_notification_out wfno
group by wfno.corrid, wfno.state;
prompt </TABLE><P><P>




REM
REM ******* WF_NOTIFICATION_IN *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="wfni">WF_NOTIFICATION_IN - All Messages and Their States</A></B></TD></TR>
prompt <TR>
prompt <TD>CORRID</TD>
prompt <TD>STATE</TD>
prompt <TD>COUNT(*)</TD>
select  
'<TR><TD>'||wfni.corrid||'</TD>'||chr(10)||
'<TD>'||decode(wfni.state,
                          0, '0 = Ready',
                          1, '1 = Delayed',
                          2, '2 = Retained',
                          3, '3 = Exception/Expired',
                          to_char(substr(wfni.state,1,12)))||'</TD>'||chr(10)||
'<TD>'||count(*)||'</TD></TR>'
from wf_notification_in wfni
group by wfni.corrid, wfni.state;
prompt </TABLE><P><P>



REM
REM ******* Workflow Email Event Groups *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="wfnevgrp">Workflow Email Notifications Event Groups</A></B></TD></TR>
prompt <TR>
prompt <TD>EVENT_NAME</TD>
prompt <TD>PHASE</TD>
prompt <TD>RULE_FUNCTION</TD>
prompt <TD>OUT_AGENT</TD>
prompt <TD>STATUS</TD>
select  
'<TR><TD>'||e.name||'</TD>'||chr(10)||
'<TD>'||PHASE||'</TD>'||chr(10)||
'<TD>'||DECODE(sub.guid, NULL, 'Subscription Not Defined', DECODE(sub.rule_function, NULL, 'Not  Defined', sub.rule_function || '@' || s.name))||'</TD>'||chr(10)||
'<TD>'||DECODE(sub.guid, NULL, 'Subscription Not Defined', DECODE(sub.out_agent_guid, NULL, 'Not Defined', oa.name || '@' || oas.name))||'</TD>'||chr(10)||
'<TD>'||sub.status||'</TD></TR>'
FROM   WF_EVENTS e, WF_SYSTEMS s, WF_EVENT_SUBSCRIPTIONS sub, WF_AGENTS oa, WF_SYSTEMS oas
WHERE  e.NAME IN  ('oracle.apps.wf.notification.send.group', 'oracle.apps.wf.notification.summary.send', 'oracle.apps.fnd.wf.mailer.Mailer.notification.summary', 'oracle.apps.wf.notification.receive')
AND    e.guid = sub.event_filter_guid(+)
AND    sub.licensed_flag(+) = 'Y'
AND    e.licensed_flag = 'Y'
AND    sub.system_guid = s.guid(+)
AND    oa.guid(+) = sub.out_agent_guid
AND    oa.system_guid = oas.guid(+)
ORDER BY e.name;
prompt </TABLE><P><P>


REM
REM ******* Ebusiness Suite Node Information *******
REM


prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=9 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="fndnode">Ebusiness Suite Node Information</A></B></TD></TR>
prompt <TR>
prompt <TD>NODE_NAME</TD>
prompt <TD>HOST</TD>
prompt <TD>DOMAIN</TD>
prompt <TD>WEBHOST</TD>
prompt <TD>SERVER_ID</TD>
prompt <TD>SERVER_ADDRESS</TD>
prompt <TD>SUPPORT_CP</TD>
prompt <TD>SUPPORT_FORMS</TD>
prompt <TD>SUPPORT_WEB</TD>
prompt <TD>SUPPORT_ADMIN</TD>
prompt <TD>SUPPORT_DB</TD>
prompt <TD>STATUS</TD>
select  
'<TR><TD>'||node_name||'</TD>'||chr(10)||
'<TD>'||host||'</TD>'||chr(10)||
'<TD>'||domain||'</TD>'||chr(10)||
'<TD>'||webhost||'</TD>'||chr(10)||
'<TD>'||server_id||'</TD>'||chr(10)||
'<TD>'||server_address||'</TD>'||chr(10)||
'<TD>'||support_cp||'</TD>'||chr(10)||
'<TD>'||support_forms||'</TD>'||chr(10)||
'<TD>'||support_web||'</TD>'||chr(10)||
'<TD>'||support_admin||'</TD>'||chr(10)||
'<TD>'||support_db||'</TD>'||chr(10)||
'<TD>'||status||'</TD></TR>'
from fnd_nodes;
prompt </TABLE><P><P>

REM
REM ******* FND Profile Values *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="fndprofaa">Current FND Profile Values Set in Instance</A></B>
prompt <TR>
prompt <TD><B>USER_PROFILE_OPTION_NAME</B></TD>
prompt <TD><B>PROFILE_OPTION_VALUE</B></TD>
select  
'<TR><TD>'||z.user_profile_option_name||'</TD>'||chr(10)||
'<TD>'||v.PROFILE_OPTION_VALUE||'</TD></TR>'
from fnd_profile_options t, fnd_profile_option_values v, fnd_profile_options_tl z, fnd_application fa, 
fnd_responsibility_vl fr, fnd_user fu, 
fnd_logins fl
where (v.PROFILE_OPTION_ID (+) = t.PROFILE_OPTION_ID)
and fa.application_id(+)=v.level_value 
and fr.application_id(+)=v.level_value_application_id 
and fr.responsibility_id(+)=v.level_value 
and fu.user_id(+)=v.level_value 
and fl.login_id(+) = v.LAST_UPDATE_LOGIN 
and (z.PROFILE_OPTION_NAME = t.PROFILE_OPTION_NAME)
and (t.PROFILE_OPTION_NAME in ('APPS_FRAMEWORK_AGENT'))
and z.language='US'
and v.level_id = 10001
order by v.level_id;
prompt </TABLE><P><P>

REM
REM ******* FND Profile Values *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="fndprofwf">Current FND Profile Values Set in Instance</A></B>
prompt <TR>
prompt <TD><B>USER_PROFILE_OPTION_NAME</B></TD>
prompt <TD><B>PROFILE_OPTION_VALUE</B></TD>
select  
'<TR><TD>'||z.user_profile_option_name||'</TD>'||chr(10)||
'<TD>'||nvl(v.PROFILE_OPTION_VALUE, 'Set to a node <B>http(s)://WEBHOST:port</B> if WEBHOST:port not login URL')||'</TD></TR>'
from fnd_profile_options t, fnd_profile_option_values v, fnd_profile_options_tl z, fnd_application fa, 
fnd_responsibility_vl fr, fnd_user fu, 
fnd_logins fl
where (v.PROFILE_OPTION_ID (+) = t.PROFILE_OPTION_ID)
and fa.application_id(+)=v.level_value 
and fr.application_id(+)=v.level_value_application_id 
and fr.responsibility_id(+)=v.level_value 
and fu.user_id(+)=v.level_value 
and fl.login_id(+) = v.LAST_UPDATE_LOGIN 
and (z.PROFILE_OPTION_NAME = t.PROFILE_OPTION_NAME)
and (t.PROFILE_OPTION_NAME in ('WF_MAIL_WEB_AGENT'))
and z.language='US'
order by v.level_id;
prompt </TABLE><P><P>


undef username
spool off
set heading on
set feedback on  
set verify on
exit
;
