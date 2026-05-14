# DCret.ctl:590:Collects Oracle Retail Information
# $Id: DCret.ctl,v 1.5 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCret.ctl,v 1.3 2013/10/30 07:18:21 RDA Exp $
#
# Change History
# 20190326  SJC  Add default value to get_db_version in case d/b is not running.
# 20190214  SJC  Change database version check to 9 or above.
# 20130711  MSC  Identify Oracle Database 12c.

=head1 NAME

APPS:DCret - Collects Oracle Retail Information

=head1 DESCRIPTION

This module collects Oracle Retail-related diagnostic information. The
following reports can be generated and are regrouped under C<Oracle Retail>:

=cut

if !${I_DB/E}
{echo 'Oracle Retail module is not considered when no database is analyzed'
 return
}

echo tput('bold'),'Processing APPS.RET module ...',tput('off')

# Initialization
var $USER_NAME = uc(${T_USER})

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Oracle Retail'

# Validate the user name
if !match($USER_NAME,'^[A-Z0-9][\w\$\#]{0,127}$')
{echo "The Oracle Retail username should begin with an alphanumeric character \
       and can have only alphanumeric characters, '_', '$', or '#' thereafter. \
       It can be only 128 characters long."
 return
}

# Load the common macros
run DB:DBinfo()

=head2 not_applicable - Not Applicable

The Oracle Retail module can be executed on Oracle 9i or later.

=cut

debug 'Inside Oracle Retail module, checking the database version'
var $ver = get_db_version(true,'81')
if compare('older',$ver,'90')
{report not_applicable
 write 'The Oracle Retail module can only be executed on 9i or higher. The \
        database must be accessible.'
 toc '2:[[',getFile(),'][rda_report][Not Applicable]]'
 return
}

=head2 tablespace - Tablespace Information

Provides a tablespace overview.

=cut

debug ' Inside Retail module, collecting tablespace information'
report tablespace
var $TTL = '---+!! Tablespace Information'
var @TTL = ('',\
            '---+ Total Permanent Tablespace Size Information',\
            '---+ Individual Permanent Tablespace Information',\
            '---+ Total Locally Managed Tablespace Size Information',\
            '---+ Individual Locally Managed Tablespace Information')
var @HDR = ('',\
            '| *Size in MiB*|',\
            '|*Tablespace*| *Size(MiB)*|*Extent Mgmt*|*Segment Space Mgmt*|',\
            '| *Size in MiB*|',\
            '|*Tablespace*| *Size(MiB)*|*Extent Mgmt*|*Segment Space Mgmt*|')
set $sql
{SELECT '| ' ||
"       TO_CHAR(ROUND(SUM(bytes)/1048576,1),'999999990.9') || '|'
" FROM dba_data_files;
"PROMPT ___Macro_separator(2)___
"SELECT '|' ||
"       f.tablespace_name || ' | ' ||
"       TO_CHAR(NVL(ROUND(SUM(bytes)/1048576,1),0),'999999990.9') || '|' ||
"       extent_management || ' |' ||
"       segment_space_management || ' |'
" FROM dba_data_files f,dba_tablespaces t
" WHERE f.tablespace_name = t.tablespace_name
" GROUP BY f.tablespace_name,extent_management,segment_space_management;
"PROMPT ___Macro_separator(3)___
"SELECT '| ' ||
"       TO_CHAR(ROUND(SUM(bytes)/1048576,1),'999999990.9') || '|'
" FROM dba_temp_files;
"PROMPT ___Macro_separator(4)___
"SELECT '|' ||
"       f.tablespace_name || ' | ' ||
"       TO_CHAR(NVL(ROUND(SUM(bytes)/1048576,1),0),'999999990.9') || '|' ||
"       extent_management || ' |' ||
"       segment_space_management || ' |'
" FROM dba_temp_files f,dba_tablespaces t
" WHERE f.tablespace_name = t.tablespace_name
" GROUP BY f.tablespace_name,extent_management,segment_space_management;
}
call separator(1)
call writeSql($sql)
call separator(0,'Tablespace Information')

=head2 log_info - V$Log Information

Gathers information from C<V$Log>.

=cut

debug 'Inside Oracle Retail module, collecting the V$Log information'
report log
var $TTL = '---+!! V$Log Information'
var @TTL = ('',\
            '---+ Total Redo Log Size Information')
var @HDR = ('',\
            '| *Size in MiB*|')
set $sql
{SELECT '| ' ||
"       TO_CHAR(ROUND(SUM(bytes)/1048576,1),'999999990.9') || '|'
" FROM v$log;
}
call separator(1)
call writeSql($sql)
call separator(0,'V$Log Information')

debug 'Inside Oracle Retail module, checking Oracle Retail user existence'
set $sql
{SELECT 'Userexists'
" FROM dba_users
" WHERE username = ':1';
}
if !grepSql(bindSql($sql,$USER_NAME),'Userexists','f')
{var ${STA.APPS.RET.T_RUN:'Execution error'} = \
       concat('The user ',$USER_NAME,' is not a valid database user and the \
               user specific information cannot be collected.')
 return
}

=head2 table - Table Information

Gathers information about Oracle Retail tables.

=cut

debug 'Inside Oracle Retail module, collecting the table information'
report table
var $TTL = '---+!! Table Information'
var @TTL = ('',\
            '---+ Total Table Size Information',\
            '---+ Individual Table Storage Information')
var @HDR = ('',\
            '| *Size in MiB*|',\
            '|*Table Name*| *Rows*| *Row Length*| *Size (MiB)*| *Initrans*| \
              *Freelists*| *Degree*|')
set $sql
{SELECT '| ' ||
"       TO_CHAR(NVL(ROUND(SUM(num_rows*avg_row_len/1048576/
"                    (1-NVL(pct_free,10)/100)),1),0),'999999990.9') || '|'
" FROM dba_tables
" WHERE owner = ':1';
"PROMPT ___Macro_separator(2)___
"SELECT '|' ||
"       table_name || ' | ' ||
"       NVL(num_rows,0) || '| ' ||
"       NVL(ROUND(avg_row_len/(1-NVL(pct_free,10)/100),0),0) || '| '||
"       TO_CHAR(NVL(ROUND(num_rows*avg_row_len/1048576/
"                 (1-NVL(pct_free,10)/100),1),0),'999999990.9') || '| ' ||
"       NVL(ini_trans,0) || '| ' ||
"       NVL(freelists,0) || '| '||
"       NVL(degree,0) || '|'
" FROM dba_tables
" WHERE owner = ':1'
" ORDER BY NVL(ROUND(num_rows*avg_row_len/1048576/
"                    (1-NVL(pct_free,10)/100),1),0) DESC,
"          table_name ASC;
}
call separator(1)
call writeSql(bindSql($sql,$USER_NAME))
call separator(0,'Table Information')

=head2 index - Index Information

Gathers information about Oracle Retail indexes.

=cut

debug 'Inside Oracle Retail module, collecting the index information'
report index
var $TTL = '---+!! Index Information'
var @TTL = ('',\
            '---+ Total Index Size Information',\
            '---+ Individual Index Storage Information')
var @HDR = ('',\
            '| *Size in MiB*|',\
            '|*Table Name*|*Index Name*| *Rows*| *Size (MiB)*| *Initrans*| \
            *Freelists*| *Degree*|')
set $sql
{SELECT '| ' ||
"       TO_CHAR(NVL(ROUND(SUM(i.leaf_blocks*t.block_size*1.05/1048576),1),0),
"               '999999990.9') || '|'
" FROM dba_indexes i,dba_tablespaces t
" WHERE owner = ':1'
"   AND i.tablespace_name = t.tablespace_name;
"PROMPT ___Macro_separator(2)___
"SELECT '|' ||
"       i.table_name || ' |' ||
"       i.index_name || ' | ' ||
"       NVL(i.num_rows,0) || '| ' ||
"       TO_CHAR(NVL(ROUND(i.leaf_blocks*t.block_size*1.05/1048576,1),0),
"               '999999990.9') || '| ' ||
"       NVL(i.INI_TRANS,0) || '| ' ||
"       NVL(i.FREELISTS,0) || '| ' ||
"       NVL(i.DEGREE,0) || '|'
" FROM dba_indexes i,dba_tablespaces t
" WHERE i.owner = ':1'
"   AND i.tablespace_name = t.tablespace_name
" ORDER BY NVL(i.leaf_blocks,0) DESC,index_name ASC;
}
call separator(1)
call writeSql(bindSql($sql,$USER_NAME))
call separator(0,'Index Information')

=head2 segment - Segment Information

Gathers information about Oracle Retail segments.

=cut

debug 'Inside Oracle Retail module, collecting the segment information'
report segment
var $TTL = '---+!! Segment Information'
var @TTL = ('',\
            '---+ Total Segment Size Information',\
            '---+ Individual Segment Infomation')
var @HDR = ('',\
            '| *Size in MiB*|',\
            '|*Segment Name*|*Segment Type*| *Size(MiB)*|')
set $sql
{SELECT '| ' ||
"        TO_CHAR(NVL(ROUND(SUM(bytes)/1048576,1),0),'999999990.9') || '|'
" FROM dba_extents
" WHERE owner = ':1';
"PROMPT ___Macro_separator(2)___
"SELECT '|' ||
"       segment_name || ' |' ||
"       segment_type || ' | ' ||
"       TO_CHAR(NVL(ROUND(SUM(bytes)/1048576,1),0),'999999990.9') || '|'
" FROM dba_extents
" WHERE owner = ':1'
" GROUP BY segment_name,segment_type
" ORDER BY SUM(bytes) DESC,segment_name ASC;
}
call separator(1)
call writeSql(bindSql($sql,$USER_NAME))
call separator(0,'Segment Information')

=head1 SEE ALSO

L<DB:DBinfo|collect::DB:DBinfo>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
