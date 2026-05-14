REM +======================================================================+ 
REM |    Copyright (c) 2005, 2018 Oracle and/or its affiliates.           | 
REM |                         All rights reserved.                         | 
REM |                           Version 12.0.0                             | 
REM +======================================================================+ 
REM $Header: ADZDDMDIAG.sql 120.0.12020000.4 2018/11/14 12:17:21 rsatyava noship $
REM dbdrv: none
REM +=======================================================================+
REM |Copyright (c) 2005, 2018  Oracle and/or its affiliates.
REM |All rights reserved.
REM |Version 12.0.0
REM +=======================================================================+
REM This script ADZDDMDIAG.sql is used to diagnose ad data model descrepancies
REM It will identify  all the ad tables with ddl changes post 12.2 ,for which editioning view is pointing to the revised column but data is not populated into the revised columns


SET FEEDBACK OFF;
SET ECHO OFF;

WHENEVER OSERROR EXIT FAILURE ROLLBACK;
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;



REM
REM  Spool results to adzdshowdmdiag.out file.
REM
spool adzdshowdmdiag.out


set pagesize 1000
set linesize 200
set trimspool on
set verify off


column table_name   format A30
column original_column_name  format A30
column modified_column_name  format A30
column notnull_flag           format A2
column data_default format A24
column cet          format A30
column dm_sync      format A10

prompt -- Validating the table AD_APPL_TOPS for data model changes in sync or not

whenever sqlerror continue;

SELECT 'AD_APPL_TOPS' as table_name,'NAME' as original_column_name,'NAME#1' as modified_column_name,'Y' as notnull_flag,'*NULL*' as data_default,'AD_APPL_TOPS_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_APPL_TOPS#')
 and runcol.view_column_name ='NAME'
 and runcol.table_column_name ='NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_APPL_TOPS appltop
            WHERE 	appltop.NAME IS NOT NULL
            AND   appltop.NAME#1 = '*NULL*')	

/

prompt -- Validating the table AD_TRACKABLE_ENTITIES for data model changes in sync or not			

SELECT 'AD_TRACKABLE_ENTITIES' as table_name,'ABBREVIATION' as original_column_name,'ABBREVIATION#1' as modified_column_name,'Y' as notnull_flag,'A' as data_default,'AD_TRACKABLE_ENTITIES_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_TRACKABLE_ENTITIES#')
 and runcol.view_column_name ='ABBREVIATION'
 and runcol.table_column_name ='ABBREVIATION#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_TRACKABLE_ENTITIES track
            WHERE 	track.ABBREVIATION IS NOT NULL
            AND   track.ABBREVIATION#1 = '*A*')	

/

prompt -- Validating the table AD_TRACKABLE_ENTITIES for data model changes in sync or not			

SELECT 'AD_TRACKABLE_ENTITIES' as table_name,'NAME' as original_column_name,'NAME#1' as modified_column_name,'Y' as notnull_flag,'*null*' as data_default,'AD_TRACKABLE_ENTITIES_F2' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_TRACKABLE_ENTITIES#')
 and runcol.view_column_name ='NAME'
 and runcol.table_column_name ='NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_TRACKABLE_ENTITIES track
            WHERE 	track.NAME IS NOT NULL
            AND   track.NAME#1 = '*null*')	

/

prompt -- Validating the table AD_TIMESTAMPS for data model changes in sync or not			

SELECT 'AD_TIMESTAMPS' as table_name,'ATTRIBUTE' as original_column_name,'ATTRIBUTE#1' as modified_column_name,'Y' as notnull_flag,'*NULL*' as data_default,'AD_TIMESTAMPS_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_TIMESTAMPS#')
 and runcol.view_column_name ='ATTRIBUTE'
 and runcol.table_column_name ='ATTRIBUTE#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_TIMESTAMPS adtime
            WHERE 	adtime.ATTRIBUTE IS NOT NULL
            AND   adtime.ATTRIBUTE#1 = '*NULL*')	

/

prompt -- Validating the table AD_TE_LEVEL_HISTORY for data model changes in sync or not			

SELECT 'AD_TE_LEVEL_HISTORY' as table_name,'ABBREVIATION' as original_column_name,'ABBREVIATION#1' as modified_column_name,'Y' as notnull_flag,'*A*' as data_default,'AD_TE_LEVEL_HISTORY_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_TE_LEVEL_HISTORY#')
 and runcol.view_column_name ='ABBREVIATION'
 and runcol.table_column_name ='ABBREVIATION#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_TE_LEVEL_HISTORY adtelevel
            WHERE 	adtelevel.ABBREVIATION IS NOT NULL
            AND   adtelevel.ABBREVIATION#1 = '*A*')	

/

prompt -- Validating the table AD_TE_LEVEL_HISTORY for data model changes in sync or not			

SELECT 'AD_TE_LEVEL_HISTORY' as table_name,'NAME' as original_column_name,'NAME#1' as modified_column_name,'Y' as notnull_flag,'*null*' as data_default,'AD_TE_LEVEL_HISTORY_F2' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_TE_LEVEL_HISTORY#')
 and runcol.view_column_name ='NAME'
 and runcol.table_column_name ='NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_TE_LEVEL_HISTORY adtelevel
            WHERE 	adtelevel.NAME IS NOT NULL
            AND   adtelevel.NAME#1 = '*null*')	

/

prompt -- Validating the table ADOP_VALID_NODES for data model changes in sync or not			

SELECT 'ADOP_VALID_NODES' as table_name,'NODE_NAME' as original_column_name,'NODE_NAME#1' as modified_column_name,'Y' as notnull_flag,'*NULL*' as data_default,'ADOP_VALID_NODES_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='ADOP_VALID_NODES#')
 and runcol.view_column_name ='NODE_NAME'
 and runcol.table_column_name ='NODE_NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.ADOP_VALID_NODES advalnode
            WHERE 	advalnode.NODE_NAME IS NOT NULL
            AND   advalnode.NODE_NAME#1 = '*NULL*')	

/


prompt -- Validating the table AD_NODES_CONFIG_STATUS for data model changes in sync or not			

SELECT 'AD_NODES_CONFIG_STATUS' as table_name,'NODENAME' as original_column_name,'NODENAME#1' as modified_column_name,'Y' as notnull_flag,'*NULL*' as data_default,'AD_NODES_CONFIG_STATUS_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_NODES_CONFIG_STATUS#')
 and runcol.view_column_name ='NODENAME'
 and runcol.table_column_name ='NODENAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_NODES_CONFIG_STATUS adnodeconf
            WHERE  adnodeconf.NODENAME IS NOT NULL
            AND   adnodeconf.NODENAME#1 = '*NULL*')	
            

/

prompt -- Validating the table AD_ADOP_SESSIONS for data model changes in sync or not			

SELECT 'AD_ADOP_SESSIONS' as table_name,'NODE_NAME' as original_column_name,'NODE_NAME#1' as modified_column_name,'N' as notnull_flag,'' as data_default,'AD_ADOP_SESSIONS_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_ADOP_SESSIONS#')
 and runcol.view_column_name ='NODE_NAME'
 and runcol.table_column_name ='NODE_NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_ADOP_SESSIONS adsess
            WHERE  adsess.NODE_NAME IS NOT NULL	
			AND    adsess.NODE_NAME#1 IS NULL)

            

/

prompt -- Validating the table AD_ADOP_SESSION_PATCHES for data model changes in sync or not			

SELECT 'AD_ADOP_SESSION_PATCHES' as table_name,'NODE_NAME' as original_column_name,'NODE_NAME#1' as modified_column_name,'N' as notnull_flag,'' as data_default,'AD_ADOP_SESSION_PATCHES_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_ADOP_SESSION_PATCHES#')
 and runcol.view_column_name ='NODE_NAME'
 and runcol.table_column_name ='NODE_NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_ADOP_SESSION_PATCHES adspatch
            WHERE adspatch.NODE_NAME IS NOT NULL	
			AND   adspatch.NODE_NAME#1 IS NULL)

            

/

prompt -- Validating the table AD_BUGS for data model changes in sync or not			

SELECT 'AD_BUGS' as table_name,'TRACKABLE_ENTITY_ABBR' as original_column_name,'TRACKABLE_ENTITY_ABBR#1' as modified_column_name,'N' as notnull_flag,'' as data_default,'AD_BUGS_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_BUGS#')
 and runcol.view_column_name ='TRACKABLE_ENTITY_ABBR'
 and runcol.table_column_name ='TRACKABLE_ENTITY_ABBR#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_BUGS adbugs
            WHERE adbugs.TRACKABLE_ENTITY_ABBR IS NOT NULL
			and adbugs.TRACKABLE_ENTITY_ABBR#1 IS NULL)

            

/


prompt -- Validating the table AD_PATCH_COND_HISTORY for data model changes in sync or not			

SELECT 'AD_PATCH_COND_HISTORY' as table_name,'COND_TE_NAME' as original_column_name,'COND_TE_NAME#1' as modified_column_name,'N' as notnull_flag,'' as data_default,'AD_PATCH_COND_HISTORY_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_PATCH_COND_HISTORY#')
 and runcol.view_column_name ='COND_TE_NAME'
 and runcol.table_column_name ='COND_TE_NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_PATCH_COND_HISTORY adpcond
            WHERE adpcond.COND_TE_NAME IS NOT NULL	
			AND   adpcond.COND_TE_NAME#1 IS NULL)

            

/

prompt -- Validating the table AD_PATCH_COND_HISTORY for data model changes in sync or not			

SELECT 'AD_PATCH_COND_HISTORY' as table_name,'REQUIRED_TE_ABBR' as original_column_name,'REQUIRED_TE_ABBR#1' as modified_column_name,'N' as notnull_flag,'' as data_default,'AD_PATCH_COND_HISTORY_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_PATCH_COND_HISTORY#')
 and runcol.view_column_name ='REQUIRED_TE_ABBR'
 and runcol.table_column_name ='REQUIRED_TE_ABBR#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_PATCH_COND_HISTORY adpcond
            WHERE adpcond.REQUIRED_TE_ABBR IS NOT NULL	
			AND   adpcond.REQUIRED_TE_ABBR#1 IS NULL)

            

/

prompt -- Validating the table AD_PATCH_COND_HISTORY for data model changes in sync or not			

SELECT 'AD_PATCH_COND_HISTORY' as table_name,'TRACKABLE_ENTITY_ABBR' as original_column_name,'TRACKABLE_ENTITY_ABBR#1' as modified_column_name,'N' as notnull_flag,'' as data_default,'AD_PATCH_COND_HISTORY_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='AD_PATCH_COND_HISTORY#')
 and runcol.view_column_name ='TRACKABLE_ENTITY_ABBR'
 and runcol.table_column_name ='TRACKABLE_ENTITY_ABBR#1'
 and exists(SELECT 1 FROM
            APPLSYS.AD_PATCH_COND_HISTORY adpcond
            WHERE adpcond.TRACKABLE_ENTITY_ABBR IS NOT NULL	
			AND   adpcond.TRACKABLE_ENTITY_ABBR#1 IS NULL)

            

/


prompt -- Validating the table FND_NODES for data model changes in sync or not			

SELECT 'FND_NODES' as table_name,'NODE_NAME' as original_column_name,'NODE_NAME#1' as modified_column_name,'N' as notnull_flag,'' as data_default,'FND_NODES_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='FND_NODES#')
 and runcol.view_column_name ='NODE_NAME'
 and runcol.table_column_name ='NODE_NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.FND_NODES fnodes
            WHERE fnodes.NODE_NAME IS NOT NULL	
			AND   fnodes.NODE_NAME#1 ='*NULL*')

            

/

prompt -- Validating the table FND_OAM_CONTEXT_FILES for data model changes in sync or not			

SELECT 'FND_OAM_CONTEXT_FILES' as table_name,'NODE_NAME' as original_column_name,'NODE_NAME#1' as modified_column_name,'N' as notnull_flag,'' as data_default,'FND_OAM_CONTEXT_FILES_F1' as cet,'N' as dm_sync
 from dba_editioning_view_cols runcol
 WHERE runcol.OWNER='APPLSYS'
 and (runcol.view_name ='FND_OAM_CONTEXT_FILES#')
 and runcol.view_column_name ='NODE_NAME'
 and runcol.table_column_name ='NODE_NAME#1'
 and exists(SELECT 1 FROM
            APPLSYS.FND_OAM_CONTEXT_FILES foam
            WHERE foam.NODE_NAME IS NOT NULL	
			AND   foam.NODE_NAME#1 ='*NULL*' )

            

/
prompt
spool off;
EXIT;
/

















