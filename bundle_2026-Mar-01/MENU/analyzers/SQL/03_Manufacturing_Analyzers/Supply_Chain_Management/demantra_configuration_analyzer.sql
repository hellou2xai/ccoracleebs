SET SERVEROUTPUT ON SIZE 1000000
SET ESCAPE OFF
SET DEFINE OFF
WHENEVER SQLERROR EXIT
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM | FRAMEWORK 4.8.4                                                           |
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    demantra_configuration_analyzer.sql                                    |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    SQL to install package used for Demantra Configuration Analyzer        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM +===========================================================================+


declare

apps_version FND_PRODUCT_GROUPS.RELEASE_NAME%TYPE;
db_version VARCHAR2(255);
db_version_short VARCHAR2(4);

BEGIN
 SELECT max(release_name) INTO apps_version
 FROM fnd_product_groups;

 apps_version := substr(apps_version,1,4);

    begin
        -- Try to get version using new 19c method
        execute immediate 'select version_full FROM v$instance'
            into db_version;
    exception when others then
        -- Get version using old method
        SELECT version INTO db_version
        FROM V$INSTANCE;
    end;

 db_version_short := substr(db_version, 1, instr(db_version, '.')-1);

 -- Validation to verify analyzer is run on proper e-Business application version
 -- So will fail before package is created
 if apps_version NOT IN ('11.5','12.0','12.1','12.2') then
    dbms_output.put_line('***************************************************************');
    dbms_output.put_line('*** WARNING WARNING WARNING WARNING WARNING WARNING WARNING ***');
    dbms_output.put_line('***************************************************************');
    dbms_output.put_line('*** This instance is eBusiness Suite version '|| apps_version ||'           ');
    dbms_output.put_line('*** This Analyzer script is compatible for following version(s): ');
    dbms_output.put_line('***   11i,12.0,12.1,12.2 ');
    dbms_output.put_line('*** Note: the error below is intentional                    ');
    raise_application_error(-20001, 'ERROR: The script requires eBusiness versions 11i,12.0,12.1,12.2');
 end if;

 -- Validation to verify analyzer is run on proper Database version (10g or higher)
 -- So will fail before package is created
 if (to_number(nvl(db_version_short, 10)) < 10) then
    dbms_output.put_line('***************************************************************');
    dbms_output.put_line('*** WARNING WARNING WARNING WARNING WARNING WARNING WARNING ***');
    dbms_output.put_line('***************************************************************');
    dbms_output.put_line('*** This instance is running on database version '|| db_version);
    dbms_output.put_line('*** This Analyzer script is compatible for versions higher than 10g. ');
    dbms_output.put_line('*** Note: the error below is intentional                    ');
    raise_application_error(-20001, 'ERROR: The script requires database version 10g or higher.');
 end if;

END;
/


CREATE OR REPLACE PACKAGE dm_demantra_analyzer_pkg AUTHID DEFINER AS

TYPE section_rec IS RECORD(
  name           VARCHAR2(255),
  result         VARCHAR2(1), -- E,W,S
  error_count    NUMBER,
  warn_count     NUMBER,
  success_count  NUMBER,
  print_count    NUMBER);

TYPE family_area_tbl IS TABLE OF VARCHAR2(10) INDEX BY VARCHAR(32);
TYPE rep_section_tbl IS TABLE OF section_rec INDEX BY BINARY_INTEGER;
TYPE hash_tbl_2k     IS TABLE OF VARCHAR2(2000) INDEX BY VARCHAR2(255);
TYPE hash_tbl_4k     IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(255);
TYPE hash_tbl_8k     IS TABLE OF VARCHAR2(8000) INDEX BY VARCHAR2(255);
TYPE col_list_tbl    IS TABLE OF DBMS_SQL.VARCHAR2_TABLE;
TYPE varchar_tbl     IS TABLE OF VARCHAR2(255);
TYPE results_hash    IS TABLE OF NUMBER INDEX BY VARCHAR(1);
TYPE parameter_rec   IS RECORD(
  pname        VARCHAR2(255),
  pvalue       VARCHAR2(2000));
TYPE parameter_hash IS TABLE OF parameter_rec;


TYPE signature_rec IS RECORD(
  sigrepo_id       VARCHAR2(10),
  sig_sql          VARCHAR2(32000),
  title            VARCHAR2(255),
  fail_condition   VARCHAR2(4000),
  problem_descr    VARCHAR2(32000),
  solution         VARCHAR2(4000),
  success_msg      VARCHAR2(4000),
  print_condition  VARCHAR2(8),
  fail_type        VARCHAR2(1),
  print_sql_output VARCHAR2(2),
  limit_rows       VARCHAR2(1),
  extra_info       HASH_TBL_4K,
  child_sigs       VARCHAR_TBL := VARCHAR_TBL(),
  include_in_xml   VARCHAR2(1),
  styles           HASH_TBL_2K,
  version          VARCHAR2(10)  -- EBSAF-177
);

TYPE signature_tbl IS TABLE OF signature_rec INDEX BY VARCHAR2(255);
TYPE colsType      IS TABLE OF VARCHAR(126) INDEX BY VARCHAR(126);
TYPE hyperlinkColType IS RECORD(
   cols    colsType
);
TYPE sourceToDestType IS TABLE OF hyperlinkColType INDEX BY VARCHAR2(126);
TYPE destToSourceType IS TABLE OF hyperlinkColType INDEX BY VARCHAR2(126);

TYPE resultType      IS TABLE OF VARCHAR2(32) INDEX BY VARCHAR2(32);
TYPE dx_pr_type      IS TABLE OF INTEGER INDEX BY VARCHAR(320);

TYPE sig_record IS RECORD(
   sig_id      VARCHAR2(320),
   sig_name    VARCHAR2(320),
   sig_result  VARCHAR2(10)
);
TYPE signatures_tbl IS TABLE OF sig_record;

TYPE section_record IS RECORD(
   name          VARCHAR2(320),
   title         VARCHAR (320),
   sigs          signatures_tbl,
   results       results_hash
);
TYPE section_record_tbl IS TABLE OF section_record;

-- EBSAF-177 Capture signature performance details
TYPE sig_stats_rec IS RECORD(
    sig_id          VARCHAR2(320),
    version         NUMBER,
    row_count       NUMBER,
    query_start     TIMESTAMP,
    query_time      NUMBER, -- in seconds
    process_start   TIMESTAMP,
    process_time    NUMBER -- in seconds
);
TYPE sig_stats_tbl IS TABLE OF sig_stats_rec INDEX BY VARCHAR(320);


PROCEDURE main
(            p_schema_owner                 IN VARCHAR2    DEFAULT NULL
           ,p_middle_tier_cpu              IN NUMBER      DEFAULT 1
           ,p_max_output_rows              IN NUMBER      DEFAULT 50
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y')
;


PROCEDURE main_cp (
            errbuf                         OUT VARCHAR2
           ,retcode                        OUT VARCHAR2
           ,p_schema_owner                 IN VARCHAR2    DEFAULT NULL
           ,p_middle_tier_cpu              IN NUMBER      DEFAULT 1
           ,p_max_output_rows              IN NUMBER      DEFAULT 50
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y'
);

----------------------------------------------------------------
-- Analyzer-specific code: Function and Procedures (Spec)     --
----------------------------------------------------------------



END dm_demantra_analyzer_pkg;
/
show errors


CREATE OR REPLACE PACKAGE BODY dm_demantra_analyzer_pkg AS
-- $Id: demantra_configuration_analyzer.sql, 200.82 2026/01/28 14:33:31 oracle Exp $

----------------------------------
-- Global Variables             --
----------------------------------
g_log_file         UTL_FILE.FILE_TYPE;
g_out_file         UTL_FILE.FILE_TYPE;
g_is_concurrent    BOOLEAN := (to_number(nvl(FND_GLOBAL.CONC_REQUEST_ID,0)) >  0);
g_debug_mode       VARCHAR2(1) := 'N';
g_max_output_rows  NUMBER := 10;
g_family_result    VARCHAR2(1);
g_errbuf           VARCHAR2(1000);
g_retcode          VARCHAR2(1);
g_section_id       VARCHAR2(300);
g_snap_days        NUMBER := 0;
g_dx_printed       dx_pr_type;
g_issues_count     NUMBER := 0;
g_guid             VARCHAR2(40);

g_query_start_time TIMESTAMP;
g_query_elapsed    INTERVAL DAY(2) TO SECOND(3);
g_analyzer_start_time TIMESTAMP;
g_analyzer_elapsed    INTERVAL DAY(2) TO SECOND(3);

g_signatures      SIGNATURE_TBL;
g_sig_stats       sig_stats_tbl; -- EBSAF-177
g_sections        REP_SECTION_TBL;
g_sql_tokens      HASH_TBL_8K;
g_masked_tokens   HASH_TBL_8K; -- EBSAF-275
g_fk_mask_options HASH_TBL_2K; -- EBSAF-275
g_rep_info        HASH_TBL_2K;
g_parameters      parameter_hash := parameter_hash();
g_exec_summary      HASH_TBL_2K;
g_sig_errors      HASH_TBL_2K;
g_item_id         INTEGER := 0;
g_sig_id        INTEGER := 0;
g_parent_sig_id   VARCHAR2(320);
analyzer_title VARCHAR2(255);
g_analyzer_doc_id VARCHAR2(15) := TO_CHAR(TRUNC(1618885.1));
g_cmos_patch_url   VARCHAR2(500) :=
  'https://support.oracle.com/support/?patchId=';
g_cmos_doc_url     VARCHAR2(500) :=
  'https://support.oracle.com/support/?kmContentId='||g_analyzer_doc_id;
g_cmos_km_url     VARCHAR2(500) :=
  'https://support.oracle.com/support/?kmContentId=';
g_cmos_sr_url     VARCHAR2(500) :=
  'https://support.oracle.com/support/';
g_mos_patch_url   VARCHAR2(500) :=
  'https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=';
g_mos_doc_url     VARCHAR2(500) :=
  'https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId='||g_analyzer_doc_id;
g_mos_km_url     VARCHAR2(500) :=
  'https://support.oracle.com/epmos/faces/DocumentDisplay?id=';
g_mos_sr_url     VARCHAR2(500) :=
  'https://support.oracle.com/epmos/faces/SrCreate';
g_hidden_xml      XMLDOM.DOMDocument;
g_dx_summary_error VARCHAR2(4000);
g_preserve_trailing_blanks BOOLEAN := false;  -- EBSAF-255 g_preserve_trailing_blanks functionality is obsolete
g_sec_detail   section_record_tbl := section_record_tbl();
g_level            NUMBER := 1;
g_child_sig_html   CLOB;
g_result           resulttype;
g_cloud_flag       BOOLEAN := FALSE;
g_sig_count        NUMBER := 0;
g_hypercount       NUMBER := 1;
g_dest_to_source  destToSourceType;
g_source_to_dest  sourceToDestType;
g_results         results_hash;
g_fam_area_hash   family_area_tbl;
g_params_string   VARCHAR2(500) := '';

g_family_area      VARCHAR2(24) := 'EBS MFG';
g_framework_version VARCHAR(240) := '4.8.4';
g_rec_patch_in_dx   VARCHAR2(1) := nvl('A','A'); -- 'A' all rows, change to 'F' for failing rows in DX only
g_g2g_flag          BOOLEAN := nvl('Y','N')='Y'; -- EBSAF-272

g_banner_severity VARCHAR2(1) := 'E';
g_banner_message VARCHAR2(2000) := null;


----------------------------------------------------------------
-- Analyzer-specific code: Global Declarations                --
----------------------------------------------------------------
g_sum_rows_sales_data		number;
g_sum_rows_mdp_matrix		number;
g_sum_rows_promotion_data	number;
g_concurrent_users		number;
g_app_server_ctas		number;
g_maxdbconnections_derived	number;
g_total_batch_connections	number;
g_min_ctas_cpu_required		number;
g_max_ctas_cpu_required		number;
g_appserver_cpu_required        number;
g_job_queue_value		varchar2(4000);
g_middle_tier_cpu		number;
g_MIN_APP_SERVER_CORES		number;
g_MAX_APP_SERVER_CORES		number;
g_manual_threads_per_cpu        number;
g_batch_threads_per_cpu         number;
g_pool_threads_per_cpu          number;
g_maxdbconnection_cpu_comp      number;
g_tp_query_run_size_derived     number;
g_maxdbconnection_derived       number;
g_parallel_max_servers          number;
g_parallel_max_servers_min      number;
g_parallel_max_servers_max      number;
g_min_app_server_cores17        number;
g_max_app_server_cores17        number;
g_min_app_server_cores3         number;
g_max_app_server_cores3         number;
g_min_comb_cpu_req              number;
g_max_comb_cpu_req              number;

-- patch gap analysis
--
-- version_details table
g_current_version               VARCHAR2(20);
g_current_build                 VARCHAR2(20);
g_anchor_link                   varchar2(40);
g_anchor_test                   varchar2(40);
--
-- VERSION_DETAILS_HISTORY
g_VERSION                       VARCHAR2(20);
g_BUILD                         VARCHAR2(20);
g_SP                            VARCHAR2(20);
g_UPGRADE_DATE                  DATE;
--
--


-- The following are for patch gap analysis
-- The default is 0 (zero) for NOT APPLIED or condition is NOT TRUE
-- 1 (one) is APPLIED or condition is TRUE
-- The DEFAULT is 0 (zero) 
g_1229_30187573_15			number := 0;
g_1229_30187573_17			number := 0;
G_1229_12290397_attn        number := 0;
G_1229_12290401_attn        number := 0;
G_1229_build15_ok              number := 0;
G_12271_12270326_ATTN           number := 0;
G_1226_27278471_ATTN            number := 0;
G_1226_12260250_ATTN            number := 0;
G_7315_18048597_ATTN            number := 0;
G_7315_20415508_ATTN            number := 0;
G_7315_17640575_ATTN            number := 0;
G_7314_18048597_ATTN            number := 0;
G_7314_17640575_ATTN            number := 0;

G_7314_17640575_442_ATTN        number := 0;
G_7314_17640575_450_ATTN        number := 0;
G_7314_18048597_450_ATTN        number := 0;
G_7314_BUILD450_OK              number := 0;
G_7315_20415508_528_ATTN        number := 0;
G_7315_18048597_528_ATTN        number := 0;
G_12251_27320973_ATTN           number := 0;
G_1225_BUILD3_OK                number := 0;
G_1221_BUILD11_OK               number := 0;
G_7315_BUILD5207_OK             number := 0;
G_7315_18048597_5207_ATTN       number := 0;
G_7315_20415508_5207_ATTN       number := 0;
G_7315_BUILD528_OK              number := 0;
G_12271_BUILD107_OK             number := 0;
G_12271_27128464_ATTN           number := 0;
G_12271_26975832_ATTN           number := 0;
G_1227_27128464_ATTN            number := 0;
G_12263_27278471_ATTN           number := 0;
G_12261_BUILD110_OK             number := 0;
G_1225_BUILD136_OK              number := 0;
g_1227_build19_ok               number := 0;      
g_12263_build311_ok             number := 0;
g_12262_26641148_ok             number := 0;
g_12262_12260323_ok             number := 0;
g_12262_build216_ok             number := 0;
g_12261_build112_ok             number := 0;
g_1226_build35_ok               number := 0;
g_12251_build136_ok             number := 0;
g_12251_sp12250248_attn         number := 0;
g_12251_12250139_attn           number := 0;
g_12251_12250260_attn         number := 0;
g_12225_build3_attn             number := 0;
g_12241_build117_ok             number := 0;
g_1224_build50_ok               number := 0;
g_1223_build6_ok                number := 0;
g_1222_build11_ok               number := 0;
g_1221_build15_ok               number := 0;
g_1220_build87_ok               number := 0;
g_73152_build5265_ok            number := 0;
g_73152_build5207_ok            number := 0;
g_73151_build5106_ok            number := 0;
g_7314_build419_ok              number := 0;
g_1226_bld35_ok               number := 0;
g_12262_bld216_attn             number := 0;
g_12261_bld112_attn             number := 0;
g_12251_sp12250168_attn         number := 0;
g_12262_26798382_attn           number := 0;
g_12262_26641148_attn           number := 0;
g_12261_25403411_attn           number := 0;
g_12261_25332178_attn           number := 0;
g_12261_25332178_bld110_attn    number := 0;
g_1226_25332169_attn            number := 0;
g_1226_24710302_attn            number := 0;
g_1226_24710302_bld34_attn      number := 0;
g_12251_22254051_attn           number := 0;
g_12251_26663751_attn           number := 0;
g_12251_26305727_attn           number := 0;
g_12251_23059980_attn           number := 0;
g_12251_23088083_attn           number := 0;
g_12251_21094268_attn           number := 0;
g_12251_21959406_attn           number := 0;

g_12251_12250168_ATTN          number := 0;

g_1225_12250139_attn            number := 0;
g_1224_19945449_attn            number := 0;
g_1224_18139794_attn            number := 0;
g_1223_18080391_attn            number := 0;
g_1223_18040010_attn            number := 0;
g_12263_18139794_attn           number := 0;
g_12262_18139794_attn           number := 0;
g_1226_18139794_attn            number := 0;
g_12251_18139794_attn           number := 0;
g_1225_18139794_attn            number := 0;
g_12241_18139794_attn           number := 0;
g_1223_18139794_attn            number := 0;
g_1222_18139794_attn            number := 0;
g_1221_18139794_attn            number := 0;
g_122_18139794_attn             number := 0;
g_7315_18067048_attn            number := 0;
g_7315_17232259_5265_attn       number := 0;
g_7315_17232259_5207_attn       number := 0;
g_7315_17232259_5106_attn       number := 0;
g_7315_17232259_528_attn        number := 0;
g_73144_17261893_attn           number := 0;
g_73143_17261893_attn           number := 0;
g_12263_bld311_attn             number := 0;
g_1220_13930627_attn           number := 0;
g_1220_17024161_attn           number := 0;
g_1220_17640575_attn           number := 0;
g_1220_17808535_attn           number := 0;
g_1220_18638749_attn           number := 0;
g_1220_20211773_attn           number := 0;
g_1220_20429760_attn           number := 0;
g_1220_20613106_attn           number := 0;
g_1220_21089579_attn           number := 0;
g_1220_22018502_attn           number := 0;
g_1220_24935262_attn           number := 0;
g_1220_25506270_attn           number := 0;
g_1220_25634269_attn           number := 0;
g_1220_26981675_attn           number := 0;
g_1221_13930627_attn           number := 0;
g_1221_17024161_attn           number := 0;
g_1221_17640575_attn           number := 0;
g_1221_17808535_attn           number := 0;
g_1221_18638749_attn           number := 0;
g_1221_20211773_attn           number := 0;
g_1221_20429760_attn           number := 0;
g_1221_20613106_attn           number := 0;
g_1221_21089579_attn           number := 0;
g_1221_22018502_attn           number := 0;
g_1221_22275972_attn           number := 0;
g_1221_24935262_attn           number := 0;
g_1221_25103402_attn           number := 0;
g_1221_25506270_attn           number := 0;
g_1221_25634269_attn           number := 0;
g_1221_26981675_attn           number := 0;
g_1222_13930627_attn           number := 0;
g_1222_17024161_attn           number := 0;
g_1222_17640575_attn           number := 0;
g_1222_17808535_attn           number := 0;
g_1222_18638749_attn           number := 0;
g_1222_20211773_attn           number := 0;
g_1222_20429760_attn           number := 0;
g_1222_20613106_attn           number := 0;
g_1222_21089579_attn           number := 0;
g_1222_22018502_attn           number := 0;
g_1222_22275972_attn           number := 0;
g_1222_24935262_attn           number := 0;
g_1222_25103402_attn           number := 0;
g_1222_25506270_attn           number := 0;
g_1222_25634269_attn           number := 0;
g_1222_26981675_attn           number := 0;
g_1223_13930627_attn           number := 0;
g_1223_17024161_attn           number := 0;
g_1223_17640575_attn           number := 0;
g_1223_17808535_attn           number := 0;
g_1223_18638749_attn           number := 0;
g_1223_20211773_attn           number := 0;
g_1223_20429760_attn           number := 0;
g_1223_20613106_attn           number := 0;
g_1223_21089579_attn           number := 0;
g_1223_22018502_attn           number := 0;
g_1223_22275972_attn           number := 0;
g_1223_24935262_attn           number := 0;
g_1223_25103402_attn           number := 0;
g_1223_25506270_attn           number := 0;
g_1223_25634269_attn           number := 0;
g_1223_26981675_attn           number := 0;
g_12241_13930627_attn           number := 0;
g_12241_17024161_attn           number := 0;
g_12241_17640575_attn           number := 0;
g_12241_17808535_attn           number := 0;
g_12241_18638749_attn           number := 0;
g_12241_20174176_attn           number := 0;
g_12241_20211773_attn           number := 0;
g_12241_20429760_attn           number := 0;
g_12241_20613106_attn           number := 0;
g_12241_21089579_attn           number := 0;
g_12241_22018502_attn           number := 0;
g_12241_22275972_attn           number := 0;
g_12241_24935262_attn           number := 0;
g_12241_25506270_attn           number := 0;
g_12241_25634269_attn           number := 0;
g_12241_25739519_attn           number := 0;
g_12241_26981675_attn           number := 0;
g_1224_13930627_attn           number := 0;
g_1224_17024161_attn           number := 0;
g_1224_17640575_attn           number := 0;
g_1224_17808535_attn           number := 0;
g_1224_18638749_attn           number := 0;
g_1224_19550595_attn           number := 0;
g_1224_20174176_attn           number := 0;
g_1224_20211773_attn           number := 0;
g_1224_20429760_attn           number := 0;
g_1224_20613106_attn           number := 0;
g_1224_21089579_attn           number := 0;
g_1224_22018502_attn           number := 0;
g_1224_22275972_attn           number := 0;
g_1224_24935262_attn           number := 0;
g_1224_25506270_attn           number := 0;
g_1224_25634269_attn           number := 0;
g_1224_26981675_attn           number := 0;
g_12251_13930627_attn           number := 0;
g_12251_17024161_attn           number := 0;
g_12251_17640575_attn           number := 0;
g_12251_17808535_attn           number := 0;
g_12251_18638749_attn           number := 0;
g_12251_20211773_attn           number := 0;
g_12251_20429760_attn           number := 0;
g_12251_20613106_attn           number := 0;
g_12251_21089579_attn           number := 0;
g_12251_22018502_attn           number := 0;
g_12251_22275972_attn           number := 0;
g_12251_24935262_attn           number := 0;
g_12251_25506270_attn           number := 0;
g_12251_25634269_attn           number := 0;
g_12251_26981675_attn           number := 0;
g_1225_13930627_attn           number := 0;
g_1225_17024161_attn           number := 0;
g_1225_17640575_attn           number := 0;
g_1225_17808535_attn           number := 0;
g_1225_18638749_attn           number := 0;
g_1225_20211773_attn           number := 0;
g_1225_20429760_attn           number := 0;
g_1225_20613106_attn           number := 0;
g_1225_21089579_attn           number := 0;
g_1225_22018502_attn           number := 0;
g_1225_22275972_attn           number := 0;
g_1225_24935262_attn           number := 0;
g_1225_25506270_attn           number := 0;
g_1225_25634269_attn           number := 0;
g_1225_26981675_attn           number := 0;
g_12261_13930627_attn           number := 0;
g_12261_17024161_attn           number := 0;
g_12261_17640575_attn           number := 0;
g_12261_17808535_attn           number := 0;
g_12261_18139794_attn           number := 0;
g_12261_18638749_attn           number := 0;
g_12261_20211773_attn           number := 0;
g_12261_20429760_attn           number := 0;
g_12261_20613106_attn           number := 0;
g_12261_21089579_attn           number := 0;
g_12261_22018502_attn           number := 0;
g_12261_22275972_attn           number := 0;
g_12261_24935262_attn           number := 0;
g_12261_25506270_attn           number := 0;
g_12261_25634269_attn           number := 0;
g_12261_26981675_attn           number := 0;
g_12262_12260323_attn           number := 0;
g_12262_13930627_attn           number := 0;
g_12262_17024161_attn           number := 0;
g_12262_17640575_attn           number := 0;
g_12262_17808535_attn           number := 0;
g_12262_18638749_attn           number := 0;
g_12262_20211773_attn           number := 0;
g_12262_20429760_attn           number := 0;
g_12262_20613106_attn           number := 0;
g_12262_21089579_attn           number := 0;
g_12262_22018502_attn           number := 0;
g_12262_22275972_attn           number := 0;
g_12262_24935262_attn           number := 0;
g_12262_25506270_attn           number := 0;
g_12262_25634269_attn           number := 0;
g_12262_26981675_attn           number := 0;
g_12263_13930627_attn           number := 0;
g_12263_17024161_attn           number := 0;
g_12263_17640575_attn           number := 0;
g_12263_17808535_attn           number := 0;
g_12263_18638749_attn           number := 0;
g_12263_20211773_attn           number := 0;
g_12263_20429760_attn           number := 0;
g_12263_20613106_attn           number := 0;
g_12263_21089579_attn           number := 0;
g_12263_22018502_attn           number := 0;
g_12263_22275972_attn           number := 0;
g_12263_24935262_attn           number := 0;
g_12263_25506270_attn           number := 0;
g_12263_25634269_attn           number := 0;
g_12263_26798382_attn           number := 0;
g_1226_13930627_attn           number := 0;
g_1226_17024161_attn           number := 0;
g_1226_17640575_attn           number := 0;
g_1226_17808535_attn           number := 0;
g_1226_18638749_attn           number := 0;
g_1226_20211773_attn           number := 0;
g_1226_20429760_attn           number := 0;
g_1226_20613106_attn           number := 0;
g_1226_21089579_attn           number := 0;
g_1226_22018502_attn           number := 0;
g_1226_22275972_attn           number := 0;
g_1226_24935262_attn           number := 0;
g_1226_25506270_attn           number := 0;
g_1226_25634269_attn           number := 0;
g_1226_26981675_attn           number := 0;
g_1227_13930627_attn           number := 0;
g_1227_17024161_attn           number := 0;
g_1227_17640575_attn           number := 0;
g_1227_17808535_attn           number := 0;
g_1227_18638749_attn           number := 0;
g_1227_20211773_attn           number := 0;
g_1227_20429760_attn           number := 0;
g_1227_20613106_attn           number := 0;
g_1227_21089579_attn           number := 0;
g_1227_22018502_attn           number := 0;
g_1227_24935262_attn           number := 0;
g_1227_25506270_attn           number := 0;
g_1227_25634269_attn           number := 0;
g_1227_26798382_attn           number := 0;
g_1227_26975832_attn           number := 0;
g_122_22275972_attn           number := 0;
g_73143_13930627_442_attn           number := 0;
g_73143_17024161_442_attn           number := 0;
g_73143_17640575_442_attn           number := 0;
g_73143_17808535_442_attn           number := 0;
g_73143_18638749_442_attn           number := 0;
g_73143_20211773_442_attn           number := 0;
g_73143_20429760_442_attn           number := 0;
g_73143_20613106_442_attn           number := 0;
g_73143_21089579_442_attn           number := 0;
g_73143_22018502_442_attn           number := 0;
g_73143_24935262_442_attn           number := 0;
g_73143_25506270_attn           number := 0;
g_73143_25634269_442_attn           number := 0;
g_73143_26798382_attn           number := 0;
g_73144_13930627_450_attn           number := 0;
g_73144_17024161_450_attn           number := 0;
g_73144_17640575_450_attn           number := 0;
g_73144_17808535_450_attn           number := 0;
g_73144_18638749_450_attn           number := 0;
g_73144_20211773_450_attn           number := 0;
g_73144_20429760_450_attn           number := 0;
g_73144_20613106_450_attn           number := 0;
g_73144_21089579_450_attn           number := 0;
g_73144_22018502_450_attn           number := 0;
g_73144_24935262_450_attn           number := 0;
g_73144_25506270_attn           number := 0;
g_73144_25634269_450_attn           number := 0;
g_73144_26981675_attn           number := 0;
g_7315_13930627_5106_attn           number := 0;
g_7315_13930627_5207_attn           number := 0;
g_7315_13930627_5265_attn           number := 0;
g_7315_13930627_528_attn           number := 0;
g_7315_17024161_5106_attn           number := 0;
g_7315_17024161_5207_attn           number := 0;
g_7315_17024161_5265_attn           number := 0;
g_7315_17024161_528_attn           number := 0;
g_7315_17640575_5106_attn           number := 0;
g_7315_17640575_5207_attn           number := 0;
g_7315_17640575_5265_attn           number := 0;
g_7315_17640575_528_attn           number := 0;
g_7315_17808535_5106_attn           number := 0;
g_7315_17808535_5207_attn           number := 0;
g_7315_17808535_5265_attn           number := 0;
g_7315_17808535_528_attn           number := 0;
g_7315_18638749_5106_attn           number := 0;
g_7315_18638749_5207_attn           number := 0;
g_7315_18638749_5265_attn           number := 0;
g_7315_18638749_528_attn           number := 0;
g_7315_20174176_5106_attn           number := 0;
g_7315_20174176_5207_attn           number := 0;
g_7315_20174176_5265_attn           number := 0;
g_7315_20174176_528_attn           number := 0;
g_7315_20211773_5106_attn           number := 0;
g_7315_20211773_5207_attn           number := 0;
g_7315_20211773_5265_attn           number := 0;
g_7315_20211773_528_attn           number := 0;
g_7315_20429760_5106_attn           number := 0;
g_7315_20429760_5207_attn           number := 0;
g_7315_20429760_5265_attn           number := 0;
g_7315_20429760_528_attn           number := 0;
g_7315_20613106_5106_attn           number := 0;
g_7315_20613106_5207_attn           number := 0;
g_7315_20613106_5265_attn           number := 0;
g_7315_20613106_528_attn           number := 0;
g_7315_21089579_5106_attn           number := 0;
g_7315_21089579_5207_attn           number := 0;
g_7315_21089579_5265_attn           number := 0;
g_7315_21089579_528_attn           number := 0;
g_7315_22018502_5106_attn           number := 0;
g_7315_22018502_5207_attn           number := 0;
g_7315_22018502_5265_attn           number := 0;
g_7315_22018502_528_attn           number := 0;
g_7315_24935262_5106_attn           number := 0;
g_7315_24935262_5207_attn           number := 0;
g_7315_24935262_5265_attn           number := 0;
g_7315_24935262_528_attn           number := 0;
g_7315_25103402_5207_attn           number := 0;
g_7315_25634269_5106_attn           number := 0;
g_7315_25634269_5207_attn           number := 0;
g_7315_25634269_5265_attn           number := 0;
g_7315_25634269_528_attn           number := 0;
g_7315_5106_25506270_attn           number := 0;
g_7315_5106_26981675_attn           number := 0;
g_7315_5207_25506270_attn           number := 0;
g_7315_5207_26981675_attn           number := 0;
g_7315_5265_25506270_attn           number := 0;
g_7315_5265_26981675_attn           number := 0;
g_7315_528_25506270_attn           number := 0;
g_7315_528_26981675_attn         number := 0;
g_12225_BUILD3_ok                 number := 0;
g_12251_SP12250168_ok             number := 0;
g_1227_26981675_attn             number := 0;
g_12263_26981675_attn             number := 0;
g_73143_26981675_attn             number := 0;
g_12263_25420760_attn              number := 0;
g_12262_25420760_attn              number := 0;
g_12261_25420760_attn              number := 0;
g_1226_25420760_attn              number := 0;
G_1223_12230017_ATTN              number := 0;
G_1223_12230019_ATTN              number := 0;
G_7313_7314209_ATTN               number := 0;
G_7314_7314209_ATTN               number := 0;
G_12251_26985862_ATTN             number := 0;
g_1225_22254051_attn              number := 0;
G_73144_26981675_450_ATTN         number := 0;
G_73143_26981675_442_ATTN         number := 0;
g_7315_26981675_528_ATTN          number := 0;
g_7315_26981675_5265_attn          number := 0;
g_7315_26981675_5207_attn          number := 0;
g_7315_26981675_5106_attn          number := 0;
G_7315_18067048_5265_ATTN         number := 0;
G_7315_18067048_5207_ATTN         number := 0;
G_7315_18067048_5106_ATTN         number := 0;
G_7315_18067048_528_ATTN          number := 0;
G_7315_7315238_5265_ATTN          number := 0;
G_7315_7315238_5207_ATTN          number := 0;
G_7315_7315238_5106_ATTN          number := 0;
G_7315_7315238_528_ATTN           number := 0;

-- v$parameter, for the RDBMS
g_cpu_count			varchar2(4);
g_cpu_count_17                  number;
g_cpu_count_3                   number;
g_physical_cpu_count		number;
g_physical_cpu_count_17         number;
g_physical_cpu_count_3          number;
g_total_batch_cores		number;
g_concurrent_users_disp		number;
g_SD_INDEX			number;
g_SD_FACTOR    			number;
g_MDP_INDEX    			number;
g_MDP_FACTOR   			number;


-- for job_queue_processes
g_sales_data_analyzed		number := 0;  -- 0 = no, 1 = yes

-- aps_params
g_tp_update_record_batch_size	number;
g_tp_update_record_manual_size	number;
g_tp_update_data_manual_size	number;
g_tp_update_data_batch_size	number;
g_tp_update_table_manual_size	number;
g_tp_update_comb_manual_size	number;
g_tp_update_comb_batch_size	number;
g_tp_update_table_batch_size	number;
g_tp_update_size     		number;
g_tp_update_timeout		number;
g_tp_query_run_size		number;
g_tp_query_run_per_user		number := 0;
g_tp_query_run_timeout		number;
g_tp_level_method_size		number;
g_tp_level_method_timeout	number;
g_tp_copy_paste_size		number;
g_manual_java_threads		number;
g_batch_java_threads		number;
g_total_update_pool		number;
g_maxdbconnections 		number;
g_maxupdatethreads 		number;
g_dbidletimeout 		number;
g_schema_owner			VARCHAR2(128);


---- Worksheet Specific
g_ws_data_comb_block_size	number;
g_worksheet_full_load		number;
g_ct_worksheet_calcSummaryExp	number;
g_ct_uilimitations_maxcells	number;   -- client.uilimitations.maxcells
g_ct_uilimitations_maxcells_ws	number;   -- client.uilimitations.maxcells.ws
g_ct_uilimitations_maxcombs_ws	number;   -- client.uilimitations.maxcombs.ws
g_ct_uilimitations_maxdisk	number;   -- client.uilimitations.maxdiskspace
g_enableworksheetcaching	number;
g_ct_uilimitations_warning	number;   -- client_uilimitations_warning
g_max_worksheet_db_weight	number;

---- BLE Specific
g_blethreadpoolsize		number;
g_bletimeout			number;

-- sys_params
g_dynamic_hint_max_parallel_db	number;
g_gatherstatisticsthreshold	number;
g_min_sales_date		date;
g_max_sales_date      		date;
g_maxsalesgen			number;
g_min_fore_sales_date		date;


-- threadpool to tp
-- worksheet to ws
-- worksheet.data.comb.block_size to ws_data_comb_block_size
-- client.worksheet.calcSummaryExpressions to client_ws_calcSummaryExpressions
-- g_client.worksheet.calcSummaryExpressions to g_ct_wsheet_calcSummaryExp
-- g_client.uilimitations.maxcombs.ws to g_ct_uilimitations_maxcombs_ws 
-- g_client.uilimitations.maxdiskspace to g_ct_uilimitations_maxdisk
-- g_client.uilimitations.maxcells.ws to g_ct_uilimitations_maxcells_ws
-- g_client_uilimitations_maxcombs_ws to g_ct_uilimitations_maxcombs_ws

-- APPSERVERURL
-- URL and ACL configuration verification
--
g_appserverurl    	varchar2(100);
g_protocol		varchar2(5);
g_slash			varchar2(2);
g_port1        		varchar2(5);
g_port2        		NUMBER;
g_rest			varchar2(100);
G_HOST_NAME		varchar2(100);
g_EngineBaseURL		varchar2(100);
g_apps_version_max	varchar2(20);
g_appsurl_upgrade_date		date;
g_eng_appserverurl	varchar2(100);
g_eng_protocol		varchar2(5);
g_eng_slash		varchar2(2);
g_eng_host_name		varchar2(100);
g_eng_port1		varchar2(5);
g_eng_rest		varchar2(100);
g_eng_platform		varchar2(100);
g_MSD_DEM_PROFILE_PROTOCOL	varchar2(5);


-- appserverurl_exists 	NUMBER;
g_appserverurl_stripped	varchar2(100);
g_appserverurl_https	varchar2(10);
g_APPSERVERURL_FINAL	varchar2(100);
g_MSD_DEM_HTTP		VARCHAR2(100);
g_privilege            	VARCHAR2(20);
g_denied               	BOOLEAN := FALSE;
g_granted              	BOOLEAN := FALSE;
g_input_acl            	VARCHAR2(500);
g_create_acl           	BOOLEAN := FALSE;
g_add_privilege        	BOOLEAN := FALSE; 
g_assign_acl           	BOOLEAN := FALSE;
g_user_exist           	INTEGER;
g_engine_platform 	VARCHAR2(50);
g_acl_name 		VARCHAR2(240);
g_acl_type            	VARCHAR2(240);
g_cursor_sql      	VARCHAR2(4000);
g_sql         		VARCHAR2(8000);
g_server      		VARCHAR2(2000);
g_err_msg     		VARCHAR2(1000);
g_acl         		VARCHAR2(500) := null;
g_oracle_ver  		VARCHAR2(100);
g_user_name   		VARCHAR2(50);
g_input_user  		VARCHAR2(50);
g_acl_count   		INTEGER;

-- end

----------------------------------------------------------------
-- Debug, log and output procedures                          --
----------------------------------------------------------------

PROCEDURE enable_debug IS
BEGIN
  g_debug_mode := 'Y';
END enable_debug;

PROCEDURE disable_debug IS
BEGIN
  g_debug_mode := 'N';
END disable_debug;

PROCEDURE print_log(p_msg IN VARCHAR2) is
BEGIN
  -- print only when debug flag is 'Y'
    IF g_debug_mode = 'Y' THEN
        IF NOT g_is_concurrent THEN
          utl_file.put_line(g_log_file, p_msg);
          utl_file.fflush(g_log_file);
        ELSE
          fnd_file.put_line(FND_FILE.LOG, p_msg);
        END IF;
   END IF;

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line(substr('Error in print_log: '||sqlerrm,1,254));
  raise;
END print_log;


PROCEDURE debug(p_msg VARCHAR2) is
 l_time varchar2(25);
BEGIN
  -- print only when debug flag is 'Y'
  IF g_debug_mode = 'Y' THEN
    l_time := to_char(sysdate,'DD-MON-YY HH24:MI:SS');

    IF NOT g_is_concurrent THEN
      utl_file.put_line(g_log_file, l_time||'-'||p_msg);
    ELSE
      fnd_file.put_line(FND_FILE.LOG, l_time||'-'||p_msg);
    END IF;

  END IF;

EXCEPTION WHEN OTHERS THEN
  print_log('Error in debug');
  raise;
END debug;


PROCEDURE print_out(
    p_msg IN VARCHAR2,
    p_newline IN VARCHAR  DEFAULT 'Y'
) IS
BEGIN
  IF NOT g_is_concurrent THEN
    IF (p_newline = 'N') THEN
       utl_file.put(g_out_file, p_msg);
    ELSE
       utl_file.put_line(g_out_file, p_msg);
    END IF;
    utl_file.fflush(g_out_file);
  ELSE
     IF (p_newline = 'N') THEN
        fnd_file.put(FND_FILE.OUTPUT, p_msg);
     ELSE
        fnd_file.put_line(FND_FILE.OUTPUT, p_msg);
     END IF;
  END IF;
EXCEPTION WHEN OTHERS THEN
  print_log('Error in print_out');
  raise;
END print_out;


PROCEDURE print_clob(
    p_clob IN OUT NOCOPY CLOB,
    p_newline IN VARCHAR  DEFAULT 'Y'
) IS
    l_length  NUMBER := dbms_lob.getlength(p_clob);
    l_offset NUMBER := 1;
    l_buffer VARCHAR2(16000);
    l_read   NUMBER := 4000;
BEGIN
    WHILE l_offset < l_length LOOP
        dbms_lob.read(p_clob, l_read, l_offset, l_buffer);
        print_out(l_buffer, 'N');
        l_offset := l_offset + l_read;
    END LOOP;
    IF (p_newline = 'Y') THEN
        print_out(null,'Y');
    END IF;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in print_clob');
    raise;
END print_clob;


PROCEDURE print_buffer(
    p_clob IN OUT NOCOPY CLOB,
    p_msg IN VARCHAR2,
    p_newline IN VARCHAR DEFAULT 'Y'
) IS
BEGIN
    -- Create storage if needed
    if (p_clob is null) then
        dbms_lob.createtemporary(p_clob, true, dbms_lob.session);
    end if;
    -- Append message
    if (p_newline = 'N') then
        dbms_lob.append(p_clob, p_msg);
    else
        dbms_lob.append(p_clob, p_msg || chr(10));
    end if;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in print_buffer');
    raise;
END;


PROCEDURE print_error(
    p_msg VARCHAR2,
    p_sig_id VARCHAR2 DEFAULT '',
    p_section_id VARCHAR2 DEFAULT '')
IS
BEGIN
    -- ER #124 Show in unix session the error if parameter or additional validation failed.
    dbms_output.put_line('**************************************************');
    dbms_output.put_line('**** ERROR  ERROR  ERROR  ERROR  ERROR  ERROR ****');
    dbms_output.put_line('**************************************************');
    dbms_output.put_line('**** The analyzer did not run to completion!');
    dbms_output.put_line('**** '||p_msg);
    IF p_msg LIKE 'INVALID ARGUMENT:%' THEN
        dbms_output.put_line('**** Please rerun the analyzer with proper parameter value.');
    END IF;
    print_out('<br><b>ERROR</b><br>'||p_msg||'<br>');
    print_log('ERROR: '||p_msg);
END print_error;


----------------------------------------------------------------
--- Time Management                                          ---
----------------------------------------------------------------

PROCEDURE get_current_time (p_time IN OUT TIMESTAMP) IS
BEGIN
  SELECT localtimestamp(3) INTO p_time
  FROM   dual;
END get_current_time;

FUNCTION stop_timer(p_start_time IN TIMESTAMP) RETURN INTERVAL DAY TO SECOND IS
  l_elapsed INTERVAL DAY(2) TO SECOND(3);
BEGIN
  SELECT localtimestamp - p_start_time  INTO l_elapsed
  FROM   dual;
  RETURN l_elapsed;
END stop_timer;

FUNCTION format_elapsed (p_elapsed IN INTERVAL DAY TO SECOND, p_mili IN BOOLEAN DEFAULT TRUE) RETURN VARCHAR2 IS
  l_days         VARCHAR2(3);
  l_hours        VARCHAR2(2);
  l_minutes      VARCHAR2(2);
  l_seconds      VARCHAR2(6);
  l_fmt_elapsed  VARCHAR2(80);
BEGIN
  l_days := EXTRACT(DAY FROM p_elapsed);
  IF to_number(l_days) > 0 THEN
    l_fmt_elapsed := l_days||' days';
  END IF;
  l_hours := EXTRACT(HOUR FROM p_elapsed);
  IF to_number(l_hours) > 0 THEN
    IF length(l_fmt_elapsed) > 0 THEN
      l_fmt_elapsed := l_fmt_elapsed||', ';
    END IF;
    l_fmt_elapsed := l_fmt_elapsed || l_hours||' Hrs';
  END IF;
  l_minutes := EXTRACT(MINUTE FROM p_elapsed);
  IF to_number(l_minutes) > 0 THEN
    IF length(l_fmt_elapsed) > 0 THEN
      l_fmt_elapsed := l_fmt_elapsed||', ';
    END IF;
    l_fmt_elapsed := l_fmt_elapsed || l_minutes||' Min';
  END IF;
  l_seconds := EXTRACT(SECOND FROM p_elapsed);
  IF (NOT p_mili) THEN
      l_seconds := TO_CHAR(ROUND(TO_NUMBER(l_seconds)));
  END IF;
  IF length(l_fmt_elapsed) > 0 THEN
    l_fmt_elapsed := l_fmt_elapsed||', ';
  END IF;
  l_fmt_elapsed := l_fmt_elapsed || l_seconds||' Sec';
  RETURN(l_fmt_elapsed);

EXCEPTION WHEN OTHERS THEN
  print_log('There was an exception when trying to calculate elapsed time: ' || SQLERRM);
  RETURN p_elapsed;
END format_elapsed;

--EBSAF-177
function seconds_elapsed(p_elapsed IN INTERVAL DAY TO SECOND) return number is
begin
    return round(
        EXTRACT(DAY FROM p_elapsed)*86400   -- 24*60*60
      + EXTRACT(HOUR FROM p_elapsed)*3600   -- 60*60
      + EXTRACT(MINUTE FROM p_elapsed)*60
      + EXTRACT(SECOND FROM p_elapsed)
    , 3);
end seconds_elapsed;

--EBSAF-177 Start tracking signature step time
procedure sig_time_start(p_sig_id varchar2, p_parent_sig_id varchar2, p_type varchar2) is
    l_stat_id varchar(320);
    l_rec sig_stats_rec;
begin
    l_stat_id := p_sig_id || '|' || p_parent_sig_id;

    -- Initialize record if not present
    if not g_sig_stats.exists(l_stat_id) then
        l_rec.sig_id := p_sig_id;
        l_rec.version := g_signatures(p_sig_id).version;
        l_rec.row_count := 0;
        l_rec.query_time := 0;
        l_rec.process_time := 0;
        g_sig_stats(l_stat_id) := l_rec;
    end if;

    -- Update timestamp
    if p_type = 'Q' then
        g_sig_stats(l_stat_id).query_start := localtimestamp;
    elsif p_type = 'P' then
        g_sig_stats(l_stat_id).process_start := localtimestamp;
    end if;
exception when others then
    print_log('Error in sig_time_start: '||sqlerrm);
end;

--EBSAF-177 Adds seconds since signature step last started
procedure sig_time_add(p_sig_id varchar2, p_parent_sig_id varchar2, p_type varchar2) is
    l_stat_id varchar(320);
    l_seconds number;
begin
    l_stat_id := p_sig_id || '|' || p_parent_sig_id;
    if p_type = 'Q' then
        g_sig_stats(l_stat_id).query_time := g_sig_stats(l_stat_id).query_time +
            seconds_elapsed(localtimestamp - g_sig_stats(l_stat_id).query_start);
    elsif p_type = 'P' then
        g_sig_stats(l_stat_id).process_time := g_sig_stats(l_stat_id).process_time +
            seconds_elapsed(localtimestamp - g_sig_stats(l_stat_id).process_start);
    end if;
exception when others then
    print_log('Error in sig_time_add: '||sqlerrm);
end;



----------------------------------------------------------------
--- Check last snapshot date days and populate the days flag ---
----------------------------------------------------------------

PROCEDURE set_snap_days IS

BEGIN
   select round(sysdate - (select * from (select snapshot_update_date from ad_snapshots
       where snapshot_name like '%_VIEW'
         and appl_top_id in (select appl_top_id from ad_appl_tops where name in ('GLOBAL'))
         and SNAPSHOT_TYPE in ('C','G')
         order by snapshot_update_date desc)
         where rownum = 1),0)+1 into g_snap_days
         from dual;
    print_log ('Snapshot days:' || to_char(g_snap_days));

EXCEPTION WHEN OTHERS THEN
      print_log('Snapshot query errored out');
END set_snap_days;

----------------------------------------------------------------
--- Set Cloud flag                                           ---
----------------------------------------------------------------

PROCEDURE set_cloud_flag IS
    l_response VARCHAR2(2000);
    l_response_compute VARCHAR2(32000);
    l_response_baremetal VARCHAR2(32000);
BEGIN
    BEGIN
        SELECT '1'
           INTO l_response
           FROM dual
           WHERE EXISTS (
             SELECT 1
             FROM (SELECT db_domain AS domain FROM fnd_databases
                          UNION ALL
                          SELECT domain AS domain FROM fnd_nodes) domains
             WHERE UPPER(domains.domain) LIKE '%ORACLECLOUD.%' OR UPPER(domains.domain) LIKE '%ORACLECVCN.%');

        -- If a row is selected we are on the cloud
        IF SQL%ROWCOUNT > 0 THEN
            g_cloud_flag := TRUE;
            RETURN;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            g_cloud_flag := FALSE;
        WHEN OTHERS THEN
            g_cloud_flag := FALSE;
            print_log('Error in set_cloud_flag: '||sqlerrm);
    END;

    BEGIN
       -- set transfertimeout to 15 seconds, we don't want the analyzer waiting more than that
       UTL_HTTP.set_transfer_timeout(15);

       SELECT UTL_HTTP.request('http://192.0.0.192/2007-08-29/meta-data/local-hostname')
       INTO l_response_compute
       FROM dual;

       SELECT UTL_HTTP.request('http://169.254.169.254/opc/v1/instance/')
       INTO l_response_baremetal
       FROM dual;

       -- Check if the response is indeed from an Oracle cloud service
       IF (lower(nvl(l_response_compute,'AAA')) LIKE '%oraclecloud.%' or lower(nvl(l_response_baremetal,'AAA')) LIKE '%oraclevcn.%') THEN
           g_cloud_flag := TRUE;
           RETURN;
       END IF;
    EXCEPTION
        WHEN OTHERS THEN
           -- we are NOT on the cloud
           g_cloud_flag := FALSE;
           RETURN;
    END;

END set_cloud_flag;

PROCEDURE initialize_globals IS
BEGIN
  -- clear tables
  g_sec_detail.delete;
  g_signatures.delete;
  g_sections.delete;
  g_sig_stats.delete;
  g_sql_tokens.delete;
  g_masked_tokens.delete;
  g_fk_mask_options.delete;
  g_rep_info.delete;
  g_parameters.delete;
  g_exec_summary.delete;
  g_sig_errors.delete;
  g_dest_to_source.delete;
  g_source_to_dest.delete;
  g_results.delete;
  g_fam_area_hash.delete;

  -- re-initialize values
  g_sig_id := 0;
  g_item_id := 0;
  g_sig_count := 0 ;

  -- initialize the global results hash
  g_results('S') := 0;
  g_results('W') := 0;
  g_results('E') := 0;
  g_results('I') := 0;
  g_results('P') := 0;    -- for checks that passed, but will not be printed in the report

  -- initialize global hash for converting the family area codes that come from the builder to the anchor format used in Note 1545562
  g_fam_area_hash('ATG') := 'EBS';
  g_fam_area_hash('EBS CRM') := 'CRM';
  g_fam_area_hash('Financials') := 'Fin';
  g_fam_area_hash('HCM') := 'HCM';
  g_fam_area_hash('MFG') := 'Man';
  g_fam_area_hash('MFG ON PREM') := 'Man';
  g_fam_area_hash('EBS Defect') := '';

  -- reset banner settings
  g_banner_severity := 'E';
  g_banner_message := null;

  IF g_is_concurrent THEN
     g_rep_info('Calling From'):='Concurrent Program';
     -- Record calling module (EBSAF-265)
     select nvl(max(CONCURRENT_PROGRAM_NAME), 'Unknown')
     into g_rep_info('Calling Module')
     from FND_CONCURRENT_PROGRAMS
     where APPLICATION_ID = FND_GLOBAL.PROG_APPL_ID
     and CONCURRENT_PROGRAM_ID = FND_GLOBAL.CONC_PROGRAM_ID;
  ELSE
     g_rep_info('Calling From'):='SQL Script';
     -- Record calling module (EBSAF-265)
     g_rep_info('Calling Module'):=nvl( sys_context('userenv', 'module'), 'Unknown');
  END IF;

  -- Assign a GUID to this execution
  g_guid := upper(regexp_replace(sys_guid(), '(.{8})(.{4})(.{4})(.{4})(.{12})', '\1-\2-\3-\4-\5'));

END initialize_globals;

----------------------------------------------------------------
--- File Management                                          ---
----------------------------------------------------------------

PROCEDURE initialize_files is
  l_date_char        VARCHAR2(20);
  l_log_file         VARCHAR2(400);
  l_out_file         VARCHAR2(400);
  l_file_location    V$PARAMETER.VALUE%TYPE;
  l_db_name          VARCHAR2(255);
  l_host             VARCHAR2(255);
  NO_UTL_DIR         EXCEPTION;
  l_step             VARCHAR2(2);
  l_dirs             varchar_tbl;
  l_invalid_paths    number;
BEGIN
  get_current_time(g_analyzer_start_time);
  l_step := '1';

  IF NOT g_is_concurrent THEN
  l_step := '2';

    SELECT to_char(sysdate,'YYYY-MM-DD_hh24_mi') INTO l_date_char from dual;

    SELECT sys_context('USERENV','DB_NAME'), nvl(host_name,sys_context('USERENV','SERVER_HOST'))
    INTO l_db_name, l_host
    FROM v$instance;

    g_params_string := substr(regexp_replace(convert(g_params_string,'US7ASCII'), '\W+', '-'), 1, 64);  -- Filter illegal filename changes
    l_step := '3';

    l_log_file := 'MSCDPA_SQL_Analyzer_'||l_db_name||'_'||g_params_string||l_date_char||'.log';
    l_out_file := 'MSCDPA_SQL_Analyzer_'||l_db_name||'_'||g_params_string||l_date_char||'.html';
    l_step := '4';

    -- Get first valid UTL_FILE_DIR entry
    begin
        -- Try to get path using new 19c method
        execute immediate 'select value from apps.v$parameter2 where name = ''utl_file_dir'' order by ordinal asc'
            bulk collect into l_dirs;
    exception when others then
        -- Get path using old method
        execute immediate 'select value from v$parameter2 where name = ''utl_file_dir'' order by ordinal asc'
            bulk collect into l_dirs;
    end;
    l_file_location := null;
    l_invalid_paths := 0;
    for i in 1..l_dirs.count loop
        if (l_file_location is null) then
            begin
                l_file_location := l_dirs(i);
                -- Set maximum line size to 10000 for encoding of base64 icon
                g_out_file := utl_file.fopen(l_file_location, l_out_file, 'w',32000);
                IF g_debug_mode = 'Y' THEN
                    g_log_file := utl_file.fopen(l_file_location, l_log_file, 'w',10000);
                END IF;
            exception when others then
                l_file_location := null;
                l_invalid_paths := l_invalid_paths + 1;
                -- Unable to create either out or log files at specified directory
                if (utl_file.is_open(g_out_file) ) then
                    utl_file.fclose(g_out_file);
                end if;
                if (utl_file.is_open(g_log_file) ) then
                    utl_file.fclose(g_log_file);
                end if;
            end;
        end if;
    end loop;
    l_step := '5';

    -- Verify a valid file location was found
    if l_invalid_paths > 0 then
        -- Log invalid paths for reference
        dbms_output.put_line('Warning: Unable to create files in the following UTL_FILE_DIR locations: ');
        for i in 1..l_invalid_paths loop
            dbms_output.put_line('- ' || l_dirs(i) );
        end loop;
        dbms_output.new_line;
    end if;
    IF l_file_location IS NULL THEN
        RAISE NO_UTL_DIR;
    END IF;
    l_step := '6';

    dbms_output.put_line('Files are located on Host : '||l_host);
    --dbms_output.put_line('Files are located on the database host.'); -- EBSAF-274; reverted by EBSAF-293
    dbms_output.put_line('Output file : '||l_file_location||'/'||l_out_file);
    l_step := '7';
    IF g_debug_mode = 'Y' THEN
       dbms_output.put_line('Log file : '||l_file_location||'/'||l_log_file);
    END IF;
  END IF;
EXCEPTION
  WHEN NO_UTL_DIR THEN
    dbms_output.put_line('Error in initialize_files at step '||l_step||
        ': Unable to identify a valid output directory for UTL_FILE' );
    raise;
  WHEN OTHERS THEN
    dbms_output.put_line('Error in initialize_files at step '||l_step||': '||sqlerrm);
    raise;
END initialize_files;


PROCEDURE close_files IS
BEGIN
  debug('Entered close_files');
  print_out('<div style="display:none;" id="integrityCheck"></div>'); -- this is for integrity check
  print_out('</BODY></HTML>');
  IF NOT g_is_concurrent THEN
    debug('Closing files');
    IF g_debug_mode = 'Y' THEN
       utl_file.fclose(g_log_file);
    END IF;
    utl_file.fclose(g_out_file);
  END IF;
END close_files;


----------------------------------------------------------------
-- REPORTING PROCEDURES                                       --
----------------------------------------------------------------

----------------------------------------------------------------
-- UTILITIES                                                  --
----------------------------------------------------------------

----------------------------------------------------------------
-- Replace invalid chars in the sig name (so we can use the   --
-- the sig name as CSS class                                  --
----------------------------------------------------------------
FUNCTION replace_chars(p_name VARCHAR2) RETURN VARCHAR2 IS
    l_name         VARCHAR2(512);
BEGIN
    l_name := p_name;
    l_name := REPLACE(l_name, '%', '_PERCENT_');
    l_name := REPLACE(l_name, '*', '_STAR_');  --EBSAF-279
    l_name := REPLACE(l_name, ':', '_COLON_');
    l_name := REPLACE(l_name, '/', '_SLASH_');
    l_name := REPLACE(l_name, '&', '_AMP_');
    l_name := REPLACE(l_name, '<', '_LT_');
    l_name := REPLACE(l_name, '>', '_GT_');
    l_name := REPLACE(l_name, '(', '__');
    l_name := REPLACE(l_name, ')', '__');
    l_name := REPLACE(l_name, ',', '----');
    -- Only replace underscores if needed (EBSAF-279)
    if instr(l_name, ' ') > 0 then
        -- replace existing _ with double _ and spaces with _ (to avoid multi-word section and signature names)
        l_name := REPLACE(l_name, '_', '__');
        l_name := REPLACE(l_name, ' ', '_');
    end if;
    -- Only replace dashes if needed (EBSAF-279)
    if instr(l_name, '.') > 0 then
        -- replace existing - with double - and . with - (as Firefox does not accept . in the css class name)
        l_name := REPLACE(l_name, '-', '--');
        l_name := REPLACE(l_name, '.', '-');
    end if;
    RETURN l_name;

EXCEPTION WHEN OTHERS THEN
    print_log('Error in replace_chars: '||sqlerrm||'.  Text unmodified.');
    return p_name;
END replace_chars;

----------------------------------------------------------------
-- Escape HTML characters (& < >)                             --
----------------------------------------------------------------
FUNCTION escape_html(p_text VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN REPLACE(REPLACE(REPLACE(p_text,
        '&','&amp;'),
        '>','&gt;'),
        '<','&lt;');
EXCEPTION
    WHEN OTHERS THEN
        print_log('Error in escape_html: '||sqlerrm||'.  Text unmodified.');
        RETURN p_text;
END escape_html;

----------------------------------------------------------------
-- Prints the Cloud image in the page header and              --
-- also in the Execution Details pop-up page,                 --
-- if the domain like "%oraclecloud.internal%"                --
----------------------------------------------------------------
PROCEDURE print_cloud_image IS
BEGIN
  IF (g_cloud_flag = TRUE) THEN
       print_out ('<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAepJREFUeNq01U9IVFEUx/FxHEFNNAPdCEGMKLQJpVwIokYzJYpiCNGqchEIQiBUIu0E/4DgQlwVBq2Cgv4oBQOC/6hAWrQIXAilhC5caCL+qcX4PfJb2HDHec9mLnx478277553z5x7XzAejwcyKRjIcMuKRCLJ7p3FA3SgHL/xDeN47zVAdjgcdv1+EQtoQylCKIB1vo0LOMAfBU7aXCkqwkecxxc0Ig9leIhd3MEHrGAGl/wE6NHgn1GvAfaxhhG0YhoxbKuP9b3qJUA+bum8TylIbDb4NVzXrJ5phq8wpoDOAPfwE5W6/uThP9zBfQU9h27N+C0KjwcYxgRKsIj+JG/vanHcRbOe21JxvLEisjJt4WRSA9qf9/I/S98qbF7p67QZPNKN3jQMbu0HHuv8KEC1Lp6ncQFP6VhlAbJ14cr5rHJ8khnHc3s65gS1/K3dcHTM9/C2rj6XdVy2AC90MYjihI5XbL9KoSZxf8MTnb+zAE9VmhXaGlq0cPymKEt72Gs0YQOjFuCv6vargljJLvlI0RkdB/AdN7GJdgsS0s111KLLSgu5x1IU8LHgfukFh7Ca6ntgbQ51KQa2NDb42U3/+V54ePOcE79o9t10tWg06mtlxWKxU81g7pQLzXOAUMZSlK52KMAAKSLBDAvj51YAAAAASUVORK5CYII=" class="smallimg" title="This is a Cloud instance">');
  END IF;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in print_cloud_image: '||sqlerrm);
END print_cloud_image;


----------------------------------------------------------------
-- Prints HTML page header and auxiliary Javascript functions --
----------------------------------------------------------------
PROCEDURE print_page_header is
    l_html_clob clob;
BEGIN
    dbms_lob.createtemporary(l_html_clob, true);

    ------------------------------------------------------------
    -- Main header
    ------------------------------
    print_out('<HTML>');
    print_out('<HEAD>');
    print_out('  <meta http-equiv="content-type" content="text/html; charset=UTF-8">');
    print_out('  <meta http-equiv="X-UA-Compatible" content="IE=edge" />');
    print_out('<TITLE>MSCDPA_SQL Analyzer Report</TITLE>');

    ------------------------------------------------------------
    -- Styles (EBSAF-262)
    ------------------------------
    -- Start with empty CLOB to ensure string literals are concatenated as such
    dbms_lob.trim(l_html_clob, 0);
    l_html_clob := l_html_clob ||
'/* TableSorter Default Theme */

.tablesorter-default .header,
.tablesorter-default .tablesorter-header {
    background-image: url(data:image/gif;base64,R0lGODlhFQAJAIAAACMtMP///yH5BAEAAAEALAAAAAAVAAkAAAIXjI+AywnaYnhUMoqt3gZXPmVg94yJVQAAOw==);
    background-position: center right;
    background-repeat: no-repeat;
    cursor: pointer;
    white-space: normal;
    padding: 4px 20px 4px 4px;
}

.tablesorter-default thead .headerSortUp,
.tablesorter-default thead .tablesorter-headerSortUp,
.tablesorter-default thead .tablesorter-headerAsc {
    background-image: url(data:image/gif;base64,R0lGODlhFQAEAIAAACMtMP///yH5BAEAAAEALAAAAAAVAAQAAAINjI8Bya2wnINUMopZAQA7);
    border-bottom: #CC6666 1px solid;
}

.tablesorter-default thead .headerSortDown,
.tablesorter-default thead .tablesorter-headerSortDown,
.tablesorter-default thead .tablesorter-headerDesc {
    background-image: url(data:image/gif;base64,R0lGODlhFQAEAIAAACMtMP///yH5BAEAAAEALAAAAAAVAAQAAAINjB+gC+jP2ptn0WskLQA7);
    border-bottom: #CC6666 1px solid;
}

.tablesorter-default thead .sorter-false {
    background-image: none;
    cursor: default;
    padding: 4px;
}

/* Analyzer CSS, 2.5.11 2025/12/05 00:00:00 fvaduva */

* {
  font-family: "Oracle Sans", "Segoe UI", sans-serif;
  color: #505050;
  font-size: inherit;
}

a {
    color: #3973ac;
    border: none;
    text-decoration: none;
}

img {
    border: none;
}

pre {
    margin: 0px;
}

a.hypersource {
  color: blue;
  text-decoration: underline;
}

a.nolink {
  color: #505050;
  text-decoration: none;
}

a.tagcount {
  color: blue;
  text-decoration: underline;
}

a.tagcount:hover {
    cursor: pointer;
}

a.hypersource {
  color: blue;
  text-decoration: underline;
}

a.nolink {
  color: #505050;
  text-decoration: none;
}

.successcount {
   color: #76b418;
   font-size: 20px;
   font-weight: bold;
}

.warncount {
   color: #fcce4b;
   font-size: 20px;
   font-weight: bold;
}

.errcount {
   color: #e5001e;
   font-size: 20px;
   font-weight: bold;
}

.infocount {
   color: #000000;
   font-size: 20px;
   font-weight: bold;
}

input[type=checkbox] {
  cursor: pointer;
  border: 0px;
  display:none;
}

.exportcheck {
    margin-bottom: 0px;
    padding-bottom: 0px;
}

.export2Txt {
    padding-left: 2px;
}

.pageheader {
    position: fixed;
    top: 0px;
    width: 100%;
    height: 75px;
    background-color: #F5F5F5;
    color: #505050;
    margin: 0px;
    border: 0px;
    padding: 0px;
    box-shadow: 10px 0px 5px #888888;
    z-index: 1;
}

.header_s1 {
    margin-top: 6px;
}

.header_img {
    float: left;
    margin-top: 8px;
    margin-right: 8px;
}

.header_title {
    display: inline;
    font-weight: 600;
    font-size: 20px;
}

.header_subtitle {
    font-weight: 300;
    font-size: 13px;
}

.menubox_subtitle {
    font-weight: 300;
    font-size: 13px;
}

.header_version {
    height: 16px;
    opacity: 0.85;
}

.floatingHeader {
  position: fixed;
  top: -76px;
  display: none;
}
.floatingHeader[docked] {
  position: static;
  display: table-header-group;
}
.pheader {
  position: static;
}
.pheader[undocked] {
  position: fixed;
  top: 76px;
}

td.hlt {
  padding: inherit;
  font-family: inherit;
  font-size: inherit;
  font-weight: bold;
  color: #333333;
  background-color: #FFE864;
  text-indent: 0px;
}
tr.hlt {
    background-color: #FFFBE5;
}

.blacklink:link, .blacklink:visited, .blacklink:link:active, .blacklink:visited:active {
   color: #505050;

}

.blacklink:hover{
   color: #808080;
}

.error_small, .success_small, .warning_small {
   vertical-align:middle;
   display: inline-block;
   width: 24px;
   height: 24px;
}

.h1 {
    font-size: 20px;
    font-weight: bold;
}

.background {
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAYAAAAGCAIAAABvrngfAAAAIElEQVQIW2P49evX27dvf4EBhMGAzIEwGNCUQFWRpREAFU9npcsNrzoAAAAASUVORK5CYII=");
}

.body {
    top: 30px;
    width: 100%;
    padding: 0px;
    font-size: 14px;
}

.footerarea {
    height: 35px;
    bottom: 0px;
    position: fixed;
    width: 100%;
    background-color: #F5F5F5;
    border-top: 1px solid #D9DFE3;
    z-index:100;
}

.footer {
    visibility: visible;
    max-height: 29px;
    min-height: 29px;
    background-color: #F5F5F5;
    color: #145c9e;
    font-weight: normal;
    font-size: 14px;
}

.separator {
    border-left: 1px solid #D6DFE6;
    margin-left: 10px;
    margin-right: 10px;
    height: 22px;
    width: 0px;
    vertical-align: middle;
    display: inline-block;
}

body {
    color: #505050;
    margin: 0px;
    padding: 0px;
    background-color: #F5F5F5;
    overflow-y: auto;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAYAAAAGCAIAAABvrngfAAAAIElEQVQIW2P49evX27dvf4EBhMGAzIEwGNCUQFWRpREAFU9npcsNrzoAAAAASUVORK5CYII=");
}

.header, .footer { padding: 0px 1em;}

.icon {
    border: none;
    vertical-align:middle;
    width: 32px;
    height: 32px;
    display: inline-block;
}

.table1 {
    vertical-align: middle;
    text-align: left;
    padding: 3px;
    margin: 1px;
    min-width: 1200px;
    font-size: small;
    border-spacing: 1px;
    border-collapse: collapse;
}

.table2 {
    vertical-align: middle;
    text-align: left;
    padding: 3px;
    margin: 1px;
    width: 100%;
    border-spacing: 1px;
}

th.sigdetails {
    background-color: #f2f4f7;
}

th.sigdetails.masked {
    background-color: #d2d4d7;
}

tr.tdata td{
    border: 1px solid #f2f4f7;
    white-space: pre;
}

tr.tdata td.masked{
    background-color: #eeeeee;
}
span.masked{
    background-color: #eeeeee;
}

.topmenu {
    position: absolute;
    right: 50px;
    float: right;
    bottom: 10px;
    font-size: 12px;
    color: #505050;
    font-weight: bold;
    text-shadow: none;
    background-color: #f7f8f9;
    background-image: none;
}

.fullsection {
    padding-right: 5px;
}

.menubutton {
    border: 1px solid;
    cursor: pointer;
    display: inline;
    float: left;
    background-color: #fafafa;
    background-image: none;
    padding: 4px 15px 1px 10px;
    height: 28px;
    border-color: #d9dfe3;
    filter: none;
    border-left-color: rgba(217, 223, 227, 0.7);
    border-right-color: rgba(217, 223, 227, 0.7);
    text-shadow: none;
    vertical-align: middle;
    font-weight: 600;
    font-size: 14px;
}

.menubutton:hover {
    background-color: #EEEEEE;
}

.whatsnew_ico:hover {
    cursor: pointer;
}

.smallimg {
    padding: 0px 2px 1px 0px;
    vertical-align: middle;
    height: 18px;
    width: 18px;
    opacity: 0.75;
}

.menubox {
    border: 1px solid lightblue;
    background-color: #FFFFFF;
    display: inline;
    width: 300px;
    height: 390px;
    float: left;
    padding: 10px;
    border-radius:2px;
    border: 1px solid #E7E7E9;
}

.menuboxitem {
    white-space: nowrap;
    font-size: 16px;
    cursor: pointer;
    padding: 10px 0px 10px 0px;
}

.menuboxitem:hover {
    background-color: #EEEEEE;
}

.menuboxitemt {
    white-space: nowrap;
    font-size: 18px;
    padding: 10px 0px 10px 0px;
}

.mboxelem {
    margin-left:8px;
    text-align:left;
    display:inline-block;
}

.mboxinner {
    margin-left: 15px;
    margin-top: 6px;
}

.mainmenu {
    overflow-y: auto;
    padding: 50px 100px 50px 100px;

}

.maindata {
    display: none;
    width: auto;
    overflow: visible;
    min-height: 600px;
    height: 100%;
}

.leftcell {
   width:200px;
   vertical-align:top;
   padding: 0px;
}

.rightcell {
   vertical-align:top;
   padding: 0px;
}

.floating-box {
    display: inline-block;
    width: 277px;
    height: 120px;
    margin: 5px;
    padding: 10px;
    border: 1px solid #E7E7E9;;
    background-color: #FFFFFF;
    text-align: center;
    border-radius:2px;
    font-size: 16px;
}

.floating-box:hover {
    background-color: #bfdde5;
    font-weight: 600;
}

.textbox {
    text-align: center;
    height: 60px;
    width: 100%;
}

.counternumber {
    padding: 5px;
    vertical-align: top;
    height: 100%;
    display: inline;
    vertical-align:middle;
}

.counterbox {
    padding-top: 10px;
    height: 30px;
    font-size:20px;
    font-weight:bold;
    width: 100%;
    border: none;
}

.backtop {
    position:fixed;
    width: 90px;
    height: 25px;
    bottom: 35px;
    right: 20px;
    background-color: white;
    padding-left:15px;
    border-radius:10px;
    font-size:14px;
    color:#3973ac;
    vertical-align:middle;
}

.backtop:hover {
    background-color: #bfdde5;
}

.popup {
    width:100%;
    height:100%;
    display:none;
    position:fixed;
    top:0px;
    left:0px;
    background:rgba(0,0,0,0.75);
    border: solid 1px #8794A3;
    border-color: #c4ced7;
    color: #333333;
}

.popup-inner {
    max-width:700px;
    width:90%;
    overflow-y:auto;
    max-height: 90%;
    padding: 0px;
    position:absolute;
    top:50%;
    left:50%;
    -webkit-transform:translate(-50%, -50%);
    transform:translate(-50%, -50%);
    box-shadow:0px 2px 6px rgba(0,0,0,1);
    border-radius:3px;
    background:#fff;
    font-size: 14px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAYAAAAGCAIAAABvrngfAAAAIElEQVQIW2P49evX27dvf4EBhMGAzIEwGNCUQFWRpREAFU9npcsNrzoAAAAASUVORK5CYII=");
}

.popup-title {
    display: table-cell;
    vertical-align: top;
    top: 10px;
    padding: 10px;
    border-bottom: 1px solid lightblue;
    background-color: #F5F5F5;
}

.close-button {
    display: inline-block;
    padding: 4px 7px 1px 7px;
    margin-right:20px;
    margin-bottom:20px;
    float:right;
    vertical-align: bottom;
    min-height: 18px;
    border: 1px solid #c4ced7;
    border-radius: 2px;
    background-color: #E4E8EA;
    font-size: 12px;
    color: #000000;
    text-shadow: 0px 1px 0px #FFFFFF;
    font-weight: bold;
}

.close-button:hover {
    background-color: #FFFFFF;
}

.popup-paramname {
    display: table-cell;
    width: 50%;
    text-align: left;
    vertical-align: top;
    padding: 10px 5px 5px 10px;
}

.popup-paramval {
    display: table-cell;
    width: 50%;
    text-align: left;
    vertical-align: top;
    padding: 10px 10px 5px 5px;
}

.close-link {
    padding: 0px 12px 10px 10px;
    text-align: right;
    float: right;
    color: blue;
}

.popup-value {
    display: table-cell;
    vertical-align: top;
    top: 10px;
    border-bottom: 1px solid lightblue;
    background-color: #F5F5F5;
}

.sectionmenu {
    border-top: 1px solid #E7E7E9;
    border-radius: 5px 0px 0px 5px;
    margin: 0px 0px 2px 7px;
    left:0px;
    width:200px;
    z-index: 3;
}

.sectionbutton, .subsectionbutton {
    cursor: pointer;
    background-color: #e7ecf0;
    border-left: 1px solid #D6DFE6;
    border-bottom: 1px solid #D6DFE6;
    border-right: 2px solid white;
    font-weight: normal;
    font-size: 14px;
    border-top: 0px;
    border-right: 0px;
    border-radius: 5px 0px 0px 5px;
    padding: 5px;
    display: none;
    margin-right: 0px;
    word-wrap: break-word;
}

.sct-submenu {
    padding-left: 5px;
}

.sct-submenu[sct-root="true"] {
    padding-left: 0px;
}

.sigcontainer {
    font-weight: normal;
    font-size: 12px;
    background-color: #FFFFFF;
    border: 1px solid #D6DFE6;
    border-radius: 3px;
    padding: 5px;
    margin: 5px 5px 5px 5px;
    width: auto;
    display: block;
    z-index:2;
}

.tagarea {
    font-weight: normal;
    font-size: 12px;
    background-color: #FFFFFF;
    border: 1px solid #D6DFE6;
    border-radius: 3px;
    padding: 5px;
    margin: 5px 5px 5px 5px;
    width: 400px;
    display: none;
}

.containertitle {
   font-weight: bold;
   font-size: 25px;
   text-align: center;
   padding-bottom: 10px;
   padding-top: 5px;
}

.searchbox {
   width:100%;
   font-size: 14px;
   display:block;
   padding-left: 5px;
}

.search{
   display:block;
   font-weight: normal;
   font-size: 12px;
   color: #333333;
   border-radius: 2px;
   background-color: #FCFDFE;
   border: 1px solid #DFE4E7;
   padding: 6px 5px 5px 5px;
   height: 28px;
   margin-top: 5px;
}

thead tr .search_match {
    border: 2px dotted #76b418;
}
tr.tdata .search_match {
    border: 2px dotted #76b418;
}

.expcoll {
   display:block;
   padding-left: 0px;
   padding-top:5px;
   padding-bottom:5px;
   margin-left:10px;
   float:left;
   font-size: 12px;
}

.sigtitle {
    font-size: small;

}

.sigdetails {
    font-size: 12px;
    margin-bottom: 2px;
    padding: 2px;
}

.signature {
    border: 1px solid #EAEAEA;
    padding: 6px;
    font-size: 12px;
    font-weight: normal;
}

.divtable {
    overflow-x: hidden;
    width: 100%;
    z-index:3;
    margin: 3px;
    margin-right: 10px;
}

.results {
    z-index:4;
    margin: 5px;
}

.divItemTitle{
    text-align: left;
    font-size: 18px;
    font-weight: 600;

    color: #336699;
    border-bottom-style: dotted;
    border-bottom-width: 1px;
    border-bottom-color: #336699;
    margin-bottom: 9px;
    padding-bottom: 2px;
    margin-left: 3px;
    margin-right: 3px;
}

.divItemTitlet{
    font-size: 16px;
    font-weight: 600;
    color: #336699;
    border-bottom-style: none;
}

.arrowright, .arrowdown {
    display: inline-block;
    cursor: pointer;
    font-size: 12px;
    color: #336699;
    padding: 2px 0px 10px 2px;
    vertical-align: middle;
    height: 18px;
    width: 18px;
}

.divwarn {
  color: #333333;
  background-color: #FFEF95;
  border: 0px solid #FDC400;
  padding: 9px;
  margin: 0px;
  font-size: small;
  min-width:1200px;
}

.divwarn1 {
  font-size: small;
  font-weight: bold;
  color: #9B7500;
  margin-bottom: 9px;
  padding-bottom: 2px;
  margin-left: 3px;
  margin-right: 3px;
}

.solution {
  font-weight: normal;
  color: #0572ce;
 font-size: small;
  font-weight: bold
}

.detailsmall {
  text-decoration:none;
  font-size: xx-small;
  cursor: pointer;
  display: inline;
}

.divuar {
  border: 1px none #00CC99;
  font-size: small;
  font-weight: normal;
  background-color: #ffd6cc;
  color: #333333;
  padding: 9px;
  margin: 3px;
  min-width:1200px;
}

.divuar1 {
  font-size: small;
  font-weight: bold;
  color: #CC0000;
  margin-bottom: 9px;
  padding-bottom: 2px;
  margin-left: 3px;
  margin-right: 3px;
}

.divok {
  border: 1px none #00CC99;
  font-size: small;
  font-weight: normal;
  background-color: #d9f2d9;
  color: #333333;
  padding: 9px;
  margin: 3px;
  min-width:1200px;
}

.divok1 {
  font-size: small;
  font-weight: bold;
  color: #006600;
  margin-bottom: 9px;
  padding-bottom: 2px;
  margin-left: 3px;
  margin-right: 3px;
}

.divinfo {
  border: 1px none #BCC3C1;
  font-size: small;
  font-weight: normal;
  background-color: #eff3f5;
  color: #333333;
  padding: 9px;
  margin: 3px;
  min-width:1200px;
}

.divinfo1 {
  font-size: small;
  font-weight: bold;
  color: #000000;
  margin-bottom: 9px;
  padding-bottom: 2px;
  margin-left: 3px;
  margin-right: 3px;
}

.anchor{
  padding-top: 100px;
  color: #505050;
}

.tabledata tr[visible="false"],
.no-result{
  display:none;
}

.exportAll {
  display:inline;
}

.exportAllImg {
  display:inline;
}

.tabledata tr[visible="true"]{
  display:table-row;
}

.counter{
  padding:8px;
  color:#ccc;
}

.brokenlink {
    display: inline-block;
    height: 15px;
    width: 10px;
    background-image: url("data:image/false;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAPCAYAAADd/14OAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAABLSURBVChTY/wPBAxEACYoTRCgKrw3h+GTrCrDO+85DH+hQjBApol4AHaFGkoMzFAmDNDaaiUlnDqJNpHMmNlTzvCO0gCndqJgYAAAyhkXWDyo/t0AAAAASUVORK5CYII=");
}

/* Masking buttons */
.mask_enabled {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAATJJREFUeNpi/P//P4OamhoDMohNK4gCUllAbAAVugDE0xbPmrAMWd2tW7cYmBjQAFDzLAFBwaUioqLWzMzM3CAMYoPEgHJz0NUzoWmOFBAQTP3w/v2fN69fF/39+1cYiAWB7EKg2F+gXDJIDbIeFjQDs9jY2UF0M9C5/UjiE4AaBdk52OugXluO1QVAYPj+3VsQPY8BE8x89xYsZ4gsyAgKxMNTY8CcA9+t/oNoB85jjFgMwJC3zV4C8QIXJ8fHb99/8AElYGr/YzMAWR6o5xOQ5gcbANJsZqjBQAo4df4GH7YwQAf/cbkGVyAiA1CIKQKxEhC/w6WIBY8Br4H4ERJbiFQDQIECSzTq5LgABE4SCkx8YfAMiAWg+Bk5LpAC4jOEXABLSJ9g8UosgCYkBoAAAwAan2XYz/UdXgAAAABJRU5ErkJggg==");
}
.mask_disabled {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAANtJREFUeNpi/P//P0NH70QGNBAFxFlAbADlXwDiaUC8DFlRRXE+AwsDJpgFxKloYtZQ7ATEKcgSTGgKI6Ga/wBxERALA7EgEBcC8V8gToaqwWlAFpRuBuJ+IH4HxB+AeAIQt6KpwWqAIZSeh8VrM9HUYDWAG0o/wWLAMzQ1KAYcBuL/SOL/cWBk+cPIBtgwkA5ssHkBHaDbjAHwGfAWiBWBWAkaG1gBCx4DXgPxIyS2EKkGaCAlGnVyXAACJwmFJL4wAMW7ABQ/I8cFUkB8hlgXHCEjHRwFEQABBgBFOS62FueYEgAAAABJRU5ErkJggg==");
}
/*
Default: 242, 244, 247 = #f2f4f7
Hover:   240, 233, 205 = #f0e9cd
Masked:  237, 222, 164 = #eddea4
*/
.mask_target:hover {
    cursor: pointer;
    background-color: #f0e9cd;
}
.mask_header[mask="on"] {
    cursor: default;
    background-color: #eddea4;
}

/* Hidden data */
div[temp-filter-search], div[temp-filter-hidden] {
    display: none;
}

.hidden_data {
    display: none;
}
.hidden_data[hide-type="err"] {
    color: #e5001e;
}
.hidden_data[hide-type="wrn"] {
    background-color: #fcce4b;
    white-space: pre;
}

tr.tdata td.hidden_data_parent_err {
    border: 2px solid #e5001e;
}

tr.tdata td.hidden_data_parent_wrn {
    border: 2px dashed #fcce4b;
}

.hidden_ico {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA3XAAAN1wFCKJt4AAAAB3RJTUUH4wUJEw4dCglfCAAAAnFJREFUOMuNk0tIVHEUxn/nP46oTVhkFFFBL40WQkRQREEbQYiINhFY0MOKIp2xGfUqyVQ2V51rc61QqYUhiNIiilrUokVBm6AsiEqStBa5M7ScbBzvaeFUCEZ+m3MOnPPxnRfMgVhLgvki609R3F0oQvf0lHesrjo0Ol8C89eVPGCbz28eOo0x+VdBNNo1K56VGIsndonIE4GbCrlAUSZnBOVRemhT5/n2kunqq3doqdg/o+B3v80tbXl1kdBTgQsK5UAZsBVYBaxDsH1r36abHPfy4snhRQB2a2JGwaVYa74/29evqvesSChkO+47YGNG5F4rXHnfjrvLMLITpRf0K8bbZVVVvRc73rYA0bfAtKA7snzZP6d0Kh+PjxmCBORGkORSQY+mJgJX/HkT/cBKRIoMorYiS/zG21wbDo2kpqfaSTOqcGCGQCsg+Qblharsa2gonwzk5mxBdBLVTgOUinrxcFXVGICojmG4XhcO3gYeA75MOytQfQ5w9sypJGoqgd0GtAaRqO24hwDEyBWgzHbcyuSnDyXAt8ySfmDkGkCz424H7UGl3KTS3l2gD+i2422HAwHfoGL2AMdz1hQuF5WSzCy6rHPBATueKPXgGUjPq6GXfQJw1blhvpM8IdABDCBy3Ut5D+qt0DCAHXe7EA4CA0CxKKfH06OdMeuiGoBx892rCwc7wStE+YzqReOXIdtxtclxe61I8AjwBSj2VNfXRoId+aZAZ11ic+IaNaGzzBxIWwGeV4BIHijq09cmbYpU6AduWeHgyXk9SjQanWVtx220HXfcdhKr5/yF/6E+1i6B7NQGPDNoVVd4AL8AVmv8erkAFsYAAAAASUVORK5CYII=");
}
.hidden_ico[shown] {
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA3XAAAN1wFCKJt4AAAAB3RJTUUH4wUKDjQz9T0TcwAAAflJREFUOMvNkj1oU3EUxX/330qoFYKDg5PUpZMfVVDQSWlFXIqDKQ5iS/EDo+lr85LyMpQimKfJi3nvSRBBUawOLipaQSiFzi5W7CAVXFxEENFIK9q865BYEsiuZ7qXy7mce8+Bfw35W0xXKkwnk+uDvBdshqhLECUyP5xsqgpwLFnkaG+MVCrVumCdWArOieoosA3oBiLgG/ARpOLYYw9bFAyNBzwqj+F6/l7gBbAFeCWwpMgvIdqgyG/gALBb4YPAoGNbS1OuV1fgFv0LCBXgGarnMR0n0WgKiAPe13g8W9i3Xa/NL/ZENb2FcFhhOGdbD4zrlfsQKgr3HdsaFCMxNLrcIKOqtwtnRtR9+TamNfPZyVhHEJ4LzOQ9f6cBcw+YydnW6QZhV+P2+o1GbuaL5V7pXHOhNgDgpK3jILOC3ukETKsvsoY29cohEXmnChjmmwafBIkZIzIKnHI9PwDQSF8D39tYXlWVNwBXPb8MDCt6sf5Ez58ASgp3FbJi6JeIsOEIwBcjZGrIrKheAUZUSeQy1hO5vjLAxMY5XC/YA/oU2AosKCwK/ESJYbQblR3Awbq9nHBsa9kthW2CVAyGRPQS0NMUpCqwjFBw0tZc2yiHYciNhVXeP54EwC2Em5CoS41GHSZamRxPrwKcTTv07+8jkUjwf+APzp3C7mJ3tzAAAAAASUVORK5CYII=");
}

.internal:not([data-internal="true"]) {
    display: none !important;
}

.siginfo_ico {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAXNJREFUeNqUU80uA1EYPXNHSliMaJPZ6EITi5LY8ARiUSuPYFOKjXTjISxYo30ADyCxaDyENGLVkJakSYsR/RlFnXvvVCYzpvRLzvzdc858Ofe7BraLCNQCkSXWiTnvW4W4JArEjZ885nuOEUfELuJJgSmLq+N6peem0XbSaFb3+XZG5ImO30CKL2DZa0gkEarYhMa0LWiSw0t93uvwXXiU40hxsOLkWPaq1y2kwSKRQ2I2xO0fLCmESnN3pFaowBJJEzDw/yJXaZCVGWQwaf1OO7yO9lCaakYapH7SDrQ/1EhrUiKyyWF/V3/oY7ALFXy4GLm05l6oCWs7oxt0XuW1JA2KaFQ/2VNkBuGtJFdpUJAhlokTNGp7/kEamkGjBqWhdhBiHk69RNe/W2+S49SvvPMAE8sb8i7bOYfbmsHz4wpM04DJ5oSp0+51gbcn4OH2C93WKbmbhKtHKnyc5WhvqQGTM8KtIu5kYN5xLvvJ3wIMAEduatirqrxIAAAAAElFTkSuQmCC");
}

.whatsnew_ico {
    display: inline-block;
    height: 23px;
    width: 23px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4QYTDTErvhkC9wAAAjhJREFUSMfFls9rE0EUxz+psT9StsRmWawePCjWoMHqZfwbbE+i1MbWRcGqf5HtRYyVJgerF/8FsbmIcQSxhx4EjQybGjKYpEklHhxhm+4m2Sr4YA/LfOf75s173/cm1ul0GNSKucwnAOHK6UH3xIlmZyPiGeIfWzGXiQVGYBY+A2+AReHKVkTiYWDDRDl9IALhyg6w6djWDSBvNnTbtvmCyF86KWsOeN0rB7eUp484tnVNeXoNmPcvCleeDgmg4KSsq6qi14F7oQ6EK1vFXOam8vRT4LzvdA+ABeCCgX4A8sCKucpzqqIfA8vClT/9nLFeZVrMZU4CrxzbmplMJhgb/X1rjWaLnWod5el3wJxw5ZcwjlAH5uTFE8eTM1PORCCmrGp8/VYtAUK4cjdqmd53bCuUHGDKmcCxrYvA8mF0kJ1MJvqWp8FkQ5Vs5O9X6JZpBZcTY8N9HRjMJV8r2cc1FFCqkdqHSWE7ZG883qO239YbrSvjiZGeDhrN1p+yDdRJrxzkd6r1vhEYTP4wSV5Vni6VVS0UUFY1lKffA6uRddAttNSxcUZHjgLQ3G1T+f4D5ekSMBtJaEZgBSAtXJk2/w+BRSBtYB+BZ8Aj0162gE3grnDlXqgDQ/bCSVmzqqLXhCtvD9iqC45tzStPPweywpXtsJLcMOR54E6EkbmkPB13bOu68vSeaYz7k2wGzilV0U+Ape6u6BuZB8amOfGC8vQ6cGbgJAdE0DGEsf82k//2VbEd1cEvrVrxKdMN1qwAAAAASUVORK5CYII=");
}

/* Section buttons */
.copysql_ico {
    height: 16px;
    width: 16px;
    display: inline-block;
    background-size: contain;
    background-repeat: no-repeat;
    background-image:  url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5ggeFAMd33sN5AAAAKNJREFUOMudUikSwzAMXGX8rcL8R8DEJWmRiIHf07BOQH6VknjGUa1GzSJrPVqtDoKC5PICMGo+RSbJZUqRny0/4BsjbDwkl+lM4AwHkaHally2KyLBYfswB80Fb8mewxSZrswAniFKa9d6mwIp8r1a3ve/9fo3BX4luAT2qmyJtXHwTLyN9V/PwexcwAwApFRvKfLyzxrJOhLvNdYW3s78VRMfzKVKHhr36QkAAAAASUVORK5CYII=");
}

.export_ico {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA2hpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMy1jMDExIDY2LjE0NTY2MSwgMjAxMi8wMi8wNi0xNDo1NjoyNyAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0ieG1wLmRpZDo2QUVENDk5NjdGMjM2ODExODIyQURBRDlDNkZERTUzMyIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDpBOTRBQzQzMTQ3NjkxMUU0OTZEMEZDMjFEMDE4Q0VDRiIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDpBOTRBQzQzMDQ3NjkxMUU0OTZEMEZDMjFEMDE4Q0VDRiIgeG1wOkNyZWF0b3JUb29sPSJBZG9iZSBQaG90b3Nob3AgQ1M2IChNYWNpbnRvc2gpIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6NTM0ODVEQ0I0ODIwNjgxMTgyMkFCMTdDQzcxMzg3NzIiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6NkFFRDQ5OTY3RjIzNjgxMTgyMkFEQUQ5QzZGREU1MzMiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+IDw/eHBhY2tldCBlbmQ9InIiPz6s1KKrAAAAf0lEQVR42mI07fb79+PvT0YGMgAXM8c/FpBmCRVpcvQzvLjzlImJgUIw8AYw7tix47+trS1Zmg8fPjwIvMCCTzJgey6G2AbPyaS5oNk8H4UmygXINteenIhCEx0GMBthTkZ3OkEDYDbCXIMtPHB6AZdtNEuJ74G0AJn63wAEGACAQStffMHfsAAAAABJRU5ErkJggg==");
}

.export_txt_ico {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsQAAA7EAZUrDhsAAAAZdEVYdFNvZnR3YXJlAEFkb2JlIEltYWdlUmVhZHlxyWU8AAADaGlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNS4zLWMwMTEgNjYuMTQ1NjYxLCAyMDEyLzAyLzA2LTE0OjU2OjI3ICAgICAgICAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgeG1wTU06T3JpZ2luYWxEb2N1bWVudElEPSJ4bXAuZGlkOjZBRUQ0OTk2N0YyMzY4MTE4MjJBREFEOUM2RkRFNTMzIiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOkE5NEFDNDMxNDc2OTExRTQ5NkQwRkMyMUQwMThDRUNGIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOkE5NEFDNDMwNDc2OTExRTQ5NkQwRkMyMUQwMThDRUNGIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDUzYgKE1hY2ludG9zaCkiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDo1MzQ4NURDQjQ4MjA2ODExODIyQUIxN0NDNzEzODc3MiIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo2QUVENDk5NjdGMjM2ODExODIyQURBRDlDNkZERTUzMyIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PqzUoqsAAABKSURBVDhPY9yxY8d/BgoA2ICHikZQLmlA/v45BiYom2ww8AaAw8DW1hbKJQ0cPnx4OITBqAGDwQDGPXv2/P/z5w+USxpgY2NjAAAByhXLwOyrWgAAAABJRU5ErkJggg==");
}

.export_html_ico {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAATdJREFUeNpibN39fA8DA4MzA3lgLxMFmkHAmQVIMIJYVS4SZJkAMuA/iNG25wVZBjBhEQMZmAbE7khi9kCcB7OMkAHFQO/MBtIqSGJKQLHJQLqCkAEtQIX9QO+EA9mTkMTnAMUCgHJdQHY7LgOmAhXUAhV6ANmLgJgZSQ7EXgmUcwaqqQKyp8MkGIHpAOSvpUAcC8RWQLwLiLlwhNk3IHYC4lNAvBiIo2EuKIDSM/FoZoDKzUXWAzNgLtSZkUD8EY8Br6FqWIF4HrIBfkC8AIivQKPvGxbNX4HYF6pmHpSNEojRQNwPDKSTQDoUiH8hyYHYflC5KVC1WKMxHxjSlUCF24DsdCTxWKDYPqBcI5CdhawBFgvoIB+IrwLxHijfEogtQC7Elhc2ArE/mvhENP5xHIG6ASDAAPC+UvCkGM89AAAAAElFTkSuQmCC");
}

.sort_ico {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAALhJREFUeNpi/P//PwMMtO15wQikVgMxiA6pcpFASELkwXygOCNMjIkBFdQBcTAQBwFxPQMRgAnJ9AA0TXVAsSCiDAAq1AFSi6BOhwEQeyFQTpcYFywEYl4s8jxAvBifASzQQDHGF1BEhQG5YNQAaCzgA8BYOQukjLAlaSC4SIwLEoD4MxbxL0AcS9AAYHq4DKTigRg5Y4HY8SA5osIAqHA9kGpEEmoCiq0jKgyQNQGxLjSPwA0DCDAAMMM1IrHFpIQAAAAASUVORK5CYII=");
}

.information_ico {
    display: inline-block;
    height: 32px;
    width: 32px;
    background-image:  url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAdhJREFUeNrEl70vA3EYx69NK5VSFjpLu0lKLF0s0kXKZmEn5i5qtHmJhD+AmYENsTSWiq2RSzppY2660FKSDvV95Fuheud3516+yWe5l+f53u/tniewvX+oKWoILIA5MA0mwAjvPYNHcA9uwCV4UQkaUngmCfJgBUQNnhknabAOXsEJ2AUVs+BBk3sRsAPKYNUkeT9F+U6ZJiJWDSTAHb98QLMveXeDsZKqBmbALefZKUmsImObGhCX1yCuOa84YyeNDAyCMzCmuSeJfc5cvwxsgSnNfaWY64cBWXQ5i4ECPVhRrjsVXQObIKx5pzBzfhoY5iHjtZYltxjIWjxknJLkzMpRnLEZoOOAiUyQq9IvpULcAVZXv1MjkpARiPk4ArGgzbnvOOVADDR8HIGGGKj6aKAqBnQfDehioOCjgYIYuGIN57VaklsMNMGpjb+g6nUjSdHa7G5DKT7bHn59m8Xq1+9YSucDi+eAESqSZuShX0XkxY7Q+1VEojewBOouJq8zR8uoKpapmAc1F5LXGLvyV19QArMOT4fOmCXVzqjCPm/vn7ujzRhpox7R7G/4ztZsEhx9nzcFyXo65rt5xrLdHct2WWMpvdjTno/ymaee9vxCtT3/EGAAeihgXfXnZOsAAAAASUVORK5CYII=");
}

.warn_ico {
    background-image:  url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA15JREFUeNqsV81qFEEQ7umZjbuLgqgg69/Bg+bgQb1kD3qQmFXEJxB8Ah9AxLN4SbyYTR5AyAsoimZzioLJQfAgmlwUwRVNIoG4ycrOTPt9szPLZDI/PZMtqMxmuru+r6q7aqqN3odbIkm63X+D35ZlHldKPFBKTUDP4FUVT8kxwzBcPLbx/A6dNwzx2LadX+XyAZElRhYBAI+7rmq6rnveNKWQUhJwoBQQGSjmCcdxOW9FSuOeZVkLhQjYtn0YBl/BWB1GSETkEUSANgRIL4HoTdjYjJsnE8CvAbiNhXWGMS+4v2WCa2FjjLZgc1yLACbewYKWaZoVer5foQ3ags03tJ1KgCwx8RnYSw2vO9AL0IvQv1nRoE3ajkZChsCPYMJzsJVQHeeaOKSfoB/xezprMm3SNjBeEGsPARy4lxivaO43PZ4M/T+ZFYUgEsAoE2sXAf/QjeXYc3q/FkrXDZ0oBGeCWMFWeASQ57M5wOnpVMx7RmFLlwQwZzwCYFJjkcmRatNh74tFwWTBOkdsieJ1nxUuh/eDvUeeL1JD41O6USAmsUFA3WB5zeH9Ruj/K76Go/BUxxAxPWz8ORXU9AzZipz8JHmiEwViEhuuq6omgaj3SR8wrSj0MVWVZ0BqEEg6+YWj0I+A0N58Le+LZAS8Fy6/40P0XisjiElsRMDYziDAqreeMPYW+i4lCs00AsQ2Ou8nPiMnRxM+QPT+bFzh0RHUiKN4fIUeio45jsOS/IUH8DXbqASZKQqeFQViEtvYWW7U0D61YxrIju/97xQPF32gqxlR+AY9GNNvnkDjYf1EVVplDxeR2TTwcEblzQhiEZPYXlPKTyNetiJROInFbTEEgd1jeKxFvG+AwLz0P48L7F7ZxYbkkhieXA51XvwQLRN8V1vut2Q/kA3lIl2wbquO098FgdMgsL6rJcOLPxi4jQkuU2TY0k87xyVGAL6nK/a34i6YujGHcl+e0yZtR29KMqZdmsPEBkMVORMFwe0g7Dx0c1o3Iz8SNZTLJZ7YItHgGq6lDdpKuiPKlMZxs38vNBuoWis01uv1vL1EQynC34/+pVR5Y5zDuVizyrWlUqmedC/0cDQ8YbqM+tfzhyB1XSmH1/NK5Hq+41/PW5j7iNfzkZHs6/l/AQYA4OEjjlxSJk0AAAAASUVORK5CYII=");
}

.error_ico {
    background-image:   url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA8BJREFUeNq0V81rE0EUf7PpponWCnoRoSJa0VKoCtKDVuvFkxar9SJePNRDBS3mj1BEeip4MRdBq4cKgiKCIH6hIFoVRYVWCuIH4snSNEmT7Ph7u5O63c7sbmI68JL9mvf7vTfvvXkjvtEGMo0cyYXrFSRWlYkyDsl+h2gT3rRALH4niBxIHvIVD+4JEhfnSf5eyW8ihogiAOBtJZJXKkS7oc5KQCmjWh6wO6QSEKMyrvAvE0Rv8e1gE9FEGAEr5F2qmcS1AsmPUN6DaysFSBsvEj5w5QFXURNPwl2ahMCznfDCa8hd93GNBNoxcbpI8oQNZc3K6riDCSXxy/NA/iD0fIdXOmMRwIRuTHiPy3Vwv2tVvYM9xSRAaA0MmgCJnigCW/DhE0xIJb2JDRlJz4NJ6H4IEh0mAmkF3pxsGPQSEjYC+iljLSGAFMuW4HZ7MTiCn0YhhyAXIKUYWEXIechhyGWVIAskcLMWSq4vSkM83Ipo/8QBF1jzUaTi2eoN8pqJ3HJ16UcBcgRz7vvmMIkhv0WIMYls6YL1H1wPwC1ZXAhNwD0I1AVOqQHIfBxwnY6El64C9SLrLgGsb+UiY+vXfY+mODGJYwESJnAee4MPmoCFJe8G9moLF8Nc4Qx5fk65PUjijo+EERxzj+LvjC71LNcLlBFfqO2NRWKHbQ4qBhlQlgcB+ngFQ8BvmOKl5JZu+U5MUtsfRGdrIjyyjSR0Iwq8GoxI+xmOgRYrThoj+nXLUQ94dRlcbN5SRdxaEkEiLnh1v5Dm2DMO6dUs4yjVWiHZekfG+5YrXL8h1XTZEWkJYzOBnNMA8FpJOB6BHK/BtFMnONZ8IEadMBJgbBAQtyskw9LPCI6/MRWYfbWSYEzGtlCXR8DGMXjhUgR4Usl4CIkRnfUwWTI2x8AMLl6U9F54FQHuT1EtCdI0pYyFwvecsS21OZziTlaTXwdigEeR2O+/KXsekNj8Bkk1shwM3AvcxD593FrcgA5BIXvsMWQXJAOxI4oVkxhRljP4aX/qAYP7xDFY/zl4LkijikxJkuuXoyXzItpd5p/Q347/uWBPmIdpvfikME9yWcChNQ/w3iq4riue4g+qJBpBw/kHPgfX78PtZOi5AM5/iQ+7cPlrDtPK/wHOc/PQgQb/B3Ru12WVaTOahCc2crAgZWTRO+/FHqrx5HTj5vMqlnYze7fWs2GBj2ZQ0AmvPONOtuAq9QBkYGOpqK2QLYbLHWTTI8ztQL6fVG1bfafjGo7ns7iZAvC47bXzs3GO538FGABlYXzRnnOThQAAAABJRU5ErkJggg==");
}
' || 
'
.success_ico {
    background-image:   url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA4ZJREFUeNqsl8tLFVEcx2fOqHgjKoIyQwyiUqJFi8AbBCWmlhpFG0PoH6igVkW0iSCiZYuK1j0gSFpkDx+ZRYusv0A3QfQgiLCNWXln+nzHuXKdOzN3HO+Bn+c6c8738z2POQ/7/FCDFZf+/vu3+NsxpsGzrIuW53WSN3uet4rHJnjt2rY9a1vWJ8u2R8mvFVz3e11trVUp1VQqALgD2E0EW4wxlgKYxR/LDsp4MuJ5qym30yUoe9bY9lShUDjtOM7LTAaovA7Yc8TyiFh1xsSK+EZkiPBLUV6G0RjD3CTvD6ExE1XXxMDbaclXKubVjU4CPKHnLNVFo01aaHakMkDBAdyP0fqcWr7SJA1poTki7UQDcknBuzWOY7K0Oqk3pCntcE+YEvh6uuoJjo2pInwRhKa0YQyJVWaAyfKMmZtzqgt/S7QTN4o9AaNerCUG/Ennum3VGPOS9IboZi2ZIM7x+0pxTohVHArfAN/v7SrDXxOHAc+WPLtMfCyagHnLN4CTRsalpYpdL3hPCK60jdhUHAqYO8Q2jMeFKk66iSg468EWsjEiVzopfTZ90W1su1rw3gh4E9k40bzkqxBTbFw02eUG5ol3xJ8VwjcH8K1lyzdMsY12tZCB2UBsL/l+4ldG+EYybUTbI/cPGYBtIpbjAcRGgu14kqwzwcSrGPiGAN5acX2KaVHpmeBDjAnB+yLgWuXUgF2pVkgdJkLP7iDiVDAxHgNfSzZM7E45d1yjkwxjUfqwn7iXYOIxcSQCvobsBbEnDVlMsQ3T73PIgNKJOBPE8Qi4jmdPiXzab9Y3AFvnq2G33ECsiXAqge9bzqLhM2GrB66zOcSVSzTB8/pgSA4sd9USU2zDxvCNiTBdSDZxP2yC/+vIBomu5cLFEtNnB4vCKTaGpDr9pSYC+EOt+1nWbLFgnlncjnV0ZnOYTGFiELha/Ig4lhUO6z3M0SXHcsajh4nxhcGpT9iajwaRKanrYczR/b1lRzIc/eRFHw7dhEmZOUlT2mLA+hF5KtZQ0PqT8xQsVNGEtKQp7fBNyUSc4x9QsAvHcxXmROoxl5Y0pZ3qZuRPSttu1LVKF9QsvaE6qisNacXdEU3CjWbG1b0Q557rTklsfqE1VsTS7T9zF7p6Aey606rLhSQfdy9MdTumJfpcWoPr+SUgB4PreS50Pf8dXM/HKHvVv57XVJS3/gswABvS7PkJ4jDUAAAAAElFTkSuQmCC");
}

.proc_success_small {
    background-image:   url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAw9JREFUeNq0l19IFFEUxscpw8w0iMzIKNkSjNKKwChfyqhtk8KkMH2u3oJ9KemlnqJ6yYdeeg4yyP7QHylTI4gigoh9CCItggJFIrNWI6ntO/RN3a73zoy7swd+zO69M/c7c+bec88tyGQyjp+d7hv2fpaA3WArWAeqQBn7voB34CV4CO6Cb9JxYnuF7/iznWBbCY6Dg2Ce5Z5yUg+OgDToAmfBoN/gBbYI4M2LcDkFkmCOk539AJ3gJCLxPbQDEI/h0s1QR2HyafbDicFAByC+AZcesNiJ1kZAAk68sDoAcfneT8AiJz82CjarkXAV8bkMe77EHY59jVr/O8AJVxex4G3QDJ4pbbXU+ucAJ10yYnGJZjPCfRPXnZoTSX7uvxHoAIURit8A7eAnk5EkqsNKfyE1HReezGeSicokC7YyBzha6FVrFW2JQMInw83U7oF9ujiEJH1f1O4VzYQ40BiReJ9FfBMut0Cx4ZlG1xAaz4bA55Dij8BeMKm1r2dUSizP1YoDMUPHBVANasCrAPHH3CUntPbV4L6yY5osJg6Uao3XwVHM3F9ghJ/otWWApxRPG3bQ3hBJrdQ1NA5AWN0ghumEvpE8B7vAuNZeyfmwNMy3cw0DdGDirNDaPrIQecv/sqHsYCGiWgULkuUh5864y8mmv8EAnFimtX8A25heRXzMkOd7Gf6wNiQOpAwdVXSiUmt/D/aAT1p7GbfwtTNcuilxoN+nFJO+JQGDFDP7bcwid/S79DxtuaGaTpRb+ouYZLZkIS7LtsfFjP+KH1d8bqyhE/qSkjrxag6ZtEu0vWV4Bkz53LwGPAAL+X8WuASashSfYsX8ZztmiXQ+4KE6ru8WRuxADvtGJzTf6OcCqVLiPnuDwyq5O8dNKzWtImIUJvl2o3msCWXsFmhNmGpC71PEWUJHbTJmXD8bTNsLWLc3WBJULmFv0M8ERgeUSMg571zA6ggz22WMetOpyPdsqFQ0q3A5BtosVY3JZD5dlqXmzfZcTscywCGW7U3a8XwB7xnTjud3vON5kP0WYAATfdz0oKr6+wAAAABJRU5ErkJggg==");
}

.error_small {
    background-image:   url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyRJREFUeNqcVstLFXEU/uY392ZlZdd7vXZ7mKhBaWjLNgX6J7QoaudGCSKCgjYSFj02QkEQlhEEtuwvSG6LNhLSLh9JaGXm28TMzHn0nXHGZsaZrnbgMO/vO7/vnN85o42hAnH2HdaxBVg3f8I+vQw7bcBO2LyfgGYUQVvYDq13F7T2fdD74jC0KIJfsKsmYL6cgXkiBR0pKBRDQ5Ku8TmJQFIJAJMwUQo1WAr9DI8DBQn4UfMXGF27ofQcwYscyHiz6GOknIVl74feVg79rv+58l8w4o6PMJ4xGr2SQhQC9wAq+O4B6NonGHfGYXZGElDri59hXj3EqPkytmpZflNDEbmaVsp2PSCRaP4Bq8Np6MoFl1w+p3+jt9DTMbjT9KfOIoALgjfFnHAVVhUStXughhLyliSUF8oXeXcvVprl5CSKXvCQd4IM2gS9iT7gU+O8rIQVp2ZgCeZxxaTWSrXkgrJ89U5I9N4FmvoHOJxcu8ZkM+lm3TyxhaA9tbFaWhl5bQxJFHi9K6VjUs5S2ouw2pRsolSwmMRS9NckqYsgaeJ5GLyHXhIE0LEEu1ExwZni6HIUzfNhkhjwsvDH3OGSizLFXakn4+t9A8lmwD2ZBFtJPRbYTpbrYTPdco7uQe5DRSbzd/x7ktDGkCyeRVXXuq0SU7AVO+LMUjSBBz7o3aBU9SG5YkkEk9izisnIzzqrDdhcFLireT6CpJE+7wfgHsBOaG9UCdTtBbItB1fxOATe4Eto1t3ZfpJ+epd3Ia18jgR7oW4IQX8W6t1kcBUVIfBXoWqJIqn0TgSrHKqPBP1Os1thsxtisytjs8v9bXbdbh5awpsoMD6AJ/TD9LNSPGx00iaso0jWMMkj6wOHS7oyAuO+tOvsf7RrL/IxejUSlxn9Qzjj1TWOuwcW9IOjnAkiVm6LJDLVpqk723SHBx4gEMtAv8ZVDo/DeETZ1GZGppSjRM4iMY8geYlV2Vlw6LMKqqfWhn6Df+hvo9vuJlqkS3n/4JF/FW85i88x2tFN/VWEfltukfAUI8wQWNfW+oyxA9o0fwx6KMc9kg/EYfwRYABD0jtDqxO2xwAAAABJRU5ErkJggg==");
}

.warning_small {
    background-image:  url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAxVJREFUeNqclktvElEUxy+XGZgGqBQsLdpSibFd2LhRE2NcunLha4MfQvsBjAsXvl9RUxJNdKELbeNr4dKVpjFGbWO0JpJaG7AttbWAlLEwPMb/wdIM41yoPck/XO6Z+zuXO/ecg1QcO8BENpPM7NGKpdMFrbRLK5a9pVLFbrMxXZbsRUniWadDGnXI0rnNQe8rEcNmFYDA6rI2lFPzPR3trczjUpiiyEyWONN1xhCUaVqZLal5NjefZR63Ene1OI4h0JumARIzqTOLafVkMLDBRnDsuKlRkOT8L93ndUV7unwnjD7J+GXq++LTVFo9si0cYK0exYoVgSrQI+NkZ6CVuV1OW2zyx/FKRe8Oh/yHaz5eG8SnU9cJvr0vKIJ/IPDox8RjfI6ZnQjA+vs2sVRGPUSsugB05nAM9G7tYIpTFp3ERcD1lfEFqwecTokRg1jEXA2AF/qQztyDXQjsq+lYnkATVg8Sg1hgDlcDINLepVx+C51jA7uM3Zd37gh9gmIY03u4JHqYWGCGiM1x5U51tjeEJ6F7K+NuqHdlfB+aFQYBk9gcSbQb97hRgGvYccE8iTmNfKJFxCQ2R8K0tSjCF5uBbjUIfhtKWzmISWxeKlfsSHsRIIqd5hoEIN+glYOYxOYNFi9DN0xz09A309xN6LcIIkl2XqYiJst2s+8udr9gOvd+C8ZP6A40YJwEkxGbOxz2zHK+aF5Ugq6YJ3FFX0AjFkGuQnUQYoKd5ii5b3FnzQuGsNu4VfUVnEQCemCcICbY7zjV87mFrHmBZRIh6H5onyBI3S8mJrE5avgI7myCSq7BKuz/TTOWb2ISu1qu0SwiqOevqeS6/9ajcZw1W4/l1EK1NwT8nshqsaNOhGYxiHrO8oUiW68hcxkxiFXrbqt5gE404GtzPfscS7LsUn5dOx//Mkvw58T6p+GQhbv9R9v97rOT8QXd9E6atsyJqXl9o88dRTc7uNamP0wll0ovNX2qLbWSQklE99zQ9BP0HtfU9IV/WzT8bUFtqaY/MpQSFPf8vSxL57uC3pcixh8BBgBX2nwB4HBekwAAAABJRU5ErkJggg==");
}

.success_small {
    background-image:   url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyNJREFUeNqclstrE1EUxu/cmWTyzjRWK0pbce/CF4qCRRHqRutjUVcuXEtXIoIVilZdCeJj48KVqAWpSOtCdOGL4vMfUPFRbYttSNM0zWTefmdM4jhO0jYXPs5k5s7vzL3nnnMinRptY/XGXE7dbpnOgGVYW2AV27ZFxgRHlASDc6EghsQPkiRcTGWiL+oxpHpgQ7PuaarZmVQiLJ4MMynEGRc5Y44jWJYdNk2nVVfN7vl8uVvXrO8hWTyazkRf+1ncfyOfVQcXCvqYHJU6165XWCoTYbhmosSZIOD7uQBnIovgHj2jOTR3YU4fy8+UrjVcwex0abhU1A+tWB1nkViILXXQKuWIJMxMFk84DmtvWRU7+N8K4P0KwdvaU8uCV0c4IjF6F4weYv3jgPa8VDT6Wtck3L1uYnyFTuLdcWIQi5g1Bwjo3WSLLGCZzcA/Q7ugy1AXGFPEAnPIdVDIqTtwWtbRPjYJ3w39rPz+Br0hFpgdxOY4bv1JRW4G/skHp3Ec6vkTeJkRmyOJtoajoWbge3zwY9BNSHCDDiaxOTK0JfQ3sDp0Grq6THgvdAsSqzeISWyJ0t/N0MpXTHzJu8FBAmVhzgVtC+ZMUIJVxhHothfuBhdMl+0DvKxeAHIe5mwQ3HNvP3SnXslxHWFYtmVXf4/gyzIeJ4MVJx8D4Pug+7TdQWBiEpujMuZNo+ZgE/QkwMlmLxzP98IM14O7uQUm2LMcJfetphreZ+Tkqc9J0QPvgnkIRRsdMx1MsN9xqufzec3/fKPfSQW+E2YUii12jolJbI5m8Qrldhx1vaET2G0wj6DE4vAylfBxYrunCM2id35Wc7SyGeTkGeBnYB9D6cXgxCAWMWvFjjpRLBG6np0sMk/Aq2MDNLgUOL1LDGJVu1stD5SVsb5YIvzg148CK5eMZRcmHV9O74IxQqzAlolOdDieki/kpktOQEwa7nl2asFB774BxoGGTV9pjfYLnI2i3A4VcvkOtx2i/9aafiWJaDswpxbQeDrcG9T0A1O8MrGTupJp2gNaTvX8bXHT36IExTl/n1DkS5j/vN7qfgswAFMPc0H/GzIVAAAAAElFTkSuQmCC");
}

    /* EBSAF-397 Ability to deselect all highlighted rows*/
.select_all_rows {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-repeat: no-repeat;
    background-size: contain;
    cursor: pointer; /* Change cursor to indicate it is clickable */
	background-position: center center;
	background-image:  url("data:image/png;base64,	iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAYAAAA7MK6iAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAZiS0dEAN8ASQA3NRBAtwAAAAlwSFlzAAAuIwAALiMBeKU/dgAAAAd0SU1FB+kGFw4LGEUXFvsAAALWSURBVEjH7ZZbSBRRGMd/e8lyM+ilkCK7vAfjUxdYwS6yFD0ky2A5tCBE+BAUWxCaqCFIhGDaW2Q7tlBsG3ahWHqqnRCpl4WCIqMCkcwlupmul53pobNyWnfddQV98YPDzHzfmfM73zn/+c7AMpnNG4ptATTAVcgAlmkSHx5dyCvfgR4n8AzYscQJH3IK6HugXQocBrxAAHg+3wimaW0FWoAYcDXXCos+e53CMRJWlUAq6g3FSgW4X/ZnsiOBgXIBHor6PYFcqVZ0RC4DJfblEpdTEpk9bUky+efY5HjCLmVjX4iqLcAEJtMmtAqYBmZyqNoeHx5dDSSBqTyYa4CEU8rQIQXt0tWRh2AyjTFv/xTghZhJql0U/vo0/5w2lZjaLfo+ztVXtLi8x1ZYVSxJ1bPTk/1ZVD0bj/o9Vh6q/m9Jl03VG72hWK3kV8R1lzcUG59vgORMcpu43VzREanNU1yzqi7YCqjVABOpjIeAW1JgD1AJPBGlMDvYskqBOmAQuJsH9AxgS4E/hVWlURLXBQG+H1aV63mUzDrgXdTvaczWzx30lYOt1Pa15iRQ4lwKIbmDvkrgEVjF2JIJLMfiVW2a5h/AAn5lge77B2Ut0I7lGAHGUuL6mbaXZcB2cVx+ycLsD6tKg/g2FeBz1O/5kQXqAtoMTW+q6IiUAc5FqNp661rfEwFe91Z138yQ6X7goYBeMjS9OdN3/Ao4LvlPAeeARiCUCVvkik0Dg6ZlOd1B3zpD07sk6AHggYC2Gprekq2ATIRV5YOk6m/iNi770+3E09PHgNtApzvow9D0LnfQd1BAi4EWQ9NbM727KHH1VnXfSyatGnF0drqDvmsStDkTdNPHDTa5cr0EaqR4PXAeaADuZOHGw6oyJpa2WmReJGJNhqa35foR+A2UFJDwm7Cq7JT29ShwA7hiaHp7PodENXA2VbwXYAPyg6HpfUAfK7Ziwv4CWbwBD80/KOgAAAAASUVORK5CYII=");

}

.deselect_all_rows {
    display: inline-block;
    height: 16px;
    width: 16px;
    background-repeat: no-repeat;
    background-size: contain;
    cursor: pointer; /* Change cursor to indicate it is clickable */
	background-position: center center;
	margin-left: 5px;
	background-image:  url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAYAAAA7MK6iAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAZiS0dEAN8ASQA3NRBAtwAAAAlwSFlzAAAuIwAALiMBeKU/dgAAAAd0SU1FB+kGFw4mMSeP1HgAAAOZSURBVEjH3ZZdaBxVFMd/k50kraZUaFEiNjEqqRVcZu3aFRJC39IZtaDdDlh8kBZK86QhPqkBKxSVkgpi64sIQrWwbpCquxsFhQahTRFnHZCC27i2Nluz5mPTzUdnP33IHbmum+zSlAb8wzB77zl7/vec+d9zL6wTlGAo3gT0AhvWEshZusncVKYe1wXgWxUYBp65wwmfVoGngWngQ8mwE9CB74DzNYJsAfo8Hs9vwGd1kPYD3aoYTIVNbdC1BEPxPkH8TdjUjq8WJRiKbwf6GlTP+OjAnsFarD1DI4cBGtZLXA3rqeoSsAj8IM23ATuAX4FkjRh3A915Jzc9m575sRYfsBtIqdKfe6s4doqnJkql0pYVYlRdrAqUgEmxEhf7gWPA+8AHNYK0AufUxsaLwIt1kJ4DWt2MC2FTS0hKnRQ/Z+T5FVTtACgKS6MDexJ1qLqwruJyM1aDoXh7RVMA2FwxXw33A5TLNPcMjbTXwelxVV1wB3eoV/8rYweQt8J9wCPAVeCPGjGaAb+iKHMK/LIjO/N4a3Zmk1ossNi0kfF77k2mmjemJH8/0OwST4ZNrVsSzCHgI+DjsKkdrSGuNuCKfy6d8Z9+vQXYJNu7lnvCeaDfsOx0z9DIVWCbejuE0pu6zK7IifaJ5aENRIC/gMeA54EDQFfU5939TkWpbxmDsZPbWqYSLBZzReBl4JRh2WXXHvV5E8C7QDsw3FguK3lFKbrimhfNwoUGPCs2++gKnJfCpnYmqQeigF4q89rDI2Nvyw5Rn/cIcBLIAxPAQ4ld+z8d7nzy67WoeuHY52+2Nc1fnwQywAMdsTGngvQUkAP2CY6zwFeGZe91Sz0NDMgNBjgIfCGcq2G8af56p/hcFypI+0SmOWCfYdmRqM+7WZg75G+8EDa1TySlqoL4Z3m+Esf1QJe0HStJHSBoWHZEmPLSCbVmcf0OlIGdST3QcOnPpSPiUHFEplHJ9wnxTq+5V3fExiaAn4AHb9wsnlmFFOBV8Y64LTMjzuNrklMLsFWIJrOKqo2kHtgLnM06Ra7N5hzgOcOyY1LpFeAt4A0gBTwKzKvAK8AJt9lLyAF3iacabgRDcaXD1L5M6oH3xO3RAwSjPu8GYFa03UPAU+KW84Jh2dl/PnQwFFduoeylsKmVAZJ6QJleKPSns/mjolr/qQ7wkmHZF0UFlolvF6I+71Zxe/GLBaSA74GYYdkF/ndI6oG6K/g3fzJID7xJV8sAAAAASUVORK5CYII=");
}

    /* Default highlight color for row selection*/
tr.tdata.selected td  {
	background-color: #d4e9f8;
	color: #000000;
	font-weight: bold;
}
    /* Default highlight color for hover over row*/
tr.tdata:Hover td  {
	background-color: #DCDCDC;
	color: #000000;
}
tr.tdata {
	cursor: pointer;
	transition: background-color 0.3s ease, color 0.3s ease;
}

.latest_version_ico {
    display: inline-block;
    width: 23px;          /* match the icon size */
    height: 23px;
    background-size: contain;
    background-repeat: no-repeat;
    /* Font APEX style icon */
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABsAAAAdCAYAAABbjRdIAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAIzSURBVEhL7ZTNbxJhEIf7HxLbaLGxhvLRQzUmHtSoJ2+1hnjy1pteSjzQ1CoN0ErbQKmbYl4sWJYFdhdkgbKFZdaEGv2Z940fiYgSSz20HJ7kzexmnplkZsZs28b/YuzXwGlyDmUb2wmsrK3DJkJNjaKQWkAm5kY6PIF0eByZ1y7kk/dRkQMwa/sgsnpycIg6P771lb2KxBAIroKIoKafQJWuo87caLCrAv422DVU2D3oaT/K75+hUY6jZZZAHRNEbVimjoa+LYrl0r6y5VAUTwNB8ZOcvAt9dxLdoheftVnBcdEHW55Bk11BRZqGJs2hsu+HoSyhVlpDTQ3DUJ6jmJpH8a0fRK3BZR8kJ77os7/luOQDHczA2JuCsjWBbNSBTNQBeXMc2XUHcolbotuhyHinn0o+dBUPPspuUM4l4J3ryUvDlf2JqnR5JPspk2MXUH4zCTVxUcCn00hNwcq60C14eyT/LOOjqyRvQ2MPobLHAo0tQGcPUGU3UWdemOlpMRB8Jb6vBx8YfdcJeefOYDJ+QQxlBUYxhFazAOocCdqmhsNKAnpmUSTLbblgpNxoZz2w8x7YsgfmOxfUpBuFvXkQHQ0gs210rAbIOvx2dkjA37xaq1WFWc+IRdbYI+TjcziIOQXKzg2Us4toViVxiQaS/Q1eNT9NPGlNjcAovBDUtQ1xNzvtuihwKLJBGcmGwkg2FPrKXkZiWAqu9sRPQl9ZdDOO5VCkJ34S+spOg7Mr+wo1OzckYjPsCgAAAABJRU5ErkJggg==");
}

.thumb_up, .thumb_dn, .af_idea {
    height: 16px;
    width: 16px;
}

.thumb_up_lg, .thumb_dn_lg, .af_idea_lg {
    height: 24px;
    width: 24px;
}

.thumb_up, .thumb_up_lg {
    display: inline-block;
    background-size: contain;
    background-repeat: no-repeat;
    /* Transform to flip horizontally */
    /* transform: scaleX(-1); */
    /* Redwood style icon */
    /* background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABhGlDQ1BJQ0MgcHJvZmlsZQAAKJF9kT1Iw0AcxV9TxSotDhYRcchQnSyIijhKFYtgobQVWnUwufQLmjQkKS6OgmvBwY/FqoOLs64OroIg+AHi5uak6CIl/i8ptIjx4Lgf7+497t4BQqPCVLNrAlA1y0jFY2I2tyr2vCKAMEIYRK/ETD2RXszAc3zdw8fXuyjP8j735wgpeZMBPpF4jumGRbxBPLNp6Zz3icOsJCnE58TjBl2Q+JHrsstvnIsOCzwzbGRS88RhYrHYwXIHs5KhEk8TRxRVo3wh67LCeYuzWqmx1j35C4N5bSXNdZojiGMJCSQhQkYNZVRgIUqrRoqJFO3HPPzDjj9JLplcZTByLKAKFZLjB/+D392ahalJNykYA7pfbPtjFOjZBZp12/4+tu3mCeB/Bq60tr/aAGY/Sa+3tcgR0L8NXFy3NXkPuNwBhp50yZAcyU9TKBSA9zP6phwwcAv0rbm9tfZx+gBkqKvlG+DgEBgrUva6x7sDnb39e6bV3w9A93KTHc9WYwAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAAN1wAADdcBQiibeAAAAAd0SU1FB+UIFA4OHgtEln8AAAIPSURBVFjD7de/a1NRFAfwz0tLqaJiQRG01W5SB+lQsEud0g4ibtZODoqCujkK/gkWBF10EsRinexQBNNBENqhU1IIxUmbRRQdHGJbk+eQa0zbpJqUvA56lnfuu/ee++X8+N5z+dclannnOQesGhA5bq9XZnxrxUyq6R1jDhr12LpPUhZEpn13JRkPXLBf0Vuc3jSzrGBAXtxeDxTdrTl8CXNBP+mYdBIhuBy+iwqGlN1AGcRutRdAWg+OhMOeyFs1553IbLB03pj+9gHosq9m9LGqld0PWoey6+2vgs2SkUE2pPQ1A7qTBVAJyYOgHXLUxeQBHPYUn4PFppKxs4Zgzoq9abhyfRsrU4rSHoncwRlpQzIWm/VAluaJpCrdHlZhRm62xoSjVtCLr8hsE/NJGQt1SnVKZAJFsav40aCi5s0qbAxBxXBWpBcUXGqBWu9hAntEnjVctWYcL7YmYSQXtB4n9LVQkovNbtnsgVw1KGWD+LCD0lzAZM14WMrt7QF0yikFvWQQMzvoNFa8rrg55Mdf8MB7eayFmcEkOqKNAPLWsRxGuwDgVx5UpD/cgAkD+F0JkdSWzidRDyQShlQdlspW9dJuAJi1Eqg4kUrorPu3bEnKCE5JG2/pkor1Sdf0BrHhej14fQAdsmIj6BJ53iIRDWP6Tw+AVAMP5JJ6mtX3QMlLHb607dQu8/5LkJ+T2H3eWOuuGgAAAABJRU5ErkJggg=="); */
    /* Support Assistant style icon */
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAAOwQAADsEBuJFr7QAAAAd0SU1FB+kLBw4lHZbzeHYAAAN1SURBVDjLpZRPTFxVFMZ/5743b5iBAaYw/JNASYoSU0OUpNForNiVGnEDSd3omlTrxlgXJC7cKFUWVRMS2aCLxibGGrEbWVQIlQhMqptGJASxIU3MADUgnffnHhczMEUEidzkLN599/zyve9+56GqHKbm5ubo7e3Vzs5O7evr02w2e+D5Q0EXFhbIZDJal/b07PPNWpf2tL6+XhcXF48GHhwcxHVEZ0e7VZf6dHa0W11HdGhoaN8ewyFWLpcjXenR0VJOdGeLh1rKqU555HK5fXsOBU4mk0RhRN63OK4h70dYazHGHA08Pj6unufgxQWNLCIFC6Mo+v/gC2+9yeTkJENvnKQiZSBQ4p6DEaGiomLfPvcg6NWvvmTw4of6Wm8bL7/UTH7dJ56OM39zlbubIdlsVkdGRiSRKOPMs2doaGwsNe93q7/O/0Jtba12dVSr/8OLGtx4Qf2J53T58ik91ZFSEdR1UMeIAtra2qrT09M7/aKq/6r29OmnNTt7g+xnz9DemiTMW+4s3IZYnDVN4IgiIriey+0/fF55Z4aWE48xNTUlO1YMDw8Ti8UIwxDP8/j++nWdmJjk8rtdtD9Ygb8eoGFI4Ee0PdJIswEUECC0tHfV8OpMC8NXb+32uL+/X0UK58SAtXCu9zhne5rJr/l4noMfQpAPWP5pCQVUQUSIrFKZcrm3tsH63T85//q59y599MnboqrUVif0u4+fJJUUwtAiwIkHEohTjJcR/C2flYUVMi0Z7iOjgIOyFjlc/HyJS1cW+XZsTIqpsDx8PEm8QiCwIIL1LdiC/6KCquLGXFKZqp19RIoJgPIyw/vnTzJ67Xd+nJkpWGGtZXMrxHUMUWgREYwUPlVVUaMYx7C1cY/ln5dKN1wEqyqOEdb/AoOWPBYRjBEcI6gRzLaS4jsAtUos7pJuTMNewTjGkAgExzFYaw8ekB04B1uhkSJVMW7NrLK+EVBTU1MA7xkQ9g7QLiukIHM7Fakyh69vbnLh00UydQ309PSUFEcWIqtEVlH5BxglCCwm5lLVcAyN7I5NYaRUZsqYH1tlK/D45toVaWtrK4Bdx6G2Og7l4Ia2ZB6lWMXKHTK5OFV1SUjEC2FHigYLH3zxG41NTTz+xFMlRV6sMO//VbJdsnu/+9FjCujAwMDef0VTU5NyhLWysiL3P/8NontMDwJfGt4AAAAASUVORK5CYII=");
}

.thumb_dn, .thumb_dn_lg {
    display: inline-block;
    background-size: contain;
    background-repeat: no-repeat;
    /* Redwood style icon */
    /* background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABhWlDQ1BJQ0MgcHJvZmlsZQAAKJF9kT1Iw0AcxV9TpSpVh3YQUchQnSyIXzhKFYtgobQVWnUwufQLmjQkKS6OgmvBwY/FqoOLs64OroIg+AHi5uak6CIl/i8ptIj14Lgf7+497t4BQq3EVLNjHFA1y0hEI2I6syr6XtGNYQTQh2mJmXosuZhC2/F1Dw9f78I8q/25P0evkjUZ4BGJ55huWMQbxDObls55nzjICpJCfE48ZtAFiR+5Lrv8xjnvsMAzg0YqMU8cJBbzLSy3MCsYKvEUcUhRNcoX0i4rnLc4q6UKa9yTv9Cf1VaSXKc5hCiWEEMcImRUUEQJFsK0aqSYSNB+pI1/0PHHySWTqwhGjgWUoUJy/OB/8LtbMzc54Sb5I0Dni21/jAC+XaBete3vY9uunwDeZ+BKa/rLNWD2k/RqUwsdAf3bwMV1U5P3gMsdYOBJlwzJkbw0hVwOeD+jb8oAgVugZ83trbGP0wcgRV0t3wAHh8BonrLX27y7q7W3f880+vsBwqFyx02ZFnsAAAAGYktHRAD/AP8A/6C9p5MAAAAJcEhZcwAADdcAAA3XAUIom3gAAAAHdElNRQflCR0TEA6WJO/dAAACDklEQVRYw+3WO2gUQRzH8c9u4qsQfIAJ0WgnBDWNTUAEQewDop2VkEZBsIzmNIlaBpsQPCurgLGxs7Cx0sLgAwStBGMRQYMQUGMMa7Gb7HK3ObO53Fror5mdmWXmO/N/Df+6grzBK3S2cbxVm27i6RAfoT3vh3b6IyZaBbDIWUxBmPdDxJGyTNC+GkBim584Fw+tWfeT9hnGMmv2BVz+I8AAQZDewJuRdME1qZI618xwcs3Z8VrVmWAv3diRdF+22gRhjoP0Zq6tfIC2jAOGfwMgEwFRwOvSAaQA76/ztVSAATbjYFkOWAfQRY8YohQHrMsDSxwOUrJXzSwc0V3hTE0iagwQ0hulEy+aPFxfJivmV71aE2Qi4MsQM0V3rMSbNlULlgHCaw1ScMTYSJzra3Upab9HnA/4tVo5rgO4yi7sS7o7o4z9cjSlBuAmXQucTrqTo0wWioK2JkvwAhfjw6HAW2LlBoZ50sBXjNK9yIe8udtsm2NguQyP8LyZTFhYc/GbYXfiH+PNpuL16ELSfv7Eg1IBKpySlvBqlR8tAVhiPhOGnZkEsxx6SyF3N+RZ3uC0s+jA9CzH9rA/5C3CiIej9G9EOW5Eey/5PNrBdBiHW5jMja/HhIUAtnBDUqQCDuFk8v1ulsctBxhkPuREwJ0496xoolrs6b4+H8jqFtu/0RNyYCuPBjNO+l9F9BumF28Iy3n+aAAAAABJRU5ErkJggg=="); */
    /* Support Assistant style icon */
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABsAAAAbCAYAAACN1PRVAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+kLBw4eHjNIxvQAAATQSURBVEjHrZZdbBRVFMd/597ZHbptl7JNEYofKdAQqZSUIB/y4gPxgWDiA+KLooHokyYmYKKC8aFvVYwhKAiiiQnYxBgCMUZNVErDh4miFeGBRIsWpd1CoXS33e3O3OPDfnS3VCiGm5yZydw793/Ouf//OSOqSvk4ceKEHj78OQMDg6V3k9dMd4hI6fvt27fnH4q2b98+NcYocNetq6tLpej1hQsXdNmyZVgy7H6ljbZFtYQ5hxhBVTHGMJYaY6B3gMaFc4nGfDR0iJjCflRkIlSoqo2yfdd5jnYP0H28C6+44LezPaTTad58/kGe2dQEQ1kwAiKgBQf9BEN1AdYLmbmwDsYDEChcytHAOajzmVVrCYIAYAKs61gXIkI8qmT+ucHYtQyeZyrOzEQsqdEAMSE1YwHheFBxNhWROcX3Q4LAld55AO3t7bpr93vEa6L4bozrFy4xPOrwrJQcBUWMkEllSTTOwgr5yKcEy9/ziZlY4wF0dHQwJ+Hzza5VLGmuJcg5GgQEqYjMRj36f79MGIQ3p24aw5w+dUJTqRSPrZrNkpUNOCd4EYv1PIxnMZ7FFoyIxRYI8z+w8JxTRITc6BjXzvYxMjKOFalIjaKgYDzDyNUUNYnqiVzdCVhJsGJKkZhJYJSBGXtzSKp5h4t7FXVbfgSqimetQVWxM3xmLp5H/EoWEc1TfvKJRyMIkM2Ml+aLGixuOkGIyioiCN79DzRRV1fHV6cGOH3sMg8vjuMCrZBPiSCqhLkwv0HB+/wzWJvXZBjmgcrBjDFgQFSVnTt36rZt24h4lo7nGnlqdW2e+gVqayE6MUImnaV+XoI5C+biciEKiBVGRwOefP0Mf/aPYo3gFIwVLg2MMZwK6O7uzlN/69atkuy/rG/tfAdTXUt9ywPEro0XdKalLHpRy9W+K7hwQqhOIVrj8WL7r3z9wyCJRIJYLIZzDhGhZmac6rji+/5EBVn1yGr0beXycEi0oYZopKxcUaC6eOhfV7DWICK4EKIJnwOdF/nkyz5al7Rw5MhR4vH4Z865tSLyh1NQ1fmxWCxRKsS9vb3a1tZGLjNCx0utLF1USxg4XBgCyngAC2YpZvQGjYvuw4tG8aoMPeeHWfPCKcRE+O77Y7S0tEgsFpua++Ut5uDBg1pdXT1li1jY6Ou5/Us18+1aDU6u19zJdTpyfJ22NtcpoHv2vK/pdLpiv8kmkxtjT0+PHj1ymIHkICJCZ+en3Bi+RvfeNaxY2UBwfRx1SiQeYcuOHj764iKbNj3Nnj0f/HdEU0WmqqTT6TJL0dTUpM33xlRPPa5B9zrNdq1TPfuE7n9tqQK65KHFmkwmf7xVREXzJoOXe3clmRzK5XL4VggKDIxUGX46M8TL754jXlvDhwc+pqGhYfm0CvEtJ63dVyxDIoJziszwOHysn/RYwI43drBixYppl+RbgsnNfzB5vdl8ZWhubr6zFnOrSYfOz9c+KXR6RRE8awHIZrN3D8zzIhsjkQjXUyGhU2bMjCAzhL8HM6gqt2Xf7dg4mZlbNm9WQJ9d36SnDz6qe19t0yrfaH19vfb19el0WFhqObdb0Nvbq62trRUC931fDx06dEdAU4p6qpFMJoc6Ow/N+vnML9wzZzYbNmxk+fLld/xj8C9laB9YHslUkAAAAABJRU5ErkJggg==");
}

.af_idea, .af_idea_lg {
    display: inline-block;
    background-size: contain;
    background-repeat: no-repeat;
    /* Redwood style icon */
    /* background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABhGlDQ1BJQ0MgcHJvZmlsZQAAKJF9kT1Iw0AcxV9TpUUqDhYRcYhQnSyIijhKFYtgobQVWnUwufQLmjQkKS6OgmvBwY/FqoOLs64OroIg+AHi5uak6CIl/i8ptIjx4Lgf7+497t4BQqPCVLNrAlA1y0jFY2I2tyoGXhFCEAMYgU9ipp5IL2bgOb7u4ePrXZRneZ/7c/QqeZMBPpF4jumGRbxBPLNp6Zz3icOsJCnE58TjBl2Q+JHrsstvnIsOCzwzbGRS88RhYrHYwXIHs5KhEk8TRxRVo3wh67LCeYuzWqmx1j35C0N5bSXNdZrDiGMJCSQhQkYNZVRgIUqrRoqJFO3HPPxDjj9JLplcZTByLKAKFZLjB/+D392ahalJNykUA7pfbPtjFAjsAs26bX8f23bzBPA/A1da219tALOfpNfbWuQI6NsGLq7bmrwHXO4Ag0+6ZEiO5KcpFArA+xl9Uw7ovwV61tzeWvs4fQAy1NXyDXBwCIwVKXvd493Bzt7+PdPq7wdK/XKX0fkhgwAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAAN1wAADdcBQiibeAAAAAd0SU1FB+UMCBYlJEZCDosAAAL4SURBVFjD7ZdJaBNhFMd/L4nRWkHFFjwoKKInixWRiktLDyKo2OyIBxekFqroVQ+K6NkVrBSkiCDVJk3qRbGCUhApYkVxuQguCFJJxaq41WSeh86kgyTNzJibvtN83/znff95y//NwL9u4vaBjk6ktpYFwEIRZgABVUaBV9ksr9vb0IoT6OhEamrZKMJ2lA3AzBLQTwg3Vbk0kuW6EzJlCaQy1KvSBSx3GawhEXbHwjz2TCCVIazKZaDKtv1IlQGEF8AHwAfMRlksQhNQb8N+E2FbLMw11wRSGZarcheYbm71+XwcjoZ4Ohnp3j7q8nmOi9Bibn31B2iIbOFZMbyvlCNVTluHq3IkHiFc7nCAaIgniSghVY6aW9W5X5wvhS9K4GovK4FGAIUbiSjH3XbLyAjHEPoBRFiXyrDMMQERmm05OuWlv9vbUMPgpLU2lPXOCcCSAsDPfa8iowZDtuUiVzVg2fthfnolUF3ND9tLTXFOQPhoXc6pYb5XAt+/M68QDRh2TECVR7Z6aPwLoV9rWz13TCCXox8wzNBt+otBYz2bN/LjHeFYiJIZBlEagDywOB7hlZvDk2kWAi8Avwj3YmHWFMMFSpcwJ4AewA+8TKa9j1xT1HDVBdksvVBe+RzYw2yWlNdh1KTKHRvuFsLo5K/LLCiIjorQHAsz4Hkc96Q5J9BuhvJiIsquMrnvgnGMCOdiYfZNhi8rRFOnchB4YzrckcpMyHSRiDUDO83lmylBDlXkiyiZZj0U2ugtwmCJ8K+CgnBtiEeKt56nb8KeNN0CWx1VPXQnImxzgvW5EJW0C2zGKTbguJfhi0z09YFElLN/5P+A1e+G8tmpX8cRyOd4XJBnobWjk2nWvf7bVBkGrdboz/2amCUV/S9IpskAIXP5RJULZq/vAZaaHpPxMImKpwAgGGTv2BgrzEqvE+HMH5DX+Tz73fj0uQG3bOZdMMgqxovMsGcISOVyrN4aKz73K/ZrZtmVFHN9PurVIKDwwO3B/82y36zf65FsjJp6AAAAAElFTkSuQmCC"); */
    /* Font APEX style icon */
    background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABhGlDQ1BJQ0MgcHJvZmlsZQAAKJF9kT1Iw0AcxV9TpVIqHewg4pChOlkoKuIoVSyChdJWaNXB5NIvaNKQpLg4Cq4FBz8Wqw4uzro6uAqC4AeIm5uToouU+L+k0CLGg+N+vLv3uHsHCK0aU82+OKBqlpFJJsR8YVUMvCKEIMKIIywxU09lF3PwHF/38PH1LsazvM/9OQaVoskAn0g8x3TDIt4gntm0dM77xBFWkRTic+IJgy5I/Mh12eU3zmWHBZ4ZMXKZeeIIsVjuYbmHWcVQiaeJo4qqUb6Qd1nhvMVZrTVY5578haGitpLlOs1RJLGEFNIQIaOBKmqwEKNVI8VEhvYTHv4Rx58ml0yuKhg5FlCHCsnxg//B727N0tSkmxRKAP0vtv0xBgR2gXbTtr+Pbbt9AvifgSut66+3gNlP0ptdLXoEhLeBi+uuJu8BlzvA8JMuGZIj+WkKpRLwfkbfVACGboHgmttbZx+nD0COulq+AQ4OgfEyZa97vHugt7d/z3T6+wGGw3KvejNEhQAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAAN1wAADdcBQiibeAAAAAd0SU1FB+UMChAvDVCbylQAAANmSURBVFjDxddfaNVlGAfwz/s7R9IgF9qIcl30R6iugoiENDGlm9rczrZjEXUTIdlFIKJICHljJl3YjTS6izCdzm12lZaRQnVhEKEJEsHCP+FZc0cqc9s5bxf+DFs72+83lZ6rw+H7vs/3eZ7v8zzvL8hpe/ssKCTa63VtIfGwqAUEZ0SnQnAwRgPdJRez3BeyOj50xLxq1XrRRsyfAV4VvNvUZOezz7h8wwT6P7VoYtwgHk//Ohzprdccu2O+M/DH7+4LwTKUsSrFHS/O0d7R6uysCaTOv0ULTofgta4OR6c7s7/f8hh9iMU4U5xjSSMSyUxpTyNvwVEsmck5dHX4qh4tidExtEyM69/VY25uAtWq9WnaT6M9q7BgTaeRSDt+whPNzd7MVYK9fRYkwc9oCsHyyZH3DWit1XQVirZ0rvbLNOVYEaMjGMUDk4NomIFCoh1NODzZee8B2+p1B0PwSq3m6RnK8SW+wJ0hWJ25BPW6Noj0ToqoLbAZY5GNwxW7M1SkF2K8euf1VmzYHsEjUK85NolYZwhE3iqXvJdFDzE6GgKCRzMTwD0w73bn/lWaoi21ms+GKz7JKsjb5jo7dgXRvXkITCnQVHC784zveu2fu2KeNjwHl//8L+u8NjZmURrS+cwEYnQKCoXpVZ7FksSyNP4fMxNIEoPpz7Ibt3Iq7MHMBGp1g7iEVfv7rZit530HrMRKVGN0MDOBNZ1GBO+k5ejZs8/CvM7TMx+k6ts21SifdhdULtiJ77A4SQwcOmJenvdDkhjAQzg+XPF+7mW0bq2/Jia0YigES6ujPspKoDrq4xAsxVCtrnXdWldyE4AXy84niedTPXT1HvDSjHO3z8so4VKh6LkXuvzaUOxZoulsdyLyRjqdtu7qUWiE3dWjGIKtad1fL7U5OW2LZk1punRO4MHmZisb4e5qtgr344fhij037VEK+/ptFm3LtIDYVC7ZMeOQytVX0eGs0MDnWXDFPP7HJwzNuXriQnfJ3Q0GzwU012qGMo3pPARGL/rtWqmngS2EkZGb/GFyXYQxC667lO3uxP9sxVmc+R6PCXZ0d9g0KTvbsSnFuFUZeBXjog1793vqumf8k9iAWj1am6NbZrVir0U6Vf9vL5dsvpUZUKl4O/LNFC/pr4crV8dwVvsbqc0kSreNCg4AAAAASUVORK5CYII=");
}
.feedback-title {
    top: 10px;
    padding: 10px;
    border-bottom: 1px solid lightblue;
    background-color: #F5F5F5;
    font-weight: bold;
}

.feedback-block {
    margin: 10px;
}

.close-button {
    cursor: pointer;
}

a.clicked-link {
  color: purple !important;
  text-decoration: underline !important;
}';
    print_out('<STYLE type="text/css">');
    print_clob(l_html_clob);
    print_out('</STYLE>');


    ------------------------------------------------------------
    -- JavaScript (EBSAF-262)
    ------------------------------
    -- Start with empty CLOB to ensure string literals are concatenated as such
    dbms_lob.trim(l_html_clob, 0);
    l_html_clob := l_html_clob ||
q'`/*! jQuery v1.11.1 | (c) 2005, 2014 jQuery Foundation, Inc. | jquery.org/license */
!function(a,b){"object"==typeof module&&"object"==typeof module.exports?module.exports=a.document?b(a,!0):function(a){if(!a.document)throw new Error("jQuery requires a window with a document");return b(a)}:b(a)}("undefined"!=typeof window?window:this,function(a,b){var c=[],d=c.slice,e=c.concat,f=c.push,g=c.indexOf,h={},i=h.toString,j=h.hasOwnProperty,k={},l="1.11.1",m=function(a,b){return new m.fn.init(a,b)},n=/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g,o=/^-ms-/,p=/-([\da-z])/gi,q=function(a,b){return b.toUpperCase()};m.fn=m.prototype={jquery:l,constructor:m,selector:"",length:0,toArray:function(){return d.call(this)},get:function(a){return null!=a?0>a?this[a+this.length]:this[a]:d.call(this)},pushStack:function(a){var b=m.merge(this.constructor(),a);return b.prevObject=this,b.context=this.context,b},each:function(a,b){return m.each(this,a,b)},map:function(a){return this.pushStack(m.map(this,function(b,c){return a.call(b,c,b)}))},slice:function(){return this.pushStack(d.apply(this,arguments))},first:function(){return this.eq(0)},last:function(){return this.eq(-1)},eq:function(a){var b=this.length,c=+a+(0>a?b:0);return this.pushStack(c>=0&&b>c?[this[c]]:[])},end:function(){return this.prevObject||this.constructor(null)},push:f,sort:c.sort,splice:c.splice},m.extend=m.fn.extend=function(){var a,b,c,d,e,f,g=arguments[0]||{},h=1,i=arguments.length,j=!1;for("boolean"==typeof g&&(j=g,g=arguments[h]||{},h++),"object"==typeof g||m.isFunction(g)||(g={}),h===i&&(g=this,h--);i>h;h++)if(null!=(e=arguments[h]))for(d in e)a=g[d],c=e[d],g!==c&&(j&&c&&(m.isPlainObject(c)||(b=m.isArray(c)))?(b?(b=!1,f=a&&m.isArray(a)?a:[]):f=a&&m.isPlainObject(a)?a:{},g[d]=m.extend(j,f,c)):void 0!==c&&(g[d]=c));return g},m.extend({expando:"jQuery"+(l+Math.random()).replace(/\D/g,""),isReady:!0,error:function(a){throw new Error(a)},noop:function(){},isFunction:function(a){return"function"===m.type(a)},isArray:Array.isArray||function(a){return"array"===m.type(a)},isWindow:function(a){return null!=a&&a==a.window},isNumeric:function(a){return!m.isArray(a)&&a-parseFloat(a)>=0},isEmptyObject:function(a){var b;for(b in a)return!1;return!0},isPlainObject:function(a){var b;if(!a||"object"!==m.type(a)||a.nodeType||m.isWindow(a))return!1;try{if(a.constructor&&!j.call(a,"constructor")&&!j.call(a.constructor.prototype,"isPrototypeOf"))return!1}catch(c){return!1}if(k.ownLast)for(b in a)return j.call(a,b);
for(b in a);return void 0===b||j.call(a,b)},type:function(a){return null==a?a+"":"object"==typeof a||"function"==typeof a?h[i.call(a)]||"object":typeof a},globalEval:function(b){b&&m.trim(b)&&(a.execScript||function(b){a.eval.call(a,b)})(b)},camelCase:function(a){return a.replace(o,"ms-").replace(p,q)},nodeName:function(a,b){return a.nodeName&&a.nodeName.toLowerCase()===b.toLowerCase()},each:function(a,b,c){var d,e=0,f=a.length,g=r(a);if(c){if(g){for(;f>e;e++)if(d=b.apply(a[e],c),d===!1)break}else for(e in a)if(d=b.apply(a[e],c),d===!1)break}else if(g){for(;f>e;e++)if(d=b.call(a[e],e,a[e]),d===!1)break}else for(e in a)if(d=b.call(a[e],e,a[e]),d===!1)break;return a},trim:function(a){return null==a?"":(a+"").replace(n,"")},makeArray:function(a,b){var c=b||[];return null!=a&&(r(Object(a))?m.merge(c,"string"==typeof a?[a]:a):f.call(c,a)),c},inArray:function(a,b,c){var d;if(b){if(g)return g.call(b,a,c);for(d=b.length,c=c?0>c?Math.max(0,d+c):c:0;d>c;c++)if(c in b&&b[c]===a)return c}return-1},merge:function(a,b){var c=+b.length,d=0,e=a.length;while(c>d)a[e++]=b[d++];if(c!==c)while(void 0!==b[d])a[e++]=b[d++];return a.length=e,a},grep:function(a,b,c){for(var d,e=[],f=0,g=a.length,h=!c;g>f;f++)d=!b(a[f],f),d!==h&&e.push(a[f]);return e},map:function(a,b,c){var d,f=0,g=a.length,h=r(a),i=[];if(h)for(;g>f;f++)d=b(a[f],f,c),null!=d&&i.push(d);else for(f in a)d=b(a[f],f,c),null!=d&&i.push(d);return e.apply([],i)},guid:1,proxy:function(a,b){var c,e,f;return"string"==typeof b&&(f=a[b],b=a,a=f),m.isFunction(a)?(c=d.call(arguments,2),e=function(){return a.apply(b||this,c.concat(d.call(arguments)))},e.guid=a.guid=a.guid||m.guid++,e):void 0},now:function(){return+new Date},support:k}),m.each("Boolean Number String Function Array Date RegExp Object Error".split(" "),function(a,b){h["[object "+b+"]"]=b.toLowerCase()});function r(a){var b=a.length,c=m.type(a);return"function"===c||m.isWindow(a)?!1:1===a.nodeType&&b?!0:"array"===c||0===b||"number"==typeof b&&b>0&&b-1 in a}var s=function(a){var b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u="sizzle"+-new Date,v=a.document,w=0,x=0,y=gb(),z=gb(),A=gb(),B=function(a,b){return a===b&&(l=!0),0},C="undefined",D=1<<31,E={}.hasOwnProperty,F=[],G=F.pop,H=F.push,I=F.push,J=F.slice,K=F.indexOf||function(a){for(var b=0,c=this.length;c>b;b++)
if(this[b]===a)return b;return-1},L="checked|selected|async|autofocus|autoplay|controls|defer|disabled|hidden|ismap|loop|multiple|open|readonly|required|scoped",M="[\\x20\\t\\r\\n\\f]",N="(?:\\\\.|[\\w-]|[^\\x00-\\xa0])+",O=N.replace("w","w#"),P="\\["+M+"*("+N+")(?:"+M+"*([*^$|!~]?=)"+M+"*(?:'((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\"|("+O+"))|)"+M+"*\\]",Q=":("+N+")(?:\\((('((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\")|((?:\\\\.|[^\\\\()[\\]]|"+P+")*)|.*)\\)|)",R=new RegExp("^"+M+"+|((?:^|[^\\\\])(?:\\\\.)*)"+M+"+$","g"),S=new RegExp("^"+M+"*,"+M+"*"),T=new RegExp("^"+M+"*([>+~]|"+M+")"+M+"*"),U=new RegExp("="+M+"*([^\\]'\"]*?)"+M+"*\\]","g"),V=new RegExp(Q),W=new RegExp("^"+O+"$"),X={ID:new RegExp("^#("+N+")"),CLASS:new RegExp("^\\.("+N+")"),TAG:new RegExp("^("+N.replace("w","w*")+")"),ATTR:new RegExp("^"+P),PSEUDO:new RegExp("^"+Q),CHILD:new RegExp("^:(only|first|last|nth|nth-last)-(child|of-type)(?:\\("+M+"*(even|odd|(([+-]|)(\\d*)n|)"+M+"*(?:([+-]|)"+M+"*(\\d+)|))"+M+"*\\)|)","i"),bool:new RegExp("^(?:"+L+")$","i"),needsContext:new RegExp("^"+M+"*[>+~]|:(even|odd|eq|gt|lt|nth|first|last)(?:\\("+M+"*((?:-\\d)?\\d*)"+M+"*\\)|)(?=[^-]|$)","i")},Y=/^(?:input|select|textarea|button)$/i,Z=/^h\d$/i,$=/^[^{]+\{\s*\[native \w/,_=/^(?:#([\w-]+)|(\w+)|\.([\w-]+))$/,ab=/[+~]/,bb=/'|\\/g,cb=new RegExp("\\\\([\\da-f]{1,6}"+M+"?|("+M+")|.)","ig"),db=function(a,b,c){var d="0x"+b-65536;return d!==d||c?b:0>d?String.fromCharCode(d+65536):String.fromCharCode(d>>10|55296,1023&d|56320)};try{I.apply(F=J.call(v.childNodes),v.childNodes),F[v.childNodes.length].nodeType}catch(eb){I={apply:F.length?function(a,b){H.apply(a,J.call(b))}:function(a,b){var c=a.length,d=0;while(a[c++]=b[d++]);a.length=c-1}}}function fb(a,b,d,e){var f,h,j,k,l,o,r,s,w,x;if((b?b.ownerDocument||b:v)!==n&&m(b),b=b||n,d=d||[],!a||"string"!=typeof a)return d;if(1!==(k=b.nodeType)&&9!==k)return[];if(p&&!e){if(f=_.exec(a))if(j=f[1]){if(9===k){if(h=b.getElementById(j),!h||!h.parentNode)return d;if(h.id===j)return d.push(h),d}else if(b.ownerDocument&&(h=b.ownerDocument.getElementById(j))&&t(b,h)&&h.id===j)return d.push(h),d}else{if(f[2])return I.apply(d,b.getElementsByTagName(a)),d;
if((j=f[3])&&c.getElementsByClassName&&b.getElementsByClassName)return I.apply(d,b.getElementsByClassName(j)),d}if(c.qsa&&(!q||!q.test(a))){if(s=r=u,w=b,x=9===k&&a,1===k&&"object"!==b.nodeName.toLowerCase()){o=g(a),(r=b.getAttribute("id"))?s=r.replace(bb,"\\$&"):b.setAttribute("id",s),s="[id='"+s+"'] ",l=o.length;while(l--)o[l]=s+qb(o[l]);w=ab.test(a)&&ob(b.parentNode)||b,x=o.join(",")}if(x)try{return I.apply(d,w.querySelectorAll(x)),d}catch(y){}finally{r||b.removeAttribute("id")}}}return i(a.replace(R,"$1"),b,d,e)}function gb(){var a=[];function b(c,e){return a.push(c+" ")>d.cacheLength&&delete b[a.shift()],b[c+" "]=e}return b}function hb(a){return a[u]=!0,a}function ib(a){var b=n.createElement("div");try{return!!a(b)}catch(c){return!1}finally{b.parentNode&&b.parentNode.removeChild(b),b=null}}function jb(a,b){var c=a.split("|"),e=a.length;while(e--)d.attrHandle[c[e]]=b}function kb(a,b){var c=b&&a,d=c&&1===a.nodeType&&1===b.nodeType&&(~b.sourceIndex||D)-(~a.sourceIndex||D);if(d)return d;if(c)while(c=c.nextSibling)if(c===b)return-1;return a?1:-1}function lb(a){return function(b){var c=b.nodeName.toLowerCase();return"input"===c&&b.type===a}}function mb(a){return function(b){var c=b.nodeName.toLowerCase();return("input"===c||"button"===c)&&b.type===a}}function nb(a){return hb(function(b){return b=+b,hb(function(c,d){var e,f=a([],c.length,b),g=f.length;while(g--)c[e=f[g]]&&(c[e]=!(d[e]=c[e]))})})}function ob(a){return a&&typeof a.getElementsByTagName!==C&&a}c=fb.support={},f=fb.isXML=function(a){var b=a&&(a.ownerDocument||a).documentElement;return b?"HTML"!==b.nodeName:!1},m=fb.setDocument=function(a){var b,e=a?a.ownerDocument||a:v,g=e.defaultView;return e!==n&&9===e.nodeType&&e.documentElement?(n=e,o=e.documentElement,p=!f(e),g&&g!==g.top&&(g.addEventListener?g.addEventListener("unload",function(){m()},!1):g.attachEvent&&g.attachEvent("onunload",function(){m()})),c.attributes=ib(function(a){return a.className="i",!a.getAttribute("className")}),c.getElementsByTagName=ib(function(a){return a.appendChild(e.createComment("")),!a.getElementsByTagName("*").length}),c.getElementsByClassName=$.test(e.getElementsByClassName)&&ib(
function(a){return a.innerHTML="<div class='a'></div><div class='a i'></div>",a.firstChild.className="i",2===a.getElementsByClassName("i").length}),c.getById=ib(function(a){return o.appendChild(a).id=u,!e.getElementsByName||!e.getElementsByName(u).length}),c.getById?(d.find.ID=function(a,b){if(typeof b.getElementById!==C&&p){var c=b.getElementById(a);return c&&c.parentNode?[c]:[]}},d.filter.ID=function(a){var b=a.replace(cb,db);return function(a){return a.getAttribute("id")===b}}):(delete d.find.ID,d.filter.ID=function(a){var b=a.replace(cb,db);return function(a){var c=typeof a.getAttributeNode!==C&&a.getAttributeNode("id");return c&&c.value===b}}),d.find.TAG=c.getElementsByTagName?function(a,b){return typeof b.getElementsByTagName!==C?b.getElementsByTagName(a):void 0}:function(a,b){var c,d=[],e=0,f=b.getElementsByTagName(a);if("*"===a){while(c=f[e++])1===c.nodeType&&d.push(c);return d}return f},d.find.CLASS=c.getElementsByClassName&&function(a,b){return typeof b.getElementsByClassName!==C&&p?b.getElementsByClassName(a):void 0},r=[],q=[],(c.qsa=$.test(e.querySelectorAll))&&(ib(function(a){a.innerHTML="<select msallowclip=''><option selected=''></option></select>",a.querySelectorAll("[msallowclip^='']").length&&q.push("[*^$]="+M+"*(?:''|\"\")"),a.querySelectorAll("[selected]").length||q.push("\\["+M+"*(?:value|"+L+")"),a.querySelectorAll(":checked").length||q.push(":checked")}),ib(function(a){var b=e.createElement("input");
b.setAttribute("type","hidden"),a.appendChild(b).setAttribute("name","D"),a.querySelectorAll("[name=d]").length&&q.push("name"+M+"*[*^$|!~]?="),a.querySelectorAll(":enabled").length||q.push(":enabled",":disabled"),a.querySelectorAll("*,:x"),q.push(",.*:")})),(c.matchesSelector=$.test(s=o.matches||o.webkitMatchesSelector||o.mozMatchesSelector||o.oMatchesSelector||o.msMatchesSelector))&&ib(function(a){c.disconnectedMatch=s.call(a,"div"),s.call(a,"[s!='']:x"),r.push("!=",Q)}),q=q.length&&new RegExp(q.join("|")),r=r.length&&new RegExp(r.join("|")),b=$.test(o.compareDocumentPosition),t=b||$.test(o.contains)?function(a,b){var c=9===a.nodeType?a.documentElement:a,d=b&&b.parentNode;return a===d||!(!d||1!==d.nodeType||!(c.contains?c.contains(d):a.compareDocumentPosition&&16&a.compareDocumentPosition(d)))}:function(a,b){if(b)while(b=b.parentNode)if(b===a)return!0;return!1},B=b?function(a,b){if(a===b)return l=!0,0;var d=!a.compareDocumentPosition-!b.compareDocumentPosition;return d?d:(d=(a.ownerDocument||a)===(b.ownerDocument||b)?a.compareDocumentPosition(b):1,1&d||!c.sortDetached&&b.compareDocumentPosition(a)===d?a===e||a.ownerDocument===v&&t(v,a)?-1:b===e||b.ownerDocument===v&&t(v,b)?1:k?K.call(k,a)-K.call(k,b):0:4&d?-1:1)}:function(a,b){if(a===b)return l=!0,0;var c,d=0,f=a.parentNode,g=b.parentNode,h=[a],i=[b];if(!f||!g)return a===e?-1:b===e?1:f?-1:g?1:k?K.call(k,a)-K.call(k,b):0;if(f===g)return kb(a,b);c=a;while(c=c.parentNode)h.unshift(c);c=b;while(c=c.parentNode)i.unshift(c);
while(h[d]===i[d])d++;return d?kb(h[d],i[d]):h[d]===v?-1:i[d]===v?1:0},e):n},fb.matches=function(a,b){return fb(a,null,null,b)},fb.matchesSelector=function(a,b){if((a.ownerDocument||a)!==n&&m(a),b=b.replace(U,"='$1']"),!(!c.matchesSelector||!p||r&&r.test(b)||q&&q.test(b)))try{var d=s.call(a,b);if(d||c.disconnectedMatch||a.document&&11!==a.document.nodeType)return d}catch(e){}return fb(b,n,null,[a]).length>0},fb.contains=function(a,b){return(a.ownerDocument||a)!==n&&m(a),t(a,b)},fb.attr=function(a,b){(a.ownerDocument||a)!==n&&m(a);var e=d.attrHandle[b.toLowerCase()],f=e&&E.call(d.attrHandle,b.toLowerCase())?e(a,b,!p):void 0;return void 0!==f?f:c.attributes||!p?a.getAttribute(b):(f=a.getAttributeNode(b))&&f.specified?f.value:null},fb.error=function(a){throw new Error("Syntax error, unrecognized expression: "+a)},fb.uniqueSort=function(a){var b,d=[],e=0,f=0;if(l=!c.detectDuplicates,k=!c.sortStable&&a.slice(0),a.sort(B),l){while(b=a[f++])b===a[f]&&(e=d.push(f));while(e--)a.splice(d[e],1)}return k=null,a},e=fb.getText=function(a){var b,c="",d=0,f=a.nodeType;if(f){if(1===f||9===f||11===f){if("string"==typeof a.textContent)return a.textContent;for(a=a.firstChild;a;a=a.nextSibling)c+=e(a)}else if(3===f||4===f)return a.nodeValue}else while(b=a[d++])c+=e(b);return c},d=fb.selectors={cacheLength:50,createPseudo:hb,match:X,attrHandle:{},find:{},relative:{">":{dir:"parentNode",first:!0}," ":{dir:"parentNode"},"+":{dir:"previousSibling",first:!0},"~":{dir:"previousSibling"}},preFilter:{ATTR:function(a){return a[1]=a[1].replace(cb,db),a[3]=(a[3]||a[4]||a[5]||"").replace(cb,db),"~="===a[2]&&(a[3]=" "+a[3]+" "),a.slice(0,4)},CHILD:function(a){return a[1]=a[1].toLowerCase(),"nth"===a[1].slice(0,3)?(a[3]||fb.error(a[0]),a[4]=+(a[4]?a[5]+(a[6]||1):2*("even"===a[3]||"odd"===a[3])),a[5]=+(a[7]+a[8]||"odd"===a[3])):a[3]&&fb.error(a[0]),a},PSEUDO:function(a){var b,c=!a[6]&&a[2];
return X.CHILD.test(a[0])?null:(a[3]?a[2]=a[4]||a[5]||"":c&&V.test(c)&&(b=g(c,!0))&&(b=c.indexOf(")",c.length-b)-c.length)&&(a[0]=a[0].slice(0,b),a[2]=c.slice(0,b)),a.slice(0,3))}},filter:{TAG:function(a){var b=a.replace(cb,db).toLowerCase();return"*"===a?function(){return!0}:function(a){return a.nodeName&&a.nodeName.toLowerCase()===b}},CLASS:function(a){var b=y[a+" "];return b||(b=new RegExp("(^|"+M+")"+a+"("+M+"|$)"))&&y(a,function(a){return b.test("string"==typeof a.className&&a.className||typeof a.getAttribute!==C&&a.getAttribute("class")||"")})},ATTR:function(a,b,c){return function(d){var e=fb.attr(d,a);return null==e?"!="===b:b?(e+="","="===b?e===c:"!="===b?e!==c:"^="===b?c&&0===e.indexOf(c):"*="===b?c&&e.indexOf(c)>-1:"$="===b?c&&e.slice(-c.length)===c:"~="===b?(" "+e+" ").indexOf(c)>-1:"|="===b?e===c||e.slice(0,c.length+1)===c+"-":!1):!0}},CHILD:function(a,b,c,d,e){var f="nth"!==a.slice(0,3),g="last"!==a.slice(-4),h="of-type"===b;return 1===d&&0===e?function(a){return!!a.parentNode}:function(b,c,i){var j,k,l,m,n,o,p=f!==g?"nextSibling":"previousSibling",q=b.parentNode,r=h&&b.nodeName.toLowerCase(),s=!i&&!h;if(q){if(f){while(p){l=b;while(l=l[p])if(h?l.nodeName.toLowerCase()===r:1===l.nodeType)return!1;o=p="only"===a&&!o&&"nextSibling"}return!0}if(o=[g?q.firstChild:q.lastChild],g&&s){k=q[u]||(q[u]={}),j=k[a]||[],n=j[0]===w&&j[1],m=j[0]===w&&j[2],l=n&&q.childNodes[n];while(l=++n&&l&&l[p]||(m=n=0)||o.pop())if(1===l.nodeType&&++m&&l===b){k[a]=[w,n,m];break}}else if(s&&(j=(b[u]||(b[u]={}))[a])&&j[0]===w)m=j[1];else while(l=++n&&l&&l[p]||(m=n=0)||o.pop())if((h?l.nodeName.toLowerCase()===r:1===l.nodeType)&&++m&&(s&&((l[u]||(l[u]={}))[a]=[w,m]),l===b))break;
return m-=e,m===d||m%d===0&&m/d>=0}}},PSEUDO:function(a,b){var c,e=d.pseudos[a]||d.setFilters[a.toLowerCase()]||fb.error("unsupported pseudo: "+a);return e[u]?e(b):e.length>1?(c=[a,a,"",b],d.setFilters.hasOwnProperty(a.toLowerCase())?hb(function(a,c){var d,f=e(a,b),g=f.length;while(g--)d=K.call(a,f[g]),a[d]=!(c[d]=f[g])}):function(a){return e(a,0,c)}):e}},pseudos:{not:hb(function(a){var b=[],c=[],d=h(a.replace(R,"$1"));return d[u]?hb(function(a,b,c,e){var f,g=d(a,null,e,[]),h=a.length;while(h--)(f=g[h])&&(a[h]=!(b[h]=f))}):function(a,e,f){return b[0]=a,d(b,null,f,c),!c.pop()}}),has:hb(function(a){return function(b){return fb(a,b).length>0}}),contains:hb(function(a){return function(b){return(b.textContent||b.innerText||e(b)).indexOf(a)>-1}}),lang:hb(function(a){return W.test(a||"")||fb.error("unsupported lang: "+a),a=a.replace(cb,db).toLowerCase(),function(b){var c;do if(c=p?b.lang:b.getAttribute("xml:lang")||b.getAttribute("lang"))return c=c.toLowerCase(),c===a||0===c.indexOf(a+"-");while((b=b.parentNode)&&1===b.nodeType);return!1}}),target:function(b){var c=a.location&&a.location.hash;return c&&c.slice(1)===b.id},root:function(a){return a===o},focus:function(a){return a===n.activeElement&&(!n.hasFocus||n.hasFocus())&&!!(a.type||a.href||~a.tabIndex)},enabled:function(a){return a.disabled===!1},disabled:function(a){return a.disabled===!0},checked:function(a){var b=a.nodeName.toLowerCase();
return"input"===b&&!!a.checked||"option"===b&&!!a.selected},selected:function(a){return a.parentNode&&a.parentNode.selectedIndex,a.selected===!0},empty:function(a){for(a=a.firstChild;a;a=a.nextSibling)if(a.nodeType<6)return!1;return!0},parent:function(a){return!d.pseudos.empty(a)},header:function(a){return Z.test(a.nodeName)},input:function(a){return Y.test(a.nodeName)},button:function(a){var b=a.nodeName.toLowerCase();return"input"===b&&"button"===a.type||"button"===b},text:function(a){var b;return"input"===a.nodeName.toLowerCase()&&"text"===a.type&&(null==(b=a.getAttribute("type"))||"text"===b.toLowerCase())},first:nb(function(){return[0]}),last:nb(function(a,b){return[b-1]}),eq:nb(function(a,b,c){return[0>c?c+b:c]}),even:nb(function(a,b){for(var c=0;b>c;c+=2)a.push(c);return a}),odd:nb(function(a,b){for(var c=1;b>c;c+=2)a.push(c);return a}),lt:nb(function(a,b,c){for(var d=0>c?c+b:c;--d>=0;)a.push(d);return a}),gt:nb(function(a,b,c){for(var d=0>c?c+b:c;++d<b;)a.push(d);return a})}},d.pseudos.nth=d.pseudos.eq;for(b in{radio:!0,checkbox:!0,file:!0,password:!0,image:!0})d.pseudos[b]=lb(b);for(b in{submit:!0,reset:!0})d.pseudos[b]=mb(b);function pb(){}pb.prototype=d.filters=d.pseudos,d.setFilters=new pb,g=fb.tokenize=function(a,b){var c,e,f,g,h,i,j,k=z[a+" "];if(k)return b?0:k.slice(0);h=a,i=[],j=d.preFilter;while(h){(!c||(e=S.exec(h)))&&(e&&(h=h.slice(e[0].length)||h),i.push(f=[])),c=!1,(e=T.exec(h))&&(c=e.shift(),f.push({value:c,type:e[0].replace(R," ")}),h=h.slice(c.length));for(g in d.filter)!(e=X[g].exec(h))||j[g]&&!(e=j[g](e))||(c=e.shift(),f.push({value:c,type:g,matches:e}),h=h.slice(c.length));if(!c)break}return b?h.length:h?fb.error(a):z(a,i).slice(0)};function qb(a){for(var b=0,c=a.length,d="";c>b;b++)d+=a[b].value;return d}
function rb(a,b,c){var d=b.dir,e=c&&"parentNode"===d,f=x++;return b.first?function(b,c,f){while(b=b[d])if(1===b.nodeType||e)return a(b,c,f)}:function(b,c,g){var h,i,j=[w,f];if(g){while(b=b[d])if((1===b.nodeType||e)&&a(b,c,g))return!0}else while(b=b[d])if(1===b.nodeType||e){if(i=b[u]||(b[u]={}),(h=i[d])&&h[0]===w&&h[1]===f)return j[2]=h[2];if(i[d]=j,j[2]=a(b,c,g))return!0}}}function sb(a){return a.length>1?function(b,c,d){var e=a.length;while(e--)if(!a[e](b,c,d))return!1;return!0}:a[0]}function tb(a,b,c){for(var d=0,e=b.length;e>d;d++)fb(a,b[d],c);return c}function ub(a,b,c,d,e){for(var f,g=[],h=0,i=a.length,j=null!=b;i>h;h++)(f=a[h])&&(!c||c(f,d,e))&&(g.push(f),j&&b.push(h));return g}function vb(a,b,c,d,e,f){return d&&!d[u]&&(d=vb(d)),e&&!e[u]&&(e=vb(e,f)),hb(function(f,g,h,i){var j,k,l,m=[],n=[],o=g.length,p=f||tb(b||"*",h.nodeType?[h]:h,[]),q=!a||!f&&b?p:ub(p,m,a,h,i),r=c?e||(f?a:o||d)?[]:g:q;if(c&&c(q,r,h,i),d){j=ub(r,n),d(j,[],h,i),k=j.length;while(k--)(l=j[k])&&(r[n[k]]=!(q[n[k]]=l))}if(f){if(e||a){if(e){j=[],k=r.length;while(k--)(l=r[k])&&j.push(q[k]=l);e(null,r=[],j,i)}k=r.length;while(k--)(l=r[k])&&(j=e?K.call(f,l):m[k])>-1&&(f[j]=!(g[j]=l))}}else r=ub(r===g?r.splice(o,r.length):r),e?e(null,g,r,i):I.apply(g,r)})}function wb(a){for(var b,c,e,f=a.length,g=d.relative[a[0].type],h=g||d.relative[" "],i=g?1:0,k=rb(function(a){return a===b},h,!0),l=rb(function(a){return K.call(b,a)>-1},h,!0),m=[function(a,c,d){return!g&&(d||c!==j)||((b=c).nodeType?k(a,c,d):l(a,c,d))}];f>i;i++)if(c=d.relative[a[i].type])m=[rb(sb(m),c)];else{if(c=d.filter[a[i].type].apply(null,a[i].matches),c[u]){for(e=++i;f>e;e++)if(d.relative[a[e].type])break;
return vb(i>1&&sb(m),i>1&&qb(a.slice(0,i-1).concat({value:" "===a[i-2].type?"*":""})).replace(R,"$1"),c,e>i&&wb(a.slice(i,e)),f>e&&wb(a=a.slice(e)),f>e&&qb(a))}m.push(c)}return sb(m)}function xb(a,b){var c=b.length>0,e=a.length>0,f=function(f,g,h,i,k){var l,m,o,p=0,q="0",r=f&&[],s=[],t=j,u=f||e&&d.find.TAG("*",k),v=w+=null==t?1:Math.random()||.1,x=u.length;for(k&&(j=g!==n&&g);q!==x&&null!=(l=u[q]);q++){if(e&&l){m=0;while(o=a[m++])if(o(l,g,h)){i.push(l);break}k&&(w=v)}c&&((l=!o&&l)&&p--,f&&r.push(l))}if(p+=q,c&&q!==p){m=0;while(o=b[m++])o(r,s,g,h);if(f){if(p>0)while(q--)r[q]||s[q]||(s[q]=G.call(i));s=ub(s)}I.apply(i,s),k&&!f&&s.length>0&&p+b.length>1&&fb.uniqueSort(i)}return k&&(w=v,j=t),r};return c?hb(f):f}return h=fb.compile=function(a,b){var c,d=[],e=[],f=A[a+" "];if(!f){b||(b=g(a)),c=b.length;while(c--)f=wb(b[c]),f[u]?d.push(f):e.push(f);f=A(a,xb(e,d)),f.selector=a}return f},i=fb.select=function(a,b,e,f){var i,j,k,l,m,n="function"==typeof a&&a,o=!f&&g(a=n.selector||a);if(e=e||[],1===o.length){if(j=o[0]=o[0].slice(0),j.length>2&&"ID"===(k=j[0]).type&&c.getById&&9===b.nodeType&&p&&d.relative[j[1].type]){if(b=(d.find.ID(k.matches[0].replace(cb,db),b)||[])[0],!b)return e;n&&(b=b.parentNode),a=a.slice(j.shift().value.length)}i=X.needsContext.test(a)?0:j.length;while(i--)
{if(k=j[i],d.relative[l=k.type])break;if((m=d.find[l])&&(f=m(k.matches[0].replace(cb,db),ab.test(j[0].type)&&ob(b.parentNode)||b))){if(j.splice(i,1),a=f.length&&qb(j),!a)return I.apply(e,f),e;break}}}return(n||h(a,o))(f,b,!p,e,ab.test(a)&&ob(b.parentNode)||b),e},c.sortStable=u.split("").sort(B).join("")===u,c.detectDuplicates=!!l,m(),c.sortDetached=ib(function(a){return 1&a.compareDocumentPosition(n.createElement("div"))}),ib(function(a){return a.innerHTML="<a href='javascript:void(0)'></a>","javascript:void(0)"===a.firstChild.getAttribute("href")})||jb("type|href|height|width",function(a,b,c){return c?void 0:a.getAttribute(b,"type"===b.toLowerCase()?1:2)}),c.attributes&&ib(function(a){return a.innerHTML="<input/>",a.firstChild.setAttribute("value",""),""===a.firstChild.getAttribute("value")})||jb("value",function(a,b,c){return c||"input"!==a.nodeName.toLowerCase()?void 0:a.defaultValue}),ib(function(a){return null==a.getAttribute("disabled")})||jb(L,function(a,b,c){var d;return c?void 0:a[b]===!0?b.toLowerCase():(d=a.getAttributeNode(b))&&d.specified?d.value:null}),fb}(a);m.find=s,m.expr=s.selectors,m.expr[":"]=m.expr.pseudos,m.unique=s.uniqueSort,m.text=s.getText,m.isXMLDoc=s.isXML,m.contains=s.contains;var t=m.expr.match.needsContext,u=/^<(\w+)\s*\/?>(?:<\/\1>|)$/,v=/^.[^:#\[\.,]*$/;function w(a,b,c){if(m.isFunction(b))return m.grep(a,function(a,d){return!!b.call(a,d,a)!==c});if(b.nodeType)return m.grep(a,function(a){return a===b!==c});if("string"==typeof b){if(v.test(b))return m.filter(b,a,c);b=m.filter(b,a)}return m.grep(a,function(a){return m.inArray(a,b)>=0!==c})}m.filter=function(a,b,c){var d=b[0];
return c&&(a=":not("+a+")"),1===b.length&&1===d.nodeType?m.find.matchesSelector(d,a)?[d]:[]:m.find.matches(a,m.grep(b,function(a){return 1===a.nodeType}))},m.fn.extend({find:function(a){var b,c=[],d=this,e=d.length;if("string"!=typeof a)return this.pushStack(m(a).filter(function(){for(b=0;e>b;b++)if(m.contains(d[b],this))return!0}));for(b=0;e>b;b++)m.find(a,d[b],c);return c=this.pushStack(e>1?m.unique(c):c),c.selector=this.selector?this.selector+" "+a:a,c},filter:function(a){return this.pushStack(w(this,a||[],!1))},not:function(a){return this.pushStack(w(this,a||[],!0))},is:function(a){return!!w(this,"string"==typeof a&&t.test(a)?m(a):a||[],!1).length}});var x,y=a.document,z=/^(?:\s*(<[\w\W]+>)[^>]*|#([\w-]*))$/,A=m.fn.init=function(a,b){var c,d;if(!a)return this;if("string"==typeof a){if(c="<"===a.charAt(0)&&">"===a.charAt(a.length-1)&&a.length>=3?[null,a,null]:z.exec(a),!c||!c[1]&&b)return!b||b.jquery?(b||x).find(a):this.constructor(b).find(a);if(c[1]){if(b=b instanceof m?b[0]:b,m.merge(this,m.parseHTML(c[1],b&&b.nodeType?b.ownerDocument||b:y,!0)),u.test(c[1])&&m.isPlainObject(b))for(c in b)m.isFunction(this[c])?this[c](b[c]):this.attr(c,b[c]);return this}if(d=y.getElementById(c[2]),d&&d.parentNode){if(d.id!==c[2])return x.find(a);this.length=1,this[0]=d}return this.context=y,this.selector=a,this}return a.nodeType?(this.context=this[0]=a,this.length=1,this):m.isFunction(a)?"undefined"!=typeof x.ready?x.ready(a):a(m):(void 0!==a.selector&&(this.selector=a.selector,this.context=a.context),m.makeArray(a,this))};A.prototype=m.fn,x=m(y);
var B=/^(?:parents|prev(?:Until|All))/,C={children:!0,contents:!0,next:!0,prev:!0};m.extend({dir:function(a,b,c){var d=[],e=a[b];while(e&&9!==e.nodeType&&(void 0===c||1!==e.nodeType||!m(e).is(c)))1===e.nodeType&&d.push(e),e=e[b];return d},sibling:function(a,b){for(var c=[];a;a=a.nextSibling)1===a.nodeType&&a!==b&&c.push(a);return c}}),m.fn.extend({has:function(a){var b,c=m(a,this),d=c.length;return this.filter(function(){for(b=0;d>b;b++)if(m.contains(this,c[b]))return!0})},closest:function(a,b){for(var c,d=0,e=this.length,f=[],g=t.test(a)||"string"!=typeof a?m(a,b||this.context):0;e>d;d++)for(c=this[d];c&&c!==b;c=c.parentNode)if(c.nodeType<11&&(g?g.index(c)>-1:1===c.nodeType&&m.find.matchesSelector(c,a))){f.push(c);break}return this.pushStack(f.length>1?m.unique(f):f)},index:function(a){return a?"string"==typeof a?m.inArray(this[0],m(a)):m.inArray(a.jquery?a[0]:a,this):this[0]&&this[0].parentNode?this.first().prevAll().length:-1},add:function(a,b){return this.pushStack(m.unique(m.merge(this.get(),m(a,b))))},addBack:function(a){return this.add(null==a?this.prevObject:this.prevObject.filter(a))}});function D(a,b){do a=a[b];while(a&&1!==a.nodeType);return a}m.each({parent:function(a){var b=a.parentNode;return b&&11!==b.nodeType?b:null},parents:function(a){return m.dir(a,"parentNode")},parentsUntil:function(a,b,c){return m.dir(a,"parentNode",c)},next:function(a){return D(a,"nextSibling")},prev:function(a){return D(a,"previousSibling")},nextAll:function(a){return m.dir(a,"nextSibling")},prevAll:function(a){return m.dir(a,"previousSibling")},nextUntil:function(a,b,c)
{return m.dir(a,"nextSibling",c)},prevUntil:function(a,b,c){return m.dir(a,"previousSibling",c)},siblings:function(a){return m.sibling((a.parentNode||{}).firstChild,a)},children:function(a){return m.sibling(a.firstChild)},contents:function(a){return m.nodeName(a,"iframe")?a.contentDocument||a.contentWindow.document:m.merge([],a.childNodes)}},function(a,b){m.fn[a]=function(c,d){var e=m.map(this,b,c);return"Until"!==a.slice(-5)&&(d=c),d&&"string"==typeof d&&(e=m.filter(d,e)),this.length>1&&(C[a]||(e=m.unique(e)),B.test(a)&&(e=e.reverse())),this.pushStack(e)}});var E=/\S+/g,F={};function G(a){var b=F[a]={};return m.each(a.match(E)||[],function(a,c){b[c]=!0}),b}m.Callbacks=function(a){a="string"==typeof a?F[a]||G(a):m.extend({},a);var b,c,d,e,f,g,h=[],i=!a.once&&[],j=function(l){for(c=a.memory&&l,d=!0,f=g||0,g=0,e=h.length,b=!0;h&&e>f;f++)if(h[f].apply(l[0],l[1])===!1&&a.stopOnFalse){c=!1;break}b=!1,h&&(i?i.length&&j(i.shift()):c?h=[]:k.disable())},k={add:function(){if(h){var d=h.length;!function f(b){m.each(b,function(b,c){var d=m.type(c);"function"===d?a.unique&&k.has(c)||h.push(c):c&&c.length&&"string"!==d&&f(c)})}(arguments),b?e=h.length:c&&(g=d,j(c))}return this},remove:function(){return h&&m.each(arguments,function(a,c){var d;while((d=m.inArray(c,h,d))>-1)h.splice(d,1),b&&(e>=d&&e--,f>=d&&f--)}),this},has:function(a){return a?m.inArray(a,h)>-1:!(!h||!h.length)},empty:function(){return h=[],e=0,this},disable:function(){return h=i=c=void 0,this},disabled:
function(){return!h},lock:function(){return i=void 0,c||k.disable(),this},locked:function(){return!i},fireWith:function(a,c){return!h||d&&!i||(c=c||[],c=[a,c.slice?c.slice():c],b?i.push(c):j(c)),this},fire:function(){return k.fireWith(this,arguments),this},fired:function(){return!!d}};return k},m.extend({Deferred:function(a){var b=[["resolve","done",m.Callbacks("once memory"),"resolved"],["reject","fail",m.Callbacks("once memory"),"rejected"],["notify","progress",m.Callbacks("memory")]],c="pending",d={state:function(){return c},always:function(){return e.done(arguments).fail(arguments),this},then:function(){var a=arguments;return m.Deferred(function(c){m.each(b,function(b,f){var g=m.isFunction(a[b])&&a[b];e[f[1]](function(){var a=g&&g.apply(this,arguments);a&&m.isFunction(a.promise)?a.promise().done(c.resolve).fail(c.reject).progress(c.notify):c[f[0]+"With"](this===d?c.promise():this,g?[a]:arguments)})}),a=null}).promise()},promise:function(a){return null!=a?m.extend(a,d):d}},e={};return d.pipe=d.then,m.each(b,function(a,f){var g=f[2],h=f[3];d[f[1]]=g.add,h&&g.add(function(){c=h},b[1^a][2].disable,b[2][2].lock),e[f[0]]=function(){return e[f[0]+"With"](this===e?d:this,arguments),this},e[f[0]+"With"]=g.fireWith}),d.promise(e),a&&a.call(e,e),e},when:function(a){var b=0,c=d.call(arguments),e=c.length,f=1!==e||a&&m.isFunction(a.promise)?e:0,g=1===f?a:m.Deferred(),h=function(a,b,c)
{return function(e){b[a]=this,c[a]=arguments.length>1?d.call(arguments):e,c===i?g.notifyWith(b,c):--f||g.resolveWith(b,c)}},i,j,k;if(e>1)for(i=new Array(e),j=new Array(e),k=new Array(e);e>b;b++)c[b]&&m.isFunction(c[b].promise)?c[b].promise().done(h(b,k,c)).fail(g.reject).progress(h(b,j,i)):--f;return f||g.resolveWith(k,c),g.promise()}});var H;m.fn.ready=function(a){return m.ready.promise().done(a),this},m.extend({isReady:!1,readyWait:1,holdReady:function(a){a?m.readyWait++:m.ready(!0)},ready:function(a){if(a===!0?!--m.readyWait:!m.isReady){if(!y.body)return setTimeout(m.ready);m.isReady=!0,a!==!0&&--m.readyWait>0||(H.resolveWith(y,[m]),m.fn.triggerHandler&&(m(y).triggerHandler("ready"),m(y).off("ready")))}}});function I(){y.addEventListener?(y.removeEventListener("DOMContentLoaded",J,!1),a.removeEventListener("load",J,!1)):(y.detachEvent("onreadystatechange",J),a.detachEvent("onload",J))}function J(){(y.addEventListener||"load"===event.type||"complete"===y.readyState)&&(I(),m.ready())}m.ready.promise=function(b){if(!H)if(H=m.Deferred(),"complete"===y.readyState)setTimeout(m.ready);else if(y.addEventListener)y.addEventListener("DOMContentLoaded",J,!1),a.addEventListener("load",J,!1);else{y.attachEvent("onreadystatechange",J),a.attachEvent("onload",J);var c=!1;try{c=null==a.frameElement&&y.documentElement}catch(d){}c&&c.doScroll&&!function e(){if(!m.isReady){try{c.doScroll("left")}catch(a){return setTimeout(e,50)}I(),m.ready()}}()}return H.promise(b)};var K="undefined",L;for(L in m(k))break;k.ownLast="0"!==L,k.inlineBlockNeedsLayout=!1,m(function(){var a,b,c,d;c=y.getElementsByTagName("body")[0],c&&c.style&&(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),typeof b.style.zoom!==K&&(b.style.cssText="display:inline;margin:0;border:0;padding:1px;width:1px;zoom:1",k.inlineBlockNeedsLayout=a=3===b.offsetWidth,a&&(c.style.zoom=1)),c.removeChild(d))}),function(){var a=y.createElement("div");
if(null==k.deleteExpando){k.deleteExpando=!0;try{delete a.test}catch(b){k.deleteExpando=!1}}a=null}(),m.acceptData=function(a){var b=m.noData[(a.nodeName+" ").toLowerCase()],c=+a.nodeType||1;return 1!==c&&9!==c?!1:!b||b!==!0&&a.getAttribute("classid")===b};var M=/^(?:\{[\w\W]*\}|\[[\w\W]*\])$/,N=/([A-Z])/g;function O(a,b,c){if(void 0===c&&1===a.nodeType){var d="data-"+b.replace(N,"-$1").toLowerCase();if(c=a.getAttribute(d),"string"==typeof c){try{c="true"===c?!0:"false"===c?!1:"null"===c?null:+c+""===c?+c:M.test(c)?m.parseJSON(c):c}catch(e){}m.d`' || 
q'`ata(a,b,c)}else c=void 0}return c}function P(a){var b;for(b in a)if(("data"!==b||!m.isEmptyObject(a[b]))&&"toJSON"!==b)return!1;return!0}function Q(a,b,d,e){if(m.acceptData(a)){var f,g,h=m.expando,i=a.nodeType,j=i?m.cache:a,k=i?a[h]:a[h]&&h;if(k&&j[k]&&(e||j[k].data)||void 0!==d||"string"!=typeof b)return k||(k=i?a[h]=c.pop()||m.guid++:h),j[k]||(j[k]=i?{}:{toJSON:m.noop}),("object"==typeof b||"function"==typeof b)&&(e?j[k]=m.extend(j[k],b):j[k].data=m.extend(j[k].data,b)),g=j[k],e||(g.data||(g.data={}),g=g.data),void 0!==d&&(g[m.camelCase(b)]=d),"string"==typeof b?(f=g[b],null==f&&(f=g[m.camelCase(b)])):f=g,f}}function R(a,b,c){if(m.acceptData(a)){var d,e,f=a.nodeType,g=f?m.cache:a,h=f?a[m.expando]:m.expando;if(g[h]){if(b&&(d=c?g[h]:g[h].data)){m.isArray(b)?b=b.concat(m.map(b,m.camelCase)):b in d?b=[b]:(b=m.camelCase(b),b=b in d?[b]:b.split(" ")),e=b.length;while(e--)delete d[b[e]];if(c?!P(d):!m.isEmptyObject(d))return}(c||(delete g[h].data,P(g[h])))&&(f?m.cleanData([a],!0):k.deleteExpando||g!=g.window?delete g[h]:g[h]=null)}}}m.extend({cache:{},noData:{"applet ":!0,"embed ":!0,"object ":"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"},hasData:function(a)
{return a=a.nodeType?m.cache[a[m.expando]]:a[m.expando],!!a&&!P(a)},data:function(a,b,c){return Q(a,b,c)},removeData:function(a,b){return R(a,b)},_data:function(a,b,c){return Q(a,b,c,!0)},_removeData:function(a,b){return R(a,b,!0)}}),m.fn.extend({data:function(a,b){var c,d,e,f=this[0],g=f&&f.attributes;if(void 0===a){if(this.length&&(e=m.data(f),1===f.nodeType&&!m._data(f,"parsedAttrs"))){c=g.length;while(c--)g[c]&&(d=g[c].name,0===d.indexOf("data-")&&(d=m.camelCase(d.slice(5)),O(f,d,e[d])));m._data(f,"parsedAttrs",!0)}return e}return"object"==typeof a?this.each(function(){m.data(this,a)}):arguments.length>1?this.each(function(){m.data(this,a,b)}):f?O(f,a,m.data(f,a)):void 0},removeData:function(a){return this.each(function(){m.removeData(this,a)})}}),m.extend({queue:function(a,b,c){var d;return a?(b=(b||"fx")+"queue",d=m._data(a,b),c&&(!d||m.isArray(c)?d=m._data(a,b,m.makeArray(c)):d.push(c)),d||[]):void 0},dequeue:function(a,b){b=b||"fx";var c=m.queue(a,b),d=c.length,e=c.shift(),f=m._queueHooks(a,b),g=function(){m.dequeue(a,b)};"inprogress"===e&&(e=c.shift(),d--),e&&("fx"===b&&c.unshift("inprogress"),delete f.stop,e.call(a,g,f)),!d&&f&&f.empty.fire()},_queueHooks:function(a,b){var c=b+"queueHooks";return m._data(a,c)||m._data(a,c,{empty:m.Callbacks("once memory").add(function(){m._removeData(a,b+"queue"),m._removeData(a,c)})})}}),m.fn.extend({queue:function(a,b){var c=2;return"string"!=typeof a&&(b=a,a="fx",c--),arguments.length<c?m.queue(this[0],a):void 0===b?this:this.each(function(){var c=m.queue(this,a,b);
m._queueHooks(this,a),"fx"===a&&"inprogress"!==c[0]&&m.dequeue(this,a)})},dequeue:function(a){return this.each(function(){m.dequeue(this,a)})},clearQueue:function(a){return this.queue(a||"fx",[])},promise:function(a,b){var c,d=1,e=m.Deferred(),f=this,g=this.length,h=function(){--d||e.resolveWith(f,[f])};"string"!=typeof a&&(b=a,a=void 0),a=a||"fx";while(g--)c=m._data(f[g],a+"queueHooks"),c&&c.empty&&(d++,c.empty.add(h));return h(),e.promise(b)}});var S=/[+-]?(?:\d*\.|)\d+(?:[eE][+-]?\d+|)/.source,T=["Top","Right","Bottom","Left"],U=function(a,b){return a=b||a,"none"===m.css(a,"display")||!m.contains(a.ownerDocument,a)},V=m.access=function(a,b,c,d,e,f,g){var h=0,i=a.length,j=null==c;if("object"===m.type(c)){e=!0;for(h in c)m.access(a,b,h,c[h],!0,f,g)}else if(void 0!==d&&(e=!0,m.isFunction(d)||(g=!0),j&&(g?(b.call(a,d),b=null):(j=b,b=function(a,b,c){return j.call(m(a),c)})),b))for(;i>h;h++)b(a[h],c,g?d:d.call(a[h],h,b(a[h],c)));return e?a:j?b.call(a):i?b(a[0],c):f},W=/^(?:checkbox|radio)$/i;!function(){var a=y.createElement("input"),b=y.createElement("div"),c=y.createDocumentFragment();
if(b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",k.leadingWhitespace=3===b.firstChild.nodeType,k.tbody=!b.getElementsByTagName("tbody").length,k.htmlSerialize=!!b.getElementsByTagName("link").length,k.html5Clone="<:nav></:nav>"!==y.createElement("nav").cloneNode(!0).outerHTML,a.type="checkbox",a.checked=!0,c.appendChild(a),k.appendChecked=a.checked,b.innerHTML="<textarea>x</textarea>",k.noCloneChecked=!!b.cloneNode(!0).lastChild.defaultValue,c.appendChild(b),b.innerHTML="<input type='radio' checked='checked' name='t'/>",k.checkClone=b.cloneNode(!0).cloneNode(!0).lastChild.checked,k.noCloneEvent=!0,b.attachEvent&&(b.attachEvent("onclick",function(){k.noCloneEvent=!1}),b.cloneNode(!0).click()),null==k.deleteExpando){k.deleteExpando=!0;try{delete b.test}catch(d){k.deleteExpando=!1}}}(),function(){var b,c,d=y.createElement("div");for(b in{submit:!0,change:!0,focusin:!0})c="on"+b,(k[b+"Bubbles"]=c in a)||(d.setAttribute(c,"t"),k[b+"Bubbles"]=d.attributes[c].expando===!1);d=null}();var X=/^(?:input|select|textarea)$/i,Y=/^key/,Z=/^(?:mouse|pointer|contextmenu)|click/,$=/^(?:focusinfocus|focusoutblur)$/,_=/^([^.]*)(?:\.(.+)|)$/;function ab(){return!0}
function bb(){return!1}function cb(){try{return y.activeElement}catch(a){}}m.event={global:{},add:function(a,b,c,d,e){var f,g,h,i,j,k,l,n,o,p,q,r=m._data(a);if(r){c.handler&&(i=c,c=i.handler,e=i.selector),c.guid||(c.guid=m.guid++),(g=r.events)||(g=r.events={}),(k=r.handle)||(k=r.handle=function(a){return typeof m===K||a&&m.event.triggered===a.type?void 0:m.event.dispatch.apply(k.elem,arguments)},k.elem=a),b=(b||"").match(E)||[""],h=b.length;while(h--)f=_.exec(b[h])||[],o=q=f[1],p=(f[2]||"").split(".").sort(),o&&(j=m.event.special[o]||{},o=(e?j.delegateType:j.bindType)||o,j=m.event.special[o]||{},l=m.extend({type:o,origType:q,data:d,handler:c,guid:c.guid,selector:e,needsContext:e&&m.expr.match.needsContext.test(e),namespace:p.join(".")},i),(n=g[o])||(n=g[o]=[],n.delegateCount=0,j.setup&&j.setup.call(a,d,p,k)!==!1||(a.addEventListener?a.addEventListener(o,k,!1):a.attachEvent&&a.attachEvent("on"+o,k))),j.add&&(j.add.call(a,l),l.handler.guid||(l.handler.guid=c.guid)),e?n.splice(n.delegateCount++,0,l):n.push(l),m.event.global[o]=!0);a=null}},remove:function(a,b,c,d,e){var f,g,h,i,j,k,l,n,o,p,q,r=m.hasData(a)&&m._data(a);if(r&&(k=r.events)){b=(b||"").match(E)||[""],j=b.length;while(j--)if(h=_.exec(b[j])||[],o=q=h[1],p=(h[2]||"").split(".").sort(),o){l=m.event.special[o]||{},o=(d?l.delegateType:l.bindType)||o,n=k[o]||[],h=h[2]&&new RegExp("(^|\\.)"+p.join("\\.(?:.*\\.|)")+"(\\.|$)"),i=f=n.length;while(f--)g=n[f],!e&&q!==g.origType||c&&c.guid!==g.guid||h&&!h.test(g.namespace)||d&&d!==g.selector&&("**"!==d||!g.selector)||(n.splice(f,1),g.selector&&n.delegateCount--,l.remove&&l.remove.call(a,g));
i&&!n.length&&(l.teardown&&l.teardown.call(a,p,r.handle)!==!1||m.removeEvent(a,o,r.handle),delete k[o])}else for(o in k)m.event.remove(a,o+b[j],c,d,!0);m.isEmptyObject(k)&&(delete r.handle,m._removeData(a,"events"))}},trigger:function(b,c,d,e){var f,g,h,i,k,l,n,o=[d||y],p=j.call(b,"type")?b.type:b,q=j.call(b,"namespace")?b.namespace.split("."):[];if(h=l=d=d||y,3!==d.nodeType&&8!==d.nodeType&&!$.test(p+m.event.triggered)&&(p.indexOf(".")>=0&&(q=p.split("."),p=q.shift(),q.sort()),g=p.indexOf(":")<0&&"on"+p,b=b[m.expando]?b:new m.Event(p,"object"==typeof b&&b),b.isTrigger=e?2:3,b.namespace=q.join("."),b.namespace_re=b.namespace?new RegExp("(^|\\.)"+q.join("\\.(?:.*\\.|)")+"(\\.|$)"):null,b.result=void 0,b.target||(b.target=d),c=null==c?[b]:m.makeArray(c,[b]),k=m.event.special[p]||{},e||!k.trigger||k.trigger.apply(d,c)!==!1)){if(!e&&!k.noBubble&&!m.isWindow(d)){for(i=k.delegateType||p,$.test(i+p)||(h=h.parentNode);h;h=h.parentNode)o.push(h),l=h;l===(d.ownerDocument||y)&&o.push(l.defaultView||l.parentWindow||a)}n=0;while((h=o[n++])&&!b.isPropagationStopped())b.type=n>1?i:k.bindType||p,f=(m._data(h,"events")||{})[b.type]&&m._data(h,"handle"),f&&f.apply(h,c),f=g&&h[g],f&&f.apply&&m.acceptData(h)&&(b.result=f.apply(h,c),b.result===!1&&b.preventDefault());if(b.type=p,!e&&!b.isDefaultPrevented()&&(!k._default||k._default.apply(o.pop(),c)===!1)&&m.acceptData(d)&&g&&d[p]&&!m.isWindow(d)){l=d[g],l&&(d[g]=null),m.event.triggered=p;try{d[p]()}catch(r){}m.event.triggered=void 0,l&&(d[g]=l)}return b.result}},dispatch:function(a){a=m.event.fix(a);
var b,c,e,f,g,h=[],i=d.call(arguments),j=(m._data(this,"events")||{})[a.type]||[],k=m.event.special[a.type]||{};if(i[0]=a,a.delegateTarget=this,!k.preDispatch||k.preDispatch.call(this,a)!==!1){h=m.event.handlers.call(this,a,j),b=0;while((f=h[b++])&&!a.isPropagationStopped()){a.currentTarget=f.elem,g=0;while((e=f.handlers[g++])&&!a.isImmediatePropagationStopped())(!a.namespace_re||a.namespace_re.test(e.namespace))&&(a.handleObj=e,a.data=e.data,c=((m.event.special[e.origType]||{}).handle||e.handler).apply(f.elem,i),void 0!==c&&(a.result=c)===!1&&(a.preventDefault(),a.stopPropagation()))}return k.postDispatch&&k.postDispatch.call(this,a),a.result}},handlers:function(a,b){var c,d,e,f,g=[],h=b.delegateCount,i=a.target;if(h&&i.nodeType&&(!a.button||"click"!==a.type))for(;i!=this;i=i.parentNode||this)if(1===i.nodeType&&(i.disabled!==!0||"click"!==a.type)){for(e=[],f=0;h>f;f++)d=b[f],c=d.selector+" ",void 0===e[c]&&(e[c]=d.needsContext?m(c,this).index(i)>=0:m.find(c,this,null,[i]).length),e[c]&&e.push(d);e.length&&g.push({elem:i,handlers:e})}return h<b.length&&g.push({elem:this,handlers:b.slice(h)}),g},fix:function(a){if(a[m.expando])return a;var b,c,d,e=a.type,f=a,g=this.fixHooks[e];g||(this.fixHooks[e]=g=Z.test(e)?this.mouseHooks:Y.test(e)?this.keyHooks:{}),d=g.props?this.props.concat(g.props):this.props,a=new m.Event(f),b=d.length;while(b--)c=d[b],a[c]=f[c];return a.target||(a.target=f.srcElement||y),3===a.target.nodeType&&(a.target=a.target.parentNode),a.metaKey=!!a.metaKey,g.filter?g.filter(a,f):a},props:"altKey bubbles cancelable ctrlKey currentTarget eventPhase metaKey relatedTarget shiftKey target timeStamp view which".split(" "),fixHooks:{},keyHooks:{props:"char charCode key keyCode".split(" "),filter:function(a,b){return null==a.which&&(a.which=null!=b.charCode?b.charCode:b.keyCode),a}},mouseHooks:{props:"button buttons clientX clientY fromElement offsetX offsetY pageX pageY screenX screenY toElement".split(" "),filter:function(a,b){var c,d,e,f=b.button,g=b.fromElement;
return null==a.pageX&&null!=b.clientX&&(d=a.target.ownerDocument||y,e=d.documentElement,c=d.body,a.pageX=b.clientX+(e&&e.scrollLeft||c&&c.scrollLeft||0)-(e&&e.clientLeft||c&&c.clientLeft||0),a.pageY=b.clientY+(e&&e.scrollTop||c&&c.scrollTop||0)-(e&&e.clientTop||c&&c.clientTop||0)),!a.relatedTarget&&g&&(a.relatedTarget=g===a.target?b.toElement:g),a.which||void 0===f||(a.which=1&f?1:2&f?3:4&f?2:0),a}},special:{load:{noBubble:!0},focus:{trigger:function(){if(this!==cb()&&this.focus)try{return this.focus(),!1}catch(a){}},delegateType:"focusin"},blur:{trigger:function(){return this===cb()&&this.blur?(this.blur(),!1):void 0},delegateType:"focusout"},click:{trigger:function(){return m.nodeName(this,"input")&&"checkbox"===this.type&&this.click?(this.click(),!1):void 0},_default:function(a){return m.nodeName(a.target,"a")}},beforeunload:{postDispatch:function(a){void 0!==a.result&&a.originalEvent&&(a.originalEvent.returnValue=a.result)}}},simulate:function(a,b,c,d){var e=m.extend(new m.Event,c,{type:a,isSimulated:!0,originalEvent:{}});d?m.event.trigger(e,null,b):m.event.dispatch.call(b,e),e.isDefaultPrevented()&&c.preventDefault()}},m.removeEvent=y.removeEventListener?function(a,b,c){a.removeEventListener&&a.removeEventListener(b,c,!1)}:function(a,b,c){var d="on"+b;a.detachEvent&&(typeof a[d]===K&&(a[d]=null),a.detachEvent(d,c))},m.Event=function(a,b){return this instanceof m.Event?(a&&a.type?(this.originalEvent=a,this.type=a.type,this.isDefaultPrevented=a.defaultPrevented||void 0===a.defaultPrevented&&a.returnValue===!1?ab:bb):this.type=a,b&&m.extend(this,b),this.timeStamp=a&&a.timeStamp||m.now(),void(this[m.expando]=!0)):new m.Event(a,b)},m.Event.prototype={isDefaultPrevented:bb,isPropagationStopped:bb,isImmediatePropagationStopped:bb,preventDefault:function(){var a=this.originalEvent;this.isDefaultPrevented=ab,a&&(a.preventDefault?a.preventDefault():a.returnValue=!1)},stopPropagation:function(){var a=this.originalEvent;this.isPropagationStopped=ab,a&&(a.stopPropagation&&a.stopPropagation(),a.cancelBubble=!0)},stopImmediatePropagation:function(){var a=this.originalEvent;
this.isImmediatePropagationStopped=ab,a&&a.stopImmediatePropagation&&a.stopImmediatePropagation(),this.stopPropagation()}},m.each({mouseenter:"mouseover",mouseleave:"mouseout",pointerenter:"pointerover",pointerleave:"pointerout"},function(a,b){m.event.special[a]={delegateType:b,bindType:b,handle:function(a){var c,d=this,e=a.relatedTarget,f=a.handleObj;return(!e||e!==d&&!m.contains(d,e))&&(a.type=f.origType,c=f.handler.apply(this,arguments),a.type=b),c}}}),k.submitBubbles||(m.event.special.submit={setup:function(){return m.nodeName(this,"form")?!1:void m.event.add(this,"click._submit keypress._submit",function(a){var b=a.target,c=m.nodeName(b,"input")||m.nodeName(b,"button")?b.form:void 0;c&&!m._data(c,"submitBubbles")&&(m.event.add(c,"submit._submit",function(a){a._submit_bubble=!0}),m._data(c,"submitBubbles",!0))})},postDispatch:function(a){a._submit_bubble&&(delete a._submit_bubble,this.parentNode&&!a.isTrigger&&m.event.simulate("submit",this.parentNode,a,!0))},teardown:
function(){return m.nodeName(this,"form")?!1:void m.event.remove(this,"._submit")}}),k.changeBubbles||(m.event.special.change={setup:function(){return X.test(this.nodeName)?(("checkbox"===this.type||"radio"===this.type)&&(m.event.add(this,"propertychange._change",function(a){"checked"===a.originalEvent.propertyName&&(this._just_changed=!0)}),m.event.add(this,"click._change",function(a){this._just_changed&&!a.isTrigger&&(this._just_changed=!1),m.event.simulate("change",this,a,!0)})),!1):void m.event.add(this,"beforeactivate._change",function(a){var b=a.target;X.test(b.nodeName)&&!m._data(b,"changeBubbles")&&(m.event.add(b,"change._change",function(a){!this.parentNode||a.isSimulated||a.isTrigger||m.event.simulate("change",this.parentNode,a,!0)}),m._data(b,"changeBubbles",!0))})},handle:function(a){var b=a.target;return this!==b||a.isSimulated||a.isTrigger||"radio"!==b.type&&"checkbox"!==b.type?a.handleObj.handler.apply(this,arguments):void 0},teardown:function(){return m.event.remove(this,"._change"),!X.test(this.nodeName)}}),k.focusinBubbles||m.each({focus:"focusin",blur:"focusout"},function(a,b){var c=function(a){m.event.simulate(b,a.target,m.event.fix(a),!0)};
m.event.special[b]={setup:function(){var d=this.ownerDocument||this,e=m._data(d,b);e||d.addEventListener(a,c,!0),m._data(d,b,(e||0)+1)},teardown:function(){var d=this.ownerDocument||this,e=m._data(d,b)-1;e?m._data(d,b,e):(d.removeEventListener(a,c,!0),m._removeData(d,b))}}}),m.fn.extend({on:function(a,b,c,d,e){var f,g;if("object"==typeof a){"string"!=typeof b&&(c=c||b,b=void 0);for(f in a)this.on(f,b,c,a[f],e);return this}if(null==c&&null==d?(d=b,c=b=void 0):null==d&&("string"==typeof b?(d=c,c=void 0):(d=c,c=b,b=void 0)),d===!1)d=bb;else if(!d)return this;return 1===e&&(g=d,d=function(a){return m().off(a),g.apply(this,arguments)},d.guid=g.guid||(g.guid=m.guid++)),this.each(function(){m.event.add(this,a,d,c,b)})},one:function(a,b,c,d){return this.on(a,b,c,d,1)},off:function(a,b,c){var d,e;if(a&&a.preventDefault&&a.handleObj)return d=a.handleObj,m(a.delegateTarget).off(d.namespace?d.origType+"."+d.namespace:d.origType,d.selector,d.handler),this;if("object"==typeof a){for(e in a)this.off(e,b,a[e]);
return this}return(b===!1||"function"==typeof b)&&(c=b,b=void 0),c===!1&&(c=bb),this.each(function(){m.event.remove(this,a,c,b)})},trigger:function(a,b){return this.each(function(){m.event.trigger(a,b,this)})},triggerHandler:function(a,b){var c=this[0];return c?m.event.trigger(a,b,c,!0):void 0}});function db(a){var b=eb.split("|"),c=a.createDocumentFragment();if(c.createElement)while(b.length)c.createElement(b.pop());return c}var eb="abbr|article|aside|audio|bdi|canvas|data|datalist|details|figcaption|figure|footer|header|hgroup|mark|meter|nav|output|progress|section|summary|time|video",fb=/ jQuery\d+="(?:null|\d+)"/g,gb=new RegExp("<(?:"+eb+")[\\s/>]","i"),hb=/^\s+/,ib=/<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:]+)[^>]*)\/>/gi,jb=/<([\w:]+)/,kb=/<tbody/i,lb=/<|&#?\w+;/,mb=/<(?:script|style|link)/i,nb=/checked\s*(?:[^=]|=\s*.checked.)/i,ob=/^$|\/(?:java|ecma)script/i,pb=/^true\/(.*)/,qb=/^\s*<!(?:\[CDATA\[|--)|(?:\]\]|--)>\s*$/g,rb={option:[1,"<select multiple='multiple'>","</select>"],legend:[1,"<fieldset>","</fieldset>"],area:[1,"<map>","</map>"],param:[1,"<object>","</object>"],thead:[1,"<table>","</table>"],tr:[2,"<table><tbody>","</tbody></table>"],col:[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"],td:[3,"<table><tbody><tr>","</tr></tbody></table>"],_default:k.htmlSerialize?[0,"",""]:[1,"X<div>","</div>"]},sb=db(y),tb=sb.appendChild(y.createElement("div"));rb.optgroup=rb.option,rb.tbody=rb.tfoot=rb.colgroup=rb.caption=rb.thead,rb.th=rb.td;function ub(a,b){var c,d,e=0,f=typeof a.getElementsByTagName!==K?a.getElementsByTagName(b||"*"):typeof a.querySelectorAll!==K?a.querySelectorAll(b||"*"):void 0;if(!f)for(f=[],c=a.childNodes||a;null!=(d=c[e]);
e++)!b||m.nodeName(d,b)?f.push(d):m.merge(f,ub(d,b));return void 0===b||b&&m.nodeName(a,b)?m.merge([a],f):f}function vb(a){W.test(a.type)&&(a.defaultChecked=a.checked)}function wb(a,b){return m.nodeName(a,"table")&&m.nodeName(11!==b.nodeType?b:b.firstChild,"tr")?a.getElementsByTagName("tbody")[0]||a.appendChild(a.ownerDocument.createElement("tbody")):a}function xb(a){return a.type=(null!==m.find.attr(a,"type"))+"/"+a.type,a}function yb(a){var b=pb.exec(a.type);return b?a.type=b[1]:a.removeAttribute("type"),a}function zb(a,b){for(var c,d=0;null!=(c=a[d]);d++)m._data(c,"globalEval",!b||m._data(b[d],"globalEval"))}function Ab(a,b){if(1===b.nodeType&&m.hasData(a)){var c,d,e,f=m._data(a),g=m._data(b,f),h=f.events;if(h){delete g.handle,g.events={};for(c in h)for(d=0,e=h[c].length;e>d;d++)m.event.add(b,c,h[c][d])}g.data&&(g.data=m.extend({},g.data))}}function Bb(a,b){var c,d,e;if(1===b.nodeType){if(c=b.nodeName.toLowerCase(),!k.noCloneEvent&&b[m.expando]){e=m._data(b);for(d in e.events)m.removeEvent(b,d,e.handle);b.removeAttribute(m.expando)}"script"===c&&b.text!==a.text?(xb(b).text=a.text,yb(b)):"object"===c?(b.parentNode&&(b.outerHTML=a.outerHTML),k.html5Clone&&a.innerHTML&&!m.trim(b.innerHTML)&&(b.innerHTML=a.innerHTML)):"input"===c&&W.test(a.type)?(b.defaultChecked=b.checked=a.checked,b.value!==a.value&&(b.value=a.value)):"option"===c?b.defaultSelected=b.selected=a.defaultSelected:("input"===c||"textarea"===c)&&(b.defaultValue=a.defaultValue)}}
m.extend({clone:function(a,b,c){var d,e,f,g,h,i=m.contains(a.ownerDocument,a);if(k.html5Clone||m.isXMLDoc(a)||!gb.test("<"+a.nodeName+">")?f=a.cloneNode(!0):(tb.innerHTML=a.outerHTML,tb.removeChild(f=tb.firstChild)),!(k.noCloneEvent&&k.noCloneChecked||1!==a.nodeType&&11!==a.nodeType||m.isXMLDoc(a)))for(d=ub(f),h=ub(a),g=0;null!=(e=h[g]);++g)d[g]&&Bb(e,d[g]);if(b)if(c)for(h=h||ub(a),d=d||ub(f),g=0;null!=(e=h[g]);g++)Ab(e,d[g]);else Ab(a,f);return d=ub(f,"script"),d.length>0&&zb(d,!i&&ub(a,"script")),d=h=e=null,f},buildFragment:function(a,b,c,d){for(var e,f,g,h,i,j,l,n=a.length,o=db(b),p=[],q=0;n>q;q++)if(f=a[q],f||0===f)if("object"===m.type(f))m.merge(p,f.nodeType?[f]:f);else if(lb.test(f)){h=h||o.appendChild(b.createElement("div")),i=(jb.exec(f)||["",""])[1].toLowerCase(),l=rb[i]||rb._default,h.innerHTML=l[1]+f.replace(ib,"<$1></$2>")+l[2],e=l[0];while(e--)h=h.lastChild;if(!k.leadingWhitespace&&hb.test(f)&&p.push(b.createTextNode(hb.exec(f)[0])),!k.tbody){f="table"!==i||kb.test(f)?"<table>"!==l[1]||kb.test(f)?0:h:h.firstChild,e=f&&f.childNodes.length;while(e--)m.nodeName(j=f.childNodes[e],"tbody")&&!j.childNodes.length&&f.removeChild(j)}m.merge(p,h.childNodes),h.textContent="";while(h.firstChild)h.removeChild(h.firstChild);h=o.lastChild}else p.push(b.createTextNode(f));
h&&o.removeChild(h),k.appendChecked||m.grep(ub(p,"input"),vb),q=0;while(f=p[q++])if((!d||-1===m.inArray(f,d))&&(g=m.contains(f.ownerDocument,f),h=ub(o.appendChild(f),"script"),g&&zb(h),c)){e=0;while(f=h[e++])ob.test(f.type||"")&&c.push(f)}return h=null,o},cleanData:function(a,b){for(var d,e,f,g,h=0,i=m.expando,j=m.cache,l=k.deleteExpando,n=m.event.special;null!=(d=a[h]);h++)if((b||m.acceptData(d))&&(f=d[i],g=f&&j[f])){if(g.events)for(e in g.events)n[e]?m.event.remove(d,e):m.removeEvent(d,e,g.handle);j[f]&&(delete j[f],l?delete d[i]:typeof d.removeAttribute!==K?d.removeAttribute(i):d[i]=null,c.push(f))}}}),m.fn.extend({text:function(a){return V(this,function(a){return void 0===a?m.text(this):this.empty().append((this[0]&&this[0].ownerDocument||y).createTextNode(a))},null,a,arguments.length)},append:function(){return this.domManip(arguments,function(a){if(1===this.nodeType||11===this.nodeType||9===this.nodeType){var b=wb(this,a);b.appendChild(a)}})},prepend:function(){return this.domManip(arguments,function(a){if(1===this.nodeType||11===this.nodeType||9===this.nodeType){var b=wb(this,a);b.insertBefore(a,b.firstChild)}})},before:function(){return this.domManip(arguments,function(a){this.parentNode&&this.parentNode.insertBefore(a,this)})},after:function(){return this.domManip(arguments,
function(a){this.parentNode&&this.parentNode.insertBefore(a,this.nextSibling)})},remove:function(a,b){for(var c,d=a?m.filter(a,this):this,e=0;null!=(c=d[e]);e++)b||1!==c.nodeType||m.cleanData(ub(c)),c.parentNode&&(b&&m.contains(c.ownerDocument,c)&&zb(ub(c,"script")),c.parentNode.removeChild(c));return this},empty:function(){for(var a,b=0;null!=(a=this[b]);b++){1===a.nodeType&&m.cleanData(ub(a,!1));while(a.firstChild)a.removeChild(a.firstChild);a.options&&m.nodeName(a,"select")&&(a.options.length=0)}return this},clone:function(a,b){return a=null==a?!1:a,b=null==b?a:b,this.map(function(){return m.clone(this,a,b)})},html:function(a){return V(this,function(a){var b=this[0]||{},c=0,d=this.length;if(void 0===a)return 1===b.nodeType?b.innerHTML.replace(fb,""):void 0;if(!("string"!=typeof a||mb.test(a)||!k.htmlSerialize&&gb.test(a)||!k.leadingWhitespace&&hb.test(a)||rb[(jb.exec(a)||["",""])[1].toLowerCase()])){a=a.replace(ib,"<$1></$2>");try{for(;d>c;c++)b=this[c]||{},1===b.nodeType&&(m.cleanData(ub(b,!1)),b.innerHTML=a);b=0}catch(e){}}b&&this.empty().append(a)},null,a,arguments.length)},replaceWith:function(){var a=arguments[0];
return this.domManip(arguments,function(b){a=this.parentNode,m.cleanData(ub(this)),a&&a.replaceChild(b,this)}),a&&(a.length||a.nodeType)?this:this.remove()},detach:function(a){return this.remove(a,!0)},domManip:function(a,b){a=e.apply([],a);var c,d,f,g,h,i,j=0,l=this.length,n=this,o=l-1,p=a[0],q=m.isFunction(p);if(q||l>1&&"string"==typeof p&&!k.checkClone&&nb.test(p))return this.each(function(c){var d=n.eq(c);q&&(a[0]=p.call(this,c,d.html())),d.domManip(a,b)});if(l&&(i=m.buildFragment(a,this[0].ownerDocument,!1,this),c=i.firstChild,1===i.childNodes.length&&(i=c),c)){for(g=m.map(ub(i,"script"),xb),f=g.length;l>j;j++)d=i,j!==o&&(d=m.clone(d,!0,!0),f&&m.merge(g,ub(d,"script"))),b.call(this[j],d,j);if(f)for(h=g[g.length-1].ownerDocument,m.map(g,yb),j=0;f>j;j++)d=g[j],ob.test(d.type||"")&&!m._data(d,"globalEval")&&m.contains(h,d)&&(d.src?m._evalUrl&&m._evalUrl(d.src):m.globalEval((d.text||d.textContent||d.innerHTML||"").replace(qb,"")));i=c=null}return this}}),m.each({appendTo:"append",prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(a,b){m.fn[a]=function(a){for(var c,d=0,e=[],g=m(a),h=g.length-1;h>=d;d++)c=d===h?this:this.clone(!0),m(g[d])[b](c),f.apply(e,c.get());return this.pushStack(e)}});var Cb,Db={};
function Eb(b,c){var d,e=m(c.createElement(b)).appendTo(c.body),f=a.getDefaultComputedStyle&&(d=a.getDefaultComputedStyle(e[0]))?d.display:m.css(e[0],"display");return e.detach(),f}function Fb(a){var b=y,c=Db[a];return c||(c=Eb(a,b),"none"!==c&&c||(Cb=(Cb||m("<iframe frameborder='0' width='0' height='0'/>")).appendTo(b.documentElement),b=(Cb[0].contentWindow||Cb[0].contentDocument).document,b.write(),b.close(),c=Eb(a,b),Cb.detach()),Db[a]=c),c}!function(){var a;k.shrinkWrapBlocks=function(){if(null!=a)return a;a=!1;var b,c,d;return c=y.getElementsByTagName("body")[0],c&&c.style?(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),typeof b.style.zoom!==K&&(b.style.cssText="-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:1px;width:1px;zoom:1",b.appendChild(y.createElement("div")).style.width="5px",a=3!==b.offsetWidth),c.removeChild(d),a):void 0}}();
var Gb=/^margin/,Hb=new RegExp("^("+S+")(?!px)[a-z%]+$","i"),Ib,Jb,Kb=/^(top|right|bottom|left)$/;a.getComputedStyle?(Ib=function(a){return a.ownerDocument.defaultView.getComputedStyle(a,null)},Jb=function(a,b,c){var d,e,f,g,h=a.style;return c=c||Ib(a),g=c?c.getPropertyValue(b)||c[b]:void 0,c&&(""!==g||m.contains(a.ownerDocument,a)||(g=m.style(a,b)),Hb.test(g)&&Gb.test(b)&&(d=h.width,e=h.minWidth,f=h.maxWidth,h.minWidth=h.maxWidth=h.width=g,g=c.width,h.width=d,h.minWidth=e,h.maxWidth=f)),void 0===g?g:g+""}):y.documentElement.currentStyle&&(Ib=function(a){return a.currentStyle},Jb=function(a,b,c){var d,e,f,g,h=a.style;return c=c||Ib(a),g=c?c[b]:void 0,null==g&&h&&h[b]&&(g=h[b]),Hb.test(g)&&!Kb.test(b)&&(d=h.left,e=a.runtimeStyle,f=e&&e.left,f&&(e.left=a.currentStyle.left),h.left="fontSize"===b?"1em":g,g=h.pixelLeft+"px",h.left=d,f&&(e.left=f)),void 0===g?g:g+""||"auto"});function Lb(a,b){return{get:
function(){var c=a();if(null!=c)return c?void delete this.get:(this.get=b).apply(this,arguments)}}}!function(){var b,c,d,e,f,g,h;if(b=y.createElement("div"),b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",d=b.getElementsByTagName("a")[0],c=d&&d.style){c.cssText="float:left;opacity:.5",k.opacity="0.5"===c.opacity,k.cssFloat=!!c.cssFloat,b.style.backgroundClip="content-box",b.cloneNode(!0).style.backgroundClip="",k.clearCloneStyle="content-box"===b.style.backgroundClip,k.boxSizing=""===c.boxSizing||""===c.MozBoxSizing||""===c.WebkitBoxSizing,m.extend(k,{reliableHiddenOffsets:function(){return null==g&&i(),g},boxSizingReliable:function(){return null==f&&i(),f},pixelPosition:function(){return null==e&&i(),e},reliableMarginRight:function(){return null==h&&i(),h}});function i(){var b,c,d,i;c=y.getElementsByTagName("body")[0],c&&c.style&&(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),b.style.cssText="-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box;display:block;margin-top:1%;top:1%;border:1px;padding:1px;width:4px;position:absolute",e=f=!1,h=!0,a.getComputedStyle&&(e="1%"!==(a.getComputedStyle(b,null)||{}).top,f="4px"===(a.getComputedStyle(b,null)||{width:"4px"}).width,i=b.appendChild(y.createElement("div")),i.style.cssText=b.style.cssText="-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:0",i.style.marginRight=i.style.width="0",b.style.width="1px",h=!parseFloat((a.getComputedStyle(i,null)||{}).marginRight)),b.innerHTML="<table><tr><td></td><td>t</td></tr></table>",i=b.getElementsByTagName("td"),i[0].style.cssText="margin:0;border:0;padding:0;display:none",g=0===i[0].offsetHeight,g&&(i[0].style.display="",i[1].style.display="none",g=0===i[0].offsetHeight),c.removeChild(d))}}}(),m.swap=function(a,b,c,d){var e,f,g={};for(f in b)g[f]=a.style[f],a.style[f]=b[f];e=c.apply(a,d||[]);for(f in b)a.style[f]=g[f];return e};var Mb=/alpha\([^)]*\)/i,Nb=/opacity\s*=\s*([^)]*)/,Ob=/^(none|table(?!-c[ea]).+)/,Pb=new RegExp("^("+S+")(.*)$","i"),Qb=new RegExp("^([+-])=("+S+")","i"),Rb={position:"absolute",visibility:"hidden",display:"block"},Sb={letterSpacing:"0",fontWeight:"400"},Tb=["Webkit","O","Moz","ms"];function Ub(a,b){if(b in a)return b;var c=b.charAt(0).
toUpperCase()+b.slice(1),d=b,e=Tb.length;while(e--)if(b=Tb[e]+c,b in a)return b;return d}function Vb(a,b){for(var c,d,e,f=[],g=0,h=a.length;h>g;g++)d=a[g],d.style&&(f[g]=m._data(d,"olddisplay"),c=d.style.display,b?(f[g]||"none"!==c||(d.style.display=""),""===d.style.display&&U(d)&&(f[g]=m._data(d,"olddisplay",Fb(d.nodeName)))):(e=U(d),(c&&"none"!==c||!e)&&m._data(d,"olddisplay",e?c:m.css(d,"display"))));for(g=0;h>g;g++)d=a[g],d.style&&(b&&"none"!==d.style.display&&""!==d.style.display||(d.style.display=b?f[g]||"":"none"));return a}function Wb(a,b,c){var d=Pb.exec(b);return d?Math.max(0,d[1]-(c||0))+(d[2]||"px"):b}function Xb(a,b,c,d,e){for(var f=c===(d?"border":"content")?4:"width"===b?1:0,g=0;4>f;f+=2)"margin"===c&&(g+=m.css(a,c+T[f],!0,e)),d?("content"===c&&(g-=m.css(a,"padding"+T[f],!0,e)),"margin"!==c&&(g-=m.css(a,"border"+T[f]+"Width",!0,e))):(g+=m.css(a,"padding"+T[f],!0,e),"padding"!==c&&(g+=m.css(a,"border"+T[f]+"Width",!0,e)));return g}function Yb(a,b,c){var d=!0,e="width"===b?a.offsetWidth:a.offsetHeight,f=Ib(a),g=k.boxSizing&&"border-box"===m.css(a,"boxSizing",!1,f);if(0>=e||null==e){if(e=Jb(a,b,f),(0>e||null==e)&&(e=a.style[b]),Hb.test(e))return e;d=g&&(k.boxSizingReliable()||e===a.style[b]),e=parseFloat(e)||0}return e+Xb(a,b,c||(g?"border":"content"),d,f)+"px"}m.extend({cssHooks:{opacity:{get:function(a,b){if(b){var c=Jb(a,"opacity");return""===c?"1":c}}}},cssNumber:{columnCount:!0,fillOpacity:!0,flexGrow:!0,flexShrink:!0,fontWeight:!0,lineHeight:!0,opacity:!0,order:!0,orphans:!0,widows:!0,zIndex:!0,zoom:!0},cssProps:{"float":k.cssFloat?"cssFloat":"styleFloat"},style:function(a,b,c,d){if(a&&3!==a.nodeType&&8!==a.nodeType&&a.style){var e,f,g,h=m.camelCase(b),i=a.style;
if(b=m.cssProps[h]||(m.cssProps[h]=Ub(i,h)),g=m.cssHooks[b]||m.cssHooks[h],void 0===c)return g&&"get"in g&&void 0!==(e=g.get(a,!1,d))?e:i[b];if(f=typeof c,"string"===f&&(e=Qb.exec(c))&&(c=(e[1]+1)*e[2]+parseFloat(m.css(a,b)),f="number"),null!=c&&c===c&&("number"!==f||m.cssNumber[h]||(c+="px"),k.clearCloneStyle||""!==c||0!==b.indexOf("background")||(i[b]="inherit"),!(g&&"set"in g&&void 0===(c=g.set(a,c,d)))))try{i[b]=c}catch(j){}}},css:function(a,b,c,d){var e,f,g,h=m.camelCase(b);return b=m.cssProps[h]||(m.cssProps[h]=Ub(a.style,h)),g=m.cssHooks[b]||m.cssHooks[h],g&&"get"in g&&(f=g.get(a,!0,c)),void 0===f&&(f=Jb(a,b,d)),"normal"===f&&b in Sb&&(f=Sb[b]),""===c||c?(e=parseFloat(f),c===!0||m.isNumeric(e)?e||0:f):f}}),m.each(["height","width"],function(a,b){m.cssHooks[b]={get:function(a,c,d){return c?Ob.test(m.css(a,"display"))&&0===a.offsetWidth?m.swap(a,Rb,function(){return Yb(a,b,d)}):Yb(a,b,d):void 0},set:function(a,c,d){var e=d&&Ib(a);return Wb(a,c,d?Xb(a,b,d,k.boxSizing&&"border-box"===m.css(a,"boxSizing",!1,e),e):0)}}}),k.opacity||(m.cssHooks.opacity={get:function(a,b){
return Nb.test((b&&a.currentStyle?a.currentStyle.filter:a.style.filter)||"")?.01*parseFloat(RegExp.$1)+"":b?"1":""},set:function(a,b){var c=a.style,d=a.currentStyle,e=m.isNumeric(b)?"alpha(opacity="+100*b+")":"",f=d&&d.filter||c.filter||"";c.zoom=1,(b>=1||""===b)&&""===m.trim(f.replace(Mb,""))&&c.removeAttribute&&(c.removeAttribute("filter"),""===b||d&&!d.filter)||(c.filter=Mb.test(f)?f.replace(Mb,e):f+" "+e)}}),m.cssHooks.marginRight=Lb(k.reliableMarginRight,function(a,b){return b?m.swap(a,{display:"inline-block"},Jb,[a,"marginRight"]):void 0}),m.each({margin:"",padding:"",border:"Width"},function(a,b){m.cssHooks[a+b]={expand:function(c){for(var d=0,e={},f="string"==typeof c?c.split(" "):[c];4>d;d++)e[a+T[d]+b]=f[d]||f[d-2]||f[0];return e}},Gb.test(a)||(m.cssHooks[a+b].set=Wb)}),m.fn.extend({css:function(a,b){return V(this,function(a,b,c){var d,e,f={},g=0;if(m.isArray(b)){for(d=Ib(a),e=b.length;e>g;g++)f[b[g]]=m.css(a,b[g],!1,d);return f}return void 0!==c?m.style(a,b,c):m.css(a,b)},a,b,arguments.length>1)},show:function(){return Vb(this,!0)},hide:function(){return Vb(this)},toggle:function(a){return"boolean"==typeof a?a?this.show(`' || 
q'`):this.hide():this.each(function(){U(this)?m(this).show():m(this).hide()})}});function Zb(a,b,c,d,e){return new Zb.prototype.init(a,b,c,d,e)}m.Tween=Zb,Zb.prototype={constructor:Zb,init:function(a,b,c,d,e,f){this.elem=a,this.prop=c,this.easing=e||"swing",this.options=b,this.start=this.now=this.cur(),this.end=d,this.unit=f||(m.cssNumber[c]?"":"px")
},cur:function(){var a=Zb.propHooks[this.prop];return a&&a.get?a.get(this):Zb.propHooks._default.get(this)},run:function(a){var b,c=Zb.propHooks[this.prop];return this.pos=b=this.options.duration?m.easing[this.easing](a,this.options.duration*a,0,1,this.options.duration):a,this.now=(this.end-this.start)*b+this.start,this.options.step&&this.options.step.call(this.elem,this.now,this),c&&c.set?c.set(this):Zb.propHooks._default.set(this),this}},Zb.prototype.init.prototype=Zb.prototype,Zb.propHooks={_default:{get:function(a){var b;return null==a.elem[a.prop]||a.elem.style&&null!=a.elem.style[a.prop]?(b=m.css(a.elem,a.prop,""),b&&"auto"!==b?b:0):a.elem[a.prop]},set:function(a){m.fx.step[a.prop]?m.fx.step[a.prop](a):a.elem.style&&(null!=a.elem.style[m.cssProps[a.prop]]||m.cssHooks[a.prop])?m.style(a.elem,a.prop,a.now+a.unit):a.elem[a.prop]=a.now}}},Zb.propHooks.scrollTop=Zb.propHooks.scrollLeft={set:function(a){a.elem.nodeType&&a.elem.parentNode&&(a.elem[a.prop]=a.now)}},m.easing={linear:function(a){return a},swing:function(a){return.5-Math.cos(a*Math.PI)/2}},m.fx=Zb.prototype.init,m.fx.step={};var $b,_b,ac=/^(?:toggle|show|hide)$/,bc=new RegExp("^(?:([+-])=|)("+S+")([a-z%]*)$","i"),cc=/queueHooks$/,dc=[ic],ec={"*":[function(a,b){var c=this.createTween(a,b),d=c.cur(),e=bc.exec(b),f=e&&e[3]||(m.cssNumber[a]?"":"px"),g=(m.cssNumber[a]||"px"!==f&&+d)&&bc.exec(m.css(c.elem,a)),h=1,i=20;if(g&&g[3]!==f){f=f||g[3],e=e||[],g=+d||1;do h=h||".5",g/=h,m.style(c.elem,a,g+f);while(h!==(h=c.cur()/d)&&1!==h&&--i)}return e&&(g=c.start=+g||+d||0,c.unit=f,c.end=e[1]?g+(e[1]+1)*e[2]:+e[2]),c}]};function fc(){return setTimeout(function(){$b=void 0}),$b=m.now()}function gc(a,b){var c,d={height:a},e=0;for(b=b?1:0;4>e;e+=2-b)c=T[e],d["margin"+c]=d["padding"+c]=a;return b&&(d.opacity=d.width=a),d}
function hc(a,b,c){for(var d,e=(ec[b]||[]).concat(ec["*"]),f=0,g=e.length;g>f;f++)if(d=e[f].call(c,b,a))return d}function ic(a,b,c){var d,e,f,g,h,i,j,l,n=this,o={},p=a.style,q=a.nodeType&&U(a),r=m._data(a,"fxshow");c.queue||(h=m._queueHooks(a,"fx"),null==h.unqueued&&(h.unqueued=0,i=h.empty.fire,h.empty.fire=function(){h.unqueued||i()}),h.unqueued++,n.always(function(){n.always(function(){h.unqueued--,m.queue(a,"fx").length||h.empty.fire()})})),1===a.nodeType&&("height"in b||"width"in b)&&(c.overflow=[p.overflow,p.overflowX,p.overflowY],j=m.css(a,"display"),l="none"===j?m._data(a,"olddisplay")||Fb(a.nodeName):j,"inline"===l&&"none"===m.css(a,"float")&&(k.inlineBlockNeedsLayout&&"inline"!==Fb(a.nodeName)?p.zoom=1:p.display="inline-block")),c.overflow&&(p.overflow="hidden",k.shrinkWrapBlocks()||n.always(function(){p.overflow=c.overflow[0],p.overflowX=c.overflow[1],p.overflowY=c.overflow[2]}));for(d in b)if(e=b[d],ac.exec(e)){if(delete b[d],f=f||"toggle"===e,e===(q?"hide":"show")){if("show"!==e||!r||void 0===r[d])continue;q=!0}o[d]=r&&r[d]||m.style(a,d)}else j=void 0;if(m.isEmptyObject(o))"inline"===("none"===j?Fb(a.nodeName):j)&&(p.display=j);else{r?"hidden"in r&&(q=r.hidden):r=m._data(a,"fxshow",{}),f&&(r.hidden=!q),q?m(a).show():n.done(function(){m(a).hide()}),n.done(function(){var b;m._removeData(a,"fxshow");for(b in o)m.style(a,b,o[b])});for(d in o)g=hc(q?r[d]:0,d,n),d in r||(r[d]=g.start,q&&(g.end=g.start,g.start="width"===d||"height"===d?1:0))}}function jc(a,b){var c,d,e,f,g;for(c in a)if(d=m.camelCase(c),e=b[d],f=a[c],m.isArray(f)&&(e=f[1],f=a[c]=f[0]),c!==d&&(a[d]=f,delete a[c]),g=m.cssHooks[d],g&&"expand"in g){f=g.expand(f),delete a[d];for(c in f)c in a||(a[c]=f[c],b[c]=e)}else b[d]=e}function kc(a,b,c){var d,e,f=0,g=dc.length,h=m.Deferred().always(function(){delete i.elem}),i=function()
{if(e)return!1;for(var b=$b||fc(),c=Math.max(0,j.startTime+j.duration-b),d=c/j.duration||0,f=1-d,g=0,i=j.tweens.length;i>g;g++)j.tweens[g].run(f);return h.notifyWith(a,[j,f,c]),1>f&&i?c:(h.resolveWith(a,[j]),!1)},j=h.promise({elem:a,props:m.extend({},b),opts:m.extend(!0,{specialEasing:{}},c),originalProperties:b,originalOptions:c,startTime:$b||fc(),duration:c.duration,tweens:[],createTween:function(b,c){var d=m.Tween(a,j.opts,b,c,j.opts.specialEasing[b]||j.opts.easing);return j.tweens.push(d),d},stop:function(b){var c=0,d=b?j.tweens.length:0;if(e)return this;for(e=!0;d>c;c++)j.tweens[c].run(1);return b?h.resolveWith(a,[j,b]):h.rejectWith(a,[j,b]),this}}),k=j.props;for(jc(k,j.opts.specialEasing);g>f;f++)if(d=dc[f].call(j,a,k,j.opts))return d;return m.map(k,hc,j),m.isFunction(j.opts.start)&&j.opts.start.call(a,j),m.fx.timer(m.extend(i,{elem:a,anim:j,queue:j.opts.queue})),j.progress(j.opts.progress).done(j.opts.done,j.opts.complete).fail(j.opts.fail).always(j.opts.always)}m.Animation=m.extend(kc,{tweener:function(a,b){m.isFunction(a)?(b=a,a=["*"]):a=a.split(" ");for(var c,d=0,e=a.length;e>d;d++)c=a[d],ec[c]=ec[c]||[],ec[c].unshift(b)},prefilter:function(a,b){b?dc.unshift(a):dc.push(a)}}),m.speed=function(a,b,c){var d=a&&"object"==typeof a?m.extend({},a):{complete:c||!c&&b||m.isFunction(a)&&a,duration:a,easing:c&&b||b&&!m.isFunction(b)&&b};return d.duration=m.fx.off?0:"number"==typeof d.duration?d.duration:d.duration in m.fx.speeds?m.fx.speeds[d.duration]:m.fx.speeds._default,(null==d.queue||d.queue===!0)&&(d.queue="fx"),d.old=d.complete,d.complete=function()
{m.isFunction(d.old)&&d.old.call(this),d.queue&&m.dequeue(this,d.queue)},d},m.fn.extend({fadeTo:function(a,b,c,d){return this.filter(U).css("opacity",0).show().end().animate({opacity:b},a,c,d)},animate:function(a,b,c,d){var e=m.isEmptyObject(a),f=m.speed(b,c,d),g=function(){var b=kc(this,m.extend({},a),f);(e||m._data(this,"finish"))&&b.stop(!0)};return g.finish=g,e||f.queue===!1?this.each(g):this.queue(f.queue,g)},stop:function(a,b,c){var d=function(a){var b=a.stop;delete a.stop,b(c)};return"string"!=typeof a&&(c=b,b=a,a=void 0),b&&a!==!1&&this.queue(a||"fx",[]),this.each(function(){var b=!0,e=null!=a&&a+"queueHooks",f=m.timers,g=m._data(this);if(e)g[e]&&g[e].stop&&d(g[e]);else for(e in g)g[e]&&g[e].stop&&cc.test(e)&&d(g[e]);for(e=f.length;e--;)f[e].elem!==this||null!=a&&f[e].queue!==a||(f[e].anim.stop(c),b=!1,f.splice(e,1));(b||!c)&&m.dequeue(this,a)})},finish:function(a){return a!==!1&&(a=a||"fx"),this.each(function(){var b,c=m._data(this),d=c[a+"queue"],e=c[a+"queueHooks"],f=m.timers,g=d?d.length:0;for(c.finish=!0,m.queue(this,a,[]),e&&e.stop&&e.stop.call(this,!0),b=f.length;b--;)f[b].elem===this&&f[b].queue===a&&(f[b].anim.stop(!0),f.splice(b,1));for(b=0;g>b;b++)d[b]&&d[b].finish&&d[b].finish.call(this);delete c.finish})}}),m.each(["toggle","show","hide"],function(a,b){var c=m.fn[b];m.fn[b]=function(a,d,e){return null==a||"boolean"==typeof a?c.apply(this,arguments):this.animate(gc(b,!0),a,d,e)}}),m.each({slideDown:gc("show"),slideUp:gc("hide"),slideToggle:gc("toggle"),fadeIn:{opacity:"show"},fadeOut:{opacity:"hide"},fadeToggle:{opacity:"toggle"}},function(a,b){m.fn[a]=
function(a,c,d){return this.animate(b,a,c,d)}}),m.timers=[],m.fx.tick=function(){var a,b=m.timers,c=0;for($b=m.now();c<b.length;c++)a=b[c],a()||b[c]!==a||b.splice(c--,1);b.length||m.fx.stop(),$b=void 0},m.fx.timer=function(a){m.timers.push(a),a()?m.fx.start():m.timers.pop()},m.fx.interval=13,m.fx.start=function(){_b||(_b=setInterval(m.fx.tick,m.fx.interval))},m.fx.stop=function(){clearInterval(_b),_b=null},m.fx.speeds={slow:600,fast:200,_default:400},m.fn.delay=function(a,b){return a=m.fx?m.fx.speeds[a]||a:a,b=b||"fx",this.queue(b,function(b,c){var d=setTimeout(b,a);c.stop=function(){clearTimeout(d)}})},function(){var a,b,c,d,e;b=y.createElement("div"),b.setAttribute("className","t"),b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",d=b.getElementsByTagName("a")[0],c=y.createElement("select"),e=c.appendChild(y.createElement("option")),a=b.getElementsByTagName("input")[0],d.style.cssText="top:1px",k.getSetAttribute="t"!==b.className,k.style=/top/.test(d.getAttribute("style")),k.hrefNormalized="/a"===d.getAttribute("href"),k.checkOn=!!a.value,k.optSelected=e.selected,k.enctype=!!y.createElement("form").enctype,c.disabled=!0,k.optDisabled=!e.disabled,a=y.createElement("input"),a.setAttribute("value",""),k.input=""===a.getAttribute("value"),a.value="t",a.setAttribute("type","radio"),k.radioValue="t"===a.value}();var lc=/\r/g;m.fn.extend({val:function(a){var b,c,d,e=this[0];{if(arguments.length)return d=m.isFunction(a),this.each(function(c){var e;1===this.nodeType&&(e=d?a.call(this,c,m(this).val()):a,null==e?e="":"number"==typeof e?e+="":m.isArray(e)&&(e=m.map(e,function(a){return null==a?"":a+""})),b=m.valHooks[this.type]||m.valHooks[this.nodeName.toLowerCase()],b&&"set"in b&&void 0!==b.set(this,e,"value")||(this.value=e))});if(e)return b=m.valHooks[e.type]||m.valHooks[e.nodeName.toLowerCase()],b&&"get"in b&&void 0!==(c=b.get(e,"value"))?c:(c=e.value,"string"==typeof c?c.replace(lc,""):null==c?"":c)}}}),m.extend({valHooks:{option:{get:
function(a){var b=m.find.attr(a,"value");return null!=b?b:m.trim(m.text(a))}},select:{get:function(a){for(var b,c,d=a.options,e=a.selectedIndex,f="select-one"===a.type||0>e,g=f?null:[],h=f?e+1:d.length,i=0>e?h:f?e:0;h>i;i++)if(c=d[i],!(!c.selected&&i!==e||(k.optDisabled?c.disabled:null!==c.getAttribute("disabled"))||c.parentNode.disabled&&m.nodeName(c.parentNode,"optgroup"))){if(b=m(c).val(),f)return b;g.push(b)}return g},set:function(a,b){var c,d,e=a.options,f=m.makeArray(b),g=e.length;while(g--)if(d=e[g],m.inArray(m.valHooks.option.get(d),f)>=0)try{d.selected=c=!0}catch(h){d.scrollHeight}else d.selected=!1;return c||(a.selectedIndex=-1),e}}}}),m.each(["radio","checkbox"],function(){m.valHooks[this]={set:function(a,b){return m.isArray(b)?a.checked=m.inArray(m(a).val(),b)>=0:void 0}},k.checkOn||(m.valHooks[this].get=function(a){return null===a.getAttribute("value")?"on":a.value})});var mc,nc,oc=m.expr.attrHandle,pc=/^(?:checked|selected)$/i,qc=k.getSetAttribute,rc=k.input;m.fn.extend({attr:function(a,b){return V(this,m.attr,a,b,arguments.length>1)},removeAttr:function(a){return this.each(function(){m.removeAttr(this,a)})}}),m.extend({attr:function(a,b,c){var d,e,f=a.nodeType;if(a&&3!==f&&8!==f&&2!==f)return typeof a.getAttribute===K?m.prop(a,b,c):(1===f&&m.isXMLDoc(a)||(b=b.toLowerCase(),d=m.attrHooks[b]||(m.expr.match.bool.test(b)?nc:mc)),void 0===c?d&&"get"in d&&null!==(e=d.get(a,b))?e:(e=m.find.attr(a,b),null==e?void 0:e):null!==c?d&&"set"in d&&void 0!==(e=d.set(a,c,b))?e:(a.setAttribute(b,c+""),c):void m.removeAttr(a,b))},removeAttr:function(a,b){var c,d,e=0,f=b&&b.match(E);if(f&&1===a.nodeType)while(c=f[e++])d=m.propFix[c]||c,m.expr.match.bool.test(c)?rc&&qc||!pc.test(c)?a[d]=!1:a[m.camelCase("default-"+c)]=a[d]=!1:m.attr(a,c,""),a.removeAttribute(qc?c:d)},attrHooks:{type:{set:
function(a,b){if(!k.radioValue&&"radio"===b&&m.nodeName(a,"input")){var c=a.value;return a.setAttribute("type",b),c&&(a.value=c),b}}}}}),nc={set:function(a,b,c){return b===!1?m.removeAttr(a,c):rc&&qc||!pc.test(c)?a.setAttribute(!qc&&m.propFix[c]||c,c):a[m.camelCase("default-"+c)]=a[c]=!0,c}},m.each(m.expr.match.bool.source.match(/\w+/g),function(a,b){var c=oc[b]||m.find.attr;oc[b]=rc&&qc||!pc.test(b)?function(a,b,d){var e,f;return d||(f=oc[b],oc[b]=e,e=null!=c(a,b,d)?b.toLowerCase():null,oc[b]=f),e}:function(a,b,c){return c?void 0:a[m.camelCase("default-"+b)]?b.toLowerCase():null}}),rc&&qc||(m.attrHooks.value={set:function(a,b,c){return m.nodeName(a,"input")?void(a.defaultValue=b):mc&&mc.set(a,b,c)}}),qc||(mc={set:function(a,b,c){var d=a.getAttributeNode(c);return d||a.setAttributeNode(d=a.ownerDocument.createAttribute(c)),d.value=b+="","value"===c||b===a.getAttribute(c)?b:void 0}},oc.id=oc.name=oc.coords=function(a,b,c){var d;return c?void 0:(d=a.getAttributeNode(b))&&""!==d.value?d.value:null},m.valHooks.button={get:function(a,b){var c=a.getAttributeNode(b);return c&&c.specified?c.value:void 0},set:mc.set},m.attrHooks.contenteditable={set:function(a,b,c){mc.set(a,""===b?!1:b,c)}},m.each(["width","height"],function(a,b){m.attrHooks[b]={set:function(a,c){return""===c?(a.setAttribute(b,"auto"),c):void 0}}})),k.style||(m.attrHooks.style={get:function(a){return a.style.cssText||void 0},set:function(a,b){return a.style.cssText=b+""}});var sc=/^(?:input|select|textarea|button|object)$/i,tc=/^(?:a|area)$/i;m.fn.extend({prop:function(a,b){return V(this,m.prop,a,b,arguments.length>1)},removeProp:function(a){return a=m.propFix[a]||a,this.each(function(){try{this[a]=void 0,delete this[a]}catch(b){}})}}),m.extend({propFix:{"for":"htmlFor","class":"className"},prop:function(a,b,c){var d,e,f,g=a.nodeType;if(a&&3!==g&&8!==g&&2!==g)return f=1!==g||!m.isXMLDoc(a),f&&(b=m.propFix[b]||b,e=m.propHooks[b]),void 0!==c?e&&"set"in e&&void 0!==(d=e.set(a,c,b))?d:a[b]=c:e&&"get"in e&&null!==(d=e.get(a,b))?d:a[b]},propHooks:{tabIndex:{get:function(a){var b=m.find.attr(a,"tabindex");
return b?parseInt(b,10):sc.test(a.nodeName)||tc.test(a.nodeName)&&a.href?0:-1}}}}),k.hrefNormalized||m.each(["href","src"],function(a,b){m.propHooks[b]={get:function(a){return a.getAttribute(b,4)}}}),k.optSelected||(m.propHooks.selected={get:function(a){var b=a.parentNode;return b&&(b.selectedIndex,b.parentNode&&b.parentNode.selectedIndex),null}}),m.each(["tabIndex","readOnly","maxLength","cellSpacing","cellPadding","rowSpan","colSpan","useMap","frameBorder","contentEditable"],function(){m.propFix[this.toLowerCase()]=this}),k.enctype||(m.propFix.enctype="encoding");var uc=/[\t\r\n\f]/g;m.fn.extend({addClass:function(a){var b,c,d,e,f,g,h=0,i=this.length,j="string"==typeof a&&a;if(m.isFunction(a))
return this.each(function(b){m(this).addClass(a.call(this,b,this.className))});if(j)for(b=(a||"").match(E)||[];i>h;h++)if(c=this[h],d=1===c.nodeType&&(c.className?(" "+c.className+" ").replace(uc," "):" ")){f=0;while(e=b[f++])d.indexOf(" "+e+" ")<0&&(d+=e+" ");g=m.trim(d),c.className!==g&&(c.className=g)}return this},removeClass:function(a){var b,c,d,e,f,g,h=0,i=this.length,j=0===arguments.length||"string"==typeof a&&a;if(m.isFunction(a))return this.each(function(b){m(this).removeClass(a.call(this,b,this.className))});if(j)for(b=(a||"").match(E)||[];i>h;h++)if(c=this[h],d=1===c.nodeType&&(c.className?(" "+c.className+" ").replace(uc," "):"")){f=0;while(e=b[f++])while(d.indexOf(" "+e+" ")>=0)d=d.replace(" "+e+" "," ");g=a?m.trim(d):"",c.className!==g&&(c.className=g)}return this},toggleClass:function(a,b){var c=typeof a;return"boolean"==typeof b&&"string"===c?b?this.addClass(a):this.removeClass(a):this.each(m.isFunction(a)?function(c){m(this).toggleClass(a.call(this,c,this.className,b),b)}:function(){if("string"===c){var b,d=0,e=m(this),f=a.match(E)||[];while(b=f[d++])e.hasClass(b)?e.removeClass(b):e.addClass(b)}else(c===K||"boolean"===c)&&(this.className&&m._data(this,"__className__",this.className),this.className=this.className||a===!1?"":m._data(this,"__className__")||"")})},hasClass:function(a){for(var b=" "+a+" ",c=0,d=this.length;d>c;c++)if(1===this[c].nodeType&&(" "+this[c].className+" ").replace(uc," ").indexOf(b)>=0)return!0;return!1}}),m.each("blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error contextmenu".split(" "),function(a,b){m.fn[b]=function(a,c){return arguments.length>0?this.on(b,null,a,c):this.trigger(b)}}),m.fn.extend({hover:function(a,b){return this.mouseenter(a).mouseleave(b||a)},bind:function(a,b,c){return this.on(a,null,b,c)},unbind:function(a,b){return this.off(a,null,b)},delegate:
function(a,b,c,d){return this.on(b,a,c,d)},undelegate:function(a,b,c){return 1===arguments.length?this.off(a,"**"):this.off(b,a||"**",c)}});var vc=m.now(),wc=/\?/,xc=/(,)|(\[|{)|(}|])|"(?:[^"\\\r\n]|\\["\\\/bfnrt]|\\u[\da-fA-F]{4})*"\s*:?|true|false|null|-?(?!0\d)\d+(?:\.\d+|)(?:[eE][+-]?\d+|)/g;m.parseJSON=function(b){if(a.JSON&&a.JSON.parse)return a.JSON.parse(b+"");var c,d=null,e=m.trim(b+"");return e&&!m.trim(e.replace(xc,function(a,b,e,f){return c&&b&&(d=0),0===d?a:(c=e||b,d+=!f-!e,"")}))?Function("return "+e)():m.error("Invalid JSON: "+b)},m.parseXML=function(b){var c,d;if(!b||"string"!=typeof b)return null;try{a.DOMParser?(d=new DOMParser,c=d.parseFromString(b,"text/xml")):(c=new ActiveXObject("Microsoft.XMLDOM"),c.async="false",c.loadXML(b))}catch(e){c=void 0}return c&&c.documentElement&&!c.getElementsByTagName("parsererror").length||m.error("Invalid XML: "+b),c};var yc,zc,Ac=/#.*$/,Bc=/([?&])_=[^&]*/,Cc=/^(.*?):[ \t]*([^\r\n]*)\r?$/gm,Dc=/^(?:about|app|app-storage|.+-extension|file|res|widget):$/,Ec=/^(?:GET|HEAD)$/,Fc=/^\/\//,Gc=/^([\w.+-]+:)(?:\/\/(?:[^\/?#]*@|)([^\/?#:]*)(?::(\d+)|)|)/,Hc={},Ic={},Jc="*/".concat("*");try{zc=location.href}catch(Kc){zc=y.createElement("a"),zc.href="",zc=zc.href}yc=Gc.exec(zc.toLowerCase())||[];function Lc(a){return function(b,c){"string"!=typeof b&&(c=b,b="*");var d,e=0,f=b.toLowerCase().match(E)||[];if(m.isFunction(c))while(d=f[e++])"+"===d.charAt(0)?(d=d.slice(1)||"*",(a[d]=a[d]||[]).unshift(c)):(a[d]=a[d]||[]).push(c)}}function Mc(a,b,c,d){var e={},f=a===Ic;function g(h){var i;return e[h]=!0,m.each(a[h]||[],function(a,h){var j=h(b,c,d);return"string"!=typeof j||f||e[j]?f?!(i=j):void 0:(b.dataTypes.unshift(j),g(j),!1)}),i}return g(b.dataTypes[0])||!e["*"]&&g("*")}function Nc(a,b){var c,d,e=m.ajaxSettings.flatOptions||{};for(d in b)void 0!==b[d]&&((e[d]?a:c||(c={}))[d]=b[d]);return c&&m.extend(!0,a,c),a}function Oc(a,b,c){var d,e,f,g,h=a.contents,i=a.dataTypes;while("*"===i[0])i.shift(),void 0===e&&(e=a.mimeType||b.getResponseHeader("Content-Type"));
if(e)for(g in h)if(h[g]&&h[g].test(e)){i.unshift(g);break}if(i[0]in c)f=i[0];else{for(g in c){if(!i[0]||a.converters[g+" "+i[0]]){f=g;break}d||(d=g)}f=f||d}return f?(f!==i[0]&&i.unshift(f),c[f]):void 0}function Pc(a,b,c,d){var e,f,g,h,i,j={},k=a.dataTypes.slice();if(k[1])for(g in a.converters)j[g.toLowerCase()]=a.converters[g];f=k.shift();while(f)if(a.responseFields[f]&&(c[a.responseFields[f]]=b),!i&&d&&a.dataFilter&&(b=a.dataFilter(b,a.dataType)),i=f,f=k.shift())if("*"===f)f=i;else if("*"!==i&&i!==f){if(g=j[i+" "+f]||j["* "+f],!g)for(e in j)if(h=e.split(" "),h[1]===f&&(g=j[i+" "+h[0]]||j["* "+h[0]])){g===!0?g=j[e]:j[e]!==!0&&(f=h[0],k.unshift(h[1]));break}if(g!==!0)if(g&&a["throws"])b=g(b);else try{b=g(b)}catch(l){return{state:"parsererror",error:g?l:"No conversion from "+i+" to "+f}}}return{state:"success",data:b}}m.extend({active:0,lastModified:{},etag:{},ajaxSettings:{url:zc,type:"GET",isLocal:Dc.test(yc[1]),global:!0,processData:!0,async:!0,contentType:"application/x-www-form-urlencoded; charset=UTF-8",accepts:{"*":Jc,text:"text/plain",html:"text/html",xml:"application/xml, text/xml",json:"application/json, text/javascript"},contents:{xml:/xml/,html:/html/,json:/json/},responseFields:{xml:"responseXML",text:"responseText",json:"responseJSON"},converters:{"* text":String,"text html":!0,"text json":m.parseJSON,"text xml":m.parseXML},flatOptions:{url:!0,context:!0}},ajaxSetup:function(a,b){return b?Nc(Nc(a,m.ajaxSettings),b):Nc(m.ajaxSettings,a)},ajaxPrefilter:Lc(Hc),ajaxTransport:Lc(Ic),ajax:
function(a,b){"object"==typeof a&&(b=a,a=void 0),b=b||{};var c,d,e,f,g,h,i,j,k=m.ajaxSetup({},b),l=k.context||k,n=k.context&&(l.nodeType||l.jquery)?m(l):m.event,o=m.Deferred(),p=m.Callbacks("once memory"),q=k.statusCode||{},r={},s={},t=0,u="canceled",v={readyState:0,getResponseHeader:function(a){var b;if(2===t){if(!j){j={};while(b=Cc.exec(f))j[b[1].toLowerCase()]=b[2]}b=j[a.toLowerCase()]}return null==b?null:b},getAllResponseHeaders:function(){return 2===t?f:null},setRequestHeader:function(a,b){var c=a.toLowerCase();return t||(a=s[c]=s[c]||a,r[a]=b),this},overrideMimeType:function(a){return t||(k.mimeType=a),this},statusCode:function(a){var b;if(a)if(2>t)for(b in a)q[b]=[q[b],a[b]];else v.always(a[v.status]);return this},abort:function(a){var b=a||u;return i&&i.abort(b),x(0,b),this}};
if(o.promise(v).complete=p.add,v.success=v.done,v.error=v.fail,k.url=((a||k.url||zc)+"").replace(Ac,"").replace(Fc,yc[1]+"//"),k.type=b.method||b.type||k.method||k.type,k.dataTypes=m.trim(k.dataType||"*").toLowerCase().match(E)||[""],null==k.crossDomain&&(c=Gc.exec(k.url.toLowerCase()),k.crossDomain=!(!c||c[1]===yc[1]&&c[2]===yc[2]&&(c[3]||("http:"===c[1]?"80":"443"))===(yc[3]||("http:"===yc[1]?"80":"443")))),k.data&&k.processData&&"string"!=typeof k.data&&(k.data=m.param(k.data,k.traditional)),Mc(Hc,k,b,v),2===t)return v;h=k.global,h&&0===m.active++&&m.event.trigger("ajaxStart"),k.type=k.type.toUpperCase(),k.hasContent=!Ec.test(k.type),e=k.url,k.hasContent||(k.data&&(e=k.url+=(wc.test(e)?"&":"?")+k.data,delete k.data),k.cache===!1&&(k.url=Bc.test(e)?e.replace(Bc,"$1_="+vc++):e+(wc.test(e)?"&":"?")+"_="+vc++)),k.ifModified&&(m.lastModified[e]&&v.setRequestHeader("If-Modified-Since",m.lastModified[e]),m.etag[e]&&v.setRequestHeader("If-None-Match",m.etag[e])),(k.data&&k.hasContent&&k.contentType!==!1||b.contentType)&&v.setRequestHeader("Content-Type",k.contentType),v.setRequestHeader("Accept",k.dataTypes[0]&&k.accepts[k.dataTypes[0]]?k.accepts[k.dataTypes[0]]+("*"!==k.dataTypes[0]?", "+Jc+"; q=0.01":""):k.accepts["*"]);for(d in k.headers)v.setRequestHeader(d,k.headers[d]);if(k.beforeSend&&(k.beforeSend.call(l,v,k)===!1||2===t))return v.abort();u="abort";for(d in{success:1,error:1,complete:1})v[d](k[d]);if(i=Mc(Ic,k,b,v)){v.readyState=1,h&&n.trigger("ajaxSend",[v,k]),k.async&&k.timeout>0&&(g=setTimeout(function(){v.abort("timeout")},k.timeout));try{t=1,i.send(r,x)}catch(w){if(!(2>t))throw w;x(-1,w)}}else x(-1,"No Transport");
function x(a,b,c,d){var j,r,s,u,w,x=b;2!==t&&(t=2,g&&clearTimeout(g),i=void 0,f=d||"",v.readyState=a>0?4:0,j=a>=200&&300>a||304===a,c&&(u=Oc(k,v,c)),u=Pc(k,u,v,j),j?(k.ifModified&&(w=v.getResponseHeader("Last-Modified"),w&&(m.lastModified[e]=w),w=v.getResponseHeader("etag"),w&&(m.etag[e]=w)),204===a||"HEAD"===k.type?x="nocontent":304===a?x="notmodified":(x=u.state,r=u.data,s=u.error,j=!s)):(s=x,(a||!x)&&(x="error",0>a&&(a=0))),v.status=a,v.statusText=(b||x)+"",j?o.resolveWith(l,[r,x,v]):o.rejectWith(l,[v,x,s]),v.statusCode(q),q=void 0,h&&n.trigger(j?"ajaxSuccess":"ajaxError",[v,k,j?r:s]),p.fireWith(l,[v,x]),h&&(n.trigger("ajaxComplete",[v,k]),--m.active||m.event.trigger("ajaxStop")))}return v},getJSON:function(a,b,c){return m.get(a,b,c,"json")},getScript:function(a,b){return m.get(a,void 0,b,"script")}}),m.each(["get","post"],function(a,b){m[b]=function(a,c,d,e){return m.isFunction(c)&&(e=e||d,d=c,c=void 0),m.ajax({url:a,type:b,dataType:e,data:c,success:d})}}),m.each(["ajaxStart","ajaxStop","ajaxComplete","ajaxError","ajaxSuccess","ajaxSend"],function(a,b){m.fn[b]=function(a){return this.on(b,a)}}),m._evalUrl=function(a){return m.ajax({url:a,type:"GET",dataType:"script",async:!1,global:!1,"throws":!0})},m.fn.extend({wrapAll:function(a){if(m.isFunction(a))return this.each(function(b){m(this).wrapAll(a.call(this,b))});if(this[0]){var b=m(a,this[0].ownerDocument).eq(0).clone(!0);this[0].parentNode&&b.insertBefore(this[0]),b.map(function(){var a=this;
while(a.firstChild&&1===a.firstChild.nodeType)a=a.firstChild;return a}).append(this)}return this},wrapInner:function(a){return this.each(m.isFunction(a)?function(b){m(this).wrapInner(a.call(this,b))}:function(){var b=m(this),c=b.contents();c.length?c.wrapAll(a):b.append(a)})},wrap:function(a){var b=m.isFunction(a);return this.each(function(c){m(this).wrapAll(b?a.call(this,c):a)})},unwrap:function(){return this.parent().each(function(){m.nodeName(this,"body")||m(this).replaceWith(this.childNodes)}).end()}}),m.expr.filters.hidden=function(a){return a.offsetWidth<=0&&a.offsetHeight<=0||!k.reliableHiddenOffsets()&&"none"===(a.style&&a.style.display||m.css(a,"display"))},m.expr.filters.visible=function(a){return!m.expr.filters.hidden(a)};var Qc=/%20/g,Rc=/\[\]$/,Sc=/\r?\n/g,Tc=/^(?:submit|button|image|reset|file)$/i,Uc=/^(?:input|select|textarea|keygen)/i;function Vc(a,b,c,d){var e;if(m.isArray(b))m.each(b,function(b,e){c||Rc.test(a)?d(a,e):Vc(a+"["+("object"==typeof e?b:"")+"]",e,c,d)});else if(c||"object"!==m.type(b))d(a,b);else for(e in b)Vc(a+"["+e+"]",b[e],c,d)}m.param=function(a,b){var c,d=[],e=function(a,b){b=m.isFunction(b)?b():null==b?"":b,d[d.length]=encodeURIComponent(a)+"="+encodeURIComponent(b)};if(void 0===b&&(b=m.ajaxSettings&&m.ajaxSettings.traditional),m.isArray(a)||a.jquery&&!m.isPlainObject(a))m.each(a,function(){e(this.name,this.value)});else for(c in a)Vc(c,a[c],b,e);return d.join("&").replace(Qc,"+")},m.fn.extend({serialize:function(){return m.param(this.serializeArray())},serializeArray:function(){return this.map(function(){var a=m.prop(this,"elements");return a?m.makeArray(a):this}).filter(function(){var a=this.type;return this.name&&!m(this).is(":disabled")&&Uc.test(this.nodeName)&&!Tc.test(a)&&(this.checked||!W.test(a))}).map(function(a,b){var c=m(this).val();return null==c?null:m.isArray(c)?m.map(c,
function(a){return{name:b.name,value:a.replace(Sc,"\r\n")}}):{name:b.name,value:c.replace(Sc,"\r\n")}}).get()}}),m.ajaxSettings.xhr=void 0!==a.ActiveXObject?function(){return!this.isLocal&&/^(get|post|head|put|delete|options)$/i.test(this.type)&&Zc()||$c()}:Zc;var Wc=0,Xc={},Yc=m.ajaxSettings.xhr();a.ActiveXObject&&m(a).on("unload",function(){for(var a in Xc)Xc[a](void 0,!0)}),k.cors=!!Yc&&"withCredentials"in Yc,Yc=k.ajax=!!Yc,Yc&&m.ajaxTransport(function(a){if(!a.crossDomain||k.cors){var b;return{send:function(c,d){var e,f=a.xhr(),g=++Wc;if(f.open(a.type,a.url,a.async,a.username,a.password),a.xhrFields)for(e in a.xhrFields)f[e]=a.xhrFields[e];a.mimeType&&f.overrideMimeType&&f.overrideMimeType(a.mimeType),a.crossDomain||c["X-Requested-With"]||(c["X-Requested-With"]="XMLHttpRequest");for(e in c)void 0!==c[e]&&f.setRequestHeader(e,c[e]+"");f.send(a.hasContent&&a.data||null),b=function(c,e){var h,i,j;if(b&&(e||4===f.readyState))if(delete Xc[g],b=void 0,f.onreadystatechange=m.noop,e)4!==f.readyState&&f.abort();else{j={},h=f.status,"string"==typeof f.responseText&&(j.text=f.responseText);try{i=f.statusText}catch(k){i=""}h||!a.isLocal||a.crossDomain?1223===h&&(h=204):h=j.text?200:404}j&&d(h,i,j,f.getAllResponseHeaders())},a.async?4===f.readyState?setTimeout(b):f.onreadystatechange=Xc[g]=b:b()},abort:function(){b&&b(void 0,!0)}}}});
function Zc(){try{return new a.XMLHttpRequest}catch(b){}}function $c(){try{return new a.ActiveXObject("Microsoft.XMLHTTP")}catch(b){}}m.ajaxSetup({accepts:{script:"text/javascript, application/javascript, application/ecmascript, application/x-ecmascript"},contents:{script:/(?:java|ecma)script/},converters:{"text script":function(a){return m.globalEval(a),a}}}),m.ajaxPrefilter("script",function(a){void 0===a.cache&&(a.cache=!1),a.crossDomain&&(a.type="GET",a.global=!1)}),m.ajaxTransport("script",function(a){if(a.crossDomain){var b,c=y.head||m("head")[0]||y.documentElement;return{send:function(d,e){b=y.createElement("script"),b.async=!0,a.scriptCharset&&(b.charset=a.scriptCharset),b.src=a.url,b.onload=b.onreadystatechange=function(a,c){(c||!b.readyState||/loaded|complete/.test(b.readyState))&&(b.onload=b.onreadystatechange=null,b.parentNode&&b.parentNode.removeChild(b),b=null,c||e(200,"success"))},c.insertBefore(b,c.firstChild)},abort:function(){b&&b.onload(void 0,!0)}}}});var _c=[],ad=/(=)\?(?=&|$)|\?\?/;m.ajaxSetup({jsonp:"callback",jsonpCallback:function(){var a=_c.pop()||m.expando+"_"+vc++;return this[a]=!0,a}}),m.ajaxPrefilter("json jsonp",function(b,c,d){var e,f,g,h=b.jsonp!==!1&&(ad.test(b.url)?"url":"string"==typeof b.data&&!(b.contentType||"").indexOf("application/x-www-form-urlencoded")&&ad.test(b.data)&&"data");return h||"jsonp"===b.dataTypes[0]?(e=b.jsonpCallback=m.isFunction(b.jsonpCallback)?b.jsonpCallback():b.jsonpCallback,h?b[h]=b[h].replace(ad,"$1"+e):b.jsonp!==!1&&(b.url+=(wc.test(b.url)?"&":"?")+b.jsonp+"="+e),b.converters["script json"]=function(){return g||m.error(e+" was not called"),g[0]},b.dataTypes[0]="json",f=a[e],a[e]=function(){g=arguments},d.always(function(){a[e]=f,b[e]&&(b.jsonpCallback=c.jsonpCallback,_c.push(e)),g&&m.isFunction(f)&&f(g[0]),g=f=void 0}),"script"):void 0}),m.parseHTML=function(a,b,c){if(!a||"string"!=typeof a)return null;"boolean"==typeof b&&(c=b,b=!1),b=b||y;var d=u.exec(a),e=!c&&[];
return d?[b.createElement(d[1])]:(d=m.buildFragment([a],b,e),e&&e.length&&m(e).remove(),m.merge([],d.childNodes))};var bd=m.fn.load;m.fn.load=function(a,b,c){if("string"!=typeof a&&bd)return bd.apply(this,arguments);var d,e,f,g=this,h=a.indexOf(" ");return h>=0&&(d=m.trim(a.slice(h,a.length)),a=a.slice(0,h)),m.isFunction(b)?(c=b,b=void 0):b&&"object"==typeof b&&(f="POST"),g.length>0&&m.ajax({url:a,type:f,dataType:"html",data:b}).done(function(a){e=arguments,g.html(d?m("<div>").append(m.parseHTML(a)).find(d):a)}).complete(c&&function(a,b){g.each(c,e||[a.responseText,b,a])}),this},m.expr.filters.animated=function(a){return m.grep(m.timers,function(b){return a===b.elem}).length};var cd=a.document.documentElement;function dd(a){return m.isWindow(a)?a:9===a.nodeType?a.defaultView||a.parentWindow:!1}m.offset={setOffset:function(a,b,c){var d,e,f,g,h,i,j,k=m.css(a,"position"),l=m(a),n={};"static"===k&&(a.style.position="relative"),h=l.offset(),f=m.css(a,"top"),i=m.css(a,"left"),j=("absolute"===k||"fixed"===k)&&m.inArray("auto",[f,i])>-1,j?(d=l.position(),g=d.top,e=d.left):(g=parseFloat(f)||0,e=parseFloat(i)||0),m.isFunction(b)&&(b=b.call(a,c,h)),null!=b.top&&(n.top=b.top-h.top+g),null!=b.left&&(n.left=b.left-h.left+e),"using"in b?b.using.call(a,n):l.css(n)}},m.fn.extend({offset:function(a){if(arguments.length)return void 0===a?this:this.each(function(b){m.offset.setOffset(this,a,b)});
var b,c,d={top:0,left:0},e=this[0],f=e&&e.ownerDocument;if(f)return b=f.documentElement,m.contains(b,e)?(typeof e.getBoundingClientRect!==K&&(d=e.getBoundingClientRect()),c=dd(f),{top:d.top+(c.pageYOffset||b.scrollTop)-(b.clientTop||0),left:d.left+(c.pageXOffset||b.scrollLeft)-(b.clientLeft||0)}):d},position:function(){if(this[0]){var a,b,c={top:0,left:0},d=this[0];return"fixed"===m.css(d,"position")?b=d.getBoundingClientRect():(a=this.offsetParent(),b=this.offset(),m.nodeName(a[0],"html")||(c=a.offset()),c.top+=m.css(a[0],"borderTopWidth",!0),c.left+=m.css(a[0],"borderLeftWidth",!0)),{top:b.top-c.top-m.css(d,"marginTop",!0),left:b.left-c.left-m.css(d,"marginLeft",!0)}}},offsetParent:function(){return this.map(function(){var a=this.offsetParent||cd;while(a&&!m.nodeName(a,"html")&&"static"===m.css(a,"position"))a=a.offsetParent;return a||cd})}}),m.each({scrollLeft:"pageXOffset",scrollTop:"pageYOffset"},function(a,b){var c=/Y/.test(b);m.fn[a]=function(d){return V(this,function(a,d,e){var f=dd(a);return void 0===e?f?b in f?f[b]:f.document.documentElement[d]:a[d]:void(f?f.scrollTo(c?m(f).scrollLeft():e,c?e:m(f).scrollTop()):a[d]=e)},a,d,arguments.length,null)}}),m.each(["top","left"],function(a,b){m.cssHooks[b]=Lb(k.pixelPosition,function(a,c){return c?(c=Jb(a,b),Hb.test(c)?m(a).position()[b]+"px":c):void 0})}),m.each({Height:"height",Width:"width"},function(a,b){m.each({padding:"inner"+a,content:b,"":"outer"+a},function(c,d){m.fn[d]=function(d,e){var f=arguments.length&&(c||"boolean"!=typeof d),g=c||(d===!0||e===!0?"margin":"border");
return V(this,function(b,c,d){var e;return m.isWindow(b)?b.document.documentElement["client"+a]:9===b.nodeType?(e=b.documentElement,Math.max(b.body["scroll"+a],e["scroll"+a],b.body["offset"+a],e["offset"+a],e["client"+a])):void 0===d?m.css(b,c,g):m.style(b,c,d,g)},b,f?d:void 0,f,null)}})}),m.fn.size=function(){return this.length},m.fn.andSelf=m.fn.addBack,"function"==typeof define&&define.amd&&define("jquery",[],function(){return m});var ed=a.jQuery,fd=a.$;return m.noConflict=function(b){return a.$===m&&(a.$=fd),b&&a.jQuery===m&&(a.jQuery=ed),m},typeof b===K&&(a.jQuery=a.$=m),m});
`' || 
q'`
/*!
* TableSorter 2.15.3 min - Client-side table sorting with ease!
* Copyright (c) 2007 Christian Bach
*/
!function(g){g.extend({tablesorter:new function(){function d(){var a=arguments[0],b=1<arguments.length?Array.prototype.slice.call(arguments):a;if("undefined"!==typeof console&&"undefined"!==typeof console.log)console[/error/i.test(a)?"error":/warn/i.test(a)?"warn":"log"](b);else alert(b)}function u(a,b){d(a+" ("+((new Date).getTime()-b.getTime())+"ms)")}function m(a){for(var b in a)return!1;return!0}function p(a,b,c){if(!b)return"";var h=a.config,e=h.textExtraction,f="",f="simple"===e?h.supportsTextContent? b.textContent:g(b).text():"function"===typeof e?e(b,a,c):"object"===typeof e&&e.hasOwnProperty(c)?e[c](b,a,c):h.supportsTextContent?b.textContent:g(b).text();return g.trim(f)}function t(a){var b=a.config,c=b.$tbodies=b.$table.children("tbody:not(."+b.cssInfoBlock+")"),h,e,w,k,n,g,l,z="";if(0===c.length)return b.debug?d("Warning: *Empty table!* Not building a parser cache"):"";b.debug&&(l=new Date,d("Detecting parsers for each column"));c=c[0].rows;if(c[0])for(h=[],e=c[0].cells.length,w=0;w<e;w++){k= b.$headers.filter(":not([colspan])");k=k.add(b.$headers.filter('[colspan="1"]')).filter('[data-column="'+w+'"]:last');n=b.headers[w];g=f.getParserById(f.getData(k,n,"sorter"));b.empties[w]=f.getData(k,n,"empty")||b.emptyTo||(b.emptyToBottom?"bottom":"top");b.strings[w]=f.getData(k,n,"string")||b.stringTo||"max";if(!g)a:{k=a;n=c;g=-1;for(var m=w,y=void 0,x=f.parsers.length,r=!1,t="",y=!0;""===t&&y;)g++,n[g]?(r=n[g].cells[m],t=p(k,r,m),k.config.debug&&d("Checking if value was empty on row "+g+", column: "+ m+': "'+t+'"')):y=!1;for(;0<=--x;)if((y=f.parsers[x])&&"text"!==y.id&&y.is&&y.is(t,k,r)){g=y;break a}g=f.getParserById("text")}b.debug&&(z+="column:"+w+"; parser:"+g.id+"; string:"+b.strings[w]+"; empty: "+b.empties[w]+"\n");h.push(g)}b.debug&&(d(z),u("Completed detecting parsers",l));
b.parsers=h}function v(a){var b=a.tBodies,c=a.config,h,e,w=c.parsers,k,n,q,l,z,m,y,x=[];c.cache={};if(!w)return c.debug?d("Warning: *Empty table!* Not building a cache"):"";c.debug&&(y=new Date);c.showProcessing&&f.isProcessing(a, !0);for(l=0;l<b.length;l++)if(c.cache[l]={row:[],normalized:[]},!g(b[l]).hasClass(c.cssInfoBlock)){h=b[l]&&b[l].rows.length||0;e=b[l].rows[0]&&b[l].rows[0].cells.length||0;for(n=0;n<h;++n)if(z=g(b[l].rows[n]),m=[],z.hasClass(c.cssChildRow))c.cache[l].row[c.cache[l].row.length-1]=c.cache[l].row[c.cache[l].row.length-1].add(z);else{c.cache[l].row.push(z);for(q=0;q<e;++q)k=p(a,z[0].cells[q],q),k=w[q].format(k,a,z[0].cells[q],q),m.push(k),"numeric"===(w[q].type||"").toLowerCase()&&(x[q]=Math.max(Math.abs(k)|| 0,x[q]||0));m.push(c.cache[l].normalized.length);c.cache[l].normalized.push(m)}c.cache[l].colMax=x}c.showProcessing&&f.isProcessing(a);c.debug&&u("Building cache for "+h+" rows",y)}function A(a,b){var c=a.config,h=c.widgetOptions,e=a.tBodies,w=[],k=c.cache,d,q,l,z,p,y,x,r,t,s,v;
if(m(k))return c.appender?c.appender(a,w):"";c.debug&&(v=new Date);for(r=0;r<e.length;r++)if(d=g(e[r]),d.length&&!d.hasClass(c.cssInfoBlock)){p=f.processTbody(a,d,!0);d=k[r].row;q=k[r].normalized;z=(l=q.length)?q[0].length- 1:0;for(y=0;y<l;y++)if(s=q[y][z],w.push(d[s]),!c.appender||c.pager&&!(c.pager.removeRows&&h.pager_removeRows||c.pager.ajax))for(t=d[s].length,x=0;x<t;x++)p.append(d[s][x]);f.processTbody(a,p,!1)}c.appender&&c.appender(a,w);c.debug&&u("Rebuilt table",v);b||c.appender||f.applyWidget(a);g(a).trigger("sortEnd",a);g(a).trigger("updateComplete",a)}function D(a){var b=[],c={},h=0,e=g(a).find("thead:eq(0), tfoot").children("tr"),f,d,n,q,l,m,u,p,s,r;for(f=0;f<e.length;f++)for(l=e[f].cells,d=0;d<l.length;d++){q= l[d];m=q.parentNode.rowIndex;u=m+"-"+q.cellIndex;p=q.rowSpan||1;s=q.colSpan||1;"undefined"===typeof b[m]&&(b[m]=[]);for(n=0;n<b[m].length+1;n++)if("undefined"===typeof b[m][n]){r=n;break}c[u]=r;h=Math.max(r,h);g(q).attr({"data-column":r});for(n=m;n<m+p;n++)for("undefined"===typeof b[n]&&(b[n]=[]),u=b[n],q=r;q<r+s;q++)u[q]="x"}a.config.columns=h+1;return c}function C(a){return/^d/i.test(a)||1===a}function E(a){var b=D(a),c,h,e,w,k,n,q,l=a.config;
l.headerList=[];l.headerContent=[];l.debug&&(q=new Date); w=l.cssIcon?'<i class="'+(l.cssIcon===f.css.icon?f.css.icon:l.cssIcon+" "+f.css.icon)+'"></i>':"";l.$headers=g(a).find(l.selectorHeaders).each(function(a){h=g(this);c=l.headers[a];l.headerContent[a]=g(this).html();k=l.headerTemplate.replace(/\{content\}/g,g(this).html()).replace(/\{icon\}/g,w);l.onRenderTemplate&&(e=l.onRenderTemplate.apply(h,[a,k]))&&"string"===typeof e&&(k=e);g(this).html('<div class="'+f.css.headerIn+'">'+k+"</div>");l.onRenderHeader&&l.onRenderHeader.apply(h,[a]);this.column= b[this.parentNode.rowIndex+"-"+this.cellIndex];this.order=C(f.getData(h,c,"sortInitialOrder")||l.sortInitialOrder)?[1,0,2]:[0,1,2];this.count=-1;this.lockedOrder=!1;n=f.getData(h,c,"lockedOrder")||!1;"undefined"!==typeof n&&!1!==n&&(this.order=this.lockedOrder=C(n)?[1,1,1]:[0,0,0]);h.addClass(f.css.header+" "+l.cssHeader);l.headerList[a]=this;h.parent().addClass(f.css.headerRow+" "+l.cssHeaderRow).attr("role","row");l.tabIndex&&h.attr("tabindex",0)}).attr({scope:"col",role:"columnheader"});G(a);l.debug&& (u("Built headers:",q),d(l.$headers))}function B(a,b,c){var h=a.config;h.$table.find(h.selectorRemove).remove();t(a);v(a);H(h.$table,b,c)}
function G(a){var b,c,h=a.config;h.$headers.each(function(e,d){c=g(d);b="false"===f.getData(d,h.headers[e],"sorter");d.sortDisabled=b;c[b?"addClass":"removeClass"]("sorter-false").attr("aria-disabled",""+b);a.id&&(b?c.removeAttr("aria-controls"):c.attr("aria-controls",a.id))})}function F(a){var b,c,h,e=a.config,d=e.sortList,k=f.css.sortNone+" "+e.cssNone,n=[f.css.sortAsc+ " "+e.cssAsc,f.css.sortDesc+" "+e.cssDesc],q=["ascending","descending"],l=g(a).find("tfoot tr").children().removeClass(n.join(" "));e.$headers.removeClass(n.join(" ")).addClass(k).attr("aria-sort","none");h=d.length;for(b=0;b<h;b++)if(2!==d[b][1]&&(a=e.$headers.not(".sorter-false").filter('[data-column="'+d[b][0]+'"]'+(1===h?":last":"")),a.length))for(c=0;c<a.length;c++)a[c].sortDisabled||(a.eq(c).removeClass(k).addClass(n[d[b][1]]).attr("aria-sort",q[d[b][1]]),l.length&&l.filter('[data-column="'+ d[b][0]+'"]').eq(c).addClass(n[d[b][1]]));e.$headers.not(".sorter-false").each(function(){var a=g(this),b=this.order[(this.count+1)%(e.sortReset?3:2)],b=a.text()+": "+f.language[a.hasClass(f.css.sortAsc)?"sortAsc":a.hasClass(f.css.sortDesc)?"sortDesc":"sortNone"]+f.language[0===b?"nextAsc":1===b?"nextDesc":"nextNone"];a.attr("aria-label",b)})}function L(a){if(a.config.widthFixed&&0===g(a).find("colgroup").length){var b=g("<colgroup>"),c=g(a).width();g(a.tBodies[0]).find("tr:first").children("td:visible").each(function(){b.append(g("<col>").css("width", parseInt(g(this).width()/c*1E3,10)/10+"%"))});
g(a).prepend(b)}}function M(a,b){var c,h,e,f=a.config,d=b||f.sortList;f.sortList=[];g.each(d,function(a,b){c=[parseInt(b[0],10),parseInt(b[1],10)];if(e=f.$headers[c[0]])f.sortList.push(c),h=g.inArray(c[1],e.order),e.count=0<=h?h:c[1]%(f.sortReset?3:2)})}function N(a,b){return a&&a[b]?a[b].type||"":""}function O(a,b,c){var h,e,d,k=a.config,n=!c[k.sortMultiSortKey],q=g(a);q.trigger("sortStart",a);b.count=c[k.sortResetKey]?2:(b.count+1)%(k.sortReset?3:2); k.sortRestart&&(e=b,k.$headers.each(function(){this===e||!n&&g(this).is("."+f.css.sortDesc+",."+f.css.sortAsc)||(this.count=-1)}));e=b.column;if(n){k.sortList=[];if(null!==k.sortForce)for(h=k.sortForce,c=0;c<h.length;c++)h[c][0]!==e&&k.sortList.push(h[c]);h=b.order[b.count];if(2>h&&(k.sortList.push([e,h]),1<b.colSpan))for(c=1;c<b.colSpan;c++)k.sortList.push([e+c,h])}else if(k.sortAppend&&1<k.sortList.length&&f.isValueInArray(k.sortAppend[0][0],k.sortList)&&k.sortList.pop(),f.isValueInArray(e,k.sortList))for(c= 0;c<k.sortList.length;c++)d=k.sortList[c],h=k.$headers[d[0]],d[0]===e&&(d[1]=h.order[b.count],2===d[1]&&(k.sortList.splice(c,1),h.count=-1));else if(h=b.order[b.count],2>h&&(k.sortList.push([e,h]),1<b.colSpan))for(c=1;c<b.colSpan;c++)k.sortList.push([e+c,h]);if(null!==k.sortAppend)for(h=k.sortAppend,c=0;c<h.length;c++)h[c][0]!==e&&k.sortList.push(h[c]);q.trigger("sortBegin",a);
setTimeout(function(){F(a);I(a);A(a)},1)}function I(a){var b,c,h,e,d,k,g,q,l,p,s,t,x=0,r=a.config,v=r.textSorter||"",A=r.sortList, B=A.length,C=a.tBodies.length;if(!r.serverSideSorting&&!m(r.cache)){r.debug&&(l=new Date);for(c=0;c<C;c++)d=r.cache[c].colMax,q=(k=r.cache[c].normalized)&&k[0]?k[0].length-1:0,k.sort(function(c,k){for(b=0;b<B;b++){e=A[b][0];g=A[b][1];x=0===g;if(r.sortStable&&c[e]===k[e]&&1===B)break;(h=/n/i.test(N(r.parsers,e)))&&r.strings[e]?(h="boolean"===typeof r.string[r.strings[e]]?(x?1:-1)*(r.string[r.strings[e]]?-1:1):r.strings[e]?r.string[r.strings[e]]||0:0,p=r.numberSorter?r.numberSorter(s[e],t[e],x,d[e], a):f["sortNumeric"+(x?"Asc":"Desc")](c[e],k[e],h,d[e],e,a)):(s=x?c:k,t=x?k:c,p="function"===typeof v?v(s[e],t[e],x,e,a):"object"===typeof v&&v.hasOwnProperty(e)?v[e](s[e],t[e],x,e,a):f["sortNatural"+(x?"Asc":"Desc")](c[e],k[e],e,a,r));if(p)return p}return c[q]-k[q]});r.debug&&u("Sorting on "+A.toString()+" and dir "+g+" time",l)}}function J(a,b){var c=a[0].config;c.pager&&!c.pager.ajax&&a.trigger("updateComplete");"function"===typeof b&&b(a[0])}function H(a,b,c){!1===b||a[0].isProcessing?J(a,c):a.trigger("sorton", [a[0].config.sortList,function(){J(a,c)}])}function K(a){var b=a.config,c=b.$table;c.unbind("sortReset update updateRows updateCell updateAll addRows sorton appendCache applyWidgetId applyWidgets refreshWidgets destroy mouseup mouseleave ".split(" ").join(".tablesorter ")).bind("sortReset.tablesorter",function(c){c.stopPropagation();
b.sortList=[];F(a);I(a);A(a)}).bind("updateAll.tablesorter",function(c,e,d){c.stopPropagation();f.refreshWidgets(a,!0,!0);f.restoreHeaders(a);E(a);f.bindEvents(a,b.$headers); K(a);B(a,e,d)}).bind("update.tablesorter updateRows.tablesorter",function(b,c,d){b.stopPropagation();G(a);B(a,c,d)}).bind("updateCell.tablesorter",function(h,e,d,f){h.stopPropagation();c.find(b.selectorRemove).remove();var n,q,l;n=c.find("tbody");h=n.index(g(e).parents("tbody").filter(":first"));var m=g(e).parents("tr").filter(":first");e=g(e)[0];n.length&&0<=h&&(q=n.eq(h).find("tr").index(m),l=e.cellIndex,n=b.cache[h].normalized[q].length-1,b.cache[h].row[a.config.cache[h].normalized[q][n]]=m,b.cache[h].normalized[q][l]= b.parsers[l].format(p(a,e,l),a,e,l),H(c,d,f))}).bind("addRows.tablesorter",function(h,e,d,f){h.stopPropagation();if(m(b.cache))G(a),B(a,d,f);else{var g,q=e.filter("tr").length,l=[],u=e[0].cells.length,v=c.find("tbody").index(e.parents("tbody").filter(":first"));b.parsers||t(a);for(h=0;h<q;h++){for(g=0;g<u;g++)l[g]=b.parsers[g].format(p(a,e[h].cells[g],g),a,e[h].cells[g],g);l.push(b.cache[v].row.length);b.cache[v].row.push([e[h]]);b.cache[v].normalized.push(l);l=[]}H(c,d,f)}}).bind("sorton.tablesorter", function(b,e,d,f){var g=a.config;b.stopPropagation();c.trigger("sortStart",this);M(a,e);F(a);g.delayInit&&m(g.cache)&&v(a);c.trigger("sortBegin",this);I(a);A(a,f);"function"===typeof d&&d(a)}).bind("appendCache.tablesorter",function(b,c,d){b.stopPropagation();A(a,d);"function"===typeof c&&c(a)}).bind("applyWidgetId.tablesorter",function(c,e){c.stopPropagation();f.getWidgetById(e).format(a,b,b.widgetOptions)}).bind("applyWidgets.tablesorter",function(b,c){b.stopPropagation();f.applyWidget(a,c)}).bind("refreshWidgets.tablesorter", 
function(b,c,d){b.stopPropagation();f.refreshWidgets(a,c,d)}).bind("destroy.tablesorter",function(b,c,d){b.stopPropagation();f.destroy(a,c,d)})}var f=this;f.version="2.15.3";f.parsers=[];f.widgets=[];f.defaults={theme:"default",widthFixed:!1,showProcessing:!1,headerTemplate:"{content}",onRenderTemplate:null,onRenderHeader:null,cancelSelection:!0,tabIndex:!0,dateFormat:"mmddyyyy",sortMultiSortKey:"shiftKey",sortResetKey:"ctrlKey",usNumberFormat:!0,delayInit:!1,serverSideSorting:!1,headers:{},ignoreCase:!0, sortForce:null,sortList:[],sortAppend:null,sortStable:!1,sortInitialOrder:"asc",sortLocaleCompare:!1,sortReset:!1,sortRestart:!1,emptyTo:"bottom",stringTo:"max",textExtraction:"simple",textSorter:null,numberSorter:null,widgets:[],widgetOptions:{zebra:["even","odd"]},initWidgets:!0,initialized:null,tableClass:"",cssAsc:"",cssDesc:"",cssNone:"",cssHeader:"",cssHeaderRow:"",cssProcessing:"",cssChildRow:"tablesorter-childRow",cssIcon:"tablesorter-icon",cssInfoBlock:"tablesorter-infoOnly",selectorHeaders:"> thead th, > thead td", selectorSort:"th, td",selectorRemove:".remove-me",debug:!1,headerList:[],empties:{},strings:{},parsers:[]};f.css={table:"tablesorter",childRow:"tablesorter-childRow",header:"tablesorter-header",headerRow:"tablesorter-headerRow",headerIn:"tablesorter-header-inner",icon:"tablesorter-icon",info:"tablesorter-infoOnly",processing:"tablesorter-processing",sortAsc:"tablesorter-headerAsc",sortDesc:"tablesorter-headerDesc",sortNone:"tablesorter-headerUnSorted"};f.language={sortAsc:"Ascending sort applied, ", sortDesc:"Descending sort applied, ",sortNone:"No sort applied, ",nextAsc:"activate to apply an ascending sort",nextDesc:"activate to apply a descending sort",nextNone:"activate to remove the sort"};f.log=d;f.benchmark=u;f.construct=function(a){return this.each(function(){var b=g.extend(!0,{},f.defaults,a);
!this.hasInitialized&&f.buildTable&&"TABLE"!==this.tagName&&f.buildTable(this,b);f.setup(this,b)})};f.setup=function(a,b){if(!a||!a.tHead||0===a.tBodies.length||!0===a.hasInitialized)return b.debug? d("ERROR: stopping initialization! No table, thead, tbody or tablesorter has already been initialized"):"";var c="",h=g(a),e=g.metadata;a.hasInitialized=!1;a.isProcessing=!0;a.config=b;g.data(a,"tablesorter",b);b.debug&&g.data(a,"startoveralltimer",new Date);b.supportsTextContent="x"===g("<span>x</span>")[0].textContent;b.supportsDataObject=function(a){a[0]=parseInt(a[0],10);return 1<a[0]||1===a[0]&&4<=parseInt(a[1],10)}(g.fn.jquery.split("."));b.string={max:1,min:-1,"max+":1,"max-":-1,zero:0,none:0, "null":0,top:!0,bottom:!1};/tablesorter\-/.test(h.attr("class"))||(c=""!==b.theme?" tablesorter-"+b.theme:"");b.$table=h.addClass(f.css.table+" "+b.tableClass+c).attr({role:"grid"});b.$tbodies=h.children("tbody:not(."+b.cssInfoBlock+")").attr({"aria-live":"polite","aria-relevant":"all"});b.$table.find("caption").length&&b.$table.attr("aria-labelledby","theCaption");b.widgetInit={};E(a);L(a);t(a);b.delayInit||v(a);f.bindEvents(a,b.$headers);K(a);b.supportsDataObject&&"undefined"!==typeof h.data().sortlist? b.sortList=h.data().sortlist:e&&h.metadata()&&h.metadata().sortlist&&(b.sortList=h.metadata().sortlist);
f.applyWidget(a,!0);0<b.sortList.length?h.trigger("sorton",[b.sortList,{},!b.initWidgets]):(F(a),b.initWidgets&&f.applyWidget(a));b.showProcessing&&h.unbind("sortBegin.tablesorter sortEnd.tablesorter").bind("sortBegin.tablesorter sortEnd.tablesorter",function(b){f.isProcessing(a,"sortBegin"===b.type)});a.hasInitialized=!0;a.isProcessing=!1;b.debug&&f.benchmark("Overall initialization time",g.data(a, "startoveralltimer"));h.trigger("tablesorter-initialized",a);"function"===typeof b.initialized&&b.initialized(a)};f.isProcessing=function(a,b,c){a=g(a);var h=a[0].config;a=c||a.find("."+f.css.header);b?("undefined"!==typeof c&&0<h.sortList.length&&(a=a.filter(function(){return this.sortDisabled?!1:f.isValueInArray(parseFloat(g(this).attr("data-column")),h.sortList)})),a.addClass(f.css.processing+" "+h.cssProcessing)):a.removeClass(f.css.processing+" "+h.cssProcessing)};f.processTbody=function(a,b, c){a=g(a)[0];if(c)return a.isProcessing=!0,b.before('<span class="tablesorter-savemyplace"/>'),c=g.fn.detach?b.detach():b.remove();c=g(a).find("span.tablesorter-savemyplace");b.insertAfter(c);c.remove();a.isProcessing=!1};f.clearTableBody=function(a){g(a)[0].config.$tbodies.empty()};f.bindEvents=function(a,b){a=g(a)[0];var c,h=a.config;b.find(h.selectorSort).add(b.filter(h.selectorSort)).unbind("mousedown.tablesorter mouseup.tablesorter sort.tablesorter keyup.tablesorter").bind("mousedown.tablesorter mouseup.tablesorter sort.tablesorter keyup.tablesorter", function(e,d){var f;f=e.type;
if(!(1!==(e.which||e.button)&&!/sort|keyup/.test(f)||"keyup"===f&&13!==e.which||"mouseup"===f&&!0!==d&&250<(new Date).getTime()-c)){if("mousedown"===f)return c=(new Date).getTime(),"INPUT"===e.target.tagName?"":!h.cancelSelection;h.delayInit&&m(h.cache)&&v(a);f=/TH|TD/.test(this.tagName)?this:g(this).parents("th, td")[0];f=h.$headers[b.index(f)];f.sortDisabled||O(a,f,e)}});h.cancelSelection&&b.attr("unselectable","on").bind("selectstart",!1).css({"user-select":"none", MozUserSelect:"none"})};f.restoreHeaders=function(a){var b=g(a)[0].config;b.$table.find(b.selectorHeaders).each(function(a){g(this).find("."+f.css.headerIn).length&&g(this).html(b.headerContent[a])})};f.destroy=function(a,b,c){a=g(a)[0];if(a.hasInitialized){f.refreshWidgets(a,!0,!0);var h=g(a),e=a.config,d=h.find("thead:first"),k=d.find("tr."+f.css.headerRow).removeClass(f.css.headerRow+" "+e.cssHeaderRow),n=h.find("tfoot:first > tr").children("th, td");d.find("tr").not(k).remove();h.removeData("tablesorter").unbind("sortReset update updateAll updateRows updateCell addRows sorton appendCache applyWidgetId applyWidgets refreshWidgets destroy mouseup mouseleave keypress sortBegin sortEnd ".split(" ").join(".tablesorter ")); e.$headers.add(n).removeClass([f.css.header,e.cssHeader,e.cssAsc,e.cssDesc,f.css.sortAsc,f.css.sortDesc,f.css.sortNone].join(" ")).removeAttr("data-column");k.find(e.selectorSort).unbind("mousedown.tablesorter mouseup.tablesorter keypress.tablesorter");f.restoreHeaders(a);!1!==b&&h.removeClass(f.css.table+" "+e.tableClass+" tablesorter-"+e.theme);a.hasInitialized=!1;"function"===typeof c&&c(a)}};
f.regex={chunk:/(^([+\-]?(?:0|[1-9]\d*)(?:\.\d*)?(?:[eE][+\-]?\d+)?)?$|^0x[0-9a-f]+$|\d+)/gi,hex:/^0x[0-9a-f]+$/i}; f.sortNatural=function(a,b){if(a===b)return 0;var c,h,e,d,g,n;h=f.regex;if(h.hex.test(b)){c=parseInt(a.match(h.hex),16);e=parseInt(b.match(h.hex),16);if(c<e)return-1;if(c>e)return 1}c=a.replace(h.chunk,"\\0$1\\0").replace(/\\0$/,"").replace(/^\\0/,"").split("\\0");h=b.replace(h.chunk,"\\0$1\\0").replace(/\\0$/,"").replace(/^\\0/,"").split("\\0");n=Math.max(c.length,h.length);for(g=0;g<n;g++){e=isNaN(c[g])?c[g]||0:parseFloat(c[g])||0;d=isNaN(h[g])?h[g]||0:parseFloat(h[g])||0;if(isNaN(e)!==isNaN(d))return isNaN(e)? 1:-1;typeof e!==typeof d&&(e+="",d+="");if(e<d)return-1;if(e>d)return 1}return 0};f.sortNaturalAsc=function(a,b,c,d,e){if(a===b)return 0;c=e.string[e.empties[c]||e.emptyTo];return""===a&&0!==c?"boolean"===typeof c?c?-1:1:-c||-1:""===b&&0!==c?"boolean"===typeof c?c?1:-1:c||1:f.sortNatural(a,b)};f.sortNaturalDesc=function(a,b,c,d,e){if(a===b)return 0;c=e.string[e.empties[c]||e.emptyTo];return""===a&&0!==c?"boolean"===typeof c?c?-1:1:c||1:""===b&&0!==c?"boolean"===typeof c?c?1:-1:-c||-1:f.sortNatural(b, a)};f.sortText=function(a,b){return a>b?1:a<b?-1:0};f.getTextValue=function(a,b,c){if(c){var d=a?a.length:0,e=c+b;for(c=0;c<d;c++)e+=a.charCodeAt(c);return b*e}return 0};f.sortNumericAsc=function(a,b,c,d,e,g){if(a===b)return 0;g=g.config;e=g.string[g.empties[e]||g.emptyTo];
if(""===a&&0!==e)return"boolean"===typeof e?e?-1:1:-e||-1;if(""===b&&0!==e)return"boolean"===typeof e?e?1:-1:e||1;isNaN(a)&&(a=f.getTextValue(a,c,d));isNaN(b)&&(b=f.getTextValue(b,c,d));return a-b};f.sortNumericDesc=function(a, b,c,d,e,g){if(a===b)return 0;g=g.config;e=g.string[g.empties[e]||g.emptyTo];if(""===a&&0!==e)return"boolean"===typeof e?e?-1:1:e||1;if(""===b&&0!==e)return"boolean"===typeof e?e?1:-1:-e||-1;isNaN(a)&&(a=f.getTextValue(a,c,d));isNaN(b)&&(b=f.getTextValue(b,c,d));return b-a};f.sortNumeric=function(a,b){return a-b};f.characterEquivalents={a:"\u00e1\u00e0\u00e2\u00e3\u00e4\u0105\u00e5",A:"\u00c1\u00c0\u00c2\u00c3\u00c4\u0104\u00c5",c:"\u00e7\u0107\u010d",C:"\u00c7\u0106\u010c",e:"\u00e9\u00e8\u00ea\u00eb\u011b\u0119", E:"\u00c9\u00c8\u00ca\u00cb\u011a\u0118",i:"\u00ed\u00ec\u0130\u00ee\u00ef\u0131",I:"\u00cd\u00cc\u0130\u00ce\u00cf",o:"\u00f3\u00f2\u00f4\u00f5\u00f6",O:"\u00d3\u00d2\u00d4\u00d5\u00d6",ss:"\u00df",SS:"\u1e9e",u:"\u00fa\u00f9\u00fb\u00fc\u016f",U:"\u00da\u00d9\u00db\u00dc\u016e"};f.replaceAccents=function(a){var b,c="[",d=f.characterEquivalents;if(!f.characterRegex){f.characterRegexArray={};for(b in d)"string"===typeof b&&(c+=d[b],f.characterRegexArray[b]=RegExp("["+d[b]+"]","g"));f.characterRegex= RegExp(c+"]")}if(f.characterRegex.test(a))for(b in d)"string"===typeof b&&(a=a.replace(f.characterRegexArray[b],b));return a};f.isValueInArray=function(a,b){var c,d=b.length;for(c=0;c<d;c++)if(b[c][0]===a)return!0;return!1};f.addParser=function(a){var b,c=f.parsers.length,d=!0;for(b=0;b<c;b++)f.parsers[b].id.toLowerCase()===a.id.toLowerCase()&&(d=!1);d&&f.parsers.push(a)};f.getParserById=function(a){var b,c=f.parsers.length;for(b=0;b<c;b++)if(f.parsers[b].id.toLowerCase()===a.toString().toLowerCase())return f.parsers[b]; 
return!1};f.addWidget=function(a){f.widgets.push(a)};f.getWidgetById=function(a){var b,c,d=f.widgets.length;for(b=0;b<d;b++)if((c=f.widgets[b])&&c.hasOwnProperty("id")&&c.id.toLowerCase()===a.toLowerCase())return c};f.applyWidget=function(a,b){a=g(a)[0];var c=a.config,d=c.widgetOptions,e=[],m,k,n;c.debug&&(m=new Date);c.widgets.length&&(c.widgets=g.grep(c.widgets,function(a,b){return g.inArray(a,c.widgets)===b}),g.each(c.widgets||[],function(a,b){(n=f.getWidgetById(b))&&n.id&&(n.priority||(n.priority= 10),e[a]=n)}),e.sort(function(a,b){return a.priority<b.priority?-1:a.priority===b.priority?0:1}),g.each(e,function(e,f){if(f){if(b||!c.widgetInit[f.id])f.hasOwnProperty("options")&&(d=a.config.widgetOptions=g.extend(!0,{},f.options,d)),f.hasOwnProperty("init")&&f.init(a,f,c,d),c.widgetInit[f.id]=!0;!b&&f.hasOwnProperty("format")&&f.format(a,c,d,!1)}}));c.debug&&(k=c.widgets.length,u("Completed "+(!0===b?"initializing ":"applying ")+k+" widget"+(1!==k?"s":""),m))};f.refreshWidgets=function(a,b,c){a= g(a)[0];var h,e=a.config,m=e.widgets,k=f.widgets,n=k.length;for(h=0;h<n;h++)k[h]&&k[h].id&&(b||0>g.inArray(k[h].id,m))&&(e.debug&&d('Refeshing widgets: Removing "'+k[h].id+'"'),k[h].hasOwnProperty("remove")&&e.widgetInit[k[h].id]&&(k[h].remove(a,e,e.widgetOptions),e.widgetInit[k[h].id]=!1));!0!==c&&f.applyWidget(a,b)};f.getData=function(a,b,c){var d="";a=g(a);var e,f;if(!a.length)return"";e=g.metadata?a.metadata():!1;
f=" "+(a.attr("class")||"");"undefined"!==typeof a.data(c)||"undefined"!==typeof a.data(c.toLowerCase())? d+=a.data(c)||a.data(c.toLowerCase()):e&&"undefined"!==typeof e[c]?d+=e[c]:b&&"undefined"!==typeof b[c]?d+=b[c]:" "!==f&&f.match(" "+c+"-")&&(d=f.match(RegExp("\\s"+c+"-([\\w-]+)"))[1]||"");return g.trim(d)};f.formatFloat=function(a,b){if("string"!==typeof a||""===a)return a;var c;a=(b&&b.config?!1!==b.config.usNumberFormat:"undefined"!==typeof b?b:1)?a.replace(/,/g,""):a.replace(/[\s|\.]/g,"").replace(/,/g,".");/^\s*\([.\d]+\)/.test(a)&&(a=a.replace(/^\s*\(([.\d]+)\)/,"-$1"));c=parseFloat(a);return isNaN(c)? g.trim(a):c};f.isDigit=function(a){return isNaN(a)?/^[\-+(]?\d+[)]?$/.test(a.toString().replace(/[,.'"\s]/g,"")):!0}}});var p=g.tablesorter;g.fn.extend({tablesorter:p.construct});p.addParser({id:"text",is:function(){return!0},format:function(d,u){var m=u.config;d&&(d=g.trim(m.ignoreCase?d.toLocaleLowerCase():d),d=m.sortLocaleCompare?p.replaceAccents(d):d);return d},type:"text"});p.addParser({id:"digit",is:function(d){return p.isDigit(d)},format:function(d,u){var m=p.formatFloat((d||"").replace(/[^\w,. \-()]/g, ""),u);return d&&"number"===typeof m?m:d?g.trim(d&&u.config.ignoreCase?d.toLocaleLowerCase():d):d},type:"numeric"});p.addParser({id:"currency",is:function(d){return/^\(?\d+[\u00a3$\u20ac\u00a4\u00a5\u00a2?.]|[\u00a3$\u20ac\u00a4\u00a5\u00a2?.]\d+\)?$/.test((d||"").replace(/[+\-,. ]/g,""))},format:function(d,u){var m=p.formatFloat((d||"").replace(/[^\w,. \-()]/g,""),u);return d&&"number"===typeof m?m:d?g.trim(d&&u.config.ignoreCase?d.toLocaleLowerCase():d):d},type:"numeric"});p.addParser({id:"ipAddress", is:function(d){return/^\d{1,3}[\.]\d{1,3}[\.]\d{1,3}[\.]\d{1,3}$/.test(d)},format:function(d,g){var m,s=d?d.split("."):"",t="",v=s.length;
for(m=0;m<v;m++)t+=("00"+s[m]).slice(-3);return d?p.formatFloat(t,g):d},type:"numeric"});p.addParser({id:"url",is:function(d){return/^(https?|ftp|file):\/\//.test(d)},format:function(d){return d?g.trim(d.replace(/(https?|ftp|file):\/\//,"")):d},type:"text"});p.addParser({id:"isoDate",is:function(d){return/^\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2}/.test(d)},format:function(d, g){return d?p.formatFloat(""!==d?(new Date(d.replace(/-/g,"/"))).getTime()||"":"",g):d},type:"numeric"});p.addParser({id:"percent",is:function(d){return/(\d\s*?%|%\s*?\d)/.test(d)&&15>d.length},format:function(d,g){return d?p.formatFloat(d.replace(/%/g,""),g):d},type:"numeric"});p.addParser({id:"usLongDate",is:function(d){return/^[A-Z]{3,10}\.?\s+\d{1,2},?\s+(\d{4})(\s+\d{1,2}:\d{2}(:\d{2})?(\s+[AP]M)?)?$/i.test(d)||/^\d{1,2}\s+[A-Z]{3,10}\s+\d{4}/i.test(d)},format:function(d,g){return d?p.formatFloat((new Date(d.replace(/(\S)([AP]M)$/i, "$1 $2"))).getTime()||"",g):d},type:"numeric"});p.addParser({id:"shortDate",is:function(d){return/(^\d{1,2}[\/\s]\d{1,2}[\/\s]\d{4})|(^\d{4}[\/\s]\d{1,2}[\/\s]\d{1,2})/.test((d||"").replace(/\s+/g," ").replace(/[\-.,]/g,"/"))},format:function(d,g,m,s){if(d){m=g.config;
var t=m.$headers.filter("[data-column="+s+"]:last");s=t.length&&t[0].dateFormat||p.getData(t,m.headers[s],"dateFormat")||m.dateFormat;d=d.replace(/\s+/g," ").replace(/[\-.,]/g,"/");"mmddyyyy"===s?d=d.replace(/(\d{1,2})[\/\s](\d{1,2})[\/\s](\d{4})/, "$3/$1/$2"):"ddmmyyyy"===s?d=d.replace(/(\d{1,2})[\/\s](\d{1,2})[\/\s](\d{4})/,"$3/$2/$1"):"yyyymmdd"===s&&(d=d.replace(/(\d{4})[\/\s](\d{1,2})[\/\s](\d{1,2})/,"$1/$2/$3"))}return d?p.formatFloat((new Date(d)).getTime()||"",g):d},type:"numeric"});p.addParser({id:"time",is:function(d){return/^(([0-2]?\d:[0-5]\d)|([0-1]?\d:[0-5]\d\s?([AP]M)))$/i.test(d)},format:function(d,g){return d?p.formatFloat((new Date("2000/01/01 "+d.replace(/(\S)([AP]M)$/i,"$1 $2"))).getTime()||"",g):d},type:"numeric"});p.addParser({id:"metadata", is:function(){return!1},format:function(d,p,m){d=p.config;d=d.parserMetadataName?d.parserMetadataName:"sortValue";return g(m).metadata()[d]},type:"numeric"});p.addWidget({id:"zebra",priority:90,format:function(d,u,m){var s,t,v,A,D,C,E=RegExp(u.cssChildRow,"i"),B=u.$tbodies;u.debug&&(D=new Date);for(d=0;d<B.length;d++)s=B.eq(d),C=s.children("tr").length,1<C&&(v=0,s=s.children("tr:visible").not(u.selectorRemove),s.each(function(){t=g(this);E.test(this.className)||v++;A=0===v%2;t.removeClass(m.zebra[A? 1:0]).addClass(m.zebra[A?0:1])}));u.debug&&p.benchmark("Applying Zebra widget",D)},remove:function(d,p,m){var s;p=p.$tbodies;var t=(m.zebra||["even","odd"]).join(" ");for(m=0;m<p.length;m++)s=g.tablesorter.processTbody(d,p.eq(m),!0),s.children().removeClass(t),g.tablesorter.processTbody(d,s,!1)}})}(jQuery);

/*! Analyzer JavaScript, 2.5.7 2025/12/05 00:00:00 fvaduva */

/* ********************************************************
    Global variables
******************************************************** */
var MASK_KEY = "";
var FILTER_STRING = "";
/* EBSAF-202 Improved floating header tracking */
var HEADER_SIZE = 0;
var FOOTER_SIZE = 0;
/* EBSAF-287 Disable export functionality */
var DISABLE_EXPORT = false;
var FEEDBACK_URL = "", FEEDBACK_AZR = "", FEEDBACK_SR = "", FEEDBACK_SIG = void 0, FEEDBACK_TYPE = void 0, FEEDBACK_SHOW = !1;


/* ********************************************************
    Main handler for document ready
******************************************************** */
$(document).ready(function(){
    /* Before anything else, verify if the file is complete and alert otherwise    */
    if (! $("#integrityCheck").length ) {
        alert("The file is incomplete or corrupt and will not be displayed correctly!\n" +
            "You might be able to view a partial content using Data View / Full View.");
    }

    /* Build dynamic content areas */
    buildTagsArea();
    buildSectionMenu();
    buildMainMenu();
    showExceptions();
	addRowSelectionButtons()

    /* Register event handlers */
    $(window).resize(UpdateHeaderFooter).trigger("resize");
    $(window).scroll(UpdateTableHeaders).trigger("scroll");
    registerPopupHandlers();
    registerViewHandlers();
    registerExpColAllHandlers();
    registerSearchHandlers();
    registerSignatureHandlers();
    registerMaskingHandlers();
    registerExportHandlers();
    registerSortHandlers();
    registerHideHandlers();
    registerIconHandlers();

    /* Update content */
    fixAnchorUrls();
    updateFailRows();
    updateInternalViewer();
	enableRowSelection();
	
});
/* ********************************************************
    End of document ready
******************************************************** */

function UpdateHeaderFooter(){
    HEADER_SIZE = $("div.pageheader").height();
    FOOTER_SIZE = $("div.footerarea").height();
}

/* Maintain the persistent table header positions when scrolling */
function UpdateTableHeaders() {
    $(".parea:visible").each(function() {
        var el             = $(this);
        var offset         = el.offset();
        var scrollTop      = $(window).scrollTop() + HEADER_SIZE;
        var floatingHeader = $(".floatingHeader", this);
        var persistHeader  = $(".pheader", this);
        var undocked = (persistHeader.attr("undocked") == "true");

        if ((scrollTop > offset.top) && (scrollTop < offset.top + el.height())) {
            /* EBSAF-214 Maintain horizontal alignment */
            var offsetLeft = Math.round(offset.left - $(window).scrollLeft() ) + "px";
            if (persistHeader.css("left") != offsetLeft) {
                persistHeader.css("left", offsetLeft);
            }

            /* EBSAF-202 Persistent header is undocked to stay on screen */
            if (!undocked) {
                floatingHeader.attr("docked","true");
                persistHeader.attr("undocked","true");
            }
        } else {
            /* EBSAF-202 Persistent header is docked when table off screen*/
            if (undocked) {
                floatingHeader.removeAttr("docked");
                persistHeader.removeAttr("undocked");
            }
        };
    });
}


/* Build the section for filtering signatures by associated tags */
function buildTagsArea(){
    /* if there is no tags div defined, nothing to do */
    if ($("div.sigtag").size() <= 0) return;

    var myList=[];

    /* gather a list with all the tags */
    $(".sigtag").each(function(){
        var myIA = $(this).attr("tag");
        if (myList.indexOf(myIA) < 0) {
            myList.push(myIA);
        }
    });

    /* no tags, do nothing */
    if (myList.length <= 0) return;

    var iaTable = "<table class='table2'><thead><tr><th bgcolor='#f2f4f7'>Impact Areas</th><th bgcolor='#f2f4f7'>Count</th></tr></thead>\n";

    myList.forEach(function(item){
        var count = $("div.sigtag[tag='" + item + "']").size();
        iaTable += "<tr><td>" + item + "</td><td><div class='tagFilter' filter='" + item + "'><a class='tagcount' show-tag='" + item + "'>" + count + "</a></div></td></tr>\n";
    });
    iaTable += "</table>";
    $("#tags_area").html(iaTable);
    $("#tags_area").addClass("print");

    /* Add click handlers */
    $("a[show-tag]").on("click", function(){
        var tagID = $(this).attr("show-tag");
        $(".sigcontainer.data").hide();
        $(".tags").show();
        $(".sigtag[tag='" + tagID + "']").parent().show();
    });
}

/* Event handlers for pop-up windows */
function registerPopupHandlers() {
    var popupVisible=false;

    /* Show banner */
    $("#banner").show();
`' || 
q'`
    /* Open pop-up window*/
    $("[data-popup-open]").on("click", function()  {
        var targeted_popup_class = jQuery(this).attr("data-popup-open");
        $("[data-popup]").hide();
        $("[data-popup='" + targeted_popup_class + "']").fadeIn(350, function(){
           popupVisible = true;
        });
    });

    /* Close pop-up window*/
    $("[data-popup-close]").on("click", function()  {
        var targeted_popup_class = jQuery(this).attr("data-popup-close");
        $("[data-popup='" + targeted_popup_class + "']").fadeOut(350, function(){
           popupVisible = false;
        });
    });

    /* Close active pop-up window when clicking outside its boundaries*/
    $("body").click(function(e) {
       if (popupVisible == true){
          if (!e) e = window.event;
          if ((!$(e.target).parents().hasClass("popup-inner")) && ($(e.target).attr("id")!="execDetails") && ($(e.target).attr("id")!="execParameters")){
             $("[data-popup-close]").click();
          }
       }
    });

    /* Close active pop-up window when pressing Esc, Space or Enter*/
    $(document).keydown(function(e) {
       if (((e.which == 13) || (e.which == 32) || (e.which == 27)) && popupVisible == true) {
             $("[data-popup-close]").click();
       }
    });
}

/* Event handlers for changing views/sections */
function registerViewHandlers() {

    /* Open home page */
    $("#homeButton").click(function(){
        $(".data").hide();
        $(".maindata").hide();
        $(".mainmenu").show();
        $("#search").val("");
    });

    /* Open section (by section name or by error type)*/
    $("[open-section]").on("click", function()  {
        var sectionID = jQuery(this).attr("open-section");
        var sectionName = jQuery(this).find("div.textbox").text();
        var sectionTitle = {"E": "Error Signatures",
                            "W": "Warning Signatures",
                            "S": "Successful Signatures",
                            "I": "Informational Signatures",
                            "P": "Background Passed Checks"};
        if ((sectionName == null) || (sectionName == "")){
            sectionName = sectionTitle[sectionID];
        }
        FILTER_STRING = sectionID;

        /* if the section is empty, do nothing*/
        if ($("." + sectionID).size() <= 0) {
           return;
        }

        /* Hide banner */
        $("#banner").hide();

        /* Reset indent for section roots */
        $("#sectionmenu .sct-submenu[sct-root='true']").attr("sct-root", "false");
        $("#" + sectionID + "_submenu").attr("sct-root", "true");

        $(".mainmenu").hide();
        $(".data").hide();
        $(".section").show();
        $(".signature").hide();
        $("." + sectionID).show();
        $("#search").val("");
        $("#showhidesection").attr("mode", "show");
        $("span.brokenlink").hide();

        $("#export2TextLink").attr("onClick", "onclick=export2PaddedText('" + sectionID + "', 0);return false;");
        $(".exportAllImg").attr("onClick", "export2CSV('" + sectionID + "', 'section')");

        $(".containertitle").html(sectionName);

        if ((sectionID == 'error') || (sectionID == 'success') || (sectionID == 'information') || (sectionID == 'warning')) {
            $(".sectionview").attr("open-sig-class", sectionID + "sig");
        } else {
            $(".sectionview").attr("open-sig-class", sectionID);
        }
        $("a[siglink]").removeAttr("href");  /* remove links between signature records in section view*/
        $("a[siglink]").removeClass("hypersource");
        $("a[siglink]").addClass("nolink");
        $("#sectionmenu .sectionbutton." + sectionID).filter(":visible").first().click();
    });


    /* Print, Analysis and Full Section view */
    $("[open-sig-class]").on("click", function(){
        var sigClassID = jQuery(this).attr("open-sig-class");

        /* hide everything first*/
        $(".mainmenu").hide();
        $(".data").hide();
        $("#search").val("");
        $("#banner").hide();


        if (sigClassID == "print"){
            $(".containertitle").html("Full View");
            $("#expandall").attr("mode", "print");
            $("#collapseall").attr("mode", "print");
            $("#expandallinfo").attr("mode", "print");
            $("#collapseallinfo").attr("mode", "print");
            
            FILTER_STRING="";
            /* show all divs that have the print class*/
            $(".print").show();
            $("a[siglink]").removeAttr("href");  /* remove links between signature records in print view */
            $("a[siglink]").removeClass("hypersource");
            $("a[siglink]").addClass("nolink");
            $("span.brokenlink").hide();
            $(".exportAllImg").attr("onClick", "export2CSV('ALL')");

        } else if (sigClassID == "analysis") {
            $(".containertitle").html("Data View");
            $("#expandall").attr("mode", "analysis");
            $("#collapseall").attr("mode", "analysis");
            $("#expandallinfo").attr("mode", "analysis");
            $("#collapseallinfo").attr("mode", "analysis");
            FILTER_STRING="";
            /* show all divs that have the analysis class*/
            $(".analysis").show();

            /* add links to the records that are interconnected (links are saved in a separate attribute named siglink)*/
            $("a[siglink]").each(function(){
               /* if target anchor exists, create the link. Otherwise, display an exclamation mark*/
               if ($("a#" + $(this).attr("siglink") + ".anchor").length > 0){
                   $(this).attr("href", "#" + $(this).attr("siglink"));
                   $(this).addClass("hypersource");
                   $(this).removeClass("nolink");
               } else {
                   $(this).closest('td').find('span.brokenlink').show();
               }
            });

        } else if (sigClassID == "passed"){
            /* Short summary of background passed checks. No search, export, checkboxes, etc. */
            $(".containertitle").html("Background Passed Checks");
            $(".signature").hide();
            $(".P").show();
        } else if (sigClassID == "exception"){
            /* Short summary of signature exceptions. No search, export, checkboxes, etc. */
            $(".containertitle").html("Exceptions Occurred");
            $(".signature").hide();
            $(".X").show();
            $(".maindata").show();
        } else { /* Entire Section view */
            if ($("#showhidesection").attr("mode") == "show") {
                if (/^(E|I|S|W)$/.test(sigClassID)){
                    $(".sigrescode."+sigClassID).parents("div.sigcontainer").show();
                } else {
                    $("." + sigClassID).show();
                }
                $(".fullsection").show();
                FILTER_STRING = sigClassID;
                $("#showhidesection").attr("mode", "hide");
                $("#expandall").attr("mode", "print");
                $("#collapseall").attr("mode", "print");
                $("#expandallinfo").attr("mode", "print");
                $("#collapseallinfo").attr("mode", "print");
            } else {
                $(".section").show();
                $(".signature").hide();
                $("#showhidesection").attr("mode", "show");
                $("[open-section='"+sigClassID+"']").click();
            }
        }

        resetHiddenDataSigs();
    });
}

/* Event handlers for all button icons */
function registerIconHandlers() {
    // Add animation to indicate something happened
    $(".divItemTitle .detailsmall, .expcoll .detailsmall, .header_title .detailsmall").click(function(){
        $(this).fadeTo(200, 0.5, function () {
            $(this).fadeTo(200, 1.0, function () {
                $(this).removeAttr("style");
            });
        })
    });
}

/* Event handlers for Expand/Collapse All buttons */
function registerExpColAllHandlers() {
    var alertOn = true;
    
    /* Ensure proper view classes on buttons */
    $("#expandall").addClass("fullsection data print analysis");
    $("#collapseall").addClass("fullsection data print analysis");
    $("#expandallinfo").addClass("fullsection data print analysis");
    $("#collapseallinfo").addClass("fullsection data print analysis");
    
    $("#expandall").on("click", function(){
        if (alertOn){
            var returnVal = confirm ("This action could lead to performance issues and might even freeze your browser window. Do you want to continue?");
            if (returnVal == false) return;
            alertOn = false;
        }
        if (returnVal == false) return;
        $(".tabledata").show();
        if ($("#expandall").attr("mode") == "print"){
            $(".results").show();
        }
        $(".arrowright").hide();
        $(".arrowdown").show();
        var e = jQuery.Event("keypress");
        e.keyCode = 13;
        $("#search").trigger(e);
        $(".parea").each(function() {
            /* EBSAF-202 Build all floating headers */
            buildFloatingHeader( $(this).attr("id") );
        });
    });
    $("#collapseall").on("click", function(){
        $(".tabledata").hide();
        if ($("#collapseall").attr("mode") == "print"){
            $(".results").show();
        } else {
            $(".results").hide();
        }
        $(".arrowright").show();
        $(".arrowdown").hide();
        $(".parea").each(function() {
            /* EBSAF-202 Remove all floating headers */
            removeFloatingHeader( $(this).attr("id") );
        });
    });

    $("#expandallinfo").on("click", function(){
        // EBSAF-354
        $("a[toggle-info]").each(function(){
            var infoID = $(this).attr("toggle-info");
            $("#"+infoID).show();
        });
    });
    $("#collapseallinfo").on("click", function(){
        // EBSAF-354
        $("a[toggle-info]").each(function(){
            var infoID = $(this).attr("toggle-info");
            $("#"+infoID).hide();
        });
    });
}

/* Event handlers for searching data */
function registerSearchHandlers() {
    var searchFlag = false;
    var isOldBrowser = false;
    var ua = navigator.userAgent;
    var browserDetails = ua.match(/(opera|chrome|safari|firefox|msie|trident(?=\/))\/?\s*(\d+)/i) || [];
    /* if browser is firefox and version is 45 or lower, do not hide rows when filtering. Only highlight those that match.*/
    if ((browserDetails[1] == "Firefox") && (browserDetails[2] <= 45)) {
        isOldBrowser = true;
    }

    /* Dynamic display based on the search string*/
    $("#search").keypress (function(e) {
       if (e.keyCode == 13){
         /* EBSAF-210 Clear all existing matches first */
         $(".search_match").removeClass("search_match");

         var searchTerm = $("#search").val().toLowerCase();
         $.extend($.expr[":"], {
             "containsi": function(elem, i, match, array) {
               return (elem.textContent || elem.innerText || "").toLowerCase().indexOf((match[3] || "").toLowerCase()) >= 0;
             }
         });

         if (!isOldBrowser) { /* if the browser is not old, show only rows that include the string and hide the rest of the rows. */

            if ((searchTerm == null) || (searchTerm == "")) {
               if (!searchFlag){
                  return;
               } else {
                  var rowList = FILTER_STRING ? $(".tdata."+FILTER_STRING+":hidden") : $(".tdata:hidden");
                  rowList.show();
               }
               return;
            }
            var $showRows = FILTER_STRING ? $(".tdata."+FILTER_STRING+":containsi('"+searchTerm+"')") : $(".tdata:containsi('"+searchTerm+"')");
            var $noShow = FILTER_STRING ? $(".tdata."+FILTER_STRING).not(":containsi('"+searchTerm+"')") : $(".tdata").not(":containsi('"+searchTerm+"')");

            $noShow.css("display","none");
            /*$showRows.css("display","table-row");*/
            $showRows.addClass("search_match").css("display","table-row");
            $($showRows.closest(".tabledata")).show();

         } else { /* is old browser, do not repaint, just highlight */
            /* if string is empty, show everything and return*/
            if ((searchTerm == null) || (searchTerm == "")) {

                if (!searchFlag){
                   return;
                } else {
                   searchFlag=false;
                   $(".tdata").css("background-color", "white");
                   return;
                }
            }

            $(".tdata").not(":containsi('" + searchTerm + "')").css("background-color", "white");
            /*$(".tdata:containsi('" + searchTerm + "')").css("background-color", "#ffffe6");*/
            $(".tdata:containsi('" + searchTerm + "')").addClass("search_match").css("background-color", "#ffffe6");  /* EBSAF-210 */

         }

        /* EBSAF-210 Add column headers to search */
        var $headRows = FILTER_STRING ? $(".tdata."+FILTER_STRING).closest(".tabledata").find("thead tr:containsi('"+searchTerm+"')") : $(".tdata").closest(".tabledata").find("thead tr:containsi('"+searchTerm+"')");
        $headRows.addClass("search_match");
        $($headRows.closest(".tabledata")).show();

        /* EBSAF-210 Highlight matching cells */
        var $showCols = $("tr.search_match").children(":containsi('"+searchTerm+"')");
        $showCols.addClass("search_match");
      }
      searchFlag = true;
   });
}

/* Event handlers for showing signatures and their components */
function registerSignatureHandlers() {
    /* Open signature */
    $("[open-sig]").on("click", function()  {
        var sigID = jQuery(this).attr("open-sig");

        $(".signature").hide();
        $(".sectionbutton").css("background-color", "");
        $(".export2Txt").hide();
        $("#SignatureTitle").html("Signature: " + sigID);
        $("." + sigID).show();
        $(".sectionbutton[open-sig='" + sigID + "']").css("background-color","white");
        var e = jQuery.Event("keypress");
        e.keyCode = 13;
        $("#search").focus();
        $("#search").trigger(e);
    });

    /* Open table data for a sig    */
    $("a[toggle-data]").on("click", function(){
        var $tabledataID = $(this).attr("toggle-data");
        var $dataTable = $("#"+$tabledataID);
        $dataTable.toggle();
        $(this).find(".arrowright").toggle();
        if ($(this).find(".arrowdown").css("display") == "none"){
            $(this).find(".arrowdown").show();
            /* EBSAF-202 Build the floating header if missing */
            buildFloatingHeader($tabledataID);
        } else {
            $(this).find(".arrowdown").hide();
            /* EBSAF-202 Remove the floating header if present */
            removeFloatingHeader($tabledataID);
        };
        var e = jQuery.Event("keypress");
        e.keyCode = 13; /* Enter */
        $("#search").trigger(e);
    });

    /* Toggle header information */
    $("a[toggle-info]").on("click", function(){
        var infoID = $(this).attr("toggle-info");
        $("#"+infoID).toggle();
    });
}

/* Event handlers for masking options */
function registerMaskingHandlers() {
    /* if masking is enabled, mask column when user clicks on a column header */
    $("th.sigdetails").on('click', function(){
        var $maskDiv=$(this).closest('div.sigcontainer').find('span.mask');
        var $maskOn = $maskDiv.hasClass('mask_enabled') ? true : false;
        /* if masking is not enabled for the sig, do nothing */
        if (($maskOn != true) || (MASK_KEY.length <= 0)) return;
        /* if masking is already enabled on the column, do nothing */
        if ($(this).attr('mask') == 'on') return;

        /* obtain the column number - starts from 0 */
        var $table = $(this).closest(".table1.tabledata");
        var $colNo = $(this).parent().children().index($(this));
        $colNo++;  /* nth-child starts from 1 */

        /* EBSAF-258 Verify masking allowed first so error only occurs once */
        var validCol = true;
        $table.find("tr.tdata").each(function(){
            if (validCol) {
                var $cell = $(this).find('td:nth-child(' + $colNo + ')');
                if ($cell.find("a").length > 0) {
                   alert ("This column includes a link. It cannot be masked");
                   validCol = false;
                }
            }
        });

        /* Do masking for the column */
        if (validCol) {
            var $sigId=$(this).closest('div.sigcontainer').attr('sigid');
            var $colId=$(this).text();
            var $thCell = $(this);
            var $index = 1;
            /* Copy DX content for update outside DOM */
            var $oldDx = $('#dx-summary');
            var $newDx = $("<div></div>").append($oldDx.html());
            $(this).css('background-color', '#eddea4');
            $(this).attr('mask', 'on');
            /* mask data on all tds on the same column */
            $table.find("tr.tdata").each(function(){
                var $cell = $(this).find('td:nth-child(' + $colNo + ')');
                var $cellVal = $cell.text();
                $thCell.css("background-color", "#eddea4");
                $thCell.attr("mask", "on");
                var $maskedCell = doMask($cellVal);
                $(this).find('td:nth-child(' + $colNo + ')').text($maskedCell);
                $newDx.find('signature[id="' + $sigId + '"]').find('failure[row="' + $index + '"]').find('column[name="' + $colId + '"]').text("***MASKED***");
                $index++;
            });
            /* Update DX content depending on tag type */
            if ($oldDx.is("script")) {
                $oldDx.text($newDx.html());
            } else {
                $oldDx.html($newDx.html());
            }
        }
    });
}



/* Event handlers for exporting data */
function registerExportHandlers() {
    /* Check All / Uncheck All*/
    $("#exportAll").on("click", function(){
        if ($(this).is(":checked")) {
            $(".exportcheck").prop("checked", true);
        } else {
            $(".exportcheck").prop("checked", false);
        }
    });

    /* If parent is checked, check all its children*/
    $(".exportcheck").on("click", function(){
        if ($(this).is(":checked")) {
            $(this).closest(".sigcontainer").find(".exportcheck").prop("checked", true);
        } else {
            $(this).closest(".sigcontainer").find(".exportcheck").prop("checked", false);
        }
    });
}

/* Event handlers for sorting data */
function registerSortHandlers() {
   /* enable sorting (and disable masking if enabled) */
   $(".sort_ico").on('click', function(){
      var tableName = $(this).attr("table-name");
      $("#restable_" + tableName).tablesorter();
      $(this).hide();
      var $maskDiv=$('div#' + tableName).find('span.mask');
      disableMask($maskDiv);

      /* EBSAF-202 Force rebuild of floating header */
      removeFloatingHeader("restable_" + tableName);
      buildFloatingHeader("restable_" + tableName);
   });
}

/* Register event handlers for hidden data within signatures */
function registerHideHandlers() {
    /* Add attributes to data cells */
    var $hiddenDataCells = $("td.hidden_data_parent");
    $hiddenDataCells.each(function() {
        if ($(this).children("span.hidden_data[hide-type='err']").length > 0) {
            /* Error type formatting */
            $(this).attr("hide-type","err");
        } else {
            /* Warning type formatting */
            $(this).attr("hide-type","wrn");
        }
    });

    /* Add attributes to signatures */
    var $hiddenDataSigs = $hiddenDataCells.closest("div.signature");
    $hiddenDataSigs.each(function() {
        $(this).addClass("hidden_data_parent").attr("hide-type","sig");
    });

    /* Add signature level icons */
    var $hiddenDataTitles = $hiddenDataSigs.children("div.divItemTitle");
    $hiddenDataTitles.each(function() {
        var $toggleHideButton = $(this).children("span.hidden_ico");
        if ($toggleHideButton.length == 0) {
            /* Add button if it doesn't already exist */
            $toggleHideButton = $("<span class='detailsmall hidden_ico' title='Toggle Hidden Data' alt='Hidden Data'><span>");
            $(this).append($toggleHideButton);
        }
        $toggleHideButton.click(toggleHiddenData);
    });

    /* Add section level icon */
    var $sectionIcons = $("div.expcoll");
    var $toggleSigsButton = $sectionIcons.children("span.hidden_ico");
    if ($toggleSigsButton.length == 0) {
        /* Add button if it doesn't already exist */
        $toggleSigsButton = $("<a id='hiddensigs' class='detailsmall print data analysis fullsection' href='javascript:;'>" +
            " <span class='hidden_ico' title='Show only tables with hidden data' alt='Signatures with Hidden Data'>" +
            "</span> </a>");
        $sectionIcons.append("&nbsp;&nbsp;",$toggleSigsButton);
    }
    $toggleSigsButton.click(toggleHiddenSigs);
}

/* Event handler to toggle hidden data within a signature */
function toggleHiddenData() {
    $parentSig = $(this).closest("div.sigcontainer");
    if ( $(this).attr("shown") == "true") {
        hideSigHiddenData($parentSig);
    } else {
        showSigHiddenData($parentSig);
    }
}

/* Hide all hidden data within a signature and update icon */
function hideSigHiddenData($sig) {
    if ($sig.hasClass("hidden_data_parent") && $sig.attr("hide-type") == "sig" ) {
        var $hiddenDataCells = $sig.find("td.hidden_data_parent");
        $hiddenDataCells.each(function() {
            $(this).removeClass("hidden_data_parent_err hidden_data_parent_wrn");
            $(this).children("span.hidden_data").hide();
        });
        $sig.find("span.hidden_ico").removeAttr("shown");
    }
}

/* Show all hidden data within a signature and update icon */
function showSigHiddenData($sig) {
    if ($sig.hasClass("hidden_data_parent") && $sig.attr("hide-type") == "sig" ) {
        var $hiddenDataCells = $sig.find("td.hidden_data_parent");
        $hiddenDataCells.each(function() {
            if ($(this).attr("hide-type") == "err") {
                /* Error type hidden data found */
                $(this).addClass("hidden_data_parent_err");
            } else {
                /* Warning type hidden data assumed */
                $(this).addClass("hidden_data_parent_wrn");
            }
            $(this).children("span.hidden_data").show();
        });
        $sig.find("span.hidden_ico").attr("shown","true");
    }
}

/* Event handler to toggle signatures with hidden data */
function toggleHiddenSigs() {
    /* Check if signatures are temporarily hidden */
    var $sectionHideIcon = $("#hiddensigs > span.hidden_ico");
    var $signatureList = $("div.signature[temp-filter-hidden]");
    if ($sectionHideIcon.attr("shown") || $signatureList.length > 0) {
        /* Restore hidden signatures */
        $signatureList.removeAttr("temp-filter-hidden").show();
        $(this).children("span.hidden_ico").removeAttr("shown");
        $sectionHideIcon.attr("title","Show only tables with hidden data");
        /* Disable hidden data */
        $signatureList = $("div.signature[hide-type='sig']:visible");
        $signatureList.each(function() {
            hideSigHiddenData($(this));
        });
    } else {
        /* Hide signatures without hidden data */
        $signatureList = $("div.signature[hide-type!='sig']:visible");
        $signatureList.attr("temp-filter-hidden","true").hide();
        $(this).children("span.hidden_ico").attr("shown","true");
        $sectionHideIcon.attr("title","Restore hidden tables");
        /* Enable hidden data */
        $signatureList = $("div.signature[hide-type='sig']:visible");
        $signatureList.each(function() {
            showSigHiddenData($(this));
        });
    }
}

/* Reset state of all signatures with hidden data and icons */
function resetHiddenDataSigs() {
    /* Restore all hidden signatures */
    $("div.signature[temp-filter-hidden]").removeAttr("temp-filter-hidden").show();

    /* Reset all hidden data icons*/
    $("span.hidden_ico").removeAttr("shown");

    /* Disable all hidden data */
    $("div.signature[hide-type='sig']").each(function() {
        hideSigHiddenData($(this));
    });

    /* Update the section level icon tooltip */
    $("#hiddensigs > span.hidden_ico").attr("title","Show only tables with hidden data");

    /* Hide section level icon if not needed */
    if ( $("div.signature[hide-type='sig']:visible").length == 0 ) {
        $("#hiddensigs").hide();
    }
}

/* EBSAF-202 Build the floating header for a signature.
    The floating header is used to maintain table column widths when the
    persistent header undocks during scrolling.  It gets hidden when the
    persistent header is docked again. */
function buildFloatingHeader(tableId) {
    var $dataTable = $("#"+tableId);
    /* Only build for "parea" tables */
    if ($dataTable.hasClass("parea") ) {
        var $persistHeader = $("thead.pheader", $dataTable);
        /* Only build if persistent header is actually shown */
        if ($persistHeader.width() > 0) {
            var resizeRequired = false;
            var $floatingHeader = $("thead.floatingHeader", $dataTable);
            /* Only build floating if not already present */
            if ($floatingHeader.length == 0) {
                $floatingHeader = $persistHeader.clone();
                $floatingHeader.addClass("floatingHeader");
                $floatingHeader.removeClass("pheader"); /* EBSAF-257 */
                $floatingHeader.width("auto");
                $floatingHeader.find("th").width("auto");
                /* Docking state should be opposite */
                if ($floatingHeader.attr("undocked") == "true") {
                    $floatingHeader.removeAttr("undocked");
                    $floatingHeader.attr("docked", "true");
                }
                $persistHeader.after($floatingHeader);
                resizeRequired = true;
            }

            /* Reset width of persistent header to static values */
            if (resizeRequired) {
                if ($persistHeader.attr("undocked") == "true") {
                    /* Use calculated width of docked floating header */
                    $persistHeader.width( $floatingHeader.width() );
                    $persistHeader.find("th").width(function (i, val) {
                        return $floatingHeader.find("th").eq(i).width();
                    });
                } else {
                    /* Use calculated width of docked persistent header */
                    $persistHeader.width("auto");
                    $persistHeader.find("th").width("auto");
                    $persistHeader.width( $persistHeader.width() );
                    $persistHeader.find("th").width(function (i, val) {
                        return $persistHeader.find("th").eq(i).width();
                    });
                }
            }
        }
    }
}
function removeFloatingHeader(tableId) {
    var $dataTable = $("#"+tableId);
    /* Only built for "parea" tables */
    if ($dataTable.hasClass("parea") ) {
        $("thead.floatingHeader", $dataTable).remove();
    }
}

/* Build the full section menu for signature filtering if not saved */
function buildSectionMenu() {
    if ($("#sectionmenu").children().length == 0) {
        /* Identify all top level named signatures */
        $(".sigcontainer[sigid][level='1']").each(function() {
            /* Get final signature results after checking children */
            var resultClasses = $(this).find("div.sigrescode[level='1']:last-child").attr("class");
            /* Strip out result classes and add the button class */
            var buttonClasses = resultClasses.replace("sigrescode","sectionbutton data");
            /* Get ID for the link */
            var sigId = $(this).attr("id");
            /* Get button title */
            var sigTitle = $(this).find("td.divItemTitlet").html();
            /* EBSAF-251 - add word wrap hints */
            sigTitle = sigTitle.replace(/_/g,"_&#8203;");

            /* Get the icon to show before the title based on result code class */
            /* Information status returns "info_small" class incase an icon is configured later */
            var resultIcon = "info_small";  /* Default value */
            var resultCode = resultClasses.match(/\b\w\b/)
            if (resultCode) {
                switch(resultCode[0]) {
                    case "E": resultIcon = "error_small"; break;
                    case "W": resultIcon = "warning_small"; break;
                    case "S": resultIcon = "success_small"; break;
                    case "I": resultIcon = "info_small"; break;
                    default: resultIcon = "info_small";
                }
            }
            /* Combine results */
            var sectionButton = '<div class="' + buttonClasses +'" open-sig="' + sigId + '">' +
                            '<span class="' + resultIcon +'"></span>' +
                            '<span style="padding:5px;">' + sigTitle + '</span></div>';
            $("#sectionmenu").append(sectionButton);
        });
    }
}

/* Build the main menu if not saved */
function buildMainMenu() {
    if ($("#menu-tiles").length == 0 || $("#menu-tiles td").length > 0) {
        return;
    }

    /* Initialize execution summary counts */
    var summaryCount = {};
    summaryCount.E = 0;
    summaryCount.W = 0;
    summaryCount.S = 0;
    summaryCount.I = 0;
    summaryCount.P = 0;

    /* Gather details */
    var tileDetails = [];
    $(".sectiongroup").each(function() {
        var $section = $(this);
        var tileDetail = {};
        tileDetail.id = $section.attr("section-id");
        tileDetail.title = $section.attr("section-title");
        tileDetail.E = 0;
        tileDetail.W = 0;
        tileDetail.S = 0;
        tileDetail.I = 0;

        /* Count printed signatures */
        $section.find(".sigcontainer.signature[sigid][level='1']").each(function() {
            var $sig = $(this);
            var sigId = $sig.attr("id");
            var resultClasses = $sig.find("div.sigrescode[level='1']:last-child").attr("class").split(" ");
            var resultCode = resultClasses[resultClasses.length - 1];
            tileDetail[resultCode]++;
            summaryCount[resultCode]++;
        });

        /* Count background checks */
        summaryCount.P += $section.find(".sigcontainer.signature.p[level='1']").length;
`' || 
q'`
        /* Build Tile HTML */
        var tileHtml = '<td><a href="javascript:void(0)" class="blacklink">';
        tileHtml += ('<div class="floating-box" open-section="' + tileDetail.id + '">');
        tileHtml += ('<div class="textbox">' + tileDetail.title + '</div>');
        tileHtml += ('<div id="' + tileDetail.id + 'Count" class="counterbox">');
        if (tileDetail.E + tileDetail.W + tileDetail.S + tileDetail.I > 0) {
            /* Status counters */
            if (tileDetail.E > 0) {
                tileHtml += ('<div class="counternumber">' + tileDetail.E + '</div>');
                tileHtml += ('<span class="error_ico icon"></span>&nbsp;');
            }
            if (tileDetail.W > 0) {
                tileHtml += ('<div class="counternumber">' + tileDetail.W + '</div>');
                tileHtml += ('<span class="warn_ico icon"></span>&nbsp;');
            }
            if (tileDetail.S > 0) {
                tileHtml += ('<div class="counternumber">' + tileDetail.S + '</div>');
                tileHtml += ('<span class="success_ico icon"></span>&nbsp;');
            }
            if (tileDetail.I > 0) {
                tileHtml += ('<div class="counternumber">' + tileDetail.I + '</div>');
                tileHtml += ('<span class="information_ico icon"></span>&nbsp;');
            }
        } else {
            /* Executed, nothing to report */
            tileHtml += ('<span class="menubox_subtitle">Executed, nothing to report</span>');
        }
        tileHtml += ('</div>');
        tileHtml += ('</div>');
        tileHtml += ('</a></td>');

        tileDetail.element = tileHtml;
        tileDetails.push(tileDetail);
    });

    /* Build Tiles */
    var tileCount = 0;
    var tilesHtml = "<tr>";
    for (t=0; t < tileDetails.length; t++) {
        if (tileCount == 3) {
            tilesHtml += "</tr><tr>";
            tileCount = 0;
        }
        tilesHtml += tileDetails[t].element;
        tileCount++;
    }
    tilesHtml += "</tr>";
    $("#menu-tiles").html(tilesHtml);

    /* Update execution summary counts */
    $("#summary-count-e").html(summaryCount.E);
    $("#summary-count-w").html(summaryCount.W);
    $("#summary-count-s").html(summaryCount.S);
    $("#summary-count-i").html(summaryCount.I);
    $("#summary-count-p").html(summaryCount.P);
}

/* Add Exceptions */
function showExceptions() {
    if ($("#summary-count-x").length > 0) {
        return;
    }
    
    /* Count root exceptions */
    var exCount = $(".sigcontainer.signature.X[level='1']").length;
    
    /* Create summary row */
    if (exCount > 0) {
        var entryHtml  = '<tr>';

        /* Exceptions are internal only on live frameworks */
        const fmwk = $(".popup[data-popup='popup-1'] .popup-paramname:contains('Framework Version') + td").text();
        if (!fmwk.startsWith("TEST")) {
            entryHtml = '<tr class="internal">';
            $(".sigcontainer.signature.X[level='1']").addClass("internal");
        }
        entryHtml += ('<td><div open-sig-class="exception" class="menuboxitem">');
        entryHtml += ('<span class="error_ico icon"></span>');
        entryHtml += ('<div class="mboxelem" title="List of signatures that failed to execute. Please report issues using thumbs down with comments.">Exceptions Occurred</div>');
        entryHtml += ('</div></td>');
        entryHtml += ('<td align="right"><span id="summary-count-x" class="errcount">'+exCount+'</span></td></tr>');
        $(".menubox").height("auto");
        $(".mboxinner").append(entryHtml);
    }
}

/* EBSAF-260 Fix anchor URLs */
function fixAnchorUrls() {
    var $backTop = $(".backtop a[href*='#']");
    if ($backTop.length > 0) {
        var baseUrl = $backTop.attr("href").replace("#top","");
        if (baseUrl != "") {
            var oldUrl, newUrl;
            $("a[href*='#']").each( function() {
                oldUrl = $(this).attr("href");
                newUrl = oldUrl.replace(baseUrl, "");
                $(this).attr("href", newUrl);
            });
        }
    }
}

/* EBSAF-295 Highlight all cells of failed rows */
function updateFailRows() {
    $("td.hlt").parent().addClass("hlt");
}

/* Updates functionality specific to internal viewer */
function updateInternalViewer() {
    if (/*Location is AC, Analysis Center MOSFS*/
        window.location.href.indexOf("/ISDE/sr/") >= 0) {

        /*EBSAF-401 Hide Feedback button in AC*/
        $("#feedback").hide()

        /* EBSAF-402 - Disable Buttons only in Analysis Center: Copy SQL, Export to txt, Export to cvs*/
        disableExport();

		// EBSAF-398 - Latest available for download icon not working in MOSFS - Replace the webfolder latest version with static one 
		$('img.header_version')
		.closest('a[href^="https://support.oracle.com/support/?kmContentId="]')
		.each(function () {
			const $a = $(this);
			const href = $a.attr('href');
			// Capture the full kmContentId value (up to & or end)
			const match = href.match(/kmContentId=([^&#]+)/);
			if (!match) return;
			const docId = match[1]; // e.g., "123456", "123456.1", etc.
			const $newA = $(
			  '<a href="https://fa-etmi-saasfaprod1.fa.ocs.oraclecloud.com/fscmUI/redwood/myknowledge/content/container/main/article?answerId=' +
			  docId +
			  '" target="_blank" title="Click here to download the latest version of Analyzer">' +
			  '<span class="latest_version_ico" title="Click here to download the latest version"></span>' +
			  '</a>'
			);
			$a.replaceWith($newA);
		});

		//Extract SR from the current Analysis Center URL
		const srMatch = window.location.pathname.match(/\/sr\/([34]-\d{7,12})(?:\/|$)/i);
		const FEEDBACK_SR = srMatch ? srMatch[1] : "";

		 // Replace SR number in every link that has data-sr-href (template containing {SR})
		document.querySelectorAll('[data-sr-href]').forEach(a => {
			const template = a.getAttribute('data-sr-href') || '';

				if (FEEDBACK_SR) {
					// Build final URL
					const href = template.replaceAll('{SR}', encodeURIComponent(FEEDBACK_SR));
					a.href = encodeURI(href);

					// REMOVE "internal" class so the button shows up
					a.classList.remove('internal');
				}
		});

        /* Redirect links to Agent Portal*/
        $('a[href^="https://support.oracle.com/support"]').each(function () {
            oldUrl = $(this).attr("href");
            newUrl = oldUrl.replace('https://support.oracle.com/support/?kmContentId=', 'https://fa-etmi-saasfaprod1.fa.ocs.oraclecloud.com/fscmUI/redwood/myknowledge/content/container/main/article?answerId=');
            $(this).attr("href", newUrl);
        });

		/* Redirect patches links */
        $('a[href^="https://support.oracle.com/epmos"]').each( function() {
            oldUrl = $(this).attr("href");
            newUrl = oldUrl.replace('https://support.oracle.com/epmos', 'https://mosemp.us.oracle.com/epmos');
            $(this).attr("href", newUrl);
        });

		/* Adding a visual that a link has been clicked: change color and add underline*/
		document.addEventListener("click", function (e) {
			const link = e.target.closest('a[target="_blank"][href^="https://fa-etmi-saasfaprod1"]');
			if (!link) return;

			link.classList.add("clicked-link");
		}); 
        return;
}
    if (window.location.href.indexOf("oracle.com/iss/") >= 0 ||
        window.location.href.indexOf("oracle.com/collectionviewer/") >= 0 ||
        window.location.href.indexOf("oracle.com/ui/broker/viewer/") >= 0
    ) {
        /* EBSAF-298 Redirect feedback */
        $("div#feedback").attr("title", "Provide feedback on this analyzer");
        $("div#feedback").find("a.blacklink").attr("href", "https://mosemp.us.oracle.com/epmos/faces/DocumentDisplay?id=1618885.1#feedback");

        /* Redirect links */
        $('a[href^="https://support.oracle.com/"]').each( function() {
            oldUrl = $(this).attr("href");
            newUrl = oldUrl.replace('https://support.oracle.com/', 'https://mosemp.us.oracle.com/');
            $(this).attr("href", newUrl);
        });

        /* EBSAF-287 Disable export if needed */
        var p = window.location.pathname.split("/").slice(-1);
        var h = window.parent.document.getElementsByClassName("af_panelHeader_title-table2");
        for (t=0; t < h.length; t++) {
            var i = h[t].querySelectorAll("img[src$='policyentitlement_qualifier.png']");
            if (i.length > 0) {
                disableExport();
            }
        }
        if (window.parent.document.getElementById("dcac-restricted-icon") &&
            window.parent.document.getElementById("dcac-restricted-icon").style.display != "none"
        ) {
            disableExport();
        }

        /* Enable internal items */
        $(".internal").attr("data-internal", "true");
    } else if(window.location.href.match(/\banalysiscenter\b[^/]+\.oracle(corp)?\.com/)) {
        /* Disable export and internal items */
        disableExport();
        $(".internal[data-internal]").removeAttr("data-internal");
    } else {
        /* Disable internal items */
        $(".internal[data-internal]").removeAttr("data-internal");
    }
}

function enableMask(maskDiv){
   maskDiv.addClass('mask_enabled');
   maskDiv.removeClass('mask_disabled');
}

function disableMask(maskDiv){
   maskDiv.addClass('mask_disabled');
   maskDiv.removeClass('mask_enabled');
}

function switchMask(sig) {
    var $maskDiv=$('div#' + sig).find('span.mask');
    var $enableMasking = $maskDiv.hasClass('mask_disabled') ? true : false;

    if ($enableMasking == true ){
        if ((MASK_KEY == null) || (MASK_KEY == '')){
            /* Get numeric mask key */
            alert ('To enable masking for a particular column, please click on the column header.\n\nPlease note!\nOnce data masking is complete, you must SAVE the file as "Web Page, Complete", otherwise the changes will be lost.');
            var maskKeyEntered;
            do {
                maskKeyEntered = prompt("Please enter a masking key (numeric):");
                if (maskKeyEntered == '' || maskKeyEntered == null) {
                    /* Cancel mask attempt */
                    return;
                } else {
                    maskKeyEntered = parseInt(maskKeyEntered);
                    if ( isNaN(maskKeyEntered) ) {
                        alert('Invalid mask key entered.');
                    } else {
                        MASK_KEY = maskKeyEntered;
                    }
                }
            } while ( isNaN(maskKeyEntered) );
        }
        enableMask($maskDiv);
        /* disable table sorting */
        $('#restable_' + sig).trigger('destroy');
        $('div#' + sig).find('a.enablesort').children('.sort_ico').show();
    } else {
        disableMask($maskDiv);
    }
}

function doMask(text){
    var maskInt = parseInt(MASK_KEY);
    if ( MASK_KEY == null || MASK_KEY == '' || isNaN(maskInt) ) {
        /* Return unmodified text if invalid mask key */
        return text;
    }
    var chars = text.split('');
    for (var i = 0; i < chars.length; i++) {
        var ch = chars[i].charCodeAt(0);
        if (ch <= 126) {
          chars[i] = String.fromCharCode((chars[i].charCodeAt(0) + maskInt) % 126);
        }
    }
    var scrambledText = chars.join('');
    return scrambledText;
}

function copySql(id) {
    let sql = $("#" + id).text().trim();
    copyTextToClipboard(sql);
}

/* Copy to clipboard function from example: https://stackoverflow.com/questions/400212/how-do-i-copy-to-the-clipboard-in-javascript */
function copyTextToClipboard(text) {
    if (!navigator.clipboard) {
        fallbackCopyTextToClipboard(text);
        return;
    }
    navigator.clipboard.writeText(text).then(function () {
        console.log('Async: Copying to clipboard was successful!');
    }, function (err) {
        console.error('Async: Could not copy text: ', err);
    });
}
function fallbackCopyTextToClipboard(text) {
    var textArea = document.createElement("textarea");
    textArea.value = text;

    // Avoid scrolling to bottom
    textArea.style.top = "0";
    textArea.style.left = "0";
    textArea.style.position = "fixed";

    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
        var successful = document.execCommand('copy');
        var msg = successful ? 'successful' : 'unsuccessful';
        console.log('Fallback: Copying text command was ' + msg);
    } catch (err) {
        console.error('Fallback: Oops, unable to copy', err);
    }

    document.body.removeChild(textArea);
}

/* EBSAF-287 Disable export functionality */
function disableExport() {
    DISABLE_EXPORT = true;
    $("a span[class^='export_'], a span.copysql_ico")
        .css("opacity",0.25)
        .removeAttr("title")
		.attr("title","Export is currently disabled")
        .parent()
            .css("cursor","not-allowed")
            .attr("title","Export is currently disabled");
}

function getExportName(id) {
    let name = 'data';
    if ('ALL' !== id && 'DEV' !== id) {
        // Find signature or section by ID
        let sigName = $("#"+id+".sigcontainer").find(".divItemTitlet:first").text();
        let secName = $(".floating-box[open-section='"+id+"']").find(".textbox:first").text();
        if (sigName) {
            name = sigName;
        } else if (secName) {
            name = secName;
        }
        // Filter title characters, truncate, and trim
        name = name.replace(/\W+/g, '_').replace(/^_/, '').substring(0,40).replace(/_$/, '');
    }
    return "Analyzer_export_" + name;
}

function export2CSV(name, type) {
  if (DISABLE_EXPORT) {return;} /* EBSAF-287 */

  var $records;

  /* if section param has a value, export all section*/
  if (type == "section"){
      if ((name != null) && (name != "")) {
          $records = $(".data.sigcontainer."+name).find(".exportcheck");
      }
  } else {
      /* if no particular table was provided as parameter, export all selected tables on the page*/
      if ((name == "ALL") || (name == null) || (name == "")){
        if ($(".exportcheck:checkbox:checked").length == 0) {
          return;
        } else {
          $records = $(".exportcheck:checkbox:checked");
        }
      } else {
        $records = $(".data.sigcontainer."+name).find(".exportcheck");
      }
  }

  var csv = '"';
  $records.each(function(){

    var $rows = $("tr." + $(this).attr("rowid"));
    var level = $($("#" + $(this).attr("rowid"))).attr("level");

    tmpColDelim = String.fromCharCode(11),
    tmpRowDelim = String.fromCharCode(0),

    colDelim = '","',
    rowDelim = '"\r\n"';

/*CG comment    csv += rowDelim + $($("#" + $(this).attr("rowid")).find("div.sigdescription")).find("td").text() + rowDelim;*/
    csv += $rows.map(function (i, row) {
                            var $row = $(row);
                            if ($row.parent().hasClass("floatingHeader")) return; /* Fix the double headers bug EBSAF-197 */
                            var $cols = $row.find('td,th');

                         return $cols.map(function (j, col) {
                                       var $col = $(col);
                                       var $text = $col.text();
                                       return $text.replace(/"/g, '""').trim(); /* escape double quotes, trim leading and trailing blacks to avoid Excel misreading them  */
            }).get().join(tmpColDelim);
        }).get().join(tmpRowDelim)
            .split(tmpRowDelim).join(rowDelim)
            .split(tmpColDelim).join(colDelim) + rowDelim + rowDelim;

   });

   csv += '"';
   var blob = new Blob([csv], {type: "text/csv;charset=utf-8;"});

   if (window.navigator.msSaveOrOpenBlob)
       window.navigator.msSaveBlob(blob, getExportName(name) + ".csv");
   else
   {
       var a = window.document.createElement("a");
       a.href = window.URL.createObjectURL(blob, {type: "text/plain"});
       a.download = getExportName(name) + ".csv";
       document.body.appendChild(a);
       a.click();
       document.body.removeChild(a);
   }

}

/* Function to quickly repeat a string for indenting */
String.prototype.repeat = function(n) {
   return (new Array(n + 1)).join(this);
};

function export2PaddedText(section, level) {
  if (DISABLE_EXPORT) {return;} /* EBSAF-287 */


 /* export a full section - the section id is passed as parameter. If null, then return.*/
   if ((section == null) || (section ==''))
       return;

    var text =  buildExportText(section, level);

    var blob = new Blob([text], {type: "text/csv;charset=utf-8;"});

    if (window.navigator.msSaveOrOpenBlob)
        window.navigator.msSaveBlob(blob, getExportName(section) + ".txt");
    else
    {
        var a = window.document.createElement("a");
        a.href = window.URL.createObjectURL(blob, {type: "text/plain"});
        a.download = getExportName(section) + ".txt";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }
}

function buildExportText(section, $level) {
   var text = '';
   var $records = $('.signature.'+section);
   var INDENT = '    ';

   if ($level == null) $level = 0;

   /*if no signatures in the section, nothing to do. Return.*/
   if ($records.length < 0) return;

   /* define array for col max length */
   var maxlen = [];

   /* parse all rows once and gather the max length for each column in each table (first columns, second columns etc). Populate maxlen array.   */
   var $rows = $('tr.'+section);
   $rows.each(function(){
      /* skip if this is a sig title row or if it is a floating header*/
      if (($(this).hasClass('sigtitle')) || ($(this).parent().hasClass('floatingHeader'))) return;
      $currrow = $(this);
      var counter = 0;
      $currrow.find("td,th").each(function(){
          if (($(this).text().length > maxlen[counter]) || (typeof maxlen[counter] == "undefined")) {
              maxlen[counter] = $(this).text().length;
          }
          counter++;
      });
   });

   colDelim = ' ',
   rowDelim = '\r\n' + INDENT.repeat($level-1);

   text = '';

   $rows.each(function(){

      if ($(this).parent().hasClass("floatingHeader")) return;
      if ($(this).hasClass("sigtitle")) {
           var title = $(this).find("td").text();
           text += rowDelim + rowDelim + rowDelim + title + rowDelim + "_".repeat(title.length) + rowDelim + rowDelim;
           return;
      }

      $cols = $(this).find('td,th');

      text += $cols.map(function (j, col) {
         var $col = $(col);
         var text = $col.text() + " ".repeat(maxlen[j] - $col.text().length + 1);
         return text;
      }).get().join(colDelim);

      text += rowDelim;

    });

    /* if this is not a section (level is 1 or more), try to go recursive */
    if ($level > 0){
         $level++;
         var $children = $(".sigcontainer." + section + "[level='" + $level + "']");

         if ($children.length == 0) return text;

         /* if there are children, get their IDs in a unique list and call yourself with the sigid and level */
         var $uniqueChildren = {};

         $children.each(function(){
             $uniqueChildren[$(this).attr("id")] = 1;
         });

         Object.keys($uniqueChildren).forEach(function($child){
               text += buildExportText($child, $level);
         });

    }

    return text;
}

function export2HTML() {
  if (DISABLE_EXPORT) {return;} /* EBSAF-287 */

   var i = 0;
   var $signatures = $("div.signature");

   /*if no signatures return */
   if ($signatures.length < 0) return;

   rowDelim = "\r\n";

   var text = "";
   var header = "<html><head><title>Data export</title></head><body style='background=\"#ffffff\";color:#336699;font-family=arial;'>";

   var params = "<br><br><table align='center' cellspacing='1' cellpadding='1' border='1'><thead><tr bgcolor='#cccc99'><th><i>The test was run with the following parameters </i></th><th></th></tr></thead><tbody>";

   var $paramDiv = $("div.popup[data-popup='popup-2']");
   var $paramRecords = $paramDiv.find("td.popup-paramname");

   $paramRecords.each(function(){
       var paramName = $(this).text();
       var paramValue = $(this).closest("tr").find("td.popup-paramval").text();

       params += "<tr bgcolor='#f4f4e4'><td width='50%'>" + paramName + "</td><td width='50%'>" + paramValue + "</td></tr>";

   });


   params += "</tbody></table><br><br>";

   var indexTbl = "<br><br><table align='center' cellspacing='1' cellpadding='1' border='1'><thead><tr bgcolor='#cccc99'><th colspan=2><i>INDEX FOR MAJOR TABLES DIRECT ACCESS</i></th></tr></thead><tbody><tr bgcolor='#f4f4e4'>";

   $signatures.each(function(){
       var sigId = $(this).attr("id");
       var level = $(this).attr("level");
       var title = $(this).children("div.divItemTitle").find("td.divItemTitlet").text();

       if (level > 1) {
          text += "<blockquote>";
       } else {
           indexTbl += "<td width='50%'><a href='#" + sigId + "'>" + title + "</a></td>";
           i++;
           if (i % 2 == 0) {
               indexTbl += "</tr><tr bgcolor='#f4f4e4'>";
           }
       }
       text += "<br><br><b>";
       text += "<a id='" + sigId + "'>" + title + "</a>";
       text += "</b><br><br><table width='100%' cellspacing='1' cellpadding='1' border='1'>";

       var $rows = $(this).find('table.tabledata').find('tr.' + sigId);

       $rows.each(function(){
          if ($(this).hasClass("tdata")) {
             text += "<tr bgcolor='#f7f7e7'>" + $(this).html() + "</tr>";
          } else {
             /*replace background color for the header*/
             text += "<tr bgcolor='#f7f7e7'>" + $(this).html().replace(/\#f2f4f7/g, "#cccc99") + "</tr>";
          }
       });

      text += "</table>" + rowDelim;
       if (level > 1) {
          text += "</blockquote>";
       }
   });

   if (i % 2 == 1) {
       indexTbl += "</td><td></td></tr>";
   }

   indexTbl += "</tbody></table><br><br>";
   text = header + params + indexTbl + text;
   text += "</body></html>";

   var blob = new Blob([text], {type: "text/csv;charset=utf-8;"});

   if (window.navigator.msSaveOrOpenBlob)
       window.navigator.msSaveBlob(blob, getExportName('DEV') + ".htm");
   else
   {
       var a = window.document.createElement("a");
       a.href = window.URL.createObjectURL(blob, {type: "text/plain"});
       a.download = getExportName('DEV') + ".htm";
       document.body.appendChild(a);
       a.click();
       document.body.removeChild(a);
   }
}

//Adding the ability to click to select rows for visibility on scrollig right in a table
function enableRowSelection() {
   document.querySelectorAll(`.table1 tr.tdata`).forEach(function(row) {
       row.addEventListener('click', function() {
       // Toggle 'selected' class on clicked row
       row.classList.toggle('selected');
       });
  });
}

//Adding the ability to deselect all highlighted rows
function clearSelectedRows(id) {
	const table = document.getElementById(id);
    if (!table) return;
    table.querySelectorAll(`tr.tdata.selected`).forEach(function(row) {
        row.classList.remove('selected');
    });
}

//Adding the ability to select all rows
function selectAllRows(id) {
    const table = document.getElementById(id);
    if (!table) return;

    table.querySelectorAll('tr.tdata').forEach(function(row) {
        row.classList.add('selected');
    });
}

//Adding the buttons to each table
function addRowSelectionButtons() {
    $(".divItemTitle").each(function () {
        const $container = $(this).closest(".data.sigcontainer");
        const toggleId = $container.find("table.table1").attr("id");
        if (!toggleId || !toggleId.startsWith("tbitm_")) return;

        const restableId = toggleId.replace("tbitm_", "restable_");
        const $targetTable = $("#" + restableId);
        if ($targetTable.length === 0 || $targetTable.find("tr.tdata").length === 0) return;

        // Prevent duplicates
        if ($(this).find(".select_all_rows").length > 0) return;

        // Create the select buttons
        const selectBtn = $('<a class="detailsmall" href="javascript:;" onclick="selectAllRows(\'' + restableId + '\')"><span class="select_all_rows" title="Select All Rows" ></span></a>');
		
		// Create the deselect buttons
        const deselectBtn = $('<a class="detailsmall" href="javascript:;" onclick="clearSelectedRows(\'' + restableId + '\')"><span class="deselect_all_rows" title="Deselect All Rows"></span></a>');

        // Append buttons into the current .divItemTitle
        $(this).append(selectBtn).append(deselectBtn);
    });
}

function getCurrentDate() {
    let e = new Date;
    return `${(e.getUTCMonth() + 1).toString()}/${e.getUTCDate().toString()}/${e.getUTCFullYear().toString()}`
}

function getDisplayName(e) {
    try {
        if (e) {
            return $(`.internal[onclick='postIdea(${e});']`).first().closest(".divItemTitle").find(".divItemTitlet").text()
        }
        return $(".header_title").text().match("(.*Analyzer) Report")[1]
    } catch {
        return e ? `Signature ID ${e}` : `Analyzer ID ${FEEDBACK_AZR}`
    }
}`';
    print_out('<SCRIPT type="text/javascript">');
    print_clob(l_html_clob);
    print_out('</SCRIPT>');

    print_out('<!-- HOTFIX -->');
    print_out('<SCRIPT type="text/javascript" src="https://www.oracle.com/webfolder/s/analyzer/hotfix.js"></SCRIPT>');
    print_out('<LINK rel="stylesheet" href="https://www.oracle.com/webfolder/s/analyzer/hotfix.css">');

    print_out('<!-- FEEDBACK -->');
    print_out('<SCRIPT type="text/javascript" src="https://www.oracle.com/webfolder/s/analyzer/feedback.js"></SCRIPT>');
    print_out('<LINK rel="stylesheet" href="https://www.oracle.com/webfolder/s/analyzer/feedback.css">');

    print_out('</HEAD>');
    print_out('<BODY>');

    dbms_lob.freeTemporary(l_html_clob);
EXCEPTION WHEN OTHERS THEN
    dbms_lob.freeTemporary(l_html_clob);
    print_log('Error in print_page_header: '||sqlerrm);
    raise;
END print_page_header;


----------------------------------------------------------------
-- Prints analyzer header (title and top menu)                --
----------------------------------------------------------------

PROCEDURE print_rep_header(p_analyzer_title varchar2) is
BEGIN

-- page header
    print_out('<!-- page header (always displayed) -->
<div class="pageheader">
    <div class="header_s1">
    ');

    -- Print new logo image (EBSAF-165)
    print_out('        <div class="header_img">');
    print_out('<img src="data:image/png;base64,', 'N');
    print_out('iVBORw0KGgoAAAANSUhEUgAAAJYAAAAkCAYAAABrA8OcAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAC4jAAAuIwF4pT92AAAAB3RJTUUH4wEDDQwplQ4B4QAAEpxJREFUeNrtnHmUVNWdxz+1dVd30w+KphtkFRUBBaERcCEo4xZNjHFcGBfioM6JGjNWZlzOcTQx6uiJEhPLJVFjZkziQlrcDZrgceuoaDSNjjpsCiJLi9jVXWD3bbqr3vzxvs++PKqqu4DxJJ6+59Sh+r377rv3d7+/3+/7+/1uAf2tv/W3/vb30kJ7aqBMKrE3UAOEgXbgAyeZNv0i7gdWqUCaDJwJnABMLdDtU+CPwBNOMr2oX9z9wCoGqKnA3cBM6/JqYCXQDHQBCWBf4ACgQn0+By5zkum79tTkjWcd3Ti4geshgOD1AmP02reU8fI8F4pDbhfXV/C9xtq7OLjBv/eAbEPCR0H52u8KzjVUIqh+C3xHf74L3Ag84yTTrQX6h4AZwMXAObr8MXCsk0yv2IXFRoBBwEhghECbK6Iw7cBGYD3QFoesNVYtMFnjufqEiihgF7AWWAdkets8zXUGMAH4CFgah44+rDEODAFGAcP8zS2yxs3ACrz1HCgvsUzrLVURosBAyXakh5OdxnBFd2LAZ8ByoBMYD3QDy+JgQn0AU0gWqAkYDXwCnO8k038oEZR1wJ3Aabo0z0mmHyhh0YOAOcDxwEQJINrLY9uBNPA+8AzQGIetGu9Q4BJgf40T6UXRckAL8BqwMA5v96LtXwfOAw4C1gAP6LnuIs/tC3wD+AdgL2BAkTlFBKJFwOPAyVLe1cB1wPJSLKXx9niO5j0RcCSXUB45RIEy4DFgofBxsPq+FIfXon14Z420tEJc6eRdMa1OMr0ZOD2TSpwGNAD3Z1KJ6r64RgODgX8Sp6uXJnXQu+AiQLksx0Sg1kCDLEe1rEm9rFF7L1YrIgs3CagycFfcA2y+Nho4BThOCjBW831X1iTfGqcB84CT1L9TilHIgpbLGv+P5j1Ga4kClaV4IwN1wOmScW/yDQtUG6QwLZqvo/519EHjAf5XoFrgJNNX7K7vdpLpRZlUYqLG/WUmlVjnJNOLiyw6Zmn/dFnMZ/EsxrYiAnS12KnAEcDREtjHBl7Ac4th9X0ZeB7PmkULWKsE8E3NYS7wkcljFWStjpfVGag5RoBDgBMNrIp7fNN+ZrRAda5c8/t4c1xTxNXH1G+p3GBI6+mmBBco13ssMF9rawYWC7D55BuWjDZKbs0CU43evaqvLmyWuFXR1tDYVCpfm5pJJVx9EkUWPtbAIgNdBjYaWGBgqjhMb0KLGZhh4KcGNhnoNvCggWoDcww0Gdhu4IfG0/Lexppv4H3jkeUHDQzN02+SgWfVZ4WBew0s0d+vGjgy0L/cwIUGPlCf1/WeESWAY6zW2K3np/VFPnp2ouTbqTlca7ygqxRuNtDAQcaz5nu+NTQ2tTQ0NrkNjU0/6iO4/lXAeqkQVzFwqoGVBoyBO41n8ksl/ftog7sMtBuYbOAYA29JoNeIY/Q2zigDTwoATxjPNdr3Bxj4iYEtAuz1BkYb+K6BjIFtBu6Wa/efGWng9xrzYwMX7sL69t4VYBmIGDjLwGrJ4XYD++m6YyBhYFCej3+9whTwGOHdAFE48PcsejZnXh/d4u0y90dkUolZBXjNISKyzcCSuBdhldq2AC8Cm8QPDhAPca0oJ2KgTAKrDnyqDFSJX9VpzA4gkycK/IbcwlLgmbjHT19VPq8KOAo4zvS43H0V/aE5PvYlppvi4pkDlQ4apLzkvyj6P1ufefqcrevzFSyMowCAowUsyQhgs5NMdxWZ1PKGxqYaRSATw+HwGeFQiJybw3UZ19DY9AZwDfBt4J+B0+fOrn86zzhnahOu0qYEucRwEdUtQOsuCrBdaY5PNd4odgSoKzK/j8CTDRBnn2OdKALfpjB7YyDIOU8btR74rcg6wAcKWA7QZpwN','N');
    print_out('/MV4SjVYgANYG/c45JcJrFqBo1oc8ngpWiGeFtW9l4F1haLcaB5QjZTQPsykEgfnA1dDY9MFEhDhcPjW1rYM6zdtprVtK3XDh1NZEacqHpsxqDK+2JrdU/mItpNMv55JJZqBExQlbg0AK6uFRHZDgCE976cUcgHBubo2QpHReCsq80nxIG1CFHgUeDruRZPImp2oKDAq8vtiXBYtDh3GU54ngR+I2J8I3Kt35Iop+v9j89fty7lVhD1cJH8Wk2K9otQGvQIrk0oMFaiqpJl/Ebiydr+5s+vvbmhsujkcDjur165j3fpPiETCuK4Lrsv27izbt2Vpa+9kZI1DOBQCuKnIAhdK4N/Ud9tSrJWZHgIMN14mu9TM8gApgu9yVlkC9T8Z4A2BapzyWz6o29RnhaK1h4C/Wtn/CcAZmuNyheDTRWb9SC2uTWnVPM4B/qwEp2+JJxgYH/fe82W0dlnX7Vrn08BzUqoyyxC4loKGBL5VSjkUB1YmlahVvqrMGmyKws6dooRQKLRmQ/OnUz7euJlIJLyDCnyBipzLhs+2MrrWwXV5qsgCH7I02QZWVppxqjbvHxViLytRgOPFHYYqXbFc7jBkWSTisMF4798OXCBw+dWCBr13pVyAb2XqlA45TOM8KGCdKf7krwO5mxp9n6Sc1cPimduVFjnLwE/9RG4JlsdWxk67ylDEDxrjrWmz9niY3PE7UphwILfnf8/2ptxRgWov8YAyae1M4DJxnqMzqcR7TjJ9oOUK6wmFpqz+8CPfGhEKhV4JhUIXx8rKmpVsux2gO5sl095JdUX5FeJb+ZrPRQ4OLNw1Xr7qz0oAHocXXS0SR/q8D5ZqgtzOUdLEh6WlwwMC88G11nhA7xS4Jgs8MWWz1wRyQNME+AEi6U8JSIfLdZZbrjerSkBcObZTBdaXlZicIVfcYaBRwUa2iHtH1rDaAlccLxLdalEIt8gYbaqqjMVLhTQbz2Wvs+QbtFxh00MrtgEtQSBHLY36HFgg9M4ENjnJ9DGZVGKJ+AUNjU2TgV8Cs1paWsm5rg+s9G2Xnvs1a9w7FjzyQpkLt4RCIbaaLpzK8pMaGpteA26ZO7t+UYBntWdSiXZFJ8H2qTjNCCU5z5K2L5MLKZYgHSyrO0V/Pwf8WpwnavGucADQmwSu7Xjh/zQR85gs2gqBZV9ZnXpZqfvFO9pluVYE6pk+wGoF9gMVXf23SjM1sq5JYLae7yqwRp8DrVKy2FeO4bKWG/sY+b8J/EF7fLQiwpkB+YYCcg0pql4vmabzWiyVW2plva62wmmcZPpYq/+RwCyADtNJqMdaPZZn1U+4cAtANuvTGfdQ4GZgUSaVGAzc4CTTF1ngjmgONwO/cJLptXHIGc9iVSozPkea7ZdiyCN41yKaYSnLS8BvgHestUetgmrQTbQYDyhdwPf0zqTc6X1yj18TL4zI6vwJaJelfV5uPJwnUBisd58DfEvAWCIZzAP2s2qGhcpMEa3rd1rbVvWrU2Ugm8e6BeWTljye1X53aI9nSpm687zftUpKjwPP5YsM80UhWy0+EGwrfQBEozsEaRPzmItRXyTLQjuEGO26nALmZVKJ6U4yPUMT3ZZJJR5WoXqyeBFxL6n5lLTzHbm1Yb2ExX6ks1GE+2lghcWN2izLs5E8wpFle0jW/Fxt+EzRhkYpY6sCjPuBD33uEQfjecu8rc14LnmEXPx+KpLfIU57iqxsVRGLXCarslhuaxnwViD6pRfZrABeiXsJ3ae0jrelvIXk63PSFpXBVhfz03ZkeKrM8nVOMn1NgeToJdlsNvXy0r8SjXrYDIfDl6b+ff7PAH7+yAtDurxa4BAAp7KcwQMq1iiX9Zb1rjfFq3xeh5X3mewk0x35ssUSXFRgjOSpp/k49lMGuSAHUA1ygJ7/HDCFCKmIbKU2MyIQdls1u25gW18Ic6CmWEXP0ZRtcW++WG46pvuFisGd1mmNsPpW5CH0+fbcFfA77HVb8o1Z683leb5L','N');
    print_out('z3b1FVjDRBr/5CTTXy8kmEWvvN363ooPBm5psXKWrrtlr1GjmqOx2KSeSy5j6hKEQ5wzd3b97/K8b5m0EysC289JprfT3/5uWzhPwrJZZu64TCoRK/RgLpfLThw3llgsaru/Ia7r7gCqoYkBhD34Li9Q1plKz9mmj4Cx/aD6CgJL7RH9e3IBV3i1CCiHHjyZ4UNryeZyZLNZXBdyrkssGmH4YIeqcj8txm1FaoZTRULHB5OxeThhNEC8/xZalD34wxSLnJfpE/2qAOtW/XtVgfvPWGbq/nH7jFp/1OHTmT7lAEbWDWJM7SBGDXEoj0WedF03Z1kjioDrHCeZ7izSpU75lpfxirUPqeb2ZQu9zuIxfnsM2HsPviOkFESrKgKv+lH731BL5JFDcWA5yfT7wOvAlEwqMT94XwR8EjB47uz675w2a+qonOveUD2gisryMiLh0Mpczi2fO7v+2yK958+dXX/Gbi5knN55isL+51UmWmhpuH+6sdyyIHHldoZZVQW/VSgyG6ZndhCD7tUE5LREiU0/cICemmIkkLoIBeZShndSo64XhfiNvEWt5r8CuCgwpr2HvsX0rXil1jw4MJeY1jzcD6zygGWk/g1Z4/tRZoU17w+BqyWfyl7Ju0Wqx+rhDqDOSaa3Fdv1hsamA4D39OeVc2fX/6Q3pGRSiYp8kV+BdqislQ2O4/F+0DFNeZ8hirS2Kr1QiXfEwz+P/aIswVa8U5sXKEmZ07079f0gpRfGKtfzmFIWhwL3KCm4HO8c+yZZzj8qx3U48CsrZTMf+C+BYZ7KNl2a35PkL928oM08TbkqG0T7Kd3iH+keqXLSK7Ka++u9Rwjw90hu45V3q9C/YbxfWz0nsMzCOxJTp/TLIt2boHJPVOP7J1bvUYrjGbwjTQ/YkWi4iGtag3ckpkL5kaJt7uz695XsO9Mv5/QCqsuBlZlUYtAuuorBSua14eXMblFVwD+/FcM7PXCKNvohWbjz/CkDx1hW70YrP/YL5eYW4JVwvqUNzCj/02F9x+o/XAL3LdlUjVGpTbtYXHMx8CO8wnW+dqFAejNeecyxuNxJwH9afScAP5ZyHSvFGS15tIu77qU1/ErAXKD80xKlXIZqTp3ADQL+rXhHladJMX6Id6xouNIrOfXfRml1zS8A8KxOeb6ZSSX2CFm2To52ZVKJMSVYLBevWH2trMtbAs6+4l83WP1r8HJpR1nXrlOJqFLlo30EsMsEoKsE1g0UPlH6giyl3db7FQm8n0QdLQt1jzR/oCzar5XBP0QbeWeR9R6m59v03HQp1PeVyPTbHFmR4ySXJwNzXyMr9v08ua0tsqJHyvL6bags6o149d13ZeUI5BqvL5W825breLyfPB0MbJKL3B1QPWBFiJOdZLrUE6EDZRHW4f1861G5v2yA30wSuGzXuVTu0pXr/A9lvsdKAyP0/CopXaSUUlZkfvcC/6b5HCvrUCNN9w/5zZOmvyMOla+9BnxXFqtG1iZaIPHpWknhcICDBftXWevolEWaFKgStOOdAnE0bksBrxEpNP8+RVROMn14JpW4D+8k6IeZVOIO4MreeFcAUGdKQxOyGtOcZHp9iaDqklbmE2ywrRI4ugNWYIu4x11yRynde1VgaBEIquip7tcIeH6xtVj0epss2AxxndcF3E3S/Gvlfqo0Xr6yzwxZ4xxe/fE1ud5Kdi6zdLDzD0u7i8zPX1NWCvKO5msDxHePb9NTwgkqWUzry+2SxbLANV9up11mdWsmlXgkk0qckEklavIAKZ5JJaZkUonrM6lEK161PwHc5yTTdbsAqmDEFVxHdUA4GxV83Cr+cwhwqfhJVtroHwu+QqCrk/v8TBZioHjR7+k5kxYTX9lfAPStgB+ZbdB77xM5RqB6SZHeGAH15+x8FNtv35N1nanI9HG8g4VtckEjFWAcIXfpuz6DVxSfr/XdrnsdFphu1nyvlfV+QlGnI6WoFscbp3u+EgRP8L6Jd8SnFu/YUKhP','N');
    print_out('UWERyxMSJ/lxIMxsl1blNJHqAHAfBS51kum1u+hFq8Wvri9w7zBZmzet63sBlytSi0lwi6S1R8latSqiWaNNWCj3cJF4zVopxWI9N12Ev0YbuAy4UgTXP69+oIKEa+TyEIjPF4nv1KbdJQsabPuo7zGyRK9q7mv13gXiPAvxDgbMAX6mjT5GVvIQvecm8btL1OdavOJ+TErzhpTiCMl3lCLe2/XeiSL8S+Vp/FYruQ3BOx1xtW29ditbnEklZmtCJ4hA+z+c/Byv5teofNMSJ5lO7wHeX0Hh///AB3EuD6eo0wZ9zI6F4lEScLMUI265poQ2cZtC/lwAsP55pE597wi4owEWqAjk1Fy9s6OXtQ7Vuj5hx0N3jjY0LcUYqO83CQiX03O6YrPel5T1HipFNOx8tLhWY7VZIIpYcg1SjiF457haCvCw/vYVaSmlEIblufcDAaOqX0z9rdQWKRKQhYtw1D3e/g9CtGBUiSReIQAAAABJRU5ErkJggg==','N');
    print_out('" alt="Proactive Services Banner">');
    print_out('        </div>');

-- page title
    print_out('        <div class="header_title">'||p_analyzer_title|| ' Report <br>
        <span class="header_subtitle"><b>Compiled using version '||g_rep_info('File Version')||'</b></span>
        <span class="whatsnew_ico" title="What''s New" border="none" data-popup-open="popup-3"></span>
        <span class="header_subtitle"> / Latest available for download:</span>
        <a target="_blank" href="'||g_cmos_doc_url||'">
        <img class="header_version" src="https://www.oracle.com/webfolder/s/analyzer/demantra_latest_version.gif" title="Click here to download the latest version of Analyzer" alt="Latest Version Icon"></a>');
    print_cloud_image;
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,808,EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="thumb_up_lg" title="Analyzer Feedback: Thumbs Up"></span></a>');
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,808,EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="thumb_dn_lg" title="Analyzer Feedback: Thumbs Down"></span></a>');
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},808,EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="af_idea_lg" title="Analyzer Idea"></span></a>');
    print_out('        </div>
    </div>');

-- top right menu
    print_out('<div class="topmenu">
          <div class="menubutton" id="homeButton" title="Open the analyzer''s main page">
          <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAZZJREFUeNrMls8uA1EYxTvaBZEgbLrmAfQNuiFio5SFxLKJnWAhFaJVUiEktk0aElai/m2IaBcaPAsrT0Dr9yWniTCYTlrpJL/c6Z3vO2d67p3JONVqNdDMoy3Q5CO0VXrxVLgyFHadp7/AEIdLaqa+GXi9E4Qchh39TCJWy3YSHJn4jigIB7AkDjEM6tqrRsc1Ig/iHXACY5DRXBp6MZlmHIYi9Pkx6IEriJo4sawrLovHzm8hJpNSvQZhCQyaGOIZhLNa8FVtDjMpw4hMPBsMwB30S2QDwX3GBf2DToZFqCq2J5l4WuQIPErcst6EXE1cx7zmsqqx2geMI38ZWNb3iictgWOYdbkRmzv6ZGI9ZUyiPxnElHm3GrbhFGZ+WSe7VlBtCrpMA5PxrwYJOId2Fe5q98Q9bOMJ1e6p1zTOMEnUDJKQ18OUUubXMFrHK8dqb9hd1rsmrTwmy062+OzW4OsVi4Hz72/TljKY04MZ0nnDDXJk/G7oIWusAcJvbuctuwYVH1qVegwufBi49jjN/mz5EGAAm494BUo6enYAAAAASUVORK5CYII=" class="smallimg">
          Home</div>');

    print_out('<div class="menubutton" id="execDetails" title="Show the analyzer''s execution details" data-popup-open="popup-1">
          <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYBAMAAAASWSDLAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAACFQTFRFJSUlXI2z////XI2zXI2zXI2zIrW9XI2zbKDIhLvm8PT344Mw7gAAAAZ0Uk5TAAAAucPE2PdAKgAAAFJJREFUGNNjUEICDOHlcFDCULUKDpYTwVmWhZ2zLAs7B8TExoEwsXFwuaByJhxMR+WYI/xTzAACglCAhVNejsSpnA7jsJeXd84oLy+EcUAAyAEAU+SE9OHO8IMAAAAASUVORK5CYII=" class="smallimg">
          Execution Details</div>');
    print_out('<div class="menubutton" id="execParameters" title="Shows the analyzer''s execution parameters" data-popup-open="popup-2">
          <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAATVQTFRF////LYa/LYa/LYa/LYa/LYa/LYa/LYa/LIW/LYW/LYW/LYa/LIW/LIW/LIW+LIW+LIS9LIS9LIS9LIS9K4O8K4O8K4O8K4O8K4O8K4O8K4O8K4K7K4K7K4K7KoK7KoK7KoK7KoK6KoG6KoG6KoG5KYG5KYG5KYC5KYG5KYC5KYC5KYC4KYC4KYC4KYC4KH+3KH+3J321J321JnyzJnyzJnuzJnuzJXqyJHmwJHmwJHivJHmvJHmwJHivI3etI3euIXSqIXSrIXWrInWrInasI3atJHivJnuzJnyzJ321J361J362KH62KYC4KYC5KYG5KoG5KoG6K4K7K4O8LIS9LYa/MIrEMIrFMIvFMYzGMYzHMY3IMo3IM4/KNpPPNpPQNpTQN5XSN5bSOJbSOZfUOZjUOZjVtemDjwAAAEB0Uk5TAAIEBggOEBIXGx8hLDAxM11hYmRwcXR2d3l6jJCTlJaYoqiqsbO0tri8vcLExsfQ0+Lj6+zt7vP3+Pr6+vv9/dC+MVIAAAFxSURBVCjPbVLpPxtRFD1v3kgprVKJrWm66RaKkYwlliTP8p6GCbcqwgxpOf//n+BDJvjhfrvn3P0e4M6KxhTxnNU7nfojKJv3AFTJKgAvn+vhMy4KtHqzR9oRpRcj9zWNdwmlvL73lzy1lVCYuG5OPiIZJyRJJjHJow8AAB0IScYHu7sHMUlKoLu1/DDmtSxPDw9PL8s149BPm6tKQpnXAKDnhUnFS4kRy3ao8OrnjyGosE072t23ak/pcni9eXKyNYScY8tWTRH1DkmaDL78IeUzMoYkO3XUblLik5DHH1PipoaF7Z3GOV0WL1eb0coAso4XjZ3tBaB/cLLBdknhRSGfgSq12Zga7AcAeBuXlF8KANSc8HKjN64ux/wvpbG+vrEl+ce4nC6uF4Ukz5wx7uzhSd4dPj5i9B4AkHNXlHDNtsiWXQuFV78nurW+7TcD33trSTvq+UFz/3vvheMF//61ujD+VAy1Z1Uya8zsvXcLH9dhX50/y6MAAAAASUVORK5CYII=" class="smallimg">
          Parameters</div>');
    print_out('<div class="menubutton" id="feedback" title="Opens the Oracle Community feedback thread"><a href="https://community.oracle.com/mosc/discussion/4587003" class="blacklink" target="new">
          <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAJNQTFRFIXSq////IXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqIXSqInatI3iuJHmvK4O7K4O8LIW+LYbALofBLojCMYzGMo3INZHNNpPPN5XRN5bSOJfUOZjVUpq7wgAAAB90Uk5TAAABAgwODxkgJD5HUlpncn+WoKyyu7zD0Nbq7vf6/POduf8AAAChSURBVCjPddJpE4IgEAbgpdNu7LDDas1QO4n//+vKxIbN5f3EzAPLsgMIT2CFNkICCZoqKFD6QEkPPIk4YIg4UEYyAHxXynbdgPqgHybtBry01gi47P5Bvo8/Acy2Awqnvt15iUcEkt66bEsZczvOKCT18qHmPNzPIVvqepi6pdLAXl7shuTyIv2OBLNNwL4cFx1+JONWNZIISaLfEH3f5w2X1DnbEexn8QAAAABJRU5ErkJggg==" class="smallimg">Feedback</a></div>');
    print_out('<div class="menubutton" id="analysisView" open-sig-class="analysis" title="Displays all data in a single page, without the Errors/Warnings/Passed Checks/Information messages - Click Plus (+) icon to expand all Table Data">
          <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsQAAA7EAZUrDhsAAAAZdEVYdFNvZnR3YXJlAEFkb2JlIEltYWdlUmVhZHlxyWU8AAABjFBMVEVentFhn89in9FjoNFjodNkodFnotJppNNppdRqpdVqptVrptVsptRtptRwuGl0um16rtd7r9d7sdx8r9h8st19r9h9s95+v3ibzZadzpmk0qCp1KWr1qiy0+yz2a++2e7A2+/U7NjV7dnZ7t3i8OHj7fbj7vbj7vfj8eLk7vblPCPl7/bl7/fmRCzmRi7mSjPmSjTmSzTm8Pfm8fnm8uTnSjLnTTbn8Pfn8frn8vrn8vvn8+bn8/7n9Pzn9f3n9f7n9v7oUjzoUz3oVD7oVT/oWEPoWUPoWUToWkXo8Pfo8ffo8fjpWkXpW0bqX0vq8vjraFXrb13rcF7sd2Xs9Pnt9Pnt9Prt9uzwi33w9vrw9+/xlx3xmiPx9vryny7yn5PyojTypZnzojT0qkb2vLT2vbX2xb72xr73wrr3/Pn62NP63Nf74Nz76ef7/fv87dj879z8/f797+7+4tz++Pf/4tz/5uH/6ub/7tf/7tv/79n/79z/8d3/8eH/8u///Pr//fr//vr//vz///8pVMrYAAABOklEQVQYGQXBPWuTURgA0HNvngSbNLQxKCpNBpVWsAUHHXRwcnJzcnLxr/TXODk7OQripHWpVIh1CbTFGKW+356TXh1PAQBwvmsaAAAQ19J4+/EJw1yWoB9w68Ov0Ds4oLocBmiLTD362IUOi4tvT2+Ai/OgutelgO+LnBOQBokWGT+P+hsZACBwtjUA0JVBg8DpBANgspmpEYCd9w31o7vLd4n2NYHZCjuU3YZVmWmQMV2VUNXDTcfroijWCMyqRdPrF3XMtjz5M2WJgNtxtl7Oh1evs1z9pkVImN/818QoYX8fJKH5csIwp7YuANxp2A4AAIhJPPvcA/I86X60QP0gHQL4VBo8BBAA3h71NKcvADKAvTwe5z0A6ZA3X3Mmj7L2b0vb3n9JoEpXoOikgMsKgefHHQBIu/gPPNJqMuZfDkEAAAAASUVORK5CYII=" class="smallimg">
          Data View</div>');
    print_out('<div class="menubutton" id="printView" open-sig-class="print" title="Displays all data in a single page, including the Errors/Warnings/Passed Checks/Information messages - Click Plus (+) icon to expand all Table Data">
          <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAiUlEQVRIx2NgoCdYs2nHYSD+TyE+jM+C/8/efKYIg8wYWAuogekarwzmERMPA/F/GuHDIAv+B5XvoAkGmU2xBT8vtoExjJ983hiMh44FRAWRU+pCqkcwzEwGmAANUiemBdTMaDgtoFZRMfAWNO19RhIeUB8cpqEPjgxchUOpD4ZvlUmNVgVKxAIAsdgxrFcW4/sAAAAASUVORK5CYII=" class="smallimg">
          Full View</div>
        </div>
    </div>
    <div class="backtop sectionview data section fullsection data print analysis" style="display:none;"><a href="#top">Back to top</a></div>
    ');

EXCEPTION WHEN OTHERS THEN
  print_log('Error in print_rep_header: '||sqlerrm);
  raise;
END print_rep_header;


----------------------------------------------------------------
-- Prints Feedback items                                      --
----------------------------------------------------------------
PROCEDURE print_feedback IS
BEGIN
    print_out('    <!-- print hidden feedback items -->
    <div style="display: none;">
        <span id="feedback-apex">ASEPROD</span>
        <span id="feedback-azr">808</span>
        <span id="feedback-guid">' || g_guid || '</span>
    </div>');
END print_feedback;


----------------------------------------------------------------
-- Prints What's New pop-up window                            --
----------------------------------------------------------------
PROCEDURE print_whatsnew IS

BEGIN
    print_out('       <!-- print Whats New pop-up window -->
       <div class="popup" data-popup="popup-3">
            <div class="popup-inner" style="padding:15px">
            <b><br>&nbsp;&nbsp;What''s new in this release:</b><br><br>
<div>We’re listening to your feedback and made the following changes:</div>
<ul><li><span style="font-family:&apos;Calibri&apos;,&apos;sans-serif&apos;;font-size:11.0pt;">The analyzer is now executed as a Package instead of an Anonymous Block.&nbsp; Please see the instructions in Doc</span><br>
<span style="font-family:&apos;Calibri&apos;,&apos;sans-serif&apos;;font-size:11.0pt;">&nbsp;&nbsp;&nbsp;&nbsp; ID 1618885.1 for running the analyzer from Sql*Plus and from Concurrent Manager as a Concurrent Program.</span></li>
<li>New page from the Execution Summary showing all Passed Checks that are not printed in the main report</li>
<li>Enhanced Search to make it easier to find results found</li>
<li>Back to top link</li>
<li>Modified icons but same functionality for easier ease of use</li>
<li>Fix of all known bugs</li>
</ul>
<p><strong>The Data Masking feature has been expanded.&nbsp;&nbsp; &nbsp;</strong></p><p>1. Select data is now pre-masked at the point of collection.<br>
2. The masked information displayed will be just enough to permit effective review and troubleshooting of an issue.&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;<br>
&nbsp;&nbsp;&nbsp;&nbsp; Example:&nbsp; A credit card number would be displayed as ****-****-****-1234<br>
&nbsp;&nbsp;&nbsp;&nbsp; An employee name would be displayed as Display first and last 25% per word (J**n S**w = John Snow)<br>
3. The existing “Lock Icon” still provides customers the manual column scrambling capabilities, which can be used in addition to the newly introduced pre-masked data feature.</p>
            <br><br>
            <div class="close-button" data-popup-close="popup-3"><a class="black-link">OK</a></div>
            </div>
       </div>');

END print_whatsnew;


----------------------------------------------------------------
-- Prints execution details pop-up window                     --
----------------------------------------------------------------
PROCEDURE print_execdetails IS
  l_key  VARCHAR2(255);
  l_time TIMESTAMP;
BEGIN
  g_analyzer_elapsed := stop_timer(g_analyzer_start_time);
  get_current_time(l_time);

  --g_sections.delete;

    print_out('       <!-- print Execution Details pop-up window -->
       <div class="popup" data-popup="popup-1">
            <div class="popup-inner">
                     <table cellpadding="3" cellspacing="0" border="0" width="100%" style="font-size: 14px;">
                        <tbody>
                           <tr>
                              <td colspan="2" class="popup-title"><b>Execution Details</b></td>
                           </tr>');





  -- Loop and print values
  l_key := g_rep_info.first;
  WHILE l_key IS NOT NULL LOOP
    IF ((l_key = 'FullHost') AND (g_cloud_flag)) THEN
        print_out('                       <tr>
                              <td class="popup-paramname"><b>'||l_key||'</b></td>
                              <td class="popup-paramval">
                                 <span title="">'||g_rep_info(l_key));
        print_cloud_image;
        print_out('                                 </span>
                              </td>
                           </tr>');
    ELSE
        print_out('                       <tr>
                              <td class="popup-paramname"><b>'||l_key||'</b></td>
                              <td class="popup-paramval"><span title="">'||g_rep_info(l_key)||'</span></td>
                           </tr>');
    END IF;
    l_key := g_rep_info.next(l_key);
  END LOOP;

  print_out('                       <tr>
                        <td class="popup-paramname"><b>Start time:</b></td>
                        <td class="popup-paramval">
                          <span id="start_time">' || to_char(g_analyzer_start_time,'hh24:mi:ss') ||
                          '</span>
                        </td>
                     </tr>');
  print_out('                       <tr>
                        <td class="popup-paramname"><b>End time:</b></td>
                        <td class="popup-paramval">
                          <span id="end_time">' || to_char(l_time,'hh24:mi:ss') ||
                          '</span>
                        </td>
                     </tr>');
  print_out('                       <tr>
                        <td class="popup-paramname"><b>Execution time:</b></td>
                        <td class="popup-paramval">
                          <span id="exec_time">' || format_elapsed(g_analyzer_elapsed, FALSE) ||
                          '</span>
                        </td>
                     </tr>');
  print_out('                        </tbody>
                     </table>
                <div class="close-button" data-popup-close="popup-1"><a class="black-link">OK</a></div>
            </div>
    </div>
  ');

EXCEPTION WHEN OTHERS THEN
  print_log('Error in print_execdetails: '||sqlerrm);
  raise;
END print_execdetails;


----------------------------------------------------------------
-- Prints parameters pop-up window                            --
----------------------------------------------------------------
PROCEDURE print_parameters IS
BEGIN

  print_out('    <!-- print Parameters pop-up window -->
      <div class="popup" data-popup="popup-2">
            <div class="popup-inner">
                   <table cellpadding="5" cellspacing="0" border="0" width="100%" style="font-size: 14px;">
                        <tbody>
                           <tr>
                              <td colspan="2" class="popup-title"><b>Parameters</b></td>
                           </tr>');
  FOR i IN 1..g_parameters.COUNT LOOP
    print_out('                           <tr>
                              <td class="popup-paramname"><b>'||to_char(i)||'. '||g_parameters(i).pname||'</b></td>
                              <td class="popup-paramval"><span>'||g_parameters(i).pvalue||'</span></td>
                           </tr>');
  END LOOP;
    print_out('                        </tbody>
                     </table>
                <div class="close-button" data-popup-close="popup-2"><a class="black-link">OK</a></div>
            </div>

    </div>');

EXCEPTION WHEN OTHERS THEN
    print_log('Error in print_parameters: '||sqlerrm);
    raise;
END print_parameters;


PROCEDURE print_mainpage IS

   l_loop_count NUMBER;
   l_section_id  VARCHAR2(320);
   l_counter_str VARCHAR2(2048);
BEGIN

   l_loop_count := g_sections.count;

    print_out('
<!-- main menu with tiles -->

    <div class="mainmenu">
     <table align="center"  id="menutable">
        <tbody>
            <tr>
            <td>
              <div class="menubox">
                <table cellpadding="5" cellspacing="2" class="mboxinner">
                <thead>
                <tr><th><span class="menuboxitemt">Execution Summary</span></th></tr></thead>
                <tbody>
                <tr><td><div open-section="E" class="menuboxitem"><span class=''error_ico icon''></span><div class="mboxelem" title="List of signatures that affect critical business operations and should be addressed right away.">Errors</div></div></td>
                <td align="right"><span class="errcount">'||g_results('E')||'</span></td></tr>
                <tr><td><div open-section="W" class="menuboxitem"><span class=''warn_ico icon''></span><div class="mboxelem" title="List of signatures that do not affect critical business operations, but still could affect your business based on your requirements.">Warnings</div></div></td>
                <td align="right"><span class="warncount">'||g_results('W')||'</span></td></tr>
                <tr><td><div open-section="S" class="menuboxitem"><span class=''success_ico icon''></span><div class="mboxelem" title="List of Error and Warning signatures with no problem(s) identified.">Passed Checks</div></div></td>
                <td align="right"><span class="successcount">'||g_results('S')||'</span></td></tr>
                <tr><td><div open-section="I" class="menuboxitem"><span class=''information_ico icon''></span><div class="mboxelem" title="List of signatures that are data collection only.">Informational</div></div></td>
                <td align="right"><span class="infocount">'||g_results('I')||'</span></td></tr>
                <tr><td><div open-sig-class="passed" class="menuboxitem"><span class=''proc_success_small icon''></span><div class="mboxelem" title="Additional Error and Warning signatures with no problem(s) identified and designed to only display in the main report when they fail.">Background Passed Checks</div></div></td>
                <td align="right"><span class="infocount">'||g_results('P')||'</span></td></tr>
                </tbody></table>
              </div>
            </td>
            <td>');

    print_out('
                <table>
                <tr>');

    FOR i in 1 .. l_loop_count LOOP
        l_section_id := g_sec_detail(i).name;
        l_counter_str := '';

        IF (g_sec_detail(i).results('E') > 0)THEN
            l_counter_str := '<div class=''counternumber''>' || to_char(g_sec_detail(i).results('E')) || '</div><span class=''error_ico icon''></span>&nbsp;';
        END IF;
        IF (g_sec_detail(i).results('W') > 0)THEN
            l_counter_str := l_counter_str || '<div class=''counternumber''>' || to_char(g_sec_detail(i).results('W')) || '</div><span class=''warn_ico icon''></span>&nbsp;';
        END IF;
        IF (g_sec_detail(i).results('S') > 0)THEN
            l_counter_str := l_counter_str || '<div class=''counternumber''>' || to_char(g_sec_detail(i).results('S')) || '</div><span class=''success_ico icon''></span>&nbsp;';
        END IF;
        IF (g_sec_detail(i).results('I') > 0)THEN
            l_counter_str := l_counter_str || '<div class=''counternumber''>' || to_char(g_sec_detail(i).results('I')) || '</div><span class=''information_ico icon''></span>&nbsp;';
        END IF;
        IF (g_sec_detail(i).results('E') + g_sec_detail(i).results('W') + g_sec_detail(i).results('S') + g_sec_detail(i).results('I') = 0) THEN
            l_counter_str := '<span class=''menubox_subtitle''>Executed, nothing to report</span>';
        END IF;
        print_out('
                <td>
                <a href="javascript:void(0)" class="blacklink"><div class="floating-box" open-section="'||l_section_id||'"><div class="textbox">'||g_sec_detail(i).title||'</div><div id="'||l_section_id||'Count" class="counterbox">'||l_counter_str||'</div></div></a>
                </td>');
        IF (MOD(i,3)=0 ) THEN
            print_out('                </tr><tr>');
        END IF;
    END LOOP;

    print_out('
                </tr>
            </table>
            </td></tr>
        </tbody>
     </table>
    </div>
<!-- end main menu -->     ');

EXCEPTION WHEN OTHERS THEN
  print_log('Error in print_mainpage: '||sqlerrm);
  raise;
END print_mainpage;


----------------------------------------------------------------
-- Print footer and end of html page def                      --
----------------------------------------------------------------
PROCEDURE print_footer IS

BEGIN

   print_out('      <!-- footer area -->
       <div class="footerarea">
           <div class="footer">
               <div style="visibility: visible; max-height: 33px; min-height: 33px;">
                  <span><a href="' || g_cmos_km_url || '432" target="_blank" class="blacklink">About Oracle Proactive Support</a></span>
                  <span class="separator"></span>
                  <span><a href="' || g_cmos_sr_url || '" target="_blank" class="blacklink">Log a Service Request</a></span>
                  <span class="separator"></span>');
   -- just to be sure there is no error while getting the family area code
   BEGIN
   print_out('
                  <span><a href="' || g_cmos_km_url || '1545562#' || nvl(g_fam_area_hash(nvl(g_family_area, 'ATG')), '') || '" target="_blank"');

   EXCEPTION WHEN OTHERS THEN
   print_out('
                  <span><a href="' || g_cmos_km_url || '1545562" target="_blank"');
   END;
   print_out('
                  class="blacklink">Related Analyzers</a></span>
                  <span class="separator"></span>
                  <span><a href="' || g_cmos_km_url || '1939637" target="_blank" class="blacklink">Analyzer Bundle Menu Tool</a></span>
                  <span class="separator"></span>
                  <span><a href="https://www.oracle.com/us/legal/privacy/overview/index.html" target="_blank" class="blacklink">Your Privacy Rights</a></span>
                  <span class="separator"></span>
                  <span><a href="' || g_cmos_km_url || '2116869" target="_blank" class="blacklink">Frequently Asked Questions</a></span>','N');
   -- EBSAF-272
   if g_g2g_flag then
      print_out('
                  <span style="float:right;color:lightgreen;font-size:8px">&#9679;&#9679;&#9679;</span>','N');
   end if;
   print_out('
               </div>
           </div>
       </div><!-- end footer area -->
   ');
EXCEPTION WHEN OTHERS THEN
  print_log('Error in print_footer: '||sqlerrm);
  raise;
END print_footer;


/* REMOVED TO ELIMINATE INLINE JAVASCRIPT (EBSAF-262)
----------------------------------------------------------------
-- Print execution times in the Execution Details page        --
----------------------------------------------------------------
PROCEDURE print_execution_time (l_time TIMESTAMP) IS
BEGIN

  print_out('        <script>
            $("#start_time").text("'||to_char(g_analyzer_start_time,'hh24:mi:ss')||'");
        </script>');
  print_out('        <script>
            $("#end_time").text("'||to_char(l_time,'hh24:mi:ss')||'");
        </script>');
  print_out('        <script>
            $("#exec_time").text("'||format_elapsed(g_analyzer_elapsed, FALSE)||'");
        </script>');

END print_execution_time;
*/


----------------------------------------------------------------
-- Split text into a varchar2 table (escape delims with \)    --
----------------------------------------------------------------
FUNCTION split_text(p_text varchar2 default null,
    p_delims varchar2 default ',') return varchar_tbl
IS
    l_tokens varchar_tbl := varchar_tbl();
    l_search varchar2(100);
BEGIN
    if p_text is null then
        return l_tokens;
    end if;

    l_search := '(\\[' || nvl(p_delims, ',') || ']|[^' || nvl(p_delims, ',') || '])+';
    select substr(trim(token), 1, 255)
    bulk collect into l_tokens
    from (
        select regexp_replace(
            -- Tokens matching search string
            regexp_substr(p_text, l_search, 1, level),
            -- EBSAF-306 Escaped delimiters must be reverted
            '\\([' || nvl(p_delims, ',') || '])', '\1') token
        from dual
        connect by regexp_substr(p_text, l_search, 1, level) is not null
    )
    where trim(token) is not null;

    return l_tokens;
exception when others then
    print_log('Error in split_text: '||sqlerrm);
    return l_tokens;
END split_text;


------------------------------------------------------
-- Join a varchar2 table into a single string       --
------------------------------------------------------
FUNCTION join_text(p_tokens varchar_tbl default null,
    p_delims varchar2 default ',') return varchar2
IS
    l_token varchar2(255);
    l_text varchar2(32767);
    l_token_count number;
    l_display_count number;
    l_text_size number;
    l_delim_size number;
BEGIN
    if p_tokens is null or p_tokens.count = 0 then
        return null;
    end if;

    l_text_size := 0;
    l_delim_size := length(p_delims);
    l_token_count := p_tokens.count;
    l_display_count := 0;
    for i in 1..l_token_count loop
        l_token := p_tokens(i);
        if l_token is not null then
            l_text_size := l_text_size + l_delim_size + length(l_token);
            exit when l_text_size > 32767;
            l_text := l_text || p_delims || l_token;
            l_display_count := l_display_count + 1;
        end if;
    end loop;

    if l_text_size > 32767 then
        debug('Too many values in join_text');
        debug('Showing '||l_display_count||' of '||l_token_count);
    end if;

    return substr(l_text, l_delim_size + 1);
exception when others then
    print_log('Error in join_text: '||sqlerrm);
    print_log('Showing '||l_display_count||' of '||l_token_count);
    return substr(l_text, l_delim_size + 1);
END join_text;


------------------------------------------------------
-- Filter leading/trailing spaces and invalid       --
-- characters.  Options are:                        --
--  [D]eleted (default), [H]idden, or [I]gnored     --
------------------------------------------------------
FUNCTION filter_html(
    p_text          IN VARCHAR2,
    p_spaces_opt    IN VARCHAR2 DEFAULT NULL,
    p_invalid_opt   IN VARCHAR2 DEFAULT NULL
) RETURN VARCHAR2
IS
    l_html varchar2(32767);
    l_tag_L varchar2(1) := '`';
    l_tag_R varchar2(1) := '~';
BEGIN
    if p_text is null then
        return null;
    end if;

    l_html := p_text;

    -- Handle invalid characters (EBSAF-263)
    -- Workaround needed for partial overlap of [:space:] and [:cntrl:].
    if nvl(p_invalid_opt, 'D') = 'D' then
        -- Deleted
        -- Keep spaces but delete control
        l_html := regexp_replace(l_html,
            '(([[:space:]])|([[:cntrl:]]))',
            '\2'
        );
    elsif p_invalid_opt = 'H' then
        -- Hidden
        -- Tag spaces
        -- Need to be different in case of control between spaces.
        -- Also shouldn't be common/paired characters: {},[], etc.
        l_html := regexp_replace(l_html,
            '([[:space:]])',
            l_tag_L||'\1'||l_tag_R
        );
        -- Replace untagged control
        l_html := regexp_replace(l_html,
            '([^'||l_tag_L||']|^)[[:cntrl:]]([^'||l_tag_R||']|$)',
            '\1&#65533;\2'
        );
        -- Remove tags from spaces
        l_html := regexp_replace(l_html,
            l_tag_L||'([[:space:]])'||l_tag_R,
            '\1'
        );
        -- Wrap groups of entities
        l_html := regexp_replace(l_html,
            '((&#65533;)+)',
            '<span class="hidden_data" hide-type="err">\1</span>'
        );
    elsif p_invalid_opt = 'I' then
        -- Ignored
        null;
    end if;

    -- Handle leading/trailing spaces (EBSAF-255)
    if nvl(p_spaces_opt, 'D') = 'D' then
         -- Deleted
        l_html := regexp_replace(l_html,
            '(^[[:space:]]+|[[:space:]]+$)',
            null
        );
    elsif p_spaces_opt = 'H' then
       -- Hidden
        l_html := regexp_replace(l_html,
            '(^[[:space:]]+|[[:space:]]+$)',
            '<span class="hidden_data" hide-type="wrn">\1</span>'
        );
    elsif p_spaces_opt = 'I' then
        -- Ignored
        null;
    end if;

    return l_html;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in filter_html: '||sqlerrm||'.  Text unmodified.');
    return p_text;
END filter_html;


------------------------------------------------------------------
-- Remove HTML formatting from text (EBSAF-294)     --
------------------------------------------------------------------
FUNCTION plain_text(p_text varchar2 default null) return varchar2
IS
    l_text varchar2(32767);
    l_old_length number;
BEGIN
    if (p_text is null) then
        return null;
    end if;

    l_text := p_text;

    -- Keep text between matching open/close tags (loop for nested tags)
    l_old_length := length(l_text);
    loop
        l_text := regexp_replace(l_text,'<(\w+)(\s[^>]*)?>(.*?)</\1>', '\3', 1, 1, 'im');
        exit when l_old_length = length(l_text);
        l_old_length := length(l_text);
    end loop;

    -- Convert breaks
    l_text := regexp_replace(l_text,'<br[^>]*?/?>', chr(10), 1, 0, 'i');

    -- Remove other standalone tags
    l_text := regexp_replace(l_text,'<(hr|img|input|link|meta|wbr)(>|\W[^>]*>)', null, 1, 0, 'i');

    -- Restore entities
    l_text := regexp_replace(l_text,'&apos;', '''', 1, 0, 'i');
    l_text := regexp_replace(l_text,'&quot;', '"', 1, 0, 'i');
    l_text := regexp_replace(l_text,'&lt;', '<', 1, 0, 'i');
    l_text := regexp_replace(l_text,'&gt;', '>', 1, 0, 'i');
    l_text := regexp_replace(l_text,'&amp;', '&', 1, 0, 'i');

    return l_text;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in plain_text: '||sqlerrm||'.  Text unmodified.');
    return p_text;
END plain_text;


------------------------------------------------------------------
-- Get the masked data according to mask option (EBSAF-269)     --
-- NOTE: This is different than client-side masking             --
------------------------------------------------------------------
FUNCTION mask_text(p_text varchar2 default null,
    p_mask_option varchar2 default null) return varchar2
IS
    l_text_length number;
    l_mask_char varchar2(1) := '*';
    l_masked_text varchar2(32767);
    l_mask_length number;
    l_unmask_length number;
    l_word varchar2(32767);
    l_char varchar2(4);
    l_word_length number;
    l_word_active boolean;
    l_tokens varchar_tbl;
    l_full_mask varchar2(32767);
    l_ip_pattern varchar2(255) := '^[[:digit:]]+[.][[:digit:]]+[.][[:digit:]]+[.][[:digit:]]+$';
BEGIN
    -- Quick exit if masking not necessary or possible
    if (p_mask_option = 'NO_MASK' or p_text is null) then
        return p_text;
    end if;

    -- Get the full masked value as a backup
    l_text_length := length(p_text);
    l_full_mask := rpad(l_mask_char, l_text_length, l_mask_char);

    case(p_mask_option)
    when 'DISPLAY_FIRST_4_CHAR' then
        -- Display first 4 characters of entire text
        l_unmask_length := least(4, l_text_length);
        l_mask_length := l_text_length - l_unmask_length;
        l_masked_text := substr(p_text, 1, l_unmask_length) || substr(l_full_mask, 1, l_mask_length);
    when 'DISPLAY_LAST_4_CHAR' then
        -- Display last 4 characters of entire text
        l_unmask_length := least(4, l_text_length);
        l_mask_length := l_text_length - l_unmask_length;
        l_masked_text := substr(l_full_mask, 1, l_mask_length) || substr(p_text, -1 * l_unmask_length, l_unmask_length);
    when 'DISPLAY_FIRST_25_PCNT' then
        -- Display first 25% of entire text
        l_unmask_length := floor(0.25 * l_text_length);
        l_mask_length := l_text_length - l_unmask_length;
        l_masked_text := substr(p_text, 1, l_unmask_length) || substr(l_full_mask, 1, l_mask_length);
    when 'DISPLAY_LAST_25_PCNT' then
        -- Display last 25% of entire text
        l_unmask_length := floor(0.25 * l_text_length);
        l_mask_length := l_text_length - l_unmask_length;
        l_masked_text := substr(l_full_mask, 1, l_mask_length) || substr(p_text, -1 * l_unmask_length, l_unmask_length);
    when 'DISPLAY_FIRST_WORD' then
        -- Display first word of entire text
        l_word := regexp_replace(p_text, '^([^[:alnum:]]*[[:alnum:]]+).*?$', '\1');
        l_unmask_length := length(l_word);
        l_mask_length := l_text_length - l_unmask_length;
        l_masked_text := substr(p_text, 1, l_unmask_length) || substr(l_full_mask, 1, l_mask_length);
    when 'DISPLAY_LAST_WORD' then
        -- Display last word of entire text
        l_word := regexp_replace(p_text, '^.*?([[:alnum:]]+[^[:alnum:]]*)$', '\1');
        l_unmask_length := length(l_word);
        l_mask_length := l_text_length - l_unmask_length;
        l_masked_text := substr(l_full_mask, 1, l_mask_length) || substr(p_text, -1 * l_unmask_length, l_unmask_length);
    when 'DISPLAY_BOTH_25_PCNT_WORD' then
        -- Display first and last 25% of each word
        l_word := null;
        l_word_length := 0;
        l_masked_text := null;
        for i in 1..l_text_length loop
            l_char := substr(p_text, i, 1);
            if regexp_like(l_char, '[[:alnum:]]') then
                -- Letter/number found, keep building word
                l_word_active := true;
                l_word_length := l_word_length + 1;
                l_word := l_word || l_char;
                -- Clear letter to prevent duplication at end
                l_char := null;
            else
                l_word_active := false;
            end if;
            if not l_word_active or i = l_text_length then
                if (l_word_length > 2) then
                    -- Mask captured word
                    l_unmask_length := floor(0.25 * l_word_length);
                    l_mask_length := l_word_length - 2 * l_unmask_length;
                    l_masked_text := l_masked_text ||
                        substr(l_word, 1, l_unmask_length) ||
                        substr(l_full_mask, 1, l_mask_length) ||
                        substr(l_word, -1 * l_unmask_length, l_unmask_length);
                    l_word := null;
                    l_word_length := 0;
                elsif (l_word_length > 0) then
                    -- Word too short, mask entire thing
                    l_masked_text := l_masked_text || substr(l_full_mask, 1, l_word_length);
                    l_word := null;
                    l_word_length := 0;
                end if;
                l_masked_text := l_masked_text || l_char;
            end if;
        end loop;
    when 'DISPLAY_FIRST_25_PCNT_WORD' then
        -- Display first 25% of each word (EBSAF-281)
        l_word := null;
        l_word_length := 0;
        l_masked_text := null;
        for i in 1..l_text_length loop
            l_char := substr(p_text, i, 1);
            if regexp_like(l_char, '[[:alnum:]]') then
                -- Letter/number found, keep building word
                l_word_active := true;
                l_word_length := l_word_length + 1;
                l_word := l_word || l_char;
                -- Clear letter to prevent duplication at end
                l_char := null;
            else
                l_word_active := false;
            end if;
            if not l_word_active or i = l_text_length then
                if (l_word_length > 2) then
                    -- Mask captured word
                    l_unmask_length := floor(0.25 * l_word_length);
                    l_mask_length := l_word_length - l_unmask_length;
                    l_masked_text := l_masked_text ||
                        substr(l_word, 1, l_unmask_length) ||
                        substr(l_full_mask, 1, l_mask_length);
                    l_word := null;
                    l_word_length := 0;
                elsif (l_word_length > 0) then
                    -- Word too short, mask entire thing
                    l_masked_text := l_masked_text || substr(l_full_mask, 1, l_word_length);
                    l_word := null;
                    l_word_length := 0;
                end if;
                l_masked_text := l_masked_text || l_char;
            end if;
        end loop;
    when 'DISPLAY_LAST_25_PCNT_WORD' then
        -- Display last 25% of each word (EBSAF-281)
        l_word := null;
        l_word_length := 0;
        l_masked_text := null;
        for i in 1..l_text_length loop
            l_char := substr(p_text, i, 1);
            if regexp_like(l_char, '[[:alnum:]]') then
                -- Letter/number found, keep building word
                l_word_active := true;
                l_word_length := l_word_length + 1;
                l_word := l_word || l_char;
                -- Clear letter to prevent duplication at end
                l_char := null;
            else
                l_word_active := false;
            end if;
            if not l_word_active or i = l_text_length then
                if (l_word_length > 2) then
                    -- Mask captured word
                    l_unmask_length := floor(0.25 * l_word_length);
                    l_mask_length := l_word_length - l_unmask_length;
                    l_masked_text := l_masked_text ||
                        substr(l_full_mask, 1, l_mask_length) ||
                        substr(l_word, -1 * l_unmask_length, l_unmask_length);
                    l_word := null;
                    l_word_length := 0;
                elsif (l_word_length > 0) then
                    -- Word too short, mask entire thing
                    l_masked_text := l_masked_text || substr(l_full_mask, 1, l_word_length);
                    l_word := null;
                    l_word_length := 0;
                end if;
                l_masked_text := l_masked_text || l_char;
            end if;
        end loop;
    when 'DISPLAY_1_3_OCTET' then
        -- Display 1st and 3rd octet of IP address
        if regexp_like(p_text, l_ip_pattern) then
            l_tokens := split_text(p_text, '.');
            l_masked_text := l_tokens(1) || '.***.' || l_tokens(3) || '.***';
        else
            -- Invalid format, mask everything
            l_masked_text := l_full_mask;
        end if;
    when 'DISPLAY_2_4_OCTET' then
        -- Display 2nd and 4th octet of IP address
        if regexp_like(p_text, l_ip_pattern) then
            l_tokens := split_text(p_text, '.');
            l_masked_text := '***.' || l_tokens(2) || '.***.' || l_tokens(4);
        else
            -- Invalid format, mask everything
            l_masked_text := l_full_mask;
        end if;
    when 'DISPLAY_4_OCTET' then
        -- Display 4th octet of IP address
        if regexp_like(p_text, l_ip_pattern) then
            l_tokens := split_text(p_text, '.');
            l_masked_text := '***.***.***.' || l_tokens(4);
        else
            -- Invalid format, mask everything
            l_masked_text := l_full_mask;
        end if;
    when 'MASK_ALPHANUMERIC' then
        -- Mask all letters and numbers
        l_masked_text := regexp_replace(p_text, '[[:alnum:]]', l_mask_char);
    when 'DISPLAY_NONE' then
        -- Mask everything
        l_masked_text := l_full_mask;
    when 'HASH_VALUE' then
        -- Generate hash of the text
        select ('HASH_' || ora_hash(p_text)) into l_masked_text from dual;
    when 'REMOVE_COLUMN' then
        -- Remove the entire column
        l_masked_text := null;
    else
        -- Invalid option, mask everything
        l_masked_text := l_full_mask;
    end case;

    -- When all or nothing, choose nothing
    if (l_masked_text = p_text) then
        l_masked_text := l_full_mask;
    end if;

    return l_masked_text;
EXCEPTION
   WHEN OTHERS THEN
        print_log('Error in mask_text(' || p_mask_option || '): ' || sqlerrm);
        return l_full_mask;
END mask_text;


----------------------------------------------------------------
-- Evaluates if a rowcol meets desired criteria               --
----------------------------------------------------------------
FUNCTION evaluate_rowcol(p_oper varchar2, p_criteria varchar2, p_value varchar2,
    p_criteria_set varchar_tbl default null) return boolean is
    l_value VARCHAR2(4000);
    l_criteria VARCHAR2(255);   -- SIGNATURES.FAIL_CONDITION is only varchar2(240)
    l_oper VARCHAR2(255);
    l_result boolean := false;
    l_comparing_num   boolean := false;
    l_value_num   NUMBER;
    l_criteria_num   NUMBER;
    l_comparing_date   boolean := false;
    l_value_date date;
    l_criteria_date date;
BEGIN
    -- Expand out SQL Tokens (EBSAF-199)
    IF (p_criteria like '##$$%$$##' and g_sql_tokens.exists(p_criteria) ) THEN
        l_criteria := g_sql_tokens(p_criteria);
    ELSE
        l_criteria := p_criteria;
    END IF;
    l_value := p_value;
    l_oper := trim(upper(regexp_replace(p_oper,'\s+',' ')));

    -- Relative operations require data type conversion
    IF l_oper IN ('<=','<','>','>=') THEN
        -- Attempt to convert to number
        BEGIN
            l_value_num := to_number(l_value);
            l_criteria_num := to_number(l_criteria);
            l_comparing_num := true;
            l_comparing_date := false;
        EXCEPTION WHEN OTHERS THEN
            l_comparing_num := false;
        END;
        -- Otherwise, attempt to convert to sortable date
        IF NOT l_comparing_num THEN
            BEGIN
                l_value_date := to_date(l_value);
                l_criteria_date := to_date(l_criteria);
                l_comparing_date := true;
            EXCEPTION WHEN OTHERS THEN
                l_comparing_date := false;
            END;
        END IF;
        IF l_comparing_date THEN
            l_value := to_char(l_value_date, 'YYYYMMDDHH24MISS');
            l_criteria := to_char(l_criteria_date, 'YYYYMMDDHH24MISS');
        END IF;
    END IF;

    -- Do comparisons
    IF l_oper = '=' THEN
        l_result := l_value = l_criteria;
    ELSIF l_oper = '!=' OR l_oper = '<>' THEN
        l_result := l_value != l_criteria;
    ELSIF l_oper = '>' THEN
        IF l_comparing_num THEN
            l_result := l_value_num > l_criteria_num;
        ELSE
            l_result := l_value > l_criteria;
        END IF;
    ELSIF l_oper = '<' THEN
        IF l_comparing_num THEN
            l_result := l_value_num < l_criteria_num;
        ELSE
            l_result := l_value < l_criteria;
        END IF;
    ELSIF l_oper = '<=' THEN
        IF l_comparing_num THEN
            l_result := l_value_num <= l_criteria_num;
        ELSE
            l_result := l_value <= l_criteria;
        END IF;
    ELSIF l_oper = '>=' THEN
        IF l_comparing_num THEN
            l_result := l_value_num >= l_criteria_num;
        ELSE
            l_result := l_value >= l_criteria;
        END IF;
    -- EBSAF-198
    ELSIF l_oper = 'LIKE' THEN
        l_result := l_value like l_criteria;
    ELSIF l_oper = 'NOT LIKE' THEN
        l_result := l_value not like l_criteria;
    ELSIF l_oper = 'IS NULL' THEN
        l_result := l_value is null;
    ELSIF l_oper = 'IS NOT NULL' THEN
        l_result := l_value is not null;
    ELSIF l_oper = 'IN' OR l_oper = 'NOT IN' THEN
        IF p_criteria_set is null or p_criteria_set.count = 0 THEN
            -- Criteria set is required
            print_log('No fail condition criteria for ' || l_oper || ' operation');
            raise COLLECTION_IS_NULL;
        ELSE
            -- Check value against each criteria in the set
            l_result := false;
            for i in 1..p_criteria_set.count loop
                -- EBSAF-306 Recursive check for at least one match
                if not l_result then
                    l_result := evaluate_rowcol('=', p_criteria_set(i), p_value);
                end if;
            end loop;
            if l_oper = 'NOT IN' then
                l_result := l_value is not null and not l_result;
            end if;
        END IF;
    ELSE
        print_log('Unknown fail condition operation: ' || l_oper);
        raise VALUE_ERROR;
    END IF;
    return l_result;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in evaluate_rowcol');
    raise;
END evaluate_rowcol;

/* CONSOLIDATED INTO expand_html (EBSAF-180)
---------------------------------------------
-- Expand [note] or {patch} tokens         --
---------------------------------------------
FUNCTION expand_links(p_str VARCHAR2, p_sigrepo_id VARCHAR2 DEFAULT '')
    return VARCHAR2
IS
  l_str VARCHAR2(32767);
BEGIN
  -- Assign to working variable
  l_str := p_str;

  -- First deal with patches - add codeline for R12 patches
  l_str := regexp_replace(l_str,'({)([0-9]*)(})',
    '<a target="_blank" href="'||g_cmos_patch_url||'\2">\2</a>',1,0);
  -- Same for notes
  l_str := regexp_replace(l_str,'(\[)([0-9]*\.[0-9])(\#[a-zA-Z0-9_]+)*(\])',
    '<a target="_blank" href="'||g_cmos_doc_url||'_sigId'||p_sigrepo_id||'&id=\2\3">Doc ID \2</a>',1,0);
  return l_str;
EXCEPTION WHEN OTHERS THEN
     print_log ('Exception in expand_links: ' || SQLERRM);
     return p_str;
END expand_links;
*/

/* CONSOLIDATED INTO expand_html (EBSAF-180)
------------------------------------------------------------------
-- Expand {#TOKEN#} tokens - replace with value from extra_info --
------------------------------------------------------------------
FUNCTION expand_tokens(p_str VARCHAR2, p_extra_info HASH_TBL_4K)
    return VARCHAR2
IS
  l_str VARCHAR2(32767);
  l_key VARCHAR2(256);
  l_regex VARCHAR2(256);
BEGIN
  l_str := p_str;

  -- if there is no token in the text, return
  IF NOT regexp_like(p_str,'{#') THEN
      RETURN p_str;
  END IF;

  IF p_extra_info.count > 0 THEN
    l_key := p_extra_info.first;
    WHILE l_key IS NOT NULL LOOP
      IF regexp_like(l_key,'^#[^#]') THEN
          l_regex := '{' || l_key || '}';
          l_str := regexp_replace(l_str, l_regex, p_extra_info(l_key));
      END IF;
    l_key := p_extra_info.next(l_key);
    END LOOP;
  END IF;

  RETURN l_str;
EXCEPTION WHEN OTHERS THEN
  debug ('Exception when trying to expand tokens: ' || SQLERRM);
  return p_str;
END expand_tokens;
*/

---------------------------------------------------------------------
-- Populate user and respo details when running as conc request    --
---------------------------------------------------------------------
PROCEDURE populate_user_details IS
    l_user_name   fnd_user.user_name%type := fnd_global.user_name ;
    l_resp_name   VARCHAR2(256) := fnd_global.resp_name ;
BEGIN
   g_rep_info('Username') := mask_text(l_user_name, 'DISPLAY_BOTH_25_PCNT_WORD');  --EBSAF-280
   g_rep_info('Responsibility') := l_resp_name;
EXCEPTION WHEN OTHERS THEN
  debug ('Error in populate_user_details: '||sqlerrm);
END populate_user_details;


------------------------------------------------------
-- Expand the SQL tokens (for SQL only)             --
------------------------------------------------------
FUNCTION expand_sql_tokens(
  p_raw_sql IN VARCHAR2,
  p_mask_flag IN VARCHAR2 default null
) RETURN VARCHAR2
IS
  l_formatted_sql  VARCHAR2(32767);
  l_key             VARCHAR2(255);
  l_pattern         VARCHAR2(612);
  l_do_mask BOOLEAN := nvl(p_mask_flag, 'N') = 'Y';
BEGIN
  -- Assign signature to working variable
  l_formatted_sql := p_raw_sql;
  --  Replace SQL tokens inside the SQL (exclude the cases when the SQL token is used as a column alias)
  l_key := g_sql_tokens.first;
  WHILE l_key is not null LOOP
    l_pattern := '([^"])' || l_key;
    l_pattern := replace(l_pattern, '$' , '\$');
    -- Allow tokens to be masked (EBSAF-275)
    if l_do_mask then
        l_formatted_sql := regexp_replace(l_formatted_sql, l_pattern , '\1' || replace(g_masked_tokens(l_key),'\', '\\'));
		/*Allow tokens to have \1,\2..\9. regexp_replace is necessary to ensure it doesn't replace "##$$FK1$$##" column names needed to create the hidden column in parent signatures.
		The pattern adds a requirement that the character preceding the token is not a double-quote.
		(EBSAF-391)*/
    else
        l_formatted_sql := regexp_replace(l_formatted_sql, l_pattern , '\1' || replace(g_sql_tokens(l_key),'\', '\\'));
    end if;
    l_key := g_sql_tokens.next(l_key);
  END LOOP;
  RETURN l_formatted_sql;
EXCEPTION WHEN OTHERS THEN
  print_log('Error in expand_sql_tokens');
  raise;
END expand_sql_tokens;

/* CONSOLIDATED INTO expand_html (EBSAF-180)
------------------------------------------------------
-- Prepare the text with the substitution values     --
------------------------------------------------------
FUNCTION prepare_text(
  p_raw_text IN VARCHAR2
  ) RETURN VARCHAR2 IS
  l_formatted_text  VARCHAR2(32767);
  l_key             VARCHAR2(255);
BEGIN
  -- Assign signature to working variable
  l_formatted_text := p_raw_text;

  -- Allow tokens to be masked (EBSAF-275)
  l_key := g_masked_tokens.first;
  WHILE l_key is not null LOOP
    l_formatted_text := replace(l_formatted_text, l_key, g_masked_tokens(l_key));
    l_key := g_masked_tokens.next(l_key);
  END LOOP;
  RETURN l_formatted_text;
EXCEPTION WHEN OTHERS THEN
  print_log('Error in prepare_text');
  raise;
END prepare_text;
*/

------------------------------------------------------
-- Expand all values in text into HTML (EBSAF-180)  --
------------------------------------------------------
FUNCTION expand_html(
    p_raw_text  IN VARCHAR2,
    p_sig_id    IN VARCHAR2 default null
) RETURN VARCHAR2
IS
    l_step  VARCHAR2(20) := '00';
    l_html  VARCHAR2(32767);
    l_key   VARCHAR2(255);
    l_url   VARCHAR2(4000);
    l_sigrepo_id    VARCHAR2(10);
    l_extra_info    HASH_TBL_4K;
BEGIN
    -- Quick exit test
    if p_raw_text is null then
        return null;
    else
        l_html := p_raw_text;
    end if;

    -- Get signature details
    l_step := '10';
    if p_sig_id is not null and g_signatures.exists(p_sig_id) then
        l_sigrepo_id := g_signatures(p_sig_id).sigrepo_id;
        l_extra_info := g_signatures(p_sig_id).extra_info;
    end if;

    -- Expand masked SQL tokens: ##$$TOKEN$$##
    l_step := '20';
    IF regexp_like(l_html,'##\$\$[^#]+\$\$##') THEN
        l_key := g_masked_tokens.first;
        WHILE l_key is not null LOOP
            l_html := replace(l_html, l_key, g_masked_tokens(l_key));
            l_key := g_masked_tokens.next(l_key);
        END LOOP;
    END IF;

    -- Expand extra info tokens: {#TAG#}
    l_step := '30';
    IF l_extra_info.count > 0 and regexp_like(l_html,'\{#[^#]+#\}') THEN
        l_key := l_extra_info.first;
        WHILE l_key IS NOT NULL LOOP
            IF regexp_like(l_key,'^#[^#]+#') THEN
                l_html := replace(l_html,
                    '{' || l_key || '}', l_extra_info(l_key) );
            END IF;
            l_key := l_extra_info.next(l_key);
        END LOOP;
    END IF;

    -- Expand patch tokens: {123456}
    l_step := '40';
    l_html := regexp_replace(l_html,
        '\{([0-9]+)\}',
        '<a target="_blank" href="' || g_cmos_patch_url || '\1">\1</a>'
    );

    -- Expand note tokens: [432#HEADER]
    l_step := '50';
	
    l_html := regexp_replace(l_html,
        '\[((\d{3,})/(\w{3,})|(\d{3,})(\.\d)?)(#[^]]+)?\]',
        '<a target="_blank" href="' || g_cmos_km_url || '\2\4\6">\3\4</a>'
    );	
/* 	    l_html := regexp_replace(l_html,
        '\[([0-9]+)(\.[0-9])?(#[a-zA-Z 0-9_]+)?([^]]*)\]',
        '<a target="_blank" href="' || g_cmos_km_url || '\1\3">Doc ID \1</a>'
    ); */
/*     IF l_sigrepo_id is not null THEN
        l_url := g_cmos_doc_url || '_sigId' || l_sigrepo_id || '&id=';
    ELSE
        l_url := g_cmos_doc_url || '&id=';
    END IF;
    l_html := regexp_replace(l_html,
        -- EBSAF-297 Add space as allowed character in anchor
       -- '\[([0-9]+\.[0-9])(#[a-zA-Z 0-9_]+)?\]',
		  '\[([0-9]+)\.[0-9]+(#[a-zA-Z 0-9_]+)?\]',
        '<a target="_blank" href="' || l_url || '\1\2">Doc ID \1</a>'
    ); */

    RETURN l_html;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in expand_html at step ' || l_step);
    raise;
END expand_html;


---------------------------------------------
-- Remove [note] or {patch} token brackets --
---------------------------------------------
FUNCTION remove_links(p_text IN VARCHAR2)
    RETURN VARCHAR2
IS
    l_text VARCHAR2(32767);
BEGIN
    -- Quick exit test
    if p_text is null then
        return null;
    else
        l_text := p_text;
    end if;

    -- Strip patch tokens: {123456}
    l_text := regexp_replace(l_text,
        '\{([0-9]+)\}',
        '\1'
    );

    -- Strip note tokens: [432#HEADER]
    l_text := regexp_replace(l_text,
        '\[([0-9]+\.[0-9])(#[a-zA-Z 0-9_]+)?\]',
        '\1\2'
    );

    RETURN l_text;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in remove_links: '||sqlerrm||'.  Text unmodified.');
    RETURN p_text;
END remove_links;


----------------------------------------------------------
-- Change text like #ABC_DEF# into Abc Def              --
----------------------------------------------------------
FUNCTION word_to_titlecase(p_text IN VARCHAR2)
   RETURN VARCHAR2
IS
BEGIN
    return initcap(replace(replace(p_text,
        '_', ' '),
        '#', '')
    );
EXCEPTION WHEN OTHERS THEN
   print_log('Error in word_to_titlecase: '||sqlerrm||'.  Text unmodified.');
   return p_text;
END word_to_titlecase;


----------------------------------------------------------
-- Prepare the SQL for display in header and remove     --
-- references to FK strings                             --
----------------------------------------------------------
FUNCTION prepare_SQL(p_raw_SQL IN VARCHAR2)
   RETURN VARCHAR2
IS
   l_modified_SQL  VARCHAR2(32767);
BEGIN
   l_modified_SQL := escape_html(p_raw_SQL);  -- EBSAF-180
   l_modified_SQL := regexp_replace(l_modified_SQL, '\S+\s+"#{2}\${2}FK[0-9]\${2}#{2}"\s*,\s*', ' ');
   l_modified_SQL := regexp_replace(l_modified_SQL, ',\s*\S+\s+"#{2}\${2}FK[0-9]\${2}#{2}"\s*', ' ');
   l_modified_SQL := expand_sql_tokens(l_modified_SQL, 'Y');

   return l_modified_SQL;
EXCEPTION WHEN OTHERS THEN
   print_log('Error in prepare_SQL: '||sqlerrm||'.  Text unmodified.');
   return p_raw_SQL;
END prepare_SQL;


----------------------------------------------------------------
-- Set partial section result                                 --
----------------------------------------------------------------
PROCEDURE set_item_result(result varchar2) is
BEGIN
  IF g_sections(g_sections.last).result in ('U','I') THEN
          g_sections(g_sections.last).result := result;
      ELSIF g_sections(g_sections.last).result = 'S' THEN
        IF result in ('E','W') THEN
          g_sections(g_sections.last).result := result;
        END IF;
      ELSIF g_sections(g_sections.last).result = 'W' THEN
        IF result = 'E' THEN
          g_sections(g_sections.last).result := result;
        END IF;
      END IF;
  -- Set counts
  IF result = 'S' THEN
    g_sections(g_sections.last).success_count :=
       g_sections(g_sections.last).success_count + 1;
  ELSIF result = 'W' THEN
    g_sections(g_sections.last).warn_count :=
       g_sections(g_sections.last).warn_count + 1;
  ELSIF result = 'E' THEN
    g_sections(g_sections.last).error_count :=
       g_sections(g_sections.last).error_count + 1;
  END IF;
EXCEPTION WHEN OTHERS THEN
  print_log('Error in set_item_result: '||sqlerrm);
END set_item_result;


----------------------------------------------------------------------
-- Create associative tables that will keep the links
-- between the signatures that use hyperlinks
----------------------------------------------------------------------
PROCEDURE create_hyperlink_table IS
    TYPE l_split_str_type IS TABLE OF VARCHAR(126);
    l_split_str          l_split_str_type := l_split_str_type();
    l_hyperlink          VARCHAR2(512);
    l_hyperlink_group    VARCHAR2(2048);
    l_count              NUMBER;
    l_key                VARCHAR2(215);
    l_group_flag         BOOLEAN := TRUE;
    l_single_flag        BOOLEAN := TRUE;
BEGIN
    l_key := g_signatures.first;


    WHILE ((l_key IS NOT NULL) AND (g_signatures.EXISTS(l_key))) LOOP
        IF (g_signatures(l_key).extra_info.EXISTS('##HYPERLINK##')) AND (g_signatures(l_key).extra_info('##HYPERLINK##') IS NOT NULL) THEN
            l_hyperlink_group := g_signatures(l_key).extra_info('##HYPERLINK##');
             -- remove the table entry as we won't need it anymore
            g_signatures(l_key).extra_info.DELETE('##HYPERLINK##');

            -- if there are multiple links, push each group one by one (they are split through : )
            WHILE (l_hyperlink_group IS NOT NULL) LOOP
                l_hyperlink := regexp_substr(l_hyperlink_group, '^([^:]+)');
                l_hyperlink_group := regexp_replace(l_hyperlink_group, '^([^:]+)$', '');
                l_hyperlink_group := regexp_replace(l_hyperlink_group, '^([^:]+):(.+)', '\2');
            l_count := 1;

                -- split the string and extract the hyperlink details
                WHILE (l_count < 4) AND (l_hyperlink IS NOT NULL) LOOP
                     l_split_str.extend();
                     l_split_str(l_count) := regexp_substr(l_hyperlink, '^([^,]+)');
                     l_hyperlink := regexp_replace(l_hyperlink, '^([^,]+),(.+)', '\2');
                    l_count := l_count + 1;
                END LOOP;

                 IF (l_count < 3) THEN
                     print_log('Broken hyperlink! ');
                    GOTO go_next2;
                 END IF;

                -- populate dest to source table (anchors)
                g_dest_to_source(UPPER(l_split_str(2))).cols(UPPER(l_split_str(3))) := 'a' || to_char(g_hypercount);
                -- populate source to dest (links) table - sig and column names in upper case
                g_source_to_dest(l_key).cols(UPPER(l_split_str(1))) := 'a' || to_char(g_hypercount);
                g_hypercount := g_hypercount + 1;
            <<go_next2>>
            NULL;
            END LOOP;
        END IF;
    l_key := g_signatures.next(l_key);
    END LOOP;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in create_hyperlink_table: '||sqlerrm);
END create_hyperlink_table;


----------------------------------------------------------------------
-- Runs a single SQL using DBMS_SQL returns filled tables
-- Precursor to future run_signature which will call this and
-- the print api. For now calls are manual.
----------------------------------------------------------------------
FUNCTION run_sig_sql(
   p_sig_id       IN  VARCHAR2 DEFAULT '',  -- We need the sig id for printing it in the output (EBSAF-201)
   p_raw_sql      IN  VARCHAR2,     -- SQL in the signature may require substitution
   p_col_rows     OUT COL_LIST_TBL, -- signature SQL column names
   p_col_headings OUT VARCHAR_TBL,  -- signature SQL row values
   p_limit_rows   IN  VARCHAR2 DEFAULT 'Y',
   p_parent_sig_id IN VARCHAR2 DEFAULT NULL -- Needed for performance tracking (EBSAF-177)
) RETURN BOOLEAN IS
  l_sql            VARCHAR2(32700);
  c                INTEGER;
  l_rows_fetched   NUMBER;
  l_total_rows     NUMBER DEFAULT 0;
  l_step           VARCHAR2(20);
  l_col_rows       COL_LIST_TBL := col_list_tbl();
  l_col_headings   VARCHAR_TBL := varchar_tbl();
  l_col_cnt        INTEGER;
  l_desc_rec_tbl   DBMS_SQL.DESC_TAB2;
BEGIN
  sig_time_start(p_sig_id, p_parent_sig_id, 'Q'); -- EBSAF-177

  -- Prepare the Signature SQL
  l_step := '10';
  l_sql := expand_sql_tokens(p_raw_sql);

  l_step := '20';
  get_current_time(g_query_start_time);
  debug('Query start');
  c := dbms_sql.open_cursor;

  l_step := '30';
  DBMS_SQL.PARSE(c, l_sql, DBMS_SQL.NATIVE);

  -- Get column count and descriptions
  l_step := '40';
  DBMS_SQL.DESCRIBE_COLUMNS2(c, l_col_cnt, l_desc_rec_tbl);

  -- Register arrays to bulk collect results and set headings
  l_step := '50';
  FOR i IN 1..l_col_cnt LOOP
    l_step := '50.1.'||to_char(i);
    l_col_headings.extend();
    l_col_headings(i) := replace(l_desc_rec_tbl(i).col_name,'|','<br>');
    l_col_rows.extend();
    dbms_sql.define_array(c, i, l_col_rows(i), g_max_output_rows, 1);
  END LOOP;

  -- Execute and Fetch
  l_step := '60';
  -- the return value from DBMS_SQL.EXECUTE() will always be 0 for SELECT, so the actual value of l_rows_fetched will come from FETCH
  l_rows_fetched := DBMS_SQL.EXECUTE(c);
  l_rows_fetched := DBMS_SQL.FETCH_ROWS(c);

  l_step := '70';
  IF l_rows_fetched > 0 THEN
    FOR i in 1..l_col_cnt LOOP
      l_step := '70.1.'||to_char(i);
      DBMS_SQL.COLUMN_VALUE(c, i, l_col_rows(i));
    END LOOP;
  l_total_rows := l_rows_fetched;
  END IF;
  IF nvl(p_limit_rows,'Y') = 'N' THEN
    WHILE l_rows_fetched = g_max_output_rows LOOP
      l_rows_fetched := DBMS_SQL.FETCH_ROWS(c);
      l_total_rows := l_total_rows + l_rows_fetched;
      FOR i in 1..l_col_cnt LOOP
        l_step := '70.2.'||to_char(i);
        DBMS_SQL.COLUMN_VALUE(c, i, l_col_rows(i));
      END LOOP;
    END LOOP;
  END IF;
  g_query_elapsed := stop_timer(g_query_start_time);
  debug('Query finish ('||format_elapsed(g_query_elapsed)||')');
  debug(' Rows fetched: '||to_char(l_total_rows));

  -- Close cursor
  l_step := '80';
  IF dbms_sql.is_open(c) THEN
    dbms_sql.close_cursor(c);
  END IF;

  -- Set out parameters
  p_col_headings := l_col_headings;
  p_col_rows := l_col_rows;
  sig_time_add(p_sig_id, p_parent_sig_id, 'Q'); -- EBSAF-177 Time only needed for successful query

  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    g_query_elapsed := stop_timer(g_query_start_time);
    debug('Query failed ('||format_elapsed(g_query_elapsed)||')');
    g_errbuf := 'PROGRAM ERROR'||chr(10)||
      'Error in run_sig_sql at step '|| l_step||': '||sqlerrm||chr(10)||
      'See the log file for additional details';
    print_log('Error in run_sig_sql at step '||l_step||' running: '||l_sql);
    print_log('Error: '||sqlerrm);
    IF dbms_sql.is_open(c) THEN
      dbms_sql.close_cursor(c);
    END IF;
    RETURN FALSE;
END run_sig_sql;

FUNCTION get_tags (
  p_sig_id     VARCHAR2) RETURN VARCHAR2
IS
  l_tags_str  VARCHAR2(512);
  l_replace_pattern VARCHAR2(200);
BEGIN
  l_tags_str := '';
  l_replace_pattern := '                    <div class="sigtag"  tag="\1" style="display:none;"></div>
';
  IF (
    g_signatures.EXISTS(p_sig_id)
    AND g_signatures(p_sig_id).extra_info.EXISTS('#IMPACT_AREAS#')
    AND g_signatures(p_sig_id).extra_info('#IMPACT_AREAS#') IS NOT NULL
  ) THEN
        l_tags_str := g_signatures(p_sig_id).extra_info('#IMPACT_AREAS#');
        l_tags_str := regexp_replace(l_tags_str, '([a-zA-Z0-9][^,]+[0-9a-zA-Z])', l_replace_pattern, 1, 0);
        l_tags_str := regexp_replace(l_tags_str, chr(10)||', ', chr(10), 1, 0);
  END IF;
  RETURN l_tags_str;
EXCEPTION
  WHEN OTHERS THEN
  print_log ('Could not get tags / impact areas for sig id: ' || p_sig_id);
  print_log (SQLERRM);
  RETURN '';
END get_tags;

----------------------------------------------------------------------
-- XML functions to simplify DX summary creation
----------------------------------------------------------------------
-- Create XML node with multiple attributes and return it
FUNCTION append_hidden_xml(
    p_parent_node XMLDOM.DOMNode,
    p_tag_name varchar2,
    p_tag_type varchar2 default null,
    p_tag_text varchar2 default null,
    p_attr_list varchar_tbl,
    p_val_list varchar_tbl
) RETURN XMLDOM.DOMNode IS
    l_elem XMLDOM.DOMElement;
    l_node XMLDOM.DOMNode;
    l_empty varchar2(15) := '';  -- Placeholder for empty content
BEGIN
    -- Abort if XML not available
    if g_dx_summary_error is not null then
       raise program_error;
    end if;

    -- Create the new node
    l_elem := XMLDOM.createElement(g_hidden_xml, p_tag_name);
    l_node := XMLDOM.appendChild(p_parent_node, XMLDOM.makeNode( l_elem ) );

    -- Add text if needed
    if (p_tag_type = 'TEXT') then
        l_node := XMLDOM.appendChild( l_node,
            XMLDOM.makeNode( XMLDOM.createTextNode(g_hidden_xml, nvl(p_tag_text, l_empty) ) )
        );
    elsif (p_tag_type = 'CDATA') then
        l_node := XMLDOM.appendChild( l_node,
            XMLDOM.makeNode( XMLDOM.createCDATASection(g_hidden_xml, nvl(p_tag_text, l_empty) ) )
        );
    end if;

    -- Add attributes if needed
    if p_attr_list is not null then
        for i in 1..p_attr_list.count loop
            if (p_attr_list(i) is not null and p_val_list(i) is not null) then
                XMLDOM.setAttribute(l_elem, p_attr_list(i), p_val_list(i) );
            end if;
        end loop;
    end if;

    -- Return the new node
    return l_node;
EXCEPTION
    when program_error then
        print_log('Error in append_hidden_xml: XML not available due to prior error');
        raise;
    when others then
        print_log('Error in append_hidden_xml: '||SQLERRM);
        raise;
END append_hidden_xml;
-- Overload: Create XML node with one or zero attributes and return it
FUNCTION append_hidden_xml(
    p_parent_node XMLDOM.DOMNode,
    p_tag_name varchar2,
    p_tag_type varchar2 default null,
    p_tag_text varchar2 default null,
    p_attr varchar2 default null,
    p_val varchar2 default null
) RETURN XMLDOM.DOMNode IS
BEGIN
    return append_hidden_xml(p_parent_node, p_tag_name, p_tag_type, p_tag_text, varchar_tbl(p_attr), varchar_tbl(p_val) );
END append_hidden_xml;

-- Get an XML node with specified name, orphaned if not found
function get_hidden_xml(
    p_node_name varchar2 default null
) return XMLDOM.DOMNode is
    l_root_node XMLDOM.DOMNode;
    l_child_nodes XMLDOM.DOMNodeList;
begin
    -- Start at root
    l_root_node := XMLDOM.getFirstChild(XMLDOM.makeNode(g_hidden_xml));
    if (p_node_name is null) then
        return l_root_node;
    end if;

    -- Get first matching child node
    l_child_nodes := XMLDOM.getChildrenByTagName(XMLDOM.makeElement(l_root_node), p_node_name);
    if (XMLDOM.getLength(l_child_nodes) > 0) then
        return XMLDOM.item(l_child_nodes, 0);
    end if;

    -- Nothing found so create as orphan
    return XMLDOM.makeNode(XMLDOM.createElement(g_hidden_xml, p_node_name));
end get_hidden_xml;


procedure initialize_hidden_xml is
    l_step varchar2(3) := '0';
    l_root_node XMLDOM.DOMNode;
    l_main_node XMLDOM.DOMNode;
    l_temp_node XMLDOM.DOMNode;

    l_key varchar2(255);
    l_value varchar2(4000);
begin
    -- Prepare document root
    l_step := '10';
    g_hidden_xml := XMLDOM.newDOMDocument;
    l_root_node := XMLDOM.appendChild(XMLDOM.makeNode(g_hidden_xml), XMLDOM.makeNode(XMLDOM.createElement(g_hidden_xml,'diagnostic')));

    -- Prepare main nodes
    l_step := '20';
    l_main_node := append_hidden_xml(l_root_node, 'run_details');
    l_main_node := append_hidden_xml(l_root_node, 'parameters');
    l_main_node := append_hidden_xml(l_root_node, 'tokens');
    l_main_node := append_hidden_xml(l_root_node, 'issues');
    l_main_node := append_hidden_xml(l_root_node, 'exceptions');

    -- Populate run details from report info
    l_step := '30';
    l_main_node := get_hidden_xml('run_details');
    l_key := g_rep_info.first;
    while l_key is not null loop
        l_temp_node := append_hidden_xml(
            p_parent_node => l_main_node,
            p_tag_name => 'detail',
            p_tag_type => 'TEXT',
            p_tag_text => plain_text(g_rep_info(l_key)),
            p_attr => 'name',
            p_val => l_key
        );
        l_key := g_rep_info.next(l_key);
    end loop;

    -- Add run detail: Cloud
    l_step := '32';
    l_temp_node := append_hidden_xml(
        p_parent_node => l_main_node,
        p_tag_name => 'detail',
        p_tag_type => 'TEXT',
        p_tag_text => case when g_cloud_flag then 'Y' else 'N' end,
        p_attr => 'name',
        p_val => 'Cloud'
    );

    -- Add run detail: g2g
    l_step := '34';
    l_temp_node := append_hidden_xml(
        p_parent_node => l_main_node,
        p_tag_name => 'detail',
        p_tag_type => 'TEXT',
        p_tag_text => case when g_g2g_flag then 'C' else 'R' end,
        p_attr => 'name',
        p_val => 'g2g'
    );

    -- Add run detail: GUID
    l_step := '36';
    l_temp_node := append_hidden_xml(
        p_parent_node => l_main_node,
        p_tag_name => 'detail',
        p_tag_type => 'TEXT',
        p_tag_text => g_guid,
        p_attr => 'name',
        p_val => 'GUID'
    );

    -- Populate parameters
    l_step := '40';
    l_main_node := get_hidden_xml('parameters');
    for i in 1..g_parameters.count loop
        l_temp_node := append_hidden_xml(
            p_parent_node => l_main_node,
            p_tag_name => 'parameter',
            p_tag_type => 'TEXT',
            p_tag_text => g_parameters(i).pvalue,
            p_attr => 'name',
            p_val => to_char(i) || '. ' ||g_parameters(i).pname
        );
    end loop;

    -- Populate tokens
    l_step := '50';
    l_main_node := get_hidden_xml('tokens');
    l_key := g_masked_tokens.first;
    while l_key is not null loop
        -- Ignore parent/child FKs
        if (l_key not like '##$$FK_$$##') then
            -- Delete invalid characters from value (EBSAF-263) and remove links (EBSAF-233)
            l_value := substr(remove_links(filter_html(g_masked_tokens(l_key),'I','D')), 1, 4000);

            l_temp_node := append_hidden_xml(
                p_parent_node => l_main_node,
                p_tag_name => 'token',
                p_tag_type => 'TEXT',
                p_tag_text => l_value,
                p_attr => 'name',
                p_val => l_key
            );
        end if;
        l_key := g_masked_tokens.next(l_key);
    end loop;
exception
    when others then
        print_log('Error in initialize_hidden_xml at step '||l_step||': '||SQLERRM);
        g_dx_summary_error := '<DXSUMMGENERR><![CDATA[' ||
            'Error in initialize_hidden_xml at step '||l_step||': '||SQLERRM||chr(10)||
            'Exception stack: '||chr(10)||
            SUBSTR(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 3500)||
            ']]></DXSUMMGENERR>';
end initialize_hidden_xml;


-- EBSAF-177 Add performance details for all processed signatures
PROCEDURE generate_stats_xml IS
    l_stat_id varchar2(320);
    l_sig_id varchar2(320);
    l_parent_sig_id varchar2(320);
    l_sig_rec sig_stats_rec;
    l_perf_node XMLDOM.DOMNode;
    l_sig_node XMLDOM.DOMNode;
    l_temp_node XMLDOM.DOMNode;
BEGIN
    -- Skip if previous DX error
    if g_dx_summary_error is not null then
        return;
    end if;

    -- Get details
    l_perf_node := append_hidden_xml(
        p_parent_node => get_hidden_xml(),
        p_tag_name => 'performance',
        p_attr => 'analyzer_time',
        p_val => trim(to_char(seconds_elapsed(g_analyzer_elapsed),'999999999999.000') ) );

    -- Get details for all signatures
    l_stat_id := g_sig_stats.first;
    while l_stat_id is not null loop
        l_sig_rec := g_sig_stats(l_stat_id);
        l_sig_id := regexp_replace(l_stat_id, '(.*)[|](.*)', '\1');
        l_parent_sig_id := regexp_replace(l_stat_id, '(.*)[|](.*)', '\2');

        l_sig_node := append_hidden_xml(
            p_parent_node => l_perf_node,
            p_tag_name => 'signature',
            p_attr_list => varchar_tbl('id', 'parent_id'),
            p_val_list => varchar_tbl(l_sig_id, l_parent_sig_id) );
        l_temp_node := append_hidden_xml(
            p_parent_node => l_sig_node,
            p_tag_name => 'sig_version',
            p_tag_type => 'TEXT',
            p_tag_text => l_sig_rec.version );
        l_temp_node := append_hidden_xml(
            p_parent_node => l_sig_node,
            p_tag_name => 'sig_query_time',
            p_tag_type => 'TEXT',
            p_tag_text => trim(to_char(l_sig_rec.query_time, '999999999999.000') ) );
        l_temp_node := append_hidden_xml(
            p_parent_node => l_sig_node,
            p_tag_name => 'sig_process_time',
            p_tag_type => 'TEXT',
            p_tag_text => trim(to_char(l_sig_rec.process_time, '999999999999.000') ) );
        l_temp_node := append_hidden_xml(
            p_parent_node => l_sig_node,
            p_tag_name => 'sig_row_count',
            p_tag_type => 'TEXT',
            p_tag_text => l_sig_rec.row_count );

        l_stat_id := g_sig_stats.next(l_stat_id);
    end loop;
EXCEPTION
    WHEN OTHERS THEN
        -- Performance details are non-essential
        print_log('Error in generate_stats_xml: '||SQLERRM);
END generate_stats_xml;


procedure append_error_xml(
    p_sig_id    varchar2,
    p_error     varchar2
) is
    l_sig signature_rec;
    l_sig_node XMLDOM.DOMNode;
    l_temp_node XMLDOM.DOMNode;
begin
    -- Skip if previous DX error
    if g_dx_summary_error is not null then
        return;
    end if;

    -- Get signature details
    l_sig := g_signatures(p_sig_id);

    -- Add exception node
    l_sig_node := append_hidden_xml(
        p_parent_node => get_hidden_xml('exceptions'),
        p_tag_name => 'signature',
        p_attr_list => varchar_tbl(
            'id',
            'sig_repo_id',
            'sig_version',
            'sig_type',
            'azr_id'
        ),
        p_val_list => varchar_tbl(
            p_sig_id,
            l_sig.sigrepo_id,
            l_sig.version,
            l_sig.fail_type,
            '808'
        )
    );

    -- Add exception details
    l_temp_node := append_hidden_xml(
        p_parent_node => l_sig_node,
        p_tag_name => 'exception',
        p_tag_type => 'CDATA',
        p_tag_text => p_error
    );
exception when others then
    print_log('Error in append_error_xml: '||sqlerrm);
end append_error_xml;


procedure append_hits_xml(
    p_sig_id        varchar2,       -- Name of signature item
    p_col_rows      col_list_tbl,   -- signature SQL row values
    p_col_headings  VARCHAR_TBL,    -- signature SQL column names
    p_fail_col      NUMBER,         -- Custom fail column ID
    p_fail_flags    VARCHAR_TBL,    -- Rows failed
    p_mask_opts     VARCHAR_TBL,    -- Column masking options
    p_parent_sig_id VARCHAR2 DEFAULT NULL   -- flag identifying a child sig
) is
    l_sig signature_rec;
    l_key varchar2(255);
    l_value varchar2(4000);
    l_info_count integer;
    l_fail_count integer;
    l_data_count integer;
    l_remaining integer;
    l_fail_only boolean;
    l_filter_cols boolean;

    l_orphan_node XMLDOM.DOMNode;
    l_sig_node XMLDOM.DOMNode;
    l_info_node XMLDOM.DOMNode;
    l_fail_node XMLDOM.DOMNode;
    l_temp_node XMLDOM.DOMNode;
    l_step varchar2(3) := '0';
begin
    -- Skip if previous DX error
    if g_dx_summary_error is not null then
        return;
    end if;

    -- Get signature details
    l_step := '10';
    l_sig := g_signatures(p_sig_id);

    -- Verify XML is needed
    l_step := '20';
    if (l_sig.include_in_xml = 'P') then
        -- Partial entries only print once
        if (g_dx_printed.exists(p_sig_id)) then
            return;
        else
            g_dx_printed(p_sig_id) := 1;
        end if;
    elsif (l_sig.include_in_xml = 'N') then
        -- Not printed at all
        return;
    end if;

    -- Create orphan node as temporary parent
    l_step := '30';
    l_orphan_node := get_hidden_xml('orphaned');

    -- Create signature node
    l_step := '40';
    l_sig_node := append_hidden_xml(
        p_parent_node => l_orphan_node,
        p_tag_name => 'signature',
        p_attr_list => varchar_tbl(
            'id',
            'sig_repo_id',
            'sig_version',
            'sig_type',
            'azr_id'
        ),
        p_val_list => varchar_tbl(
            p_sig_id,
            l_sig.sigrepo_id,
            l_sig.version,
            l_sig.fail_type,
            '808'
        )
    );

    -- Append extra info
    l_step := '50';
    if (l_sig.extra_info.count > 0) then
        -- Prepare child node
        l_info_node := append_hidden_xml(l_orphan_node, 'sigxinfo');

        -- Add info if needed
        l_key := l_sig.extra_info.first;
        while l_key is not null loop
            -- skip internal use keys
            if (l_key not like '##%') then
                l_temp_node := append_hidden_xml(
                    p_parent_node => l_info_node,
                    p_tag_name => 'info',
                    p_tag_type => 'TEXT',
                    p_tag_text => l_sig.extra_info(l_key),
                    p_attr => 'name',
                    p_val => l_key
                );
            end if;
            l_key := l_sig.extra_info.next(l_key);
        end loop;

        -- Add child node only if populated
        if (XMLDOM.hasChildNodes(l_info_node)) then
            l_temp_node := XMLDOM.appendChild(l_sig_node, l_info_node);
        end if;
    end if;

    -- Verify results are needed
    l_step := '60';
    if (l_sig.include_in_xml = 'P' or p_col_rows(1).count = 0) then
        l_fail_count := 0;
        l_data_count := 0;
    else
        l_fail_count := p_col_rows(1).count;
        l_data_count := p_col_headings.count;
    end if;

    -- Result option: included row count
    l_step := '70';
    l_remaining := least(50, l_fail_count);
    if (l_sig.extra_info.exists('##DX_ROWS##') and regexp_like(l_sig.extra_info('##DX_ROWS##'), '^[0-9]+$')) then
        l_remaining := least(l_remaining, to_number(l_sig.extra_info('##DX_ROWS##')));
    end if;

    -- Result option: included row types
    l_step := '72';
    if (l_fail_count = 0) then
        l_fail_only := false;
    elsif (l_sig.fail_condition in ('RSGT1','RS','NRS')) then
        -- All rows are failure rows
        l_fail_only := false;
    elsif (l_sig.extra_info.exists('##DX_FAIL_ONLY##') and l_sig.extra_info('##DX_FAIL_ONLY##') = 'Y') then
        l_fail_only := true;
    elsif (l_sig.extra_info.exists('##DX_FAIL_ONLY##') and l_sig.extra_info('##DX_FAIL_ONLY##') = 'N') then
        l_fail_only := false;
    elsif (g_rec_patch_in_dx = 'F') then
        l_fail_only := true;
    else
        l_fail_only := false;
    end if;
    if (l_fail_only and p_fail_col = 0) then
        -- Failure column is invalid so no rows
        l_remaining := 0;
    end if;

    -- Result option: included row columns
    l_step := '74';
    l_filter_cols := false;
    if (l_data_count > 0) then
        l_key := l_sig.extra_info.first;
        while l_key is not null loop
            if (l_key like '##DX_COL##%') then
                l_filter_cols := true;
                exit;
            end if;
            l_key := l_sig.extra_info.next(l_key);
        end loop;
    end if;

    -- Append results
    l_step := '80';
    for i in 1..l_fail_count loop
        exit when l_remaining = 0;

        -- Skip excluded rows
        continue when l_fail_only and p_fail_flags(i) = 'N';

        -- Prepare child node
        l_remaining := l_remaining - 1;
        l_fail_node := append_hidden_xml(
            p_parent_node => l_orphan_node,
            p_tag_name => 'failure',
            p_attr => 'row',
            p_val => i
        );

        -- Append column nodes
        for j in 1..l_data_count loop
            -- Skip removed columns
            continue when p_mask_opts(j) = 'REMOVE_COLUMN';

            -- Skip excluded columns
            l_key := filter_html(p_col_headings(j),'I','D');
            continue when l_filter_cols and not l_sig.extra_info.exists('##DX_COL##' || upper(l_key));

            -- Process data
            l_value := substr(remove_links(filter_html(p_col_rows(j)(i),'I','D')), 1, 4000);
            l_value := mask_text(l_value, p_mask_opts(j) );
            l_temp_node := append_hidden_xml(
                p_parent_node => l_fail_node,
                p_tag_name => 'column',
                p_tag_type => 'TEXT',
                p_tag_text => l_value,
                p_attr => 'name',
                p_val => l_key
            );
        end loop;

        -- Add child node only if populated
        if (XMLDOM.hasChildNodes(l_fail_node)) then
            l_temp_node := XMLDOM.appendChild(l_sig_node, l_fail_node);
        else
            -- No rows needed if no columns
            exit;
        end if;
    end loop;
    -- Move completed signature node
    l_temp_node := XMLDOM.appendChild(get_hidden_xml('issues'), l_sig_node);
exception when others then
    l_value := 'Error in append_hits_xml at step '||l_step||' for sig '||p_sig_id||' : '||sqlerrm;
    print_log(l_value);
    append_error_xml(p_sig_id, l_value);
end append_hits_xml;


PROCEDURE print_hidden_xml
IS
    l_hidden_xml_clob   clob;
    l_issues_nodes      XMLDOM.DOMNodeList;
    l_issues_node       XMLDOM.DOMNode;
    l_node              XMLDOM.DOMNode;
BEGIN

    IF g_dx_summary_error IS NOT NULL THEN
        print_out('<script id="dx-summary" type="application/xml">','Y');
        print_out('<!-- ######BEGIN DX SUMMARY######-->','Y');
        print_out(g_dx_summary_error);
        print_out('<!-- ######END DX SUMMARY######-->','Y');
        print_out('</script>','Y');
        g_dx_summary_error:=null;
        return;
    END IF;

    -- EBSAF-177 Add performance stats to DX summary
    generate_stats_xml;

    /* Replaced by EBSAF-264
    -- EBSAF-215 (avoid empty self-closing nodes)
    IF (g_issues_count = 0) THEN
        l_issues_nodes := XMLDOM.getElementsByTagName(g_hidden_xml,'issues');
        -- EBSAF-237
        IF NOT XMLDOM.isNULL(l_issues_nodes) THEN
            BEGIN
                l_issues_node := XMLDOM.item(l_issues_nodes, 0);
                l_node := XMLDOM.appendChild(l_issues_node,XMLDOM.makeNode(XMLDOM.createTextNode(g_hidden_xml,'')));
            --EBSAF-239
            EXCEPTION
                WHEN OTHERS THEN
                    l_node := XMLDOM.appendChild(l_issues_node,XMLDOM.makeNode(XMLDOM.createTextNode(g_hidden_xml,' ')));
            END;
        END IF;
    END IF;
    */

    dbms_lob.createtemporary(l_hidden_xml_clob, true);

    --print CLOB
    XMLDOM.WRITETOCLOB(g_hidden_xml, l_hidden_xml_clob);
    -- EBSAF-264 - Locate self-closing tags and create matching closing tag
    -- \1 is actual tag
    -- \2 is tag attributes
    l_hidden_xml_clob := regexp_replace(l_hidden_xml_clob, '<(\w+)([^>]*)/>', '<\1\2></\1>');

    print_out('<script id="dx-summary" type="application/xml">','Y');
    print_out('<!-- ######BEGIN DX SUMMARY######-->','Y');
    print_clob(l_hidden_xml_clob);
    print_out('<!-- ######END DX SUMMARY######-->','Y');
    print_out('</script>','Y');

    dbms_lob.freeTemporary(l_hidden_xml_clob);
    XMLDOM.FREEDOCUMENT(g_hidden_xml);

EXCEPTION
   WHEN OTHERS THEN
      print_log('Error in print_hidden_xml: '||SQLERRM);
END print_hidden_xml;


procedure print_sig_exceptions
is
    l_sig_id varchar2(255);
begin
    if (g_sig_errors.count > 0) then
        print_log('Signatures where exception occurred:');
        l_sig_id := g_sig_errors.first;
        while l_sig_id is not null loop
            print_log('- ' || l_sig_id || ' "' || g_sig_errors(l_sig_id) || '"');
            l_sig_id := g_sig_errors.next(l_sig_id);
        end loop;
    end if;
exception
   when others then
      print_log('Error in print_sig_exceptions: '||sqlerrm);
end print_sig_exceptions;


----------------------------------------------------------------
-- Get the cell formatting options from the Sig Repo          --
-- and tranform it into CSS style                             --
----------------------------------------------------------------
FUNCTION get_style(p_style_string VARCHAR2) RETURN VARCHAR2
IS
   l_formatted_style     VARCHAR2(1024) := '';
   l_styles              resultType;
   l_key                 VARCHAR2(32);
   l_count               NUMBER := 0;
BEGIN
   IF (p_style_string is null) THEN
       print_log ('Formatting string is empty');
       return '';
   END IF;

   BEGIN
       l_styles('text-align') := substr(p_style_string, 1, instr(p_style_string, ',', 1, 1) - 1);
       l_styles('color') := substr(p_style_string, instr(p_style_string, ',', 1, 1) + 1, instr(p_style_string, ',', 1, 2) - instr(p_style_string, ',', 1, 1) - 1);
       l_styles('background-color') := substr(p_style_string, instr(p_style_string, ',', 1, 2) + 1, instr(p_style_string, ',', 1, 3) - instr(p_style_string, ',', 1, 2) - 1);
       l_styles('font-weight') := substr(p_style_string, instr(p_style_string, ',', 1, 3) + 1);
   EXCEPTION
      WHEN OTHERS THEN
          print_log('Error in get_style extracting the format details: '|| sqlerrm);
          return '';
   END;

    l_key := l_styles.first;
    l_formatted_style := 'style="';

    WHILE ((l_key IS NOT NULL) AND (l_styles.EXISTS(l_key))) LOOP
        IF (l_styles(l_key) IS NOT NULL) THEN
            l_formatted_style := l_formatted_style || l_key || ':' || l_styles(l_key) || ';';
            l_count := l_count + 1;
        END IF;
    l_key := l_styles.next(l_key);
    END LOOP;

    l_formatted_style := l_formatted_style || '"';

    IF (l_count = 0) THEN   -- if all styles have been empty, return empty string
        return '';
    END IF;
    return l_formatted_style;
EXCEPTION
   WHEN OTHERS THEN
   print_log('Error in get_style formatting the column: ' || sqlerrm);
   return '';
END get_style;


------------------------------------------------------------------
-- Get the mask option for a specified column (EBSAF-269)       --
------------------------------------------------------------------
FUNCTION get_mask_option(p_col_num number,
    p_col_name varchar2,
    p_extra_info HASH_TBL_4K) return varchar2
IS
    l_default varchar2(255) := 'NO_MASK';
    l_col_key varchar2(255);
    l_opt_key varchar2(255);
BEGIN
    if p_extra_info.exists('##MASK##' || p_col_num) then
        -- Check by column number
        return nvl(upper(trim(p_extra_info('##MASK##' || p_col_num))), l_default);
    elsif p_extra_info.exists('##MASK##' || p_col_name) then
        -- Check by exact column name
        return nvl(upper(trim(p_extra_info('##MASK##' || p_col_name))), l_default);
    else
        -- Check by wildcard column name
        l_col_key := '##MASK##' || p_col_name;
        l_opt_key := p_extra_info.first;
        while (l_opt_key is not null) loop
            if (l_col_key like l_opt_key) then
                return nvl(upper(trim(p_extra_info(l_opt_key))), l_default);
            end if;
            l_opt_key := p_extra_info.next(l_opt_key);
        end loop;

        -- Return default
        return l_default;
    end if;
EXCEPTION
    WHEN OTHERS THEN
        print_log('Error in get_mask_option('||p_col_num||','||p_col_name||'): ' || sqlerrm);
        print_log('Using default option: ' || l_default);
        return l_default;
END get_mask_option;


------------------------------------------------------------------
-- Get the chart definitions script for a signature             --
------------------------------------------------------------------
FUNCTION get_chartdef(
    p_id varchar2,
    p_info hash_tbl_4k
) return varchar2
IS
    l_json varchar2(32767);
    l_html varchar2(32767);
    l_key varchar2(255);
    l_old_chart varchar2(255);
    l_new_chart varchar2(255);
    l_option varchar2(255);
    l_value varchar2(4000);
BEGIN
    -- Write chart options as JSON
    l_old_chart := '1';
    l_key := p_info.first;
    while (l_key is not null) loop
        -- Chart keys are case sensitive so ignore copied keys in uppercase
        if (l_key <> upper(l_key)) then
            l_new_chart := regexp_substr(l_key, '^##CHART##(\d+)#.', 1, 1, '', 1);
            -- Must be valid chart key
            if (l_new_chart is not null) then
                -- Check if new chart object
                if (l_new_chart <> l_old_chart) then
                    l_json := rtrim(l_json, ',') || '},' || chr(10) || '{';
                    l_old_chart := l_new_chart;
                end if;

                -- Append option
                l_option := substr(l_key, instr(l_key, '#', 1,5) + 1);
                l_value := p_info(l_key);
                l_json := l_json || '"' || l_option || '":"' || l_value || '",';
            end if;
        end if;
        l_key := p_info.next(l_key);
    end loop;

    -- Abort if no chart options
    if (l_json is null) then
        return null;
    end if;

    -- Wrapper JSON
    l_json := '{"source":"restable_' || p_id || '","charts":[' || chr(10) ||
        '{' || rtrim(l_json, ',') || '}' || chr(10) ||
        ']}';

    -- Wrapper HTML
    l_html := chr(10) ||
        '<!-- chart configuration script -->' || chr(10) ||
        '<script id="chartdef_' || p_id || '" type="application/json" class="sig-chart-defs">' || chr(10) ||
        l_json || chr(10) ||
        '</script>';

    return l_html;
END get_chartdef;


------------------------------------------------------------------
-- For signatures that have print condition set to failure      --
-- and are successful, print partial details on a separate page --
------------------------------------------------------------------
PROCEDURE get_sig_partial(
    p_sig_html  IN OUT NOCOPY CLOB,
    p_sig_id    VARCHAR2,
    p_level NUMBER default null,
    p_class_string VARCHAR2 default null,
    p_error_msg VARCHAR2 default null
) IS
    l_sig           SIGNATURE_REC;
    l_level         NUMBER;
    l_result        VARCHAR2(1);
    l_views         VARCHAR2(255);
    l_current_sig   VARCHAR2(6);
    l_step          VARCHAR(260);
    l_html          VARCHAR2(32767);
    l_i             VARCHAR2(255);
BEGIN
    -- Get sig details
    l_step := '10';
    if (g_signatures.exists(p_sig_id)) then
        l_sig := g_signatures(p_sig_id);
        l_level := nvl(p_level, 1);
        if (p_error_msg is null) then
            l_result := 'P';
            l_views := null;
        else
            l_result := 'X';
            l_views := 'section print analysis';
            g_sig_errors(p_sig_id) := expand_html(l_sig.title);
            append_error_xml(p_sig_id, p_error_msg);
        end if;
    else
        -- No signature details so nothing to print
        print_log('Error: No details for signature ID ' || p_sig_id);
        raise NO_DATA_FOUND;
    end if;

    -- Clear buffer if needed
    if (p_sig_html is not null) then
        dbms_lob.trim(p_sig_html, 0);
    end if;

    -- Open signature container
    l_step := '20';
    g_sig_count := g_sig_count + 1;
    l_current_sig := 'S'||to_char(g_sig_count);  --build signature class name
    l_html := '
<!-- '||l_current_sig||' -->
               <div class="data sigcontainer signature '||p_class_string||' '||l_current_sig||' '||l_result||' '||l_views||'" sig="'||p_sig_id||'" level="'||l_level||'"  id="'||l_current_sig||'" style="display: none;">
                    <div class="divItemTitle">
                        <div class="sigdescription" style="display:inline;"><table style="display:inline;"><tr class="'||l_current_sig||' '||l_result||' sigtitle"><td class="divItemTitlet">'||expand_html(l_sig.title)||'</td></tr></table></div>';
    -- Show info icon only if needed
    if (l_sig.extra_info.count > 0 OR l_sig.sig_sql is not null) then
        l_html := l_html || '
                        <a class="detailsmall" toggle-info="tbitm_'||l_current_sig||'"><span class="siginfo_ico" title="Show signature information" alt="Show Info"></span></a>';
    end if;
    -- Show copy SQL icon only if needed (SHOW_SQL != 'N' and the SQL string is not null)
    IF ((l_sig.sig_sql is not null) AND ((NOT l_sig.extra_info.EXISTS('##SHOW_SQL##')) OR (l_sig.extra_info.EXISTS('##SHOW_SQL##')) AND (nvl(l_sig.extra_info('##SHOW_SQL##'), 'Y') != 'N'))) THEN
        l_html := l_html || '
                        <a class="detailsmall" href="javascript:;" onclick=''copySql("sql_'||l_current_sig||'")''><span class="copysql_ico" title="Copy SQL query to clipboard" alt="Copy SQL"></span></a>';
    end if;
    -- Add feedback
	l_html := l_html || '
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,808,'||l_sig.sigrepo_id||',EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="thumb_up" title="Signature Feedback: Thumbs Up"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,808,'||l_sig.sigrepo_id||',EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="thumb_dn" title="Signature Feedback: Thumbs Down"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_SIGNATURE_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},808,'||l_sig.sigrepo_id||',EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="af_idea" title="Signature Idea"></span></a>
	</div>';


    print_buffer(p_sig_html, l_html);
    l_html := null;

    -- Print collapsable/expandable extra info table if there are contents
    l_step := '30';
    IF l_sig.extra_info.count > 0 OR l_sig.sig_sql is not null THEN
        l_step := '40';
        l_html := '
                        <table class="table1 data" id="tbitm_' || l_current_sig || '" style="display:none">
                        <thead>
                           <tr><th bgcolor="#f2f4f7" class="sigdetails">Item Name</th><th bgcolor="#f2f4f7" class="sigdetails">Item Value</th></tr>
                        </thead>
                        <tbody>';
        print_buffer(p_sig_html, l_html);
        l_html := null;
        -- Loop and print values
        l_step := '50';
        l_i := l_sig.extra_info.FIRST;
        WHILE (l_i IS NOT NULL) LOOP
          l_step := '60.'||l_i;
          -- don't print the extra info that starts with ## (these are hidden)
          IF (NOT regexp_like(l_i,'^##')) THEN
               -- if extra info includes keys like #IMPACT_AREAS#, change the display name to IMpact Areas (title case)
              IF (regexp_like(l_i,'^#[0-9a-zA-Z]')) THEN
                  l_html := l_html || '                           <tr><td>' || word_to_titlecase(l_i) || '</td><td>'||
                      l_sig.extra_info(l_i) || '</td></tr>';
              ELSE
                  l_html := l_html || '                           <tr><td>' || l_i || '</td><td>'||
                     l_sig.extra_info(l_i) || '</td></tr>';
              END IF;
          END IF;

          l_step := '60.'||l_i;
          l_i := l_sig.extra_info.next(l_i);
        END LOOP;
        print_buffer(p_sig_html, l_html);
        l_html := null;
        l_step := '65';
        -- print SQL only if SHOW_SQL != 'N' and the SQL string is not null
        IF ((l_sig.sig_sql is not null) AND ((NOT l_sig.extra_info.EXISTS('##SHOW_SQL##')) OR (l_sig.extra_info.EXISTS('##SHOW_SQL##')) AND (nvl(l_sig.extra_info('##SHOW_SQL##'), 'Y') != 'N'))) THEN
            l_step := '70';
            l_html := l_html || '
                              <tr><td>SQL</td><td id="sql_'||l_current_sig||'"><pre>'||prepare_SQL(l_sig.sig_sql)||'</pre></td></tr>';
        END IF;
        if (l_sig.version is not null) then
            l_html := l_html ||'
                              <tr><td>Version:</td><td>'||l_sig.version||'</td></tr>';
        end if;
        IF (l_result = 'P') THEN
            l_html := l_html || '
                              <tr><td>Elapsed time:</td><td>'||format_elapsed(g_query_elapsed)||'</td></tr>';
        END IF;
        l_html := l_html || '
                        </tbody>
                        </table>';
    END IF;
    print_buffer(p_sig_html, l_html);
    l_html := null;

    -- Show error message
    l_step := '80';
    if (l_result = 'X') then
        print_buffer(p_sig_html, replace(p_error_msg, chr(10), '<br>'));
    end if;

    -- Show success message
    l_step := '90';
    IF (l_result = 'P' and l_sig.success_msg is not null) THEN
        l_html := '
               <div class="divok data P"><div class="divok1"><span class="check_ico"></span> All checks passed.</div>' ||
            expand_html(l_sig.success_msg, p_sig_id) || '</div> <!-- end results div -->';
    END IF;

    -- Close signature container
    l_step := '100';
    l_html := l_html || '
               </div>  <!-- end of sig container -->
<!-- '||l_current_sig||'-->';
    print_buffer(p_sig_html, l_html);
EXCEPTION WHEN OTHERS THEN
    print_log('Error in get_sig_partial at step ' || l_step);
    print_log('Error: ' || sqlerrm);
    p_sig_html := null;
END get_sig_partial;


----------------------------------------------------------------
-- Once a signature has been run, evaluates and prints it     --
----------------------------------------------------------------
FUNCTION process_signature_results(
  p_sig_id          VARCHAR2,      -- signature id
  p_sig             SIGNATURE_REC, -- Name of signature item
  p_col_rows        COL_LIST_TBL,  -- signature SQL row values
  p_col_headings    VARCHAR_TBL,    -- signature SQL column names
  p_parent_id       VARCHAR2    DEFAULT NULL,
  p_sig_suffix      VARCHAR2    DEFAULT NULL,
  p_class_string    VARCHAR2    DEFAULT NULL,
  p_parent_sig_id   VARCHAR2    DEFAULT NULL -- Needed for performance tracking (EBSAF-177)
) RETURN VARCHAR2 IS             -- returns 'E','W','S','I'

  l_sig_fail      BOOLEAN := false;
  l_row_fail      BOOLEAN := false;
  l_fail_flag     BOOLEAN := false;
  l_html          VARCHAR2(32767) := null;
  l_cell_text     VARCHAR2(4200);
  l_column        VARCHAR2(255) := null;
  l_operand       VARCHAR2(255);
  l_value         VARCHAR2(4000);
  l_step          VARCHAR2(255);
  l_i             VARCHAR2(255);
  l_curr_col      VARCHAR2(255) := NULL;
  l_curr_val      VARCHAR2(4000) := NULL;
  l_value_set     varchar_tbl;
  l_fail_pattern  VARCHAR2(255);
  l_fail_text     VARCHAR2(4000);    -- EBSAF-259
  l_fail_col      number;
  l_fail_flags    varchar_tbl;
  l_print_sql_out BOOLEAN := true;
  l_inv_param     EXCEPTION;
  l_rows_fetched  NUMBER := p_col_rows(1).count;
  l_printing_cols NUMBER := 0;
  l_error_type    VARCHAR2(1);
  l_current_section  VARCHAR2(320);
  l_current_sig      VARCHAR2(320);
  l_sig_suffix       VARCHAR2(100);
  l_class_string     VARCHAR2(1024);
  l_style            VARCHAR2(250);
  l_mask_option     VARCHAR2(255);
  l_mask_opts     varchar_tbl;
  l_removed_cols     VARCHAR2(4000);
  l_masked_cols     VARCHAR2(4000);
  l_hashed_cols     VARCHAR2(4000);
  l_run_result      BOOLEAN;
  l_sig_result      VARCHAR2(1);
  l_tags            VARCHAR2(520) := '';
  l_hidden_data     BOOLEAN := false;
  l_sig_html      CLOB;
  l_process_start_time TIMESTAMP;
  l_process_elapsed INTERVAL DAY(2) TO SECOND(3);
BEGIN
    -- Complex signature may not have been registered (EBSAF-221)
    if not g_signatures.exists(p_sig_id) then
        g_signatures(p_sig_id) := p_sig;
    end if;
    sig_time_start(p_sig_id, p_parent_sig_id, 'P'); -- EBSAF-177
    g_sig_stats(p_sig_id||'|'||p_parent_sig_id).row_count := g_sig_stats(p_sig_id||'|'||p_parent_sig_id).row_count + l_rows_fetched;

    -- Validate parameters which have fixed values against errors when defining or loading signatures
    IF NOT (
        -- EBSAF-198 Changing fail condition validation to regex for control
        p_sig.fail_condition in ('NRS','RS','RSGT1') -- Standard
        or regexp_like(p_sig.fail_condition, '^\s*\[[^]]+\]\s*(<|<=|=|>|>=|<>|\!=)\s*\[[^]]+\]\s*$') -- Comparisons
        or regexp_like(p_sig.fail_condition, '^\s*\[[^]]+\]\s*(NOT\s+)?(LIKE|IN)\s*\[[^]]+\]\s*$', 'i') -- LIKE or IN
        or regexp_like(p_sig.fail_condition, '^\s*\[[^]]+\]\s*IS\s+(NOT\s+)?NULL\s*$', 'i') -- NULL
    ) THEN
        print_log('Invalid value or format for failure condition: '||p_sig.fail_condition);
        raise l_inv_param;
    ELSIF p_sig.print_condition NOT IN ('SUCCESS','FAILURE','ALWAYS','NEVER') THEN
        print_log('Invalid value for print_condition: '||p_sig.print_condition);
        raise l_inv_param;
    ELSIF p_sig.fail_type NOT IN ('E','W','I') THEN
        print_log('Invalid value for fail_type: '||p_sig.fail_type);
        raise l_inv_param;
    ELSIF p_sig.print_sql_output NOT IN ('Y','N','RS') THEN
        print_log('Invalid value for print_sql_output: '||p_sig.print_sql_output);
        raise l_inv_param;
    ELSIF p_sig.limit_rows NOT IN ('Y','N') THEN
        print_log('Invalid value for limit_rows: '||p_sig.limit_rows);
        raise l_inv_param;
    ELSIF p_sig.print_condition in ('ALWAYS','SUCCESS') AND
            p_sig.success_msg is null AND p_sig.print_sql_output = 'N' THEN
        print_log('Invalid parameter combination.');
        print_log('print_condition/success_msg/print_sql_output: '||
        p_sig.print_condition||'/'||nvl(p_sig.success_msg,'null')||'/'||p_sig.print_sql_output);
        print_log('When printing on success either success msg or SQL output printing should be enabled.');
        raise l_inv_param;
    END IF;

    -- Get signature class names
    g_sig_count := g_sig_count + 1;
    l_current_sig := 'S'||to_char(g_sig_count)||p_sig_suffix; --  Suffix is parent row ID
    l_current_section := replace_chars(g_sec_detail(g_sec_detail.COUNT).name);

    -- Log processing
    get_current_time(l_process_start_time);
    debug('Process start ['||l_current_sig||']');

    l_print_sql_out := (
        nvl(p_sig.print_sql_output,'Y') = 'Y' OR
        (p_sig.print_sql_output = 'RSGT1' AND l_rows_fetched > 1) OR
        (p_sig.print_sql_output = 'RS' AND l_rows_fetched > 0) OR
        (p_sig.child_sigs.count > 0 AND l_rows_fetched > 0)
    );

  -- Determine signature failure status
  l_fail_col := 0;
  l_fail_flags := varchar_tbl();
  IF p_sig.fail_condition NOT IN ('RSGT1','RS','NRS') THEN
    -- Get the column to evaluate, if any
    l_step := '20';

    -- EBSAF-198 Use regex for more control
    l_fail_pattern := '^\s*\[([^]]+)\]\s*([^[]+?)\s*(\[([^]]+)\])?\s*$';
    l_fail_text := expand_sql_tokens(p_sig.fail_condition);  -- EBSAF-259
    l_column := trim(upper(regexp_replace(l_fail_text, l_fail_pattern, '\1')));
    l_operand := trim(upper(regexp_replace(l_fail_text, l_fail_pattern, '\2')));
    l_value := trim(regexp_replace(l_fail_text, l_fail_pattern, '\4'));
    l_value_set := split_text(l_value);
    l_fail_flags.extend(l_rows_fetched);


    l_step := '30';
    -- Process to cache the fail status of each row
    FOR j in 1..p_col_headings.count LOOP
        l_step := '40 col ' || j || ' of ' || p_col_headings.count;
        IF l_column = upper(p_col_headings(j)) THEN
            l_fail_col := j;
            FOR i in 1..l_rows_fetched LOOP
                l_step := '40 col ' || j || ' row ' || i || ' of ' || l_rows_fetched;
                l_curr_val := p_col_rows(j)(i);
                l_row_fail := evaluate_rowcol(l_operand, l_value, l_curr_val, l_value_set);
                IF l_row_fail THEN
                    l_fail_flag := true;
                    l_fail_flags(i) := 'Y';
                ELSE
                    l_fail_flags(i) := 'N';
                END IF;
            END LOOP;
        END IF;
    END LOOP;
  END IF;

    -- Process to cache the mask option of each column (EBSAF-269)
    l_printing_cols := 0;
    l_mask_opts := varchar_tbl();
    l_mask_opts.extend(p_col_headings.count);
    FOR j in 1..p_col_headings.count LOOP
        l_step := '45 col ' || j || ' of ' || p_col_headings.count;
        l_curr_col := upper(p_col_headings(j));
        if l_curr_col not like '##$$FK_$$##' then
            l_mask_opts(j) := get_mask_option(j, l_curr_col, p_sig.extra_info);
            if l_mask_opts(j) = 'REMOVE_COLUMN' then
                l_removed_cols := l_removed_cols || ', ' || l_curr_col;
            elsif l_mask_opts(j) = 'HASH_VALUE' then
                l_hashed_cols := l_hashed_cols || ', ' || l_curr_col;
                l_printing_cols := l_printing_cols + 1;
            elsif l_mask_opts(j) <> 'NO_MASK' then
                l_masked_cols := l_masked_cols || ', ' || l_curr_col;
                l_printing_cols := l_printing_cols + 1;
            else
                l_printing_cols := l_printing_cols + 1;
            end if;
        end if;
    END LOOP;
    -- Don't print output if everything was removed
    if l_printing_cols = 0 then
        l_removed_cols := 'All columns';
        l_hashed_cols := null;
        l_masked_cols := null;
        l_print_sql_out := false;
    else
        l_removed_cols := substr(l_removed_cols, 3);
        l_hashed_cols := substr(l_hashed_cols, 3);
        l_masked_cols := substr(l_masked_cols, 3);
    end if;

    -- Process to mask foreign key tokens (EBSAF-275)
    if p_parent_id is not null or p_sig.child_sigs.count > 0 then
        l_curr_col := g_sql_tokens.first;
        while l_curr_col is not null loop
            if l_curr_col like '##$$FK_$$##' then
                l_curr_val := g_sql_tokens(l_curr_col);
                if (g_fk_mask_options.exists(l_curr_col) ) then
                    -- Analyzer defined setting
                    g_masked_tokens(l_curr_col) := mask_text(l_curr_val, g_fk_mask_options(l_curr_col) );
                else
                    -- Signature defined setting
                    g_masked_tokens(l_curr_col) := mask_text(l_curr_val, get_mask_option(0, l_curr_col, p_sig.extra_info) );
                end if;
            end if;
            l_curr_col := g_sql_tokens.next(l_curr_col);
        end loop;
    end if;

  -- Evaluate this signature
  l_step := '50';
  l_sig_fail := l_fail_flag OR
                (p_sig.fail_condition = 'RSGT1' AND l_rows_fetched > 1) OR
                (p_sig.fail_condition = 'RS' AND l_rows_fetched > 0) OR
                (p_sig.fail_condition = 'NRS' and l_rows_fetched = 0);

  l_step := '55';
  IF (l_sig_fail) THEN
    append_hits_xml(
        p_sig_id => p_sig_id,
        p_col_headings => p_col_headings,
        p_col_rows => p_col_rows,
        p_fail_col => l_fail_col,
        p_fail_flags => l_fail_flags,
        p_mask_opts => l_mask_opts,
        p_parent_sig_id => p_parent_id
    );
  END IF;

  -- If success and no print just return
  l_step := '60';
  IF ((NOT l_sig_fail) AND p_sig.print_condition IN ('FAILURE','NEVER')) THEN
    IF p_sig.fail_type = 'I' THEN
      sig_time_add(p_sig_id, p_parent_sig_id, 'P'); -- EBSAF-177
      l_process_elapsed := stop_timer(l_process_start_time);
      debug('Process finish ['||l_current_sig||'] ('||format_elapsed(l_process_elapsed)||')');
      return 'I';
    ELSE
    -- Before returning, populate the processed-successfully data
       IF (p_parent_id IS NULL) THEN
           g_results('P') := g_results('P') + 1;
           get_sig_partial(
              p_sig_html => l_sig_html,
              p_sig_id => p_sig_id
           );
           print_clob(l_sig_html);
       END IF;
       sig_time_add(p_sig_id, p_parent_sig_id, 'P'); -- EBSAF-177
       l_process_elapsed := stop_timer(l_process_start_time);
       debug('Process finish ['||l_current_sig||'] ('||format_elapsed(l_process_elapsed)||')');
       return 'S';
    END IF;
  ELSIF (l_sig_fail AND (p_sig.print_condition IN ('SUCCESS','NEVER'))) THEN
    sig_time_add(p_sig_id, p_parent_sig_id, 'P'); -- EBSAF-177
    l_process_elapsed := stop_timer(l_process_start_time);
    debug('Process finish ['||l_current_sig||'] ('||format_elapsed(l_process_elapsed)||')');
    return p_sig.fail_type;
-- if the sig is set as "Print in DX only" then return
  ELSIF (p_sig.include_in_xml = 'D') THEN
    sig_time_add(p_sig_id, p_parent_sig_id, 'P'); -- EBSAF-177
    l_process_elapsed := stop_timer(l_process_start_time);
    debug('Process finish ['||l_current_sig||'] ('||format_elapsed(l_process_elapsed)||')');
    return p_sig.fail_type;
  END IF;


  -- if p_parent_id is null, this is not a child sig (it's a first level signature)
  IF (p_parent_id IS NULL) THEN
     g_level := 1;
     g_family_result := '';
     -- populate the signature result to the global hash
     l_step := 'Populate result in the structure';
     g_sec_detail(g_sec_detail.LAST).sigs.extend();
     g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_id := l_current_sig;
     g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_name := p_sig_id;
     g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result := p_sig.fail_type;
     IF (NOT l_sig_fail AND (p_sig.fail_type != 'I')) THEN
           g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result := 'S';
     END IF;
   ELSE
     g_level := g_level + 1;
   END IF;

   l_tags := get_tags(p_sig_id);

   -- Print container and title
  l_html := '
<!-- '||l_current_sig||' -->

               <div class="data sigcontainer signature '||l_current_section||' '||l_current_sig||' '|| p_class_string || ' ' || g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result ||' section print analysis" sigid="'||p_sig_id||'" level="'||to_char(g_level)||'"  id="'||l_current_sig||'" style="display: none;">'
               || l_tags || '
                    <div class="divItemTitle">
                        <input type="checkbox" rowid="'||l_current_sig||'" class="exportcheck data print">';
    -- Add expand/collapse icons only if data
    IF (l_print_sql_out) THEN
        l_html := l_html || '
                        <a class="detail" toggle-data="restable_'||l_current_sig||'">
                           <div class="arrowright data section fullsection print analysis" title="Click to expand the result data">&#9654;</div><div class="arrowdown data" style="display: none" title="Click to collapse the result data">&#9660;</div>
                           <div class="sigdescription" style="display:inline;"><table style="display:inline;"><tr class="'||l_current_section||' '||l_current_sig||' '||g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result ||' sigtitle"><td class="divItemTitlet">'||expand_html(p_sig.title)||'</td></tr></table></div>
                        </a>';
    ELSE
        l_html := l_html || '
                        <div class="sigdescription" style="display:inline;"><table style="display:inline;"><tr class="'||l_current_section||' '||l_current_sig||' '||g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result ||' sigtitle"><td class="divItemTitlet">'||expand_html(p_sig.title)||'</td></tr></table></div>';
    END IF;
    -- CG Review this condition
    IF p_sig.extra_info.count > 0 OR p_sig.sig_sql is not null THEN
        l_html := l_html || '
                        <a class="detailsmall" toggle-info="tbitm_'||l_current_sig||'"><span class="siginfo_ico" title="Show signature information" alt="Show Info"></span></a>';
    END IF;
    -- Show copy SQL icon only if needed (SHOW_SQL != 'N' and the SQL string is not null)
    IF ((p_sig.sig_sql is not null) AND ((NOT p_sig.extra_info.EXISTS('##SHOW_SQL##')) OR (p_sig.extra_info.EXISTS('##SHOW_SQL##')) AND (nvl(p_sig.extra_info('##SHOW_SQL##'), 'Y') != 'N'))) THEN
        l_html := l_html || '
                        <a class="detailsmall" href="javascript:;" onclick=''copySql("sql_'||l_current_sig||'")''><span class="copysql_ico" title="Copy SQL query to clipboard" alt="Copy SQL"></span></a>';
    end if;
    -- Add export icons only if data
    IF (l_print_sql_out) THEN
        l_html := l_html || '
                        <a class="detailsmall" href="javascript:;" onclick=''export2PaddedText("'||l_current_sig||'", '||to_char(g_level)||');return false;''><span class="export_txt_ico" title="Export to .txt" alt="Export to .txt"></span></a>
                        <a class="detailsmall" href="javascript:;" onclick=''export2CSV("'||l_current_sig||'")''><span class="export_ico" title="Export to .csv" alt="Export to .csv"></span></a>';
    END IF;
    IF (l_print_sql_out AND (l_rows_fetched > 0)) THEN
       l_html := l_html || '
                       <a class="detailsmall" href="javascript:;" onclick=''switchMask("'||l_current_sig||'")''><span class="mask mask_disabled" title="Mask data" alt="Mask data"></span></a>';
       -- add sort icon for non-parents sigs and only when more than 1 record is retrieved (it doesn't make any sense to sort a single record)
       IF ((p_sig.child_sigs.count = 0) AND (l_rows_fetched > 1)) THEN
           l_html := l_html || '
                       <a class="detailsmall"><span class="sort_ico" table-name='||l_current_sig||' title="Sort table" alt="Sort table"></span></a>';
       END IF;
    END IF;
    -- Add feedback
	l_html := l_html || '
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,808,'||p_sig.sigrepo_id||',EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="thumb_up" title="Signature Feedback: Thumbs Up"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,808,'||p_sig.sigrepo_id||',EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="thumb_dn" title="Signature Feedback: Thumbs Down"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_SIGNATURE_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},808,'||p_sig.sigrepo_id||',EBS,EBS MFG,EBS - Value Chain Planning" target="_blank"><span class="af_idea" title="Signature Idea"></span></a>
	</div>';

  -- Print collapsable/expandable extra info table if there are contents
  l_step := '80';
  IF p_sig.extra_info.count > 0 OR p_sig.sig_sql is not null THEN
    g_item_id := g_item_id + 1;
    l_step := '90';

    l_html := l_html || '
                    <table class="table1 data" id="tbitm_' || l_current_sig || '" style="display:none">
                    <thead>
                       <tr><th bgcolor="#f2f4f7" class="sigdetails">Item Name</th><th bgcolor="#f2f4f7" class="sigdetails">Item Value</th></tr>
                    </thead>
                    <tbody>';
    -- Loop and print values
    l_step := '110';
    l_i := p_sig.extra_info.FIRST;
    WHILE (l_i IS NOT NULL) LOOP
      l_step := '110.1.'||l_i;
      -- don't print the extra info that starts wiht ## (these are hidden)
      IF (NOT regexp_like(l_i,'^##')) THEN
           -- if extra info includes keys like #IMPACT_AREAS#, change the display name to IMpact Areas (title case)
          IF (regexp_like(l_i,'^#[0-9a-zA-Z]')) THEN
              l_html := l_html || '                           <tr><td>' || word_to_titlecase(l_i) || '</td><td>'||
                  p_sig.extra_info(l_i) || '</td></tr>';
          ELSE
              l_html := l_html || '                           <tr><td>' || l_i || '</td><td>'||
                 p_sig.extra_info(l_i) || '</td></tr>';
          END IF;
      END IF;
      l_step := '110.2.'||l_i;
      l_i := p_sig.extra_info.next(l_i);
    END LOOP;
    -- print SQL only if SHOW_SQL != 'N' and the SQL string is not null
    IF ((p_sig.sig_sql is not null) AND ((NOT p_sig.extra_info.EXISTS('##SHOW_SQL##')) OR (p_sig.extra_info.EXISTS('##SHOW_SQL##')) AND (nvl(p_sig.extra_info('##SHOW_SQL##'), 'Y') != 'N'))) THEN
      l_step := '120';
      l_html := l_html || '
                        <tr><td>SQL</td><td id="sql_'||l_current_sig||'"><pre>'|| prepare_SQL(p_sig.sig_sql) ||
         '</pre></td></tr>';

        -- Explain if results for query may differ from recorded output (EBSAF-269)
        -- Print if selected columns were masked in output
        if l_masked_cols is not null then
            l_html := l_html || '
                        <tr><td>Columns masked in results:</td><td>' || l_masked_cols ||
                '</td></tr>';
        end if;
        -- Print if selected columns were hashed in output
        if l_hashed_cols is not null then
            l_html := l_html || '
                        <tr><td>Columns hashed in results:</td><td>' || l_hashed_cols ||
                '</td></tr>';
        end if;
        -- Print if selected columns were removed from output
        if l_removed_cols is not null then
            l_html := l_html || '
                        <tr><td>Columns removed from results:</td><td>'||l_removed_cols ||
                '</td></tr>';
        end if;
    END IF;

    -- failure condition (EBSAF-259)
    l_html := l_html ||'<tr><td>Failure condition:</td><td>';
    IF p_sig.fail_condition = 'RSGT1' THEN
        l_html := l_html || 'Multiple rows selected';
    ELSIF p_sig.fail_condition = 'RS' THEN
        l_html := l_html || 'Any rows selected';
    ELSIF p_sig.fail_condition = 'NRS' THEN
        l_html := l_html || 'No rows selected';
    ELSE
        l_fail_text := '"' || l_column || '" ' || l_operand;
        if l_operand like '%NULL' then
            null;
        elsif l_operand like '%IN' then
            l_fail_text := l_fail_text ||
                ' (' || join_text(l_value_set, ',') || ')';
        else
            l_fail_text := l_fail_text || ' ' || l_value;
        end if;
        l_html := l_html || escape_html(l_fail_text);
    END IF;
    l_html := l_html || '</td></tr>';

    -- number of records retrieved and elapsed time
    l_html := l_html ||'<tr><td>Number of rows:</td><td>';
      IF p_sig.limit_rows = 'N' OR l_rows_fetched < g_max_output_rows THEN
        l_html := l_html || l_rows_fetched || ' rows selected';
      ELSE
        l_html := l_html ||'The resultset is limited to '||to_char(g_max_output_rows)||' rows. For a complete list of records, please run the query directly in the database.';
      END IF;
      l_html := l_html ||'</td></tr>';
      if (p_sig.version is not null) then
        l_html := l_html ||'<tr><td>Version:</td><td>'||p_sig.version||'</td></tr>';
      end if;
      l_html := l_html ||'<tr><td>Elapsed time:</td><td>'||format_elapsed(g_query_elapsed)||'</td></tr>';
      l_html := l_html || '
                    </tbody>
                    </table>';
  END IF;

  l_step := '140';

  -- Print the header SQL info table
  --print_out(expand_links(l_html, p_sig.sigrepo_id));
  print_buffer(l_sig_html, expand_html(l_html, p_sig_id));
  l_html := null;

    -- Add chart definition if needed
    l_step := '145';
    l_html := get_chartdef(l_current_sig, p_sig.extra_info);
    if (l_html is not null) then
        print_buffer(l_sig_html, l_html);
        l_html := null;
    end if;

  IF l_print_sql_out THEN
    IF p_sig.child_sigs.count = 0 or l_rows_fetched = 0 THEN        -- Signature has no children or no rows
      -- Print the actual results table
      -- Table header
      l_step := '150';

      l_html := '
                    <!-- table that includes the SQL results (data) -->
                    <div class="divtable">';
      IF (p_parent_id IS NULL) THEN
           l_html := l_html || '
                    <table class="table1 data tabledata parea" id="restable_'||l_current_sig||'" style="display:none">
                    <thead class="pheader">';
      ELSE
           l_html := l_html || '
                    <table class="table1 data tabledata" id="restable_'||l_current_sig||'" style="display:none">
                    <thead>';
      END IF;

      -- Column headings
      l_html := l_html || '
                        <tr class="'||l_current_section||' '||l_current_sig||' '||g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result ||'">';
      print_buffer(l_sig_html, l_html);
      l_html := '';
      l_step := '160';
      FOR i IN 1..p_col_headings.count LOOP
        l_curr_col := filter_html(p_col_headings(i),'I','D'); -- Delete invalid characters from header (EBSAF-263)
        IF upper(nvl(l_curr_col,'XXX')) not like '##$$FK_$$##' THEN
            l_mask_option := l_mask_opts(i);
            if (l_mask_option <> 'REMOVE_COLUMN') then  -- EBSAF-269

                if (l_mask_option = 'HASH_VALUE') then
                    l_tags := ' masked" title="Data in this column has been hashed and does not show the actual value';
                elsif (l_mask_option <> 'NO_MASK') then
                    l_tags := ' masked" title="Data in this column has been masked and does not show the full value';
                else
                    l_tags := null;
                end if;

                  l_html := l_html || '
                                    <th bgcolor="#f2f4f7" class="sigdetails' || l_tags || '">'||nvl(l_curr_col,'&nbsp;')||'</th>';
                 -- if the html buffer is already larger than the limit, spool the content and reset
                 IF (LENGTH(l_html) > 32000) THEN
                 print_buffer(l_sig_html, expand_html(l_html, p_sig_id));
                     l_html := '';
                 END IF;

            end if;
        END IF;
      END LOOP;
      l_html := l_html || '
                        </tr>
                    </thead>
                    <tbody>';
      -- Print headers
      print_buffer(l_sig_html, expand_html(l_html, p_sig_id));
      -- Row values
      l_step := '170';
      FOR i IN 1..l_rows_fetched LOOP
        l_html := '                        <tr class="tdata '||l_current_section||' '||l_current_sig||' '||g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result ||'">';
        l_step := '170.1.'||to_char(i);
        FOR j IN 1..p_col_headings.count LOOP
          -- Evaluate if necessary
          l_step := '170.2.'||to_char(j);
          -- Use cached fail flags
          l_row_fail := (j = l_fail_col AND l_fail_flags(i) = 'Y');
          l_step := '170.3.'||to_char(j);
          l_curr_col := upper(filter_html(p_col_headings(j),'I','D')); -- Delete invalid characters from header (EBSAF-263)
          l_step := '170.4.'||to_char(j);
          l_curr_val := p_col_rows(j)(i);
          l_step := '170.5.'||to_char(j);

          IF (p_sig.extra_info.EXISTS('##STYLE##'||l_curr_col)) AND (p_sig.extra_info.EXISTS('##STYLE##'||l_curr_col) IS NOT NULL) THEN
              l_style := get_style(p_sig.extra_info('##STYLE##'||l_curr_col));
          ELSE
              l_style := '';
          END IF;

            -- EBSAF-269
            l_mask_option := l_mask_opts(j);
            if (l_mask_option <> 'REMOVE_COLUMN') then

              -- Print
              l_step := '170.7.'||to_char(j);
              IF upper(nvl(p_col_headings(j),'XXX')) not like '##$$FK_$$##' THEN
                 BEGIN
                    l_tags := 'sigdetails';
                    if (l_mask_option = 'NO_MASK') then -- EBSAF-269
                      IF (g_dest_to_source.EXISTS(p_sig_id)) AND (g_dest_to_source(p_sig_id).cols.EXISTS(l_curr_col)) AND (g_dest_to_source(p_sig_id).cols(l_curr_col) IS NOT NULL) THEN
                            l_cell_text := '<a class="anchor" id="'|| g_dest_to_source(p_sig_id).cols(l_curr_col)||'_'||filter_html(l_curr_val,'D','D')|| '"></a>' || filter_html(l_curr_val,'H','H');
                      ELSIF (g_source_to_dest.EXISTS(p_sig_id)) AND (g_source_to_dest(p_sig_id).cols.EXISTS(l_curr_col)) AND (g_source_to_dest(p_sig_id).cols(l_curr_col) IS NOT NULL) THEN
                            l_cell_text := '<a href="" siglink="'|| g_source_to_dest(p_sig_id).cols(l_curr_col)||'_'||filter_html(l_curr_val,'D','D')|| '">' || filter_html(l_curr_val,'H','H') || '</a>';
                            l_cell_text := l_cell_text || '<span class="brokenlink" style="display:none;" title="This record does not have a parent"></span>';
                      ELSE
                            l_cell_text := filter_html(l_curr_val,'H','H');
                      END IF;
                    else
                        -- Masking prevents linking (EBSAF-269)
                        l_cell_text := mask_text(l_curr_val, l_mask_option);
                        l_tags := l_tags || ' masked';
                    end if;

                    if l_row_fail then
                        l_tags := l_tags || ' hlt';
                    end if;

                    -- Mark cell as containing hidden data
                    IF instr(lower(l_cell_text),'"hidden_data"') > 0 THEN
                        l_tags := l_tags || ' hidden_data_parent';
                        l_hidden_data := true;
                    END IF;

                    l_html := l_html || '
                                   <td class="' || l_tags || '" ' || l_style || '>'|| l_cell_text || '</td>';
                 EXCEPTION WHEN OTHERS THEN
                      print_log('Error in process_signature_results populating table data for signature: ' || p_sig_id);
                      print_log('Error:' || sqlerrm);
                 END;
              END IF;

            end if;

            -- if the html buffer is already larger than the limit, spool the content and reset
            IF (LENGTH(l_html) > 32000) THEN
                print_buffer(l_sig_html, expand_html(l_html, p_sig_id) );
                l_html := '';
            END IF;
        END LOOP;
        l_html := l_html || '
                        </tr>';
        print_buffer(l_sig_html, expand_html(l_html, p_sig_id) );
      END LOOP;

      -- End of results and footer
      l_step := '180';
      l_html :=  '
                    </tbody>
                    </table>
                    </div>  <!-- end table data -->';

      -- Add block for row limit warning
      if not (p_sig.limit_rows = 'N' or l_rows_fetched < g_max_output_rows) then
        l_html := l_html || '
                    <div>
                        <b>Attention:</b>
                        This data is limited to maximum '||g_max_output_rows || ' rows.
                        Click the <span class="siginfo_ico" alt="Show Info"></span> icon for additional information.
                    </div>';
      end if;

      -- Add block for hidden data (EBSAF-255)
      if l_hidden_data then
        l_html := l_html || '
                    <div>
                        <b>Attention:</b>
                        This data contains leading/trailing whitespace or invalid characters that are hidden by default.
                        Click the <span class="hidden_ico" alt="Hidden Data"></span> icon to toggle hidden data visibility.
                     </div>';
      end if;

      l_step := '190';
      print_buffer(l_sig_html, l_html);
--
    ELSE -- there are children signatures
      -- Print master rows and call appropriate processes for the children
      -- Table header
      l_html := '
                    <!-- table that includes the SQL results (data) -->
                    <div class="divtable">';
      l_html := l_html || '
                    <table class="table1 data tabledata" id="restable_'||l_current_sig||'" style="display:none">';

      -- Row values
      l_step := '200';
      FOR i IN 1..l_rows_fetched LOOP
        l_step := '200.1'||to_char(i);
        -- Column headings printed for each row
        l_html := l_html || '
                        <tr class="'||l_current_section||' '||l_current_sig||' '||g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result ||'">';
        FOR j IN 1..p_col_headings.count LOOP
          l_step := '200.2'||to_char(j);
            l_mask_option := l_mask_opts(j);
            if (l_mask_option <> 'REMOVE_COLUMN') then  -- EBSAF-269
              IF upper(nvl(p_col_headings(j),'XXX')) not like '##$$FK_$$##' THEN
                if (l_mask_option = 'HASH_VALUE') then
                    l_tags := ' masked" title="Data in this column has been hashed and does not show the actual value';
                elsif (l_mask_option <> 'NO_MASK') then
                    l_tags := ' masked" title="Data in this column has been masked and does not show the full value';
                else
                    l_tags := null;
                end if;
                l_html := l_html || '
                                <th bgcolor="#f2f4f7" class="sigdetails '||l_current_sig||l_tags||'">'||nvl(p_col_headings(j),'&nbsp;')||'</th>';
              END IF;
            end if;
          -- if the html buffer is already larger than the limit, spool the content and reset
          IF (LENGTH(l_html) > 32000) THEN
            print_buffer(l_sig_html, expand_html(l_html, p_sig_id) );
            l_html := '';
          END IF;
        END LOOP;
        l_step := '200.3';
        l_html := l_html || '
                        </tr>';
        -- Print headers
        print_buffer(l_sig_html, expand_html(l_html, p_sig_id) );
        -- Print a row
        l_html := '
                        <tr class="tdata '||l_current_section||' '||l_current_sig||' '||g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result||'">';

        l_printing_cols := 0;
        FOR j IN 1..p_col_headings.count LOOP
          l_step := '200.4'||to_char(j);
          l_curr_col := upper(p_col_headings(j));
          l_curr_val := p_col_rows(j)(i);

          -- If the col is a FK set the global replacement vals
          IF l_curr_col like '##$$FK_$$##' THEN
            l_step := '200.5';
            g_sql_tokens(l_curr_col) := l_curr_val;
            -- Allow tokens to be masked (EBSAF-275)
            if (g_fk_mask_options.exists(l_curr_col) ) then
                -- Analyzer defined setting
                g_masked_tokens(l_curr_col) := mask_text(l_curr_val, g_fk_mask_options(l_curr_col) );
            else
                -- Signature defined setting
                g_masked_tokens(l_curr_col) := mask_text(l_curr_val, get_mask_option(0, l_curr_col, p_sig.extra_info) );
            end if;
          ELSE -- printable column
            l_printing_cols := l_printing_cols + 1;

            -- Use cached fail flags
            l_row_fail := (j = l_fail_col AND l_fail_flags(i) = 'Y');

            IF (p_sig.extra_info.EXISTS('##STYLE##'||l_curr_col)) AND (p_sig.extra_info('##STYLE##'||l_curr_col) IS NOT NULL) THEN
                l_style := get_style(p_sig.extra_info('##STYLE##'||l_curr_col));
            ELSE
                l_style := '';
            END IF;

            -- EBSAF-269
            l_mask_option := l_mask_opts(j);
            if (l_mask_option <> 'REMOVE_COLUMN') then
                -- Print
              BEGIN
                    l_tags := 'sigdetails';
                    if (l_mask_option = 'NO_MASK') then -- EBSAF-269
                       IF (g_dest_to_source.EXISTS(p_sig_id)) AND (g_dest_to_source(p_sig_id).cols.EXISTS(l_curr_col)) AND (g_dest_to_source(p_sig_id).cols(l_curr_col) IS NOT NULL) THEN
                             l_cell_text := '<a class="anchor" id="'|| g_dest_to_source(p_sig_id).cols(l_curr_col)||'_'||to_char(l_curr_val)|| '"></a>' || l_curr_val;
                       ELSIF (g_source_to_dest.EXISTS(p_sig_id)) AND (g_source_to_dest(p_sig_id).cols.EXISTS(l_curr_col)) AND (g_source_to_dest(p_sig_id).cols(l_curr_col) IS NOT NULL) THEN
                             l_cell_text := '<a href="" siglink="'|| g_source_to_dest(p_sig_id).cols(l_curr_col)||'_'||to_char(l_curr_val)|| '">' || l_curr_val || '</a>';
                             l_cell_text := l_cell_text || '<span class="brokenlink" style="display:none;" title="This record does no have a parent"></span>';
                       ELSE
                             l_cell_text := l_curr_val;
                       END IF;
                    else
                        -- Masking prevents linking (EBSAF-269)
                        l_cell_text := mask_text(l_curr_val, l_mask_option);
                        l_tags := l_tags || ' masked';
                    end if;

                    if l_row_fail then
                        l_tags := l_tags || ' hlt';
                    end if;
                    l_html := l_html || '
                                   <td class="' || l_tags || '" ' || l_style || '>'|| l_cell_text || '</td>';
              EXCEPTION WHEN OTHERS THEN
                   print_log('Error in process_signature_results populating table data for signature: ' || p_sig_id);
              END;

            end if;

          END IF;
          -- if the html buffer is already larger than the limit, spool the content and reset
          IF (LENGTH(l_html) > 32000) THEN
            print_buffer(l_sig_html, expand_html(l_html, p_sig_id) );
            l_html := '';
          END IF;
        END LOOP;
        l_html := l_html || '
                        </tr>';
        print_buffer(l_sig_html, expand_html(l_html, p_sig_id) );
        l_html := null;
        FOR k IN p_sig.child_sigs.first..p_sig.child_sigs.last LOOP
          print_buffer(l_sig_html, '
                        <tr><td colspan="'||to_char(l_printing_cols)||'"><blockquote>');
          DECLARE
            l_col_rows  COL_LIST_TBL := col_list_tbl();
            l_col_hea   VARCHAR_TBL := varchar_tbl();
            l_child_sig SIGNATURE_REC;
            l_result    VARCHAR2(1);
          BEGIN
           l_child_sig := g_signatures(p_sig.child_sigs(k));
           print_log('Processing child signature: '||p_sig.child_sigs(k));
           l_run_result := run_sig_sql(p_sig.child_sigs(k), l_child_sig.sig_sql, l_col_rows, l_col_hea, l_child_sig.limit_rows, p_sig_id);
           l_class_string := p_class_string || ' ' || l_current_sig;
           g_child_sig_html := null;
           IF (l_run_result) THEN
               l_result := process_signature_results(p_sig.child_sigs(k), l_child_sig, l_col_rows, l_col_hea, l_current_sig, p_sig_suffix || '_' || to_char(i), l_class_string, p_sig_id);
               set_item_result(l_result);
           ELSE
               -- Child signature query failed
               get_sig_partial(
                    p_sig_html => g_child_sig_html,
                    p_sig_id => p_sig.child_sigs(k),
                    p_level => g_level + 1,
                    p_class_string => l_current_section||' '||l_class_string,
                    p_error_msg => g_errbuf
               );
           END IF;
           IF (g_child_sig_html is not null) THEN
               dbms_lob.append(l_sig_html, g_child_sig_html);
               dbms_lob.freetemporary(g_child_sig_html);
           END IF;

           -- show parent signature failure based on result from child signature(s)
         IF l_result in ('W','E') THEN
             l_fail_flag := true;
           IF l_result = 'E' THEN
             l_error_type := 'E';
           ELSIF (l_result = 'W') AND ((l_error_type is NULL) OR (l_error_type != 'E')) THEN
             l_error_type := 'W';
           END IF;
           -- if g_family_result already has a value of 'E', no need to set it again
           IF (g_family_result = 'E') THEN
              NULL;
           ELSIF (g_family_result = 'W' AND l_result = 'E') THEN
              g_family_result := 'E';
           ELSE
              g_family_result := l_result;
           END IF;
         END IF;

          EXCEPTION WHEN OTHERS THEN
            print_log('Error in process_signature_results processing child signature: '||p_sig.child_sigs(k));
            print_log('Error: '||sqlerrm);
          END;
          print_buffer(l_sig_html, '
                        </blockquote></td></tr>');
        END LOOP;
      END LOOP;

      -- End of results and footer
      l_step := '210';
      l_html := l_html || '
                     <div style="display:none" class="sigrescode '||l_current_section||' '||l_current_sig||' '|| p_class_string || ' ' || l_sig_result||'" level="'||to_char(g_level)||'"></div>
      ';
      l_html := l_html ||  '
                    </tbody>
                    </table>
                    </div>  <!-- end table data -->';

      print_buffer(l_sig_html, l_html);
    END IF; -- master or child

  END IF; -- print output is true

  -------------------------------------
  -- Print actions for each signature
  -------------------------------------
  l_sig_result := 'S';
  IF l_sig_fail THEN
    l_step := '230';
    IF p_sig.fail_type = 'E' THEN
      l_html := '
                    <div class="divuar results data print section fullsection">
                        <span class="divuar1">Error: </span>' || p_sig.problem_descr; --||prepare_text(expand_tokens(p_sig.problem_descr, p_sig.extra_info));
      l_sig_result := 'E';
    ELSIF p_sig.fail_type = 'W' THEN
      l_html := '
                    <div class="divwarn results data print section fullsection">
                        <span class="divwarn1">Warning: </span>' || p_sig.problem_descr; --||prepare_text(expand_tokens(p_sig.problem_descr, p_sig.extra_info));
      l_sig_result := 'W';
    ELSE
      l_html := '
                    <div class="divinfo results data print section fullsection">
                        <span class="divinfo1">Information: </span>' || p_sig.problem_descr; --||prepare_text(expand_tokens(p_sig.problem_descr, p_sig.extra_info));
      l_sig_result := 'I';
    END IF;

    -----------------------------------------------------
    -- Print solution part of the action - only if passed
    -----------------------------------------------------
    l_step := '240';
    IF p_sig.solution is not null THEN
      l_html := l_html || '
                     <br><br><span class="solution">Findings and Recommendations:</span><br>
        ' || p_sig.solution;
    END IF;

    -- Close div here cause success div is conditional
    l_html := l_html || '
                    </div> <!-- end results div -->';
  ELSE
    IF p_sig.fail_type = 'I' THEN
         l_sig_result := 'I';
    END IF;
    l_step := '250';
    IF p_sig.success_msg is not null THEN
      IF p_sig.fail_type = 'I' THEN
        l_html := '
          <div class="divinfo results data print section fullsection"><div class="divinfo1">Information:</div>'||
          nvl(p_sig.success_msg, 'No instances of this problem found') ||
          '</div> <!-- end results div -->';
      ELSE
        l_html := '
          <div class="divok results data print section fullsection"><div class="divok1"><span class="check_ico"></span> All checks passed.</div>'||
          nvl(p_sig.success_msg, 'No instances of this problem found') ||
          '</div> <!-- end results div -->';
      END IF;
    ELSE
      l_html := null;
    END IF;
  END IF;
  l_html := expand_html(l_html, p_sig_id); -- EBSAF-180


  -- DIV for parent

     IF p_sig.child_sigs.count > 0 and (p_parent_id IS NULL) THEN
        IF g_family_result = 'E' THEN
           l_html := l_html || '
             <div class="divuar results data print section fullsection"><span class="divuar1">Error:</span> Error(s) and/or warning(s) are reported in this section. Please expand section for more information.</div>';
        ELSIF g_family_result = 'W' THEN
           l_html := l_html || '
             <div class="divwarn results data print section fullsection"><span class="divwarn1">Warning:</span> Warning(s) are reported in this section. Please expand section for more information. </div>';
        END IF;
      END IF;

    -- if p_parent_id is null, this is not a child sig (it's a first level signature)
    IF (p_parent_id IS NULL)  THEN
        IF (g_family_result = 'E' or g_family_result = 'W') THEN
            g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result := g_family_result;
            l_sig_result := g_family_result;
        END IF;
        -- increment the global counter and the section counter for the fail_type
        DECLARE
           l_result VARCHAR2(1);
        BEGIN
           l_result := g_sec_detail(g_sec_detail.LAST).sigs(g_sec_detail(g_sec_detail.LAST).sigs.LAST).sig_result;
           g_results(l_result) := g_results(l_result) + 1;
           g_sec_detail(g_sec_detail.LAST).results(l_result) := g_sec_detail(g_sec_detail.LAST).results(l_result) + 1;
        END;
    END IF;


   -- print the result div of the sig container

    l_html := l_html || '
                     <div style="display:none" class="sigrescode '||l_current_section||' '||l_current_sig||' '|| p_class_string || ' ' || l_sig_result||'" level="'||to_char(g_level)||'"></div>
    ';


    l_html := l_html || '
                </div> <!-- end of sig container -->
<!-- '||l_current_sig||'-->';

  l_step := '260';
  g_sections(g_sections.last).print_count := g_sections(g_sections.last).print_count + 1;

  -- Print or return HTML
  l_step := '270';
  print_buffer(l_sig_html, expand_html(l_html, p_sig_id) );
  if (p_parent_id is null) then
    print_clob(l_sig_html, 'N');
  else
    g_child_sig_html := l_sig_html;
  end if;

  g_level := g_level - 1;

  sig_time_add(p_sig_id, p_parent_sig_id, 'P'); -- EBSAF-177 Time only needed for successful process
  l_process_elapsed := stop_timer(l_process_start_time);
  debug('Process finish ['||l_current_sig||'] ('||format_elapsed(l_process_elapsed)||')');

  IF l_sig_fail THEN
    l_step := '280';
    return p_sig.fail_type;
  ELSE
    l_step := '290';
    IF p_sig.fail_type = 'I' THEN
      return 'I';
    ELSE
      return 'S';
    END IF;
  END IF;

EXCEPTION
  WHEN L_INV_PARAM THEN
    print_log('Invalid parameter error in process_signature_results at step '||l_step);
    return 'X';
  WHEN OTHERS THEN
    l_process_elapsed := stop_timer(l_process_start_time);
    debug('Process failed ['||l_current_sig||'] ('||format_elapsed(l_process_elapsed)||')');
    print_log('Error in process_signature_results at step '||l_step);
    print_log(SQLERRM);

    -- Print or return HTML
    g_errbuf := 'PROGRAM ERROR'||chr(10)||
      'Error in process_signature_results at step '|| l_step||': '||sqlerrm||chr(10)||
      'See the log file for additional details';
    get_sig_partial(
        p_sig_html => l_sig_html,
        p_sig_id => p_sig_id,
        p_level => g_level,
        p_class_string => l_current_section||' '||p_class_string,
        p_error_msg => g_errbuf
    );
    if (p_parent_id is null) then
        print_clob(l_sig_html, 'N');
    else
        g_child_sig_html := l_sig_html;
    end if;
    return 'X';
END process_signature_results;


----------------------------------------------------------------
-- Start the main section                                     --
-- (where the sections and signatures reside)                 --
----------------------------------------------------------------
PROCEDURE start_main_section is
    l_banner_code varchar2(3000);
    l_banner_bg varchar2(20);
    l_banner_fg varchar2(20);
    l_banner_lbl varchar2(20);
BEGIN
  -- Start main body and spacer under header
  print_out('
<!-- start body -->
    <div class="body background">
    <div style="min-height:75px;"></div>');

    -- Build custom banner message if needed
    if (g_banner_message is not null) then
        l_banner_code := '    <div id="banner" class="#99#BANNER_BG#99#" style="text-align:center; overflow:hidden; min-width:initial;" data-popup="banner">
        <span class="#99#BANNER_FG#99#">#99#BANNER_LBL#99#:</span> #99#BANNER_MSG#99#
        <div class="close-button" style="margin:0px;" data-popup-close="banner"><a class="black-link">OK</a></div>
    </div>';
        case g_banner_severity
            when 'S' then
                l_banner_bg := 'divok';
                l_banner_fg := 'divok1';
                l_banner_lbl := 'Success';
            when 'I' then
                l_banner_bg := 'divinfo';
                l_banner_fg := 'divinfo1';
                l_banner_lbl := 'Information';
            when 'W' then
                l_banner_bg := 'divwarn';
                l_banner_fg := 'divwarn1';
                l_banner_lbl := 'Warning';
            else -- assume 'E'
                l_banner_bg := 'divuar';
                l_banner_fg := 'divuar1';
                l_banner_lbl := 'Error';
        end case;
        l_banner_code := replace(l_banner_code, '#99#BANNER_BG#99#', l_banner_bg);
        l_banner_code := replace(l_banner_code, '#99#BANNER_FG#99#', l_banner_fg);
        l_banner_code := replace(l_banner_code, '#99#BANNER_LBL#99#', l_banner_lbl);
        l_banner_code := replace(l_banner_code, '#99#BANNER_MSG#99#', g_banner_message);
        print_out(expand_html(filter_html(l_banner_code, 'I', 'D')));
    end if;

  -- Main page
  print_out('<!-- main data screen (showing section and signatures) -->
    <div class="maindata print analysis section fullsection P">
    <div style="min-height:10px;"></div>
    <div class="sigcontainer background">
       <div style="width:100%;">
           <div style="float:left;padding-left:10px;padding-top:15px;display:inline-block" id ="showhidesection" mode="show">
               <a href="javascript:void(0)" class="detailsmall data section sectionview" mode="show" id="showAll" open-sig-class=""><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAARCAYAAAA/mJfHAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAAB3RJTUUH4gMcDiQnlEv7GQAAACtJREFUOMtj/P//PwO1AGNAQADVTGNioCKgqmGM1AyzQezN0dgcjc0RHZsAwIQR3X8SrOYAAAAASUVORK5CYII=" alt="show_all" title="Show entire section"></a>
               <a href="javascript:void(0)" class= "detailsmall data fullsection sectionview" mode="hide" id="hideAll" open-sig-class=""><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAARCAYAAAA/mJfHAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAAB3RJTUUH4gMcDiQnlEv7GQAAACtJREFUOMtj/P//PwO1AGNAQADVTGNioCKgqmGM1AyzQezN0dgcjc0RHZsAwIQR3X8SrOYAAAAASUVORK5CYII=" alt="hide_all" title="Show Single Signature"></a>
          </div>
          <div class="containertitle" style="display:inline-block;vertical-align:middle;float:right;width:95%;"></div>
       </div>
       <table class="background" style="width:100%;border-spacing:0;border-collapse:collapse;">
        <tr>
            <td class="leftcell data section background">   <!-- Start menu on the left hand side -->
            <div class="sectionmenu background" id="sectionmenu">
            </div>
            </td>
            <!-- Cell that includes the signature details -->
            <td class="rightcell analysis print section fullsection P">
                 <div class="sigcontainer" style="padding:20px;margin:0;">
                   <div class="searchbox data analysis print section fullsection">
                       <div style="float:left"><b>Search within tables:</b></div><br>
                       <div style="float:left"><input type="text" class="search" placeholder="Enter search string and press <enter>" id="search" size="96" maxlength="96"></div><br>
                   </div><br><br>
                   <div class="expcoll data analysis print section fullsection">
                       <a class="detailsmall export2Txt data fullsection" id="export2TextLink" href="javascript:;" onclick=''export2PaddedText("")''><span class="export_txt_ico" title="Export to .txt" alt="Export to .txt"></span></a>
                       &nbsp;&nbsp;
                       <input type="checkbox" class="data print" id="exportAll">
                       <a class="detailsmall print data exportAllImg fullsection" href="javascript:;" onclick=''export2CSV("ALL")''><span class="export_ico" title="Export to Excel (.csv)" alt="Export to .csv"></span></a>
                       &nbsp;&nbsp;
                       <a class="detailsmall export2HTML data analysis" id="export2HTMLLink" href="javascript:;" onclick=''export2HTML()''><span class="export_html_ico" title="Development view (Export to .html)" alt="Export to .htm"></span></a>
                       &nbsp;&nbsp;
                       <a href="javascript:void(0)" class="detailsmall fullsection data print analysis" id="expandall" mode="analysis"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABcAAAASCAYAAACw50UTAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAB3RJTUUH4QcDCAcI/tBeNAAAAHxJREFUOMtj/P//PwMMMC4zvMvAwMDwP+q8MgMVABMDDQFNDWdkWGpwF58CSoKIhaDtReeqyHY5vgilxGCIt///h2OGpQZ3GZYa3IXzC89WIcuTKkbTCGWhVuQRDHNqRiZGmFMSvnQPc9rm0NEwH2xhfraYgYGRncwA/wkAE9bkVHL11nAAAAAASUVORK5CYII=" alt="expand_all" title="Expand All Tables"></a>&nbsp;
                       <a href="javascript:void(0)" class="detailsmall fullsection data print analysis" id="collapseall"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAARCAYAAAAyhueAAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAB3RJTUUH4QcDCA4nhMPYJAAAAFRJREFUOMtjfM3A+ZgBBxD5/02WgQzAxEADwPj//3+qG8qC1aaic1WUGEoT7zP8//8fAzMUnq2iRIwmLqVf7FMaUaNhOhqm9AnTs8UMDIzsZAboTwAjVcX2TISAoAAAAABJRU5ErkJggg==" alt="collapse_all" title="Collapse All Tables"></a>
                       &nbsp;&nbsp;
                       <a href="javascript:void(0)" class="detailsmall fullsection data print analysis" id="expandallinfo" mode="analysis"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABcAAAASCAYAAACw50UTAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAB3RJTUUH5wcVERQZRVNM9QAAAYpJREFUOMu11D1uE1EUBeDPxhAEhYtYSoORcBrAKMoaEAVZQ0ob85vCTRZBkS4UJi6zBKQUViR2EKEIaBIBU1myJSZFTBxgUowxDjbMDIJbzjv3vDvnnneYrO3lA9vLB/5R5f3HKmRCN9q3UccKboy+HmIHW1q1t5PwXKIMq3uLGu1L2MBj8+W8q0UKc/H56QnHIf3gO16iqVUbpCN/vXYLrxQX7imV//xn/YDP3V2saNWGBat7i+cW+mPasRQ2UxHDfJnIXWF3A8/yCRpX8VDp2tRRtL4kWl+a7omxjzTa1SS31JXKF8hl2HpO3KOeS5j8net3brp4OZsHT7/waf99khUrY1f8Isl4zudvZhh8Dip/9YhmEp67PYJhEvmhryfZb497PiaR7zgOs5MPjqCTRN7WC74R/VbzaTtG4h5buRR5sqm48CTVI4JeQNh9oVV7mmahTWG3oxckI/sBYXcXzZHjU6Xhz+AqlfOujIIriuLlDY7ozQqubJFbxQPcRwVDfEBnFLn7k/Azx1uB7VIBA+8AAAAASUVORK5CYII=" alt="expand_all_info" title="Expand All Information"></a>&nbsp;
                       <a href="javascript:void(0)" class="detailsmall fullsection data print analysis" id="collapseallinfo"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAARCAYAAAAyhueAAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAB3RJTUUH5wcVERUPqJzI5QAAAWJJREFUOMudlLFOwlAUhj8K0YhDBzBMHcRNEx18A+MAz1EkUScWH8JBJx0qPIYJA+ENHDTGTaK5U2ObWAYaULwOtyEVuC31TDf3/v+fc89/zsl9sCHQxBahxT+isBKq2dkFGkAd2I5uB0AXaOPYL3F4LkVsDbgCTilZBpsmFNbV29cYRgH44ge4A1o4dpgsqgTvMSvHlFOq4Av4dPtAHceeGAnQ65UEAUoWmJWj6FeaTJudPeCRncP8PERe7Ku6XT7NkSS8PkyBA12mDcpWPq3kfyOH4tDQuV+jaC6nLmQYi6IJiJpOtDpzecnXteKKUzWyNHVilgBSAmjdH/A9zj5KivOuE+0yCrKLhkOAnk60gyemILU1jZ9nLeWJKdBOmqgbzMrZSs0P4AkI3Fsc+zzJqBaB28MT6YK+gMDtA61sC6VsGRSjhSKlMiUcgpdloSyO7QlQA6rABHgDetHqe47DfwFD3nM0Cq93PgAAAABJRU5ErkJggg==" alt="collapse_all_info" title="Collapse All Information"></a>
                   </div>
            <br><br>
                   <div class="data tags tagarea" id="tags_area"></div>
            ');

EXCEPTION WHEN OTHERS THEN
  print_log('Error in start_main_section: '||sqlerrm);
  raise;
END start_main_section;


PROCEDURE end_main_section IS
   l_html           VARCHAR2(32767) := '';
BEGIN

print_out('
      </div> <!-- end of inner container -->
            </td>
        </tr>
      </table>
    </div>  <!-- end of outer container -->
    <div style="min-height: 35;"></div>
  </div> <!-- end of main data -->
 </div> <!-- end of body -->');

/* REMOVED TO ELIMINATE INLINE JAVASCRIPT (EBSAF-262)
-- Populate the sectionmenu details here, because we need the signature results
    print_out('<script>');
    print_out('if ($("#sectionmenu").children().length == 0) {');  -- EBSAF-211
    FOR i IN 1 .. g_sec_detail.COUNT LOOP
        FOR j IN 1 .. g_sec_detail(i).sigs.COUNT LOOP
            -- in case of customizations, the global signatures table might not be populated correctly, so we might encounter a "no data found" exception.
            BEGIN
                l_html := ' <div class="sectionbutton data '||g_sec_detail(i).name||' '||nvl(g_sec_detail(i).sigs(j).sig_id, 'null')||' '||nvl(g_sec_detail(i).sigs(j).sig_result, 'I')||'" open-sig="'||g_sec_detail(i).sigs(j).sig_id||'"> <span class="'||g_result(nvl(g_sec_detail(i).sigs(j).sig_result, 'I'))||'_small"></span><span style="padding:5px;">'||prepare_text(g_signatures(g_sec_detail(i).sigs(j).sig_name).title)||'</span> </div>';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                l_html := ' <div class="sectionbutton data '||g_sec_detail(i).name||' '||nvl(g_sec_detail(i).sigs(j).sig_id, 'null')||' '||nvl(g_sec_detail(i).sigs(j).sig_result, 'I')||'" open-sig="'||g_sec_detail(i).sigs(j).sig_id||'"> <span class="'||g_result(nvl(g_sec_detail(i).sigs(j).sig_result, 'I'))||'_small"></span><span style="padding:5px;">' || g_sec_detail(i).sigs(j).sig_name || '</span> </div>';
                WHEN OTHERS THEN
                raise;
            END;
            print_out('
                  $("#sectionmenu").append('''||l_html||''');');
        END LOOP;
    END LOOP;
    print_out('}');  -- EBSAF-211
    print_out('</script>');
*/

EXCEPTION WHEN OTHERS THEN
  print_log('Error in end_main_section: '||sqlerrm);
  raise;
END end_main_section;



----------------------------------------------------------------
-- Creates a report section                                   --
-- For now it just prints html, in future it could be         --
-- smarter by having the definition of the section logic,     --
-- signatures etc....                                         --
----------------------------------------------------------------

PROCEDURE start_section(p_sect_title VARCHAR2, p_sect_name VARCHAR2 DEFAULT null) IS
  lsect section_rec;
  l_sig_array signatures_tbl := signatures_tbl();

BEGIN
  print_out('<div class="sectiongroup" section-id="' || replace_chars(nvl(p_sect_name, p_sect_title)) || ' " section-title="' || htf.escape_sc(p_sect_title) || '">' || chr(10));

  g_sections(g_sections.count + 1) := lsect;

  -- add element in the sections table
  g_sec_detail.extend();
  -- Fix section names (EBSAF-279)
  IF (p_sect_name is not null) THEN
      g_sec_detail(g_sec_detail.LAST).name := replace_chars(p_sect_name);
  ELSE
      g_sec_detail(g_sec_detail.LAST).name := replace_chars(p_sect_title);
  END IF;
  g_sec_detail(g_sec_detail.LAST).title := p_sect_title;

  g_sec_detail(g_sec_detail.LAST).sigs := l_sig_array;
  -- initialize the results hash for section
  g_sec_detail(g_sec_detail.LAST).results('E') := 0;
  g_sec_detail(g_sec_detail.LAST).results('W') := 0;
  g_sec_detail(g_sec_detail.LAST).results('S') := 0;
  g_sec_detail(g_sec_detail.LAST).results('I') := 0;

EXCEPTION WHEN OTHERS THEN
  print_log('Error in start_section: '||sqlerrm);
  raise;
END start_section;


----------------------------------------------------------------
-- Finalizes a report section                                 --
-- Finalizes the html                                         --
----------------------------------------------------------------
PROCEDURE end_section (p_success_msg IN VARCHAR2 DEFAULT null) IS
  -- p_success_message is no longer used (EBSAB-498)
BEGIN
  print_out('</div>' || chr(10));
END end_section;

----------------------------------------------------------------
-- Analyzer-specific code: Function and Procedures (Body)     --
----------------------------------------------------------------
-- Line 1227 of you code successfully prints
-- print_log('l_1222_build11_ok = '||l_1222_build11_ok);
-- so the issue is below line 1227
-- 
-- Add a couple more debugs for navigation to help isolate where it's failing
-- Replace line 1361
--           -- END section verifing correct install of the reported version in version_details, version and build
-- with
--           print_log('===========[ END of reported versions in version_details, version and build ]==========');
-- Add on line 1466
-- 	print_log('l_protocol = '||l_protocol);
-- 	print_log('l_eng_protocol = '||l_eng_protocol);
-- 	print_log('l_MSD_DEM_PROFILE_PROTOCOL = '||l_MSD_DEM_PROFILE_PROTOCOL);
-- Replace line 1467
          -- ==============================================================================================
-- with
--           print_log('===========[ Assigning Global Variables ]=======================');
-- g_concurrent_uers_now           := l_concurrent_uers_now;
--  l_concurrent_uers_now does not exist (edited) 
--  l_concurrent_uers_now is the problem ?
-----------------------------------------------
-- Diagnostic specific functions and procedures
-----------------------------------------------
procedure threadpool IS

begin

-- ADD -> For a different signature id, change THREADPOOL with the sig id (replace spaces by _ and : by  -)
print_out('<div class="data sigcontainer signature THREADPOOL ' ||  replace_chars(g_sec_detail(g_sec_detail.COUNT).name) || ' I section print analysis" level="1" id="THREADPOOL" style="display: none;">');
print_out('<span style="font-size: medium;"><B>Disclaimer</B></span>');

print_out('<span style="font-size: medium;"><UL><li>There are no valid general recommendations available.</li></span>');
print_out('<span style="font-size: medium;"><li>Each implementation is different.</li></span>');
print_out('<span style="font-size: medium;"><li>The setting for the parameters depend on the number of concurrent users, the number of concurrent batch jobs and their nature, the database hardware configuration and more.</li></span></UL><BR><BR>');  
print_out('<span style="font-size: medium;font-weight:bold;">THREADPOOL Section</span><BR>');
print_out('----------------------------------------------------------------------------------------------------------------<BR>');
print_out('<span style="font-size: medium;font-weight:bold;">Overview</span><BR>');
print_out('<span style="font-size: medium;font-weight:bold;">MaxDBConnections</span><BR>');
print_out('<span style="font-size: medium;font-weight:bold;">CPU</span><BR>');
print_out('<span style="font-size: medium;font-weight:bold;">JAVA Analysis</span><BR>');
print_out('<span style="font-size: medium;font-weight:bold;">Parameter Verification Table</span><BR>');
print_out('<span style="font-size: medium;font-weight:bold;">Parallel</span><BR>');
print_out('<span style="font-size: medium;font-weight:bold;">Additional Parameters</span><BR>');
print_out('----------------------------------------------------------------------------------------------------------------<BR>');
print_out('<span style="font-size: medium;">The purpose is to establish the impact possible to the CPU and memory based on current database (RDBMS) and middle tier parameter settings.  The results are meant to reveal potential setup issues and settings that appear to be out of recommended specification.</span><BR>');
print_out('<span style="font-size: medium;">The facts used for this example:</span><br>');
print_out('<UL><li><span style="font-size: medium;">Middle Tier CPU: '||g_middle_tier_cpu||'</span></li>');
print_out('<li><span style="font-size: medium;">RDBMS server CPUs: '||g_physical_cpu_count||'</span></li>');
print_out('<ul><li><span style="font-size: medium;">Note that 4 simultaneous users running worksheets is equal to approximately 30-40 users logged in</span></li></ul>');
print_out('<li><span style="font-size: medium;">MaxUpdateThreads, Number of DB CPU + 1: '||g_maxupdatethreads||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.query_run.size: '||g_tp_query_run_size||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.query_run.per_user: '||g_tp_query_run_per_user||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.update.data.manual.size: '||g_tp_update_data_manual_size||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.update.table.manual.size: '||g_tp_update_table_manual_size||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.update.comb.manual.size: '||g_tp_update_comb_manual_size||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.update.record.manual.size: '||g_tp_update_record_manual_size||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.update.data.batch.size: '||g_tp_update_data_batch_size||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.update.table.batch.size: '||g_tp_update_table_batch_size||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.update.comb.batch.size: '||g_tp_update_comb_batch_size||'</span></li>');
print_out('<li><span style="font-size: medium;">threadpool.update.record.batch.size: '||g_tp_update_record_batch_size||'</span></li></ul>');

print_out('<span style="font-size: medium;"><B>MinDBConnections:</B></span><br>');
print_out('<span style="font-size: medium;">MinDBConnections are allocated at Weblogic startup.  These connections are made available based on parameter driven setting requirements.</span><br>');
print_out('<ul><li><span style="font-size: medium;">The Demanta application setting must match the setting at the Weblogic server to ensure proper memory allocation for Demantra processes.</span></li></ul><br>');

print_out('<span style="font-size: medium;"><B>MaxDBConnections</B>: '||g_maxdbconnections||'</span><BR>');
print_out('<span style="font-size: medium;">It is important that the application server will have sufficient threads to execute all parallel requests, query executions, workflow runs and updates.  Including users opening WorkSheets, running methods and any batch processes that may run in parallel such as data loads BLE.</span><BR>');
print_out('<span style="font-size: medium;"><UL><LI>A rule of thumb would be: number of concurrent users: '||g_concurrent_users||' * threadpool.query_run.per_user: '||g_tp_query_run_per_user||' (+ 10 if threadpool.query_run.per_user > 4)</span></LI></UL><BR>');

print_out('<span style="font-size: medium;"><B>Current middle tier CPU: '||g_middle_tier_cpu||'</B></span><BR>');
print_out('<span style="font-size: medium;">threadpool.query_run.size: '||g_tp_query_run_size||' / threadpool.query_run.per_user: '||g_tp_query_run_per_user||' = '||g_appserver_cpu_required||' suggested CPU required.</span><BR><BR>');

print_out('<span style="font-size: medium;"><B>Worksheet Control:</B></span><BR>');
print_out('<span style="font-size: medium;">There are some parameters that will alert us if the worksheet we are trying to open is too big:</span><BR>');
print_out('<UL><li><span style="font-size: medium;">client.uilimitations.maxcombs.ws: Maximum number of combinations that can be retrieved for a single worksheet</span></li>');
print_out('<ul><li><span style="font-size: medium;">Default: 2000    Current Setting: '||g_ct_uilimitations_maxcombs_ws||'</span></li></ul>');

print_out('<li><span style="font-size: medium;">client.uilimitations.maxcells.ws: The maximum number of cells allowed for a single worksheet</span></li>');
print_out('<ul><li><span style="font-size: medium;">Default: 100000    Current Setting: '||g_ct_uilimitations_maxcells_ws||'</span></li></ul>');

print_out('<li><span style="font-size: medium;">client.uilimitations.maxcells: The total maximum number of cells allowed for the client</span></li>');
print_out('<ul><li><span style="font-size: medium;">Default: 300000    Current Setting: '||g_ct_uilimitations_maxcells||'</span></li></ul>');

print_out('<li><span style="font-size: medium;">client.uilimitations.maxdiskspace: The maximum disk space allowed to be used by the LRU Disk Cache in Kb</span></li>');
print_out('<ul><li><span style="font-size: medium;">Default: 200000    Current Setting: '||g_ct_uilimitations_maxdisk||'</span></li></ul>');

print_out('<li><span style="font-size: medium;">client.uilimitations.warning: The percentage of the allowable maximum combinations, cells or disk space at which to display a warning message.  If this value is 100, then no warnings will be displayed, since the error messages will occur at the same time</span></li>');
print_out('<ul><li><span style="font-size: medium;">Default: 80    Current Setting: '||g_ct_uilimitations_warning||'</span></li></ul>');

print_out('<li><span style="font-size: medium;">max.worksheet.db.weight: The maximum back-end (database) weight (rows of item/location ratio) allowed to be retrieved for a single worksheet.</span></li>');
print_out('<ul><li><span style="font-size: medium;">Default: .5    Current Setting: '||g_max_worksheet_db_weight||'</span></li></ul></ul>');

print_out('<span style="font-size: medium;font-weight:bold;">Parameter Compare Table</span><BR><BR>');
print_out('<span style="font-size: medium;font-weight:bold;">Comparing parameters of typical CONCURRENT user configurations, 8 and 30 users, to current settings in this schema:</span><BR>');
print_out('<span style="font-size: medium;">Compare your settings with the typical settings in the table.  Compare current settings with the typical settings in the table.  Answering questions such as:  Is the value of parameter threadpool.query_run.size = 500?  According to the table below the value is out of scope and could be the cause of a performance problem.</span><BR><BR>');

print_out('<span style="font-size: medium;font-weight:bold;">Concurrent User Parameter Comparison</span><BR>');
print_out('----------------------------------------------------------------------------------------------------------------<BR>');

print_out('<span style="font-size: medium;">Comparing parameters of a typical CONCURRENT user configurations, 8 and 30 users, to current settings in this schema.</span><BR>');
print_out('<span style="font-size: medium;">In the table provided below, compare the instance current settings to the typically recommended settings based on projected/actual concurrent users.</span><BR>');
print_out('<table style="width: 100%;" border="1" cellspacing="1" cellpadding="4">');
print_out('<tbody>');
print_out('<tr>');
print_out('<th class="km" style="width: 20%; padding: 4px;"><span style="font-size: medium;">Parameter</span></th>');
print_out('<th class="km" style="width: 20%; padding: 4px;"><span style="font-size: medium;">8 Users</span></th>');
print_out('<th class="km" style="width: 20%; padding: 4px;"><span style="font-size: medium;">30 Users</span></th>');
print_out('<th class="km" style="width: 20%; padding: 4px;"><span style="font-size: medium;">Your Current Settings</span></th>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">MaxDBConnections</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">100</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">600</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_maxdbconnections||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.query_run.per_user</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">8</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">8</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_query_run_per_user||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.query_run.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">64</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">120</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_query_run_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.update.comb.batch.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">4</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">4</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_update_comb_batch_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.update.data.batch.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">2</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">2</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_update_data_batch_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.update.record.batch.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">4</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">4</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_update_record_batch_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.update.table.batch.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">1</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">1</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_update_table_batch_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.update.comb.manual.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">4</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">4</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_update_comb_manual_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.update.data.manual.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">8</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">15</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_update_data_manual_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.update.record.manual.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">3</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">4</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_update_record_manual_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">threadpool.update.table.manual.size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">2</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">2</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_tp_update_table_manual_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">worksheet.data.comb.block_size</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">200000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">200000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_ws_data_comb_block_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">MaxUpdateThreads</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">CPU+1</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">CPU+1</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_MaxUpdateThreads||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">client.uilimitations.maxcells</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">300000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">300000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_ct_uilimitations_maxcells||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">client.uilimitations.maxcells.ws</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">300000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">300000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_ct_uilimitations_maxcells_ws||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">client.uilimitations.maxcombs.ws</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">300000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">300000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_ct_uilimitations_maxcombs_ws||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">client.uilimitations.maxdiskspace</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">200000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">200000</span></td>');
print_out('<td class="km" style="width: 20%; padding: 4px;"><span style="font-size: small;">'||g_ct_uilimitations_maxdisk||'</span></td>');
print_out('</tr>');
print_out('</tbody>');
print_out('</table><BR><BR>');

print_out('</div>');
-- the above closes the <div> from above

-- ADD replace signature id and name as needed 
     g_sec_detail(g_sec_detail.COUNT).sigs.extend();     
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_id := 'THREADPOOL';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_name := 'Threadpool';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_result := 'I';
--END ADD
end threadpool;

PROCEDURE cpu_required IS

BEGIN

-- ADD -> For a different signature id, change CPU_REQUIRED with the sig id (replace spaces by _ and : by  -)
print_out('<div class="data sigcontainer signature CPU_REQUIRED ' ||  replace_chars(g_sec_detail(g_sec_detail.COUNT).name) || ' I section print analysis" level="1" id="CPU_REQUIRED" style="display: none;">');

print_out('<span style="font-size: medium;font-weight:bold;">JAVA Threads Managed by JVM, Either Weblogic or Tomcat</span><BR>');
print_out('<span style="font-size: medium;">There are two pools of JAVA threads possible.  The MANUAL or USER pool is used when updating a worksheet.  The BATCH pool is used for batch processes such as BLE.</span><BR><BR>');

print_out('<span style="font-size: medium;">We use the following to arrive at the MEMORY requirement for each pool:</span><BR><BR>');
print_out('<span style="font-size: medium;font-weight:bold;">The Batch pool calculation</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.data.batch.size<BR>');
print_out('+<BR>');
print_out('(threadpool.update.data.batch.size * threadpool.update.table.batch.size)<BR>');
print_out('+<BR>');
print_out('(threadpool.update.data.batch.size * threadpool.update.table.batch.size * threadpool.update.comb.batch.size)<BR>');
print_out('+<BR>');
print_out('(threadpool.update.data.batch.size * threadpool.update.table.batch.size * threadpool.update.comb.batch.size * threadpool.update.record.batch.size)<BR><BR></span>');
print_out('<span style="font-size: medium;font-weight:bold;">The Worksheet or User pool calculation</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.data.manual.size<BR>');
print_out('+<BR>');
print_out('(threadpool.update.data.manual.size * threadpool.update.table.manual.size)<BR>');
print_out('+<BR>');
print_out('(threadpool.update.data.manual.size * threadpool.update.table.manual.size) * threadpool.update.comb.manual.size)<BR>');
print_out('+<BR>');
print_out('(threadpool.update.data.manual.size * threadpool.update.table.manual.size) * threadpool.update.comb.manual.size * threadpool.update.record.manual.size)</span><BR><BR>');

print_out('<span style="font-size: medium;font-weight:bold;">This instance has the following JAVA threads ceilings set for WORKSHEET or USER updates:</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.comb.manual.size = </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_comb_manual_size||'</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.data.manual.size = </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_data_manual_size||'</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.record.manual.size = </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_record_manual_size||'</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.table.manual.size = </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_table_manual_size||'</span><BR>');
print_out('<span style="font-size: medium;">The total maximum user update threads required: </span><span style="color:#f2a50c; font-size: medium;">'||g_manual_java_threads||'</span><BR>');
print_out('<span style="font-size: medium;">The maximum user update threads per CPU required is: '||g_manual_threads_per_cpu||' Comparing middle tier CPU </span><span style="color:#f2a50c; font-size: medium;">'||g_middle_tier_cpu||'</span><span style="font-size: medium;"> as the CPU count.</span><BR><BR>');

print_out('<span style="font-size: medium; font-weight:bold;">This instance has the following JAVA threads ceilings set for BATCH updates:</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.comb.batch.size = </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_comb_batch_size||'</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.data.batch.size = </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_data_batch_size||'</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.record.batch.size = </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_record_batch_size||'</span><BR>');
print_out('<span style="font-size: medium;">threadpool.update.table.batch.size = </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_record_batch_size||'</span><BR>');
print_out('<span style="font-size: medium;">The total maximum batch process threads required: '||g_batch_java_threads||'</span><BR>');

print_out('<span style="font-size: medium;">The maximum batch update threads per CPU required is:</span><span style="color:#f2a50c; font-size: medium;"> '||g_batch_threads_per_cpu||'</span><span style="font-size: medium;">  Comparing middle tier CPU </span><span style="color:#f2a50c; font-size: medium;">'||g_middle_tier_cpu||'</span><span style="font-size: medium;"> as the CPU count.</span><BR><BR>');

print_out('<span style="font-size: medium;"><B>Total JAVA thread pool</span></B><br>');
print_out('<span style="font-size: medium;">The maximum total pool possibly required is calculated by adding the User pool + Batch pool.</span><br>');
print_out('<span style="font-size: medium;">You have the following JAVA threads ceilings set for BOTH USER and BATCH updates combined: </span><span style="color:#f2a50c; font-size: medium;">'||g_total_update_pool||'</span><BR>');
print_out('<span style="font-size: medium;">The maximum of threads per CPU required is: </span><span style="color:#f2a50c; font-size: medium;">'||g_pool_threads_per_cpu||'</span><BR>');      
print_out('<span style="font-size: medium;">Comparing middle tier CPU </span><span style="color:#f2a50c; font-size: medium;">'||g_middle_tier_cpu||'</span><span style="font-size: medium;"> as the CPU count.</span><BR><BR>');

print_out('<h3 class="km"><span style="font-size: medium;">Parameter Driven Hardware Requirements</span></h3>');
print_out('<table style="width: 100%;" border="1" cellspacing="1" cellpadding="1">');
print_out('<tbody>');
print_out('<tr>');
print_out('<th class="km" style="width: 100%; padding: 4px;"><span style="font-size: medium;"><B>Parameter Setting Impact</B></span></th>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 100%; padding: 4px;"><span style="font-size: medium;">The total maximum JAVA threads possible, as set in the threadpool parameters, are: </span><span style="font-size: medium;">'||g_total_update_pool||'</span><span style="font-size: medium;">  This is the total possible Manual + Batch Java threads.</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 100%; padding: 4px;"><span style="font-size: medium;">The maximum batch threads available are: </span><span style="color:#f2a50c; font-size: medium;">'||g_app_server_ctas||'</span><span style="font-size: medium;">.  This is calculated as follows: threadpool.update.comb.batch.size </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_comb_batch_size ||'</span><span style="font-size: medium;"> x threadpool.update.data.batch.size </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_data_batch_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 100%; padding: 4px;"><span style="font-size: medium;">The minimum CPU required is: </span><span style="color:#f2a50c; font-size: medium;">'||g_min_comb_cpu_req||'</span><span style="font-size: medium;">.  This is calculated as follows: threadpool.update.comb.batch.size </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_comb_batch_size||'</span></td>');
print_out('</tr>');
print_out('<tr>');
print_out('<td class="km" style="width: 100%; padding: 4px;"><span style="font-size: medium;">The maximum CPU required is: </span><span style="color:#f2a50c; font-size: medium;">'||g_max_comb_cpu_req||'</span><span style="font-size: medium;">.  This is calculated as follows: (threadpool.update.comb.batch.size </span><span style="color:#f2a50c; font-size: medium;">'||g_tp_update_comb_batch_size||'</span><span style="font-size: medium;"> x threadpool.update.data.batch.size </span> <span style="color:#f2a50c; font-size: medium;">'||g_tp_update_data_batch_size||'</span></td>');
print_out('</tr>');
-- print_out('<tr>');
print_out('</tbody>');
print_out('</table><BR><BR>');

print_out('</div>');
-- the above closes the <div> from above

-- ADD replace signature id and name as needed 
     g_sec_detail(g_sec_detail.COUNT).sigs.extend();     
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_id := 'CPU_REQUIRED';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_name := 'CPU Required';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_result := 'I';
--END ADD

END cpu_required;

PROCEDURE maxdbconnections_cpu_check IS
	
begin

  -- ADD -> For a different signature id, change MAXDB_CPU_CHECK with the sig id (replace spaces by _ and : by  -)
  print_out('<div class="data sigcontainer signature maxdbconnections_cpu_check ' ||  replace_chars(g_sec_detail(g_sec_detail.COUNT).name) || ' I section print analysis" level="1" id="maxdbconnections_cpu_check" style="display: none;">');

print_out('<span style="font-size: medium;"><B>Best Practice:</B></span>');
print_out('<ul><li><span style="font-size: medium;">The number of engines/machines as defined in the Engine Administrator should not exceed 3 times the number of database CPUs.</span></li>');
print_out('<li><span style="font-size: medium;">The OS is most likely, by default, limited to 1024, (ulimit) processes, not including any other threads used by JVM and other application processes.</span></li>');
print_out('<li><span style="font-size: medium;">Verify that the configured value does not exceed the system limits.</span></li>');
print_out('<li><span style="font-size: medium;">ulimit -aS - Soft limits</span></li>');
print_out('<ul><li><span style="font-size: medium;">ulimit -aS</span></li></ul>');
print_out('<li><span style="font-size: medium;">ulimit -aH - Hard limits</span></li>');
print_out('<ul><li><span style="font-size: medium;">ulimit -aH</span></li></ul></ul>');

print_out('<span style="font-size: medium;"><B>Best practice regardless of configuration:</B></span>');
print_out('<span style="font-size: medium;"><ul><li>Demantra does not support hyper threading.  If hyperthreading is enabled, please turn hyperthreading off.</li></span>');
print_out('<span style="font-size: medium;"><li>Set the JVM Xmx (max heap-size) to no greater then 50% of available physical memory at the web server.</li></span></ul><br>');

print_out('<span style="font-size: medium;"><B>Typical Implemenation Approach</B></span><BR>');
print_out('<span style="font-size: medium;">If you expect to have 110 users with concurrency rate of 30%, your setting and hardware should be:</span><BR>');
print_out('<span style="font-size: medium;"><ul><li>110 user * 30% = ~40 users</li></span>');
print_out('<span style="font-size: medium;"><li>threadpool.query_run.per_user = 16</li></span>');
print_out('<span style="font-size: medium;"><li>threadpool.query_run.size = Number of concurrent users * threadpool.query_run.per_user (16) = 640</li></span>');
print_out('<span style="font-size: medium;"><li>MaxDBConnections = threadpool.query_run.size + 10 = 650</li></span></ul><BR>');

print_out('<span style="font-size: medium;">To run a production environment with the above settings you should have:</span><BR>');
print_out('<span style="font-size: medium;">Database machine with 110 CPUs (the rule of thumb is: MaxDBConnections (650) / 6 = ~ 110)</span><BR>');
print_out('<span style="font-size: medium;">Application Server with 44 CPUs (the rule of thumb is: (threadpool.query_run.size (640)/16) + 4 which in this case is (640/16) + 4)</span><BR><BR>');

print_out('<span style="font-size: medium;"><B>To Change the Weblogic Application Server Min/Max Capacity</B></span><BR>');
print_out('<span style="font-size: medium;"><ul><li>Log into Weblogic Console.</li></span><BR>');
print_out('<span style="font-size: medium;"><li>Navigate to Console Tree panel on the left hand side and </li></span><BR>');
print_out('<span style="font-size: medium;"><li>select ""Services"-->JDBC-->Datasources---></li></span><BR>');
print_out('<span style="font-size: medium;"><li>Select DemantraDS Connection pool --></li></span><BR>');
print_out('<span style="font-size: medium;"><li>Select Lock and Edit --> Modify the initial capacity and maximum capacity values --> Select activate changes</li></span><BR>');
print_out('<span style="font-size: medium;"><li>Maximum Capacity can be set to the same value of MaxDBConnections parameter.</li></span><BR>');
print_out('<span style="font-size: medium;"><li>Restart the application server.</li></span></ul><BR>');


print_out('</div>');
-- the above closes the <div> from above

-- ADD replace signature id and name as needed 
     g_sec_detail(g_sec_detail.COUNT).sigs.extend();     
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_id := 'maxdbconnections_cpu_check';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_name := 'maxdbconnections_cpu_check';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_result := 'I';
--END ADD

END maxdbconnections_cpu_check;

procedure concurrent_users_derived

IS

begin

  -- ADD -> For a different signature id, change CONC_USERS_DERIVED with the sig id (replace spaces by _ and : by  -)
  print_out('<div class="data sigcontainer signature concurrent_users_derived '||  replace_chars(g_sec_detail(g_sec_detail.COUNT).name) || ' I section print analysis" level="1" id="concurrent_users_derived" style="display: none;">');


  print_out('<span style="font-size: medium;"><B>Concurrent Users Derived compared to Actual Concurrent User</B></span><BR><BR>');
  print_out('<span style="font-size: medium;">threadpool.query_run.size parameter is set to: '||g_tp_query_run_size||'</span><BR>');
  print_out('<span style="font-size: medium;">threadpool.query_run.per_user is set to: '||g_tp_query_run_per_user||'</span><BR>');
  print_out('<span style="font-size: medium;">The potential number of concurrent users can be derived by dividing threadpool.query_run.size: '||g_tp_query_run_size||' / threadpool.query_run.per_user: '||g_tp_query_run_per_user||' = '||g_appserver_cpu_required||' suggested Concurrent Users.</span><BR><BR>');
  
  print_out('<span style="font-size: medium;">This schema has derived concurrent users: '||g_concurrent_users||' which has an impact on MaxDBConnections.  It is OK if MaxDBConnections is set higher than concurrent users however not lower.</span><BR>');
  print_out('<span style="font-size: medium;">MaxDBConnections: '||g_maxdbconnections||' concurrent users: '||g_concurrent_users||'</span><BR>');

print_out('</div>');
-- the above closes the <div> from above

-- ADD replace signature id and name as needed 
     g_sec_detail(g_sec_detail.COUNT).sigs.extend();     
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_id := 'concurrent_users_derived';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_name := 'concurrent_users_derived';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_result := 'I';
--END ADD  
  
END concurrent_users_derived;

PROCEDURE MAX_PARALLEL_CPU_COMP 

IS
	
begin

-- ADD -> For a different signature id, change THREADPOOL with the sig id (replace spaces by _ and : by  -)
print_out('<div class="data sigcontainer signature MAX_PARALLEL_CPU_COMP ' ||  replace_chars(g_sec_detail(g_sec_detail.COUNT).name) || ' I section print analysis" level="1" id="MAX_PARALLEL_CPU_COMP" style="display: none;">');

print_out('<span style="font-size: medium;font-weight:bold;">RDBMS Parameter Setting Impact</span><BR>');
print_out('----------------------------------------------------------------------------------------------------------------<BR>');
print_out('<span style="font-size: medium;">The v$parameter RDBMS settings of sessions and parallel_max_servers are also reported in context of Demantra parameter settings.  For example:</span><BR><BR>');
print_out('<span style="font-size: medium;">The maximum CPU impact is the same as possible Create Table As Select (CTAS) threads allowed.  We calculate maximum possible CTAS as:</span><BR>');

print_out('<span style="font-size: medium;">  - minimum parallel_max_servers_min = cpu_count ('||g_physical_cpu_count||') * 2</span><BR>');
print_out('<span style="font-size: medium;">  - maximum parallel_max_servers_max = cpu_count ('||g_physical_cpu_count||') * 4</span><BR>');
print_out('<span style="font-size: medium;">As an approximate guideline, the number of parallel queues on the RDBMS server should not exceed the number of CPUs of the RDBMS server.</span><BR><BR>');
print_out('<span style="font-size: medium;">Schema MaxDBConnections: '||g_maxdbconnections||'</span><br>');

print_out('<span style="font-size: medium;">This sets the Oracle RDBMS instance ceiling of possible parallel queries started or allocated: (eg. P000, P0001)</span><BR>');
print_out('<span style="font-size: medium;">- Using parallel is very resource hungry.  It should not be used when there are multiple users trying to use the application.</span><BR>');
print_out('<span style="font-size: medium;">- It is effective for large queries and updates where they are few users.  For example the data load process or worksheet operations.</span><BR><BR>');

  IF g_parallel_max_servers >= g_parallel_max_servers_min THEN 
    IF g_parallel_max_servers <= g_parallel_max_servers_max THEN
      print_out('<span style="font-size: medium;">parallel_max_servers are within scope of MIN/MAX servers.</span><BR><BR>');
    ELSE
      print_out('<span style="font-size: medium;">The parameter max_parallel_servers is higher that CPU count * 4.  This is out of recommended scope.</span><BR>');
    END IF;
  ELSE 
    print_out('<span style="font-size: medium;">We advise that max_parallel_servers be set to a minimum of CPU count * 2.</span><BR>');
  END IF;

print_out('<span style="font-size: medium;">All of the sys_params parameters below are generic and unrestricted.  The following relevant parameters are  configured in sys_params:</span><BR>');

print_out('<span style="font-size: medium;"><UL><LI>dynamic_hint_max_parallel_db: '||g_dynamic_hint_max_parallel_db||' is the max number of parallel threads allowed on a database for a worksheet SQL</span></LI><BR>');
   
print_out('</div>');
-- the above closes the <div> from above

-- ADD replace signature id and name as needed 
     g_sec_detail(g_sec_detail.COUNT).sigs.extend();     
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_id := 'MAX_PARALLEL_CPU_COMP';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_name := 'MAX_PARALLEL_CPU_COMP';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_result := 'I';
--END ADD

END MAX_PARALLEL_CPU_COMP;

PROCEDURE PATCH_GAP_ANALYSIS

IS

begin

-- ADD -> For a different signature id, change PATCH_GAP_ANALYSIS with the sig id (replace spaces by _ and : by  -)
print_out('<div class="data sigcontainer signature PATCH_GAP_ANALYSIS ' ||  replace_chars(g_sec_detail(g_sec_detail.COUNT).name) || ' I section print analysis" level="1" id="PATCH_GAP_ANALYSIS" style="display: none;">');

print_out('<span style="font-size: medium;font-weight:bold;">Patch Recommendations Section</span><BR>');
print_out('----------------------------------------------------------------------------------------------------------------<BR>');

print_out('<span style="font-size: medium;font-weight:bold;font-style:italic;">Reporting Missing Mandatory or highly recommended Patches by Release</span><BR>');

print_out('<span style="font-size: medium;font-weight:bold;">--------------------------------------------------------------------</span><br>');

-- If there are no version matches, drive to the patch gap MOS doc
IF g_anchor_test = '2362233.1' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

IF g_current_version = '12.2.11' THEN
   print_out('<span style="font-size: medium;">1. Installed Demantra 12.2.11:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 33556953  - Demanta 12.2.11 Release</span><BR><BR>');
   print_out('<span style="font-size: medium;">2. Highly recommended patches:</span><BR>');  
   print_out('<span style="font-size: medium;">Patch 33624797 - DEMANTRA 12.2.11 WEB GENERIC PATCH (SP 122110418)</span><BR>');
   print_out('<span style="font-size: medium;">Patch 33556715 - 12.2.11.X ORACLE DEMANTRA DATABASE PLATFORM GENERIC PATCH (SP 12210414)</span><BR>');
   print_out('<span style="font-size: medium;">Patch 33602883 - 12.2.11 ENGINE GENERIC PATCH (SP 122110417)</span><BR><BR>');
   print_out('<span style="font-size: medium;">3. For engine, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide.</span><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">For more information see 1342064.1 Install Demantra ~ How to UPGRADE ~ Main Release Patches List And Recommended Patches</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span><BR>');
   print_out('<span style="font-size: medium;">- DB 19c</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR2 (12.2.0.1)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 11gR2 (11.2.0.4+)</span><BR><BR>');
END IF;

IF g_current_version = '12.2.10' THEN
   print_out('<span style="font-size: medium;">1. Installed Demantra 12.2.10: Patch 31913246  - Demanta 12.2.10 Release</span><BR><BR>');
   print_out('<span style="font-size: medium;">2. Highly recommended patches:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 32241210 - 12.2.10.X ORACLE DEMANTRA DATABASE PLATFORM GENERIC PATCH (SP 12210406)</span><BR>');
   print_out('<span style="font-size: medium;">Patch 32886426 - ISSUE IN CUSTOM STEP EXECUTION DURING DATA SAVE FROM WORKSHEET - web mandatory patch that is require to be applied only once</span><BR>');
   print_out('<span style="font-size: medium;">Patch 32632953 - GENERIC 12.2.10 WEB PATCH (SP 12210409) This patch should be apply only on demantra version 12.2.10</span><BR>');
   print_out('<span style="font-size: medium;">Patch 33602881 - 12.2.10 ENGINE GENERIC PATCH (SP 12210416) This patch should be apply only on demantra version 12.2.10</span><BR><BR>');
   print_out('<span style="font-size: medium;">3. For engine, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide.</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">For more information see 1342064.1 Install Demantra ~ How to UPGRADE ~ Main Release Patches List And Recommended Patches</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span><BR>');
   print_out('<span style="font-size: medium;">- DB 19c</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR2 (12.2.0.1)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 11gR2 (11.2.0.4+)</span><BR><BR>');
END IF;

IF g_current_version = '12.2.9' and g_current_build = '17' THEN
   print_out('<span style="font-size: medium;">1. Installed Demantra 12.2.9, Build 17:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 30187573  - Demanta 12.2.9 Release (BUILD=17 AppServer=6167)</span><BR>');
   print_out('<span style="font-size: medium;">2. Highly recommended patches:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 30324307 - GENERIC 12.2.9 WEB PATCH (SP 12290397).  This patch should be apply only on demantra version 12.2.9</span><BR>');
   print_out('<span style="font-size: medium;">Patch 31488676 - GENERIC 12.2.9 DB PATCH (SP 12290401).</span><BR>');
   print_out('<span style="font-size: medium;">Patch 32978049 - 12.2.9 ENGINE GENERIC PATCH (SP 12290410)</span><BR><BR>');
   print_out('<span style="font-size: medium;">3. For engine, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide.</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">For more information see 1342064.1 Install Demantra ~ How to UPGRADE ~ Main Release Patches List And Recommended Patches</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span><BR>');
   print_out('<span style="font-size: medium;">- DB 19c</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR2 (12.2.0.1)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 11gR2 (11.2.0.4+)</span><BR><BR>');
END IF;

IF g_current_version = '12.2.9' and g_current_build = '15' THEN

   print_out('<span style="font-size: medium;">1. Installed Demantra 12.2.9, Build 15:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 30187573  - Demanta 12.2.9 Release (BUILD=15 AppServer=6035) - old build</span><BR><BR>');
   print_out('<span style="font-size: medium;">2. Highly recommended patches:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 30324307 - GENERIC 12.2.9 WEB PATCH (SP 12290397).  This patch should be apply only on demantra version 12.2.9</span><BR>');
   print_out('<span style="font-size: medium;">Patch 31488676 - GENERIC 12.2.9 DB PATCH (SP 12290401).</span><BR>');
   print_out('<span style="font-size: medium;">Patch 32978049 - 12.2.9 ENGINE GENERIC PATCH (SP 12290410)</span><BR><BR>');
   print_out('<span style="font-size: medium;">3. For engine, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide.</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">For more information see 1342064.1 Install Demantra ~ How to UPGRADE ~ Main Release Patches List And Recommended Patches</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span><BR>');
   print_out('<span style="font-size: medium;">- DB 19c</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR2 (12.2.0.1)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 11gR2 (11.2.0.4+)</span><BR><BR>');
END IF;

IF g_current_version = '12.2.8' THEN
   print_out('<span style="font-size: medium;">1. Installed Demantra Patch 28653182  - Demanta 12.2.8 Release (BUILD=18 AppServer=5882)</span><BR><BR>');
   print_out('<span style="font-size: medium;">2. Highly recommended patches:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 28968256 - GENERIC 12.2.8 WEB PATCH (SP 12280384).  This patch should be apply only on demantra version 12.2.8</span><BR>');
   print_out('<span style="font-size: medium;">Patch 29533273 - 12.2.8.X ORACLE DEMANTRA DATABASE PLATFORM GENERIC PATCH (12280391)</span><BR><BR>');
   print_out('<span style="font-size: medium;">3. For engine, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide. </span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">For more information see 1342064.1 Install Demantra ~ How to UPGRADE ~ Main Release Patches List And Recommended Patches</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span><BR>');
   print_out('<span style="font-size: medium;">- DB 19c</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR2 (12.2.0.1)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 11gR2 (11.2.0.4+)</span><BR><BR>');
END IF;


IF g_current_version = '12.2.7.1' THEN
   print_out('<span style="font-size: medium;">1. Installed Demantra Patch 27506109  - Demanta 12.2.7.1 Release (BUILD=106 AppServer=5664)</span><BR><BR>');
   print_out('<span style="font-size: medium;">2. Highly recommended patches:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 28080594 - GENERIC 12.2.7.1 WEB PATCH (SP 12270371) . This patch should be apply only on demantra version 12.2.7.1</span><BR>');
   print_out('<span style="font-size: medium;">Patch 26975832 - GENERIC 12.2.7.X DATABASE PLATFORM GENERIC PATCH (SP 12270326 )</span><BR>');
   print_out('<span style="font-size: medium;">Patch 28002205 - ENGINE NOT WRITING BASELINE FORECAST TO SALES_DATA (SP 12270365 )</span><BR><BR>');
   print_out('<span style="font-size: medium;">3. For engine, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide.</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">For more information see 1342064.1 Install Demantra ~ How to UPGRADE ~ Main Release Patches List And Recommended Patches</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span><BR>');
   print_out('<span style="font-size: medium;">- DB 19c</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR2 (12.2.0.1)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 11gR2 (11.2.0.4+)</span><BR><BR>');
END IF;

IF g_current_version = '12.2.6.3' THEN
   print_out('<span style="font-size: medium;">1. Installed Demantra Patch 27209775  - Demanta 12.2.6.3 Release (BUILD=311 AppServer=5514)</span><BR><BR>');
   print_out('<span style="font-size: medium;">2. Highly recommended patches:</span><BR>');
   print_out('<span style="font-size: medium;">Patch 27278471 - GENERIC 12.2.6.3 WEB PATCH (SP 12260340)</span><BR>');
   print_out('<span style="font-size: medium;">Patch 25420760 - GENERIC 12.2.6.X DATABASE PLATFORM PATCH ( SP 12260250 )</span><BR>');
   print_out('<span style="font-size: medium;">Patch 28003547 - ENGINE 2K LOG ERROR PLS-00905: OBJECT TPM.PROCESSTEMPSALESTABLE0 IS INVALID (SP 12260366) - engine patch</span><BR><BR>');
   print_out('<span style="font-size: medium;">3. For engine, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide.</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">For more information see 1342064.1 Install Demantra ~ How to UPGRADE ~ Main Release Patches List And Recommended Patches</span><BR><BR>');
   print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span></span><BR>');
   print_out('<span style="font-size: medium;">- DB 19c</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR2 (12.2.0.1)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
   print_out('<span style="font-size: medium;">- DB 11gR2 (11.2.0.4+)</span><BR><BR>');
END IF;

IF g_current_version = '12.2.5.1' THEN
    print_out('<span style="font-size: medium;">1. Installed Demantra 12.2.5.1: Patch 21951481 - DEMANTRA 12.2.5.1 Release (BUILD=136 AppServer=3825)<BR><BR>');
    print_out('<span style="font-size: medium;">2. Highly recommended patches:<BR>');
    print_out('<span style="font-size: medium;">For engine on Demantra 12.2.5.1, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide.<BR>');
    print_out('<span style="font-size: medium;">Patch 27320973 - 12.2.5.1 GENERIC PATCH (WEB, PB, DB) (SP=12250299) - latest generic WEB patch. This will have all web fixes followed by<BR>');
    print_out('<span style="font-size: medium;">Patch 22254051 - 12.2.5.X ORACLE DEMANTRA DATABASE PLATFORM GENERIC PATCH (SP=12250139) - generic DB patch apply on demantra 12.2.5.x only<BR>');
    print_out('<span style="font-size: medium;">Patch 28049497 - ENGINE ERROR- MATLAB EXCEPTION: MCLMTIMES: INVALID MATRICES DIMENSIONS ( SP = 12250379 (5491))<BR><BR>');
    print_out('<span style="font-size: medium;">3. For engine on Demantra 12.2.5.1, please follow Note 2069139.1 - 12.2.5.1 Engine Deployment Guide.<BR><BR>');
	print_out('<span style="font-size: medium;font-weight:bold;">For more information see 1342064.1 Install Demantra ~ How to UPGRADE ~ Main Release Patches List And Recommended Patches</span><BR><BR>');
	print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span></span><BR>');
    print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
    print_out('<span style="font-size: medium;">- DB 11gR2 (latest version)</span><BR>');
    print_out('<span style="font-size: medium;">- DB 11gR</span><BR><BR>');
END IF;

IF g_current_version = '12.2.4.1' THEN
    print_out('<span style="font-size: medium;">Demantra patches for 12.2.4.1 see Note 1342064.1<BR><BR>');
	print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span></span><BR><BR>');
    print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
    print_out('<span style="font-size: medium;">- DB 11gR2 (latest version)</span><BR>');
    print_out('<span style="font-size: medium;">- DB 11gR</span><BR><BR>');
END IF;

IF g_current_version = '12.2.3' THEN
    print_out('<span style="font-size: medium;">Demantra patches for 12.2.3 see Note 1342064.1</span><BR><BR>');
	print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span><BR>');
    print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
    print_out('<span style="font-size: medium;">- DB 11gR2 (latest version)</span><BR>');
    print_out('<span style="font-size: medium;">- DB 11gR</span><BR><BR>');
END IF;

IF g_current_version = '12.2.2' THEN
    print_out('<span style="font-size: medium;">Demantra patches for 12.2.2 see Note 1342064.1</span><BR><BR>');
	print_out('<span style="font-size: medium;font-weight:bold;">Oracle Database Certifications For Demantra '||g_current_version||'</span><BR>');
    print_out('<span style="font-size: medium;">- DB 12cR1 (12.1.0.1 and 12.1.0.2)</span><BR>');
    print_out('<span style="font-size: medium;">- DB 11gR2 (latest version)</span><BR>');
    print_out('<span style="font-size: medium;">- DB 11gR</span><BR><BR>');
END IF;

-- 12.2.7.1 Build 107
-- 27506109 	  	Build 107 	5667 	Base 	Base install.
-- 27128464 	12270334 	  	apps srv 	WEB 	Highly recommended patch. GENERIC 12.2.7 WEB PATCH.
-- 26975832 	12270326 	  	apps srv 	DB 	Highly recommended patch. GENERIC 12.2.7.X DATABASE PLATFORM GENERIC PATCH.

IF g_12271_build107_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.7.1, Build 107 isntalled.<BR><BR>');
END IF;

IF g_12271_27128464_attn != 1 and g_current_version = '12.2.7' and g_current_build = '107' THEN
  print_out('ATTENTION: Patch 27128464, SP 12270334, Customer Generic Highly recommended patch.  WEB PATCH for 12.2.7.1, build 107.<BR><BR>');
END IF;

IF g_12271_26975832_attn != 1 and g_current_version = '12.2.7' and g_current_build = '107' THEN
  print_out('ATTENTION: Patch 26975832, SP 12270326, Customer Generic Highly recommended patch.  DB PATCH for 12.2.7.1, build 107.<BR><BR>');
END IF;

IF g_anchor_link = '12.2.7_107' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.7_107">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 12.2.7.1 Build 107
-- 27506109 	  	Build 107 	5667 	Base 	Base install.
-- 27128464 	12270334 	  	apps srv 	WEB 	Highly recommended patch. GENERIC 12.2.7 WEB PATCH.
-- 26975832 	12270326 	  	apps srv 	DB 	Highly recommended patch. GENERIC 12.2.7.X DATABASE PLATFORM GENERIC PATCH.

IF g_12271_build107_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.7.1, Build 107 isntalled.<BR><BR>');
END IF;

IF g_12271_27128464_attn != 1 and g_current_version = '12.2.7' and g_current_build = '107' THEN
  print_out('ATTENTION: Patch 27128464, SP 12270334, Customer Generic Highly recommended patch.  WEB PATCH for 12.2.7.1, build 107.<BR><BR>');
END IF;

IF g_12271_26975832_attn != 1 and g_current_version = '12.2.7' and g_current_build = '107' THEN
  print_out('ATTENTION: Patch 26975832, SP 12270326, Customer Generic Highly recommended patch.  DB PATCH for 12.2.7.1, build 107.<BR><BR>');
END IF;

-- 
-- <h2 class="km">12.2.7 Build 19</h2>

IF g_anchor_link = '12.2.7_19' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.7_19">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 12.2.7 Build 19
-- 26710559 	  	Build 19 	5513 	Base 	Base install.
-- 27128464 	12270334 	  	apps srv 	WEB 	Highly recommended patch. GENERIC 12.2.7 WEB PATCH.
-- 26975832 	12270326 	  	apps srv 	DB 	Highly recommended patch. GENERIC 12.2.7.X DATABASE PLATFORM GENERIC PATCH.

IF g_1227_build19_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.7, Build 19 installed.</span><BR><BR>');
END IF;

IF g_1227_27128464_attn != 1 and g_current_version = '12.2.7' and g_current_build = '19' THEN
  print_out('ATTENTION: Patch 27128464, SP 12270334 Customer Generic Highly recommended WEB PATCH patch for 12.2.7.x., build 19.<BR><BR>');
END IF;

IF g_1227_26975832_attn != 1 and g_current_version = '12.2.7' and g_current_build = '19' THEN
  print_out('ATTENTION: Patch 26975832, SP 12270326, Customer Generic Highly recommended DATABASE PLATFORM patch for 12.2.7.x., build 19.<BR><BR>');
END IF;

-- 
-- <h2 class="km">12.2.6.3 Build 311</h2>

IF g_anchor_link = '12.2.6_311' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.6_311">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 12.2.6.3 Build 311
-- 27209775 	  	Build 311 	5514 	Base 	Base Install.
-- 27278471 	12260340 	  	  	DB 	Highly recommended patch. Generic Patch Web,PB.
-- 25420760 	12260250 	  	  	DB 	Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.

IF g_12263_build311_ok = 1 and g_current_version = '12.2.6' and g_current_build = '311' THEN
  print_out('<span style="font-size: medium;">12.2.6.3, Build 311 installed.<BR><BR>');
END IF;

IF g_12263_27278471_attn != 1 and g_current_version = '12.2.6' and g_current_build = '311' THEN
  print_out('ATTENTION: Patch 27278471, SP 12260340, Customer Generic Web,PB Patch to be applied on top of 12.2.6.3, build 311.<BR><BR>');
END IF;

IF g_12263_25420760_attn != 1 and g_current_version = '12.2.6' and g_current_build = '311' THEN
  print_out('ATTENTION: Patch 25420760, SP 12260250, Customer Generic DATABASE PLATFORM Patch to be applied on top of 12.2.6.3, build 311.<BR><BR>');
END IF;

-- ----------------------------------------------------

-- <h2 class="km">12.2.6.2 Build 216</h2>

IF g_anchor_link = '12.2.6_216' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.6_216">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 12.2.6.2 Build 216
-- 25820351 	  	Build 216 	4956 	Base 	Base Install.
-- 26641148 	12260314 WEB 	Highly recommended patch. GENERIC 12.2.6.2 WEB PATCH.
-- 25420760 	12260250 DB 	Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.
-- 26798382 	12260323 Engine 	Highly recommended patch. FAILED TO BULK LOAD THE BRANCH DIVIDER OUTPUT TO THE DB.

IF g_12262_build216_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.6.2, Build 216 isntalled.<BR><BR>');
END IF;

If g_current_version = '12.2.6' and g_current_build = '216' and g_12262_26641148_attn != 1 THEN
    print_out('ATTENTION: Patch 26641148, SP 12260314.  Highly recommended patch. GENERIC 12.2.6.2 WEB PATCH on top of 12.2.6.2, build 216.<BR>');
END IF;

If g_current_version = '12.2.6' and g_current_build = '216' and g_12262_25420760_attn != 1 THEN
    print_out('ATTENTION: Patch 25420760, SP 12260250.  Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH on top of 12.2.6.2, build 216.<BR>');
END IF;

IF g_current_version = '12.2.6' and g_current_build = '216' and g_12262_26798382_attn != 1 THEN
  print_out('ATTENTION: Patch 26798382, SP 12260323.  Highly recommended patch. FAILED TO BULK LOAD THE BRANCH DIVIDER OUTPUT TO THE DB on top of 12.2.6.2, build 216.<BR><BR>');
END IF;

--
-- <h2 class="km">12.2.6.1 Build 112</h2>

IF g_anchor_link = '12.2.6_112' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.6_112">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 12.2.6.1 Build 112
-- 25168361 	  	Build 112 	4770 	Base 	Base Install. Demanta 12.2.6.1
-- 25403411 	12260251 	  	  	WEB 	Highly recommended patch. INSTALLER FOR THE LOCAL APP THAT SUPPORTS A 32-BIT O/S.
-- 25420760 	12260250 	  	  	DB 	Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.

IF g_12261_build112_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.6.1, Build 112 installed.<BR><BR>');
END IF;


If g_current_version = '12.2.6' AND g_current_build = '112' AND g_12261_25403411_attn != 1 THEN
    print_out('ATTENTION: Patch 12260251, SP 25403411, build 4857.  Customer Web Patch to be applied on top of 12.2.6.1, build 112.<BR><BR>');
END IF;

IF g_current_version = '12.2.6' AND g_current_build = '112' and g_12261_25420760_attn != 1 THEN
  print_out('ATTENTION: Patch 12260250, SP 25420760, Customer Web Patch to be applied on top of 12.2.6.1, build 112.<BR><BR>');
END IF;


-- 
-- 12.2.6.1 Build 110
-- verify that this is not installed
IF g_12261_build110_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.6.1, Build 110 is INCORRECTLY installed.<BR><BR>');
END IF;

-- 
-- <h2 class="km">12.2.6 Build 35</h2>

IF g_anchor_link = '12.2.6_35' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.6_35">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 12.2.6 Build 35
-- 24393123 	  	Build 35 	4622 	Base 	Base Install. Demanta 12.2.6
-- 25420760 	12260250 	  	  	DB 	Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.
-- 25332169 	12260244 	  	  	WEB 	Highly recommended patch. Local application cannot be installed if jre 1.8.112 is installed.

IF g_1226_build35_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.6, Build 35 installed.<BR><BR>');
END IF;

IF g_current_version = '12.2.6' AND g_current_build = '35' and g_1226_25420760_attn != 1 THEN
  print_out('ATTENTION: Patch 25420760, SP 12260250.  Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.<BR><BR>');
END IF;

If g_current_version = '12.2.6' AND g_current_build = '35' and g_1226_25332169_attn != 1 THEN
    print_out('ATTENTION: Patch 25332169, SP 12260244.  Highly recommended patch. Local application cannot be installed if jre 1.8.112 is installed.<BR>');
    print_out('A generic patch on top of 12.2.6 build 35 to resolve the installation issue of the Demantra Local Application if JRE 8 update 112 or above installed JRE.<BR><BR>');
END IF;

-- 
-- <h2 class="km">12.2.5.1 Build 136</h2>

IF g_anchor_link = '12.2.5_136' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.5_136">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 12.2.5.1 Build 136
-- 21951481 	  	Build 136 	3825 	Base 	Base Install. Demanta 12.2.5.1
-- 27320973 	12250299 	  	  	WEB 	Highly recommended patch. Latest generic WEB patch. Followed by:
-- 22254051 	12250139 	DB  Highly recommended patch. 12.2.5.X DEMANTRA PERFORMANCE ISSUE ON EP_LOAD - Generic DB patch to apply on Demantra 12.2.5.x only.
-- 26663751 	12250322 	  	  	Engine 	Highly recommended patch. SIMULATION ENGINE IS CRASHING. EVEN AFTER CLEARING QUEUES.

IF g_1225_build136_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.5.1, Build 136 installed.<BR><BR>');
END IF;

If g_12251_27320973_attn != 1 and g_current_version = '12.2.5' AND g_current_build = '136' THEN
    print_out('ATTENTION: patch 27320973, sp patch 12250299.  Highly recommended patch. Latest generic WEB patch. Followed by: 22254051 and 26663751 in that order.<BR><BR>');
END IF;

IF g_12251_22254051_attn != 1 and g_current_version = '12.2.5' AND g_current_build = '136' THEN
  print_out('ATTENTION: Patch 22254051, SP 12250139, Highly recommended patch. 12.2.5.X DEMANTRA PERFORMANCE ISSUE ON EP_LOAD - Generic DB patch to apply on Demantra 12.2.5.x only.</span><BR><BR>');
END IF;

IF g_12251_26663751_attn != 1 and g_current_version = '12.2.5' AND g_current_build = '136' THEN
  print_out('ATTENTION: Patch 26663751, SP 12250322.  Highly recommended patch. SIMULATION ENGINE IS CRASHING. EVEN AFTER CLEARING QUEUES.<BR><BR>');
END IF;


-- 
-- <h2 class="km">12.2.5 Build 3</h2>

IF g_anchor_link = '12.2.5_3' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.5_3">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

IF g_1225_build3_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.5, Build 3 installed.<BR><BR>');
END IF;

-- 
-- <h2 class="km">12.2.4.1 Build 117</h2>

IF g_anchor_link = '12.2.4_117' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.4_117">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 19973580 	  	Build 117 	3307 	Base 	Base Install. DEMANTRA 12.2.4.1
-- 18139794 	12230033 	45+ 	  	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.

IF g_12241_build117_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.4.1, Build 117 installed.<BR><BR>');
END IF;

IF g_12241_18139794_attn != 1 and g_current_version = '12.2.4' AND g_current_build = '117' THEN
  print_out('ATTENTION: Patch 12230033, SP 18139794, build 45.  Highly recommended patch. 12.2.x oracle Demantra database platform generic patch. Minimum Build Required: 45.<BR><BR>');
END IF;

-- 
-- <h2 class="km">12.2.4 Build 50</h2>

IF g_anchor_link = '12.2.4_50' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.4_50">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 19361678 	  	Build 50 	  	Base 	Base Install. DEMANTRA 12.2.4
-- 18139794 	12230033 	45+ 	  	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.

IF g_1224_build50_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.4, Build 50 installed.<BR><BR>');
END IF;

IF g_1224_18139794_attn != 1 and g_current_version = '12.2.4' AND g_current_build = '50' THEN
  print_out('ATTENTION: Patch 18139794, SP 12230033.  Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.<BR><BR>');
END IF;

-- 
-- <h2 class="km">12.2.3 Build 6</h2>

IF g_anchor_link = '12.2.3_6' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.3_6">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 17921238 	  	Build 6 	Base 	Base Install. DEMANTRA 12.2.3
-- 18139794 	12230033 	45+   	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.

IF g_1223_build6_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.3, Build 6 installed.<BR><BR>');
END IF;

IF g_12263_18139794_attn != 1 and g_current_version = '12.2.6' AND g_current_build = '6' THEN
  print_out('ATTENTION: Patch 18139794, SP 12230033.  Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.<BR><BR>');
END IF;

-- 
-- <h2 class="km">12.2.2 Build 11</h2>

IF g_anchor_link = '12.2.2_11' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.2_11">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 17326462 	  	Build 11 	  	Base 	Base Install. DEMANTRA 12.2.2
-- 18139794 	12230033 	45+ 	  	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.
-- 17640575 	  	  	  	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

IF g_1222_build11_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.2, Build 11 installed.<BR><BR>');
END IF;

IF g_1222_18139794_attn != 1 and g_current_version = '12.2.2' AND g_current_build = '11' THEN
  print_out('ATTENTION: Patch 18139794, SP 12230033.  Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.<BR><BR>');
END IF;

IF g_1222_17640575_attn != 1 and g_current_version = '12.2.2' and g_current_build = '11' THEN
  print_out('ATTENTION: patch 7314232, SP 17640575.  Highly recommended patch. Demantra TABLE_REORG PATCH.<BR>');
END IF;


-- 
-- <h2 class="km">12.2.1 Build 15</h2>

IF g_anchor_link = '12.2.1_15' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.1_15">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 16409031 	Build 15 	  	Base 	Base Install. DEMANTRA 12.2.1
-- 18139794 	12230033 	45+   	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.
-- 17640575 	  	  	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

IF g_1221_build11_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.1, Build 15 installed.<BR><BR>');
END IF;

IF g_1221_18139794_attn != 1 and g_current_version = '12.2.1' AND g_current_build = '15' THEN
  print_out('ATTENTION: Patch 18139794, SP 12230033.  Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.<BR><BR>');
END IF;

IF g_1221_17640575_attn != 1 and g_current_version = '12.2.1' and g_current_build = '15' THEN
  print_out('ATTENTION: patch 7314232, SP 17640575.  Highly recommended patch. Demantra TABLE_REORG PATCH.<BR>');
END IF;


-- 
-- <h2 class="km">12.2.0 Build 87</h2>

IF g_anchor_link = '12.2.0_87' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#12.2.0_87">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

IF g_1220_build87_ok = 1 THEN
  print_out('<span style="font-size: medium;">12.2.0, Build 87 installed.<BR><BR>');
END IF;

IF g_1220_17640575_attn != 1 and g_current_version = '12.2.0' and g_current_build = '87' THEN
  print_out('ATTENTION: patch 7314232, SP 17640575.  Highly recommended patch. Demantra TABLE_REORG PATCH.<BR>');
END IF;

-- 
-- <h2 class="km">7.3.1.5(.2) Build 5207</h2>

IF g_anchor_link = '7.3.1_5207' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#7.3.1_5207">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 17850720 	  	Build 5207 	  	Base 	Base Install. DEMANTRA 7.3.1 CU5
-- 18048597 	7314242 26 DB, Highly recommended patch. 7.3.1.x oracle demantra database platform generic patch. Minimum Build Required: 26 as of Dec 2017.
-- 20415508 	7315273 	  	  	DB 	Highly recommended patch. historylength parameter does not work per node.
-- 17640575 	  	  	  	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

IF g_7315_build5207_ok = 1 THEN
  print_out('<span style="font-size: medium;">7.3.1.5, Build 5207 installed.<BR><BR>');
END IF;

IF g_7315_18048597_5207_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '5207' THEN
  print_out('ATTENTION: patch 18048597, SP 7314242. Highly recommended DB patch. 7.3.1.x oracle Demantra database platform generic patch. Minimum Build Required: 26 as of Dec 2017.Build 5207.<BR>');
END IF;

IF g_7315_20415508_5207_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '5207' THEN
  print_out('ATTENTION: patch 20415508, SP 7315273.  Highly recommended DB patch. historylength parameter does not work per node.<BR>');
END IF;

IF g_7315_17640575_5207_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '5207' THEN
  print_out('ATTENTION: patch 7314232, SP 17640575.  Highly recommended patch. Demantra TABLE_REORG PATCH.<BR>');
END IF;


-- 
-- <h2 class="km">7.3.1.5(.1) Build 5106</h2>

IF g_anchor_link = '7.3.1_5106' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#7.3.1_5106">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

IF g_73151_build5106_ok = 1 THEN
  print_out('<span style="font-size: medium;">7.3.1.5, Build 5106 installed.<BR><BR>');
END IF;

IF g_7315_17640575_5106_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '5106' THEN
  print_out('ATTENTION: patch 7314232, SP 17640575.  Highly recommended patch. Demantra TABLE_REORG PATCH.<BR>');
END IF;

-- 
-- <h2 class="km">7.3.1.5 Build 528</h2>

IF g_anchor_link = '7.3.1_528' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#7.3.1_528">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 16865694 	  	Build 5106 	  	Base 	Base Install. DEMANTRA Consumption-Driven Planning Release 7.3.1.5
-- 18048597 	7314242 26 DB 	Highly recommended patch. 7.3.1.x oracle demantra database platform generic patch. Minimum Build Required: as of Dec 2017.
-- 20415508 	7315273 	  	  	DB 	Highly recommended patch. historylength parameter does not work per node.
-- 17640575 	 	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

IF g_7315_build528_ok = 1 THEN
  print_out('<span style="font-size: medium;">7.3.1.5, Build 528 installed.<BR><BR>');
END IF;

IF g_7315_18048597_528_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '528' THEN
  print_out('ATTENTION: patch 18048597, SP 7314242, Generic non-installer patch for 7.3.1.5, Build 528.<BR>');
END IF;

IF g_7315_20415508_528_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '528' THEN
  print_out('ATTENTION: patch 20415508, SP 7315273, Generic non-installer patch for 7.3.1.5, Build 528.<BR>');
END IF;

IF g_7315_17640575_528_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '528' THEN
  print_out('ATTENTION: patch 7314232, SP 17640575, Generic non-installer patch for 7.3.1.5, Build 528.<BR>');
END IF;


-- 
-- <h2 class="km">7.3.1.4.4 Build 450</h2>

IF g_anchor_link = '7.3.1_450' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#7.3.1_450">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

-- 14405087 	  	Build 450 	  	Base 	Base Install. 7.3.1.4.4
-- 18048597 	7314242 26 DB 	Highly recommended patch. 7.3.1.x oracle demantra database platform generic patch. Minimum Build Required: as of Dec 2017.
-- 17640575 	  	  	  	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

IF g_7314_build450_ok = 1 THEN
  print_out('<span style="font-size: medium;">7.3.1.4.4, Build 450 installed.<BR><BR>');
END IF;

IF g_7314_18048597_450_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '450' THEN
  print_out('ATTENTION: patch 18048597, SP 7314242, Generic non-installer patch for 7.3.1.4.4, Build 450.<BR>');
END IF;

IF g_7314_17640575_450_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '450' THEN
  print_out('ATTENTION: patch 7314232, SP 17640575, Generic non-installer patch for 7.3.1.4.4, Build 450.<BR>');
END IF;


-- 
-- <h2 class="km">7.3.1.4.3 Build 442</h2>

IF g_anchor_link = '7.3.1_442' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#7.3.1_442">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

IF g_7314_17640575_442_attn != 1 and g_current_version = '7.3.1' AND g_current_build = '442' THEN
  print_out('ATTENTION: patch 7314232, SP 17640575, Generic non-installer patch for 7.3.1.4.4, Build 442.<BR>');
END IF;



-- ----------------------------------------------------
IF g_anchor_link = '7.3.1_442' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#7.3.1_442">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;


IF g_anchor_link = '7.3.1_419' then
print_out('<span style="font-size: medium;">Complete Patch List For '||g_current_version||' build '||g_current_build||': '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#590">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;

IF g_7314_build419_ok = 1 THEN
  print_out('<span style="font-size: medium;">7.3.1.4, Build 419 installed.  Please consider upgrading. '||'<a target="_blank" href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&sourceId=1618885.1_sigId8166&id=2362233.1#590">Doc ID 2362233.1</a>'||'</span><br><br>');
END IF;


print_out ('</div>');
-- the above closes the <div> from above

-- ADD replace signature id and name as needed 
     g_sec_detail(g_sec_detail.COUNT).sigs.extend();     
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_id := 'PATCH_GAP_ANALYSIS';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_name := 'Patch Recommendations';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_result := 'I';
--END ADD
END PATCH_GAP_ANALYSIS;





-------------------------
-- Recommended Patches
-------------------------




-------------------------
-- Signatures
-------------------------


PROCEDURE add_signature(
  p_sig_repo_id      VARCHAR2    DEFAULT '',        -- IF of the signature in Sig Repo
  p_sig_id           VARCHAR2,     -- Unique Signature identifier
  p_sig_sql          VARCHAR2,     -- The text of the signature query
  p_title            VARCHAR2,     -- Signature title
  p_fail_condition   VARCHAR2,     -- 'RSGT1' (RS greater than 1), 'RS' (row selected), 'NRS' (no row selected), '[count(*)] > [0]'
  p_problem_descr    VARCHAR2,     -- Problem description
  p_solution         VARCHAR2,     -- Problem solution
  p_success_msg      VARCHAR2    DEFAULT null,      -- Message on success
  p_print_condition  VARCHAR2    DEFAULT 'ALWAYS',  -- ALWAYS, SUCCESS, FAILURE, NEVER
  p_fail_type        VARCHAR2    DEFAULT 'W',       -- Warning(W), Error(E), Informational(I) is for use of data dump so no validation
  p_print_sql_output VARCHAR2    DEFAULT 'RS',      -- Y/N/RS - when to print data
  p_limit_rows       VARCHAR2    DEFAULT 'Y',       -- Y/N
  p_extra_info       HASH_TBL_4K DEFAULT CAST(null AS HASH_TBL_4K), -- Additional info
  p_child_sigs       VARCHAR_TBL DEFAULT VARCHAR_TBL(),
  p_include_in_dx_summary   VARCHAR2    DEFAULT 'N', -- This is for AT use so internal only. Set to Y if want signature result to be printed at end of output file in DX Summary section
  p_version          VARCHAR2    DEFAULT null)  -- Used for performance tracking over time
IS
    l_rec signature_rec;
    l_key varchar2(255);
    l_new_key varchar2(255);
BEGIN
    l_rec.sigrepo_id       := p_sig_repo_id;
    l_rec.sig_sql          := p_sig_sql;
    l_rec.title            := p_title;
    l_rec.fail_condition   := p_fail_condition;
    l_rec.problem_descr    := p_problem_descr;
    l_rec.solution         := p_solution;
    l_rec.success_msg      := p_success_msg;
    l_rec.print_condition  := p_print_condition;
    l_rec.fail_type        := p_fail_type;
    l_rec.print_sql_output := p_print_sql_output;
    l_rec.limit_rows       := p_limit_rows;
    l_rec.extra_info       := p_extra_info;
    l_rec.child_sigs       := p_child_sigs;
    l_rec.include_in_xml   := p_include_in_dx_summary;
    l_rec.version          := p_version;

    -- EBSAF-285 Internal key names must match resulting column names
    l_key := l_rec.extra_info.first;
    while l_key is not null loop
        if l_key like '##%' then
            l_new_key := substr( upper( replace(l_key, '|', '<br>') ), 1, 255);
            if l_new_key <> l_key then
                -- Create a copy of existing key
                l_rec.extra_info(l_new_key) := l_rec.extra_info(l_key);
            end if;
        end if;
        l_key :=  l_rec.extra_info.next(l_key);
    end loop;

    g_signatures(p_sig_id) := l_rec;
EXCEPTION WHEN OTHERS THEN
    print_log('Error in add_signature: '||p_sig_id);
    raise;
END add_signature;


FUNCTION run_stored_sig(p_sig_id varchar2) RETURN VARCHAR2 IS

  l_col_rows COL_LIST_TBL := col_list_tbl();
  l_col_hea  VARCHAR_TBL := varchar_tbl();
  l_sig      signature_rec;
  l_key      VARCHAR2(255);
  l_row_num  NUMBER;
  l_run_res  BOOLEAN;
  l_err_html CLOB;

BEGIN
  -- Get the signature record from the signature table
  BEGIN
    l_sig := g_signatures(p_sig_id);
  EXCEPTION WHEN NO_DATA_FOUND THEN
    print_log('No such signature '||p_sig_id||' error in run_stored_sig');
    return 'E';
  END;
	print_log('Processing signature: '||p_sig_id||' "'||expand_html(l_sig.title)||'"'||' (version '||l_sig.version||')');

  -- Clear FK values if the sig has children
  IF l_sig.child_sigs.count > 0 THEN
    l_key := g_sql_tokens.first;
    WHILE l_key is not null LOOP
      IF l_key like '##$$FK_$$##' THEN
        g_sql_tokens.delete(l_key);
        g_masked_tokens.delete(l_key);  -- EBSAF-275
      END IF;
      l_key := g_sql_tokens.next(l_key);
    END LOOP;
  END IF;

  -- Run SQL
  l_run_res := run_sig_sql(p_sig_id, l_sig.sig_sql, l_col_rows, l_col_hea, l_sig.limit_rows);

  IF (l_run_res) THEN
      -- Evaluate and print
      RETURN process_signature_results(
           p_sig_id,               -- signature id
           l_sig,                  -- Name/title of signature item
           l_col_rows,             -- signature SQL row values
           l_col_hea);             -- signature SQL column names
    ELSE
        -- Print error
        get_sig_partial(
            p_sig_html => l_err_html,
            p_sig_id => p_sig_id,
            p_class_string => replace_chars(g_sec_detail(g_sec_detail.COUNT).name), -- current section name
            p_error_msg => g_errbuf
        );
        print_clob(l_err_html);
        RETURN 'X';
    END IF;
EXCEPTION WHEN OTHERS THEN
  print_log('Error in run_stored_sig procedure for sig_id: '||p_sig_id);
  print_log('Error: '||sqlerrm);
  print_error('PROGRAM ERROR<br>
    Error for sig '||p_sig_id||' '||sqlerrm||'<br>
    See the log file for additional details');
  return 'X';
END run_stored_sig;

--------------------------------------
-- Print argument validation errors --
--------------------------------------

PROCEDURE print_error_args(
  p_message      VARCHAR2 DEFAULT '',
  l_step         VARCHAR2 DEFAULT '')
IS
  l_key   VARCHAR2(255);
BEGIN
    print_log(p_message);
    print_log('Error in validate_parameters at step: ' || l_step);
    dbms_output.put_line('***************************************************************');
    dbms_output.put_line('*** WARNING WARNING WARNING WARNING WARNING WARNING WARNING ***');
    dbms_output.put_line('***************************************************************');
    dbms_output.put_line('*** '||p_message);
    dbms_output.put_line('Parameter Values');
    print_out('<div>');
    print_out('<br>'||p_message);
    print_out('<br>Error in validate_parameters at step: ' || l_step);
    print_out('<br><br><b>Parameter Values:</b><br><ul>');
    l_key := g_parameters.first;
    FOR i IN 1..g_parameters.COUNT LOOP
       dbms_output.put_line(to_char(i) || '. ' || g_parameters(i).pname || ': ' || g_parameters(i).pvalue);
       print_out('<li>' || to_char(i) || '. ' || g_parameters(i).pname || ': ' || g_parameters(i).pvalue || '</li>');
    END LOOP;
    dbms_output.put_line('Error in validate_parameters at step: ' || l_step);
    print_out('</ul>');
    print_out('<br><br><b>Execution Details:</b><br><ul>');
    l_key := g_rep_info.first;
    WHILE l_key IS NOT NULL LOOP
       print_out('<li>' || l_key || ': ' || g_rep_info(l_key) || '</li>');
       l_key := g_rep_info.next(l_key);
    END LOOP;
    print_out('</ul>');
    print_out('</div>');
END print_error_args;


--########################################################################################
--     Beginning of specific code of this ANALYZER
--########################################################################################

----------------------------------------------------------------
--- Validate Parameters                                      ---
----------------------------------------------------------------
PROCEDURE validate_parameters(
            p_schema_owner                 IN VARCHAR2    DEFAULT NULL
           ,p_middle_tier_cpu              IN NUMBER      DEFAULT 1
           ,p_max_output_rows              IN NUMBER      DEFAULT 50
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y')

IS

  l_revision                  VARCHAR2(25);
  l_date_char                 VARCHAR2(30);
  l_instance                  VARCHAR2(255);
  l_apps_version              VARCHAR2(255);
  l_host                      VARCHAR2(255);
  l_full_hostname             VARCHAR2(255);
  l_key                       VARCHAR2(255);
  l_system_function_var       VARCHAR2(2000);
  l_exists_val                VARCHAR2(2000);
  l_index                     NUMBER:=1;
  l_dbversion                 VARCHAR2(255);
  l_db_name                   VARCHAR2(255);
  l_step                      VARCHAR2(10);
  invalid_parameters EXCEPTION;
  invalid_escape EXCEPTION;

----------------------------------------------------------------
-- Analyzer-specific code: Validation Declarations            --
----------------------------------------------------------------
-- Additional Code>  Validation Declaration

l_sum_rows_sales_data		number;
l_sum_rows_mdp_matrix		number;
l_sum_rows_promotion_data	number;
l_concurrent_users		number;
l_app_server_ctas		number;
l_maxdbconnections_derived	number;
l_total_batch_connections	number;
l_min_ctas_cpu_required		number;
l_max_ctas_cpu_required		number;
l_appserver_cpu_required        number;      
l_middle_tier_cpu		number;
l_MIN_APP_SERVER_CORES		number;
l_MAX_APP_SERVER_CORES		number;
l_manual_threads_per_cpu        number;
l_batch_threads_per_cpu         number;
l_pool_threads_per_cpu          number;
l_maxdbconnection_cpu_comp      number;
l_tp_query_run_size_derived     number;
l_maxdbconnection_derived       number;
l_concurrent_uers_now           number;
l_parallel_max_servers          number := 0;
l_parallel_max_servers_min      number := 0;
l_parallel_max_servers_max      number := 0;
l_min_app_server_cores17        number;
l_max_app_server_cores17        number;
l_min_app_server_cores3         number;
l_max_app_server_cores3         number;
l_min_comb_cpu_req              number := 0;
l_max_comb_cpu_req              number := 0;

-- v$parameter
l_cpu_count			varchar2(4);
l_cpu_count_17                  number;
l_cpu_count_3                   number;
l_physical_cpu_count		number;
l_physical_cpu_count_17         number;
l_physical_cpu_count_3          number;

-- for job_queue_processes
l_job_queue_value		varchar2(4000);
l_sales_data_analyzed		number := 0;  -- 0 = no, 1 = yes
l_total_batch_cores		number;
l_concurrent_users_disp		number;
l_SD_INDEX			number;
l_SD_FACTOR			number;
l_MDP_INDEX			number;
l_MDP_FACTOR			number;


-- aps_params
l_tp_update_record_batch_size	number;
l_tp_update_record_manual_size	number;   
l_tp_update_data_manual_size	number;
l_tp_update_data_batch_size	number := 0;   
l_tp_update_table_manual_size	number;
l_tp_update_comb_manual_size	number;
l_tp_update_comb_batch_size	number := 0;
l_tp_update_table_batch_size	number;
l_tp_update_size		number;
l_tp_update_timeout		number;
l_tp_query_run_size		number;
l_tp_query_run_per_user		number := 0;
l_tp_query_run_timeout		number;
l_tp_level_method_size		number;
l_tp_level_method_timeout	number;
l_tp_copy_paste_size		number;
l_manual_java_threads		number;
l_batch_java_threads		number;
l_total_update_pool		number;
l_maxdbconnections		number;
l_maxupdatethreads		number;
l_dbidletimeout			number;
mySql		                VARCHAR2(2048);


---- Worksheet Specific
l_ws_data_comb_block_size	number;
l_worksheet_full_load		number;
l_ct_worksheet_calcSummaryExp	number;
l_ct_uilimitations_maxcells	number;   -- client.uilimitations.maxcells
l_ct_uilimitations_maxcells_ws	number;   -- client.uilimitations.maxcells.ws
l_ct_uilimitations_maxcombs_ws	number;   -- client.uilimitations.maxcombs.ws
l_ct_uilimitations_maxdisk	number;   -- client.uilimitations.maxdiskspace
l_enableworksheetcaching	number;   -- Depends on usage
l_ct_uilimitations_warning	number;   -- client_uilimitations_warning
l_max_worksheet_db_weight	number;

---- BLE Specific
l_blethreadpoolsize		number;
l_bletimeout			number;

--  sys_params
l_dynamic_hint_max_parallel_db	number;

l_gatherstatisticsthreshold	number;
l_min_sales_date		date;
l_max_sales_date		date;
l_maxsalesgen			number;
l_min_fore_sales_date		date;


-- threadpool to tp
-- worksheet to ws
-- worksheet.data.comb.block_size to ws.data.comb.block_size
-- client.worksheet.calcSummaryExpressions to client.ws.calcSummaryExpressions
-- l_client.worksheet.calcSummaryExpressions to l_ct.wsheet.calcSummaryExp
-- l_client.uilimitations.maxcombs.ws to l_ct.uilimitations.maxcombs.ws 
-- l_client.uilimitations.maxdiskspace to l_ct.uilimitations.maxdisk
-- l_client.uilimitations.maxcells.ws to l_ct.uilimitations.maxcells.ws
-- l_client_uilimitations_maxcells to l_ct_uilimitations_maxcells

-- patch gap analysis
--
-- version_details table
l_current_version               VARCHAR2(20);
l_current_build                 VARCHAR2(20);
l_anchor_link                   varchar2(40);
l_anchor_test                   varchar2(40);
--
-- VERSION_DETAILS_HISTORY
l_VERSION                       VARCHAR2(20);
l_BUILD                         VARCHAR2(20);
l_SP                            VARCHAR2(20);
l_UPGRADE_DATE                  DATE;
--
-- 

-- The following are for patch gap analysis
-- The default is 0 (zero) for NOT APPLIED or condition is NOT TRUE
-- 1 (one) is APPLIED or condition is TRUE
-- The DEFAULT is 0 (zero) 
l_1229_30187573_15			number := 0;
l_1229_30187573_17			number := 0;
l_1229_12290397_attn        number := 0;
l_1229_12290401_attn        number := 0;
l_1229_build15_ok               number := 0;
l_7314_17640575_442_ATTN        number := 0;
l_7314_17640575_450_ATTN        number := 0;
l_7314_18048597_450_ATTN        number := 0;
l_7314_BUILD450_OK              number := 0;
l_7315_20415508_528_ATTN        number := 0;
l_7315_18048597_528_ATTN        number := 0;
l_1225_BUILD3_OK                number := 0;
l_1221_BUILD11_OK               number := 0;
l_7315_BUILD5207_OK             number := 0;
l_7315_18048597_5207_ATTN       number := 0;
l_7315_20415508_5207_ATTN       number := 0;
l_12271_BUILD107_OK             number := 0;
l_12271_27128464_ATTN           number := 0;
l_12271_26975832_ATTN           number := 0;
l_1227_27128464_ATTN            number := 0;
l_12263_27278471_ATTN           number := 0;
l_12261_BUILD110_OK             number := 0;
l_1225_BUILD136_OK              number := 0;

l_1227_build19_ok               number := 0;      
l_12263_build311_ok             number := 0;
l_12262_26641148_ok             number := 0;
l_12262_12260323_ok             number := 0;
l_12262_build216_ok             number := 0;
l_12261_build112_ok             number := 0;
l_1226_build35_ok               number := 0;
l_12251_build136_ok             number := 0;
l_12251_sp12250248_attn           number := 0;
l_12251_12250260_attn           number := 0;
l_12225_build3_attn           number := 0;    
l_12241_build117_ok             number := 0;
l_1224_build50_ok               number := 0;
l_1223_build6_ok                number := 0;
l_1222_build11_ok               number := 0;
l_1221_build15_ok               number := 0;
l_1220_build87_ok               number := 0;
l_73152_build5265_ok            number := 0;
l_73152_build5207_ok            number := 0;
l_73151_build5106_ok            number := 0;
l_7315_build528_ok           number := 0;
l_7314_build419_ok              number := 0;
l_73144_BUILD450_OK             number := 0;
l_1226_bld35_ok           number := 0;      

l_12271_12270326_ATTN    number := 0;

L_1226_27278471_ATTN           number := 0;
L_1226_12260250_ATTN           number := 0;
l_12251_27320973_attn           number := 0;
l_7315_18048597_attn           number := 0;
l_7315_20415508_attn           number := 0;
l_7314_18048597_attn           number := 0;

l_12262_bld216_attn           number := 0;    
l_12261_bld112_attn           number := 0;    
l_12251_sp12250168_attn           number := 0;
l_12262_26798382_attn           number := 0;  
l_12262_26641148_attn           number := 0;  
l_12261_25403411_attn           number := 0;  
l_12261_25332178_attn           number := 0;  
l_12261_25332178_bld110_attn           number := 0; 
l_1226_25332169_attn           number := 0;   
l_1226_24710302_attn           number := 0;   
l_1226_24710302_bld34_attn           number := 0;
l_12251_22254051_attn           number := 0;  
l_12251_26663751_attn           number := 0;  
l_12251_26305727_attn           number := 0;  
l_12251_23059980_attn           number := 0;  
l_12251_23088083_attn           number := 0;  
l_12251_21094268_attn           number := 0;  
l_12251_21959406_attn           number := 0;  
l_12251_12250139_attn           number := 0;   
l_1224_19945449_attn           number := 0;   
l_1224_18139794_attn           number := 0;   
l_1223_18080391_attn           number := 0;   
l_1223_18040010_attn           number := 0;   
l_12263_18139794_attn           number := 0;  
l_12262_18139794_attn           number := 0;  
l_1226_18139794_attn           number := 0;   
l_12251_18139794_attn           number := 0;  
l_1225_18139794_attn           number := 0;   
l_12241_18139794_attn           number := 0;  
l_1223_18139794_attn           number := 0;   
l_1222_18139794_attn           number := 0;   
l_1221_18139794_attn           number := 0;   
l_122_18139794_attn           number := 0;    
l_7315_18067048_attn           number := 0;   
l_7315_17232259_5265_attn           number := 0;
l_7315_17232259_5207_attn           number := 0;
l_7315_17232259_5106_attn           number := 0;
l_7315_17232259_528_attn           number := 0; 
l_73144_17261893_attn           number := 0;  
l_73143_17261893_attn           number := 0;  
l_12263_bld311_attn           number := 0;    
l_1220_13930627_attn           number := 0;  
l_1220_17024161_attn           number := 0;  

l_1220_17808535_attn           number := 0;
l_1220_18638749_attn           number := 0;
l_1220_20211773_attn           number := 0;
l_1220_20429760_attn           number := 0;
l_1220_20613106_attn           number := 0;
l_1220_21089579_attn           number := 0;
l_1220_22018502_attn           number := 0;
l_1220_24935262_attn           number := 0;
l_1220_25506270_attn           number := 0;
l_1220_25634269_attn           number := 0;
l_1220_26981675_attn           number := 0;
l_1221_13930627_attn           number := 0;
l_1221_17024161_attn           number := 0;

l_1221_17808535_attn           number := 0;
l_1221_18638749_attn           number := 0;
l_1221_20211773_attn           number := 0;
l_1221_20429760_attn           number := 0;
l_1221_20613106_attn           number := 0;
l_1221_21089579_attn           number := 0;
l_1221_22018502_attn           number := 0;
l_1221_22275972_attn           number := 0;
l_1221_24935262_attn           number := 0;
l_1221_25103402_attn           number := 0;
l_1221_25506270_attn           number := 0;
l_1221_25634269_attn           number := 0;
l_1221_26981675_attn           number := 0;
l_1222_13930627_attn           number := 0;
l_1222_17024161_attn           number := 0;
l_1222_17808535_attn           number := 0;
l_1222_18638749_attn           number := 0;
l_1222_20211773_attn           number := 0;
l_1222_20429760_attn           number := 0;
l_1222_20613106_attn           number := 0;
l_1222_21089579_attn           number := 0;
l_1222_22018502_attn           number := 0;
l_1222_22275972_attn           number := 0;
l_1222_24935262_attn           number := 0;
l_1222_25103402_attn           number := 0;
l_1222_25506270_attn           number := 0;
l_1222_25634269_attn           number := 0;
l_1222_26981675_attn           number := 0;
l_1223_13930627_attn           number := 0;
l_1223_17024161_attn           number := 0;

l_1223_17808535_attn           number := 0;
l_1223_18638749_attn           number := 0;
l_1223_20211773_attn           number := 0;
l_1223_20429760_attn           number := 0;
l_1223_20613106_attn           number := 0;
l_1223_21089579_attn           number := 0;
l_1223_22018502_attn           number := 0;
l_1223_22275972_attn           number := 0;
l_1223_24935262_attn           number := 0;
l_1223_25103402_attn           number := 0;
l_1223_25506270_attn           number := 0;
l_1223_25634269_attn           number := 0;
l_1223_26981675_attn           number := 0;
l_12241_13930627_attn           number := 0;
l_12241_17024161_attn           number := 0;
l_12241_17808535_attn           number := 0;
l_12241_18638749_attn           number := 0;
l_12241_20174176_attn           number := 0;
l_12241_20211773_attn           number := 0;
l_12241_20429760_attn           number := 0;
l_12241_20613106_attn           number := 0;
l_12241_21089579_attn           number := 0;
l_12241_22018502_attn           number := 0;
l_12241_22275972_attn           number := 0;
l_12241_24935262_attn           number := 0;
l_12241_25506270_attn           number := 0;
l_12241_25634269_attn           number := 0;
l_12241_25739519_attn           number := 0;
l_12241_26981675_attn           number := 0;
l_1224_13930627_attn           number := 0;
l_1224_17024161_attn           number := 0;

l_1224_17808535_attn           number := 0;
l_1224_18638749_attn           number := 0;
l_1224_19550595_attn           number := 0;
l_1224_20174176_attn           number := 0;
l_1224_20211773_attn           number := 0;
l_1224_20429760_attn           number := 0;
l_1224_20613106_attn           number := 0;
l_1224_21089579_attn           number := 0;
l_1224_22018502_attn           number := 0;
l_1224_22275972_attn           number := 0;
l_1224_24935262_attn           number := 0;
l_1224_25506270_attn           number := 0;
l_1224_25634269_attn           number := 0;
l_1224_26981675_attn           number := 0;
l_12251_13930627_attn           number := 0;
l_12251_17024161_attn           number := 0;
l_12251_17808535_attn           number := 0;
l_12251_18638749_attn           number := 0;
l_12251_20211773_attn           number := 0;
l_12251_20429760_attn           number := 0;
l_12251_20613106_attn           number := 0;
l_12251_21089579_attn           number := 0;
l_12251_22018502_attn           number := 0;
l_12251_22275972_attn           number := 0;
l_12251_24935262_attn           number := 0;
l_12251_25506270_attn           number := 0;
l_12251_25634269_attn           number := 0;
l_12251_26981675_attn           number := 0;

L_12251_12250168_ATTN          number := 0;

l_1225_13930627_attn           number := 0;
l_1225_17024161_attn           number := 0;
l_1225_17808535_attn           number := 0;
l_1225_18638749_attn           number := 0;
l_1225_20211773_attn           number := 0;
l_1225_20429760_attn           number := 0;
l_1225_20613106_attn           number := 0;
l_1225_21089579_attn           number := 0;
l_1225_22018502_attn           number := 0;
l_1225_22275972_attn           number := 0;
l_1225_24935262_attn           number := 0;
l_1225_25506270_attn           number := 0;
l_1225_25634269_attn           number := 0;
l_1225_26981675_attn           number := 0;
l_12261_13930627_attn           number := 0;
l_12261_17024161_attn           number := 0;
l_12261_17808535_attn           number := 0;
l_12261_18139794_attn           number := 0;
l_12261_18638749_attn           number := 0;
l_12261_20211773_attn           number := 0;
l_12261_20429760_attn           number := 0;
l_12261_20613106_attn           number := 0;
l_12261_21089579_attn           number := 0;
l_12261_22018502_attn           number := 0;
l_12261_22275972_attn           number := 0;
l_12261_24935262_attn           number := 0;
l_12261_25506270_attn           number := 0;
l_12261_25634269_attn           number := 0;
l_12261_26981675_attn           number := 0;
l_12262_12260323_attn           number := 0;
l_12262_13930627_attn           number := 0;
l_12262_17024161_attn           number := 0;
l_12262_17808535_attn           number := 0;
l_12262_18638749_attn           number := 0;
l_12262_20211773_attn           number := 0;
l_12262_20429760_attn           number := 0;
l_12262_20613106_attn           number := 0;
l_12262_21089579_attn           number := 0;
l_12262_22018502_attn           number := 0;
l_12262_22275972_attn           number := 0;
l_12262_24935262_attn           number := 0;
l_12262_25506270_attn           number := 0;
l_12262_25634269_attn           number := 0;
l_12262_26981675_attn           number := 0;
l_12263_13930627_attn           number := 0;
l_12263_17024161_attn           number := 0;
l_12263_17808535_attn           number := 0;
l_12263_18638749_attn           number := 0;
l_12263_20211773_attn           number := 0;
l_12263_20429760_attn           number := 0;
l_12263_20613106_attn           number := 0;
l_12263_21089579_attn           number := 0;
l_12263_22018502_attn           number := 0;
l_12263_22275972_attn           number := 0;
l_12263_24935262_attn           number := 0;
l_12263_25506270_attn           number := 0;
l_12263_25634269_attn           number := 0;
l_12263_26981675_attn           number := 0;
l_1226_13930627_attn           number := 0;
l_1226_17024161_attn           number := 0;
l_1226_17808535_attn           number := 0;
l_1226_18638749_attn           number := 0;
l_1226_20211773_attn           number := 0;
l_1226_20429760_attn           number := 0;
l_1226_20613106_attn           number := 0;
l_1226_21089579_attn           number := 0;
l_1226_22018502_attn           number := 0;
l_1226_22275972_attn           number := 0;
l_1226_24935262_attn           number := 0;
l_1226_25506270_attn           number := 0;
l_1226_25634269_attn           number := 0;
l_1226_26981675_attn           number := 0;
l_1227_13930627_attn           number := 0;
l_1227_17024161_attn           number := 0;
l_1227_17808535_attn           number := 0;
l_1227_18638749_attn           number := 0;
l_1227_20211773_attn           number := 0;
l_1227_20429760_attn           number := 0;
l_1227_20613106_attn           number := 0;
l_1227_21089579_attn           number := 0;
l_1227_22018502_attn           number := 0;
l_1227_24935262_attn           number := 0;
l_1227_25506270_attn           number := 0;
l_1227_25634269_attn           number := 0;
l_1227_26975832_attn           number := 0;
l_1227_26981675_attn           number := 0;
l_122_22275972_attn           number := 0;
l_73143_13930627_442_attn           number := 0;
l_73143_17024161_442_attn           number := 0;

l_73143_17808535_442_attn           number := 0;
l_73143_18638749_442_attn           number := 0;
l_73143_20211773_442_attn           number := 0;
l_73143_20429760_442_attn           number := 0;
l_73143_20613106_442_attn           number := 0;
l_73143_21089579_442_attn           number := 0;
l_73143_22018502_442_attn           number := 0;
l_73143_24935262_442_attn           number := 0;
l_73143_25506270_attn           number := 0;
l_73143_25634269_442_attn           number := 0;
l_73143_26981675_attn           number := 0;
l_73144_13930627_450_attn           number := 0;
l_73144_17024161_450_attn           number := 0;
l_73144_17808535_450_attn           number := 0;
l_73144_18638749_450_attn           number := 0;
l_73144_20211773_450_attn           number := 0;
l_73144_20429760_450_attn           number := 0;
l_73144_20613106_450_attn           number := 0;
l_73144_21089579_450_attn           number := 0;
l_73144_22018502_450_attn           number := 0;
l_73144_24935262_450_attn           number := 0;
l_73144_25506270_attn           number := 0;
l_73144_25634269_450_attn           number := 0;
l_73144_26981675_attn           number := 0;
l_7315_13930627_5106_attn           number := 0;
l_7315_13930627_5207_attn           number := 0;
l_7315_13930627_5265_attn           number := 0;
l_7315_13930627_528_attn           number := 0;
l_7315_17024161_5106_attn           number := 0;
l_7315_17024161_5207_attn           number := 0;
l_7315_17024161_5265_attn           number := 0;
l_7315_17024161_528_attn           number := 0;

l_7315_17640575_5106_attn           number := 0;
l_7315_17640575_5207_attn           number := 0;
l_7315_17640575_5265_attn           number := 0;
l_7315_17640575_528_attn           number := 0;
l_7315_17640575_attn           number := 0;
l_7314_17640575_attn           number := 0;
l_1220_17640575_attn           number := 0;
l_1221_17640575_attn           number := 0;
l_1222_17640575_attn           number := 0;

l_7315_17808535_5106_attn           number := 0;
l_7315_17808535_5207_attn           number := 0;
l_7315_17808535_5265_attn           number := 0;
l_7315_17808535_528_attn           number := 0;
l_7315_18638749_5106_attn           number := 0;
l_7315_18638749_5207_attn           number := 0;
l_7315_18638749_5265_attn           number := 0;
l_7315_18638749_528_attn           number := 0;
l_7315_20174176_5106_attn           number := 0;
l_7315_20174176_5207_attn           number := 0;
l_7315_20174176_5265_attn           number := 0;
l_7315_20174176_528_attn           number := 0;
l_7315_20211773_5106_attn           number := 0;
l_7315_20211773_5207_attn           number := 0;
l_7315_20211773_5265_attn           number := 0;
l_7315_20211773_528_attn           number := 0;
l_7315_20429760_5106_attn           number := 0;
l_7315_20429760_5207_attn           number := 0;
l_7315_20429760_5265_attn           number := 0;
l_7315_20429760_528_attn           number := 0;
l_7315_20613106_5106_attn           number := 0;
l_7315_20613106_5207_attn           number := 0;
l_7315_20613106_5265_attn           number := 0;
l_7315_20613106_528_attn           number := 0;
l_7315_21089579_5106_attn           number := 0;
l_7315_21089579_5207_attn           number := 0;
l_7315_21089579_5265_attn           number := 0;
l_7315_21089579_528_attn           number := 0;
l_7315_22018502_5106_attn           number := 0;
l_7315_22018502_5207_attn           number := 0;
l_7315_22018502_5265_attn           number := 0;
l_7315_22018502_528_attn           number := 0;
l_7315_24935262_5106_attn           number := 0;
l_7315_24935262_5207_attn           number := 0;
l_7315_24935262_5265_attn           number := 0;
l_7315_24935262_528_attn           number := 0;
l_7315_25103402_5207_attn           number := 0;
l_7315_25634269_5106_attn           number := 0;
l_7315_25634269_5207_attn           number := 0;
l_7315_25634269_5265_attn           number := 0;
l_7315_25634269_528_attn           number := 0;
l_7315_5106_25506270_attn           number := 0;
l_7315_5106_26981675_attn           number := 0;
l_7315_5207_25506270_attn           number := 0;
l_7315_5207_26981675_attn           number := 0;
l_7315_5265_25506270_attn           number := 0;
l_7315_5265_26981675_attn           number := 0;
l_7315_528_25506270_attn           number := 0;
l_7315_528_26981675_attn           number := 0;
l_12225_build3_ok                  number := 0;
l_12251_sp12250168_ok              number := 0;
l_12263_25420760_attn              number := 0;
l_12262_25420760_attn              number := 0;
l_12261_25420760_attn              number := 0;
l_1226_25420760_attn              number := 0;
L_12251_26985862_ATTN              number := 0;
l_1225_22254051_attn               number := 0;
l_73144_26981675_450_ATTN          number := 0;
l_73143_26981675_442_ATTN          number := 0;
L_7315_26981675_528_ATTN           number := 0;
l_7315_26981675_5265_attn          number := 0;
l_7315_26981675_5207_attn          number := 0;
l_7315_26981675_5106_attn          number := 0;
l_7315_18067048_5265_attn          number := 0;
l_7315_18067048_5207_attn          number := 0;
l_7315_18067048_5106_attn          number := 0;
l_7315_18067048_528_attn          number := 0;
l_7315_7315238_5265_ATTN          number := 0;
l_7315_7315238_5207_ATTN          number := 0;
l_7315_7315238_5106_ATTN          number := 0;
L_7315_7315238_528_ATTN           number := 0;


-- APPSERVERURL

-- URL and ACL configuration verification
--

l_appserverurl    	varchar2(100);
l_protocol		varchar2(5);
l_slash			varchar2(2);
l_port1        		varchar2(5);
l_port2        		NUMBER := 0;
l_rest			varchar2(100);
L_HOST_NAME		varchar2(100);
l_EngineBaseURL		varchar2(100);
l_apps_version_max	varchar2(20);
l_appsurl_upgrade_date		date;
l_eng_appserverurl	varchar2(100);
l_eng_protocol		varchar2(5);
l_eng_slash		varchar2(2);
l_eng_host_name		varchar2(100);
l_eng_port1		varchar2(5);
l_eng_rest		varchar2(100);
l_eng_platform		varchar2(100);
l_MSD_DEM_PROFILE_PROTOCOL	varchar2(5);


l_appserverurl_stripped	varchar2(100);
l_appserverurl_https	varchar2(10);
L_APPSERVERURL_FINAL	varchar2(100);
L_MSD_DEM_HTTP		VARCHAR2(240);
l_privilege   		VARCHAR2(20);
l_denied               	BOOLEAN := FALSE;
l_granted              	BOOLEAN := FALSE;
l_input_acl            	VARCHAR2(500);
l_create_acl           	BOOLEAN := FALSE;
l_add_privilege        	BOOLEAN := FALSE; 
l_assign_acl           	BOOLEAN := FALSE;
l_user_exist          	INTEGER;
l_engine_platform 	VARCHAR2(50);
l_acl_name 		VARCHAR2(240);
l_acl_type		VARCHAR2(240);
l_cursor_sql      	VARCHAR2(4000);
l_sql         		VARCHAR2(8000);
l_server      		VARCHAR2(2000);
l_err_msg     		VARCHAR2(1000);
l_acl         		VARCHAR2(500) := null;
l_oracle_ver  		VARCHAR2(100);
l_user_name   		VARCHAR2(50);
l_input_user  		VARCHAR2(50);
l_acl_count   		INTEGER;

-- end





BEGIN

  l_step := '1';

  print_log(analyzer_title || ' Log File');
  print_log('***************************************************************');

  -- Create global hash for parameters. Numbers required for the output order
debug('begin populate parameters hash table');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Schema Owner';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_schema_owner,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Middle Tier CPUs (extrapolated)';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_middle_tier_cpu,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Maximum Rows to Display';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_max_output_rows,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Debug Mode';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_debug_mode,'NO_MASK');
debug('end populate parameters hash table');



  l_key := g_parameters.first;
  -- Print parameters to the log
  print_log(chr(10)||'Parameter Values before validation:');
  print_log('---------------------------');

  FOR i IN 1..g_parameters.COUNT LOOP
    print_log(to_char(i) || '. ' || g_parameters(i).pname || ': ' || g_parameters(i).pvalue);
  END LOOP;
  print_log('---------------------------');

  BEGIN

    SELECT max(release_name) INTO l_apps_version
    FROM fnd_product_groups;

    begin
        -- Try to get version using new 19c method
        execute immediate 'select instance_name, host_name, version_full, sys_context(''USERENV'',''DB_NAME'') FROM v$instance'
            into l_instance, l_host, l_dbversion, l_db_name;
    exception when others then
        -- Get version using old method
        SELECT instance_name, host_name, version, sys_context('USERENV','DB_NAME')
        INTO l_instance, l_host, l_dbversion, l_db_name
        FROM v$instance;
    end;
    l_host := nvl(l_host, sys_context('USERENV','SERVER_HOST'));
    l_instance := nvl(l_instance, sys_context('USERENV','INSTANCE_NAME'));

  EXCEPTION WHEN OTHERS THEN
    print_log('Error in validate_parameters gathering instance information: '
      ||sqlerrm);
    raise;
  END;

  l_step := '2';
  BEGIN
    SELECT distinct domain
    INTO l_full_hostname
    FROM (SELECT db_domain AS domain
            FROM fnd_databases
          UNION ALL
          SELECT domain AS domain
          FROM fnd_nodes) domains WHERE domains.domain IS NOT NULL and rownum = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_full_hostname := NULL;
        WHEN OTHERS    THEN
          print_log('Error in validate_parameters gathering instance information: '
          ||sqlerrm);
    END;

  l_step := '3';
-- Revision and date values can be populated by RCS
  l_revision := rtrim(replace('$Revision: 200.82  $','$',''));
  l_revision := ltrim(replace(l_revision,'Revision:',''));
  l_date_char := rtrim(replace('$Date: 2026/01/28 14:33:30 $','$',''));
  l_date_char := ltrim(replace(l_date_char,'Date:',''));
  l_date_char := to_char(to_date(l_date_char,'YYYY/MM/DD HH24:MI:SS'),'DD-MON-YYYY');

  l_step := '4';
-- Create global hash for mapping internal result codes (E, W, S, I) to user friendly result codes (error, warning, successful, information)
  g_result('E') := 'error';
  g_result('W') := 'warning';
  g_result('S') := 'success';
  g_result('I') := 'info';

  l_step := '5';
-- Create global hash for report information
-- Do not report host details (EBSAF-274); reverted by EBSAF-293
  g_rep_info('Host') := regexp_substr(l_host, '^[^.]+');
  -- the host name might already be fully qualified, need to check if it includes the domain before appending it
  IF (l_host LIKE '%.%') THEN
       g_rep_info('FullHost') := l_host;
  ELSE
       g_rep_info('FullHost') := l_host || '.' || l_full_hostname;
  END IF;
  l_step := '6';
  g_rep_info('Instance') := l_instance;
  g_rep_info('DB Name') := l_db_name;
  g_rep_info('DB Version') := l_dbversion;
  g_rep_info('Apps Version') := l_apps_version;
  g_rep_info('File Name') := 'demantra_configuration_analyzer.sql';
  g_rep_info('File Version') := l_revision;
  g_rep_info('Framework Version') := RTRIM(g_framework_version, ' ');
  g_rep_info('Execution Date') := to_char(sysdate,'DD-MON-YYYY HH24:MI:SS');
  g_rep_info('Description') := ('The ' || analyzer_title || ' <a href="' || g_cmos_km_url || g_analyzer_doc_id||'" target="_blank">(Note '||g_analyzer_doc_id||')</a> is a self-service health-check script that reviews the overall footprint, analyzes current configurations and settings for the environment and provides feedback and recommendations on best practices. Your application data is not altered in any way when you run this analyzer.');

  l_step := '7';
  IF (g_is_concurrent) THEN
     populate_user_details();
  END IF;

  ------------------------------------------------------------------------------
  -- NOTE: Add code here for validation to the parameters of your diagnostic
  ------------------------------------------------------------------------------
  l_step := '8';


  g_max_output_rows := nvl(p_max_output_rows,20);
  g_debug_mode := nvl(p_debug_mode, 'Y');

debug('begin parameter validation: p_schema_owner');
IF p_schema_owner IS NULL THEN
   print_error('INVALID ARGUMENT: Parameter Schema Owner is required.');
   raise invalid_parameters;
END IF;
IF p_schema_owner IS NOT NULL THEN
BEGIN
SELECT OWNER
INTO l_exists_val
FROM DBA_TABLES
WHERE OWNER = p_schema_owner
 AND table_name = 'SALES_DATA'
 and rownum < 2;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
   print_error('INVALID ARGUMENT: There is no SALES_DATA table in DBA_TABLES or you do not have privileges.');
   raise invalid_parameters;
   WHEN OTHERS THEN
   print_error('INVALID ARGUMENT: Validation query for p_schema_owner failed with '||sqlerrm||'.');
   raise invalid_parameters;
END;
END IF;
debug('end parameter validation: p_schema_owner');

debug('begin parameter validation: p_middle_tier_cpu');
IF p_middle_tier_cpu IS NULL THEN
   print_error('INVALID ARGUMENT: Parameter Middle Tier CPUs (extrapolated) is required.');
   raise invalid_parameters;
END IF;
debug('end parameter validation: p_middle_tier_cpu');


debug('begin parameter validation: p_debug_mode');
IF p_debug_mode IS NOT NULL AND p_debug_mode NOT IN ( 'N','Y') THEN
   print_error('INVALID ARGUMENT: Debug Mode is invalid.  Valid values are Y or N');
   raise invalid_parameters;
END IF;
debug('end parameter validation: p_debug_mode');



-- Validation to verify analyzer is run on proper e-Business application version
-- In case validation at the beginning is updated/removed, adding validation here also so execution fails

  IF substr(l_apps_version,1,4) NOT IN ('11.5','12.0','12.1','12.2') THEN
    print_log('eBusiness Suite version = '||l_apps_version);
    print_log('ERROR: This Analyzer script is compatible for following version(s): 11i,12.0,12.1,12.2');
    raise invalid_parameters;
  END IF;

-- .log enhancements (ER # 140)
  print_log(chr(10)||'Instance Information:');
  print_log('---------------------------');
  -- Do not report host details (EBSAF-274); reverted by EBSAF-293
  print_log('Host: '||g_rep_info('Host'));
  print_log('FullHost: '||g_rep_info('FullHost'));
  print_log('Instance: '||g_rep_info('Instance'));
  print_log('Database name: '||g_rep_info('DB Name'));
  print_log('Database version: '||g_rep_info('DB Version'));
  print_log('Applications version: '||g_rep_info('Apps Version'));
  print_log('Analyzer version: '||g_rep_info('File Version'));
  -- Report call details for troubleshooting (EBSAF-265)
  print_log('Calling method: '||g_rep_info('Calling From') );
  print_log('Calling module: '||g_rep_info('Calling Module') );
  print_log('---------------------------');

  -- Log session details (EBSAF-308)
  l_step := '8.5';
  print_log(chr(10)||'Session Information:');
  print_log('---------------------------');
  print_log('Language Code: '||sys_context('USERENV', 'LANG'));
  print_log('Region: '||sys_context('USERENV', 'NLS_TERRITORY'));
  print_log('Locale: '||sys_context('USERENV', 'LANGUAGE'));
  print_log('Date Format: '||sys_context('USERENV', 'NLS_DATE_FORMAT'));
  -- Get number characters
  select max(value) into l_system_function_var from v$parameter where name = 'nls_numeric_characters';
  print_log('Number Characters: '||l_system_function_var);
  -- Check for language installation
  begin
    execute immediate 'select max(installed_flag) from FND_LANGUAGES where language_code = sys_context(''USERENV'', ''LANG'')' into l_system_function_var;
    if (l_system_function_var is null or l_system_function_var not in ('B', 'I')) then
      print_log('WARNING: FND_LANGUAGES shows the session language is not installed.');
      print_log('Signatures relying on translation information may have incorrect results.');
    end if;
  exception when others then
    print_log('WARNING: Failed to check FND_LANGUAGES if session language is installed.');
  end;
  print_log('---------------------------');

  -- Verify escape character is set properly (EBSAF-265)
  l_step := '9';
  IF regexp_replace('Replace Test', '\s', '*') <>
     regexp_replace('Replace Test', chr(92) || 's', '*') THEN
    print_log('Invalid Escape:  Expected "' || chr(92) || 's' ||'" Received "\s"');
    print_log('Backslash character was not escaped properly during installation or execution.');
    raise invalid_escape;
  END IF;

  l_step := '10';
----------------------------------------------------------------
-- Analyzer-specific code: Additional Validation              --
----------------------------------------------------------------
debug('begin Additional Code: Additional Validation');
print_log('p_schema_owner = '||p_schema_owner);

g_schema_owner := p_schema_owner;

print_log('in additional validation g_schema_owner = '||g_schema_owner);

select value * 3
into l_cpu_count
from v$parameter
where lower(name) = 'cpu_count';

select to_number(value)
into l_physical_cpu_count
from v$parameter
where lower(name) = 'cpu_count';

select round(to_number(value) * 1.7)
into l_physical_cpu_count_17
from v$parameter
where lower(name) = 'cpu_count';

select to_number(value) * 3
into l_physical_cpu_count_3
from v$parameter
where lower(name) = 'cpu_count';

select round(l_cpu_count * 1.7)
into l_cpu_count_17
from dual;

select l_cpu_count * 3
into l_cpu_count_3
from dual;

select value
into l_parallel_max_servers
from v$parameter
where lower(name) = 'parallel_max_servers';

select l_cpu_count * 2
into l_parallel_max_servers_min
from dual;

select l_cpu_count * 4
into l_parallel_max_servers_max
from dual;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''maxdbconnections''';
EXECUTE immediate mySql
into l_maxdbconnections;

select round((l_maxdbconnections / 3),0)
into l_maxdbconnection_cpu_comp
from dual;
-- using 3 threads per CPU.  max / 3 used to give max CPU comparison

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.update.record.batch.size''';
EXECUTE immediate mySql
into l_tp_update_record_batch_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.update.record.manual.size''';
EXECUTE immediate mySql
into l_tp_update_record_manual_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.update.data.manual.size''';
EXECUTE immediate mySql
into l_tp_update_data_manual_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params
where lower(pname) = ''threadpool.update.data.batch.size''';
EXECUTE immediate mySql
into l_tp_update_data_batch_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.update.table.manual.size''';
EXECUTE immediate mySql
into l_tp_update_table_manual_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.update.comb.manual.size''';
EXECUTE immediate mySql
into l_tp_update_comb_manual_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.update.comb.batch.size''';
EXECUTE immediate mySql
into l_tp_update_comb_batch_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.update.table.batch.size''';
EXECUTE immediate mySql
into l_tp_update_table_batch_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.update.timeout''';
EXECUTE immediate mySql
into l_tp_update_timeout;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.query_run.size''';
EXECUTE immediate mySql
into l_tp_query_run_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.query_run.per_user''';
EXECUTE immediate mySql
into l_tp_query_run_per_user;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.query_run.timeout''';
EXECUTE immediate mySql
into l_tp_query_run_timeout;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.level_method.size''';
EXECUTE immediate mySql
into l_tp_level_method_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.level_method.timeout''';
EXECUTE immediate mySql
into l_tp_level_method_timeout;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''threadpool.copy_paste.size''';
EXECUTE immediate mySql
into l_tp_copy_paste_size;

mySql := ' 
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''maxupdatethreads''';
EXECUTE immediate mySql
into l_maxupdatethreads;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''dbidletimeout''';
EXECUTE immediate mySql
into l_dbidletimeout;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''worksheet.data.comb.block_size''';
EXECUTE immediate mySql
into l_ws_data_comb_block_size;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''client.worksheet.calcsummaryexpressions''';
EXECUTE immediate mySql
into l_ct_worksheet_calcsummaryexp;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''client.uilimitations.maxcells''';
EXECUTE immediate mySql
into l_ct_uilimitations_maxcells;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''client.uilimitations.maxcells.ws''';
EXECUTE immediate mySql
into l_ct_uilimitations_maxcells_ws;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''client.uilimitations.maxcombs.ws''';
EXECUTE immediate mySql
into l_ct_uilimitations_maxcombs_ws;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''client.uilimitations.maxdiskspace''';
EXECUTE immediate mySql
into l_ct_uilimitations_maxdisk;

mySql := '  
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''client.uilimitations.warning''';
EXECUTE immediate mySql
into l_ct_uilimitations_warning;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''max.worksheet.db.weight''';
EXECUTE immediate mySql
into l_max_worksheet_db_weight;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''blethreadpoolsize''';
EXECUTE immediate mySql
into l_blethreadpoolsize;

mySql := '
Select decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) 
from '||p_schema_owner||'.aps_params 
where lower(pname) = ''blethreadtimeout''';
EXECUTE immediate mySql
into l_bletimeOut;


-- below building the java thread requirement  for the middle tier user/worksheet operations
select l_tp_update_data_manual_size + (l_tp_update_data_manual_size * l_tp_update_table_manual_size) + (l_tp_update_data_manual_size * l_tp_update_table_manual_size * l_tp_update_comb_manual_size) + (l_tp_update_data_manual_size * l_tp_update_table_manual_size * l_tp_update_comb_manual_size * l_tp_update_record_manual_size)
into l_manual_java_threads
from dual;

-- below building the java thread requirement  for the middle tier batch forecast operations
select l_tp_update_data_batch_size + (l_tp_update_data_batch_size * l_tp_update_table_batch_size) +
(l_tp_update_data_batch_size * l_tp_update_table_batch_size * l_tp_update_comb_batch_size) + 
(l_tp_update_data_batch_size * l_tp_update_table_batch_size * l_tp_update_comb_batch_size * l_tp_update_record_batch_size)
into l_batch_java_threads
from dual;

select l_manual_java_threads + l_batch_java_threads 
into l_total_update_pool
from dual;

-- this is not for the db connections
-- CPU required based on the possible connections per user

IF l_tp_query_run_per_user <5 THEN
  select l_tp_query_run_size / l_tp_query_run_per_user
  into l_appserver_cpu_required
  from dual;
ELSE
  select (l_tp_query_run_size / l_tp_query_run_per_user) + 4
  into l_appserver_cpu_required
  from dual;
END IF;


select round((l_manual_java_threads / l_appserver_cpu_required),2) 
into l_manual_threads_per_cpu
from dual;

select round((l_batch_java_threads / l_appserver_cpu_required),2)
into l_batch_threads_per_cpu
from dual;

select round((l_total_update_pool / l_appserver_cpu_required), 2)
into l_pool_threads_per_cpu
from dual;

-- this is for combinations * batch size CTAS requirement
select round((l_tp_update_comb_batch_size * l_tp_update_data_batch_size),2)
into l_app_server_ctas
from dual; 

-- the following presents the CPU requirement based on parameter and CPU type: 
-- single, dual, multi core

select l_app_server_ctas
into l_max_app_server_cores
from dual;

select l_tp_update_comb_batch_size
into l_min_app_server_cores
from dual;

select l_tp_update_comb_batch_size * 1.7
into l_min_app_server_cores17
from dual;

select l_app_server_ctas * 1.7
into l_max_app_server_cores17
from dual;

select l_tp_update_comb_batch_size * 3
into l_min_app_server_cores3
from dual;

select l_app_server_ctas * 3
into l_max_app_server_cores3
from dual;

-- Concurrent users ceiling can be derived by:
select round((l_tp_query_run_size / l_tp_query_run_per_user),0)
into l_concurrent_users
from dual;


-- maxdbconnections recommended 10 * concurrent users
select 10 * l_concurrent_users
into l_concurrent_users_disp
from dual;

-- threadpool_query.run_size is 
select l_concurrent_users * l_tp_query_run_per_user
into l_tp_query_run_size_derived
from dual;


IF l_tp_query_run_per_user > 4 THEN

 select (l_concurrent_users * l_tp_query_run_per_user) + 10
 into l_tp_query_run_size_derived
 from dual;
ELSE

 select (l_concurrent_users * l_tp_query_run_per_user)
 into l_tp_query_run_size_derived
 from dual;

END IF;

-- The following two are used in Parameter Driven Hardware Requirements

select l_tp_update_comb_batch_size * 1.5
into l_min_comb_cpu_req
from dual; 

select (l_tp_update_comb_batch_size * l_tp_update_data_batch_size) * 1.7
into l_max_comb_cpu_req
from dual;
-------------------------------------------------------------------------------------------------------------------------------
--
-- Before the load of version_details, verify that the row exists in version_details_history
--

mySql := '
Select version
from '||p_schema_owner||'.version_details';
EXECUTE immediate mySql
into l_current_version;

mySql := '
Select build
from '||p_schema_owner||'.version_details';
EXECUTE immediate mySql
into l_current_build;

l_anchor_link := l_current_version||'_'||l_current_build;
-- the anchor_link is for mos note 2362233.1

print_log('l_current_version = '||l_current_version);
print_log('l_current_build = '||l_current_build);
print_log('l_anchor_link = '||l_anchor_link);

g_current_version               := l_current_version;
g_current_build                 := l_current_build;


IF l_current_version not in ('12.2.11', '12.2.10', '12.2.9', '12.2.7', '12.2.6', '12.2.5', '12.2.4', '12.2.3', '12.2.2', '12.2.1', '12.2.0', '7.3.1') then
mySql := '
select ''2362233.1''
from dual';
EXECUTE immediate mySql
into l_anchor_test;
END IF;



IF l_current_version = '7.3.1' and l_current_build not in ('5207', '5106', '528', '450') then 
mySql := '
select ''2362233.1''
from dual';
EXECUTE immediate mySql
into l_anchor_test;
END IF;

g_anchor_test := l_anchor_test;
print_log('g_anchor_test = '||g_anchor_test);

--
--
-- Create the SQLs for each check according to the master table below.
--

-- maxdbconnections is (concurrent users * query run per user) + 10 if query run per user > 4
-- select decode(l_tp_query_run_per_user, > 4, (l_concurrent_users * l_tp_query_run_per_user) + 10, -- l_concurrent_users * l_tp_query_run_per_user)
-- into l_maxdbconnection_derived
-- from dual;
--------------------------------------------------------
---
-- Populate the globals
---
-- Additional Code>  Validation Declaration

------------------------------
----------------------------------
-- This section verifies a correct install of the reported version in version_details, version and build
--
-- DEMANTRA 12.2.7 RELEASE 21516577
-- The following are for patch gap analysis
-- The default is 0 (zero) for NOT APPLIED or condition is NOT TRUE
-- 1 (one) is APPLIED or condition is TRUE
-- The DEFAULT is 0 (zero) 
 

-- 12.2.7.1 Build 107
-- 27506109 	  	Build 107 	5667 	Base 	Base install.
-- 27128464 	12270334 	  	apps srv 	WEB 	Highly recommended patch. GENERIC 12.2.7 WEB PATCH.
-- 26975832 	12270326 	  	apps srv 	DB 	Highly recommended patch. GENERIC 12.2.7.X DATABASE PLATFORM GENERIC PATCH.

-- 27128464
If l_current_version = '12.2.7' AND l_current_build = '107' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12270334'')
                         and a.sp = ''12270334''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12270334''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12271_27128464_attn;
End IF;

-- 26975832
If l_current_version = '12.2.7' AND l_current_build = '107' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12270326'')
                         and a.sp = ''12270326''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12270326''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12271_26975832_attn;
End IF;


-- 12.2.7 Build 19
-- 26710559 	  	Build 19 	5513 	Base 	Base install.
-- 27128464 	12270334 	  	apps srv 	WEB 	Highly recommended patch. GENERIC 12.2.7 WEB PATCH.
-- 26975832 	12270326 	  	apps srv 	DB 	Highly recommended patch. GENERIC 12.2.7.X DATABASE PLATFORM GENERIC PATCH.


-- 27128464
If l_current_version = '12.2.7' AND l_current_build = '19' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12270334'')
                         and a.sp = ''12270334''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12270334''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1227_27128464_attn;
End IF;

-- 26975832
If l_current_version = '12.2.7' AND l_current_build = '19' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12270326'')
                         and a.sp = ''12270326''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12270326''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1227_26975832_attn;
End IF;


-- 12.2.6.3 Build 311
-- 27209775 	  	Build 311 	5514 	Base 	Base Install.
-- 27278471 	12260340 	  	  	DB 	Highly recommended patch. Generic Patch Web,PB.
-- 25420760 	12260250 	  	  	DB 	Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.

-- 27278471
If l_current_version = '12.2.6' AND l_current_build = '311' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260340'')
                         and a.sp = ''12260340''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260340''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12263_27278471_attn;
End IF;

-- 25420760
If l_current_version = '12.2.6' AND l_current_build = '311' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260250'')
                         and a.sp = ''12260250''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260250''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12263_25420760_attn;
End IF;


-- 12.2.6.2 Build 216
-- 25820351 	  	Build 216 	4956 	Base 	Base Install.
-- 26641148 	12260314 WEB 	Highly recommended patch. GENERIC 12.2.6.2 WEB PATCH.
-- 25420760 	12260250 DB 	Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.
-- 26798382 	12260323 Engine 	Highly recommended patch. FAILED TO BULK LOAD THE BRANCH DIVIDER OUTPUT TO THE DB.


-- 26641148
If l_current_version = '12.2.6' AND l_current_build = '216' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260314'')
                         and a.sp = ''12260314''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260314''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12262_26641148_attn;
End IF;

-- 25420760
If l_current_version = '12.2.6' AND l_current_build = '216' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260250'')
                         and a.sp = ''12260250''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260250''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12262_25420760_attn;
End IF;

-- 26798382
If l_current_version = '12.2.6' AND l_current_build = '216' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260323'')
                         and a.sp = ''12260323''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260323''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12262_26798382_attn;
End IF;

-- 12.2.6.1 Build 112
-- 25168361 	  	Build 112 	4770 	Base 	Base Install. Demanta 12.2.6.1
-- 25403411 	12260251 	  	  	WEB 	Highly recommended patch. INSTALLER FOR THE LOCAL APP THAT SUPPORTS A 32-BIT O/S.
-- 25420760 	12260250 	  	  	DB 	Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.


-- 25403411
If l_current_version = '12.2.6' AND l_current_build = '112' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260251'')
                         and a.sp = ''12260251''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260251''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12261_25403411_attn;
End IF;

-- 25420760
If l_current_version = '12.2.6' AND l_current_build = '112' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260250'')
                         and a.sp = ''12260250''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260250''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12261_25420760_attn;
End IF;


-- 12.2.6 Build 35
-- 24393123 	  	Build 35 	4622 	Base 	Base Install. Demanta 12.2.6
-- 25420760 	12260250 	  	  	DB 	Highly recommended patch. GENERIC 12.2.6.X DATABASE PLATFORM PATCH.
-- 25332169 	12260244 	  	  	WEB 	Highly recommended patch. Local application cannot be installed if jre 1.8.112 is installed.

-- 25420760
If l_current_version = '12.2.6' AND l_current_build = '35' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260250'')
                         and a.sp = ''12260250''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260250''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1226_25420760_attn;
End IF;


-- 25332169
If l_current_version = '12.2.6' AND l_current_build = '35' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12260244'')
                         and a.sp = ''12260244''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12260244''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1226_25332169_attn;
End IF;


-- 12.2.5.1 Build 136
-- 21951481 	  	Build 136 	3825 	Base 	Base Install. Demanta 12.2.5.1
-- 27320973 	12250299 	  	  	WEB 	Highly recommended patch. Latest generic WEB patch. Followed by:
-- 22254051 	12250139 	DB  Highly recommended patch. 12.2.5.X DEMANTRA PERFORMANCE ISSUE ON EP_LOAD - Generic DB patch to apply on Demantra 12.2.5.x only.
-- 26663751 	12250322 	  	  	Engine 	Highly recommended patch. SIMULATION ENGINE IS CRASHING. EVEN AFTER CLEARING QUEUES.

-- 27320973
If l_current_version = '12.2.5' AND l_current_build = '136' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12250299'')
                         and a.sp = ''12250299''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12250299''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12251_27320973_attn;
End IF;

-- 22254051
If l_current_version = '12.2.5' AND l_current_build = '136' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12250139'')
                         and a.sp = ''12250139''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12250139''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12251_22254051_attn;
End IF;

-- 26663751
If l_current_version = '12.2.5' AND l_current_build = '136' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12250322'')
                         and a.sp = ''12250322''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12250322''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12251_26663751_attn;
End IF;

-- <h2 class="km">12.2.4.1 Build 117</h2>
-- 19973580 	  	Build 117 	3307 	Base 	Base Install. DEMANTRA 12.2.4.1
-- 18139794 	12230033 	45+ 	  	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.


-- 18139794
If l_current_version = '12.2.4' AND l_current_build = '117' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12230033'')
                         and a.sp = ''12230033''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12230033''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_12241_18139794_attn;
End IF;




-- <h2 class="km">12.2.4 Build 50</h2>
-- 19361678 	  	Build 50 	Base 	Base Install. DEMANTRA 12.2.4
-- 18139794 	12230033 	45+ 	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.

-- 18139794
If l_current_version = '12.2.4' AND l_current_build = '50' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12230033'')
                         and a.sp = ''12230033''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12230033''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1224_18139794_attn;
End IF;





-- <h2 class="km">12.2.3 Build 6</h2>
-- 17921238 	  	Build 6 	Base 	Base Install. DEMANTRA 12.2.3
-- 18139794 	12230033 	45+   	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.

-- 18139794
If l_current_version = '12.2.3' AND l_current_build = '6' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12230033'')
                         and a.sp = ''12230033''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12230033''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1223_18139794_attn;
End IF;



-- <h2 class="km">12.2.2 Build 11</h2>

-- 17326462 	  	Build 11 	  	Base 	Base Install. DEMANTRA 12.2.2
-- 18139794 	12230033 	45+ 	  	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.
-- 17640575 	  	  	  	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

-- 18139794
If l_current_version = '12.2.2' AND l_current_build = '11' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12230033'')
                         and a.sp = ''12230033''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12230033''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1222_18139794_attn;
End IF;


-- 17640575
If l_current_version = '12.2.2' AND l_current_build = '11' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314232 '')
                         and a.sp = ''7314232 ''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314232 ''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1222_17640575_attn;
End IF;


-- <h2 class="km">12.2.1 Build 15</h2>

-- 16409031 	Build 15 	  	Base 	Base Install. DEMANTRA 12.2.1
-- 18139794 	12230033 	45+   	WEB 	Highly recommended patch. 12.2.x oracle demantra database platform generic patch. Minimum Build Required: 45.
-- 17640575 	  	  	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

-- 18139794
If l_current_version = '12.2.1' AND l_current_build = '15' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''12230033'')
                         and a.sp = ''12230033''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''12230033''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1221_18139794_attn;
End IF;

-- 17640575
If l_current_version = '12.2.1' AND l_current_build = '15' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314232 '')
                         and a.sp = ''7314232 ''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314232 ''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1221_17640575_attn;
End IF;

-- <h2 class="km">12.2.0 Build 87</h2>

-- 17640575
If l_current_version = '12.2.0' AND l_current_build = '87' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314232 '')
                         and a.sp = ''7314232 ''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314232 ''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_1220_17640575_attn;
End IF;


-- <h2 class="km">7.3.1.5(.2) Build 5207</h2>

-- 17850720 	  	Build 5207 	  	Base 	Base Install. DEMANTRA 7.3.1 CU5
-- 18048597 	7314242 26 DB, Highly recommended patch. 7.3.1.x oracle demantra database platform generic patch. Minimum Build Required: 26 as of Dec 2017.
-- 20415508 	7315273 	  	  	DB 	Highly recommended patch. historylength parameter does not work per node.
-- 17640575 	  	  	  	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

-- 18048597
If l_current_version = '7.3.1' AND l_current_build = '5207' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314242'')
                         and a.sp = ''7314242''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314242''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7315_18048597_attn;
End IF;

-- 20415508
If l_current_version = '7.3.1' AND l_current_build = '5207' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7315273'')
                         and a.sp = ''7315273''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7315273''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7315_20415508_attn;
End IF;


-- 17640575
If l_current_version = '7.3.1' AND l_current_build = '5207' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314232 '')
                         and a.sp = ''7314232 ''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314232 ''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7315_17640575_attn;
End IF;


-- <h2 class="km">7.3.1.5(.1) Build 5106</h2>
-- 17640575
If l_current_version = '7.3.1' AND l_current_build = '5106' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314232 '')
                         and a.sp = ''7314232 ''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314232 ''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7315_17640575_5106_attn;
End IF;

-- <h2 class="km">7.3.1.5 Build 528</h2>

-- 16865694 	  	Build 5106 	  	Base 	Base Install. DEMANTRA Consumption-Driven Planning Release 7.3.1.5
-- 18048597 	7314242 26 DB 	Highly recommended patch. 7.3.1.x oracle demantra database platform generic patch. Minimum Build Required: as of Dec 2017.
-- 20415508 	7315273 	  	  	DB 	Highly recommended patch. historylength parameter does not work per node.
-- 17640575 	 	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

-- 18048597
If l_current_version = '7.3.1' AND l_current_build = '528' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314242'')
                         and a.sp = ''7314242''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314242''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7315_18048597_attn;
End IF;

-- 20415508
If l_current_version = '7.3.1' AND l_current_build = '528' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7315273'')
                         and a.sp = ''7315273''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7315273''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7315_20415508_attn;
End IF;


-- 17640575
If l_current_version = '7.3.1' AND l_current_build = '528' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314232 '')
                         and a.sp = ''7314232 ''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314232 ''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7315_17640575_attn;
End IF;


-- <h2 class="km">7.3.1.4.4 Build 450</h2>

-- 14405087 	  	Build 450 	  	Base 	Base Install. 7.3.1.4.4
-- 18048597 	7314242 26 DB 	Highly recommended patch. 7.3.1.x oracle demantra database platform generic patch. Minimum Build Required: as of Dec 2017.
-- 17640575 	  	  	  	DB 	Highly recommended patch. Demantra TABLE_REORG PATCH.

-- 18048597
If l_current_version = '7.3.1' AND l_current_build = '450' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314242'')
                         and a.sp = ''7314242''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314242''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7314_18048597_attn;
End IF;

-- 17640575
If l_current_version = '7.3.1' AND l_current_build = '450' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314232 '')
                         and a.sp = ''7314232 ''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314232 ''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7314_17640575_attn;
End IF;


-- <h2 class="km">7.3.1.4.3 Build 442</h2>
-- 17640575
If l_current_version = '7.3.1' AND l_current_build = '442' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where sp = ''7314232 '')
                         and a.sp = ''7314232 ''
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history
                                               where sp = ''7314232 ''
                                               group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql into l_7314_17640575_attn;
End IF;



-- -------------------------------------------------------
-- Version Check
-- -------------------------------------------------------

-- 12.2.9 Demantra version
-- l_1229_build15_ok
If l_current_version = '12.2.9' and l_current_build = '15' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_1229_build15_ok;
print_log('l_1229_build15_ok = '||l_1229_build15_ok);
End IF;


-- 12.2.7.1 Demantra version---
-- l_12271_build107_ok
If l_current_version = '12.2.7' and l_current_build = '107' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_12271_build107_ok;
print_log('l_12271_build107_ok = '||l_12271_build107_ok);
End IF;



-- 12.2.7 Demantra version---
-- l_1227_build19_ok
If l_current_version = '12.2.7' and l_current_build = '19' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_1227_build19_ok;
print_log('l_1227_build19_ok = '||l_1227_build19_ok);
End IF;


-- l_12263_build311_ok
-- 12.2.6.3
If l_current_version = '12.2.6' and l_current_build = '311' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_12263_build311_ok;
print_log('l_12263_build311_ok = '||l_12263_build311_ok);
End IF;


-- 12.2.6.2 Demantra version---
-- l_12262_build216_ok, Patch 25820351
If l_current_version = '12.2.6' and l_current_build = '216' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_12262_build216_ok;
print_log('l_12262_build216_ok = '||l_12262_build216_ok);
End IF;



-- 12.2.6.1 Demantra version---
-- l_12261_build112_ok, patch 25168361
If l_current_version = '12.2.6' and l_current_build = '112' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_12261_build112_ok;
print_log('l_12261_build112_ok = '||l_12261_build112_ok);
End IF;





-- 12.2.6, Build 35, ARU 20627746
-- l_1226_build35_ok, patch 24393123
If l_current_version = '12.2.6' and l_current_build = '35' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_1226_build35_ok;
print_log('l_1226_build35_ok = '||l_1226_build35_ok);
End IF;


-- l_12251_build136_ok
If l_current_version = '12.2.5' and l_current_build = '136' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_12251_build136_ok;
print_log('l_12251_build136_ok = '||l_12251_build136_ok);
End IF;
    

-- l_12225_build3_ok
-- 12.2.5 Demantra version---
If l_current_version = '12.2.5' and l_current_build = '3' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_12225_build3_ok;
print_log('l_12225_build3_ok = '||l_12225_build3_ok);
End IF;



-- l_12241_build117_ok
-- 12.2.4.1 Demantra version---
If l_current_version = '12.2.4' and l_current_build = '117' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_12241_build117_ok;
print_log('l_12241_build117_ok = '||l_12241_build117_ok);
End IF;




-- l_1224_build50_ok
-- 12.2.4 Demantra version---
If l_current_version = '12.2.4' and l_current_build = '50' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_1224_build50_ok;
print_log('l_1224_build50_ok = '||l_1224_build50_ok);
End IF;


-- l_1223_build6_ok
-- 12.2.3 Demantra version---
If l_current_version = '12.2.3' and l_current_build = '6' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_1223_build6_ok;
print_log('l_1223_build6_ok = '||l_1223_build6_ok);
End IF;


-- l_1222_build11_ok
-- 12.2.2 Demantra version---
If l_current_version = '12.2.2' and l_current_build = '11' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_1222_build11_ok;
print_log('l_1222_build11_ok = '||l_1222_build11_ok);
End IF;



-- l_1221_build15_ok
-- 12.2.1 Demantra version---
If l_current_version = '12.2.1' and l_current_build = '15' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_1221_build15_ok;
print_log('l_1221_build15_ok = '||l_1221_build15_ok);
End IF;



-- l_1220_build87_ok
-- 12.2.0 Demantra version---
If l_current_version = '12.2.0' and l_current_build = '87' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_1220_build87_ok;
print_log('l_1220_build87_ok = '||l_1220_build87_ok);
End IF;


-- l_73152_build5207_ok
-- 7.3.1.5(.2) Demantra version---
If l_current_version = '7.3.1' and l_current_build = '5207' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_73152_build5207_ok;
print_log('l_73152_build5207_ok = '||l_73152_build5207_ok);
End IF;


-- l_73151_build5106_ok
-- 7.3.1.5(.1) Demantra version---
If l_current_version = '7.3.1' and l_current_build = '5106' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_73151_build5106_ok;
print_log('l_73151_build5106_ok = '||l_73151_build5106_ok);
End IF;


-- l_7315_build528_ok
-- 7.3.1.5CDP-only Demantra version---
If l_current_version = '7.3.1' and l_current_build = '528' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_7315_build528_ok;
print_log('l_7315_build528_ok = '||l_7315_build528_ok);
End IF;


-- l_73144_build450_ok
-- 7.3.1.4, 7.3.1, Build 419
If l_current_version = '7.3.1' and l_current_build = '450' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_73144_build450_ok;
print_log('l_73144_build450_ok = '||l_73144_build450_ok);
End IF;


-- l_7314_build419_ok
-- 7.3.1.4, 7.3.1, Build 419, ARU #15495162 ---
If l_current_version = '7.3.1' and l_current_build = '419' THEN
 mySql := '
select decode((select 1 from '||p_schema_owner||'.version_details_history a
                         where exists (select 2 from '||p_schema_owner||'.version_details_history where version = ''l_current_version'')
                         and TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS'') =
                                              (select max(TO_CHAR(cast(upgrade_date as timestamp), ''DD-MON-YYYY HH24:MI:SS''))
                                               from '||p_schema_owner||'.version_details_history 
                                               where version = ''l_current_version'' group by version)), 1,1,4) result from dual';
EXECUTE immediate mySql
into l_7314_build419_ok;
print_log('l_7314_build419_ok = '||l_7314_build419_ok);
End IF;

--
print_log('===========[ END of reported versions in version_details, version and build ]==========');
--
-- APPSERVERURL
--
-- mySql := '
-- Select COUNT(*) 
-- from '||p_schema_owner||'.sys_params
-- where pname = ''AppServerURL''';
-- EXECUTE immediate mySql
-- into l_appserverurl_exists;

-- get length
-- mySql := '
-- SELECT length(pval)
-- FROM '||p_schema_owner||'.sys_params 
-- WHERE pname = ''AppServerURL''';
-- EXECUTE immediate mySql
-- into l_appserverurl_length;

mySql := '
SELECT pval, 
Nvl(Substr(pval,0,Instr(pval,'':'')-1),''null''),
nvl(Substr(Pval,Instr(Pval,'':'')+1,Instr(Pval,''.'',1,2)-Instr(Pval,''.'')-1),''na''),
nvl(SUBSTR(pval,INSTR(pval,'':'',1,1)+3,INSTR(pval,'':'',1,2)-INSTR(pval,'':'',1,1)-3),''null''),
Substr(Pval,Instr(Pval,'':'',1,2)+1,Instr(Pval,''/'',1,2)-(Instr(Pval,''/'',1,1)-3)),
Substr(Pval,Instr(Pval,'':'',1,2)+1,Instr(Pval,''/'',1,2)-(Instr(Pval,''/'',1,1)-3)),
nvl(Substr(Pval,Instr(Pval,''/'',1,3)+1),''null'')
from '||p_schema_owner||'.sys_params 
where pname = ''AppServerURL''';
EXECUTE immediate mySql
into l_appserverurl, l_protocol, l_slash, l_host_name, l_port1, l_port2, l_rest;

mySql := '
SELECT pval, 
Nvl(Substr(pval,0,Instr(pval,'':'')-1),''null''),
nvl(Substr(Pval,Instr(Pval,'':'')+1,Instr(Pval,''.'',1,2)-Instr(Pval,''.'')-1),''na''),
nvl(SUBSTR(pval,INSTR(pval,'':'',1,1)+3,INSTR(pval,'':'',1,2)-INSTR(pval,'':'',1,1)-3),''null''),
nvl(Substr(Pval,Instr(Pval,'':'',1,2)+1,Instr(Pval,''/'',1,2)-(Instr(Pval,''/'',1,1)-3)),''null''),
nvl(Substr(Pval,Instr(Pval,''/'',1,3)+1),''null'')
from '||p_schema_owner||'.sys_params 
where pname = ''EngineBaseURL''';
EXECUTE immediate mySql
into l_eng_appserverurl, l_eng_protocol, l_eng_slash, l_eng_host_name, l_eng_port1, l_eng_rest;

mySql := '
select pval
from '||p_schema_owner||'.sys_params
where pname = ''EnginePlatform''';
EXECUTE immediate mySql
into l_eng_platform;

mySql := '
select nvl(pval, ''null'')
from '||p_schema_owner||'.sys_params
where exists (select nvl(pval, ''null'') from '||p_schema_owner||'.sys_params where pname = ''EngineBaseURL'' and instr(pval, ''EngineManager'') > 0)
and pname = ''EngineBaseURL''';
EXECUTE immediate mySql
into l_enginebaseurl;


-- HTTP setting of MSD_DEM: Host URL at the SITE level ONLY.  If no rows returned either no entry for schema owner or not set at site level
   mySql := '
   select nvl(fpov.profile_option_value, ''NULL'') Value
   from fnd_profile_option_values fpov, -- FND_PROFILE_OPTIONS_VL
   fnd_profile_options_vl fpo,
   fnd_application fa,
   fnd_responsibility_vl fr,
   fnd_user fu,
   fnd_logins fl
   where exists (select fpov.profile_option_value Value
     from fnd_profile_option_values fpov, -- FND_PROFILE_OPTIONS_VL
     fnd_profile_options_vl fpo,
     fnd_application fa,
     fnd_responsibility_vl fr,
     fnd_user fu,
     fnd_logins fl
     where fpo.profile_option_id = fpov.profile_option_id(+)
     and fa.application_id(+) = fpov.level_value
     and fr.application_id(+) = fpov.level_value_application_id
     and fr.responsibility_id(+) = fpov.level_value
     and fu.user_id(+) = fpov.level_value
     and fl.login_id(+) = fpov.LAST_UPDATE_LOGIN
     and fpo.profile_option_name LIKE (''%MSD_DEM_HOST_URL%'')
     and fpov.level_id = 10001
     and substr(upper(fpov.profile_option_value),1,4) = ''HTTP'')
   and fpo.profile_option_id=fpov.profile_option_id(+)
   and fa.application_id(+)=fpov.level_value
   and fr.application_id(+)=fpov.level_value_application_id
   and fr.responsibility_id(+)=fpov.level_value
   and fu.user_id(+)=fpov.level_value
   and fl.login_id(+) = fpov.LAST_UPDATE_LOGIN
   and fpo.profile_option_name LIKE (''%MSD_DEM_HOST_URL%'')
   and fpov.level_id = 10001';
   EXECUTE immediate mySql
   into l_MSD_DEM_http;

IF lower(substr(l_MSD_DEM_http, 1, 5)) = 'https' THEN
    l_MSD_DEM_PROFILE_PROTOCOL := 'HTTPS';
ELSE
    l_MSD_DEM_PROFILE_PROTOCOL := 'HTTP';
END IF;

l_protocol := upper(l_protocol);
l_eng_protocol := upper(l_eng_protocol);
l_MSD_DEM_PROFILE_PROTOCOL := upper(l_MSD_DEM_PROFILE_PROTOCOL);
	print_log('l_protocol = '||l_protocol);
	print_log('l_eng_protocol = '||l_eng_protocol);
	print_log('l_MSD_DEM_PROFILE_PROTOCOL = '||l_MSD_DEM_PROFILE_PROTOCOL);
    print_log('===========[ Assigning Global Variables ]=======================');
g_1229_30187573_15 := l_1229_30187573_15;
g_1229_30187573_17 := l_1229_30187573_17;
G_7314_17640575_442_ATTN    := l_7314_17640575_442_ATTN;
G_7314_17640575_450_ATTN    := l_7314_17640575_450_ATTN;
G_7314_18048597_450_ATTN    := l_7314_18048597_450_ATTN;
G_7314_BUILD450_OK          := l_7314_BUILD450_OK;
G_7315_20415508_528_ATTN    := l_7315_20415508_528_ATTN;
G_7315_18048597_528_ATTN    := l_7315_18048597_528_ATTN;
G_12251_27320973_ATTN       := l_12251_27320973_ATTN;
G_1225_BUILD3_OK            := l_1225_BUILD3_OK;
G_1221_BUILD11_OK           := l_1221_BUILD11_OK;
G_7315_BUILD5207_OK         := l_7315_BUILD5207_OK;
G_7315_18048597_5207_ATTN   := l_7315_18048597_5207_ATTN;
G_7315_20415508_5207_ATTN   := l_7315_20415508_5207_ATTN;
G_7315_BUILD528_OK          := l_7315_BUILD528_OK;
G_12271_BUILD107_OK         := l_12271_BUILD107_OK;
G_12271_27128464_ATTN       := l_12271_27128464_ATTN;
G_12271_26975832_ATTN       := l_12271_26975832_ATTN;
G_1227_27128464_ATTN        := l_1227_27128464_ATTN;
G_12263_27278471_ATTN       := l_12263_27278471_ATTN;
G_12261_BUILD110_OK         := l_12261_BUILD110_OK;
G_1225_BUILD136_OK          := l_1225_BUILD136_OK;
g_1227_build19_ok           := l_1227_build19_ok;
g_12263_build311_ok         := l_12263_build311_ok;
g_12262_build216_ok         := l_12262_build216_ok;
g_12261_build112_ok         := l_12261_build112_ok;
g_1226_build35_ok           := l_1226_build35_ok;
g_12251_build136_ok         := l_12251_build136_ok;
g_12225_build3_ok           := l_12225_build3_ok;
g_12241_build117_ok         := l_12241_build117_ok;
g_1224_build50_ok           := l_1224_build50_ok;
g_1223_build6_ok            := l_1223_build6_ok;
g_1222_build11_ok           := l_1222_build11_ok;
g_1221_build15_ok           := l_1221_build15_ok;
g_1220_build87_ok           := l_1220_build87_ok;
g_73152_build5265_ok        := l_73152_build5265_ok;
g_73152_build5207_ok        := l_73152_build5207_ok;
g_73151_build5106_ok        := l_73151_build5106_ok;
g_7315_build528_ok       := l_7315_build528_ok;
g_7314_build450_ok          := l_7314_build450_ok;
g_7314_build419_ok          := l_7314_build419_ok;
g_12271_12270326_ATTN       := l_12271_12270326_ATTN;
g_12271_build107_ok         := l_12271_build107_ok;

-- patch checks
g_1229_12290397_attn		:= l_1229_12290397_attn;
g_1229_12290401_attn        := l_1229_12290401_attn;
g_1229_build15_ok			:= l_1229_build15_ok;

g_12271_27128464_attn       := l_12271_27128464_attn;
g_12271_26975832_attn       := l_12271_26975832_attn;
g_1227_27128464_attn        := l_1227_27128464_attn;
g_1227_26975832_attn        := l_1227_26975832_attn;
g_12263_27278471_attn       := l_12263_27278471_attn;
g_12263_25420760_attn       := l_12263_25420760_attn;
g_1226_27278471_attn        := l_1226_27278471_attn;
g_1226_12260250_attn        := l_1226_12260250_attn;
g_12262_26641148_attn       := l_12262_26641148_attn;
g_12262_25420760_attn       := l_12262_25420760_attn;
g_12251_27320973_attn       := l_12251_27320973_attn;
g_7315_18048597_attn       := l_7315_18048597_attn;
g_7315_20415508_attn       := l_7315_20415508_attn;
g_7315_17640575_attn       := l_7315_17640575_attn;
g_7315_18048597_attn       := l_7315_18048597_attn;
g_7315_20415508_attn       := l_7315_20415508_attn;
g_7314_18048597_attn       := l_7314_18048597_attn;
g_7314_17640575_attn       := l_7314_17640575_attn;

g_12262_bld216_attn         := l_12262_bld216_attn;
g_12261_25420760_attn       := l_12261_25420760_attn;
g_1226_25420760_attn        := l_1226_25420760_attn;

g_7314_17640575_442_attn   := l_7314_17640575_442_attn;
g_7315_build528_ok          := l_7315_build528_ok;
g_7315_20415508_528_attn    := l_7315_20415508_528_attn;
g_1222_18139794_attn        := l_1222_18139794_attn;

g_12261_bld112_attn         := l_12261_bld112_attn;
g_12262_26798382_attn       := l_12262_26798382_attn;
g_12261_25403411_attn       := l_12261_25403411_attn;
g_12261_25332178_attn       := l_12261_25332178_attn;
g_1226_24710302_attn        := l_1226_24710302_attn;
g_1226_24710302_bld34_attn  := l_1226_24710302_bld34_attn;
g_12251_22254051_attn       := l_12251_22254051_attn;
g_1225_22254051_attn        := l_1225_22254051_attn;
g_12251_26663751_attn       := l_12251_26663751_attn;
g_12251_26305727_attn       := l_12251_26305727_attn;
g_12251_23059980_attn       := l_12251_23059980_attn;
g_12251_23088083_attn       := l_12251_23088083_attn;
g_12251_21094268_attn       := l_12251_21094268_attn;
g_12251_21959406_attn       := l_12251_21959406_attn;
g_1224_19945449_attn        := l_1224_19945449_attn;
g_1224_18139794_attn        := l_1224_18139794_attn;
g_1223_18080391_attn        := l_1223_18080391_attn;
g_1223_18040010_attn        := l_1223_18040010_attn;
g_1223_18139794_attn        := l_1223_18139794_attn;
g_12263_18139794_attn       := l_12263_18139794_attn;
g_12262_18139794_attn       := l_12262_18139794_attn;
g_1226_18139794_attn        := l_1226_18139794_attn;
g_12251_18139794_attn       := l_12251_18139794_attn;
g_1225_18139794_attn        := l_1225_18139794_attn;
g_12241_18139794_attn       := l_12241_18139794_attn;
g_1221_18139794_attn        := l_1221_18139794_attn;
g_122_18139794_attn         := l_122_18139794_attn;
g_7315_18067048_attn        := l_7315_18067048_attn;
g_7315_7315238_5265_attn   := l_7315_7315238_5265_attn;
g_7315_7315238_5207_attn   := l_7315_7315238_5207_attn;
g_7315_7315238_5106_attn   := l_7315_7315238_5106_attn;
g_7315_7315238_528_attn    := l_7315_7315238_528_attn;
g_73144_17261893_attn       := l_73144_17261893_attn;
g_73143_17261893_attn       := l_73143_17261893_attn;
g_1226_25332169_ATTN := l_1226_25332169_ATTN;
g_12251_12250168_attn := L_12251_12250168_attn;
g_12263_bld311_attn         := l_12263_bld311_attn;
g_1227_26981675_attn  := l_1227_26981675_attn;
g_12263_26981675_attn := l_12263_26981675_attn;
g_12262_26981675_attn := l_12262_26981675_attn;
g_12261_26981675_attn := l_12261_26981675_attn;
g_1226_26981675_attn := l_1226_26981675_attn;
g_12251_26981675_attn := l_12251_26981675_attn;
g_1225_26981675_attn := l_1225_26981675_attn;
g_12241_26981675_attn := l_12241_26981675_attn;
g_1224_26981675_attn := l_1224_26981675_attn;
g_1223_26981675_attn := l_1223_26981675_attn;
g_1222_26981675_attn := l_1222_26981675_attn;
g_1221_26981675_attn := l_1221_26981675_attn;
g_1220_26981675_attn := l_1220_26981675_attn;
g_7315_5265_26981675_attn := l_7315_5265_26981675_attn;
g_7315_5207_26981675_attn := l_7315_5207_26981675_attn;
g_7315_5106_26981675_attn := l_7315_5106_26981675_attn;
g_7315_528_26981675_attn := l_7315_528_26981675_attn;
g_73144_26981675_attn := l_73144_26981675_attn;
g_73143_26981675_attn := l_73143_26981675_attn;
g_7315_5265_25506270_attn := l_7315_5265_25506270_attn;
g_7315_5207_25506270_attn := l_7315_5207_25506270_attn;
g_7315_5106_25506270_attn := l_7315_5106_25506270_attn;
g_7315_528_25506270_attn := l_7315_528_25506270_attn;
g_73144_25506270_attn := l_73144_25506270_attn;
g_73143_25506270_attn := l_73143_25506270_attn;
g_12262_bld216_attn := l_12262_bld216_attn;
g_12251_12250139_attn := l_12251_12250139_attn;
g_12251_12250260_attn := l_12251_12250260_attn;
g_12261_25332178_bld110_attn := l_12261_25332178_bld110_attn;
g_12261_18139794_attn := l_12261_18139794_attn;
g_1224_19550595_attn := l_1224_19550595_attn;
g_12241_25739519_attn := l_12241_25739519_attn;
g_1227_25634269_attn := l_1227_25634269_attn;
g_12263_25634269_attn := l_12263_25634269_attn;
g_12262_25634269_attn := l_12262_25634269_attn;
g_12261_25634269_attn := l_12261_25634269_attn;
g_1226_25634269_attn := l_1226_25634269_attn;
g_12251_25634269_attn := l_12251_25634269_attn;
g_1225_25634269_attn := l_1225_25634269_attn;
g_12241_25634269_attn := l_12241_25634269_attn;
g_1224_25634269_attn := l_1224_25634269_attn;
g_1223_25634269_attn := l_1223_25634269_attn;
g_1222_25634269_attn := l_1222_25634269_attn;
g_1221_25634269_attn := l_1221_25634269_attn;
g_1220_25634269_attn := l_1220_25634269_attn;
g_7315_25634269_528_attn := l_7315_25634269_528_attn;
g_7315_25634269_5265_attn := l_7315_25634269_5265_attn;
g_7315_25634269_5207_attn := l_7315_25634269_5207_attn;
g_7315_25634269_5106_attn := l_7315_25634269_5106_attn;
g_73144_25634269_450_attn := l_73144_25634269_450_attn;
g_73143_25634269_442_attn := l_73143_25634269_442_attn;
g_1221_25103402_attn := l_1221_25103402_attn;
g_1222_25103402_attn := l_1222_25103402_attn;
g_1223_25103402_attn := l_1223_25103402_attn;
g_7315_25103402_5207_attn := l_7315_25103402_5207_attn;
g_1227_24935262_attn := l_1227_24935262_attn;
g_12263_24935262_attn := l_12263_24935262_attn;
g_12262_24935262_attn := l_12262_24935262_attn;
g_12261_24935262_attn := l_12261_24935262_attn;
g_1226_24935262_attn := l_1226_24935262_attn;
g_12251_24935262_attn := l_12251_24935262_attn;
g_1225_24935262_attn := l_1225_24935262_attn;
g_12241_24935262_attn := l_12241_24935262_attn;
g_1224_24935262_attn := l_1224_24935262_attn;
g_1223_24935262_attn := l_1223_24935262_attn;
g_1222_24935262_attn := l_1222_24935262_attn;
g_1221_24935262_attn := l_1221_24935262_attn;
g_1220_24935262_attn := l_1220_24935262_attn;
g_7315_24935262_528_attn := l_7315_24935262_528_attn;
g_7315_24935262_5265_attn := l_7315_24935262_5265_attn;
g_7315_24935262_5207_attn := l_7315_24935262_5207_attn;
g_7315_24935262_5106_attn := l_7315_24935262_5106_attn;
g_73144_24935262_450_attn := l_73144_24935262_450_attn;
g_73143_24935262_442_attn := l_73143_24935262_442_attn;
g_12263_22275972_attn := l_12263_22275972_attn;
g_12262_22275972_attn := l_12262_22275972_attn;
g_12261_22275972_attn := l_12261_22275972_attn;
g_1226_22275972_attn := l_1226_22275972_attn;
g_12251_22275972_attn := l_12251_22275972_attn;
g_1225_22275972_attn := l_1225_22275972_attn;
g_12241_22275972_attn := l_12241_22275972_attn;
g_1224_22275972_attn := l_1224_22275972_attn;
g_1223_22275972_attn := l_1223_22275972_attn;
g_1222_22275972_attn := l_1222_22275972_attn;
g_1221_22275972_attn := l_1221_22275972_attn;
g_122_22275972_attn := l_122_22275972_attn;
g_1227_20211773_attn := l_1227_20211773_attn;
g_12263_20211773_attn := l_12263_20211773_attn;
g_12262_20211773_attn := l_12262_20211773_attn;
g_12261_20211773_attn := l_12261_20211773_attn;
g_1226_20211773_attn := l_1226_20211773_attn;
g_12251_20211773_attn := l_12251_20211773_attn;
g_1225_20211773_attn := l_1225_20211773_attn;
g_12241_20211773_attn := l_12241_20211773_attn;
g_1224_20211773_attn := l_1224_20211773_attn;
g_1223_20211773_attn := l_1223_20211773_attn;
g_1222_20211773_attn := l_1222_20211773_attn;
g_1221_20211773_attn := l_1221_20211773_attn;
g_1220_20211773_attn := l_1220_20211773_attn;
g_7315_20211773_528_attn := l_7315_20211773_528_attn;
g_7315_20211773_5265_attn := l_7315_20211773_5265_attn;
g_7315_20211773_5207_attn := l_7315_20211773_5207_attn;
g_7315_20211773_5106_attn := l_7315_20211773_5106_attn;
g_73144_20211773_450_attn := l_73144_20211773_450_attn;
g_73143_20211773_442_attn := l_73143_20211773_442_attn;
g_1227_22018502_attn := l_1227_22018502_attn;
g_12263_22018502_attn := l_12263_22018502_attn;
g_12262_22018502_attn := l_12262_22018502_attn;
g_12261_22018502_attn := l_12261_22018502_attn;
g_1226_22018502_attn := l_1226_22018502_attn;
g_12251_22018502_attn := l_12251_22018502_attn;
g_1225_22018502_attn := l_1225_22018502_attn;
g_12241_22018502_attn := l_12241_22018502_attn;
g_1224_22018502_attn := l_1224_22018502_attn;
g_1223_22018502_attn := l_1223_22018502_attn;
g_1222_22018502_attn := l_1222_22018502_attn;
g_1221_22018502_attn := l_1221_22018502_attn;
g_1220_22018502_attn := l_1220_22018502_attn;
g_7315_22018502_528_attn := l_7315_22018502_528_attn;
g_7315_22018502_5265_attn := l_7315_22018502_5265_attn;
g_7315_22018502_5207_attn := l_7315_22018502_5207_attn;
g_7315_22018502_5106_attn := l_7315_22018502_5106_attn;
g_73144_22018502_450_attn := l_73144_22018502_450_attn;
g_73143_22018502_442_attn := l_73143_22018502_442_attn;
g_1227_20613106_attn := l_1227_20613106_attn;
g_12263_20613106_attn := l_12263_20613106_attn;
g_12262_20613106_attn := l_12262_20613106_attn;
g_12261_20613106_attn := l_12261_20613106_attn;
g_1226_20613106_attn := l_1226_20613106_attn;
g_12251_20613106_attn := l_12251_20613106_attn;
g_1225_20613106_attn := l_1225_20613106_attn;
g_12241_20613106_attn := l_12241_20613106_attn;
g_1224_20613106_attn := l_1224_20613106_attn;
g_1223_20613106_attn := l_1223_20613106_attn;
g_1222_20613106_attn := l_1222_20613106_attn;
g_1221_20613106_attn := l_1221_20613106_attn;
g_1220_20613106_attn := l_1220_20613106_attn;
g_7315_20613106_528_attn := l_7315_20613106_528_attn;
g_7315_20613106_5265_attn := l_7315_20613106_5265_attn;
g_7315_20613106_5207_attn := l_7315_20613106_5207_attn;
g_7315_20613106_5106_attn := l_7315_20613106_5106_attn;
g_73144_20613106_450_attn := l_73144_20613106_450_attn;
g_73143_20613106_442_attn := l_73143_20613106_442_attn;
g_1227_21089579_attn := l_1227_21089579_attn;
g_12263_21089579_attn := l_12263_21089579_attn;
g_12262_21089579_attn := l_12262_21089579_attn;
g_12261_21089579_attn := l_12261_21089579_attn;
g_1226_21089579_attn := l_1226_21089579_attn;
g_12251_21089579_attn := l_12251_21089579_attn;
g_1225_21089579_attn := l_1225_21089579_attn;
g_12241_21089579_attn := l_12241_21089579_attn;
g_1224_21089579_attn := l_1224_21089579_attn;
g_1223_21089579_attn := l_1223_21089579_attn;
g_1222_21089579_attn := l_1222_21089579_attn;
g_1221_21089579_attn := l_1221_21089579_attn;
g_1220_21089579_attn := l_1220_21089579_attn;
g_7315_21089579_528_attn := l_7315_21089579_528_attn;
g_7315_21089579_5265_attn := l_7315_21089579_5265_attn;
g_7315_21089579_5207_attn := l_7315_21089579_5207_attn;
g_7315_21089579_5106_attn := l_7315_21089579_5106_attn;
g_73144_21089579_450_attn := l_73144_21089579_450_attn;
g_73143_21089579_442_attn := l_73143_21089579_442_attn;
g_1227_20429760_attn := l_1227_20429760_attn;
g_12263_20429760_attn := l_12263_20429760_attn;
g_12262_20429760_attn := l_12262_20429760_attn;
g_12261_20429760_attn := l_12261_20429760_attn;
g_1226_20429760_attn := l_1226_20429760_attn;
g_12251_20429760_attn := l_12251_20429760_attn;
g_1225_20429760_attn := l_1225_20429760_attn;
g_12241_20429760_attn := l_12241_20429760_attn;
g_1224_20429760_attn := l_1224_20429760_attn;
g_1223_20429760_attn := l_1223_20429760_attn;
g_1222_20429760_attn := l_1222_20429760_attn;
g_1221_20429760_attn := l_1221_20429760_attn;
g_1220_20429760_attn := l_1220_20429760_attn;
g_7315_20429760_528_attn := l_7315_20429760_528_attn;
g_7315_20429760_5265_attn := l_7315_20429760_5265_attn;
g_7315_20429760_5207_attn := l_7315_20429760_5207_attn;
g_7315_20429760_5106_attn := l_7315_20429760_5106_attn;
g_73144_20429760_450_attn := l_73144_20429760_450_attn;
g_73143_20429760_442_attn := l_73143_20429760_442_attn;
g_12241_20174176_attn := l_12241_20174176_attn;
g_1224_20174176_attn := l_1224_20174176_attn;
g_7315_20174176_528_attn := l_7315_20174176_528_attn;
g_7315_20174176_5265_attn := l_7315_20174176_5265_attn;
g_7315_20174176_5207_attn := l_7315_20174176_5207_attn;
g_7315_20174176_5106_attn := l_7315_20174176_5106_attn;
g_1227_18638749_attn := l_1227_18638749_attn;
g_12263_18638749_attn := l_12263_18638749_attn;
g_12262_18638749_attn := l_12262_18638749_attn;
g_12261_18638749_attn := l_12261_18638749_attn;
g_1226_18638749_attn := l_1226_18638749_attn;
g_12251_18638749_attn := l_12251_18638749_attn;
g_1225_18638749_attn := l_1225_18638749_attn;
g_12241_18638749_attn := l_12241_18638749_attn;
g_1224_18638749_attn := l_1224_18638749_attn;
g_1223_18638749_attn := l_1223_18638749_attn;
g_1222_18638749_attn := l_1222_18638749_attn;
g_1221_18638749_attn := l_1221_18638749_attn;
g_1220_18638749_attn := l_1220_18638749_attn;
g_7315_18638749_528_attn := l_7315_18638749_528_attn;
g_7315_18638749_5265_attn := l_7315_18638749_5265_attn;
g_7315_18638749_5207_attn := l_7315_18638749_5207_attn;
g_7315_18638749_5106_attn := l_7315_18638749_5106_attn;
g_73144_18638749_450_attn := l_73144_18638749_450_attn;
g_73143_18638749_442_attn := l_73143_18638749_442_attn;
g_1222_17640575_attn := l_1222_17640575_attn;
g_1221_17640575_attn := l_1221_17640575_attn;
g_1220_17640575_attn := l_1220_17640575_attn;
g_7315_17640575_528_attn := l_7315_17640575_528_attn;
g_7315_17640575_5265_attn := l_7315_17640575_5265_attn;
g_7315_17640575_5207_attn := l_7315_17640575_5207_attn;
g_7315_17640575_5106_attn := l_7315_17640575_5106_attn;
g_7314_17640575_450_attn := l_7314_17640575_450_attn;
g_7314_17640575_442_attn := l_7314_17640575_442_attn;
g_1227_17808535_attn := l_1227_17808535_attn;
g_12263_17808535_attn := l_12263_17808535_attn;
g_12262_17808535_attn := l_12262_17808535_attn;
g_12261_17808535_attn := l_12261_17808535_attn;
g_1226_17808535_attn := l_1226_17808535_attn;
g_12251_17808535_attn := l_12251_17808535_attn;
g_1225_17808535_attn := l_1225_17808535_attn;
g_12241_17808535_attn := l_12241_17808535_attn;
g_1224_17808535_attn := l_1224_17808535_attn;
g_1223_17808535_attn := l_1223_17808535_attn;
g_1222_17808535_attn := l_1222_17808535_attn;
g_1221_17808535_attn := l_1221_17808535_attn;
g_1220_17808535_attn := l_1220_17808535_attn;
g_7315_17808535_528_attn := l_7315_17808535_528_attn;
g_7315_17808535_5265_attn := l_7315_17808535_5265_attn;
g_7315_17808535_5207_attn := l_7315_17808535_5207_attn;
g_7315_17808535_5106_attn := l_7315_17808535_5106_attn;
g_73144_17808535_450_attn := l_73144_17808535_450_attn;
g_73143_17808535_442_attn := l_73143_17808535_442_attn;
g_1227_17024161_attn := l_1227_17024161_attn;
g_12263_17024161_attn := l_12263_17024161_attn;
g_12262_17024161_attn := l_12262_17024161_attn;
g_12261_17024161_attn := l_12261_17024161_attn;
g_1226_17024161_attn := l_1226_17024161_attn;
g_12251_17024161_attn := l_12251_17024161_attn;
g_1225_17024161_attn := l_1225_17024161_attn;
g_12241_17024161_attn := l_12241_17024161_attn;
g_1224_17024161_attn := l_1224_17024161_attn;
g_1223_17024161_attn := l_1223_17024161_attn;
g_1222_17024161_attn := l_1222_17024161_attn;
g_1221_17024161_attn := l_1221_17024161_attn;
g_1220_17024161_attn := l_1220_17024161_attn;
g_7315_17024161_528_attn := l_7315_17024161_528_attn;
g_7315_17024161_5265_attn := l_7315_17024161_5265_attn;
g_7315_17024161_5207_attn := l_7315_17024161_5207_attn;
g_7315_17024161_5106_attn := l_7315_17024161_5106_attn;
g_73144_17024161_450_attn := l_73144_17024161_450_attn;
g_73143_17024161_442_attn := l_73143_17024161_442_attn;
g_1227_13930627_attn := l_1227_13930627_attn;
g_12263_13930627_attn := l_12263_13930627_attn;
g_12262_13930627_attn := l_12262_13930627_attn;
g_12261_13930627_attn := l_12261_13930627_attn;
g_1226_13930627_attn := l_1226_13930627_attn;
g_12251_13930627_attn := l_12251_13930627_attn;
g_1225_13930627_attn := l_1225_13930627_attn;
g_12241_13930627_attn := l_12241_13930627_attn;
g_1224_13930627_attn := l_1224_13930627_attn;
g_1223_13930627_attn := l_1223_13930627_attn;
g_1222_13930627_attn := l_1222_13930627_attn;
g_1221_13930627_attn := l_1221_13930627_attn;
g_1220_13930627_attn := l_1220_13930627_attn;
g_7315_13930627_528_attn := l_7315_13930627_528_attn;
g_7315_13930627_5265_attn := l_7315_13930627_5265_attn;
g_7315_13930627_5207_attn := l_7315_13930627_5207_attn;
g_7315_13930627_5106_attn := l_7315_13930627_5106_attn;
g_73144_13930627_450_attn := l_73144_13930627_450_attn;
g_73143_13930627_442_attn := l_73143_13930627_442_attn;

g_1226_25420760_attn := l_1226_25420760_attn;

g_12261_25420760_attn := l_12261_25420760_attn;
g_1226_25420760_attn := l_1226_25420760_attn;
g_12251_26985862_attn := l_12251_26985862_attn;
g_7315_5265_25506270_attn := l_7315_5265_25506270_attn;
g_7315_5207_25506270_attn := l_7315_5207_25506270_attn;
g_7315_5106_25506270_attn := l_7315_5106_25506270_attn;
g_7315_528_25506270_attn := l_7315_528_25506270_attn;
g_73144_25506270_attn := l_73144_25506270_attn;
g_73143_25506270_attn := l_73143_25506270_attn;
g_1227_25506270_attn := l_1227_25506270_attn;
g_12263_25506270_attn := l_12263_25506270_attn;
g_12262_25506270_attn := l_12262_25506270_attn;
g_12261_25506270_attn := l_12261_25506270_attn;
g_1226_25506270_attn := l_1226_25506270_attn;
g_1225_25506270_attn := l_1225_25506270_attn;
g_12241_25506270_attn := l_12241_25506270_attn;
g_1224_25506270_attn := l_1224_25506270_attn;
g_1223_25506270_attn := l_1223_25506270_attn;
g_1222_25506270_attn := l_1222_25506270_attn;
g_1221_25506270_attn := l_1221_25506270_attn;
g_1220_25506270_attn := l_1220_25506270_attn;
G_73144_26981675_450_ATTN := l_73144_26981675_450_ATTN;
G_73143_26981675_442_ATTN := l_73143_26981675_442_ATTN;
g_7315_26981675_528_ATTN := L_7315_26981675_528_ATTN;
g_7315_26981675_5265_attn := l_7315_26981675_5265_attn;
g_7315_26981675_5207_attn := l_7315_26981675_5207_attn;
g_7315_26981675_5106_attn := l_7315_26981675_5106_attn;
g_7315_18067048_5265_attn := l_7315_18067048_5265_attn;
g_7315_18067048_5207_attn := l_7315_18067048_5207_attn;
g_7315_18067048_5106_attn := l_7315_18067048_5106_attn;
g_7315_18067048_528_attn := l_7315_18067048_528_attn;
g_anchor_link := l_anchor_link;

g_sum_rows_sales_data 		:= l_sum_rows_sales_data;
g_sum_rows_mdp_matrix 		:= l_sum_rows_mdp_matrix;
g_sum_rows_promotion_data 	:= l_sum_rows_promotion_data;
g_concurrent_users      	:= l_concurrent_users;
g_batch_java_threads 		:= l_batch_java_threads;
g_manual_java_threads 		:= l_manual_java_threads;
g_total_update_pool 		:= l_total_update_pool;
g_app_server_ctas 		:= l_app_server_ctas;
g_maxdbconnections_derived 	:= l_maxdbconnections_derived;
g_total_batch_connections 	:= l_total_batch_connections;
g_min_ctas_cpu_required 	:= l_min_ctas_cpu_required;
g_max_ctas_cpu_required 	:= l_max_ctas_cpu_required;
g_appserver_cpu_required        := l_appserver_cpu_required;
g_middle_tier_cpu 		:= l_middle_tier_cpu;
g_MIN_APP_SERVER_CORES		:= l_MIN_APP_SERVER_CORES;
g_MAX_APP_SERVER_CORES		:= l_MAX_APP_SERVER_CORES;
g_manual_threads_per_cpu        := l_manual_threads_per_cpu;
g_batch_threads_per_cpu         := l_batch_threads_per_cpu;
g_pool_threads_per_cpu          := l_pool_threads_per_cpu;
g_maxdbconnection_cpu_comp      := l_maxdbconnection_cpu_comp;
g_tp_query_run_size_derived     := l_tp_query_run_size_derived;
g_maxdbconnection_derived       := l_maxdbconnection_derived;
g_parallel_max_servers          := l_parallel_max_servers;
g_parallel_max_servers_min      := l_parallel_max_servers_min;
g_parallel_max_servers_max      := l_parallel_max_servers_max;
g_min_comb_cpu_req              := l_min_comb_cpu_req;
g_max_comb_cpu_req              := l_max_comb_cpu_req;

-- v$parameter
g_cpu_count 		:= l_cpu_count;
g_cpu_count_17 		:= l_cpu_count_17;
g_cpu_count_3 		:= l_cpu_count_3;
g_physical_cpu_count    := l_physical_cpu_count;
g_physical_cpu_count_17 := l_physical_cpu_count_17;
g_physical_cpu_count_3  := l_physical_cpu_count_3;
g_manual_java_threads 	:= l_manual_java_threads;
g_batch_java_threads 	:= l_batch_java_threads;
g_total_update_pool 	:= l_total_update_pool;

-- for job_queue_processes
g_job_queue_value	:= l_job_queue_value;
g_sales_data_analyzed	:= l_sales_data_analyzed;  -- 0 = no, 1 = yes
g_total_batch_cores	:= l_total_batch_cores;
g_concurrent_users_disp := l_concurrent_users_disp;
g_SD_INDEX 		:= l_SD_INDEX;
g_SD_FACTOR 		:= l_SD_FACTOR;
g_MDP_INDEX 		:= l_MDP_INDEX;
g_MDP_FACTOR 		:= l_MDP_FACTOR;
g_min_app_server_cores17 := l_min_app_server_cores17;
g_max_app_server_cores17 := l_max_app_server_cores17;
g_min_app_server_cores3  := l_min_app_server_cores3;
g_max_app_server_cores3  := l_max_app_server_cores3;

-- aps_params
g_tp_update_record_batch_size 	:= l_tp_update_record_batch_size;
g_tp_update_record_manual_size 	:= l_tp_update_record_manual_size;   
g_tp_update_data_manual_size	:= l_tp_update_data_manual_size;
g_tp_update_data_batch_size 	:= l_tp_update_data_batch_size;   
g_tp_update_table_manual_size  	:= l_tp_update_table_manual_size;
g_tp_update_comb_manual_size 	:= l_tp_update_comb_manual_size;
g_tp_update_comb_batch_size 	:= l_tp_update_comb_batch_size;
g_tp_update_table_batch_size 	:= l_tp_update_table_batch_size;
g_tp_update_size 		:= l_tp_update_size;
g_tp_update_timeout 		:= l_tp_update_timeout;
g_tp_query_run_size 		:= l_tp_query_run_size;
g_tp_query_run_per_user 	:= l_tp_query_run_per_user;
g_tp_query_run_timeout 		:= l_tp_query_run_timeout;
g_tp_level_method_size 		:= l_tp_level_method_size;
g_tp_level_method_timeout 	:= l_tp_level_method_timeout;
g_tp_copy_paste_size 		:= l_tp_copy_paste_size;
g_manual_java_threads 		:= l_manual_java_threads;
g_batch_java_threads 		:= l_batch_java_threads;
g_total_update_pool 		:= l_total_update_pool;
g_maxdbconnections 		:= l_maxdbconnections;
g_maxupdatethreads 		:= l_maxupdatethreads;
g_dbidletimeout 		:= l_dbidletimeout;

---- Worksheet Specific
g_ws_data_comb_block_size 	:= l_ws_data_comb_block_size;
g_worksheet_full_load 		:= l_worksheet_full_load;
g_ct_worksheet_calcSummaryExp 	:= l_ct_worksheet_calcSummaryExp;
g_ct_uilimitations_maxcells 	:= l_ct_uilimitations_maxcells;
g_ct_uilimitations_maxcells_ws 	:= l_ct_uilimitations_maxcells_ws;
g_ct_uilimitations_maxcombs_ws 	:= l_ct_uilimitations_maxcombs_ws;
g_ct_uilimitations_maxdisk 	:= l_ct_uilimitations_maxdisk;
g_enableworksheetcaching 	:= l_enableworksheetcaching;
g_ct_uilimitations_warning 	:= l_ct_uilimitations_warning;
g_max_worksheet_db_weight 	:= l_max_worksheet_db_weight;

---- BLE Specific
g_blethreadpoolsize 	:= l_blethreadpoolsize;
g_bletimeout 		:= l_bletimeout;

--  sys_params
g_dynamic_hint_max_parallel_db 	:= l_dynamic_hint_max_parallel_db;
g_gatherstatisticsthreshold 	:= l_gatherstatisticsthreshold;
g_min_sales_date 		:= l_min_sales_date;
g_max_sales_date 		:= l_max_sales_date;
g_maxsalesgen 			:= l_maxsalesgen;
g_min_fore_sales_date 		:= l_min_fore_sales_date;

-- APPSERVERURL

-- URL and ACL configuration verification
--

g_appserverurl	:= l_appserverurl;
g_protocol	:= l_protocol;
g_slash		:= l_slash;
g_port1        	:= l_port1;
g_port2        	:= l_port2;
g_rest		:= l_rest;
g_host_name 	:= L_HOST_NAME;
g_privilege	:= l_privilege;
g_acl_name	:= l_acl_name;
g_acl_type	:= l_acl_type;
g_apps_version_max := l_apps_version_max;
g_appsurl_upgrade_date	:= l_appsurl_upgrade_date;
g_eng_appserverurl	:= l_eng_appserverurl;
g_eng_protocol		:= l_eng_protocol;
g_eng_slash		:= l_eng_slash;
g_eng_host_name		:= l_eng_host_name;
g_eng_port1		:= l_eng_port1;
g_eng_rest		:= l_eng_rest;
g_eng_platform		:= l_eng_platform;
g_enginebaseurl		:= l_enginebaseurl;
g_MSD_DEM_PROFILE_PROTOCOL	:= l_MSD_DEM_PROFILE_PROTOCOL;

g_appserverurl_stripped	:= l_appserverurl_stripped;
g_appserverurl_https 	:= l_appserverurl_https;
g_APPSERVERURL_FINAL 	:= L_APPSERVERURL_FINAL;
g_MSD_DEM_HTTP		:= L_MSD_DEM_HTTP;
--



debug('end Additional Code: Additional Validation');



  g_parameters.DELETE;

  -- Recreate global hash for parameters after validation (includes the modifiers)
debug('begin populate parameters hash table');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Schema Owner';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_schema_owner,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Middle Tier CPUs (extrapolated)';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_middle_tier_cpu,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Maximum Rows to Display';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_max_output_rows,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Debug Mode';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_debug_mode,'NO_MASK');
debug('end populate parameters hash table');



  l_key := g_parameters.first;
  -- Print parameters to the log
  l_step := '11';
  print_log(chr(10)||'Parameter Values after validation:');
  print_log('---------------------------');

  FOR i IN 1..g_parameters.COUNT LOOP
    print_log(to_char(i) || '. ' || g_parameters(i).pname || ': ' || g_parameters(i).pvalue);
  END LOOP;
  print_log('---------------------------');

  -- Create global hash of SQL token values
debug('begin populate sql tokens hash table');
   g_sql_tokens('##$$SCHEMA_OWNER$$##') := p_schema_owner;
   g_masked_tokens('##$$SCHEMA_OWNER$$##') := mask_text( g_sql_tokens('##$$SCHEMA_OWNER$$##'), 'NO_MASK');
debug('end populate sql tokens hash table');



  l_key := g_masked_tokens.first;
  -- Print token values to the log

  -- if max rows param is not set and does not have a default, g_max_output_rows might end up being -1. We don't want that.
  IF (g_max_output_rows <= 0) THEN
     print_log ('Max rows was not set and there is no default value for it. Defaulting to 20.');
     g_max_output_rows := 20;
  ELSIF (g_max_output_rows > 100000) THEN
     print_log ('Max rows was set too high. Defaulting to 100000.');
     g_max_output_rows := 100000;
  END IF;

  l_step := '12';
  print_log('SQL Token Values');

  WHILE l_key IS NOT NULL LOOP
    -- Ensure tokens do not contain invalid characters (EBSAF-263)
    g_sql_tokens(l_key) := filter_html(g_sql_tokens(l_key), 'I', 'D' );
    g_masked_tokens(l_key) := filter_html(g_masked_tokens(l_key), 'I', 'D' );

    -- Allow tokens to be masked in log (EBSAF-275)
    print_log(l_key||': '|| g_masked_tokens(l_key));
    l_key := g_masked_tokens.next(l_key);
  END LOOP;

EXCEPTION
  WHEN INVALID_PARAMETERS THEN
    print_error_args('Invalid parameters provided. Process cannot continue.', l_step);
    raise;
  WHEN INVALID_ESCAPE THEN
    print_error('INVALID ESCAPE: Regular expression search results are incorrect.' ||
        ' Calling method "' || g_rep_info('Calling From') || '" module "' || g_rep_info('Calling Module') || '".' );
    raise;
  WHEN OTHERS THEN
    print_error_args('Error validating parameters: '||sqlerrm, l_step);
    raise;
END validate_parameters;


---------------------------------------------
-- Load signatures for this ANALYZER       --
---------------------------------------------
PROCEDURE load_signatures IS
  l_info  HASH_TBL_4K;
BEGIN

null;

   -----------------------------------------
  -- Add definition of signatures here ....
  ------------------------------------------


debug('begin add_signature: CONCURRENT_USERS_ONLINE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6313',
      p_sig_id                 => 'CONCURRENT_USERS_ONLINE',
      p_sig_sql                => 'select count(*)
from 
( SELECT distinct osuser,  machine
  FROM v$session
  WHERE LOWER(PROGRAM) = ''jdbc thin client''
   AND TYPE = ''USER''
   AND STATUS = ''ACTIVE''
   AND SCHEMANAME = ''##$$SCHEMA_OWNER$$##'')',
      p_title                  => 'JDBC Thin Client concurrent users on line',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'JDBC Thin Client',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '12'
      );
   l_info.delete;
debug('end add_signature: CONCURRENT_USERS_ONLINE');



debug('begin add_signature: APPROVALPROCESSSCOPE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5455',
      p_sig_id                 => 'APPROVALPROCESSSCOPE',
      p_sig_sql                => 'select decode(pval,''0'',''Global scope - Approval series are added to every Worksheet (WS).'',
''1'',''Sales Data scope - series are added if other SALES_DATA series are explicitly or implicitly in the Worksheet (WS).'', ''2'',''No scope - series are NOT added.'',
''approvalprocessscope is null'') ApprovalProcessScope
from ##$$SCHEMA_OWNER$$##.sys_params
where lower(pname) = ''approvalprocessscope''',
      p_title                  => 'The scope of the forecast approval process',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'If you are using General Level worksheets that do not include any sales_data series, set the parameter from 0 to 1.<br>
This will have a positive performance impact, eliminating the join with sales_data.  Setting worksheet.full.load = 1 if using crosstab worksheets.<br>
The scope of the forecast approval process:<br>
0 - Global scope - Approval series are added to every WS.<br>
1 - Sales Data scope - series are added if other SALES_DATA series are explicitly or implicitly in the WS.<br>
2 - None scope - series are NOT added.',
      p_solution               => 'See [1201774/FAQ2686], Oracle Demantra Parameters for Performance',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: APPROVALPROCESSSCOPE');



debug('begin add_signature: CACHE SIZE CALCULATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8374',
      p_sig_id                 => 'CACHE SIZE CALCULATIONS',
      p_sig_sql                => 'select  round(sum(MB),2) "JVM MBytes" from 
(
select    
count(*) * 8 * 
  (select num_rows from all_tables where owner = upper(''##$$SCHEMA_OWNER$$##'') and upper(table_name )  in (select upper( gtable) from ##$$SCHEMA_OWNER$$##.group_tables where group_table_id = group_id  ) ) /1024/1024  MB  
from ##$$SCHEMA_OWNER$$##.group_attributes  WHERE upper(ATTRIBUTE_TYPE) = ''NUM''
group by group_id
union 
select    
count(*) * 16 * 
  (select num_rows from all_tables where owner = upper(''##$$SCHEMA_OWNER$$##'') and upper(table_name )  in (select upper( gtable) from ##$$SCHEMA_OWNER$$##.group_tables where group_table_id = group_id  ) ) /1024/1024  MB  
from ##$$SCHEMA_OWNER$$##.group_attributes  WHERE upper(ATTRIBUTE_TYPE) = ''DATE''
group by group_id
union 
select    
count(*) * 64 * 
  (select num_rows from all_tables where owner = upper(''##$$SCHEMA_OWNER$$##'') and upper(table_name )  in (select upper( gtable) from ##$$SCHEMA_OWNER$$##.group_tables where group_table_id = group_id  ) ) /1024/1024  MB  
from ##$$SCHEMA_OWNER$$##.group_attributes  WHERE upper(ATTRIBUTE_TYPE) = ''CHAR''
group by group_id
union 
select num_rows * 200 / 1024 /1024  MB from all_tables where  owner = upper(''##$$SCHEMA_OWNER$$##'') and upper(table_name )  in (select upper( gtable) from ##$$SCHEMA_OWNER$$##.group_tables )
)',
      p_title                  => 'Cache_Size_Calculations',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Member caching is connected indirectly to the application performance.  It relates to the size of Java Virtual Machine (JVM). <br>
This calculates roughly how much memory all the levels will require during the application server startup, if we do not specify the level member caching. <br>
<span style="font-style: italic;">The more members loaded in startup of the Application server the more it will consume JVM memory.</span> <br>
',
      p_solution               => 'The goal is to minimize the memory size at the Application Server startup to avoid the need to add more RAM to the machine to increase JVM size. <br>
Level member caching objectives: <br>
• Limit the number of level members stored in memory <br>
• Preload level members on application server startup <br>
• CTO level members are not displayed on WS, these can be prevented from loading into cache <br>
<br>
Detailed descriptions can be found in&nbsp;Level Member Caching Purpose Performance Guidance [1627689/KB198247]
',
      p_success_msg            => 'This calculates roughly how much memory all the levels will require during the application server startup, if we do not specify the level member caching.  If you are experiencing worksheet loading issues please review the guidelines in Level Member Caching Purpose Performance Guidance [1627689/KB198247]',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: CACHE SIZE CALCULATIONS');



debug('begin add_signature: CHAINED_ROWS_PERCENT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5431',
      p_sig_id                 => 'CHAINED_ROWS_PERCENT',
      p_sig_sql                => 'select 
   substr(owner,1,25) Owner, 
   table_name, 
   pct_free, 
   pct_used, 
   avg_row_len,
   last_analyzed, 
   decode(num_rows, null, 0, num_rows) num_rows, 
   chain_cnt,
   round(((decode(chain_cnt,null,0,chain_cnt)/decode(num_rows,0,1,null,1)) * 100), 2) Frag_Pct
from all_tables
where owner = ''##$$SCHEMA_OWNER$$##''
and table_name in (''SALES_DATA'', ''MDP_MATRIX'', ''PROMOTION_DATA'')
and num_rows > 0
ORDER BY Frag_Pct desc',
      p_title                  => 'Chained Rows Percent',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'The presence of migrated or chained rows can severely affect performance.  Any statements that query, update or create chained rows will be adding I/O overhead to the system, impacting performance.  Demantra development suggests that you quickly identify and rectify situations involving chained rows.  Chained rows can also add overhead to the performance of indexes and full-table scans.',
      p_solution               => 'If you are on version greater than 7.3.1.3 you can use TABLE_REORG to reduce chaining.  If you are on a version before 7.3.1.4 you will need to either Rebuild the table having chained rows or create a new table using CREATE TABLE AS.  In either case consider increasing PCTFREE.<br>
See [1356886/KB294079], How to check Demantra Performance DataBase and Worksheet Parameters.<BR><BR>
If one follows the instructions in [1109438/KB197709] Oracle Demantra Shrink vs. Rebuild Schema Fragmentation/Chaining Elimination.
It will automatically reduce their chained rows, because all of the rows are re-inserted into a new table.<br>Another tip to help reduce chained rows --  increase the PCTFREE parameter on the table. This is best done as part of the table rebuild.<br><br>
- Row migration is typically caused by UPDATE operation<br>
- Row chaining is typically caused by INSERT operation<br>
- SQL statements which are creating/querying these chained/migrated rows will degrade the performance due to more I/O work<br>
- To diagnose chained/migrated rows use ANALYZE command , query V$SYSSTAT view and USER_TABLES<br>
- To remove chained/migrated rows use higher PCTFREE using ALTER TABLE MOVE, Import/export<br>
- In most cases chaining is unavoidable, especially when this involves tables with large columns such as LONGS, LOBs, etc. When you have a lot of chained rows in different tables and the average row length of these tables is not that large, then you might consider rebuilding the database with a larger blocksize.<br>
- Tables with more than 255 columns can potentially *force* Chaining
',
      p_success_msg            => 'There are no statistics available in DBA_TABLES.  This indicates that you have not analyzed this schema.  Analyze this schema and review the results.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '13'
      );
   l_info.delete;
debug('end add_signature: CHAINED_ROWS_PERCENT');



debug('begin add_signature: CLIENT.UILIMITATIONS.WARNING PARAMETER');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8264',
      p_sig_id                 => 'CLIENT.UILIMITATIONS.WARNING PARAMETER',
      p_sig_sql                => 'select 
(select decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'')
from ##$$SCHEMA_OWNER$$##.aps_params
where lower(pname) = ''client.uilimitations.maxcombs.ws'') value1,
(select decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'')
from ##$$SCHEMA_OWNER$$##.aps_params
where lower(pname) = ''client.uilimitations.warning'') value2,
(((select decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'')
from ##$$SCHEMA_OWNER$$##.aps_params where lower(pname) = ''client.uilimitations.maxcombs.ws'')
*
(select decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'')
from ##$$SCHEMA_OWNER$$##.aps_params where lower(pname) = ''client.uilimitations.warning'')) * .01) "Combinations"
from ##$$SCHEMA_OWNER$$##.aps_params
where lower(pname) = ''client.uilimitations.warning''
and decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'') <> 80',
      p_title                  => 'Worksheet Maximum Combinations Percentage',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This parameter is the percentage of the parameter client.uilimitations.maxcombs.ws for which to display the warning messages.  Warning message displayed in worksheet is:<br>
The current settings will return a large amount of data and take a long  time to run.  To improve performance, modify aggregation levels and select additional filters before running the worksheet',
      p_solution               => 'The percentage out of the client.uilimitations.maxcombs at which to display the warning messages. (If max combs is 1000 and this value is 80(%) then when trying to load 800 combinations - will display warning messages to client).<br>
If user has entered 0, it is ignored and the default value is used instead.<br>
If this value is 100, no warnings will be displayed, since the error messages precedes it.
See [980023/KB649809] Page Loading Was Cancelled Message In Demantra Worksheets
  
To change the value of this parameter,to avoid warning<br>
Please open Business Modeler:<br>
1) Choose Parameters menu. <br>
2) Choose System Parameters.<br>
3) Click on Application Server tab.<br>
4) Clike on Collaborator tab.<br>
5) Scroll down to parameter client.uilimitations.warning.<br>
6) Set the value and Save.<br>
7) Bounce (restart) the application server.<br>
8) Run the worksheet using the updated value.',
      p_success_msg            => 'client.uilimitations.warning is to set warning to retrieve worksheet combinations to avoid performance issues.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: CLIENT.UILIMITATIONS.WARNING PARAMETER');



debug('begin add_signature: COMBINATIONS_DATE_RANGE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5436',
      p_sig_id                 => 'COMBINATIONS_DATE_RANGE',
      p_sig_sql                => 'select *
from
(SELECT ITEM_ID,LOCATION_ID FROM (
 SELECT ITEM_ID,LOCATION_ID,FROM_DATE,UNTIL_DATE FROM ##$$SCHEMA_OWNER$$##.MDP_MATRIX
 UNION
 SELECT ITEM_ID,LOCATION_ID, MIN(SALES_DATE), MAX(SALES_DATE) FROM ##$$SCHEMA_OWNER$$##.SALES_DATA
 GROUP BY ITEM_ID,LOCATION_ID)
 GROUP BY ITEM_ID,LOCATION_ID
 HAVING COUNT(*) > 1
 ORDER BY ITEM_ID,LOCATION_ID)
where ROWNUM <= 250',
      p_title                  => 'Combinations Min/Max Date Range Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are rows in MDP_MATRIX that are outside of the SALES_DATA min/max sales_date date range.  Combinations are being filtered out depending on whether they have any sales_data records in the historical time frame selected.  ',
      p_solution               => 'This confirms that you have forecast entries that are outside of the FROM_DATE and UNTIL_DATE range.   During the EP_LOAD process MDP_ADD is updating mdp_matrix cache dates for new or updated SALES_DATA rows.  INSERT_UNITS is run as part of the forecast engine run.  The worksheets and export views both use the FROM_DATE and UNTIL_DATE columns to determine the correct population to include in their queries.<br>
See [969874/KB530264], Not all Members being included in the Demantra Worksheet, Export View is not including all rows.',
      p_success_msg            => 'There are no rows outside of the sales_date min(sales_date) - max(sales_date) in mdp_matrix.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: COMBINATIONS_DATE_RANGE');



debug('begin add_signature: DEAD_COMBINATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5423',
      p_sig_id                 => 'DEAD_COMBINATIONS',
      p_sig_sql                => 'SELECT round(decode((select count(*) from ##$$SCHEMA_OWNER$$##.mdp_matrix where nvl(prediction_status,''0'') = ''99''),0,1,(((select count(*) 
    from ##$$SCHEMA_OWNER$$##.mdp_matrix where nvl(prediction_status,''0'') = ''99'') / 
    (select count(*) from ##$$SCHEMA_OWNER$$##.mdp_matrix)) * 100))) "Percent Dead"
    from dual',
      p_title                  => 'DEAD_COMBINATIONS',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'MDP_MATRIX contains at least 20 percent of dead combinations.  These rows have prediction_status = 99.    Verify Proport configuration and the last_date_backup setting of the system compared to max_sales_date where quantity form > 0.',
      p_solution               => 'Please see the technical paper describing this issue provided in [1921705/KB245544] Baseline Forecast - Analyze and Verify Forecast Tree, Forecast Results Plus a Very Nice Engine Startup Issues and Errors',
      p_success_msg            => 'You have less than 20% of dead combinations in MDP_MATRIX.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: DEAD_COMBINATIONS');



debug('begin add_signature: DEM_ LRU_CACHE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '7814',
      p_sig_id                 => 'DEM_ LRU_CACHE',
      p_sig_sql                => 'Select  pname "Parameter" , 
decode(value_number,null,decode(default_number,null,''null'',default_number),value_number) Value
from ##$$SCHEMA_OWNER$$##.aps_params 
where lower(pname) = ''client.uilimitations.maxdiskspace'' 
and decode(value_number,null,decode(default_number,null,''null'',default_number),value_number) <> 200000',
      p_title                  => 'LRU Cache - client.uilimitations.maxdiskspace',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'client.uilimitations.maxdiskspace was implemented to maintain reasonable performance as well as stability of the client application.  Maximum disk space allowed to be used by the LRU Disk Cache in Kb.  The least recently used combinations are written to local disk instead of being removed completely from the memory cache.
',
      p_solution               => 'The client.uilimitations.maxdiskspace parameter is default set to 200MB.  This setting does not need to be changed unless issues of disk size arise.  The worksheet parameters are describe in Clarify Worksheet Related Parameters [1133303/KB427167].  If you have been instructed to set this parameter outside of the default please be aware of the possible impact as discussed in [1133303/KB427167].',
      p_success_msg            => 'This parameter is set to the default, typically recommended, value.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: DEM_ LRU_CACHE');



debug('begin add_signature: ENABLEWORKSHEETCACHING');
   l_info('##MASK##2'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8370',
      p_sig_id                 => 'ENABLEWORKSHEETCACHING',
      p_sig_sql                => 'select user_id, user_name "NO worksheet cache"
from ##$$SCHEMA_OWNER$$##.user_id 
where can_create_cw = 0
and exists (select pval
from ##$$SCHEMA_OWNER$$##.sys_params  
where pname = ''EnableWorkSheetCaching''
and  pval = ''1'')',
      p_title                  => 'Enabling Worksheet Caching for User Name Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The list of users returned are not permitted to create cached worksheets.',
      p_solution               => '<b>Default Worksheet Caching Behavior</b><br>
By default, all
users can create cached Worksheets. However, a system administrator can
revoke this privilege for specific users.<br>
To do this, the administrator must modify the CAN_CREATE_CW column on
the USER_ID table (this table contains one row for each User). This
setting is not visible in Business Modeler; therefore it must be
updated directly in the database.<br>
Set the CAN_CREATE_CW column to:<br>
<ul>
  <li>0 (or null) to indicate that the user cannot create cached
Worksheets.</li>
  <li>1 to indicate that the user can create cached Worksheets
(this is the default).</li>
</ul>
Enabling Worksheet Caching<br>
Steps to enable worksheet caching:<br>
<ul>
  <li>Verify that the System Parameter EnableWorkSheetCaching is
set to
True (Business Modeler &gt; Parameters &gt; System Parameters).</li>
  <li>For each Worksheet that you want to cache, open Worksheet
Designer
(Display section) and then select Cache Worksheet Data.</li>
  <li>Set Refresh Type to either Manual or Automatic:<br>
Manual: Users must manually refresh the cache.<br>
Automatic: Changes to source data will be detected when the worksheet
is opened and the cache will automatically be refreshed as needed.</li>
</ul>
Oracle Demantra Worksheets Caching, Details how the Caching
Functionality can be Leveraged to Potentially Increase Performance
[1627652/KB197810]<br>
Additional note on How To Setup Worksheet Automatic Caching. Quick Steps. Technical Details [1435201/KB483581]',
      p_success_msg            => 'There are no users blocked from creating cached worksheets.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: ENABLEWORKSHEETCACHING');



debug('begin add_signature: GROUP_TABLES_TABLE_INCORRECT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '15021',
      p_sig_id                 => 'GROUP_TABLES_TABLE_INCORRECT',
      p_sig_sql                => 'SELECT TABLE_LABEL, 
GTABLE, 
GROUP_TYPE
FROM ##$$SCHEMA_OWNER$$##.GROUP_TABLES
WHERE MDP_SEARCH_TABLE IS NULL',
      p_title                  => 'GROUP_TABLES TABLE has INCORRECT data',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'When attempting to edit any Workflow or open any worksheet it fails with ERROR appserver.error: java.lang.NullPointerException',
      p_solution               => '[1578406/KB322994] Java.io.IOException: Server Returned HTTP Response Code: : 500<br>
The errant data in GROUP_TABLES needs to be updated.',
      p_success_msg            => 'The GROUP_TABLES data is verified as correct.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: GROUP_TABLES_TABLE_INCORRECT');



debug('begin add_signature: MAX_SALES_DATE_POPULATE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5520',
      p_sig_id                 => 'MAX_SALES_DATE_POPULATE',
      p_sig_sql                => 'select to_char(to_date(pval, ''MM-DD-YYYY HH24:MI:SS''))
from ##$$SCHEMA_OWNER$$##.sys_params
where lower(pname) = ''max_sales_date''
and to_char(to_date(pval, ''MM-DD-YYYY HH24:MI:SS'')) != (select to_char(to_date(value_date, ''DD-MON-YYYY'')) from ##$$SCHEMA_OWNER$$##.init_params_0 where lower(pname) = ''last_date_backup'')',
      p_title                  => 'Verify correct population of MAX_SALES_DATE_POPULATE',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The value of sys_params.max_sales_date is compared to init_params.last_date_backup.  If it is not equal there is an issue that needs to be addressed.',
      p_solution               => 'Please see [1355195/KB217311]  ENGINE Warning FillMissingDates() .. no causal or INSERT_UNITS was Not Run.
',
      p_success_msg            => 'The sys_params.max_sales_date should be equal to init_params.last_date_backup.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: MAX_SALES_DATE_POPULATE');



debug('begin add_signature: MAX_SALES_DATE_SALES_DATA');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5451',
      p_sig_id                 => 'MAX_SALES_DATE_SALES_DATA',
      p_sig_sql                => 'select max(sales_date) "Max Sales Date" from ##$$SCHEMA_OWNER$$##.sales_data',
      p_title                  => 'Maximum SALES_DATE in SALES_DATA table',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This is the MAX(SALES_DATE) from the SALES_DATA table.  Rows returned here show data created in the future. If a different maximum SALES_DATE is expected in the SALES_DATA table, see the note below.',
      p_solution               => 'see [1467517/KB565283]. How to Control the MAX_SALES_DATE When Collecting Future Demand.',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: MAX_SALES_DATE_SALES_DATA');



debug('begin add_signature: MIN_DATE_SALES_DATA');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5453',
      p_sig_id                 => 'MIN_DATE_SALES_DATA',
      p_sig_sql                => 'select min(sales_date) "Min_Sales_Date" from ##$$SCHEMA_OWNER$$##.sales_data',
      p_title                  => 'Minimum SALES_DATE in SALES_DATA',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Verify the existing history that could be archived.',
      p_solution               => 'See [1423486/KB428908], How to Setup Series. Copy Series. Display in a worksheet. Aggregation.',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: MIN_DATE_SALES_DATA');



debug('begin add_signature: MISSING_SALES_DATA');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5447',
      p_sig_id                 => 'MISSING_SALES_DATA',
      p_sig_sql                => 'select (nullif(count(*),0)) "Qty_Missing"
from ##$$SCHEMA_OWNER$$##.sales_data
where sales_date not in (select datet from ##$$SCHEMA_OWNER$$##.inputs)',
      p_title                  => 'Missing dates in SALES_DATA',
      p_fail_condition         => '[Qty_Missing] > [0]',
      p_problem_descr          => 'This confirms that you have missing dates between SALES_DATA and available dates registered in INPUTS table.  The forecasting process requires all of the sales_date dates must be a date from datet field of inputs table.<br>
Please clarify why rows were added to the sales_data table.  Perhaps manual inserts or a time bucket was changed.<br>
See solution below.

',
      p_solution               => 'See [1355195/KB217311], ENGINE Warning FillMissingDates() .. no causal or INSERT_UNITS was Not Run.<br>
Review point #8 specifically.',
      p_success_msg            => 'Success.  All the sales_date dates are a date from datet field of inputs table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: MISSING_SALES_DATA');



debug('begin add_signature: PRE_LOGON_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5480',
      p_sig_id                 => 'PRE_LOGON_CHECK',
      p_sig_sql                => 'SELECT pname,
       pval
FROM ##$$SCHEMA_OWNER$$##.db_params
WHERE (SUBSTR(pname,1,1) = ''_''
      OR pname LIKE ''nls_%''
      OR pname LIKE ''plpi_%''
      OR pname LIKE ''plp_%'')
AND pval IS NOT NULL',
      p_title                  => 'PRE Logon Settings if present',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Parameters can be set upon Demantra log in.  These are known as pre_logon parameters.  ',
      p_solution               => 'They can also be added to the DB_PARAMS table as new pre_logon parameters with the prefix of plpi_<br><br>
plpi = pre_logon parameter using integer value<br>
plp  = pre_logon parameter using string  value<br><br>
See [1906641/KB311795], Performance Issue With Chaining After Upgrade To 12.2.3.',
      p_success_msg            => 'There are no pre_logon parameters set.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: PRE_LOGON_CHECK');



debug('begin add_signature: SERIES CONFIGURATION');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8506',
      p_sig_id                 => 'SERIES CONFIGURATION',
      p_sig_sql                => 'select COMPUTED_TITLE "Series Name" from ##$$SCHEMA_OWNER$$##.COMPUTED_FIELDS
  where DBNAME IS NOT NULL
  AND LOWER(DATA_TABLE_NAME) = ''branch_data''
  AND FORECAST_TYPE_ID not in (select ser.FORECAST_TYPE_ID from ##$$SCHEMA_OWNER$$##.QUERIES q, ##$$SCHEMA_OWNER$$##.ACTIVE_SERIES SER where q.QUERY_ID  =SER.QUERY_ID)
  AND FORECAST_TYPE_ID not in (select tqs.series_id from ##$$SCHEMA_OWNER$$##.Transfer_Query_Series tqs, ##$$SCHEMA_OWNER$$##.Transfer_Query tq where tqs.ID = tq.id )
  AND FORECAST_TYPE_ID NOT in  (select source_series from ##$$SCHEMA_OWNER$$##.rolling_profiles)
  AND FORECAST_TYPE_ID NOT in  (select target_series from ##$$SCHEMA_OWNER$$##.rolling_profiles)
  AND FORECAST_TYPE_ID NOT in  (select FORECAST_TYPE_ID from ##$$SCHEMA_OWNER$$##.COMPUTED_FIELDS_BASE)',
      p_title                  => 'SERIES Configuration',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There is an upper limit to the number of columns in the sales_data table which is 1000.<br><br>
Every time a custom series is created on the sales_data table, it adds a column to the sales_data table which takes up a column in the sales_data table ',
      p_solution               => 'It is advised that you use more of the seeded series.<BR>
If the query returns less than 50 rows then consider removing some unused series.<br>
The customer needs to review which series are not in use and cleanup accordingly.<br><br>
Refer [1359843/KB366225] Limitation On Number Of Columns Sales_data Table - Not Allowing Series Creation',
      p_success_msg            => 'Series are configured to within recommended tolerance.  For example: Adding 300+ new series is not best practice.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: SERIES CONFIGURATION');



debug('begin add_signature: UI_WORKSHEET_LIMITATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5439',
      p_sig_id                 => 'UI_WORKSHEET_LIMITATIONS',
      p_sig_sql                => 'select pname "Parameter",
decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) "Value"
from ##$$SCHEMA_OWNER$$##.aps_params
where lower(pname) in (''client.uilimitations.maxcombs.ws'',''client.uilimitations.maxcells.ws'',''client.uilimitations.maxcells'',
   ''client.uilimitations.maxdiskspace'',''client.uilimitations.warning'',''max.worksheet.db.weight'',
   ''worksheetbeancontentprovider.membercombinationslimit'')
   and 
   ((lower(pname) = ''client.uilimitations.maxcombs.ws'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 200000)
     or
   (lower(pname) = ''client.uilimitations.maxcells.ws'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
     or
   (lower(pname) = ''client.uilimitations.maxcells'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
     or
   (lower(pname) = ''client.uilimitations.maxdiskspace'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 200000)
     or
   (lower(pname) = ''client.uilimitations.warning'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 80)
     or
   (lower(pname) = ''max.worksheet.db.weight'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != .5)
     or
   (lower(pname) = ''worksheetbeancontentprovider.membercombinationslimit'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 4)
     or
   (lower(pname) = ''Query.MaxCombinations'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 10))',
      p_title                  => 'User Interface Limitations Parameters',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The parameters that impact worksheet performance have been changed from the default settings.  If you need to return to the default settings, see below.<br>
Default Values:<br>
client.uilimitations.maxcombs.ws = 2000 is typically recommended. 200000 is the default.<br>
client.uilimitations.maxcells.ws = 100000 is typically recommended. 300000 is the default.<br>
client.uilimitations.maxcells = 300000<br>
client.uilimitations.maxdiskspace = 200000<br>
client.uilimitations.warning = 80<br>
max.worksheet.db.weight = .5<br>
worksheetbeancontentprovider.membercombinationslimit = 4<br>
Query.MaxCombinations = 10<br>',
      p_solution               => 'See [1072163/KB350419], Does Demantra Have a Limit on the Number of Combinations.  Returning the values to default and retesting may prove beneficial.',
      p_success_msg            => 'No issue found. This means Success.  The following parameters were verified:<br><br>
    client.uilimitations.maxcombs.ws = 2000<br>
    client.uilimitations.maxcells.ws = 100000<br>
    client.uilimitations.maxcells = 300000<br>
    client.uilimitations.maxdiskspace = 200000<br>
    client.uilimitations.warning = 80<br>
    max.worksheet.db.weight = .5<br>
    worksheetbeancontentprovider.membercombinationslimit = 4<br>
    Query.MaxCombinations = 10',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: UI_WORKSHEET_LIMITATIONS');



debug('begin add_signature: UPDATE_COMBINATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5444',
      p_sig_id                 => 'UPDATE_COMBINATIONS',
      p_sig_sql                => 'select trunc(pval) "Update_Dead_Comb",
    decode(pval,''0'',''update only when prediction_status = 1,97,98 and 99 if it has historical rows'',
              ''1'',''update only when prediction_status = 1,97,98,99'',
              ''2'',''update only when prediction_status = 1,97,98 (never update 99)'',
              ''update_dead_comb not set.  This will not be forecasted.'') "Dead Combo Impact"
from ##$$SCHEMA_OWNER$$##.sys_params
where lower(pname) = ''update_dead_comb''',
      p_title                  => 'Updateable Combinations',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Combinations that can be updated by prediction_status based on Update_Dead_Comb.<br>
Based on the setting of sys_params.update_dead_comb, combinations will be updated.<br>
Dead Combo Impact:<br><br>
0 - We update all combinations where prediction_status update only 1,97,98 and 99 if the 99 has historical rows <br>
1 - We update all combinations where prediction_status update= update 1,97,98,99.  All combinations, even those with a prediction_status of 99 (dead), will be updated; i.e. they will be allocated a forecast.<br>
2 - Update only 1,97,98 (never update 99)',
      p_solution               => 'See [1509754/KB197533], The Column Prediction_Status, MDP_Matrix and Engine. How are they Related?',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: UPDATE_COMBINATIONS');



debug('begin add_signature: WORKSHEET.DATA.COMB.BLOCK_SIZE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '7883',
      p_sig_id                 => 'WORKSHEET.DATA.COMB.BLOCK_SIZE',
      p_sig_sql                => 'select pname "Parameter", 
decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl(default_string,''null''), value_string), ''null'') "Value" 
from ##$$SCHEMA_OWNER$$##.aps_params 
where lower(pname) = ''worksheet.data.comb.block_size''
and decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl(default_string,''null''), value_string), ''null'') > 0',
      p_title                  => 'Block of Combinations in one Select',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This parameter controls the block size for worksheet data retrieval.  Indicates whether we retrieve all WS Combinations in one SQL (value=0) or with a block of Combinations in the SQL (value > 0).<br>
This setting is appropriate for crosstab worksheets.  That is, worksheets in which the levels and their combinations are displayed within the table vs. as dropdowns or within the members browser.<br>
The default is 0 or with a block of Combinations in the returned SQL results.',
      p_solution               => 'This parameter is set to retrieve combinations by levels for crosstab type implementation.  If there are performance issues retrieving the worksheet data please set to 0 (zero) and test.<br>
Information on worksheet performance can be found in [1356886/KB294079] : How to check Demantra Performance DataBase and Worksheet Parameters.<br><br>
To change the value of this parameter, please open Business Modeler:<br>
1) Choose Parameters menu. <br>
2) Choose System Parameter.<br>
3) Click on Application Server tab.<br>
4) Scroll down to parameter worksheet.data.comb.block_size.<br>
5) Set the value and Save.<br>
6) Bounce (restart) the application server.<br>
7) Run the worksheet using the updated value. ',
      p_success_msg            => 'worksheet.data.comb.block_size is set to retrieve all combinations for each level.  If there are performance issues please consider setting this value to 0 (zero) and test.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: WORKSHEET.DATA.COMB.BLOCK_SIZE');



debug('begin add_signature: Worksheet Parallel Hints');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '7546',
      p_sig_id                 => 'Worksheet Parallel Hints',
      p_sig_sql                => 'select q.query_name, wh.data_hint, wh.population_hint 
from ##$$SCHEMA_OWNER$$##.WORKSHEET_HINTS wh, ##$$SCHEMA_OWNER$$##.queries q
where wh.query_id = q.query_id',
      p_title                  => 'Worksheet Parallel Hints',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Some worksheets access a large amount of data which can cause slow rendering.  A parallel hint can be implemented to improve performance for such worksheets.  A hint specifies the number of threads used by the worksheet query and can be applied to two parts of the worksheet: generation of the combinations and retrieval of data to be displayed in the worksheet.<br>
Setting a hint requires manually adding a row to the WORKSHEET_HINTS table.',
      p_solution               => 'No worksheet hints were added for worksheets with large amounts of data in order to improve performance.<br>
[2085264/KB198441] Advanced DM Training - Demantra UI Best Practices - This is Part 1 of 10. Course Index<br>
[2085286/KB197879] Advanced DM Training - Demantra UI Best Practices.',
      p_success_msg            => 'There is a parallel hint enabled in the WORKSHEET_HINTS table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: Worksheet Parallel Hints');



debug('begin add_signature: CAUSAL_FACTOR_LIST');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8200',
      p_sig_id                 => 'CAUSAL_FACTOR_LIST',
      p_sig_sql                => 'select FACTOR_ID,
       FACTOR_NAME "Name", 
       substr(COMMENTS,1,40) "Comments",
       FACTOR_TYPE,
       substr(LOCAL_FUNCT,1,20) "Local_funct",
       DAILY_VAL "DVAL",
       MONTHLY_VAL "MVAL",
       NON_SEASONAL_VAL "NSVAL",
       FILL_CAUSALS "FILL",
       SHAPE_INDICATOR "SHAPE",
       OMIT_SEASONAL "OMIT",
       IGNORE "IGN",
       substr(TRANSPOSE_FUNCTION, 1, 20) "Transpose_funct",
       ENGINE_PROFILES_ID 
from ##$$SCHEMA_OWNER$$##.causal_factors 
where factor_type is null',
      p_title                  => 'Causal Factors',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The column factor_type cannot be null.  This will cause errors during the engine run.',
      p_solution               => 'Either of the following can be implemented:<br><br>

1. Define these causal properly and make sure that the factor_type is selected <br>
or<br>
2. Remove these causal factors.<br><br>
Please see [2188505/KB619664]  Engine Fails with "WARNING Number of local CF in agri sql and local causal filter differs" WARNING Number of local CF 10 != 11',
      p_success_msg            => 'There are no causal factors where the column factor_type is null.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: CAUSAL_FACTOR_LIST');



debug('begin add_signature: DEMANTRA_NON-DUPLICATE_BASE_LEVELS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '19608',
      p_sig_id                 => 'DEMANTRA_NON-DUPLICATE_BASE_LEVELS',
      p_sig_sql                => 'select count(t_ep_asset_group_ep_id) as qty, item_status "Affected Rows Count"
from ##$$SCHEMA_OWNER$$##.items
where t_ep_asset_group_ep_id <> 0
group by item_status
union
select count(t_ep_class_code_ep_id) as qty, item_status "Affected Rows Count"
from ##$$SCHEMA_OWNER$$##.items
where t_ep_class_code_ep_id <> 0
group by item_status',
      p_title                  => 'Data Load Default Value Check to Avoid Duplicates ',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This is due to the fact that two new levels in the standard item hierarchy - Class code and Asset group.  These two new levels are now included in ep_load_items to determine if an item being imported is a new combination or not.  The Demantra upgrade initialized all existing items in Demantra with the value ''Default''.  However, the Demantra integration is populating the values as ''N/A''.  As a result, when existing items are imported through the integration, the items are erroneously being considered as new items.',
      p_solution               => 'Default values require reset to avoid duplicate rows during import.  Please see [2025954/KB383878] Upgrading from Demantra 7.3.1.x to 12.2.x? This can produce duplicate rows. There are two ways to solve. See patch 21089579 and the details in this note',
      p_success_msg            => 'There are NO default level values that require adjustment.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: DEMANTRA_NON-DUPLICATE_BASE_LEVELS');



debug('begin add_signature: DUPLICATE_COLLECTED_DATA');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '13805',
      p_sig_id                 => 'DUPLICATE_COLLECTED_DATA',
      p_sig_sql                => 'select inventory_item_id,
 organization_id,
 category_set_id,
 category_id
 , count(*)
 from mtl_item_categories
 where exists (
select inventory_item_id,
organization_id,
category_set_id,
category_id
, count(*)
from mtl_item_cats_sn
group by
inventory_item_id,
organization_id,
category_set_id,
category_id
having count(*) > 1
)
 group by
 inventory_item_id,
 organization_id,
 category_set_id,
 category_id
 having count(*) > 1',
      p_title                  => 'Duplicates After Shipment - Booking History Collection',
      p_fail_condition         => 'RS',
      p_problem_descr          => '<BR>Executed the following steps:<BR>
-------------------------------<BR>
1) Run Shipment & Booking History Collections to collect data into Demantra.<BR>
2) Modify the name of one of the customer, for which data has been collected into Demantra, in EBS.<BR>
3) Run Shipment & Booking History Collections to collect data into Demantra again.<BR>

A new Customer entry gets created in Demantra, resulting in Duplicate Customer.  This can exist for several data entities for example customer site.',
      p_solution               => 'Please see My Oracle Support note:
[1312493/KB224322], Customer Name is Renamed and Again Collected into Demantra Running Shipment & Booking History Collections, a Duplicate row is Created for the Same Customer.',
      p_success_msg            => 'There are no duplicate data entities present in collected data.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: DUPLICATE_COLLECTED_DATA');



debug('begin add_signature: DUPLICATE RELATION VALUE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '7428',
      p_sig_id                 => 'DUPLICATE RELATION VALUE',
      p_sig_sql                => 'select distinct ERROR_MESSAGE_RECORD from ##$$SCHEMA_OWNER$$##.t_src_item_tmpl_err where  ERROR_MESSAGE_RECORD like  ''Duplicate relation value%'' and load_date > sysdate - 7
union
select distinct ERROR_MESSAGE_RECORD from ##$$SCHEMA_OWNER$$##.t_src_loc_tmpl_err where  ERROR_MESSAGE_RECORD like  ''Duplicate relation value%''  and load_date > sysdate - 7',
      p_title                  => 'Duplicate relation value in error tables.',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Duplicate data is rejected to the error tables with the Duplicate relation value error message.
Items and locations are not getting loaded into demantra application from EBS or other ERP sources.',
      p_solution               => 'This error message is the result of the child to parent, one to many, rule being violated.  
In order to correct data that is loaded into Demantra, please see [1956556/KB294802] Duplicate relation value - XXX error message in Demantra error table .',
      p_success_msg            => 'There are no Duplicate relation value errors.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: DUPLICATE RELATION VALUE');



debug('begin add_signature: FORECAST_HISTORY_STATUS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5450',
      p_sig_id                 => 'FORECAST_HISTORY_STATUS',
      p_sig_sql                => 'select decode(status,-2,''Never Executed'',-1,''Engine Manager Initialize'',0,''Engine Running Normal'', 1, ''Successful Completion'', 2, ''Configuration Problems'', null) Status,
          time_sig,
          lead,
          last_date,
          start_date,
          last_forecast_date,
          fore_column_name,
          start_forecast_date,
          init_params_table_name,
          engine_profiles_id
   from  ##$$SCHEMA_OWNER$$##.forecast_history
  where time_sig > sysdate - 365
   order by time_sig desc',
      p_title                  => 'FORECAST_HISTORY Analysis',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The status column in the forecast_history table indicates when the Demantra forecast appears to have been generated.',
      p_solution               => 'See [848205/KB197095], No Demantra Forecast Generated - Common Issues.<br><br>
The status column definition:<br>
-2: Engine was never executed<br>
-1: Engine manager is doing some initialization for engine to run<br>
 0: Engine is running normally<br>
 1: Engine run has completed successfully<br>
 2: configuration problems<br><br>
Lead: The number of future time buckets to forecast out into the horizon<br>
Last_Date:  The sales_date value in the sales_data table that represents the last period of demand in the database.  Last date of actual sales, to be used by the Analytical Engine and the proport mechanism.  No dates after this are used towards the forecast or the proport calculation.<br>
Start_Date: The beginning of forecast history.  The data used to generate the future forecast will begin on this date.<br>
Last_Forecast_Date:  The sales_date value in the sales_data table that represents the period with the furthest amount of sales of demand in the database.  The value should be the value in the Last_Date column plus the Lead column value.<br><br>
If you see that there are no forecast buckets, it would be expected that the Last_Forecast_Date would be equal to the Last_Forecast_Date or at least that the Last_Forecast_Date is not equal to the Last_Date plus the Lead value.<br>
Start_Forecast_Date: This is the first date of the future forecast that is to be generated.',
      p_success_msg            => 'There are no forecast_history entries older than 365 days.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '15'
      );
   l_info.delete;
debug('end add_signature: FORECAST_HISTORY_STATUS');



debug('begin add_signature: FORECAST_LEVEL_STRUCTURE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5445',
      p_sig_id                 => 'FORECAST_LEVEL_STRUCTURE',
      p_sig_sql                => 'SELECT  level_id "Level_ID", count(*) "Count"
   FROM ##$$SCHEMA_OWNER$$##.mdp_matrix
   WHERE do_fore = 1 
   AND prediction_status = ''1''
   GROUP BY level_id
   order by level_id',
      p_title                  => 'Forecast Structure by level_id',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The level of the Forecast Tree where the forecast is being generated.  This is the nodal tree structure.  
Having a majority of combinations higher on the forecast tree may indicate either a poorly designed forecast tree and / or engine parameters that are too strict.
',
      p_solution               => 'Based on the results, adjust the Forecast Tree to see if choosing a different hierarchy might produce a better forecast for more combinations at a lower level.<br><br>
See [1632458/KB197499] Constructing an Effective Forecast Tree Using Correct Using Levels, Hierarchies, min_fore_level, max_fore_level and Proportion of Models.<br><br>
The treehierarchytest.exe can also be used to validate the forecast tree.<br>
We would like the engine to forecast at least 70% of the combinations in the min_fore_level and if it does not you are advised to revise the forecast tree or further tune the engine in new ways, to reach this desired target.',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: FORECAST_LEVEL_STRUCTURE');



debug('begin add_signature: FORECAST_TREE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8471',
      p_sig_id                 => 'FORECAST_TREE',
      p_sig_sql                => 'select f.forecast_level,
    nvl(G1.TABLE_LABEL, ''Highest Fictive Level'') "Item Level",
    g1.id_field  "Item ID field",
    nvl(G2.TABLE_LABEL, ''Highest Fictive Level'') "Location Level",
    g2.id_field  "Location ID field",
    decode (f.promotion_level_type, 1, ''Lowest Promotion Level'', 2, ''Lowest Promotion Level and Influence Group'' , 3, ''Influence Group'', 4, ''Influence Range'', null)  "Promotion Level Type"
from ##$$SCHEMA_OWNER$$##.forecast_tree f
left outer  join ##$$SCHEMA_OWNER$$##.items_levels i on f.item_level=i.item_level and 
f.engine_profiles_id=i.engine_profiles_id
left outer  join ##$$SCHEMA_OWNER$$##.loc_levels l on f.loc_level=l.loc_level and 
f.engine_profiles_id=l.engine_profiles_id
left outer  join ##$$SCHEMA_OWNER$$##.group_tables g1 on i.item_field=g1.group_table_id
left outer  join ##$$SCHEMA_OWNER$$##.group_tables g2 on l.loc_field=g2.group_table_id
where f.engine_profiles_id=1
order by f.forecast_level',
      p_title                  => 'Forecast Tree definition',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Analytical Engine aggregates the data to a higher level and tries to generate a forecast at that level. <br>
The purpose of the forecast tree is to organize data for this process.  Each node in the forecast tree aggregates both by items and by locations. ',
      p_solution               => 'There is no Forecast Tree set up for Batch engine profile.<br>
Please set up the Forecast Tree.<br>
<i>Reference:<BR>
[1921705/KB245544]: Baseline Forecast - Analyze and Verify Forecast Tree, Forecast Results Plus a Very Nice Engine Startup Issues and Errors',
      p_success_msg            => 'Analytical Engine aggregates the data to a higher level and tries to generate a forecast there. <br>
The purpose of the forecast tree is to organize data for this process. Each node in the forecast tree aggregates both by items and by locations. <br><br>
To change the Forecast Tree definition:<br>
&nbsp; &nbsp; &nbsp;1. Log into Business Modeler <br>
&nbsp; &nbsp; &nbsp;2. Navigate to Engine <br>
&nbsp; &nbsp; &nbsp;3. Forecast Tree<br>
&nbsp; &nbsp; &nbsp;4. Choose  the Engine Profile<br>
&nbsp; &nbsp; &nbsp;5. Set up / Modify the forecast tree definition.<br>
<br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: FORECAST_TREE');



debug('begin add_signature: PREDICTION_STATUS_ANALYSIS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5441',
      p_sig_id                 => 'PREDICTION_STATUS_ANALYSIS',
      p_sig_sql                => 'Select level_id "Level",
decode(prediction_status, 1,''Live or Active'',
                         96,''No Forecast'',
                         97,''Do not Forecast item/location'',
                         98,''Young'',
                         99,''Dead'') "Prediction Status",
count(*) "Count",
do_fore "Do Forecast",
do_aggri "Aggregate?",
aggri_98 "Aggregate Young?",
aggri_99 "Aggregate Dead?"
from ##$$SCHEMA_OWNER$$##.MDP_MATRIX
Group by level_id, prediction_status, do_fore, do_aggri, aggri_98, aggri_99
order by LEVEL_ID desc, PREDICTION_STATUS desc',
      p_title                  => 'Prediction_status Detailed Forecast Impact',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'MDP_MATRIX contains known combinations which are chosen by the engine, based in part by the prediction status.',
      p_solution               => 'Performance is directly impacted by the number of rows selected from this table.<br>
Prediction status controls how the Analytical Engine uses this combination.  Each combination has one of the following prediction status values:<br><br>
97 (Create Zero Forecast) A user has set do_fore equal to 2. This status means that the Analytical Engine will insert a Zero forecast for this combination but otherwise ignore it.<br>
98 (Young) Sales for this combination are too new to be used for prediction.<br>
99 (Dead) Sales for this combination are not recent enough to be used for prediction.<br>
1 (Live or Active) Neither young nor dead.<br><br>
Important - See [1509754/KB197533] The Column Prediction_Status, MDP_Matrix and Engine. How are they Related? Understand Prediction_status Values
',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: PREDICTION_STATUS_ANALYSIS');



debug('begin add_signature: PREDICTION_STATUS_IMPACT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5440',
      p_sig_id                 => 'PREDICTION_STATUS_IMPACT',
      p_sig_sql                => 'select substr(prediction_status,1,10) "Prediction Status", count(*) "Count"
from ##$$SCHEMA_OWNER$$##.MDP_MATRIX 
group by prediction_status',
      p_title                  => 'Prediction Status Summary',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The prediction_status column is a key column that controls the volume of forecast data that the engine is processing.  The prediction_status column is a key to understanding what the Demantra forecast engine will be processing.
',
      p_solution               => 'Controls how the Analytical Engine uses this combination. Each combination has one of the following prediction status values:<br>
96 (No Forecast) This status means that the Analytical Engine will completely ignore this combination.<br>
97 (Create Zero Forecast) --- A user has set do_fore equal to 2 manually.<br>
This status means that the Analytical Engine will insert a zero forecast for this combination but otherwise ignore it.<br>
98 (Young) -- Sales for this combination are too new to be used for prediction.<br>
99 (Dead) -- Sales for this combination are not recent enough to be used for prediction.<br>
1 (Live or Active) -- Neither young nor dead.<br><br>
The Analytical Engine ignores any young or dead combinations, except when it is necessary to aggregate<br><br>
See [1509754/KB197533], The Column Prediction_Status, MDP_Matrix and Engine. How are they Related? Understand Prediction_status Values.',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: PREDICTION_STATUS_IMPACT');



debug('begin add_signature: PURGE OLD DATA');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '7525',
      p_sig_id                 => 'PURGE OLD DATA',
      p_sig_sql                => 'select sales_date "Sales Date", count(*) "Nbr of Rows"
from ##$$SCHEMA_OWNER$$##.sales_data
where sales_date < sysdate -  730
group by sales_date
order by sales_date',
      p_title                  => 'PURGE OLD - UNUSED DATA',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'It is recommended to purge old, unused data from the schemas SALES_DATA table.  This signature reveals data older than 2 years from today.',
      p_solution               => 'It is recommended to purge old, unused data from the schemas SALES_DATA table.  This, currently, should be done as a user defined process, but in the future Demantra will provide its own archiving capabilities, as per [471211/FAQ2704] Demantra Have a Standard Procedure to Delete Old Data?

It is also important to purge old combinations from MDP_MATRIX.  For this, one can set the Mdp_AddDeleteUnlinkedMdp_Matrix parameter to TRUE and execute the MDP_ADD procedure.
',
      p_success_msg            => 'It is recommended to purge old, unused data from the schemas SALES_DATA table.  This, currently, should be done as a user defined process, but in the future Demantra will provide its own archiving capabilities, as per [471211/FAQ2704] Demantra Have a Standard Procedure to Delete Old Data?<br>

It is also important to purge old combinations from MDP_MATRIX.  For this, one can set the Mdp_AddDeleteUnlinkedMdp_Matrix parameter to TRUE and execute the MDP_ADD procedure.
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: PURGE OLD DATA');



debug('begin add_signature: TOP_LEVEL_MINUS_ONE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5519',
      p_sig_id                 => 'TOP_LEVEL_MINUS_ONE',
      p_sig_sql                => 'select t_ep_ebs_prod_cat_ep_id, t_ep_ebs_cust_class_ep_id, count(*)
from ##$$SCHEMA_OWNER$$##.mdp_matrix
where prediction_status = 1
group by t_ep_ebs_prod_cat_ep_id, t_ep_ebs_cust_class_ep_id
order by count(*) desc',
      p_title                  => 'The TLMO (the level just below the top level, called top level minus one), affects performance.',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Provide a general guideline on engine behavior regarding the baseline forecast generation.  Each engine task receives one or more nodes of the TLMO.  TLMO should have many nodes and ensure each node does not contain too many lowest level combinations.  1000 to 2000 active combinations per branch is ideal.
',
      p_solution               => 'The scope of this document is to provide a general line on engine behavior regarding the baseline forecast generation.<br>
The main points on those documents are:<br>
Forecast tree<br>
Forecast results<br>
Engine issues<br><br>
Please see [1921705/KB245544]  Baseline Forecast - Analyze and Verify Forecast Tree, Forecast Results Plus a Very Nice Engine Startup Issues and Errors',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: TOP_LEVEL_MINUS_ONE');



debug('begin add_signature: APPLICATION_SERVER_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5425',
      p_sig_id                 => 'APPLICATION_SERVER_PARAMETERS',
      p_sig_sql                => 'SELECT pname "Parameter",
   decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) "Value Number"
   from ##$$SCHEMA_OWNER$$##.aps_params
   where lower(pname) in (''maxdbconnections'', ''dbidletimeout'', ''threadpool.update.data.batch.size'', ''threadpool.update.table.manual.size'',
   ''threadpool.update.comb.manual.size'', ''threadpool.update.comb.batch.size'', ''threadpool.update.record.manual.size'',
   ''threadpool.update.record.batch.size'', ''threadpool.update.data.manual.size'', ''threadpool.update.table.batch.size'',
   ''threadpool.query_run.size'', ''threadpool.level_method.size'', ''threadpool.copy_paste.size'', ''threadpool.level_method.timeout'', ''threadpool.query_run.per_user'', ''threadpool.query_run.timeout'', ''maxupdatethreads'', ''threadpool.update.size'', ''threadpool.update.timeout'')
   and 
   ((lower(pname) = ''maxdbconnections'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 100)
    or
    (lower(pname) = ''DBIdleTimeOut'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
    or
    (lower(pname) = ''threadpool.update.data.batch.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
    or
    (lower(pname) = ''threadpool.update.table.manual.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
    or
    (lower(pname) = ''threadpool.update.comb.manual.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
    or
    (lower(pname) = ''threadpool.update.comb.batch.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
    or
    (lower(pname) = ''threadpool.update.record.manual.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
    or
    (lower(pname) = ''threadpool.update.record.batch.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
    or
    (lower(pname) = ''threadpool.update.data.manual.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 8)
    or
    (lower(pname) = ''threadpool.update.table.batch.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
    or
    (lower(pname) = ''threadpool.level_method.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 25)
    or
    (lower(pname) = ''threadpool.query_run.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 40)
    or
    (lower(pname) = ''threadpool.copy_paste.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 40)
    or
    (lower(pname) = ''threadpool.level_method.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000))',
      p_title                  => 'Application Server Parameter Default Value Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Configuring the Oracle Demantra Web Platform Server.  You may need to adjust the Web Platform Server parameters settings.  These are the defaults and recommendations for the application server.  They can be changed using the business modeler.
',
      p_solution               => 'For more information see [470852/KB197778], Oracle Demantra Worksheet Performance - A Technical Paper<br><br>
Parameter description and instructions:<br>
Increasing the comb.comb.batch.size should have biggest performance impact.  If there are more combinations than dates in the staging table use higher number for comb.batch.size, otherwise use higher number for record.batch.size.<br>
Watch carefully for database IO and CPU bottle necks. <br><br>
Number of threads generated should be: comb.comb.batch.size * record.batch.size<br>
If there is no CPU overload or IO overload bump up by 1, comb.comb.batch.size or record.batch.size, until you see good database throughput.<br>
Assuming the database is tuned, if one of these are over loaded you probably have reached the capacity of the database.<br><br>
maxdbconnections = 100: Number of concurrent users multiplied by 2<br>
DBIdleTimeOut = 300000 (5 minutes): This setting frees up unused database connections sooner, because they overstress the database.<br>
threadpool.update.data.batch.size = 2: Update threadpool data batch size.  The number of tasks to run in parallel when updating combinations.<br>
threadpool.update.data.batch.size and BLEThreadPoolSize should be the same.<br>
threadpool.update.table.manual.size = 2: Number of parallel manual update tables that the Applications server can handle per process.<br>
threadpool.update.comb.manual.size = 2: Number of parallel manual update combinations that the Applications server can handle per table.<br>
threadpool.update.comb.batch.size = 2: Number of parallel batch (Integration-Ble) update combinations that the Applications server can handle per table.<br>
threadpool.update.record.manual.size = 2: Number of parallel manual update records that the Applications server can handle per combination.<br>
threadpool.update.record.batch.size = 2: Number of parallel batch (Integration-Ble) update records that the Applications server can handle per combination.<br>
threadpool.update.data.manual.size = 8: Update threadpool data manual size.<br>
threadpool.update.table.batch.size = 2: Number of parallel batch (Integration-Ble) update tables that the Applications server can handle per process.<br>
threadpool.query_run.size = 40: 4 * the number of concurrent users.  Use a size that is less than MaxDBConnections and that also leaves space for other system processes.<br>
threadpool.level_method.size = 25: Use a size that is less than MaxDBConnections and that also leaves space for other system processes.<br>
threadpool.copy_paste.size = 40: Use a size that is less than MaxDBConnections and that also leaves space for other system processes.<br>
threadpool.level_method.timeout = 300000 (5 minutes): This setting frees up unused threads.<br>
threadpool.query_run.per_user = review [470852/KB197778].  Experiment by increasing it in values of 4 to determine an optimal value<br>
threadpool.query_run.timeout = 300000:  This must be greater than zero.<br>
maxupdatethreads : Max number of Parallel Update Threads',
      p_success_msg            => 'All application server parameters are set to default.  We verified the following in aps_params:<br>
maxdbconnections, maxdbconnections should be: comb.comb.batch.size * record.batch.size<br>
DBIdleTimeOut<br>
threadpool.update.data.batch.size and BLEThreadPoolSize should be the same.<br>
threadpool.update.table.manual.size<br>
threadpool.update.comb.manual.size<br>
threadpool.update.comb.batch.size<br>
threadpool.update.record.manual.size<br>
threadpool.update.record.batch.size<br>
threadpool.update.data.manual.size<br>
threadpool.update.table.batch.size<br>
threadpool.query_run.size<br>
threadpool.level_method.siz<br>
threadpool.copy_paste.size <br>
threadpool.level_method.timeout<br>
threadpool.query_run.per_user<br>
threadpool.query_run.timeout<br>
maxupdatethreads<br>
threadpool.update.size<br>
threadpool.update.timeout',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '13'
      );
   l_info.delete;
debug('end add_signature: APPLICATION_SERVER_PARAMETERS');



debug('begin add_signature: CONNECTION POOL PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8435',
      p_sig_id                 => 'CONNECTION POOL PARAMETERS',
      p_sig_sql                => 'select pname Aps_Parameter , decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'') aps_params_value ,  decode(ptype, 0, decode(default_number,null,''null'',default_number)) aps_params_default_value, ''min-capacity(Minimum Capacity)'' as For_weblogic ,''minIdle'' as For_Tomcat,  description
from  ##$$SCHEMA_OWNER$$##.aps_params
where pname  in  (''MinDBConnections'') 

union 
select pname Aps_Parameter , decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'') aps_params_value ,  decode(ptype, 0, decode(default_number,null,''null'',default_number)) defaultvalue,''max-capacity(Maximum Capacity)''  as For_welogic ,''maxActive, maxIdle'' as For_Tomcat, description
from  ##$$SCHEMA_OWNER$$##.aps_params
where pname  in  (''MaxDBConnections'') 

union 
select pname Aps_Parameter , decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'') aps_params_value ,  decode(ptype, 0, decode(default_number,null,''null'',default_number)) defaultvalue, ''test-frequency-seconds(Test Frequency)'' as For_weblogic, ''minEvictableIdleTimeMillis,timeBetweenEvictionRunsMillis'' as For_Tomcat, description
from  ##$$SCHEMA_OWNER$$##.aps_params
where pname  in  (''DBIdleTimeout'') 

union 
select pname Aps_Parameter , decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',default_number),value_number), 1,decode(value_string, null, nvl
(default_string,''null''), value_string), ''null'') aps_params_value ,  decode(ptype, 0, decode(default_number,null,''null'',default_number)) defaultvalue, ''connection-reserve-timeout-seconds(Connection Reserve Timeout)'' as For_weblogic, ''maxWait'' as For_Tomcat, description
from  ##$$SCHEMA_OWNER$$##.aps_params
where pname  in  (''DBConnectionTimeout'')',
      p_title                  => 'Connection Pool Parameters',
      p_fail_condition         => 'RS',
      p_problem_descr          => '<b>For aps_params:</b><br>
<ul>
  <li>DBConnectionTimeout</li>
  <li>DBIdleTimeout</li>
  <li>MaxDBConnections</li>
  <li>MinDBConnections</li>
</ul>
<br>
<b>For tomcat server:</b><br>
<ul>
  <li>maxWait</li>
  <li>minEvictableIdleTimeMllisi</li>
  <li>timeBetweenEvictionRunsMillis</li>
  <li>maxActive</li>
  <li>maxIdle</li>
  <li>minIdle</li>
</ul>
<br>
<b>For Weblogic:</b><br>
<ul>
  <li>connection-reserve-timeout-seconds</li>
  <li>Connection Reserve Timeout</li>
  <li>max-capacity(Maximum Capacity)</li>
  <li>min-capacity</li>
</ul>
<br>
',
      p_solution               => '<b>For Tomcat :</b><br>
To change the value of this parameters:<br>
1) go to the <tomcat root direcory>\conf<br>
2) open server.xml file<br>
3) change the required connection pool parameters<br>

<b>For Weblogic :</b><br>

To change the value of this parameter:<br>
1) go to <middleare-home>\user_projects\domains\<your-domain>\config\jdbc<br>

2) open the concern jdbc.xml file<br>

3) change concern  connection pool parameters<br>

example:<br>

<jdbc-connection-pool-params><br>
    <initial-capacity>1</initial-capacity><br>
    <max-capacity>150</max-capacity><br>
    <min-capacity>1</min-capacity><br>
    <connection-reserve-timeout-seconds>5510</connection-reserve-timeout-seconds><br>
    <test-frequency-seconds>120</test-frequency-seconds><br>
   </jdbc-connection-pool-params><br>

Please see [1201774/FAQ2686] Oracle Demantra Parameters for Performance',
      p_success_msg            => 'Note forthcoming.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: CONNECTION POOL PARAMETERS');



debug('begin add_signature: DEM_APS_PARAMS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '7956',
      p_sig_id                 => 'DEM_APS_PARAMS',
      p_sig_sql                => 'Select substr(pname, 1, 30) "Parameter" ,
decode(ptype, 0, decode(value_number,null,decode(default_number,null,''null'',substr(default_number,1,60)),substr(value_number,1,60)), 1,
decode(value_string, null, nvl(substr(default_string,1,60),''null''), substr(value_string,1,60)), ''null'') Value,
description
from ##$$SCHEMA_OWNER$$##.aps_params
where pname not in (''DBName'', ''DBPort'', ''DBType'', ''DBUser'', ''TNSName'', ''UserListContentProvider.common'', ''auditMailAddress'', ''general.userList.whoisonline'', ''wfschema.updatedata.key'',
                    ''update.ora.sql'', ''upk.LaunchURL'', ''collaborator.supportURL'', ''company.name'', ''database.password'', ''mail.server'', ''mailAddress'', ''server.generalurl'')
order by 1',
      p_title                  => 'APS_PARAMS Complete Listing',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'APS_PARAMS table for application parameters that has information on the parameters description and value settings including default settings.  The problem is that there are ZERO rows returned.',
      p_solution               => 'If there are no rows returned, this would be a serious issue with your APS_PARAMS data.  Please contact the DBA.  PLEASE ADD NOTE here.',
      p_success_msg            => 'APS_PARAMS table for application parameters that has information on the parameters description and value settings including default settings.  The output returns the user setting if present or the default setting.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: DEM_APS_PARAMS');



debug('begin add_signature: DEM_DB_PARAMS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8367',
      p_sig_id                 => 'DEM_DB_PARAMS',
      p_sig_sql                => 'Select substr(pname, 1, 50) "Parameter" ,
decode(pval, null, decode(default_val,null,''null'',default_val),pval) Value,
description 
from ##$$SCHEMA_OWNER$$##.db_params
where pname not in (''stats_sleep_time'')
order by 1',
      p_title                  => 'DB_PARAMS Complete Listing',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is a serious issue with your DB_PARAMS data. Please contact the DBA.
',
      p_solution               => 'The parameters that affect these procedures:<br>
<ul>
<li>EP_LOAD_MAIN</li>
<li>EP_LOAD_MDP_LEVEL</li>
<li>EP_LOAD_ITEMS</li>
<li>EP_LOAD_LOCATIONS</li>
<li>EP_LOAD_SALES</li>
<li>MDP_ADD</li>
<li>DBHINTPROPORT_SALESMINSALESDATE used with PROPORT</li>
</ul>
<br>
Please refer to the Note[1232333/FAQ2706]',
      p_success_msg            => 'DB_PARAMS table contains parameters for Data Load Procedures, Proport and many others.  The output returns the user setting if present.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: DEM_DB_PARAMS');



debug('begin add_signature: DEM_INIT_PARAMS_0');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8288',
      p_sig_id                 => 'DEM_INIT_PARAMS_0',
      p_sig_sql                => 'Select substr(pname, 1, 30) "Parameter",
decode(ptype, ''float'', decode(value_float,null,decode(default_val,null,''null'',substr(default_val,1,60)),substr(value_float,1,60)),
''string'', decode(value_string, null, nvl(substr(default_val,1,60),''null''), substr(value_string,1,60)),
''date'',  decode(value_date, null, nvl(substr(default_val,1,60),''null''), substr(value_date,1,60)),''null'') "Value", 
substr(description, 1, 70) "Description"
from ##$$SCHEMA_OWNER$$##.init_params_0
where pname in (''BatchRunMode'', ''CutTailZeros'', ''def_delta'', ''dying_time'', ''ForecastGenerationHorizon'', ''hist_glob_prop'', ''HistoryLength'', ''last_date'', ''last_date_backup'',
''lead'', ''mature_age'',''max_fore_level'', ''min_fore_level'', ''need_spread'', ''proport_missing'', ''proport_spread'', ''PopulationExtraFilter'',''PopulationFilter'',
''quantity_form'',''ResetForeVals'',''resetmat'',''RunInsertUnits'', ''RunInsertUnitsSim'', ''RUNMODE'',
''start_new_run'', ''start_date'',''timeunit'', ''top_level'',''UseModelsPerNode'',''UseParamsPerNode'', ''work_status'')
order by 1',
      p_title                  => 'INIT_PARAMS_0 Settings',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The Base engine profile is the standard default Demantra engine profile.<br>
The Demantra Engine is using base engine parameters when not super seeded individually by user created profiles.',
      p_solution               => 'There is a serious issue with your INIT_PARAMS_0 data. Either contact the DBA or follow the navigation below to verify settings.  Reference [2069139/KB544217]<br><br>
To change the values of Base engine parameters,<br>
Please open Business Modeler:<br>
1) Choose Parameters menu. <br>
2) Choose System Parameters.<br>
3) Click on Engine tab.<br>
4) Select for Engine Profile: Base <br>
5) All the tabs will display the parameters values for Base engine profile.<br>
Any modification that will be done will be saved to INIT_PARAMS_0 table.
',
      p_success_msg            => 'The Base engine profile is the standard default Demantra engine profile.<br>
The Demantra Engine is using base engine parameters when not super seeded individually by user created profiles.  Please review the parameter settings in this report.
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: DEM_INIT_PARAMS_0');



debug('begin add_signature: DEM_INIT_PARAMS_1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8289',
      p_sig_id                 => 'DEM_INIT_PARAMS_1',
      p_sig_sql                => 'Select substr(pname, 1, 30) "Parameter",
decode(ptype, ''float'', decode(value_float,null,decode(default_val,null,''null'',substr(default_val,1,60)),substr(value_float,1,60)),
''string'', decode(value_string, null, nvl(substr(default_val,1,60),''null''), substr(value_string,1,60)),
''date'',  decode(value_date, null, nvl(substr(default_val,1,60),''null''), substr(value_date,1,60)),''null'') "Value", 
substr(description, 1, 70) "Description"
from ##$$SCHEMA_OWNER$$##.init_params_1
where pname in (''BatchRunMode'', ''CutTailZeros'', ''def_delta'', ''dying_time'', ''ForecastGenerationHorizon'', ''hist_glob_prop'', ''HistoryLength'', ''last_date'', ''last_date_backup'',
''lead'', ''mature_age'',''max_fore_level'', ''min_fore_level'', ''need_spread'', ''proport_missing'', ''proport_spread'', ''PopulationExtraFilter'',''PopulationFilter'',
''quantity_form'',''ResetForeVals'',''resetmat'',''RunInsertUnits'', ''RunInsertUnitsSim'', ''RUNMODE'',
''start_new_run'', ''start_date'',''timeunit'', ''top_level'',''UseModelsPerNode'',''UseParamsPerNode'', ''work_status'')
order by 1',
      p_title                  => 'INIT_PARAMS_1 Parameter Check',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'In Batch mode, the Analytical Engine considers all the item-location combinations and generates a forecast for all of them.<br>
In a typical implementation, the engine automatically runs in batch mode regularly.<br>
Batch mode should be run separately of data load, typically after new data is imported.<br>
The Batch engine profile uses the same forecast tree and causal factors as the Base engine,<br>
but the parameters can be modified individually to reflect a different demand stream or other customization without modifying the Base.',
      p_solution               => 'The engine run for Batch profile is using the parameters from Base profile when those are not specifically define for Batch.<br>
The description of each engine profile is available in Oracle Demantra Analytical Engine Guide from [443969/KB586904]<br><br>
To change the value of Batch engine parameters,<br>
Please open Business Modeler:<br>
1) Choose Parameters menu. <br>
2) Choose System Parameters.<br>
3) Click on Engine tab.<br>
4) Select for Engine Profile: Batch <br>
5) All the tabs will display the parameters values for Batch engine profile.<br>
Any modification that will be done will be saved to INIT_PARAMS_1 table.',
      p_success_msg            => 'The batch engine profile uses the same forecast tree and causal factors as the Base engine,<br>
but the parameters can be modified individually to reflect a different demand stream or other customization without modifying the Base.<br>
This signature has listed the parameters that are set for the batch engine profile and override the parameters for the base engine profile.
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: DEM_INIT_PARAMS_1');



debug('begin add_signature: DEM_INIT_PARAMS_99');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8290',
      p_sig_id                 => 'DEM_INIT_PARAMS_99',
      p_sig_sql                => 'Select substr(pname, 1, 30) "Parameter",
decode(ptype, ''float'', decode(value_float,null,decode(default_val,null,''null'',substr(default_val,1,60)),substr(value_float,1,60)),
''string'', decode(value_string, null, nvl(substr(default_val,1,60),''null''), substr(value_string,1,60)),
''date'',  decode(value_date, null, nvl(substr(default_val,1,60),''null''), substr(value_date,1,60)),''null'') "Value", 
substr(description, 1, 70) "Description"
from ##$$SCHEMA_OWNER$$##.init_params_99
where pname in (''BatchRunMode'', ''CutTailZeros'', ''def_delta'', ''dying_time'', ''ForecastGenerationHorizon'', ''hist_glob_prop'', ''HistoryLength'', ''last_date'', ''last_date_backup'',
''lead'', ''mature_age'',''max_fore_level'', ''min_fore_level'', ''need_spread'', ''proport_missing'', ''proport_spread'', ''PopulationExtraFilter'',''PopulationFilter'',
''quantity_form'',''ResetForeVals'',''resetmat'',''RunInsertUnits'', ''RunInsertUnitsSim'', ''RUNMODE'',
''start_new_run'', ''start_date'',''timeunit'', ''top_level'',''UseModelsPerNode'',''UseParamsPerNode'', ''work_status'')
order by 1',
      p_title                  => 'INIT_PARAMS_99 Settings',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The Simulation engine profile is the standard default simulation engine.<br>
In a simulation run, the Analytical Engine performs what if scenarios, in which some of the forecast data is changed or different models are run to determine how this influences the final results.',
      p_solution               => 'The Simulation engine profile is the standard default simulation engine.
Oracle Demantra Analytical Engine Guide from Oracle Demantra: Documentation, Release Notes, Transfer of Information (TOI), and Training [443969/KB586904]<br><br>
The Simulation engine profile uses the same parameters as Batch engine profile, but those parameters can be modified individually.
To change the value for those parameters,<br>
Please open Business Modeler:<br>
1) Choose Parameters menu. <br>
2) Choose System Parameters.<br>
3) Click on Engine tab.<br>
4) Select for Engine Profile : Simulation <br>
5) All the tabs will display the parameters values for Batch engine profile.<br>
Any modification that will be done for Simulation profile will be saved to INIT_PARAMS_99 table.',
      p_success_msg            => 'The Simulation engine profile is the standard default simulation engine.<br>  
Please review the Simulation parameter settings in the report.
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: DEM_INIT_PARAMS_99');



debug('begin add_signature: DEM_SYS_PARAMS');
   l_info('##MASK##2'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##3'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8260',
      p_sig_id                 => 'DEM_SYS_PARAMS',
      p_sig_sql                => 'Select substr(pname, 1, 30) "Parameter",
substr(nvl(pval,''null''), 1, 70) "Value",
substr(nvl(default_val,''null''),1,70) "Default Value",
Description
from ##$$SCHEMA_OWNER$$##.sys_params order by 1',
      p_title                  => 'SYS_PARAMS Complete Listing',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The SYS_PARAMS table has parameters that are listed on the Database, System and Worksheet tabs.  SYS_PARAMS has information concerning the parameters description and value settings.<b> 
The problem is that there have been ZERO rows returned for the signature.

',
      p_solution               => 'There is a serious issue with your SYS_PARAMS data.  Please contact the DBA.  Reference [2069139/KB544217]',
      p_success_msg            => 'SYS_PARAMS table for Database, System and Worksheet tabs parameters that has information on the parameters description and value settings.  The output returns the user setting if present.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: DEM_SYS_PARAMS');



debug('begin add_signature: DEMANTRA_MODIFIED_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8464',
      p_sig_id                 => 'DEMANTRA_MODIFIED_PARAMETERS',
      p_sig_sql                => 'select substr(pname, 1, 30) "Parameter",
TO_CHAR(change_date,''DD-MON-RRRR HH24:MI:SS'') "Changed Date" 
from  ##$$SCHEMA_OWNER$$##.SYS_PARAMS_AUDIT 
where change_date > sysdate - 31
order by change_date desc',
      p_title                  => 'Parameters modified in the last month',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'Demantra parameters are usually modified from the Business Modeler. <br>
Parameters have been changed in the last 30 days. Please verify if the recent changes correspond with the timing of your issue and adjust them accordingly. Tracking modifications will help identify any possible issue that did not occur in the past, but started occurring recently.',
      p_solution               => 'This confirms there are parameters modified in the last month from the Business Modeler.<br>
Those could cause changes in the behavior of the Demantra application.<br>
To change the parameters:<br>
&nbsp; &nbsp; &nbsp;1. Log into Business Modeler <br>
&nbsp; &nbsp; &nbsp;2. Navigate to Parameters <br>
&nbsp; &nbsp; &nbsp;3.&nbsp;System Parameters.<br>
<br>
Reference:<BR>
[1589219/KB515591]: Receiving Error Internal System Error: Ep_tools While Trying To Use System Parameters In Business Modeler',
      p_success_msg            => 'There are no parameters modified from Business Modeler in the last 31 days.<br>
<br>
<span style="font-weight: bold;">Note:</span>
&nbsp;<br>
There could be other parameters modified either by<br>
-&nbsp;demantra application, like max_sales_date during EP_LOAD process,<br>
&nbsp;&nbsp; or <br>
- some manual update using some SQL Tool like SQL Developer even if the recommendation is to always modified the parameters from Business Modeler.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: DEMANTRA_MODIFIED_PARAMETERS');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_2118871_1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '23911',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_2118871_1',
      p_sig_sql                => 'SELECT COUNT(*)
FROM ##$$SCHEMA_OWNER$$##.aps_PARAMS
WHERE pname = ''JSPGetAllow''',
      p_title                  => 'ORA-29273 ORA-24247 After Upgrade to 12.2.5.1+, Calls to Workflows Stop Working',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Demantra Workflow not triggered through UTL_HTTP.request method .
Run UTL_HTTP from Demantra Workflow, error occurs:
ORA-29273: HTTP request failed
ORA-24247: network access denied by access control list (ACL) 
',
      p_solution               => 'Set "JSPGetAllow" parameter in the Bbusiness Modeler to true in order for  both Get and Post to be enabled.

 [2118871/PALRT1657]-Calling Demantra Workflow using HTTP POST method in Oracle Demantra 12.2.5.1 and up. New enhanced security measures. ACL permission error.Review attachments.',
      p_success_msg            => 'Seting "JSPGetAllow" parameter in the Business Modeler to true allows calling Demantra Workflow using HTTP POST method in Oracle Demantra 12.2.5.1 and up to be successful.

',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_2118871_1');



debug('begin add_signature: EMAIL_SETUP_CHECK');
   l_info('##MASK##2'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##3'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5428',
      p_sig_id                 => 'EMAIL_SETUP_CHECK',
      p_sig_sql                => 'SELECT pname "Parameter",
nvl(value_string,''(null)'') "Value String",
nvl(default_string,''(null)'') "Default String"
from ##$$SCHEMA_OWNER$$##.aps_params
where lower(pname) in (''mail'', ''mail.strings.processterminated'', ''mail.strings.recovery'', ''mail.strings.taskfailuresubject'', ''mail.strings.taskstimedoutsubject'',
''mail.strings.timeout.group'', ''mail.strings.timeout.user'', ''mailProtocol'')',
      p_title                  => 'EMAIL setup Verification',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Displaying EMAIL related parameter settings in table aps_param.',
      p_solution               => 'Important - See [1068368/KB263115], DEMANTRA 7.3 MAIL SERVER SETUP - mail-username and mail-password parameters were deprecated.  Review the following parameter settings:<br>
auditmailaddress<br>
mail<br>
mail.server<br>
mail.strings.processterminated<br>
mail.strings.recovery<br>
mail.strings.taskfailuresubject<br>
mail.strings.taskstimedoutsubject<br>
mail.strings.timeout.group<br>
mail.strings.timeout.user<br>
mailAddress<br>
mailProtocol
',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: EMAIL_SETUP_CHECK');



debug('begin add_signature: ENVIRONMENT_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5429',
      p_sig_id                 => 'ENVIRONMENT_PARAMETERS',
      p_sig_sql                => 'select name "Name",
value "Value"
from v$parameter
where name in (''optimizer_mode'',''cursor_sharing'',''db_file_multiblock_read_count'', ''processes'', ''sessions'', ''cpu_count'', ''disk_asynch_io'',''service_names'')',
      p_title                  => 'Environment Parameters',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Verify V$Parameter Values, CPU Count, Service_Names, etc',
      p_solution               => 'These parameter settings are from v$parameter.  Please note as you review Demantra specific parameters.  Please note settings if producing clone.',
      p_success_msg            => 'These parameter settings are from v$parameter.  Please note as you review Demantra specific parameters.  Please note settings if producing clone.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: ENVIRONMENT_PARAMETERS');



debug('begin add_signature: MSD_DEM_DEBUG_MODE_CHECK');
   l_info('##MASK##USER'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8292',
      p_sig_id                 => 'MSD_DEM_DEBUG_MODE_CHECK',
      p_sig_sql                => 'select fpo.user_profile_option_name,
fpo.profile_option_name Profile,
fpov.profile_option_value Value,
decode(fpov.level_id,10001,
''SITE'',10002,
''APPLICATION'',10003,
''RESPONSIBILITY'',
10004,''USER'')"LEVEL",
fa.application_short_name App,
fr.responsibility_name Responsibility,
fu.user_name "USER"
from fnd_profile_option_values fpov, -- FND_PROFILE_OPTIONS_VL
fnd_profile_options_vl fpo,
fnd_application fa,
fnd_responsibility_vl fr,
fnd_user fu,
fnd_logins fl
where fpo.profile_option_id=fpov.profile_option_id(+)
and fa.application_id(+)=fpov.level_value
and fr.application_id(+)=fpov.level_value_application_id
and fr.responsibility_id(+)=fpov.level_value
and fu.user_id(+)=fpov.level_value
and fl.login_id(+) = fpov.LAST_UPDATE_LOGIN
and fpo.profile_option_name LIKE (''%MSD_DEM_DEBUG_MODE%'')
and fpov.profile_option_value = ''Y''
order by 1,3',
      p_title                  => 'MSD_DEM: Debug Mode Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => '<span style="color: #9B7500; font-weight:bold;">The MSD_DEM: Debug Mode Profile Option is set to Yes</span>',
      p_solution               => 'The Shipment and Booking History Collections request can have extra logging turned on by changing MSD_DEM: Debug Mode to Yes (default is No).<BR>
However, if Debug Mode is set to YES at the site level, performance may be negatively influenced.  Verify all MSD_DEM: Debug Mode = YES settings.
<BR>
Reference:<BR>
[1952102/KB197427] Demantra Debugging, Error Location, Log File Location, Log Files by Process, Patch, Patching
',
      p_success_msg            => 'This profile option is set to <span style="color: #9B7500; font-weight:bold;">Yes</span>. 
<br>
When set to Yes, this profile is used to print debug information to the output file of the concurrent request.  There are no MSD_DEM: Debug Mode = YES settings in this schema.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: MSD_DEM_DEBUG_MODE_CHECK');



debug('begin add_signature: MSD_DEM_HOST_URL_CHECK');
   l_info('##MASK##USER'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8293',
      p_sig_id                 => 'MSD_DEM_HOST_URL_CHECK',
      p_sig_sql                => 'select fpo.user_profile_option_name,
fpo.profile_option_name Profile,
fpov.profile_option_value Value,
decode(fpov.level_id,10001,
''SITE'',10002,
''APPLICATION'',10003,
''RESPONSIBILITY'',
10004,''USER'')"LEVEL",
fa.application_short_name App,
fr.responsibility_name Responsibility,
fu.user_name "USER"
from fnd_profile_option_values fpov, -- FND_PROFILE_OPTIONS_VL
fnd_profile_options_vl fpo,
fnd_application fa,
fnd_responsibility_vl fr,
fnd_user fu,
fnd_logins fl
where fpo.profile_option_id=fpov.profile_option_id(+)
and fa.application_id(+)=fpov.level_value
and fr.application_id(+)=fpov.level_value_application_id
and fr.responsibility_id(+)=fpov.level_value
and fu.user_id(+)=fpov.level_value
and fl.login_id(+) = fpov.LAST_UPDATE_LOGIN
and fpo.profile_option_name LIKE (''%MSD_DEM_HOST_URL%'')
and fpov.profile_option_value <> ( select pval from ##$$SCHEMA_OWNER$$##.sys_params where pname like ''%AppServerURL%'')
order by 1,3',
      p_title                  => 'MSD_DEM: Host URL Profile Option Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => '<span style="color: #9B7500; font-weight:bold;">The MSD_DEM: Host URL Profile Option is different than AppServerURL SYS_PARAMS parameter</span>',
      p_solution               => 'This profile is used to invoke Oracle Demantra URLs from the E-Business Suite applications.<BR>
Set this profile to the Oracle Demantra Application Server Host Name, Port Number and Application Name. <BR>
<BR>
Reference:<BR>
[1944142/KB515025] Shipment Booking History error - ORA-29273: HTTP request failed , ORA-06512: at "SYS.UTL_HTTP" line 1577 ORA-12541: TNS:no listener',
      p_success_msg            => 'This profile option is set to the<span style="color: #9B7500; font-weight:bold;">SYS_PARAMS.AppServerURL parameter</span>. 
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '12'
      );
   l_info.delete;
debug('end add_signature: MSD_DEM_HOST_URL_CHECK');



debug('begin add_signature: MSD_DEM_SCHEMA_CHECK');
   l_info('##MASK##USER'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8291',
      p_sig_id                 => 'MSD_DEM_SCHEMA_CHECK',
      p_sig_sql                => 'select fpo.user_profile_option_name "User Profile Name",
fpo.profile_option_name "Profile",
fpov.profile_option_value "Value",
decode(fpov.level_id,10001, ''SITE'',10002,''APPLICATION'',10003,''RESPONSIBILITY'',10004,''USER'') "LEVEL",
fa.application_short_name "App",
fr.responsibility_name "Responsibility",
fu.user_name "User"
from fnd_profile_option_values fpov, -- FND_PROFILE_OPTIONS_VL
fnd_profile_options_vl fpo,
fnd_application fa,
fnd_responsibility_vl fr,
fnd_user fu,
fnd_logins fl
where fpo.profile_option_id=fpov.profile_option_id(+)
and fa.application_id(+)=fpov.level_value
and fr.application_id(+)=fpov.level_value_application_id
and fr.responsibility_id(+)=fpov.level_value
and fu.user_id(+)=fpov.level_value
and fl.login_id(+) = fpov.LAST_UPDATE_LOGIN
and fpo.profile_option_name LIKE (''%MSD_DEM_SCHEMA%'')
and upper(fpov.profile_option_value) = upper(''##$$SCHEMA_OWNER$$##'')
order by 1,3',
      p_title                  => 'MSD_DEM: SCHEMA Check',
      p_fail_condition         => 'NRS',
      p_problem_descr          => '<span style="color: #9B7500; font-weight:bold;">The MSD_DEM: Schema Profile Option is not set to the Demantra schema name</span>',
      p_solution               => 'After Demantra has been installed you must run the Update Synonyms concurrent request, which is under the responsibility Demand Management System Administrator.
This program defines the value of the MSD_DEM: Schema profile option. <BR>
<BR>
Reference:<BR>
[549215/KB562817] MSDDEMPSP Push Setup Parameters Errors ORA-00942 Table Or View Does Not Exist - MSD_DEM: Schema Profile Option is not set to the demantra schema name
For supporting information, see:
[1061331/KB197864] Update Synonyms procedure - What it does and why it is important to EBS/ASCP - Demantra implementations',
      p_success_msg            => 'This profile option is set to <span style="color: #9B7500; font-weight:bold;">demantra schema name</span>. This is the correct setting.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '14'
      );
   l_info.delete;
debug('end add_signature: MSD_DEM_SCHEMA_CHECK');



debug('begin add_signature: TIME_CONTROL_APS_PARAMS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5427',
      p_sig_id                 => 'TIME_CONTROL_APS_PARAMS',
      p_sig_sql                => 'SELECT pname "Parameter",
decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) "Value Number"
from ##$$SCHEMA_OWNER$$##.aps_params
where lower(pname) in (''mindbconnections'', ''dbidletimeout'', ''dbconnectiontimeout'', ''UpdateThreadTimeout'', ''BLEThreadTimeout'', ''threadpool.update.timeout'', ''UpdateQueueTimeout'', ''threadpool.copy_paste.timeout'', ''threadpool.default.timeout'', ''threadpool.event_manager.timeout'', ''threadpool.external_process_reader.timeout'',
''threadpool.level_method.timeout'', ''threadpool.paste_process.timeout'', ''threadpool.populationRefresher.timeout'', ''QueryMechanisimTimeOut'', ''Server.SessionExpiration'', ''tunnel.server.threadpool.threadTimeout'', ''Server.SessionExpiration'')
and 
((lower(pname) = ''mindbconnections'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 4)
or
(lower(pname) = ''dbidletimeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 1800000)
or
(lower(pname) = ''dbconnectiontimeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''UpdateThreadTimeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 5000)
or
(lower(pname) = ''BLEThreadTimeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 5000)
or
(lower(pname) = ''threadpool.update.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''threadpool.copy_paste.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''threadpool.default.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''UpdateQueueTimeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 5000)
or
(lower(pname) = ''threadpool.event_manager.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''threadpool.external_process_reader.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''threadpool.level_method.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''threadpool.paste_process.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''threadpool.populationRefresher.timeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000)
or
(lower(pname) = ''QueryMechanisimTimeOut'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 0)
or
(lower(pname) = ''Server.SessionExpiration'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 1200)
or
(lower(pname) = ''tunnel.server.threadpool.threadTimeout'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 300000))',
      p_title                  => 'Time Control Parameters NOT set to default in APS_PARAMS',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The parameters that affect timeouts are not set to default values.  Please review these settings to verify desired changes.<br><br>If you are having timeout issues, consider setting to defaults and testing.
',
      p_solution               => 'There are times when setting parameters to default will allow for a fresh testing environment.  We verified the following parameters:<br><br>
Parameter description and instructions:<br>
mindbconnections = 0: The minimum number of database connections for the previously mentioned database user.<br>
DBIdleTimeOut = 300000 (5 minutes): This setting frees up unused database connections sooner, because they overstress the database.<br>
dbconnectiontimeout = 5000: The database connection timeout period, in milliseconds.<br>
UpdateQueueTimeout = 5000: The timeout period for the manual update listener, in milliseconds.<br>
UpdateThreadTimeout = 2: Number of parallel manual update tables that the Applications server can handle per process.<br>
BLEThreadTimeout = 5000: Timeout after which an idle BLE thread is killed.<br>
threadpool.copy_paste.timeout = 300000: Idle time- defines the amount of time a thread can be idle before it is terminated.<br>
threadpool.default.timeout = 30000: Default thread pool timeout.<br>
threadpool.event_manager.timeout = 300000: Defined the Event Manager threads idle timeout, i.e., the amount of time, in milliseconds, that a thread can be idle before it is terminated.<br>
threadpool.external_process_reader.timeout = 300000: Defines the External Process Reader threads idle timeout, i.e., the amount of time, in milliseconds, that a thread can be idle before it is terminated.<br>
threadpool.level_method.timeout = 300000: the idle timeout for each thread (time to live when the thread is not active).<br>
threadpool.paste_process.timeout = 300000: Idle time- defines the amount of time a thread can be idle before it is terminated.<br>
threadpool.populationRefresher.timeout = 300000: Idle time- defines the amount of time a thread can be idle before it is terminated. If the population refresher thread pool size is negative this value is meaningless.<br>
threadpool.update.timeout = 60000: Parallel values update thread pool timeout.<br>
QueryMechanisimTimeOut = null: The timeout period for the query notification listener, in milliseconds.<br>
Server.SessionExpiration = 1200: Session expiration time, in seconds.<br>
tunnel.server.threadpool.threadTimeout = 300000: When number of running threads reaches minThreads at runtime, each thread allocated beyond that value will be killed, if it is unused longer than threadTimeout milliseconds.',
      p_success_msg            => 'Time control parameters are set to default.',
      p_print_condition        => nvl('NEVER','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: TIME_CONTROL_APS_PARAMS');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_AUDIT_563555_1');
   l_info('##MASK##USER_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '26058',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_AUDIT_563555_1',
      p_sig_sql                => 'select u.user_name, q.query_name
from ##$$SCHEMA_OWNER$$##.queries_for_users qa,
     ##$$SCHEMA_OWNER$$##.user_id u, 
	 ##$$SCHEMA_OWNER$$##.queries q
where qa.user_id = u.user_id
and qa.query_id = q.query_id
order by user_name, query_name',
      p_title                  => 'Scripts to Query Users in the Database, to Find Related Worksheets (this select), Profiles and Audit Trail',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Three additional queries available in the My Oracle Support note.  

Q1: Query to retrieve user accounts from the database.  See note.

Q2: Query to find the associated worksheets for each user.  This query.

Q3: Query for the Integration Profile attached to each user.  See note.

Q4: Query for user records in the Audit Trail.  Included in this analyzer.
',
      p_solution               => 'See [563555/KB495821] Scripts to Query Users in the Database, to Find Related Worksheets, Profiles and Audit Trail.',
      p_success_msg            => 'Four queries to reveal Demantra users.
1: Query to retrieve user accounts from the database.

Q2: Query to find the associated worksheets for each user.  This query.

Q3: Query for the Integration Profile attached to each user.

Q4: Query for user records in the Audit Trail.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_AUDIT_563555_1');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_AUDIT_TRAIL_563555_1');
   l_info('##MASK##USER_ID'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '26059',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_AUDIT_TRAIL_563555_1',
      p_sig_sql                => 'select user_id, 
       audit_id 
from ##$$SCHEMA_OWNER$$##.AUDIT_TRAIL 
where CHANGE_DATE < sysdate - 31',
      p_title                  => 'Scripts to Query Users in the Database, to Find Related Worksheets, Profiles and Audit Trail (this select).',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Three additional queries available in the My Oracle Support note.

Q1: Query to retrieve user accounts from the database. See note.

Q2: Query to find the associated worksheets for each user. This query.

Q3: Query for the Integration Profile attached to each user. See note.

Q4: Query for user records in the Audit Trail. Included in this analyzer.',
      p_solution               => 'See [563555/KB495821] Scripts to Query Users in the Database, to Find Related Worksheets, Profiles and Audit Trail.',
      p_success_msg            => 'Four queries to reveal Demantra users.
1: Query to retrieve user accounts from the database.

Q2: Query to find the associated worksheets for each user. This query.

Q3: Query for the Integration Profile attached to each user.

Q4: Query for user records in the Audit Trail.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_AUDIT_TRAIL_563555_1');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_DEMANTRA_PARAM_AUDIT_RECORDED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '27747',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_DEMANTRA_PARAM_AUDIT_RECORDED',
      p_sig_sql                => 'select TABLE_NAME, 
       PNAME, 
       UPDATED_COLUMN, 
       ACTION, 
       OLD_VALUE, 
       NEW_VALUE, 
       UPDATE_DATE
from ##$$SCHEMA_OWNER$$##.PARAMS_AUDIT
where UPDATE_DATE > sysdate - 31
order by UPDATE_DATE desc',
      p_title                  => 'Parameters (DB ,SYS and APS_PARAMS) modified or inserted in the last 30 days as recorded in the PARAMS_AUDIT table.',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Demantra parameters modified in the last 30 days. Please verify if the recent changes correspond with the timing of your issue and adjust them accordingly.  Reviewing modifications will help identify any possible issue that did not occur in the past, but started occurring recently.',
      p_solution               => 'This confirms there are parameters (DB ,SYS and APS_PARAMS) modified or inserted in the last month as recorded in the PARAMS_AUDIT table.
<br>
Reference:<BR>
Developer Unit Test:
--------------------
1. Try to update parameter value of (DB ,SYS and APS_PARAMS) or try to insert 
   new parameter in any of those tables.
2. Once Insertion / Updation Done, Check in PARAMS_AUDIT. It will have 
   information of action that performed.
3. If Module not starts with "DEM:" or CALLED_FROM not having the Demantra 
   seeded procedure, then it most likely is not from Demantra. 
  
Release        Patch Bug No Checkin Type MiniPack Name (Yes/No)
-------        ----------   ------------ -------------  ------
12.2.11.x       33556715    (Patch no - 122110414)',
      p_success_msg            => 'There are no updates or inserts to parameter values of (DB ,SYS and APS_PARAMS).
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_DEMANTRA_PARAM_AUDIT_RECORDED');



debug('begin add_signature: AVAILABLE_SCHEMAS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5422',
      p_sig_id                 => 'AVAILABLE_SCHEMAS',
      p_sig_sql                => 'select owner "Schema Owner",
   table_name "Table"
   from dba_tables 
   where table_name like ''SALES_DATA''',
      p_title                  => 'Available Schemas',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Available schemas as indicated by the owners of the SALES_DATA table.',
      p_solution               => 'Verify the number of available schemas associated with the sales_data table.',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: AVAILABLE_SCHEMAS');



debug('begin add_signature: CURSOR_SHARING_VERIFY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6785',
      p_sig_id                 => 'CURSOR_SHARING_VERIFY',
      p_sig_sql                => 'select name "Parameter Name",
value "Parameter Value"
from v$parameter
where name = ''cursor_sharing''
and name = ( select pval from ##$$SCHEMA_OWNER$$##.db_params where pname = ''plp_cursor_sharing'')',
      p_title                  => 'Cursor_Sharing v$parameter compare to db_params.plp_cursor_sharing',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Warning, the value of v$parameter.cursor_sharing and db_params.plp_cursor_sharing are not equal.

Version 12.2.6 and higher the default value for cursor_sharing is EXACT.  In a stand alone install prior to 12.2.6 it should be changed to FORCE for better performance.  BUT if the DB has both Demantra and ASCP/EBS on the same instance AND the Demantra version is prior to 12.2.6, it is recommended to keep cursor_sharing = EXACT.  IF the Demantra version is 12.2.6 and above, CURSOR_SHARING should be EXACT.  12.2.6 and beyond, Demantra has been adjusted to accommodate CURSOR_SHARING = EXACT both in stand alone and when installed on the same RDBMS with EBS.

* Please note that beginning in 12.2.6 CURSOR_SHARING = EXTACT is recommended.',
      p_solution               => 'Please see [2492866/KB198344] cursor_sharing Set RDBMS and Demantra Parameter Correctly for Performance',
      p_success_msg            => 'v$parameter cursor_sharing is equal to db_params.plp_cursor_sharing',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: CURSOR_SHARING_VERIFY');



debug('begin add_signature: DBA_NETWORK_ACLS_PRIVS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6769',
      p_sig_id                 => 'DBA_NETWORK_ACLS_PRIVS',
      p_sig_sql                => 'select principal "Principal",
   privilege "Privilege",
   is_grant "IS_Grant"
   from dba_network_acl_privileges
   where principal = ''##$$SCHEMA_OWNER$$##''
   and is_grant = ''true''',
      p_title                  => 'Demantra Network ACL Privilege Check',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The Network ACL Privilege is not granted.  This is granted when the SYS_GRANTS.sql script is successfully submitted. 
       ',
      p_solution               => 'See [1419564/KB390823], ORA-24247: Network Access Denied by Access Control List (ACL), How to Run GRANT_HTTP_TO_DEMANTRA.sql',
      p_success_msg            => 'No issue found. This means Success.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: DBA_NETWORK_ACLS_PRIVS');



debug('begin add_signature: DEFAULT_PERFORMANCE_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5424',
      p_sig_id                 => 'DEFAULT_PERFORMANCE_PARAMETERS',
      p_sig_sql                => 'SELECT ''Y'' "Modified?",
   pname "Parameter",
   decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) "Value Number"
   from ##$$SCHEMA_OWNER$$##.aps_params
   where lower(pname) in (''blethreadpoolsize'', ''maxdbconnections'', ''threadpool.query_run.per_user'', ''threadpool.query_run.size'',
                          ''threadpool.update.comb.manual.size'', ''threadpool.update.data.batch.size'', ''threadpool.update.data.manual.size'',
                           ''threadpool.update.record.manual.size'', ''threadpool.update.table.batch.size'', ''threadpool.update.table.manual.size'',
                           ''tunnel.server.threadpool.maxthreads'', ''maxupdatethreads'', ''worksheet.data.comb.block_size'', 
                           ''threadpool.update.record.batch.size'', ''threadpool.update.comb.batch.size'')
   and 
   ((lower(pname) = ''blethreadpoolsize'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 4)
   or
   (lower(pname) = ''maxdbconnections'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 100)
   or
   (lower(pname) = ''threadpool.query_run.per_user'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 4)
      or
   (lower(pname) = ''threadpool.query_run.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 40)
   or
   (lower(pname) = ''threadpool.update.comb.manual.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
   or
   (lower(pname) = ''threadpool.update.data.batch.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
   or
   (lower(pname) = ''threadpool.update.data.manual.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 8)
   or
   (lower(pname) = ''threadpool.update.record.manual.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
   or
   (lower(pname) = ''threadpool.update.table.batch.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
   or
   (lower(pname) = ''threadpool.update.table.manual.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
   or
   (lower(pname) = ''tunnel.server.threadpool.maxthreads'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 100)
   or
   (lower(pname) = ''maxupdatethreads'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 5)
   or
   (lower(pname) = ''worksheet.data.comb.block_size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 0)
   or
   (lower(pname) = ''threadpool.update.record.batch.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
  or
   (lower(pname) = ''threadpool.update.comb.batch.size'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 2)
   or
   (lower(pname) = ''maxupdatethreads'' and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) != 5))',
      p_title                  => 'Parallel and performance threads default parameter comparison.',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The parameters that affect worksheet behavior, parallelism and performance are not set to default values.
',
      p_solution               => 'If you are experiencing issues that cannot be explained, there are times when retreating to the defaults and testing may help.<br><br>
See [1201774/FAQ2686] Oracle Demantra Parameters for Performance.<br><br>
         The default parameter settings are: <br>
         BLEThreadPoolSize	(4)<br>
         MaxDBConnections	(100)<br>
         threadpool.query_run.per_user	(4)<br>
         threadpool.query_run.size	(40)<br>
         threadpool.update.comb.manual.size	(2)<br>
         threadpool.update.data.batch.size	(2)<br>
         threadpool.update.data.manual.size	(8)<br>
         threadpool.update.record.manual.size	(2)<br>
         threadpool.update.table.batch.size	(2)<br>
         threadpool.update.table.manual.size	(2)<br>
         tunnel.server.threadpool.maxthreads (100)<br>
         maxupdatethreads (5)<br>
         worksheet.data.comb.block_size  (0)<br>
         threadpool.update.record.batch.size (2)<br>
         maxupdatethreads (5)',
      p_success_msg            => 'Worksheet and parallel parameters are set to default.  We verified the following aps_params:<br><br>
blethreadpoolsize<br>
maxdbconnections<br>
threadpool.query_run.per_user<br>
threadpool.query_run.size<br>
threadpool.update.comb.manual.size<br>
threadpool.update.data.batch.size<br>
threadpool.update.data.manual.size<br>
threadpool.update.record.manual.size<br>
threadpool.update.table.batch.size<br>
threadpool.update.table.manual.size<br>
tunnel.server.threadpool.maxthreads<br>
maxupdatethreads<br>
worksheet.data.comb.block_size<br>
threadpool.update.record.batch.size<br>
threadpool.update.comb.batch.size',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: DEFAULT_PERFORMANCE_PARAMETERS');



debug('begin add_signature: DEMANTRA_CURSOR_SHARING');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6782',
      p_sig_id                 => 'DEMANTRA_CURSOR_SHARING',
      p_sig_sql                => 'select pval from ##$$SCHEMA_OWNER$$##.db_params where lower(pname) = ''plp_cursor_sharing''',
      p_title                  => 'Cursor Sharing in DB_PARAMS',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The default value for cursor_sharing is EXACT.  In a stand alone install prior to 12.2.6 it should be changed to FORCE for better performance.  BUT if the DB has both Demantra and ASCP/EBS on the same instance AND the Demantra version is prior to 12.2.6, it is recommended to keep cursor_sharing = EXACT.  IF the Demantra version is 12.2.6 and above, CURSOR_SHARING should be EXACT.  12.2.6 and beyond, Demantra has been adjusted to accommodate CURSOR_SHARING = EXACT both in stand alone and when installed on the same RDBMS with EBS.

* Please note that beginning in 12.2.6 CURSOR_SHARING = FORCE is recommended.
',
      p_solution               => 'Please see [1356886/KB294079] How to check Demantra Performance DataBase and Worksheet Parameters
',
      p_success_msg            => 'Please review cursor_sharing setting.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: DEMANTRA_CURSOR_SHARING');



debug('begin add_signature: DICTIONARY CORRUPTION');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '15113',
      p_sig_id                 => 'DICTIONARY CORRUPTION',
      p_sig_sql                => 'select *
from user_objects 
where (object_name like ''DEM\_%\_IN%'' ESCAPE ''\''  or  object_name like 
''ENG\_%\_IN%'' ESCAPE ''\'')
or    (object_name like ''DEM\_%\_OUT%'' ESCAPE ''\'' or  object_name like 
''ENG\_%\_OUT%'' ESCAPE ''\'')
and object_type in (''RULE SET'',''QUEUE'',''TABLE'')',
      p_title                  => 'Notification Clean UP',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'When attempting to run engine or load data using EP_LOAD or log in after changing the user password, the following errors occurs in DB_EXCEPTION_LOG table.<BR><BR>

ERROR<BR>
-----------------------<BR>
NOTIFICATION.INITIALIZE    Error failed to create queue table : DEM_APPSERV_IN<BR>

OR<BR>
NOTIFICATION.INITIALIZE    FAILURE: -24000 ORA-24000: invalid value DEMANTRA.DEM_OUT_Q<BR>

 OR<BR>
NOTIFICATION.INITIALIZE    FAILURE: -24001 ORA-24001: cannot create QUEUE_TABLE, DEMANTRA.DEM_APPSERV_OUT already exists<BR>

OR<BR>
NOTIFICATION.LISTEN    FAILURE: -24010 ORA-24010: QUEUE DEMANTRA.DEM_APPSERV_IN_Q does not exist<BR>

 OR<BR>
NOTIFICATION.INITIALIZE    FAILURE: -24032 ORA-24032: object AQ$_ENG_MANAGER_IN_S exists, index could not be created for queue table ENG_MANAGER_IN.<BR><BR>
Advanced Queues in the Oracle database are corrupted with Notification clean up messages.


',
      p_solution               => 'NOTIFICATION.INITIALIZE Error failed to create queue table [2129902/KB679758]
',
      p_success_msg            => 'Demantra related AQ dependent objects are resolved.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: DICTIONARY CORRUPTION');



debug('begin add_signature: EBR CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11458',
      p_sig_id                 => 'EBR CHECK',
      p_sig_sql                => 'SELECT ''EBR Enabled for Demantra Schema'' "EBR"
FROM dba_users
WHERE USERNAME = ''##$$SCHEMA_OWNER$$##''
AND EDITIONS_ENABLED = ''Y''',
      p_title                  => 'Edition-Based Redefinition Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => '<span style="color: #9B7500; font-weight:bold;">Demantra does not support Edition-Based Redefinition (EBR)</span>',
      p_solution               => 'In 12.2.X EBS/VCP schema enables Editions to support live (hot) patching capabilities.<BR>
Demantra does not support this and the Demantra schema cannot be set to Editioned. This is due to the dynamic nature of demantra schema where the tables change frequently and table are added and removed ad-hoc.<BR>
<BR>
Demantra schema can not be editioned.<BR>
1. Export demantra schema.<BR>
2. Drop the schema.<BR>
3. Re-import it in a non-Editioned state.<BR>
<BR>
Reference:<BR>
[2138804/KB609025]-Demantra Upgrade From 12.2.3 To 12.2.5- Engine fails-NOTIFICATION.INITIALIZE FAILURE: -24000 ORA-24000: invalid value. Editioned Schema <BR>
[1932210/FAQ2711] Oracle Demantra and RDBMS Edition Based Redefinition (EBR) EBS schema - Processing and Hot Patching Editioning',
      p_success_msg            => 'Demantra schema is not editioned<BR>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: EBR CHECK');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_GLOB_COMPILE_TEMP_2817525_1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24035',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_GLOB_COMPILE_TEMP_2817525_1',
      p_sig_sql                => 'select count(*) from ##$$SCHEMA_OWNER$$##.GLOB_COMPILE_TEMP',
      p_title                  => 'GLOB_COMPILE_TEMP Row Count Verify',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'This is caused by changes on database side.
On a edition based database, the OBJ public synonym was changed to point to USER_EDITION_INHERITED_OBJECTS instead of USER_TABLES.',
      p_solution               => '[2817525/KB377021] Installation / Upgrade / Data Model Upgrade Is Stuck on GLOB_COMPILE_TEMP',
      p_success_msg            => 'GLOB_COMPILE_TEMP is setup correctly.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_GLOB_COMPILE_TEMP_2817525_1');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_2912865_1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24570',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_2912865_1',
      p_sig_sql                => 'SELECT owner, index_name, status
FROM  dba_indexes
WHERE status = ''UNUSABLE''
and owner = ''##$$SCHEMA_OWNER$$##''',
      p_title                  => 'Are There Indexes in an UNUSABLE State for the Demantra Schema?',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Performance Issue.  Engine is not completing, running for many hours.  There are Demantra indexes that are in an UNUSABLE state.',
      p_solution               => 'Run the query to make the indexes in Unsable state, Usable for the SALES_DATA table.

[2912865/KB537461]-Demantra Engine Is Not Completing In 12.2.11 Version - Sales_data Shows All Indexes Are In "UNUSABLE" State.',
      p_success_msg            => ' There are no Demantra indexes in an Unusable state.  The indexes are usable. ',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_2912865_1');



debug('begin add_signature: EXECUTE PRIVILEGE ON DL_LOG_STATUS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '14471',
      p_sig_id                 => 'EXECUTE PRIVILEGE ON DL_LOG_STATUS',
      p_sig_sql                => 'SELECT GRANTEE, OWNER, GRANTOR, PRIVILEGE, GRANTABLE FROM DBA_TAB_PRIVS
WHERE TABLE_NAME = ''DL_LOG_STATUS''
AND GRANTEE = ''APPS''',
      p_title                  => 'PRIVILEGE ON DL_LOG_STATUS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The APPS account does not have privileges on <DEMANTRA_SCHEMA_NAME>.DL_LOG_STATUS.',
      p_solution               => 'The APPS account requires privileges on <DEMANTRA_SCHEMA_NAME>.DL_LOG_STATUS.  Please see [1276744/KB465644] Error ORA-20015 and ORA-06550 In Forecast Export From Demantra To ASCP ',
      p_success_msg            => 'The APPS account has sufficient privileges for <DEMANTRA_SCHEMA_NAME>.DL_LOG_STATUS.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: EXECUTE PRIVILEGE ON DL_LOG_STATUS');



debug('begin add_signature: INVALID_OBJECTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5446',
      p_sig_id                 => 'INVALID_OBJECTS',
      p_sig_sql                => 'SELECT a.object_name,
           decode(a.object_type,
             ''PACKAGE'', ''Package Spec'',
             ''PACKAGE BODY'', ''Package Body'',
             a.object_type) type,
           (
             SELECT ltrim(rtrim(substr(substr(c.text, instr(c.text,''Header: '')),
               instr(substr(c.text, instr(c.text,''Header: '')), '' '', 1, 1),
               instr(substr(c.text, instr(c.text,''Header: '')), '' '', 1, 2) -
               instr(substr(c.text, instr(c.text,''Header: '')), '' '', 1, 1)
               ))) || '' - '' ||
               ltrim(rtrim(substr(substr(c.text, instr(c.text,''Header: '')),
               instr(substr(c.text, instr(c.text,''Header: '')), '' '', 1, 2),
               instr(substr(c.text, instr(c.text,''Header: '')), '' '', 1, 3) -
               instr(substr(c.text, instr(c.text,''Header: '')), '' '', 1, 2)
               )))
             FROM dba_source c
             WHERE a.owner = ''##$$SCHEMA_OWNER$$##''
             AND   c.owner = a.owner
             AND   c.name = a.object_name
             AND   c.type = a.object_type
             AND   c.line = 2
             AND   c.text like ''%$Header%''
           ) "File Version",
           b.text "Error Text"
    FROM dba_objects a,
         dba_errors b
    WHERE a.object_name = b.name(+)
    AND a.object_type = b.type(+)
    AND a.status = ''INVALID''
    order by 1 ASC',
      p_title                  => 'Demantra Invalid Objects',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Invalid objects exist that are related to Demantra schema.',
      p_solution               => 'Please recompile the individual objects.<br>
See [1356886/KB294079] How to check Demantra Performance DataBase and Worksheet Parameters
Section: Recompile:

SQL> EXEC CALL_DM_BUILD_PROCEDURES;
SQL> EXEC BUILD_ORDER_COMPILE;
SQL> EXEC COMPILE_ALL;',
      p_success_msg            => 'There are no Demantra related invalid objects.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: INVALID_OBJECTS');



debug('begin add_signature: INSTANCE_REPORT');
   l_info('##MASK##2'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5417',
      p_sig_id                 => 'INSTANCE_REPORT',
      p_sig_sql                => 'select upper(instance_name) "Instance",
       substr(host_name,1,35) "Host",
       version "Version",
       status "Status",
       log_switch_wait "Log Wait",
       database_status "RDBMS Status"
from v$instance',
      p_title                  => 'Instance Information',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This information is taken directly from v$instance.  Status reveals the open - close status of the database.  RDBMS Status reveals if the instance is active.',
      p_solution               => 'Please review with site DBA.  Review: [856857/KB246901] Tips on Cloning a Demantra Schema/Database (ex. refreshing the DEV environment with PRD data)',
      p_success_msg            => 'There are instances available.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: INSTANCE_REPORT');



debug('begin add_signature: LAST_ANALYZED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5482',
      p_sig_id                 => 'LAST_ANALYZED',
      p_sig_sql                => 'SELECT table_name,
       pct_free,
       freelists,
       freelist_groups,
       decode(num_rows, null, 0, num_rows) num_rows,
       chain_cnt,
       last_analyzed
FROM all_tables
where owner = ''##$$SCHEMA_OWNER$$##''
ORDER BY num_rows desc',
      p_title                  => 'Table last analyzed date',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are rows of user_tables ordered by num_rows desc, last_analyzed.',
      p_solution               => 'See [1458911/FAQ2698] Demantra 11g Statistics new Features and Best Practices Gather Schema Stats<br>
For partitioned tables:<br>
See [1601596/FAQ2642] Demantra Gathering Statistics on Partitioned Objects Oracle RDBMS 11gR2',
      p_success_msg            => 'There are no tables in this schema.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LAST_ANALYZED');



debug('begin add_signature: OPTIMIZER_INDEX_CACHING_DEMANTRA');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5457',
      p_sig_id                 => 'OPTIMIZER_INDEX_CACHING_DEMANTRA',
      p_sig_sql                => 'select value
from v$parameter
where lower(name) = ''optimizer_index_caching''',
      p_title                  => 'Verify optimizer_index_caching for Demantra',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Default 100% - the optimizer evaluates index access at the regular cost.<br>
50% makes the index access path look half as expensive.  Demantra Development recommends between 75 and 100.  Your setting is out of typical scope.<br>
If not intended please test with a setting within recommended scope.<br>',
      p_solution               => 'See [470852/KB197778], Oracle Demantra Worksheet Performance - A Technical Paper.<br>
We suggest three possible testing scenarios:<br>
1) optimizer_index_caching = 0 optimizer_index_cost_adj = 100 default values, generally when the data warehouse reporting system.<br>
2) optimizer_index_caching = 90 optimizer_index_cost_adj = 25 general time transaction processing - OLTP system.<br>
3) Leave the parameters at default: optimizer_index_caching = 0, optimizer_index_cost_adj = 100<br>
Gather SYSTEM statistics, CPU, MEM, etc.  Please see [1148577/KB138603] Example of How To Gather and Display The Workload System Statistics into a User Defined Table<br><br>
DBMS_STATS.GATHER_SYSTEM_STATS (<br>
gathering_mode   VARCHAR2 DEFAULT NOWORKLOAD,<br>
interval         INTEGER  DEFAULT NULL,<br>
stattab          VARCHAR2 DEFAULT NULL,<br>
statid           VARCHAR2 DEFAULT NULL,<br>
statown          VARCHAR2 DEFAULT NULL)',
      p_success_msg            => 'The setting is within suggested range.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: OPTIMIZER_INDEX_CACHING_DEMANTRA');



debug('begin add_signature: OPTIMIZER_INDEX_COST_ADJ_DEMANTRA');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5458',
      p_sig_id                 => 'OPTIMIZER_INDEX_COST_ADJ_DEMANTRA',
      p_sig_sql                => 'select value
from v$parameter
where lower(name) = ''optimizer_index_cost_adj''',
      p_title                  => 'Verify optimizer_index_cost_adj',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Default 100% - the optimizer evaluates index access at the regular cost.<br>
50% makes the index access path look half as expensive.  Demantra Development recommends between 25 and 50.  Your setting is out of typical scope.<br>
If not intended please test with a setting within recommended scope.',
      p_solution               => 'See [470852/KB197778], Oracle Demantra Worksheet Performance - A Technical Paper.<br>
We suggest three possible testing scenarios:<br>
1) optimizer_index_caching = 0 optimizer_index_cost_adj = 100 default values, generally when the data warehouse reporting system.<br>
2) optimizer_index_caching = 90 optimizer_index_cost_adj = 25 general time transaction processing / OLTP system.<br>
3) Leave the parameters at default: optimizer_index_caching = 0, optimizer_index_cost_adj = 100<br>
Gather SYSTEM statistics, CPU, MEM, etc.  Please see [1148577/KB138603] Example of How To Gather and Display The Workload System Statistics into a User Defined Table<br><br>
DBMS_STATS.GATHER_SYSTEM_STATS (<br>
gathering_mode   VARCHAR2 DEFAULT NOWORKLOAD,<br>
interval         INTEGER  DEFAULT NULL,<br>
stattab          VARCHAR2 DEFAULT NULL,<br>
statid           VARCHAR2 DEFAULT NULL,<br>
statown          VARCHAR2 DEFAULT NULL)',
      p_success_msg            => 'The setting is within suggested range.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: OPTIMIZER_INDEX_COST_ADJ_DEMANTRA');



debug('begin add_signature: OPTIMIZER_USE_SQL_PLAN_BASELINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5222',
      p_sig_id                 => 'OPTIMIZER_USE_SQL_PLAN_BASELINES',
      p_sig_sql                => 'select value "Not set to recommendation"
from v$parameter
where lower(name) = ''optimizer_use_sql_plan_baselines'' and trim(nvl(value, null)) != ''FALSE''',
      p_title                  => 'Verify optimizer_use_sql_plan_baselines',
      p_fail_condition         => '[Not set to recommendation] != ['']',
      p_problem_descr          => 'Verify optimizer_use_sql_plan_baselines<br>
By disabling the OPTIMIZER_USE_SQL_PLAN_BASELINES parameter, the Cost Based Optimizer (CBO) has to recalculate the execution plan every time. This is advantageous in environments where data is very dynamic.',
      p_solution               => 'Default TRUE.  We recommend FALSE. <br><br>
See [2230898/KB343405] Impact Of Disabling OPTIMIZER_USE_SQL_PLAN_BASELINES Parameter In ASCP Environment?<br>
and see [567107/KB680271] Init.ora Parameter OPTIMIZER_USE_SQL_PLAN_BASELINES Reference Note',
      p_success_msg            => 'No issue found. This means Success.  Review [2230898/KB343405] Impact Of Disabling OPTIMIZER_USE_SQL_PLAN_BASELINES Parameter In ASCP Environment? for confirmation.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: OPTIMIZER_USE_SQL_PLAN_BASELINES');



debug('begin add_signature: OS_RESOURCE_LIMITS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5433',
      p_sig_id                 => 'OS_RESOURCE_LIMITS',
      p_sig_sql                => 'select RESOURCE_NAME, LIMIT
from user_resource_limits',
      p_title                  => 'Operating System User Resource Settings',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Connections to the database can cause the current number of operating system processes associated with the Oracle Instance to exceed the SESSIONS_PER_USER database parameter.  Also a client process can be terminated and their V$SESSION / V$PROCESS entries can continue to exist for a period of time after which they disappear.',
      p_solution               => 'See [1287854/KB790978], Troubleshooting Guide - ORA-20: Maximum Number Of Processes (%S) Exceeded.<br>
Also<br>
See [951892/KB111428] Why does a server process continue to run after its client process has been terminated?',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: OS_RESOURCE_LIMITS');



debug('begin add_signature: RDBMS_CURSOR_SHARING');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6781',
      p_sig_id                 => 'RDBMS_CURSOR_SHARING',
      p_sig_sql                => 'select name "Parameter Name",
value "Parameter Value"
from v$parameter
where name = ''cursor_sharing''',
      p_title                  => 'RDBMS CURSOR_SHARING',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Version 12.2.6 and higher the default value for cursor_sharing is EXACT. In a stand alone install prior to 12.2.6 it should be changed to FORCE for better performance. BUT if the DB has both Demantra and ASCP/EBS on the same instance AND the Demantra version is prior to 12.2.6, it is recommended to keep cursor_sharing = EXACT. IF the Demantra version is 12.2.6 and above, CURSOR_SHARING should be EXACT. 12.2.6 and beyond, Demantra has been adjusted to accommodate CURSOR_SHARING = EXACT both in stand alone and when installed on the same RDBMS with EBS.

* Please note that beginning in 12.2.6 CURSOR_SHARING = EXTACT is recommended.

* Please note that beginning in 12.2.6 CURSOR_SHARING = FORCE is recommended.
',
      p_solution               => 'Please see [2492866/KB198344] cursor_sharing Set RDBMS and Demantra Parameter Correctly for Performance
',
      p_success_msg            => 'Please see [2492866/KB198344] cursor_sharing Set RDBMS and Demantra Parameter Correctly for Performance
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: RDBMS_CURSOR_SHARING');



debug('begin add_signature: SALES_DATA_CHAIN_ROWS_PERCENT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5432',
      p_sig_id                 => 'SALES_DATA_CHAIN_ROWS_PERCENT',
      p_sig_sql                => 'select decode(num_rows,0,0,round(chain_cnt/(num_rows*100),2))
from dba_tables
where decode(num_rows,0,0,round(chain_cnt/(num_rows*100),2)) > ''20''
and table_name = ''SALES_DATA''',
      p_title                  => 'SALES_DATA Chained row percent.',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The presence of migrated or chained rows can severely affect performance.  Any statements that query, update or create chained rows will be adding I/O overhead to the system, impacting performance.<br>
Demantra development suggests that you quickly identify and rectify situations involving chained rows.  Chained rows can also add overhead to the performance of indexes and full-table scans.<br>
If you are on version greater than 7.3.1.3 you can use TABLE_REORG to reduce chaining.  If you are on a version before 7.3.1.4 you will need to either Rebuild the table having chained rows or create a new table using CREATE TABLE AS.  In either case consider increasing PCTFREE.',
      p_solution               => 'For more information see [1356886/KB294079], How to check Demantra Performance DataBase and Worksheet Parameters.',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: SALES_DATA_CHAIN_ROWS_PERCENT');



debug('begin add_signature: VERIFY_DEMANTRA_PACKAGE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5483',
      p_sig_id                 => 'VERIFY_DEMANTRA_PACKAGE',
      p_sig_sql                => 'SELECT name, type, text
FROM dba_source
WHERE line  < 100
and owner = ''##$$SCHEMA_OWNER$$##''
AND ( type =''PACKAGE BODY''
 OR type   = ''PACKAGE''
or type = ''FUNCTION''
or type = ''PROCEDURE'')
AND (text LIKE ''%Revision:%''
OR text LIKE ''%$Id:%'')
ORDER BY 1,2',
      p_title                  => 'Package Inventory',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Detailed list of package and package bodies.',
      p_solution               => 'Used to verify code revision level.',
      p_success_msg            => 'There are no rows in this table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: VERIFY_DEMANTRA_PACKAGE');



debug('begin add_signature: VERSION_DETAILS_HISTORY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5477',
      p_sig_id                 => 'VERSION_DETAILS_HISTORY',
      p_sig_sql                => 'SELECT version,
    build,
    sp,
    TO_CHAR(upgrade_date,''DD-MON-YYYY HH24:MI:SS'') "Upgrade Date"
FROM ##$$SCHEMA_OWNER$$##.version_details_history
ORDER BY upgrade_date DESC',
      p_title                  => 'VERSION_DETAILS_HISTORY',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This is the version_details_history order by update_date descending.',
      p_solution               => 'Version details',
      p_success_msg            => 'Version details',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: VERSION_DETAILS_HISTORY');



debug('begin add_signature: WAIT FOR STARTUP');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '14470',
      p_sig_id                 => 'WAIT FOR STARTUP',
      p_sig_sql                => 'SELECT INSTANCE_NAME, STARTUP_TIME FROM v$instance where STARTUP_TIME < sysdate-240',
      p_title                  => 'WAIT FOR STARTUP',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Engine Manager is not starting.  In particular, the EngineManagerPreRunLog shows it''s waiting for Startup.',
      p_solution               => 'Engine Is Not Starting And Engine Logs Are Not Written - OCCI Connection Issue [1373888/KB672820]',
      p_success_msg            => 'Engine has started without OCCI Connection Issue.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: WAIT FOR STARTUP');



debug('begin add_signature: SALES_DATA_COLUMN_COUNT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '19316',
      p_sig_id                 => 'SALES_DATA_COLUMN_COUNT',
      p_sig_sql                => 'select COMPUTED_TITLE "Series Name" 
from ##$$SCHEMA_OWNER$$##.COMPUTED_FIELDS
where DBNAME IS NOT NULL
AND LOWER(DATA_TABLE_NAME) = ''branch_data''
AND FORECAST_TYPE_ID not in (select ser.FORECAST_TYPE_ID from ##$$SCHEMA_OWNER$$##.QUERIES q, ##$$SCHEMA_OWNER$$##.ACTIVE_SERIES SER where q.QUERY_ID =SER.QUERY_ID)
AND FORECAST_TYPE_ID not in (select tqs.series_id from ##$$SCHEMA_OWNER$$##.Transfer_Query_Series tqs, ##$$SCHEMA_OWNER$$##.Transfer_Query tq where tqs.ID = tq.id )
AND FORECAST_TYPE_ID NOT in (select source_series from ##$$SCHEMA_OWNER$$##.rolling_profiles)
AND FORECAST_TYPE_ID NOT in (select target_series from ##$$SCHEMA_OWNER$$##.rolling_profiles)
AND FORECAST_TYPE_ID NOT in (select FORECAST_TYPE_ID from ##$$SCHEMA_OWNER$$##.COMPUTED_FIELDS_BASE)',
      p_title                  => 'Delete Unused Series to Avoid ORA-01792: maximum number of columns in SALES_DATA Table',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Consider deleting unused series to avoid ORA-01792: maximum number of columns in SALES_DATA table.  See [1359843/KB366225] Limitation On Number Of Columns Sales_data Table - Not Allowing Series Creation Receiving ORA-01792',
      p_solution               => 'Consider deleting unused series to avoid ORA-01792: maximum number of columns in SALES_DATA table.  See [1359843/KB366225] Limitation On Number Of Columns Sales_data Table - Not Allowing Series Creation Receiving ORA-01792',
      p_success_msg            => 'Consider deleting unused series to avoid ORA-01792: maximum number of columns in SALES_DATA table.  See [1359843/KB366225] Limitation On Number Of Columns Sales_data Table - Not Allowing Series Creation Receiving ORA-01792',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: SALES_DATA_COLUMN_COUNT');



debug('begin add_signature: BIIO_CTO_DATA_ERR');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5415',
      p_sig_id                 => 'BIIO_CTO_DATA_ERR',
      p_sig_sql                => 'SELECT count(*) "NBR_CTO_Data_Recs" FROM ##$$SCHEMA_OWNER$$##.BIIO_CTO_DATA_ERR',
      p_title                  => 'BIIO_CTO_DATA_ERR',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'While importing CTO data, in Booking and Shipping History load, errors reside in the BIIO_CTO_DATA_ERR table.',
      p_solution               => 'Please see [1347289/KB197500] Demantra CTO Import Procedure/Debugging Collection Table(s) Reset',
      p_success_msg            => 'There are no rows in the BIIO_CTO_DATA_ERR table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: BIIO_CTO_DATA_ERR');



debug('begin add_signature: BIIO_CTO_LEVEL_ERR');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5412',
      p_sig_id                 => 'BIIO_CTO_LEVEL_ERR',
      p_sig_sql                => 'SELECT count(*) "NBR_CTO_Level_Import_Recs" FROM ##$$SCHEMA_OWNER$$##.BIIO_CTO_LEVEL_ERR',
      p_title                  => 'BIIO_CTO_LEVEL_ERR',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'There are erred rows in the BIIO_CTO_LEVEL_ERR table.',
      p_solution               => 'Please review MOS [1347289/KB197500] Demantra CTO Import Procedure/Debugging Collection Table(s) Reset',
      p_success_msg            => 'There are no erred rows in the BIIO_CTO_LEVEL_ERR table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: BIIO_CTO_LEVEL_ERR');



debug('begin add_signature: EBS_SALES_IMPORT_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5201',
      p_sig_id                 => 'EBS_SALES_IMPORT_ERRORS',
      p_sig_sql                => 'SELECT count(*) "Nbr_Sales_Import_Records"
FROM ##$$SCHEMA_OWNER$$##.t_src_sales_tmpl_err',
      p_title                  => 'EBS Sales Import Errors',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'You have at least one row in the sales order download err table.',
      p_solution               => 'Please see [809410/FAQ2645], Demantra Data Load - Import Diagnostics Investigation - EBS and Legacy',
      p_success_msg            => 'No sales order import rows in the err table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: EBS_SALES_IMPORT_ERRORS');



debug('begin add_signature: BIIO_CTO_POPULATION_ERR');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5414',
      p_sig_id                 => 'BIIO_CTO_POPULATION_ERR',
      p_sig_sql                => 'SELECT count(*) "NBR_CTO_Population_Import_Recs" FROM ##$$SCHEMA_OWNER$$##.BIIO_CTO_POPULATION_ERR',
      p_title                  => 'BIIO_CTO_POPULATION_ERR',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'While importing CTO Population data, erred rows are written to this table.',
      p_solution               => 'Please see [1347289/KB197500] Demantra CTO Import Procedure/Debugging Collection Table(s) Reset',
      p_success_msg            => 'You have no rows in the err table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: BIIO_CTO_POPULATION_ERR');



debug('begin add_signature: EBS_ITEM_IMPORT_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5199',
      p_sig_id                 => 'EBS_ITEM_IMPORT_ERRORS',
      p_sig_sql                => 'SELECT count(*) "No_of_Item_Import_Records"
FROM ##$$SCHEMA_OWNER$$##.T_SRC_ITEM_TMPL_ERR',
      p_title                  => 'EBS Item Import Errors',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'Rows that failed EBS item import.',
      p_solution               => 'Please see [809410/FAQ2645], Demantra Data Load / Import Diagnostics Investigation - EBS and Legacy',
      p_success_msg            => 'No item import rows in the err table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: EBS_ITEM_IMPORT_ERRORS');



debug('begin add_signature: EBS_LOCATION_IMPORT_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5200',
      p_sig_id                 => 'EBS_LOCATION_IMPORT_ERRORS',
      p_sig_sql                => 'SELECT count(*) "No_of_Location_Import_Records"
FROM ##$$SCHEMA_OWNER$$##.t_src_loc_tmpl_err',
      p_title                  => 'Demantra Data Load / Import Diagnostics Investigation - EBS and Legacy',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'There are erred location rows in the t_src_loc_tmpl_err table.',
      p_solution               => 'Please see [809410/FAQ2645], Demantra Data Load / Import Diagnostics Investigation - EBS and Legacy',
      p_success_msg            => 'No location import rows in the err table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: EBS_LOCATION_IMPORT_ERRORS');



debug('begin add_signature: EP_LOAD_ORA-1652');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11380',
      p_sig_id                 => 'EP_LOAD_ORA-1652',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(err_date,''DD-MON-RRRR HH24:MI:SS'') "ERR_DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(err_msg,1,70) "ERR_MSG"
FROM ##$$SCHEMA_OWNER$$##.db_exception_log
where err_date >= sysdate-4
and ((instr(err_msg, ''ORA-01652'') > 0) or (instr(err_msg, ''ORA-1652'') > 0)))
order by err_date desc',
      p_title                  => 'ORA-1652 Check in DB_EXCEPTION_LOG table',
      p_fail_condition         => 'RS',
      p_problem_descr          => '<span style="color: #9B7500; font-weight:bold;">ORA-1652 in db_exception_log table</span>',
      p_solution               => 'ORA-1652 in db_exception_log table<BR>
When ORA-1652: unable to extend temp segment by 128 in table space TEMP2 error shows, one of the three steps should be taken:<BR>

a) Ensure that the Demantra Schema has Stats computed on a regular basis since this helps in Temp space issues<BR>
b) Ensure that there is enough Temp space to match the jobs being run<BR>
c) Ensure that other jobs that might utilize the Temp table space are not running at the same time.<BR>

If another ORA-type error is present then take corrective actions based on the correct procedure for that particular ORA error <BR>
<BR>
Reference:<BR>
[969580/KB341050] EBS FULL DOWNLOAD FATAL workflow.general ORA-20002 ORA-20003 PACKAGE BODY DATA_LOAD ACTIVE_PROC_DYN(''EP_LOAD_SALES'') ',
      p_success_msg            => 'No  <span style="color: #9B7500; font-weight:bold;">ORA-1652</span> in <span style="color: #9B7500; font-weight:bold;">db_exception_log table</span>.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: EP_LOAD_ORA-1652');



debug('begin add_signature: EVENT SUBSCRIPTION LICENSE FLAG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '15945',
      p_sig_id                 => 'EVENT SUBSCRIPTION LICENSE FLAG',
      p_sig_sql                => 'select count(*) 
from (select *
      from WF_EVENT_SUBSCRIPTIONS
      where rule_function = ''MSD_DEM_EVENT.USER_CHANGE''
      and LICENSED_FLAG = ''Y'') subs
having count(*) < 5',
      p_title                  => 'EVENT SUBSCRIPTION LICENSE FLAG',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There should be 5 event subscriptions that have the correct license status.  If there are not the correct number/status wf_event_subscriptions rows, see solution.',
      p_solution               => 'Please see [602530/KB684407] Troubleshooting EBS - DEMANTRA : User Synchronization does not work',
      p_success_msg            => 'The subscriptions required for EBS/Demantra user integration are present and valid.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EVENT SUBSCRIPTION LICENSE FLAG');



debug('begin add_signature: EXPORT TO EXCEL - FILLVALUEEXPORTTOEXCEL PARAMETER');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '7526',
      p_sig_id                 => 'EXPORT TO EXCEL - FILLVALUEEXPORTTOEXCEL PARAMETER',
      p_sig_sql                => 'select pname "Parameter",  decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) "Value" 
from ##$$SCHEMA_OWNER$$##.aps_params 
where pname = ''FillValueExportToExcel'' 
and decode(nvl(value_number,0),0,nvl(default_number,0),nvl(value_number,0)) = 0',
      p_title                  => 'EXPORT TO EXCEL - FillValueExportToExcel parameter',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Use this parameter to specify the default setting for dialog Export to Excel, option Fully Describe Data. 
Valid values are:<br>
- Yes (1): Selected: The export process formats the file so that you can imported it back into Demantra.<br>
- No (0): Not Selected: Display combination information only once.',
      p_solution               => 'By setting this parameter to 1 - Fully Describe Data, you are allowing users to more easily create reports such as pivot tables within Excel.  Values:<br>
YES = fill all rows or columns with combination details;<br> NO = display combination information only once.<br>
As of 12.2 as part of the Import From Excel enhancement, the default values of FillValueExportToExcel parameter was define the default for the Fully Describe Data prompt.
In Fully Describe Data, the empty rows are not hidden (all rows are shown)<br>
A new parameter FillLevelMembersToCells was introduced as per Demantra 12.2.5.1 - Worksheet Export Shows All Empty Rows Even When Hide Empty Rows Is Set In The Worksheet [2173292/KB578601]
in order to have export file that will have the level members repeated in each row and the empty rows excluded, provided when Fully Describe Data is unchecked.
',
      p_success_msg            => 'You have this set to 1 so you have Fully Describe Data .',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: EXPORT TO EXCEL - FILLVALUEEXPORTTOEXCEL PARAMETER');



debug('begin add_signature: INTEG_STATUS');
   l_info('##MASK##USER NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5475',
      p_sig_id                 => 'INTEG_STATUS',
      p_sig_sql                => 'SELECT substr(username,1,15) "USER NAME",
       substr(process,1,30) "PROCESS",
       substr(stage,1,25) "STAGE",
       substr(status,1,25) "STATUS",
       substr(info,1,25) "INFO",
       status_date "STATUS_DATE"
FROM ##$$SCHEMA_OWNER$$##.integ_status
WHERE rownum < 50
    order by status_date desc',
      p_title                  => 'INTEG_STATUS rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the first 50 rows of the integ_status.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the integ_status table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: INTEG_STATUS');



debug('begin add_signature: LEGACY_ITEM_IMPORT_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5202',
      p_sig_id                 => 'LEGACY_ITEM_IMPORT_ERRORS',
      p_sig_sql                => 'SELECT count(*) "Nbr_Legacy_Item_Imp_Records"
FROM ##$$SCHEMA_OWNER$$##.T_SRC_ITEM_ERR',
      p_title                  => 'Legacy Item Import Log',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'There are erred legacy item rows in the t_src_item_err table.',
      p_solution               => 'Please see [809410/FAQ2645], Demantra Data Load / Import Diagnostics Investigation - EBS and Legacy',
      p_success_msg            => 'There are no legacy item import rows in the err table.',
      p_print_condition        => nvl('NEVER','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('N','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: LEGACY_ITEM_IMPORT_ERRORS');



debug('begin add_signature: LEGACY_LOCATION_IMPORT_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5204',
      p_sig_id                 => 'LEGACY_LOCATION_IMPORT_ERRORS',
      p_sig_sql                => 'SELECT count(*) "Nbr_Legacy_Loc_Imp_Records"
FROM ##$$SCHEMA_OWNER$$##.t_src_loc_err',
      p_title                  => 'LEGACY Location Import Errors',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'There are erred import rows in the legacy location table t_src_loc_err.',
      p_solution               => 'Please see [809410/FAQ2645], Demantra Data Load / Import Diagnostics Investigation - EBS and Legacy',
      p_success_msg            => 'No legacy location import rows in the err table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: LEGACY_LOCATION_IMPORT_ERRORS');



debug('begin add_signature: STATSLOWROWLIMIT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5416',
      p_sig_id                 => 'STATSLOWROWLIMIT',
      p_sig_sql                => 'select trim(pval) "StatsLowRowLimit"
from ##$$SCHEMA_OWNER$$##.db_params
where lower(pname) = ''statslowrowlimit''',
      p_title                  => 'Controlling gather statistics using STATSLOWROWLIMIT.',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This parameter will cause EP_CHECK_ITEMS, EP_LOAD_SALES and EP_LOAD_ITEMS to gather stats on the table whenever it has less than 100,000 rows.  The EP_LOAD_% procedure(s) should only gather stats when there are no stats or the previous stats ROW_NUM count is less than DB_PARAMS StatsLowRowLimit.',
      p_solution               => 'You may be concerned that this recommendation would change the stats collection and the potential performance behavior for many tables.<br>
This recommendation will change the statistics only if the table has less then 100,000 rows.  All these tables are from ep_load process.<br>
You can see below the tables list:<br>
EP_CHECK_ITEMS: - All tables from this query result<br><br>
  SELECT DISTINCT ept.table_name, ut.num_row<br>
  FROM   e_plan_tree ept, user_tables ut<br>
  WHERE  model_version         = 15<br>
  AND    UPPER(ept.table_name) = UPPER(ut.table_name);<br><br>
EP_LOAD_ITEMS: - All tables from this query result<br><br>
  SELECT UPPER(table_name) table_name<br>
  FROM   ep_model_syntax<br>
  WHERE  dim_type = 1',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: STATSLOWROWLIMIT');



debug('begin add_signature: TRANSFER_LIST_470192.1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '18288',
      p_sig_id                 => 'TRANSFER_LIST_470192.1',
      p_sig_sql                => 'select TABLE_NAME
from all_synonyms
where SYNONYM_NAME = ''MSD_DEM_TRANSFER_LIST''',
      p_title                  => 'Demantra Forecast Name Is Not Visible In ASCP Plan Names',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'If TRANSFER_LIST does not show in this view, then it will not be seen in the ASCP plan names/options form.',
      p_solution               => 'Please see [470192/KB758781] MSCFPCSC Demantra Forecast Name Is Not Visible In ASCP Plan Names As A Demand Schedule Or Global Demand Schedule.  Navigate to the EBS side as Advanced Supply Chain Planner/Supply Chain Plan/Names - define the ASCP plan name - click on Plan Options (form short name MSCFPCSC) - click on the Organizations Tab - Review the list of values for Demand Schedules - You will not see the desired forecast in the list.',
      p_success_msg            => 'The forecast(s) will be available to the planning demand schedules.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: TRANSFER_LIST_470192.1');



debug('begin add_signature: DB_EXCEPTION_LOG_2209403.1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '18405',
      p_sig_id                 => 'DB_EXCEPTION_LOG_2209403.1',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(err_date,''DD-MON-RRRR HH24:MI:SS'') "ERR DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(err_msg,1,70) "ERR_MSG"
FROM ##$$SCHEMA_OWNER$$##.db_exception_log
where err_date >= sysdate - 5
and (((instr(err_msg, ''ORA-20002'') > 0) or (instr(err_msg, ''ORA-20003'') > 0))
     and (instr(err_msg, ''ORA-00913'') > 0)))
WHERE rownum < 50',
      p_title                  => 'DB_EXCEPTION_LOG Note 2209403.1 Rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the rows of the dp_exception_log table within the last 5 days that have (ORA-20002 or ORA-20003) and ORA-00913.',
      p_solution               => 'See [2209403/KB198310] EP_LOAD_MAIN Procedure Is Hitting "ORA-20003:" Error Due To Error "ORA-00913: too many values" in Procedure EP_LOAD_SALES',
      p_success_msg            => 'There are no rows in the db_exception_log table within the last 5 days that have (ORA-20002 or ORA-20003) and ORA-00913',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: DB_EXCEPTION_LOG_2209403.1');



debug('begin add_signature: ALL_DBEX_LOGS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6118',
      p_sig_id                 => 'ALL_DBEX_LOGS',
      p_sig_sql                => 'SELECT LOG_TABLE,
       TO_CHAR(msg_date,''DD-MON-YYYY HH24:MI:SS'') "MSG DATE",
       PROC_NAME,
       MSG
FROM
    (SELECT ''DB_AUDIT_LOG'' LOG_TABLE
       , a.*
    FROM ##$$SCHEMA_OWNER$$##.DB_AUDIT_LOG a
    where rownum < 501
    UNION ALL
    SELECT ''DB_CALL_LOG'' LOG_TABLE
       , c.*
    FROM ##$$SCHEMA_OWNER$$##.DB_CALL_LOG c
    where rownum < 501
    UNION ALL
    SELECT ''DB_DETAILED_SECTION_LOG'' LOG_TABLE
       , d.*
    FROM ##$$SCHEMA_OWNER$$##.DB_DETAILED_SECTION_LOG d
    where rownum < 501
    UNION ALL
    SELECT ''DB_HEALTH_LOG'' LOG_TABLE
       , h.*
    FROM ##$$SCHEMA_OWNER$$##.DB_HEALTH_LOG h
    where rownum < 501
    UNION ALL
    SELECT ''DB_INFO_LOG'' LOG_TABLE
       , i.*
    FROM ##$$SCHEMA_OWNER$$##.DB_INFO_LOG i
    where rownum < 501
    UNION ALL
    SELECT ''DB_SECTION_LOG'' LOG_TABLE
       , s.*
    FROM ##$$SCHEMA_OWNER$$##.DB_SECTION_LOG s
    where rownum < 501
    UNION ALL
    SELECT ''DB_SQL_LOG'' LOG_TABLE
       , sql.*
    FROM ##$$SCHEMA_OWNER$$##.DB_SQL_LOG SQL
    where rownum < 501
    UNION ALL
    SELECT ''DB_TIMING_LOG''LOG_TABLE
       , t.*
    FROM ##$$SCHEMA_OWNER$$##.DB_TIMING_LOG t
    where rownum < 501
    UNION ALL
    SELECT ''DB_UPGRADE_SQL_LOG'' LOG_TABLE
       , USQL.*
    FROM ##$$SCHEMA_OWNER$$##.DB_UPGRADE_SQL_LOG USQL
    where rownum < 501
    UNION ALL
    SELECT ''DB_WARNING_LOG'' LOG_TABLE
       , w.*
    FROM ##$$SCHEMA_OWNER$$##.DB_WARNING_LOG W
    where rownum < 501
    UNION ALL
    SELECT ''DB_EXCEPTION_LOG'' LOG_TABLE
       , e.*
    FROM ##$$SCHEMA_OWNER$$##.DB_EXCEPTION_LOG e
    where rownum < 501
    )
where exists (select ''x'' from all_tables where table_name in
(''DB_AUDIT_LOG'', ''DB_CALL_LOG'', ''DB_DETAILED_SECTION_LOG'', ''DB_HEALTH_LOG'', ''DB_INFO_LOG'', ''DB_SECTION_LOG'', ''DB_SQL_LOG'', ''DB_TIMING_LOG'', ''DB_UPGRADE_SQL_LOG'', ''DB_WARNING_LOG'', ''DB_EXCEPTION_LOG''))
ORDER BY msg_date DESC',
      p_title                  => 'DBEX log tables by date',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'This is the time sensitive selection from individual logs.  When an entry is inserted into the the ED_EXCEPTION_LOG table, companion entries are potentially made into 11 additional logs.  If one of the log files is not present, this signature will fail.',
      p_solution               => 'Please review the following list of tables that are required:
DB_AUDIT_LOG
DB_CALL_LOG
DB_DETAILED_SECTION_LOG
DB_EXCEPTION_LOG
DB_HEALTH_LOG
DB_INFO_LOG
DB_SECTION_LOG
DB_SQL_LOG
DB_TIMING_LOG
DB_UPGRADE_SQL_LOG
DB_WARNING_LOG',
      p_success_msg            => 'Please review log details.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: ALL_DBEX_LOGS');



debug('begin add_signature: AQ CLEANUP');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '7427',
      p_sig_id                 => 'AQ CLEANUP',
      p_sig_sql                => 'SELECT TO_CHAR(err_date,''DD-MON-RRRR HH24:MI:SS'') "ERR DATE", substr(proc_name,1,30) "PROC_NAME", substr(err_msg,1,70) "ERR_MSG" FROM ##$$SCHEMA_OWNER$$##.db_exception_log WHERE ERR_DATE > sysdate - 7 and
PROC_NAME like ''%NOTIFICATION%'' and 
(ERR_MSG like ''FAILURE%DEM_%OUT%'' or ERR_MSG like ''FAILURE%DEM_%IN%'' or ERR_MSG like ''FAILURE%ENG_%OUT%'' or ERR_MSG like ''FAILURE%ENG_%IN%'') and
rownum < 5 
order by err_date desc',
      p_title                  => 'CLEANUP AQ objects',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There were issues with AQ objects in the last 7 days, based on db_exception_log table data.',
      p_solution               => '1. Stop the application server, all engines, engine manager and Business Modeler.<br>
2. Ensure that there are no Demantra schema sessions connected to the database.  You can verify by running the following from any SQL client:<br>

SQL> select * from v$session where username= replace_with_demantra_schema_name and single quotes;<br>

If there are any connected sessions, disconnect them.  Do not proceed if there are any connected sessions.<br>

3. Open a new connection to the database as the Demantra schema and run the following:<br>

SQL> BEGIN<br>
SQL> notification.cleanup_all;<br>
SQL> dbms_lock.sleep(61);<br>
SQL> notification.cleanup_all(FORCE with single quotes);<br>
SQL> END;<br>
SQL> /<br>

4. Start up the application server.<br>
Please see: [2129902/KB679758] Demantra Upgrade To 12.2.5.1- ERROR: Failed to initialize notification queue for Engine Starter ID NOTIFICATION.INITIALIZE Error failed to create queue table',
      p_success_msg            => 'There are no AQ issues.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: AQ CLEANUP');



debug('begin add_signature: DB_AUDIT_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5467',
      p_sig_id                 => 'DB_AUDIT_LOG',
      p_sig_sql                => 'select * from
(SELECT TO_CHAR(msg_date,''DD-MON-RRRR HH24:MI:SS'') "MSG DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(msg,1,70) "MSG"
FROM ##$$SCHEMA_OWNER$$##.db_audit_log
order by msg_date desc)
WHERE rownum < 50',
      p_title                  => 'DB_AUDIT_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the first 50 rows of the db_audit_log.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the db_audit_log table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: DB_AUDIT_LOG');



debug('begin add_signature: DB_CALL_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5468',
      p_sig_id                 => 'DB_CALL_LOG',
      p_sig_sql                => 'SELECT * FROM
(Select msg_date "MSG DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(msg,1,70) "MSG"
FROM ##$$SCHEMA_OWNER$$##.db_call_log
order by msg_date desc)
WHERE rownum < 50',
      p_title                  => 'DB_CALL_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the first 50 rows of the db_call_log.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the db_call_log table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: DB_CALL_LOG');



debug('begin add_signature: DB_DETAILED_SECTION_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5469',
      p_sig_id                 => 'DB_DETAILED_SECTION_LOG',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(msg_date,''DD-MON-RRRR HH24:MI:SS'') "MSG DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(msg,1,70) "MSG"
FROM ##$$SCHEMA_OWNER$$##.db_detailed_section_log
order by msg_date desc)
WHERE rownum < 50',
      p_title                  => 'DB_DETAILED_SECTION_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the first 50 rows of the db_detailed_section_log.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the db_detailed_section_log table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: DB_DETAILED_SECTION_LOG');



debug('begin add_signature: DB_EXCEPTION_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5466',
      p_sig_id                 => 'DB_EXCEPTION_LOG',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(err_date,''DD-MON-RRRR HH24:MI:SS'') "ERR DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(err_msg,1,70) "ERR_MSG"
FROM ##$$SCHEMA_OWNER$$##.db_exception_log
where err_date > trunc(sysdate - 8)
order by err_date desc)
',
      p_title                  => 'DB_EXCEPTION_LOG Rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the rows greater than sysdate-8, last seven, days of the dp_exception_log table.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the db_exception_log table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '12'
      );
   l_info.delete;
debug('end add_signature: DB_EXCEPTION_LOG');



debug('begin add_signature: DB_EXCEP_LOG_ORA-24019_2180246.1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '19510',
      p_sig_id                 => 'DB_EXCEP_LOG_ORA-24019_2180246.1',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(err_date,''DD-MON-RRRR HH24:MI:SS'') "ERR_DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(err_msg,1,70) "ERR_MSG"
FROM ##$$SCHEMA_OWNER$$##.db_exception_log
where err_date >= sysdate-4
and instr(err_msg, ''ORA-24019'') > 0)
order by err_date desc',
      p_title                  => 'DB_EXCEPTION_LOG Note 2180246.1 Rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the rows in the dp_exception_log table that have an ORA-24019 within the LAST 4 DAYS.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'These are NO rows in the dp_exception_log table that have an ORA-24019 within the LAST 4 DAYS.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: DB_EXCEP_LOG_ORA-24019_2180246.1');



debug('begin add_signature: DB_HEALTH_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5474',
      p_sig_id                 => 'DB_HEALTH_LOG',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(msg_date,''DD-MON-RRRR HH24:MI:SS'') "MSG DATE",
       substr(proc_name,1,30) "PROC_NAME",
       substr(msg,1,70) "MSG"
FROM ##$$SCHEMA_OWNER$$##.DB_HEALTH_LOG
order by msg_date desc)
WHERE rownum < 50',
      p_title                  => 'DB_HEALTH_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the first 50 rows of the DB_HEALTH_LOG.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the DB_HEALTH_LOG table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: DB_HEALTH_LOG');



debug('begin add_signature: DB_INFO_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5470',
      p_sig_id                 => 'DB_INFO_LOG',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(msg_date,''DD-MON-RRRR HH24:MI:SS'') "MSG DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(msg,1,70) "MSG"
FROM ##$$SCHEMA_OWNER$$##.db_info_log
order by msg_date desc)
WHERE rownum < 50',
      p_title                  => 'DB_INFO_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the first 50 rows of the db_info_log.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the db_info_log table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: DB_INFO_LOG');



debug('begin add_signature: DB_SECTION_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5471',
      p_sig_id                 => 'DB_SECTION_LOG',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(msg_date,''DD-MON-RRRR HH24:MI:SS'') "MSG DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(msg,1,70) "MSG"
FROM ##$$SCHEMA_OWNER$$##.db_section_log
order by msg_date desc)
WHERE rownum < 50',
      p_title                  => 'DB_SECTION_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the first 50 rows of the db_section_log.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the db_section_log table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: DB_SECTION_LOG');



debug('begin add_signature: DB_SQL_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5472',
      p_sig_id                 => 'DB_SQL_LOG',
      p_sig_sql                => 'SELECT * FROM
(SELECT TO_CHAR(msg_date,''DD-MON-RRRR HH24:MI:SS'') "MSG DATE",
substr(proc_name,1,30) "PROC_NAME",
substr(msg,1,70) "MSG"
FROM ##$$SCHEMA_OWNER$$##.db_sql_log
order by msg_date desc)
WHERE rownum < 50',
      p_title                  => 'DB_SQL_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the first 50 rows of the db_sql_log.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the db_sql_log table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: DB_SQL_LOG');



debug('begin add_signature: DB_TIMING_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5473',
      p_sig_id                 => 'DB_TIMING_LOG',
      p_sig_sql                => 'SELECT TO_CHAR(msg_date,''DD-MON-RRRR HH24:MI:SS'') "MSG DATE",
       substr(proc_name,1,30) "PROC_NAME",
       substr(msg,1,70) "MSG"
FROM   ##$$SCHEMA_OWNER$$##.DB_TIMING_LOG
where msg_date > sysdate - 7
order by msg_date desc',
      p_title                  => 'DB_TIMING_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This logs how long specific procedures take to complete with processed row count(s).  Use this information to track performance over the duration of time.',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the db_timing_log table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: DB_TIMING_LOG');



debug('begin add_signature: LOG_IT_PARAMS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5476',
      p_sig_id                 => 'LOG_IT_PARAMS',
      p_sig_sql                => 'SELECT substr(pname,1,30) "PROCESS NAME",
       log_table "LOG_TABLE",
       logging_level "LOGGING_LEVEL"
FROM ##$$SCHEMA_OWNER$$##.log_it_params
order by pname',
      p_title                  => 'LOG_IT_PARAMS settings',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the rows of the log_it_params.',
      p_solution               => 'Please turn logging off unless required.',
      p_success_msg            => 'These are the rows of the log_it_params.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: LOG_IT_PARAMS');



debug('begin add_signature: TABLE_REORG_LOG_TABLE_REORG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '22410',
      p_sig_id                 => 'TABLE_REORG_LOG_TABLE_REORG',
      p_sig_sql                => 'select substr(msg_text,1,80) Recommendation, log_time
from ##$$SCHEMA_OWNER$$##.log_table_reorg
where msg_text like ''High recommendation%''
and log_time > sysdate - 5
order by log_time desc
',
      p_title                  => 'Table Reorg Recommendation',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Recommendation from LOG_TABLE_REORG For Enhancing Performance ',
      p_solution               => 'Use this note to determine if reorg is recommended

Demantra  How to Use TABLE_REORG to Reorder MDP_MATRIX in Primary Key (PK) Order Action Plan Version 7.3.1.3 and Later. See 1085012.1 Prior to 7.3.1.3 [1528966/KB197148]	',
      p_success_msg            => 'There are currently no recommendations
for  a  table reorg . ',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: TABLE_REORG_LOG_TABLE_REORG');



debug('begin add_signature: WF_PROCESS_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5478',
      p_sig_id                 => 'WF_PROCESS_LOG',
      p_sig_sql                => 'select process_id "PROCESS ID",
       schema_id "SCHEMA ID",
       status "STATUS",
       substr(step_id,1,25) "STEP ID",
       num_steps "NBR STEPS",
       record_created "CREATED",
       record_updated "UPDATED"
from ##$$SCHEMA_OWNER$$##.wf_process_log
order by record_created',
      p_title                  => 'WF_PROCESS_LOG rows',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This is the first 50 rows of wf_process_log order by record_created descending.<br>
wf_process_log.status<br>
-3 = ENDLESS_LOOP<br>
-2 = FAILED<br>
-1 = TERMINATED<br>
 0 = COMPLETED<br>
 1 = ACTIVE<br>
 2 = PAUSED',
      p_solution               => 'Address as required.',
      p_success_msg            => 'There are no rows in the WF_PROCESS_LOG table.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: WF_PROCESS_LOG');



debug('begin add_signature: DBHINT_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6762',
      p_sig_id                 => 'DBHINT_PARAMETERS',
      p_sig_sql                => 'select pname, pval
from ##$$SCHEMA_OWNER$$##.db_params
where lower(pname) like ''%hint%''',
      p_title                  => 'DBHint Performance and Scalability',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Performance and Scalability: Usage of Database (SQL) Hints, Parallelism and Other Methods

New system parameters were added to grant users more advanced controls of how Demantra executes specific processes. This will enable implementations to be tuned based on each implementations unique characteristic. This process relies almost entirely of the expertise of the persons participating, and may, if done incorrectly, cause system issues. Parameters were added to the DB_PARAMS table to allow for the activation and deactivation of certain low level processes - for example, the number of commit statements issued during the run of a stored procedure can have adverse affects on performance due to logging and other issues, it could be that reducing the number of commits will provide the performance gain required.',
      p_solution               => 'Please see [879014/KB270233] Demantra Platform and Solutions Release 7.3.0 Technical Transfer of Information (TOI)',
      p_success_msg            => 'Please see [879014/KB270233] Demantra Platform and Solutions Release 7.3.0 Technical Transfer of Information (TOI)',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: DBHINT_PARAMETERS');



debug('begin add_signature: EP_LOAD_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6763',
      p_sig_id                 => 'EP_LOAD_PARAMETERS',
      p_sig_sql                => 'select pname, pval
from ##$$SCHEMA_OWNER$$##.db_params
where lower(pname) like ''%ep_load%''',
      p_title                  => 'EP_Load Performance and Scalability',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Performance and Scalability: Usage of Database (SQL) Hints, Parallelism and Other Methods

New system parameters were added to grant users more advanced controls of how Demantra executes specific processes. This will enable implementations to be tuned based on each implementations unique characteristic. This process relies almost entirely of the expertise of the persons participating, and may, if done incorrectly, cause system issues. Parameters were added to the DB_PARAMS table to allow for the activation and deactivation of certain low level processes - for example, the number of commit statements issued during the run of a stored procedure can have adverse affects on performance due to logging and other issues, it could be that reducing the number of commits will provide the performance gain required.',
      p_solution               => 'Please see [879014/KB270233] Demantra Platform and Solutions Release 7.3.0 Technical Transfer of Information (TOI)',
      p_success_msg            => 'Please see [879014/KB270233] Demantra Platform and Solutions Release 7.3.0 Technical Transfer of Information (TOI)',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: EP_LOAD_PARAMETERS');



debug('begin add_signature: MDP_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6764',
      p_sig_id                 => 'MDP_PARAMETERS',
      p_sig_sql                => 'select pname, pval
from ##$$SCHEMA_OWNER$$##.db_params
where lower(pname) like ''%mdp_add%''',
      p_title                  => 'MDP PARAMETERS Performance and Scalability: Usage of Database (SQL) Hints, Parallelism and Other Methods',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Performance and Scalability: Usage of Database (SQL) Hints, Parallelism and Other Methods

New system parameters were added to grant users more advanced controls of how Demantra executes specific processes.  This will enable implementations to be tuned based on each implementations unique characteristic.  This process relies almost entirely of the expertise of the persons participating, and may, if done incorrectly, cause system issues.  Parameters were added to the DB_PARAMS table to allow for the activation and deactivation of certain low level processes - for example, the number of commit statements issued during the run of a stored procedure can have adverse affects on performance due to logging and other issues, it could be that reducing the number of commits will provide the performance gain required.',
      p_solution               => 'Please see [879014/KB270233] Demantra Platform and Solutions Release 7.3.0 Technical Transfer of Information (TOI)',
      p_success_msg            => 'Please see [879014/KB270233] Demantra Platform and Solutions Release 7.3.0 Technical Transfer of Information (TOI)',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: MDP_PARAMETERS');



debug('begin add_signature: PARALLEL_MAX_SERVERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6474',
      p_sig_id                 => 'PARALLEL_MAX_SERVERS',
      p_sig_sql                => 'select value from v$parameter
where name = ''parallel_max_servers''',
      p_title                  => 'Parallel_max_servers sets the Oracle RDBMS instance ceiling of possible parallel queries started or allocated.',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'As an approximate guideline, the number of parallel queues should not exceed the number of CPUs in your Demantra deployment.  Implementing PARALLEL_MAX_SERVERS CPU Count 10 for example:<br>
This sets the Oracle RDBMS instance ceiling of possible parallel queries started or allocated: (eg. P000, P0001)<br>
- Using parallel is very resource hungry.  It should not be used when there are multiple users trying to use the application.<br>
- It is effective for large queries and updates where they are few users.  For example the data load process or worksheet operations.<br>

A parallel query may need (2 x N) + 1 processes, where N is the parallel degree.<br>
- Parallel degree 2 may need 5  processes.<br>
- Parallel degree 6 may need 13 processes.',
      p_solution               => 'Please see [124452/KB149704] How to set the Parameters parallel_max_servers and parallel_min_servers
',
      p_success_msg            => 'Review your parameter setting using the following:<br>
Please see [124452/KB149704] How to set the Parameters parallel_max_servers and parallel_min_servers',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: PARALLEL_MAX_SERVERS');



debug('begin add_signature: ROLLING_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6765',
      p_sig_id                 => 'ROLLING_PARAMETERS',
      p_sig_sql                => 'select pname, pval
from ##$$SCHEMA_OWNER$$##.db_params
where lower(pname) like ''%rollingupdates%''',
      p_title                  => 'ROLLING Updates Performance and Scalability',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Performance and Scalability: Usage of Database (SQL) Hints, Parallelism and Other Methods<br>

New system parameters were added to grant users more advanced controls of how Demantra executes specific processes.  This will enable implementations to be tuned based on each implementations unique characteristic.  This process relies almost entirely of the expertise of the persons participating, and may, if done incorrectly, cause system issues.  Parameters were added to the DB_PARAMS table to allow for the activation and deactivation of certain low level processes - for example, the number of commit statements issued during the run of a stored procedure can have adverse affects on performance due to logging and other issues, it could be that reducing the number of commits will provide the performance gain required.',
      p_solution               => 'Please see [879014/KB270233] Demantra Platform and Solutions Release 7.3.0 Technical Transfer of Information (TOI)',
      p_success_msg            => 'Please see [879014/KB270233] Demantra Platform and Solutions Release 7.3.0 Technical Transfer of Information (TOI)',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: ROLLING_PARAMETERS');



debug('begin add_signature: VERIFY_ASYNCHRONOUS _IO');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6444',
      p_sig_id                 => 'VERIFY_ASYNCHRONOUS _IO',
      p_sig_sql                => 'select name,asynch_io 
from v$datafile f,v$iostat_file i
where f.file#=i.file_no
and (filetype_name=''Data File'' or filetype_name=''Temp File'')
and asynch_io = ''ASYNC_OFF''',
      p_title                  => 'Ensure asynchronous I/O is enabled on all datafiles and tempfiles.',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'If asynchronous I/O is not enabled set disk_asynch_io=true.  Note that on Linux, async IO can be silently disabled if the max number of async IO slots are used up.  This can be one reason why the query above reflects async off when disk_asynch_io is true.  The max number of async IO slots can be found in /proc/sys/fs/aio-max-nr and the currently used slots can be found in /proc/sys/fs/aio-nr<br>

$ more aio-max-nr<br>
65536<br>

$ more aio-nr<br>
22136
',
      p_solution               => 'We cannot advise the proper settings for your environment however please refer to the following:
[2242312/KB390059] Engine Manager Time Out Warning Message In Engine Manager Log-- WARNING [ManagerServiceListener] Got timeout while waiting for notifications.',
      p_success_msg            => 'The data files and temp segments are setup to use asynchronous I/O.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: VERIFY_ASYNCHRONOUS _IO');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_2787340_1_LIFT_SHIFT_CLOUD');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '26866',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_2787340_1_LIFT_SHIFT_CLOUD',
      p_sig_sql                => 'Select ''Lift and Shift to Cloud'' from dual',
      p_title                  => 'How to Lift And Shift Demantra On-premise To OCI',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'How to Lift And Shift Demantra On-premise To OCI',
      p_solution               => 'How to Lift And Shift Demantra On-premise To OCI [2787340/KB405580]',
      p_success_msg            => 'How to Lift And Shift Demantra On-premise To OCI',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_2787340_1_LIFT_SHIFT_CLOUD');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_2693617_1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '26916',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_2693617_1',
      p_sig_sql                => 'select ''Migration Strategy From 12.2.5.1 To Oracle Fusion Cloud- Demand Management Cloud'' from dual',
      p_title                  => 'Migration Strategy From 12.2.5.1 To Oracle Fusion Cloud- Demand Management Cloud',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Migration Strategy From 12.2.5.1 To Oracle Fusion Cloud- Demand Management Cloud',
      p_solution               => 'See [2693617/KB472225] Migration Strategy From 12.2.5.1 To Oracle Fusion Cloud- Demand Management Cloud',
      p_success_msg            => 'Migration Strategy From 12.2.5.1 To Oracle Fusion Cloud- Demand Management Cloud',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_2693617_1');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_RMA_2966733_1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '26919',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_RMA_2966733_1',
      p_sig_sql                => 'select ''How To Separate The RMA Order As Positive Stream?'' from dual',
      p_title                  => 'How To Separate The RMA Order As Positive Stream?',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'How To Separate The RMA Order As Positive Stream?',
      p_solution               => 'See [2966733/KB164115] How To Separate The RMA Order As Positive Stream?',
      p_success_msg            => 'How To Separate The RMA Order As Positive Stream?',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_RMA_2966733_1');



debug('begin add_signature: PREMIER_SUPPORT_11.5');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '17951',
      p_sig_id                 => 'PREMIER_SUPPORT_11.5',
      p_sig_sql                => 'select release_name from fnd_product_groups
where release_name like ''11.5%''',
      p_title                  => 'Application Version 11.5',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Premier Support for the application version on this instance ended on November 2010. Please refer to  Oracle''s Lifetime Support Policy<br>
Ignore this warning if you have upgraded since this analyzer output was generated.',
      p_solution               => 'Please consider these timelines for upgrade planning. Updating the application version will ensure you have access to major product releases.  Review: <br>
 [11007164/KA692] - Information Center: Oracle Database 19c with Oracle E-Business Suite 12.2 and 12.1 (KA692)<br> - Click on Support Policy Tab to see the Applications Lifetime Support Policy.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '12'
      );
   l_info.delete;
debug('end add_signature: PREMIER_SUPPORT_11.5');



debug('begin add_signature: PREMIER_SUPPORT_12.0');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '17602',
      p_sig_id                 => 'PREMIER_SUPPORT_12.0',
      p_sig_sql                => 'select release_name from fnd_product_groups
where release_name like ''12.0%''',
      p_title                  => 'Application Version 12.0',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Premier Support for the application version on this instance ended on January 2012. Please refer to Oracle''s Lifetime Support Policy.<br>Ignore this warning if you have upgraded since this analyzer output was generated.',
      p_solution               => 'Please consider these timelines for upgrade planning. Updating the application version will ensure you have access to major product releases. Refer:  <br>
<br> [11007164/KA692] - Information Center: Oracle Database 19c with Oracle E-Business Suite 12.2 and 12.1 (KA692)<br>',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '14'
      );
   l_info.delete;
debug('end add_signature: PREMIER_SUPPORT_12.0');



debug('begin add_signature: PREMIER_SUPPORT_12.1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '17952',
      p_sig_id                 => 'PREMIER_SUPPORT_12.1',
      p_sig_sql                => 'select release_name from fnd_product_groups
where release_name like ''12.1%''',
      p_title                  => 'Application Version 12.1',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Premier Support End for the application version on this instance: December 2021. Please refer to Oracle''s Lifetime Support Policy. <br>Ignore this warning if you have upgraded since this analyzer output was generated.',
      p_solution               => 'Updating the application version will ensure you have access to major product releases.  Refer:  <br>
[11007164/KA692] - Information Center: Oracle Database 19c with Oracle E-Business Suite 12.2 and 12.1 (KA692)<br>
If you are an Oracle-E-Business Suite Release 12.1.3 customer that is planning to upgrade to EBS 12.2 or move to Oracle SaaS, but are not able to complete the transition prior to January 1, 2022, you may use Oracle Market Driven Support (MDS) to bridge the support gap.  Additional details regarding MDS for EBS 12.1.3 are available here<br>
[11007164/KA692] ANNOUNCEMENT: Additional Coverage Options for 12.1.3 E-Business Suite Sustaining Support',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '13'
      );
   l_info.delete;
debug('end add_signature: PREMIER_SUPPORT_12.1');



debug('begin add_signature: PREMIER_SUPPORT_DB_CHECK_11');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '17954',
      p_sig_id                 => 'PREMIER_SUPPORT_DB_CHECK_11',
      p_sig_sql                => 'SELECT banner from V$VERSION WHERE ROWNUM = 1
and (banner like ''%11.2%'' or banner like ''%11.1%'' or banner like ''%10.%'')',
      p_title                  => 'Database in Sustaining Support',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The database version running on this instance is in Sustaining Support. Please refer to Lifetime Support Policy: Oracle Technology Products (PDF) - Oracle Database Releases.<br>Ignore this warning if you have upgraded since this analyzer output was generated.',
      p_solution               => 'The database version running on this instance is in Premier Support.<br> 
[11007164/KA692] - Information Center: Oracle Database 19c with Oracle E-Business Suite 12.2 and 12.1 (KA692)<br>
Ignore this warning if you have upgraded since this analyzer output was generated.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: PREMIER_SUPPORT_DB_CHECK_11');



debug('begin add_signature: PREMIER_SUPPORT_DB_CHECK_12.1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '17955',
      p_sig_id                 => 'PREMIER_SUPPORT_DB_CHECK_12.1',
      p_sig_sql                => 'SELECT banner from V$VERSION WHERE ROWNUM = 1
and (banner like ''%12.1%'')',
      p_title                  => 'Database in Extended Support',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The database version running on this instance is in Extended Support. Please refer to Lifetime Support Policy: Oracle Technology Products (PDF) - Oracle Database Releases.<br>Ignore this warning if you have upgraded since this analyzer output was generated.',
      p_solution               => 'The database version running on this instance is in Extended Support.<br>
[11007164/KA692] - Information Center: Oracle Database 19c with Oracle E-Business Suite 12.2 and 12.1 (KA692)<br>
Ignore this warning if you have upgraded since this analyzer output was generated.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: PREMIER_SUPPORT_DB_CHECK_12.1');



debug('begin add_signature: EBS_ATG_ECC_12_2_7');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '26198',
      p_sig_id                 => 'EBS_ATG_ECC_12_2_7',
      p_sig_sql                => 'select release_name from fnd_product_groups where release_name in (''12.2.0'' , ''12.2.1'' , ''12.2.2'' , ''12.2.3'' , ''12.2.4'' , ''12.2.5'' , ''12.2.6'')',
      p_title                  => 'E-Business Suite 12.2 Error Correction',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Effective July 1, 2024, the E-Business Suite 12.2 Error Correction Baseline will be 12.2.7.<br><br>

',
      p_solution               => 'Updating the application version to release 12.2.7 or higher, will ensure you have access to major product releases.<br><br>
Refer to [1195034/KB696368] Applications Lifetime Support Policy<br><br>
<a href="https://blogs.oracle.com/ebstech/post/update-error-correction-baseline-for-ebs-122"target="_blank">Oracle E-Business Suite Technology Blog</a> Update: Error Correction Baseline for EBS 12.2<br><br>


Customers running E-Business Suite products on the 12.2.3 - 12.2.6 release levels are encouraged to update to current code levels of those products before July 2024 so they can benefit from the simpler and smaller patches that will be available starting in July 2024.<br><br>

 In the event a new issue is reported on a product at a code level below the baseline, Oracle Support will attempt to resolve the issue and engage Development if necessary.  Development may determine that the issue can be resolved at the customer’s code level, or may determine that the only practical way to provide the fix is for the customer to apply the baseline (or later) code in the affected area, and provide the fix at that level.<br><br>

Customers operating below the baseline level are still supported, but the process for getting a fix that’s applicable to their system may involve more interaction with Support and Development than if they were above the baseline, which may extend the time required to resolve the issue.<br><br>',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_ECC_12_2_7');



debug('begin add_signature: EBS_MFG_VCP_MSCDPA_SQL_2923838_1_LATEST');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25331',
      p_sig_id                 => 'EBS_MFG_VCP_MSCDPA_SQL_2923838_1_LATEST',
      p_sig_sql                => 'select ''12.2.12 is the Latest Available.  See 2923838.1 for details'' " "
from dual',
      p_title                  => 'What is the Latest Available Version for Demantra',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'What is the latest version available?',
      p_solution               => 'See [2923838.1] Latest Certifications for Demantra 12.2.12 version
',
      p_success_msg            => 'What is the latest version available?',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_VCP_MSCDPA_SQL_2923838_1_LATEST');



EXCEPTION WHEN OTHERS THEN
  print_log('Error in load_signatures');
  raise;
END load_signatures;


---------------------------------
-- MAIN ENTRY POINT
---------------------------------
PROCEDURE main(
            p_schema_owner                 IN VARCHAR2    DEFAULT NULL
           ,p_middle_tier_cpu              IN NUMBER      DEFAULT 1
           ,p_max_output_rows              IN NUMBER      DEFAULT 50
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y')

 IS

  l_sql_result VARCHAR2(1);
  l_step       VARCHAR2(5);
  --l_analyzer_end_time   TIMESTAMP;

BEGIN

  l_step := '1';
  initialize_globals;

  -- Workaround for handling debugging before file init
  g_debug_mode := nvl(p_debug_mode, 'Y');
  g_params_string := '';

  IF (p_middle_tier_cpu IS NOT NULL) THEN
    g_params_string := g_params_string || to_char(p_middle_tier_cpu) || '_';
  END IF;


  l_step := '10';
  initialize_files;

  analyzer_title := 'Demantra Configuration Analyzer';
  analyzer_title := regexp_replace('EBS ' || analyzer_title, '(\S+\s)\1', '\1', 1, 0, 'i');  -- EBSAF-243

  l_step := '15';
   validate_parameters(
     p_schema_owner                 => upper(p_schema_owner)
    ,p_middle_tier_cpu              => p_middle_tier_cpu
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );


  l_step := '20';
  set_cloud_flag;

  l_step := '23';
  set_snap_days;

  l_step := '25';
  print_page_header;

  l_step := '30';
  print_rep_header(analyzer_title);
  --print_execdetails;
  print_feedback;
  print_parameters;
  print_whatsnew;

  l_step := '40';
  load_signatures;

  l_step := '45';
  create_hyperlink_table;

  l_step := '50';
  initialize_hidden_xml;

  -- Start of Sections and signatures
  l_step := '60';
  debug('begin section: Main Section');
  -- Print the menu of the section screen
  start_main_section;

debug('begin section: Threadpool_Analysis');
start_section('Threadpool Analysis<br>Click This Tile.  Then click the stack <br>Upper Left', 'Threadpool_Analysis');
threadpool;

cpu_required;

maxdbconnections_cpu_check;

concurrent_users_derived;

max_parallel_cpu_comp;
   set_item_result(run_stored_sig('CONCURRENT_USERS_ONLINE'));
end_section;
debug('end section: Threadpool_Analysis');

debug('begin section: Worksheet');
start_section('Worksheet', 'Worksheet');
   set_item_result(run_stored_sig('APPROVALPROCESSSCOPE'));
   set_item_result(run_stored_sig('CACHE SIZE CALCULATIONS'));
   set_item_result(run_stored_sig('CHAINED_ROWS_PERCENT'));
   set_item_result(run_stored_sig('CLIENT.UILIMITATIONS.WARNING PARAMETER'));
   set_item_result(run_stored_sig('COMBINATIONS_DATE_RANGE'));
   set_item_result(run_stored_sig('DEAD_COMBINATIONS'));
   set_item_result(run_stored_sig('DEM_ LRU_CACHE'));
   set_item_result(run_stored_sig('ENABLEWORKSHEETCACHING'));
   set_item_result(run_stored_sig('GROUP_TABLES_TABLE_INCORRECT'));
   set_item_result(run_stored_sig('MAX_SALES_DATE_POPULATE'));
   set_item_result(run_stored_sig('MAX_SALES_DATE_SALES_DATA'));
   set_item_result(run_stored_sig('MIN_DATE_SALES_DATA'));
   set_item_result(run_stored_sig('MISSING_SALES_DATA'));
   set_item_result(run_stored_sig('PRE_LOGON_CHECK'));
   set_item_result(run_stored_sig('SERIES CONFIGURATION'));
   set_item_result(run_stored_sig('UI_WORKSHEET_LIMITATIONS'));
   set_item_result(run_stored_sig('UPDATE_COMBINATIONS'));
   set_item_result(run_stored_sig('WORKSHEET.DATA.COMB.BLOCK_SIZE'));
   set_item_result(run_stored_sig('Worksheet Parallel Hints'));
end_section;
debug('end section: Worksheet');

debug('begin section: Forecast_Data');
start_section('Forecast Data', 'Forecast_Data');
   set_item_result(run_stored_sig('CAUSAL_FACTOR_LIST'));
   set_item_result(run_stored_sig('DEMANTRA_NON-DUPLICATE_BASE_LEVELS'));
   set_item_result(run_stored_sig('DUPLICATE_COLLECTED_DATA'));
   set_item_result(run_stored_sig('DUPLICATE RELATION VALUE'));
   set_item_result(run_stored_sig('FORECAST_HISTORY_STATUS'));
   set_item_result(run_stored_sig('FORECAST_LEVEL_STRUCTURE'));
   set_item_result(run_stored_sig('FORECAST_TREE'));
   set_item_result(run_stored_sig('PREDICTION_STATUS_ANALYSIS'));
   set_item_result(run_stored_sig('PREDICTION_STATUS_IMPACT'));
   set_item_result(run_stored_sig('PURGE OLD DATA'));
   set_item_result(run_stored_sig('TOP_LEVEL_MINUS_ONE'));
end_section;
debug('end section: Forecast_Data');

debug('begin section: ParametersPlusUserSpecificData');
start_section('Parameters Plus User Specific Data', 'ParametersPlusUserSpecificData');
   set_item_result(run_stored_sig('APPLICATION_SERVER_PARAMETERS'));
   set_item_result(run_stored_sig('CONNECTION POOL PARAMETERS'));
   set_item_result(run_stored_sig('DEM_APS_PARAMS'));
   set_item_result(run_stored_sig('DEM_DB_PARAMS'));
   set_item_result(run_stored_sig('DEM_INIT_PARAMS_0'));
   set_item_result(run_stored_sig('DEM_INIT_PARAMS_1'));
   set_item_result(run_stored_sig('DEM_INIT_PARAMS_99'));
   set_item_result(run_stored_sig('DEM_SYS_PARAMS'));
   set_item_result(run_stored_sig('DEMANTRA_MODIFIED_PARAMETERS'));
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_2118871_1'));
   set_item_result(run_stored_sig('EMAIL_SETUP_CHECK'));
   set_item_result(run_stored_sig('ENVIRONMENT_PARAMETERS'));
   set_item_result(run_stored_sig('MSD_DEM_DEBUG_MODE_CHECK'));
   set_item_result(run_stored_sig('MSD_DEM_HOST_URL_CHECK'));
   set_item_result(run_stored_sig('MSD_DEM_SCHEMA_CHECK'));
   set_item_result(run_stored_sig('TIME_CONTROL_APS_PARAMS'));
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_AUDIT_563555_1'));
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_AUDIT_TRAIL_563555_1'));
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_DEMANTRA_PARAM_AUDIT_RECORDED'));
end_section;
debug('end section: ParametersPlusUserSpecificData');

debug('begin section: Database');
start_section('Database', 'Database');
   set_item_result(run_stored_sig('AVAILABLE_SCHEMAS'));
   set_item_result(run_stored_sig('CHAINED_ROWS_PERCENT'));
   set_item_result(run_stored_sig('CURSOR_SHARING_VERIFY'));
   set_item_result(run_stored_sig('DBA_NETWORK_ACLS_PRIVS'));
   set_item_result(run_stored_sig('DEFAULT_PERFORMANCE_PARAMETERS'));
   set_item_result(run_stored_sig('DEMANTRA_CURSOR_SHARING'));
   set_item_result(run_stored_sig('DICTIONARY CORRUPTION'));
   set_item_result(run_stored_sig('EBR CHECK'));
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_GLOB_COMPILE_TEMP_2817525_1'));
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_2912865_1'));
   set_item_result(run_stored_sig('EXECUTE PRIVILEGE ON DL_LOG_STATUS'));
   set_item_result(run_stored_sig('INVALID_OBJECTS'));
   set_item_result(run_stored_sig('INSTANCE_REPORT'));
   set_item_result(run_stored_sig('LAST_ANALYZED'));
   set_item_result(run_stored_sig('OPTIMIZER_INDEX_CACHING_DEMANTRA'));
   set_item_result(run_stored_sig('OPTIMIZER_INDEX_COST_ADJ_DEMANTRA'));
   set_item_result(run_stored_sig('OPTIMIZER_USE_SQL_PLAN_BASELINES'));
   set_item_result(run_stored_sig('OS_RESOURCE_LIMITS'));
   set_item_result(run_stored_sig('RDBMS_CURSOR_SHARING'));
   set_item_result(run_stored_sig('SALES_DATA_CHAIN_ROWS_PERCENT'));
   set_item_result(run_stored_sig('VERIFY_DEMANTRA_PACKAGE'));
   set_item_result(run_stored_sig('VERSION_DETAILS_HISTORY'));
   set_item_result(run_stored_sig('WAIT FOR STARTUP'));
   set_item_result(run_stored_sig('SALES_DATA_COLUMN_COUNT'));
end_section;
debug('end section: Database');

debug('begin section: Import_Export');
start_section('Import - Export', 'Import_Export');
   set_item_result(run_stored_sig('BIIO_CTO_DATA_ERR'));
   set_item_result(run_stored_sig('BIIO_CTO_LEVEL_ERR'));
   set_item_result(run_stored_sig('DEMANTRA_NON-DUPLICATE_BASE_LEVELS'));
   set_item_result(run_stored_sig('EBS_SALES_IMPORT_ERRORS'));
   set_item_result(run_stored_sig('BIIO_CTO_POPULATION_ERR'));
   set_item_result(run_stored_sig('EBS_ITEM_IMPORT_ERRORS'));
   set_item_result(run_stored_sig('EBS_LOCATION_IMPORT_ERRORS'));
   set_item_result(run_stored_sig('EP_LOAD_ORA-1652'));
   set_item_result(run_stored_sig('EVENT SUBSCRIPTION LICENSE FLAG'));
   set_item_result(run_stored_sig('EXPORT TO EXCEL - FILLVALUEEXPORTTOEXCEL PARAMETER'));
   set_item_result(run_stored_sig('INTEG_STATUS'));
   set_item_result(run_stored_sig('LEGACY_ITEM_IMPORT_ERRORS'));
   set_item_result(run_stored_sig('LEGACY_LOCATION_IMPORT_ERRORS'));
   set_item_result(run_stored_sig('STATSLOWROWLIMIT'));
   set_item_result(run_stored_sig('TRANSFER_LIST_470192.1'));
   set_item_result(run_stored_sig('DB_EXCEPTION_LOG_2209403.1'));
end_section;
debug('end section: Import_Export');

debug('begin section: LogsORAErrorsinLogs');
start_section('Logs + ORA Errors in Logs', 'LogsORAErrorsinLogs');
   set_item_result(run_stored_sig('ALL_DBEX_LOGS'));
   set_item_result(run_stored_sig('AQ CLEANUP'));
   set_item_result(run_stored_sig('DB_AUDIT_LOG'));
   set_item_result(run_stored_sig('DB_CALL_LOG'));
   set_item_result(run_stored_sig('DB_DETAILED_SECTION_LOG'));
   set_item_result(run_stored_sig('DB_EXCEPTION_LOG'));
   set_item_result(run_stored_sig('DB_EXCEP_LOG_ORA-24019_2180246.1'));
   set_item_result(run_stored_sig('DB_HEALTH_LOG'));
   set_item_result(run_stored_sig('DB_INFO_LOG'));
   set_item_result(run_stored_sig('DB_SECTION_LOG'));
   set_item_result(run_stored_sig('DB_SQL_LOG'));
   set_item_result(run_stored_sig('DB_TIMING_LOG'));
   set_item_result(run_stored_sig('EP_LOAD_ORA-1652'));
   set_item_result(run_stored_sig('LOG_IT_PARAMS'));
   set_item_result(run_stored_sig('TABLE_REORG_LOG_TABLE_REORG'));
   set_item_result(run_stored_sig('WF_PROCESS_LOG'));
end_section;
debug('end section: LogsORAErrorsinLogs');

debug('begin section: Parallel');
start_section('Parallel Processing', 'Parallel');
   set_item_result(run_stored_sig('DBHINT_PARAMETERS'));
   set_item_result(run_stored_sig('EP_LOAD_PARAMETERS'));
   set_item_result(run_stored_sig('MDP_PARAMETERS'));
   set_item_result(run_stored_sig('PARALLEL_MAX_SERVERS'));
   set_item_result(run_stored_sig('ROLLING_PARAMETERS'));
   set_item_result(run_stored_sig('VERIFY_ASYNCHRONOUS _IO'));
end_section;
debug('end section: Parallel');

debug('begin section: DEMANTRA_CLOUD_OCI');
start_section('Cloud / OCI', 'DEMANTRA_CLOUD_OCI');
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_2787340_1_LIFT_SHIFT_CLOUD'));
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_2693617_1'));
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_RMA_2966733_1'));
end_section;
debug('end section: DEMANTRA_CLOUD_OCI');

debug('begin section: LifetimeSupportPolicy_COPY');
start_section('Critical Alerts', 'LifetimeSupportPolicy_COPY');
   set_item_result(run_stored_sig('PREMIER_SUPPORT_11.5'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_12.0'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_12.1'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_DB_CHECK_11'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_DB_CHECK_12.1'));
   set_item_result(run_stored_sig('EBS_ATG_ECC_12_2_7'));
end_section;
debug('end section: LifetimeSupportPolicy_COPY');

debug('begin section: PATCH_GAP_ANALYSIS');
start_section('Patch, RDBMS, Windows Recommendations-Click This Tile<BR>Then click the stack Upper Left', 'PATCH_GAP_ANALYSIS');
patch_gap_analysis;
   set_item_result(run_stored_sig('EBS_MFG_VCP_MSCDPA_SQL_2923838_1_LATEST'));
   set_item_result(run_stored_sig('VERSION_DETAILS_HISTORY'));
end_section;
debug('end section: PATCH_GAP_ANALYSIS');



  -- End of Sections and signatures
  end_main_section;
  debug('end section: Main Section');

  l_step := '140';
  --g_analyzer_elapsed := stop_timer(g_analyzer_start_time);
  --get_current_time(l_analyzer_end_time);
  --print_execution_time (l_analyzer_end_time);
  print_execdetails;

  print_mainpage;

  print_footer;

  print_hidden_xml;

  print_sig_exceptions;

  close_files;

EXCEPTION WHEN others THEN
  g_retcode := 2;
  g_errbuf := 'Error in main at step '||l_step||': '||sqlerrm;
  print_log(g_errbuf);

END main;


PROCEDURE main_cp(
            errbuf                         OUT VARCHAR2
           ,retcode                        OUT VARCHAR2
           ,p_schema_owner                 IN VARCHAR2    DEFAULT NULL
           ,p_middle_tier_cpu              IN NUMBER      DEFAULT 1
           ,p_max_output_rows              IN NUMBER      DEFAULT 50
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y'
)
 IS

BEGIN
  g_retcode := 0;
  g_errbuf := null;

   main(
     p_schema_owner                 => upper(p_schema_owner)
    ,p_middle_tier_cpu              => p_middle_tier_cpu
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );


  retcode := g_retcode;
  errbuf  := g_errbuf;
EXCEPTION WHEN OTHERS THEN
  retcode := '2';
  errbuf := 'Error in main_cp: '||sqlerrm||' : '||g_errbuf;
END main_cp;


END dm_demantra_analyzer_pkg;
/
show errors
exit;
-- Exit required for bundling project so do not remove
