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
REM |    psa_data_analyzer.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    SQL to install package used for PSA Data Validation Analyzer           |
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
 if apps_version NOT IN ('12.0','12.1','12.2') then
    dbms_output.put_line('***************************************************************');
    dbms_output.put_line('*** WARNING WARNING WARNING WARNING WARNING WARNING WARNING ***');
    dbms_output.put_line('***************************************************************');
    dbms_output.put_line('*** This instance is eBusiness Suite version '|| apps_version ||'           ');
    dbms_output.put_line('*** This Analyzer script is compatible for following version(s): ');
    dbms_output.put_line('***   12.0,12.1,12.2 ');
    dbms_output.put_line('*** Note: the error below is intentional                    ');
    raise_application_error(-20001, 'ERROR: The script requires eBusiness versions 12.0,12.1,12.2');
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


CREATE OR REPLACE PACKAGE psa_data_analyzer_pkg AUTHID DEFINER AS

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
(            p_invoice_id                   IN NUMBER      DEFAULT NULL
           ,p_max_output_rows              IN NUMBER      DEFAULT 20
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y')
;


PROCEDURE main_cp (
            errbuf                         OUT VARCHAR2
           ,retcode                        OUT VARCHAR2
           ,p_invoice_id                   IN NUMBER      DEFAULT NULL
           ,p_max_output_rows              IN NUMBER      DEFAULT 20
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y'
);

----------------------------------------------------------------
-- Analyzer-specific code: Function and Procedures (Spec)     --
----------------------------------------------------------------



END psa_data_analyzer_pkg;
/
show errors


CREATE OR REPLACE PACKAGE BODY psa_data_analyzer_pkg AS
-- $Id: psa_data_analyzer.sql, 200.52 2026/02/25 11:58:05 sdenye Exp $

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
g_analyzer_doc_id VARCHAR2(15) := TO_CHAR(TRUNC(2086996.1));
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

g_family_area      VARCHAR2(24) := 'EBS Financials';
g_framework_version VARCHAR(240) := '4.8.4';
g_rec_patch_in_dx   VARCHAR2(1) := nvl('A','A'); -- 'A' all rows, change to 'F' for failing rows in DX only
g_g2g_flag          BOOLEAN := nvl('Y','N')='Y'; -- EBSAF-272

g_banner_severity VARCHAR2(1) := 'E';
g_banner_message VARCHAR2(2000) := null;


----------------------------------------------------------------
-- Analyzer-specific code: Global Declarations                --
----------------------------------------------------------------
g_psa_rpc_applied BOOLEAN := true;
g_upg_date_set    BOOLEAN := true;
g_upg_date        DATE;
g_bc_option       VARCHAR2(50);
g_DBbanner        VARCHAR2(255);
g_db_version      V$INSTANCE.VERSION%TYPE;

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

    l_log_file := 'PSADIAGNOSTICS_Analyzer_'||l_db_name||'_'||g_params_string||l_date_char||'.log';
    l_out_file := 'PSADIAGNOSTICS_Analyzer_'||l_db_name||'_'||g_params_string||l_date_char||'.html';
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
    print_out('<TITLE>PSADIAGNOSTICS Analyzer Report</TITLE>');

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
        $("div#feedback").find("a.blacklink").attr("href", "https://mosemp.us.oracle.com/epmos/faces/DocumentDisplay?id=2086996.1#feedback");

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
        <img class="header_version" src="https://www.oracle.com/webfolder/s/analyzer/psa_data_ver.gif" title="Click here to download the latest version of Analyzer" alt="Latest Version Icon"></a>');
    print_cloud_image;
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,568,EBS,EBS Financials,EBS - Payables" target="_blank"><span class="thumb_up_lg" title="Analyzer Feedback: Thumbs Up"></span></a>');
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,568,EBS,EBS Financials,EBS - Payables" target="_blank"><span class="thumb_dn_lg" title="Analyzer Feedback: Thumbs Down"></span></a>');
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},568,EBS,EBS Financials,EBS - Payables" target="_blank"><span class="af_idea_lg" title="Analyzer Idea"></span></a>');
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
    print_out('<div class="menubutton" id="feedback" title="Opens the Oracle Community feedback thread"><a href="https://community.oracle.com/thread/3886076" class="blacklink" target="new">
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
        <span id="feedback-azr">568</span>
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
<div class="ck-content"><p><strong>Version 200.52 </strong>25-Feb-2026</p><ul><li>Signatures updated for indexing and recommended patches</li>
</ul>
<p><strong>Version 200.51 </strong>26-Jan-2026</p><ul><li>Signatures updated to reflect knowledge article IDs</li>
</ul>
<p><strong>Version 200.50 </strong>08-Dec-2025</p><ul><li>Modified template for patch linksnabling you to work more efficiently with your data.</li>
</ul>
</div>

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
            '568'
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
            '568'
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
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,568,'||l_sig.sigrepo_id||',EBS,EBS Financials,EBS - Payables" target="_blank"><span class="thumb_up" title="Signature Feedback: Thumbs Up"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,568,'||l_sig.sigrepo_id||',EBS,EBS Financials,EBS - Payables" target="_blank"><span class="thumb_dn" title="Signature Feedback: Thumbs Down"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_SIGNATURE_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},568,'||l_sig.sigrepo_id||',EBS,EBS Financials,EBS - Payables" target="_blank"><span class="af_idea" title="Signature Idea"></span></a>
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
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,568,'||p_sig.sigrepo_id||',EBS,EBS Financials,EBS - Payables" target="_blank"><span class="thumb_up" title="Signature Feedback: Thumbs Up"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,568,'||p_sig.sigrepo_id||',EBS,EBS Financials,EBS - Payables" target="_blank"><span class="thumb_dn" title="Signature Feedback: Thumbs Down"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_SIGNATURE_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},568,'||p_sig.sigrepo_id||',EBS,EBS Financials,EBS - Payables" target="_blank"><span class="af_idea" title="Signature Idea"></span></a>
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



-------------------------
-- Recommended Patches
-------------------------

FUNCTION check_rec_patches_1 RETURN VARCHAR2 IS
  /* Signature PSA_REC_PATCH */
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

    print_log('Processing recommended patches signature: PSA_REC_PATCH (check_rec_patches_1) "PSA Recommended Patch Collection (RPC)" (version 12)');

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
   l_col_rows(1)(l_rows) := '22850140';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.2: Public Sector Financials Recommended Patch Collection (RPC), Mar 2016';
   l_col_rows(5)(l_rows) := NULL;

END IF;

IF substr(g_rep_info('Apps Version'),1,4) = '12.1' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22850140';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.1: Public Sector Financials Recommended Patch Collection (RPC), Mar 2016';
   l_col_rows(5)(l_rows) := NULL;

END IF;

IF substr(g_rep_info('Apps Version'),1,4) = '12.0' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22850140';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.0: Public Sector Financials Recommended Patch Collection (RPC), Mar 2016';
   l_col_rows(5)(l_rows) := NULL;

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '2924';
   l_sig.title := 'PSA Recommended Patch Collection (RPC)';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := 'Please check if any of the recommended patches were not applied in this instance.';
   l_sig.solution := '<ul><li>Please review list above and schedule to apply any unappplied patches as soon as possible</li><li>Refer to the note indicated for more information about each patch</li></ul>
<br/>
For the most current recommendations, use the Patch Wizard or the Updates & Patches Tab in My Oracle Support.<br>
Further guidance can be found in the following documents:<br>
<ul>
<li>[11086538/KA747] How to Find EBS Patches and EBS Technology Patches</li>
<li>[976188/KB739927] R11i / R12 : Patch Wizard Utility</li>
<li>[10940175/KA580] Patch Wizard FAQ</li>
</ul>
Best Practice: Always ensure that you are on the latest code with all recommended patches applied. <br/>
This will help avoid known issues, prevent potential data corruption and provide the latest features and functionality. Having a proactive patching plan and periodic proactive patching process in place are the best ways to stay current.';
   l_sig.success_msg := 'The latest Public Sector Financials (PSA) Recommended Patch Collection (RPC) has been applied.';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'N';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='Y';
   l_sig.version := '12';

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
  g_signatures('PSA_REC_PATCH') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'PSA_REC_PATCH',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_1 at step '||l_step);
  raise;
END check_rec_patches_1;

FUNCTION check_rec_patches_2 RETURN VARCHAR2 IS
  /* Signature PSA_RELATED_REC_PATCHES */
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

    print_log('Processing recommended patches signature: PSA_RELATED_REC_PATCHES (check_rec_patches_2) "PSA Related Product Recommended Patches" (version 11)');

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
   l_col_rows(1)(l_rows) := '22536210';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.2: Payables Patch for the Latest View Extracts';
   l_col_rows(5)(l_rows) := '[1055606/KB633271]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22117915';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.2: Payables Patch for the Latest Application Accounting Definitions';
   l_col_rows(5)(l_rows) := '[1055606/KB633271]';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '17813590';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.2: Payables Patch  to Allow Prepayment Unapplication for 11i Invoices';
   l_col_rows(5)(l_rows) := '[1055606/KB633271]';

END IF;

IF substr(g_rep_info('Apps Version'),1,4) = '12.1' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22042663';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Post AUG15 Payables RPC One-off for Latest Application Accounting Definitions';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21340722';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.1: Subledger Accounting Recommended Patch Collection - AUG 2015';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21261629';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'R12.1: Payables Recommended Patch Collection (CORE AP-AUG 2015))';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '18947348';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Post AUG15 Payables RPC One-off for Key Accounting Entity Views';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '14082924';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Consolidated GDF Pre-Req Patch - Includes all undo related fixes from AP and SLA';
   l_col_rows(5)(l_rows) := NULL;

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '2925';
   l_sig.title := 'PSA Related Product Recommended Patches';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := 'Please check if any of the recommended patches were not applied in this instance.';
   l_sig.solution := '<ul><li>Please review list above and schedule to apply any unappplied patches as soon as possible</li><li>Refer to the note indicated for more information about each patch</li></ul>
<br/>
For the most current recommendations, use the Patch Wizard or the Updates & Patches Tab in My Oracle Support.<br>
Further guidance can be found in the following documents:<br>
<ul>
<li>[11086538/KA747] How to Find EBS Patches and EBS Technology Patches</li>
<li>[976188/KB739927] R11i / R12 : Patch Wizard Utility</li>
<li>[10940175/KA580] Patch Wizard FAQ</li>
</ul>
Best Practice: Always ensure that you are on the latest code with all recommended patches applied. 
This will help avoid known issues, prevent potential data corruption and provide the latest features and functionality. Having a proactive patching plan and periodic proactive patching process in place are the best ways to stay current.';
   l_sig.success_msg := 'The latest Public Sector Financials (PSA) Related Product Recommended Patches have been applied.';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'N';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='Y';
   l_sig.version := '11';

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
  g_signatures('PSA_RELATED_REC_PATCHES') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'PSA_RELATED_REC_PATCHES',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_2 at step '||l_step);
  raise;
END check_rec_patches_2;

FUNCTION check_rec_patches_3 RETURN VARCHAR2 IS
  /* Signature AP_RPC_PATCHES */
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

    print_log('Processing recommended patches signature: AP_RPC_PATCHES (check_rec_patches_3) "AP Recommended Patch Collection (RPC)" (version 28)');

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

IF substr(g_rep_info('Apps Version'),1,4) = '12.0' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '8649286';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Payables Critical Patch Collection July 2009';
   l_col_rows(5)(l_rows) := NULL;

END IF;

IF substr(g_rep_info('Apps Version'),1,4) = '12.1' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22384200';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Core AP February 2016';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22350639';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Payments February 2016';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '20178726';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Purchase Card/Workflow August 2015';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21340722';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Subledger Accounting August 2015';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22453253';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'E-Business Tax February 2016';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21261663';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'ISP/Suppliers August 2015';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22644544';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Oracle E-Business Suite Release 12.1.3+ Recommended Patch Collection 5';
   l_col_rows(5)(l_rows) := '[2152266/KB196540]';

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '4503';
   l_sig.title := 'AP Recommended Patch Collection (RPC)';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := 'Some recommended RPC patches were not applied in this instance.';
   l_sig.solution := 'Please review list by clicking on "Latest Payables Recommended Patch Collection (RPC)" above and schedule to apply any unapplied patches as soon as possible.<br>
<b>The Recommended Patch Collections (RPCs) include very important fixes for Oracle Payables and Payments applications.</b><br><br>
Above are the recommended patches for this product area.  For the most current recommendations, use the Patch Wizard or the Updates & Patches Tab in My Oracle Support.  Further guidance can be found in the following documents:
<ul>
<li>[11086538/KA747] How to Find EBS Patches and EBS Technology Patches</li>
<li>[976188/KB739927] Patch Wizard Utility</li>
<li>[10940175/KA580] Patch Wizard FAQ</li>
</ul>
Best Practice:  Always ensure that you are on the latest code with all recommended patches applied. This will help avoid known issues, prevent potential data corruption and provide the latest features and functionality. Having a proactive patching plan and periodic proactive patching process in place are the best ways to stay current.';
   l_sig.success_msg := 'All latest RPC patches applied.';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'N';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='Y';
   l_sig.version := '28';

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
  g_signatures('AP_RPC_PATCHES') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'AP_RPC_PATCHES',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_3 at step '||l_step);
  raise;
END check_rec_patches_3;

FUNCTION check_rec_patches_4 RETURN VARCHAR2 IS
  /* Signature AP_RUP_PATCHES */
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

    print_log('Processing recommended patches signature: AP_RUP_PATCHES (check_rec_patches_4) "AP Release Update Pack (RUP)" (version 4)');

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

IF substr(g_rep_info('Apps Version'),1,6) = '12.2.4' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '17919161';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Oracle E-Business Suite 12.2.4 Release Update Pack';
   l_col_rows(5)(l_rows) := '[1903217/KB772454]';

END IF;

IF substr(g_rep_info('Apps Version'),1,6) = '12.2.5' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '19676458';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Oracle E-Business Suite 12.2.5 Release Update Pack';
   l_col_rows(5)(l_rows) := '[2049015/KB203504]';

END IF;

IF substr(g_rep_info('Apps Version'),1,6) = '12.2.6' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '21900901';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Oracle E-Business Suite 12.2.6 Release Update Pack';
   l_col_rows(5)(l_rows) := '[2114173/KB203522]';

END IF;

IF substr(g_rep_info('Apps Version'),1,6) = '12.2.7' THEN
   l_rel := 'R12';

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '24690690';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'Oracle E-Business Suite 12.2.7 Release Update Pack';
   l_col_rows(5)(l_rows) := '[2243855/KB203604]';

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '22260';
   l_sig.title := 'AP Release Update Pack (RUP)';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := 'Latest Payables Release Update Pack (RUP) is not applied in this instance.';
   l_sig.solution := 'Please review list by clicking on "Latest Payables Release Update Pack (RUP)" above and schedule to apply any unapplied patches as soon as possible.<br>
<b> For the most current recommendations, use the Patch Wizard or the Updates & Patches Tab in My Oracle Support.  Further guidance can be found in the following documents:
<ul>
<li>[11086538/KA747] How to Find EBS Patches and EBS Technology Patches</li>
<li>[976188/KB739927] Patch Wizard Utility</li>
<li>[10940175/KA580] Patch Wizard FAQ</li>
</ul>
Best Practice:  Always ensure that you are on the latest code to help avoid known issues, prevent potential data corruption and provide the latest features and functionality. ';
   l_sig.success_msg := 'Latest RUP patch applied.';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'N';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='Y';
   l_sig.version := '4';

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
  g_signatures('AP_RUP_PATCHES') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'AP_RUP_PATCHES',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_4 at step '||l_step);
  raise;
END check_rec_patches_4;

FUNCTION check_rec_patches_5 RETURN VARCHAR2 IS
  /* Signature EBTAX_check_rec_patches */
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

    print_log('Processing recommended patches signature: EBTAX_check_rec_patches (check_rec_patches_5) "EBTax Related Product Recommended Patches" (version 11)');

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
   l_col_rows(1)(l_rows) := '22458196';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'NEW! R12.1: E-Business Tax Reporting Ledger Recommended Patch Collection (ZX), Feb 2016';
   l_col_rows(5)(l_rows) := NULL;

   l_rows := l_rows + 1;
   l_rel_rows(1)(l_rows) := l_rel;
   l_col_rows(1)(l_rows) := '22453253';
   l_col_rows(2)(l_rows) := 'No';
   l_col_rows(3)(l_rows) := NULL;
   l_col_rows(4)(l_rows) := 'NEW! R12.1: E-Business Tax Recommended Patch Collection (ZX RPC), Feb 2016';
   l_col_rows(5)(l_rows) := NULL;

END IF;

   l_extra_info('##SHOW_SQL##'):= 'Y';

   l_sig.sigrepo_id := '1680';
   l_sig.title := 'EBTax Related Product Recommended Patches';
   l_sig.fail_condition := '[Applied] = [No]';
   l_sig.problem_descr := 'You have recommended patch(es) not applied to this environment. Please expand the list above for the details.';
   l_sig.solution := 'Above are the recommended patches for this product area.  For the most current recommendations, use the Patch Wizard or the Updates & Patches Tab in My Oracle Support.  Further guidance can be found in the following documents:
<ul>
<li>[11086538/KA747] How to Find EBS Patches and EBS Technology Patches</li>
<li>[976188/KB739927] Patch Wizard Utility</li>
<li>[10940175/KA580] Patch Wizard FAQ</li>
</ul>';
   l_sig.success_msg := 'All related RPC patches applied.
';
   l_sig.print_condition := 'ALWAYS';
   l_sig.fail_type := 'W';
   l_sig.print_sql_output := 'Y';
   l_sig.limit_rows := 'Y';
   l_sig.extra_info := l_extra_info;
   l_sig.include_in_xml :='Y';
   l_sig.version := '11';

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
  g_signatures('EBTAX_check_rec_patches') := l_sig;

  --Render
  l_step := '70';
  RETURN process_signature_results(
    'EBTAX_check_rec_patches',     -- sig ID
    l_sig,                              -- signature information
    l_col_rows,                         -- data
    l_hdr);                             -- headers

EXCEPTION WHEN OTHERS THEN
  print_log('Error in check_rec_patches_5 at step '||l_step);
  raise;
END check_rec_patches_5;




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
            p_invoice_id                   IN NUMBER      DEFAULT NULL
           ,p_max_output_rows              IN NUMBER      DEFAULT 20
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
l_org_id NUMBER;
l_DBbanner VARCHAR2(255);
p_transaction_id NUMBER;





BEGIN

  l_step := '1';

  print_log(analyzer_title || ' Log File');
  print_log('***************************************************************');

  -- Create global hash for parameters. Numbers required for the output order
debug('begin populate parameters hash table');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Invoice ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_invoice_id,'NO_MASK');
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
  l_revision := rtrim(replace('$Revision: 200.52  $','$',''));
  l_revision := ltrim(replace(l_revision,'Revision:',''));
  l_date_char := rtrim(replace('$Date: 2026/02/25 11:58:03 $','$',''));
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
  g_rep_info('File Name') := 'psa_data_analyzer.sql';
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

debug('begin parameter validation: p_invoice_id');
IF p_invoice_id IS NULL THEN
   print_error('INVALID ARGUMENT: Parameter Invoice ID is required.');
   raise invalid_parameters;
END IF;
IF p_invoice_id IS NOT NULL THEN
BEGIN
SELECT INV.INVOICE_ID
INTO l_exists_val
FROM AP_INVOICES_ALL INV, HR_OPERATING_UNITS OU
WHERE INV.INVOICE_ID = p_invoice_id
 AND ou.organization_id = inv.org_id
AND (mo_global.is_mo_init_done = 'N' or mo_global.check_access(inv.org_id) = 'Y')
 and rownum < 2;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
   print_error('INVALID ARGUMENT: The invoice ID provided is invalid.');
   raise invalid_parameters;
   WHEN OTHERS THEN
   print_error('INVALID ARGUMENT: Validation query for p_invoice_id failed with '||sqlerrm||'.');
   raise invalid_parameters;
END;
END IF;
debug('end parameter validation: p_invoice_id');


debug('begin parameter validation: p_debug_mode');
IF p_debug_mode IS NOT NULL AND p_debug_mode NOT IN ( 'N','Y') THEN
   print_error('INVALID ARGUMENT: Debug Mode is invalid.  Valid values are Y or N');
   raise invalid_parameters;
END IF;
debug('end parameter validation: p_debug_mode');



-- Validation to verify analyzer is run on proper e-Business application version
-- In case validation at the beginning is updated/removed, adding validation here also so execution fails

  IF substr(l_apps_version,1,4) NOT IN ('12.0','12.1','12.2') THEN
    print_log('eBusiness Suite version = '||l_apps_version);
    print_log('ERROR: This Analyzer script is compatible for following version(s): 12.0,12.1,12.2');
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
SELECT org_id INTO l_org_id
FROM ap_invoices_all
WHERE invoice_id = p_invoice_id;

g_db_version    := l_dbversion;
select CASE 
WHEN g_db_version > '18'
THEN 'banner_full'
Else 'banner'
END into l_DBbanner from dual where rownum=1;
g_DBbanner := l_DBbanner;

BEGIN
  g_upg_date := to_date(fnd_profile.value_wnps('PSA_R12_UPGRADE_DATE'),'MM/DD/YYYY HH24:MI:SS');
EXCEPTION WHEN OTHERS THEN
  g_upg_date := null;
  debug('Error getting value for profile PSA_R12_UPGRADE_DATE: '||sqlerrm);
END;

BEGIN
  g_bc_option := fnd_profile.value('BUDGETARY_CONTROL_OPTION');
EXCEPTION WHEN OTHERS THEN
  g_bc_option := null;
  debug('Error getting value for profile BUDGETARY_CONTROL_OPTION: '||sqlerrm);
END;

IF g_upg_date is null THEN
  g_upg_date_set := false;
END IF;




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
            g_banner_message := 'The database version running on this instance is in Sustaining Support. Please refer to Oracle''s Lifetime Support Policy in [2655839.2#supportp].<br>Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 2 then
            -- Application Version 11.5
            g_banner_severity := 'W';
            g_banner_message := 'Premier Support for the application version on this instance ended on November 2010. Please refer to Oracle''s Lifetime Support Policy in [2655839.2#supportp].<br> Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 3 then
            -- Application Version 12.1
            g_banner_severity := 'W';
            g_banner_message := 'Premier Support End for the application version on this instance is on December 2021. Please refer to Oracle''s Lifetime Support Policy in [2655839.2#supportp]. <br>Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 4 then
            -- Database in Extended Support
            g_banner_severity := 'W';
            g_banner_message := 'The database version running on this instance is in Extended Support. Please refer to Oracle''s Lifetime Support Policy in [2655839.2#supportp].<br>Ignore this warning if you have upgraded since this analyzer output was generated.';
        when 5 then
            -- Application Version 12.0
            g_banner_severity := 'W';
            g_banner_message := 'Premier Support for the application version on this instance ended on January 2012. Please refer to Oracle''s Lifetime Support Policy in [2655839.2#supportp].<br>Ignore this warning if you have upgraded since this analyzer output was generated.';
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
   g_parameters(g_parameters.LAST).pname := 'Invoice ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_invoice_id,'NO_MASK');
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
   g_sql_tokens('##$$INV$$##') := p_invoice_id;
   g_masked_tokens('##$$INV$$##') := mask_text( g_sql_tokens('##$$INV$$##'), 'NO_MASK');
   g_sql_tokens('##$$ORG$$##') := l_org_id;
   g_masked_tokens('##$$ORG$$##') := mask_text( g_sql_tokens('##$$ORG$$##'), 'NO_MASK');
   g_sql_tokens('##$$UPGDATE$$##') := to_char(g_upg_date, 'MM/DD/YYYY HH24:MI:SS');
   g_masked_tokens('##$$UPGDATE$$##') := mask_text( g_sql_tokens('##$$UPGDATE$$##'), 'NO_MASK');
   g_sql_tokens('##$$BCOPT$$##') := g_bc_option;
   g_masked_tokens('##$$BCOPT$$##') := mask_text( g_sql_tokens('##$$BCOPT$$##'), 'NO_MASK');
   g_sql_tokens('##$$VALID_ORGS$$##') := 'select organization_id from hr_operating_units where (mo_global.is_mo_init_done = ''N'' or mo_global.check_access(organization_id) = ''Y'')';
   g_masked_tokens('##$$VALID_ORGS$$##') := mask_text( g_sql_tokens('##$$VALID_ORGS$$##'), 'NO_MASK');
   g_sql_tokens('##$$IVIEW$$##') := 'SELECT DISTINCT d.invoice_id, d.invoice_distribution_id '||' FROM ap_invoice_distributions_all d '||' 
WHERE d.invoice_id ='||nvl(p_invoice_id,-99)||'';
   g_masked_tokens('##$$IVIEW$$##') := mask_text( g_sql_tokens('##$$IVIEW$$##'), 'NO_MASK');
   g_sql_tokens('##$$HEADERID$$##') := 'select poh.po_header_id  '||' 
from po_headers_all poh, po_distributions_all pod, AP_INVOICE_DISTRIBUTIONS_ALL apd  '||' 
where pod.po_distribution_id = apd.PO_DISTRIBUTION_ID   '||' 
and poh.PO_HEADER_ID = POD.PO_HEADER_ID  '||' 
and pod.po_distribution_id in  '||' 
( '||' select apd.PO_DISTRIBUTION_ID  '||' from AP_INVOICE_DISTRIBUTIONS_ALL apd  '||' where apd.invoice_id = '||nvl(p_invoice_id,-99)||')';
   g_masked_tokens('##$$HEADERID$$##') := mask_text( g_sql_tokens('##$$HEADERID$$##'), 'NO_MASK');
   g_sql_tokens('##$$ICVIEW$$##') := 'SELECT DISTINCT d.invoice_id '||' FROM ap_invoices_all d '||' WHERE d.invoice_id = '||nvl(p_invoice_id,-99)||'';
   g_masked_tokens('##$$ICVIEW$$##') := mask_text( g_sql_tokens('##$$ICVIEW$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM1$$##') := '200';
   g_masked_tokens('##$$APPS_PARAM1$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM1$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM2$$##') := '235';
   g_masked_tokens('##$$APPS_PARAM2$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM2$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM3$$##') := '602';
   g_masked_tokens('##$$APPS_PARAM3$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM3$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM4$$##') := '673';
   g_masked_tokens('##$$APPS_PARAM4$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM4$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM5$$##') := '201';
   g_masked_tokens('##$$APPS_PARAM5$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM5$$##'), 'NO_MASK');
   g_sql_tokens('##$$INVID$$##') := p_invoice_id;
   g_masked_tokens('##$$INVID$$##') := mask_text( g_sql_tokens('##$$INVID$$##'), 'NO_MASK');
   g_sql_tokens('##$$INVS$$##') := 'SELECT DISTINCT d.invoice_id '||' FROM ap_invoices_all d '||' WHERE d.invoice_id = '||nvl(p_transaction_id,-99)||'';
   g_masked_tokens('##$$INVS$$##') := mask_text( g_sql_tokens('##$$INVS$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM6$$##') := '8901';
   g_masked_tokens('##$$APPS_PARAM6$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM6$$##'), 'NO_MASK');
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


debug('begin add_signature: PSA_BUD_CTRL_OPTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2926',
      p_sig_id                 => 'PSA_BUD_CTRL_OPTIONS',
      p_sig_sql                => 'SELECT b.bc_option_name,
       b.description,
       d.je_source_name,
       d.je_category_name,
       decode(d.funds_check_level_code,
         ''B'',''Absolute'',
         ''N'',''None'',
         ''D'',''Advisory'') Funds_Check_Level,
       d.override_amount,
       d.tolerance_percentage,
       d.tolerance_amount,
       b.attribute15
FROM gl_bc_option_details d,
     gl_bc_options b
WHERE b.bc_option_id = d.bc_option_id
AND b.bc_option_id = fnd_profile.value(''BUDGETARY_CONTROL_OPTION'')',
      p_title                  => 'Budgetary Control Options',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Budgetary Control Options - None found.',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: PSA_BUD_CTRL_OPTIONS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_PSA_LEDGER_CONTROLS_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##LEDGER_NAME'):= ',,#F5F6CE,bold';
  add_signature(
      p_sig_repo_id            => '28503',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_PSA_LEDGER_CONTROLS_CHECK',
      p_sig_sql                => 'SELECT DISTINCT
    pot.user_profile_option_name   profile_name,
    decode(a.level_id, 10003, c.responsibility_name) responsibility_name,
    decode(funds_check_level_code, ''N'', ''None'', ''B'', ''Absolute'',
           ''D'', ''Advisory'')  fund_check_level
FROM
    fnd_responsibility_tl      c,
    fnd_profile_option_values  a,
    fnd_profile_options        b,
    fnd_profile_options_tl     pot,
    gl_bc_option_details       gbc,
    gl_je_categories_tl        gje
WHERE
        1 = 1
    AND pot.user_profile_option_name = ''Budgetary Control Group''
    AND a.level_id = 10003
    AND pot.profile_option_name = b.profile_option_name
    AND b.application_id = a.application_id (+)
    AND b.profile_option_id = a.profile_option_id (+)
    AND a.level_value = c.responsibility_id (+)
    AND pot.language = ''US''
    AND je_source_name = ''Payables''
    AND gbc.je_category_name = gje.je_category_name
    AND user_je_category_name = ''Payables - All''
    AND decode(a.profile_option_value, ''1'', ''1 (may be "Yes")'', ''2'', ''2 (may be "No")'',
               a.profile_option_value) = bc_option_id
    AND c.application_id = 200
--  AND funds_check_level_code=''N''  /*(Always want to print the value but now just highlight when it''s wrong)*/
ORDER BY
    profile_name',
      p_title                  => 'GL Budgetary Control Setup for AP',
      p_fail_condition         => '[FUND_CHECK_LEVEL]=[None]',
      p_problem_descr          => 'Incorrect Budgetary Control Setup in General Ledger for Payables ',
      p_solution               => 'Please review [2827893/KB720516] and if the issue is still not resolved, please log an SR/bug with the Payables team.',
      p_success_msg            => 'Budgetary Control Setup in General Ledger for Payables is OK',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_PSA_LEDGER_CONTROLS_CHECK');



debug('begin add_signature: PSA_BUD_CTRL_ENABLED_JLD');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2929',
      p_sig_id                 => 'PSA_BUD_CTRL_ENABLED_JLD',
      p_sig_sql                => 'SELECT ja.*
FROM gl_ledgers l,
     xla_acctg_method_rules r,
     xla_product_rules_vl a,
     xla_prod_acct_headers e,
     xla_aad_line_defn_assgns la,
     xla_line_definitions_vl ld,
     xla_line_defn_jlt_assgns ja,
     ap_invoices_all ap
WHERE l.ledger_id=ap.set_of_books_id
AND   ap.invoice_id in (##$$INV$$##)
AND   l.sla_accounting_method_type = r.accounting_method_type_code
AND   l.sla_accounting_method_code = r.accounting_method_code
AND   r.application_id = 200
AND   a.application_id = r.application_id
AND   r.product_rule_type_code = a.product_rule_type_code
AND   r.product_rule_code = a.product_rule_code
AND   r.product_rule_type_code = e.product_rule_type_code
AND   r.product_rule_code = e.product_rule_code
AND   r.product_rule_type_code = la.product_rule_type_code
AND   r.product_rule_code = la.product_rule_code
AND   e.event_class_code = la.event_class_code
AND   e.event_type_code = la.event_type_code
AND   la.line_definition_owner_code = ld.line_definition_owner_code
AND   la.line_definition_code = ld.line_definition_code
AND   la.event_class_code = ld.event_class_code
AND   la.event_type_code = ld.event_type_code
AND   ld.line_definition_owner_code = ja.line_definition_owner_code
AND   ld.line_definition_code = ja.line_definition_code
AND   ld.event_class_code = ja.event_class_code
AND   ld.event_type_code = ja.event_type_code
AND   ld.enabled_flag =''Y''
AND   ld.budgetary_control_flag = ''Y''',
      p_title                  => 'Budgetary Control Enabled Journal Line Definitions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Budgetary Control Enabled Journal Line Definitions - None found.',
      p_solution               => 'Follow the steps detailed in [2912164/KB637260].',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: PSA_BUD_CTRL_ENABLED_JLD');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_LEDGER_ACCT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24961',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_LEDGER_ACCT',
      p_sig_sql                => 'SELECT DISTINCT gl.*
FROM ap_invoices_all ai
	,gl_ledgers gl
	,gl_ledger_relationships glr1
	,gl_ledger_relationships glr2
	,gl_ledger_relationships glr3
WHERE glr3.source_ledger_id = ai.set_of_books_id
	AND ai.invoice_id in (##$$INV$$##)
	AND glr3.source_ledger_id = glr2.primary_ledger_id
	AND glr2.target_ledger_id = glr1.primary_ledger_id
	AND gl.ledger_id = glr1.source_ledger_id
ORDER BY gl.ledger_id',
      p_title                  => 'Ledger and Accounting Setup',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Ledger and Accounting Setup',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_LEDGER_ACCT');



debug('begin add_signature: PSA_LEDGER_DEFINITIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2927',
      p_sig_id                 => 'PSA_LEDGER_DEFINITIONS',
      p_sig_sql                => 'SELECT DISTINCT gl.*
FROM ap_invoices_all         ai,
     gl_ledgers              gl,
     gl_ledger_relationships glr1,
     gl_ledger_relationships glr2,
     gl_ledger_relationships glr3
WHERE glr3.source_ledger_id = ai.set_of_books_id
AND   ai.invoice_id in (##$$INV$$##)
AND   glr3.source_ledger_id = glr2.primary_ledger_id
AND   glr2.target_ledger_id = glr1.primary_ledger_id
AND   gl.ledger_id = glr1.source_ledger_id
ORDER BY gl.ledger_id',
      p_title                  => 'Ledger Definitions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Ledger Definitions - None found.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: PSA_LEDGER_DEFINITIONS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_AAD_SLAM');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24962',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_AAD_SLAM',
      p_sig_sql                => 'SELECT am.accounting_method_type_code
	,am.accounting_method_type_dsp
	,am.accounting_method_code
	,am.name
	,am.enabled_flag
	,af.application_id
	,af.application_name
	,af.amb_context_code
	,af.product_rule_code
	,af.product_rule_type_code
	,af.product_rule_name
	,af.product_rule_type_dsp
	,af.start_date_active
	,af.end_date_active
	,af.created_by
	,af.creation_date
	,af.last_updated_by
	,af.last_update_date
	,a.compile_status_code
FROM xla_acctg_methods_fvl am
	,xla_acctg_method_rules_fvl af
	,xla_product_rules_vl a
WHERE (
		am.accounting_method_code
		,am.accounting_method_type_code
		) IN (
		SELECT gl.sla_accounting_method_code
			,gl.sla_accounting_method_type
		FROM ap_invoices_all ai
			,gl_ledgers gl
			,gl_ledger_relationships glr1
			,gl_ledger_relationships glr2
			,gl_ledger_relationships glr3
		WHERE glr3.source_ledger_id = ai.set_of_books_id
			AND ai.invoice_id IN (##$$INV$$##)
			AND glr3.source_ledger_id = glr2.primary_ledger_id
			AND glr2.target_ledger_id = glr1.primary_ledger_id
			AND gl.ledger_id = glr1.source_ledger_id
		)
	AND am.accounting_method_type_code = af.accounting_method_type_code
	AND am.accounting_method_code = af.accounting_method_code
	AND a.application_id = af.application_id
	AND a.product_rule_type_code = af.product_rule_type_code
	AND a.product_rule_code = af.product_rule_code
ORDER BY am.accounting_method_code
	,af.application_id',
      p_title                  => 'AAD associated with Ledgers SLAM',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'AAD associated with Ledgers SLAM',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_AAD_SLAM');



debug('begin add_signature: PSA_AAD_DEFINITIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2928',
      p_sig_id                 => 'PSA_AAD_DEFINITIONS',
      p_sig_sql                => 'SELECT am.accounting_method_type_code,
       am.accounting_method_type_dsp,
       am.accounting_method_code,
       am.name,
       am.enabled_flag,
       af.application_id,
       af.application_name,
       af.amb_context_code,
       af.product_rule_code,
       af.product_rule_type_code,
       af.product_rule_name,
       af.product_rule_type_dsp,
       af.start_date_active,
       af.end_date_active,
       af.created_by,
       af.creation_date,
       af.last_updated_by,
       af.last_update_date,
       a.compile_status_code
FROM xla_acctg_methods_fvl      am,
     xla_acctg_method_rules_fvl af,
     xla_product_rules_vl       a
WHERE af.application_id = 200
AND   (am.accounting_method_code, am.accounting_method_type_code) IN (
        SELECT gl.sla_accounting_method_code,
               gl.sla_accounting_method_type
        FROM ap_invoices_all ai,
             gl_ledgers gl,
             gl_ledger_relationships glr1,
             gl_ledger_relationships glr2,
             gl_ledger_relationships glr3
        WHERE glr3.source_ledger_id = ai.set_of_books_id
        AND   ai.invoice_id in (##$$INV$$##)
        AND   glr3.source_ledger_id = glr2.primary_ledger_id
        AND   glr2.target_ledger_id = glr1.primary_ledger_id
        AND   gl.ledger_id = glr1.source_ledger_id)
AND   am.accounting_method_type_code = af.accounting_method_type_code
AND   am.accounting_method_code = af.accounting_method_code
AND   a.application_id = af.application_id
AND   a.product_rule_type_code = af.product_rule_type_code
AND   a.product_rule_code = af.product_rule_code
ORDER BY am.accounting_method_code',
      p_title                  => 'Accounting Definitions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Accounting Definitions - None found.',
      p_solution               => 'Follow the steps detailed Section 2.2) Subledger Information - Application Accounting Definition Information [1053172/KB559267].',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: PSA_AAD_DEFINITIONS');



debug('begin add_signature: PSA_GEN_INVALID_AAD');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2948',
      p_sig_id                 => 'PSA_GEN_INVALID_AAD',
      p_sig_sql                => 'SELECT l.name ledger_name,
       l.ledger_id,
       o.owner,
       o.object_name,
       o.object_id,
       o.status,
       o.last_ddl_time,
       o.timestamp,
       am.accounting_method_code,
       am.name accounting_method_name,
       am.enabled_flag accounting_method_enabled,
       pr.product_rule_code aad,
       pr.name aad_name,
       pr.enabled_flag aad_enabled_flag,
       pr.compile_status_code aad_compile_status,
       pr.product_rule_type_code,
       pr.product_rule_hash_id
FROM ap_system_parameters_all sp,
     gl_ledgers l,
     xla_acctg_methods_vl am,
     xla_acctg_method_rules aad,
     xla_product_rules_vl pr,
     dba_objects o
WHERE sp.org_id IN (##$$ORG$$##)
AND   o.owner = ''APPS''
AND   o.object_type = ''PACKAGE BODY''
AND   o.object_name like ''XLA_00200_AAD%''||pr.product_rule_hash_id||''%PKG''
AND   o.status = ''INVALID''
AND   l.ledger_id = sp.set_of_books_id
AND   am.accounting_method_type_code = l.sla_accounting_method_type
AND   am.accounting_method_code = l.sla_accounting_method_code
AND   aad.application_id = 200
AND   aad.accounting_method_code = am.accounting_method_code
AND   aad.accounting_method_type_code = am.accounting_method_type_code
AND   pr.application_id = aad.application_id
AND   pr.amb_context_code = aad.amb_context_code
AND   pr.product_rule_type_code = aad.product_rule_type_code
AND   pr.product_rule_code = aad.product_rule_code
ORDER BY l.ledger_id',
      p_title                  => 'Invalid Application Accounting Definitions',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Invalid Application Accounting Definitions (AAD) exist for the indicated ledgers.  A valid Payables AAD is required to create Payables accounting for a ledger.',
      p_solution               => 'Run the Validate Application Accounting definition program to validate the AAD.  Review the report output and investigate/resolve any invalids.  See [601318/KB662778] for details on running and investigating/resolving invalid AAD errors.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: PSA_GEN_INVALID_AAD');



debug('begin add_signature: PSA_CUSTOM_JLT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2930',
      p_sig_id                 => 'PSA_CUSTOM_JLT',
      p_sig_sql                => 'SELECT ja.*
FROM gl_ledgers l,
     xla_acctg_method_rules r,
     xla_product_rules_vl a,
     xla_prod_acct_headers e,
     xla_aad_line_defn_assgns la,
     xla_line_definitions_vl ld,
     xla_line_defn_jlt_assgns ja,
     ap_invoices_all ap
WHERE l.ledger_id=ap.set_of_books_id
AND   ap.invoice_id in (##$$INV$$##)
AND   l.sla_accounting_method_type = r.accounting_method_type_code
AND   l.sla_accounting_method_code = r.accounting_method_code
AND   r.application_id = 200
AND   a.application_id = r.application_id
AND   r.product_rule_type_code = a.product_rule_type_code
AND   r.product_rule_code = a.product_rule_code
AND   r.product_rule_type_code = e.product_rule_type_code
AND   r.product_rule_code = e.product_rule_code
AND   r.product_rule_type_code = la.product_rule_type_code
AND   r.product_rule_code = la.product_rule_code
AND   e.event_class_code = la.event_class_code
AND   e.event_type_code = la.event_type_code
AND   la.line_definition_owner_code = ld.line_definition_owner_code
AND   la.line_definition_code = ld.line_definition_code
AND   la.event_class_code = ld.event_class_code
AND   la.event_type_code = ld.event_type_code
AND   ld.line_definition_owner_code = ja.line_definition_owner_code
AND   ld.line_definition_code = ja.line_definition_code
AND   ld.event_class_code = ja.event_class_code
AND   ld.event_type_code = ja.event_type_code
AND   ld.enabled_flag = ''Y''
AND   ld.budgetary_control_flag = ''Y''
AND   ja.LINE_DEFINITION_CODE = ''C''',
      p_title                  => 'Custom Journal Line Types (JLT)',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Custom Journal Line Types detected',
      p_solution               => 'Review [1612433/KB355910] and verify Custom Journal Line Types (JLT) are not causing the issue ',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: PSA_CUSTOM_JLT');



debug('begin add_signature: PSA_SETUP_BC_OPTIONS_EXIST');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3093',
      p_sig_id                 => 'PSA_SETUP_BC_OPTIONS_EXIST',
      p_sig_sql                => 'WITH ranges AS (
  SELECT ar.range_id,
         ar.budget_entity_id,
         be.name
  FROM gl_budget_assignment_ranges ar,
       gl_code_combinations cc,
       gl_budget_entities be,
       ap_invoices_all ai
  WHERE cc.code_combination_id IN (
          SELECT apd.dist_code_combination_id FROM ap_invoice_distributions_all apd
          WHERE apd.invoice_id in (##$$INV$$##)
          AND   line_type_lookup_code != ''REC_TAX'')
  AND   ai.invoice_id in (##$$INV$$##)
  AND   ar.ledger_id = ai.set_of_books_id
  AND   ar.currency_code = ai.invoice_currency_code
  AND   ar.budget_entity_id = be.budget_entity_id
  AND   (nvl(cc.segment1, -99) BETWEEN
           nvl(ar.segment1_low, -99) AND nvl(ar.segment1_high, -99))
  AND   (nvl(cc.segment2, -99) BETWEEN
           nvl(ar.segment2_low, -99) AND nvl(ar.segment2_high, -99))
  AND   (nvl(cc.segment3, -99) BETWEEN
           nvl(ar.segment3_low, -99) AND nvl(ar.segment3_high, -99))
  AND   (nvl(cc.segment4, -99) BETWEEN
           nvl(ar.segment4_low, -99) AND nvl(ar.segment4_high, -99))
  AND   (nvl(cc.segment5, -99) BETWEEN
           nvl(ar.segment5_low, -99) AND nvl(ar.segment5_high, -99))
  AND   (nvl(cc.segment6, -99) BETWEEN
           nvl(ar.segment6_low, -99) AND nvl(ar.segment6_high, -99))
  AND   (nvl(cc.segment7, -99) BETWEEN
           nvl(ar.segment7_low, -99) AND nvl(ar.segment7_high, -99))
  AND   (nvl(cc.segment8, -99) BETWEEN
           nvl(ar.segment8_low, -99) AND nvl(ar.segment8_high, -99))
  AND   (nvl(cc.segment9, -99) BETWEEN
           nvl(ar.segment9_low, -99) AND nvl(ar.segment9_high, -99))
  AND   (nvl(cc.segment10, -99) BETWEEN
           nvl(ar.segment10_low, -99) AND nvl(ar.segment10_high, -99))
  AND   (nvl(cc.segment11, -99) BETWEEN
           nvl(ar.segment11_low, -99) AND nvl(ar.segment11_high, -99))
  AND   (nvl(cc.segment12, -99) BETWEEN
           nvl(ar.segment12_low, -99) AND nvl(ar.segment12_high, -99))
  AND   (nvl(cc.segment13, -99) BETWEEN
           nvl(ar.segment13_low, -99) AND nvl(ar.segment13_high, -99))
  AND   (nvl(cc.segment14, -99) BETWEEN
           nvl(ar.segment14_low, -99) AND nvl(ar.segment14_high, -99))
  AND   (nvl(cc.segment15, -99) BETWEEN
           nvl(ar.segment15_low, -99) AND nvl(ar.segment15_high, -99))
  AND   (nvl(cc.segment16, -99) BETWEEN
           nvl(ar.segment16_low, -99) AND nvl(ar.segment16_high, -99))
  AND   (nvl(cc.segment17, -99) BETWEEN
           nvl(ar.segment17_low, -99) AND nvl(ar.segment17_high, -99))
  AND   (nvl(cc.segment18, -99) BETWEEN
           nvl(ar.segment18_low, -99) AND nvl(ar.segment18_high, -99))
  AND   (nvl(cc.segment19, -99) BETWEEN
           nvl(ar.segment19_low, -99) AND nvl(ar.segment19_high, -99))
  AND   (nvl(cc.segment20, -99) BETWEEN
           nvl(ar.segment20_low, -99) AND nvl(ar.segment20_high, -99))
  AND   (nvl(cc.segment21, -99) BETWEEN
           nvl(ar.segment21_low, -99) AND nvl(ar.segment21_high, -99))
  AND   (nvl(cc.segment22, -99) BETWEEN
           nvl(ar.segment22_low, -99) AND nvl(ar.segment22_high, -99))
  AND   (nvl(cc.segment23, -99) BETWEEN
           nvl(ar.segment23_low, -99) AND nvl(ar.segment23_high, -99))
  AND   (nvl(cc.segment24, -99) BETWEEN
           nvl(ar.segment24_low, -99) AND nvl(ar.segment24_high, -99))
  AND   (nvl(cc.segment25, -99) BETWEEN
           nvl(ar.segment25_low, -99) AND nvl(ar.segment25_high, -99))
  AND   (nvl(cc.segment26, -99) BETWEEN
           nvl(ar.segment26_low, -99) AND nvl(ar.segment26_high, -99))
  AND   (nvl(cc.segment27, -99) BETWEEN
           nvl(ar.segment27_low, -99) AND nvl(ar.segment27_high, -99))
  AND   (nvl(cc.segment28, -99) BETWEEN
           nvl(ar.segment28_low, -99) AND nvl(ar.segment28_high, -99))
  AND   (nvl(cc.segment29, -99) BETWEEN
           nvl(ar.segment29_low, -99) AND nvl(ar.segment29_high, -99))
  AND   (nvl(cc.segment30, -99) BETWEEN
           nvl(ar.segment30_low, -99) AND nvl(ar.segment30_high, -99))
)
SELECT decode(bco.funds_check_level_code,
         ''B'',''Absolute'',
         ''N'',''None'',
         ''D'',''Advisory'') "Funds Check Level",
       decode(bco.amount_type,
         ''PTD'', ''Period To Date'',
         ''YTD'', ''Year To Date'',
         ''QTD'',''Quater To Date'') "Amount Type",
       decode(bco.boundary_code,
         ''P'',''Period'',
         ''Y'',''Year'') "Boundary Code",
       b.budget_name "Funding Budget",
       bco.funding_budget_version_id "Funding Budget Version ID"
FROM gl_budorg_bc_options bco,
     gl_budget_versions bv,
     gl_budgets b,
     gl_period_statuses ps,
     ap_invoices_all ai
WHERE bco.range_id IN (
        SELECT range_id FROM ranges)
AND   bco.funding_budget_version_id = bv.budget_version_id
AND   bv.budget_name = b.budget_name
AND   bv.budget_type = b.budget_type
AND   ps.period_name IN (
        SELECT apd.period_name FROM ap_invoice_distributions_all apd
        WHERE apd.invoice_id = ##$$INV$$##
        AND   line_type_lookup_code != ''REC_TAX'')
AND   ai.invoice_id = ##$$INV$$##
AND   ps.ledger_id = ai.set_of_books_id
AND   ps.application_id = 101
AND   ps.start_date >= (
        SELECT p1.start_date FROM gl_period_statuses p1
        WHERE p1.period_name = b.first_valid_period_name
        AND   p1.application_id = ps.application_id
        AND   p1.ledger_id = ps.ledger_id)
AND   ps.end_date <= (
        SELECT p2.end_date FROM gl_period_statuses p2
        WHERE p2.period_name = b.last_valid_period_name
        AND   p2.application_id = ps.application_id
        AND   p2.ledger_id = ps.ledger_id)
AND   rownum < 2',
      p_title                  => 'Budget Setup Options',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Budgetary control options not found for invoice ledger and expense code combinations. ',
      p_solution               => 'Please review:
<ul>
<li>Verify the code combinations exist (General Ledger -> Setup -> Accounts -> Combinations).</li>
<li>Ensure the Franchise budget is defined. (See Section 1.2 of [1928941/KB792707#aref_section36] for information on 
    defining the budget for franchise cost)
<li>Verify that the correct ranges have been defined for the budget organization.  
    See section 1.3 of [1928941/KB792707#aref_section33] for details.</li>
</ul>

<br/>Please review the entirety of [1928941/KB792707] for full details on setting up the budget before logging a bug or service request.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: PSA_SETUP_BC_OPTIONS_EXIST');



debug('begin add_signature: PSA_SETUP_BUD_FCHK_LVL_NONE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3046',
      p_sig_id                 => 'PSA_SETUP_BUD_FCHK_LVL_NONE',
      p_sig_sql                => 'WITH ranges AS (
  SELECT ar.range_id,
         ar.budget_entity_id,
         be.name
  FROM gl_budget_assignment_ranges ar,
       gl_code_combinations cc,
       gl_budget_entities be,
       ap_invoices_all ai
  WHERE cc.code_combination_id IN (
          SELECT apd.dist_code_combination_id FROM ap_invoice_distributions_all apd
          WHERE apd.invoice_id in (##$$INV$$##)
          AND   line_type_lookup_code != ''REC_TAX'')
  AND   ai.invoice_id in (##$$INV$$##)
  AND   ar.ledger_id = ai.set_of_books_id
  AND   ar.currency_code = ai.invoice_currency_code
  AND   ar.budget_entity_id = be.budget_entity_id
  AND   (nvl(cc.segment1, -99) BETWEEN
           nvl(ar.segment1_low, -99) AND nvl(ar.segment1_high, -99))
  AND   (nvl(cc.segment2, -99) BETWEEN
           nvl(ar.segment2_low, -99) AND nvl(ar.segment2_high, -99))
  AND   (nvl(cc.segment3, -99) BETWEEN
           nvl(ar.segment3_low, -99) AND nvl(ar.segment3_high, -99))
  AND   (nvl(cc.segment4, -99) BETWEEN
           nvl(ar.segment4_low, -99) AND nvl(ar.segment4_high, -99))
  AND   (nvl(cc.segment5, -99) BETWEEN
           nvl(ar.segment5_low, -99) AND nvl(ar.segment5_high, -99))
  AND   (nvl(cc.segment6, -99) BETWEEN
           nvl(ar.segment6_low, -99) AND nvl(ar.segment6_high, -99))
  AND   (nvl(cc.segment7, -99) BETWEEN
           nvl(ar.segment7_low, -99) AND nvl(ar.segment7_high, -99))
  AND   (nvl(cc.segment8, -99) BETWEEN
           nvl(ar.segment8_low, -99) AND nvl(ar.segment8_high, -99))
  AND   (nvl(cc.segment9, -99) BETWEEN
           nvl(ar.segment9_low, -99) AND nvl(ar.segment9_high, -99))
  AND   (nvl(cc.segment10, -99) BETWEEN
           nvl(ar.segment10_low, -99) AND nvl(ar.segment10_high, -99))
  AND   (nvl(cc.segment11, -99) BETWEEN
           nvl(ar.segment11_low, -99) AND nvl(ar.segment11_high, -99))
  AND   (nvl(cc.segment12, -99) BETWEEN
           nvl(ar.segment12_low, -99) AND nvl(ar.segment12_high, -99))
  AND   (nvl(cc.segment13, -99) BETWEEN
           nvl(ar.segment13_low, -99) AND nvl(ar.segment13_high, -99))
  AND   (nvl(cc.segment14, -99) BETWEEN
           nvl(ar.segment14_low, -99) AND nvl(ar.segment14_high, -99))
  AND   (nvl(cc.segment15, -99) BETWEEN
           nvl(ar.segment15_low, -99) AND nvl(ar.segment15_high, -99))
  AND   (nvl(cc.segment16, -99) BETWEEN
           nvl(ar.segment16_low, -99) AND nvl(ar.segment16_high, -99))
  AND   (nvl(cc.segment17, -99) BETWEEN
           nvl(ar.segment17_low, -99) AND nvl(ar.segment17_high, -99))
  AND   (nvl(cc.segment18, -99) BETWEEN
           nvl(ar.segment18_low, -99) AND nvl(ar.segment18_high, -99))
  AND   (nvl(cc.segment19, -99) BETWEEN
           nvl(ar.segment19_low, -99) AND nvl(ar.segment19_high, -99))
  AND   (nvl(cc.segment20, -99) BETWEEN
           nvl(ar.segment20_low, -99) AND nvl(ar.segment20_high, -99))
  AND   (nvl(cc.segment21, -99) BETWEEN
           nvl(ar.segment21_low, -99) AND nvl(ar.segment21_high, -99))
  AND   (nvl(cc.segment22, -99) BETWEEN
           nvl(ar.segment22_low, -99) AND nvl(ar.segment22_high, -99))
  AND   (nvl(cc.segment23, -99) BETWEEN
           nvl(ar.segment23_low, -99) AND nvl(ar.segment23_high, -99))
  AND   (nvl(cc.segment24, -99) BETWEEN
           nvl(ar.segment24_low, -99) AND nvl(ar.segment24_high, -99))
  AND   (nvl(cc.segment25, -99) BETWEEN
           nvl(ar.segment25_low, -99) AND nvl(ar.segment25_high, -99))
  AND   (nvl(cc.segment26, -99) BETWEEN
           nvl(ar.segment26_low, -99) AND nvl(ar.segment26_high, -99))
  AND   (nvl(cc.segment27, -99) BETWEEN
           nvl(ar.segment27_low, -99) AND nvl(ar.segment27_high, -99))
  AND   (nvl(cc.segment28, -99) BETWEEN
           nvl(ar.segment28_low, -99) AND nvl(ar.segment28_high, -99))
  AND   (nvl(cc.segment29, -99) BETWEEN
           nvl(ar.segment29_low, -99) AND nvl(ar.segment29_high, -99))
  AND   (nvl(cc.segment30, -99) BETWEEN
           nvl(ar.segment30_low, -99) AND nvl(ar.segment30_high, -99))
)
SELECT decode(bco.funds_check_level_code,
         ''B'',''Absolute'',
         ''N'',''None'',
         ''D'',''Advisory'') "Funds Check Level",
       decode(bco.amount_type,
         ''PTD'', ''Period To Date'',
         ''YTD'', ''Year To Date'',
         ''QTD'',''Quater To Date'') "Amount Type",
       decode(bco.boundary_code,
         ''P'',''Period'',
         ''Y'',''Year'') "Boundary Code",
       b.budget_name "Funding Budget",
       bco.funding_budget_version_id "Funding Budget Version ID"
FROM gl_budorg_bc_options bco,
     gl_budget_versions bv,
     gl_budgets b,
     gl_period_statuses ps,
     ap_invoices_all ai
WHERE bco.range_id IN (
        SELECT range_id FROM ranges)
AND   bco.funding_budget_version_id = bv.budget_version_id
AND   bv.budget_name = b.budget_name
AND   bv.budget_type = b.budget_type
AND   ps.period_name IN (
        SELECT apd.period_name FROM ap_invoice_distributions_all apd
        WHERE apd.invoice_id = ##$$INV$$##
        AND   line_type_lookup_code != ''REC_TAX'')
AND   ai.invoice_id = ##$$INV$$##
AND   ps.ledger_id = ai.set_of_books_id
AND   ps.application_id = 101
AND   ps.start_date >= (
        SELECT p1.start_date FROM gl_period_statuses p1
        WHERE p1.period_name = b.first_valid_period_name
        AND   p1.application_id = ps.application_id
        AND   p1.ledger_id = ps.ledger_id)
AND   ps.end_date <= (
        SELECT p2.end_date FROM gl_period_statuses p2
        WHERE p2.period_name = b.last_valid_period_name
        AND   p2.application_id = ps.application_id
        AND   p2.ledger_id = ps.ledger_id)
AND   rownum < 2',
      p_title                  => 'Budget Org Funds Check Level',
      p_fail_condition         => '[Funds Check Level] != [Absolute]',
      p_problem_descr          => 'Budget organization funds check is disabled.',
      p_solution               => 'Review Section 1.3 of [1928941/KB792707] for details on setting the appropriate funds check level on the funding budget.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: PSA_SETUP_BUD_FCHK_LVL_NONE');



debug('begin add_signature: PSA_SETUP_BUD_FCHK_LVL_ADV');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3045',
      p_sig_id                 => 'PSA_SETUP_BUD_FCHK_LVL_ADV',
      p_sig_sql                => 'WITH ranges AS (
  SELECT ar.range_id,
         ar.budget_entity_id,
         be.name
  FROM gl_budget_assignment_ranges ar,
       gl_code_combinations cc,
       gl_budget_entities be,
       ap_invoices_all ai
  WHERE cc.code_combination_id IN (
          SELECT apd.dist_code_combination_id FROM ap_invoice_distributions_all apd
          WHERE apd.invoice_id in (##$$INV$$##)
          AND   line_type_lookup_code != ''REC_TAX'')
  AND   ai.invoice_id in (##$$INV$$##)
  AND   ar.ledger_id = ai.set_of_books_id
  AND   ar.currency_code = ai.invoice_currency_code
  AND   ar.budget_entity_id = be.budget_entity_id
  AND   (nvl(cc.segment1, -99) BETWEEN
           nvl(ar.segment1_low, -99) AND nvl(ar.segment1_high, -99))
  AND   (nvl(cc.segment2, -99) BETWEEN
           nvl(ar.segment2_low, -99) AND nvl(ar.segment2_high, -99))
  AND   (nvl(cc.segment3, -99) BETWEEN
           nvl(ar.segment3_low, -99) AND nvl(ar.segment3_high, -99))
  AND   (nvl(cc.segment4, -99) BETWEEN
           nvl(ar.segment4_low, -99) AND nvl(ar.segment4_high, -99))
  AND   (nvl(cc.segment5, -99) BETWEEN
           nvl(ar.segment5_low, -99) AND nvl(ar.segment5_high, -99))
  AND   (nvl(cc.segment6, -99) BETWEEN
           nvl(ar.segment6_low, -99) AND nvl(ar.segment6_high, -99))
  AND   (nvl(cc.segment7, -99) BETWEEN
           nvl(ar.segment7_low, -99) AND nvl(ar.segment7_high, -99))
  AND   (nvl(cc.segment8, -99) BETWEEN
           nvl(ar.segment8_low, -99) AND nvl(ar.segment8_high, -99))
  AND   (nvl(cc.segment9, -99) BETWEEN
           nvl(ar.segment9_low, -99) AND nvl(ar.segment9_high, -99))
  AND   (nvl(cc.segment10, -99) BETWEEN
           nvl(ar.segment10_low, -99) AND nvl(ar.segment10_high, -99))
  AND   (nvl(cc.segment11, -99) BETWEEN
           nvl(ar.segment11_low, -99) AND nvl(ar.segment11_high, -99))
  AND   (nvl(cc.segment12, -99) BETWEEN
           nvl(ar.segment12_low, -99) AND nvl(ar.segment12_high, -99))
  AND   (nvl(cc.segment13, -99) BETWEEN
           nvl(ar.segment13_low, -99) AND nvl(ar.segment13_high, -99))
  AND   (nvl(cc.segment14, -99) BETWEEN
           nvl(ar.segment14_low, -99) AND nvl(ar.segment14_high, -99))
  AND   (nvl(cc.segment15, -99) BETWEEN
           nvl(ar.segment15_low, -99) AND nvl(ar.segment15_high, -99))
  AND   (nvl(cc.segment16, -99) BETWEEN
           nvl(ar.segment16_low, -99) AND nvl(ar.segment16_high, -99))
  AND   (nvl(cc.segment17, -99) BETWEEN
           nvl(ar.segment17_low, -99) AND nvl(ar.segment17_high, -99))
  AND   (nvl(cc.segment18, -99) BETWEEN
           nvl(ar.segment18_low, -99) AND nvl(ar.segment18_high, -99))
  AND   (nvl(cc.segment19, -99) BETWEEN
           nvl(ar.segment19_low, -99) AND nvl(ar.segment19_high, -99))
  AND   (nvl(cc.segment20, -99) BETWEEN
           nvl(ar.segment20_low, -99) AND nvl(ar.segment20_high, -99))
  AND   (nvl(cc.segment21, -99) BETWEEN
           nvl(ar.segment21_low, -99) AND nvl(ar.segment21_high, -99))
  AND   (nvl(cc.segment22, -99) BETWEEN
           nvl(ar.segment22_low, -99) AND nvl(ar.segment22_high, -99))
  AND   (nvl(cc.segment23, -99) BETWEEN
           nvl(ar.segment23_low, -99) AND nvl(ar.segment23_high, -99))
  AND   (nvl(cc.segment24, -99) BETWEEN
           nvl(ar.segment24_low, -99) AND nvl(ar.segment24_high, -99))
  AND   (nvl(cc.segment25, -99) BETWEEN
           nvl(ar.segment25_low, -99) AND nvl(ar.segment25_high, -99))
  AND   (nvl(cc.segment26, -99) BETWEEN
           nvl(ar.segment26_low, -99) AND nvl(ar.segment26_high, -99))
  AND   (nvl(cc.segment27, -99) BETWEEN
           nvl(ar.segment27_low, -99) AND nvl(ar.segment27_high, -99))
  AND   (nvl(cc.segment28, -99) BETWEEN
           nvl(ar.segment28_low, -99) AND nvl(ar.segment28_high, -99))
  AND   (nvl(cc.segment29, -99) BETWEEN
           nvl(ar.segment29_low, -99) AND nvl(ar.segment29_high, -99))
  AND   (nvl(cc.segment30, -99) BETWEEN
           nvl(ar.segment30_low, -99) AND nvl(ar.segment30_high, -99))
)
SELECT decode(bco.funds_check_level_code,
         ''B'',''Absolute'',
         ''N'',''None'',
         ''D'',''Advisory'') "Funds Check Level",
       decode(bco.amount_type,
         ''PTD'', ''Period To Date'',
         ''YTD'', ''Year To Date'',
         ''QTD'',''Quater To Date'') "Amount Type",
       decode(bco.boundary_code,
         ''P'',''Period'',
         ''Y'',''Year'') "Boundary Code",
       b.budget_name "Funding Budget",
       bco.funding_budget_version_id "Funding Budget Version ID"
FROM gl_budorg_bc_options bco,
     gl_budget_versions bv,
     gl_budgets b,
     gl_period_statuses ps,
     ap_invoices_all ai
WHERE bco.range_id IN (
        SELECT range_id FROM ranges)
AND   bco.funding_budget_version_id = bv.budget_version_id
AND   bv.budget_name = b.budget_name
AND   bv.budget_type = b.budget_type
AND   ps.period_name IN (
        SELECT apd.period_name FROM ap_invoice_distributions_all apd
        WHERE apd.invoice_id = ##$$INV$$##
        AND   line_type_lookup_code != ''REC_TAX'')
AND   ai.invoice_id = ##$$INV$$##
AND   ps.ledger_id = ai.set_of_books_id
AND   ps.application_id = 101
AND   ps.start_date >= (
        SELECT p1.start_date FROM gl_period_statuses p1
        WHERE p1.period_name = b.first_valid_period_name
        AND   p1.application_id = ps.application_id
        AND   p1.ledger_id = ps.ledger_id)
AND   ps.end_date <= (
        SELECT p2.end_date FROM gl_period_statuses p2
        WHERE p2.period_name = b.last_valid_period_name
        AND   p2.application_id = ps.application_id
        AND   p2.ledger_id = ps.ledger_id)
AND   rownum < 2',
      p_title                  => 'Budget Org Funds Check Level Advisory',
      p_fail_condition         => '[Funds Check Level] = [Advisory]',
      p_problem_descr          => 'The budget funds check level is "Advisory". Transactions may be created which exceed allocated budget amounts. ',
      p_solution               => 'To prevent transactions from being created which exceed budget amounts, the funds check level should be set to "Absolute".<br>
See [1928941/KB792707] for complete details on budgetary control setup.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: PSA_SETUP_BUD_FCHK_LVL_ADV');



debug('begin add_signature: PSA_SETUP_BC_OPTION');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3047',
      p_sig_id                 => 'PSA_SETUP_BC_OPTION',
      p_sig_sql                => 'select bc_option_name "Option Setting", bc_option_id "ID", description "Description" 
FROM gl_bc_options 
WHERE bc_option_id = to_number(''##$$BCOPT$$##'')',
      p_title                  => 'Budgetary Control Group Profile Option',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'The profile option "Budgetary Control Group" is not set.',
      p_solution               => 'Set the profile option "Budgetary Control Group" as per your requirements.  See [1928941/KB792707] for details on budgetary control groups.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: PSA_SETUP_BC_OPTION');



debug('begin add_signature: PSA_SETUP_BUDGET');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3044',
      p_sig_id                 => 'PSA_SETUP_BUDGET',
      p_sig_sql                => 'SELECT cc.code_combination_id, ai.invoice_id, ai.set_of_books_id, be.budget_entity_id, ai.invoice_currency_code
FROM gl_budget_assignment_ranges ar,
     gl_code_combinations cc,
     gl_budget_entities be,
     ap_invoices_all ai
WHERE ai.invoice_id in (##$$INV$$##) 
and cc.code_combination_id IN (
        SELECT apd.dist_code_combination_id
        FROM ap_invoice_distributions_all apd
        WHERE apd.invoice_id=ai.invoice_id
        AND   line_type_lookup_code != ''REC_TAX'')
AND   ar.ledger_id = ai.set_of_books_id
AND   ar.currency_code = ai.invoice_currency_code
AND   ar.budget_entity_id = be.budget_entity_id
AND   (nvl(cc.segment1, -99) BETWEEN
         nvl(ar.segment1_low, -99) AND nvl(ar.segment1_high, -99))
AND   (nvl(cc.segment2, -99) BETWEEN
         nvl(ar.segment2_low, -99) AND nvl(ar.segment2_high, -99))
AND   (nvl(cc.segment3, -99) BETWEEN
         nvl(ar.segment3_low, -99) AND nvl(ar.segment3_high, -99))
AND   (nvl(cc.segment4, -99) BETWEEN
         nvl(ar.segment4_low, -99) AND nvl(ar.segment4_high, -99))
AND   (nvl(cc.segment5, -99) BETWEEN
         nvl(ar.segment5_low, -99) AND nvl(ar.segment5_high, -99))
AND   (nvl(cc.segment6, -99) BETWEEN
         nvl(ar.segment6_low, -99) AND nvl(ar.segment6_high, -99))
AND   (nvl(cc.segment7, -99) BETWEEN
         nvl(ar.segment7_low, -99) AND nvl(ar.segment7_high, -99))
AND   (nvl(cc.segment8, -99) BETWEEN
         nvl(ar.segment8_low, -99) AND nvl(ar.segment8_high, -99))
AND   (nvl(cc.segment9, -99) BETWEEN
         nvl(ar.segment9_low, -99) AND nvl(ar.segment9_high, -99))
AND   (nvl(cc.segment10, -99) BETWEEN
         nvl(ar.segment10_low, -99) AND nvl(ar.segment10_high, -99))
AND   (nvl(cc.segment11, -99) BETWEEN
         nvl(ar.segment11_low, -99) AND nvl(ar.segment11_high, -99))
AND   (nvl(cc.segment12, -99) BETWEEN
         nvl(ar.segment12_low, -99) AND nvl(ar.segment12_high, -99))
AND   (nvl(cc.segment13, -99) BETWEEN
         nvl(ar.segment13_low, -99) AND nvl(ar.segment13_high, -99))
AND   (nvl(cc.segment14, -99) BETWEEN
         nvl(ar.segment14_low, -99) AND nvl(ar.segment14_high, -99))
AND   (nvl(cc.segment15, -99) BETWEEN
         nvl(ar.segment15_low, -99) AND nvl(ar.segment15_high, -99))
AND   (nvl(cc.segment16, -99) BETWEEN
         nvl(ar.segment16_low, -99) AND nvl(ar.segment16_high, -99))
AND   (nvl(cc.segment17, -99) BETWEEN
         nvl(ar.segment17_low, -99) AND nvl(ar.segment17_high, -99))
AND   (nvl(cc.segment18, -99) BETWEEN
         nvl(ar.segment18_low, -99) AND nvl(ar.segment18_high, -99))
AND   (nvl(cc.segment19, -99) BETWEEN
         nvl(ar.segment19_low, -99) AND nvl(ar.segment19_high, -99))
AND   (nvl(cc.segment20, -99) BETWEEN
         nvl(ar.segment20_low, -99) AND nvl(ar.segment20_high, -99))
AND   (nvl(cc.segment21, -99) BETWEEN
         nvl(ar.segment21_low, -99) AND nvl(ar.segment21_high, -99))
AND   (nvl(cc.segment22, -99) BETWEEN
         nvl(ar.segment22_low, -99) AND nvl(ar.segment22_high, -99))
AND   (nvl(cc.segment23, -99) BETWEEN
         nvl(ar.segment23_low, -99) AND nvl(ar.segment23_high, -99))
AND   (nvl(cc.segment24, -99) BETWEEN
         nvl(ar.segment24_low, -99) AND nvl(ar.segment24_high, -99))
AND   (nvl(cc.segment25, -99) BETWEEN
         nvl(ar.segment25_low, -99) AND nvl(ar.segment25_high, -99))
AND   (nvl(cc.segment26, -99) BETWEEN
         nvl(ar.segment26_low, -99) AND nvl(ar.segment26_high, -99))
AND   (nvl(cc.segment27, -99) BETWEEN
         nvl(ar.segment27_low, -99) AND nvl(ar.segment27_high, -99))
AND   (nvl(cc.segment28, -99) BETWEEN
         nvl(ar.segment28_low, -99) AND nvl(ar.segment28_high, -99))
AND   (nvl(cc.segment29, -99) BETWEEN
         nvl(ar.segment29_low, -99) AND nvl(ar.segment29_high, -99))
AND   (nvl(cc.segment30, -99) BETWEEN
         nvl(ar.segment30_low, -99) AND nvl(ar.segment30_high, -99))',
      p_title                  => 'Setup Budget',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No budget has been established for the invoice expense accounts.',
      p_solution               => 'Invoice expense accounts are not included in budget assignment ranges. Please review:
<ul>
<li>Verify the code combinations exist (General Ledger -> Setup -> Accounts -> Combinations).</li>
<li>Ensure the Franchise budget is defined. (See Section 1.2 of [1928941/KB792707] for information on 
    defining the budget for franchise cost)
<li>Verify that the correct ranges have been defined for the budget organization.  
    See section 1.3 of [1928941/KB792707] for details.</li>
</ul>

<br/>Please review the entirety of [1928941/KB792707] for full details on setting up the budget before logging a bug or service request.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: PSA_SETUP_BUDGET');



debug('begin add_signature: PSA_SETUP_LEDGER_BUD_CTRL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3025',
      p_sig_id                 => 'PSA_SETUP_LEDGER_BUD_CTRL',
      p_sig_sql                => 'SELECT l.name "Ledger Name",
       decode(l.enable_budgetary_control_flag, ''Y'', ''Enabled'',''Disabled'') "Ledger Level Budgetary Control",
       decode(l.sla_ledger_cash_basis_flag, ''Y'', ''Cash Based'', ''Accrual Based'') "Accounting Type",
       decode(l.sla_accounting_method_type, ''S'', ''Seeded'', ''Custom'') "Setup Type",
       l.sla_accounting_method_code "Accounting Method",
       l.ledger_category_code "Category Code",
       l.currency_code "Currency Code"
FROM ap_invoices_all i,
     gl_ledgers l
WHERE i.invoice_id = ##$$INV$$##
AND   i.set_of_books_id = l.ledger_id
AND   rownum < 2',
      p_title                  => 'Ledger Level Budgetary Control for Invoice',
      p_fail_condition         => '[Ledger Level Budgetary Control] = [Disabled]',
      p_problem_descr          => 'Budgetary control is not enabled at the ledger level for the invoice.',
      p_solution               => 'Critical setup error.  Budgetary control is not enabled at the ledger level. <br>
See [1928941/KB792707] for information on PSA setup.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: PSA_SETUP_LEDGER_BUD_CTRL');



debug('begin add_signature: PSA_SETUP_JLD_BUD_CTRL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3026',
      p_sig_id                 => 'PSA_SETUP_JLD_BUD_CTRL',
      p_sig_sql                => 'SELECT count(*)
FROM gl_ledgers l,
     xla_acctg_method_rules r,
     xla_product_rules_vl a,
     xla_prod_acct_headers e,
     xla_aad_line_defn_assgns la,
     xla_line_definitions_vl ld,
     ap_invoices_all ap
WHERE l.ledger_id = ap.set_of_books_id
AND   ap.invoice_id = ##$$INV$$##
AND   ld.budgetary_control_flag=''Y''
AND   l.sla_accounting_method_type = r.accounting_method_type_code
AND   l.sla_accounting_method_code = r.accounting_method_code
AND   r.application_id = 200
AND   a.application_id = r.application_id
AND   r.product_rule_type_code = a.product_rule_type_code
AND   r.product_rule_code = a.product_rule_code
AND   r.product_rule_type_code = e.product_rule_type_code
AND   r.product_rule_code = e.product_rule_code
AND   r.product_rule_type_code = la.product_rule_type_code
AND   r.product_rule_code = la.product_rule_code
AND   e.event_class_code = la.event_class_code
AND   e.event_type_code = la.event_type_code
AND   la.line_definition_owner_code = ld.line_definition_owner_code
AND   la.line_definition_code = ld.line_definition_code
AND   la.event_class_code = ld.event_class_code
AND   la.event_type_code = ld.event_type_code',
      p_title                  => 'Budgetary Control at Journal Line Definition (JLD) Level',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Critical setup error - No JLD''s are budgetary control enabled.',
      p_solution               => 'Review Section 3.5 of [1928941/KB792707] for details on defining source and category level budgetary controls.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: PSA_SETUP_JLD_BUD_CTRL');



debug('begin add_signature: PSA_SETUP_UPG_DATE_SET');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '3027',
      p_sig_id                 => 'PSA_SETUP_UPG_DATE_SET',
      p_sig_sql                => 'SELECT ''##$$UPGDATE$$##'' "Upgrade Date" from dual where ''##$$UPGDATE$$##'' is not null',
      p_title                  => 'Upgrade Date Set',
      p_fail_condition         => '[count(*)] = [0]',
      p_problem_descr          => 'Critical setup error - the profile option "PSA: R12 Upgrade Date" is not set or is not set correctly.',
      p_solution               => 'Set the profile option "PSA: R12 Upgrade Date" using the format MM/DD/YYYY HH24:MI:SS.
The remaining validations will be skipped until this problem is addressed.
Please review section 2 from  [1053172/KB559267].',
      p_success_msg            => 'The "PSA: R12 Upgrade Date" profile option is correctly set.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: PSA_SETUP_UPG_DATE_SET');



debug('begin add_signature: PSA_INV_ORPHAN_BC_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2961',
      p_sig_id                 => 'PSA_INV_ORPHAN_BC_EVENTS',
      p_sig_sql                => 'SELECT xe.event_id,
       xe.entity_id,
       xe.event_type_code,
       xe.event_status_code,
       xe.event_date,
       xe.upg_batch_id
FROM ap_invoices_all ai,
     xla.xla_transaction_entities xte,
     xla_events xe
WHERE ai.invoice_id in (##$$INV$$##)
AND   xe.entity_id = xte.entity_id
AND   xte.application_id = 200
AND   nvl(xte.source_id_int_1,-99) = ai.invoice_id
AND   xe.application_id = 200
AND   xe.event_status_code = ''U''
AND   xe.process_status_code = ''U''
AND   xe.budgetary_control_flag = ''Y''
AND   xe.event_type_code <> ''MANUAL''
AND   NOT EXISTS (
        SELECT ''not exists'' FROM ap_invoice_distributions_all aid
        WHERE aid.bc_event_id = xe.event_id)
AND   NOT EXISTS (
        SELECT ''not exists'' FROM ap_prepay_history_all aph
        WHERE aph.bc_event_id = xe.event_id)
AND   NOT EXISTS (
        SELECT ''not exists'' FROM ap_prepay_app_dists apd
        WHERE apd.bc_event_id = xe.event_id)
AND   NOT EXISTS (
        SELECT ''not exists'' FROM ap_self_assessed_tax_dist_all aps
        WHERE aps.bc_event_id = xe.event_id)
ORDER BY xe.entity_id, xe.event_id',
      p_title                  => 'Orphan Unprocessed Budgetary Control Events',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Orphan unprocessed budgetary control events exist. These events are not processed and not assigned to any Invoice or Prepayment.',
      p_solution               => '1) Please run the "Budgetary Control Optimizer" program.<br>
For more details refer to [1055606/KB633271] item #3. "Cleanup the Data".
2) Check section 3 - Orphan BC Events and incorrect stamping from [1053172/KB559267]',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_ORPHAN_BC_EVENTS');



debug('begin add_signature: PSA_INV_ORPHAN_PROCESSED_BC_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2962',
      p_sig_id                 => 'PSA_INV_ORPHAN_PROCESSED_BC_EVENTS',
      p_sig_sql                => 'SELECT xe.event_id,
       xe.entity_id,
       xe.event_type_code,
       xe.event_status_code,
       xe.event_date,
       xe.upg_batch_id,
       (
         SELECT xlaerr.encoded_msg
         FROM xla_accounting_errors xlaerr
         WHERE xlaerr.accounting_error_id = (
                 SELECT MAX(xlaerr1.accounting_error_id)
                 FROM xla_accounting_errors xlaerr1
                 WHERE xlaerr1.event_id = xlaerr.event_id)
         AND   xlaerr.event_id = xe.event_id
       ) xla_accounting_error
FROM ap_invoices_all ai,
     xla.xla_transaction_entities xte,
     xla_events xe
WHERE ai.invoice_id in (##$$INV$$##)
AND   xe.entity_id = xte.entity_id
AND   xte.application_id = 200
AND   nvl(xte.source_id_int_1,-99) = ai.invoice_id
AND   xte.ledger_id = ai.set_of_books_id
AND   xe.application_id = 200
AND   xe.event_status_code = ''P''
AND   xe.process_status_code = ''P''
AND   xe.budgetary_control_flag = ''Y''
AND   xe.event_type_code <> ''MANUAL''
AND   NOT EXISTS (
        SELECT ''not exists'' FROM ap_invoice_distributions_all aid
        WHERE aid.bc_event_id = xe.event_id)
AND   NOT EXISTS (
        SELECT ''not exists'' FROM ap_prepay_history_all aph
        WHERE aph.bc_event_id = xe.event_id)
AND   NOT EXISTS (
        SELECT ''not exists'' FROM ap_prepay_app_dists apd
        WHERE apd.bc_event_id = xe.event_id)
AND   NOT EXISTS (
        SELECT ''not exists'' FROM ap_self_assessed_tax_dist_all aps
        WHERE aps.bc_event_id = xe.event_id)
ORDER BY xe.entity_id, xe.event_id',
      p_title                  => 'Orphan Processed Budgetary Control Events',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Orphan processed budgetary control (BC) events exist.  Events exist which are processed but are not assigned to any invoice or prepayment.',
      p_solution               => 'Please run the "Budgetary Control Optimizer" program.<br>
For more details refer to [1055606/KB633271] -> Item #3 "Cleanup the Data"',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_ORPHAN_PROCESSED_BC_EVENTS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_ORPHAN_AP_PREPAY_APP_DISTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24994',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_ORPHAN_AP_PREPAY_APP_DISTS',
      p_sig_sql                => '    SELECT
    aid.invoice_id,
    aid.invoice_distribution_id,
    apad.accounting_event_id,
    apad.bc_event_id,
    apad.prepay_history_id
FROM
    ap_prepay_app_dists          apad,
    ap_invoice_distributions_all aid
WHERE
        aid.invoice_id in (##$$INV$$##) 
    AND aid.invoice_distribution_id = apad.invoice_distribution_id
        AND apad.prepay_history_id NOT IN (
        SELECT
            prepay_history_id
        FROM
            ap_prepay_history_all
    )',
      p_title                  => 'Orphan Data in AP_PREPAY_APP_DISTS',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Orphan data in AP_PREPAY_APP_DISTS',
      p_solution               => 'As detailed in Section 4 [1446360/KB786606], apply latest available version for appredib.pls package file via Patch:12858105:R12.AP.A/Patch:12858105:R12.AP.B.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_ORPHAN_AP_PREPAY_APP_DISTS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BC_EVENT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24995',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_BC_EVENT',
      p_sig_sql                => 'SELECT aid1.invoice_distribution_id,aid1.line_type_lookup_code,aid1.bc_event_id
                            FROM ap_invoice_distributions_all aid1 
                            WHERE ''PREPAY'' = DECODE(aid1.charge_applicable_to_dist_id,NULL,aid1.line_type_lookup_code,
                            (SELECT aid3.line_type_lookup_Code FROM ap_invoice_distributions_all aid3 
                            WHERE aid3.invoice_distribution_id = aid1.charge_applicable_to_dist_id))   
                            AND aid1.bc_event_id IN (SELECT aid2.bc_event_id  FROM   ap_invoice_distributions_all aid2  
                            WHERE  aid1.invoice_id = aid2.invoice_id  AND ''PREPAY'' <> DECODE(aid2.charge_applicable_to_dist_id,NULL,aid2.line_type_lookup_code, 
                            (SELECT aid3.line_type_lookup_Code FROM ap_invoice_distributions_all aid3 
                            WHERE aid3.invoice_distribution_id = aid2.charge_applicable_to_dist_id))) AND aid1.invoice_id in (##$$INV$$##)
                            UNION
                            SELECT aid1.invoice_distribution_id,aid1.line_type_lookup_code,aid1.bc_event_id
                            FROM   ap_invoice_distributions_all aid1
                            WHERE  ''PREPAY'' <> DECODE(aid1.charge_applicable_to_dist_id,NULL,aid1.line_type_lookup_code,
                            (SELECT aid3.line_type_lookup_Code
                            FROM ap_invoice_distributions_all aid3
                            WHERE aid3.invoice_distribution_id = aid1.charge_applicable_to_dist_id))
                            AND aid1.bc_event_id IN (SELECT aid2.bc_event_id
                            FROM   ap_invoice_distributions_all aid2
                            WHERE  aid1.invoice_id = aid2.invoice_id
                            AND ''PREPAY'' = DECODE(aid2.charge_applicable_to_dist_id,NULL,aid2.line_type_lookup_code,
                            (SELECT aid3.line_type_lookup_Code
                            FROM ap_invoice_distributions_all aid3
                            WHERE aid3.invoice_distribution_id = aid2.charge_applicable_to_dist_id)))
                            AND aid1.invoice_id in (##$$INV$$##)',
      p_title                  => 'Incorrect BC Event Stamping',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Incorrect BC Event Stamping - Prepay distributions should not share the same BC_EVENT_ID stamped for the ITEM distributions',
      p_solution               => 'As detailed in Section 4 [1446360/KB786606] <br><br> 1) <b>Apply latest PSA Rollup Patch</b>: <br>Patch:14563642:R12.PSA.A<br>Patch:19266556:R12.PSA.B<br>Patch:22850140:R12.PSA.C <br><br>2) <b>Run the Budgetary Control Optimizer concurrent program.</b>',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BC_EVENT');



debug('begin add_signature: PSA_INV_UNENC_DIST_WITH_PROCESSED_EVENT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2963',
      p_sig_id                 => 'PSA_INV_UNENC_DIST_WITH_PROCESSED_EVENT',
      p_sig_sql                => 'SELECT  invoice_id, sum(Accounted_Amount_DR) , sum(Accounted_Amount_CR)  FROM
(SELECT ai.invoice_id invoice_id, h.event_type_code event_type_code,
       sum(nvl(l.accounted_dr,0)) Accounted_Amount_DR,
       sum(nvl(l.accounted_cr,0)) Accounted_Amount_CR
FROM ap_invoices_all ai,
     xla_transaction_entities_upg xt,
     xla_ae_headers h,
     xla_ae_lines l,
     xla_events e
WHERE ai.invoice_id in (##$$INVS$$##)
AND   l.ae_header_id = h.ae_header_id
AND   h.entity_id =  xt.entity_id
AND   nvl(xt.source_id_int_1,-99) = ai.invoice_id
AND   xt.ledger_id = ai.set_of_books_id
AND   xt.application_id = 200
AND   xt.entity_code = ''AP_INVOICES''
AND   h.application_id = 200
AND   h.balance_type_code = ''E''
AND   e.process_status_code = ''P''
AND   e.event_status_code = ''P''
AND   e.entity_id = xt.entity_id
AND   l.accounting_class_code not in ( ''RFE'',''PURCHASE_ORDER'')
AND   ap_invoices_utility_pkg.get_posting_status(ai.invoice_id) = ''Y''
GROUP BY ai.invoice_id, h.event_type_code
HAVING   sum(nvl(l.accounted_dr,0)) <> sum(nvl(l.accounted_cr,0))
UNION
SELECT aip.invoice_id invoice_id, h.event_type_code event_type_code,
       sum(nvl(l.accounted_dr,0)) Accounted_Amount_DR,
       sum(nvl(l.accounted_cr,0)) Accounted_Amount_CR
FROM
     ap_invoice_payments_all aip,
     xla_transaction_entities_upg xt,
     xla_ae_headers h,
     xla_ae_lines l,
     xla_events e
WHERE aip.invoice_id in (##$$INVS$$##)
AND   l.ae_header_id = h.ae_header_id
AND   h.entity_id =  xt.entity_id
AND   nvl(xt.source_id_int_1,-99) = aip.check_id
AND   xt.ledger_id = aip.set_of_books_id
AND   xt.application_id = 200
AND   xt.entity_code = ''AP_PAYMENTS''
AND   h.application_id = 200
AND   h.balance_type_code = ''E''
AND   e.process_status_code = ''P''
AND   e.event_status_code = ''P''
AND   e.entity_id = xt.entity_id
AND   l.accounting_class_code not in ( ''RFE'')
GROUP BY aip.invoice_id, h.event_type_code
HAVING   sum(nvl(l.accounted_dr,0)) <> sum(nvl(l.accounted_cr,0))
ORDER BY invoice_id, event_type_code )
GROUP BY invoice_id
HAVING sum(Accounted_Amount_DR) <> sum(Accounted_Amount_CR)',
      p_title                  => 'Unencumbered Distributions with Processed BC Event',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The invoice has distributions which are marked as not encumbered but which have a processed BC event.',
      p_solution               => 'The invoice has distributions that are marked as not encumbered but which have a processed BC event.<br><br>

Please use solution from R12: Generic Data Fix (GDF) Patch for ISSUES ARISING FROM INCORRECT ENCUMBERED FLAG OR FUND HOLDS [1349026/KB613273]<br><br>

',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_UNENC_DIST_WITH_PROCESSED_EVENT');



debug('begin add_signature: PSA_INV_ENC_DIST_UNPROC_EVENT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2964',
      p_sig_id                 => 'PSA_INV_ENC_DIST_UNPROC_EVENT',
      p_sig_sql                => 'SELECT d.invoice_id invoice_id,
       e.event_id,
       e.event_type_code,
       e.event_date,
       e.event_status_code,
       e.process_status_code,
       e.budgetary_control_flag,
       d.invoice_distribution_id
FROM ap_invoice_distributions_all d,
     xla_transaction_entities_upg xt,
     xla_events e
WHERE d.invoice_id in (##$$INV$$##)
AND   e.entity_id =  xt.entity_id
AND   xt.application_id = 200
AND   nvl(xt.source_id_int_1,-99) = d.invoice_id
AND   xt.ledger_id = d.set_of_books_id
AND   e.budgetary_control_flag = ''Y''
AND   e.process_status_code= ''U''
AND   xt.entity_code = ''AP_INVOICES''
AND   d.encumbered_flag = ''Y''
AND   d.bc_event_id = e.event_id
ORDER BY e.event_id',
      p_title                  => 'Encumbered Distributions with Unprocessed Events',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The invoice has distributions marked as encumbered having unprocessed events.',
      p_solution               => 'Accounting will have to be undone for the affected invoices.<br><br>

Please run the psa_invoice_reversal_sel.sql selection script and log a service request against Payables (AP) to obtain the data fix. <br><br>

The selection script can be downloaded from [2086996/KB550563]; it is part of PSA Data Validation Analyzer zip file (psa_data_analyzer.zip)',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_ENC_DIST_UNPROC_EVENT');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_REV_BC_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24996',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_REV_BC_EVENTS',
      p_sig_sql                => '    SELECT
    eve.event_id,
    eve.event_type_code,
    eve.event_status_code,
    eve.process_status_code,
    eve.budgetary_control_flag,
    eve.event_date,
    dist.invoice_distribution_id
FROM
    xla_events                   eve,
    ap_invoice_distributions_all dist
WHERE
        eve.event_id = dist.bc_event_id
    AND dist.encumbered_flag = ''R''
        AND dist.invoice_id in (##$$INV$$##)
ORDER BY
    eve.event_id',
      p_title                  => 'Reversal distributions stamped with BC events',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Reversal distributions stamped with BC events. It is expected that the pair of the distributions, original and reversal, should not have bc_event_id stamped on them.',
      p_solution               => 'As detailed in Section 4 [1446360/KB786606], apply latest code changes for encumbrance events reversal, provided through Patch 8733916',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_REV_BC_EVENTS');



debug('begin add_signature: PSA_INV_REV_ENC_PARENT_UNENC');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2965',
      p_sig_id                 => 'PSA_INV_REV_ENC_PARENT_UNENC',
      p_sig_sql                => 'SELECT aid1.invoice_id,
       aid1.invoice_distribution_id,
       aid1.parent_reversal_id,
       aid1.encumbered_flag,
       aid2.encumbered_flag parent_reversal_encum_flag,
       e.event_id bc_event_id,
       e.event_type_code,
       e.event_status_code,
       e.process_status_code
FROM ap_invoice_distributions_all aid1,
     ap_invoice_distributions_all aid2,
     xla_events e
WHERE aid1.invoice_id in (##$$INV$$##)
AND   aid1.invoice_id = aid2.invoice_id
AND   e.event_id = aid1.bc_event_id
AND   aid1.encumbered_flag = ''Y''
AND   aid1.parent_reversal_id = aid2.invoice_distribution_id
AND   aid2.encumbered_flag = ''R''',
      p_title                  => 'Encumbered Reversal Dists with Unencumbered Parents',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Reversal distributions exist which are encumbered, but the corresponding parent distributions are not encumbered',
      p_solution               => 'Accounting will have to be undone for the affected invoices per [753695/KB218158].<br><br>

Please run the psa_invoice_reversal_sel.sql selection script and log a service request against Payables (AP) to obtain the data fix. <br><br>

The selection script can be downloaded from [2086996/KB550563]; it is part of PSA Data Validation Analyzer zip file (psa_data_analyzer.zip)',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_REV_ENC_PARENT_UNENC');



debug('begin add_signature: PSA_INV_PARENT_ENC_REV_UNENC');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2968',
      p_sig_id                 => 'PSA_INV_PARENT_ENC_REV_UNENC',
      p_sig_sql                => 'SELECT aid1.invoice_id,
       aid1.invoice_distribution_id,
       aid1.parent_reversal_id,
       aid1.encumbered_flag,
       aid2.encumbered_flag parent_reversal_encum_flag,
       e.event_id bc_event_id,
       e.event_type_code,
       e.event_status_code,
       e.process_status_code
FROM ap_invoice_distributions_all aid1,
     ap_invoice_distributions_all aid2,
     xla_events e
WHERE aid1.invoice_id in (##$$INV$$##)
AND   e.event_id = aid2.bc_event_id
AND   aid2.encumbered_flag = ''Y''
AND   aid1.parent_reversal_id = aid2.invoice_distribution_id
AND   aid1.encumbered_flag = ''R''
AND   aid1.invoice_id = aid2.invoice_id',
      p_title                  => 'Encumbered Distributions with Unencumbered Reversals',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Distributions exist on the invoice which are encumbered, but the corresponding reversal distributions are not encumbered',
      p_solution               => 'Accounting will have to be undone for the affected invoices.<br><br>

Please run the psa_invoice_reversal_sel.sql selection script and log a service request against Payables (AP) to obtain the data fix. <br><br>

The selection script can be downloaded from [2086996/KB550563]; it is part of PSA Data Validation Analyzer zip file (psa_data_analyzer.zip)',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_PARENT_ENC_REV_UNENC');



debug('begin add_signature: PSA_GEN_INVALID_PO_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
   l_info('##STYLE##LEDGER_NAME'):= ',,#F5F6CE,bold';
  add_signature(
      p_sig_repo_id            => '2949',
      p_sig_id                 => 'PSA_GEN_INVALID_PO_EVENTS',
      p_sig_sql                => 'SELECT DISTINCT
       l.name ledger_name,
       l.ledger_id,
       xe.event_id,
       xe.event_type_code,
       xe.event_date,
       xe.event_status_code,
       xe.process_status_code,
       xte.entity_id,
       xte.legal_entity_id,
       xte.entity_code,
       xte.source_id_int_1,
       xte.source_id_int_2,
       xte.source_id_int_3,
       xte.source_id_int_4,
       xte.source_id_char_1
 FROM xla_transaction_entities_upg xte,
      xla_events  xe,
      ap_invoices_all ap,
      gl_ledgers l
WHERE NVL(xe.budgetary_control_flag, ''N'') =''Y''
AND   xte.entity_code IN (''REQUISITION'',''PURCHASE_ORDER'',''RELEASE'')
AND   xte.application_id = 201
AND   xe.application_id =xte.application_id
AND   xte.entity_id =  xe.entity_id
AND   xe.EVENT_STATUS_CODE  in (''U'' ,''I'',''P'')
AND   xe.PROCESS_STATUS_CODE  IN (''I'',''D'',''U'')
AND   xte.ledger_id =  ap.set_of_books_id
AND   l.ledger_id = xte.ledger_id
AND   ap.invoice_id in (##$$INV$$##)',
      p_title                  => 'Invalid Accounting Events for PO, Requisition or Release',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There exist purchase orders, requisitions, or releases in the ledger associated with this invoice which have invalid accounting events.
',
      p_solution               => 'Please review [1264605/KB781060] and if the issue is still not resolved, please log an SR/bug with the Purchasing team.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: PSA_GEN_INVALID_PO_EVENTS');



debug('begin add_signature: PSA_INV_PARENT_REVERSAL_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2951',
      p_sig_id                 => 'PSA_INV_PARENT_REVERSAL_LINES',
      p_sig_sql                => 'SELECT aid1.invoice_id,
       aid1.invoice_distribution_id,
       aid1.parent_reversal_id,
       aid1.bc_event_id,aid1.encumbered_flag
FROM ap_invoice_distributions_all aid1,
     ap_invoice_distributions_all aid2
WHERE aid1.match_status_flag = ''T''
AND   aid1.parent_reversal_id is not null
AND   aid2.invoice_distribution_id = aid1.parent_reversal_id
AND   nvl(aid2.bc_event_id,-1) = nvl(aid1.bc_event_id,-1)
AND   aid1.set_of_books_id = aid2.set_of_books_id
AND   aid1.invoice_id = aid2.invoice_id
AND   aid1.invoice_id in (##$$INV$$##)',
      p_title                  => 'Parent and Reversal Invoice Lines Trying to Generate Encumbrance Accounting',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Parent and reversal invoice lines trying to generate encumbrance accounting.',
      p_solution               => 'Apply the data fix from [1349026/KB613273] to help resolve the issue.
',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_PARENT_REVERSAL_LINES');



debug('begin add_signature: PRC_SIG21_PO_AP_QV_Copy');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '21809',
      p_sig_id                 => 'PRC_SIG21_PO_AP_QV_Copy',
      p_sig_sql                => 'SELECT aid.invoice_id
     , ai.invoice_num
     , nvl(aid3.quantity_variance, aid3.amount_variance) variance
     , aid.invoice_distribution_id
     , aid.invoice_line_number
  FROM ap_invoices_all ai
     , ap_invoice_distributions_all aid
     , ap_invoice_distributions_all aid3,
(##$$IVIEW$$##) invs
 WHERE ai.invoice_id = invs.invoice_id
and ai.invoice_id = aid.invoice_id
   AND aid3.invoice_distribution_id = aid.invoice_distribution_id
   AND nvl(aid.quantity_variance, aid.amount_variance) IS NULL
   AND EXISTS
       ( SELECT ''reversed''
           FROM ap_invoice_distributions_all aid2
          WHERE aid.invoice_distribution_id = aid2.parent_reversal_id
            AND nvl(aid2.quantity_variance, aid2.amount_variance) IS NOT NULL )
         UNION
         SELECT aid.invoice_id
              , ai.invoice_num
              , nvl(aid.quantity_variance, aid.amount_variance) variance
              , aid.invoice_distribution_id
              , aid.invoice_line_number
           FROM ap_invoices_all ai
              , ap_invoice_distributions_all aid,
(##$$IVIEW$$##) invs
          WHERE ai.invoice_id = invs.invoice_id
and ai.invoice_id = aid.invoice_id
            AND nvl(aid.quantity_variance, aid.amount_variance) IS NOT NULL
            AND EXISTS
                ( SELECT ''not reversed''
                    FROM ap_invoice_distributions_all aid2
                   WHERE aid.invoice_distribution_id = aid2.parent_reversal_id
                     AND nvl(aid2.quantity_variance, aid2.amount_variance) IS NULL ) ',
      p_title                  => 'Purchase Order Active Encumbrance Due To Incorrect Quantity / Amount Variance',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Purchase Order Active Encumbrance incorrect due to Amount Variance',
      p_solution               => '- Option 1: Open an SR with Payables Support team for review of code level and any possible datafix referencing [2393099/KB786397] R12: AP: Purchase Order Active Encumbrance Due To Incorrect Quantity / Amount Variance
<br>- Option 2: Correct Invalid Active Encumbrance by Finally Close the PO. Refer to [2099907/KB716197] Encumbrance Accounting in Procure to Pay Business Flow for more information',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: PRC_SIG21_PO_AP_QV_Copy');



debug('begin add_signature: PSA_INV_HOLDS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2958',
      p_sig_id                 => 'PSA_INV_HOLDS',
      p_sig_sql                => 'SELECT apl.invoice_id,
     apl.hold_lookup_code,
     apl.hold_reason,
     apl.RELEASE_REASON,
     apl.STATUS_FLAG
FROM ap_holds_all apl
WHERE apl.hold_lookup_code in (''CANT FUNDS CHECK'',''INSUFFICIENT FUNDS'',''Encumbrance Acctg Fail'')
AND   apl.release_lookup_code is null
AND   apl.invoice_id in (##$$INV$$##)',
      p_title                  => 'Encumbrance Accounting and Funds Check Invoice Holds',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Invoices which are on hold due to "Insufficient Funds", "Encumbrance Acctg Fail" or "Cant Funds Check" holds.',
      p_solution               => '<ol>
<li>Verify PSA critical rollup patch(es) have been applied or not</li>
<li>Submit Budgetary Control Optimizer program,if not submitted.  ([1055606/KB633271]-> 3. Cleanup the Data)</li>
<li>Review and act on other signatures displayed on this PSA Data Validation report.</li>
<li>If the issue still persist,Log an SR with the following files:
  <ol type="A"> 
     <li>FND log of Invoice validation.</li>
     <li>Output of the this analyzer.</li>
     <li>Payables Invoice and EBTax Analyser.</li>
   </ol>
  </li>
</ol>',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_HOLDS');



debug('begin add_signature: PSA_INV_FUNDS_AVAILABLE_INFO_AP');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '22285',
      p_sig_id                 => 'PSA_INV_FUNDS_AVAILABLE_INFO_AP',
      p_sig_sql                => 'SELECT g.packet_id,
       g.application_id,
       g.ledger_id,
       g.status_code,
       g.funds_check_level_code,
       g.code_combination_id,
       g.accounted_dr,
       g.accounted_cr,
       nvl(g.budget_posted_balance, 0) + nvl(g.budget_approved_balance, 0) +
         nvl(g.budget_pending_balance, 0) budget_balance,
       nvl(g.encumbrance_posted_balance, 0) + nvl(g.encumbrance_approved_balance, 0) +
         nvl(g.encumbrance_pending_balance, 0) encumbrance_balance,
      nvl(g.actual_posted_balance, 0) + nvl(g.actual_approved_balance, 0) +
         nvl(g.actual_pending_balance, 0) actual_balance,
      (nvl(g.budget_posted_balance, 0) + nvl(g.budget_approved_balance, 0) +
         nvl(g.budget_pending_balance, 0)) -
         (nvl(g.encumbrance_posted_balance, 0) +
          nvl(g.encumbrance_approved_balance, 0) + nvl(g.encumbrance_pending_balance, 0)) -
         (nvl(g.actual_posted_balance, 0) + nvl(g.actual_approved_balance, 0) +
          nvl(g.actual_pending_balance, 0)) funds_available
FROM gl_bc_packets g
WHERE g.application_id = 200
AND   g.effect_on_funds_code = ''D''
AND   g.status_code = ''R''
AND   g.funds_check_level_code != ''N''
AND   (nvl(g.budget_posted_balance, 0) + nvl(g.budget_approved_balance, 0) +
       nvl(g.budget_pending_balance, 0) - nvl(g.encumbrance_posted_balance, 0) +
       nvl(g.encumbrance_approved_balance, 0) + nvl(g.encumbrance_pending_balance, 0) -
       nvl(g.actual_posted_balance, 0) + nvl(g.actual_approved_balance, 0) +
       nvl(g.actual_pending_balance, 0) - g.accounted_dr) < 0
AND   EXISTS (
        SELECT 1 FROM ap_invoice_distributions_all d
        WHERE d.invoice_id in (##$$INV$$##)
        AND   d.bc_event_id = g.event_id)',
      p_title                  => 'Funds Available Issues',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Funds available issues detected',
      p_solution               => '<ol>
 <li>Verify that the PSA critical rollup patch(es) have been applied (See the Recommended Patches section of this report)</li>
 <li>Submit the "Budgetary Control Optimizer" program, if you have not done so.  (See [1055606/KB633271] -> Item #3: "Cleanup the Data")</li>
 <li>Follow [1055606/KB633271] -> Section 4 "Funds Available Issues" (Items #4.1 to #4.4)</li>
</ol>',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_FUNDS_AVAILABLE_INFO_AP');



debug('begin add_signature: PRC_PSA_XLA_ACCOUNTING_ERRORS_COPY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '21818',
      p_sig_id                 => 'PRC_PSA_XLA_ACCOUNTING_ERRORS_COPY',
      p_sig_sql                => 'SELECT PXAE.*
FROM PSA_XLA_ACCOUNTING_ERRORS PXAE
WHERE APPLICATION_ID = 201
AND ENTITY_CODE      = ''PURCHASE_ORDER''
AND SOURCE_ID_INT_1  in (##$$HEADERID$$##)
UNION
SELECT PXAE.*
FROM PSA_XLA_ACCOUNTING_ERRORS PXAE,
  PO_DISTRIBUTIONS_ALL POD,
  PO_REQ_DISTRIBUTIONS_ALL PRD
WHERE PXAE.APPLICATION_ID   = 201
AND PXAE.SOURCE_ID_INT_1    = POD.PO_HEADER_ID
AND POD.REQ_DISTRIBUTION_ID = PRD.DISTRIBUTION_ID
AND PXAE.ENTITY_CODE        = ''REQUISITION''
AND POD.PO_HEADER_ID in (##$$HEADERID$$##)
UNION
SELECT PXAE.*
FROM PSA_XLA_ACCOUNTING_ERRORS PXAE,
  PO_DISTRIBUTIONS_ALL POD,
  AP_INVOICES_ALL AI,
  AP_INVOICE_DISTRIBUTIONS_ALL AID
WHERE PXAE.APPLICATION_ID  = 200
AND PXAE.SOURCE_ID_INT_1   = AI.INVOICE_ID
AND AI.INVOICE_ID          = AID.INVOICE_ID
AND AID.PO_DISTRIBUTION_ID = POD.PO_DISTRIBUTION_ID
AND PXAE.ENTITY_CODE       = ''AP_INVOICES''
AND POD.PO_HEADER_ID       in (##$$HEADERID$$##)',
      p_title                  => 'Encumbrance Accounting Errors',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Public Sector Encumbrance Accounting Errors on this invoice have been detected',
      p_solution               => 'Review the data displayed above for more information.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: PRC_PSA_XLA_ACCOUNTING_ERRORS_COPY');



debug('begin add_signature: PSA_BC_ACCOUNTING_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '22284',
      p_sig_id                 => 'PSA_BC_ACCOUNTING_ERRORS',
      p_sig_sql                => 'select * from psa_bc_accounting_errors where application_id = 200 and entity_id in (select e.entity_id from xla.xla_transaction_entities e where e.entity_code = ''AP_INVOICES'' and e.source_id_int_1 in (##$$INV$$##))',
      p_title                  => 'Budgetary Control Accounting Errors',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Public Sector accounting errors for the Budgetary Control on this invoice have been detected.',
      p_solution               => 'Please review the above ENCODED_MESSAGE for details of how to resolve this.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: PSA_BC_ACCOUNTING_ERRORS');



debug('begin add_signature: PSA_INV_SLA_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2960',
      p_sig_id                 => 'PSA_INV_SLA_ERRORS',
      p_sig_sql                => 'SELECT e.entity_id,       e.event_id,       xlaerr.encoded_msg
FROM xla_events                   e,
     xla.xla_transaction_entities xt,
     xla_accounting_errors        xlaerr,
     ap_invoices_all ai
WHERE ai.invoice_id in (##$$INV$$##)
AND   e.entity_id = xt.entity_id
AND   xt.application_id = 200
AND   nvl(xt.source_id_int_1,-99) = ai.invoice_id
AND   xt.ledger_id = ai.set_of_books_id
AND   xt.entity_code = ''AP_INVOICES''
AND   xlaerr.event_id = e.event_id
UNION
SELECT e.entity_id,       e.event_id,       xlaerr.encoded_message
FROM xla_events                   e,
     xla.xla_transaction_entities xt,
     psa_bc_accounting_errors        xlaerr,
     ap_invoices_all ai
WHERE ai.invoice_id  in (##$$INV$$##)
AND   e.entity_id = xt.entity_id
AND   xt.application_id = 200
AND   nvl(xt.source_id_int_1,-99) = ai.invoice_id
AND   xt.ledger_id = ai.set_of_books_id
AND   xt.entity_code = ''AP_INVOICES''
AND   xlaerr.event_id = e.event_id',
      p_title                  => 'Subledger Accounting (SLA) Errors',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Subledger Accounting errors exist for the specified invoice',
      p_solution               => 'Review and follow [1053172/KB559267] -> section 5 - SLA errors and data corruption note which contains solutions for different issues.',
      p_success_msg            => '',
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
debug('end add_signature: PSA_INV_SLA_ERRORS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_TOLERANCE_TEMPS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24991',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_TOLERANCE_TEMPS',
      p_sig_sql                => 'select * from AP_TOLERANCE_TEMPLATES where tolerance_id in
(select ss.tolerance_id from ap_supplier_sites ss, ap_invoices_all i where i.vendor_site_id = ss.vendor_site_id and i.invoice_id in (##$$INV$$##) 
union
select sp.tolerance_id from ap_system_parameters_all sp, ap_invoices_all i where i.invoice_id in (##$$INV$$##) and i.org_Id = sp.org_id)',
      p_title                  => 'Matching Tolerances',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Matching Tolerances',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_TOLERANCE_TEMPS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BC_PACKETS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24990',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_BC_PACKETS',
      p_sig_sql                => 'SELECT
    g.*
FROM
    gl_bc_packets                g,
    xla_events                   e,
    xla_transaction_entities_upg xt
WHERE
    xt.source_id_int_1 IN to_char(##$$INV$$##)
    AND xt.application_id = 200
        AND xt.entity_code = ''AP_INVOICES''
            AND e.entity_id = xt.entity_id
                AND e.application_id = 200
                    AND g.event_id = e.event_id
ORDER BY
    g.packet_id',
      p_title                  => 'Budgetary Control Details',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Budgetary Control Details',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BC_PACKETS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BUDGET_ASSIGNMENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24997',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_BUDGET_ASSIGNMENTS',
      p_sig_sql                => 'SELECT
    ba.*
FROM
    gl_bc_packets         g,
    gl_budget_assignments ba
WHERE
        application_id = 200
    AND g.code_combination_id = ba.code_combination_id
        AND EXISTS (
        SELECT
            1
        FROM
            ap_invoice_distributions_all d
        WHERE
                d.invoice_id in (##$$INV$$##)
           AND d.bc_event_id = g.event_id
    )',
      p_title                  => 'Budget Assignments',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Budget Assignments',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BUDGET_ASSIGNMENTS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BUDGET_OPTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24998',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_BUDGET_OPTIONS',
      p_sig_sql                => 'SELECT
    bco.*
FROM
    gl_bc_packets         g,
    gl_budget_assignments ba,
    gl_budorg_bc_options  bco
WHERE
        application_id = 200
    AND g.code_combination_id = ba.code_combination_id
        AND bco.range_id = ba.range_id
            AND EXISTS (
        SELECT
            1
        FROM
            ap_invoice_distributions_all d
        WHERE
                d.invoice_id in (##$$INV$$##)
            AND d.bc_event_id = g.event_id
    )',
      p_title                  => 'Budget Options',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Budget Options',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BUDGET_OPTIONS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_SUMMARY_TEMPLATE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24999',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_SUMMARY_TEMPLATE',
      p_sig_sql                => '    SELECT
    st.*
FROM
    gl_bc_packets        g,
    gl_summary_templates st
WHERE
        application_id = 200
    AND g.template_id IS NOT NULL
        AND st.template_id = g.template_id
            AND EXISTS (
        SELECT
            1
        FROM
            ap_invoice_distributions_all d
        WHERE
                d.invoice_id in (##$$INV$$##)
            AND d.bc_event_id = g.event_id
    )',
      p_title                  => 'Summary Template',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Summary Template Details',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_SUMMARY_TEMPLATE');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_SUMM_TEMP_BC_OPTION');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25000',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_SUMM_TEMP_BC_OPTION',
      p_sig_sql                => 'SELECT
    bc.*
FROM
    gl_bc_packets         g,
    gl_summary_templates  st,
    gl_summary_bc_options bc
WHERE
        application_id = 200
    AND g.template_id IS NOT NULL
    AND st.template_id = g.template_id
    AND bc.template_id = st.template_id       
    and exists (select 1        from ap_invoice_distributions_all d       where d.invoice_id in (##$$INV$$##)
AND d.bc_event_id = g.event_id)',
      p_title                  => 'Summary Template BC Option',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Summary Template BC Option',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_SUMM_TEMP_BC_OPTION');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_CODE_COMBINATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25001',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_CODE_COMBINATIONS',
      p_sig_sql                => 'SELECT
    k.*
FROM
    gl_bc_packets            g,
    gl_code_combinations_kfv k
WHERE
        application_id = 200
    AND g.code_combination_id = k.code_combination_id
        AND EXISTS (
        SELECT
            1
        FROM
            ap_invoice_distributions_all d
        WHERE
                d.invoice_id in (##$$INV$$##)
            AND d.bc_event_id = g.event_id
)',
      p_title                  => 'Code Combinations',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Code Combinations',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_CODE_COMBINATIONS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BALANCE_ENC_ACT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25002',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_BALANCE_ENC_ACT',
      p_sig_sql                => 'SELECT nvl(ap.encumbrance_type,''Actual'') Encumbrance_Type, 
Sum(nvl(l.accounted_dr,0)) Accounted_Amount_DR,
sum(nvl(l.accounted_cr,0)) Accounted_Amount_CR
FROM xla_ae_lines l, xla_ae_headers ah, xla_transaction_entities_upg xt, ap_invoices_all a, gl_encumbrance_types ap
WHERE l.ae_header_id = ah.ae_header_id 
AND invoice_id in (##$$INV$$##)
AND ah.entity_id =  xt.entity_id 
AND a.invoice_id = xt.source_id_int_1 
AND xt.application_id = 200 
AND xt.entity_code = ''AP_INVOICES'' 
AND ah.application_id = 200 
AND ap.encumbrance_type_id (+)= l.encumbrance_type_id 
AND l.accounting_class_code not in (''RFE'') 
GROUP BY nvl(ap.encumbrance_type,''Actual'') 
ORDER BY nvl(ap.encumbrance_type,''Actual'')',
      p_title                  => 'Balances - Encumbrance and Actual amounts',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Encumbrance and Actual amounts',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_BALANCE_ENC_ACT');



debug('begin add_signature: PSA_INV_PO_ENC_NOT_RELIEVED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '2966',
      p_sig_id                 => 'PSA_INV_PO_ENC_NOT_RELIEVED',
      p_sig_sql                => 'SELECT  invoice_id, sum(Accounted_Amount_DR) , sum(Accounted_Amount_CR)  FROM
(SELECT ai.invoice_id invoice_id, h.event_type_code event_type_code,
       sum(nvl(l.accounted_dr,0)) Accounted_Amount_DR,
       sum(nvl(l.accounted_cr,0)) Accounted_Amount_CR
FROM ap_invoices_all ai,
     xla_transaction_entities_upg xt,
     xla_ae_headers h,
     xla_ae_lines l,
     xla_events e
WHERE ai.invoice_id in (##$$INV$$##)
AND   l.ae_header_id = h.ae_header_id
AND   h.entity_id =  xt.entity_id
AND   nvl(xt.source_id_int_1,-99) = ai.invoice_id
AND   xt.ledger_id = ai.set_of_books_id
AND   xt.application_id = 200
AND   xt.entity_code = ''AP_INVOICES''
AND   h.application_id = 200
AND   h.balance_type_code = ''E''
AND   e.process_status_code = ''P''
AND   e.event_status_code = ''P''
AND   e.entity_id = xt.entity_id
AND   l.accounting_class_code not in ( ''RFE'',''PURCHASE_ORDER'')
AND   ap_invoices_utility_pkg.get_posting_status(ai.invoice_id) = ''Y''
GROUP BY ai.invoice_id, h.event_type_code
HAVING   sum(nvl(l.accounted_dr,0)) <> sum(nvl(l.accounted_cr,0))
UNION
SELECT aip.invoice_id invoice_id, h.event_type_code event_type_code,
       sum(nvl(l.accounted_dr,0)) Accounted_Amount_DR,
       sum(nvl(l.accounted_cr,0)) Accounted_Amount_CR
FROM
     ap_invoice_payments_all aip,
     xla_transaction_entities_upg xt,
     xla_ae_headers h,
     xla_ae_lines l,
     xla_events e
WHERE aip.invoice_id in (##$$INV$$##)
AND   l.ae_header_id = h.ae_header_id
AND   h.entity_id =  xt.entity_id
AND   nvl(xt.source_id_int_1,-99) = aip.check_id
AND   xt.ledger_id = aip.set_of_books_id
AND   xt.application_id = 200
AND   xt.entity_code = ''AP_PAYMENTS''
AND   h.application_id = 200
AND   h.balance_type_code = ''E''
AND   e.process_status_code = ''P''
AND   e.event_status_code = ''P''
AND   e.entity_id = xt.entity_id
AND   l.accounting_class_code not in ( ''RFE'')
GROUP BY aip.invoice_id, h.event_type_code
HAVING   sum(nvl(l.accounted_dr,0)) <> sum(nvl(l.accounted_cr,0))
ORDER BY invoice_id, event_type_code )
GROUP BY invoice_id
HAVING sum(Accounted_Amount_DR) <> sum(Accounted_Amount_CR)',
      p_title                  => 'Balances - Encumbrance Balance not Relieved by Payables',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Encumbrance Balance not Relieved by Payables',
      p_solution               => 'Accounting will have to be undone for the affected invoices.<br><br>

1) Please run the psa_invoice_reversal_sel.sql selection script and log a service request against Payables (AP) to obtain the data fix. <br>
The selection script can be downloaded from [2086996/KB550563]; it is part of PSA Data Validation Analyzer zip file (psa_data_analyzer.zip)<br>
<br>
2) Review [1053172/KB559267], point 4.2) Encumbrance Balance not relieved by Payables<br>
<ul><li> For a fully accounted invoice, the encumbrance balance should be 0.</li>
   <li> The invoice encumbrance generated during validation should be fully relieved during invoice accounting.</li>
<li> If the invoice is fully accounted for, then expect this to return no rows.</li>
</ul>
3) If the invoice is fully/partially accounted, perform an undo accounting using instructions from [753695/KB218158].',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: PSA_INV_PO_ENC_NOT_RELIEVED');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_UNENC_PREP');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25004',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_UNENC_PREP',
      p_sig_sql                => '    SELECT
    ai.invoice_id  prepayment_id,
    ai.invoice_num prepayment_num,
    aid.invoice_distribution_id,
    aid.encumbered_flag,
    aid.match_status_flag,
    aid.bc_event_id
FROM
    ap_invoices_all              ai,
    ap_invoice_distributions_all aid
WHERE
        ai.invoice_id = aid.invoice_id
    AND ( aid.encumbered_flag <> ''Y''
          OR bc_event_id IS NULL )
        AND aid.match_status_flag = ''A''
            AND ai.invoice_type_lookup_code = ''PREPAYMENT''
                AND ai.invoice_id IN (
        SELECT DISTINCT
            l.prepay_invoice_id
        FROM
            ap_invoices_all      a, ap_invoice_lines_all l
        WHERE
                a.invoice_id = l.invoice_id
            AND a.invoice_id in (##$$INV$$##)
    )
ORDER BY
    ai.invoice_id,
    aid.invoice_distribution_id',
      p_title                  => 'Unencumbered Prepayments Applied',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Unencumbered Prepayments Applied ',
      p_solution               => '1) Apply PSA Patches from R12: How To Troubleshoot Funds Check Hold Issues On Payables Invoices [1055606/KB633271] <br>br> 2) Run point 3. Cleanup the Data from [1055606/KB633271] - Budgetary Control Optimizer.
',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_UNENC_PREP');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_UNENC_PO_MATCHED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25005',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_UNENC_PO_MATCHED',
      p_sig_sql                => 'SELECT
    aid.invoice_id                     invoice_id,
    po.po_header_id                    po_header_id,
    pod.line_location_id,
    pod.po_distribution_id,
    pod.encumbered_flag,
    substr(po.segment1, 1, 15)         po_number,
    substr(pl.line_num, 1, 4)          line_number,
    substr(pll.shipment_num, 1, 8)     shipment_number,
    substr(pod.distribution_num, 1, 4) dist_number,
    po.closed_code                     po_status,
    pll.closed_code                    shipment_status,
    aid.invoice_distribution_id
FROM
    ap_invoice_distributions_all aid,
    po_headers_all               po,
    po_distributions_all         pod,
    po_line_locations_all        pll,
    po_lines_all                 pl
WHERE
        aid.invoice_id in (##$$INV$$##)
    AND aid.po_distribution_id = pod.po_distribution_id
        AND pod.po_header_id = po.po_header_id
            AND pll.line_location_id = pod.line_location_id
             AND pll.po_line_id = pl.po_line_id  -- Added join to po_lines_all  REQ 220083 29/4/25
             AND pod.po_line_id = pl.po_line_id  -- Added join to po_lines_all REQ 220083 29/4/25
            AND pll.po_line_id = pod.po_line_id
                    AND pod.encumbered_flag <> ''Y''
                        AND pod.accrue_on_receipt_flag = ''N''
                            AND nvl(pll.closed_code, ''OPEN'') <> ''FINALLY CLOSED''',
      p_title                  => 'Unencumbered PO Matched',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Unencumbered PO is matched to an invoice',
      p_solution               => 'a) Verify within the "Proactive Recommendations" section of this analyzer that both the PSA RPC and the PSA Related Product RPC patches are all applied:<br><br>
<b>For R12.0 and R12.1:</b> Patch 22850140<br>
<b>For R12.2:</b> Patch 22850140 <b>and</b> the following additional patches: 17813590:R12.AP.C, 22117915:R12.AP.C and 22536210:R12.AP.C.<br>
<br>
<b>IMPORTANT:</b> These patches have the latest fixes related to budgetary control for Payables and are required to prevent known code issues and deliver an enhanced version of the "Budgetary Control Optimizer Program".
<br><br>
b) Cleanup the Data - Run Budgetary Control Optimizer Program with Shortname = BCOPT
<br>c) Run the "Budgetary Control Information for Payables Invoice" diagnostic [979855/KB550140].
<br>
d) As detailed in [1053172/KB559267] Section 6.2 a data fix will likely needed from the Oracle Purchasing team for help to encumber the non encumbered Purchase orders so please log an SR with the output of both this analzyer and the diagnostic from c).',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_UNENC_PO_MATCHED');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_NOT_MATCHED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25006',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_NOT_MATCHED',
      p_sig_sql                => '    SELECT
    ai.invoice_id,
    ail.line_number,
    ai.po_header_id,
    ail.match_type
FROM
    ap_invoices_all      ai,
    ap_invoice_lines_all ail
WHERE
    ai.po_header_id IS NOT NULL
    AND ail.match_type = ''NOT_MATCHED''
        AND ai.invoice_id = ail.invoice_id
            AND ai.invoice_id in (##$$INV$$##)',
      p_title                  => 'PO_HEADER_ID Stamped but PO is Not Matched ',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'PO_HEADER_ID stamped but PO is not matched ',
      p_solution               => 'As detailed in Section 4 [1446360/KB786606], get the latest available version for APXINLIN.pld. <br><br>At this moment, the following patches are released:<br>
12.2: 35300212:R12.AP.C<br>
12.1:  35300212:R12.AP.B<br>
12.0: 26100681:R12.AP.A<br>
',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_NOT_MATCHED');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_CANT_FUNDS_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25008',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_CANT_FUNDS_CHECK',
      p_sig_sql                => '            SELECT
    inv.invoice_id invoice_id,
    aid.invoice_distribution_id,
    aid.prepay_distribution_id,
    (
        SELECT
            segment1
        FROM
            po_headers_all
        WHERE
            po_header_id = lines.po_header_id
    )              po_number,
    lines.prepay_invoice_id,
    (
        SELECT
            invoice_num
        FROM
            ap_invoices_all
        WHERE
            invoice_id = lines.prepay_invoice_id
    )              prepay_invoice_num
FROM
    ap_invoices_all              inv,
    ap_invoice_lines_all         lines,
    ap_invoice_distributions_all aid
WHERE
        aid.line_type_lookup_code = ''PREPAY''
    AND aid.po_distribution_id IS NOT NULL
        AND aid.invoice_id = inv.invoice_id
            AND lines.invoice_id = inv.invoice_id
                AND aid.prepay_distribution_id IS NOT NULL
                    AND EXISTS (
        SELECT
            1
        FROM
            ap_invoice_distributions_all dist
        WHERE
                aid.prepay_distribution_id = dist.invoice_distribution_id
            AND dist.po_distribution_id IS NULL
    )
                        AND inv.invoice_id in (##$$INV$$##)
ORDER BY
    aid.prepay_distribution_id',
      p_title                  => 'Zero Amount Invoice Distribution causing Cant Funds Check Hold',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Zero amount NONREC_TAX distribution causing Can''t Funds Check hold',
      p_solution               => 'As detailed in Section 4 [1446360/KB786606] <br><br>1)<b> Apply latest PSA Rollup Patch</b>: <br><br>Patch:14563642:R12.PSA.A<br>Patch:19266556:R12.PSA.B<br>Patch:22850140:R12.PSA.C<br><br> 2)<b> Run the Budgetary Control Optimizer concurrent program</b>.',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_CANT_FUNDS_CHECK');



debug('begin add_signature: EBS_FIN_AP_PREP_NOT_MATCHED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '25007',
      p_sig_id                 => 'EBS_FIN_AP_PREP_NOT_MATCHED',
      p_sig_sql                => ' SELECT
    inv.invoice_id,
    aid.invoice_distribution_id,
    aid.prepay_distribution_id,
    poh.segment1 AS po_number,
    lines.prepay_invoice_id,
    prepay_inv.invoice_num AS prepay_invoice_num
FROM
    ap_invoices_all inv
JOIN
    ap_invoice_lines_all lines ON inv.invoice_id = lines.invoice_id
JOIN
    ap_invoice_distributions_all aid ON inv.invoice_id = aid.invoice_id
JOIN
    po_headers_all poh ON lines.po_header_id = poh.po_header_id
JOIN
    ap_invoices_all prepay_inv ON lines.prepay_invoice_id = prepay_inv.invoice_id
WHERE
    aid.line_type_lookup_code = ''PREPAY''
    AND aid.po_distribution_id IS NOT NULL
    AND aid.prepay_distribution_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1
        FROM ap_invoice_distributions_all dist
        WHERE aid.prepay_distribution_id = dist.invoice_distribution_id
              AND dist.po_distribution_id IS NOT NULL
    )
                        AND inv.invoice_id in (##$$INVS$$##)
ORDER BY
    aid.prepay_distribution_id',
      p_title                  => 'Prepayment Invoice not Matched',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Prepayment Application Lines on Standard Invoices with a PO_HEADER_ID but corresponding Prepayment Invoice is not PO matched',
      p_solution               => 'Follow the instructions as detailed in [1992985/KB409532] and log an SR with the output of this analyser to request a data fix to null out the PO_HEADER_ID.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_PREP_NOT_MATCHED');



debug('begin add_signature: APLIST_10_AP_SYSTEM_PARAMETERS_ALL');
   l_info('##MASK##FEDERAL_IDENTIFICATION_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10412',
      p_sig_id                 => 'APLIST_10_AP_SYSTEM_PARAMETERS_ALL',
      p_sig_sql                => 'SELECT distinct asp.* FROM ap_invoices_all ai, AP_SYSTEM_PARAMETERS_ALL asp WHERE asp.org_id = ai.org_id and ai.invoice_id in (##$$ICVIEW$$##)',
      p_title                  => 'AP_SYSTEM_PARAMETERS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: APLIST_10_AP_SYSTEM_PARAMETERS_ALL');



debug('begin add_signature: APLIST_20_FINANCIALS_SYSTEM_PARAMS_ALL');
   l_info('##MASK##VAT_REGISTRATION_NUM'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10413',
      p_sig_id                 => 'APLIST_20_FINANCIALS_SYSTEM_PARAMS_ALL',
      p_sig_sql                => 'SELECT fsp.* FROM ap_invoices_all ai, FINANCIALS_SYSTEM_PARAMS_ALL fsp WHERE fsp.org_id = ai.org_id and ai.invoice_id in (##$$ICVIEW$$##)',
      p_title                  => 'FINANCIALS_SYSTEM_PARAMS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_20_FINANCIALS_SYSTEM_PARAMS_ALL');



debug('begin add_signature: APLIST_30_HR_OPERATING_UNITS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10414',
      p_sig_id                 => 'APLIST_30_HR_OPERATING_UNITS',
      p_sig_sql                => 'SELECT hou.* FROM ap_invoices_all ai, HR_OPERATING_UNITS hou WHERE hou.organization_id = ai.org_id and ai.invoice_id in (##$$ICVIEW$$##)',
      p_title                  => 'HR_OPERATING_UNITS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_30_HR_OPERATING_UNITS');



debug('begin add_signature: APLIST_40_GL_LEDGERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10415',
      p_sig_id                 => 'APLIST_40_GL_LEDGERS',
      p_sig_sql                => 'select distinct gl.* from ap_invoices_all ai, gl_ledgers gl, gl_ledger_relationships glr1, gl_ledger_relationships glr2, gl_ledger_relationships glr3 where glr3.source_ledger_id = ai.set_of_books_id and ai.invoice_id in (##$$ICVIEW$$##)
and glr3.source_ledger_id = glr2.primary_ledger_id and glr2.target_ledger_id = glr1.primary_ledger_id and gl.ledger_id = glr1.source_ledger_id',
      p_title                  => 'GL_LEDGERS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_40_GL_LEDGERS');



debug('begin add_signature: APLIST_80_GL_LEDGER_CONFIG_DETAILS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10556',
      p_sig_id                 => 'APLIST_80_GL_LEDGER_CONFIG_DETAILS',
      p_sig_sql                => 'select distinct glcd2.* from ap_invoices_all ai, GL_LEDGER_CONFIG_DETAILS glcd1, GL_LEDGER_CONFIG_DETAILS glcd2 where ai.legal_entity_id = glcd1.object_id and glcd1.configuration_id = glcd2.configuration_id and glcd1.object_type_code = ''LEGAL_ENTITY'' and ai.invoice_id  in (##$$ICVIEW$$##) order by glcd2.object_id',
      p_title                  => 'GL_LEDGER_CONFIG_DETAILS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_80_GL_LEDGER_CONFIG_DETAILS');



debug('begin add_signature: APLIST_90_GL_LEDGER_RELATIONSHIPS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10557',
      p_sig_id                 => 'APLIST_90_GL_LEDGER_RELATIONSHIPS',
      p_sig_sql                => 'select distinct glr1.* from ap_invoices_all ai, gl_ledgers gl, gl_ledger_relationships glr1, gl_ledger_relationships glr2, gl_ledger_relationships glr3 where glr3.source_ledger_id = ai.set_of_books_id and ai.invoice_id in (##$$ICVIEW$$##) and glr3.source_ledger_id = glr2.primary_ledger_id and glr2.target_ledger_id = glr1.primary_ledger_id and gl.ledger_id = glr1.source_ledger_id',
      p_title                  => 'GL_LEDGER_RELATIONSHIPS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_90_GL_LEDGER_RELATIONSHIPS');



debug('begin add_signature: APLIST_100_GL_LEGAL_ENTITIES_BSVS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10558',
      p_sig_id                 => 'APLIST_100_GL_LEGAL_ENTITIES_BSVS',
      p_sig_sql                => 'SELECT * FROM GL_LEGAL_ENTITIES_BSVS WHERE legal_entity_id IN ( select distinct glcd2.object_id from ap_invoices_all ai, GL_LEDGER_CONFIG_DETAILS glcd1, GL_LEDGER_CONFIG_DETAILS glcd2 where ai.legal_entity_id = glcd1.object_id and glcd1.configuration_id = glcd2.configuration_id and glcd1.object_type_code = ''LEGAL_ENTITY'' and ai.invoice_id in (##$$ICVIEW$$##) and glcd1.object_type_code = glcd2.object_type_code)',
      p_title                  => 'GL_LEGAL_ENTITIES_BSVS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_100_GL_LEGAL_ENTITIES_BSVS');



debug('begin add_signature: APLIST_110_GL_LEDGER_NORM_SEG_VALS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10565',
      p_sig_id                 => 'APLIST_110_GL_LEDGER_NORM_SEG_VALS',
      p_sig_sql                => 'SELECT DISTINCT gl.* FROM ap_invoices_all ai, GL_LEDGER_NORM_SEG_VALS gl, gl_ledger_relationships glr1, gl_ledger_relationships glr2, gl_ledger_relationships glr3 WHERE glr3.source_ledger_id = ai.set_of_books_id AND ai.invoice_id in (##$$ICVIEW$$##) AND glr3.source_ledger_id = glr2.primary_ledger_id AND glr2.target_ledger_id = glr1.primary_ledger_id AND gl.ledger_id = glr1.source_ledger_id ORDER BY gl.ledger_id',
      p_title                  => 'GL_LEDGER_NORM_SEG_VALS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_110_GL_LEDGER_NORM_SEG_VALS');



debug('begin add_signature: APLIST_260_AP_BATCHES_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10720',
      p_sig_id                 => 'APLIST_260_AP_BATCHES_ALL',
      p_sig_sql                => 'SELECT * FROM AP_BATCHES_ALL WHERE batch_id IN ( SELECT batch_id FROM AP_INVOICES_ALL WHERE invoice_id in (##$$ICVIEW$$##))',
      p_title                  => 'AP_BATCHES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_260_AP_BATCHES_ALL');



debug('begin add_signature: APLIST_70_XLA_SUBLEDGERS2');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10555',
      p_sig_id                 => 'APLIST_70_XLA_SUBLEDGERS2',
      p_sig_sql                => 'SELECT DISTINCT * FROM XLA_SUBLEDGERS WHERE application_id = 200',
      p_title                  => 'XLA_SUBLEDGERS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_70_XLA_SUBLEDGERS2');



debug('begin add_signature: APLIST_150_AP_INVOICES_ALL_SUMMARY');
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10569',
      p_sig_id                 => 'APLIST_150_AP_INVOICES_ALL_SUMMARY',
      p_sig_sql                => 'SELECT ai.invoice_id, ai.invoice_num, aps.vendor_id, aps.vendor_name,
ai.invoice_date, ai.invoice_amount, ai.base_amount,
substr(ai.invoice_type_lookup_code,1,15) invoice_type_lookup_code,
substr(ai.invoice_currency_code,1,3) invoice_currency_code,
substr(ai.payment_currency_code,1,3) payment_currency_code, ai.legal_entity_id, ai.org_id 
FROM AP_INVOICES_ALL ai, AP_SUPPLIERS aps, AP_SUPPLIER_SITES_ALL avs WHERE ai.invoice_id in(##$$ICVIEW$$##) AND ai.vendor_id = aps.vendor_id(+) AND ai.vendor_site_id = avs.vendor_site_id(+) ORDER BY ai.invoice_id asc',
      p_title                  => 'AP_INVOICES_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_150_AP_INVOICES_ALL_SUMMARY');



debug('begin add_signature: APLIST_170_AP_INVOICE_LINES_ALL_SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10570',
      p_sig_id                 => 'APLIST_170_AP_INVOICE_LINES_ALL_SUMMARY',
      p_sig_sql                => 'SELECT invoice_id, line_number, line_type_lookup_code, line_source,accounting_date, period_name, amount, base_amount, summary_tax_line_id, deferred_acctg_flag, org_id, discarded_flag, cancelled_flag, generate_dists
FROM AP_INVOICE_LINES_ALL 
WHERE invoice_id in (##$$ICVIEW$$##) order by line_number asc',
      p_title                  => 'AP_INVOICE_LINES_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_170_AP_INVOICE_LINES_ALL_SUMMARY');



debug('begin add_signature: APLIST_170_AP_INVOICE_DISTS_ALL_SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10571',
      p_sig_id                 => 'APLIST_170_AP_INVOICE_DISTS_ALL_SUMMARY',
      p_sig_sql                => 'SELECT invoice_id, invoice_line_number, substr(distribution_line_number,1,8) distribution_line_number, substr(line_type_lookup_code,1,9) line_type_lookup_code, accounting_date, period_name, amount, base_amount, posted_flag, match_status_flag, encumbered_flag, historical_flag, substr(dist_code_combination_id,1,15) dist_code_combination_id, substr(accounting_event_id,1,15) accounting_event_id, substr(bc_event_id,1,15) bc_event_id, substr(invoice_distribution_id,1,15) invoice_distribution_id, substr(parent_reversal_id,1,15) parent_reversal_id, substr(po_distribution_id,1,15) po_distribution_id, summary_tax_line_id, detail_tax_dist_id, org_id FROM AP_INVOICE_DISTRIBUTIONS_ALL WHERE invoice_id in (##$$ICVIEW$$##) ORDER BY invoice_line_number, distribution_line_number asc',
      p_title                  => 'AP_INVOICE_DISTRIBUTIONS_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_170_AP_INVOICE_DISTS_ALL_SUMMARY');



debug('begin add_signature: APLIST_190_AP_HOLDS_ALL_SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10573',
      p_sig_id                 => 'APLIST_190_AP_HOLDS_ALL_SUMMARY',
      p_sig_sql                => 'SELECT held_by, hold_date, hold_lookup_code, substr(hold_reason,1,25) hold_reason, invoice_id, release_lookup_code, substr(release_reason,1,25) release_reason, status_flag, org_id FROM AP_HOLDS_ALL WHERE invoice_id  in (##$$ICVIEW$$##)',
      p_title                  => 'AP_HOLDS_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: APLIST_190_AP_HOLDS_ALL_SUMMARY');



debug('begin add_signature: APLIST_270_AP_INVOICES_ALL_INVS');
   l_info('##MASK##ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##CUST_REGISTRATION_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##GLOBAL_ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##INTERNAL_CONTACT_EMAIL'):= 'REMOVE_COLUMN';
   l_info('##MASK##REMIT_TO_SUPPLIER_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '22234',
      p_sig_id                 => 'APLIST_270_AP_INVOICES_ALL_INVS',
      p_sig_sql                => 'SELECT distinct ai.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'', gl.chart_of_accounts_id , ai.accts_pay_code_combination_id) "Accts Pay Account" FROM AP_INVOICES_ALL ai, gl_ledgers gl WHERE gl.ledger_id = ai.set_of_books_id
and ai.invoice_id IN ( ##$$ICVIEW$$##) 
ORDER BY ai.invoice_id asc',
      p_title                  => 'AP_INVOICES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: APLIST_270_AP_INVOICES_ALL_INVS');



debug('begin add_signature: APLIST_290_AP_INVOICE_LINES_ALL');
   l_info('##MASK##ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##GLOBAL_ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##MERCHANT_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##MERCHANT_TAXPAYER_ID'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MERCHANT_TAX_REG_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10722',
      p_sig_id                 => 'APLIST_290_AP_INVOICE_LINES_ALL',
      p_sig_sql                => 'SELECT * FROM AP_INVOICE_LINES_ALL WHERE invoice_id in (##$$ICVIEW$$##)',
      p_title                  => 'AP_INVOICE_LINES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: APLIST_290_AP_INVOICE_LINES_ALL');



debug('begin add_signature: APLIST_300_AP_INVOICE_DISTRIBUTIONS_ALL');
   l_info('##MASK##ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##MERCHANT_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##MERCHANT_TAXPAYER_ID'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MERCHANT_TAX_REG_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10723',
      p_sig_id                 => 'APLIST_300_AP_INVOICE_DISTRIBUTIONS_ALL',
      p_sig_sql                => 'SELECT aid.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , aid.accts_pay_code_combination_id) "Accts Pay Account", fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , aid.dist_code_combination_id) "Dist Account" FROM AP_INVOICE_DISTRIBUTIONS_ALL aid, GL_LEDGERS GL, AP_SYSTEM_PARAMETERS_ALL ASP
WHERE aid.invoice_id in (##$$ICVIEW$$##) 
AND GL.LEDGER_ID = ASP.SET_OF_BOOKS_ID
AND ASP.ORG_ID = AID.ORG_ID
ORDER BY aid.invoice_id, aid.invoice_line_number, aid.distribution_line_number asc',
      p_title                  => 'AP_INVOICE_DISTRIBUTIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_300_AP_INVOICE_DISTRIBUTIONS_ALL');



debug('begin add_signature: APLIST_390_AP_HOLDS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10733',
      p_sig_id                 => 'APLIST_390_AP_HOLDS_ALL',
      p_sig_sql                => 'SELECT * FROM AP_HOLDS_ALL WHERE invoice_id  IN (##$$ICVIEW$$##)
',
      p_title                  => 'AP_HOLDS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: APLIST_390_AP_HOLDS_ALL');



debug('begin add_signature: APLIST_400_AP_HOLD_CODES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10734',
      p_sig_id                 => 'APLIST_400_AP_HOLD_CODES',
      p_sig_sql                => 'SELECT * FROM AP_HOLD_CODES WHERE hold_lookup_code IN ( SELECT hold_lookup_code FROM AP_HOLDS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) )',
      p_title                  => 'AP_HOLD_CODES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_400_AP_HOLD_CODES');



debug('begin add_signature: APLIST_320_AP_INVOICE_DISTS_ARCH');
   l_info('##MASK##MERCHANT_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##MERCHANT_TAXPAYER_ID'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MERCHANT_TAX_REG_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10724',
      p_sig_id                 => 'APLIST_320_AP_INVOICE_DISTS_ARCH',
      p_sig_sql                => 'select aidh.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'', gl.chart_of_accounts_id , aidh.accts_pay_code_combination_id) "Accts Pay Account", fnd_flex_ext.get_segs(''SQLGL'',''GL#'',  gl.chart_of_accounts_id , aidh.dist_code_combination_id) "Dist Account" from ap_invoice_dists_arch aidh, gl_ledgers gl, ap_system_parameters_all asp WHERE aidh.invoice_id in (##$$ICVIEW$$##) 
and asp.org_id = aidh.org_id
and asp.set_of_books_id = gl.ledger_id
ORDER BY aidh.invoice_distribution_id, aidh.invoice_line_number, aidh.distribution_line_number asc',
      p_title                  => 'AP_INVOICE_DISTS_ARCH',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_320_AP_INVOICE_DISTS_ARCH');



debug('begin add_signature: APLIST_430_AP_INVOICE_PREPAYS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10861',
      p_sig_id                 => 'APLIST_430_AP_INVOICE_PREPAYS_ALL',
      p_sig_sql                => 'SELECT * FROM AP_INVOICE_PREPAYS_ALL WHERE invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_INVOICE_PREPAYS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_430_AP_INVOICE_PREPAYS_ALL');



debug('begin add_signature: APLIST_440_AP_CHRG_ALLOCATIONS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10862',
      p_sig_id                 => 'APLIST_440_AP_CHRG_ALLOCATIONS_ALL',
      p_sig_sql                => 'SELECT distinct aca.* FROM AP_CHRG_ALLOCATIONS_ALL aca, AP_INVOICE_DISTRIBUTIONS_ALL aid WHERE ( aca.charge_dist_id = aid.invoice_distribution_id OR aca.item_dist_id = aid.invoice_distribution_id ) AND aid.invoice_id IN (##$$ICVIEW$$##) ORDER BY aca.charge_dist_id',
      p_title                  => 'AP_CHRG_ALLOCATIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_440_AP_CHRG_ALLOCATIONS_ALL');



debug('begin add_signature: APLIST_340_ZX_LINES_SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10726',
      p_sig_id                 => 'APLIST_340_ZX_LINES_SUMMARY',
      p_sig_sql                => 'SELECT * FROM zx_lines_summary WHERE application_id = 200 AND entity_code = ''AP_INVOICES'' AND trx_id IN (##$$ICVIEW$$##) AND event_class_code in (''STANDARD INVOICES'' , ''PREPAYMENT INVOICES'', ''EXPENSE REPORTS'')',
      p_title                  => 'ZX_LINES_SUMMARY',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_340_ZX_LINES_SUMMARY');



debug('begin add_signature: APLIST_330_ZX_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10725',
      p_sig_id                 => 'APLIST_330_ZX_LINES',
      p_sig_sql                => 'SELECT * FROM ZX_LINES WHERE application_id = 200 AND entity_code = ''AP_INVOICES'' AND trx_id IN (##$$ICVIEW$$##) AND event_class_code in (''STANDARD INVOICES'' , ''PREPAYMENT INVOICES'', ''EXPENSE REPORTS'')',
      p_title                  => 'ZX_LINES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_330_ZX_LINES');



debug('begin add_signature: APLIST_450_AP_INV_APRVL_HIST_ALL');
   l_info('##MASK##APPROVER_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10863',
      p_sig_id                 => 'APLIST_450_AP_INV_APRVL_HIST_ALL',
      p_sig_sql                => 'SELECT * FROM AP_INV_APRVL_HIST_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ORDER BY 1',
      p_title                  => 'AP_INV_APRVL_HIST_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_450_AP_INV_APRVL_HIST_ALL');



debug('begin add_signature: APLIST_250_ZX_REC_NREC_DIST');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10727',
      p_sig_id                 => 'APLIST_250_ZX_REC_NREC_DIST',
      p_sig_sql                => 'SELECT * FROM zx_rec_nrec_dist WHERE application_id = 200 AND entity_code = ''AP_INVOICES'' AND trx_id in (##$$ICVIEW$$##) AND event_class_code in (''STANDARD INVOICES'' , ''PREPAYMENT INVOICES'', ''EXPENSE REPORTS'')',
      p_title                  => 'ZX_REC_NREC_DIST',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_250_ZX_REC_NREC_DIST');



debug('begin add_signature: APLIST_360_ZX_LINES_DET_FACTORS');
   l_info('##MASK##MERCHANT_PARTY_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10728',
      p_sig_id                 => 'APLIST_360_ZX_LINES_DET_FACTORS',
      p_sig_sql                => 'SELECT * FROM zx_lines_det_factors WHERE application_id = 200 AND entity_code = ''AP_INVOICES'' AND trx_id IN (##$$ICVIEW$$##) AND event_class_code in (''STANDARD INVOICES'' , ''PREPAYMENT INVOICES'', ''EXPENSE REPORTS'')',
      p_title                  => 'ZX_LINES_DET_FACTORS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_360_ZX_LINES_DET_FACTORS');



debug('begin add_signature: APLIST_120_XLE_ENTITY_PROFILES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10566',
      p_sig_id                 => 'APLIST_120_XLE_ENTITY_PROFILES',
      p_sig_sql                => 'SELECT * FROM XLE_ENTITY_PROFILES WHERE legal_entity_id IN ( select distinct glcd2.object_id from ap_invoices_all ai, GL_LEDGER_CONFIG_DETAILS glcd1, GL_LEDGER_CONFIG_DETAILS glcd2 where ai.legal_entity_id = glcd1.object_id and glcd1.configuration_id = glcd2.configuration_id and glcd1.object_type_code = ''LEGAL_ENTITY'' and ai.invoice_id in (##$$ICVIEW$$##) and glcd1.object_type_code = glcd2.object_type_code )',
      p_title                  => 'XLE_ENTITY_PROFILES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_120_XLE_ENTITY_PROFILES');



debug('begin add_signature: APLIST_130_FND_PRODUCT_INSTALLATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10567',
      p_sig_id                 => 'APLIST_130_FND_PRODUCT_INSTALLATIONS',
      p_sig_sql                => 'SELECT * FROM FND_PRODUCT_INSTALLATIONS WHERE application_id = 200',
      p_title                  => 'FND_PRODUCT_INSTALLATIONS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_130_FND_PRODUCT_INSTALLATIONS');



debug('begin add_signature: APLIST_140_FND_PRODUCT_GROUPS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10568',
      p_sig_id                 => 'APLIST_140_FND_PRODUCT_GROUPS',
      p_sig_sql                => 'SELECT * FROM FND_PRODUCT_GROUPS',
      p_title                  => 'FND_PRODUCT_GROUPS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_140_FND_PRODUCT_GROUPS');



debug('begin add_signature: APLIST_180_AP_PAYMENT_SCHED_ALL_SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10572',
      p_sig_id                 => 'APLIST_180_AP_PAYMENT_SCHED_ALL_SUMMARY',
      p_sig_sql                => 'SELECT amount_remaining, batch_id, due_date, gross_amount, hold_flag, invoice_id, payment_num, substr(payment_status_flag,1,1) payment_status_flag, org_id FROM AP_PAYMENT_SCHEDULES_ALL WHERE invoice_id in (##$$ICVIEW$$##)',
      p_title                  => 'AP_PAYMENT_SCHEDULES_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_180_AP_PAYMENT_SCHED_ALL_SUMMARY');



debug('begin add_signature: APLIST_200_AP_DOCUMENTS_PAYABLE_SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10574',
      p_sig_id                 => 'APLIST_200_AP_DOCUMENTS_PAYABLE_SUMMARY',
      p_sig_sql                => 'SELECT pay_proc_trxn_type_code, calling_app_doc_unique_ref1 check_id, calling_app_doc_unique_ref2 invoice_id, calling_app_doc_unique_ref4 invoice_payment_id, calling_app_doc_ref_number invoice_number, payment_function, payment_date, document_date, document_type, payment_currency_code, payment_amount, payment_method_code FROM AP_DOCUMENTS_PAYABLE WHERE calling_app_id = 200 AND calling_app_doc_unique_ref2 in (##$$ICVIEW$$##)',
      p_title                  => 'AP_DOCUMENTS_PAYABLE (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_200_AP_DOCUMENTS_PAYABLE_SUMMARY');



debug('begin add_signature: APLIST_210_AP_INVOICE_PAYMENTS_ALL _SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10575',
      p_sig_id                 => 'APLIST_210_AP_INVOICE_PAYMENTS_ALL _SUMMARY',
      p_sig_sql                => 'SELECT check_id, substr(invoice_payment_id,1,15) invoice_payment_id, amount, payment_base_amount, invoice_base_amount, accounting_date, period_name, posted_flag, accounting_event_id, invoice_id, org_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id in (##$$ICVIEW$$##) ORDER BY check_id asc',
      p_title                  => 'AP_INVOICE_PAYMENTS_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_210_AP_INVOICE_PAYMENTS_ALL _SUMMARY');



debug('begin add_signature: APLIST_220_AP_CHECKS_ALL _SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10576',
      p_sig_id                 => 'APLIST_220_AP_CHECKS_ALL _SUMMARY',
      p_sig_sql                => 'SELECT check_id, check_number, vendor_site_code, amount, base_amount, checkrun_id, checkrun_name, check_date, substr(status_lookup_code,1,15) status_lookup_code, void_date, org_id FROM AP_CHECKS_ALL WHERE check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id in (##$$ICVIEW$$##) )',
      p_title                  => 'AP_CHECKS_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_220_AP_CHECKS_ALL _SUMMARY');



debug('begin add_signature: APLIST_230_AP_PAYMENT_HISTORY_ALL_SUMMARY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10577',
      p_sig_id                 => 'APLIST_230_AP_PAYMENT_HISTORY_ALL_SUMMARY',
      p_sig_sql                => 'SELECT payment_history_id, check_id, accounting_date, substr(transaction_type,1,20) transaction_type, posted_flag, substr(accounting_event_id,1,10) accounting_event_id, rev_pmt_hist_id, org_id FROM AP_PAYMENT_HISTORY_ALL WHERE check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id in (##$$ICVIEW$$##) ) ORDER BY payment_history_id asc',
      p_title                  => 'AP_PAYMENT_HISTORY_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_230_AP_PAYMENT_HISTORY_ALL_SUMMARY');



debug('begin add_signature: APLIST_240_AP_SELECTED_INVOICES_ALL_SUMMARY2');
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10580',
      p_sig_id                 => 'APLIST_240_AP_SELECTED_INVOICES_ALL_SUMMARY2',
      p_sig_sql                => 'SELECT checkrun_name, payment_num, payment_amount, ok_to_pay_flag, dont_pay_reason_code, substr(vendor_name,1,25) vendor_name, substr(vendor_site_code,1,25) vendor_site_code, pay_selected_check_id, print_selected_check_id, org_id FROM AP_SELECTED_INVOICES_ALL WHERE invoice_id in (##$$ICVIEW$$##)',
      p_title                  => 'AP_SELECTED_INVOICES_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_240_AP_SELECTED_INVOICES_ALL_SUMMARY2');



debug('begin add_signature: APLIST_250_AP_SELECTED_INVOICE_CHECKS_SUMMARY');
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10581',
      p_sig_id                 => 'APLIST_250_AP_SELECTED_INVOICE_CHECKS_SUMMARY',
      p_sig_sql                => 'SELECT asic.checkrun_name, asic.check_number, asic.check_amount, asic.ok_to_pay_flag, asic.dont_pay_reason_code, asic.status_lookup_code, substr(asic.vendor_name,1,25) vendor_name, substr(asic.vendor_site_code,1,25) vendor_site_code, asic.check_id, asic.selected_check_id, asic.org_id FROM AP_SELECTED_INVOICE_CHECKS_ALL asic, AP_SELECTED_INVOICES_ALL asi WHERE asi.invoice_id in (##$$ICVIEW$$##) AND ( asic.selected_check_id = asi.pay_selected_check_id OR asic.selected_check_id = asi.print_selected_check_id )',
      p_title                  => 'AP_SELECTED_INVOICE_CHECKS_ALL (Summary)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_250_AP_SELECTED_INVOICE_CHECKS_SUMMARY');



debug('begin add_signature: APLIST_370_AP_PAYMENT_SCHEDULES_ALL');
   l_info('##MASK##REMIT_TO_SUPPLIER_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10729',
      p_sig_id                 => 'APLIST_370_AP_PAYMENT_SCHEDULES_ALL',
      p_sig_sql                => 'SELECT * FROM AP_PAYMENT_SCHEDULES_ALL WHERE invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_PAYMENT_SCHEDULES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_370_AP_PAYMENT_SCHEDULES_ALL');



debug('begin add_signature: APLIST_380_AP_RECURRING_PAYMENTS_ALL');
   l_info('##MASK##REMIT_TO_SUPPLIER_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10732',
      p_sig_id                 => 'APLIST_380_AP_RECURRING_PAYMENTS_ALL',
      p_sig_sql                => 'select distinct arp.* from ap_recurring_payments_all arp, ap_invoices_all ai where ai.recurring_payment_id = arp.recurring_payment_id and ai.invoice_id IN (##$$ICVIEW$$##)
',
      p_title                  => 'AP_RECURRING_PAYMENTS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_380_AP_RECURRING_PAYMENTS_ALL');



debug('begin add_signature: APLIST_410_AP_TERMS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10859',
      p_sig_id                 => 'APLIST_410_AP_TERMS',
      p_sig_sql                => 'SELECT * FROM AP_TERMS WHERE term_id IN ( SELECT distinct terms_id FROM AP_INVOICES_ALL WHERE invoice_id IN (##$$ICVIEW$$##))',
      p_title                  => 'AP_TERMS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_410_AP_TERMS');



debug('begin add_signature: APLIST_420_AP_TERMS_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10860',
      p_sig_id                 => 'APLIST_420_AP_TERMS_LINES',
      p_sig_sql                => 'SELECT * FROM AP_TERMS_LINES WHERE term_id IN ( SELECT distinct terms_id FROM AP_INVOICES_ALL WHERE invoice_id IN (##$$ICVIEW$$##))',
      p_title                  => 'AP_TERMS_LINES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_420_AP_TERMS_LINES');



debug('begin add_signature: APLIST_460_AP_ALLOCATION_RULES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10864',
      p_sig_id                 => 'APLIST_460_AP_ALLOCATION_RULES',
      p_sig_sql                => 'SELECT * FROM AP_ALLOCATION_RULES WHERE invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_ALLOCATION_RULES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_460_AP_ALLOCATION_RULES');



debug('begin add_signature: APLIST_470_AP_ALLOCATION_RULE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10865',
      p_sig_id                 => 'APLIST_470_AP_ALLOCATION_RULE_LINES',
      p_sig_sql                => 'SELECT * FROM AP_ALLOCATION_RULE_LINES WHERE invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_ALLOCATION_RULE_LINES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_470_AP_ALLOCATION_RULE_LINES');



debug('begin add_signature: APLIST_480_AP_SELF_ASSESSED_TAX_DIST_ALL');
   l_info('##MASK##MERCHANT_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##MERCHANT_TAXPAYER_ID'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MERCHANT_TAX_REG_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10866',
      p_sig_id                 => 'APLIST_480_AP_SELF_ASSESSED_TAX_DIST_ALL',
      p_sig_sql                => 'SELECT * FROM AP_SELF_ASSESSED_TAX_DIST_ALL WHERE invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_SELF_ASSESSED_TAX_DIST_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_480_AP_SELF_ASSESSED_TAX_DIST_ALL');



debug('begin add_signature: APLIST_490_AP_INVOICE_RELATIONSHIPS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10867',
      p_sig_id                 => 'APLIST_490_AP_INVOICE_RELATIONSHIPS',
      p_sig_sql                => 'SELECT * FROM AP_INVOICE_RELATIONSHIPS WHERE original_invoice_id IN (##$$ICVIEW$$##) OR related_invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_INVOICE_RELATIONSHIPS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_490_AP_INVOICE_RELATIONSHIPS');



debug('begin add_signature: APLIST_500_AP_DOCUMENTS_PAYABLE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10874',
      p_sig_id                 => 'APLIST_500_AP_DOCUMENTS_PAYABLE',
      p_sig_sql                => 'SELECT * FROM AP_DOCUMENTS_PAYABLE WHERE calling_app_id = 200 AND calling_app_doc_unique_ref2 IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_DOCUMENTS_PAYABLE',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_500_AP_DOCUMENTS_PAYABLE');



debug('begin add_signature: APLIST_510_AP_INVOICE_PAYMENTS_ALL');
   l_info('##MASK##ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##IBAN_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##REMIT_TO_SUPPLIER_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10875',
      p_sig_id                 => 'APLIST_510_AP_INVOICE_PAYMENTS_ALL',
      p_sig_sql                => 'SELECT distinct aip.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'',  CHART_OF_ACCOUNTS_ID , aip.accts_pay_code_combination_id) "Accts Pay Account" FROM AP_INVOICE_PAYMENTS_ALL aip, AP_INVOICE_PAYMENTS_ALL aip2, AP_SYSTEM_PARAMETERS_ALL ASP,
GL_LEDGERS GL WHERE aip2.check_id = aip.check_id AND aip2.invoice_id IN (##$$ICVIEW$$##) 
AND AIP.ORG_ID = ASP.ORG_ID
AND ASP.SET_OF_BOOKS_ID = GL.LEDGER_ID 
ORDER BY aip.check_id asc, aip.invoice_payment_id asc',
      p_title                  => 'AP_INVOICE_PAYMENTS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_510_AP_INVOICE_PAYMENTS_ALL');



debug('begin add_signature: APLIST_530_AP_CHECKS_ALL');
   l_info('##MASK##ADDRESS_LINE%'):= 'REMOVE_COLUMN';
   l_info('##MASK##ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##IBAN_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##REMIT_TO_SUPPLIER_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10876',
      p_sig_id                 => 'APLIST_530_AP_CHECKS_ALL',
      p_sig_sql                => 'SELECT * FROM AP_CHECKS_ALL WHERE check_id IN ( SELECT check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) )',
      p_title                  => 'AP_CHECKS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_530_AP_CHECKS_ALL');



debug('begin add_signature: APLIST_540_AP_PAYMENT_DISTRIBUTIONS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10877',
      p_sig_id                 => 'APLIST_540_AP_PAYMENT_DISTRIBUTIONS_ALL',
      p_sig_sql                => 'SELECT tab.* FROM AP_INVOICE_PAYMENTS_ALL aip, AP_PAYMENT_DISTRIBUTIONS_ALL tab WHERE aip.invoice_payment_id = tab.invoice_payment_id AND aip.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_PAYMENT_DISTRIBUTIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_540_AP_PAYMENT_DISTRIBUTIONS_ALL');



debug('begin add_signature: APLIST_550_AP_PAYMENT_HISTORY_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10878',
      p_sig_id                 => 'APLIST_550_AP_PAYMENT_HISTORY_ALL',
      p_sig_sql                => 'SELECT * FROM AP_PAYMENT_HISTORY_ALL WHERE check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ORDER BY accounting_event_id asc',
      p_title                  => 'AP_PAYMENT_HISTORY_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_550_AP_PAYMENT_HISTORY_ALL');



debug('begin add_signature: APLIST_560_AP_PAYMENT_HIST_DISTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10879',
      p_sig_id                 => 'APLIST_560_AP_PAYMENT_HIST_DISTS',
      p_sig_sql                => 'SELECT distinct aphd.* FROM ap_payment_hist_dists aphd, AP_PAYMENT_HISTORY_ALL aph WHERE aph.payment_history_id = aphd.payment_history_id and aph.check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ORDER BY aphd.payment_history_id asc',
      p_title                  => 'AP_PAYMENT_HIST_DISTS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_560_AP_PAYMENT_HIST_DISTS');



debug('begin add_signature: APLIST_580_AP_INV_SELECTION_CRITERIA_ALL');
   l_info('##MASK##BANK_ACCOUNT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10880',
      p_sig_id                 => 'APLIST_580_AP_INV_SELECTION_CRITERIA_ALL',
      p_sig_sql                => 'SELECT * FROM AP_INV_SELECTION_CRITERIA_ALL WHERE checkrun_name IN (
SELECT c.checkrun_name FROM AP_CHECKS_ALL c WHERE c.check_id IN ( SELECT p.check_id FROM AP_INVOICE_PAYMENTS_ALL p WHERE p.invoice_id IN (##$$ICVIEW$$##) )
Union select k.checkrun_name from ap_selected_invoices_all k where k.invoice_id in (##$$ICVIEW$$##)
union SELECT v.checkrun_name from ap_inv_selection_criteria_all v where v.checkrun_id in (select w.CALLING_APP_DOC_UNIQUE_REF1 FROM IBY_DOCS_PAYABLE_ALL w WHERE w.calling_app_id = 200 AND calling_app_doc_unique_ref2 IN (##$$ICVIEW$$##)))',
      p_title                  => 'AP_INV_SELECTION_CRITERIA_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_580_AP_INV_SELECTION_CRITERIA_ALL');



debug('begin add_signature: APLIST_590_AP_SELECTED_INVOICES_ALL');
   l_info('##MASK##ADDRESS_LINE%'):= 'REMOVE_COLUMN';
   l_info('##MASK##ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##IBAN_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##REMIT_TO_SUPPLIER_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10881',
      p_sig_id                 => 'APLIST_590_AP_SELECTED_INVOICES_ALL',
      p_sig_sql                => 'SELECT * 
FROM AP_SELECTED_INVOICES_ALL 
WHERE invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_SELECTED_INVOICES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_590_AP_SELECTED_INVOICES_ALL');



debug('begin add_signature: APLIST_600_AP_SELECTED_INVOICE_CHECKS_ALL');
   l_info('##MASK##ADDRESS_LINE%'):= 'REMOVE_COLUMN';
   l_info('##MASK##ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##IBAN_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10882',
      p_sig_id                 => 'APLIST_600_AP_SELECTED_INVOICE_CHECKS_ALL',
      p_sig_sql                => 'SELECT asic.* FROM AP_SELECTED_INVOICE_CHECKS_ALL asic, AP_SELECTED_INVOICES_ALL asi WHERE asi.invoice_id IN (##$$ICVIEW$$##) AND ( asic.selected_check_id = asi.pay_selected_check_id OR asic.selected_check_id = print_selected_check_id )',
      p_title                  => 'AP_SELECTED_INVOICE_CHECKS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_600_AP_SELECTED_INVOICE_CHECKS_ALL');



debug('begin add_signature: APLIST_610_IBY_DOCS_PAYABLE_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10883',
      p_sig_id                 => 'APLIST_610_IBY_DOCS_PAYABLE_ALL',
      p_sig_sql                => 'SELECT * FROM IBY_DOCS_PAYABLE_ALL WHERE calling_app_id = 200 AND calling_app_doc_unique_ref2 IN (##$$ICVIEW$$##)',
      p_title                  => 'IBY_DOCS_PAYABLE_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_610_IBY_DOCS_PAYABLE_ALL');



debug('begin add_signature: APLIST_620_IBY_PAYMENTS_ALL');
   l_info('##MASK##ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BENEFICIARY_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##EXT_BANK_ACCOUNT_ALT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##EXT_BANK_ACCOUNT_IBAN_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##EXT_BANK_ACCOUNT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##EXT_BANK_ACCOUNT_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##EXT_BANK_ACCOUNT_NUM_ELEC'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##EXT_BANK_ACCT_OWNER_PARTY_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##EXT_BANK_ALT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##EXT_BANK_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##EXT_BANK_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##EXT_BNK_ACCT_OWNR_INV_PRTY_NME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##INT_BANK_ACCOUNT_ALT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##INT_BANK_ACCOUNT_IBAN'):= 'REMOVE_COLUMN';
   l_info('##MASK##INT_BANK_ACCOUNT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##INT_BANK_ACCOUNT_NUMBER'):= 'REMOVE_COLUMN';
   l_info('##MASK##INT_BANK_ACCOUNT_NUM_ELEC'):= 'REMOVE_COLUMN';
   l_info('##MASK##INT_BANK_ALT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##INT_BANK_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##INT_BANK_NUMBER'):= 'REMOVE_COLUMN';
   l_info('##MASK##INV_BENEFICIARY_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##INV_PAYEE_ADDRESS%'):= 'REMOVE_COLUMN';
   l_info('##MASK##INV_PAYEE_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##INV_PAYEE_PARTY_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##PAYEE_ADDRESS%'):= 'REMOVE_COLUMN';
   l_info('##MASK##PAYEE_ALTERNATE_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##PAYEE_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##PAYEE_PARTY_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##REMIT_ADVICE_EMAIL'):= 'REMOVE_COLUMN';
   l_info('##MASK##REMIT_ADVICE_FAX'):= 'REMOVE_COLUMN';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10884',
      p_sig_id                 => 'APLIST_620_IBY_PAYMENTS_ALL',
      p_sig_sql                => 'SELECT * FROM IBY_PAYMENTS_ALL WHERE payment_id IN ( SELECT payment_id FROM IBY_DOCS_PAYABLE_ALL WHERE calling_app_id = 200 AND calling_app_doc_unique_ref2 IN (##$$ICVIEW$$##) )',
      p_title                  => 'IBY_PAYMENTS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_620_IBY_PAYMENTS_ALL');



debug('begin add_signature: APLIST_630_IBY_PAY_INSTRUCTIONS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10885',
      p_sig_id                 => 'APLIST_630_IBY_PAY_INSTRUCTIONS_ALL',
      p_sig_sql                => 'SELECT * FROM IBY_PAY_INSTRUCTIONS_ALL WHERE payment_instruction_id IN ( SELECT payment_instruction_id FROM IBY_PAYMENTS_ALL WHERE payment_id IN ( SELECT payment_id FROM IBY_DOCS_PAYABLE_ALL WHERE calling_app_id = 200 AND calling_app_doc_unique_ref2 IN (##$$ICVIEW$$##) ) )',
      p_title                  => 'IBY_PAY_INSTRUCTIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_630_IBY_PAY_INSTRUCTIONS_ALL');



debug('begin add_signature: APLIST_640_AP_RECON_DISTRIBUTIONS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10886',
      p_sig_id                 => 'APLIST_640_AP_RECON_DISTRIBUTIONS_ALL',
      p_sig_sql                => 'SELECT * FROM AP_RECON_DISTRIBUTIONS_ALL WHERE check_id IN ( SELECT check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) )',
      p_title                  => 'AP_RECON_DISTRIBUTIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_640_AP_RECON_DISTRIBUTIONS_ALL');



debug('begin add_signature: APLIST_650_AP_AWT_TAX_RATES_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10887',
      p_sig_id                 => 'APLIST_650_AP_AWT_TAX_RATES_ALL',
      p_sig_sql                => 'select distinct awt.* from ap_tax_codes_all atc, ap_awt_tax_rates_all awt where awt.tax_name = atc.name and atc.tax_id in (select distinct aid.tax_code_id tax_code_id from ap_invoice_distributions_all aid, ap_tax_codes_all atc where aid.tax_code_id = atc.tax_id and aid.tax_code_id is not null and atc.tax_type = ''AWT'' and aid.invoice_id IN (##$$ICVIEW$$##)) UNION select distinct awt.* from ap_awt_tax_rates_all awt where awt.tax_rate_id in (select distinct aid.awt_tax_rate_id from ap_invoice_distributions_all aid where aid.awt_tax_rate_id is not null and aid.invoice_id IN (##$$ICVIEW$$##))',
      p_title                  => 'AP_AWT_TAX_RATES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_650_AP_AWT_TAX_RATES_ALL');



debug('begin add_signature: APLIST_660_AP_TAX_CODES_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10888',
      p_sig_id                 => 'APLIST_660_AP_TAX_CODES_ALL',
      p_sig_sql                => 'SELECT DISTINCT atc.* FROM ap_invoice_distributions_all aid, ap_tax_codes_all atc WHERE aid.tax_code_id = atc.tax_id AND aid.tax_code_id IS NOT NULL AND atc.tax_type = ''AWT'' AND aid.invoice_id IN (##$$ICVIEW$$##)
UNION
    SELECT DISTINCT atc.*
FROM ap_invoice_distributions_all aid,
     ap_tax_codes_all             atc,
     AP_AWT_GROUP_TAXES_ALL  aagta
WHERE aagta.GROUP_ID in (aid.PAY_AWT_GROUP_ID, aid.AWT_GROUP_ID)
      AND nvl(aid.PAY_AWT_GROUP_ID, aid.AWT_GROUP_ID) IS NOT NULL
      and aagta.TAX_NAME = atc.name
      and atc.tax_type = ''AWT''
      and aid.org_id = aagta.org_id
      and aagta.org_id = atc.org_id
      AND aid.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_TAX_CODES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_660_AP_TAX_CODES_ALL');



debug('begin add_signature: APLIST_670_AP_AWT_GROUPS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10889',
      p_sig_id                 => 'APLIST_670_AP_AWT_GROUPS',
      p_sig_sql                => 'select distinct awt.* from ap_awt_groups awt where awt.group_id in (select distinct aid.awt_group_id from ap_invoice_distributions_all aid where aid.awt_group_id is not null and aid.invoice_id  IN (##$$ICVIEW$$##) UNION select distinct aid.pay_awt_group_id from ap_invoice_distributions_all aid where aid.pay_awt_group_id is not null and aid.invoice_id  IN (##$$ICVIEW$$##) UNION select distinct ai.awt_group_id from ap_invoices_all ai where ai.awt_group_id is not null and ai.invoice_id  IN (##$$ICVIEW$$##) UNION select distinct ai.pay_awt_group_id from ap_invoices_all ai where ai.pay_awt_group_id is not null and ai.invoice_id  IN (##$$ICVIEW$$##))',
      p_title                  => 'AP_AWT_GROUPS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_670_AP_AWT_GROUPS');



debug('begin add_signature: APLIST_680_AP_AWT_GROUP_TAXES_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10890',
      p_sig_id                 => 'APLIST_680_AP_AWT_GROUP_TAXES_ALL',
      p_sig_sql                => 'select distinct awt.* from AP_AWT_GROUP_TAXES_ALL awt where awt.group_id in (select distinct aid.awt_group_id from ap_invoice_distributions_all aid where aid.awt_group_id is not null and aid.invoice_id IN (##$$ICVIEW$$##) UNION select distinct aid.pay_awt_group_id from ap_invoice_distributions_all aid where aid.pay_awt_group_id is not null and aid.invoice_id IN (##$$ICVIEW$$##) UNION select distinct ai.awt_group_id from ap_invoices_all ai where ai.awt_group_id is not null and ai.invoice_id IN (##$$ICVIEW$$##) UNION select distinct ai.pay_awt_group_id from ap_invoices_all ai where ai.pay_awt_group_id is not null and ai.invoice_id IN (##$$ICVIEW$$##) )',
      p_title                  => 'AP_AWT_GROUP_TAXES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_680_AP_AWT_GROUP_TAXES_ALL');



debug('begin add_signature: APLIST_690_AP_AWT_TEMP_DISTRIBUTIONS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10891',
      p_sig_id                 => 'APLIST_690_AP_AWT_TEMP_DISTRIBUTIONS_ALL',
      p_sig_sql                => 'select * FROM ap_awt_temp_distributions_all where invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_AWT_TEMP_DISTRIBUTIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_690_AP_AWT_TEMP_DISTRIBUTIONS_ALL');



debug('begin add_signature: APLIST_750_XLA_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10913',
      p_sig_id                 => 'APLIST_750_XLA_EVENTS',
      p_sig_sql                => 'select distinct xe.* from ap_invoices_all ai, xla_events xe, xla.xla_transaction_entities xte where xte.application_id = 200 and xe.application_id = 200 and ai.invoice_id IN (##$$ICVIEW$$##) and xte.entity_code = ''AP_INVOICES'' and nvl(xte.source_id_int_1, -99) = ai.invoice_id and xte.entity_id = xe.entity_id order by xe.entity_id, xe.event_number',
      p_title                  => 'XLA_EVENTS (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_750_XLA_EVENTS');



debug('begin add_signature: APLIST_760_XLA_AE_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10914',
      p_sig_id                 => 'APLIST_760_XLA_AE_HEADERS',
      p_sig_sql                => 'select distinct xeh.* from xla_ae_headers xeh, ap_invoices_all ai, xla.xla_transaction_entities xte where xte.application_id = 200 and xeh.application_id = 200 and ai.invoice_id IN (##$$ICVIEW$$##) and xte.entity_code = ''AP_INVOICES'' and nvl(xte.source_id_int_1, -99) = ai.invoice_id and xte.entity_id = xeh.entity_id ORDER BY xeh.event_id, xeh.ae_header_id asc',
      p_title                  => 'XLA_AE_HEADERS (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_760_XLA_AE_HEADERS');



debug('begin add_signature: APLIST_770_XLA_AE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10915',
      p_sig_id                 => 'APLIST_770_XLA_AE_LINES',
      p_sig_sql                => 'select distinct xel.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'', gl.chart_of_accounts_id , xel.code_combination_id) "Account" from xla_ae_lines xel, xla_ae_headers xeh, ap_invoices_all ai, 
gl_ledgers gl, xla.xla_transaction_entities xte where xte.application_id = 200 and xel.application_id = 200 and xeh.application_id = 200 and ai.invoice_id  IN (##$$ICVIEW$$##) and xel.ae_header_id = xeh.ae_header_id and xte.entity_code = ''AP_INVOICES'' and nvl(xte.source_id_int_1, -99) = ai.invoice_id and xte.entity_id = xeh.entity_id
and gl.ledger_id = xeh.ledger_id
 ORDER BY xel.ae_header_id, xel.ae_line_num asc',
      p_title                  => 'XLA_AE_LINES (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_770_XLA_AE_LINES');



debug('begin add_signature: APLIST_780_XLA_DISTRIBUTION_LINKS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10916',
      p_sig_id                 => 'APLIST_780_XLA_DISTRIBUTION_LINKS',
      p_sig_sql                => 'select distinct xdl.* from xla_distribution_links xdl, xla_ae_headers xeh, ap_invoices_all ai, xla.xla_transaction_entities xte where xte.application_id = 200 and xdl.application_id = 200 and xeh.application_id = 200 and ai.invoice_id IN (##$$ICVIEW$$##) and xdl.ae_header_id = xeh.ae_header_id and xte.entity_code = ''AP_INVOICES'' and nvl(xte.source_id_int_1, -99) = ai.invoice_id and xte.entity_id = xeh.entity_id ORDER BY xdl.event_id, xdl.ae_header_id, xdl.ae_line_num asc',
      p_title                  => 'XLA_DISTRIBUTION_LINKS (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_780_XLA_DISTRIBUTION_LINKS');



debug('begin add_signature: APLIST_790_XLA_TRANSACTION_ENTITIES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10924',
      p_sig_id                 => 'APLIST_790_XLA_TRANSACTION_ENTITIES',
      p_sig_sql                => 'select distinct xte.* from ap_invoices_all ai, xla.xla_transaction_entities xte where xte.application_id = 200 and ai.invoice_id IN (##$$ICVIEW$$##) and xte.entity_code = ''AP_INVOICES'' and nvl(xte.source_id_int_1, -99) = ai.invoice_id',
      p_title                  => 'XLA_TRANSACTION_ENTITIES (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_790_XLA_TRANSACTION_ENTITIES');



debug('begin add_signature: APLIST_800_XLA_ACCOUNTING_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10917',
      p_sig_id                 => 'APLIST_800_XLA_ACCOUNTING_ERRORS',
      p_sig_sql                => 'select distinct xae.* from ap_invoices_all ai, xla_events xe, xla.xla_transaction_entities xte, xla_accounting_errors xae where xte.application_id = 200 and xe.application_id = 200 and xae.application_id = 200 and ai.invoice_id IN (##$$ICVIEW$$##) and xe.event_id = xae.event_id and xte.entity_code = ''AP_INVOICES'' and nvl(xte.source_id_int_1, -99) = ai.invoice_id and xte.entity_id = xe.entity_id',
      p_title                  => 'XLA_ACCOUNTING_ERRORS (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: APLIST_800_XLA_ACCOUNTING_ERRORS');



debug('begin add_signature: APLIST_810_XLA_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10918',
      p_sig_id                 => 'APLIST_810_XLA_EVENTS',
      p_sig_sql                => 'select distinct xe.* from ap_invoice_payments_all aip, xla_events xe, xla.xla_transaction_entities xte where xte.application_id = 200 and xe.application_id = 200 and aip.invoice_id IN (##$$ICVIEW$$##) and xte.entity_code = ''AP_PAYMENTS'' and nvl(xte.source_id_int_1, -99) = aip.check_id and xte.entity_id = xe.entity_id order by xe.entity_id, xe.event_number',
      p_title                  => 'XLA_EVENTS (Payment)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_810_XLA_EVENTS');



debug('begin add_signature: APLIST_820_XLA_AE_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10921',
      p_sig_id                 => 'APLIST_820_XLA_AE_HEADERS',
      p_sig_sql                => 'select distinct xeh.* from xla_ae_headers xeh, ap_invoice_payments_all aip, xla.xla_transaction_entities xte where xte.application_id = 200 and xeh.application_id = 200 and aip.invoice_id IN (##$$ICVIEW$$##) and xte.entity_code = ''AP_PAYMENTS'' and nvl(xte.source_id_int_1, -99) = aip.check_id and xte.entity_id = xeh.entity_id ORDER BY xeh.event_id, xeh.ae_header_id asc',
      p_title                  => 'XLA_AE_HEADERS (Payment)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_820_XLA_AE_HEADERS');



debug('begin add_signature: APLIST_830_XLA_AE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10920',
      p_sig_id                 => 'APLIST_830_XLA_AE_LINES',
      p_sig_sql                => 'select distinct xel.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'', gl.chart_of_accounts_id , xel.code_combination_id) "Account" from xla_ae_lines xel, xla_ae_headers xeh, ap_invoice_payments_all aip, xla.xla_transaction_entities xte, gl_ledgers gl where xte.application_id = 200 and xel.application_id = 200 and xeh.application_id = 200 and aip.invoice_id IN (##$$ICVIEW$$##) and xel.ae_header_id = xeh.ae_header_id and xte.entity_code = ''AP_PAYMENTS'' and nvl(xte.source_id_int_1, -99) = aip.check_id and xte.entity_id = xeh.entity_id 
and gl.ledger_id = xeh.ledger_id
ORDER BY xel.ae_header_id, xel.ae_line_num asc',
      p_title                  => 'XLA_AE_LINES (Payment)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_830_XLA_AE_LINES');



debug('begin add_signature: APLIST_840_XLA_DISTRIBUTION_LINKS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10922',
      p_sig_id                 => 'APLIST_840_XLA_DISTRIBUTION_LINKS',
      p_sig_sql                => 'select distinct xdl.* from xla_distribution_links xdl, xla_ae_headers xeh, ap_invoice_payments_all aip, xla.xla_transaction_entities xte where xte.application_id = 200 and xeh.application_id = 200 and xdl.application_id = 200 and aip.invoice_id IN (##$$ICVIEW$$##) and xdl.ae_header_id = xeh.ae_header_id and xte.entity_code = ''AP_PAYMENTS'' and nvl(xte.source_id_int_1, -99) = aip.check_id and xte.entity_id = xeh.entity_id ORDER BY xdl.event_id, xdl.ae_header_id, xdl.ae_line_num asc',
      p_title                  => 'XLA_DISTRIBUTION_LINKS (Payment)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_840_XLA_DISTRIBUTION_LINKS');



debug('begin add_signature: APLIST_850_XLA_TRANSACTION_ENTITIES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10923',
      p_sig_id                 => 'APLIST_850_XLA_TRANSACTION_ENTITIES',
      p_sig_sql                => 'select distinct xte.* from ap_invoice_payments_all aip, xla.xla_transaction_entities xte where xte.application_id = 200 and aip.invoice_id IN (##$$ICVIEW$$##) and xte.entity_code = ''AP_PAYMENTS'' and nvl(xte.source_id_int_1, -99) = aip.check_id',
      p_title                  => 'XLA_TRANSACTION_ENTITIES (Payment)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_850_XLA_TRANSACTION_ENTITIES');



debug('begin add_signature: APLIST_860_XLA_ACCOUNTING_ERRORS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10925',
      p_sig_id                 => 'APLIST_860_XLA_ACCOUNTING_ERRORS',
      p_sig_sql                => 'select distinct xae.* 
from ap_invoice_payments_all aip, 
xla_events xe, 
xla.xla_transaction_entities xte, 
xla_accounting_errors xae 
where xte.application_id = 200 
and xe.application_id = 200 
and xae.application_id = 200 
and aip.invoice_id IN (##$$ICVIEW$$##) 
and xe.event_id = xae.event_id 
and xte.entity_code = ''AP_PAYMENTS'' 
and nvl(xte.source_id_int_1, -99) = aip.check_id 
and xte.entity_id = xe.entity_id
',
      p_title                  => 'XLA_ACCOUNTING_ERRORS (Payment)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: APLIST_860_XLA_ACCOUNTING_ERRORS');



debug('begin add_signature: APLIST_870_AP_LIABILITY_BALANCE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10926',
      p_sig_id                 => 'APLIST_870_AP_LIABILITY_BALANCE',
      p_sig_sql                => 'select * from ap_liability_balance where invoice_id IN (##$$ICVIEW$$##) order by ae_header_id',
      p_title                  => 'AP_LIABILITY_BALANCE',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_870_AP_LIABILITY_BALANCE');



debug('begin add_signature: APLIST_880_XLA_TRIAL_BALANCES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10927',
      p_sig_id                 => 'APLIST_880_XLA_TRIAL_BALANCES',
      p_sig_sql                => 'SELECT * FROM XLA_TRIAL_BALANCES XTB WHERE (SELECT XTE.ENTITY_ID FROM XLA.XLA_TRANSACTION_ENTITIES XTE WHERE XTE.APPLICATION_ID = 200 AND XTE.ENTITY_CODE = ''AP_INVOICES'' AND NVL(XTE.SOURCE_ID_INT_1,-99) IN (##$$INVID$$##)) IN (XTB.APPLIED_TO_ENTITY_ID, XTB.SOURCE_ENTITY_ID) ORDER BY DEFINITION_CODE, LEDGER_ID',
      p_title                  => 'XLA_TRIAL_BALANCES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_880_XLA_TRIAL_BALANCES');



debug('begin add_signature: APLIST_900_AX_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10942',
      p_sig_id                 => 'APLIST_900_AX_EVENTS',
      p_sig_sql                => 'SELECT e.* FROM AX.AX_EVENTS e WHERE e.application_id = 200 AND e.event_type like ''NON_CASH%'' AND e.event_field1 IN (##$$ICVIEW$$##)',
      p_title                  => 'AX_EVENTS (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_900_AX_EVENTS');



debug('begin add_signature: APLIST_910_AX_SLE_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10943',
      p_sig_id                 => 'APLIST_910_AX_SLE_HEADERS',
      p_sig_sql                => 'SELECT h.* FROM AX.AX_SLE_HEADERS h, AX.AX_EVENTS e WHERE h.event_id = e.event_id AND e.application_id = 200 AND e.event_type like ''NON_CASH%'' AND e.event_field1 IN (##$$ICVIEW$$##) ORDER BY h.set_of_books_id asc, h.event_id asc',
      p_title                  => 'AX_SLE_HEADERS (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_910_AX_SLE_HEADERS');



debug('begin add_signature: APLIST_920_AX_SLE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10944',
      p_sig_id                 => 'APLIST_920_AX_SLE_LINES',
      p_sig_sql                => 'SELECT l.* FROM AX.AX_EVENTS e, AX.AX_SLE_HEADERS h, AX.AX_SLE_LINES l WHERE l.set_of_books_id = h.set_of_books_id AND l.journal_sequence_id = h.journal_sequence_id AND l.sle_header_id = h.sle_header_id AND h.event_id = e.event_id AND e.application_id = 200 AND e.event_type like ''NON_CASH%'' AND e.event_field1 IN (##$$ICVIEW$$##) ORDER BY h.set_of_books_id, h.sle_header_id, l.sle_line_num',
      p_title                  => 'AX_SLE_LINES (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_920_AX_SLE_LINES');



debug('begin add_signature: APLIST_930_AX_DOCUMENT_STATUSES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10945',
      p_sig_id                 => 'APLIST_930_AX_DOCUMENT_STATUSES',
      p_sig_sql                => 'SELECT * FROM AX.AX_DOCUMENT_STATUSES WHERE document_id1 IN (##$$ICVIEW$$##) AND document_code = ''INVOICE''',
      p_title                  => 'AX_DOCUMENT_STATUSES (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_930_AX_DOCUMENT_STATUSES');



debug('begin add_signature: APLIST_940_AX_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10946',
      p_sig_id                 => 'APLIST_940_AX_EVENTS',
      p_sig_sql                => 'SELECT e.* FROM AX.AX_EVENTS e WHERE e.application_id = 200 AND ( e.event_type like ''CASH%'' OR e.event_type like ''FUTURE%'' ) AND e.event_field1 IN ( SELECT check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##))',
      p_title                  => 'AX_EVENTS (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_940_AX_EVENTS');



debug('begin add_signature: APLIST_950_AX_SLE_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10947',
      p_sig_id                 => 'APLIST_950_AX_SLE_HEADERS',
      p_sig_sql                => 'SELECT h.* FROM AX.AX_SLE_HEADERS h, AX.AX_EVENTS e WHERE h.event_id = e.event_id AND e.application_id = 200 AND ( e.event_type like ''CASH%'' OR e.event_type like ''FUTURE%'' ) AND e.event_field1 IN ( SELECT check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ORDER BY h.set_of_books_id asc, h.event_id asc',
      p_title                  => 'AX_SLE_HEADERS (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_950_AX_SLE_HEADERS');



debug('begin add_signature: APLIST_960_AX_SLE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10948',
      p_sig_id                 => 'APLIST_960_AX_SLE_LINES',
      p_sig_sql                => 'SELECT l.* FROM AX.AX_EVENTS e, AX.AX_SLE_HEADERS h, AX.AX_SLE_LINES l WHERE l.set_of_books_id = h.set_of_books_id AND l.journal_sequence_id = h.journal_sequence_id AND l.sle_header_id = h.sle_header_id AND h.event_id = e.event_id AND e.application_id = 200 AND ( e.event_type like ''CASH%'' OR e.event_type like ''FUTURE%'' ) AND e.event_field1 IN ( SELECT check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) )  ORDER BY h.set_of_books_id, h.sle_header_id, l.sle_line_num',
      p_title                  => 'AX_SLE_LINES (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_960_AX_SLE_LINES');



debug('begin add_signature: APLIST_970_AX_DOCUMENT_STATUSES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10949',
      p_sig_id                 => 'APLIST_970_AX_DOCUMENT_STATUSES',
      p_sig_sql                => 'SELECT * FROM AX.AX_DOCUMENT_STATUSES WHERE document_id1 IN ( SELECT check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) )  AND document_code = ''CHECK''',
      p_title                  => 'AX_DOCUMENT_STATUSES (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_970_AX_DOCUMENT_STATUSES');



debug('begin add_signature: APLIST_980_AP_ACCOUNTING_EVENTS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10950',
      p_sig_id                 => 'APLIST_980_AP_ACCOUNTING_EVENTS_ALL',
      p_sig_sql                => 'SELECT e.* FROM AP_ACCOUNTING_EVENTS_ALL e WHERE e.source_id IN (##$$ICVIEW$$##) AND e.source_table = ''AP_INVOICES'' ORDER BY e.accounting_event_id asc',
      p_title                  => 'AP_ACCOUNTING_EVENTS_ALL (Invoices)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_980_AP_ACCOUNTING_EVENTS_ALL');



debug('begin add_signature: APLIST_990_AP_AE_HEADERS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10951',
      p_sig_id                 => 'APLIST_990_AP_AE_HEADERS_ALL',
      p_sig_sql                => 'SELECT h.* FROM AP_AE_HEADERS_ALL h, AP_ACCOUNTING_EVENTS_ALL e WHERE h.accounting_event_id = e.accounting_event_id AND e.source_id IN (##$$ICVIEW$$##) AND e.source_table = ''AP_INVOICES'' ORDER BY h.ae_header_id asc',
      p_title                  => 'AP_AE_HEADERS_ALL (Invoices)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_990_AP_AE_HEADERS_ALL');



debug('begin add_signature: APLIST_1000_AP_AE_LINES_ALL');
   l_info('##MASK##REFERENCE1'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10952',
      p_sig_id                 => 'APLIST_1000_AP_AE_LINES_ALL',
      p_sig_sql                => 'SELECT l.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.chart_of_accounts_id , l.code_combination_id) Account FROM AP_AE_LINES_ALL l, AP_AE_HEADERS_ALL h, AP_ACCOUNTING_EVENTS_ALL e, gl_ledgers gl WHERE l.ae_header_id = h.ae_header_id AND h.accounting_event_id = e.accounting_event_id AND e.source_id IN (##$$ICVIEW$$##) AND e.source_table = ''AP_INVOICES'' 
and gl.ledger_id = h.set_of_books_id
ORDER BY l.ae_header_id asc, l.ae_line_number',
      p_title                  => 'AP_AE_LINES_ALL (Invoices)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: APLIST_1000_AP_AE_LINES_ALL');



debug('begin add_signature: APLIST_1010_AP_ENCUMBRANCE_LINES_ALL');
   l_info('##MASK##REFERENCE1'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10954',
      p_sig_id                 => 'APLIST_1010_AP_ENCUMBRANCE_LINES_ALL',
      p_sig_sql                => 'SELECT enc.* FROM AP_ENCUMBRANCE_LINES_ALL enc, AP_INVOICE_DISTRIBUTIONS_ALL aid WHERE aid.invoice_id IN (##$$ICVIEW$$##) AND aid.invoice_distribution_id = enc.invoice_distribution_id ORDER BY enc.invoice_distribution_id asc',
      p_title                  => 'AP_ENCUMBRANCE_LINES_ALL (Invoices)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1010_AP_ENCUMBRANCE_LINES_ALL');



debug('begin add_signature: APLIST_1020_AP_ACCOUNTING_EVENTS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10955',
      p_sig_id                 => 'APLIST_1020_AP_ACCOUNTING_EVENTS_ALL',
      p_sig_sql                => 'SELECT distinct e.* FROM AP_ACCOUNTING_EVENTS_ALL e, ( SELECT distinct aip.check_id, aph.payment_history_id FROM AP_INVOICE_PAYMENTS_ALL aip, AP_PAYMENT_HISTORY_ALL aph WHERE aip.invoice_id IN (##$$ICVIEW$$##) AND aph.check_id(+) = aip.check_id ) ct WHERE ( ( e.source_id = ct.check_id AND e.source_table = ''AP_CHECKS'' ) OR ( e.source_id = ct.payment_history_id AND e.source_table = ''AP_PAYMENT_HISTORY'' ) ) ORDER BY e.accounting_event_id asc',
      p_title                  => 'AP_ACCOUNTING_EVENTS_ALL (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1020_AP_ACCOUNTING_EVENTS_ALL');



debug('begin add_signature: APLIST_1030_AP_AE_HEADERS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10956',
      p_sig_id                 => 'APLIST_1030_AP_AE_HEADERS_ALL',
      p_sig_sql                => 'SELECT distinct h.* FROM AP_AE_HEADERS_ALL h, AP_ACCOUNTING_EVENTS_ALL e, ( SELECT distinct aip.check_id, aph.payment_history_id FROM AP_INVOICE_PAYMENTS_ALL aip, AP_PAYMENT_HISTORY_ALL aph WHERE aip.invoice_id IN (##$$ICVIEW$$##) AND aph.check_id(+) = aip.check_id ) ct WHERE h.accounting_event_id = e.accounting_event_id AND ( ( e.source_id = ct.check_id AND e.source_table = ''AP_CHECKS'' ) OR ( e.source_id = ct.payment_history_id AND e.source_table = ''AP_PAYMENT_HISTORY'' ) ) ORDER BY h.ae_header_id asc',
      p_title                  => 'AP_AE_HEADERS_ALL (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1030_AP_AE_HEADERS_ALL');



debug('begin add_signature: APLIST_1040_AP_AE_LINES_ALL');
   l_info('##MASK##REFERENCE1'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10957',
      p_sig_id                 => 'APLIST_1040_AP_AE_LINES_ALL',
      p_sig_sql                => 'SELECT distinct l.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , l.code_combination_id) Account FROM AP_AE_LINES_ALL l, AP_AE_HEADERS_ALL h, AP_ACCOUNTING_EVENTS_ALL e,   GL_LEDGERS GL,
 ( SELECT distinct aip.check_id, aph.payment_history_id FROM AP_INVOICE_PAYMENTS_ALL aip, AP_PAYMENT_HISTORY_ALL aph
 WHERE aip.invoice_id IN (##$$ICVIEW$$##) 
AND aph.check_id(+) = aip.check_id ) ct 
WHERE l.ae_header_id = h.ae_header_id 
AND GL.LEDGER_ID = H.SET_OF_BOOKS_ID
AND h.accounting_event_id = e.accounting_event_id AND ( ( e.source_id = ct.check_id AND e.source_table = ''AP_CHECKS'' ) OR ( e.source_id = ct.payment_history_id AND e.source_table = ''AP_PAYMENT_HISTORY'' ) ) ORDER BY l.ae_header_id asc, l.ae_line_number',
      p_title                  => 'AP_AE_LINES_ALL (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1040_AP_AE_LINES_ALL');



debug('begin add_signature: APLIST_1050_AP_UNDO_EVENT_LOG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10897',
      p_sig_id                 => 'APLIST_1050_AP_UNDO_EVENT_LOG',
      p_sig_sql                => 'select * from AP_undo_event_log where invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##))',
      p_title                  => 'AP_UNDO_EVENT_LOG',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'AP_UNDO_EVENT_LOG',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '11'
      );
   l_info.delete;
debug('end add_signature: APLIST_1050_AP_UNDO_EVENT_LOG');



debug('begin add_signature: APLIST_1060_UNDO_ORIG_XLA_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10958',
      p_sig_id                 => 'APLIST_1060_UNDO_ORIG_XLA_EVENTS',
      p_sig_sql                => 'select distinct xe.* from xla_distribution_links xdl, xla_ae_lines xel, xla_ae_headers xeh, xla_events xe, ap_undo_event_log undo where xe.application_id = 200 and xeh.application_id = 200 and xel.application_id = 200 and xdl.application_id = 200 and xe.event_id = undo.e3 and xel.ae_header_id = xeh.ae_header_id and xe.event_id = xeh.event_id and xdl.ae_header_id = xeh.ae_header_id and xdl.event_id = xe.event_id and (invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##)) ) order by xe.event_id',
      p_title                  => 'Original/incorrect Accounting XLA_EVENTS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Original/Incorrect Accounting XLA_DISTRIBUTION_LINKS',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1060_UNDO_ORIG_XLA_EVENTS');



debug('begin add_signature: APLIST_1070_UNDO_ORIG_XLA_AE_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10960',
      p_sig_id                 => 'APLIST_1070_UNDO_ORIG_XLA_AE_HEADERS',
      p_sig_sql                => 'select distinct xeh.* from xla_distribution_links xdl, xla_ae_lines xel, xla_ae_headers xeh, xla_events xe, ap_undo_event_log undo where xe.application_id = 200 and xeh.application_id = 200 and xel.application_id = 200 and xdl.application_id = 200 and xe.event_id = undo.e3 and xel.ae_header_id = xeh.ae_header_id and xe.event_id = xeh.event_id and xdl.ae_header_id = xeh.ae_header_id and xdl.event_id = xe.event_id and (invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##)) ) order by xeh.ae_header_id',
      p_title                  => 'Original/Incorrect Accounting XLA_AE_HEADERS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Original/Incorrect Accounting XLA_AE_HEADERS',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1070_UNDO_ORIG_XLA_AE_HEADERS');



debug('begin add_signature: APLIST_1080_UNDO_ORIG_XLA_AE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10961',
      p_sig_id                 => 'APLIST_1080_UNDO_ORIG_XLA_AE_LINES',
      p_sig_sql                => 'select distinct xel.* from xla_distribution_links xdl, xla_ae_lines xel, xla_ae_headers xeh, xla_events xe, ap_undo_event_log undo where xe.application_id = 200 and xeh.application_id = 200 and xel.application_id = 200 and xdl.application_id = 200 and xe.event_id = undo.e3 and xel.ae_header_id = xeh.ae_header_id and xe.event_id = xeh.event_id and xdl.ae_header_id = xeh.ae_header_id and xdl.event_id = xe.event_id and (invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##)) ) order by xel.ae_header_id',
      p_title                  => 'Original/Incorrect Accounting XLA_AE_LINES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Original/Incorrect Accounting XLA_AE_LINES',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1080_UNDO_ORIG_XLA_AE_LINES');



debug('begin add_signature: APLIST_1090_UDO_ORIG_XDL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10962',
      p_sig_id                 => 'APLIST_1090_UDO_ORIG_XDL',
      p_sig_sql                => 'select distinct xdl.* from xla_distribution_links xdl, xla_ae_lines xel, xla_ae_headers xeh, xla_events xe, ap_undo_event_log undo where xe.application_id = 200 and xeh.application_id = 200 and xel.application_id = 200 and xdl.application_id = 200 and xe.event_id = undo.e3 and xel.ae_header_id = xeh.ae_header_id and xe.event_id = xeh.event_id and xdl.ae_header_id = xeh.ae_header_id and xdl.event_id = xe.event_id and (invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##)) ) order by xdl.ae_header_id',
      p_title                  => 'Original/Incorrect Accounting XLA_DISTRIBUTION_LINKS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Original/Incorrect Accounting XLA_DISTRIBUTION_LINKS',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1090_UDO_ORIG_XDL');



debug('begin add_signature: APLIST_1100_UNDO_REV_XLA_EVENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10963',
      p_sig_id                 => 'APLIST_1100_UNDO_REV_XLA_EVENTS',
      p_sig_sql                => 'select distinct xe.* from xla_distribution_links xdl, xla_ae_lines xel, xla_ae_headers xeh, xla_events xe, ap_undo_event_log undo where xe.application_id = 200 and xeh.application_id = 200 and xel.application_id = 200 and xdl.application_id = 200 and xe.event_id = undo.e2 and xel.ae_header_id = xeh.ae_header_id and xe.event_id = xeh.event_id and xdl.ae_header_id = xeh.ae_header_id and xdl.event_id = xe.event_id and (invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##)) ) order by xe.event_id',
      p_title                  => 'Reversal Accounting XLA_EVENTS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'XLA Events Undo Info',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1100_UNDO_REV_XLA_EVENTS');



debug('begin add_signature: APLIST_1110_UNDO_REV_XLA_AE_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10964',
      p_sig_id                 => 'APLIST_1110_UNDO_REV_XLA_AE_HEADERS',
      p_sig_sql                => 'select distinct xeh.* from xla_distribution_links xdl, xla_ae_lines xel, xla_ae_headers xeh, xla_events xe, ap_undo_event_log undo where xe.application_id = 200 and xeh.application_id = 200 and xel.application_id = 200 and xdl.application_id = 200 and xe.event_id = undo.e2 and xel.ae_header_id = xeh.ae_header_id and xe.event_id = xeh.event_id and xdl.ae_header_id = xeh.ae_header_id and xdl.event_id = xe.event_id and (invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##)) ) order by xeh.event_id',
      p_title                  => 'Reversal Accounting XLA_AE_HEADERS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Reversal Accounting XLA_AE_HEADERS',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: APLIST_1110_UNDO_REV_XLA_AE_HEADERS');



debug('begin add_signature: APLIST_1120_UNDO_REV_XLA_AE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10965',
      p_sig_id                 => 'APLIST_1120_UNDO_REV_XLA_AE_LINES',
      p_sig_sql                => 'select distinct xel.* from xla_distribution_links xdl, xla_ae_lines xel, xla_ae_headers xeh, xla_events xe, ap_undo_event_log undo where xe.application_id = 200 and xeh.application_id = 200 and xel.application_id = 200 and xdl.application_id = 200 and xe.event_id = undo.e2 and xel.ae_header_id = xeh.ae_header_id and xe.event_id = xeh.event_id and xdl.ae_header_id = xeh.ae_header_id and xdl.event_id = xe.event_id and (invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##)) ) order by xel.ae_header_id',
      p_title                  => 'Reversal Accounting XLA_AE_LINES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Reversal Accounting XLA_AE_LINES',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: APLIST_1120_UNDO_REV_XLA_AE_LINES');



debug('begin add_signature: APLIST_1130_UNDO_REV_XDL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10966',
      p_sig_id                 => 'APLIST_1130_UNDO_REV_XDL',
      p_sig_sql                => 'select distinct xdl.* from xla_distribution_links xdl, xla_ae_lines xel, xla_ae_headers xeh, xla_events xe, ap_undo_event_log undo where xe.application_id = 200 and xeh.application_id = 200 and xel.application_id = 200 and xdl.application_id = 200 and xe.event_id = undo.e2 and xel.ae_header_id = xeh.ae_header_id and xe.event_id = xeh.event_id and xdl.ae_header_id = xeh.ae_header_id and xdl.event_id = xe.event_id and (invoice_id IN (##$$ICVIEW$$##) OR check_id in (select x.check_id from ap_invoice_payments_all x where x.invoice_id IN (##$$ICVIEW$$##)) ) order by xdl.event_id',
      p_title                  => 'Reversal Accounting XLA_DISTRIBUTION_LINKS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Reversal Accounting XLA_DISTRIBUTION_LINKS',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '10'
      );
   l_info.delete;
debug('end add_signature: APLIST_1130_UNDO_REV_XDL');



debug('begin add_signature: APLIST_1140_GL_JE_BATCHES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10968',
      p_sig_id                 => 'APLIST_1140_GL_JE_BATCHES',
      p_sig_sql                => 'SELECT distinct gjb.* FROM GL_IMPORT_REFERENCES gir, GL_JE_BATCHES gjb, XLA_AE_LINES ael, XLA_AE_HEADERS aeh, XLA_EVENTS aea 
WHERE aea.event_id IN 
 (SELECT aid.accounting_event_id FROM AP_INVOICE_DISTRIBUTIONS_ALL aid 
  WHERE aid.invoice_id IN (##$$ICVIEW$$##) ) 
 AND ael.gl_sl_link_id = gir.gl_sl_link_id 
 AND gir.gl_sl_link_table in (''APECL'', ''XLAJEL'',''AX_SLE_LINES'') 
 AND aea.application_id = 200 and aeh.application_id = 200
 AND aea.event_id = aeh.event_id AND aeh.ae_header_id = ael.ae_header_id
 AND gjb.je_batch_id = gir.je_batch_id',
      p_title                  => 'GL_JE_BATCHES (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1140_GL_JE_BATCHES');



debug('begin add_signature: APLIST_1150_GL_JE_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10969',
      p_sig_id                 => 'APLIST_1150_GL_JE_HEADERS',
      p_sig_sql                => 'SELECT distinct gjh.* FROM GL_IMPORT_REFERENCES gir, GL_JE_HEADERS gjh, XLA_AE_LINES ael, XLA_AE_HEADERS aeh, XLA_EVENTS aea
 WHERE aea.event_id IN
  (SELECT aid.accounting_event_id FROM AP_INVOICE_DISTRIBUTIONS_ALL aid WHERE aid.invoice_id IN (##$$ICVIEW$$##) )
 AND ael.gl_sl_link_id = gir.gl_sl_link_id
 AND gir.gl_sl_link_table in (''APECL'', ''XLAJEL'',''AX_SLE_LINES'')
 AND aea.application_id = 200 and aeh.application_id = 200
 AND aea.event_id = aeh.event_id AND aeh.ae_header_id = ael.ae_header_id
 AND gjh.je_header_id = gir.je_header_id',
      p_title                  => 'GL_JE_HEADERS (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1150_GL_JE_HEADERS');



debug('begin add_signature: APLIST_1160_GL_JE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10970',
      p_sig_id                 => 'APLIST_1160_GL_JE_LINES',
      p_sig_sql                => 'SELECT distinct gll.* FROM GL_IMPORT_REFERENCES gir, GL_JE_LINES gll, XLA_AE_LINES ael, XLA_AE_HEADERS aeh, XLA_EVENTS aea 
WHERE aea.event_id IN
 (SELECT aid.accounting_event_id FROM AP_INVOICE_DISTRIBUTIONS_ALL aid WHERE aid.invoice_id IN (##$$ICVIEW$$##) ) 
 AND ael.gl_sl_link_id = gir.gl_sl_link_id 
 AND gir.gl_sl_link_table in (''APECL'', ''XLAJEL'',''AX_SLE_LINES'')
 AND aea.application_id = 200 and aeh.application_id = 200
 AND aea.event_id = aeh.event_id AND aeh.ae_header_id = ael.ae_header_id
 AND gll.je_header_id = gir.je_header_id AND gll.je_line_num = gir.je_line_num
 order by gll.je_header_id ,gll.je_line_num',
      p_title                  => 'GL_JE_LINES (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: APLIST_1160_GL_JE_LINES');



debug('begin add_signature: APLIST_1170_GL_IMPORT_REFERENCES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10971',
      p_sig_id                 => 'APLIST_1170_GL_IMPORT_REFERENCES',
      p_sig_sql                => 'SELECT distinct gir.* FROM GL_IMPORT_REFERENCES gir, GL_JE_LINES gll, XLA_AE_LINES ael, XLA_AE_HEADERS aeh, XLA_EVENTS aea
 WHERE aea.event_id IN
  (SELECT aid.accounting_event_id FROM AP_INVOICE_DISTRIBUTIONS_ALL aid WHERE aid.invoice_id IN (##$$ICVIEW$$##) )
 AND ael.gl_sl_link_id = gir.gl_sl_link_id
 AND gir.gl_sl_link_table in (''APECL'', ''XLAJEL'',''AX_SLE_LINES'')
 AND aea.application_id = 200 and aeh.application_id = 200
 AND aea.event_id = aeh.event_id AND aeh.ae_header_id = ael.ae_header_id
 AND gll.je_header_id = gir.je_header_id AND gll.je_line_num = gir.je_line_num',
      p_title                  => 'GL_IMPORT_REFERENCES (Invoice)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1170_GL_IMPORT_REFERENCES');



debug('begin add_signature: APLIST_1180_GL_JE_BATCHES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10972',
      p_sig_id                 => 'APLIST_1180_GL_JE_BATCHES',
      p_sig_sql                => 'SELECT distinct gjb.* 
FROM GL_IMPORT_REFERENCES gir, GL_JE_BATCHES gjb, XLA_AE_LINES ael, XLA_AE_HEADERS aeh, XLA_EVENTS aea 
WHERE aea.event_id IN 
  (SELECT aip.accounting_event_id FROM AP_INVOICE_PAYMENTS_ALL aip 
   WHERE aip.invoice_id IN (##$$ICVIEW$$##) 
   UNION SELECT distinct aph.accounting_event_id FROM AP_INVOICE_PAYMENTS_ALL aip, AP_PAYMENT_HISTORY_ALL aph 
     WHERE aph.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) ) 
 AND ael.gl_sl_link_id = gir.gl_sl_link_id 
 AND gir.gl_sl_link_table in (''APECL'', ''XLAJEL'',''AX_SLE_LINES'') 
 AND aea.application_id = 200 and aeh.application_id = 200 
 AND aea.event_id = aeh.event_id AND aeh.ae_header_id = ael.ae_header_id 
 AND gjb.je_batch_id = gir.je_batch_id',
      p_title                  => 'GL_JE_BATCHES (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1180_GL_JE_BATCHES');



debug('begin add_signature: APLIST_1190_GL_JE_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10973',
      p_sig_id                 => 'APLIST_1190_GL_JE_HEADERS',
      p_sig_sql                => 'SELECT distinct gjh.* FROM GL_IMPORT_REFERENCES gir, GL_JE_HEADERS gjh, XLA_AE_LINES ael, XLA_AE_HEADERS aeh, XLA_EVENTS aea
 WHERE aea.event_id IN
  (SELECT aip.accounting_event_id FROM AP_INVOICE_PAYMENTS_ALL aip WHERE aip.invoice_id IN (##$$ICVIEW$$##)
   UNION SELECT distinct aph.accounting_event_id FROM AP_INVOICE_PAYMENTS_ALL aip, AP_PAYMENT_HISTORY_ALL aph
    WHERE aph.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) )
 AND ael.gl_sl_link_id = gir.gl_sl_link_id
 AND gir.gl_sl_link_table in (''APECL'', ''XLAJEL'',''AX_SLE_LINES'')
 AND aea.application_id = 200 and aeh.application_id = 200
 AND aea.event_id = aeh.event_id AND aeh.ae_header_id = ael.ae_header_id AND gjh.je_header_id = gir.je_header_id',
      p_title                  => 'GL_JE_HEADERS (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1190_GL_JE_HEADERS');



debug('begin add_signature: APLIST_1200_GL_JE_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10974',
      p_sig_id                 => 'APLIST_1200_GL_JE_LINES',
      p_sig_sql                => 'SELECT distinct gll.* FROM GL_IMPORT_REFERENCES gir, GL_JE_LINES gll, XLA_AE_LINES ael, XLA_AE_HEADERS aeh, XLA_EVENTS aea
 WHERE aea.event_id IN
 ( SELECT aip.accounting_event_id FROM AP_INVOICE_PAYMENTS_ALL aip WHERE aip.invoice_id IN (##$$ICVIEW$$##)
 UNION SELECT distinct aph.accounting_event_id FROM AP_INVOICE_PAYMENTS_ALL aip, AP_PAYMENT_HISTORY_ALL aph
  WHERE aph.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) )
 AND ael.gl_sl_link_id = gir.gl_sl_link_id AND gir.gl_sl_link_table in (''APECL'', ''XLAJEL'',''AX_SLE_LINES'')
 AND aea.application_id = 200 and ael.application_id = 200 and aeh.application_id = 200
 AND aea.event_id = aeh.event_id AND aeh.ae_header_id = ael.ae_header_id
 AND gll.je_header_id = gir.je_header_id AND gll.je_line_num = gir.je_line_num',
      p_title                  => 'GL_JE_LINES (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1200_GL_JE_LINES');



debug('begin add_signature: APLIST_1210_GL_IMPORT_REFERENCES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10975',
      p_sig_id                 => 'APLIST_1210_GL_IMPORT_REFERENCES',
      p_sig_sql                => 'SELECT distinct gir.* 
FROM GL_IMPORT_REFERENCES gir, GL_JE_LINES gll, XLA_AE_LINES ael, XLA_AE_HEADERS aeh, XLA_EVENTS aea 
WHERE aea.event_id IN 
 (SELECT aip.accounting_event_id FROM ap_invoice_payments_all aip 
  WHERE aip.invoice_id IN (##$$ICVIEW$$##) 
   UNION SELECT aph.accounting_event_id FROM ap_invoice_payments_all aip, ap_payment_history_all aph 
    WHERE aph.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) ) 
  AND ael.gl_sl_link_id = gir.gl_sl_link_id 
  AND gir.gl_sl_link_table in (''APECL'', ''XLAJEL'',''AX_SLE_LINES'') 
  AND aea.application_id = 200 and aeh.application_id = 200 
  AND aea.event_id = aeh.event_id AND aeh.ae_header_id = ael.ae_header_id 
  AND gll.je_header_id = gir.je_header_id AND gll.je_line_num = gir.je_line_num',
      p_title                  => 'GL_IMPORT_REFERENCES (Payments)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: APLIST_1210_GL_IMPORT_REFERENCES');



debug('begin add_signature: APLIST_1220_GL_PERIOD_STATUSES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10976',
      p_sig_id                 => 'APLIST_1220_GL_PERIOD_STATUSES',
      p_sig_sql                => 'SELECT distinct gps.* FROM GL_PERIOD_STATUSES gps, ( SELECT distinct accounting_date, set_of_books_id FROM AP_INVOICE_DISTRIBUTIONS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) UNION SELECT distinct accounting_date, set_of_books_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) UNION SELECT distinct accounting_date, -1 FROM AP_PAYMENT_HISTORY_ALL WHERE check_id IN ( SELECT check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ) atg_date WHERE atg_date.accounting_date between gps.start_date and gps.end_date AND gps.application_id in (101,200) AND gps.set_of_books_id = atg_date.set_of_books_id',
      p_title                  => 'GL_PERIOD_STATUSES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1220_GL_PERIOD_STATUSES');



debug('begin add_signature: APLIST_1230_GL_CODE_COMBINATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10977',
      p_sig_id                 => 'APLIST_1230_GL_CODE_COMBINATIONS',
      p_sig_sql                => 'select distinct gcc.* 
from gl_code_combinations gcc 
where gcc.code_combination_id in ( 
select distinct xel.code_combination_id 
from xla_ae_lines xel, xla_ae_headers xeh, ap_invoices_all ai, xla.xla_transaction_entities xte 
where xte.application_id = 200 
and xeh.application_id = 200 
and xel.application_id = 200 
and ai.invoice_id IN (##$$ICVIEW$$##) 
and xel.ae_header_id = xeh.ae_header_id 
and xte.entity_code = ''AP_INVOICES'' 
and nvl(xte.source_id_int_1, -99) = ai.invoice_id 
and xte.entity_id = xeh.entity_id 
UNION 
select distinct xel.code_combination_id 
from xla_ae_lines xel, xla_ae_headers xeh, ap_invoice_payments_all aip, xla.xla_transaction_entities xte 
where xte.application_id = 200 
and xel.application_id = 200 
and xeh.application_id = 200 
and aip.invoice_id IN (##$$ICVIEW$$##) 
and xel.ae_header_id = xeh.ae_header_id 
and xte.entity_code = ''AP_PAYMENTS'' 
and nvl(xte.source_id_int_1, -99) = aip.check_id 
and xte.entity_id = xeh.entity_id 
UNION 
SELECT distinct po.code_combination_id 
FROM AP_INVOICE_DISTRIBUTIONS_ALL aid, PO_DISTRIBUTIONS_ALL po 
WHERE aid.invoice_id IN (##$$ICVIEW$$##) 
AND aid.po_distribution_id is not null 
AND po.po_distribution_id = aid.po_distribution_id
    UNION
    SELECT DISTINCT aid.dist_code_combination_id
    FROM ap_invoice_distributions_all aid
    WHERE aid.invoice_id IN (##$$ICVIEW$$##))',
      p_title                  => 'GL_CODE_COMBINATIONS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1230_GL_CODE_COMBINATIONS');



debug('begin add_signature: APLIST_1240_AP_MC_INVOICES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10978',
      p_sig_id                 => 'APLIST_1240_AP_MC_INVOICES',
      p_sig_sql                => 'SELECT 1 FROM AP_MC_INVOICES WHERE invoice_id IN (##$$ICVIEW$$##) UNION SELECT 1 FROM AP_MC_CHECKS mc, AP_CHECKS_ALL aca WHERE aca.check_id IN ( SELECT distinct aa.check_id FROM AP_INVOICE_PAYMENTS_ALL aa WHERE aa.invoice_id IN (##$$ICVIEW$$##) ) AND mc.check_id = aca.check_id',
      p_title                  => 'AP_MC_INVOICES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1240_AP_MC_INVOICES');



debug('begin add_signature: APLIST_1250_AP_MC_INVOICES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10980',
      p_sig_id                 => 'APLIST_1250_AP_MC_INVOICES',
      p_sig_sql                => 'SELECT * FROM AP_MC_INVOICES WHERE invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_MC_INVOICES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1250_AP_MC_INVOICES');



debug('begin add_signature: APLIST_1260_AP_MC_CHECKS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10981',
      p_sig_id                 => 'APLIST_1260_AP_MC_CHECKS',
      p_sig_sql                => 'SELECT mc.* FROM AP_MC_CHECKS mc, AP_CHECKS_ALL aca WHERE aca.check_id IN ( SELECT distinct aa.check_id FROM AP_INVOICE_PAYMENTS_ALL aa WHERE aa.invoice_id IN (##$$ICVIEW$$##) ) AND mc.check_id = aca.check_id',
      p_title                  => 'AP_MC_CHECKS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1260_AP_MC_CHECKS');



debug('begin add_signature: APLIST_1270_AP_MC_INVOICE_DISTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10982',
      p_sig_id                 => 'APLIST_1270_AP_MC_INVOICE_DISTS',
      p_sig_sql                => 'SELECT mc.* FROM AP_MC_INVOICE_DISTS mc, AP_INVOICE_DISTRIBUTIONS_ALL a WHERE a.invoice_id IN (##$$ICVIEW$$##) AND a.invoice_distribution_id = mc.invoice_distribution_id AND a.invoice_id = mc.invoice_id',
      p_title                  => 'AP_MC_INVOICE_DISTS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1270_AP_MC_INVOICE_DISTS');



debug('begin add_signature: APLIST_1280_AP_MC_INVOICE_PAYMENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10983',
      p_sig_id                 => 'APLIST_1280_AP_MC_INVOICE_PAYMENTS',
      p_sig_sql                => 'SELECT mc.* FROM AP_MC_INVOICE_PAYMENTS mc, AP_INVOICE_PAYMENTS_ALL a WHERE a.invoice_id IN (##$$ICVIEW$$##) AND mc.invoice_payment_id = a.invoice_payment_id',
      p_title                  => 'AP_MC_INVOICE_PAYMENTS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1280_AP_MC_INVOICE_PAYMENTS');



debug('begin add_signature: APLIST_1300_AP_MC_PAYMENT_HISTORY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10985',
      p_sig_id                 => 'APLIST_1300_AP_MC_PAYMENT_HISTORY',
      p_sig_sql                => 'SELECT mc.* FROM AP_MC_PAYMENT_HISTORY mc, AP_PAYMENT_HISTORY_ALL aph WHERE aph.check_id IN ( SELECT distinct aa.check_id FROM AP_INVOICE_PAYMENTS_ALL aa WHERE aa.invoice_id IN (##$$ICVIEW$$##) ) AND mc.payment_history_id = aph.payment_history_id ORDER BY aph.accounting_event_id asc',
      p_title                  => 'AP_MC_PAYMENT_HISTORY',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1300_AP_MC_PAYMENT_HISTORY');



debug('begin add_signature: APLIST_1310_AP_SUPPLIERS');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NAME'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##COMPANY_REGISTRATION_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##FIRST_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##INDIVIDUAL_1099'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##LAST_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##NATIONAL_INSURANCE_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##NUM_1099'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##PARTNERSHIP_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##SECOND_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##TAX_REPORTING_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##TCA_SYNC_NUM_1099'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##TCA_SYNC_VAT_REG_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##TCA_SYNC_VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##TRADING_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##UNIQUE_TAX_REFERENCE_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##VALIDATION_NUMBER'):= 'REMOVE_COLUMN';
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##VENDOR_NAME_ALT'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10986',
      p_sig_id                 => 'APLIST_1310_AP_SUPPLIERS',
      p_sig_sql                => 'SELECT * FROM AP_SUPPLIERS WHERE vendor_id IN ( SELECT vendor_id FROM AP_INVOICES_ALL WHERE invoice_id IN (##$$ICVIEW$$##) )',
      p_title                  => 'AP_SUPPLIERS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1310_AP_SUPPLIERS');



debug('begin add_signature: APLIST_1320_PO_VENDORS_OBS');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##FIRST_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##LAST_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##SECOND_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##VALIDATION_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##VENDOR_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##VENDOR_NAME_ALT'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10988',
      p_sig_id                 => 'APLIST_1320_PO_VENDORS_OBS',
      p_sig_sql                => 'SELECT distinct obs.* FROM po_vendors_obs obs, ap_invoices_all ai where obs.vendor_id = ai.vendor_id and invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'PO_VENDORS_OBS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1320_PO_VENDORS_OBS');



debug('begin add_signature: APLIST_1330_PO_VENDOR_SITES_OBS');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##ADDRESS_LINE%'):= 'REMOVE_COLUMN';
   l_info('##MASK##BANK_ACCOUNT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##EMAIL_ADDRESS'):= 'REMOVE_COLUMN';
   l_info('##MASK##FAX'):= 'REMOVE_COLUMN';
   l_info('##MASK##PHONE'):= 'REMOVE_COLUMN';
   l_info('##MASK##VALIDATION_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10989',
      p_sig_id                 => 'APLIST_1330_PO_VENDOR_SITES_OBS',
      p_sig_sql                => 'SELECT distinct obs.* FROM po_vendor_sites_obs obs, ap_invoices_all ai where obs.vendor_id = ai.vendor_id and obs.vendor_site_id = ai.vendor_site_id and invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'PO_VENDOR_SITES_OBS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1330_PO_VENDOR_SITES_OBS');



debug('begin add_signature: APLIST_1340_AP_SUPPLIER_SITES_ALL');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##ADDRESS_LINE%'):= 'REMOVE_COLUMN';
   l_info('##MASK##BANK_ACCOUNT_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##DOING_BUS_AS_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##DUNS_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##EDI_ID_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##EMAIL_ADDRESS'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##FAX'):= 'REMOVE_COLUMN';
   l_info('##MASK##LEGAL_BUSINESS_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##PHONE'):= 'REMOVE_COLUMN';
   l_info('##MASK##REMITTANCE_EMAIL'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##TELEX'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##VALIDATION_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##VAT_REGISTRATION_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10987',
      p_sig_id                 => 'APLIST_1340_AP_SUPPLIER_SITES_ALL',
      p_sig_sql                => 'SELECT * FROM AP_SUPPLIER_SITES_ALL WHERE vendor_site_id IN ( SELECT vendor_site_id FROM AP_INVOICES_ALL WHERE invoice_id IN (##$$ICVIEW$$##) )',
      p_title                  => 'AP_SUPPLIER_SITES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1340_AP_SUPPLIER_SITES_ALL');



debug('begin add_signature: APLIST_1350_HZ_PARTIES');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##ADDRESS%'):= 'REMOVE_COLUMN';
   l_info('##MASK##DUNS_NUMBER'):= 'REMOVE_COLUMN';
   l_info('##MASK##EMAIL_ADDRESS'):= 'REMOVE_COLUMN';
   l_info('##MASK##KNOWN_AS%'):= 'REMOVE_COLUMN';
   l_info('##MASK##PARTY_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##PERSON_%_NAME%'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##PERSON_IDENTIFIER'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##PRIMARY_PHONE_EXTENSION'):= 'REMOVE_COLUMN';
   l_info('##MASK##PRIMARY_PHONE_NUMBER'):= 'REMOVE_COLUMN';
   l_info('##MASK##TAX_REFERENCE'):= 'REMOVE_COLUMN';
   l_info('##MASK##URL'):= 'REMOVE_COLUMN';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10990',
      p_sig_id                 => 'APLIST_1350_HZ_PARTIES',
      p_sig_sql                => 'SELECT DISTINCT HZP.* FROM AP_INVOICES_ALL AI, HZ_PARTIES HZP WHERE AI.PARTY_ID = HZP.PARTY_ID AND AI.INVOICE_ID IN (##$$ICVIEW$$##)',
      p_title                  => 'HZ_PARTIES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1350_HZ_PARTIES');



debug('begin add_signature: APLIST_1360_HZ_PARTY_SITES');
   l_info('##MASK##%ATTRIBUTE%'):= 'REMOVE_COLUMN';
   l_info('##MASK##ADDRESSEE'):= 'REMOVE_COLUMN';
   l_info('##MASK##MAILSTOP'):= 'REMOVE_COLUMN';
   l_info('##MASK##PARTY_SITE_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##PARTY_SITE_NUMBER'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10991',
      p_sig_id                 => 'APLIST_1360_HZ_PARTY_SITES',
      p_sig_sql                => 'SELECT DISTINCT HZPS.* FROM AP_INVOICES_ALL AI, HZ_PARTY_SITES HZPS WHERE AI.PARTY_ID = HZPS.PARTY_ID AND AI.PARTY_SITE_ID = HZPS.PARTY_SITE_ID AND AI.INVOICE_ID IN (##$$ICVIEW$$##)',
      p_title                  => 'HZ_PARTY_SITES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1360_HZ_PARTY_SITES');



debug('begin add_signature: APLIST_1370_IBY_EXTERNAL_PAYEES_ALL');
   l_info('##MASK##REMIT_ADVICE_EMAIL'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##REMIT_ADVICE_FAX'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10992',
      p_sig_id                 => 'APLIST_1370_IBY_EXTERNAL_PAYEES_ALL',
      p_sig_sql                => 'SELECT distinct extp.* 
FROM AP_SUPPLIER_SITES_ALL sites
, iby_external_payees_all extp
, ap_suppliers supp
, ap_invoices_all ai 
where extp.payee_party_id = supp.party_id 
and extp.party_site_id = sites.party_site_id 
and supp.vendor_id = sites.vendor_id 
and ai.vendor_site_id = sites.vendor_site_id 
and ai.invoice_id IN (##$$ICVIEW$$##)
UNION
SELECT distinct extp.*
FROM iby_external_payees_all extp
, ap_invoices_all ai
where extp.party_site_id = ai.party_site_id
and ai.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'IBY_EXTERNAL_PAYEES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1370_IBY_EXTERNAL_PAYEES_ALL');



debug('begin add_signature: APLIST_1380_IBY_ACCOUNT_OWNERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10993',
      p_sig_id                 => 'APLIST_1380_IBY_ACCOUNT_OWNERS',
      p_sig_sql                => 'SELECT DISTINCT ow.*
FROM iby_account_owners      ow,
     ap_invoices_all         ai
WHERE ow.ACCOUNT_OWNER_PARTY_ID = ai.party_Id
      AND ai.invoice_id IN (
    SELECT DISTINCT d.invoice_id
    FROM ap_invoices_all d
    WHERE d.invoice_id in (##$$ICVIEW$$##))',
      p_title                  => 'IBY_ACCOUNT_OWNERS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1380_IBY_ACCOUNT_OWNERS');



debug('begin add_signature: APLIST_1390_IBY_PMT_INSTR_USES_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10994',
      p_sig_id                 => 'APLIST_1390_IBY_PMT_INSTR_USES_ALL',
      p_sig_sql                => 'SELECT DISTINCT ibyu.*
FROM ap_supplier_sites_all    sites,
     iby_external_payees_all    extp,
     ap_suppliers    supp,
     iby_pmt_instr_uses_all    ibyu,
     ap_invoices_all    ai
WHERE extp.payee_party_id = supp.party_id
      AND extp.party_site_id = sites.party_site_id
      AND supp.vendor_id = sites.vendor_id
      AND ai.vendor_site_id = sites.vendor_site_id
      AND ibyu.ext_pmt_party_id = extp.ext_payee_id
      AND ai.invoice_id IN (##$$ICVIEW$$##)
UNION
SELECT DISTINCT ibyu.*
FROM iby_external_payees_all    extp,
     iby_pmt_instr_uses_all    ibyu,
     ap_invoices_all    ai
WHERE extp.party_site_id = ai.party_site_id
      AND ibyu.payment_function = extp.payment_function
      AND ibyu.ext_pmt_party_id = extp.ext_payee_id
      AND ai.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'IBY_PMT_INSTR_USES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1390_IBY_PMT_INSTR_USES_ALL');



debug('begin add_signature: APLIST_1400_IBY_EXT_BANK_ACCOUNTS');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##%HASH_'):= 'REMOVE_COLUMN';
   l_info('##MASK##BANK_ACCOUNT_NAME%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM%'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##CONTACT_%'):= 'REMOVE_COLUMN';
   l_info('##MASK##IBAN%'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MASKED_BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MASKED_IBAN'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##SHORT_ACCT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10995',
      p_sig_id                 => 'APLIST_1400_IBY_EXT_BANK_ACCOUNTS',
      p_sig_sql                => 'SELECT DISTINCT extb.*
FROM ap_supplier_sites_all   sites,
     iby_external_payees_all extp,
     ap_suppliers            supp,
     iby_pmt_instr_uses_all  ibyu,
     iby_ext_bank_accounts   extb,
     ap_invoices_all         ai
WHERE extp.payee_party_id = supp.party_id
      AND extp.party_site_id = sites.party_site_id
      AND supp.vendor_id = sites.vendor_id
      AND ibyu.instrument_id = extb.ext_bank_account_id
      AND ibyu.INSTRUMENT_TYPE = ''BANKACCOUNT''
      AND ai.vendor_site_id = sites.vendor_site_id
      AND ibyu.ext_pmt_party_id = extp.ext_payee_id
      AND ai.invoice_id IN (##$$ICVIEW$$##)
UNION
SELECT DISTINCT extb.*
FROM iby_external_payees_all extp,
     iby_pmt_instr_uses_all  ibyu,
     iby_ext_bank_accounts   extb,
     ap_invoices_all         ai
WHERE extp.party_site_id = ai.party_site_id
      AND ibyu.instrument_id = extb.ext_bank_account_id
      AND ibyu.ext_pmt_party_id = extp.ext_payee_id
      AND ibyu.INSTRUMENT_TYPE = ''BANKACCOUNT''
      AND ai.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'IBY_EXT_BANK_ACCOUNTS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1400_IBY_EXT_BANK_ACCOUNTS');



debug('begin add_signature: APLIST_1410_PO_HEADERS_ALL');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##CLM_SUPPLIER_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##CLM_SUPPLIER_SITE_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##COMMENTS'):= 'REMOVE_COLUMN';
   l_info('##MASK##EMAIL_ADDRESS'):= 'REMOVE_COLUMN';
   l_info('##MASK##FAX'):= 'REMOVE_COLUMN';
   l_info('##MASK##NOTE_TO%'):= 'REMOVE_COLUMN';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10996',
      p_sig_id                 => 'APLIST_1410_PO_HEADERS_ALL',
      p_sig_sql                => 'SELECT distinct poh.* FROM AP_INVOICE_DISTRIBUTIONS_ALL aid, PO_DISTRIBUTIONS_ALL po, PO_HEADERS_ALL poh WHERE aid.invoice_id IN (##$$ICVIEW$$##) AND aid.po_distribution_id is not null AND po.po_distribution_id = aid.po_distribution_id AND poh.po_header_id = po.po_header_id',
      p_title                  => 'PO_HEADERS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1410_PO_HEADERS_ALL');



debug('begin add_signature: APLIST_1420_PO_DISTRIBUTIONS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10997',
      p_sig_id                 => 'APLIST_1420_PO_DISTRIBUTIONS_ALL',
      p_sig_sql                => 'SELECT distinct po.*, 
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.CODE_COMBINATION_ID) "Charge Account", 
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.ACCRUAL_ACCOUNT_ID) "PO Accrual Account",
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.VARIANCE_ACCOUNT_ID) "Variance Account"
FROM AP_INVOICE_DISTRIBUTIONS_ALL aid, PO_DISTRIBUTIONS_ALL po, PO_HEADERS_ALL poh, GL_LEDGERS GL, AP_SYSTEM_PARAMETERS_ALL ASP
WHERE  GL.LEDGER_ID = ASP.SET_OF_BOOKS_ID
AND ASP.ORG_ID = AID.ORG_ID
and aid.invoice_id IN (##$$ICVIEW$$##) 
AND aid.po_distribution_id is not null 
AND po.po_distribution_id = aid.po_distribution_id 
AND poh.po_header_id = po.po_header_id',
      p_title                  => 'PO_DISTRIBUTIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1420_PO_DISTRIBUTIONS_ALL');



debug('begin add_signature: APLIST_1430_PO_LINES_ALL');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##CONTRACTOR_FIRST_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##CONTRACTOR_LAST_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10998',
      p_sig_id                 => 'APLIST_1430_PO_LINES_ALL',
      p_sig_sql                => 'SELECT distinct pl.*,
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.CODE_COMBINATION_ID) "Charge Account", 
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.ACCRUAL_ACCOUNT_ID) "PO Accrual Account",
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.VARIANCE_ACCOUNT_ID) "Variance Account"
FROM AP_INVOICE_DISTRIBUTIONS_ALL aid, PO_DISTRIBUTIONS_ALL po, PO_LINES_ALL pl, GL_LEDGERS GL, AP_SYSTEM_PARAMETERS_ALL ASP
WHERE  GL.LEDGER_ID = ASP.SET_OF_BOOKS_ID
AND ASP.ORG_ID = AID.ORG_ID
and aid.invoice_id IN (##$$ICVIEW$$##) 
AND aid.po_distribution_id is not null 
AND po.po_distribution_id = aid.po_distribution_id 
AND pl.po_header_id = po.po_header_id 
AND pl.po_line_id = po.po_line_id',
      p_title                  => 'PO_LINES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1430_PO_LINES_ALL');



debug('begin add_signature: APLIST_1440_PO_LINE_LOCATIONS_ALL');
   l_info('##MASK##%NOTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10999',
      p_sig_id                 => 'APLIST_1440_PO_LINE_LOCATIONS_ALL',
      p_sig_sql                => 'SELECT distinct pll.*,
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.CODE_COMBINATION_ID) "Charge Account", 
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.ACCRUAL_ACCOUNT_ID) "PO Accrual Account",
fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.CHART_OF_ACCOUNTS_ID , po.VARIANCE_ACCOUNT_ID) "Variance Account"
FROM AP_INVOICE_DISTRIBUTIONS_ALL aid, PO_DISTRIBUTIONS_ALL po, PO_LINE_LOCATIONS_ALL pll, GL_LEDGERS GL, AP_SYSTEM_PARAMETERS_ALL ASP
WHERE  GL.LEDGER_ID = ASP.SET_OF_BOOKS_ID
AND ASP.ORG_ID = AID.ORG_ID
AND aid.invoice_id IN (##$$ICVIEW$$##)
AND aid.po_distribution_id is not null 
AND po.po_distribution_id = aid.po_distribution_id 
AND pll.po_header_id = po.po_header_id 
AND pll.po_line_id = po.po_line_id 
AND pll.line_location_id = po.line_location_id',
      p_title                  => 'PO_LINE_LOCATIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1440_PO_LINE_LOCATIONS_ALL');



debug('begin add_signature: APLIST_1450_PO_MC_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11000',
      p_sig_id                 => 'APLIST_1450_PO_MC_HEADERS',
      p_sig_sql                => 'SELECT * FROM PO_MC_HEADERS WHERE po_header_id IN ( SELECT po.po_header_id FROM AP_INVOICE_DISTRIBUTIONS_ALL aid, PO_DISTRIBUTIONS_ALL po WHERE aid.invoice_id IN (##$$ICVIEW$$##) AND aid.po_distribution_id is not null AND po.po_distribution_id = aid.po_distribution_id )',
      p_title                  => 'PO_MC_HEADERS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1450_PO_MC_HEADERS');



debug('begin add_signature: APLIST_1460_PO_MC_DISTRIBUTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11001',
      p_sig_id                 => 'APLIST_1460_PO_MC_DISTRIBUTIONS',
      p_sig_sql                => 'SELECT mcd.* FROM PO_MC_DISTRIBUTIONS mcd, PO_DISTRIBUTIONS_ALL pd WHERE pd.po_distribution_id IN ( SELECT po.po_distribution_id FROM AP_INVOICE_DISTRIBUTIONS_ALL aid, PO_DISTRIBUTIONS_ALL po WHERE aid.invoice_id IN (##$$ICVIEW$$##) AND aid.po_distribution_id is not null AND po.po_distribution_id = aid.po_distribution_id ) AND pd.po_distribution_id = mcd.po_distribution_id',
      p_title                  => 'PO_MC_DISTRIBUTIONS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1460_PO_MC_DISTRIBUTIONS');



debug('begin add_signature: APLIST_1480_AP_PREPAY_HISTORY_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11003',
      p_sig_id                 => 'APLIST_1480_AP_PREPAY_HISTORY_ALL',
      p_sig_sql                => 'SELECT aph.* FROM AP_PREPAY_HISTORY_ALL aph WHERE aph.invoice_id IN (##$$ICVIEW$$##) OR aph.prepay_invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_PREPAY_HISTORY_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1480_AP_PREPAY_HISTORY_ALL');



debug('begin add_signature: APLIST_1490_AP_PREPAY_APP_DISTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11004',
      p_sig_id                 => 'APLIST_1490_AP_PREPAY_APP_DISTS',
      p_sig_sql                => 'SELECT apad.* FROM AP_PREPAY_APP_DISTS apad, AP_INVOICE_DISTRIBUTIONS_ALL aid WHERE aid.invoice_id IN (##$$ICVIEW$$##) AND apad.invoice_distribution_id = aid.invoice_distribution_id',
      p_title                  => 'AP_PREPAY_APP_DISTS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1490_AP_PREPAY_APP_DISTS');



debug('begin add_signature: APLIST_1500_APPLIED_TO');
   l_info('##MASK##VENDOR NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11005',
      p_sig_id                 => 'APLIST_1500_APPLIED_TO',
      p_sig_sql                => 'SELECT pv.vendor_name "Vendor Name", ai.invoice_num "Invoice Number", ai.invoice_id "Invoice Id", ai.invoice_amount "Invoice Amount", ail.line_number "Invoice Line Num", ail.prepay_invoice_id "Prepay Invoice Id", ai2.invoice_num "Prepay Invoice Num", ail.prepay_line_number "Prepay Invoice Line Num", (-1)*(ail.amount - NVL(ail.included_tax_amount,0)) "Prepay Amount Applied", NULLIF((-1)*(NVL(ail.total_rec_tax_amount, 0) + NVL(ail.total_nrec_tax_amount, 0)), 0) "Tax Amount Applied" FROM AP_INVOICES_ALL ai, AP_INVOICES_ALL ai2, AP_INVOICE_LINES_ALL ail, AP_SUPPLIERS pv WHERE ai.invoice_id = ail.invoice_id AND ai2.invoice_id = ail.prepay_invoice_id AND ail.amount < 0 AND NVL(ail.discarded_flag,''N'') != ''Y'' AND ail.line_type_lookup_code = ''PREPAY'' AND ai.vendor_id = pv.vendor_id AND ai.invoice_type_lookup_code NOT IN (''PREPAYMENT'', ''CREDIT'',''DEBIT'') AND ail.prepay_invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'Invoices Prepayment Invoice Has Been Applied To',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1500_APPLIED_TO');



debug('begin add_signature: APLIST_1510_APPLIED_TO2');
   l_info('##MASK##VENDOR NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11006',
      p_sig_id                 => 'APLIST_1510_APPLIED_TO2',
      p_sig_sql                => 'SELECT pv.vendor_name "Vendor Name", ai.invoice_num "Invoice Num", ai.invoice_id "Invoice Id", ai.invoice_amount "Invoice amount", ail.line_number "Invoice Line Num", ai2.invoice_id "Prepay Invoice Id", ai2.invoice_num "Prepay Invoice Num", ail.prepay_line_number "Prepay Invoice Line Num", (-1)*(ail.amount - NVL(ail.included_tax_amount,0)) "Prepay Amount Applied", NULLIF((-1)*(NVL(ail.total_rec_tax_amount, 0) + NVL(ail.total_nrec_tax_amount, 0)), 0) "Tax amount Applied" FROM AP_INVOICES_ALL ai, AP_INVOICES_ALL ai2, AP_INVOICE_LINES_ALL ail, AP_SUPPLIERS pv WHERE ai.invoice_id = ail.invoice_id AND ai2.invoice_id = ail.prepay_invoice_id AND ail.amount < 0 AND NVL(ail.discarded_flag,''N'') <> ''Y'' AND ail.line_type_lookup_code = ''PREPAY'' AND ai.vendor_id = pv.vendor_id AND ai.invoice_type_lookup_code NOT IN (''PREPAYMENT'', ''CREDIT'',''DEBIT'') AND ai.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'Prepayment Invoices Applied to Invoice',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1510_APPLIED_TO2');



debug('begin add_signature: APLIST_1520_AP_BANK_BRANCHES');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##ADDRESS_LINE%'):= 'REMOVE_COLUMN';
   l_info('##MASK##BANK_ADMIN_EMAIL'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##BANK_BRANCH_NAME_ALT'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_NAME_ALT'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##CONTACT_%_NAME'):= 'REMOVE_COLUMN';
   l_info('##MASK##PHONE'):= 'REMOVE_COLUMN';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11007',
      p_sig_id                 => 'APLIST_1520_AP_BANK_BRANCHES',
      p_sig_sql                => 'SELECT abb.* FROM AP_BANK_ACCOUNTS_ALL aba, AP_CHECK_STOCKS_ALL acs, AP_BANK_BRANCHES abb WHERE acs.check_stock_id IN ( SELECT check_stock_id FROM AP_CHECKS_ALL WHERE check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ) AND acs.bank_account_id = aba.bank_account_id AND abb.bank_branch_id = aba.bank_branch_id ORDER BY abb.bank_name',
      p_title                  => 'AP_BANK_BRANCHES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1520_AP_BANK_BRANCHES');



debug('begin add_signature: APLIST_1530_AP_BANK_ACCOUNTS_ALL');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##ACCOUNT_HOLDER_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##ACCOUNT_HOLDER_NAME_ALT'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NAME'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NAME_ALT'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##CONTACT_%_NAME'):= 'REMOVE_COLUMN';
   l_info('##MASK##CONTACT_PHONE'):= 'REMOVE_COLUMN';
   l_info('##MASK##EFT_USER_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##IBAN_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11008',
      p_sig_id                 => 'APLIST_1530_AP_BANK_ACCOUNTS_ALL',
      p_sig_sql                => 'SELECT aba.* FROM AP_BANK_ACCOUNTS_ALL aba, AP_CHECK_STOCKS_ALL acs, AP_BANK_BRANCHES abb WHERE acs.check_stock_id IN ( SELECT check_stock_id FROM AP_CHECKS_ALL WHERE check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ) AND acs.bank_account_id = aba.bank_account_id AND abb.bank_branch_id = aba.bank_branch_id ORDER BY abb.bank_name',
      p_title                  => 'AP_BANK_ACCOUNTS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1530_AP_BANK_ACCOUNTS_ALL');



debug('begin add_signature: APLIST_1540_AP_CHECK_STOCKS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11009',
      p_sig_id                 => 'APLIST_1540_AP_CHECK_STOCKS_ALL',
      p_sig_sql                => 'SELECT acs.* FROM AP_BANK_ACCOUNTS_ALL aba, AP_CHECK_STOCKS_ALL acs, AP_BANK_BRANCHES abb WHERE acs.check_stock_id IN ( SELECT check_stock_id FROM AP_CHECKS_ALL WHERE check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ) AND acs.bank_account_id = aba.bank_account_id AND abb.bank_branch_id = aba.bank_branch_id ORDER BY abb.bank_name',
      p_title                  => 'AP_CHECK_STOCKS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1540_AP_CHECK_STOCKS_ALL');



debug('begin add_signature: APLIST_1550_AP_CHECK_FORMATS');
   l_info('##MASK##%ATTRIBUTE%'):= 'REMOVE_COLUMN';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11010',
      p_sig_id                 => 'APLIST_1550_AP_CHECK_FORMATS',
      p_sig_sql                => 'SELECT acf.* FROM AP_PAYMENT_PROGRAMS app, AP_CHECK_STOCKS_ALL acs, AP_CHECK_FORMATS acf, AP_PAYMENT_PROGRAMS app2, AP_PAYMENT_PROGRAMS app3 WHERE acs.check_stock_id IN ( SELECT check_stock_id FROM AP_CHECKS_ALL WHERE check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ) AND acs.check_format_id = acf.check_format_id AND app.program_id = acf.format_payments_program_id AND acf.build_payments_program_id = app2.program_id AND acf.remittance_advice_program_id = app3.program_id(+) ORDER BY acf.name',
      p_title                  => 'AP_CHECK_FORMATS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1550_AP_CHECK_FORMATS');



debug('begin add_signature: APLIST_1560_AP_PAYMENT_PROGRAMS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11011',
      p_sig_id                 => 'APLIST_1560_AP_PAYMENT_PROGRAMS',
      p_sig_sql                => 'SELECT aPP.* FROM AP_PAYMENT_PROGRAMS app, AP_CHECK_STOCKS_ALL acs, AP_CHECK_FORMATS acf, AP_PAYMENT_PROGRAMS app2, AP_PAYMENT_PROGRAMS app3 WHERE acs.check_stock_id IN ( SELECT check_stock_id FROM AP_CHECKS_ALL WHERE check_id IN ( SELECT distinct check_id FROM AP_INVOICE_PAYMENTS_ALL WHERE invoice_id IN (##$$ICVIEW$$##) ) ) AND acs.check_format_id = acf.check_format_id AND app.program_id = acf.format_payments_program_id AND acf.build_payments_program_id = app2.program_id AND acf.remittance_advice_program_id = app3.program_id(+) ORDER BY acf.name',
      p_title                  => 'AP_PAYMENT_PROGRAMS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1560_AP_PAYMENT_PROGRAMS');



debug('begin add_signature: APLIST_1570_HZ_BANK_INFO');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##ALTBANKNAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANKNAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANKNUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##SHORTBANKNAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11012',
      p_sig_id                 => 'APLIST_1570_HZ_BANK_INFO',
      p_sig_sql                => 'Select distinct BankParty.PARTY_ID BankId, BankParty.PARTY_NAME BankName, BankParty.ORGANIZATION_NAME_PHONETIC AltBankName, BankParty.KNOWN_AS ShortBankName, BankOrgProfile.BANK_OR_BRANCH_NUMBER BankNumber, FndTerritory.territory_short_name BankCountry, BankCA.class_code AS institution_type_code, bankca.end_date_active From HZ_PARTIES BankParty, ap_invoice_payments_all aip, ap_checks_all ac, ce_bank_acct_uses_all uses, ce_bank_accounts cba, CE_GL_ACCOUNTS_CCID cegl, HZ_ORGANIZATION_PROFILES BankOrgProfile, HZ_CODE_ASSIGNMENTS BankCA, FND_TERRITORIES_VL FndTerritory Where BankParty.PARTY_TYPE = ''ORGANIZATION'' and cba.bank_id = BankParty.PARTY_ID and cba.bank_account_id = uses.bank_account_id and uses.bank_acct_use_id = cegl.bank_acct_use_id and aip.check_id = ac.check_id and aip.invoice_id IN (##$$ICVIEW$$##) and ac.ce_bank_acct_use_id = uses.bank_acct_use_id And BankParty.status = ''A'' And BankParty.PARTY_ID = BankOrgProfile.PARTY_ID And SYSDATE between TRUNC(BankOrgProfile.effective_start_date) and NVL(TRUNC(BankOrgProfile.effective_end_date), SYSDATE+1) And BankCA.CLASS_CATEGORY = ''BANK_INSTITUTION_TYPE'' And BankCA.CLASS_CODE in (''BANK'', ''CLEARINGHOUSE'') And BankCA.OWNER_TABLE_NAME = ''HZ_PARTIES'' And BankCA.OWNER_TABLE_ID = BankParty.PARTY_ID And NVL(BankCA.STATUS, ''A'') = ''A'' And BankOrgProfile.HOME_COUNTRY = FndTerritory.territory_code',
      p_title                  => 'HZ_BANK_INFO',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1570_HZ_BANK_INFO');



debug('begin add_signature: APLIST_1580_HZ_BRANCH_INFO');
   l_info('##MASK##ALTBANKNAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANKNAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANKNUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##SHORTBANKNAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11013',
      p_sig_id                 => 'APLIST_1580_HZ_BRANCH_INFO',
      p_sig_sql                => 'Select distinct BankParty.PARTY_ID BankId, BankParty.PARTY_NAME BankName, BankParty.ORGANIZATION_NAME_PHONETIC AltBankName, BankParty.KNOWN_AS ShortBankName, BankOrgProfile.BANK_OR_BRANCH_NUMBER BankNumber, FndTerritory.territory_short_name BankCountry, BranchParty.PARTY_ID BranchId, BranchParty.PARTY_NAME BranchName, BranchParty.ORGANIZATION_NAME_PHONETIC AltBranchName, BranchOrgProfile.BANK_OR_BRANCH_NUMBER BranchNumber, BankCA.class_code Bank_institution_type, BranchCPEdi.edi_ece_tp_location_code EdiLocation, bankca.end_date_active BANKCA_END_DATE, branchca.end_date_active BRANCHCA_END_DATE 
From HZ_PARTIES BankParty, ap_invoice_payments_all aip, ap_checks_all ac, ce_bank_acct_uses_all uses, ce_bank_accounts cba, CE_GL_ACCOUNTS_CCID cegl, HZ_ORGANIZATION_PROFILES BankOrgProfile, HZ_CODE_ASSIGNMENTS BankCA, HZ_PARTIES BranchParty, HZ_ORGANIZATION_PROFILES BranchOrgProfile, HZ_CODE_ASSIGNMENTS BranchCA, HZ_CONTACT_POINTS BranchCPEdi, HZ_RELATIONSHIPS BRRel, FND_TERRITORIES_VL FndTerritory 
Where BankParty.PARTY_TYPE = ''ORGANIZATION'' and cba.bank_account_id = uses.bank_account_id and uses.bank_acct_use_id = cegl.bank_acct_use_id and aip.check_id = ac.check_id and aip.invoice_id IN (##$$ICVIEW$$##) 
and ac.ce_bank_acct_use_id = uses.bank_acct_use_id and BankParty.PARTY_ID = cba.bank_id and cba.bank_branch_id = BranchParty.PARTY_ID And BankParty.status = ''A'' And BankParty.PARTY_ID = BankOrgProfile.PARTY_ID 
And SYSDATE between TRUNC(BankOrgProfile.effective_start_date) and NVL(TRUNC(BankOrgProfile.effective_end_date), SYSDATE+1) And BankCA.CLASS_CATEGORY = ''BANK_INSTITUTION_TYPE'' And BankCA.CLASS_CODE in (''BANK'', ''CLEARINGHOUSE'') 
And BankCA.OWNER_TABLE_NAME = ''HZ_PARTIES'' And BankCA.OWNER_TABLE_ID = BankParty.PARTY_ID And NVL(BankCA.STATUS, ''A'') = ''A'' And BranchParty.PARTY_TYPE = ''ORGANIZATION'' And BranchParty.status = ''A'' 
And BranchOrgProfile.PARTY_ID = BranchParty.PARTY_ID And SYSDATE between TRUNC(BranchOrgProfile.effective_start_date) and NVL(TRUNC(BranchOrgProfile.effective_end_date), SYSDATE+1) And BranchCA.CLASS_CATEGORY = ''BANK_INSTITUTION_TYPE'' And BranchCA.CLASS_CODE in (''BANK_BRANCH'', ''CLEARINGHOUSE_BRANCH'') And BranchCA.OWNER_TABLE_NAME = ''HZ_PARTIES'' And BranchCA.OWNER_TABLE_ID = BranchParty.PARTY_ID And NVL(BranchCA.STATUS, ''A'') = ''A'' And BranchCPEdi.OWNER_TABLE_NAME(+) = ''HZ_PARTIES'' And BranchCPEdi.OWNER_TABLE_ID(+) = BranchParty.PARTY_ID And BranchCPEdi.CONTACT_POINT_TYPE(+) = ''EDI'' And BranchCPEdi.STATUS(+) = ''A'' And BRRel.OBJECT_ID = BankParty.PARTY_ID And BranchParty.PARTY_ID = BRRel.SUBJECT_ID And BRRel.RELATIONSHIP_TYPE = ''BANK_AND_BRANCH'' And BRRel.RELATIONSHIP_CODE = ''BRANCH_OF'' And BRRel.STATUS = ''A'' And BRRel.SUBJECT_TABLE_NAME = ''HZ_PARTIES'' And BRRel.SUBJECT_TYPE = ''ORGANIZATION'' And BRRel.OBJECT_TABLE_NAME = ''HZ_PARTIES'' And BRRel.OBJECT_TYPE = ''ORGANIZATION'' And BankOrgProfile.home_country = FndTerritory.territory_code',
      p_title                  => 'HZ BRANCH INFO',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1580_HZ_BRANCH_INFO');



debug('begin add_signature: APLIST_1590_CE_BANK_ACCOUNTS');
   l_info('##MASK##%ATTRIBUTE%'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##ACCOUNT_HOLDER_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##ACCOUNT_HOLDER_NAME_ALT'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NAME_ALT'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##BANK_ACCOUNT_NUM_ELECTRONIC'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##MASK##EFT_USER_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##IBAN_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MASKED_ACCOUNT_NUM'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MASKED_IBAN'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##SHORT_ACCOUNT_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11014',
      p_sig_id                 => 'APLIST_1590_CE_BANK_ACCOUNTS',
      p_sig_sql                => 'select distinct cba.* 
from ap_invoice_payments_all aip, 
ap_checks_all ac, 
ce_bank_acct_uses_all uses, 
ce_bank_accounts cba, 
CE_GL_ACCOUNTS_CCID cegl 
where cba.bank_account_id = uses.bank_account_id 
and uses.bank_acct_use_id = cegl.bank_acct_use_id 
and aip.check_id = ac.check_id 
and aip.invoice_id IN (##$$ICVIEW$$##) 
and ac.ce_bank_acct_use_id = uses.bank_acct_use_id',
      p_title                  => 'CE_BANK_ACCOUNTS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1590_CE_BANK_ACCOUNTS');



debug('begin add_signature: APLIST_1600_CE_BANK_ACCT_USES_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11015',
      p_sig_id                 => 'APLIST_1600_CE_BANK_ACCT_USES_ALL',
      p_sig_sql                => 'select distinct uses.* from ap_invoice_payments_all aip, ap_checks_all ac, ce_bank_acct_uses_all uses, ce_bank_accounts cba, CE_GL_ACCOUNTS_CCID cegl where cba.bank_account_id = uses.bank_account_id and uses.bank_acct_use_id = cegl.bank_acct_use_id and aip.check_id = ac.check_id and aip.invoice_id IN (##$$ICVIEW$$##) and ac.ce_bank_acct_use_id = uses.bank_acct_use_id',
      p_title                  => 'CE_BANK_ACCT_USES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1600_CE_BANK_ACCT_USES_ALL');



debug('begin add_signature: APLIST_1610_CE_GL_ACCOUNTS_CCID');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11016',
      p_sig_id                 => 'APLIST_1610_CE_GL_ACCOUNTS_CCID',
      p_sig_sql                => 'select distinct cegl.*, fnd_flex_ext.get_segs(''SQLGL'',''GL#'', gl.chart_of_accounts_id , cegl.cash_clearing_ccid) "CASH CLEARING ACCOUNT", fnd_flex_ext.get_segs(''SQLGL'',''GL#'', GL.chart_of_accounts_id , cegl.AP_ASSET_CCID) "CASH ACCOUNT" from ap_invoice_payments_all aip, ap_checks_all ac, ce_bank_acct_uses_all uses, ce_bank_accounts cba, CE_GL_ACCOUNTS_CCID cegl,
gl_ledgers gl, ap_system_parameters_all asp where cba.bank_account_id = uses.bank_account_id and uses.bank_acct_use_id = cegl.bank_acct_use_id and aip.check_id = ac.check_id 
and gl.ledger_id = asp.set_of_books_id
and asp.org_id = ac.org_id
and aip.invoice_id IN (##$$ICVIEW$$##) and ac.ce_bank_acct_use_id = uses.bank_acct_use_id',
      p_title                  => 'CE_GL_ACCOUNTS_CCID',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1610_CE_GL_ACCOUNTS_CCID');



debug('begin add_signature: APLIST_1620_CE_STATEMENT_RECONCILS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11017',
      p_sig_id                 => 'APLIST_1620_CE_STATEMENT_RECONCILS_ALL',
      p_sig_sql                => 'SELECT distinct csr.* FROM CE_STATEMENT_LINES cel, CE_STATEMENT_HEADERS ceh, CE_STATEMENT_RECONCILS_ALL csr, AP_INVOICE_PAYMENTS_ALL aip, AP_CHECKS_ALL ac WHERE cel.statement_header_id = ceh.statement_header_id AND ac.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) AND aip.check_id = ac.check_id AND ac.bank_account_id = ceh.bank_account_id AND to_char(ac.check_number) = cel.bank_trx_number AND csr.statement_line_id = cel.statement_line_id UNION SELECT distinct csr.* FROM CE_STATEMENT_LINES cel, CE_STATEMENT_HEADERS ceh, CE_STATEMENT_RECONCILS_ALL csr, AP_INVOICE_PAYMENTS_ALL aip, AP_CHECKS_ALL ac, ce_bank_acct_uses_all uses WHERE cel.statement_header_id = ceh.statement_header_id AND ac.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) AND aip.check_id = ac.check_id AND uses.bank_account_id = ceh.bank_account_id AND to_char(ac.check_number) = cel.bank_trx_number AND csr.statement_line_id = cel.statement_line_id and ac.ce_bank_acct_use_id = uses.bank_acct_use_id',
      p_title                  => 'CE_STATEMENT_RECONCILS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1620_CE_STATEMENT_RECONCILS_ALL');



debug('begin add_signature: APLIST_1630_CE_STATEMENT_HEADERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11018',
      p_sig_id                 => 'APLIST_1630_CE_STATEMENT_HEADERS',
      p_sig_sql                => 'SELECT distinct ceh.* FROM CE_STATEMENT_LINES cel, CE_STATEMENT_HEADERS ceh, CE_STATEMENT_RECONCILS_ALL csr, AP_INVOICE_PAYMENTS_ALL aip, AP_CHECKS_ALL ac WHERE cel.statement_header_id = ceh.statement_header_id AND ac.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) AND aip.check_id = ac.check_id AND ac.bank_account_id = ceh.bank_account_id AND to_char(ac.check_number) = cel.bank_trx_number AND csr.statement_line_id = cel.statement_line_id UNION SELECT distinct ceh.* FROM CE_STATEMENT_LINES cel, CE_STATEMENT_HEADERS ceh, CE_STATEMENT_RECONCILS_ALL csr, AP_INVOICE_PAYMENTS_ALL aip, AP_CHECKS_ALL ac, ce_bank_acct_uses_all uses WHERE cel.statement_header_id = ceh.statement_header_id AND ac.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) AND aip.check_id = ac.check_id AND uses.bank_account_id = ceh.bank_account_id AND to_char(ac.check_number) = cel.bank_trx_number AND csr.statement_line_id = cel.statement_line_id and ac.ce_bank_acct_use_id = uses.bank_acct_use_id',
      p_title                  => 'CE_STATEMENT_HEADERS',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1630_CE_STATEMENT_HEADERS');



debug('begin add_signature: APLIST_1640_CE_STATEMENT_LINES');
   l_info('##MASK##BANK_ACCOUNT_TEXT'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##CUSTOMER_TEXT'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##INVOICE_TEXT'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11019',
      p_sig_id                 => 'APLIST_1640_CE_STATEMENT_LINES',
      p_sig_sql                => 'SELECT distinct cel.* FROM CE_STATEMENT_LINES cel, CE_STATEMENT_HEADERS ceh, CE_STATEMENT_RECONCILS_ALL csr, AP_INVOICE_PAYMENTS_ALL aip, AP_CHECKS_ALL ac WHERE cel.statement_header_id = ceh.statement_header_id AND ac.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) AND aip.check_id = ac.check_id AND ac.bank_account_id = ceh.bank_account_id AND to_char(ac.check_number) = cel.bank_trx_number AND csr.statement_line_id = cel.statement_line_id UNION SELECT distinct cel.* FROM CE_STATEMENT_LINES cel, CE_STATEMENT_HEADERS ceh, CE_STATEMENT_RECONCILS_ALL csr, AP_INVOICE_PAYMENTS_ALL aip, AP_CHECKS_ALL ac, ce_bank_acct_uses_all uses WHERE cel.statement_header_id = ceh.statement_header_id AND ac.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##) AND aip.check_id = ac.check_id AND uses.bank_account_id = ceh.bank_account_id AND to_char(ac.check_number) = cel.bank_trx_number AND csr.statement_line_id = cel.statement_line_id and ac.ce_bank_acct_use_id = uses.bank_acct_use_id',
      p_title                  => 'CE_STATEMENT_LINES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1640_CE_STATEMENT_LINES');



debug('begin add_signature: APLIST_1650_AP_EXPENSE_REPORT_HEADERS_ALL');
   l_info('##MASK##OVERRIDE_APPROVER_NAME'):= 'DISPLAY_FIRST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11020',
      p_sig_id                 => 'APLIST_1650_AP_EXPENSE_REPORT_HEADERS_ALL',
      p_sig_sql                => 'select distinct erh.* from ap_exp_report_dists_all erd, ap_expense_report_lines_all erl, ap_invoices_all ai, ap_expense_report_headers_all erh where ai.invoice_id = erh.vouchno and erd.report_header_id(+) = erh.report_header_id and erl.report_header_id(+) = erh.report_header_id and ai.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_EXPENSE_REPORT_HEADERS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1650_AP_EXPENSE_REPORT_HEADERS_ALL');



debug('begin add_signature: APLIST_1660_AP_EXPENSE_REPORT_LINES_ALL');
   l_info('##MASK##MERCHANT_NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##MASK##MERCHANT_TAXPAYER_ID'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##MASK##MERCHANT_TAX_REG_NUMBER'):= 'DISPLAY_LAST_25_PCNT';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11021',
      p_sig_id                 => 'APLIST_1660_AP_EXPENSE_REPORT_LINES_ALL',
      p_sig_sql                => 'select distinct erl.* from ap_exp_report_dists_all erd, ap_expense_report_lines_all erl, ap_invoices_all ai, ap_expense_report_headers_all erh where ai.invoice_id = erh.vouchno and erd.report_header_id(+) = erh.report_header_id and erl.report_header_id(+) = erh.report_header_id and ai.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_EXPENSE_REPORT_LINES_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1660_AP_EXPENSE_REPORT_LINES_ALL');



debug('begin add_signature: APLIST_1670_AP_EXPENSE_REPORT_DISTS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11022',
      p_sig_id                 => 'APLIST_1670_AP_EXPENSE_REPORT_DISTS_ALL',
      p_sig_sql                => 'select distinct erd.* from ap_exp_report_dists_all erd, ap_expense_report_lines_all erl, ap_invoices_all ai, ap_expense_report_headers_all erh where ai.invoice_id = erh.vouchno and erd.report_header_id(+) = erh.report_header_id and erl.report_header_id(+) = erh.report_header_id and ai.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'AP_EXPENSE_REPORT_DISTS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1670_AP_EXPENSE_REPORT_DISTS_ALL');



debug('begin add_signature: APLIST_1680_FV_TREASURY_CONFIRMATIONS_ALL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11023',
      p_sig_id                 => 'APLIST_1680_FV_TREASURY_CONFIRMATIONS_ALL',
      p_sig_sql                => 'SELECT distinct tc.* FROM AP_INVOICE_PAYMENTS_ALL aip, AP_CHECKS_ALL ac, FV_TREASURY_CONFIRMATIONS_ALL tc WHERE (ac.checkrun_name = tc.checkrun_name OR ac.payment_instruction_id = tc.payment_instruction_id) AND ac.check_id = aip.check_id AND aip.invoice_id IN (##$$ICVIEW$$##)',
      p_title                  => 'FV_TREASURY_CONFIRMATIONS_ALL',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: APLIST_1680_FV_TREASURY_CONFIRMATIONS_ALL');



debug('begin add_signature: APLIST_1690_FND_CURRENCIES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11024',
      p_sig_id                 => 'APLIST_1690_FND_CURRENCIES',
      p_sig_sql                => 'SELECT * FROM FND_CURRENCIES WHERE currency_code IN ( SELECT a.invoice_currency_code FROM AP_INVOICES_ALL a WHERE a.invoice_id IN (##$$ICVIEW$$##) UNION SELECT b.payment_currency_code FROM AP_INVOICES_ALL b WHERE b.invoice_id IN (##$$ICVIEW$$##) UNION SELECT c.base_currency_code FROM AP_SYSTEM_PARAMETERS_ALL c, AP_INVOICES_ALL AI WHERE 
C.ORG_ID = AI.ORG_ID
AND AI.INVOICE_ID IN (##$$ICVIEW$$##) )',
      p_title                  => 'FND_CURRENCIES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: APLIST_1690_FND_CURRENCIES');



debug('begin add_signature: EBS_FIN_AP_AP_LIST_PAYMENT_METHOD');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24015',
      p_sig_id                 => 'EBS_FIN_AP_AP_LIST_PAYMENT_METHOD',
      p_sig_sql                => 'select * 
from IBY_PAYMENT_METHODS_B b, IBY_PAYMENT_METHODS_TL t 
where t.language = ''US'' 
and b.payment_method_code = t.payment_method_code 
and b.payment_method_code in 
(
select s.PAYMENT_METHOD_CODE from ap_payment_schedules_all s where s.invoice_id in (##$$ICVIEW$$##) 
UNION 
select i.payment_method_code from ap_invoices_all i where i.invoice_id in(##$$ICVIEW$$##))',
      p_title                  => 'IBY_PAYMENT_METHOD_B',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_AP_LIST_PAYMENT_METHOD');



debug('begin add_signature: EBS_FIN_AP_PM_IBY_VAL_ASSIGNMENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24028',
      p_sig_id                 => 'EBS_FIN_AP_PM_IBY_VAL_ASSIGNMENTS',
      p_sig_sql                => 'select * 
from IBY_VAL_ASSIGNMENTS 
where val_assignment_entity_type = ''METHOD'' 
and ASSIGNMENT_ENTITY_ID in (
select s.PAYMENT_METHOD_CODE 
from ap_payment_schedules_all s 
where s.invoice_id in (##$$ICVIEW$$##)
UNION select i.payment_method_code 
from ap_invoices_all i 
where i.invoice_id in (##$$ICVIEW$$##))',
      p_title                  => 'IBY_VAL_ASSIGNMENTS (Payment Method)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_PM_IBY_VAL_ASSIGNMENTS');



debug('begin add_signature: EBS_FIN_AP_IBY_VALIDATION_SETS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24029',
      p_sig_id                 => 'EBS_FIN_AP_IBY_VALIDATION_SETS',
      p_sig_sql                => 'select b.*, t.VALIDATION_SET_DISPLAY_NAME, t.language
from IBY_VALIDATION_SETS_B b
, IBY_VALIDATION_SETS_TL t 
where b.validation_set_code = t.validation_set_code 
and t.language = ''US'' 
and b.validation_set_code in (
select a.validation_set_code from IBY_VAL_ASSIGNMENTS a 
where a.val_assignment_entity_type = ''METHOD'' 
and ASSIGNMENT_ENTITY_ID in 
(
select s.PAYMENT_METHOD_CODE from ap_payment_schedules_all s where s.invoice_id in (##$$ICVIEW$$##))
UNION 
select i.payment_method_code 
from ap_invoices_all i 
where i.invoice_id in (##$$ICVIEW$$##))',
      p_title                  => ' IBY_VALIDATION_SETS_B',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_IBY_VALIDATION_SETS');



debug('begin add_signature: EBS_FIN_AP_IBY_VALIDATION_VALUES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24030',
      p_sig_id                 => 'EBS_FIN_AP_IBY_VALIDATION_VALUES',
      p_sig_sql                => 'select * 
from IBY_VALIDATION_VALUES 
where VALIDATION_ASSIGNMENT_ID in 
(
select a.VALIDATION_ASSIGNMENT_ID from IBY_VAL_ASSIGNMENTS a where a.val_assignment_entity_type = ''METHOD'' 
and ASSIGNMENT_ENTITY_ID in 
(
select s.PAYMENT_METHOD_CODE from ap_payment_schedules_all s where s.invoice_id in (##$$ICVIEW$$##)
UNION 
select i.payment_method_code 
from ap_invoices_all i 
where i.invoice_id in (##$$ICVIEW$$##)))',
      p_title                  => 'IBY_VALIDATION_VALUES',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rows selected',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_IBY_VALIDATION_VALUES');



debug('begin add_signature: AC_PLSQL_FILE_VERSIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5500',
      p_sig_id                 => 'AC_PLSQL_FILE_VERSIONS',
      p_sig_sql                => 'select o.object_name,
       substr(ltrim(rtrim(substr(substr(s.text, instr(s.text,''Header: '')),
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 1),
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2) -
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 1) ))), 1, 25) "File Name",
       substr(ltrim(rtrim(substr(substr(s.text, instr(s.text,''Header: '')),
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2),
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 3) -
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2) ))), 1, 30) "File version",
      decode(o.object_type, ''PACKAGE'' , ''SPEC'', ''PACKAGE BODY'', ''BODY'') type,
      o.object_type pkg_type,
      o.status status
from  user_objects o , user_source s
where s.name = o.object_name
and   s.type = o.object_type
and   o.object_type  in (''PACKAGE'' , ''PACKAGE BODY'')
and   (o.object_name like ''##$$FK2$$##\_%'' escape ''\'') 
and   s.line between 2 and 3
and   s.text like ''%Header: %''
order by 1, 3 desc, 5 desc',
      p_title                  => 'Package Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => ' ',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '14'
      );
   l_info.delete;
debug('end add_signature: AC_PLSQL_FILE_VERSIONS');



debug('begin add_signature: IBY_AC_OTHER_FILE_VERSIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11564',
      p_sig_id                 => 'IBY_AC_OTHER_FILE_VERSIONS',
      p_sig_sql                => 'select distinct
   af.filename,
   substr(af.filename, instr(af.filename, ''.'') + 1) ext,
   af.app_short_name,
   af.subdir,
   (
      select
         version 
      from
         (
            select
               adv.file_id,
               adv.version 
            from
               ad_file_versions adv 
            order by
               to_number(version_segment1) desc,
               to_number(version_segment2) desc,
               to_number(version_segment3) desc,
               to_number(version_segment4) desc,
               to_number(version_segment5) desc,
               to_number(version_segment6) desc,
               to_number(version_segment7) desc,
               to_number(version_segment2) desc,
               to_number(version_segment9) desc,
               to_number(version_segment10) desc
         )
         adv2 
      where
         adv2.file_id = af.file_id 
         and rownum = 1
   )
   "File Version"
from
   ad_files af,
   fnd_application fa 
where
   af.app_short_name = fa.application_short_name 
   and fa.application_id = ##$$FK1$$## 
   and af.subdir not like ''admin%'' 
   and af.subdir not like ''help%'' 
   and af.subdir not like ''%driver%'' 
   and af.subdir not like ''%readme%'' 
   and substr(af.subdir, instr(af.subdir, ''/'', - 1) + 1) not in 
   (
      select
         language_code 
      from
         fnd_languages 
      where
         installed_flag <> ''B''
   )
   and af.filename not like ''%.txt'' 
   and af.filename not like ''%.a'' 
   and af.filename not like ''%.gif'' 
   and af.filename not like ''%.htm'' 
   and af.filename not like ''%.html'' 
order by
   af.filename',
      p_title                  => 'Other File Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => ' ',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: IBY_AC_OTHER_FILE_VERSIONS');



debug('begin add_signature: AC_INVALID_PLSQL_FILE_VERSIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5502',
      p_sig_id                 => 'AC_INVALID_PLSQL_FILE_VERSIONS',
      p_sig_sql                => 'select distinct o.object_name,
       substr(ltrim(rtrim(substr(substr(s.text, instr(s.text,''Header: '')),
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 1),
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2) -
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 1) ))), 1, 25) "File Name",
       substr(ltrim(rtrim(substr(substr(s.text, instr(s.text,''Header: '')),
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2),
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 3) -
                                    instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2) ))), 1, 30) "File version",
      decode(o.object_type, ''PACKAGE'' , ''SPEC'', ''PACKAGE BODY'', ''BODY'') type,
   --   o.object_type pkg_type,
      o.status status,
      b.text "Error Text", b.line
from  user_objects o , user_source s, dba_errors b
where s.name = o.object_name
and   o.object_name = b.name(+)
and   s.type = o.object_type
and   o.object_type = b.type(+)
and   o.object_type  in (''PACKAGE'' , ''PACKAGE BODY'')
and  (o.object_name like ''##$$FK2$$##\_%'' escape ''\'') 
and   s.line between 2 and 3
and   s.text like ''%Header: %''
and   o.status <> ''VALID''
order by 1, 3 desc, 5 desc',
      p_title                  => 'Invalid Package Versions',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Invalid Package versions found that may impact the application.',
      p_solution               => '<ul>
<li>NOTE: These may have no impact on your instance. These
are listed for your information.</li>
<li>Recompile the individual objects or recompile the
entire APPS schema using the adadmin utility.</li>
<li>Review any error messages provided and see [2847600/KB371943]
for details on compiling these invalid objects.</li>
</ul>',
      p_success_msg            => 'No Invalid Objects',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '23'
      );
   l_info.delete;
debug('end add_signature: AC_INVALID_PLSQL_FILE_VERSIONS');



debug('begin add_signature: IBY_AC_FILE_VERSIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11565',
      p_sig_id                 => 'IBY_AC_FILE_VERSIONS',
      p_sig_sql                => 'SELECT tl.Application_name, 
       b.application_short_name,
       b.application_id "##$$FK1$$##",
       b.product_code "##$$FK2$$##"
FROM fnd_application_tl tl, fnd_application b
WHERE b.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##, ##$$APPS_PARAM6$$##)
AND tl.application_id = b.application_id
AND tl.language = ''US''',
      p_title                  => 'File Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => ' ',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL('AC_PLSQL_FILE_VERSIONS','IBY_AC_OTHER_FILE_VERSIONS','AC_INVALID_PLSQL_FILE_VERSIONS'),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '26'
      );
   l_info.delete;
debug('end add_signature: IBY_AC_FILE_VERSIONS');



debug('begin add_signature: EBS_FIN_AP_PSADIAGNOSTICS_PSA_PACKAGES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24793',
      p_sig_id                 => 'EBS_FIN_AP_PSADIAGNOSTICS_PSA_PACKAGES',
      p_sig_sql                => '    SELECT  uo.object_type , uo.object_name, substr(us.text, (instr(us.text, ''$Header:'')+9), 
        (instr(us.text,''.pls'')+3) - (instr(us.text, ''$Header:'')+8)) "FILE NAME", 
        substr(us.text, instr(us.text,''.pls'')+4,((instr(us.text, ''/'',10)-8)-instr(us.text,''.pls''))) "Version" , uo.status
    FROM user_source us, user_objects uo          
    WHERE us.name IN (''PSA_FUNDS_CHECKER_PKG'',''PSA_AP_BC_PVT'',''PSA_BC_XLA_PVT'',''PSA_BC_XLA_PUB'',''PSA_BC_XML_REPORT_PUB'')
    AND uo.object_name IN (''PSA_FUNDS_CHECKER_PKG'',''PSA_AP_BC_PVT'',''PSA_BC_XLA_PVT'',''PSA_BC_XLA_PUB'',''PSA_BC_XML_REPORT_PUB'')
AND us.line = 2
    AND us.name = uo.object_name
        AND us.type = uo.object_type',
      p_title                  => 'PSA Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Versions of key PSA packages',
      p_solution               => '',
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
debug('end add_signature: EBS_FIN_AP_PSADIAGNOSTICS_PSA_PACKAGES');



debug('begin add_signature: EBS_FIN_AP_EBTAX_KEY_FILES_ACCOUNTING');
   l_info('##SHOW_SQL##'):= 'N';
  add_signature(
      p_sig_repo_id            => '22539',
      p_sig_id                 => 'EBS_FIN_AP_EBTAX_KEY_FILES_ACCOUNTING',
      p_sig_sql                => 'SELECT DISTINCT
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''area'') "Functional Area",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''subarea'') "Sub Area",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''type'') "File Type",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''name'') "File Name",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''version'') "Version",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''pkg_details'') "Package Details"
FROM ad_files f
WHERE f.filename IN (
  ''apgdfalb.pls'',''APXLAAAD.ldt'',''apeventb.pls'',''apevents.pls'',''APXLASET.ldt'',
  ''ap_extract_invoice_dtls_bc_v.xdf'',''ap_prepayapp_extract_dtls_bc_v.xdf'',
  ''aprfundb.pls'',''ap_invoice_extract_details_v.xdf'',
  ''ap_payment_extract_details_v.xdf'',''apacpayb.pls'',''apacrndb.pls'',
  ''appaydib.pls'',''apacpays.pls'',''apacrnds.pls'',''appaydis.pls'',
  ''ap_prepayapp_extract_details_v.xdf'',''appredib.pls'',''appredis.pls'',
  ''apopitrb.pls'',''apopitrs.pls'',''APXPOINV.xml'',''APXPOINV.rtf'',''APXPOPMT.xml'',
  ''APXPOPMT.rtf'',''appdstln.sql'',''apidstln.sql'',''apxlaupg.sql'',''apxlainv.sql'',
  ''apxlapay.sql'',''apxlaupb.pls'',''apxlaups.pls'')
ORDER BY 1,2,3,4',
      p_title                  => 'Accounting Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Key File Versions for Accounting',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_EBTAX_KEY_FILES_ACCOUNTING');



debug('begin add_signature: EBS_FIN_AP_EBTAX_KEY_FILES_INVOICES');
   l_info('##SHOW_SQL##'):= 'N';
  add_signature(
      p_sig_repo_id            => '22538',
      p_sig_id                 => 'EBS_FIN_AP_EBTAX_KEY_FILES_INVOICES',
      p_sig_sql                => 'SELECT DISTINCT
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''area'') "Functional Area",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''subarea'') "Sub Area",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''type'') "File Type",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''name'') "File Name",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''version'') "Version",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''pkg_details'') "Package Details"
FROM ad_files f
WHERE f.filename IN (
  ''apclawtb.pls'',''apdoawtb.pls'',''apiimptb.pls'',''apiimvtb.pls'',''apicancb.pls'',
  ''apaprvlb.pls'',''apinvutb.pls'',''APXINWKB.fmb'',''APXINLIN.pll'',''APXINWKB.pll'',
  ''APXPRCOR.fmb'',''APXHOLDS.fmb'',''APXHOLDS.pll'',''APXPMTCH.fmb'',''APPAYSHD.fmb'',
  ''APPAYSHD.pll'',''APPREPAY.fmb'',''APPREPAY.pll'',''APXRMTCH.fmb'',''apamopob.pls'',
  ''apamorcb.pls'',''apinvcob.pls'',''apothmtb.pls'',''apmatchb.pls'',''aprmtchb.pls'',
  ''aprcvmtb.pls'',''PcardAMImpl.class'',''PcardTxnSearchCO.class'',
  ''PcardVerifyInsertCO.class'',''apwcciib.pls'',''apwcintb.pls'',''apwpcwfb.pls'',
  ''PcardOpenTransactionsPG.xml'',''PcardTransactionVerificationPG.xml'',
  ''PcardTxnSearchPG.xml'',''appurgeb.pls'',''APXP7CFM.rdf'',''APXP7DEL.rdf'',
  ''APXP7SEL.rdf'',''apetxsrb.pls'',''apetxutb.pls'',''InvPoLineVOImpl.class'',
  ''InvPoReqNegoPGCO.class'',''NegotiationAMImpl.class'',
  ''NotificationPageAMImpl.class'',''aphanwfb.pls'',''apfhanwf.wft'')
ORDER BY 1,2,3,4',
      p_title                  => 'Invoices Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Key File Versions for Invoices',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_EBTAX_KEY_FILES_INVOICES');



debug('begin add_signature: EBS_FIN_AP_EBTAX_KEY_FILES_PAYMENT');
   l_info('##SHOW_SQL##'):= 'N';
  add_signature(
      p_sig_repo_id            => '22536',
      p_sig_id                 => 'EBS_FIN_AP_EBTAX_KEY_FILES_PAYMENT',
      p_sig_sql                => 'SELECT DISTINCT
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''area'') "Functional Area",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''subarea'') "Sub Area",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''type'') "File Type",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''name'') "File Name",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''version'') "Version",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''pkg_details'') "Package Details"
FROM ad_files f
WHERE f.filename IN (
  ''apintinb.pls'',''PsReadyToPayVO.xml'',''ap_documents_payable.xdf'',''appbselb.pls'',
  ''apcnfrmb.pls'',''APINVSEL.rdf'',''PsrAMImpl.class'',''PsrCO.class'',''ibydapib.pls'',
  ''apclawtb.pls'',''apdoawtb.pls'',''APXPAWKB.fmb'',''apayinvb.pls'',''apichecb.pls'',
  ''apvoidpb.pls'')
ORDER BY 1,2,3,4',
      p_title                  => 'Payments Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Key File Versions for Payments',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_EBTAX_KEY_FILES_PAYMENT');



debug('begin add_signature: EBS_FIN_AP_EBTAX_KEY_FILES_SUPPLIER');
   l_info('##SHOW_SQL##'):= 'N';
  add_signature(
      p_sig_repo_id            => '22537',
      p_sig_id                 => 'EBS_FIN_AP_EBTAX_KEY_FILES_SUPPLIER',
      p_sig_sql                => 'SELECT DISTINCT
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''area'') "Functional Area",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''subarea'') "Sub Area",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''type'') "File Type",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''name'') "File Name",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''version'') "Version",
  ap_gdf_detect_analyzer_pkg.get_kfile_dtl(f.filename, ''pkg_details'') "Package Details"
FROM ad_files f
WHERE f.filename IN (
  ''APXSCIMP.rdf'',''APXSUIMP.rdf'',''APXVDDUP.fmb'',''apvdmrgb.pls'',''APXINUPD.rdf'',
  ''APXSSIMP.rdf'',''appvndrb.pls'',''apvndhrb.pls'')
ORDER BY 1,2,3,4',
      p_title                  => 'Suppliers Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Key File Versions for Suppliers',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: EBS_FIN_AP_EBTAX_KEY_FILES_SUPPLIER');



debug('begin add_signature: IBY_APPSCHECK_PRODUCT_PROFILE_VALUES');
   l_info('##MASK##LEVEL VALUE'):= 'NO_MASK';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1867',
      p_sig_id                 => 'IBY_APPSCHECK_PRODUCT_PROFILE_VALUES',
      p_sig_sql                => 'SELECT user_profile_option_name "Profile Option",
             a.profile_option_value "Profile Value",
             DECODE(a.level_id, 10001, ''Site'',
                                10002, ''Application'',
                                10003, ''Responsibility'',
                                10004, ''User'') "Level",
             DECODE(a.level_id, 10001, ''Site'', 10002, b.application_short_name, 10003, c.responsibility_name, 10004, rpad(
substr(d.user_name, 1, ceil(length(d.user_name)*0.25) ),
length(d.user_name), ''*'')) "Level Value",
             c.responsibility_id
      FROM fnd_profile_option_values a,
           fnd_application b,
           fnd_responsibility_tl c,
           fnd_user d,
           fnd_profile_options e,
           fnd_profile_options_tl t
      WHERE e.application_id like ##$$FK3$$## 
        AND a.profile_option_id  = e.profile_option_id
        AND a.level_value          = b.application_id(+)
        AND a.level_value          = c.responsibility_id(+)
        AND a.level_value          = d.user_id(+)
        AND t.profile_option_name  = e.profile_option_name
        AND t.LANGUAGE             = ''US''
        AND nvl(c.LANGUAGE,''US'') = ''US''
     ORDER BY e.profile_option_name',
      p_title                  => 'Profile Values',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Profile Values',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: IBY_APPSCHECK_PRODUCT_PROFILE_VALUES');



debug('begin add_signature: AP_APPSCHECK_PROFILE_OPTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8433',
      p_sig_id                 => 'AP_APPSCHECK_PROFILE_OPTIONS',
      p_sig_sql                => 'SELECT tl.Application_name, b.application_short_name,
            b.application_id "##$$FK3$$##",
            b.product_code "##$$FK4$$##"
      FROM fnd_application_tl tl, fnd_application b
      WHERE b.application_id in (200,602,435,673,8450)
        AND tl.application_id = b.application_id
        AND tl.language = ''US''',
      p_title                  => 'Profile Options',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Profile Options',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL('IBY_APPSCHECK_PRODUCT_PROFILE_VALUES'),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '14'
      );
   l_info.delete;
debug('end add_signature: AP_APPSCHECK_PROFILE_OPTIONS');



debug('begin add_signature: AC_TABLE_INDEXES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5508',
      p_sig_id                 => 'AC_TABLE_INDEXES',
      p_sig_sql                => 'SELECT i.table_owner, i.table_name, i.index_name, i.index_type,
    TO_CHAR(i.last_analyzed, ''DD-MON-RR HH:MI:SS'') AS last_analyzed,
    CASE 
        WHEN i.status = ''UNUSABLE'' THEN ''UNUSABLE''
        WHEN i.status = ''N/A'' THEN ''N/A''
        ELSE ''VALID''
    END AS status
FROM 
    dba_indexes i
    JOIN fnd_application fa
        ON i.table_owner = fa.product_code
WHERE 
    fa.application_id IN (##$$APPS_PARAM1$$##, ##$$APPS_PARAM2$$##, ##$$APPS_PARAM3$$##, ##$$APPS_PARAM4$$##, ##$$APPS_PARAM5$$##)
ORDER BY 
    i.table_owner, i.table_name, i.index_name',
      p_title                  => 'Table Indexes',
      p_fail_condition         => 'NRS',
      p_problem_descr          => ' ',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '14'
      );
   l_info.delete;
debug('end add_signature: AC_TABLE_INDEXES');



debug('begin add_signature: AC_INVALID_TABLE_INDEXES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5510',
      p_sig_id                 => 'AC_INVALID_TABLE_INDEXES',
      p_sig_sql                => 'SELECT iu.name table_owner,
           io.name table_name,
           o.name index_name,
           decode(bitand(i.property, 16), 0, '''', ''FUNCTION-BASED '') ||
           decode(i.type#, 1, ''NORMAL''||
           decode(bitand(i.property, 4), 0, '''', 4, ''/REV''),
                      2, ''BITMAP'', 3, ''CLUSTER'', 4, ''IOT - TOP'',
                      5, ''IOT - NESTED'', 6, ''SECONDARY'', 7, ''ANSI'', 8, ''LOB'',
                      9, ''DOMAIN'') index_type,
           to_char(i.analyzetime, ''DD-MON-RR HH:MI:SS'') last_analyzed,
           decode(bitand(i.property, 2), 2, ''N/A'',
           decode(bitand(i.flags, 1), 1, ''UNUSABLE'',
           decode(bitand(i.flags, 8), 8, ''INRPOGRS'', ''VALID''))) status
    FROM sys.user$ iu,
         sys.obj$ io,
         sys.user$ u,
         sys.ind$ i,
         sys.obj$ o,
         fnd_application fa
    WHERE u.user# = o.owner#
    AND o.obj# = i.obj#
    AND i.bo# = io.obj#
    AND io.owner# = iu.user#
    AND io.type# = 2 -- tables
    AND i.type# in (1, 2, 3, 4, 6, 7, 9)
    AND fa.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
    AND iu.name = fa.application_short_name
    and (decode(bitand(i.property, 2), 2, ''N/A'',
           decode(bitand(i.flags, 1), 1, ''UNUSABLE'',
           decode(bitand(i.flags, 8), 8, ''INRPOGRS'', ''VALID'')))) not in (''VALID'',''N/A'')
    ORDER BY iu.name, io.name, o.name',
      p_title                  => 'Invalid Table Indexes',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Invalid table indexes detected.

',
      p_solution               => 'For assistance, see the following [1054736/KB179880] - How Do Indexes Become Unusable? 
',
      p_success_msg            => 'No invalid table indexes detected.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '14'
      );
   l_info.delete;
debug('end add_signature: AC_INVALID_TABLE_INDEXES');



debug('begin add_signature: AC_CUSTOM_TABLE_INDEXES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5509',
      p_sig_id                 => 'AC_CUSTOM_TABLE_INDEXES',
      p_sig_sql                => 'SELECT iu.name table_owner,
           io.name table_name,
           o.name index_name,
           decode(bitand(i.property, 16), 0, '''', ''FUNCTION-BASED '') ||
           decode(i.type#, 1, ''NORMAL''||
           decode(bitand(i.property, 4), 0, '''', 4, ''/REV''),
                      2, ''BITMAP'', 3, ''CLUSTER'', 4, ''IOT - TOP'',
                      5, ''IOT - NESTED'', 6, ''SECONDARY'', 7, ''ANSI'', 8, ''LOB'',
                      9, ''DOMAIN'') index_type,
           to_char(i.analyzetime, ''DD-MON-RR HH:MI:SS'') last_analyzed,
           decode(bitand(i.property, 2), 2, ''N/A'',
           decode(bitand(i.flags, 1), 1, ''UNUSABLE'',
           decode(bitand(i.flags, 8), 8, ''INRPOGRS'', ''VALID''))) status
    FROM sys.user$ iu,
         sys.obj$ io,
         sys.user$ u,
         sys.ind$ i,
         sys.obj$ o,
         fnd_application fa
    WHERE u.user# = o.owner#
    AND o.obj# = i.obj#
    AND i.bo# = io.obj#
    AND io.owner# = iu.user#
    AND io.type# = 2 -- tables
    AND i.type# in (1, 2, 3, 4, 6, 7, 9)
    AND fa.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
    AND iu.name = fa.application_short_name
    AND o.name like ''XX%''
    ORDER BY iu.name, io.name, o.name',
      p_title                  => 'Potential Custom Table Indexes',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Potential custom table indexes detected.

',
      p_solution               => 'Disable custom table indexes.

For assistance, see the following <a href="https://docs.oracle.com/cd/B14117_01/server.101/b10759/statements_1008.htm" target="_blank">Oracle documentation</a>',
      p_success_msg            => 'No custom table indexes detected.',
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
debug('end add_signature: AC_CUSTOM_TABLE_INDEXES');



debug('begin add_signature: EBS_FIN_AP_AC_DB_TRIGGERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '27212',
      p_sig_id                 => 'EBS_FIN_AP_AC_DB_TRIGGERS',
      p_sig_sql                => 'SELECT  atrg.table_owner, 
        atrg.table_name, 
        atrg.trigger_name, 
        atrg.trigger_type, 
        atrg.triggering_event, 
        atrg.status
FROM  all_triggers atrg, fnd_application fa
WHERE fa.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##,##$$APPS_PARAM6$$##)
AND   atrg.table_owner = fa.product_code
ORDER BY atrg.table_owner, atrg.table_name, atrg.trigger_type',
      p_title                  => 'Database Triggers',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Database triggers exist.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_AC_DB_TRIGGERS');



debug('begin add_signature: AC_DB_INFO');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6059',
      p_sig_id                 => 'AC_DB_INFO',
      p_sig_sql                => 'SELECT ''EBS Applications = ''|| release_name "Database Information" from fnd_product_groups
UNION ALL
SELECT ''EBS Platform = '' || platform_name FROM v$database
UNION ALL
select ''Database               = '' || '||mask_text(g_DBbanner, nvl( upper(''), 'NO_MASK') )||' db_version from v$version where rownum = 1
UNION ALL
SELECT ''OS Platform Version at DB server = '' || dbms_utility.port_string FROM dual
UNION ALL
SELECT parameter ||'' = ''||value FROM v$nls_parameters WHERE parameter IN (''NLS_LANGUAGE'', ''NLS_CHARACTERSET'')',
      p_title                  => 'Database Information',
      p_fail_condition         => 'RS',
      p_problem_descr          => ' Database Information.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '19'
      );
   l_info.delete;
debug('end add_signature: AC_DB_INFO');



debug('begin add_signature: AC_DB_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6060',
      p_sig_id                 => 'AC_DB_PARAMETERS',
      p_sig_sql                => 'select 
  name "Parameter Name"
, value "Currently Set Value" 
from v$parameter
where name in (
''shared_pool_size'',
''shared_pool_reserved_size'',
''large_pool_size'',
''pre_page_sga'',
''use_indirect_data_buffers'',
''nls_language'',
''nls_date_format'',
''nls_time_format'',
''nls_numeric_characters'',
''db_block_buffers'',
''db_block_checksum'',
''db_block_size'',
''db_block_lru_latches'',
''db_writer_processes'',
''db_block_max_dirty_target'',
''buffer_pool_keep'',
''buffer_pool_recycle'',
''optimizer_features_enable'',
''sort_area_size'',
''sort_area_retained_size'',
''sort_multiblock_read_count'',
''open_cursors'',
''sql_trace'',
''_optimizer_undo_changes'',
''optimizer_mode'',
''_optimizer_mode_force'',
''_sort_elimination_cost_ratio'',
''blank_trimming'',
''always_anti_join'',
''_complex_view_merging'',
''_push_join_predicate'',
''_push_join_union_view'',
''_fast_full_scan_enabled'',
''always_semi_join'',
''_ordered_nested_loop'',
''optimizer_max_permutations'',
''optimizer_index_cost_adj'',
''optimizer_index_caching'',
''query_rewrite_enabled'',
''query_rewrite_integrity'',
''_or_expand_nvl_predicate'',
''_like_with_bind_as_equality'',
''_table_scan_cost_plus_one'',
''_new_initial_join_orders'',
''utl_file_dir'',
''optimizer_percent_parallel'',
''cursor_sharing'',
''hash_join_enabled'',
''hash_area_size'',
''hash_multiblock_io_count'')
order by name',
      p_title                  => 'Database Parameters',
      p_fail_condition         => 'NRS',
      p_problem_descr          => ' Database Parameters',
      p_solution               => '',
      p_success_msg            => 'Refer to [11158187/KA1002].',
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
debug('end add_signature: AC_DB_PARAMETERS');



debug('begin add_signature: AC_APPLICATION_INSTALL_DETAILS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5505',
      p_sig_id                 => 'AC_APPLICATION_INSTALL_DETAILS',
      p_sig_sql                => 'SELECT fav.application_name app_name, 
       fav.application_short_name app_s_name, 
       decode(fpi.status, ''I'', ''Yes'', 
                          ''L'', ''Custom'',      
                          ''S'', ''Shared'', 
                          ''N'', ''No'', fpi.status) inst_status, 
       fpi.product_version, 
       nvl(fpi.patch_level, ''Not Available'') patchset, 
       fav.application_id app_id
FROM fnd_application_vl fav, fnd_product_installations fpi
WHERE fav.application_id = fpi.application_id
order by 3, 1',
      p_title                  => 'Application Installation Details',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Products installed',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: AC_APPLICATION_INSTALL_DETAILS');



debug('begin add_signature: AC_PATCHES_APPLIED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6026',
      p_sig_id                 => 'AC_PATCHES_APPLIED',
      p_sig_sql                => 'select distinct aap.patch_name
, substr(aap.patch_type, 1, 8) patch_type
,adb.language "Language",
trunc(aap.creation_date)
, ab.application_short_name
,ab.applied_flag
from ad_applied_patches aap,
ad_patch_run_bugs ab,
ad_bugs adb
where UPPER(ab.application_short_name) in (select distinct fa.application_short_name from fnd_application fa where fa.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##))
and ab.orig_bug_number = aap.patch_name
 and ab.applied_flag = ''Y''
 order by ab.application_short_name, trunc(aap.creation_date) desc',
      p_title                  => 'Patches Applied',
      p_fail_condition         => 'RS',
      p_problem_descr          => ' <p>Patches applied to your instance.&nbsp;</p>
<p>There may be duplicate patches and this is due to the start and end dates of when the patch driver was applied. This is expected behavior.</p>',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: AC_PATCHES_APPLIED');



debug('begin add_signature: EBS_FIN_AP_INV_SEQUENCES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '27408',
      p_sig_id                 => 'EBS_FIN_AP_INV_SEQUENCES',
      p_sig_sql                => 'SELECT sequence_owner "Owner",
       sequence_name "Name",
       cycle_flag "Cycle Flag", 
       last_number "Last Number",
       max_value "Max Value",
       round ((100 / max_value) * last_number, 2) AS "% Used",
       round (100 - ((100 / max_value) * last_number), 2) AS "% Available"
  FROM dba_sequences
 WHERE cycle_flag = ''N'' 
 and max_value > 0
and  sequence_owner IN (''AP'', ''PO'', ''APPLSYS'', ''ISP'', ''IBY'',''ZX'',''CE'', ''XTR'', ''XLA'', ''ECC'', ''FUN'', ''PSA'', ''FV'') AND 
 round ((100 / max_value) * last_number, 2) >= 70
 ORDER BY 5 DESC, 3,2',
      p_title                  => 'Sequences nearing Max Values',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Sequences are getting close (=>70%) to their Max Value.


',
      p_solution               => 'Please ensure you address this as soon as possible by following these steps:<br>

<ul>
<li>Review [2989870/KA1025] - Managing Sequences in Oracle E-Business Suite Release 12.2.</li>
<li>Apply patch {36119960} that includes sequence check scripts to assist EBS Apps DBAs with EBS 12.2 sequence management.</li>
<li>Read the <a href=“https://blogs.oracle.com/ebstech/post/ebs-122-maintenance-guidance-for-sequences”>blog post</a> on this topic.</li>
</ul>
For assistance with this please ensure to raise a new SR under product “Oracle E-Business Suite Technology Stack".',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: EBS_FIN_AP_INV_SEQUENCES');



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
            p_invoice_id                   IN NUMBER      DEFAULT NULL
           ,p_max_output_rows              IN NUMBER      DEFAULT 20
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

  analyzer_title := 'PSA Data Validation Analyzer';
  analyzer_title := regexp_replace('EBS ' || analyzer_title, '(\S+\s)\1', '\1', 1, 0, 'i');  -- EBSAF-243

  l_step := '15';
   validate_parameters(
     p_invoice_id                   => p_invoice_id
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

debug('begin section: SETUP_DATA');
start_section('Setup Details', 'SETUP_DATA');
   set_item_result(run_stored_sig('PSA_BUD_CTRL_OPTIONS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_PSA_LEDGER_CONTROLS_CHECK'));
   set_item_result(run_stored_sig('PSA_BUD_CTRL_ENABLED_JLD'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_LEDGER_ACCT'));
   set_item_result(run_stored_sig('PSA_LEDGER_DEFINITIONS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_AAD_SLAM'));
   set_item_result(run_stored_sig('PSA_AAD_DEFINITIONS'));
   set_item_result(run_stored_sig('PSA_GEN_INVALID_AAD'));
   set_item_result(run_stored_sig('PSA_CUSTOM_JLT'));
end_section;
debug('end section: SETUP_DATA');

debug('begin section: SETUP_VALIDATION');
DECLARE
  l_result VARCHAR2(1);
  l_ledger_bud_ctrl BOOLEAN := true;
  l_jld_bud_ctrl    BOOLEAN := true;
  l_bud_exists      BOOLEAN := true;
  l_bc_prof_opt     VARCHAR(240);

BEGIN
  debug('begin section: SETUP_VALIDATION');
  start_section('Setup Validation');

  set_item_result(run_stored_sig('PSA_SETUP_UPG_DATE_SET'));

  IF g_upg_date_set THEN 
    BEGIN
      l_bc_prof_opt := fnd_profile.value('BUDGETARY_CONTROL_OPTION');
    EXCEPTION WHEN OTHERS THEN
      l_bc_prof_opt := null;
      debug('Error getting value for BUDGETARY_CONTROL_OPTION: '||sqlerrm);
    END;



    l_result := run_stored_sig('PSA_SETUP_LEDGER_BUD_CTRL');
    set_item_result(l_result);
    IF l_result != 'S' THEN
      l_ledger_bud_ctrl := false;
    END IF;


    l_result := run_stored_sig('PSA_SETUP_BUDGET');
    set_item_result(l_result);
    IF l_result = 'S' THEN
    -- Check that budget control options exist
      l_result := run_stored_sig('PSA_SETUP_BC_OPTIONS_EXIST');
      set_item_result(l_result);
      IF l_result = 'S' THEN
      -- Get the budget org funds check level
        -- Warn if advisory level
        l_result := run_stored_sig('PSA_SETUP_BUD_FCHK_LVL_ADV');
        set_item_result(l_result);
        IF l_result = 'S' THEN
          -- Fail if neither absolute or advisory level
          set_item_result(run_stored_sig('PSA_SETUP_BUD_FCHK_LVL_NONE'));
        END IF;
      END IF;
    END IF;


    l_result := run_stored_sig('PSA_SETUP_JLD_BUD_CTRL');
    set_item_result(l_result);
    IF l_result != 'S' THEN
      l_jld_bud_ctrl := false;
    END IF;

    set_item_result(run_stored_sig('PSA_SETUP_BC_OPTION'));

  END IF; -- upgrade date set
  end_section;
  debug('end section: SETUP_VALIDATION');

END;
debug('end section: SETUP_VALIDATION');

debug('begin section: INV_DATA_VALIDATION');
start_section('Invoice Data Validation', 'INV_DATA_VALIDATION');
   set_item_result(run_stored_sig('PSA_INV_ORPHAN_BC_EVENTS'));
   set_item_result(run_stored_sig('PSA_INV_ORPHAN_PROCESSED_BC_EVENTS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_ORPHAN_AP_PREPAY_APP_DISTS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_BC_EVENT'));
   set_item_result(run_stored_sig('PSA_INV_UNENC_DIST_WITH_PROCESSED_EVENT'));
   set_item_result(run_stored_sig('PSA_INV_ENC_DIST_UNPROC_EVENT'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_REV_BC_EVENTS'));
   set_item_result(run_stored_sig('PSA_INV_REV_ENC_PARENT_UNENC'));
   set_item_result(run_stored_sig('PSA_INV_PARENT_ENC_REV_UNENC'));
   set_item_result(run_stored_sig('PSA_GEN_INVALID_PO_EVENTS'));
   set_item_result(run_stored_sig('PSA_INV_PARENT_REVERSAL_LINES'));
   set_item_result(run_stored_sig('PRC_SIG21_PO_AP_QV_Copy'));
   set_item_result(run_stored_sig('PSA_INV_HOLDS'));
   set_item_result(run_stored_sig('PSA_INV_FUNDS_AVAILABLE_INFO_AP'));
   set_item_result(run_stored_sig('PRC_PSA_XLA_ACCOUNTING_ERRORS_COPY'));
   set_item_result(run_stored_sig('PSA_BC_ACCOUNTING_ERRORS'));
   set_item_result(run_stored_sig('PSA_INV_SLA_ERRORS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_TOLERANCE_TEMPS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_BC_PACKETS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_BUDGET_ASSIGNMENTS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_BUDGET_OPTIONS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_SUMMARY_TEMPLATE'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_SUMM_TEMP_BC_OPTION'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_CODE_COMBINATIONS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_BALANCE_ENC_ACT'));
   set_item_result(run_stored_sig('PSA_INV_PO_ENC_NOT_RELIEVED'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_UNENC_PREP'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_UNENC_PO_MATCHED'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_NOT_MATCHED'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_CANT_FUNDS_CHECK'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PREP_NOT_MATCHED'));
end_section;
debug('end section: INV_DATA_VALIDATION');

debug('begin section: APList_COPY');
IF p_invoice_id is not null THEN
   start_section('Invoice Data Collection', 'APList_COPY');
      set_item_result(run_stored_sig('APLIST_10_AP_SYSTEM_PARAMETERS_ALL'));
      set_item_result(run_stored_sig('APLIST_20_FINANCIALS_SYSTEM_PARAMS_ALL'));
      set_item_result(run_stored_sig('APLIST_30_HR_OPERATING_UNITS'));
      set_item_result(run_stored_sig('APLIST_40_GL_LEDGERS'));
      set_item_result(run_stored_sig('APLIST_80_GL_LEDGER_CONFIG_DETAILS'));
      set_item_result(run_stored_sig('APLIST_90_GL_LEDGER_RELATIONSHIPS'));
      set_item_result(run_stored_sig('APLIST_100_GL_LEGAL_ENTITIES_BSVS'));
      set_item_result(run_stored_sig('APLIST_110_GL_LEDGER_NORM_SEG_VALS'));
      set_item_result(run_stored_sig('APLIST_260_AP_BATCHES_ALL'));
      set_item_result(run_stored_sig('APLIST_70_XLA_SUBLEDGERS2'));
      set_item_result(run_stored_sig('APLIST_150_AP_INVOICES_ALL_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_170_AP_INVOICE_LINES_ALL_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_170_AP_INVOICE_DISTS_ALL_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_190_AP_HOLDS_ALL_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_270_AP_INVOICES_ALL_INVS'));
      set_item_result(run_stored_sig('APLIST_290_AP_INVOICE_LINES_ALL'));
      set_item_result(run_stored_sig('APLIST_300_AP_INVOICE_DISTRIBUTIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_390_AP_HOLDS_ALL'));
      set_item_result(run_stored_sig('APLIST_400_AP_HOLD_CODES'));
      set_item_result(run_stored_sig('APLIST_320_AP_INVOICE_DISTS_ARCH'));
      set_item_result(run_stored_sig('APLIST_430_AP_INVOICE_PREPAYS_ALL'));
      set_item_result(run_stored_sig('APLIST_440_AP_CHRG_ALLOCATIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_340_ZX_LINES_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_450_AP_INV_APRVL_HIST_ALL'));
      set_item_result(run_stored_sig('APLIST_330_ZX_LINES'));
      set_item_result(run_stored_sig('APLIST_250_ZX_REC_NREC_DIST'));
      set_item_result(run_stored_sig('APLIST_360_ZX_LINES_DET_FACTORS'));
      set_item_result(run_stored_sig('APLIST_120_XLE_ENTITY_PROFILES'));
      set_item_result(run_stored_sig('APLIST_130_FND_PRODUCT_INSTALLATIONS'));
      set_item_result(run_stored_sig('APLIST_140_FND_PRODUCT_GROUPS'));
      set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_TOLERANCE_TEMPS'));
      set_item_result(run_stored_sig('APLIST_180_AP_PAYMENT_SCHED_ALL_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_200_AP_DOCUMENTS_PAYABLE_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_210_AP_INVOICE_PAYMENTS_ALL _SUMMARY'));
      set_item_result(run_stored_sig('APLIST_220_AP_CHECKS_ALL _SUMMARY'));
      set_item_result(run_stored_sig('APLIST_230_AP_PAYMENT_HISTORY_ALL_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_240_AP_SELECTED_INVOICES_ALL_SUMMARY2'));
      set_item_result(run_stored_sig('APLIST_250_AP_SELECTED_INVOICE_CHECKS_SUMMARY'));
      set_item_result(run_stored_sig('APLIST_370_AP_PAYMENT_SCHEDULES_ALL'));
      set_item_result(run_stored_sig('APLIST_380_AP_RECURRING_PAYMENTS_ALL'));
      set_item_result(run_stored_sig('APLIST_410_AP_TERMS'));
      set_item_result(run_stored_sig('APLIST_420_AP_TERMS_LINES'));
      set_item_result(run_stored_sig('APLIST_460_AP_ALLOCATION_RULES'));
      set_item_result(run_stored_sig('APLIST_470_AP_ALLOCATION_RULE_LINES'));
      set_item_result(run_stored_sig('APLIST_480_AP_SELF_ASSESSED_TAX_DIST_ALL'));
      set_item_result(run_stored_sig('APLIST_490_AP_INVOICE_RELATIONSHIPS'));
      set_item_result(run_stored_sig('APLIST_500_AP_DOCUMENTS_PAYABLE'));
      set_item_result(run_stored_sig('APLIST_510_AP_INVOICE_PAYMENTS_ALL'));
      set_item_result(run_stored_sig('APLIST_530_AP_CHECKS_ALL'));
      set_item_result(run_stored_sig('APLIST_540_AP_PAYMENT_DISTRIBUTIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_550_AP_PAYMENT_HISTORY_ALL'));
      set_item_result(run_stored_sig('APLIST_560_AP_PAYMENT_HIST_DISTS'));
      set_item_result(run_stored_sig('APLIST_580_AP_INV_SELECTION_CRITERIA_ALL'));
      set_item_result(run_stored_sig('APLIST_590_AP_SELECTED_INVOICES_ALL'));
      set_item_result(run_stored_sig('APLIST_600_AP_SELECTED_INVOICE_CHECKS_ALL'));
      set_item_result(run_stored_sig('APLIST_610_IBY_DOCS_PAYABLE_ALL'));
      set_item_result(run_stored_sig('APLIST_620_IBY_PAYMENTS_ALL'));
      set_item_result(run_stored_sig('APLIST_630_IBY_PAY_INSTRUCTIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_640_AP_RECON_DISTRIBUTIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_650_AP_AWT_TAX_RATES_ALL'));
      set_item_result(run_stored_sig('APLIST_660_AP_TAX_CODES_ALL'));
      set_item_result(run_stored_sig('APLIST_670_AP_AWT_GROUPS'));
      set_item_result(run_stored_sig('APLIST_680_AP_AWT_GROUP_TAXES_ALL'));
      set_item_result(run_stored_sig('APLIST_690_AP_AWT_TEMP_DISTRIBUTIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_750_XLA_EVENTS'));
      set_item_result(run_stored_sig('APLIST_760_XLA_AE_HEADERS'));
      set_item_result(run_stored_sig('APLIST_770_XLA_AE_LINES'));
      set_item_result(run_stored_sig('APLIST_780_XLA_DISTRIBUTION_LINKS'));
      set_item_result(run_stored_sig('APLIST_790_XLA_TRANSACTION_ENTITIES'));
      set_item_result(run_stored_sig('APLIST_800_XLA_ACCOUNTING_ERRORS'));
      set_item_result(run_stored_sig('APLIST_810_XLA_EVENTS'));
      set_item_result(run_stored_sig('APLIST_820_XLA_AE_HEADERS'));
      set_item_result(run_stored_sig('APLIST_830_XLA_AE_LINES'));
      set_item_result(run_stored_sig('APLIST_840_XLA_DISTRIBUTION_LINKS'));
      set_item_result(run_stored_sig('APLIST_850_XLA_TRANSACTION_ENTITIES'));
      set_item_result(run_stored_sig('APLIST_860_XLA_ACCOUNTING_ERRORS'));
      set_item_result(run_stored_sig('APLIST_870_AP_LIABILITY_BALANCE'));
      set_item_result(run_stored_sig('APLIST_880_XLA_TRIAL_BALANCES'));
      set_item_result(run_stored_sig('APLIST_900_AX_EVENTS'));
      set_item_result(run_stored_sig('APLIST_910_AX_SLE_HEADERS'));
      set_item_result(run_stored_sig('APLIST_920_AX_SLE_LINES'));
      set_item_result(run_stored_sig('APLIST_930_AX_DOCUMENT_STATUSES'));
      set_item_result(run_stored_sig('APLIST_940_AX_EVENTS'));
      set_item_result(run_stored_sig('APLIST_950_AX_SLE_HEADERS'));
      set_item_result(run_stored_sig('APLIST_960_AX_SLE_LINES'));
      set_item_result(run_stored_sig('APLIST_970_AX_DOCUMENT_STATUSES'));
      set_item_result(run_stored_sig('APLIST_980_AP_ACCOUNTING_EVENTS_ALL'));
      set_item_result(run_stored_sig('APLIST_990_AP_AE_HEADERS_ALL'));
      set_item_result(run_stored_sig('APLIST_1000_AP_AE_LINES_ALL'));
      set_item_result(run_stored_sig('APLIST_1010_AP_ENCUMBRANCE_LINES_ALL'));
      set_item_result(run_stored_sig('APLIST_1020_AP_ACCOUNTING_EVENTS_ALL'));
      set_item_result(run_stored_sig('APLIST_1030_AP_AE_HEADERS_ALL'));
      set_item_result(run_stored_sig('APLIST_1040_AP_AE_LINES_ALL'));
      set_item_result(run_stored_sig('APLIST_1050_AP_UNDO_EVENT_LOG'));
      set_item_result(run_stored_sig('APLIST_1060_UNDO_ORIG_XLA_EVENTS'));
      set_item_result(run_stored_sig('APLIST_1070_UNDO_ORIG_XLA_AE_HEADERS'));
      set_item_result(run_stored_sig('APLIST_1080_UNDO_ORIG_XLA_AE_LINES'));
      set_item_result(run_stored_sig('APLIST_1090_UDO_ORIG_XDL'));
      set_item_result(run_stored_sig('APLIST_1100_UNDO_REV_XLA_EVENTS'));
      set_item_result(run_stored_sig('APLIST_1110_UNDO_REV_XLA_AE_HEADERS'));
      set_item_result(run_stored_sig('APLIST_1120_UNDO_REV_XLA_AE_LINES'));
      set_item_result(run_stored_sig('APLIST_1130_UNDO_REV_XDL'));
      set_item_result(run_stored_sig('APLIST_1140_GL_JE_BATCHES'));
      set_item_result(run_stored_sig('APLIST_1150_GL_JE_HEADERS'));
      set_item_result(run_stored_sig('APLIST_1160_GL_JE_LINES'));
      set_item_result(run_stored_sig('APLIST_1170_GL_IMPORT_REFERENCES'));
      set_item_result(run_stored_sig('APLIST_1180_GL_JE_BATCHES'));
      set_item_result(run_stored_sig('APLIST_1190_GL_JE_HEADERS'));
      set_item_result(run_stored_sig('APLIST_1200_GL_JE_LINES'));
      set_item_result(run_stored_sig('APLIST_1210_GL_IMPORT_REFERENCES'));
      set_item_result(run_stored_sig('APLIST_1220_GL_PERIOD_STATUSES'));
      set_item_result(run_stored_sig('APLIST_1230_GL_CODE_COMBINATIONS'));
      set_item_result(run_stored_sig('APLIST_1240_AP_MC_INVOICES'));
      set_item_result(run_stored_sig('APLIST_1250_AP_MC_INVOICES'));
      set_item_result(run_stored_sig('APLIST_1260_AP_MC_CHECKS'));
      set_item_result(run_stored_sig('APLIST_1270_AP_MC_INVOICE_DISTS'));
      set_item_result(run_stored_sig('APLIST_1280_AP_MC_INVOICE_PAYMENTS'));
      set_item_result(run_stored_sig('APLIST_1300_AP_MC_PAYMENT_HISTORY'));
      set_item_result(run_stored_sig('APLIST_1310_AP_SUPPLIERS'));
      set_item_result(run_stored_sig('APLIST_1320_PO_VENDORS_OBS'));
      set_item_result(run_stored_sig('APLIST_1330_PO_VENDOR_SITES_OBS'));
      set_item_result(run_stored_sig('APLIST_1340_AP_SUPPLIER_SITES_ALL'));
      set_item_result(run_stored_sig('APLIST_1350_HZ_PARTIES'));
      set_item_result(run_stored_sig('APLIST_1360_HZ_PARTY_SITES'));
      set_item_result(run_stored_sig('APLIST_1370_IBY_EXTERNAL_PAYEES_ALL'));
      set_item_result(run_stored_sig('APLIST_1380_IBY_ACCOUNT_OWNERS'));
      set_item_result(run_stored_sig('APLIST_1390_IBY_PMT_INSTR_USES_ALL'));
      set_item_result(run_stored_sig('APLIST_1400_IBY_EXT_BANK_ACCOUNTS'));
      set_item_result(run_stored_sig('APLIST_1410_PO_HEADERS_ALL'));
      set_item_result(run_stored_sig('APLIST_1420_PO_DISTRIBUTIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_1430_PO_LINES_ALL'));
      set_item_result(run_stored_sig('APLIST_1440_PO_LINE_LOCATIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_1450_PO_MC_HEADERS'));
      set_item_result(run_stored_sig('APLIST_1460_PO_MC_DISTRIBUTIONS'));
      set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_BC_PACKETS'));
      set_item_result(run_stored_sig('APLIST_1480_AP_PREPAY_HISTORY_ALL'));
      set_item_result(run_stored_sig('APLIST_1490_AP_PREPAY_APP_DISTS'));
      set_item_result(run_stored_sig('APLIST_1500_APPLIED_TO'));
      set_item_result(run_stored_sig('APLIST_1510_APPLIED_TO2'));
      set_item_result(run_stored_sig('APLIST_1520_AP_BANK_BRANCHES'));
      set_item_result(run_stored_sig('APLIST_1530_AP_BANK_ACCOUNTS_ALL'));
      set_item_result(run_stored_sig('APLIST_1540_AP_CHECK_STOCKS_ALL'));
      set_item_result(run_stored_sig('APLIST_1550_AP_CHECK_FORMATS'));
      set_item_result(run_stored_sig('APLIST_1560_AP_PAYMENT_PROGRAMS'));
      set_item_result(run_stored_sig('APLIST_1570_HZ_BANK_INFO'));
      set_item_result(run_stored_sig('APLIST_1580_HZ_BRANCH_INFO'));
      set_item_result(run_stored_sig('APLIST_1590_CE_BANK_ACCOUNTS'));
      set_item_result(run_stored_sig('APLIST_1600_CE_BANK_ACCT_USES_ALL'));
      set_item_result(run_stored_sig('APLIST_1610_CE_GL_ACCOUNTS_CCID'));
      set_item_result(run_stored_sig('APLIST_1620_CE_STATEMENT_RECONCILS_ALL'));
      set_item_result(run_stored_sig('APLIST_1630_CE_STATEMENT_HEADERS'));
      set_item_result(run_stored_sig('APLIST_1640_CE_STATEMENT_LINES'));
      set_item_result(run_stored_sig('APLIST_1650_AP_EXPENSE_REPORT_HEADERS_ALL'));
      set_item_result(run_stored_sig('APLIST_1660_AP_EXPENSE_REPORT_LINES_ALL'));
      set_item_result(run_stored_sig('APLIST_1670_AP_EXPENSE_REPORT_DISTS_ALL'));
      set_item_result(run_stored_sig('APLIST_1680_FV_TREASURY_CONFIRMATIONS_ALL'));
      set_item_result(run_stored_sig('APLIST_1690_FND_CURRENCIES'));
      set_item_result(run_stored_sig('EBS_FIN_AP_AP_LIST_PAYMENT_METHOD'));
      set_item_result(run_stored_sig('EBS_FIN_AP_PM_IBY_VAL_ASSIGNMENTS'));
      set_item_result(run_stored_sig('EBS_FIN_AP_IBY_VALIDATION_SETS'));
      set_item_result(run_stored_sig('EBS_FIN_AP_IBY_VALIDATION_VALUES'));
   end_section;
END IF;
debug('end section: APList_COPY');

debug('begin section: Apps_Check');
start_section('Apps Check', 'Apps_Check');
   set_item_result(run_stored_sig('IBY_AC_FILE_VERSIONS'));
   set_item_result(run_stored_sig('EBS_FIN_AP_PSADIAGNOSTICS_PSA_PACKAGES'));
   set_item_result(run_stored_sig('EBS_FIN_AP_EBTAX_KEY_FILES_ACCOUNTING'));
   set_item_result(run_stored_sig('EBS_FIN_AP_EBTAX_KEY_FILES_INVOICES'));
   set_item_result(run_stored_sig('EBS_FIN_AP_EBTAX_KEY_FILES_PAYMENT'));
   set_item_result(run_stored_sig('EBS_FIN_AP_EBTAX_KEY_FILES_SUPPLIER'));
   set_item_result(run_stored_sig('AP_APPSCHECK_PROFILE_OPTIONS'));
   set_item_result(run_stored_sig('AC_TABLE_INDEXES'));
   set_item_result(run_stored_sig('AC_INVALID_TABLE_INDEXES'));
   set_item_result(run_stored_sig('AC_CUSTOM_TABLE_INDEXES'));
   set_item_result(run_stored_sig('EBS_FIN_AP_AC_DB_TRIGGERS'));
   set_item_result(run_stored_sig('AC_DB_INFO'));
   set_item_result(run_stored_sig('AC_DB_PARAMETERS'));
   set_item_result(run_stored_sig('AC_APPLICATION_INSTALL_DETAILS'));
   set_item_result(run_stored_sig('AC_PATCHES_APPLIED'));
end_section;
debug('end section: Apps_Check');

debug('begin section: Proactive_Recommendations');
IF (
(substr(g_rep_info('Apps Version'),1,4) = '12.0') 
OR 
(substr(g_rep_info('Apps Version'),1,4) = '12.1')
OR
(substr(g_rep_info('Apps Version'),1,4) = '12.2')
) THEN
   start_section('Proactive Recommendations', 'Proactive_Recommendations');
      set_item_result(check_rec_patches_1); /* Signature PSA_REC_PATCH */
      set_item_result(check_rec_patches_2); /* Signature PSA_RELATED_REC_PATCHES */
      set_item_result(check_rec_patches_3); /* Signature AP_RPC_PATCHES */
      set_item_result(check_rec_patches_4); /* Signature AP_RUP_PATCHES */
      set_item_result(check_rec_patches_5); /* Signature EBTAX_check_rec_patches */
      set_item_result(run_stored_sig('EBS_FIN_AP_INV_SEQUENCES'));
   end_section;
END IF;
debug('end section: Proactive_Recommendations');

debug('begin section: CriticalAlerts');
start_section('Critical Alerts', 'CriticalAlerts');
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
debug('end section: CriticalAlerts');



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
           ,p_invoice_id                   IN NUMBER      DEFAULT NULL
           ,p_max_output_rows              IN NUMBER      DEFAULT 20
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y'
)
 IS

BEGIN
  g_retcode := 0;
  g_errbuf := null;

   main(
     p_invoice_id                   => p_invoice_id
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );


  retcode := g_retcode;
  errbuf  := g_errbuf;
EXCEPTION WHEN OTHERS THEN
  retcode := '2';
  errbuf := 'Error in main_cp: '||sqlerrm||' : '||g_errbuf;
END main_cp;


END psa_data_analyzer_pkg;
/
show errors
exit;
-- Exit required for bundling project so do not remove
