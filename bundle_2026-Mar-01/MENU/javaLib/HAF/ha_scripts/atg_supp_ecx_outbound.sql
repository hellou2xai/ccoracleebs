REM HEADER
REM   $Header: atg_supp_ecx_outbound.sql 7.0 SUBSAHU $
REM   
REM MODIFICATION LOG:
REM 15-OCT-2008 gggrant ECX_DOCLOGS document_number column can be NULL so used ECX_OUTBOUND_LOGS.
REM			WF_ITEMS poorly formatted and too costly using wf_item_attribute_values. 
REM 18-JAN-2009 gggrant Tuned WF_ITEMS to provide event_name and parent_item_type/keys for document 
REM                     Re-organized categories to show data flow.
REM  			Added Web Servics queue for SOAP protocol type
REM 19-JAN-2009 gggrant	Added iAS FND Logging for 11i and R12
REM 22-JAN-2009	gggrant	Added aq_tm_processes which cannot be 0 and getting document_number, protocol
REM			address, protocol type from ecx_outqueue. 
REM			May wf_deferred and wf_jms both selectable from apps.  Not everyone uses APPLSYS for
REM 			FNDUSR so removing all hard coded schema references.
REM 23-JAN-2009	gggrant	Added delay for transmission failures and changed all data formats to be consistent with
REM			other scripts.  Original set it globally but better to leave it in than get it wrong.
REM 24-JAN-2009	gggrant	Added max_delay and max_retry to ecx_outqueue.
REM 01-FEB-2009	gggrant	Listed the last 10 document_numbers generated in the last 10 days.
REM 05-FEB-2009	gggrant	Added HUB protocol info to trading partner defintion section
REM	
REM			
REM   atg_supp_ecx_outbound.sql
REM     
REM   	This script was created to collect the required information
REM     on an Outbound XML Gateway Tranasaction for a specific Document Number
REM
REM   How to run it?
REM   
REM   	sqlplus apps/<password>
REM
REM   	@atg_supp_ecx_outbound.sql
REM
REM  Parameter:
REM
REM   	Document_Number
REM   
REM   Output file 
REM   
REM	ecx_<Document_Number>_outbound.html
REM
REM
REM     Created: Oct 11th, 2008
REM     Last Updated: Feb 05th, 2009
REM
REM


set arraysize 1
set heading off
set feedback off  
set verify off
SET CONCAT ON
SET CONCAT .

prompt Last 10 Document_Numbers generated in the last 10 days

select DOCUMENT_NUMBER from ECX_OUTBOUND_LOGS where rownum < 11
and TIME_STAMP > SYSDATE - 10
order by to_char(TIME_STAMP,'DD-MON-YYYY HH24:MI:SS') desc;


set lines 120
set pages 9999
def Document_Number= "&&Document_Number"
def outputfile = "ecx_outbound.html"
spool &&outputfile


prompt <FONT SIZE=3 FACE=ARIAL>

prompt Document_Number: &&Document_Number

alter session set NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

prompt </FONT>

prompt <HTML>
prompt <HEAD>
prompt <TITLE>ECX Outbound Transaction Information</TITLE>
prompt <STYLE TYPE="text/css">
prompt <!-- TD {font-size: 8pt; font-family: arial; font-style: normal} -->
prompt </STYLE>
prompt </HEAD>
prompt <BODY>


prompt <P><P>
prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=10 BGCOLOR=PURPLE><FONT COLOR=WHITE FACE=ARIAL>
prompt <B>ECX Inbound Transaction Information
prompt <BR>Quick Links to Tables</B></TD></TR>
prompt <TR>
prompt <TD><A HREF="#ecxpc">ECX_PROFILE_CHECK</A></TD>
prompt <TD><A HREF="#ecxq">ECX_QUEUE</A></TD>
prompt <TD><A HREF="#parser">XMLPARSER_VERSION</A></TD>
prompt <TD><A HREF="#pkg">PACKAGE_VERSIONS</A></TD>
prompt <TD><A HREF="#otastat">OTA STATUS</A></TD>
prompt <TD><A HREF="#wfi">WF_ITEMS</A></TD>
prompt <TD><A HREF="#wfd">WF_DEFERRED</A></TD>
prompt <TD><A HREF="#wfws">WF_WS_JMS_OUT</A></TD></TR>
prompt <TR><TD><A HREF="#ecxoxta">ECX_OXTA_LOGMSG</A></TD>
prompt <TD><A HREF="#ecxol">ECX_OUTBOUND_LOGS</A></TD>
prompt <TD><A HREF="#ecxdoc">ECX_DOCLOGS</A></TD>
prompt <TD><A HREF="#ecxoq">ECX_OUTQUEUE</A></TD>
prompt <TD><A HREF="#ecxtp">TRADING_PARTNER_DETAILS</A></TD>
prompt <TD><A HREF="#add">ADDITIONAL_DATA_COLLECTION</A></TD>
prompt </TR>
prompt </TABLE><P><P>


REM
REM ******* ECX_PROFILE_CHECK *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="ecxpc"> ECX_PROFILE_CHECK</A></B></TD></TR>
prompt <TR>
prompt <TD><B>USER_PROFILE_OPTION_NAME</B></TD>
prompt <TD><B>PROFILE_OPTION_VALUE</B></TD>
select  
'<TR><TD>'||z.USER_PROFILE_OPTION_NAME||'</TD>'||chr(10)||
'<TD>'||nvl(v.PROFILE_OPTION_VALUE,'Not set')||'</TD></TR>'
from fnd_profile_options t, fnd_profile_option_values v, fnd_profile_options_tl z
where t.profile_option_name in ('ECX_UTL_XSLT_DIR','ECX_SERVER_TIMEZONE','ECX_SYS_ADMIN_EMAIL','ECX_UTL_LOG_DIR','ECX_XML_VALIDATE_FLAG','ECX_XML_MAXIMUM_SIZE','ECX_USER_CHECK')
and (v.profile_option_id(+) = t.profile_option_id)
and (z.profile_option_name=t.profile_option_name)
and z.language='US';
prompt </TABLE><P><P>

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <TR>
prompt <TD><B>NAME</B></TD>
prompt <TD><B>VALUE</B></TD>
select  
'<TR><TD>'||NAME||'</TD>'||chr(10)||
'<TD>'||VALUE||'</TD></TR>'
from  v$parameter
where  name = 'utl_file_dir';
prompt </TABLE><P><P>

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <TR>
prompt <TD><B>INSTANCE_NAME</B></TD>
prompt <TD><B>NAME</B></TD>
prompt <TD><B>VALUE</B></TD>
select  
'<TR><TD>'||INSTANCE_NAME||'</TD>'||chr(10)||
'<TD>'||NAME||'</TD>'||chr(10)||
'<TD>'||VALUE||'</TD></TR>'
from  gv$parameter p, gv$instance i
where  name in ('aq_tm_processes', 'job_queue_processes')
and i.inst_id=p.inst_id
order by name;
prompt </TABLE><P><P>


REM
REM ******* ECX_QUEUE *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="ecxq"> ECX_QUEUE - Metadata Information about the ECX Outbound Queue</A></B></TD></TR>
prompt <TR>
prompt <TD><B>OWNER</B></TD>
prompt <TD><B>QUEUE_NAME</B></TD>
prompt <TD><B>QUEUE_TABLE_NAME</B></TD>
prompt <TD><B>ENQUEUE_ENABLED</B></TD>
prompt <TD><B>DEQUEUE_ENABLED</B></TD>
prompt <TD><B>RETRY_DELAY</B></TD>
prompt <TD><B>MAX_RETRIES</B></TD>
prompt <TD><B>RETENTION</B></TD>
select  
'<TR><TD>'||owner||'</TD>'||chr(10)||
'<TD>'||name||'</TD>'||chr(10)||
'<TD>'||queue_table||'</TD>'||chr(10)||
'<TD>'||enqueue_enabled||'</TD>'||chr(10)||
'<TD>'||dequeue_enabled||'</TD>'||chr(10)||
'<TD>'||to_char(RETRY_DELAY)||'</TD>'||chr(10)||
'<TD>'||to_char(MAX_RETRIES)||'</TD>'||chr(10)||
'<TD>'||retention||'</TD></TR>'
from dba_queues 
where name ='ECX_OUTBOUND';
prompt </TABLE><P><P>


REM
REM ******* XMLPARSER_VERSIONS *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="parser"> XML Parser Version </A></B></TD></TR>
select  
'<TR><TD>'||ECX_UTILS.XMLVersion()||'</TD>'||chr(10)||'</TD></TR>'
from dual;
prompt </TABLE><P><P>

REM
REM ******* PACKAGE_VERSIONS *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="pkg"> Package Versions </A></B></TD></TR>
prompt <TR>
prompt <TD><B>PACKAGE_NAME</B></TD>
prompt <TD><B>TEXT</B></TD></TR>
select 
'<TR><TD>'||NAME||'</TD>'||chr(10)|| 
'<TD>'||TEXT||'</TD>'||chr(10)||'</TD></TR>'
from dba_source
where name in ('ECX_OUTBOUND')
and line = 2;
prompt </TABLE><P><P>


REM
REM ******* OTA STATUS *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="otastat"> OTA STATUS - Gives the number of OTA instances running. Confirm that OTA started.</A></B></TD></TR>
prompt <TR>
prompt <TD><B>MACHINE</B></TD>
prompt <TD><B>ACTION</B></TD>
prompt <TD><B>STATUS</B></TD>
select  
'<TR><TD>'||machine||'</TD>'||chr(10)||
'<TD>'||action||'</TD>'||chr(10)||
'<TD>'||decode(count(*),0,'Error: OTA is Not Running','OTA is Running')||'</TD></TR>'
from gv$session 
where action like '%OXTA%'
group by machine, action;
prompt </TABLE><P><P>


REM
REM ******* ECX_DOCLOGS*******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=15 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="ecxdoc">ECX_DOCLOGS- Gives document summary for the Outbound transaction</A></B></TD></TR>
prompt <TR>
prompt <TD><B>DOCUMENT_NUMBER</B></TD>
prompt <TD><B>TRANSACTION_TYPE</B></TD>
prompt <TD><B>TRANSACTION_SUBTYPE</B></TD>
prompt <TD><B>PARTY_ID</B></TD>
prompt <TD><B>PARTY_SITE_ID</B></TD>
prompt <TD><B>PARTY_TYPE</B></TD>
prompt <TD><B>MESSAGE_TYPE</B></TD>
prompt <TD><B>MESSAGE_STANDARD</B></TD>
prompt <TD><B>STATUS</B></TD>
prompt <TD><B>DIRECTION</B></TD>
prompt <TD><B>TIME_STAMP</B></TD>
prompt <TD><B>PROTOCOL_TYPE</B></TD>
prompt <TD><B>PROTOCOL_ADDRESS</B></TD>
select
'<TR><TD>'||OUTLOGS.document_number||'</TD>'||chr(10)||
'<TD>'||OUTLOGS.transaction_type||'</TD>'||chr(10)||
'<TD>'||OUTLOGS.transaction_subtype||'</TD>'||chr(10)||
'<TD>'||partyid||'</TD>'||chr(10)||
'<TD>'||OUTLOGS.party_site_id||'</TD>'||chr(10)||
'<TD>'||OUTLOGS.party_type||'</TD>'||chr(10)||
'<TD>'||message_type||'</TD>'||chr(10)||
'<TD>'||message_standard||'</TD>'||chr(10)||
'<TD>'||OUTLOGS.status||'</TD>'||chr(10)||
'<TD>'||direction||'</TD>'||chr(10)||
'<TD>'||to_char(OUTLOGS.time_stamp,'DD-MON HH24:MI:SS')||'</TD>'||chr(10)||
'<TD>'||protocol_type||'</TD>'||chr(10)||
'<TD>'||protocol_address||'</TD></TR>'
from ECX_DOCLOGS DOCLOG, ECX_OUTBOUND_LOGS OUTLOGS
where OUTLOGS.document_number='&&Document_Number'
and OUTLOGS.OUT_MSGID = DOCLOG.MSGID(+);
prompt </TABLE><P><P>


REM
REM ******* WF_ITEMS *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="wfi">WF_ITEMS - Details of any workflow processes associated with the Document Number</A></B></TD></TR>
prompt <TR>
prompt <TD><B>ITEM_TYPE</B></TD>
prompt <TD><B>ITEM_KEY</B></TD>
prompt <TD><B>EVENT_NAME</B></TD>
prompt <TD><B>ROOT_ACTIVITY</B></TD>
prompt <TD><B>PARENT_ITEM_TYPE</B></TD>
prompt <TD><B>PARENT_ITEM_KEY</B></TD>
prompt <TD><B>BEGIN_DATE</B></TD>
prompt <TD><B>END_DATE</B></TD></TR>
select
'<TD>'||itm.item_type||'</TD>'||chr(10)||
'<TD>'||itm.item_key||'</TD>'||chr(10)||
'<TD>'||doclog.event_name||'</TD>'||chr(10)||
'<TD>'||itm.root_activity||'</TD>'||chr(10)||
'<TD>'||itm.parent_item_type||'</TD>'||chr(10)||
'<TD>'||itm.parent_item_key||'</TD>'||chr(10)||
'<TD>'||to_char(itm.begin_date,'DD-MON-YYYY HH24:MI:SS')||'</TD>'||chr(10)||
'<TD>'||to_char(itm.end_date,'DD-MON-YYYY HH24:MI:SS')||'</TD></TR>'
FROM WF_ITEMS ITM,WF_ITEM_ATTRIBUTE_VALUES ATR,ECX_DOCLOGS DOCLOG
WHERE ATR.ITEM_TYPE = ITM.ITEM_TYPE
and ATR.ITEM_KEY = ITM.ITEM_KEY
and ATR.NAME = 'ECX_DOCUMENT_ID'
and ATR.TEXT_VALUE = DOCLOG.DOCUMENT_NUMBER(+)
and DOCLOG.DOCUMENT_NUMBER = '&&Document_Number'
order by itm.parent_item_key;
prompt </TABLE><P><P>


REM
REM ******* WF_DEFERRED *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="wfd">WF_DEFERRED - Content on the Queue to see if Events are on the queue waiting to be processed</A></B></TD></TR>
prompt <TR>
prompt <TD>CORRID</TD>
prompt <TD>STATE</TD>
prompt <TD>COUNT(*)</TD>
select  
'<TR><TD>'||wfd.corrid||'</TD>'||chr(10)||
'<TD>'||decode(wfd.state,0, '0 = Ready',1, '1 = Delayed',2, '2 = Retained',3, '3 = Exception',to_char(substr(state,1,12))) ||'</TD>'||chr(10)||
'<TD>'||count(*)||'</TD></TR>'
from wf_deferred wfd
group by wfd.corrid, wfd.state;
prompt </TABLE><P><P>


REM
REM ******* WF_WS_JMS_OUT *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="wfws">WF_WS_JMS_OUT - Content on the Queue to see if SOAP messages are waiting to be processed</A></B></TD></TR>
prompt <TR>
prompt <TD>CORRID</TD>
prompt <TD>STATE</TD>
prompt <TD>COUNT(*)</TD>
select  
'<TR><TD>'||wfws.corrid||'</TD>'||chr(10)||
'<TD>'||decode(wfws.state,0, '0 = Ready',1, '1 = Delayed',2, '2 = Retained',3, '3 = Exception',to_char(substr(state,1,12))) ||'</TD>'||chr(10)||
'<TD>'||count(*)||'</TD></TR>'
from wf_ws_jms_out wfws
group by wfws.corrid, wfws.state;
prompt </TABLE><P><P>




REM
REM ******* ECX_OUTBOUND_LOGS*******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=15 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="ecxdoc">ECX_OUTBOUND_LOGS- Gives the status of the transaction as to whether it was enqueued successfully.</A></B></TD></TR>
prompt <TR>
prompt <TD><B>DOCUMENT_NUMBER</B></TD>
prompt <TD><B>STATUS</B></TD>
prompt <TD><B>TIME_STAMP</B></TD>
prompt <TD><B>ERROR_ID</B></TD>
prompt <TD><B>ERROR_MESSAGE</B></TD>
select
'<TR><TD>'||outlog.document_number||'</TD>'||chr(10)||
'<TD>'||decode(outlog.status,'0','SUCCESS','1','WARNING','2','ERROR',outlog.status)||'</TD>'||chr(10)||
'<TD>'||to_char(outlog.time_stamp,'DD-MON-YYYY HH24:MI:SS')||'</TD>'||chr(10)||
'<TD>'||outlog.error_id||'</TD>'||chr(10)||
'<TD>'||outmsg.message||'</TD></TR>'
FROM ECX_OUTBOUND_LOGS outlog,ECX_ERROR_MSGS outmsg
WHERE DOCUMENT_NUMBER ='&document_number'
and OUTMSG.ERROR_ID(+) = OUTLOG.ERROR_ID;
prompt </TABLE><P><P>



REM
REM ******* ECX_OUTQUEUE*******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="ecxoq">ECX_OUTBOUND_QUEUE- Gives current content in the ECX_OUTBOUND Queue</A></B></TD></TR>
prompt <TR>
prompt <TD><B>CORRID</B></TD>
prompt <TD><B>DOCUMENT_NUMBER</B></TD>
prompt <TD><B>PARTYID</B></TD>
prompt <TD><B>PROTOCOL_TYPE</B></TD>
prompt <TD><B>PROTOCOL_ADDRESS</B></TD>
prompt <TD><B>ENQ_TIME</B></TD>
prompt <TD><B>SYS_DATE</B></TD>
prompt <TD><B>DELAY</B></TD>
prompt <TD><B>STATE</B></TD>
prompt <TD><B>COUNT(*)</B></TD>
select  
'<TR><TD>'||ecxout.corrid||'</TD>'||chr(10)||
'<TD>'||ecxout.user_data.DOCUMENT_NUMBER||'</TD>'||chr(10)||
'<TD>'||ecxout.user_data.PARTYID||'</TD>'||chr(10)||
'<TD>'||ecxout.user_data.PROTOCOL_TYPE||'</TD>'||chr(10)||
'<TD>'||ecxout.user_data.PROTOCOL_ADDRESS||'</TD>'||chr(10)||
'<TD>'||to_char(enq_time, 'DD-MON-YYYY HH24:MI:SS')||'</TD>'||chr(10)||
'<TD>'||to_char(sysdate, 'DD-MON-YYYY HH24:MI:SS')||'</TD>'||chr(10)||
'<TD>'||to_char(delay, 'DD-MON-YYYY HH24:MI:SS')||'</TD>'||chr(10)||
'<TD>'||decode(ecxout.state,0, '0 = Ready',1, '1 = Delayed',2, '2 = Retained',3, '3 = Exception',to_char(substr(state,1,12))) ||'</TD>'||chr(10)||
'<TD>'||count(*)||'</TD></TR>'
from ECX_OUTQUEUE ecxout
group by corrid, ecxout.user_data.DOCUMENT_NUMBER, ecxout.user_data.PROTOCOL_TYPE, ecxout.user_data.PROTOCOL_ADDRESS, ecxout.user_data.PARTYID, ecxout.enq_time, sysdate, delay, state;
prompt </TABLE><P><P>

REM
REM ******* ECX_OXTA_LOGMSG*******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=12 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="ecxoxta">ECX_OXTA_LOGMSG- Gives the OTA status message for this Outbound Transaction</A></B></TD></TR>
prompt <TR>
prompt <TD><B>STATUS</B></TD>
prompt <TD><B>RESULT_CODE</B></TD>
prompt <TD><B>RESULT_TEXT</B></TD>
prompt <TD><B>TRANSACTION_TYPE</B></TD>
prompt <TD><B>PROTOCOL_TYPE</B></TD>
prompt <TD><B>PROTOCOL_ADDRESS</B></TD>
prompt <TD><B>EXCEPTION_TEXT</B></TD>
prompt <TD><B>BEGIN_DATE</B></TD>
prompt <TD><B>COMPLETED_DATE</B></TD>
select
'<TR><TD>'||otalog.status||'</TD>'||chr(10)||
'<TD>'||otalog.result_code||'</TD>'||chr(10)||
'<TD>'||otalog.result_text||'</TD>'||chr(10)||
'<TD>'||otalog.transaction_type||'</TD>'||chr(10)||
'<TD>'||otalog.protocol_type||'</TD>'||chr(10)||
'<TD>'||otalog.protocol_address||'</TD>'||chr(10)||
'<TD>'||otalog.exception_text||'</TD>'||chr(10)||
'<TD>'||to_char(otalog.begin_date, 'DD-MON-YYYY HH24:MI:SS')||'</TD>'||chr(10)||
'<TD>'||to_char(otalog.completed_date, 'DD-MON-YYYY HH24:MI:SS')||'</TD></TR>'
from ECX_OXTA_LOGMSG OTALOG,ECX_DOCLOGS DOCLOG, ECX_OUTBOUND_LOGS OUTLOGS
where OTALOG.SENDER_MESSAGE_ID = DOCLOG.MSGID
and OUTLOGS.OUT_MSGID = DOCLOG.MSGID(+)
and OUTLOGS.document_number='&&Document_Number'
order by otalog.begin_date;
prompt </TABLE><P><P>

REM
REM ******* TRADING_PARTNER_DETAILS *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B><A NAME="ecxtp">TRADING_PARTNER_DETAILS - Gives details of the trading partner setup for this Outbound Transaction</A></B></TD></TR>
prompt <TR>
prompt <TD><B>PARTY_ID</B></TD>
prompt <TD><B>PARTY_SITE_ID</B></TD>
prompt <TD><B>STANDARD_CODE</B></TD>
prompt <TD><B>SOURCE_TP_LOCATION_CODE</B></TD>
prompt <TD><B>CONNECTION_TYPE</B></TD>
prompt <TD><B>DIRECT_PROTOCOL_TYPE</B></TD>
prompt <TD><B>DIRECT_PROTOCOL_ADDRESS</B></TD>
prompt <TD><B>HUB_PROTOCOL_TYPE</B></TD>
prompt <TD><B>HUB_PROTOCOL_ADDRESS</B></TD>
prompt <TD><B>MAP_CODE</B></TD>
prompt <TD><B>DIRECTION</B></TD>
prompt <TD><B>TRANSACTION_TYPE</B></TD>
prompt <TD><B>TRANSACTION_SUBTYPE</B></TD></TR>
select
'<TD>'||TPH.PARTY_ID||'</TD>'||chr(10)||
'<TD>'||TPH.PARTY_SITE_ID||'</TD>'||chr(10)||
'<TD>'||STD.STANDARD_CODE||'</TD>'||chr(10)||
'<TD>'||TPD.SOURCE_TP_LOCATION_CODE||'</TD>'||chr(10)||
'<TD>'||TPD.CONNECTION_TYPE||'</TD>'||chr(10)||
'<TD>'||TPD.PROTOCOL_TYPE||'</TD>'||chr(10)||
'<TD>'||TPD.PROTOCOL_ADDRESS||'</TD>'||chr(10)||
'<TD>'||HUB.PROTOCOL_TYPE||'</TD>'||chr(10)||
'<TD>'||HUB.PROTOCOL_ADDRESS||'</TD>'||chr(10)||
'<TD>'||MAP.MAP_CODE||'</TD>'||chr(10)||
'<TD>'||EXT.DIRECTION||'</TD>'||chr(10)||
'<TD>'||TRN.TRANSACTION_TYPE||'</TD>'||chr(10)||
'<TD>'||TRN.TRANSACTION_SUBTYPE||'</TD></TR>'
FROM ECX_TP_DETAILS TPD
    ,ECX_TP_HEADERS TPH
    ,ECX_DOCLOGS  DL
    ,ECX_MAPPINGS   MAP
    ,ECX_EXT_PROCESSES EXT
    ,ECX_TRANSACTIONS  TRN
    ,ECX_STANDARDS STD
    ,ECX_OUTBOUND_LOGS OUTLOGS
    ,ECX_HUBS HUB
WHERE MAP.MAP_ID = TPD.MAP_ID
and TPD.EXT_PROCESS_ID=EXT.EXT_PROCESS_ID
and EXT.TRANSACTION_ID = TRN.TRANSACTION_ID
and TPD.TP_HEADER_ID = TPH.TP_HEADER_ID
and TPD.SOURCE_TP_LOCATION_CODE=DL.PARTY_SITE_ID
and TRN.TRANSACTION_TYPE=DL.TRANSACTION_TYPE
--and TRN.TRANSACTION_SUBTYPE=DL.TRANSACTION_SUBTYPE
and EXT.STANDARD_ID=STD.STANDARD_ID
and OUTLOGS.OUT_MSGID = DL.MSGID(+)
AND HUB.HUB_ID=TPD.HUB_ID
and OUTLOGS.document_number='&&Document_Number';
prompt </TABLE><P><P>



REM
REM ******* ADDITIONAL_DATA_COLLECTION *******
REM

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=PURPLE><font color=white face=arial>
prompt <B><A NAME="add">ADDITIONAL_DATA_COLLECTION - These are additional details which can be collected for debugging issues with Outbound flow</A></B>
prompt </TABLE><P>

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B>FND LOGGING PROFILES - The following profiles should be set at Site Level (for FND.H and above) for ECX Logging</B>
prompt <TR>
prompt <TD><B>USER_PROFILE_OPTION_NAME</B></TD>
prompt <TD><B>PROFILE_OPTION_VALUE</B></TD>
prompt <TR><TD>FND: Debug Log Enabled</TD><TD>Y</TD></TR>
prompt <TR><TD>FND: Debug Log Level</TD><TD>1 (Statement)</TD></TR>
prompt <TR><TD>FND: Debug Log Module</TD><TD>ecx%</TD></TR>
prompt </TABLE><P><P>

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B>FND LOGGING PROFILES - The following profiles should be set at Site Level for OTA Logging</B>
prompt <TR>
prompt <TD><B>USER_PROFILE_OPTION_NAME</B></TD>
prompt <TD><B>PROFILE_OPTION_VALUE</B></TD>
prompt <TR><TD>FND: Debug Log Enabled</TD><TD>Y</TD></TR>
prompt <TR><TD>FND: Debug Log Level</TD><TD>1 (Statement)</TD></TR>
prompt <TR><TD>FND: Debug Log Module</TD><TD>ecx.oxta%</TD></TR>
prompt <TR><TD>FND: Debug Log Filename for Middle-Tier</TD><TD>filename on middle tier</TD></TR>
prompt </TABLE><P><P>

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B>OTA LOGGING - Check the following parameters to enable OTA Logging from the Web Server (for 11i106/ATG RUP6 and above) and collect the following logs.</B>
prompt <TR>
prompt <TD><B>FILE_NAME</B></TD>
prompt <TD><B>PARAMETERS</B></TD>
prompt <TD><B>DESCRIPTION</B></TD></TR>
prompt <TR><TD>$IAS_ORACLE_HOME/Apache/Jserv/etc/xmlsvcs.properties</TD><TD>wrapper.bin.parameters=-DOXTALogDebugMsg=true</TD><TD>Debug Parameter for OTA</TD></TR>
prompt <TR><TD>$IAS_ORACLE_HOME/Apache/Jserv/etc/xmlsvcs.properties</TD><TD>wrapper.bin.parameters=-DAFLOG_ENABLED=true</TD><TD>Enable FND Logging</TD></TR>
prompt <TR><TD>$IAS_ORACLE_HOME/Apache/Jserv/etc/xmlsvcs.properties</TD><TD>wrapper.bin.parameters=-DAFLOG_LEVEL=1</TD><TD>Statement Level FND Logging</TD></TR>
prompt <TR><TD>$IAS_ORACLE_HOME/Apache/Jserv/etc/xmlsvcs.properties</TD><TD>wrapper.bin.parameters=-DAFLOG_MODULE=ecx%</TD><TD>ECX Module FND Logging</TD></TR>
prompt <TR><TD>$IAS_ORACLE_HOME/Apache/Jserv/etc/xmlsvcs.properties</TD><TD>wrapper.bin.parameters=-DAFLOG_FILENAME=/tmp/ecx_11i.log</TD><TD>OTA iAS node logfile for FND Logging</TD></TR>
prompt </TABLE><P><P>

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B>OTA LOGGING - Check the following parameters to enable OTA Logging from the Web Server (for R12) and collect the following logs.</B>
prompt <TR>
prompt <TD><B>FILE_NAME</B></TD>
prompt <TD><B>PARAMETERS</B></TD>
prompt <TD><B>DESCRIPTION</B></TD></TR>
prompt <TR><TD>$INST_TOP/ora/10.1.3/j2ee/oafm/config/oc4j.properties</TD><TD>AFLOG_ENABLED=true</TD><TD>Enable FND Logging</TD></TR>
prompt <TR><TD>$INST_TOP/ora/10.1.3/j2ee/oafm/config/oc4j.properties</TD><TD>AFLOG_LEVEL=1</TD><TD>Statement Level FND Logging</TD></TR>
prompt <TR><TD>$INST_TOP/ora/10.1.3/j2ee/oafm/config/oc4j.properties</TD><TD>AFLOG_MODULE=ecx%</TD><TD>ECX Module FND Logging</TD></TR>
prompt <TR><TD>$INST_TOP/ora/10.1.3/j2ee/oafm/config/oc4j.properties</TD><TD>AFLOG_FILENAME=/tmp/ecx_12.log</TD><TD>OTA iAS node logfile for FND Logging</TD></TR>
prompt </TABLE><P><P>


prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B>Current Values set in instance</B>
prompt <TR>
prompt <TD><B>USER_PROFILE_OPTION_NAME</B></TD>
prompt <TD><B>PROFILE_OPTION_VALUE</B></TD>
prompt <TD><B>LEVEL</B></TD>
select  
'<TR><TD>'||z.USER_PROFILE_OPTION_NAME||'</TD>'||chr(10)||
'<TD>'||nvl(v.PROFILE_OPTION_VALUE,'Not set')||chr(10)||
'<TD>'||decode(level_id,10001,'Site',10002,'Appl',10003,'Resp',10004,'User',10005,'Server',10006,'Organization',level_id)||'</TD></TR>'
from fnd_profile_options t, fnd_profile_option_values v, fnd_profile_options_tl z
where t.profile_option_name in ('AFLOG_ENABLED','AFLOG_LEVEL','AFLOG_MODULE','AFLOG_FILENAME')
and (v.profile_option_id(+) = t.profile_option_id)
and (z.profile_option_name=t.profile_option_name)
and z.language='US';
prompt </TABLE><P><P>

prompt <TABLE BORDER=1>
prompt <TR><TD COLSPAN=13 BGCOLOR=BLUE><font color=white face=arial>
prompt <B>OTA LOGGING - Check the following parameters to enable OTA Logging (FND H to 11i103/ATG RUP3) and collect the following logs.</B>
prompt <TR>
prompt <TD><B>FILE_NAME</B></TD>
prompt <TD><B>PARAMETERS</B></TD>
prompt <TD><B>DESCRIPTION</B></TD></TR>
prompt <TR><TD>$IAS_ORACLE_HOME/Apache/Jserv/etc/xmlsvcs.properties</TD><TD>wrapper.bin.parameters=-DOXTALogDebugMsg=true</TD><TD>Debug Parameter for OTA</TD></TR>
prompt <TR><TD>$IAS_ORACLE_HOME/Apache/Jserv/logs/jvm/XmlSvcsGrp.0.stdout|stderr</TD><TD> -- </TD><TD>Log Files generated from XML Gateway JVM</TD></TR>
prompt </TABLE><P><P>

undef username
spool off
set heading on
set feedback on  
set verify on
exit
;
