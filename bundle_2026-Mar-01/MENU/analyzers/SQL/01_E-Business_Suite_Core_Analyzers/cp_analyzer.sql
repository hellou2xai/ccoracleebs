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
REM |    cp_analyzer.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    SQL to install package used for Concurrent Processing Analyzer         |
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


CREATE OR REPLACE PACKAGE fnd_cp_analyzer_pkg AUTHID DEFINER AS

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
(            p_min_volume                   IN NUMBER      DEFAULT 3500
           ,p_max_volume                   IN NUMBER      DEFAULT 5000
           ,p_max_output_rows              IN NUMBER      DEFAULT 30
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y')
;


PROCEDURE main_cp (
            errbuf                         OUT VARCHAR2
           ,retcode                        OUT VARCHAR2
           ,p_min_volume                   IN NUMBER      DEFAULT 3500
           ,p_max_volume                   IN NUMBER      DEFAULT 5000
           ,p_max_output_rows              IN NUMBER      DEFAULT 30
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y'
);

----------------------------------------------------------------
-- Analyzer-specific code: Function and Procedures (Spec)     --
----------------------------------------------------------------



END fnd_cp_analyzer_pkg;
/
show errors


CREATE OR REPLACE PACKAGE BODY fnd_cp_analyzer_pkg AS
-- $Id: cp_analyzer.sql, 200.125 2026/02/23 20:12:09 bburbage Exp $

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
g_analyzer_doc_id VARCHAR2(15) := TO_CHAR(TRUNC(1411723.1));
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

g_family_area      VARCHAR2(24) := 'EBS ATG';
g_framework_version VARCHAR(240) := '4.8.4';
g_rec_patch_in_dx   VARCHAR2(1) := nvl('A','A'); -- 'A' all rows, change to 'F' for failing rows in DX only
g_g2g_flag          BOOLEAN := nvl('Y','N')='Y'; -- EBSAF-272

g_banner_severity VARCHAR2(1) := 'E';
g_banner_message VARCHAR2(2000) := null;


----------------------------------------------------------------
-- Analyzer-specific code: Global Declarations                --
----------------------------------------------------------------
beginmin             number;
beginmax             number;
maxitems	     number;
cls_cnt		     number;
g_reqid_cnt	     number;
gk_reqid_cnt	     VARCHAR2(15);
g_min_vol            number;
g_max_vol            number;
g_cp_status	     VARCHAR2(15);
g_nodename	     VARCHAR2(30);
g_cp_start_date	     DATE;
g_logfile_name       VARCHAR2(240);
g_last_update_date   DATE;
g_apps_invalid_cnt   number;
g_fnd_invalid_cnt    number;
g_CU1                varchar2(15);
g_CU2                varchar2(15);
g_RUP4               varchar2(15);
g_RUP6               varchar2(15);
g_run_alone_cnt      number;
g_run_alone_now_cnt  number;
g_std_mgr            VARCHAR2(30);
g_enabled            VARCHAR2(1);
g_cache              NUMBER(3);
g_rpc2               varchar2(12);
g_rpc3               varchar2(12);
g_rpc4               varchar2(12);
g_rpc5               varchar2(12);
g_rpc_122_2016_aug   varchar2(12);
g_rpc_122_2016_dec   varchar2(12);
g_instance           V$INSTANCE.INSTANCE_NAME%TYPE;
g_apps_version       FND_PRODUCT_GROUPS.RELEASE_NAME%TYPE;
g_db_version	     V$INSTANCE.VERSION%TYPE;
g_is_33606047_applied varchar2(12);
g_is_32139972_applied varchar2(12);
g_DBbanner            VARCHAR2(255);
g_FNDRSRUN_ver        varchar2(25);
g_33671306_applied    varchar2(50);
g_2nd_latest_AD_TXK_codelevels  varchar2(50);
g_ad_codelevel                  varchar2(5);
g_latest_AD_TXK_codelevels      varchar2(50);
g_txk_codelevel       varchar2(5);
g_snapDays            number;
g_snap_days_msg       varchar2(350);
g_languages_installed number;
g_lang_list_installed varchar2(300);
g_applptmp            varchar2(350);
g_found               varchar2(5);
g_is_122              varchar2(50);

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

    l_log_file := 'CP_Analyzer_'||l_db_name||'_'||g_params_string||l_date_char||'.log';
    l_out_file := 'CP_Analyzer_'||l_db_name||'_'||g_params_string||l_date_char||'.html';
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
    print_out('<TITLE>CP Analyzer Report</TITLE>');

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
        $("div#feedback").find("a.blacklink").attr("href", "https://mosemp.us.oracle.com/epmos/faces/DocumentDisplay?id=1411723.1#feedback");

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
        <img class="header_version" src="https://www.oracle.com/webfolder/s/analyzer/cpa_latest_version.gif" title="Click here to download the latest version of Analyzer" alt="Latest Version Icon"></a>');
    print_cloud_image;
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,403,EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="thumb_up_lg" title="Analyzer Feedback: Thumbs Up"></span></a>');
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,403,EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="thumb_dn_lg" title="Analyzer Feedback: Thumbs Down"></span></a>');
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},403,EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="af_idea_lg" title="Analyzer Idea"></span></a>');
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
    print_out('<div class="menubutton" id="feedback" title="Opens the Oracle Community feedback thread"><a href="https://community.oracle.com/mosc/discussion/3093389" class="blacklink" target="new">
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
        <span id="feedback-azr">403</span>
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
<p>Please see the instructions in Doc ID 1411723.1 for running the analyzer from Sql*Plus and from Concurrent Manager as a Concurrent Program.</p><p>The framework was updated to framework version <span title="">4.8.4</span></p><p>The Data Masking feature has been expanded.&nbsp;&nbsp;&nbsp;&nbsp;<br>
1.&nbsp;&nbsp;Select data is now pre-masked at the point of collection.&nbsp;<br>
2.&nbsp;&nbsp;The masked information displayed will be just enough to permit effective review and troubleshooting of an issue.&nbsp;<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Example:&nbsp; A credit card number <strong>would</strong> be displayed as ****-****-****-1234&nbsp;<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; An employee name would be displayed as Display first and last 25% per word (J**n S**w = John Snow)<br>
3.&nbsp;&nbsp;&nbsp;The existing “Lock Icon” still provides customers the manual column scrambling capabilities, which can be used <strong>in addition to</strong> the newly introduced pre-masked data feature.&nbsp;</p><p>4. Made adjustments to the Patch Checks to remove old 11i and R12.0 patch Checks.&nbsp; Updated Recommended patches.</p>
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
            '403'
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
            '403'
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
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,403,'||l_sig.sigrepo_id||',EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="thumb_up" title="Signature Feedback: Thumbs Up"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,403,'||l_sig.sigrepo_id||',EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="thumb_dn" title="Signature Feedback: Thumbs Down"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_SIGNATURE_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},403,'||l_sig.sigrepo_id||',EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="af_idea" title="Signature Idea"></span></a>
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
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,403,'||p_sig.sigrepo_id||',EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="thumb_up" title="Signature Feedback: Thumbs Up"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,403,'||p_sig.sigrepo_id||',EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="thumb_dn" title="Signature Feedback: Thumbs Down"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_SIGNATURE_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},403,'||p_sig.sigrepo_id||',EBS,EBS ATG,EBS - Component Tools" target="_blank"><span class="af_idea" title="Signature Idea"></span></a>
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
FUNCTION tab_to_string (p_delimiter     IN  VARCHAR2 DEFAULT ',') RETURN VARCHAR2 IS
l_string     VARCHAR2(32767);
      l_lang_list_installed varchar2(4000):=null;
      l_lang varchar2(20);
      cursor c is
       select language_code
       from FND_LANGUAGES WHERE INSTALLED_FLAG in ('I');
       
BEGIN        
   open c;
   loop 
     fetch c into l_lang;
     exit when c%NOTFOUND;
   
     if  l_lang_list_installed is null then
	        l_lang_list_installed := l_lang;
	     else
	       l_lang_list_installed := l_lang_list_installed ||', '||l_lang;
     end if;
   end loop;
   close c;
   return l_lang_list_installed;
END tab_to_string;


-------------------------
-- Recommended Patches
-------------------------

FUNCTION check_rec_patches_1 RETURN VARCHAR2 IS
  /* Signature EBS_CPU_PATCHES */
  l_col_rows   COL_LIST_TBL := col_list_tbl(); -- Row values
  l_rel_rows   COL_LIST_TBL := col_list_tbl(); -- Row release
  l_hdr        VARCHAR_TBL  := varchar_tbl(); -- Column headings
  l_app_date   DATE;         -- Patch applied date
  l_extra_info HASH_TBL_4K;  -- Extra information
  l_step       VARCHAR2(10);
  l_sig        SIGNATURE_REC;
  l_rel        VARCHAR2(3);
  l_rows       NUMBER := 0;

  CURSOR get_app_date(p_ptch VARCHAR2, p_rel VARCHAR2) IS
   SELECT min(Last_Update_Date) as date_applied
    FROM Ad_Bugs Adb
    WHERE Adb.Bug_Number like p_ptch
    AND ad_patch.is_patch_applied(p_rel, -1, adb.bug_number)!='NOT_APPLIED';

BEGIN

    print_log('Processing recommended patches signature: EBS_CPU_PATCHES (check_rec_patches_1) "Recommended EBS CPU Patches" (version 54)');

  -- Column headings
  l_step := '10';
  l_hdr.extend(5);
  l_hdr(1) := 'Patch';
  l_hdr(2) := 'Applied';
  l_hdr(3) := 'Date';
  l_hdr(4) := 'Name';
  l_hdr(5) := 'Note';
  l_col_rows.extend(5);
  l_rel_rows.extend(1);

IF substr(g_rep_info('Apps Version'),1,4) = '12.1' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25032333';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: CPU PATCH FOR JAN 2017';
   l_col_rows(5)(l_rows) := '[2212223/KB859608]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25449171';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: CPU PATCH FOR APR 2017';
   l_col_rows(5)(l_rows) := '[2241313/KB852095]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25982921';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: CPU PATCH FOR JUL 2017';
   l_col_rows(5)(l_rows) := '[2270270/KB825855]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '26574496';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: CPU PATCH FOR OCT 2017';
   l_col_rows(5)(l_rows) := '[2304968/KB828584]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27040859';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR JAN 2018';
   l_col_rows(5)(l_rows) := '[2334374/KB852132]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27468057';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR APR 2018';
   l_col_rows(5)(l_rows) := '[2369524/KB838667]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28018146';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR JULY 2018';
   l_col_rows(5)(l_rows) := '[2379675/KB835545]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28421543';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR OCT 2018';
   l_col_rows(5)(l_rows) := '[2304968/KB828584]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28840561';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR JAN 2019';
   l_col_rows(5)(l_rows) := '[2480398/KB849930]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '29224722';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR APR 2019';
   l_col_rows(5)(l_rows) := '[2514102/KB825182]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '29692308';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR JULY 2019';
   l_col_rows(5)(l_rows) := '[2555452/KB814611]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30077281';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR OCT 2019';
   l_col_rows(5)(l_rows) := '[2586423/KB850257]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30445462';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR JAN 2020';
   l_col_rows(5)(l_rows) := '[2613782/KB825684]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30812013';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR APR 2020';
   l_col_rows(5)(l_rows) := '[2650675/KB828709]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31198341';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR JUL 2020';
   l_col_rows(5)(l_rows) := '[2679563/KB813546]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31643022';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: CPU PATCH FOR OCT 2020';
   l_col_rows(5)(l_rows) := '[2707309/KB839954]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '32071645';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: CPU PATCH FOR JAN 2021';
   l_col_rows(5)(l_rows) := '[2737201/KB813582]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '32438190';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: CPU PATCH FOR APR 2021';
   l_col_rows(5)(l_rows) := '[2759182/KB824049]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '32841266';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR JUL 2021';
   l_col_rows(5)(l_rows) := '[2770321/KB813535]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '33154541';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR OCT 2021';
   l_col_rows(5)(l_rows) := '[2794700/KB824138]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '33487414';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR JAN 2022';
   l_col_rows(5)(l_rows) := '[2831766/KB830441]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '33782734';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1:CPU PATCH FOR APR 2022';
   l_col_rows(5)(l_rows) := '[2856622/KB824163]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34127941';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES JUL 2022';
   l_col_rows(5)(l_rows) := '[2879381/KB844459]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34451004';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES OCT 2022';
   l_col_rows(5)(l_rows) := '[2884905/KB207093]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34726970';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES JAN 2023';
   l_col_rows(5)(l_rows) := '[2916872.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35020331';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES APR 2023';
   l_col_rows(5)(l_rows) := '[2933343.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35385902';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES JUL 2023';
   l_col_rows(5)(l_rows) := '[2953581.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35642922';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES  OCT 2023';
   l_col_rows(5)(l_rows) := '[2974658.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35967234';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES  JAN 2024';
   l_col_rows(5)(l_rows) := '[2992119.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36271496';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES (APRIL 2024)';
   l_col_rows(5)(l_rows) := '[3007753.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36561723';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES (JULY) 2024';
   l_col_rows(5)(l_rows) := '[3029478.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36944304';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES (OCT) 2024';
   l_col_rows(5)(l_rows) := '[3037726.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '37237356';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES (JAN) 2025';
   l_col_rows(5)(l_rows) := '[3061171.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '37531039';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES (APRIL 2025)';
   l_col_rows(5)(l_rows) := '[3073906.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '37923855';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES (JULY 2025)';
   l_col_rows(5)(l_rows) := '[3090430.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '38298678';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: SECURITY UPDATES (OCT 2025)';
   l_col_rows(5)(l_rows) := '[3102288.1]';

END IF;

IF substr(g_rep_info('Apps Version'),1,4) = '12.2' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25032335';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JAN 2017';
   l_col_rows(5)(l_rows) := '[2212223/KB859608]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25449173';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR APR 2017';
   l_col_rows(5)(l_rows) := '[2241313/KB852095]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25982922';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JUL 2017';
   l_col_rows(5)(l_rows) := '[2270270/KB825855]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '26574498';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR OCT 2017';
   l_col_rows(5)(l_rows) := '[2304968/KB828584]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27040860';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JAN 2018';
   l_col_rows(5)(l_rows) := '[2334374/KB852132]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27468058';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR APR 2018';
   l_col_rows(5)(l_rows) := '[2369524/KB838667]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28018169';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JULY 2018';
   l_col_rows(5)(l_rows) := '[2379675/KB835545]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28421544';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR OCT 2018';
   l_col_rows(5)(l_rows) := '[2304968/KB828584]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28840562';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2:CPU PATCH FOR JAN 2019';
   l_col_rows(5)(l_rows) := '[2480398/KB849930]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '29224724';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2:CPU PATCH FOR APR 2019';
   l_col_rows(5)(l_rows) := '[2514102/KB825182]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '29692310';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2:CPU PATCH FOR JULY 2019';
   l_col_rows(5)(l_rows) := '[2555452/KB814611]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30077283';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2:CPU PATCH FOR OCT 2019';
   l_col_rows(5)(l_rows) := '[2586423/KB850257]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30445472';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2:CPU PATCH FOR JAN 2020';
   l_col_rows(5)(l_rows) := '[2613782/KB825684]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30812019';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR APR 2020';
   l_col_rows(5)(l_rows) := '[2650675/KB828709]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31198342';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JUL 2020';
   l_col_rows(5)(l_rows) := '[2679563/KB813546]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31643029';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR OCT 2020';
   l_col_rows(5)(l_rows) := '[2707309/KB839954]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '32071646';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JAN 2021';
   l_col_rows(5)(l_rows) := '[2737201/KB813582]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '32438203';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR APR 2021';
   l_col_rows(5)(l_rows) := '[2759182/KB824049]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '32841270';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JUL 2021';
   l_col_rows(5)(l_rows) := '[2770321/KB813535]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '33154561';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR OCT 2021';
   l_col_rows(5)(l_rows) := '[2794700/KB824138]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '33487428';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JAN 2022';
   l_col_rows(5)(l_rows) := '[2815550/KB845675]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '33782739';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR APR 2022';
   l_col_rows(5)(l_rows) := '[2856621/KB847647]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34127951';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JUL 2022';
   l_col_rows(5)(l_rows) := '[2879380/KB819524]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34450992';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR OCT 2022';
   l_col_rows(5)(l_rows) := '[2884904/KB817889]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34726978';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JAN 2023';
   l_col_rows(5)(l_rows) := '[2916871.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35020334';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR APR 2023';
   l_col_rows(5)(l_rows) := '[2933342.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35385938';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JUL 2023';
   l_col_rows(5)(l_rows) := '[2953580.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35642926';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR OCT 2023';
   l_col_rows(5)(l_rows) := '[2974627.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35967254';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JAN 2024';
   l_col_rows(5)(l_rows) := '[2992118.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36271505';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR APRIL 2024';
   l_col_rows(5)(l_rows) := '[3007752.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36561740';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JULY 2024';
   l_col_rows(5)(l_rows) := '[3029477.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36944346';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR OCT 2024';
   l_col_rows(5)(l_rows) := '[3037725.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '37237361';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JAN 2025';
   l_col_rows(5)(l_rows) := '[3061170.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '37531055';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR APR 2025';
   l_col_rows(5)(l_rows) := '[3073905.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '37923872';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR JUL 2025';
   l_col_rows(5)(l_rows) := '[3090429.1]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '38298685';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.2: CPU PATCH FOR OCTOBER 2025';
   l_col_rows(5)(l_rows) := '[3102287.1]';

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '9654';
   l_sig.title := 'Recommended EBS CPU Patches';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := 'You have recommended CPU patch(es) not applied to this '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'. Please expand the list above for the details.';
   l_sig.solution := 'Above are the recommended CPU patches for E-Business Suite. <br> 
For the most current CPU recommendations, use Identifying the Latest Critical Patch Update for Oracle E-Business Suite Release 12 [11123275].<br><br>

To evaluate patches against your environment, use EBS Patch Wizard or the Updates & Patches Tab in My Oracle Support.<br>
Further guidance can be found in the following documents:
<ul>
<li>[11086538/KA747] How to Find EBS Patches and EBS Technology Patches</li>
<li>[976188/KB739927] Patch Wizard Utility</li>
<li>[10940175/KA580] Patch Wizard FAQ</li>
</ul>';
   l_sig.success_msg := 'Congratulations!  You have the latest CPU patches applied for E-Business Suite.';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'N';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='P';
   l_sig.version := '54';

   -- if snapshot is old, add message to the solution
   IF nvl(g_snap_days, 10) > 30 THEN
       l_sig.solution := l_sig.solution || '<br><br><b>ADADMIN</b>: Maintain Snapshot Information was executed more than 30 days ago.<br>It is recommended that AD Utilities (Adadmin) "Maintain Snapshot Information" is run periodically as key tools (Patch Wizard, ADPatch,etc) rely on this information being accurate and up-to-date.';
   END IF;

  -- Check if applied
  get_current_time(g_query_start_time);
  FOR i in 1..l_rows loop
    l_step := '40';
    OPEN get_app_date(l_col_rows(1)(i),l_rel_rows(1)(i));
    FETCH get_app_date INTO l_app_date;
    CLOSE get_app_date;
    l_col_rows(1)(i) := '{'||l_col_rows(1)(i)||'}';
    IF l_app_date is not null THEN
      l_step := '50';
      l_col_rows(2)(i) := 'Yes';
      l_col_rows(3)(i) := to_char(l_app_date);
    END IF;
  END LOOP;
  g_query_elapsed := stop_timer(g_query_start_time);
  debug(' Rows fetched: '||to_char(l_rows));

  -- Register
  l_step := '60';
  g_signatures('EBS_CPU_PATCHES') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'EBS_CPU_PATCHES',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_1 at step '||l_step);
  raise;
END check_rec_patches_1;

FUNCTION check_rec_patches_2 RETURN VARCHAR2 IS
  /* Signature EBS_ATG_CT_CP_PATCHES_FOR_R122 */
  l_col_rows   COL_LIST_TBL := col_list_tbl(); -- Row values
  l_rel_rows   COL_LIST_TBL := col_list_tbl(); -- Row release
  l_hdr        VARCHAR_TBL  := varchar_tbl(); -- Column headings
  l_app_date   DATE;         -- Patch applied date
  l_extra_info HASH_TBL_4K;  -- Extra information
  l_step       VARCHAR2(10);
  l_sig        SIGNATURE_REC;
  l_rel        VARCHAR2(3);
  l_rows       NUMBER := 0;

  CURSOR get_app_date(p_ptch VARCHAR2, p_rel VARCHAR2) IS
   SELECT min(Last_Update_Date) as date_applied
    FROM Ad_Bugs Adb
    WHERE Adb.Bug_Number like p_ptch
    AND ad_patch.is_patch_applied(p_rel, -1, adb.bug_number)!='NOT_APPLIED';

BEGIN

    print_log('Processing recommended patches signature: EBS_ATG_CT_CP_PATCHES_FOR_R122 (check_rec_patches_2) "Recommended Concurrent Processing Patches for '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' Release" (version 2)');

  -- Column headings
  l_step := '10';
  l_hdr.extend(5);
  l_hdr(1) := 'Patch';
  l_hdr(2) := 'Applied';
  l_hdr(3) := 'Date';
  l_hdr(4) := 'Name';
  l_hdr(5) := 'Note';
  l_col_rows.extend(5);
  l_rel_rows.extend(1);

IF substr(g_rep_info('Apps Version'),1,4) = '12.2' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36987815';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND_DCP PERFORMANCE ISSUE';
   l_col_rows(5)(l_rows) := '[3053901/KB785139]';

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '30374';
   l_sig.title := 'Recommended Concurrent Processing Patches for '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' Release';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := 'There are recommended Concurrent Processing and Technology Stack patches that are not applied on this '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' instance.';
   l_sig.solution := 'Please review the list of patches above and apply any UNAPPLIED recommended Concurrent Processing patches on this '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' instance as soon as possible.<br>
Refer to the note indicated for more information about each patch.
<br>
To get a current accurate list of recommended EBS product patches that are applied/not applied to your instance, please run Patch Wizard.</b><br>
See [976188/KB739927] - Patch Wizard Utility, [10940175/KA580] FAQ, or [1077813/KB627816] Videos for more information.<br>';
   l_sig.success_msg := 'All known recommended EBS Concurrent Processing and Technology Stack patches for release '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' have been applied.';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'N';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='P';
   l_sig.version := '2';

   -- if snapshot is old, add message to the solution
   IF nvl(g_snap_days, 10) > 30 THEN
       l_sig.solution := l_sig.solution || '<br><br><b>ADADMIN</b>: Maintain Snapshot Information was executed more than 30 days ago.<br>It is recommended that AD Utilities (Adadmin) "Maintain Snapshot Information" is run periodically as key tools (Patch Wizard, ADPatch,etc) rely on this information being accurate and up-to-date.';
   END IF;

  -- Check if applied
  get_current_time(g_query_start_time);
  FOR i in 1..l_rows loop
    l_step := '40';
    OPEN get_app_date(l_col_rows(1)(i),l_rel_rows(1)(i));
    FETCH get_app_date INTO l_app_date;
    CLOSE get_app_date;
    l_col_rows(1)(i) := '{'||l_col_rows(1)(i)||'}';
    IF l_app_date is not null THEN
      l_step := '50';
      l_col_rows(2)(i) := 'Yes';
      l_col_rows(3)(i) := to_char(l_app_date);
    END IF;
  END LOOP;
  g_query_elapsed := stop_timer(g_query_start_time);
  debug(' Rows fetched: '||to_char(l_rows));

  -- Register
  l_step := '60';
  g_signatures('EBS_ATG_CT_CP_PATCHES_FOR_R122') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'EBS_ATG_CT_CP_PATCHES_FOR_R122',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_2 at step '||l_step);
  raise;
END check_rec_patches_2;

FUNCTION check_rec_patches_3 RETURN VARCHAR2 IS
  /* Signature CP1_CHK_CP_PATCHES_R122 */
  l_col_rows   COL_LIST_TBL := col_list_tbl(); -- Row values
  l_rel_rows   COL_LIST_TBL := col_list_tbl(); -- Row release
  l_hdr        VARCHAR_TBL  := varchar_tbl(); -- Column headings
  l_app_date   DATE;         -- Patch applied date
  l_extra_info HASH_TBL_4K;  -- Extra information
  l_step       VARCHAR2(10);
  l_sig        SIGNATURE_REC;
  l_rel        VARCHAR2(3);
  l_rows       NUMBER := 0;

  CURSOR get_app_date(p_ptch VARCHAR2, p_rel VARCHAR2) IS
   SELECT min(Last_Update_Date) as date_applied
    FROM Ad_Bugs Adb
    WHERE Adb.Bug_Number like p_ptch
    AND ad_patch.is_patch_applied(p_rel, -1, adb.bug_number)!='NOT_APPLIED';

BEGIN

    print_log('Processing recommended patches signature: CP1_CHK_CP_PATCHES_R122 (check_rec_patches_3) "Suggested 12.2 Patches" (version 24)');

  -- Column headings
  l_step := '10';
  l_hdr.extend(5);
  l_hdr(1) := 'Patch';
  l_hdr(2) := 'Applied';
  l_hdr(3) := 'Date';
  l_hdr(4) := 'Name';
  l_hdr(5) := 'Note';
  l_col_rows.extend(5);
  l_rel_rows.extend(1);

IF substr(g_rep_info('Apps Version'),1,4) = '12.2' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '32931976';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '32931976: TECHP:REPACKAGING OF WLS PATCH FOR EBS 12.2 ORACLE E-BUSINESS SUITE ON OL8/RHEL8';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36987815';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '36987815:R12.FND.C - FND_DCP PERFORMANCE ISSUE';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34304527';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '3551034304527:R12.FND.C - FNDRSRUN - ENLARGED SUBMIT BUTTON AFTER 32139972 AND 33606047';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '35510389';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '35510389:R12.FND.C - CP CONSOLIDATED BUG FOR 12.2 (CP ROLLUP 2)';
   l_col_rows(5)(l_rows) := '[1411723/KB627725]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25452805';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '25452805:R12.FND.C - 12.2 Concurrent Processing RUP1 Patchset';
   l_col_rows(5)(l_rows) := '[2455612/KB519027]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34637475';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '34637475:R12.FND.C - CUSTOMER IS HAVING PERF ISSUE IN FND QUERIES AFTER UPGRADING TO 12.2.11';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34091953';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '34091953:R12.FND.C - Browser does not cache request data and gives Authentication Failed on Save';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31841845';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'REQUEST NODE AFFINITY NODE_NAME ISSUE';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '16207672';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.2 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[1506669/KB262547]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '17020683';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.3 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '17919161';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.4 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19676458';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.5 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[1983050/KB873488]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21900901';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.6 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '24690690';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.7 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[11392171/KB864614]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '26787767';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.8 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28840850';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.9 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30399999';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.10 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[2666934/KB868906]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31856789';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.11 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[11218187/KB860296]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '37182900';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.15 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[3072818/KB857116]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36026788';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.14 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[11370173/KB863883]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34776655';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.13 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[11412244/KB867433]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '33527700';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE E-BUSINESS SUITE 12.2.12 RELEASE UPDATE PACK';
   l_col_rows(5)(l_rows) := '[2876726/KB873492]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '17909318';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.4';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '17912683';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.4 - online help Patch';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19245366';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.5';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19681454';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.5 - online help Patch';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21900895';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.DELTA.6';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22569528';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.6 - online help Patch';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '24690680';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.7';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '26924701';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.7 - Consolidated Bundle Patch';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25185917';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.7 - online help Patch';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28840844';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.8';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28840884';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.ATG_PF.C.Delta.8 - online help Patch';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '29273993';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'AD CONSOLIDATED PATCH II ON TOP OF AD DELTA 10';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '29193747';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ECC CLIENT IMPLEMENTATION WITH DEPENDENCY ON';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25820377';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Fix for Bug 25820377';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30900870';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'PATCH TO DELIVER SCRIPTS TO CONF DB VAULT 19C WITH EBS 12.2';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30577813';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '12.2.X APP-FND-00706 WHEN EXPORTING DUE TO FDFDDS.O';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27366092';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:R12.2.3:FRM-92101 WHEN SEARCH ITEM IN MASTER ITEM FORM LOV POPUP';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27498121';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'VIEWING TRANS FAILS WITH JAVA.LANG.ILLEGALARGUMENT EXCEP AFTER UPGRADE TO 12.2.7';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27294144';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'PATCH TO DELIVER SCRIPTS TO CONF DB VAULT 12C WITH EBS 12.2';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25242246';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:FLEXFIELD VIEW GENERATOR GIVES SIGNAL 11 ERROR WHEN CREATE MORE 2656 CONTEXTS';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25381217';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'UNABLE TO ADD NEW MESSAGE TYPE FORMS PERSONALIZATION ACTIONS ON TOP PF EXISTING';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25598741';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:RECALCULATE PARAMETERS NOT WORKING FOR REQUEST SETS - FLEX PORTION';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22220582';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:UNABLE TO DISPLAY SIT DATA AFTER UPGRADE FROM 11I TO 12.1.3 RUP8';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '24442779';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'RBAC MODEL SETUP USAGES FOR MOBILE APPS';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22259917';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND_STATS.RESTORE_SCHEMA_STATS FOR ALL SCHEMA IS FAILED';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21187973';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'NEED REPLACEMENT FOR PATCH 9570647:R12.FND.B';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '20213516';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'QRE1225.2:GSI: LONG RUNNING : FND :AFUPDFMT.SQL (2 HRS: 29 MINS)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '20283712';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '20283712:PROXY USER IS ABLE ACCESS TOP TEN LIST';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '20255218';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:122:IN MOBILE APPLICATION, GETFLEXFIELD().GETCCID(); IS RETURNING WRONG CCID';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19891697';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2:PERFORMANCE PROBLEMS RESULTS SET CACHE';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19248704';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.3: CONSOLIDATED PATCH FOR CORE FLEXJ FILES JUL18/2014';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19259764';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ERROR WHEN OPENING FORMS IN IE8 ON MULTI-NODE EBS 12.2.3';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '17443805';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND-01564, FLEX-1406 WHEN SUBMITTING CONCURRENT PROGRAM GATHER SCHEMA STATISTICS';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '26599059';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'BACKPORT 26673691 TO 12.2.4: CONNECTION LEAK ON ERRORSTACK.TOSTRING';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27038079';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:25656271:25197573: AOLJ TRACKING BUG FOR PERFORMANCE ISSUE';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25571261';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ENTER USERNAME/PASSWORD IN USERNAME FIELD IS GRANTED TO ACCESS EBS';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21562102';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (8/2015)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '24387712';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (08/2016)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25186394';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (12/2016)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25796137';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (4/2017)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '26560435';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (12/2017)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '29295520';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (2/2019)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31427243';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (7/2020)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31563978';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (8/2020)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '34231162';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (Jun/2022)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '23059811';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'QRE1226.4:GL:CP.FDFCHY:ORA-12841: CANNOT ALTER THE SESSION PARALLEL DML STAT';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '23115501';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:APP-FND-01023 THE FOLLOWING REQUIRED FIELD DOES NOT HAVE A VALUE';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21612876';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:CONSOLIDATED PATCH/CROSS VALIDATION PERFORMANCE ISSUES';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19494816';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'JDBC CONNECTION LEAK IN ORACLE.APPS.FND.COMMON.ERRORSTACK';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19157561';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'DISABLING THE SCREENS TO REGISTER APPLICATION AND USER FORM FORMS';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28292585';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'AFTER 26663218 USERS NEED TO RESET PASSWORDS IN ORDER TO LOGIN';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '26681949';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Purge Script does not consider login_id may not exist in fnd_logins and dangling records are left in target tables.';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '23601325';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:AFTER 23115501 FNDRXR PERFORMANCE STILL EXISTS';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25039936';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '12:3:64-BIT FWD PORT 8207603 - SCRIPTS TO CONF DB VAULT 12C WITH EBS 12.2';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25190067';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.4:AFTER 23601325 WHAT DOES CROSS-VALIDATION RULE VIOLATION REPORT (ENHANCED) DO?';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '23586683';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:CCID NOT SAVED WHEN ACCOUNT SEGMENTS ARE CHANGED USING THE ACCOUNTING FLEX';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22550312';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:OVER 2300 CONTEXTS DEFINED CAUSES FNDFFVGN SIGNAL 11';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21483810';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.4:CONSOLIDATED PATCH FOR BUG#9117237 AND BUG#21388669';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19641119';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.2.3::FNDLOAD FAILS WITH ORA-00918: COLUMN AMBIGUOUSLY DEFINED';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '33671306';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12 ENHANCEMENTS: PROGRAM OPTION PROPAGATION, FILE EXT WITH FILE FORMAT, EMAIL DELIVERY ATTACHMENT OR BODY';
   l_col_rows(5)(l_rows) := '[2884245/KB791131]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '36420813';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'CONCURRENT PROGRAMS SHOWING AS RUNNING WITHOUT A DATABASE SESSION';
   l_col_rows(5)(l_rows) := '[3028299/KB787184]';

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '5756';
   l_sig.title := 'Suggested 12.2 Patches';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := 'There are suggested ATG and CP patches for R12.2 that are missing from this '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' instance.';
   l_sig.solution := 'Please apply any missing suggested ATG and CP patches for R12.2, including patches marked as recommended by development.<br><br>

For more information, please review :<br>
[11086538/KA747] How to Find E-Business Suite & E-Business Suite Technology Stack Patches.';
   l_sig.success_msg := 'All suggested ATG and CP patches for R12.2 have been applied on this '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' instance.';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'N';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='P';
   l_sig.version := '24';

   -- if snapshot is old, add message to the solution
   IF nvl(g_snap_days, 10) > 30 THEN
       l_sig.solution := l_sig.solution || '<br><br><b>ADADMIN</b>: Maintain Snapshot Information was executed more than 30 days ago.<br>It is recommended that AD Utilities (Adadmin) "Maintain Snapshot Information" is run periodically as key tools (Patch Wizard, ADPatch,etc) rely on this information being accurate and up-to-date.';
   END IF;

  -- Check if applied
  get_current_time(g_query_start_time);
  FOR i in 1..l_rows loop
    l_step := '40';
    OPEN get_app_date(l_col_rows(1)(i),l_rel_rows(1)(i));
    FETCH get_app_date INTO l_app_date;
    CLOSE get_app_date;
    l_col_rows(1)(i) := '{'||l_col_rows(1)(i)||'}';
    IF l_app_date is not null THEN
      l_step := '50';
      l_col_rows(2)(i) := 'Yes';
      l_col_rows(3)(i) := to_char(l_app_date);
    END IF;
  END LOOP;
  g_query_elapsed := stop_timer(g_query_start_time);
  debug(' Rows fetched: '||to_char(l_rows));

  -- Register
  l_step := '60';
  g_signatures('CP1_CHK_CP_PATCHES_R122') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'CP1_CHK_CP_PATCHES_R122',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_3 at step '||l_step);
  raise;
END check_rec_patches_3;

FUNCTION check_rec_patches_4 RETURN VARCHAR2 IS
  /* Signature CP1_CHK_CP_PATCHES_1213 */
  l_col_rows   COL_LIST_TBL := col_list_tbl(); -- Row values
  l_rel_rows   COL_LIST_TBL := col_list_tbl(); -- Row release
  l_hdr        VARCHAR_TBL  := varchar_tbl(); -- Column headings
  l_app_date   DATE;         -- Patch applied date
  l_extra_info HASH_TBL_4K;  -- Extra information
  l_step       VARCHAR2(10);
  l_sig        SIGNATURE_REC;
  l_rel        VARCHAR2(3);
  l_rows       NUMBER := 0;

  CURSOR get_app_date(p_ptch VARCHAR2, p_rel VARCHAR2) IS
   SELECT min(Last_Update_Date) as date_applied
    FROM Ad_Bugs Adb
    WHERE Adb.Bug_Number like p_ptch
    AND ad_patch.is_patch_applied(p_rel, -1, adb.bug_number)!='NOT_APPLIED';

BEGIN

    print_log('Processing recommended patches signature: CP1_CHK_CP_PATCHES_1213 (check_rec_patches_4) "Recommended Concurrent Processing Patches for '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' Release" (version 7)');

  -- Column headings
  l_step := '10';
  l_hdr.extend(5);
  l_hdr(1) := 'Patch';
  l_hdr(2) := 'Applied';
  l_hdr(3) := 'Date';
  l_hdr(4) := 'Name';
  l_hdr(5) := 'Note';
  l_col_rows.extend(5);
  l_rel_rows.extend(1);

IF substr(g_rep_info('Apps Version'),1,4) = '12.1' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27091621';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '27091621:R12.FND:CP CONSOLIDATED BUG FOR 12.1.3.4';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '20228512';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.3:18356549:EM_MONITOR USER REQUIRES ACCESS TO TABLES';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '17189881';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND_STATS.RESTORE_SCHEMA_STATS FOR ALL SCHEMA IS FAILED';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '14629821';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:10182664:12.1.3:UNDER HEAVY LOAD, MANAGERS SPIN AND CONSUME CPU';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30900870';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'PATCH TO DELIVER SCRIPTS TO CONF DB VAULT 19C WITH E-Business Suite';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '28547072';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'HIGHEST CPU USAGE DUE TO APPSDATASOURCE FOR ISG SERVICE AUTHENTICATION';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22879584';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Fix for Bug 22879584';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '18312333';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ADGENJKY.SH GENERATING CORE DUMP AT THE END OF EXECUTION';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '20592764';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'CONSOLIDATED AD IO PATCH FOR EBS PLUGIN 12.1.0.4.0 AND 13.1.1.1.0';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19287203';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'TECHPLAT:CHANGES REQUIRED FOR RELINKING FAILURES ON WIN 2012 R2 WITH VS2013';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '24516586';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Fix for Bug 24516586';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '12923944';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12399649:12.1.3:12.1.3:11886062 BACKPORT: TST122: TRANSACTION MANAGERS NOT';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '9888158';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'CONNECTION TAGGING AUTO RELINK FOR POST 12.1.3';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '9951284';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.3:VALUESETS WITH DUPLICATE VALUES AND/OR IDS ERROR OUT WITH APP-FND-01564';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '9951283';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'QREP1213.7:FND: FNDLIBR.EXE CRASHES ON WINDOWS (2008) AFTER APPLYING 12.1.3 MP';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '9966055';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.3:TRANSLATED VERSION OF FNDSCSGN NOT LAUNCHED';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '8599456';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.1:8441573:FNDLOAD DOWNLOAD COMMAND IS INSERTING EXTRA SPACE AFTER A NEWLINE CHARACTER';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30662189';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND ATTACHMENT DOESNT RESOLVE URL WITH JAVA WEB START ENABLED';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '27366092';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:R12.1.3:FRM-92101 WHEN SEARCH ITEM IN MASTER ITEM FORM LOV POPUP';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '26052008';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.3:VIEWING GL FLEXFIELD INDEPENDENT VALUE SET GETTING ORA-0143';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25190067';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.3:AFTER 23601325 WHAT DOES CROSS-VALIDATION RULE VIOLATION REPORT (ENHANCED) DO?';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25560789';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1 OFF: R12.1.3: ABSENCE DFF WITH PROFILE REFERENCE NOT WORKING IN ARABIC SESSION';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22220582';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.3:UNABLE TO DISPLAY SIT DATA AFTER UPGRADE FROM 11I TO 12.1.3 RUP8';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21187973';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'NEED REPLACEMENT FOR PATCH 9570647:R12.FND.B';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21044265';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'APPSTAND.FMB CALLS .FND_JAF_MESSAGE WITH APPLSYS';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '20042838';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.3:SYSTEM STATUS CHANGES FROM QUERY TO CHANGED EVEN AFTER CANCELLING THE FLEX F';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '20283712';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := '1OFF:12.1.3:20283712:PROXY USER IS ABLE ACCESS TOP TEN LIST';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19494816';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'JDBC CONNECTION LEAK IN ORACLE.APPS.FND.COMMON.ERRORSTACK';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '12783535';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'LDT LOG FILES SHOWING THE VALUE CANNOT BE UPLOADED WITHOUT A PREPARE STATEMENT';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '13723427';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'CONNECTION LEAK ON LOGIN';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '11767687';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'THE CONCURRENT PROCESSING REQUEST INSTANCE / NODE AFFINITY OPTION DOES NOT WORK';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '12921332';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Fix for Bug 12921332';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '10104874';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'CONNECTION LEAKS FROM FNDGFM.JSP';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '9907719';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R1213:PERF: LEAKEDCONNECTIONEXCEPTION 1, 0X1421FC8, 2010-05-17+14:09:23.745-0700';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25449171';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ORACLE APPLICATIONS RELEASE 12.1: CPU PATCH FOR APR 2017';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25803296';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'VIEW BY SESSION ON PAGE ACCESS TRACKING RENDERS REPORT WITH VIEW BY PAGE';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25981801';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'OAM:12.1.3+ RECOMMENDED PATCHES TO BE ADDED TO THE PRODUCT RPC AS OF MAY-1-2017';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25186354';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (12/2016)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '24505803';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'PATCH WIZARD RECOMMENDS AD/TXK DELTA BUNDLE PATCHES AFTER APPLYING AD/TXK DELTA8';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '25796080';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (4/2017)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '29295435';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (2/2019)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '30369960';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (11/2019)';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '31427181';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'FND Recommended Patch Collection (6/2020)';
   l_col_rows(5)(l_rows) := NULL;

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '14756';
   l_sig.title := 'Recommended Concurrent Processing Patches for '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' Release';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := '<p>There are recommended Concurrent Processing and Technology Stack patches that are not applied on this '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' instance.</p>';
   l_sig.solution := 'Please review the list of patches above and apply any UNAPPLIED recommended Concurrent Processing patches on this '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' instance as soon as possible.<br>
Refer to the note indicated for more information about each patch.
<br>
<br><b>To get a current accurate list of recommended EBS product patches that are applied/not applied to your instance, please run Patch Wizard.</b><br>
	See [976188/KB739927] - Patch Wizard Utility, [10940175/KA580] FAQ, or [1077813/KB627816] Videos for more information.<br>';
   l_sig.success_msg := '<b>All known recommended EBS Concurrent Processing and Technology Stack patches for release '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' have been applied.</b>
	  ';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'N';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='P';
   l_sig.version := '7';

   -- if snapshot is old, add message to the solution
   IF nvl(g_snap_days, 10) > 30 THEN
       l_sig.solution := l_sig.solution || '<br><br><b>ADADMIN</b>: Maintain Snapshot Information was executed more than 30 days ago.<br>It is recommended that AD Utilities (Adadmin) "Maintain Snapshot Information" is run periodically as key tools (Patch Wizard, ADPatch,etc) rely on this information being accurate and up-to-date.';
   END IF;

  -- Check if applied
  get_current_time(g_query_start_time);
  FOR i in 1..l_rows loop
    l_step := '40';
    OPEN get_app_date(l_col_rows(1)(i),l_rel_rows(1)(i));
    FETCH get_app_date INTO l_app_date;
    CLOSE get_app_date;
    l_col_rows(1)(i) := '{'||l_col_rows(1)(i)||'}';
    IF l_app_date is not null THEN
      l_step := '50';
      l_col_rows(2)(i) := 'Yes';
      l_col_rows(3)(i) := to_char(l_app_date);
    END IF;
  END LOOP;
  g_query_elapsed := stop_timer(g_query_start_time);
  debug(' Rows fetched: '||to_char(l_rows));

  -- Register
  l_step := '60';
  g_signatures('CP1_CHK_CP_PATCHES_1213') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'CP1_CHK_CP_PATCHES_1213',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_4 at step '||l_step);
  raise;
END check_rec_patches_4;




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
            p_min_volume                   IN NUMBER      DEFAULT 3500
           ,p_max_volume                   IN NUMBER      DEFAULT 5000
           ,p_max_output_rows              IN NUMBER      DEFAULT 30
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
  l_item_cnt            number;
  lk_item_cnt           VARCHAR2(15);
  l_cp_status	 	VARCHAR2(15);
  l_nodename	 	VARCHAR2(30);
  l_cp_start_date	DATE;
  l_logfile_name    	VARCHAR2(240);
  l_last_update_date	DATE;
  l_apps_invalid_cnt    number;
  l_fnd_invalid_cnt     number;
  l_CU1                 varchar2(15);
  l_CU2                 varchar2(15);
  l_RUP4                varchar2(15);
  l_RUP6                varchar2(15);
  l_run_alone_cnt       number := 0;
  l_run_alone_now_cnt   number := 0;
  l_std_mgr             VARCHAR2(30);
  l_enabled             VARCHAR2(1);
  l_cache               NUMBER(3);
  l_rpc2                varchar2(12);
  l_rpc3                varchar2(12);
  l_rpc4                varchar2(12);
  l_rpc5                varchar2(12);
  l_rpc_122_2016_aug   varchar2(12);
  l_rpc_122_2016_dec   varchar2(12);
  l_is_33606047_applied varchar2(12);
  l_is_32139972_applied varchar2(12);
  l_DBbanner            VARCHAR2(255);
  l_FNDRSRUN_ver        varchar2(25);
  l_33671306_applied    varchar2(50);
  l_2nd_latest_AD_TXK_codelevels      varchar2(50);
  l_ad_codelevel                      varchar2(5);
  l_latest_AD_TXK_codelevels          varchar2(50);
  l_txk_codelevel                     varchar2(5);
  l_snapDays            number;
  l_snap_days_msg       varchar2(350);
  l_languages_installed number;
  l_lang_list_installed varchar2(300);
  l_applptmp            varchar2(350);
  l_found               varchar2(5);
  l_is_122              varchar2(50);





BEGIN

  l_step := '1';

  print_log(analyzer_title || ' Log File');
  print_log('***************************************************************');

  -- Create global hash for parameters. Numbers required for the output order
debug('begin populate parameters hash table');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Minimum acceptable volume of Concurrent Request data';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_min_volume,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Maximum acceptable volume of Concurrent Request data';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_max_volume,'NO_MASK');
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
  l_revision := rtrim(replace('$Revision: 200.125  $','$',''));
  l_revision := ltrim(replace(l_revision,'Revision:',''));
  l_date_char := rtrim(replace('$Date: 2026/02/23 20:12:08 $','$',''));
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
  g_rep_info('File Name') := 'cp_analyzer.sql';
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
print_log('Starting Validation Queries....');

select count(request_id) into l_item_cnt from fnd_concurrent_requests where phase_code='C';

print_log('l_item_cnt= '||l_item_cnt);

lk_item_cnt := to_char(l_item_cnt, 'FM999,999,999,999');

print_log('lk_item_cnt= '||lk_item_cnt);

print_log('Checking the setup of $APPLPTMP');

select count(rownum) into l_applptmp --VALUE
from FND_ENV_CONTEXT
where CONCURRENT_PROCESS_ID in
      (select max(CONCURRENT_PROCESS_ID) from FND_CONCURRENT_PROCESSES
       where CONCURRENT_QUEUE_ID in (select CONCURRENT_QUEUE_ID from FND_CONCURRENT_QUEUES where CONCURRENT_QUEUE_NAME = 'WFMLRSVC')
         and QUEUE_APPLICATION_ID in (select APPLICATION_ID from FND_APPLICATION
 where APPLICATION_SHORT_NAME = 'FND'))
  and VARIABLE_NAME  in ('APPLPTMP');

if (l_applptmp = '0') then
    print_log('$APPLPTMP is not set.');
else if (l_applptmp > '0') then

      select VALUE into l_applptmp
      from FND_ENV_CONTEXT
      where CONCURRENT_PROCESS_ID in
      (select max(CONCURRENT_PROCESS_ID) from FND_CONCURRENT_PROCESSES
       where CONCURRENT_QUEUE_ID in (select CONCURRENT_QUEUE_ID from FND_CONCURRENT_QUEUES where CONCURRENT_QUEUE_NAME = 'WFMLRSVC')
         and QUEUE_APPLICATION_ID in (select APPLICATION_ID from FND_APPLICATION
       where APPLICATION_SHORT_NAME = 'FND'))
       and VARIABLE_NAME  in ('APPLPTMP');
    
    print_log('$APPLPTMP is set to :'||l_applptmp);

    end if;

    SELECT decode(count(rownum),0, 'NO', 'YES') "VALUE" into l_found
    FROM  v$parameter p WHERE p.name = 'utl_file_dir'
    and p.value like '%'||l_applptmp||'%';

    print_log('l_found= ('||l_found||')');

end if;

SELECT q.CONCURRENT_QUEUE_NAME "Short Name",  q.enabled_flag "Enabled", q.cache_size
into l_std_mgr, l_enabled, l_cache
from fnd_concurrent_queues_vl q
where q.CONCURRENT_QUEUE_NAME = 'STANDARD';

print_log('lk_item_cnt= '||lk_item_cnt);

select decode(process_status_code, 
	'A', 'Active','C', 'Connecting','D', 'Deactiviating','G', 'Awaiting Discovery','K', 'Terminated','M', 'Migrating','P', 'Suspended','R', 'Running','S', 'Deactivated','T', 'Terminating','U', 'Unreachable','Z', 'Initializing'), node_name, process_start_date, logfile_name, last_update_date
	into l_cp_status, l_nodename, l_cp_start_date, l_logfile_name, l_last_update_date
	from fnd_concurrent_processes
	where concurrent_process_id = (select max(p.CONCURRENT_PROCESS_ID)
	from fnd_concurrent_processes p, fnd_concurrent_queues u
	WHERE p.concurrent_queue_id = u.concurrent_queue_id
	AND   p.queue_application_id = u.application_id
	AND   u.concurrent_queue_name = 'FNDICM');

select count(*) into l_apps_invalid_cnt 
from dba_objects where status='INVALID'
and owner in ('APPS','APPLSYS','APPLSYSPUB','CTXSYS','PUBLIC','SYS','SYSTEM');

select count(*) into l_fnd_invalid_cnt from dba_objects 
where object_name like 'FND%'
and owner in ('APPS','APPLSYS')
and status='INVALID';

select ad_patch.is_patch_applied('11i',-1,3240000) into l_CU1 from dual;

select ad_patch.is_patch_applied('11i',-1,3460000) into l_CU2 from dual;

select ad_patch.is_patch_applied('11i',-1,6435000) into l_RUP4 from dual;

select ad_patch.is_patch_applied('11i',-1,6728000) into l_RUP6 from dual;

select count(p.concurrent_program_name) into l_run_alone_cnt
from fnd_concurrent_programs p
where p.run_alone_flag = 'Y'
and p.enabled_flag = 'Y';

select round(sysdate - (select * from (select snapshot_update_date from ad_snapshots
       where snapshot_name like '%_VIEW'
         and appl_top_id in (select appl_top_id from ad_appl_tops where name in ('GLOBAL'))
         and SNAPSHOT_TYPE in ('C','G')
         order by snapshot_update_date desc)
         where rownum = 1),0)+1 
         into l_snapDays
         from dual;

select count(p.concurrent_program_name) into l_run_alone_now_cnt
FROM fnd_concurrent_programs_tl t,
fnd_concurrent_programs p, fnd_application_tl a,
fnd_concurrent_requests r, fnd_languages l,
fnd_user u
WHERE a.application_id = t.application_id
and r.concurrent_program_id = t.concurrent_program_id
and t.concurrent_program_id = p.concurrent_program_id
AND r.nls_language = l.nls_language
AND l.language_code = t.language
AND l.language_code = a.language
AND r.requested_by = u.user_id
and p.run_alone_flag = 'Y';

select Ad_Patch.Is_Patch_Applied('R12',-1,19030202) into l_rpc2 From Dual;

select Ad_Patch.Is_Patch_Applied('R12',-1,20203366) into l_rpc3 From Dual;

select Ad_Patch.Is_Patch_Applied('R12',-1,21236633) into l_rpc4 From Dual;

select Ad_Patch.Is_Patch_Applied('R12',-1,22644544) into l_rpc5 From Dual;

select Ad_Patch.Is_Patch_Applied('R12',-1,24387712) into l_rpc_122_2016_aug From Dual;

select Ad_Patch.Is_Patch_Applied('R12',-1,25186394) into l_rpc_122_2016_dec From Dual;

select Ad_Patch.Is_Patch_Applied('R12',-1,32139972) into l_is_32139972_applied From Dual;

select Ad_Patch.Is_Patch_Applied('R12',-1,33606047) into l_is_33606047_applied From Dual; 

select 'allow_client_encoding'||decode(Ad_Patch.Is_Patch_Applied('R12',-1,33671306),'EXPLICIT',', file_extension','') into l_33671306_applied From Dual;

select "Current Version" into l_FNDRSRUN_ver from (
select --af1.APP_SHORT_NAME||'_TOP/' "Top", af1.subdir||'/' "Subdir",af1.filename "Filename",
     afv1.version "Current Version", 
	   rank()over(partition by af1.filename
	     order by afv1.version_segment1 desc,
	     afv1.version_segment2 desc,afv1.version_segment3 desc,
	     afv1.version_segment4 desc,afv1.version_segment5 desc,
	     afv1.version_segment6 desc,afv1.version_segment7 desc,
	     afv1.version_segment8 desc,afv1.version_segment9 desc,
	     afv1.version_segment10 desc,
	     afv1.translation_level desc) as rankUS
  from ad_files af1, ad_file_versions afv1
where af1.file_id = afv1.file_id
  and af1.subdir = 'forms/US'
  and af1.filename in ('FNDRSRUN.fmb')
 ) 
where rankUS = 1;

  BEGIN

    SELECT max(release_name) INTO l_apps_version
    FROM fnd_product_groups;

    begin
        -- Try to set codelevels for AD and TXK when R12.2
        execute immediate 'select codelevel FROM AD_TRACKABLE_ENTITIES WHERE abbreviation in (''ad'')'
            into l_ad_codelevel;
        execute immediate 'select codelevel FROM AD_TRACKABLE_ENTITIES WHERE abbreviation in (''txk'')'
            into l_txk_codelevel;            
    exception when others then
        -- Set codelevels as placeholder for AD and TXK when not R12.2
        l_ad_codelevel := 'C.0';
        l_txk_codelevel := 'C.0';
    end;
    	l_2nd_latest_AD_TXK_codelevels := 'R12.AD.C.Delta.16 and R12.TXK.C.Delta.16';
    	l_latest_AD_TXK_codelevels := 'R12.AD.C.Delta.17 and R12.TXK.C.Delta.17';
	g_2nd_latest_AD_TXK_codelevels 	:=    l_2nd_latest_AD_TXK_codelevels;
	g_ad_codelevel                 	:=    l_ad_codelevel;
	g_latest_AD_TXK_codelevels     	:=    l_latest_AD_TXK_codelevels;
	g_txk_codelevel                	:=    l_txk_codelevel;
  EXCEPTION WHEN OTHERS THEN
    print_log('Error in validate_parameters setting Techstack Codelevels: '
      ||sqlerrm);
    raise;
  END;


g_snapDays := l_snapDays;
print_log('DEBUG for g_snapDays = '||g_snapDays);

select CASE 
WHEN (g_snapDays > 29) then '<br><br><b>ADADMIN</b>: Maintain Snapshot Information was executed '||g_snapDays||' days ago.<br>It is recommended that AD Utilities (Adadmin) "Maintain Snapshot Information" is run periodically as key tools (Patch Wizard, ADPatch,etc) rely on this information being accurate and up-to-date.'
Else '<br><br><b>ADADMIN</b>: Maintain Snapshot Information was executed '||g_snapDays||' days ago.<br>'
END AS "SNAP_DAYS_MSG"
into l_snap_days_msg
from dual;

print_log('l_snap_days_msg = '||l_snap_days_msg);

--Set the count of other languages installed
select count(language_code) "LANGUAGES" into l_languages_installed 
FROM FND_LANGUAGES WHERE INSTALLED_FLAG in ('I');

print_log('l_languages_installed= '||l_languages_installed);

--Check for Multiple Languages Installed
if (l_languages_installed > '0') then
/*    select tab_to_string(CAST(COLLECT(language_code) AS t_varchar2_tab)) into l_lang_list_installed from FND_LANGUAGES WHERE INSTALLED_FLAG in ('I'); */

l_lang_list_installed:=tab_to_string();
else if (l_languages_installed = '0') then
    select 'No Other Languages installed' into l_lang_list_installed from dual;
    end if;
end if;

print_log('l_lang_list_installed= '||l_lang_list_installed);

g_applptmp := l_applptmp;
g_reqid_cnt := l_item_cnt;
gk_reqid_cnt := lk_item_cnt;

g_cp_status := l_cp_status;
g_nodename := l_nodename;
g_cp_start_date := l_cp_start_date;
g_logfile_name := l_logfile_name;
g_last_update_date := l_last_update_date;
g_apps_invalid_cnt := l_apps_invalid_cnt;
g_CU1 := l_CU1;
g_CU2 := l_CU2;
g_RUP4 := l_RUP4;
g_RUP6 := l_RUP6;
g_run_alone_cnt := l_run_alone_cnt;
g_run_alone_now_cnt := l_run_alone_now_cnt;
g_std_mgr :=  l_std_mgr;
g_enabled :=  l_enabled;
g_cache := l_cache;
g_min_vol := p_min_volume;
g_max_vol := p_max_volume;
g_instance := l_instance;
g_apps_version := l_apps_version;
g_rpc2 := l_rpc2;
g_rpc3 := l_rpc3;
g_rpc4 := l_rpc4;
g_rpc5 := l_rpc5;
g_rpc_122_2016_aug := l_rpc_122_2016_aug;
g_rpc_122_2016_dec := l_rpc_122_2016_aug;
g_33671306_applied := l_33671306_applied;

g_snap_days_msg := l_snap_days_msg;
g_languages_installed := l_languages_installed;
g_lang_list_installed := l_lang_list_installed;
g_found := l_found;

g_db_version	   := l_dbversion;
--Accomodations for 19C DB
select CASE 
WHEN g_db_version > '18'
THEN 'banner_full'
Else 'banner'
END into l_DBbanner from dual where rownum=1;

select decode(substr(release_name,0,4),'12.2',',fpotl.ZD_EDITION_NAME,fpotl.ZD_SYNC','') into l_is_122 from fnd_product_groups;

g_is_122 := l_is_122;
g_DBbanner := l_DBbanner;
g_is_33606047_applied := l_is_33606047_applied;
g_is_32139972_applied := l_is_32139972_applied;
g_FNDRSRUN_ver := l_FNDRSRUN_ver;

print_log('g_is_122 = '||g_is_122);
print_log('l_CU1 = '||l_CU1);
print_log('l_CU2 = '||l_CU2);
print_log('g_RUP4 = '||g_RUP4);
print_log('g_RUP6 = '||g_RUP6);
print_log('g_reqid_cnt = '||g_reqid_cnt);
print_log('gk_reqid_cnt = '||gk_reqid_cnt);
print_log('l_dbversion	= '||l_dbversion);
print_log('g_db_version	= '||g_db_version);
print_log('g_is_32139972_applied = '||g_is_32139972_applied );
print_log('g_is_32139972_applied = '||g_is_32139972_applied );
print_log('g_FNDRSRUN_ver = '||g_FNDRSRUN_ver );
print_log('g_33671306_applied = '||g_33671306_applied);
print_log('g_snapDays = '||g_snapDays);
print_log('g_snap_days = '||g_snap_days);
print_log('g_snap_days_msg = '||g_snap_days_msg);
print_log('g_languages_installed= '||g_languages_installed);
print_log('g_lang_list_installed= '||g_lang_list_installed);
print_log('g_applptmp= '||g_applptmp);
print_log('g_found= '||g_found);



    /* SEEDED EBS BANNER BEGIN */

    -- Premier Support Checks by priority
    select min(error_type) into l_system_function_var from (
        -- Database in Sustaining Support
        select 1 error_type from V$VERSION WHERE banner like '%11.2%' or banner like '%11.1%' or banner like '%10.%'
        union
        -- Application Version 11.5
        select 2 error_type from fnd_product_groups where release_name like '11.5%'
        union
        -- Application Version 12.1
        select 3 error_type from fnd_product_groups where release_name like '12.1%'
        union
        -- Database in Extended Support
        select 4 error_type from V$VERSION WHERE banner like '%12.1%'
        union
        -- Application Version 12.0
        select 5 error_type from fnd_product_groups where release_name like '12.0%'
        union
        -- Application Version 12.2.x outdated
        select 6 error_type from fnd_product_groups where release_name in ('12.2.0' , '12.2.1' , '12.2.2' , '12.2.3' , '12.2.4' , '12.2.5' , '12.2.6')
    );

    -- Set banner message by error type
    case l_system_function_var
        when 1 then
            -- Database in Sustaining Support
            g_banner_severity := 'W';
            g_banner_message := 'The database version running on this instance is in Sustaining Support. Please refer to Oracle''s Lifetime Support Policy in [11007164.1#supportp].<br>Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 2 then
            -- Application Version 11.5
            g_banner_severity := 'W';
            g_banner_message := 'Premier Support for the application version on this instance ended on November 2010. Please refer to Oracle''s Lifetime Support Policy in [11007164.1#supportp].<br> Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 3 then
            -- Application Version 12.1
            g_banner_severity := 'W';
            g_banner_message := 'Premier Support End for the application version on this instance is on December 2021. Please refer to Oracle''s Lifetime Support Policy in [11007164.1#supportp]. <br>Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 4 then
            -- Database in Extended Support
            g_banner_severity := 'W';
            g_banner_message := 'The database version running on this instance is in Extended Support. Please refer to Oracle''s Lifetime Support Policy in [11007164.1#supportp].<br>Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 5 then
            -- Application Version 12.0
            g_banner_severity := 'W';
            g_banner_message := 'Premier Support for the application version on this instance ended on January 2012. Please refer to Oracle''s Lifetime Support Policy in [11007164.1#supportp].<br>Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 6 then
           -- Application Version 12.2.7
           g_banner_severity := 'W';
           g_banner_message := '<b>Effective July 1, 2024, the E-Business Suite 12.2 Error Correction Baseline will be 12.2.7.</b><br>
<br>
<div><div style="display:inline-block; text-align:left; max-width:800px;">Updating the application version to release 12.2.7 or higher will ensure you have access to major product releases.<br>
Refer to:<ul>
<li>[1195034/KB696368] Oracle E-Business Suite Error Correction Support Policy</li>
<li><a href="https://blogs.oracle.com/ebstech/post/update-error-correction-baseline-for-ebs-122" target="_blank">Oracle E-Business Suite Technology Blog</a> Update: Error Correction Baseline for EBS 12.2</li>
</ul>
Customers running E-Business Suite products on the 12.2.3 - 12.2.6 release levels are encouraged to update to current code levels of those products before July 2024 so they can benefit from the simpler and smaller patches that will be available starting in July 2024.<br>
In the event a new issue is reported on a product at a code level below the baseline, Oracle Support will attempt to resolve the issue and engage Development if necessary. Development may determine that the issue can be resolved at the customer code level, or may determine that the only practical way to provide the fix is for the customer to apply the baseline (or later) code in the affected area, and provide the fix at that level.
</div></div>';
        else
            -- No banner required
            g_banner_message := null;
    end case;
    /* SEEDED EBS BANNER END */
debug('end Additional Code: Additional Validation');



  g_parameters.DELETE;

  -- Recreate global hash for parameters after validation (includes the modifiers)
debug('begin populate parameters hash table');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Minimum acceptable volume of Concurrent Request data';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_min_volume,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Maximum acceptable volume of Concurrent Request data';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_max_volume,'NO_MASK');
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


debug('begin add_signature: EBS_ATG_AT_TECHSTACK_CLASSIC');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##EBS_INSTANCE'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '25352',
      p_sig_id                 => 'EBS_ATG_AT_TECHSTACK_CLASSIC',
      p_sig_sql                => 'select "EBS_INSTANCE", "SUMMARY" from (
select ''01'' "ORDER",  ''EBS Instance Name = '' "EBS_INSTANCE", upper(instance_name) "SUMMARY" from v$instance
union
select ''02'' "ORDER", ''EBS Applications = '', release_name from fnd_product_groups
union
select ''03'' "ORDER", ''EBS Host Name = '', host_name from v$instance
union
SELECT ''04'' "ORDER", ''ATG_PF Code Level = '', codelevel FROM AD_TRACKABLE_ENTITIES WHERE abbreviation =  ''atg_pf''
union 
SELECT ''05'' "ORDER", ''AD Code Level = '', codelevel FROM AD_TRACKABLE_ENTITIES WHERE abbreviation =  ''ad''
union
SELECT ''06'' "ORDER", ''TXK Code Level = '', codelevel FROM AD_TRACKABLE_ENTITIES WHERE abbreviation =  ''txk''
union
SELECT ''07'' "ORDER", ''FWK Code Level = '', codelevel FROM AD_TRACKABLE_ENTITIES WHERE abbreviation =  ''fwk''
union
select ''10'' "ORDER", ''EBS TLS/SSL Enabled = '', decode(UPPER(SUBSTR(FND_WEB_CONFIG.PROTOCOL,1,5)), ''HTTPS'',''SSL/TLS Is Enabled'', ''SSL/TLS Is Not Enabled'') from dual
union
select ''11'' "ORDER", ''Latest CPU Patch Installed = '', nvl(max(CODELEVEL),''4+ years behind'') from AD_TRACKABLE_ENTITIES where ABBREVIATION in (''ebscpu'')
union
select ''12'' "ORDER", ''Last Snapshot was = '', round(sysdate - snapshot_update_date,0)+1||'' days ago'' from ad_snapshots where snapshot_name like ''%_VIEW'' and appl_top_id in (select appl_top_id from ad_appl_tops where name in (''GLOBAL'')) and SNAPSHOT_TYPE in (''C'',''G'')
union
select ''13'' "ORDER", ''Database Banner = '', '||mask_text(g_DBbanner, nvl( upper(''), 'NO_MASK') )||' db_version from v$version where rownum = 1
union
select ''14'' "ORDER", ''Database Version = '', '''||mask_text(g_db_version, nvl( upper(''), 'NO_MASK') )||''' from dual
union
select ''15'' "ORDER", ''OS Platform Version at DB server = '', dbms_utility.port_string from dual
union
select ''16'' "ORDER", ''EBS DB Startup Time = '', to_char(startup_time,''YYYY-Mon-DD'') from v$instance
union
SELECT ''17'' "ORDER", ''Forms Server = '', extractValue(XMLType(TEXT),''//forms_version[@oa_var="s_forms_version"]'') FROM fnd_oam_context_files WHERE name NOT IN (''TEMPLATE'',''METADATA'') AND (status IS NULL OR status !=''H'') AND CTX_TYPE IN (''A'')and rownum=1
union
select ''18'' "ORDER", ''EBS Platform = '', platform_name from v$database
union
select ''19'' "ORDER", ''Base Language = '', language_code||'' - ''||nls_language "VALUE" FROM FND_LANGUAGES WHERE INSTALLED_FLAG in (''B'')
union
select ''20'' "ORDER", ''Other Languages = '', '''||mask_text(g_lang_list_installed, nvl( upper(''), 'NO_MASK') )||''' from dual
union
select ''21'' "ORDER", ''Character Set = '', VALUE FROM V$NLS_PARAMETERS WHERE parameter = ''NLS_CHARACTERSET''
union
SELECT ''22'' "ORDER", ''Multi Org = '', MULTI_ORG_FLAG FROM FND_PRODUCT_GROUPS
union
SELECT ''23'' "ORDER", ''Multi Currency = '', MULTI_CURRENCY_FLAG FROM FND_PRODUCT_GROUPS
order by 1
)order by "ORDER"',
      p_title                  => 'EBS TechStack Summary Information',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is a problem identifying the EBS Instance Information',
      p_solution               => '',
      p_success_msg            => 'Important EBS TechStack Information.

',
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
debug('end add_signature: EBS_ATG_AT_TECHSTACK_CLASSIC');



debug('begin add_signature: EBS_ATG_CP1_FNDRSRUN');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25565',
      p_sig_id                 => 'EBS_ATG_CP1_FNDRSRUN',
      p_sig_sql                => 'select "TOP", "SUBDIR", "FILENAME", "CURRENT VERSIONS" from (
select ''$''||af1.APP_SHORT_NAME||''_TOP/'' "TOP", af1.subdir||''/'' "SUBDIR",af1.filename "FILENAME",
     afv1.version "CURRENT VERSIONS", 
	   rank()over(partition by af1.filename
	     order by afv1.version_segment1 desc,
	     afv1.version_segment2 desc,afv1.version_segment3 desc,
	     afv1.version_segment4 desc,afv1.version_segment5 desc,
	     afv1.version_segment6 desc,afv1.version_segment7 desc,
	     afv1.version_segment8 desc,afv1.version_segment9 desc,
	     afv1.version_segment10 desc,
	     afv1.translation_level desc) as rankUS
  from ad_files af1, ad_file_versions afv1
where af1.file_id = afv1.file_id
  and af1.subdir = ''forms/US''
  and af1.filename = ''FNDRSRUN.fmb'') 
where rankUS = 1
union
select "TOP", "SUBDIR", "FILENAME", "CURRENT VERSIONS" from (
select ''$''||af1.APP_SHORT_NAME||''_TOP/'' "TOP", af1.subdir||''/'' "SUBDIR",af1.filename "FILENAME",
     afv1.version "CURRENT VERSIONS", 
	   rank()over(partition by af1.filename
	     order by afv1.version_segment1 desc,
	     afv1.version_segment2 desc,afv1.version_segment3 desc,
	     afv1.version_segment4 desc,afv1.version_segment5 desc,
	     afv1.version_segment6 desc,afv1.version_segment7 desc,
	     afv1.version_segment8 desc,afv1.version_segment9 desc,
	     afv1.version_segment10 desc,
	     afv1.translation_level desc) as rankUS
  from ad_files af1, ad_file_versions afv1
where af1.file_id = afv1.file_id
  and af1.subdir <> ''forms/US''
  and af1.filename = ''FNDRSRUN.fmb'')
where rankUS = 1',
      p_title                  => 'Identify the version of FNDRSRUN',
      p_fail_condition         => '[CURRENT VERSIONS]<['||mask_text(g_FNDRSRUN_ver, nvl( upper(''), 'NO_MASK') )||']',
      p_problem_descr          => 'There are additional language versions of FNDRSRUN form that are out of synch to the current $FND_TOP/forms/US/FNDRSRUN.fmb version '||mask_text(g_FNDRSRUN_ver, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This is a potential problem as your language files should match or be higher than the "US" language files, and should be reviewed in more detail.<br><br>
Please recompile FND Forms, following this blog reference http://madhanappsdba.blogspot.com/2014/12/how-to-compile-oracle-apps-r12-forms.html.<br>
For more information, please follow :<br>
[252422/KB860741] - Oracle E-Business Suite Translation Synchronization Patches. ',
      p_success_msg            => 'Validating the FNDRSRUN Form version(s).',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CP1_FNDRSRUN');



debug('begin add_signature: CP1_PURGEREQS');
   l_info('##COMPLEX_TYPE##'):= 'W';
   l_info('##MASK##USER_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
l_info('##MASK##USER_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
  add_signature(
      p_sig_repo_id            => '1287',
      p_sig_id                 => 'CP1_PURGEREQS',
      p_sig_sql                => 'SELECT r.REQUEST_ID, u.user_name, r.PHASE_CODE, r.ACTUAL_START_DATE,
          c.CONCURRENT_PROGRAM_NAME, p.USER_CONCURRENT_PROGRAM_NAME, r.ARGUMENT_TEXT,
          r.RESUBMIT_INTERVAL, r.RESUBMIT_INTERVAL_UNIT_CODE, r.RESUBMIT_END_DATE
          FROM fnd_concurrent_requests r, FND_CONCURRENT_PROGRAMS_TL p, fnd_concurrent_programs c, fnd_user u
          WHERE r.CONCURRENT_PROGRAM_ID = p.CONCURRENT_PROGRAM_ID and r.requested_by = u.user_id
          and p.CONCURRENT_PROGRAM_ID = c.CONCURRENT_PROGRAM_ID
          and c.CONCURRENT_PROGRAM_NAME = ''FNDCPPUR''
          AND p.language = ''US''
          and r.ACTUAL_COMPLETION_DATE is null and r.PHASE_CODE in (''P'',''R'')
          order by c.CONCURRENT_PROGRAM_NAME, r.ARGUMENT_TEXT',
      p_title                  => 'Verify Purge and/or Manager Data Programs Scheduled to Run',
      p_fail_condition         => 'NRS',
      p_problem_descr          => '<b>There are a total of '||to_char(g_reqid_cnt,'999,999,999,999')||' records in FND_CONCURRENT_REQUESTS that are completed, but no "Purge Concurrent Request and/or Manager Data" program (FNDCPPUR) scheduled or running</b>',
      p_solution               => 'Please Review Concurrent Processing purging status with your team.<br><br>
Run the concurrent program "Purge Concurrent Request and/or Manager Data" (FNDCPPUR) with "Entity" parameter as "ALL" for all requests, or for specific requests that have large volumes of purge eligible data as seen above. The last purge of Concurrent Request data completed on No Date info available for VISION.<br>
FNDCPPUR should be scheduled and run on a regular basis to avoid performance issues. Run the query behind the SQL SCRIPT button to get the complete list of purge eligible concurrent request data.<br><br>

Additionally, the following are very good methods to follow for optimizing the process:
<ul><li>Run the job during hours of low workload. Doing this after hours will lessen the contention on the tables from running against your daily processing.</li>
<li>To get the requests under control, run the FNDCPPUR program with Age=20 or Age=18 would be a good method. That means, all requests older than 18 or 20 days will be purged.</li>
<li>Once the requests are under control, run the FNDCPPUR program with Age=7 to maintain an efficient process. This would solely depend on the level of processing that is performed at your site</li></ul>
For more information please review:<br>
[104282/KB627426] - Concurrent Processing - Purge Concurrent Request and/or Manager Data Program (FNDCPPUR).<br>
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite.<br><br>
<b>Note:</b> This section is only looking at the scheduled jobs in FND_CONCURRENT_REQUESTS table. Jobs scheduled using other tools (DBMS_JOBS, CONSUB, or PL/SQL, etc) are not reflected here, so keep this in mind.',
      p_success_msg            => '<b>There is a "Purge Concurrent Request and/or Manager Data" program (FNDCPPUR) scheduled or running on '||g_rep_info('Instance')||'.</b><br>
    There are a total of '||to_char(g_reqid_cnt,'999,999,999,999')||' records in FND_CONCURRENT_REQUESTS that are completed, and eligible for purging.<br><br>
Run the query behind the SQL SCRIPT button to get the complete list of purge eligible concurrent request data.<br><br>

Additionally, the following are very good methods to follow for optimizing the "Purge Concurrent Request and/or Manager Data" process:
<ul><li>Run the job during hours of low workload. Doing this after hours will lessen the contention on the tables from running against your daily processing.</li>
<li>To get the requests under control, run the FNDCPPUR program with Age=20 or Age=18 would be a good method. That means, all requests older than 18 or 20 days will be purged.</li>
<li>Once the requests are under control, run the FNDCPPUR program with Age=7 to maintain an efficient process. This would solely depend on the level of processing that is performed at your site</li></ul>
For more information please review:<br>
[104282/KB627426] - Concurrent Processing - Purge Concurrent Request and/or Manager Data Program (FNDCPPUR).<br>
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite.<br><br>
<b>Note:</b> This section is only looking at the scheduled jobs in FND_CONCURRENT_REQUESTS table. Jobs scheduled using other tools (DBMS_JOBS, CONSUB, or PL/SQL, etc) are not reflected here, so keep this in mind.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','Y')
      );
   l_info.delete;
   l_info.delete;
debug('end add_signature: CP1_PURGEREQS');



debug('begin add_signature: CP1_PURGELIGIBLE');
   l_info('##COMPLEX_TYPE##'):= 'W';
   l_info('##STYLE##COUNT'):= 'right,,,';
l_info('##STYLE##COUNT'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '1320',
      p_sig_id                 => 'CP1_PURGELIGIBLE',
      p_sig_sql                => 'select p.USER_CONCURRENT_PROGRAM_NAME, decode(r.phase_code,''C'',''Complete'') STATUS, 
to_char(count(r.request_id),''999,999,999,999'') "COUNT"
	FROM fnd_concurrent_requests r, FND_CONCURRENT_PROGRAMS_TL p
	WHERE r.CONCURRENT_PROGRAM_ID = p.CONCURRENT_PROGRAM_ID
	and r.phase_code=''C''
        and p.language = ''US''
	group by p.USER_CONCURRENT_PROGRAM_NAME, r.phase_code
	order by count(r.request_id) desc',
      p_title                  => 'Total Purge Eligible Records in FND_CONCURRENT_REQUESTS',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are a total of '||to_char(g_reqid_cnt,'999,999,999,999')||' records in FND_CONCURRENT_REQUESTS that are completed, and eligible for purging.',
      p_solution               => 'Review Concurrent Processing purging status with your team.<br><br>
    Run the concurrent program "Purge Concurrent Request and/or Manager Data" (FNDCPPUR) with "Entity" parameter as "ALL" for all requests, or for specific requests that have large volumes of purge eligible data as seen above. The last purge of Concurrent Request data completed on No Date info available for VISION.<br><br>
FNDCPPUR should be scheduled and run on a regular basis to avoid performance issues. Run the query behind the SQL SCRIPT button to get the complete list of purge eligible concurrent request data.<br><br>
For more information please review:<br>
[104282/KB627426] - Concurrent Processing - Purge Concurrent Request and/or Manager Data Program (FNDCPPUR).<br>
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite.<br><br>
<b>Note:</b> This section is only looking at the scheduled jobs in FND_CONCURRENT_REQUESTS table. Jobs scheduled using other tools (DBMS_JOBS, CONSUB, or PL/SQL, etc) are not reflected here, so keep this in mind.',
      p_success_msg            => 'There are a total of '||to_char(g_reqid_cnt,'999,999,999,999')||' records in FND_CONCURRENT_REQUESTS that are completed, and eligible for purging.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','Y')
      );
   l_info.delete;
   l_info.delete;
debug('end add_signature: CP1_PURGELIGIBLE');



debug('begin add_signature: CP1_ORPHANED_PURGE_DATA');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##COUNT OF ORPHANED REQUEST_IDS'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '6249',
      p_sig_id                 => 'CP1_ORPHANED_PURGE_DATA',
      p_sig_sql                => 'select ''FND_RUN_REQ_LANGUAGES'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from fnd_run_req_languages
WHERE parent_request_id not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_TEMP_FILES'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from Fnd_Temp_Files
WHERE Request_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_CONC_RELEASE_PERIODS_TL'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from FND_CONC_RELEASE_PERIODS_TL
  WHERE (APPLICATION_ID, CONCURRENT_PERIOD_ID) IN
		(SELECT APPLICATION_ID, CONCURRENT_PERIOD_ID
		from FND_CONC_RELEASE_PERIODS
		Where OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests))
union
select ''FND_CONC_RELEASE_PERIODS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from FND_CONC_RELEASE_PERIODS
  WHERE OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_CONC_RELEASE_STATES_TL'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from FND_CONC_RELEASE_STATES_TL
  WHERE (APPLICATION_ID, CONCURRENT_STATE_ID) IN
		(SELECT APPLICATION_ID, CONCURRENT_STATE_ID
		   from FND_CONC_RELEASE_STATES
		   Where OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests))
union
select ''FND_CONC_RELEASE_STATES'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from FND_CONC_RELEASE_STATES
WHERE OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_CONC_RELEASE_CLASSES_TL'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from FND_CONC_RELEASE_CLASSES_TL
  WHERE (APPLICATION_ID, RELEASE_CLASS_ID) IN
		   (SELECT APPLICATION_ID, RELEASE_CLASS_ID
		    from FND_CONC_RELEASE_CLASSES
		    Where OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests))
union
select ''FND_CONC_RELEASE_CLASSES'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from FND_CONC_RELEASE_CLASSES
WHERE OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests)
union 
select ''FND_CONC_RELEASE_DISJS_TL'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  FND_CONC_RELEASE_DISJS_TL
  WHERE (APPLICATION_ID, DISJUNCTION_ID) IN
		  (SELECT APPLICATION_ID, DISJUNCTION_ID
		   from FND_CONC_RELEASE_DISJS
		    Where OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests))
union
select ''FND_CONC_RELEASE_DISJS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  FND_CONC_RELEASE_DISJS
WHERE OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_CONC_REL_DISJ_MEMBERS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  FND_CONC_REL_DISJ_MEMBERS
WHERE OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_CONC_REL_CONJ_MEMBERS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  FND_CONC_REL_CONJ_MEMBERS
WHERE OWNER_REQ_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_CONC_PP_ACTIONS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  FND_CONC_PP_ACTIONS
  WHERE CONCURRENT_REQUEST_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_RUN_REQ_PP_ACTIONS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  FND_RUN_REQ_PP_ACTIONS
  WHERE PARENT_REQUEST_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_FILE_TEMP'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  FND_FILE_TEMP
WHERE REQUEST_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FROM FND_CONC_REQ_OUTPUTS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from FND_CONC_REQ_OUTPUTS
WHERE CONCURRENT_REQUEST_ID not in (SELECT request_id from fnd_concurrent_requests)
union
select ''FND_RUN_REQUESTS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  fnd_run_requests
WHERE parent_request_id not in (SELECT request_id from fnd_concurrent_requests) 
union
select ''FND_CONC_REQUEST_ARGUMENTS'' TABLE_NAME, 
to_char(count(*),''999,999,999,999'') "COUNT OF ORPHANED REQUEST_IDS" from  fnd_conc_request_arguments
WHERE request_id not in (SELECT request_id from fnd_concurrent_requests)',
      p_title                  => 'Orphaned Purge Concurrent Data',
      p_fail_condition         => '[COUNT OF ORPHANED REQUEST_IDS] > [0]',
      p_problem_descr          => 'There are orphaned concurrent request records found that will not be purged using the concurrent program (FNDCPPUR) - Purge Concurrent Request and/or Manager Data.
',
      p_solution               => 'This orphaned data should be analyzed closer to determine why it occured.<br><br>
Several reasons could include :<ul>
<li>Manually purging CP data, but not including all the associated tables.</li>
<li>A bug.</li>
<li>A process activity being skipped or aborted.</li>
</ul>
It is recommended to log a Service Request (SR) with Oracle Support to detect the root cause of these orphaned records.<br>

For more details, please review :<br>
[104282/KB627426] - Concurrent Processing - Purge Concurrent Request and/or Manager Data Program (FNDCPPUR)',
      p_success_msg            => 'No Orphaned Concurrent Request Data found.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '22'
      );
   l_info.delete;
debug('end add_signature: CP1_ORPHANED_PURGE_DATA');



debug('begin add_signature: CP1_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1290',
      p_sig_id                 => 'CP1_PARAMETERS',
      p_sig_sql                => 'SELECT name, value
          from v$parameter
          where upper(name) in (''AQ_TM_PROCESSES'',''JOB_QUEUE_PROCESSES'',''JOB_QUEUE_INTERVAL'',
                                ''UTL_FILE_DIR'',''NLS_LANGUAGE'',''NLS_TERRITORY'',
                                ''CPU_COUNT'',''PARALLEL_THREADS_PER_CPU'')
	UNION
	select parameter, value from v$nls_parameters where parameter in (''NLS_CHARACTERSET'')',
      p_title                  => 'Concurrent Processing Database Parameter Settings',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is a problem identifying the Concurrent Processing Database Parameter Settings',
      p_solution               => 'Verify the Concurrent Processing Database Parameter Settings are set',
      p_success_msg            => 'For more information refer to [11158187/KA1002] - Database Initialization Parameters for Oracle E-Business Suite Release 12',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: CP1_PARAMETERS');



debug('begin add_signature: CP1_ENV');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1291',
      p_sig_id                 => 'CP1_ENV',
      p_sig_sql                => 'select VARIABLE_NAME, VALUE
from FND_ENV_CONTEXT
where CONCURRENT_PROCESS_ID = (select max(p.CONCURRENT_PROCESS_ID)
from fnd_concurrent_processes p, fnd_concurrent_queues u
WHERE p.concurrent_queue_id = u.concurrent_queue_id
AND   p.queue_application_id = u.application_id
AND   u.concurrent_queue_name = ''FNDICM'')
and VARIABLE_NAME in (''AF_CLASSPATH'',''AF_JLIB'',''AF_JRE_TOP'',
''AF_LD_LIBRARY_PATH'',''AFJSMARG'',''AFJVAPRG'',''APPLCSF'',''APPLDCP'',''APPLWDIR'',
''APPLFENV'',''APPLLOG'',''APPLORB'',''APPLORC'',''APPLOUT'',''APPLPTMP'',
''APPLTMP'',''APPS_JDBC_URL'',''AU_TOP'',''CA_FILEIO_64'',''CLASSPATH'',
''CONTEXT_FILE'',''CONTEXT_NAME'',''DE_DISABLE_PLS_512'',''DISPLAY'',
''EVENT_10932'',''APPL_TOP'',''FND_TOP'',''FNDNAM'',''FNDSM_SCRIPT'',''HOSTNAME'',
''LD_LIBRARY_PATH'',''NLS_LANG'',''NLS_NUMERIC_CHARACTERS'', ''OA_MEDIA'',
''ORACLE_HOME'',''PLATFORM'',''PRINTER'',''REPORTS60_PATH'', 
''REPORTS_CLASSPATH'',''REPORTS_NO_DUMMY_PRINTER'',''REPORTS_PATH'',
''REPORTS_POST'',''REPORTS_PRE'',''REPORTS_TMP'',''TK_PRINT_STATUS'', 
''TK_PRINTER'',''TNS_ADMIN'',''TWO_TASK'',''XDO_TOP'',''XENVIRONMENT'',''APPLLDM'',''APPCPNAM'',''IX_PRINTING'',''IX_RENDERING'')
order by VARIABLE_NAME',
      p_title                  => 'Concurrent Processing Environment Variables',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The Concurrent Manager Environment for '||mask_text(g_nodename, nvl( upper(''), 'NO_MASK') )||' may not be available.  It is currently in '||mask_text(g_cp_status, nvl( upper(''), 'NO_MASK') )||' status.',
      p_solution               => 'Concurrent Manager was last started on '||mask_text(g_cp_start_date, nvl( upper(''), 'NO_MASK') )||', and last updated on '||mask_text(g_last_update_date, nvl( upper(''), 'NO_MASK') )||'.<br>
	  The current Concurrent Manager logs are found :<br>
	  '||mask_text(g_logfile_name, nvl( upper(''), 'NO_MASK') )||'.<br><br>
For additional details, please refer to :<br>
[1355735/KB707634] - Difference between APPLPTMP and APPLTMP Directories in EBS
<br><br>
Environment variable APPLLDM was introduced to allow you to specify whether you want your log and out files stored in a single directory for all
Oracle E-Business Suite products. <br>
Refer to [2302177/KB762153] - No Data Generated in Logs and Out Files after Setting APPLLDM Environment Variable.',
      p_success_msg            => 'The Internal Concurrent Manager (ICM) for '||mask_text(g_nodename, nvl( upper(''), 'NO_MASK') )||' is '||mask_text(g_cp_status, nvl( upper(''), 'NO_MASK') )||', and has been running since '||mask_text(g_cp_start_date, nvl( upper(''), 'NO_MASK') )||'.<br>
	  The current Concurrent Manager logs are found :<br>
	  '||mask_text(g_logfile_name, nvl( upper(''), 'NO_MASK') )||'.<br><br>
	  For additional details, please refer to :<br>
[1355735/KB707634] - Difference between APPLPTMP and APPLTMP Directories in EBS
<br><br>
Environment variable APPLLDM was introduced to allow you to specify whether you want your log and out files stored in a single directory for all
Oracle E-Business Suite products. <br>
Refer to [2302177/KB762153] - No Data Generated in Logs and Out Files after Setting APPLLDM Environment Variable.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '16'
      );
   l_info.delete;
debug('end add_signature: CP1_ENV');



debug('begin add_signature: CP1_PROFILES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1292',
      p_sig_id                 => 'CP1_PROFILES',
      p_sig_sql                => 'select 
 p.profile_option_name SHORT_NAME, 
 n.user_profile_option_name NAME, 
 decode(v.level_id,  10001, ''Site'',
    10002,''Application'',
	10003,''Responsibility'',
	10004,''User'',
	10005,''Server'',
	10006,''Organization'', ''UnDef'') LEVEL_SET,
 v.level_value LEVEL_VAL, 
 v.profile_option_value VALUE
from fnd_profile_options p, 
   fnd_profile_option_values v, 
   fnd_profile_options_tl n
where p.profile_option_id = v.profile_option_id (+)
 and p.profile_option_name = n.profile_option_name
 and n.language = ''US''
 and v.level_id = 10001
  and p.profile_option_name in (''CONC_GSM_ENABLED'',''APPS_FRAMEWORK_AGENT'',''CONC_PP_RESPONSE_TIMEOUT'',''CONC_TM_TRANSPORT_TYPE'',''GUEST_USER_PWD'',
''AFLOG_ENABLED'',''AFLOG_FILENAME'',''AFLOG_LEVEL'',''AFLOG_BUFFER_MODE'',''AFLOG_MODULE'',
''FND_FWK_COMPATIBILITY_MODE'',''FND_VALIDATION_LEVEL'',''FND_MIGRATED_TO_JRAD'',''AMPOOL_ENABLED'',
''CONC_PP_PROCESS_TIMEOUT'', ''CONC_BI_ENABLE'',''CONC_DEBUG'',''CONC_COPIES'',''CONC_FORCE_LOCAL_OUTPUT_MODE'',''CONC_HOLD'',
''CONC_CD_ID'',''CONC_PMON_METHOD'',''CONC_PP_INIT_DELAY'',''CONC_PRINT_WARNING'',''CONC_REPORT_ACCESS_LEVEL'',
''CONC_REQUEST_LIMIT'',''CONC_SINGLE_THREAD'',''CONC_TOKEN_TIMEOUT'',''CONC_VALIDATE_SUBMISSION'',
''FND_CONC_ALLOW_DEBUG'',''CP_INSTANCE_CHECK'',''FND_NATIVE_CLIENT_ENCODING'',''FND_RESOURCE_CONSUMER_GROUP'',''FND_MGR_STRTUP_THRES_LIMIT'',''FND_MGR_STRTUP_THRES_TIME'',''ICX_CLIENT_IANA_ENCODING'',
''FS_SVC_PREFIX'',''FND_SMTP_HOST'',''FND_SMTP_PORT'',''CONC_FORCE_LOCAL_OUTPUT_FILE_MODE'',
''CONC_DATE_INCREMENT_OPTION'',''FSA_DELETE'',''FS_ENABLED'',''FS_MAX_TRANS'',''EDITOR_PS'',''FNDCPVWR_FONT_SIZE'',
''FS_MIME_TEXT'',''FS_MIME_PDF'',''FS_MIME_XML'',''CONC_FNDRSRUN_MODE'',''CZ_REPORT_ALL_BASELINE_CONFLICTS'',''SERVER_TIMEZONE_ID'',''FND_DEFAULT_REQUEST_DAYS'', ''FND_DEF_TEMPL_OUTPUT_TYPE'', ''CONC_PRIORITY'',''CONC_REQ_START'', ''AUTO_REFRESH_REQUESTS'', ''CONC_SAVE_OUTPUT'')
union
select 
 p.profile_option_name SHORT_NAME, 
 n.user_profile_option_name NAME, 
 decode(v.level_id,  10001, ''Site'', 
     10002,''Application'',
	10003,''Responsibility'',
	10004,''User'',
	10005,''Server'',
	10006,''Organization'', ''UnDef'') LEVEL_SET,
 v.level_value LEVEL_VAL, 
 v.profile_option_value VALUE
from fnd_profile_options p, 
   fnd_profile_option_values v, 
   fnd_profile_options_tl n
where p.profile_option_id = v.profile_option_id (+)
 and p.profile_option_name = n.profile_option_name
 and n.language = ''US''
 and v.level_id is null
  and p.profile_option_name in (''CONC_GSM_ENABLED'',''APPS_FRAMEWORK_AGENT'',''CONC_PP_RESPONSE_TIMEOUT'',''CONC_TM_TRANSPORT_TYPE'',''GUEST_USER_PWD'',
''AFLOG_ENABLED'',''AFLOG_FILENAME'',''AFLOG_LEVEL'',''AFLOG_BUFFER_MODE'',''AFLOG_MODULE'',
''FND_FWK_COMPATIBILITY_MODE'',''FND_VALIDATION_LEVEL'',''FND_MIGRATED_TO_JRAD'',''AMPOOL_ENABLED'',
''CONC_PP_PROCESS_TIMEOUT'', ''CONC_BI_ENABLE'',''CONC_DEBUG'',''CONC_COPIES'',''CONC_FORCE_LOCAL_OUTPUT_MODE'',''CONC_HOLD'',
''CONC_CD_ID'',''CONC_PMON_METHOD'',''CONC_PP_INIT_DELAY'',''CONC_PRINT_WARNING'',''CONC_REPORT_ACCESS_LEVEL'',
''CONC_REQUEST_LIMIT'',''CONC_SINGLE_THREAD'',''CONC_TOKEN_TIMEOUT'',''CONC_VALIDATE_SUBMISSION'',
''FND_CONC_ALLOW_DEBUG'',''FND_SMTP_HOST'',''FND_SMTP_PORT'',''CP_INSTANCE_CHECK'',''FND_NATIVE_CLIENT_ENCODING'',''FND_RESOURCE_CONSUMER_GROUP'',''FND_MGR_STRTUP_THRES_LIMIT'',''FND_MGR_STRTUP_THRES_TIME'',''ICX_CLIENT_IANA_ENCODING'',
''FS_SVC_PREFIX'',''FND_SMTP_HOST'',''FND_SMTP_PORT'',''CONC_FORCE_LOCAL_OUTPUT_FILE_MODE'',
''CONC_DATE_INCREMENT_OPTION'',''FSA_DELETE'',''FS_ENABLED'',''FS_MAX_TRANS'',''EDITOR_PS'',''FNDCPVWR_FONT_SIZE'',
''FS_MIME_TEXT'',''FS_MIME_PDF'',''FS_MIME_XML'',''CONC_FNDRSRUN_MODE'',''CZ_REPORT_ALL_BASELINE_CONFLICTS'',''SERVER_TIMEZONE_ID'', ''FND_DEFAULT_REQUEST_DAYS'', ''FND_DEF_TEMPL_OUTPUT_TYPE'',  ''CONC_PRIORITY'',''CONC_REQ_START'', ''AUTO_REFRESH_REQUESTS'', ''CONC_SAVE_OUTPUT'')
order by 1',
      p_title                  => 'E-Business Suite Profile Settings',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is a problem identifying the E-Business Suite Profile Settings',
      p_solution               => 'Verify the E-Business Suite Profile Settings',
      p_success_msg            => 'E-Business Suite Profile Settings',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '27'
      );
   l_info.delete;
debug('end add_signature: CP1_PROFILES');



debug('begin add_signature: EBS_ATG_CP2_CONC_REQUEST_LIMIT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '23817',
      p_sig_id                 => 'EBS_ATG_CP2_CONC_REQUEST_LIMIT',
      p_sig_sql                => 'select p.profile_option_name SHORT_NAME, n.user_profile_option_name NAME,
decode(v.level_id,
10001, ''Site'',
10002,''Application'',
10003,''Responsibility'',
10004,''User'',
10005,''Server'',
10006,''Organization'',
''UnDef'') LEVEL_SET, v.level_value LEVEL_VAL, v.profile_option_value VALUE
from fnd_profile_options p, fnd_profile_option_values v, fnd_profile_options_tl n
where p.profile_option_id = v.profile_option_id (+)
and p.profile_option_name = n.profile_option_name and n.language = ''US''
and v.level_id = 10001
and p.profile_option_name = (''CONC_REQUEST_LIMIT'') ',
      p_title                  => 'Concurrent:Active Request Limit Profile',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The profile ''Concurrent:Active Request Limit''  is non-zero at the Site level.',
      p_solution               => 'The profile ''Concurrent:Active Request Limit'' set at the Site level will cause ALL requests to be handled by the Conflict Resolution Manager, a large performance hit and the likelihood of many Pending requests.<br><br>

Set to blank (null) at the Site level and set at the User / Responsibility / Application level, sparingly as needed. <br><br>

For more details refer to: <br>
[1599054/KB717219] - How to Limit Active Concurrent Requests by a User.',
      p_success_msg            => 'The profile ''Concurrent:Active Request Limit''  is properly set at the Site level.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CP2_CONC_REQUEST_LIMIT');



debug('begin add_signature: CP1_GSM_ENABLED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1293',
      p_sig_id                 => 'CP1_GSM_ENABLED',
      p_sig_sql                => 'SELECT p.PROFILE_OPTION_NAME, v.PROFILE_OPTION_VALUE
   from fnd_profile_option_values v, fnd_profile_options p
  where v.PROFILE_OPTION_ID = p.PROFILE_OPTION_ID
    and p.PROFILE_OPTION_NAME = ''CONC_GSM_ENABLED''
    and sysdate BETWEEN p.start_date_active
    and NVL(p.end_date_active, sysdate)
    and v.PROFILE_OPTION_VALUE = ''Y''',
      p_title                  => 'Verify Profile "Concurrent:GSM Enabled" is enabled',
      p_fail_condition         => '[PROFILE_OPTION_VALUE] <> [Y]',
      p_problem_descr          => 'The EBS profile "Concurrent:GSM Enabled" is not enabled.',
      p_solution               => 'Please enable the EBS Profile "Concurrent:GSM Enabled".<br><br> 

Generic Service Management (GSM) is an extension of Concurrent Processing, which provides a powerful framework for managing processes on multiple host machines.  With Service Management, virtually any application tier service can be integrated into this framework.  Today, services such as the Oracle Forms Listener, Oracle Reports Server, Apache Web listener, and Oracle Workflow Mailer can be run under Service Management.<br>
For more information, please review :<br>
[210062/KB779377] - Concurrent Processing - Generic Service Management (GSM) in Oracle Applications.<BR>
[204090/KB187711] - Generic Service Management Configuration Using Applications Context Files.',
      p_success_msg            => 'Profile "Concurrent:GSM Enabled" is enabled as expected<br><br> 

Service Management is an extension of Concurrent Processing, which provides a powerful framework for managing processes on multiple host machines.  With Service Management, virtually any application tier service can be integrated into this framework.  Today, services such as the Oracle Forms Listener, Oracle Reports Server, Apache Web listener, and Oracle Workflow Mailer can be run under Service Management.<br>
For more information, please review :<br>
[210062/KB779377] - Concurrent Processing - Generic Service Management (GSM) in Oracle Applications.<BR>
[204090/KB187711] - Generic Service Management Configuration Using Applications Context Files.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: CP1_GSM_ENABLED');



debug('begin add_signature: EBS_ATG_CP1_FND_DOCS_LONG_TEXT_SN');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '23996',
      p_sig_id                 => 'EBS_ATG_CP1_FND_DOCS_LONG_TEXT_SN',
      p_sig_sql                => 'select d.owner, d.object_name, d.object_type, d.status, d.last_ddl_time
from dba_objects d
where d.status = ''INVALID''
and d.owner in (''APPS'',''APPLSYS'')
and d.object_name in (''FND_DOCS_LONG_TEXT_SN'', ''FND_DOCUMENTS_LT_PO_UAS'',''FND_DOCUMENTS_LT_PO_UBR'')',
      p_title                  => 'Check for Invalid FND Object FND_DOCS_LONG_TEXT_SN',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'FND_DOCS_LONG_TEXT_SN Materialized view is invalid.
FND_DOCUMENTS_LT_PO_UAS and FND_DOCUMENTS_LT_PO_UBR are invalid.
',
      p_solution               => 'FND_DOCS_LONG_TEXT_SN was created from MSCINVSN.sql. When trying to compile the materialized view, it still remains invalid. <br><br>

This particular materialized view becoming invalid can be ignored. <br>
It should not cause any issue or error during data collections. Also, one should be able to query on it and return records even if invalid.
<br><br> For more information refer to: <br>

[1368704/KB235147] - FND_DOCS_LONG_TEXT_SN Materialized View has INVALID Status ORA-00932 inconsistent datatypes: expected. <b>

The triggers FND_DOCUMENTS_LT_PO_UAS and FND_DOCUMENTS_LT_PO_UBR are obsoleted in R12, therefore you can ignore these objects.<b>
<br><br> For more information refer to: <br>

[2306240/KB669247] - FND_DOCUMENTS_LT_PO_UBR INVALID After Applying Patch Application
',
      p_success_msg            => 'FND_DOCS_LONG_TEXT_SN Materialized view is valid.
FND_DOCUMENTS_LT_PO_UAS and FND_DOCUMENTS_LT_PO_UBR are valid.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CP1_FND_DOCS_LONG_TEXT_SN');



debug('begin add_signature: CP1_FND_PACKAGE_CHECK_FAIL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '12453',
      p_sig_id                 => 'CP1_FND_PACKAGE_CHECK_FAIL',
      p_sig_sql                => 'SELECT status, owner, object_name, object_type
FROM dba_objects
WHERE owner = ''APPS''
AND object_name IN (
  SELECT referenced_name
  FROM dba_dependencies
  WHERE name IN (''FND_DCP'', ''FND_PROFILE'')
  AND referenced_owner = ''APPS''
  AND type = ''PACKAGE BODY'')
AND STATUS = ''INVALID''',
      p_title                  => 'Concurrent Processing Dependencies Invalid Package Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Concurrent Managers stopped with "ORACLE error 4068 in afpoload" and "ORA-04068: existing state of packages has been discarded" due to FND_PROFILE, FND_DCP or dependencies being invalid.',
      p_solution               => 'Please see the following note for the solution and root cause analysis:<br>
<br>
[2530280/KB625529] Concurrent Managers Stopped "ORACLE error 4068 in afpoload" and "ORA-04068: existing state of packages has been discarded".
',
      p_success_msg            => 'FND_PROFILE, FND_DCP and all their dependencies are valid as expected.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: CP1_FND_PACKAGE_CHECK_FAIL');



debug('begin add_signature: CP1_FND_FILE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1294',
      p_sig_id                 => 'CP1_FND_FILE',
      p_sig_sql                => 'SELECT name, value, '''||mask_text(g_found, nvl( upper(''), 'NO_MASK') )||''' FOUND 
FROM  v$parameter
WHERE name = ''utl_file_dir''
union
select name, value, '''||mask_text(g_found, nvl( upper(''), 'NO_MASK') )||''' FOUND from (
select distinct ctx.VALUE "VALUE", variable_name "NAME" from FND_ENV_CONTEXT ctx
where ctx.VARIABLE_NAME = ''APPLPTMP'')',
      p_title                  => 'Check FND_FILE Setup',
      p_fail_condition         => '[FOUND] = [NO]',
      p_problem_descr          => 'The FND_FILE Setup shows the $APPLPTMP does not exist in the utl_file_dir parameter in the database initialization file.',
      p_solution               => 'The APPLPTMP directory must be the same directory as specified by the utl_file_dir parameter in your database initialization file. <br><br>
Please correct the FND_FILE setup using [261693/KB627197] - Concurrent Processing - Troubleshooting Concurrent Request ORA-20100 errors in the request logs.',
      p_success_msg            => 'FND_FILE Setup is enabled and $APPLPTMP exists in the utl_file_dir parameter in the database initialization file as expected.<br><br>
For more information, please review [261693/KB627197] - Concurrent Processing - Troubleshooting Concurrent Request ORA-20100 errors in the request logs.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '20'
      );
   l_info.delete;
debug('end add_signature: CP1_FND_FILE');



debug('begin add_signature: EBS_ATG_CT_APPLIED_PATCHES_PAST_30_DAYS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '30694',
      p_sig_id                 => 'EBS_ATG_CT_APPLIED_PATCHES_PAST_30_DAYS',
      p_sig_sql                => 'select distinct ap.patch_name "PATCH NAME", decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,ap.patch_name),''EXPLICIT'',''Applied'','' '') as "STATUS",
(decode(pd.DRIVER_FILE_NAME, ''ucleanup.drv'', ''adop phase=cleanup'', ''ucutover.drv'', ''adop phase=cutover'')||pd.patch_abstract) "PATCH DESCRIPTION", 
    decode(pd.MERGED_DRIVER_FLAG, ''N'', ''No'', ''Y'', ''Yes'') "MERGED PATCHES", fn.host "APPL_TOP NAME", pr.END_DATE "COMPLETION DATE"
    from ad_applied_patches ap, ad_patch_drivers pd, ad_patch_runs pr, fnd_nodes fn, Ad_Appl_Tops aat
    where  pd.applied_patch_id = ap.applied_patch_id
    and pr.appl_top_id = aat.appl_top_id
    and fn.host = aat.name
    and trunc( pr.start_date + -0.125 )  >= sysdate-60
    and pr.patch_driver_id = pd.patch_driver_id
    order by pr.END_DATE desc',
      p_title                  => 'Applied Patches Over The Past 60 Days',
      p_fail_condition         => '[STATUS]=[NOT_APPLIED]',
      p_problem_descr          => 'There are no applied patches from the past 60 days.',
      p_solution               => 'Customers apply patches as needed, and no patches have been applied over the past 60 days.',
      p_success_msg            => 'EBS Application patches applied over the past 60 days.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CT_APPLIED_PATCHES_PAST_30_DAYS');



debug('begin add_signature: EBS_ATG_CP_VIEWER_OPTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25624',
      p_sig_id                 => 'EBS_ATG_CP_VIEWER_OPTIONS',
      p_sig_sql                => 'SELECT file_format_code,
mime_type, 
description, 
'||mask_text(g_33671306_applied, nvl( upper(''), 'NO_MASK') )||'
FROM fnd_mime_types_tl
WHERE language= ''US''
ORDER BY file_format_code, mime_type',
      p_title                  => 'Viewer Options (MIME Types)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No Viewer Options (MIME Types) found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please follow the setup steps in:<br>
[184375/KB342414] - 11i-12 How to Setup The Report Output to Different Viewer Types in Oracle Applications.',
      p_success_msg            => 'Viewer Options (MIME Types) found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
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
debug('end add_signature: EBS_ATG_CP_VIEWER_OPTIONS');



debug('begin add_signature: EBS_ATG_CP_VIEWING_PROFILES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25625',
      p_sig_id                 => 'EBS_ATG_CP_VIEWING_PROFILES',
      p_sig_sql                => 'SELECT fpo.PROFILE_OPTION_NAME,
       fpov.PROFILE_OPTION_VALUE,
       fpotl.LANGUAGE,
       fpotl.USER_PROFILE_OPTION_NAME,
       fpov.APPLICATION_ID,
       fpov.PROFILE_OPTION_ID,
       fpotl.CREATED_BY,
       fpotl.CREATION_DATE,
       fpotl.LAST_UPDATED_BY,
       fpotl.LAST_UPDATE_DATE,
       fpotl.LAST_UPDATE_LOGIN,
       fpotl.DESCRIPTION,
       fpotl.SOURCE_LANG'||mask_text(g_is_122, nvl( upper(''), 'NO_MASK') )||'
FROM fnd_profile_options fpo
JOIN fnd_profile_option_values fpov ON fpo.APPLICATION_ID = fpov.APPLICATION_ID
                                 AND fpo.PROFILE_OPTION_ID = fpov.PROFILE_OPTION_ID
JOIN fnd_profile_options_tl fpotl ON fpo.PROFILE_OPTION_NAME = fpotl.PROFILE_OPTION_NAME
where fpotl.user_profile_option_name like ''Viewer:%''',
      p_title                  => 'Viewer Profiles',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No Viewer Profiles found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please follow the setup steps in:<br>
[184375/KB342414] - 11i-12 How to Setup The Report Output to Different Viewer Types in Oracle Applications.',
      p_success_msg            => 'Viewer Profiles found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CP_VIEWING_PROFILES');



debug('begin add_signature: EBS_ATG_CP_REQUEST_VIEWING_ENV');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25629',
      p_sig_id                 => 'EBS_ATG_CP_REQUEST_VIEWING_ENV',
      p_sig_sql                => 'select VARIABLE_NAME, replace(value,'':'',chr(10)) "VALUE"
from FND_ENV_CONTEXT
where CONCURRENT_PROCESS_ID = (select max(p.CONCURRENT_PROCESS_ID)
from fnd_concurrent_processes p, fnd_concurrent_queues u
WHERE p.concurrent_queue_id = u.concurrent_queue_id
AND   p.queue_application_id = u.application_id
AND   u.concurrent_queue_name = ''FNDICM'')
and VARIABLE_NAME in (''APPLCSF'', ''APPLOUT'',
''APPLLOG'',
''APPCPNAM'',
''APPLLDM'')
order by VARIABLE_NAME',
      p_title                  => 'Request Viewing Environment Variables',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No Request Viewing Environment Variables found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please review and follow the instructions in:<br>
[1616827/KB781336] - Managing Concurrent Manager Log and Out Directories <br>
[1605970/KB656012] - Oracle E-Business Suite System Administration Release Notes for Release 12.2.3 <br>
	# Choose Request Log and Out File Directory Management Option...',
      p_success_msg            => 'Request Viewing Environment Variables found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
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
debug('end add_signature: EBS_ATG_CP_REQUEST_VIEWING_ENV');



debug('begin add_signature: EBS_ATG_CP_JWS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25755',
      p_sig_id                 => 'EBS_ATG_CP_JWS',
      p_sig_sql                => 'select t.PROFILE_OPTION_ID ID, z.PROFILE_OPTION_NAME, z.USER_PROFILE_OPTION_NAME Profile, v.PROFILE_OPTION_VALUE Value, 
	decode(v.level_id, 10001,''Site'',
	10002,''Application'',
	10003,''Responsibility'',
	10004,''User'',
	10005,''Server'',
	10006,''Organization'') "LEVEL"
	from fnd_profile_options t, fnd_profile_option_values v, fnd_profile_options_tl z
	where (v.PROFILE_OPTION_ID (+) = t.PROFILE_OPTION_ID)
    and (v.LEVEL_ID = 10001)
	and (z.PROFILE_OPTION_NAME = t.PROFILE_OPTION_NAME)
	and z.PROFILE_OPTION_NAME in (''FND_ENABLE_JAVA_WEB_START'', ''ICX_FORMS_LAUNCHER'')',
      p_title                  => 'Java Web Start (JWS) Profiles',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No Java Web Start (JWS) Site Level Profiles found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'The Java Web Start application-deployment technology is included in the Java Runtime Environment (JRE)..<br> <br>
Please review the following document for the minimum JRE release required on the client tier to use Java Web Start with Oracle E-Business Suite: <br>
[11165167] - Using Java Web Start with Oracle E-Business Suite.',
      p_success_msg            => 'Java Web Start (JWS) Site Level Profiles on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CP_JWS');



debug('begin add_signature: CP2_LONGRPTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1296',
      p_sig_id                 => 'CP2_LONGRPTS',
      p_sig_sql                => 'SELECT p.user_concurrent_program_name program_name, count(r.request_id),
to_char(round(avg((nvl(r.actual_completion_date,sysdate) - r.actual_start_date) * 1440), 2),''999,999,999,999.99'') "avg_run_time|mins",
to_char(round(min((nvl(r.actual_completion_date,sysdate) - r.actual_start_date) * 1440), 2),''999,999,999,999.99'') "min_run_time|mins",
to_char(round(max((nvl(r.actual_completion_date,sysdate) - r.actual_start_date) * 1440), 2),''999,999,999,999.99'') "max_run_time|mins"
from fnd_concurrent_requests r, fnd_concurrent_processes c, fnd_concurrent_queues q,
fnd_concurrent_programs_vl p
where p.concurrent_program_id = r.concurrent_program_id and p.application_id = r.program_application_id
and c.concurrent_process_id = r.controlling_manager and q.concurrent_queue_id = c.concurrent_queue_id
and q.concurrent_queue_name <> ''HIGH_IMPACT''and p.application_id >= 20000 and r.actual_start_date >= sysdate-31
and r.status_code = ''C'' and r.phase_code in (''C'',''G'')
and (nvl(r.actual_completion_date,r.actual_start_date) - r.actual_start_date) * 24 * 60 > 30
and p.user_concurrent_program_name not like ''Gather%Statistics%''
and ((nvl(r.actual_completion_date,r.actual_start_date) - r.actual_start_date) * 24 > 16
or (r.actual_start_date-trunc(r.actual_start_date)) * 24 between 9 and 17
or (r.actual_completion_date-trunc(r.actual_completion_date)) * 24 between 9 and 17)
group by p.user_concurrent_program_name
order by avg((nvl(r.actual_completion_date,sysdate) - r.actual_start_date) * 1440) desc',
      p_title                  => 'Long Running Reports During Business Hours',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'You have Long Running Reports During Business Hours',
      p_solution               => 'Review the requests listed and confirm if they are intended to run for longer amounts of time.<br> 
If the wrong date range is used or a large volume of data exists for the request, a longer run time can be expected.<br> 
Monthly, Quarterly, and Yearly requests would typically run longer.<br><br>
Please review the following :
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite 
[1460572/KB732869] - Concurrent Requests Running for long time and never completing.',
      p_success_msg            => 'There does not appear to be any long running requests during business hours.<br> 
The intent is to proactively identify requests which could represent potential performance problems.<br><br>

Please review the following :
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite 
[1460572/KB732869] - Concurrent Requests Running for long time and never completing.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: CP2_LONGRPTS');



debug('begin add_signature: CP2_ELAPSEDHIST');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE###TIMESRUN'):= 'right,,,';
   l_info('##STYLE###WAITED<BR>MINS'):= 'right,,,';
   l_info('##STYLE##AVG<BR>MINS'):= 'right,,,';
   l_info('##STYLE##AVG<BR>WAIT MINS'):= 'right,,,';
   l_info('##STYLE##MAX<BR>MINS'):= 'right,,,';
   l_info('##STYLE##MIN<BR>MINS'):= 'right,,,';
   l_info('##STYLE##RUN<BR>STHDEV MINS'):= 'right,,,';
   l_info('##STYLE##TOTAL<BR>MINS'):= 'right,,,';
   l_info('##STYLE##WAIT<BR>STHDEV MINS'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '1297',
      p_sig_id                 => 'CP2_ELAPSEDHIST',
      p_sig_sql                => 'SELECT f.application_short_name "APPLICATION", substr(p.user_concurrent_program_name,1,55) "DESCRIPTION",
substr(p.concurrent_program_name,1,20) "PROGRAM", r.priority "PRIORITY", 
to_char(count(*),''999,999,999,999'') "#TIMESRUN",
to_char(round(sum(actual_completion_date - actual_start_date) * 1440, 2),''999,999,999,999.99'') "TOTAL|MINS",
to_char(round(avg(actual_completion_date - actual_start_date) * 1440, 2),''999,999,999,999.99'') "AVG|MINS",
to_char(round(max(actual_completion_date - actual_start_date) * 1440, 2),''999,999,999,999.99'') "MAX|MINS",
to_char(round(min(actual_completion_date - actual_start_date) * 1440, 2),''999,999,999,999.99'') "MIN|MINS",
to_char(round(stddev(actual_completion_date - actual_start_date) * 1440, 2),''999,999,999,999.99'') "RUN|STHDEV MINS",
to_char(round(stddev(actual_start_date - greatest(r.requested_start_date,r.request_date)) * 1440, 2),''999,999,999,999.99'') "WAIT|STHDEV MINS",
to_char(round(sum(actual_start_date - greatest(r.requested_start_date,r.request_date)) * 1440, 2),''999,999,999,999.99'') "#WAITED|MINS",
to_char(round(avg(actual_start_date - greatest(r.requested_start_date,r.request_date)) * 1440, 2),''999,999,999,999.99'') "AVG|WAIT MINS",
c.request_class_name "TYPE"
from fnd_concurrent_request_class c, fnd_application f, fnd_concurrent_programs_vl p,
fnd_concurrent_requests r 
where r.program_application_id = p.application_id and r.concurrent_program_id = p.concurrent_program_id
and r.status_code in (''C'',''G'') and r.phase_code = ''C'' and p.application_id = f.application_id
and r.program_application_id = f.application_id and r.request_class_application_id = c.application_id(+)
and r.concurrent_request_class_id = c.request_class_id(+)
group by c.request_class_name, f.application_short_name, p.concurrent_program_name, p.user_concurrent_program_name, r.priority
order by count(*)',
      p_title                  => 'Elapsed Time History of Concurrent Requests',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This section identifies the total time duration for recently completed requests.',
      p_solution               => 'The output produced can be cross referenced with the enabled managers and defined workshifts outputs,
	for better allocation of requests across the existing managers/workshifts. <br>
	For example you can consider assigning quick requests to one manager and/or workshift, and assigning slow requests to another manager and/or workshift. <br>
	Requests with varying runtimes can also be moved to their own manager, or remain with the standard manager queue.',
      p_success_msg            => '',
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
debug('end add_signature: CP2_ELAPSEDHIST');



debug('begin add_signature: CP2_CURRENTREQS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1298',
      p_sig_id                 => 'CP2_CURRENTREQS',
      p_sig_sql                => 'SELECT w.seconds_in_wait "Secondswait", w.event "waitEvent", w.p1||chr(10)||w.p2||chr(10)||w.p3 "Session Wait",
p.spid||chr(10)||s.process "ServerClient", s.sid||chr(10)||s.serial#||chr(10)||s.sql_hash_value "SidSerialSQLHash",
u.user_name||chr(10)||PHASE_CODE||'' ''||STATUS_CODE||chr(10)||s.status "DBPhaseStatusCODEUser",
Request_id||chr(10)||priority_request_id||chr(10)||Parent_request_id "Request_id",
concurrent_program_name, user_concurrent_program_name,
to_char(requested_start_Date,''DD-MON-RR HH24:MI:SS'') "Requested Start Date",
ARGUMENT_TEXT, CONCURRENT_QUEUE_ID, QUEUE_DESCRIPTION
FROM FND_CONCURRENT_WORKER_REQUESTS, fnd_user u, v$session s, v$process p, v$session_wait w 
WHERE (Phase_Code=''R'')and hold_flag != ''Y''and Requested_Start_Date <= SYSDATE 
AND ('''' IS NULL OR ('''' = ''B'' AND PHASE_CODE = ''R'' AND STATUS_CODE IN (''I'', ''Q'')))and ''1'' in (0,1,4)
and requested_by=u.user_id and s.paddr=p.addr and s.sid=w.sid and oracle_process_id = p.spid
and oracle_session_id = s.audsid 
order by requested_start_date',
      p_title                  => 'Requests Currently Running on a System',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no Concurrent Requests currently Running on this instance.',
      p_solution               => 'This table reflects a summary for all concurrent requests running on the instance with their current state.',
      p_success_msg            => 'This reflects a summary for all concurrent requests running on the instance with their current state.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: CP2_CURRENTREQS');



debug('begin add_signature: CP2_CONCREQS2');
   l_info('##COMPLEX_TYPE##'):= 'I';
  add_signature(
      p_sig_repo_id            => '1323',
      p_sig_id                 => 'CP2_CONCREQS2',
      p_sig_sql                => 'SELECT request_id "REQUEST ID", nvl(meaning, ''UNKNOWN'') "STATUS", user_concurrent_program_name "PROGRAM NAME",
to_char(actual_start_date, ''DD-MON-RR HH24:MI:SS'') "STARTED", decode(run_alone_flag, ''Y'', ''Yes'', ''No'') "RUN ALONE"
FROM   fnd_concurrent_requests fcr, fnd_lookups fl, fnd_concurrent_programs_vl fcpv
WHERE  phase_code = ''R'' AND LOOKUP_TYPE = ''CP_STATUS_CODE'' AND lookup_code = status_code
AND fcr.concurrent_program_id = fcpv.concurrent_program_id AND fcr.program_application_id = fcpv.application_id
ORDER BY actual_start_date, request_id',
      p_title                  => 'Running Requests',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no concurrent requests currently running on this '||g_rep_info('Instance')||' instance.',
      p_solution               => 'The output provided is for review and confirmation by your teams, and serves as a baseline of whats currently running on the system.<br>
    Otherwise there is no immediate action required.',
      p_success_msg            => 'The output provided is for review and confirmation by your teams, and serves as a baseline of whats currently running on the system.<br>
    Otherwise there is no immediate action required.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','Y')
      );
   l_info.delete;
   l_info.delete;
debug('end add_signature: CP2_CONCREQS2');



debug('begin add_signature: CP2_PENDREQ');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE### REQUESTS'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '1301',
      p_sig_id                 => 'CP2_PENDREQ',
      p_sig_sql                => 'SELECT ''Pending'' "PHASE", meaning "STATUS", to_char(count(*),''999,999,999,999'') "# REQUESTS"
FROM   fnd_concurrent_requests, fnd_lookups
WHERE  LOOKUP_TYPE = ''CP_STATUS_CODE'' AND lookup_code = status_code AND phase_code = ''P''
GROUP BY meaning',
      p_title                  => 'Total Pending Requests by Status Code',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no Pending Requests currently found on this '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' instance.',
      p_solution               => 'The output provided is for review and confirmation by your teams, and serves as a baseline of whats currently pending on the system. <br>
    Otherwise there is no immediate action required.',
      p_success_msg            => 'The output provided is for review and confirmation by your teams, and serves as a baseline of whats currently pending on the system. <br>
    Otherwise there is no immediate action required.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: CP2_PENDREQ');



debug('begin add_signature: CP2_TOP_10_CONC_REQS');
   l_info('##MASK##USER_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##COUNT'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '5062',
      p_sig_id                 => 'CP2_TOP_10_CONC_REQS',
      p_sig_sql                => 'select u.user_name, cp.CONCURRENT_PROGRAM_ID "CP ID", cp.CONCURRENT_PROGRAM_NAME "SHORT NAME", cp.USER_CONCURRENT_PROGRAM_NAME "PROGRAM NAME", 
to_char(count(r.request_id),''999,999,999,999'') "COUNT"
from fnd_concurrent_requests r, fnd_user u, fnd_concurrent_programs_vl cp
where r.requested_by = u.user_id
and r.CONCURRENT_PROGRAM_ID = cp.CONCURRENT_PROGRAM_ID
and u.user_name in  (select user_name from (
select u.user_name, count(r.request_id)
from fnd_concurrent_requests r, fnd_user u
where r.requested_by = u.user_id
group by u.user_name
order by 2 desc)
where rownum < 11)
group by u.user_name, cp.CONCURRENT_PROGRAM_ID, cp.CONCURRENT_PROGRAM_NAME, cp.USER_CONCURRENT_PROGRAM_NAME
order by 5 desc',
      p_title                  => 'Top 10 Users Running Concurrent Requests',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No Users are found to be running Concurrent Requests',
      p_solution               => 'Check the FND_CONCURRENT_REQUESTS table for data.',
      p_success_msg            => 'List of top 10 users that are running/scheduling Concurrent Requests and the Concurrent Programs they are running.   This list is for performance review.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '15'
      );
   l_info.delete;
debug('end add_signature: CP2_TOP_10_CONC_REQS');



debug('begin add_signature: CP2_END_DATED_USER_REQS');
   l_info('##MASK##REQUESTED_BY'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8329',
      p_sig_id                 => 'CP2_END_DATED_USER_REQS',
      p_sig_sql                => 'select fcr.REQUEST_ID, fu.USER_NAME "REQUESTED_BY", 
decode(fcr.PHASE_CODE, ''C'',''Completed'', ''I'',''I=Inactive'', ''P'',''P=Pending'', ''R'',''R=Running'') PHASE,
p.USER_CONCURRENT_PROGRAM_NAME, fcr.ARGUMENT_TEXT "Arguments", fcr.RESUBMIT_INTERVAL EVERY, 
fcr.RESUBMIT_INTERVAL_UNIT_CODE SO_OFTEN, fcr.RESUBMIT_END_DATE
FROM fnd_concurrent_requests fcr, FND_CONCURRENT_PROGRAMS_TL p, fnd_user fu
WHERE fcr.REQUESTED_BY = fu.USER_ID
and fcr.CONCURRENT_PROGRAM_ID = p.CONCURRENT_PROGRAM_ID
and p.USER_CONCURRENT_PROGRAM_NAME LIKE ''Active%User%'' 
AND p.LANGUAGE = ''US''
and fcr.ACTUAL_COMPLETION_DATE is null
and fcr.PHASE_CODE <> ''C''
and fcr.REQUESTED_BY in (select fui.user_id from fnd_user fui where nvl(fui.END_DATE, sysdate) < sysdate )',
      p_title                  => 'Requests Submitted by End-Dated Users',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Requests found that were submitted by Users or Responsibilities that have been end-dated.<br><br>
When a user or responsibility is end-dated, if there are any scheduled requests against the user or responsibility which has been end-dated, the scheduled request still tries to run and causes high CPU and memory usage on both concurrent and database tiers.

',
      p_solution               => 'As a workaround, manually terminate the above scheduled requests submitted by end-dated users. You may reschedule the same request afresh with existing user (not end-dated).<br>
Apply any patches outlined by [1075684/KB625898] to fix the issue.<br><br>

Concurrent managers use a cursor to update request log files but this cursor may get invalid parameters assigned when 11G database is used, therefore update fails and managers keep trying to run same request in a loop.<br><br>

Please review the solution found in [1075684/KB625898] - Concurrent Managers are consuming high CPU and memory.',
      p_success_msg            => 'Success !!!<br><br>
No Concurrent Requests found scheduled by users or responsibilities that have been end-dated.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: CP2_END_DATED_USER_REQS');



debug('begin add_signature: CP2_PENDING_REQUESTS');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##COUNTS'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '5227',
      p_sig_id                 => 'CP2_PENDING_REQUESTS',
      p_sig_sql                => 'SELECT ''Pending Requests Regularly Scheduled:'' "PENDING REQUESTS", 
to_char(count(*),''999,999,999,999'') "COUNTS"
from   fnd_concurrent_requests
WHERE  (requested_start_date > sysdate OR status_code = ''P'') AND phase_code = ''P''
union
SELECT ''Pending Requests Non Regularly Scheduled:'' "Pending Requests", 
to_char(count(*),''999,999,999,999'') "COUNT"
from   fnd_concurrent_requests
WHERE  requested_start_date <= sysdate AND status_code != ''P'' AND phase_code = ''P''
union
SELECT ''Pending Requests On Hold:'' "Pending Requests", 
to_char(count(*),''999,999,999,999'') "COUNT"
from   fnd_concurrent_requests
WHERE  hold_flag = ''Y'' AND phase_code = ''P''
union
SELECT ''Pending Requests Not On Hold:'' "Pending Requests", 
to_char(count(*),''999,999,999,999'') "COUNT"
from   fnd_concurrent_requests
WHERE  hold_flag != ''Y'' AND phase_code = ''P''',
      p_title                  => 'Types of Pending Requests and Counts',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no rows found for pending requests.
',
      p_solution               => 'Ensure that Concurrent Manager is up and running.',
      p_success_msg            => 'Displays a list a Pending Requests for : <br>
<ul>
<li>Pending Requests Regularly Scheduled:</li>
<li>Pending Requests Non Regularly Scheduled:</li>
<li>Pending Requests On Hold:</li>
<li>Pending Requests Not On Hold:</li>
</ul>',
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
debug('end add_signature: CP2_PENDING_REQUESTS');



debug('begin add_signature: EBS_ATG_CP_PENDING_REQUESTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '23696',
      p_sig_id                 => 'EBS_ATG_CP_PENDING_REQUESTS',
      p_sig_sql                => 'select fcr.request_id, fcr.last_update_date, p.USER_CONCURRENT_PROGRAM_NAME, fcr.resub_count "RESUBMITTED",  
fcr.resubmit_interval "EVERY", fcr.resubmit_interval_unit_code "SO OFTEN", fcr.argument_text "ARGUMENTS",
to_char(fcr.requested_start_date, ''DD-MON-RR HH24:MI:SS'') "SCHEDULED TO RUN"
from fnd_concurrent_requests fcr, FND_CONCURRENT_PROGRAMS_TL p
where fcr.phase_code = ''P''
and fcr.concurrent_program_id = p.concurrent_program_id
order by 1',
      p_title                  => 'Pending Concurrent Requests',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No Pending Requests exist.',
      p_solution               => 'Check if Concurrent Manager is running.  <br>
For more details please review: <br>
[134033/KB515766] - ANALYZEPENDING.SQL - Analyze all Pending Requests.',
      p_success_msg            => 'Concurrent Requests that are pending.',
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
debug('end add_signature: EBS_ATG_CP_PENDING_REQUESTS');



debug('begin add_signature: CP2_SCHEDULEDREQ2');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1308',
      p_sig_id                 => 'CP2_SCHEDULEDREQ2',
      p_sig_sql                => 'SELECT request_id id, nvl(meaning, ''UNKNOWN'') status, user_concurrent_program_name pname,
to_char(request_date, ''DD-MON-RR HH24:MI:SS'') submitd, to_char(requested_start_date, ''DD-MON-RR HH24:MI:SS'') requestd
FROM   fnd_concurrent_requests fcr, fnd_lookups fl, fnd_concurrent_programs_vl fcpv
WHERE  phase_code = ''P'' AND hold_flag = ''N'' AND fcr.requested_start_date <= sysdate
AND status_code != ''P'' AND LOOKUP_TYPE = ''CP_STATUS_CODE'' AND lookup_code = status_code
AND fcr.concurrent_program_id = fcpv.concurrent_program_id AND fcr.program_application_id = fcpv.application_id
ORDER BY request_date, request_id',
      p_title                  => 'Listing of Scheduled Requests Waiting to Run',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are not scheduled requests waiting to run that are currently not on hold.',
      p_solution               => 'The output provided is for review and confirmation by your teams, and serves as a baseline of whats currently scheduled on the system. <br>
    Otherwise there is no immediate action required.',
      p_success_msg            => 'The output provided is for review and confirmation by your teams, and serves as a baseline of Pending Requests waiting to run that are currently not on hold.. <br>
    Otherwise there is no immediate action required.',
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
debug('end add_signature: CP2_SCHEDULEDREQ2');



debug('begin add_signature: CP2_SCHEDULEDREQ');
   l_info('##MASK##REQUESTED_BY'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##HOLD FLAG'):= 'right,#333333,#FFE864,bold';
  add_signature(
      p_sig_repo_id            => '1306',
      p_sig_id                 => 'CP2_SCHEDULEDREQ',
      p_sig_sql                => 'SELECT request_id REQ_ID, fu.user_name "REQUESTED_BY", nvl(meaning, ''UNKNOWN'') status, user_concurrent_program_name PROGRAM_NAME,
to_char(request_date, ''DD-MON-RR HH24:MI:SS'') SUBMITTED, to_char(requested_start_date, ''DD-MON-RR HH24:MI:SS'') START_DATE, decode(HOLD_FLAG,''Y'',''ON HOLD'',''N'','''') "HOLD FLAG"
FROM fnd_concurrent_requests fcr, fnd_lookups fl, fnd_concurrent_programs_vl fcpv, fnd_user fu
WHERE fcr.requested_by = fu.user_id
and phase_code = ''P'' AND (fcr.requested_start_date >= sysdate OR status_code = ''P'' OR hold_flag = ''Y'')
AND LOOKUP_TYPE = ''CP_STATUS_CODE'' AND lookup_code = status_code AND fcr.concurrent_program_id = fcpv.concurrent_program_id
AND fcr.program_application_id = fcpv.application_id
ORDER BY fcpv.user_concurrent_program_name, requested_start_date',
      p_title                  => 'Listing of Scheduled, Pending, and On-Hold Requests',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no Scheduled Requests.',
      p_solution               => 'Displays currently scheduled concurrent requests on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'<br>
<br>
For more information refer to [213021/KB233659] - Concurrent Processing (CP) / APPS Reporting Scripts.',
      p_success_msg            => 'Displays currently scheduled concurrent requests on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'<br>
<br>
For more information, refer to [213021/KB233659] - Concurrent Processing (CP) / APPS Reporting Scripts.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '12'
      );
   l_info.delete;
debug('end add_signature: CP2_SCHEDULEDREQ');



debug('begin add_signature: CP2_LASTMONDAILY');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##COUNTS'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '1309',
      p_sig_id                 => 'CP2_LASTMONDAILY',
      p_sig_sql                => 'SELECT trunc(REQUESTED_START_DATE) "REQUESTED START DATE", to_char(count(request_id),''999,999,999,999'') "COUNTS"
FROM FND_CONCURRENT_REQUESTS
WHERE REQUESTED_START_DATE BETWEEN sysdate-30 AND sysdate
group by rollup(trunc(REQUESTED_START_DATE))',
      p_title                  => 'Volume of Daily Concurrent Requests for Last Month',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The Volume of Daily Concurrent Requests for the past Month may be excessive.',
      p_solution               => 'Instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' has '||mask_text(gk_reqid_cnt, nvl( upper(''), 'NO_MASK') )||' requests in the FND_CONCURRENT_REQUESTS table.  Above is the volume of daily Concurrent Requests for instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' generated over the last 30 days. Based on the size of your company and system capacity, performance tuning will differ.<br>

Remember, for each Concurrent Request generated, a *.log and *.out file are generated on the file system. <ul>
<li>$APPLCSF/$APPLLOG/l<request_id>.req</li>
<li>$APPLCSF/$APPLOUT/o<request_id>.out</li>
</ul>

Large accumulation of these files can cause performance issues.<br>
Oracle Development recommends purging Concurrent Request *.log/*.out 
 files as aggressively as business requirements allow and to run the Purge Concurrent Request and/or Manager Data (FNDCPPUR) program frequently to purge the Concurrent Request tables, as well as these files regularly.<br><br>

For more details on best practices, refer to:  <br>
[1057802/KB263169] - CP - Best Practices for Performance for CMs in EBS <br>
[822368/KB728166] - Purge Concurrent Request FNDCPPUR Does Not Delete Files From File System or Slow performance <br>
[1616827/KB781336] - Managing Concurrent Manager Log and Out Directories <br><br>
',
      p_success_msg            => 'Instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' has '||mask_text(gk_reqid_cnt, nvl( upper(''), 'NO_MASK') )||' requests in the FND_CONCURRENT_REQUESTS table.  Above is the volume of daily Concurrent Requests for instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' generated over the last 30 days. Based on the size of your company and system capacity, performance tuning will differ.<br>

Remember, for each Concurrent Request generated, a *.log and *.out file are generated on the file system. <ul>
<li>$APPLCSF/$APPLLOG/l<request_id>.req</li>
<li>$APPLCSF/$APPLOUT/o<request_id>.out</li>
</ul>

Large accumulation of these files can cause performance issues.<br>
Oracle Development recommends purging Concurrent Request *.log/*.out 
 files as aggressively as business requirements allow and to run the Purge Concurrent Request and/or Manager Data (FNDCPPUR) program frequently to purge the Concurrent Request tables, as well as these files regularly.<br><br>

For more details on best practices, refer to:  <br>
[1057802/KB263169] - CP - Best Practices for Performance for CMs in EBS <br>
[822368/KB728166] - Purge Concurrent Request FNDCPPUR Does Not Delete Files From File System or Slow performance <br>
[1616827/KB781336] - Managing Concurrent Manager Log and Out Directories <br><br>
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '17'
      );
   l_info.delete;
debug('end add_signature: CP2_LASTMONDAILY');



debug('begin add_signature: CP2_RUNALONE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1310',
      p_sig_id                 => 'CP2_RUNALONE',
      p_sig_sql                => 'SELECT CONCURRENT_PROGRAM_NAME "SHORT NAME", USER_CONCURRENT_PROGRAM_NAME "PROGRAM NAME", RUN_ALONE_FLAG "RUN ALONE", ENABLED_FLAG "ENABLED",   DESCRIPTION
FROM FND_CONCURRENT_PROGRAMS_VL
WHERE (RUN_ALONE_FLAG=''Y'')
order by RUN_ALONE_FLAG, ENABLED_FLAG desc',
      p_title                  => 'Identify/Resolve the "Pending/Standby" Issue, if Caused by Run Alone Flag',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no Requests that Identify/Resolve the "Pending/Standby" Issue, if Caused by Run Alone Flag',
      p_solution               => 'The output provided is for review and confirmation by your teams, and is intended to identify any concurrent program definitions causing Pending/Standby Requests which may require review.',
      p_success_msg            => 'The output provided is for review and confirmation by your teams, and is intended to identify any concurrent program definitions causing Pending/Standby Requests which may require review.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: CP2_RUNALONE');



debug('begin add_signature: CP2_TABLESPACES2');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##BLOCKS'):= 'right,,,';
   l_info('##STYLE##EMPTY BLOCKS'):= 'right,,,';
   l_info('##STYLE##LAST ANALYZED'):= 'right,,,';
   l_info('##STYLE##NUM_ROWS'):= 'right,,,';
   l_info('##STYLE##SAMPLE SIZE'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '1312',
      p_sig_id                 => 'CP2_TABLESPACES2',
      p_sig_sql                => 'SELECT table_name "TABLE NAME", to_char(blocks,''999,999,999,999'') "BLOCKS",	
to_char(empty_blocks,''999,999,999,999'') "EMPTY BLOCKS",	
to_char(num_rows,''999,999,999,999'') "NUM_ROWS",
last_analyzed "LAST ANALYZED",
to_char(sample_size,''999,999,999,999'') "SAMPLE SIZE"
FROM all_tables
WHERE table_name in (''FND_CONCURRENT_REQUESTS'',''FND_CONCURRENT_PROCESSES'',
''FND_CONCURRENT_QUEUES'',''FND_ENV_CONTEXT'',''FND_EVENTS'',''FND_EVENT_TOKENS'')
order by 2',
      p_title                  => 'Tablespace Statistics for the FND_CONCURRENT Tables',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no rows found for Additional Tablespace Statistics for the FND_CONCURRENT Tables',
      p_solution               => 'The output provided is for review and confirmation by your teams, and serves as a baseline regarding your tablespace disk overhead. <br>
    You can cross reference the collected information with existing notes on tablespace sizing and defragmentation best practices.<br>
Please review [1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite.',
      p_success_msg            => 'The output provided is for review and confirmation by your teams and serves as a baseline regarding your tablespace disk overhead. <br>
    You can cross reference the collected information with existing notes on tablespace sizing and defragmentation best practices.<br>
Please review [1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite.',
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
debug('end add_signature: CP2_TABLESPACES2');



debug('begin add_signature: CP1_FND_CP_GSM_OPP_AQTBL_S');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '12603',
      p_sig_id                 => 'CP1_FND_CP_GSM_OPP_AQTBL_S',
      p_sig_sql                => 'select to_number(trim(substr(name, 4))) "concurrentprocessid"
from applsys.aq$fnd_cp_gsm_opp_aqtbl_s
where to_number(trim(substr(name, 4))) not in 
  (select fcp.concurrent_process_id
   from fnd_concurrent_queues fcq, fnd_concurrent_processes fcp
   where fcq.manager_type in (
           select service_id from fnd_cp_services
           where service_handle = ''FNDOPP'' )
   and fcq.concurrent_queue_id = fcp.concurrent_queue_id
   and fcq.application_id = fcp.queue_application_id
   and fcp.process_status_code = ''A''
  )',
      p_title                  => 'Unable to find an Output Post Processor service caused by orphaned OPP subscribers',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Requests fail during Post Processing with error:<br>
"Unable to find an Output Post Processor service"',
      p_solution               => 'Orphaned OPP subscribers were found in APPLSYS.AQ$FND_CP_GSM_OPP_AQTBL_S that can cause the Output Post Processor to select an invalid/non-running concurrent process id.<br>
To remove the orphaned OPP Subscribers, follow the solution steps outlined in:<br>
<br>
[2215371/KB626530] R12 E-Business Suite Output Post Processor (OPP) Fails To Pick Up Concurrent Requests With Error ''Unable to find an Output Post Processor service to post-process request nnnnn''',
      p_success_msg            => 'There are no orphaned OPP subscribers in APPLSYS.AQ$FND_CP_GSM_OPP_AQTBL_S.  This is correct.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: CP1_FND_CP_GSM_OPP_AQTBL_S');



debug('begin add_signature: CP3_CPADV1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1313',
      p_sig_id                 => 'CP3_CPADV1',
      p_sig_sql                => 'SELECT q.CONCURRENT_QUEUE_NAME "QUEUE NAME", q.USER_CONCURRENT_QUEUE_NAME "USER QUEUE NAME",  
a.application_short_name "MODULE", q.cache_size "CACHE", p.concurrent_time_period_name "TIME PERIOD", 
qs.min_processes "MIN PROCESSES", qs.max_processes "MAX PROCESSES", qs.sleep_seconds "SLEEP SECS"
from fnd_concurrent_queues_vl q, fnd_product_installations i, fnd_application_vl a,
fnd_concurrent_time_periods p, fnd_concurrent_queue_size qs
where i.application_id = q.application_id 
and a.application_id = q.application_id 
and qs.queue_application_id = q.application_id
and qs.concurrent_queue_id = q.concurrent_queue_id 
and qs.period_application_id = p.application_id
and qs.concurrent_time_period_id = p.concurrent_time_period_id 
and q.enabled_flag = ''Y'' 
and nvl(q.control_code,''X'') <> ''E''
order by q.concurrent_queue_name, p.concurrent_time_period_id',
      p_title                  => 'Concurrent Managers Active/Enabled and Workshifts',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no Concurrent Managers Active/Enabled and Workshifts',
      p_solution               => 'This section collects the Concurrent Managers that are currently Active and Enabled to process data, and associated with a specific Workshift, and establishes a baseline list of managers defined on your system. 
	The Workshifts are created to define specific times when a Manager can run requests.<br>
	The resulting data is for review and confirmation by your teams, and serves as a baseline for comparison with later outputs above. <br>
    Otherwise there is no immediate action required.<br><br>
	For more information refer to [1373727/FAQ6026] - FAQ: EBS Concurrent processing Performance and Best Practices.',
      p_success_msg            => 'This section collects the Concurrent Managers that are currently Active and Enabled to process data, and associated with a specific Workshift, and establishes a baseline list of managers defined on your system. 
	The Workshifts are created to define specific times when a Manager can run requests.<br>
	The resulting data is for review and confirmation by your teams, and serves as a baseline for comparison with later outputs above. <br>
    Otherwise there is no immediate action required.<br><br>
	For more information refer to [1373727/FAQ6026] - FAQ: EBS Concurrent processing Performance and Best Practices.',
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
debug('end add_signature: CP3_CPADV1');



debug('begin add_signature: CP3_CPADV2');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1733',
      p_sig_id                 => 'CP3_CPADV2',
      p_sig_sql                => 'SELECT f.concurrent_queue_name, f.concurrent_queue_id "CONC QUEUE ID",
f.user_concurrent_queue_name "QUEUE NAME", f.max_processes "MAX", f.running_processes "RUNNING",
DECODE(f.control_code, ''B'',''B=Activated'',''A'',''A=Activating'',''E'',''E=Deactivated'',
''D'',''D=Deactivating'',''R'',''R=Restarting'',''Q'',''Q=Resuming Concurrent Manager'',
''P'',''P=Suspended'',''O'',''O=Suspending Concurrent Manager'',
''H'',''H=System Hold, Fix Manager before resetting counters'',
''N'',''N=Target node/queue unavailable'',''X'',''X=Terminated'',
''T'',''T=Terminating'',''U'',''U=Updating Environment Information'',''V'',''V=Verifying'') "CONTROL CODE",
f.target_node "ACTUAL NODE", f.enabled_flag "ENABLED",
to_char(f.last_update_date,''DD-MON-RR HH24:MI:SS'') "LAST_UPDATE_DATE",
f.node_name "PRIMARY NODE", f.node_name2 "SECONDARY NODE"
FROM fnd_concurrent_queues_vl f
where f.enabled_flag = ''Y''
order by f.application_id, f.concurrent_queue_id',
      p_title                  => 'Concurrent Managers Active/Enabled Overview',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no Concurrent Managers which are Active or Enabled',
      p_solution               => 'Review the fnd_concurrent_queues_vl view table',
      p_success_msg            => 'Displays a list of Active Managers',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: CP3_CPADV2');



debug('begin add_signature: EBS_ATG_CT_FND_CONCURRENT_QUEUES_NODE_DETAILS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '29564',
      p_sig_id                 => 'EBS_ATG_CT_FND_CONCURRENT_QUEUES_NODE_DETAILS',
      p_sig_sql                => 'select concurrent_queue_name, control_code, target_node, node_name 
from fnd_concurrent_queues',
      p_title                  => 'Node Details for FND_CONCURRENT_QUEUES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No problem',
      p_solution               => 'No Solution',
      p_success_msg            => 'FND_CONCURRENT_QUEUES Node Details',
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
debug('end add_signature: EBS_ATG_CT_FND_CONCURRENT_QUEUES_NODE_DETAILS');



debug('begin add_signature: EBS_ATG_CT_APPLTMP_UTL_FILE_DIR');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '30020',
      p_sig_id                 => 'EBS_ATG_CT_APPLTMP_UTL_FILE_DIR',
      p_sig_sql                => 'select substrb(translate(ltrim(value),'','','' ''), 1,
 instr(translate(ltrim(value),'','','' ''),'' '') - 1) Directory
  FROM v$parameter
  WHERE name LIKE ''utl_file_dir''
UNION
select value Directory
from   fnd_env_context
where  variable_name = ''APPLTMP''
and    concurrent_process_id = 
      ( select max(concurrent_process_id) from fnd_env_context )',
      p_title                  => 'APPLTMP and utl_file_dir Defintions',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'Incorrectly set UTL_FILE_DIR and $APPLPTMP configuration.  Although the environment is not exhibiting any symptoms or errors presently, as patches are applied and the code advances, the UTL_FILE_DIR and $APPLPTMP configuration will be expected.',
      p_solution               => 'As a preventive measure, when time permits, have your DBA update the UTL_FILE_DIR database parameter; make the value of the $APPLPTMP environment variable the first path within UTL_FILE_DIR. <br><br>
Refer to [261693/KB627197]',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CT_APPLTMP_UTL_FILE_DIR');



debug('begin add_signature: CP3_CPADV3');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1314',
      p_sig_id                 => 'CP3_CPADV3',
      p_sig_sql                => 'SELECT q.CONCURRENT_QUEUE_NAME "QUEUE NAME", q.user_concurrent_queue_name "NAME", a.APPLICATION_SHORT_NAME "APPLICATION",  p.concurrent_time_period_name "TIME PERIOD", qs.min_processes "MIN PROCESSES"
from fnd_concurrent_queues_vl q, fnd_product_installations i, fnd_application_vl a,
fnd_concurrent_time_periods p, fnd_concurrent_queue_size qs
where i.application_id = q.application_id and a.application_id = q.application_id
and qs.queue_application_id = q.application_id and qs.concurrent_queue_id = q.concurrent_queue_id
and qs.period_application_id = p.application_id and qs.concurrent_time_period_id = p.concurrent_time_period_id
and q.enabled_flag = ''Y'' and nvl(q.control_code,''X'') <> ''E'' and qs.min_processes >0 and i.status <> ''I''
order by q.concurrent_queue_name, p.concurrent_time_period_id',
      p_title                  => 'Active Managers for Applications not Installed/Used',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are Concurrent Managers that are active for Application modules not Installed or Used.',
      p_solution               => 'These unused managers can impact performance, and deactivating/disabling them can reduce current application overhead on the instance.  Please see the following note for additional details on how to disable unused managers:<br>
<br>
[2603354/KB787820] How To Identify Active Concurrent Managers For Applications That Are Not Installed/Used?',
      p_success_msg            => 'There are no Concurrent Managers that are active for Application modules not Installed or Used.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '12'
      );
   l_info.delete;
debug('end add_signature: CP3_CPADV3');



debug('begin add_signature: CP3_CPADV4');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1315',
      p_sig_id                 => 'CP3_CPADV4',
      p_sig_sql                => 'SELECT q.CONCURRENT_QUEUE_NAME "QUEUE NAME", q.max_processes "MAX PROCESSES", q.work_start, q.work_end, q.running_processes "RUNNING", q.node_name "NODE1", q.node_name2 "NODE2",
p.concurrent_time_period_name "TIME PERIOD", qs.min_processes "MIN PROCESSES"
from fnd_concurrent_queues q, fnd_product_installations i, fnd_application_vl a,
fnd_concurrent_time_periods p, fnd_concurrent_queue_size qs
where i.application_id = q.application_id and a.application_id = q.application_id
and qs.queue_application_id = q.application_id and qs.concurrent_queue_id = q.concurrent_queue_id
and qs.period_application_id = p.application_id and qs.concurrent_time_period_id = p.concurrent_time_period_id
and q.enabled_flag = ''Y'' and nvl(q.control_code,''X'') <> ''E'' and qs.min_processes >0 and q.manager_type = 1
and p.concurrent_time_period_name not in (''Standard'')
order by qs.min_processes desc,q.concurrent_queue_name',
      p_title                  => 'Total Target Processes for Request Managers Excluding Standard Shift',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Total Target Processes for Request Managers Excluding Standard Shift.<br>
    This identifies the total number of processes that can be run for a given concurrent manager. <br>
    The greater the number of processes defined can impact increased Concurrent Processing loads. ',
      p_solution               => 'The resulting data is for review and confirmation by your teams, and serves as a baseline for comparison with later outputs above. <br>
	Otherwise there is no immediate action required.',
      p_success_msg            => 'There are no rows found for Total Target Processes for Request Managers Excluding Standard Shift.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: CP3_CPADV4');



debug('begin add_signature: CP3_CPADV5');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1316',
      p_sig_id                 => 'CP3_CPADV5',
      p_sig_sql                => 'SELECT q.CONCURRENT_QUEUE_NAME, q.USER_CONCURRENT_QUEUE_NAME, q.cache_size, q.running_processes "ACTUAL", q.MAX_PROCESSES "TARGET" 
from fnd_concurrent_queues_vl q, fnd_product_installations i, fnd_application_vl a,
fnd_concurrent_time_periods p, fnd_concurrent_queue_size qs
where i.application_id = q.application_id and a.application_id = q.application_id
and qs.queue_application_id = q.application_id and qs.concurrent_queue_id = q.concurrent_queue_id
and qs.period_application_id = p.application_id and qs.concurrent_time_period_id = p.concurrent_time_period_id
and q.enabled_flag = ''Y'' and nvl(q.control_code,''X'') <> ''E'' and qs.min_processes >0 and q.manager_type = 1
group by q.CONCURRENT_QUEUE_NAME, q.USER_CONCURRENT_QUEUE_NAME, q.cache_size, q.running_processes, q.MAX_PROCESSES
having decode(max(qs.min_processes),1,2,max(qs.min_processes)) > nvl(q.cache_size,1)
order by  q.concurrent_queue_name',
      p_title                  => 'Display Managers Cache Size, Actual & Target Processes',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no Concurrent Queue or Managers defined in this instance.',
      p_solution               => 'A Managers cache size reflects the number of requests a manager adds to its queue, each time it reads available requests to run. <br>
For example, if a manager has 1 target process and a cache value of 3, it will read 3 requests and run those requests before returning to cache additional requests. 
	<br><br>
	Tip: Enter a value of 1 when defining a manager that runs long, time-consuming jobs, and a value of 3 or 4 for managers that run small, quick jobs. <BR><br>
	For more information refer to [1373727/FAQ6026] - FAQ: EBS Concurrent processing Performance and Best Practices',
      p_success_msg            => 'Please review the list of Concurrent Managers for correct Cache Size and Actual & Target Processes.<br><br>
A Managers cache size reflects the number of requests a manager adds to its queue, each time it reads available requests to run. <br>
For example, if a manager has 1 target process and a cache value of 3, it will read 3 requests and run those requests before returning to cache additional requests. 
	<br><br>
Tip: Enter a value of 1 when defining a manager that runs long, time-consuming jobs, and a value of 3 or 4 for managers that run small, quick jobs. <BR><br>
For more information refer to [1373727/FAQ6026] - FAQ: EBS Concurrent processing Performance and Best Practices',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: CP3_CPADV5');



debug('begin add_signature: CP3_CPADV11');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##AVG'):= 'right,,,';
   l_info('##STYLE##AVGWAIT'):= 'right,,,';
   l_info('##STYLE##COUNT'):= 'right,,,';
   l_info('##STYLE##ELAPSED'):= 'right,,,';
   l_info('##STYLE##WAITED'):= 'right,,,';
   l_info('##STYLE##WSTDDEV'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '1317',
      p_sig_id                 => 'CP3_CPADV11',
      p_sig_sql                => 'SELECT q.concurrent_queue_name "CONCURRENT QUEUE NAME", 
to_char(count(*),''999,999,999,999'') "COUNT", 
to_char(round(sum(r.actual_completion_date - r.actual_start_date) * 24, 2),''999,999,999,999.99'') "ELAPSED",
to_char(round(avg(r.actual_completion_date - r.actual_start_date) * 24, 2),''999,999,999,999.99'') "AVG",
to_char(round(stddev(actual_start_date - greatest(r.requested_start_date,r.request_date)) * 24, 2),''999,999,999,999.99'') "WSTDDEV",
to_char(round(sum(actual_start_date - greatest(r.requested_start_date,r.request_date)) * 24, 2),''999,999,999,999.99'') "WAITED",
to_char(round(avg(actual_start_date - greatest(r.requested_start_date,r.request_date)) * 24, 2),''999,999,999,999.99'') "AVGWAIT"
from fnd_concurrent_programs p, fnd_concurrent_requests r, fnd_concurrent_queues q,
fnd_concurrent_processes p 
where r.program_application_id = p.application_id and r.concurrent_program_id = p.concurrent_program_id 
and r.phase_code=''C'' -- completed and r.status_code in (''C'',''G'') -- completed normal or with warning
and r.controlling_manager=p.concurrent_process_id and q.concurrent_queue_id=p.concurrent_queue_id 
and r.concurrent_program_id=p.concurrent_program_id 
group by q.concurrent_queue_name',
      p_title                  => 'Concurrent Manager Request Summary by Manager',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'These are the concurrent managers being used, and can be compared with the actual concurrent managers allocated at startup. <br>
    This only considers requests with completion status of normal/warning.',
      p_solution               => 'Please consider deactivation of any managers which are consistently not being used, and are listed as Active/Enabled above.',
      p_success_msg            => 'There are no concurrent managers are being used, and can be compared with the actual concurrent managers allocated at startup.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: CP3_CPADV11');



debug('begin add_signature: CP3_CPADV12');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1318',
      p_sig_id                 => 'CP3_CPADV12',
      p_sig_sql                => 'SELECT a.CONCURRENT_QUEUE_ID "Queue ID", a.QUEUE_APPLICATION_ID "Apps ID",
b.user_CONCURRENT_QUEUE_NAME "Concurrent Manager", decode(a.PHASE_CODE, ''P'',''PENDING'',''R'',''Running'') Phase,count(1)
FROM FND_CONCURRENT_WORKER_REQUESTS a, fnd_concurrent_queues_vl b
WHERE (a.Phase_Code = ''P'' or a.Phase_Code = ''R'') and a.hold_flag != ''Y'' and a.Requested_Start_Date <= SYSDATE
AND ('''' IS NULL OR ('''' = ''B'' AND a.PHASE_CODE = ''R'' AND a.STATUS_CODE IN (''I'', ''Q''))) and ''1'' in (0,1,4)
And a.concurrent_queue_id=b.concurrent_queue_id
group by a.CONCURRENT_QUEUE_ID, a.QUEUE_APPLICATION_ID, b.user_CONCURRENT_QUEUE_NAME, a.PHASE_CODE
order by 1',
      p_title                  => 'Check Manager Queues for Pending Requests',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are concurrent requests that are in a Pending state. ',
      p_solution               => 'The output above is for review and confirmation by your team. Typically when there are requests pending, the number should be the same as the number of actual processes. <br>
    However if there are no pending requests or requests were just submitted, the number of requests running may be less than the number of actual processes. <br>
	Also note if a concurrent program is incompatible with another program currently running, it does not start until the incompatible program has completed. In this case, the number of requests running may be less than number of actual processes even when there are requests pending.',
      p_success_msg            => 'There are no concurrent requests that are in a Pending state.',
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
debug('end add_signature: CP3_CPADV12');



debug('begin add_signature: CP4_RUN_ALONE_PROGRAMS');
   l_info('##MASK##USER'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5603',
      p_sig_id                 => 'CP4_RUN_ALONE_PROGRAMS',
      p_sig_sql                => 'SELECT r.request_id "REQ ID", RUN_ALONE_FLAG,
    a.application_name "APPLICATION",
    t.user_concurrent_program_name "PROGRAM",
    p.concurrent_program_name "SHORT NAME",
    DECODE(p.execution_method_code,
        ''I'',        ''PL/SQL Concurrent Program'',
        ''K'',        ''Java Concurrent Program'',
        ''P'',        ''Oracle*Reports Concurrent Program'',
        ''Q'',        ''SQL*Plus Concurrent Program'') "EXECUTION METHOD",
    DECODE(p.queue_method_code,
        ''B'',        ''B=Yes'',
        ''I'',        ''I=No'') "QUEUE METHOD",
    u.user_name "USER",
    TO_CHAR(r.requested_start_date,''DD-MON-RR HH24:MI:SS'') "STARTED",
    r.is_sub_request "IS SUB REQUEST",
    DECODE(r.phase_code,
        ''C'',        ''Completed'',
        ''I'',        ''I=Inactive'',
        ''P'',        ''P=Pending'',
        ''R'',        ''R=Running'') "PHASE",
    DECODE(r.status_code,
        ''A'',        ''Waiting'',
        ''B'',        ''B=Resuming'',
        ''C'',        ''C=Normal'',
        ''D'',        ''D=Cancelled'',
        ''E'',        ''E=Error'',
        ''G'',        ''G=Warning'',
        ''H'',        ''H=On Hold'',
        ''I'',        ''I=Normal'',
        ''M'',        ''M=No Manager'',
        ''P'',        ''P=Scheduled'',
        ''Q'',        ''Q=Standby'',
        ''R'',        ''R=Normal'',
        ''S'',        ''S=Suspended'',
        ''T'',        ''T=Terminating'',
        ''U'',        ''U=Disabled'',
        ''W'',        ''W=Paused'',
        ''X'',        ''X=Terminated'',
        ''Z'',        ''Z=Waiting'') "STATUS"
FROM
    fnd_concurrent_programs_tl t,
    fnd_concurrent_programs p,
    fnd_application_tl a,
    fnd_concurrent_requests r,
    fnd_languages l,
    fnd_user u
WHERE a.application_id = t.application_id
    AND r.concurrent_program_id = t.concurrent_program_id
    AND t.concurrent_program_id = p.concurrent_program_id
    AND r.nls_language = l.nls_language
    AND l.language_code = t.language
    AND l.language_code = a.language
    AND r.requested_by = u.user_id
    AND p.run_alone_flag = ''Y''',
      p_title                  => 'Run Alone Programs',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are Run Alone Programs defined in this this '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' instance.',
      p_solution               => '"Run Alone" programs will cause a momentary "Inactive No Manager" and/or "Pending" status, because no program can run while a "Run Alone" program runs.<br><br> 

Check the above list of program(s) that may be causing any prolonged "Inactive No Manager" state.<br>
The "Run Alone" option should be used very sparingly and only with short / quick running programs, because it blocks all other programs while it is queued / running.<br><br>
For more details, please review Concurrent Processing 11i - R12 : Requests Stay In Pending / Standby and Inactive/No Manager Status Forever Wherein The Concurrent Managers Are Up And Running But Do Not Process Requests [2083388/KB627175].

',
      p_success_msg            => 'There are no Run Alone Programs defined in this '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' instance.<br><br>
It is possible to define a concurrent program to be run-alone or to be incompatible with specific
concurrent programs by editing the concurrent program''s definition using the
Concurrent Programs window.<br><br>
Program incompatibility and run-alone program definitions are enforced by the Conflict Resolution Manager (CRM).<br>
For more details see: Oracle® E-Business Suite System Administrator''s Guide - Configuration - Concurrent Programs, page 6-65.',
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
debug('end add_signature: CP4_RUN_ALONE_PROGRAMS');



debug('begin add_signature: CP4_STD_MGR_INCL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5390',
      p_sig_id                 => 'CP4_STD_MGR_INCL',
      p_sig_sql                => 'select decode(c.include_flag,''E'',''Exclude'',''I'',''Include'') "INCLUDE_FLAG",
decode (c.type_code,''C'',''Combined Rule'',''L'',''Logical DB'',
''O'',''Oracle ID'',''P'',''Program'',''R'',''Request Type'',''U'',''User'') "TYPE_CODE",
a.application_name, t.user_concurrent_program_name
from fnd_concurrent_queue_content c, fnd_concurrent_programs p,
fnd_concurrent_programs_tl t, fnd_application_tl a
where c.concurrent_queue_id = 0
and c.include_flag = ''I''
and c.type_application_id = p.application_id
and c.type_id = p.concurrent_program_id
and p.application_id = a.application_id
and t.concurrent_program_id = p.concurrent_program_id
and a.language=t.language',
      p_title                  => 'Standard Manager has an INCLUDE defined',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The Standard concurrent manager has been altered with an INCLUDE. <br>
',
      p_solution               => 'Ensure that the Standard Manager''s definition has not been changed with a "Included" Specialization" rule--"Excluded" is ok. <br>
If you do, and you have not defined additional managers to accept your requests, some programs may not run. Use the Standard manager as a safety net, a manager who is always available to run any request. Define additional managers to handle your installation site''s specific needs.
<br><br>
(Responsibility = System Administrator, Navigate --> Concurrent: Manager: Define)<br>
Any changes requires that you "Verify" the Internal Concurrent Manager on the "Administer Concurrent Managers" screen.<br><br>

Refer to [2416412/KB789838] 

Navigate to the Standard Manager and remove the INCLUDE programs.<br><br>

When changing manager specialization or program incompatibilities, remember to "Verify" the ICM on the Administer Concurrent Manager form or bounce (restart) the concurrent managers for the changes to take effect. <br><br>
',
      p_success_msg            => 'No rows were selected so I am calling this a success.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: CP4_STD_MGR_INCL');



debug('begin add_signature: CP3_CPADV17');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1319',
      p_sig_id                 => 'CP3_CPADV17',
      p_sig_sql                => 'SELECT  v.concurrent_queue_name "CONCURRENT QUEUE NAME", v.concurrent_queue_id "QUEUE ID",
	v.user_concurrent_queue_name "NAME", v.max_processes "TARGET", v.running_processes "ACTUAL",
	v.control_code "CODE", v.target_node "TARGET NODE", 
	TO_CHAR(v.last_update_date, ''DD-MON-RR HH24:MI:SS'') "LAST UPDATE",
	v.node_name "NODE NAME", s.service_parameters "SERVICE PARAMETERS",
	c.developer_parameters "DEVELOPER PARAMETERS"
	FROM fnd_concurrent_queues_vl v, fnd_concurrent_queue_size s,
	fnd_cp_services c
	WHERE v.concurrent_queue_name like ''%FNDCPOPP%''
	and v.concurrent_queue_id = s.concurrent_queue_id
	and v.manager_type = c.service_id',
      p_title                  => 'Check the Configuration of OPP',
      p_fail_condition         => '[TARGET] >= [5]',
      p_problem_descr          => 'OPP currently configured with max processes greater than or equal to 5.  Development recommends only 2 OPP Manager Processes per node, in order to avoid manager process contention.',
      p_solution               => 'The output provided is for review and confirmation by your teams, and serves as a baseline regarding your current OPP configuration. <br>
	You can cross reference the collected information with existing notes on OPP best practices :<br>
	[1399454/KB627107] - Tuning Output Post Processor (OPP) to Improve Performance<br>
	[1057802/KB263169] -	Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite',
      p_success_msg            => 'OPP is currently configured, identifying the: Service ID, Service Handle, and Parameters used.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: CP3_CPADV17');



debug('begin add_signature: CP3_FND_CP_GSM_OPP_AQTBL');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##COUNT'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '5755',
      p_sig_id                 => 'CP3_FND_CP_GSM_OPP_AQTBL',
      p_sig_sql                => 'select ''AQ$_FND_CP_GSM_OPP_AQTBL'' "NAME", count(*) "COUNT" from applsys.FND_CP_GSM_OPP_AQTBL
union
select ''AQ$_FND_CP_GSM_OPP_AQTBL_S'' "NAME", count(*) "COUNT" from applsys.AQ$_FND_CP_GSM_OPP_AQTBL_S
union
select ''AQ$_FND_CP_GSM_OPP_AQTBL_T'' "NAME", count(*) "COUNT" from applsys.AQ$_FND_CP_GSM_OPP_AQTBL_T
union
select ''AQ$_FND_CP_GSM_OPP_AQTBL_H'' "NAME", count(*) "COUNT" from applsys.AQ$_FND_CP_GSM_OPP_AQTBL_H
union
select ''AQ$_FND_CP_GSM_OPP_AQTBL_I'' "NAME", count(*) "COUNT" from applsys.AQ$_FND_CP_GSM_OPP_AQTBL_I
union
select ''AQ$_FND_CP_GSM_OPP_AQTBL_G'' "NAME", count(*) "COUNT" from applsys.AQ$_FND_CP_GSM_OPP_AQTBL_G
union
select ''AQ$_FND_CP_GSM_OPP_AQTBL_L'' "NAME", count(*) "COUNT" from applsys.AQ$_FND_CP_GSM_OPP_AQTBL_L',
      p_title                  => 'Status of AQ$_FND_CP_GSM_OPP_AQTBL tables',
      p_fail_condition         => '[COUNT] > [500]',
      p_problem_descr          => '<b>The AQ$_FND_CP_GSM_OPP_AQTBL table has many rows</b><br>
AQs tables are used to look for "subscriptions" by FNDSMs. <br>That is, when ICM calls for FNDSM to start, they "subscribe" to this queue to identify its status. The time taking for the  process cleanup prior to the ICM starting up the regular CMs is correlated to the number of processes that were not stopped cleanly. In case of un-clean shutdown, the process to restart will be longer as manager spends extra cycles to perform housekeeping tasks.',
      p_solution               => '<ul><li>It is highly recommended to always ensure the clean shutdown of the concurrent managers.</li>
<li>The Purge Concurrent Request and/or Manager Data Program request should be run periodically, however, it does not Purge AQ Tables.<br>
For maintaining a healthy level of records in FND_CONCURRENT_REQUESTS instead of running ''Purge Concurrent Program'' with the same parameters for all the applications, try running it for different applications depending on the number of days the data should be kept for.</li>
<li>It is recommended to schedule a cron job to query records in APPLSYS.FND_CP_GSM_OPP_AQTBL to monitor it and use DBMS_AQADM.PURGE_QUEUE_TABLE to purge the table as needed.</li>
<li>If the queue table has to be recreated, the correct schema MUST be used. Confirm if schema migration has been done. Refer to [2755875/KB837303] - <i>Oracle E-Business Suite Release 12.2 System Schema Migration</i>.</li>
<li>Follow the steps outlined in <b>[1156523/KB135522] - <i>How To Purge FND_AQ Tables</i></b> on how to purge the FND_CP_GSM_OPP_AQTBL table manually to clean up the associated tables and indexes.</li></ul>',
      p_success_msg            => 'The AQ$_FND_CP_GSM_OPP_AQTBL table counts look fine.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '19'
      );
   l_info.delete;
debug('end add_signature: CP3_FND_CP_GSM_OPP_AQTBL');



debug('begin add_signature: BIPXDO_CONC_FORCE_LOCAL_OUTPUT_FILE_MODE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5752',
      p_sig_id                 => 'BIPXDO_CONC_FORCE_LOCAL_OUTPUT_FILE_MODE',
      p_sig_sql                => 'select
      b.user_profile_option_name profile_name
      , a.profile_option_name profile_short_name
      , decode(to_char(c.level_id),''10001'',''Site''
      ,''10002'',''Application''
      ,''10003'',''Responsibility''
      ,''10004'',''User''
      ,''Unknown'') Level_type
      , decode(to_char(c.level_id),''10001'',''Site''
      ,''10002'',nvl(h.application_short_name,to_char(c.level_value))
      ,''10003'',nvl(g.responsibility_name,to_char(c.level_value))
      ,''10004'',nvl(e.user_name,to_char(c.level_value))
      ,''Unknown'') level_value
      , c.PROFILE_OPTION_VALUE profile_value
    from
      fnd_profile_options a
      , FND_PROFILE_OPTIONS_VL b
      , FND_PROFILE_OPTION_VALUES c
      , FND_USER d
      , FND_USER e
      , FND_RESPONSIBILITY_VL g
      , FND_APPLICATION h
    where
      b.user_profile_option_name like ''%Concurrent%Force%Output%''
      and a.profile_option_name = b.profile_option_name
      and a.profile_option_id = c.profile_option_id
      and a.application_id = c.application_id
      and c.last_updated_by = d.user_id (+)
      and c.level_value = e.user_id (+)
      and c.level_value = g.responsibility_id (+)
      and c.level_value = h.application_id (+)
      and nvl(c.PROFILE_OPTION_VALUE,''999'') =''Y''
      order by
      b.user_profile_option_name, c.level_id,
      decode(to_char(c.level_id),''10001'',''Site''
      ,''10002'',nvl(h.application_short_name,to_char(c.level_value))
      ,''10003'',nvl(g.responsibility_name,to_char(c.level_value))
      ,''10004'',nvl(e.user_name,to_char(c.level_value))
      ,''Unknown'')',
      p_title                  => 'Verify Force Local Output File Mode Profile',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Concurrent: Force Local Output File Mode profile option is not set.',
      p_solution               => 'Please set Concurrent: Force Local Output File Mode profile option.',
      p_success_msg            => 'Concurrent: Force Local Output File Mode is set as expected',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: BIPXDO_CONC_FORCE_LOCAL_OUTPUT_FILE_MODE');



debug('begin add_signature: OPP_PENDING_REQS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5753',
      p_sig_id                 => 'OPP_PENDING_REQS',
      p_sig_sql                => 'select ''Too many pending OPP requests for the usual monthly load'' from dual
where 
    ( select count(*)
        from fnd_concurrent_requests r
        where request_id in (select concurrent_request_id
        from fnd_conc_pp_actions
        where action_type >= 6
        and processor_id is null)
        and PHASE_CODE = ''P''
        and r.REQUESTED_START_DATE between sysdate - 2 and sysdate 
    )
 >
( select 
  least(greatest(trunc(max(cnt) * 0.01),10 ), 18)
from 
 (select count(*)*2 cnt from fnd_concurrent_requests r where PHASE_CODE=''C''
   and r.REQUESTED_START_DATE between sysdate -30 and sysdate 
   and exists   /* purge has been run in last 6 months */
     (select 1 from fnd_concurrent_programs cp, fnd_concurrent_requests r2
      where r2.concurrent_program_id = cp.concurrent_program_id 
      and r2.PHASE_CODE=''C''
      and r2.REQUESTED_START_DATE >= sysdate -30
      and cp.concurrent_program_name=''FNDCPPUR'' )
   union all   
   select count(*) cnt from fnd_concurrent_requests r where PHASE_CODE=''C'' 
   and r.REQUESTED_START_DATE between sysdate -30 and sysdate
   and not exists /* purge has not been run  */
     (select 1 from fnd_concurrent_programs cp, fnd_concurrent_requests r2
      where r2.concurrent_program_id = cp.concurrent_program_id 
      and r2.PHASE_CODE=''C''
      and cp.concurrent_program_name=''FNDCPPUR''
      and r2.REQUESTED_START_DATE >= sysdate -30 )
 )
)',
      p_title                  => 'Check Pending OPP Requests',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are pending OPP Requests

',
      p_solution               => 'Review the solutions offered in [1399454/KB627107] - Tuning Output Post Processor (OPP) to Improve Performance<br>
for pending OPP Requests.<br><br>

<b>Note :</b>  In general "Administer Concurrent Manager Screen" shows pending and running requests against each manager, but it does not show pending requests against OPP manager. The OPP uses ''Advanced Queue'' to find the pending requests that it needs to process, hence it becomes difficult to configure (or) do sizing of OPP without knowing the workload. For example, "Administrator Screen" shows how many requests are pending (or) running against "Standard Managers" using this information, we can size (Increase Process) Standard Manager accordingly.

However, when the OPP begins to process a concurrent request, it will update the processor_id column of fnd_conc_pp_actions with it''s concurrent_process_id.  We can use the following query to find pending requests against OPP:
<blockquote>
select REQUEST_ID, PHASE_CODE, STATUS_CODE<br>
from fnd_concurrent_requests<br>
where request_id in (select concurrent_request_id<br>
from fnd_conc_pp_actions<br>
where action_type >= 6<br>
and processor_id is null)<br>
and PHASE_CODE != ''C'';</blockquote>
Most of the time, Requests stuck in Running/Normal as the requests wait at OPP. Because they do not know the pending queue size (OPP), customer inadvertently increases the Standard Manager process to speed up which goes in vain. That results in performance issue in the concurrent manager layer.
We have created an ER to display the "Pending Requests" in Concurrent Administer Screen for OPP.<br><br>

Bug 24626221 - CONCURRENT ADMINISTER SCREEN TO DISPLAY PENDING REQUESTS<br><br>

You can cross reference the collected information with existing notes on OPP best practices :<br>
[1399454/KB627107] - Tuning Output Post Processor (OPP) to Improve Performance for pending OPP Requests.<br>[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite',
      p_success_msg            => 'Success!!!<br>
There are no OPP pending requests at this time.<br><br>

<b>Note :</b>  In general "Administer Concurrent Manager Screen" shows pending and running requests against each manager, but it does not show pending requests against OPP manager. The OPP uses ''Advanced Queue'' to find the pending requests that it needs to process, hence it becomes difficult to configure (or) do sizing of OPP without knowing the workload. For example, "Administrator Screen" shows how many requests are pending (or) running against "Standard Managers" using this information, we can size (Increase Process) Standard Manager accordingly.

However, when the OPP begins to process a concurrent request, it will update the processor_id column of fnd_conc_pp_actions with it''s concurrent_process_id.  We can use the following query to find pending requests against OPP:
<blockquote>
select REQUEST_ID, PHASE_CODE, STATUS_CODE<br>
from fnd_concurrent_requests<br>
where request_id in (select concurrent_request_id<br>
from fnd_conc_pp_actions<br>
where action_type >= 6<br>
and processor_id is null)<br>
and PHASE_CODE != ''C'';</blockquote>

Most of the time, Requests stuck in Running/Normal as the requests wait at OPP. Because they do not know the pending queue size (OPP), customer inadvertently increases the Standard Manager process to speed up which goes in vain. That results in performance issue in the concurrent manager layer.
We have created an ER to display the Pending Requests in Concurrent Administer Screen for OPP.<br><br>

Bug 24626221 - CONCURRENT ADMINISTER SCREEN TO DISPLAY PENDING REQUESTS<br><br>

You can cross reference the collected information with existing notes on OPP best practices :<br>
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '15'
      );
   l_info.delete;
debug('end add_signature: OPP_PENDING_REQS');



debug('begin add_signature: BIPXDO_BIPXDOZIP_VER');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3645',
      p_sig_id                 => 'BIPXDO_BIPXDOZIP_VER',
      p_sig_sql                => 'select *  from
(select "Filename", "US Subdir", "US Version"
  from ( select af1.filename "Filename", af1.subdir "US Subdir", afv1.version "US Version",
                   rank()over(partition by af1.filename
                     order by afv1.version_segment1 desc,
                     afv1.version_segment2 desc,afv1.version_segment3 desc,
                     afv1.version_segment4 desc,afv1.version_segment5 desc,
                     afv1.version_segment6 desc,afv1.version_segment7 desc,
                     afv1.version_segment8 desc,afv1.version_segment9 desc,
                     afv1.version_segment10 desc,
                     afv1.translation_level desc) as rankUS
  from ad_files af1, ad_file_versions afv1
where af1.file_id = afv1.file_id
  and af1.filename like ''%xdo%''
  and af1.subdir like ''%3rdparty%'')
where rankUS = 1)',
      p_title                  => 'BI Publisher xdo10g.zip file Version',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'For EBS 12.2, this is a list of the BI Publisher 10g RE-Host file versions to include the required xdo10g.zip file version.',
      p_solution               => '<p><span style="line-height: 20.8px;">The impact of the BIP 10g re-host is for eBusiness Suite 12.2.</span>&nbsp;The following table table contains file versions of the xdo10g.zip file and the patches that distribute the files. The results of the query should match the versions below. Also the patches/checkins listed here correspond to the BIP Analyzer Recommended Patch section.</p>

<table border="0" cellpadding="0" cellspacing="0" style="width:1124px;" width="1124">
	<colgroup>
		<col />
		<col />
		<col />
	</colgroup>
	<tbody>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">File Version</td>
			<td align="left" style="width:155px;">Checkin</td>
			<td align="left" style="width:851px;">Desc</td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.26</td>
			<td>34456759:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.145 REHOSTING ROLLUP FOR EBS 12.2.X</td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.25</td>
			<td>34419550:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.144 REHOSTING ROLLUP FOR EBS 12.2.X</td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.24</td>
			<td>33765613:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.143 REHOSTING ROLLUP FOR EBS 12.2.X</td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.23</td>
			<td>33535981:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.142 REHOSTING ROLLUP FOR EBS 12.2.X </td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.22</td>
			<td>32817004:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.141 REHOSTING ROLLUP FOR EBS 12.2.X  R12.TXK.C</td>
		</tr>
	</tbody>
</table>',
      p_success_msg            => '<p><span style="line-height: 20.8px;">The impact of the BIP 10g re-host is for eBusiness Suite 12.2.</span>&nbsp;The following table table contains file versions of the xdo10g.zip file and the patches that distribute the files. The results of the query should match the versions below. Also the patches/checkins listed here correspond to the BIP Analyzer Recommended Patch section.</p>

<table border="0" cellpadding="0" cellspacing="0" style="width:1124px;" width="1124">
	<colgroup>
		<col />
		<col />
		<col />
	</colgroup>
	<tbody>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">File Version</td>
			<td align="left" style="width:155px;">Checkin</td>
			<td align="left" style="width:851px;">Desc</td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.26</td>
			<td>34456759:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.145 REHOSTING ROLLUP FOR EBS 12.2.X</td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.25</td>
			<td>34419550:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.144 REHOSTING ROLLUP FOR EBS 12.2.X</td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.24</td>
			<td>33765613:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.143 REHOSTING ROLLUP FOR EBS 12.2.X</td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.23</td>
			<td>33535981:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.142 REHOSTING ROLLUP FOR EBS 12.2.X </td>
		</tr>
		<tr height="20">
			<td align="left" height="20" style="height:20px;width:119px;">120.0.12020000.22</td>
			<td>32817004:R12.TXK.C</td>
			<td align="left">BIP 10G BUILD.141 REHOSTING ROLLUP FOR EBS 12.2.X  R12.TXK.C</td>
		</tr>
	</tbody>
</table>',
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
debug('end add_signature: BIPXDO_BIPXDOZIP_VER');



debug('begin add_signature: CP4_XDO_SETTINGS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5604',
      p_sig_id                 => 'CP4_XDO_SETTINGS',
      p_sig_sql                => 'select property_code "PROPERTY CODE", value, 
decode(to_char (config_level), ''10'', ''Site'',''30'', ''DataSource'',''50'', ''Template'', ''???'') "CONFIG LEVEL", 
data_source_code "DATA SOURCE CODE", template_code "TEMPLATE CODE", application_short_name "APP SHORT NAME", last_update_date "LAST UPDATE"
from XDO_CONFIG_VALUES order by property_code',
      p_title                  => 'XDO Settings',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No XDO Settings for this instance.',
      p_solution               => 'Need a solution here.',
      p_success_msg            => 'XDO Settings have been found on this instance.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: CP4_XDO_SETTINGS');



debug('begin add_signature: EBS_ATG_CT_GSM_OPP_PAYLOAD_TYPES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '30171',
      p_sig_id                 => 'EBS_ATG_CT_GSM_OPP_PAYLOAD_TYPES',
      p_sig_sql                => 'select object_name, owner, object_type 
from dba_objects 
where object_name in (''FND_CP_GSM_OPP_AQ_PAYLOAD'',''FND_CP_GSM_IPQ_AQ_PAYLOAD'')',
      p_title                  => 'OPP and GSM Payload Types',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The output provided is for review and confirmation by your teams that the OPP and GSM payload types exist in the correct schema.',
      p_solution               => 'Verify that the GSM and OPP payload types exist in the correct schema.<br>
<br>
TXK.C.13 or higher, there should be a type for each in the APPS_NE schema, and also an APPS synonym pointing to it. <br>
TXK.C.12 and below, there should be a type for each in the SYSTEM schema, and also an APPS synonym pointing to it.<br><br>
If the query have the wrong information, refer to [3000346/KB770445] > Step 5 for solution.',
      p_success_msg            => 'The output provided is for review and confirmation by your teams that the GSM and OPP payload types exist in the correct schema.',
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
debug('end add_signature: EBS_ATG_CT_GSM_OPP_PAYLOAD_TYPES');



debug('begin add_signature: EBS_ATG_CT_GSM_OPP_QUEUES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '30172',
      p_sig_id                 => 'EBS_ATG_CT_GSM_OPP_QUEUES',
      p_sig_sql                => 'select object_name, owner, object_type
from dba_objects 
where object_name in (''FND_CP_GSM_IPC_AQ'',''FND_CP_GSM_OPP_AQ'')',
      p_title                  => 'OPP and GSM Queues',
      p_fail_condition         => '[owner] not like [APPLSYS%]',
      p_problem_descr          => 'The OPP and GSM Queues should exist in the APPLSYS schema.',
      p_solution               => 'The OPP and GSM Queues should exist in the APPLSYS schema.<br><br>

Refer to [3000346/KB770445] > Step 5 for solution.',
      p_success_msg            => 'The OPP and GSM Queues exist in the APPLSYS schema.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CT_GSM_OPP_QUEUES');



debug('begin add_signature: EBS_ATG_CT_AQ_TABLE_PAYLOAD_TYPE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '30173',
      p_sig_id                 => 'EBS_ATG_CT_AQ_TABLE_PAYLOAD_TYPE',
      p_sig_sql                => 'select table_name, column_name, data_type_owner,data_type 
from dba_tab_columns 
where table_name in (''FND_CP_GSM_IPC_AQTBL'',''FND_CP_GSM_OPP_AQTBL'')
and column_name = ''USER_DATA''
order by table_name',
      p_title                  => 'AQ Table Payload Type',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Verify the AQ table has the correct payload type.<br>
These should have a USER_DATA that references the correct payload type. Date Type Owner should be in the APPS_NE schema (If on TXK.C.13 or higher). Otherwise, should be in SYSTEM.',
      p_solution               => 'The output provided is for review and confirmation by your teams, the AQ table has the correct payload type Date Type Owner should be in the APPS_NE schema (If on TXK.C.13 or higher). Otherwise, should be in SYSTEM.<br><br>

Refer to [3000346/KB770445] > Step 5 for solution.',
      p_success_msg            => 'Verify the AQ table has the correct payload type.<br>
These should have a USER_DATA that references the correct payload type. Date Type Owner should be in the APPS_NE schema (If on TXK.C.13 or higher). Otherwise, should be in SYSTEM.',
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
debug('end add_signature: EBS_ATG_CT_AQ_TABLE_PAYLOAD_TYPE');



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



debug('begin add_signature: EBS_ATG_VERSIONS_FROM_SNAPSHOT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '22754',
      p_sig_id                 => 'EBS_ATG_VERSIONS_FROM_SNAPSHOT',
      p_sig_sql                => 'select msg "FILE VERSIONS" from (
select ''A'' seq, ''ATG Files Versions from Snapshot View (version 200.1, snapshot G view was updated ''||trunc(sysdate - snapshot_update_date)||'' days ago on ''||snapshot_update_date||'')'' msg
from AD_SNAPSHOTS s, fnd_product_groups pg
where s.snapshot_type=''G''
union all
select ''B'','' >>> Snapshot G view has not been updated after last patch, update using adadmin: Maintain Snapshot Information / Update current view snapshot. <<< ''
from AD_SNAPSHOTS s where s.snapshot_type=''G''
and snapshot_update_date < (select max(last_update_date) from ad_applied_patches)
union all
select ''C'', f.app_short_name||'' ''||f.subdir|| '' ''|| f.filename||'' ''|| v.version  File_versions
from ad_files f, ad_file_versions v
  , AD_SNAPSHOT_FILES sf
  , AD_SNAPSHOTS s
where 
v.file_id=f.file_id
and sf.file_version_id = v.file_version_id
and f.file_id = sf.file_id
and sf.snapshot_id = s.snapshot_id 
and s.snapshot_type =''G''
and f.APP_SHORT_NAME in (''FND'', ''AU'', ''AD'')
and subdir not like ''help/%''
and subdir not like ''%driver%''
and subdir not like ''%readme%''
order by 1, 2)',
      p_title                  => 'ATG File Versions from AD Snapshot View',
      p_fail_condition         => '[FILE VERSIONS] like [%has not been updated%]',
      p_problem_descr          => 'The AD snapshot views have not been updated after last patch.
This is an auxiliary file version data collection used in other signatures, it is required that the data is up to date in AD store objects.',
      p_solution               => 'Execute adadmin, and follow this navigation:<br>

...<br>
2. Maintain Applications Files menu<br>
...4. Maintain snapshot information<br>
......2. Update current view snapshot<br>
.........1. Update Complete APPL_TOP<br><br>
      
Ref:  "Oracle E-Business Suite Maintenance Guide" - Maintaining Snapshot Information.',
      p_success_msg            => 'Snapshot view G is up to date per the last patch cycle.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_VERSIONS_FROM_SNAPSHOT');



debug('begin add_signature: CP1_CONC_REQQ1');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##COUNT'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '12901',
      p_sig_id                 => 'CP1_CONC_REQQ1',
      p_sig_sql                => 'select ''More than 6 months of concurrent requests (or > 1 million). Total: ''|| total_cnt||'' requests, average: ''||mon_avg||'' requests/mo'' msg
from 
  (select count(request_id) total_cnt from fnd_concurrent_requests r ) tcnt
 , ( select  round(avg(avg_req_cnt),1) mon_avg
            from (
            select mon.cmon
            , avg(req_cnt) 
            avg_req_cnt
            from (
            select r.requested_by, to_char(r.actual_start_date , ''RRRR-MM'') req_mon, count(request_id) req_cnt
                from fnd_concurrent_requests r
                where r.actual_start_date is not null
                and r.ACTUAL_COMPLETION_DATE >= ADD_MONTHS(sysdate,- 4)
                group by r.requested_by, to_char(r.actual_start_date , ''RRRR-MM'')
                ) r
              , (select column_value cmon 
                    from table(sys.ODCIVarchar2List
                    ( to_char(ADD_MONTHS(sysdate,-1),''RRRR-MM''),
                      to_char(ADD_MONTHS(sysdate,-2),''RRRR-MM''),
                      to_char(ADD_MONTHS(sysdate,-3),''RRRR-MM'')
                      ,to_char(ADD_MONTHS(sysdate,-4),''RRRR-MM'')
                    )) ) mon
            where mon.cmon = r.req_mon (+)
            group by mon.cmon
            order by 1 desc )
            where not exists (
            select   1 from fnd_concurrent_programs p
               , fnd_concurrent_requests r
            where p.concurrent_program_name =''FNDCPPUR''
            and r.concurrent_program_id = p.concurrent_program_id 
            and r.program_application_id = p.application_id
            and r.phase_code=''C'' and r.status_code=''C''
            and (r.argument_text like ''ALL%'' or r.argument_text like ''REQ%'')
            having max(actual_start_date) >  ADD_MONTHS(sysdate,-5)
            )
    ) av
where  total_cnt > 5000
and total_cnt > least(6 * av.mon_avg , 1000000 )',
      p_title                  => 'Your overall Concurrent Processing HealthCheck Status is in need of Immediate Review!',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The FND_CONCURRENT_REQUESTS Table has '||mask_text(gk_reqid_cnt, nvl( upper(''), 'NO_MASK') )||' rows of runtime data which exceeds the acceptable maximum thresholds of 6 times the month average or 1 million rows (whatever is lower) that were entered to run this Analyzer.',
      p_solution               => 'Clean up Concurrent Request Data by scheduling the <b>FNDCPPUR - <i>Purge Concurrent Request and/or Manager Data</i></b> on a regular basis.
<br><br>
Run these queries to gather more details about all old requests<br>
<blockquote>
	<table>
		<tr>
			<td> Show Summary of counts By Year</td>
			<td>     <blockquote>
	select to_char(actual_start_date,''YYYY'') "STARTED", to_char(actual_completion_date,''YYYY'') "ENDED", <br>
	count(request_id) "COUNT" <br>
	from fnd_concurrent_requests <br>
	where actual_start_date < sysdate-365 --Show Requests started over 1 year ago<br>
	group by to_char(actual_start_date,''YYYY''), to_char(actual_completion_date,''YYYY'')<br>
	order by 1;
	</blockquote></td>
		</tr>
		<tr>
			<td> Show Summary of counts by Concurrent Program</td>
			<td> <blockquote>
	select fcp.USER_CONCURRENT_PROGRAM_NAME, to_char(r.actual_start_date,''YYYY'') "STARTED",<br> to_char(r.actual_completion_date,''YYYY'') "ENDED", count(r.request_id) "COUNT" <br>
	from fnd_concurrent_requests r, fnd_concurrent_programs_tl fcp<br>
	where r.concurrent_program_id = fcp.concurrent_program_id<br>
	and r.actual_start_date < sysdate-365 --Show Requests started over 1 year ago<br>
	group by fcp.USER_CONCURRENT_PROGRAM_NAME, to_char(r.actual_start_date,''YYYY''),
	to_char(r.actual_completion_date,''YYYY'')<br>
	order by 2;
	</blockquote></td>
		</tr>
	</table>
</blockquote>
For more information please review: <br>
[104282/KB627426] - Concurrent Processing - Purge Concurrent Request and/or Manager Data Program (FNDCPPUR)<br>
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite
',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '18'
      );
   l_info.delete;
debug('end add_signature: CP1_CONC_REQQ1');



debug('begin add_signature: CP1_CONC_REQQ2');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##COUNT'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '12902',
      p_sig_id                 => 'CP1_CONC_REQQ2',
      p_sig_sql                => 'select to_char(actual_completion_date,''YYYY'') "YEAR COMPLETED", to_char(actual_completion_date,''YYYY-MM'') "MONTH COMPLETED",
to_char(count(request_id),''999,999,999,999'') "COUNT" 
from fnd_concurrent_requests where phase_code=''C''
group by to_char(actual_completion_date,''YYYY''), to_char(actual_completion_date,''YYYY-MM'')
order by to_char(actual_completion_date,''YYYY'') desc',
      p_title                  => 'Your overall Concurrent Processing HealthCheck Status is in need of Review!',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The FND_CONCURRENT_REQUESTS Table has '||mask_text(gk_reqid_cnt, nvl( upper(''), 'NO_MASK') )||' rows of completed runtime data which is above the minimum acceptable threshold of '||mask_text(g_min_vol, nvl( upper(''), 'NO_MASK') )||' rows, but below the maximum acceptable thresholds of '||mask_text(g_max_vol, nvl( upper(''), 'NO_MASK') )||' rows that were entered to run this Analyzer.
',
      p_solution               => 'Clean up Concurrent Request Data by scheduling the <b>FNDCPPUR - <i>Purge Concurrent Request and/or Manager Data</i></b> on a regular basis.
<br><br>
Run these queries to gather more details about all old requests<br>

<blockquote>
<table>
<tr>
<td> Show Summary of counts By Year</td>
<td> <blockquote>
select to_char(actual_start_date,''YYYY'') "STARTED", to_char(actual_completion_date,''YYYY'') "ENDED", <br>
count(request_id) "COUNT" <br>
from fnd_concurrent_requests <br>
where actual_start_date < sysdate-365 --Show Requests started over 1 year ago<br>
group by to_char(actual_start_date,''YYYY''), to_char(actual_completion_date,''YYYY'')<br>
order by 1;
</blockquote></td>
</tr>
<tr>
<td> Show Summary of counts by Concurrent Program</td>
<td> <blockquote>
select fcp.USER_CONCURRENT_PROGRAM_NAME, to_char(r.actual_start_date,''YYYY'') "STARTED",<br> to_char(r.actual_completion_date,''YYYY'') "ENDED", count(r.request_id) "COUNT" <br>
from fnd_concurrent_requests r, fnd_concurrent_programs_tl fcp<br>
where r.concurrent_program_id = fcp.concurrent_program_id<br>
and r.actual_start_date < sysdate-365 --Show Requests started over 1 year ago<br>
group by fcp.USER_CONCURRENT_PROGRAM_NAME, to_char(r.actual_start_date,''YYYY''),
to_char(r.actual_completion_date,''YYYY'')<br>
order by 2;
</blockquote></td>
</tr>
</table>
</blockquote>
For more information please review: <br>
[104282/KB627426] - Concurrent Processing - Purge Concurrent Request and/or Manager Data Program (FNDCPPUR).<br>
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite.',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '15'
      );
   l_info.delete;
debug('end add_signature: CP1_CONC_REQQ2');



debug('begin add_signature: CP1_CONC_REQQ3');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##COUNT'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '12903',
      p_sig_id                 => 'CP1_CONC_REQQ3',
      p_sig_sql                => 'select to_char(actual_completion_date,''YYYY'') "YEAR COMPLETED", to_char(actual_completion_date,''YYYY-MM'') "MONTH COMPLETED",
to_char(count(request_id),''999,999,999,999'') "COUNT" 
from fnd_concurrent_requests where phase_code=''C''
group by to_char(actual_completion_date,''YYYY''), to_char(actual_completion_date,''YYYY-MM'')
order by to_char(actual_completion_date,''YYYY'') desc',
      p_title                  => 'Your overall Concurrent Processing HealthCheck Status is Healthy!',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The FND_CONCURRENT_REQUESTS Table has '||mask_text(gk_reqid_cnt, nvl( upper(''), 'NO_MASK') )||' rows of completed runtime data which is within acceptable thresholds that were entered to run this Analyzer.',
      p_solution               => 'For more information please review:<br>
[1057802/KB263169] - Concurrent Processing - Best Practices for Performance for Concurrent Managers in E-Business Suite.',
      p_success_msg            => 'The FND_CONCURRENT_REQUESTS Table has '||mask_text(gk_reqid_cnt, nvl( upper(''), 'NO_MASK') )||' rows of completed runtime data which is within acceptable thresholds that were entered to run this Analyzer.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '16'
      );
   l_info.delete;
debug('end add_signature: CP1_CONC_REQQ3');



debug('begin add_signature: EBS_ATG_CP1_NODE_INFO_122');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '23945',
      p_sig_id                 => 'EBS_ATG_CP1_NODE_INFO_122',
      p_sig_sql                => 'SELECT substr(fn.node_name, 1, 20) "NODE_NAME",
aat.appl_top_id, EXTRACTVALUE(XMLType(TEXT),''//shared_file_system'') "IS_SHARED", flkup.meaning "PLATFORM",
fn.node_mode, fn.server_address, substr(fn.host, 1, 15) "HOST",
substr(fn.domain, 1, 20) "DOMAIN", substr(fn.support_cp, 1, 3) "CP",
substr(fn.support_web, 1, 3) "WEB", substr(fn.support_admin, 1, 3) "ADMIN",
substr(fn.support_forms, 1, 3) "FORMS", substr(fn.SUPPORT_DB, 1, 3) "DB",
substr(fn.VIRTUAL_IP, 1, 30) "VIRTUAL_IP"
from fnd_nodes fn, fnd_lookups flkup, Ad_Appl_Tops aat, FND_OAM_CONTEXT_FILES focf
where flkup.lookup_type=''PLATFORM''
and EXTRACTVALUE(XMLType(focf.TEXT),''//file_edition_type'') = ''run''
and focf.NAME not in (''TEMPLATE'',''METADATA'',''config.txt'') and focf.CTX_TYPE=''A''
and (focf.status is null or upper(focf.status) in (''S'',''F''))
and focf.node_name=fn.host
and fn.platform_code=flkup.lookup_code
and fn.node_name != ''AUTHENTICATION''
and fn.host = aat.name (+)',
      p_title                  => 'Instance Node Details',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is a problem identifying the EBS Instance Information',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_ATG_CP1_NODE_INFO_122');



debug('begin add_signature: CP1_NODE_INFO');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1289',
      p_sig_id                 => 'CP1_NODE_INFO',
      p_sig_sql                => 'SELECT substr(fn.node_name, 1, 20) "NODE_NAME",
aat.appl_top_id, flkup.meaning "PLATFORM",
fn.node_mode, fn.server_address, substr(fn.host, 1, 15) "HOST",
substr(fn.domain, 1, 20) "DOMAIN", substr(fn.support_cp, 1, 3) "CP",
substr(fn.support_web, 1, 3) "WEB", substr(fn.support_admin, 1, 3) "ADMIN",
substr(fn.support_forms, 1, 3) "FORMS", substr(fn.SUPPORT_DB, 1, 3) "DB",
substr(fn.VIRTUAL_IP, 1, 30) "VIRTUAL_IP"
from fnd_nodes fn, fnd_lookups flkup, Ad_Appl_Tops aat
where flkup.lookup_type=''PLATFORM''
and fn.platform_code=flkup.lookup_code
and fn.node_name != ''AUTHENTICATION''
and fn.host = aat.name (+)',
      p_title                  => 'Instance Node Details',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is a problem identifying the EBS Instance Information',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '14'
      );
   l_info.delete;
debug('end add_signature: CP1_NODE_INFO');



debug('begin add_signature: CP1_INVALIDS_ALL_LOW');
   l_info('##COMPLEX_TYPE##'):= 'W';
   l_info('##STYLE##COUNT'):= 'right,,,';
l_info('##STYLE##COUNT'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '3615',
      p_sig_id                 => 'CP1_INVALIDS_ALL_LOW',
      p_sig_sql                => 'select d.owner, d.object_type, substr(d.object_name,0,3)||''%...'' "OBJECT_NAME", trunc(d.LAST_DDL_TIME) "LAST DDL DATE", to_char(count(d.status),''999,999,999,999'') "COUNT"
from dba_objects d
where d.status = ''INVALID''
and d.owner in (''APPS'',''APPLSYS'',''APPLSYSPUB'',''CTXSYS'',''PUBLIC'',''SYS'',''SYSTEM'')
group by d.owner, d.object_type, substr(d.object_name,0,3),  trunc(d.LAST_DDL_TIME)
order by 4 desc',
      p_title                  => 'There are '||g_apps_invalid_cnt||' Invalid Objects Found',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are '||g_apps_invalid_cnt||' Invalid Objects found in your instance.',
      p_solution               => 'The above list summarizes quickly what products the INVALID objects belong to.<br><br>

It is recommended that you re-compile these in order to make them VALID again.<br>
We next check if any belong to FND, as this control Concurrent Processing in particular.<br>
Consider running ADADMIN and compiling the entire APPS Schema, or just for the Product in question.<br><br>
In order to avoid dependencies issues and errors, EBS customers should always use the adamin tool instead of manually compiling EBS / Apps database objects.<br>
Please review the following :<br>
[1325394/KB401905#aref_section21] - Troubleshooting Guide - Invalid Objects in the E-Business Suite Environment 11i and 12.',
      p_success_msg            => 'There are no invalid objects found on your instance.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','Y')
      );
   l_info.delete;
   l_info.delete;
debug('end add_signature: CP1_INVALIDS_ALL_LOW');



debug('begin add_signature: CP1_INVALIDS_FND_LOW');
   l_info('##COMPLEX_TYPE##'):= 'W';
add_signature(
      p_sig_repo_id            => '3616',
      p_sig_id                 => 'CP1_INVALIDS_FND_LOW',
      p_sig_sql                => 'select d.owner, d.object_name, d.object_type, d.status, trunc(d.LAST_DDL_TIME) "LAST DDL DATE"
from dba_objects d
where d.status = ''INVALID''
and d.owner in (''APPS'',''APPLSYS'')
and d.object_name like ''FND%''
and d.object_name not in (''FND_DOCS_LONG_TEXT_SN'', ''FND_DOCUMENTS_LT_PO_UAS'', ''FND_DOCUMENTS_LT_PO_UBR'', ''FND_FLEX_DIAGNOSE_KFF'', ''FND_FLEX_DIAGNOSE_VST'')',
      p_title                  => 'Check for Invalid FND Objects',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are '||g_fnd_invalid_cnt||' Invalid FND Objects found in your instance.',
      p_solution               => 'The above list summarizes quickly what FND Objects are INVALID.<br><br>

It is recommended that you re-compile these in order to make them VALID again.<br>
FND Objects are very important, as this control Concurrent Processing in particular.<br><br>

<br>
For more information, please review the following :<br>
[1325394/KB401905#aref_section21] - Troubleshooting Guide - Invalid Objects in the E-Business Suite Environment 11i and 12 <br>
[300056/KB150827] - Debug and Validate Invalid Objects',
      p_success_msg            => 'There are no Invalid FND Objects found on your instance.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','Y')
      );
   l_info.delete;
   l_info.delete;
debug('end add_signature: CP1_INVALIDS_FND_LOW');



debug('begin add_signature: CP1_INVALIDS_ALL_HIGH');
   l_info('##COMPLEX_TYPE##'):= 'W';
   l_info('##STYLE##COUNT'):= 'right,,,';
l_info('##STYLE##COUNT'):= 'right,,,';
  add_signature(
      p_sig_repo_id            => '3617',
      p_sig_id                 => 'CP1_INVALIDS_ALL_HIGH',
      p_sig_sql                => 'select d.owner, d.object_type, substr(d.object_name,0,3)||''%...'' "OBJECT_NAME",  trunc(d.LAST_DDL_TIME) "LAST DDL DATE", to_char(count(d.status),''999,999,999,999'') "COUNT"
from dba_objects d
where d.status = ''INVALID''
and d.owner in (''APPS'',''APPLSYS'',''APPLSYSPUB'',''CTXSYS'',''PUBLIC'',''SYS'',''SYSTEM'')
group by d.owner, d.object_type, substr(d.object_name,0,3), trunc(d.LAST_DDL_TIME)
order by 4 desc',
      p_title                  => 'Check for Invalid Objects All',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are '||g_apps_invalid_cnt||' Invalid Objects found in your E-Business Suite instance.',
      p_solution               => 'The above list summarizes quickly what products the INVALID objects belong to.<br><br>

It is recommended that you re-compile these in order to make them VALID again.<br>
We next check if any belong to FND, as they control Concurrent Processing in particular.<br>
Consider running ADADMIN and compiling the entire APPS Schema.<br><br>
In order to avoid dependencies issues and errors, EBS customers should always use the adamin tool instead of manually compiling EBS / Apps database objects.<br><br>
Please review the following :<br>
[1325394/KB401905#aref_section21] - Troubleshooting Guide - Invalid Objects in the E-Business Suite Environment 11i and 12.',
      p_success_msg            => 'There are no invalid objects found on your instance.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','Y')
      );
   l_info.delete;
   l_info.delete;
debug('end add_signature: CP1_INVALIDS_ALL_HIGH');



debug('begin add_signature: CP1_INVALIDS_FND_HIGH');
   l_info('##COMPLEX_TYPE##'):= 'W';
add_signature(
      p_sig_repo_id            => '3618',
      p_sig_id                 => 'CP1_INVALIDS_FND_HIGH',
      p_sig_sql                => 'select d.owner, d.object_name, d.object_type, d.status, trunc(d.LAST_DDL_TIME) "LAST DDL DATE"
from dba_objects d
where d.status = ''INVALID''
and d.owner in (''APPS'',''APPLSYS'')
and d.object_name like ''FND%''
and d.object_name not in (''FND_DOCS_LONG_TEXT_SN'', ''FND_DOCUMENTS_LT_PO_UAS'', ''FND_DOCUMENTS_LT_PO_UBR'', ''FND_FLEX_DIAGNOSE_KFF'', ''FND_FLEX_DIAGNOSE_VST'')',
      p_title                  => 'Check for Invalid FND Objects',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are '||g_fnd_invalid_cnt||' Invalid FND Objects found in your instance.',
      p_solution               => 'The above list summarizes quickly what FND Objects are INVALID.<br><br>

It is recommended that you re-compile these in order to make them VALID again.<br>
FND Objects are very important, as this control Concurrent Processing in particular.<br>
In order to avoid dependencies issues and errors, EBS customers should always use the adamin tool instead of manually compiling EBS / Apps database objects.<br><br>

For more information, please review the following :<br>
[1325394/KB401905#aref_section21] - Troubleshooting Guide - Invalid Objects in the E-Business Suite Environment 11i and 12 <br>
[300056/KB150827] - Debug and Validate Invalid Objects',
      p_success_msg            => 'There are no Invalid FND Objects found on your instance.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','Y')
      );
   l_info.delete;
   l_info.delete;
debug('end add_signature: CP1_INVALIDS_FND_HIGH');



debug('begin add_signature: AD_TXK_PATCHES_C10');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11369',
      p_sig_id                 => 'AD_TXK_PATCHES_C10',
      p_sig_sql                => 'select "PATCH", "R12.2 AD/TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
25820806, ''933'',
29273993, ''934'',
29591102, ''936'',
28280348, ''937'',
25828573, ''950'',
27294892, ''951'',
28805062, ''952'',
27147539, ''953'',
29372340, ''954'') as "SEQ",
Decode(Bugs.Bug_Number,
25820806, ''R12.AD.C.delta.10'',
29273993, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.10</b> - CONSOLIDATED PATCH II ON TOP OF AD DELTA 10'',
29591102, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.10</b> - Enhance logging to adgrants.sql'',
28280348, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.10</b> - Add a success message when a previous DDL failed from ad_zd_ddl_handler table'',
25828573, ''R12.TXK.C.delta.10'',
27294892, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.10</b> - CONSOLIDATED PATCH ON TOP OF TXK DELTA 10'',
28805062, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.10</b> - Clone fix for OAEA_SERVER and TLS configuration settings'',
27147539, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.10</b> - PROVISIONEBSONOCI.PL FAILED AS APPS HAS NO PRIV ON SYS.PROPS$'',
29372340, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.10</b> - ADGRANTS.SQL FAILED WITH WARNING AND SHIFT FLOW TERMINATES'') as "R12.2 AD/TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''11i'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From 
(select ''25820806'' as bug_number From Dual
UNION ALL 
select ''29273993'' as bug_number From Dual
UNION ALL 
select ''29591102'' as bug_number From Dual
UNION ALL 
select ''28280348'' as bug_number From Dual
UNION ALL 
select ''25828573'' as bug_number From Dual
UNION ALL 
select ''27294892'' as bug_number From Dual
UNION ALL 
select ''28805062'' as bug_number From Dual
UNION ALL 
select ''27147539'' as bug_number From Dual
UNION ALL 
select ''29372340'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> 
Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>
If not possible to be at the latest AD/TXK codelevels, then at a minimum please apply '||mask_text(g_2nd_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||' plus all critical post patches available for this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br> 
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>

Oracle recommends being on the latest AD/TXK codelevels  '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '36'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C10');



debug('begin add_signature: AD_TXK_PATCHES_C11');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '13297',
      p_sig_id                 => 'AD_TXK_PATCHES_C11',
      p_sig_sql                => 'select "PATCH", "R12.2 AD TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
26834480, ''933'',
28280348, ''935'',
30213183, ''938'',
30258630, ''940'',
30355167, ''942'',
28840822, ''950'',
29781255, ''950'',
29965377, ''951'',
28371446, ''952'') as "SEQ",
Decode(Bugs.Bug_Number,
26834480, ''R12.AD.C.delta.11'',
28280348, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.11</b> - Add a success message when a previous DDL failed from ad_zd_ddl_handler table'',
30213183, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.11</b> - Log Message added for drop old editions'',
30258630, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.11</b> - ADZDNODESTAT.SQL ORA-20000: ORU-10027: BUFFER OVERFLOW, LIMIT OF 2000 BYTES'',
30355167, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.11</b> - SYNONYMS RE-CREATED WRONGLY AFTER RUNNING RE-CREATE GRANTS AND SYNONYMS FOR APPS'',
28840822, ''R12.TXK.C.delta.11'',
29781255, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.11</b> - PROVIDE PROPER VALIDATION OF S_ADMIN_UI_ACCESS_NODES ENTRIES (CIDR)'',
29965377, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.11</b> - Critical Patch on top of R12.TXK.C.Delta.11 (Consolidation-1)'',
28371446, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.11</b>- CDB-PDB19C: TRACKING BUG FOR EBS 12.2 AUTOCONFIG CHANGES FOR DATABASE 19C)'') as "R12.2 AD TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From
(select ''26834480'' as bug_number From Dual
UNION ALL
select ''28280348'' as bug_number From Dual
UNION ALL
select ''30213183'' as bug_number From Dual
UNION ALL
select ''30258630'' as bug_number From Dual
UNION ALL
select ''30355167'' as bug_number From Dual
UNION ALL
select ''28840822'' as bug_number From Dual
UNION ALL
select ''29781255'' as bug_number From Dual
UNION ALL
select ''29965377'' as bug_number From Dual
UNION ALL
select ''28371446'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> 
Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>
If not possible to be at the latest AD/TXK codelevels, then at a minimum please apply '||mask_text(g_2nd_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||' plus all critical post patches available for this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '29'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C11');



debug('begin add_signature: AD_TXK_PATCHES_C12');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '15226',
      p_sig_id                 => 'AD_TXK_PATCHES_C12',
      p_sig_sql                => 'select "PATCH", "R12.2 AD TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
30628681, ''933'',
30735865, ''950'',
31904550, ''951'') as "SEQ",
Decode(Bugs.Bug_Number,
30628681, ''R12.AD.C.delta.12'',
30735865, ''R12.TXK.C.delta.12'',
31904550, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.12</b> - Fix large symbolic links in APPL_TOP or COMMON_TOP'') as "R12.2 AD TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From
(select ''30628681'' as bug_number From Dual
UNION ALL
select ''30735865'' as bug_number From Dual
UNION ALL
select ''31904550'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> 
Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>
If not possible to be at the latest AD/TXK codelevels, then at a minimum please apply '||mask_text(g_2nd_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||' plus all critical post patches available for this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '17'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C12');



debug('begin add_signature: AD_TXK_PATCHES_C13');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '21093',
      p_sig_id                 => 'AD_TXK_PATCHES_C13',
      p_sig_sql                => 'select "PATCH", "R12.2 AD TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,   
32394134, ''933'',
33441060, ''935'',
31356927, ''937'',
33862025, ''939'',
33969707, ''944'',
35280950, ''948'',
32392507, ''950'',
33550674, ''955'',
34207577, ''958'',
34743319, ''959'',
33535778, ''960'') as "SEQ",
Decode(Bugs.Bug_Number,
32394134, ''R12.AD.C.delta.13'',
33441060, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.13</b> - ADDED RESULT SET CACHE TO ONLINE PATCHING FOR GET_EDITION'',
31356927, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.13</b> - New script to drop covered objects'',
33862025, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.13</b> - Fix for Bug 33862025'',
33969707, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.13</b> - AD_ZD_SEED.PREPARE EXCEPTION HANDLING NEEDS TO BE REVISITED '',
35280950, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.13</b> - CHANGE TAG FOR OBSOLETE COLUMN TO AD_OBSOLETE IN TABLE MANAGER (ADZDTMB.PLS) '',
32392507, ''R12.TXK.C.delta.13'',
33550674, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.13</b> - AUTOCONFIG AND RAC FIXES FOR TXK DELTA 13'',
34207577, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.13</b> - ADPRECLONE.PL ON DBTIER AND IT FAILED WITH ERROR '',
34743319, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.13</b> - TXK DELTA 13 PATCH INVALIDATING OBJECTS IN RUN FILE SYSTEM '',
33535778, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.13</b> - TXKPOSTPDBCREATIONTASKS.PL FAILS WITH LATEST ADGRANTS.SQL DUE TO AD_ZD_SYS''
) as "R12.2 AD TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From
(select ''32394134'' as bug_number From Dual
UNION ALL
select ''33441060'' as bug_number From Dual
UNION ALL
select ''31356927'' as bug_number From Dual
UNION ALL
select ''33862025'' as bug_number from dual
UNION ALL
select ''34743319'' as bug_number from dual
UNION ALL
select ''33969707'' as bug_number from dual
UNION ALL
select ''35280950'' as bug_number from dual
UNION ALL
select ''32392507'' as bug_number From Dual
UNION ALL
select ''33550674'' as bug_number From Dual
UNION ALL
select ''34207577'' as bug_number From Dual
UNION ALL
select ''33535778'' as bug_number From Dual) Bugs)
order by SEQ  ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br> It is also recommended to apply all missing critical post patches available for your current Techstack (AD/TXK) codelevels on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '15'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C13');



debug('begin add_signature: AD_TXK_PATCHES_C5');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11363',
      p_sig_id                 => 'AD_TXK_PATCHES_C5',
      p_sig_sql                => 'select "PATCH", "R12.2 AD/TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
19197270, ''1'',
20677045, ''111'',
20864702, ''112'',
21132723, ''113'',
19330775, ''6'',
21662853, ''61'') as "SEQ",
Decode(Bugs.Bug_Number,
19197270, ''R12.AD.C.Delta.6 (Superseded by 20745242)'',
20677045, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.6</b> - TST1226 CUTOVER FAILED AFTER ADD NODE'',
20864702, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.6</b> - AFTER ADD OACORE_SERVER, FS_CLONE HANG WHEN SETTING PORT OACORE_SERVER2 IN PATCH'',
21132723, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.6</b> - 1-OFF Fixes on top of R12.AD.C.DELTA.6'',
19330775, ''R12.TXK.C.Delta.6 (Superseded by 20784380)'',
21662853, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.6</b> - MSIMODE SWITCH IS NOT BEING HONORED. MANAGED SERVER(S) STARTUP FAILS ON WINDOWS'') as "R12.2 AD/TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''11i'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From 
(select ''19197270'' as bug_number From Dual
UNION ALL
select ''20677045'' as bug_number From Dual
UNION ALL 
select ''20864702'' as bug_number From Dual
UNION ALL 
select ''21132723'' as bug_number From Dual
UNION ALL 
select ''19330775'' as bug_number From Dual
UNION ALL 
select ''21662853'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> 
Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>
If not possible to be at the latest AD/TXK codelevels, then at a minimum please apply '||mask_text(g_2nd_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||' plus all critical post patches available for this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'
',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>

Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '34'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C5');



debug('begin add_signature: AD_TXK_PATCHES_C6');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11364',
      p_sig_id                 => 'AD_TXK_PATCHES_C6',
      p_sig_sql                => 'select "PATCH", "R12.2 AD/TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
19197270, ''1'',
20677045, ''111'',
20864702, ''112'',
21132723, ''113'',
19330775, ''6'',
21662853, ''61'') as "SEQ",
Decode(Bugs.Bug_Number,
19197270, ''R12.AD.C.Delta.6 (Superseded by 20745242)'',
20677045, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.6</b> - TST1226 CUTOVER FAILED AFTER ADD NODE'',
20864702, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.6</b> - AFTER ADD OACORE_SERVER, FS_CLONE HANG WHEN SETTING PORT OACORE_SERVER2 IN PATCH'',
21132723, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.6</b> - 1-OFF Fixes on top of R12.AD.C.DELTA.6'',
19330775, ''R12.TXK.C.Delta.6 (Superseded by 20784380)'',
21662853, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.6</b> - MSIMODE SWITCH IS NOT BEING HONORED. MANAGED SERVER(S) STARTUP FAILS ON WINDOWS'') as "R12.2 AD/TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''11i'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From 
(select ''19197270'' as bug_number From Dual
UNION ALL
select ''20677045'' as bug_number From Dual
UNION ALL 
select ''20864702'' as bug_number From Dual
UNION ALL 
select ''21132723'' as bug_number From Dual
UNION ALL 
select ''19330775'' as bug_number From Dual
UNION ALL 
select ''21662853'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> 
Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>
If not possible to be at the latest AD/TXK codelevels, then at a minimum please apply '||mask_text(g_2nd_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||' plus all critical post patches available for this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>

Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '30'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C6');



debug('begin add_signature: AD_TXK_PATCHES_C7');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11365',
      p_sig_id                 => 'AD_TXK_PATCHES_C7',
      p_sig_sql                => 'select "PATCH", "R12.2 AD/TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
20745242, ''2'',
22123818, ''21'',
22700342, ''22'',
20784380, ''7'',
22363475, ''71'',
22495069, ''72'') as "SEQ",
Decode(Bugs.Bug_Number,
20745242, ''R12.AD.C.delta.7 (Superseded by 21841299)'',
22123818, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.7</b> - BUNDLE FIXES II FOR R12.AD.C.DELTA.7 (20745242)'',
22700342, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.7</b> - AD fixes added on top of AD DELTA 7 BUNDLE II (22123818)'',
20784380, ''R12.TXK.C.delta.7 (Superseded by 21830810)'',
22363475, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.7</b> - BUNDLE FIXES II FOR R12.TXK.C.DELTA.7 (20784380)'',
22495069, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.7</b> - TXK CONSOLIDATED PATCH FOR STARTCD 12.2.0.51'') as "R12.2 AD/TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''11i'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From 
(select ''20745242'' as bug_number From Dual
UNION ALL 
select ''22123818'' as bug_number From Dual
UNION ALL 
select ''22700342'' as bug_number From Dual
UNION ALL 
select ''20784380'' as bug_number From Dual
UNION ALL 
select ''22363475'' as bug_number From Dual
UNION ALL 
select ''22495069'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> 
Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>
If not possible to be at the latest AD/TXK codelevels, then at a minimum please apply '||mask_text(g_2nd_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||' plus all critical post patches available for this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>

Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '26'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C7');



debug('begin add_signature: AD_TXK_PATCHES_C8');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11367',
      p_sig_id                 => 'AD_TXK_PATCHES_C8',
      p_sig_sql                => 'select "PATCH", "R12.2 AD/TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
21841299, ''3'',
24578455, ''31'',
24494551, ''32'',
25025325, ''33'',
21830810, ''8'',
18525466, ''81'',
23569114, ''82'',
23705992, ''83'',
22363475, ''84'') as "SEQ",
Decode(Bugs.Bug_Number,
21841299, ''R12.AD.C.delta.8 (Superseded by 25178222)'',
24578455, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.8</b> - REVERT CHANGES MADE TO VALIDATE MANAGED SERVER PORTS OF ALL NODES'',
24494551, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.8</b> - 1OFF: ESCAPE SINGLE QUOTE IN OBJECT-NAMES MUST BE HANDLED PROPERLY'',
25025325, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.8</b> - DATA IN FND_FLEX_VALUES_TL TABLE MISSING AFTER APPLYING 12.2.6'',
21830810, ''R12.TXK.C.delta.8 (Superseded by 25180736)'',
18525466, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.8</b> - REVERT CHANGES MADE TO VALIDATE MANAGED SERVER PORTS OF ALL NODES'',
23569114, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.8</b> - INVALID APPS DATABASE USER CREDENTIALS - TXKGENADOPWRAPPER_PL - 12.2.4'',
23705992, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.8</b> - TNSNAMES.ORA GENERATED WITH SCAN NAME INSTEAD OF SCAN IPS FOR CUSTOM RAC DB CLONE'',
22363475, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.8</b> - BUNDLE FIXES II FOR R12.TXK.C.DELTA.7 (20784380)'') as "R12.2 AD/TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''11i'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From 
(select ''21841299'' as bug_number From Dual
UNION ALL
select ''24578455'' as bug_number From Dual
UNION ALL 
select ''24494551'' as bug_number From Dual
UNION ALL 
select ''25025325'' as bug_number From Dual
UNION ALL 
select ''21830810'' as bug_number From Dual
UNION ALL 
select ''18525466'' as bug_number From Dual
UNION ALL 
select ''23569114'' as bug_number From Dual
UNION ALL 
select ''23705992'' as bug_number From Dual
UNION ALL 
select ''22363475'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> 
Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>
If not possible to be at the latest AD/TXK codelevels, then at a minimum please apply '||mask_text(g_2nd_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||' plus all critical post patches available for this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>

Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '27'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C8');



debug('begin add_signature: AD_TXK_PATCHES_C9');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11368',
      p_sig_id                 => 'AD_TXK_PATCHES_C9',
      p_sig_sql                => 'select "PATCH", "R12.2 AD/TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
25178222, ''4'',
25250923, ''41'',
24481010, ''42'',
25615812, ''43'',
24591000, ''44'',
26482811, ''45'',
27615897, ''46'',
27797548, ''47'',
25180736, ''9'',
25874936, ''911'',
25983583, ''912'',
25994411, ''913'',
26182372, ''914'',
26400116, ''915'',
26720231, ''916'') as "SEQ",
Decode(Bugs.Bug_Number,
25178222, ''R12.AD.C.delta.9 (Superseded by 25820806)'',
25250923, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.9</b> - FIX FOR BUG 6708332'',
24481010, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.9</b> - Fix for Bug 24481010'',
25615812, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.9</b> - Fix for Bug 25615812'',
24591000, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.9</b> - ADOP -VALIDATE IS CONSUMING HUGE MEMORY AND EXITING WITH DB IN READONLY MODE'',
26482811, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.9</b> - EBS_PATCH SERVICE NOT GETTING CLEANED UP IN RAC SETUP POST AD/TXK DELTA9'',
27615897, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.9</b> - ADOP ABORT EXECUTING DROP TABLES FROM PREVIOUS PATCHING CYCLE'',
27797548, ''&#x09;&#x09;<b>Critcal Post R12.AD.C.Delta.9</b> - Indexes are not getting created for temporary tables.'',
25180736, ''R12.TXK.C.delta.9 (Superseded by 25828573)'',
25874936, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.9</b> - Fix for Bug 25874936'',
25983583, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.9</b> - ADBLDXML.PL ERRORED WITH NULLPONINTEREXCEPTION'',
25994411, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.9</b> - ADOP VALIDATION EXCEPTION: USE OF UNINITIALIZED VALUE $DATA[0]'',
26182372, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.9</b> - AUTOCONFIG WHEN RUN ON APPS TIER, DOES NOT CORRECTLY UPDATE TNSNAMES.ORA FILE'',
26400116, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.9</b> - TST12210-AUTOCONFIG FAILED WHILE EXECUTING TXKSETADOPPATCHSRVNAME.PL ON APPSTIER'',
26720231, ''&#x09;&#x09;<b>Critcal Post R12.TXK.C.Delta.9</b> - NODE MANAGER WILL NOT START IN WLS CONSOLE DUE TO INCORRECT CONFIG.XML PORT INFO'') as "R12.2 AD/TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''11i'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From 
(select ''25178222'' as bug_number From Dual
UNION ALL 
select ''25250923'' as bug_number From Dual
UNION ALL 
select ''24481010'' as bug_number From Dual
UNION ALL 
select ''25615812'' as bug_number From Dual
UNION ALL 
select ''24591000'' as bug_number From Dual
UNION ALL 
select ''26482811'' as bug_number From Dual
UNION ALL 
select ''27615897'' as bug_number From Dual
UNION ALL 
select ''27797548'' as bug_number From Dual
UNION ALL
select ''25180736'' as bug_number From Dual
UNION ALL 
select ''25874936'' as bug_number From Dual
UNION ALL 
select ''25983583'' as bug_number From Dual
UNION ALL 
select ''25994411'' as bug_number From Dual
UNION ALL 
select ''26182372'' as bug_number From Dual
UNION ALL 
select ''26400116'' as bug_number From Dual
UNION ALL 
select ''26720231'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> 
Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>
If not possible to be at the latest AD/TXK codelevels, then at a minimum please apply '||mask_text(g_2nd_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||' plus all critical post patches available for this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>

Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '26'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C9');



debug('begin add_signature: AD_TXK_PATCHES_C14');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '26732',
      p_sig_id                 => 'AD_TXK_PATCHES_C14',
      p_sig_sql                => 'select "PATCH", "R12.2 AD TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
33600809, ''933'',
34668508, ''938'',
34669333, ''939'',
34681299, ''940'',
35280947, ''950'',
33602997, ''951'',
34708635, ''953'',
34654260, ''955'') as "SEQ",
Decode(Bugs.Bug_Number,
33600809, ''R12.AD.C.delta.14'',
34668508, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.14</b> - QRE12212.7:AD:FINALIZE FAILURE: HIGH TEMPORARY TABLESPACE USAGE ISSUE WHILE RUNNING ADOP FINALIZE'',
34669333, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.14</b> - BUNDLE PATCH ON TOP OF R12.AD.C.DELTA.14'',
34681299, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.14</b> - ADOP PHASE=APPLY PATCHES=31817501 FAILS TO APPLY - ADPATCH MAY BE TERMINATING'',
35280947, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.14</b> - CHANGE TAG FOR OBSOLETE COLUMN TO AD_OBSOLETE IN TABLE MANAGER (ADZDTMB.PLS)'',
33602997, ''R12.TXK.C.delta.14'',
34708635, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.14</b> - BNE and FRM PRODUCTS HAVING ISSUES WITH UPTAKE TXK DELTA 14 (HAVING LATEST POI LIBRARIES 3.17) IF EBS RELEASE 12.2.11 OR LOWER'',
34654260, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.14</b> - BUNDLE PATCH ON TOP OF R12.TXK.C.DELTA.14''
) as "R12.2 AD TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From
(select ''33600809'' as bug_number From Dual
UNION ALL
select ''34668508'' as bug_number From Dual
UNION ALL
select ''34669333'' as bug_number From Dual
UNION ALL
select ''34681299'' as bug_number From Dual
UNION ALL
select ''35280947'' as bug_number from dual
UNION ALL
select ''33602997'' as bug_number From Dual
UNION ALL
select ''34708635'' as bug_number From Dual
UNION ALL
select ''34654260'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br> It is also recommended to apply all missing critical post patches available for your current Techstack (AD/TXK) codelevels on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: AD_TXK_PATCHES_C14');



debug('begin add_signature: EBS_ATG_AT_AD_TXK_PATCHES_C15');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '28651',
      p_sig_id                 => 'EBS_ATG_AT_AD_TXK_PATCHES_C15',
      p_sig_sql                => 'select "PATCH", "R12.2 AD TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
34695811, ''933'',
36303698, ''934'',
36903863, ''935'',
37000616, ''936'',
34785677, ''937'',
36270240, ''938'') as "SEQ",
Decode(Bugs.Bug_Number,
34695811, ''R12.AD.C.delta.15'',
36303698, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.15</b> - ERROR WHILE USING AD_ZD.GRANT_PRIVS AFTER APPLYING AD/TXK 15 PATCH'',
36903863, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.15</b> - Bug 36903863 - CLEANUP PROCESS RUNNING LONG NOT GETTING COMPLETED'',
37000616, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.15</b> - ADZDDBCC SECTION-23 REPORTS VIOLATIONS FOR XMLTYPE, ORDIMAGE USING PUBLIC SYN'',
34785677, ''R12.TXK.C.delta.15'',
36270240, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.15</b> - TCH19C: AUTCONFIG FAILING AFTER UPDATING CONTEXT FILE USING TXKAPPSDBCONFIG.PL''
) as "R12.2 AD TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From
(select ''34695811'' as bug_number From Dual
UNION ALL
select ''36303698'' as bug_number From Dual
UNION ALL
select ''36903863'' as bug_number From Dual
UNION ALL
select ''37000616'' as bug_number From Dual
UNION ALL
select ''34785677'' as bug_number From Dual
UNION ALL
select ''36270240'' as bug_number From Dual) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br> It is also recommended to apply all missing critical post patches available for your current Techstack (AD/TXK) codelevels on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For more information, please review <br>
[11177530] - Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br>
[11177533] - Applying A Non-Current Version of the AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_AT_AD_TXK_PATCHES_C15');



debug('begin add_signature: EBS_ATG_AT_AD_TXK_PATCHES_C16');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '29571',
      p_sig_id                 => 'EBS_ATG_AT_AD_TXK_PATCHES_C16',
      p_sig_sql                => 'select "PATCH", "R12.2 AD TXK PATCHSETS APPLIED", "APPLIED" from (
Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
36119925, ''933'',
36303698, ''934'',
36989014, ''935'',
38128194, ''936'', 
37988551, ''937'',
37964268, ''938'',
36117775, ''939'',
36641685, ''940'',
37500697, ''941'') as "SEQ",
Decode(Bugs.Bug_Number,
36119925, ''R12.AD.C.delta.16'',
36303698, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.16</b> - ERROR WHILE USING AD_ZD.GRANT_PRIVS AFTER APPLYING AD/TXK 15 PATCH'',
36989014, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.16</b> - GRANTING QUEUE PRIVILEGES TO APPS USER ON 23AI '',
38128194, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.16</b> - ONE-OFF REQUEST FOR DELTA.16 FOR BUG 37700549 - SEED TABLE JDR_ATTRIBUTES SYNC '',
37988551, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.16</b> - 1OFF:36607196:ADOP CLEANUP FULL FAILS ON PRIVATE AND PUBLIC SYNONYMS AND ORA-010 '',
37964268, ''&#x09;&#x09;<b>Critical Post R12.AD.C.Delta.16</b> - CONCURRENT REQUESTS COMPLETED CANCELLED AFTER ADOP DELTA16 PATCHING '',
36117775, ''R12.TXK.C.delta.16'',
36641685, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.16</b> - EBS LDAP REGISTRATION FOR OID AND OUD NEEDS TO ALLOW "SYSTEM:" FOR THE DATABASE WALLET DIRECTORY'',
37500697, ''&#x09;&#x09;<b>Critical Post R12.TXK.C.Delta.16</b> - EBS LDAP REGISTRATION FOR OID AND OUD NEEDS TO ALLOW "SYSTEM:" FOR THE DATABASE WALLET DIRECTORY''
) as "R12.2 AD TXK PATCHSETS APPLIED",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From
(select ''36119925'' as bug_number From Dual
UNION ALL
select ''36303698'' as bug_number From Dual
UNION ALL
select ''36989014'' as bug_number From Dual
UNION ALL
select ''36117775'' as bug_number From Dual
UNION ALL
select ''36641685'' as bug_number From Dual
UNION ALL
select ''37500697'' as bug_number From Dual
) Bugs)
order by SEQ',
      p_title                  => 'Recommended Technology Stack Patches',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are recommended Techstack Patches that are not applied to this instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'This instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' is currently at AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'.<br><br> Oracle recommends being on the latest AD/TXK codelevels '||mask_text(g_latest_AD_TXK_codelevels, nvl( upper(''), 'NO_MASK') )||'.<br> It is also recommended to apply all missing critical post patches available for your current Techstack (AD/TXK) codelevels on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br> 

For additional information, please review <br> 
[11177530] Applying the Latest AD and TXK Release Update Packs to Oracle E-Business Suite Release 12.2.<br> 
[2967000/KB666639] - Oracle E-Business Suite Applications DBA and Technology Stack Release Notes for R12.AD.C.Delta.16 and R12.TXK.C.Delta.16
'||mask_text(g_snap_days_msg, nvl( upper(''), 'NO_MASK') )||'',
      p_success_msg            => 'All the latest AD and TXK Release Update Packs and post patches for AD/TXK codelevels of '||mask_text(g_ad_codelevel, nvl( upper(''), 'NO_MASK') )||'/'||mask_text(g_txk_codelevel, nvl( upper(''), 'NO_MASK') )||'. are applied on '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_AT_AD_TXK_PATCHES_C16');



debug('begin add_signature: FND_PATCHES_RPC1');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11501',
      p_sig_id                 => 'FND_PATCHES_RPC1',
      p_sig_sql                => 'Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
17774755, ''17774755 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 1 [RPC1]'',
19030202, ''19030202 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 2 [RPC2]'',
20203366, ''20203366 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 3 [RPC3]'',
21236633, ''21236633 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 4 [RPC4]'',
22644544, ''22644544 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 5 [RPC5]'') as "EBS RPC PATCHES",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as "APPLIED"
From 
(select ''17774755'' as bug_number From Dual
UNION ALL 
select ''19030202'' as bug_number From Dual
UNION ALL
select ''20203366'' as bug_number From Dual
UNION ALL
select ''21236633'' as bug_number from Dual
UNION ALL
select ''22644544'' as bug_number From Dual) Bugs',
      p_title                  => 'EBS Recommended Patch Collection (RPC) Patches for R12.1',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are Recommended Patch Collection (RPC) patches not applied on this '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please review the list above and schedule to apply the latest EBS Recommended Patch Collection (RPC) patch at your earliest convenience.<br><br>

<p><a href="https://blogs.oracle.com/ebstech/identifying-recommended-patches-for-e-business-suite-environments" target="_blank"> Recommended Patches</a> for E-Business Suite Environments</p> <br><br>
	
Patch {17774755} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 1 [RPC1] has been Superseded.<br><br>
 
This patch was originally replaced by patch {19030202}. The most recent replacement for this patch is {22644544}. If you are downloading patch {17774755} because it is a prerequisite for another patch or patchset, you should verify whether or not {22644544} is suitable as a substitute prerequisite before downloading it.<br><br>

Replacement Options (Patches or Patchsets known to Include or Supersede this Patch)<br><br>
		
Follow [1920628/KB203601] to apply patch {19030202} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 2 [RPC2]
Follow [2152266/KB196540] to apply patch {22644544} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 5 [RPC5]',
      p_success_msg            => 'Nice work.  All Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection patches (RPCs) are applied as recommended.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '15'
      );
   l_info.delete;
debug('end add_signature: FND_PATCHES_RPC1');



debug('begin add_signature: FND_PATCHES_RPC2');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11511',
      p_sig_id                 => 'FND_PATCHES_RPC2',
      p_sig_sql                => 'Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
19030202, ''19030202 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 2 [RPC2]'',
20203366, ''20203366 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 3 [RPC3]'',
21236633, ''21236633 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 4 [RPC4]'',
22644544, ''22644544 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 5 [RPC5]'') as "EBS RPC PATCHES",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as "APPLIED"
From 
(select ''19030202'' as bug_number From Dual
UNION ALL
select ''20203366'' as bug_number From Dual
UNION ALL
select ''21236633'' as bug_number from Dual
UNION ALL
select ''22644544'' as bug_number From Dual) Bugs',
      p_title                  => 'EBS Recommended Patch Collection (RPC) Patches for R12.1',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are Recommended Patch Collection (RPC) patches not applied on this '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please review the list above and schedule to apply the latest EBS Recommended Patch Collection (RPC) patch at your earliest convenience.<br><br>

<p><a href="https://blogs.oracle.com/ebstech/identifying-recommended-patches-for-e-business-suite-environments" target="_blank"> Recommended Patches</a> for E-Business Suite Environments</p> <br><br>
	
Patch {19030202} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 2 [RPC2] has been Superseded.<br><br>
 
This patch was originally replaced by patch {20203366}. The most recent replacement for this patch is {22644544}. If you are downloading patch {19030202} because it is a prerequisite for another patch or patchset, you should verify whether or not {22644544} is suitable as a substitute prerequisite before downloading it.<br><br>

Replacement Options (Patches or Patchsets known to Include or Supersede this Patch)<br><br>
		
Follow [1986065/KB203591] to apply patch {20203366} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 3 [RPC3]
Follow [2152266/KB196540] to apply patch {22644544} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 5 [RPC5]',
      p_success_msg            => 'Nice work.  All Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection patches (RPCs) are applied as recommended.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '13'
      );
   l_info.delete;
debug('end add_signature: FND_PATCHES_RPC2');



debug('begin add_signature: FND_PATCHES_RPC3');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11512',
      p_sig_id                 => 'FND_PATCHES_RPC3',
      p_sig_sql                => 'Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
20203366, ''20203366 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 3 [RPC3]'',
21236633, ''21236633 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 4 [RPC4]'',
22644544, ''22644544 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 5 [RPC5]'') as "EBS RPC PATCHES",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as "APPLIED"
From 
(select ''20203366'' as bug_number From Dual
UNION ALL
select ''21236633'' as bug_number from Dual
UNION ALL
select ''22644544'' as bug_number From Dual) Bugs',
      p_title                  => 'EBS Recommended Patch Collection (RPC) Patches for R12.1',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are Recommended Patch Collection (RPC) patches not applied on this '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.                         ',
      p_solution               => 'Please review the list above and schedule to apply the latest EBS Recommended Patch Collection (RPC) patch at your earliest convenience.<br><br>

<p><a href="https://blogs.oracle.com/ebstech/identifying-recommended-patches-for-e-business-suite-environments" target="_blank"> Recommended Patches</a> for E-Business Suite Environments</p> <br><br>
	
Patch {20203366} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 3 [RPC3] has been Superseded.<br><br>
 
This patch was originally replaced by patch {21236633}. The most recent replacement for this patch is {22644544}. If you are downloading patch {20203366} because it is a prerequisite for another patch or patchset, you should verify whether or not {22644544} is suitable as a substitute prerequisite before downloading it.<br><br>

Replacement Options (Patches or Patchsets known to Include or Supersede this Patch)<br><br>
		
Follow [2053709/KB199829] to apply patch {21236633} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 4 [RPC4]
Follow [2152266/KB196540] to apply patch {22644544} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 5 [RPC5]',
      p_success_msg            => 'Nice work.  All Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection patches (RPCs) are applied as recommended.
<p>Added the HTML Link :<br><a href="https://blogs.oracle.com/ebstech/identifying-recommended-patches-for-e-business-suite-environments" target="_blank"> Recommended Patches</a> for E-Business Suite Environments</p> 

',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '14'
      );
   l_info.delete;
debug('end add_signature: FND_PATCHES_RPC3');



debug('begin add_signature: FND_PATCHES_RPC4');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11513',
      p_sig_id                 => 'FND_PATCHES_RPC4',
      p_sig_sql                => 'Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
21236633, ''21236633 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 4 [RPC4]'',
22644544, ''22644544 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 5 [RPC5]'') as "EBS RPC PATCHES",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as "APPLIED"
From 
(select ''21236633'' as bug_number from Dual
UNION ALL
select ''22644544'' as bug_number From Dual) Bugs',
      p_title                  => 'EBS Recommended Patch Collection (RPC) Patches for R12.1',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are Recommended Patch Collection (RPC) patches not applied on this '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please review the list above and schedule to apply the latest EBS Recommended Patch Collection (RPC) patch at your earliest convenience.<br><br>

<p><a href="https://blogs.oracle.com/ebstech/identifying-recommended-patches-for-e-business-suite-environments" target="_blank"> Recommended Patches</a> for E-Business Suite Environments</p> <br><br>
	
Patch {21236633} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 4 [RPC4] has been Superseded.<br><br>
 
The most recent replacement for this patch is {22644544}. If you are downloading patch {21236633} because it is a prerequisite for another patch or patchset, you should verify whether or not {22644544} is suitable as a substitute prerequisite before downloading it.<br><br>

Replacement Options (Patches or Patchsets known to Include or Supersede this Patch)<br><br>
		
Follow [2152266/KB196540] to apply patch {22644544} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 5 [RPC5]',
      p_success_msg            => 'Nice work.  All Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection patches (RPCs) are applied as recommended.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: FND_PATCHES_RPC4');



debug('begin add_signature: FND_PATCHES_RPC5');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11514',
      p_sig_id                 => 'FND_PATCHES_RPC5',
      p_sig_sql                => 'Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
22644544, ''22644544 - Oracle 12.1.3+ E-Business Suite Recommended Patch Collection 5 [RPC5]'') as "EBS RPC PATCHES",
decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as "APPLIED"
From 
(select ''22644544'' as bug_number From Dual) Bugs',
      p_title                  => 'EBS Recommended Patch Collection (RPC) Patches for R12.1',
      p_fail_condition         => '[APPLIED]<>[APPLIED]',
      p_problem_descr          => 'There are Recommended Patch Collection (RPC) patches not applied on this '||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please follow [2152266/KB196540] to apply patch {22644544} - Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 5 [RPC5] <br><br>

<p><a href="https://blogs.oracle.com/ebstech/identifying-recommended-patches-for-e-business-suite-environments" target="_blank"> Recommended Patches</a> for E-Business Suite Environments</p> ',
      p_success_msg            => 'The R'||mask_text(g_apps_version, nvl( upper(''), 'NO_MASK') )||' Oracle E-Business Suite instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||' has the latest Release 12.1.3 Recommended Patch Collection (RPC) patch applied.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: FND_PATCHES_RPC5');



debug('begin add_signature: EBS_ATG_CP_30983111');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '22605',
      p_sig_id                 => 'EBS_ATG_CP_30983111',
      p_sig_sql                => 'select ''30983111'' "PATCH", ad_patch.is_patch_applied(''R12'',-1,30983111) "APPLIED", ''2736293.1'' "NOTE" from dual',
      p_title                  => 'Check Patch for Profile Option CONC_KEEP_BLANK_FILES',
      p_fail_condition         => '[APPLIED] = [NOT_APPLIED]',
      p_problem_descr          => 'Important Concurrent Processing Patch 30983111 is not applied.',
      p_solution               => 'Concurrent Requests may Fail with Warning "APP-FND-01388: Cannot read value for profile option CONC_KEEP_BLANK_FILES in routine &ROUTINE". <br><br>

If this is found, please apply Patch  30983111 and follow instructions in [2736293/KB709174] Concurrent Requests Fail with Warning "APP-FND-01388: Cannot read value for profile option CONC_KEEP_BLANK_FILES in routine &ROUTINE".<br>
Confirm the following file versions:<br>
<br>
For 12.1: fnd src/process     afpprc.lpc 120.10.12010000.10 .<br>
<br>
For 12.2: fnd src/process     afpprc.lpc     120.10.12020000.10 .',
      p_success_msg            => 'Concurrent Patch 30983111 is applied.',
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
debug('end add_signature: EBS_ATG_CP_30983111');



debug('begin add_signature: EBS_ATG_COMPONENT_33412336');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24003',
      p_sig_id                 => 'EBS_ATG_COMPONENT_33412336',
      p_sig_sql                => 'select ''33412336'' "PATCH", ad_patch.is_patch_applied(''R12'',-1,33412336) "APPLIED", ''2880100.1'' "NOTE" from dual',
      p_title                  => 'Check Recent Patch for concurrent program Purge Sign-On Audit Data(FNDSCPRG)',
      p_fail_condition         => '[APPLIED] = [NOT_APPLIED]',
      p_problem_descr          => 'Important Concurrent Processing Patch 33412336 is not applied.',
      p_solution               => 'Concurrent Requests may Fail with Warning "Concurrent Manager encountered an error while running SQL*Plus for your concurrent request". <br><br>
In the database alert log, the error appears as "ORA-04030: out of process memory when trying to allocate 1052696 bytes".<br><br>
If this is found, please apply Patch 33412336 and follow instructions in [2880100/KB401966] After Database and Applications Upgrade
Purge Sign-On Audit Data (FNDSCPRG) Program Fails with "Concurrent Manager encountered an error while running SQL*Plus for your concurrent request" and ORA-04030 Errors.<br><br>
Confirm the following file versions:<br><br>
For 12.2.10: FNDSCPRG.sql 120.0.12020000.10
<br><br>',
      p_success_msg            => 'Concurrent Patch 33412336 is applied.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_COMPONENT_33412336');



debug('begin add_signature: EBS_ATG_CP_DELIVERY_PROCESSOR_VERSION_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25311',
      p_sig_id                 => 'EBS_ATG_CP_DELIVERY_PROCESSOR_VERSION_CHECK',
      p_sig_sql                => 'select "Top","Subdir","Filename","Current Versions","Fixed Version" from (
(select af1.APP_SHORT_NAME||''_TOP/'' "Top", af1.subdir "Subdir",af1.filename "Filename",
     afv1.version "Current Versions", ''120.2.12020000.7'' "Fixed Version",
	   rank()over(partition by af1.filename
	     order by afv1.version_segment1 desc,
	     afv1.version_segment2 desc,afv1.version_segment3 desc,
	     afv1.version_segment4 desc,afv1.version_segment5 desc,
	     afv1.version_segment6 desc,afv1.version_segment7 desc,
	     afv1.version_segment8 desc,afv1.version_segment9 desc,
	     afv1.version_segment10 desc,
	     afv1.translation_level desc) as rankUS
  from ad_files af1, ad_file_versions afv1
where af1.file_id = afv1.file_id
  and af1.filename in (''DeliveryProcessor.class'')
  )
 )
where rankUS = 1
and (FND_IREP_LOADER_PRIVATE.compare_versions("Current Versions","Fixed Version") = ''<'')
order by 3',
      p_title                  => 'Concurrent Processing file Version Check for DeliveryProcessor',
      p_fail_condition         => 'RS',
      p_problem_descr          => '$FND_TOP/java/cp/opp/DeliveryProcessor.class is below recommended version 120.2.12020000.7.',
      p_solution               => 'Please apply patch 34241625 which delivers :<br>
DeliveryProcessor.java 120.2.12020000.7 to fix a known issue with Missing Or Blank Attachments When "Send Output As Attachment" When Setting Deliver To Email On Concurrent Requests as outlined in [2894769/KB714371].',
      p_success_msg            => 'Verified $FND_TOP/java/cp/opp/DeliveryProcessor.class is at or above file version 120.2.12020000.7 as expected.
',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CP_DELIVERY_PROCESSOR_VERSION_CHECK');



debug('begin add_signature: EBS_ATG_CHECK_FND_PATCH_34304527');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24854',
      p_sig_id                 => 'EBS_ATG_CHECK_FND_PATCH_34304527',
      p_sig_sql                => 'Select Bugs.Bug_Number as PATCH,
	Decode(Bugs.Bug_Number,
	34304527, ''34304527:FNDRSRUN - ENLARGED SUBMIT BUTTON AFTER 32139972 AND 33606047'') as "Recommended patch for FNDRSRUN",
    ''2903427.1'' "NOTE",
	decode(Ad_Patch.Is_Patch_Applied(''R12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
	From 
	(select ''34304527'' As Bug_Number From Dual) Bugs',
      p_title                  => 'Recommended FNDRSRUN Patch 34304527 is missing',
      p_fail_condition         => '[Applied] = [NOT APPLIED]',
      p_problem_descr          => 'There is a recommended patch for FNDRSRUN that is missing from this instance. ',
      p_solution               => '<b>Please apply recommended patch {34304527}. <br><br>

Patch 34304527:R12.FND.C will bring new code fixes and new Concurrent Processing code FNDRSRUN.fmb 120.106.12020000.202 <br><br>
    
1. Download and review the readme and pre-requisites for 34304527:R12.FND.C<br>
2. Ensure that you have taken a backup of your system before applying the recommended patch.<br>
3. Apply the patch in a test environment.<br>
4. Retest the issue.<br>
5. Migrate the solution as appropriate to other environments.<br>

<br><br>
Further guidance can be found in [2903427/KB549689] FNDRSRUN - Enlarged Submit Button After Applying Patches 32139972 And 33606047',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_CHECK_FND_PATCH_34304527');



debug('begin add_signature: CP4_STD_MGR_ENV');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5711',
      p_sig_id                 => 'CP4_STD_MGR_ENV',
      p_sig_sql                => 'SELECT q.USER_CONCURRENT_QUEUE_NAME "Manager", a.application_name, v.VARIABLE, v.VALUE 
FROM fnd_concurrent_queues_vl q, fnd_application_vl a, FND_CONC_QUEUE_ENVIRON v
WHERE a.application_id  = q.application_id 
and q.CONCURRENT_QUEUE_NAME = ''STANDARD''
and a.application_id = v.CONCURRENT_QUEUE_ID(+)',
      p_title                  => 'Environment',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Standard Manager is not found.',
      p_solution               => 'Ensure that the Standard Manager''s definition has not been changed 
with a "Included" Specialization" rule--"Excluded" is ok. 
(Responsibility = System Administrator, Navigate --> Concurrent: 
Manager: Define)
Any changes requires that you "Verify" the Internal Concurrent Manager 
on the "Administer Concurrent Managers" screen.
',
      p_success_msg            => 'Standard Manager is running as expected.',
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
debug('end add_signature: CP4_STD_MGR_ENV');



debug('begin add_signature: CP4_STD_MGR_DEFINE_CACHE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5733',
      p_sig_id                 => 'CP4_STD_MGR_DEFINE_CACHE',
      p_sig_sql                => 'SELECT q.USER_CONCURRENT_QUEUE_NAME "MANAGER", q.CONCURRENT_QUEUE_NAME "SHORT NAME",  q.enabled_flag "ENABLED",
a.application_name "APPLICATION", q.description "DESCRIPTION", decode(q.manager_type,''0'',''Internal Concurrent Manager'',''1'',''Concurrent Manager'', ''2'',''Internal Monitor'', ''3'',''Transaction Manager'', ''4'',''Conflict Resolution Manager'',''5'',''Scheduler/Prereleaser Manager'', ''6'',''Service Manager'') "TYPE", q.DATA_GROUP_ID "DATA GROUP", q.RESOURCE_CONSUMER_GROUP "CONSUMER GROUP", 
q.cache_size "CACHE SIZE",  q.node_name "PRIMARY NODE", q.os_queue "PRIMARY SYSTEM QUEUE", 
q.node_name2 "2ND NODE", q.os_queue2 "2ND SYSTEM QUEUE"
from fnd_concurrent_queues_vl q, fnd_product_installations i, fnd_application_vl a,
fnd_concurrent_time_periods p, fnd_concurrent_queue_size qs
where i.application_id = q.application_id
and a.application_id = q.application_id
and qs.queue_application_id = q.application_id
and qs.concurrent_queue_id = q.concurrent_queue_id
and qs.period_application_id = p.application_id
and qs.concurrent_time_period_id = p.concurrent_time_period_id
and nvl(q.control_code,''X'') <> ''E''
and q.CONCURRENT_QUEUE_NAME = ''STANDARD''
order by q.concurrent_queue_name, p.concurrent_time_period_id',
      p_title                  => 'Standard Manager Cache Size',
      p_fail_condition         => '[q.cache_size] > [5]',
      p_problem_descr          => 'Standard Manager Cache Size is set to '||mask_text(g_cache, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'By setting the cache size at a higher number, the concurrent manager does not have to read its requests list each time it runs a request.<br>However, the manager does not recognize any priority changes you make for a particular request if it has already read that request into its cache. Further, even if you give a higher priority to a new request, that new request must wait until the buffer is empty and the manager returns to look at the requests list. That request may have to wait a long time if you set the buffer size to a high number.<br><br>
You should use cache size to tune your concurrent managers to work most efficiently for you site''s needs. If your organization tends to reprioritize jobs going to a certain manager, that manager should have its buffer size set fairly low.<br><br>

<b>Tip:</b> Enter a value of 1 when defining a manager that runs long, time-consuming jobs, and a value of 3 or 4 for managers that run small, quick jobs."',
      p_success_msg            => 'Standard Manager Cache Size is set to '||mask_text(g_cache, nvl( upper(''), 'NO_MASK') )||'.
<br><br>
According to the "Oracle Applications System Administrator''s Guide - Configuration" Defining Concurrent Managers section : <br>
Release 12 (Part No. B31453-04)<br>
Release 11i (Part No. B13925-06)<br><br>

"Cache Size (Concurrent Manager only)<br>
Enter the number of requests your manager remembers each time it reads which requests to run. For example, if a manager''s workshift has 1 target process and a cache value of 3, it will read three requests and wait until these three requests have been run before reading new requests.
<br><br>
In reading requests, the manager will only put requests it is allowed to run into its cache. For example, if you have defined your manager to run only Order Entry reports then the manager will put only Order Entry requests into its cache.
<br><br>
If you enter 1, the concurrent manager must look at its requests list each time it is ready to process another request.
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: CP4_STD_MGR_DEFINE_CACHE');



debug('begin add_signature: CP4_STD_MGR_WRK_SHIFTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5713',
      p_sig_id                 => 'CP4_STD_MGR_WRK_SHIFTS',
      p_sig_sql                => 'SELECT q.USER_CONCURRENT_QUEUE_NAME "Manager", a.application_name, 
p.concurrent_time_period_name "Work Shift", p.description "Description",
qs.min_processes "Processes", qs.service_parameters "Parameter", qs.sleep_seconds "Sleep Seconds"
from fnd_concurrent_queues_vl q, fnd_application_vl a,
fnd_concurrent_time_periods p, fnd_concurrent_queue_size qs
where a.application_id = q.application_id
and qs.queue_application_id = q.application_id
and qs.concurrent_queue_id = q.concurrent_queue_id
and qs.period_application_id = p.application_id
and qs.concurrent_time_period_id = p.concurrent_time_period_id
and q.enabled_flag = ''Y''
and nvl(q.control_code,''X'') <> ''E''
and q.CONCURRENT_QUEUE_NAME = ''STANDARD''
order by q.concurrent_queue_name, p.concurrent_time_period_id',
      p_title                  => 'Work Shifts',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Standard Manager is not found.',
      p_solution               => 'Ensure that the Standard Manager''s definition has not been changed 
with a "Included" Specialization" rule--"Excluded" is ok. 
(Responsibility = System Administrator, Navigate --> Concurrent: 
Manager: Define)
Any changes requires that you "Verify" the Internal Concurrent Manager 
on the "Administer Concurrent Managers" screen.
',
      p_success_msg            => 'Standard Manager is running as expected.',
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
debug('end add_signature: CP4_STD_MGR_WRK_SHIFTS');



debug('begin add_signature: CP4_STD_MGR_VALIDATE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5605',
      p_sig_id                 => 'CP4_STD_MGR_VALIDATE',
      p_sig_sql                => 'select decode(c.include_flag,''E'',''Exclude'',''I'',''Include'') "INCLUDE_FLAG",
decode (c.type_code,''C'',''Combined Rule'',''L'',''Logical DB'',
''O'',''Oracle ID'',''P'',''Program'',''R'',''Request Type'',''U'',''User'') "TYPE_CODE",
a.application_name, t.user_concurrent_program_name
from fnd_concurrent_queue_content c, fnd_concurrent_programs p,
fnd_concurrent_programs_tl t, fnd_application_tl a
where c.concurrent_queue_id = 0
and c.type_application_id = p.application_id
and c.type_id = p.concurrent_program_id
and p.application_id = a.application_id
and t.concurrent_program_id = p.concurrent_program_id
and a.language=t.language
order by 1 desc',
      p_title                  => 'Validate Standard Manager Definition',
      p_fail_condition         => '[INCLUDE_FLAG]=[Include]',
      p_problem_descr          => 'The Standard Manager''s definition has an "Include" Specialization rule.
',
      p_solution               => 'You should not alter the definition of the Standard Concurrent manager with an "Include", however, "Exclude" is ok. <br>
If you do, and you have not defined additional managers to accept your requests, some programs may not run. Use the Standard manager as a safety net, a manager who is always available to run any request. Define additional managers to handle your installation site''s specific needs.
<br><br>
(Responsibility = System Administrator, Navigate --> Concurrent: Manager: Define)<br>
Any changes requires that you "Verify" the Internal Concurrent Manager on the "Administer Concurrent Managers" screen.<br><br>

When changing manager specialization or program incompatibilities, remember to "Verify" the ICM on the Administer Concurrent Manager form or bounce (restart) the concurrent managers for the changes to take effect.
',
      p_success_msg            => 'The Standard Concurrent manager appears to be setup correctly.<br>
It may use "Exclude" Specialization rules, <br>
Define additional managers to handle your installation site''s specific needs.
<br><br>
(Responsibility = System Administrator, Navigate --> Concurrent: Manager: Define)<br>
Any changes requires that you "Verify" the Internal Concurrent Manager on the "Administer Concurrent Managers" screen.<br><br>

When changing manager specialization or program incompatibilities, remember to "Verify" the ICM on the Administer Concurrent Manager form or bounce (restart) the concurrent managers for the changes to take effect.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: CP4_STD_MGR_VALIDATE');



debug('begin add_signature: CP4_STD_MGR_DEFINE_R12');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5710',
      p_sig_id                 => 'CP4_STD_MGR_DEFINE_R12',
      p_sig_sql                => 'SELECT q.USER_CONCURRENT_QUEUE_NAME "MANAGER", q.CONCURRENT_QUEUE_NAME "SHORT NAME",  q.enabled_flag "ENABLED",
a.application_name "APPLICATION NAME", q.description "DESCRIPTION", decode(q.manager_type,''0'',''Internal Concurrent Manager'',''1'',''Concurrent Manager'', ''2'',''Internal Monitor'', ''3'',''Transaction Manager'', ''4'',''Conflict Resolution Manager'',''5'',''Scheduler/Prereleaser Manager'', ''6'',''Service Manager'') "TYPE", q.DATA_GROUP_ID "DATA GROUP", q.RESOURCE_CONSUMER_GROUP "CONSUMER GROUP", 
q.cache_size,  q.node_name "Primary Node", q.os_queue "PRIMARY SYSTEM QUEUE", 
q.node_name2 "SECOND NODE", q.os_queue2 "SECOND SYSTEM QUEUE"
from fnd_concurrent_queues_vl q, fnd_product_installations i, fnd_application_vl a,
fnd_concurrent_time_periods p, fnd_concurrent_queue_size qs
where i.application_id = q.application_id
and a.application_id = q.application_id
and qs.queue_application_id = q.application_id
and qs.concurrent_queue_id = q.concurrent_queue_id
and qs.period_application_id = p.application_id
and qs.concurrent_time_period_id = p.concurrent_time_period_id
and nvl(q.control_code,''X'') <> ''E''
and q.CONCURRENT_QUEUE_NAME = ''STANDARD''
order by q.concurrent_queue_name, p.concurrent_time_period_id',
      p_title                  => 'Standard Manager Definition',
      p_fail_condition         => '[ENABLED] <> [Y]',
      p_problem_descr          => 'Standard Manager is not enabled.',
      p_solution               => 'Ensure that the Standard Manager''s definition has not been changed with a "Included" Specialization" rule<br>
"Excluded" is ok. <br>
(Responsibility = System Administrator, Navigate --> Concurrent: Manager: Define)
Any changes requires that you "Verify" the Internal Concurrent Manager 
on the "Administer Concurrent Managers" screen.<br><br>

As per the Oracle E-Business Suite System Administrator''s Guide - Configuration:
"A manager named Standard. The Standard manager accepts any and all requests; it has no specialization. The Standard manager is active all the time; it works 365 days a year, 24 hours a day.<br>
<b>ATTENTION:</b> You should not alter the definition of the Standard concurrent manager. If you do, and you have not defined additional managers to accept your requests, some programs may not run. Use the Standard manager as a safety net, a manager who is always available to run any request. Define additional managers to handle your installation site''s specific needs."',
      p_success_msg            => 'Standard Manager is running as expected.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL('CP4_STD_MGR_ENV','CP4_STD_MGR_DEFINE_CACHE','CP4_STD_MGR_WRK_SHIFTS','CP4_STD_MGR_VALIDATE'),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '39'
      );
   l_info.delete;
debug('end add_signature: CP4_STD_MGR_DEFINE_R12');



debug('begin add_signature: CP4_STD_MGR_DEFINE_11I');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5736',
      p_sig_id                 => 'CP4_STD_MGR_DEFINE_11I',
      p_sig_sql                => 'SELECT q.USER_CONCURRENT_QUEUE_NAME "MANAGER", q.CONCURRENT_QUEUE_NAME "SHORT NAME",  q.enabled_flag "ENABLED",
a.application_name "APPLICATION NAME", q.description "DESCRIPTION", decode(q.manager_type,''0'',''Internal Concurrent Manager'',''1'',''Concurrent Manager'', ''2'',''Internal Monitor'', ''3'',''Transaction Manager'', ''4'',''Conflict Resolution Manager'',''5'',''Scheduler/Prereleaser Manager'', ''6'',''Service Manager'') "TYPE", q.DATA_GROUP_ID "DATA GROUP", q.RESOURCE_CONSUMER_GROUP "CONSUMER GROUP", 
q.cache_size "CACHE SIZE",  q.node_name "PRIMARY NODE", q.os_queue "PRIMARY SYSTEM QUEUE", 
q.node_name2 "2ND NODE", q.os_queue2 "2ND SYSTEM QUEUE"
from fnd_concurrent_queues_vl q, fnd_product_installations i, fnd_application_vl a,
fnd_concurrent_time_periods p, fnd_concurrent_queue_size qs
where i.application_id = q.application_id
and a.application_id = q.application_id
and qs.queue_application_id = q.application_id
and qs.concurrent_queue_id = q.concurrent_queue_id
and qs.period_application_id = p.application_id
and qs.concurrent_time_period_id = p.concurrent_time_period_id
and nvl(q.control_code,''X'') <> ''E''
and q.CONCURRENT_QUEUE_NAME = ''STANDARD''
order by q.concurrent_queue_name, p.concurrent_time_period_id',
      p_title                  => 'Standard Manager Definition',
      p_fail_condition         => '[q.enabled_flag] <> [Y]',
      p_problem_descr          => 'Standard Manager is not enabled.',
      p_solution               => 'Ensure that the Standard Manager''s definition has not been changed with a "Included" Specialization" rule<br>
"Excluded" is ok. <br>
(Responsibility = System Administrator, Navigate --> Concurrent: Manager: Define)
Any changes requires that you "Verify" the Internal Concurrent Manager 
on the "Administer Concurrent Managers" screen.<br><br>

As per the Oracle E-Business Suite System Administrator''s Guide - Configuration:
"A manager named Standard. The Standard manager accepts any and all requests; it has no specialization. The Standard manager is active all the time; it works 365 days a year, 24 hours a day.<br>
<b>ATTENTION:</b> You should not alter the definition of the Standard concurrent manager. If you do, and you have not defined additional managers to accept your requests, some programs may not run. Use the Standard manager as a safety net, a manager who is always available to run any request. Define additional managers to handle your installation site''s specific needs."',
      p_success_msg            => 'Standard Manager is running as expected.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL('CP4_STD_MGR_DEFINE_CACHE','CP4_STD_MGR_WRK_SHIFTS','CP4_STD_MGR_VALIDATE'),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '22'
      );
   l_info.delete;
debug('end add_signature: CP4_STD_MGR_DEFINE_11I');



debug('begin add_signature: EBS_ATG_CP_BROWSER_SUPPORT_JWS_PATCHES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25639',
      p_sig_id                 => 'EBS_ATG_CP_BROWSER_SUPPORT_JWS_PATCHES',
      p_sig_sql                => 'Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
16774851, ''ENHANCEMENTS: DELIVERY OPTIONS PROPAGATION OUTPUT FILE EXT WITH FORMAT EMAIL DELIVERY ATTACHMENTS'',
21830810, ''* R12.TXK.C.Delta.8'', 
21841299, ''* R12.AD.C.DELTA.8 PATCH'',
21900895, ''* R12.ATG_PF.C.DELTA.6'', 
24498616, ''* AD Add Java Web Start support to Oracle E-Business Suite'',
25380324, ''* Oracle E-Business Suite Java Applets launching with Java Web Start'',
25449925, ''* TXK Add Java Web Start support to Oracle E-Business Suite'',
28700057, ''** JWS: ADD SYSTEM PROPERTY TO FORMS_JNLP.TMP FOR FIREFOX ON MACOS'',
28713780, ''* Oracle Workflow Java Applets launching with Java Web Start'',
30800919, ''* EDGECHRCERT:EDGE (CHROMIUM) SUPPORT IN BROWSERDETECTOR'',
32134675, ''ATTACHMENT FILE NAME CONTAINS APSTROPHE FAILED TO DOWNLOAD IN CHROME'',
32645734, ''** Oracle E-Business Suite Java Applets launching with JWS for macOS Big Sur (and later) using Firefox ESR'',
32874257, ''*** DIFFERENTIATE EDGE LEGACY AND EDGE CHROMIUM IN BROWSERDETECTOR'',
32902510, ''*** JWS AND JRE 8u291 AND LATER COMPATIBILITY PATCH'',
33671306, ''ENHANCEMENTS: PROGRAM OPTION PROPAGATION, FILE EXT WITH FILE FORMAT, EMAIL DELIVERY ATTACHMENT OR BODY'') as "Description",
decode(Ad_Patch.Is_Patch_Applied(''12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From
(select ''16774851'' as bug_number From Dual
UNION ALL
select ''21830810'' as bug_number From Dual
UNION ALL
select ''21841299'' as bug_number From Dual
UNION ALL
select ''21900895'' as bug_number From Dual
UNION ALL
select ''24498616'' as bug_number From Dual
UNION ALL
select ''25380324'' as bug_number From Dual
UNION ALL
select ''25449925'' as bug_number From Dual
UNION ALL
select ''28700057'' as bug_number From Dual
UNION ALL
select ''28713780'' as bug_number From Dual
UNION ALL
select ''30800919'' as bug_number From Dual
UNION ALL
select ''32134675'' as bug_number From Dual
UNION ALL
select ''32645734'' as bug_number From Dual
UNION ALL
select ''32874257'' as bug_number From Dual
UNION ALL
select ''32902510'' as bug_number From Dual
UNION ALL
select ''33671306'' as bug_number From Dual) Bugs',
      p_title                  => 'Browser Support, Java Web Start (JWS) Patches',
      p_fail_condition         => '[Applied] = [NOT APPLIED]',
      p_problem_descr          => 'No Browser Support, Java Web Start (JWS) Patches found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please review and follow the documents:<br>
[11165167] - Using Java Web Start with Oracle E-Business Suite. <br>
[11217212] - Oracle E-Business Suite Desktop Client Hardware and Software Requirements. <br>
[11173332] - Recommended Browsers for Oracle E-Business Suite Releases 12.2 and 12.1 <br>
[11175888] Deploying JRE (Native Plug-in) for Windows Clients in Oracle E-Business Suite Release 12.',
      p_success_msg            => 'Browser Support, Java Web Start (JWS) Patches found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>

* Denotes Minimum JWS / Edge Requirements <br>
** Denotes Mac OS Requirements <br>
*** Denotes Critical Bug <br>

Please review and follow the documents:<br>
[11165167] - Using Java Web Start with Oracle E-Business Suite. <br>
[11217212] - Oracle E-Business Suite Desktop Client Hardware and Software Requirements. <br>
[11173332] - Recommended Browsers for Oracle E-Business Suite Releases 12.2 and 12.1 <br>
[11175888] Deploying JRE (Native Plug-in) for Windows Clients in Oracle E-Business Suite Release 12.
',
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
debug('end add_signature: EBS_ATG_CP_BROWSER_SUPPORT_JWS_PATCHES');



debug('begin add_signature: EBS_ATG_CP_BROWSER_SUPPORT_JWS_PATCHES_121');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25760',
      p_sig_id                 => 'EBS_ATG_CP_BROWSER_SUPPORT_JWS_PATCHES_121',
      p_sig_sql                => 'Select Bugs.Bug_Number as PATCH,
Decode(Bugs.Bug_Number,
  8919489,  ''* R12.TXK.B.DELTA.3'',
  8919491,  ''* R12.ATG_PF.B.Delta.3'',
  16774851, ''12.1 ENHANCEMENTS: DELIVERY OPTIONS PROPAGATION/OUTPUT FILE EXT WITH FORMAT/EMAIL DELIVERY ATTACHMENTS'',
  17884289, ''R12.AD.B.Delta.4'',
  19697691, ''18370082 BACKPORT: CHROME: CHROME SUPPORT IN BROWSERDETECTOR'',
  19697692, ''18370097 BACKPORT: NLS:CHROME: IE STYLE FILENAME SUPPORT FOR CHROME BROWSERS IN'',
  23569686, ''* R12.AD.B.Delta.8'',
  24319156, ''* TXK: Add Java Web Start support to Oracle E-Business Suite'',
  24498616, ''* AD: Add Java Web Start support to Oracle E-Business Suite'', 
  25380324, ''* Oracle E-Business Suite Java Applets launching with Java Web Start'', 
  28156520, ''** Oracle E-Business Suite Java Applets launching with Java Web Start plus macOS Support using Firefox'', 
  28700057, ''** JWS: ADD SYSTEM PROPERTY TO FORMS_JNLP TMP FOR FIREFOX ON MACOS'', 
  28713780, ''* Oracle Workflow Java Applets launching with Java Web Start'',
  29052441, ''* JWS: NEW PREFERENCE TO INDICATE LAUNCH OF NEW FORMS SESSION'', 
  29058008, ''* Oracle E-Business Suite Java Applets launching with Java Web Start Release 2'', 
  29124450, ''* TXK: Consolidated Patch for Java Web Start Release 2'', 
  30800919, ''* EDGECHRCERT:EDGE (CHROMIUM) SUPPORT IN BROWSERDETECTOR'', 
  32419826, ''CONCURRENT PROGRAM OUTPUT OPENING IN TEXT RATHER THAN EXCEL WHEN LAUNCHING FROM CHROME OR EDGE'',
  32645734, ''** Oracle E-Business Suite Java Applets launching with JWS for macOS Big Sur (and later) using Firefox ESR'',
  32874257, ''*** DIFFERENTIATE EDGE (LEGACY) AND EDGE (CHROMIUM) IN BROWSERDETECTOR'',
  32902510, ''*** JWS AND JRE (8u291 AND LATER) COMPATIBILITY PATCH'',
  33671306, ''ENHANCEMENTS: PROGRAM OPTION PROPAGATION, FILE EXT WITH FILE FORMAT, EMAIL DELIVERY ATTACHMENT OR BODY'') as "Description",
decode(Ad_Patch.Is_Patch_Applied(''12'',-1,bugs.bug_Number),''EXPLICIT'',''APPLIED'',''NOT APPLIED'') as APPLIED
From
(select ''8919489'' as bug_number From Dual
UNION ALL
select ''8919491'' as bug_number From Dual
UNION ALL
select ''16774851'' as bug_number From Dual
UNION ALL
select ''17884289'' as bug_number From Dual
UNION ALL
select ''19697691'' as bug_number From Dual
UNION ALL
select ''19697692'' as bug_number From Dual
UNION ALL
select ''23569686'' as bug_number From Dual
UNION ALL
select ''24319156'' as bug_number From Dual
UNION ALL
select ''24498616'' as bug_number From Dual
UNION ALL
select ''25380324'' as bug_number From Dual
UNION ALL
select ''28156520'' as bug_number From Dual
UNION ALL
select ''28700057'' as bug_number From Dual
UNION ALL
select ''28713780'' as bug_number From Dual
UNION ALL
select ''29052441'' as bug_number From Dual
UNION ALL
select ''29058008'' as bug_number From Dual
UNION ALL
select ''29124450'' as bug_number From Dual
UNION ALL
select ''30800919'' as bug_number From Dual
UNION ALL
select ''32419826'' as bug_number From Dual
UNION ALL
select ''32645734'' as bug_number From Dual
UNION ALL
select ''32874257'' as bug_number From Dual
UNION ALL
select ''32902510'' as bug_number From Dual
UNION ALL
select ''33671306'' as bug_number From Dual) Bugs',
      p_title                  => 'Browser Support, Java Web Start (JWS) Patches',
      p_fail_condition         => '[Applied] = [NOT APPLIED]',
      p_problem_descr          => 'No Browser Support, Java Web Start (JWS) Patches found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.',
      p_solution               => 'Please review and follow the documents:<br>
[11165167] - Using Java Web Start with Oracle E-Business Suite. <br>
[11217212] - Oracle E-Business Suite Desktop Client Hardware and Software Requirements. <br>
[11173332] - Recommended Browsers for Oracle E-Business Suite Releases 12.2 and 12.1 <br>
[11175888] Deploying JRE (Native Plug-in) for Windows Clients in Oracle E-Business Suite Release 12.',
      p_success_msg            => 'Browser Support, Java Web Start (JWS) Patches found on instance '||mask_text(g_instance, nvl( upper(''), 'NO_MASK') )||'.<br><br>

* Denotes Minimum JWS / Edge Requirements <br>
** Denotes Mac OS Requirements <br>
*** Denotes Critical Bug <br>

Please review and follow the documents:<br>
[11165167] - Using Java Web Start with Oracle E-Business Suite. <br>
[11217212] - Oracle E-Business Suite Desktop Client Hardware and Software Requirements. <br>
[11173332] - Recommended Browsers for Oracle E-Business Suite Releases 12.2 and 12.1 <br>
[11175888] Deploying JRE (Native Plug-in) for Windows Clients in Oracle E-Business Suite Release 12.
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
debug('end add_signature: EBS_ATG_CP_BROWSER_SUPPORT_JWS_PATCHES_121');



debug('begin add_signature: EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '27970',
      p_sig_id                 => 'EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX',
      p_sig_sql                => 'select * from
  (
    select
        seq.sequence_owner
      , seq.sequence_name
      , ( select application_name from
          ( select ord, application_id, application_name from
            ( select 1 ord, app.application_id, app.application_name
              from fnd_application_vl app
              where app.product_code = substr(seq.sequence_name, 1, instr(seq.sequence_name,''_'')-1)
              union
              select 2 ord, app.application_id, app.application_name
              from fnd_oracle_userid fou, fnd_product_installations fpi, fnd_application_vl app
              where fou.oracle_username = seq.sequence_owner
                and fpi.oracle_id = fou.oracle_id
                and app.application_id = fpi.application_id
            ) order by ord, application_id
          ) where rownum = 1
        ) application_name
      , seq.min_value
      , seq.max_value
      , seq.cache_size
      , seq.last_number
      , round(((seq.last_number-seq.min_value)/(seq.max_value-seq.min_value))*100) "% Range"
    from dba_sequences seq
    where seq.cycle_flag = ''N''
      and seq.max_value > 0
  )
where "% Range" >= 10 /* active threshold % */
  and max_value < 2147483648 /* limited range */
  and cache_size > 1000 /* large cache size */
  and sequence_name != ''FND_TRN_REQUEST_ID_S''
order by cache_size desc',
      p_title                  => 'Sequences With 32-bit Maximum Value and Large Cache Size',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'We have identified that at least one of your sequences is nearing its maximum threshold. ',
      p_solution               => 'Please log a SR with each product for the offending sequences.  Support will take the necessary steps to bring resolution to this issue.
Please reference [11166178/KA1025] Managing Sequences in Oracle E-Business Suite Release 12.2',
      p_success_msg            => 'No 32-bit sequences are currently close to their maximum value.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '13'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX');



debug('begin add_signature: EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25822',
      p_sig_id                 => 'EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE',
      p_sig_sql                => 'select * from 
  (
    select
        seq.sequence_owner
      , seq.sequence_name
      , ( select application_name from 
          ( select ord, application_id, application_name from 
            ( select 1 ord, app.application_id, app.application_name
              from fnd_application_vl app
              where app.product_code = substr(seq.sequence_name, 1, instr(seq.sequence_name,''_'')-1)
              union
              select 2 ord, app.application_id, app.application_name
              from fnd_oracle_userid fou, fnd_product_installations fpi, fnd_application_vl app
              where fou.oracle_username = seq.sequence_owner 
                and fpi.oracle_id = fou.oracle_id
                and app.application_id = fpi.application_id
            ) order by ord, application_id
          ) where rownum = 1
        ) application_name
      , seq.min_value
      , seq.max_value
      , seq.cache_size
      , seq.last_number
      , round(((seq.last_number-seq.min_value)/(seq.max_value-seq.min_value))*100) "% Range"
    from dba_sequences seq
    where seq.cycle_flag = ''N''
      and seq.max_value > 0
  ) 
where "% Range" >= 70  /* warning threshold % */
order by "% Range" desc, sequence_owner, sequence_name',
      p_title                  => 'Sequences Above 70 Percent of Maximum Value ',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'We have identified that at least one of your sequences is nearing its maximum threshold.  ',
      p_solution               => 'Please log a SR with each product for the offending sequences.  Support will take the necessary steps to bring resolution to this issue.
Please reference [11166178/KA1025] Managing Sequences in Oracle E-Business Suite Release 12.2',
      p_success_msg            => 'No sequences are currently close to their maximum value.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '13'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE');



debug('begin add_signature: EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX_BELOW_12C');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '28544',
      p_sig_id                 => 'EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX_BELOW_12C',
      p_sig_sql                => 'select * from 
  (
    select
        seq.sequence_owner
      , seq.sequence_name
      , ( select listagg(app.application_name, '', '') within group (order by app.application_id desc)
          from fnd_sequences fseq, fnd_application_vl app
          where fseq.sequence_name = seq.sequence_name
            and app.application_id = fseq.application_id ) application_name
      , seq.max_value
      , seq.cache_size
      , seq.last_number
      , round((seq.last_number/seq.max_value)*100) "% Max"
    from dba_sequences seq
    where seq.cycle_flag = ''N''
      and seq.max_value > 0
  ) 
where "% Max" >= 10 /* active threshold % */
  and max_value < 2147483648 /* limited range */
  and cache_size > 1000 /* large cache size */
 and sequence_name != '' FND_TRN_REQUEST_ID_S''
order by cache_size desc

',
      p_title                  => 'Sequences With 32-bit Maximum Value and Large Cache Size',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'We have identified that at least one of your sequences is nearing its maximum threshold. ',
      p_solution               => 'Please log a SR with each product for the offending sequences.  Support will take the necessary steps to bring resolution to this issue.
Please reference [11166178/KA1025] Managing Sequences in Oracle E-Business Suite Release 12.2',
      p_success_msg            => 'No 32-bit sequences are currently close to their maximum value.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX_BELOW_12C');



debug('begin add_signature: EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE_BELOW_12C');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '28545',
      p_sig_id                 => 'EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE_BELOW_12C',
      p_sig_sql                => 'select * from 
  (
    select
        seq.sequence_owner
      , seq.sequence_name
      , ( select listagg(app.application_name, '', '') within group (order by app.application_id desc)
          from fnd_sequences fseq, fnd_application_vl app
          where fseq.sequence_name = seq.sequence_name
            and app.application_id = fseq.application_id ) application_name
      , seq.max_value
      , seq.cache_size
      , seq.last_number
      , round((seq.last_number/seq.max_value)*100) "% Max"
    from dba_sequences seq
    where seq.cycle_flag = ''N''
      and seq.max_value > 0
  ) 
where "% Max" >= 70  /* warning threshold % */
order by "% Max" desc, sequence_owner, sequence_name',
      p_title                  => 'Sequences Above 70 Percent of Maximum Value ',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'We have identified that at least one of your sequences is nearing its maximum threshold.  ',
      p_solution               => 'Please log a SR with each product for the offending sequences.  Support will take the necessary steps to bring resolution to this issue.
Please reference [11166178/KA1025] Managing Sequences in Oracle E-Business Suite Release 12.2',
      p_success_msg            => 'No sequences are currently close to their maximum value.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE_BELOW_12C');



EXCEPTION WHEN OTHERS THEN
  print_log('Error in load_signatures');
  raise;
END load_signatures;


---------------------------------
-- MAIN ENTRY POINT
---------------------------------
PROCEDURE main(
            p_min_volume                   IN NUMBER      DEFAULT 3500
           ,p_max_volume                   IN NUMBER      DEFAULT 5000
           ,p_max_output_rows              IN NUMBER      DEFAULT 30
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



  l_step := '10';
  initialize_files;

  analyzer_title := 'Concurrent Processing Analyzer';
  analyzer_title := regexp_replace('EBS ' || analyzer_title, '(\S+\s)\1', '\1', 1, 0, 'i');  -- EBSAF-243

  l_step := '15';
   validate_parameters(
     p_min_volume                   => p_min_volume
    ,p_max_volume                   => p_max_volume
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

debug('begin section: EBS_CP_OVERVIEW');
start_section('EBS Concurrent Processing Analyzer Overview', 'EBS_CP_OVERVIEW');
if (g_reqid_cnt < 100) THEN
	set_item_result(run_stored_sig('CP1_CONC_REQQ3'));

	elsif (g_reqid_cnt > 99) THEN

		if (g_reqid_cnt > g_max_vol) THEN
			set_item_result(run_stored_sig('CP1_CONC_REQQ1'));

			elsif (g_reqid_cnt > g_min_vol) THEN
			set_item_result(run_stored_sig('CP1_CONC_REQQ2'));

			else
			set_item_result(run_stored_sig('CP1_CONC_REQQ3'));

		end if;
end if;
   set_item_result(run_stored_sig('EBS_ATG_AT_TECHSTACK_CLASSIC'));
   IF substr(g_rep_info('Apps Version'),1,4)='12.2' THEN
      set_item_result(run_stored_sig('EBS_ATG_CP1_NODE_INFO_122'));
   END IF;
   set_item_result(run_stored_sig('EBS_ATG_CP1_FNDRSRUN'));
   set_item_result(run_stored_sig('CP1_PURGEREQS'));
   set_item_result(run_stored_sig('CP1_PURGELIGIBLE'));
   set_item_result(run_stored_sig('CP1_ORPHANED_PURGE_DATA'));
   IF substr(g_rep_info('Apps Version'),1,4)<'12.2' THEN
      set_item_result(run_stored_sig('CP1_NODE_INFO'));
   END IF;
   set_item_result(run_stored_sig('CP1_PARAMETERS'));
   set_item_result(run_stored_sig('CP1_ENV'));
   set_item_result(run_stored_sig('CP1_PROFILES'));
   set_item_result(run_stored_sig('EBS_ATG_CP2_CONC_REQUEST_LIMIT'));
   set_item_result(run_stored_sig('CP1_GSM_ENABLED'));
   set_item_result(run_stored_sig('EBS_ATG_CP1_FND_DOCS_LONG_TEXT_SN'));
if (g_apps_invalid_cnt > 100) then
   set_item_result(run_stored_sig('CP1_INVALIDS_ALL_HIGH'));
else
   set_item_result(run_stored_sig('CP1_INVALIDS_ALL_LOW'));
end if;

if (g_fnd_invalid_cnt > 5) then
   set_item_result(run_stored_sig('CP1_INVALIDS_FND_HIGH'));
else
   set_item_result(run_stored_sig('CP1_INVALIDS_FND_LOW'));
end if;
   set_item_result(run_stored_sig('CP1_FND_PACKAGE_CHECK_FAIL'));
   set_item_result(run_stored_sig('CP1_FND_FILE'));
IF (substr(g_rep_info('Apps Version'),1,4)='12.2') THEN
  if (((g_ad_codelevel)='C.5') and ((g_txk_codelevel)='C.5')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C5'));
  elsif (((g_ad_codelevel)='C.6') and ((g_txk_codelevel)='C.6')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C6'));
  elsif (((g_ad_codelevel)='C.7') and ((g_txk_codelevel)='C.7')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C7'));
  elsif (((g_ad_codelevel)='C.8') and ((g_txk_codelevel)='C.8')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C8'));
  elsif (((g_ad_codelevel)='C.9') and ((g_txk_codelevel)='C.9')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C9'));
  elsif (((g_ad_codelevel)='C.10') and ((g_txk_codelevel)='C.10')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C10'));
  elsif (((g_ad_codelevel)='C.11') and ((g_txk_codelevel)='C.11')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C11')); 
  elsif (((g_ad_codelevel)='C.12') and ((g_txk_codelevel)='C.12')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C12'));
  elsif (((g_ad_codelevel)='C.13') and ((g_txk_codelevel)='C.13')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C13'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_POSTREQUISTE_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_MIG_CLEANUP_SCRIPT'));     
  elsif (((g_ad_codelevel)='C.14') and ((g_txk_codelevel)='C.14')) then 
     set_item_result(run_stored_sig('AD_TXK_PATCHES_C14'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_POSTREQUISTE_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_MIG_CLEANUP_SCRIPT'));     
  elsif (((g_ad_codelevel)='C.15') and ((g_txk_codelevel)='C.15')) then 
     set_item_result(run_stored_sig('EBS_ATG_AT_AD_TXK_PATCHES_C15'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_POSTREQUISTE_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_MIG_CLEANUP_SCRIPT'));     
  elsif (((g_ad_codelevel)='C.16') and ((g_txk_codelevel)='C.16')) then 
     set_item_result(run_stored_sig('EBS_ATG_AT_AD_TXK_PATCHES_C16'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_POSTREQUISTE_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_MIG_CLEANUP_SCRIPT'));     
  elsif (((g_ad_codelevel)='C.17') and ((g_txk_codelevel)='C.17')) then 
     set_item_result(run_stored_sig('EBS_ATG_AT_AD_TXK_PATCHES_C17'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_CONSOLIDATED_POSTREQUISTE_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_APPLIED'));
     set_item_result(run_stored_sig('EBS_ATG_UGLE_COMPLETION_MIG_CLEANUP_SCRIPT'));     
  else
     set_item_result(run_stored_sig('CP1_CHK_TXK_PATCHES'));
  end if;
END IF;
IF (substr(g_rep_info('Apps Version'),1,4)='12.1') THEN
  if ((g_rpc5)='EXPLICIT') then 
     set_item_result(run_stored_sig('FND_PATCHES_RPC5'));
  elsif ((g_rpc4)='EXPLICIT') then 
     set_item_result(run_stored_sig('FND_PATCHES_RPC4'));
  elsif ((g_rpc3)='EXPLICIT') then 
     set_item_result(run_stored_sig('FND_PATCHES_RPC3'));
  elsif ((g_rpc2)='EXPLICIT') then 
     set_item_result(run_stored_sig('FND_PATCHES_RPC2'));
  else
     set_item_result(run_stored_sig('FND_PATCHES_RPC1'));
  end if;
END IF;

   IF substr(g_rep_info('Apps Version'),1,4)='12.2' THEN
      set_item_result(check_rec_patches_2); /* Signature EBS_ATG_CT_CP_PATCHES_FOR_R122 */
      set_item_result(check_rec_patches_3); /* Signature CP1_CHK_CP_PATCHES_R122 */
      set_item_result(run_stored_sig('EBS_ATG_CP_30983111'));
      set_item_result(run_stored_sig('EBS_ATG_COMPONENT_33412336'));
   END IF;
   IF substr(g_rep_info('Apps Version'),1,4)='12.1' THEN
      set_item_result(check_rec_patches_4); /* Signature CP1_CHK_CP_PATCHES_1213 */
      set_item_result(run_stored_sig('EBS_ATG_CP_30983111'));
   END IF;
   set_item_result(check_rec_patches_1); /* Signature EBS_CPU_PATCHES */
   set_item_result(run_stored_sig('EBS_ATG_CT_APPLIED_PATCHES_PAST_30_DAYS'));
end_section;
debug('end section: EBS_CP_OVERVIEW');

debug('begin section: EBS_CP_RPT_RVW_AGENT');
start_section('EBS Report Review Agent Analysis', 'EBS_CP_RPT_RVW_AGENT');
   set_item_result(run_stored_sig('EBS_ATG_CP_VIEWER_OPTIONS'));
   set_item_result(run_stored_sig('EBS_ATG_CP_VIEWING_PROFILES'));
   set_item_result(run_stored_sig('EBS_ATG_CP_REQUEST_VIEWING_ENV'));
   IF substr(g_rep_info('Apps Version'),1,4)='12.1' THEN
      set_item_result(run_stored_sig('EBS_ATG_CP_BROWSER_SUPPORT_JWS_PATCHES_121'));
   END IF;
   IF substr(g_rep_info('Apps Version'),1,4)='12.2' THEN
      set_item_result(run_stored_sig('EBS_ATG_CP_BROWSER_SUPPORT_JWS_PATCHES'));
   END IF;
   set_item_result(run_stored_sig('EBS_ATG_CP_JWS'));
end_section;
debug('end section: EBS_CP_RPT_RVW_AGENT');

debug('begin section: EBS_CP_REQUEST');
start_section('EBS Concurrent Request Analysis', 'EBS_CP_REQUEST');
   set_item_result(run_stored_sig('CP2_LONGRPTS'));
   set_item_result(run_stored_sig('CP2_ELAPSEDHIST'));
   set_item_result(run_stored_sig('CP2_CURRENTREQS'));
   set_item_result(run_stored_sig('CP2_CONCREQS2'));
   set_item_result(run_stored_sig('CP2_PENDREQ'));
   set_item_result(run_stored_sig('CP2_TOP_10_CONC_REQS'));
   set_item_result(run_stored_sig('CP2_END_DATED_USER_REQS'));
   set_item_result(run_stored_sig('CP2_PENDING_REQUESTS'));
   set_item_result(run_stored_sig('EBS_ATG_CP_PENDING_REQUESTS'));
   set_item_result(run_stored_sig('CP2_SCHEDULEDREQ2'));
   set_item_result(run_stored_sig('CP2_SCHEDULEDREQ'));
   set_item_result(run_stored_sig('CP2_LASTMONDAILY'));
   set_item_result(run_stored_sig('CP2_RUNALONE'));
   set_item_result(run_stored_sig('CP2_TABLESPACES2'));
   set_item_result(run_stored_sig('CP1_FND_CP_GSM_OPP_AQTBL_S'));
   IF substr(g_rep_info('Apps Version'),1,4)='12.2' THEN
      set_item_result(run_stored_sig('EBS_ATG_CP_DELIVERY_PROCESSOR_VERSION_CHECK'));
   END IF;
if (((g_is_33606047_applied = 'EXPLICIT') OR (g_is_32139972_applied = 'EXPLICIT')) AND (g_FNDRSRUN_ver < '120.106.12020000.202')) then
   set_item_result(run_stored_sig('EBS_ATG_CHECK_FND_PATCH_34304527'));
end if;
end_section;
debug('end section: EBS_CP_REQUEST');

debug('begin section: EBS_CONC_MGR');
start_section('EBS Concurrent Manager Analysis', 'EBS_CONC_MGR');
   set_item_result(run_stored_sig('CP3_CPADV1'));
   set_item_result(run_stored_sig('CP3_CPADV2'));
   set_item_result(run_stored_sig('EBS_ATG_CT_FND_CONCURRENT_QUEUES_NODE_DETAILS'));
   set_item_result(run_stored_sig('EBS_ATG_CT_APPLTMP_UTL_FILE_DIR'));
   set_item_result(run_stored_sig('CP3_CPADV3'));
   set_item_result(run_stored_sig('CP3_CPADV4'));
   set_item_result(run_stored_sig('CP3_CPADV5'));
   set_item_result(run_stored_sig('CP3_CPADV11'));
   set_item_result(run_stored_sig('CP3_CPADV12'));
end_section;
debug('end section: EBS_CONC_MGR');

debug('begin section: STANDARD_MANAGER');
start_section('EBS Standard Manager Analysis', 'STANDARD_MANAGER');
   IF g_std_mgr = 'STANDARD' and g_enabled = 'Y' and 
(g_rep_info('Apps Version') >= '12.2.4' )  THEN
      set_item_result(run_stored_sig('CP4_STD_MGR_DEFINE_R12'));
   END IF;
   IF g_std_mgr = 'STANDARD' and g_enabled = 'Y' and 
(g_rep_info('Apps Version') < '12.2.4' )  THEN
      set_item_result(run_stored_sig('CP4_STD_MGR_DEFINE_11I'));
   END IF;
   set_item_result(run_stored_sig('CP4_RUN_ALONE_PROGRAMS'));
   set_item_result(run_stored_sig('CP4_STD_MGR_INCL'));
end_section;
debug('end section: STANDARD_MANAGER');

debug('begin section: EBS_CONC_MGR_OPP');
start_section('Output Post Processing Analysis', 'EBS_CONC_MGR_OPP');
   set_item_result(run_stored_sig('CP3_CPADV17'));
   set_item_result(run_stored_sig('CP3_FND_CP_GSM_OPP_AQTBL'));
   set_item_result(run_stored_sig('BIPXDO_CONC_FORCE_LOCAL_OUTPUT_FILE_MODE'));
   set_item_result(run_stored_sig('OPP_PENDING_REQS'));
   set_item_result(run_stored_sig('BIPXDO_BIPXDOZIP_VER'));
   set_item_result(run_stored_sig('CP4_XDO_SETTINGS'));
   set_item_result(run_stored_sig('EBS_ATG_CT_GSM_OPP_PAYLOAD_TYPES'));
   set_item_result(run_stored_sig('EBS_ATG_CT_GSM_OPP_QUEUES'));
   set_item_result(run_stored_sig('EBS_ATG_CT_AQ_TABLE_PAYLOAD_TYPE'));
end_section;
debug('end section: EBS_CONC_MGR_OPP');

debug('begin section: LifetimeSupportPolicy');
start_section('Critical Alerts', 'LifetimeSupportPolicy');
   set_item_result(run_stored_sig('PREMIER_SUPPORT_11.5'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_12.0'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_12.1'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_DB_CHECK_11'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_DB_CHECK_12.1'));
   set_item_result(run_stored_sig('EBS_ATG_ECC_12_2_7'));
   IF (substr(g_rep_info('DB Version'),1,2) >= '12') THEN
      set_item_result(run_stored_sig('EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX'));
      set_item_result(run_stored_sig('EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE'));
   END IF;
   IF (substr(g_rep_info('DB Version'),1,2) < '12') THEN
      set_item_result(run_stored_sig('EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX_BELOW_12C'));
      set_item_result(run_stored_sig('EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE_BELOW_12C'));
   END IF;
end_section;
debug('end section: LifetimeSupportPolicy');

debug('begin section: EBS_ENVIRONMENT_INFORMATION');
start_section('Other Information from The EBS Environment', 'EBS_ENVIRONMENT_INFORMATION');
   set_item_result(run_stored_sig('EBS_ATG_VERSIONS_FROM_SNAPSHOT'));
end_section;
debug('end section: EBS_ENVIRONMENT_INFORMATION');



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
           ,p_min_volume                   IN NUMBER      DEFAULT 3500
           ,p_max_volume                   IN NUMBER      DEFAULT 5000
           ,p_max_output_rows              IN NUMBER      DEFAULT 30
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y'
)
 IS

BEGIN
  g_retcode := 0;
  g_errbuf := null;

   main(
     p_min_volume                   => p_min_volume
    ,p_max_volume                   => p_max_volume
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );


  retcode := g_retcode;
  errbuf  := g_errbuf;
EXCEPTION WHEN OTHERS THEN
  retcode := '2';
  errbuf := 'Error in main_cp: '||sqlerrm||' : '||g_errbuf;
END main_cp;


END fnd_cp_analyzer_pkg;
/
show errors
exit;
-- Exit required for bundling project so do not remove
