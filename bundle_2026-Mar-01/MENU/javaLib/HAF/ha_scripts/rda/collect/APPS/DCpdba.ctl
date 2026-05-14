# DCpdba.ctl:725:Collects PeopleSoft Information from an Oracle Database
# $Id: DCpdba.ctl,v 1.3 2014/06/24 10:38:15 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCpdba.ctl,v 1.3 2014/06/24 10:38:15 RDA Exp $
#
# Change History
# 20140618  KRA  Improve 'Security Information' section.

=head1 NAME

APPS:DCpdba - Collects PeopleSoft Information from an Oracle Database

=head1 DESCRIPTION

This module collects PeopleSoft diagnostic information from an Oracle
Database. It requires that the DB module is configured with an user having
privileges to select data from the PeopleSoft schema.

The following reports can be generated and are regrouped under
C<PeopleSoft/Oracle Database>:

=cut

if !${I_DB/E}
{echo 'PeopleSoft Database information is not collected when no database is \
       analyzed'
 return
}

echo tput('bold'),'Processing APPS.PDBA module ...',tput('off')

# Initialization
var $USER_NAME = uc(${T_USER})

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '^1:PeopleSoft'
pretoc '1+:Oracle Database'

# Validate the user name
if !match($USER_NAME,'^[A-Z0-9][\w\$\#]{0,127}$')
{echo "The PeopleSoft username contains invalid characters."
 return
}

debug 'Inside PDBA module, checking PeopleSoft user existence'
set $sql
{SELECT 'UserExists'
" FROM dba_users
" WHERE username = ':1';
}
if !grepSql(bindSql($sql,$USER_NAME),'UserExists','f')
{var ${STA.APPS.PDBA.T_RUN:'Execution error'} = \
       concat('The user ',$USER_NAME,' is not a valid database user.')
 return
}

# Load the common macros
run DB:DBinfo()

=head2 version - Version Information

Collects version information.

=cut

debug ' Inside PDBA module, collecting version information'
report version
var $TTL = '---+!! Version Information'
var @TTL = ('',\
            '---+ Release Information',\
            '---+ Patch Informtaion',\
            '---+ Project Information')
var @HDR = ('',\
            '|*Release Date Stamp*|*Release Label*|',\
            '| *Patch/Bundle*|*Description*|*Date Imported*|*User*|',\
            '|*Project Name*|*Description*| *Version*|*Last Date*|\
              *Update Date*|*Release Date*|')
set $sql
{SELECT '|' ||
"       TO_CHAR(releasedttm,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
"       releaselabel || ' |'
" FROM :1.psrelease
" WHERE releasedttm = (SELECT MAX(releasedttm) FROM :1.psrelease);
"PROMPT ___Macro_separator(2)___
"SELECT '| ' ||
"       update_id || '|' ||
"       descr || ' |' ||
"       TO_CHAR(dttm_imported,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
"       applyoprid || ' |'
" FROM :1.ps_maintenance_log
" ORDER BY descr;
"PROMPT ___Macro_separator(3)___
"SELECT '|' ||
"       projectname || ' |' ||
"       projectdescr || ' | ' ||
"       version || '|' ||
"       TO_CHAR(compreldttm,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
"       TO_CHAR(lastupddttm,'DD-Mon-YYYY HH24:MI:SS') || ' |' ||
"       TO_CHAR(releasedttm ,'DD-Mon-YYYY HH24:MI:SS') || ' |'
" FROM :1.psprojectdefn
" WHERE projectname LIKE 'PRJ%';
}
call separator(1)
call writeSql(bindSql($sql,$USER_NAME))
call separator(0,'Version Information')

=head2 install - Installation Information

Collects installation information.

=cut

debug ' Inside PDBA module, collecting installation information'
report install
var $TTL = '---+!! Installation Information'
var @TTL = ('',\
            '---+ PeopleSoft Options',\
            '---+ Installation Information',\
            '---+ Node Definition')
var $sql = ''

var ($HDR[1],$col1) = getSqlColumns('RDA',$USER_NAME,'PSOPTIONS')
if $col1
{append $sql
 {SELECT :2
 " FROM :1.psoptions;
 }
}
call clearSqlColumns('RDA')

var ($HDR[2],$col2) = getSqlColumns('RDA',$USER_NAME,'PS_INSTALLATION')
if $col2
{append $sql
 {PROMPT ___Macro_separator(2)___
 "SELECT :3
 " FROM :1.ps_installation;
 }
}
call clearSqlColumns('RDA')

var ($HDR[3],$col3) = getSqlColumns('RDA',$USER_NAME,'PSMSGNODEDEFN')
if $col3
{append $sql
 {PROMPT ___Macro_separator(3)___
 "SELECT :4
 " FROM :1.psmsgnodedefn;
 }
}
call clearSqlColumns('RDA')

if $sql
{call separator(1)
 call writeSql(bindSql($sql,$USER_NAME,$col1,$col2,$col3))
 call separator(0,'Installation Information')
}

=head2 scheduler - Scheduler Information

Collects scheduler information.

=cut

debug ' Inside PDBA module, collecting scheduler information'
report scheduler
var $TTL = '---+!! Scheduler Information'
var @TTL = ('',\
            '---+ Batch Server Status',\
            '---+ Process Scheduler Information',\
            '---+ Schedule Information')
var @HDR = ('',\
            '|*Server Name*|*Description*|*Short Name*| *Sleep Time*| \
              *Heart Beat*| *Max API Aware*|',\
            '|*Server Name*|*Description*|*Type*|*Priority*| \
              *Maximum Concurrent*|',\
            '|*Server Name*|*Description*|*Day*|*Start Time*|*End Time*|')
set $sql
{SELECT '|' ||
"       psq.se || ' |' ||
"       psq.de || ' |' ||
"       xlatshortname || ' | ' ||
"       psq.sl || '| ' ||
"       psq.hb || '| ' ||
"       psq.ma || '|'
" FROM (SELECT psd.servername se,
"              descr de,
"              serverstatus ss,
"              sleeptime sl,
"              heartbeat hb,
"              maxapiaware ma
"        FROM :1.ps_serverdefn psd, :1.psserverstat pss
"        WHERE psd.servername = pss.servername
"        ORDER BY psd.servername) psq,
"      :1.psxlatitem psx
" WHERE psq.ss = psx.fieldvalue
"   AND psx.fieldname = 'SERVERSTATUS';
"PROMPT ___Macro_separator(2)___
"SELECT '|' ||
"       psd.servername || ' |' ||
"       descr || ' |' ||
"       prcstype || ' |' ||
"       prcspriority || ' | ' ||
"       maxconcurrent || '|'
" FROM :1.ps_serverclass psc,
"      :1.ps_serverdefn psd,
"      :1.psserverstat pss
" WHERE psc.servername = psd.servername
"   AND psc.servername = pss.servername;
"PROMPT ___Macro_separator(3)___
"SELECT '|' ||
"       psd.servername || ' |' ||
"       descr || ' |' ||
"       DECODE(dayofweek,'0','Sun','1','Mon','2','Tue','3','Wed','4','Thu',
"            '5','Fri','6','Sat',dayofweek) || ' |' ||
"       (TRUNC(starttime/60) || ':' || (starttime- ((TRUNC(starttime/60))*60)))
"            || ' |' ||
"       (TRUNC(endtime/60) || ':' || (endtime- ((TRUNC(endtime/60))*60)))
"            || ' |'
" FROM :1.ps_serverdefn psd,
"      :1.psserverstat pss,
"      :1.ps_serveroprtn pso
" WHERE pso.servername=psd.servername
"   AND pso.servername=pss.servername;
}
call separator(1)
call writeSql(bindSql($sql,$USER_NAME))
call separator(0,'Scheduler Information')

=head2 security - Security Information

Collects security information.

=cut

debug ' Inside PDBA module, collecting security information'
report security
var $TTL = '---+!! Security Information'
var @TTL = ('',\
            '---+ Class Information',\
            '---+ Security Options',\
            '---+ Role Information',\
            '---+ Roles and Users',\
            '---+ Role Class Information')
var $sql = ''

var ($HDR[1],$col1) = getSqlColumns('RDA',$USER_NAME,'PSCLASSDEFN')
if $col1
{append $sql
 {SELECT :2
 " FROM :1.psclassdefn;
 }
}
call clearSqlColumns('RDA')

var ($HDR[2],$col2) = getSqlColumns('RDA',$USER_NAME,'PSSECOPTIONS')
if $col2
{append $sql
 {PROMPT ___Macro_separator(2)___
 "SELECT :3
 " FROM :1.pssecoptions;
 }
}
call clearSqlColumns('RDA')

var ($HDR[3],$col3) = getSqlColumns('RDA',$USER_NAME,'PSROLEDEFN')
if $col3
{append $sql
 {PROMPT ___Macro_separator(3)___
 "SELECT :4
 " FROM :1.psroledefn;
 }
}
call clearSqlColumns('RDA')

var ($HDR[4],$col4) = getSqlColumns('RDA',$USER_NAME,'PSROLEUSER')
if $col4
{append $sql
 {PROMPT ___Macro_separator(4)___
 "SELECT :5
 " FROM :1.psroleuser;
 }
}
call clearSqlColumns('RDA')

var ($HDR[5],$col5) = getSqlColumns('RDA',$USER_NAME,'PSROLECLASS')
if $col5
{append $sql
 {PROMPT ___Macro_separator(5)___
 "SELECT :6
 " FROM :1.psroleclass;
 }
}
call clearSqlColumns('RDA')

if $sql
{call separator(1)
 call writeSql(bindSql($sql,$USER_NAME,$col1,$col2,$col3,$col4,$col5))
 call separator(0,'Security Information')
}

# Disable the group title in next index
if isTocCreated(true)
 toc '-:PeopleSoft'

=head1 SEE ALSO

L<DB:DBinfo|collect::DB:DBinfo>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
