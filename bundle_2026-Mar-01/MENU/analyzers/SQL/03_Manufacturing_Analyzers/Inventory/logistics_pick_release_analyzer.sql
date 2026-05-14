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
REM |    logistics_pick_release_analyzer.sql                                    |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    SQL to install package used for Logistics Pick Release Analyzer        |
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


CREATE OR REPLACE PACKAGE logistic_pick_rel_analyzer_pkg AUTHID DEFINER AS

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
(            p_diag_type                    IN VARCHAR2    DEFAULT NULL
           ,p_batch_id                     IN NUMBER      DEFAULT NULL
           ,p_header_id                    IN NUMBER      DEFAULT NULL
           ,p_so_line_id                   IN NUMBER      DEFAULT NULL
           ,p_wip_entity_id                IN NUMBER      DEFAULT NULL
           ,p_print_appscheck              IN VARCHAR2    DEFAULT 'Y'
           ,p_max_output_rows              IN NUMBER      DEFAULT 20
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y')
;


PROCEDURE main_cp (
            errbuf                         OUT VARCHAR2
           ,retcode                        OUT VARCHAR2
           ,p_diag_type                    IN VARCHAR2    DEFAULT NULL
           ,p_batch_id                     IN NUMBER      DEFAULT NULL
           ,p_header_id                    IN NUMBER      DEFAULT NULL
           ,p_so_line_id                   IN NUMBER      DEFAULT NULL
           ,p_wip_entity_id                IN NUMBER      DEFAULT NULL
           ,p_print_appscheck              IN VARCHAR2    DEFAULT 'Y'
           ,p_max_output_rows              IN NUMBER      DEFAULT 20
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y'
);

----------------------------------------------------------------
-- Analyzer-specific code: Function and Procedures (Spec)     --
----------------------------------------------------------------
Function GET_OH_AVAIL(
p_inv_item_id in varchar2,
p_org_id number,
p_subinv_code varchar2,
p_locator_id   NUMBER,
p_lot_number varchar2,
p_LPN_ID  NUMBER,
p_qty_type VARCHAR2
)
return number;


-- Line_Shipment_Option from OEXOELIN.pll
FUNCTION line_shipment_option(
  line_number      IN NUMBER,
  shipment_number  IN NUMBER,
  option_number    IN NUMBER,
  component_number IN NUMBER,
  service_number   IN NUMBER
)
RETURN VARCHAR2;


END logistic_pick_rel_analyzer_pkg;
/
show errors


CREATE OR REPLACE PACKAGE BODY logistic_pick_rel_analyzer_pkg AS
-- $Id: logistics_pick_release_analyzer.sql, 200.29 2026/02/23 18:17:40 jjanaiti Exp $

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
g_analyzer_doc_id VARCHAR2(15) := TO_CHAR(TRUNC(2349700.1));
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
-- Accommodations for 19C DB
g_db_version          V$INSTANCE.VERSION%TYPE;
g_DBbanner            VARCHAR2(255);

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

    l_log_file := 'LOGPR_Analyzer_'||l_db_name||'_'||g_params_string||l_date_char||'.log';
    l_out_file := 'LOGPR_Analyzer_'||l_db_name||'_'||g_params_string||l_date_char||'.html';
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
    print_out('<TITLE>LOGPR Analyzer Report</TITLE>');

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
        $("div#feedback").find("a.blacklink").attr("href", "https://mosemp.us.oracle.com/epmos/faces/DocumentDisplay?id=2349700.1#feedback");

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
        <img class="header_version" src="https://www.oracle.com/webfolder/s/analyzer/log_pick_rel_latest_version.gif" title="Click here to download the latest version of Analyzer" alt="Latest Version Icon"></a>');
    print_cloud_image;
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,1474,EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="thumb_up_lg" title="Analyzer Feedback: Thumbs Up"></span></a>');
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,1474,EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="thumb_dn_lg" title="Analyzer Feedback: Thumbs Down"></span></a>');
    print_out('<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},1474,EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="af_idea_lg" title="Analyzer Idea"></span></a>');
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
    print_out('<div class="menubutton" id="feedback" title="Opens the Oracle Community feedback thread"><a href="https://community.oracle.com/thread/4113819" class="blacklink" target="new">
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
        <span id="feedback-azr">1474</span>
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
<div class="ck-content"><p>Version 200.29 23-FEB-2026</p><p>&nbsp; &nbsp; &nbsp;Signature updates</p><p>&nbsp;</p><p>Version 200.28 29-JAN-2026</p><p>&nbsp; &nbsp; &nbsp;Updated link format</p><p>&nbsp;</p><p>Version 200.27 05-DEC-2025</p><p>&nbsp; &nbsp; &nbsp;Signature updates</p><p>&nbsp;</p><p>Version 200.26 18-AUG-2025</p><p>&nbsp; &nbsp; &nbsp;Added signature ‘Key Current Warehouse Parameters’<br>
&nbsp; &nbsp; &nbsp;Signature updates</p><p>&nbsp;</p><p>Version 200.25 04-MAR-2025</p><p>&nbsp; &nbsp; &nbsp;Signature updates</p><p>&nbsp; &nbsp; &nbsp;Framework updates</p><p>&nbsp;</p><p>Version 200.24 27-NOV-2024</p><p>&nbsp;&nbsp;&nbsp;&nbsp; Signature updates</p><p>&nbsp;</p><p>Version 200.23 26-SEP-2024</p><p>&nbsp;&nbsp;&nbsp;&nbsp; Signature updates</p><p>&nbsp;</p><p>Version 200.22 17-JUL-2024</p><p>&nbsp;&nbsp;&nbsp;&nbsp; Added signature &apos;<span class="display_only apex-item-display-only" id="P18_TITLE_DISPLAY">Virtual Private Database Policies&apos;</span></p><p>&nbsp;</p><p>Version 200.21 21-May-2024</p><p>&nbsp;&nbsp;&nbsp;&nbsp; Added new section &apos;Pick Selection Criteria Mismatches&apos;</p><p>&nbsp;</p><p>Version 200.20 10-APR-2024</p><p>&nbsp; &nbsp; Rename “Lifetime Support Policy” with “Critical Alerts”<br>
&nbsp; &nbsp; Add 2 signatures</p><p>&nbsp; &nbsp; EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX<br>
&nbsp; &nbsp; EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE</p><p>&nbsp;</p><p>Version 200.19 26-JAN-2024</p><ul><li>Signature updates</li>
</ul>
<p>&nbsp;</p><p>Version 200.18 02-JAN-2024</p><ul><li>Signature updates</li>
</ul>
<p>&nbsp;</p><p>Version 200.17 28-NOV-2023</p><ul><li>Sales Order Line(s) Information, LOGPR_ORDER_LINES, Reserved Qty removed, Subinventory removed.</li>
<li>Shipping Parameters, ONT_SHIPPING_PARAMETERS, Default Stage Locator added</li>
<li>ONT WSH QP INV PO WMS BOM Sequences, EBS_MFG_GEN_ONT_WSH_INV_SEQUENCES, BOM Sequences added and now checks at 70% instead of 90%.</li>
</ul>
<p>Version 200.16 26-OCT-2023</p><ul><li>Modified several informational signatures to always print.</li>
</ul>
<p>Version 200.15 22-AUG-2023</p><ul><li>Added signature ‘Move Order Was Created but There Is No Pick Task for the Item’</li>
<li>Framework updates</li>
</ul>
<p>Version 200.14 26-JUN-2023<br>
- Modified Open Shipping Exceptions, LOGPR_HOUSEKEEPING_EXCEPTIONS, to only display when Count is greater than 0</p><p>Version 200.13 25-MAY-2023<br>
-Added signatures AC_DB_INFO, LANGUAGES_INSTALLED_DETAILS<br>
-Signature updates</p><p>Version 200.12 28-MAR-2023</p><ul><li>WSH Pick Release Criteria Mismatch - Include Assigned Lines, LOGPR_CRITERIA_INCLUDE_PLANNED_LINES, signature name changed to: WSH Pick Release Criteria Mismatch - Include Assigned Lines and warning message changed to: Pick Release Criteria does not Include Assigned Lines but there exists delivery details already assigned to a delivery</li>
</ul>
<p>200.11 10-FEB-2023</p><ul><li>signature updates</li>
</ul>
<p>Version 200.10 10-FEB-2023</p><ul><li>Added signature EBS_MFG_GEN_ONT_WSH_INV_SEQUENCES</li>
<li>Template Changes (4.5.9.1): Bug Fixes, Minor Enhancements</li>
</ul>
<p>Version 200.9</p><ul><li>Signature updates</li>
<li>Framework update</li>
</ul>
<p>Version 200.8</p><p>Template Changes (4.5.8):&nbsp;<br>
&nbsp; &nbsp; &nbsp;- EBSAF-345 Add Copy SQL button via framework<br>
Added EBS_MFG_INV_LOGPR_WSH_TRANS_MOQD_SECONDARY_ZERO, No Secondary Controls, added under Order Management and Shipping tile. &nbsp;Issue detailed in Doc ID 2724982.1.<br>
SALES_ORDER_MTL_RESERVATIONS updated.<br>
SALES_ORDER_LINE_MTL_SYSTEM_ITEMS updated.&nbsp;<br>
INV_RUP_CHECK2_SQL_AD_BUGS updated with current RU<br>
LOGPR_CORRUPTION_OPEN_DD_CLOSED_LINE signature was returning all Deliveries, corrected where clause to only return ones for the specified order/line.<br>
LOGPR_CORRUPTION_OPEN_DD_CLOSED_LINE now refers to 2346819.1.<br>
Removed LOGPR_CRITERIA_SHIP_FROM_LOC_MISMATCH., it was a duplicate of LOGPR_CRITERIA_SHIP_METHOD.</p><p>&nbsp;</p><p>Version 200.7</p><p>Signature updates</p><p>&nbsp;</p><p>Version 200.6</p><ul><li>Signatures</li>
</ul>
<p>LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_CLOSED<br>
LOGPR_SO_WSH_DELIVERY_DETAILS</p></div>

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
            '1474'
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
            '1474'
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
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,1474,'||l_sig.sigrepo_id||',EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="thumb_up" title="Signature Feedback: Thumbs Up"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,1474,'||l_sig.sigrepo_id||',EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="thumb_dn" title="Signature Feedback: Thumbs Down"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_SIGNATURE_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},1474,'||l_sig.sigrepo_id||',EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="af_idea" title="Signature Idea"></span></a>
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
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},up,Analyzer,1474,'||p_sig.sigrepo_id||',EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="thumb_up" title="Signature Feedback: Thumbs Up"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:17::::11,RIR,RP:P17_SR_NUMBER,P17_THUMB,P17_TYPE,P17_ANALYZER_ID,P17_SIGNATURE_ID,P17_PLA_LINE,P17_PLA_FAMILY,P17_PLA_Area:{SR},dn,Analyzer,1474,'||p_sig.sigrepo_id||',EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="thumb_dn" title="Signature Feedback: Thumbs Down"></span></a>
			<a class="detailsmall internal" data-sr-href="https://aseobs.oraclecorp.com/ords/f?p=345:56::::11,RIR,RP:P56_SR,P56_ANALYZER_ID,P56_SIGNATURE_ID,P56_PLA_LINE_ANALYTICS,P56_PLA_FAMILY_1,P56_PLA_Area_1:{SR},1474,'||p_sig.sigrepo_id||',EBS,EBS MFG,EBS - Inventory" target="_blank"><span class="af_idea" title="Signature Idea"></span></a>
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
Function GET_OH_AVAIL(
p_inv_item_id in varchar2,
p_org_id number,
p_subinv_code varchar2,
p_locator_id   NUMBER,
p_lot_number varchar2,
p_LPN_ID  NUMBER,
p_qty_type          VARCHAR2
)
return number is

   x_return_status         VARCHAR2 (50);
   x_msg_count             VARCHAR2 (50);
   x_msg_data              VARCHAR2 (50);
   v_item_id               NUMBER;
   v_organization_id       NUMBER;
   v_qoh                   NUMBER;
   v_rqoh                  NUMBER;
   v_atr                   NUMBER;
   v_att                   NUMBER;
   v_qr                    NUMBER;
   v_qs                    NUMBER;
   v_lot_control_code      BOOLEAN;
   v_serial_control_code   BOOLEAN;
      v_lot_exp_date DATE :=NULL;
   L_QTY NUMBER;


BEGIN
   SELECT   inventory_item_id, mp.organization_id
     INTO   v_item_id, v_organization_id
     FROM   mtl_system_items_b msib, mtl_parameters mp
    WHERE       msib.inventory_item_id = p_inv_item_id
            AND msib.organization_id = mp.organization_id
            AND msib.organization_id =p_org_id; -- :organization_code;


   v_qoh := NULL;
   v_rqoh := NULL;
   v_atr := NULL;
   v_lot_control_code := FALSE;
   v_serial_control_code := FALSE;

   fnd_client_info.set_org_context (1);

      IF p_lot_number IS NOT NULL
      THEN
        v_lot_control_code := TRUE;
        v_lot_exp_date := SYSDATE;
      END IF;

      BEGIN
         inv_quantity_tree_grp.clear_quantity_cache;
         inv_quantity_tree_pub.query_quantities (
            p_api_version_number    => 1.0,
            p_init_msg_lst          => 'F',
            x_return_status         => x_return_status,
            x_msg_count             => x_msg_count,
            x_msg_data              => x_msg_data,
            p_organization_id       => p_org_id,
            p_inventory_item_id     => p_inv_item_id,
            p_tree_mode             => apps.inv_quantity_tree_pub.g_transaction_mode,
            p_is_revision_control   => FALSE,
            p_is_lot_control        => v_lot_control_code, 
            p_is_serial_control     => FALSE,
            p_revision              => NULL,           
            p_lot_number            => p_lot_number,   
            p_lot_expiration_date   => v_lot_exp_date,
            p_subinventory_code     => p_subinv_code,  
            p_locator_id            => p_locator_id,   
            p_onhand_source         => 3,
            x_qoh                   => v_qoh,          
            x_rqoh                  => v_rqoh,   
            x_qr                    => v_qr,
            x_qs                    => v_qs,
            x_att                   => v_att,    
            x_atr                   => v_atr,    
            p_lpn_id                => p_LPN_ID
            );


 IF p_qty_type='OHQ' THEN --On Hand qty
     L_QTY :=v_qoh; --v_QuantityOnhand;
ELSE IF p_qty_type='ATR' THEN --Available to Reserve
     L_QTY :=v_atr;
ELSE IF p_qty_type='ATT' THEN --Available to Transact
     L_QTY :=v_att;
END IF;
END IF;
END IF;

 return L_QTY;

   -- DBMS_OUTPUT.put_line ('On-Hand Quantity: ' || v_qoh);
   -- DBMS_OUTPUT.put_line ('Available to reserve: ' || v_atr);
   -- DBMS_OUTPUT.put_line ('Quantity Reserved: ' || v_qr);
   -- DBMS_OUTPUT.put_line ('Quantity Suggested: ' || v_qs);
   -- DBMS_OUTPUT.put_line ('Available to Transact: ' || v_att);
   -- DBMS_OUTPUT.put_line ('Available to Reserve: ' || v_atr);


EXCEPTION
   WHEN OTHERS
   THEN
      DBMS_OUTPUT.put_line ('ERROR: ' || SQLERRM);
END;
END GET_OH_AVAIL;


-- Line_Shipment_Option from OEXOELIN.pll
FUNCTION line_shipment_option(
  Line_Number      IN NUMBER,
  Shipment_Number  IN NUMBER,
  Option_Number    IN NUMBER,
  Component_Number IN NUMBER,
  Service_Number   IN NUMBER
) 
RETURN VARCHAR2
IS
 p_concat_value  VARCHAR2(60);
BEGIN
  -- Added for identifying Service Lines
  IF service_number is not null then
     IF option_number is not null then
        IF component_number is not null then
           p_concat_value := line_number||'.'||shipment_number||'.'||option_number||'.'||component_number||'.'||service_number;
        ELSE
           p_concat_value := line_number||'.'||shipment_number||'.'||option_number||'..'||service_number;
        END IF;
      --- if a option is not attached
      ELSE
        IF component_number is not null then
           p_concat_value := line_number||'.'||shipment_number||'..'||component_number||'.'||service_number;
        ELSE
           p_concat_value := line_number||'.'||shipment_number||'...'||service_number;
        END IF;
      END IF; /* if option number is not null */
    -- if the service number is null
    ELSE
      IF option_number is not null then
         IF component_number is not null then
            p_concat_value := line_number||'.'||shipment_number||'.'||option_number||'.'||component_number;
        ELSE
            p_concat_value := line_number||'.'||shipment_number||'.'||option_number;
        END IF;
      --- if a option is not attached
      ELSE
        IF component_number is not null then
           p_concat_value := line_number||'.'||shipment_number||'..'||component_number;
        ELSE
           IF (line_number is NULL and shipment_number is NULL ) THEN
              p_concat_value := NULL;
           ELSE
              p_concat_value := line_number||'.'||shipment_number;
           END IF;
        END IF;
      END IF; /* if option number is not null */
    END IF; /* if service number is not null */
  RETURN p_concat_value;
END line_shipment_option;


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
            p_diag_type                    IN VARCHAR2    DEFAULT NULL
           ,p_batch_id                     IN NUMBER      DEFAULT NULL
           ,p_header_id                    IN NUMBER      DEFAULT NULL
           ,p_so_line_id                   IN NUMBER      DEFAULT NULL
           ,p_wip_entity_id                IN NUMBER      DEFAULT NULL
           ,p_print_appscheck              IN VARCHAR2    DEFAULT 'Y'
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
-- Accommodations for 19C DB
l_DBbanner VARCHAR2(255);



FUNCTION get_SALESORDERID
   return VARCHAR2 IS
BEGIN
debug('begin sql token function: SALESORDERID');
BEGIN
   select distinct MSO.SALES_ORDER_ID 
    into l_system_function_var 
    from MTL_SALES_ORDERS              MSO,
         OE_ORDER_HEADERS_ALL          ORD,
         OE_TRANSACTION_TYPES_TL       TYP 
   where ORD.HEADER_ID                 = p_header_id
   and ORD.ORDER_TYPE_ID               = TYP.TRANSACTION_TYPE_ID
   and MSO.SEGMENT1                    = to_char(ORD.ORDER_NUMBER)
   and TYP.NAME                        = MSO.SEGMENT2;
   return l_system_function_var;
EXCEPTION WHEN NO_DATA_FOUND THEN
      return null;
END;
debug('end sql token function: SALESORDERID');
END get_SALESORDERID;

FUNCTION get_JOBORGID
   return VARCHAR2 IS
BEGIN
debug('begin sql token function: JOBORGID');
BEGIN
  select distinct organization_id
    into l_system_function_var
    from WIP_DISCRETE_JOBS WDJ
   where WDJ.WIP_ENTITY_ID = p_wip_entity_id;
  return l_system_function_var;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    return null;
END;
debug('end sql token function: JOBORGID');
END get_JOBORGID;

FUNCTION get_ORGID
   return VARCHAR2 IS
BEGIN
debug('begin sql token function: ORGID');
BEGIN
  select distinct organization_id
    into l_system_function_var
    from WIP_DISCRETE_JOBS WDJ
   where WDJ.WIP_ENTITY_ID = p_wip_entity_id;
  return l_system_function_var;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    return null;
END;
debug('end sql token function: ORGID');
END get_ORGID;



BEGIN

  l_step := '1';

  print_log(analyzer_title || ' Log File');
  print_log('***************************************************************');

  -- Create global hash for parameters. Numbers required for the output order
debug('begin populate parameters hash table');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Diagnostics Type';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_diag_type,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Picking Batch ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_batch_id,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Sales Order Header ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_header_id,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Sales Order Line ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_so_line_id,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Discrete Job ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_wip_entity_id,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Include Apps Check Information (Y/N)';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_print_appscheck,'NO_MASK');
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
  l_revision := rtrim(replace('$Revision: 200.29  $','$',''));
  l_revision := ltrim(replace(l_revision,'Revision:',''));
  l_date_char := rtrim(replace('$Date: 2026/02/23 18:17:39 $','$',''));
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
  g_rep_info('File Name') := 'logistics_pick_release_analyzer.sql';
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

debug('begin parameter validation: p_diag_type');
IF p_diag_type IS NULL THEN
   print_error('INVALID ARGUMENT: Parameter Diagnostics Type is required.');
   raise invalid_parameters;
END IF;
IF p_diag_type IS NOT NULL AND p_diag_type NOT IN ( 'LOGISTICS','WIP','WSH') THEN
   print_error('INVALID ARGUMENT: Diagnostics Type is Not Valid');
   raise invalid_parameters;
END IF;
debug('end parameter validation: p_diag_type');

debug('begin parameter validation: p_batch_id');
IF p_batch_id IS NOT NULL THEN
BEGIN
SELECT BATCH_ID
INTO l_exists_val
FROM WSH_PICKING_BATCHES WPB
WHERE BATCH_ID = p_batch_id and rownum < 2;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
   print_error('INVALID ARGUMENT: Invalid Batch ID parameter provided.  Process cannot continue.');
   raise invalid_parameters;
   WHEN OTHERS THEN
   print_error('INVALID ARGUMENT: Validation query for p_batch_id failed with '||sqlerrm||'.');
   raise invalid_parameters;
END;
END IF;
debug('end parameter validation: p_batch_id');

debug('begin parameter validation: p_header_id');
IF p_header_id IS NOT NULL THEN
BEGIN
SELECT HEADER_ID
INTO l_exists_val
FROM OE_ORDER_HEADERS_ALL H
WHERE HEADER_ID = p_header_id and rownum < 2;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
   print_error('INVALID ARGUMENT: Invalid Sales Order Header ID parameter provided.  Process cannot continue.');
   raise invalid_parameters;
   WHEN OTHERS THEN
   print_error('INVALID ARGUMENT: Validation query for p_header_id failed with '||sqlerrm||'.');
   raise invalid_parameters;
END;
END IF;
debug('end parameter validation: p_header_id');

debug('begin parameter validation: p_so_line_id');
IF p_so_line_id IS NOT NULL THEN
BEGIN
SELECT LINE_ID
INTO l_exists_val
FROM OE_ORDER_LINES_ALL LIN
WHERE LINE_ID = p_so_line_id
 AND LIN.HEADER_ID = p_header_id
and   LIN.OPTION_NUMBER              IS NULL
and   LIN.ITEM_TYPE_CODE             <> 'INCLUDED'

 and rownum < 2;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
   print_error('INVALID ARGUMENT: Invalid Line ID parameter provided.  Process cannot continue.');
   raise invalid_parameters;
   WHEN OTHERS THEN
   print_error('INVALID ARGUMENT: Validation query for p_so_line_id failed with '||sqlerrm||'.');
   raise invalid_parameters;
END;
END IF;
debug('end parameter validation: p_so_line_id');

debug('begin parameter validation: p_wip_entity_id');
IF p_wip_entity_id IS NOT NULL THEN
BEGIN
SELECT WIP_ENTITY_ID
INTO l_exists_val
FROM WIP_DISCRETE_JOBS WDJ
WHERE WIP_ENTITY_ID = p_wip_entity_id
 AND EXISTS ( Select 1
                from WIP_ENTITIES WE
                where WE.WIP_ENTITY_ID = WDJ.WIP_ENTITY_ID
                  AND WE.ENTITY_TYPE IN (1,3)
            )
 and rownum < 2;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
   print_error('INVALID ARGUMENT: Invalid Discrete Job ID parameter provided.  Process cannot continue.');
   raise invalid_parameters;
   WHEN OTHERS THEN
   print_error('INVALID ARGUMENT: Validation query for p_wip_entity_id failed with '||sqlerrm||'.');
   raise invalid_parameters;
END;
END IF;
debug('end parameter validation: p_wip_entity_id');

debug('begin parameter validation: p_print_appscheck');
IF p_print_appscheck IS NOT NULL AND p_print_appscheck NOT IN ( 'N','Y') THEN
   print_error('INVALID ARGUMENT: Gather and Include Apps Check Information is invalid. Valid Values are Y or N');
   raise invalid_parameters;
END IF;
debug('end parameter validation: p_print_appscheck');


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
-- Accommodations for 19C DB
g_db_version    := l_dbversion;
select CASE 
WHEN g_db_version > '18'
THEN 'banner_full'
Else 'banner'
END into l_DBbanner from dual where rownum=1;
g_DBbanner := l_DBbanner;

-- p_diag_type = 'WSH'

IF p_diag_type = 'WSH' THEN
   l_step := '10';
 IF p_batch_id IS NULL OR p_batch_id = '' THEN
   print_log('INVALID ARGUMENT: Parameter Picking Batch ID is required '||
      'if Diagnostics Type = WSH');
   raise invalid_parameters;
 END IF;

l_step := '20';
    BEGIN
        SELECT BATCH_ID
        INTO l_exists_val
        FROM WSH_PICKING_BATCHES
        WHERE BATCH_ID = p_batch_id
        and rownum < 2 ;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
    print_error('INVALID ARGUMENT: Invalid Batch ID parameter provided.  Process cannot continue.');
     raise invalid_parameters;
    END;

 l_step := '30';

  IF p_header_id IS NULL OR p_header_id = '' THEN
    print_log('INVALID ARGUMENT: Parameter Sales Order Header ID is required '||
      'if Diagnostics Type = WSH');
    raise invalid_parameters;
  END IF;

 l_step := '40';
  IF p_header_id IS NOT NULL THEN
       BEGIN
         SELECT HEADER_ID
         INTO l_exists_val
         FROM OE_ORDER_HEADERS_ALL H
         WHERE HEADER_ID = p_header_id
          and rownum < 2 ;
       EXCEPTION
       WHEN NO_DATA_FOUND THEN
       print_error('INVALID ARGUMENT: Invalid Sales Order Header ID parameter provided.  Process cannot continue.');
       raise invalid_parameters;
       END;
   END IF; 
END IF;--IF p_diag_type = 'WSH'



IF p_diag_type = 'LOGISTICS'  THEN

 l_step := '50';


IF p_header_id IS NULL OR p_header_id = '' THEN
   print_log('INVALID ARGUMENT: Parameter Sales Order Header ID is required '||
      'IF Diagnostics Type = LOGISTICS');
   raise invalid_parameters;
END IF;

 l_step := '60';

IF p_header_id IS NOT NULL THEN
       BEGIN
         SELECT HEADER_ID
         INTO l_exists_val
         FROM OE_ORDER_HEADERS_ALL H
         WHERE HEADER_ID = p_header_id
          and rownum < 2 ;
       EXCEPTION
       WHEN NO_DATA_FOUND THEN
       print_error('INVALID ARGUMENT: Invalid Sales Order Header ID parameter provided.  Process cannot continue.');
       raise invalid_parameters;
        END;
END IF;

 l_step := '70';

IF p_so_line_id IS NULL OR p_so_line_id = '' THEN
   print_log('INVALID ARGUMENT: Parameter Sales Order Line ID is required '||
      'IF Diagnostics Type = LOGISTICS');
   raise invalid_parameters;
END IF;

 l_step := '80';

IF p_so_line_id IS NOT NULL THEN

  BEGIN
     SELECT LINE_ID
     INTO l_exists_val
     FROM OE_ORDER_LINES_ALL LIN
     WHERE LINE_ID = p_so_line_id
     AND LIN.HEADER_ID = p_header_id
     and   LIN.OPTION_NUMBER              IS NULL
     and   LIN.ITEM_TYPE_CODE             <> 'INCLUDED'
     and rownum < 2 ;
  EXCEPTION
   WHEN NO_DATA_FOUND THEN
     print_error('INVALID ARGUMENT: Invalid Line ID parameter provided.  Process cannot continue.');
    raise invalid_parameters;
  END;
END IF;
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
    /* SEEDED EBS BANNER END */debug('end Additional Code: Additional Validation');
debug('end Additional Code: Additional Validation');



  g_parameters.DELETE;

  -- Recreate global hash for parameters after validation (includes the modifiers)
debug('begin populate parameters hash table');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Diagnostics Type';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_diag_type,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Picking Batch ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_batch_id,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Sales Order Header ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_header_id,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Sales Order Line ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_so_line_id,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Discrete Job ID';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_wip_entity_id,'NO_MASK');
   g_parameters.extend();
   g_parameters(g_parameters.LAST).pname := 'Include Apps Check Information (Y/N)';
   g_parameters(g_parameters.LAST).pvalue := mask_text(p_print_appscheck,'NO_MASK');
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
   g_sql_tokens('##$$BATCHID$$##') := p_batch_id;
   g_masked_tokens('##$$BATCHID$$##') := mask_text( g_sql_tokens('##$$BATCHID$$##'), 'NO_MASK');
   g_sql_tokens('##$$SOHEADERID$$##') := p_header_id;
   g_masked_tokens('##$$SOHEADERID$$##') := mask_text( g_sql_tokens('##$$SOHEADERID$$##'), 'NO_MASK');
   g_sql_tokens('##$$SOLINEID$$##') := p_so_line_id;
   g_masked_tokens('##$$SOLINEID$$##') := mask_text( g_sql_tokens('##$$SOLINEID$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM1$$##') := '660';
   g_masked_tokens('##$$APPS_PARAM1$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM1$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM2$$##') := '665';
   g_masked_tokens('##$$APPS_PARAM2$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM2$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM3$$##') := '401';
   g_masked_tokens('##$$APPS_PARAM3$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM3$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM4$$##') := '385';
   g_masked_tokens('##$$APPS_PARAM4$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM4$$##'), 'NO_MASK');
   g_sql_tokens('##$$APPS_PARAM5$$##') := '706';
   g_masked_tokens('##$$APPS_PARAM5$$##') := mask_text( g_sql_tokens('##$$APPS_PARAM5$$##'), 'NO_MASK');
   g_sql_tokens('##$$SALESORDERID$$##') := get_SALESORDERID();
   l_system_function_var := null;
   g_masked_tokens('##$$SALESORDERID$$##') := mask_text( g_sql_tokens('##$$SALESORDERID$$##'), 'NO_MASK');
   g_sql_tokens('##$$HEADERID$$##') := p_header_id;
   g_masked_tokens('##$$HEADERID$$##') := mask_text( g_sql_tokens('##$$HEADERID$$##'), 'NO_MASK');
   g_sql_tokens('##$$LINEID$$##') := p_so_line_id;
   g_masked_tokens('##$$LINEID$$##') := mask_text( g_sql_tokens('##$$LINEID$$##'), 'NO_MASK');
   g_sql_tokens('##$$JOBID$$##') := p_wip_entity_id;
   g_masked_tokens('##$$JOBID$$##') := mask_text( g_sql_tokens('##$$JOBID$$##'), 'NO_MASK');
   g_sql_tokens('##$$JOBORGID$$##') := get_JOBORGID();
   l_system_function_var := null;
   g_masked_tokens('##$$JOBORGID$$##') := mask_text( g_sql_tokens('##$$JOBORGID$$##'), 'NO_MASK');
   g_sql_tokens('##$$REL$$##') := g_rep_info('Apps Version');
   g_masked_tokens('##$$REL$$##') := mask_text( g_sql_tokens('##$$REL$$##'), 'NO_MASK');
   g_sql_tokens('##$$USERNAME$$##') := 'NULL';
   g_masked_tokens('##$$USERNAME$$##') := mask_text( g_sql_tokens('##$$USERNAME$$##'), 'NO_MASK');
   g_sql_tokens('##$$RESPID$$##') := 'NULL';
   g_masked_tokens('##$$RESPID$$##') := mask_text( g_sql_tokens('##$$RESPID$$##'), 'NO_MASK');
   g_sql_tokens('##$$ORGID$$##') := get_ORGID();
   l_system_function_var := null;
   g_masked_tokens('##$$ORGID$$##') := mask_text( g_sql_tokens('##$$ORGID$$##'), 'NO_MASK');
   g_sql_tokens('##$$ITEMID$$##') := null;
   g_masked_tokens('##$$ITEMID$$##') := mask_text( g_sql_tokens('##$$ITEMID$$##'), 'NO_MASK');
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


debug('begin add_signature: INV_RUP_CHECK2_SQL_AD_BUGS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8429',
      p_sig_id                 => 'INV_RUP_CHECK2_SQL_AD_BUGS',
      p_sig_sql                => 'select ''Application Environment: ''|| sys_context(''USERENV'',''DB_NAME'') || '', Host: ''|| sys_context(''USERENV'',''SERVER_HOST'') ||'', Application Release: '' || f.release_name || '', DB Version: ''|| i.version "Rollup Details"
from v$instance i,fnd_product_groups f
where upper(substr(i.instance_name,1,4)) =  upper(substr(f.applications_system_name,1,4))
UNION
select ''Current Application Release: ''||ver||'' (''||bug||'')'' "Description" from (
select x.* from
(select 1 seq, ''1939818'' bug,''11.5.0'' pv,''11.5.6'' ver from dual
union select 2,''2123967'',''11.5.0'',''11.5.7'' from dual
union select 3,''2293243'',''11.5.0'',''11.5.8'' from dual
union select 4,''2669606'',''11.5.0'',''11.5.9 MP'' from dual
union select 5,''3126422'',''11.5.0'',''11.5.9 Update1'' from dual
union select 6,''3171663'',''11.5.0'',''11.5.9 Update2'' from dual
union select 7,''3714435'',''11.5.0'',''11.5.9 June Update'' from dual
union select 8,''3140000'',''11.5.0'',''11.5.10'' from dual
union select 9,''3240000'',''11.5.0'',''11.5.10.1'' from dual
union select 10,''3460000'',''11.5.0'',''11.5.10.2'' from dual
union select 11,''3480000'',''11.5.0'',''11.5.10.2'' from dual
union select 12,''4440000'',''12.0.0'',''12.0'' from dual
union select 12,''94440000'',''12.0.0'',''12.0*'' from dual
union select 13,''5082400'',''12.0.0'',''12.0.1'' from dual
union select 14,''5484000'',''12.0.0'',''12.0.2'' from dual
union select 14,''95484000'',''12.0.0'',''12.0.2*'' from dual
union select 15,''6141000'',''12.0.0'',''12.0.3'' from dual
union select 15,''96141000'',''12.0.0'',''12.0.3*'' from dual
union select 16,''6435000'',''12.0.0'',''12.0.4'' from dual
union select 17,''7282993'',''12.0.0'',''12.0.5'' from dual
union select 18,''6728000'',''12.0.0'',''12.0.6'' from dual
union select 19,''6646600'',''12.0.0'',''12.1.0'' from dual
union select 20,''7303030'',''12.0.0'',''12.1.1'' from dual
union select 20,''97303030'',''12.0.0'',''12.1.1*'' from dual
union select 21,''7303033'',''12.0.0'',''12.1.2'' from dual
union select 22,''9239090'',''12.0.0'',''12.1.3'' from dual
union select 23,''10079002'',''12.0.0'',''12.2.0'' from dual
union select 24,''910079002'',''12.0.0'',''12.2.0'' from dual
union select 25,''14222221'',''12.0.0'',''12.2.1'' from dual
union select 26,''16207672'',''12.0.0'',''12.2.2'' from dual
union select 27,''17020683'',''12.0.0'',''12.2.3'' from dual
union select 28,''17919161'',''12.0.0'',''12.2.4'' from dual
union select 29,''917919161'',''12.0.0'',''12.2.4'' from dual
union select 30,''19676458'',''12.0.0'',''12.2.5'' from dual
union select 31,''919676458'',''12.0.0'',''12.2.5'' from dual
union select 32,''21900901'',''12.0.0'',''12.2.6'' from dual
union select 33,''24690690'',''12.0.0'',''12.2.7'' from dual
union select 34,''26787767'',''12.0.0'',''12.2.8'' from dual
union select 35,''28840850'',''12.0.0'',''12.2.9'' from dual
union select 36,''30399999'',''12.0.0'',''12.2.10'' from dual
union select 37,''31856789'',''12.0.0'',''12.2.11'' from dual
union select 38,''33527700'',''12.0.0'',''12.2.12'' from dual
union select 39,''34776655'',''12.0.0'',''12.2.13'' from dual
union select 40,''36026788'',''12.0.0'',''12.2.14'' from dual
) x,
(select product_version pv from fnd_product_installations
where application_id=401) i,
ad_bugs bugs
where x.bug = bugs.bug_number and x.pv = i.pv order by 1 desc) where rownum = 1
union
select ''Current INV Rollup: ''||ver||'' (''||bug||'')'' "Description" from (
select x.* from
(select 1 seq, ''1426212'' bug,''11.5.0'' pv,''INV.C'' ver from dual
union select 2,''1551167'',''11.5.0'',''MFG.D'' from dual
union select 3, ''1550583'',''11.5.0'',''OM.D'' from dual
union select 4,''1538130'',''11.5.0'',''INV.D'' from dual
union select 5, ''1745355'',''11.5.0'',''MFG.E'' from dual
union select 6,''1696652'',''11.5.0'',''INV.E'' from dual
union select 7, ''1891480'',''11.5.0'',''MFG.F'' from dual
union select 8, ''1942144'',''11.5.0'',''OM.F'' from dual
union select 9,''1886015'',''11.5.0'',''INV.F'' from dual
union select 10, ''2133107'',''11.5.0'',''MFG.G'' from dual
union select 11, ''2118482'',''11.5.0'',''OM.G'' from dual
union select 12,''2004922'',''11.5.0'',''INV.G'' from dual
union select 13, ''2248408'',''11.5.0'',''MFG.H'' from dual
union select 14,''2250333'',''11.5.0'',''OM.H'' from dual
union select 15,''2248490'',''11.5.0'',''INV.H'' from dual
union select 16, ''2697753'',''11.5.0'',''MFG.I'' from dual
union select 17,''2698175'',''11.5.0'',''OM.I'' from dual
union select 18,''2371213'',''11.5.0'',''INV.I'' from dual
union select 19,''3384350'',''11.5.0'',''INV.J'' from dual
union select 20,''4042499'',''11.5.0'',''INV.J RUP1'' from dual
union select 21,''4231215'',''11.5.0'',''INV.J RUP2'' from dual
union select 22,''4734840'',''11.5.0'',''INV.J RUP3'' from dual
union select 23,''5739724'',''11.5.0'',''INV.J RUP4'' from dual
union select 24,''6449139'',''11.5.0'',''INV.J RUP5'' from dual
union select 25,''6461517'',''11.5.0'',''INV.J RUP6'' from dual
union select 26,''6461519'',''11.5.0'',''INV.J RUP7'' from dual
union select 27,''6461522'',''11.5.0'',''INV.J RUP8'' from dual
union select 28,''6870030'',''11.5.0'',''INV.J RUP9'' from dual
union select 29,''7258620'',''11.5.0'',''INV.J RUP10'' from dual
union select 30,''7258624'',''11.5.0'',''INV.J RUP11'' from dual
union select 31,''7258629'',''11.5.0'',''INV.J RUP12'' from dual
union select 32,''7581431'',''11.5.0'',''INV.J RUP13'' from dual
union select 33,''7666112'',''11.5.0'',''INV.J RUP14'' from dual
union select 34,''8403245'',''11.5.0'',''INV.J RUP15'' from dual
union select 35,''8403254'',''11.5.0'',''INV.J RUP16'' from dual
union select 36,''8403258'',''11.5.0'',''INV.J RUP17'' from dual
union select 37,''9063156'',''11.5.0'',''INV.J RUP18'' from dual
union select 38,''9265857'',''11.5.0'',''INV.J RUP19'' from dual
union select 39,''9466436'',''11.5.0'',''INV.J RUP20'' from dual
union select 40,''9649124'',''11.5.0'',''INV.J RUP21'' from dual
union select 41,''9878808'',''11.5.0'',''INV.J RUP22'' from dual
union select 42,''10111967'',''11.5.0'',''INV.J RUP23'' from dual
union select 43,''8478486'',''12.0.0'',''R12 INV/RCV RUP7'' from dual
union select 44,''7587155'',''12.0.0'',''R12.1.1 OPM-INV Consolidated May-2009'' from dual
union select 45,''12345554'',''12.0.0'',''R12.1.3 OPM-INV Consolidated Apr-2011'' from dual
union select 46,''12916273'',''12.0.0'',''R12.1+ INV Dual UOM related fixes 3'' from dual
union select 47,''13885374'',''12.0.0'',''R12.1+INV Dual UOM related fixes 4'' from dual
union select 48,''14586882'',''12.0.0'',''R12.1+ INV RUP 5'' from dual
union select 49,''16328540'',''12.0.0'',''R12.1+ INV RUP 6'' from dual
union select 50,''16826285'',''12.0.0'',''R12.1+ INV RUP 7 (Requires RUP6)'' from dual
union select 51,''17512558'',''12.0.0'',''R12.1+ INV RUP 7 Consolidated'' from dual
union select 52,''18076740'',''12.0.0'',''R12.1+ INV RUP 8'' from dual
union select 53,''18615837'',''12.0.0'',''R12.1+ INV RUP 9'' from dual
union select 54,''19447776'',''12.0.0'',''R12.1+ INV RUP 10'' from dual
union select 55,''20187255'',''12.0.0'',''R12.1+ INV RUP 11'' from dual
union select 56,''21218468'',''12.0.0'',''R12.1+ INV RUP 12'' from dual
union select 57,''22086747'',''12.0.0'',''R12.1+ INV RUP 13'' from dual
union select 58,''22598102'',''12.0.0'',''R12.1+ INV RUP 14'' from dual
union select 59,''24011188'',''12.0.0'',''R12.1+ INV RUP 15'' from dual
union select 60,''24843312'',''12.0.0'',''R12.1+ INV RUP 16'' from dual
union select 61,''26399295'',''12.0.0'',''R12.1+ INV RUP 17'' from dual
union select 62,''10079002'',''12.0.0'',''R12.2+'' from dual
) x,
(select product_version pv from fnd_product_installations
where application_id = 401) i,
ad_bugs bugs
where x.bug = bugs.bug_number and x.pv = i.pv order by 1 desc) where rownum = 1
UNION
select ''Current WMS Rollup: ''||ver||'' (''||bug||'')'' "Description" from (
select x.* from
(select 1 seq, ''4734840'' bug, ''11.5.0'' pv,''RUP3'' ver from dual
union select 2 seq, ''5855276'' bug,''11.5.0'' pv,''WMS RUP4'' ver from dual
union select 3 seq, ''6957082'' bug,''11.5.0'' pv,''WMS RUP5'' ver from dual
union select 4 seq, ''7041845'' bug,''11.5.0'' pv,''WMS RUP6'' ver from dual
union select 5 seq, ''7219660'' bug,''11.5.0'' pv,''WMS RUP7'' ver from dual
union select 6 seq, ''7317230'' bug,''11.5.0'' pv,''WMS RUP8'' ver from dual
union select 7 seq, ''7453739'' bug,''11.5.0'' pv,''WMS RUP9'' ver from dual
union select 8 seq, ''7591071'' bug,''11.5.0'' pv,''WMS RUP10'' ver from dual
union select 9 seq, ''7644924'' bug,''11.5.0'' pv,''WMS RUP11'' ver from dual
union select 10 seq,''7688739'' bug,''11.5.0'' pv,''WMS RUP12'' ver from dual
union select 11 seq,''8337529'' bug,''11.5.0'' pv,''WMS RUP13'' ver from dual
union select 12 seq,''8524873'' bug,''11.5.0'' pv,''WMS RUP14'' ver from dual
union select 13 seq,''8785944'' bug,''11.5.0'' pv,''WMS RUP15'' ver from dual
union select 13 seq,''8941985'' bug,''11.5.0'' pv,''WMS RUP16'' ver from dual
union select 14 seq,''9127290'' bug,''11.5.0'' pv,''WMS RUP17'' ver from dual
union select 15 seq,''9857061'' bug,''11.5.0'' pv,''WMS RUP18'' ver from dual
union select 16 seq,''9951502'' bug,''11.5.0'' pv,''WMS RUP19'' ver from dual
union select 17 seq,''10129740'' bug,''11.5.0'' pv,''WMS RUP20'' ver from dual
union select 18 seq,''7716519'',''12.0.0'',''R12.1.1 OPM-WMS Consolidated May-2009'' from dual
union select 19 seq,''12364985'',''12.0.0'',''R12.1.1 OPM-WMS Consolidated Apr-2011'' from dual
union select 20 seq,''12916291'',''12.0.0'',''R12.1+ WMS Dual UOM fixes RUP 3'' from dual
union select 21 seq,''13885396'',''12.0.0'',''R12.1+ WMS Dual UOM fixes RUP 4'' from dual
union select 22 seq,''14611722'',''12.0.0'',''R12.1+ WMS RUP 5'' from dual
union select 23 seq,''16272776'',''12.0.0'',''R12.1+ WMS RUP 6'' from dual
union select 24 seq,''16812342'',''12.0.0'',''R12.1+ WMS RUP 7 (Requires RUP6)'' from dual
union select 25 seq,''17442200'',''12.0.0'',''R12.1+ WMS RUP 7 Consolidated'' from dual
union select 26 seq,''18081430'',''12.0.0'',''R12.1+ WMS RUP 8'' from dual
union select 27 seq,''18618946'',''12.0.0'',''R12.1+ WMS RUP 9'' from dual
union select 28 seq,''19447782'',''12.0.0'',''R12.1+ WMS RUP 10'' from dual
union select 29 seq,''20187263'',''12.0.0'',''R12.1+ WMS RUP 11'' from dual
union select 30 seq,''21220763'',''12.0.0'',''R12.1+ WMS RUP 12'' from dual
union select 31 seq,''22086754'',''12.0.0'',''R12.1+ WMS RUP 13'' from dual
union select 32 seq,''22598196'',''12.0.0'',''R12.1+ WMS RUP 14'' from dual
union select 33 seq,''24011194'',''12.0.0'',''R12.1+ WMS RUP 15'' from dual
union select 34 seq,''24843317'',''12.0.0'',''R12.1+ WMS RUP 16'' from dual
union select 35 seq,''26399322'',''12.0.0'',''R12.1+ WMS RUP 17'' from dual
union select 36,''10079002'',''12.0.0'',''R12.2+'' from dual
) x,
(select product_version pv from fnd_product_installations
where application_id=385) i,
ad_bugs bugs
where x.bug = bugs.bug_number and x.pv = i.pv order by 1 desc) where rownum = 1
union
select ''Product Installation List : '' from dual
union
select ''Product Installation: ''||patch_level||'': ''||decode(status,
''I'',''Installed'',''S'',''Shared'',''Not Installed'')
from fnd_product_installations
where application_id IN (401, 385, 201, 431, 702, 703)
order by 1',
      p_title                  => 'Inventory Rollup Patch Status - Database View',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'A second view of recent patches that queries directly on the AD Bugs table using SQL from [726226/KB627455]. (This is a helpful reference to see the current rollup patch applied as well as the history of patches. Its a good idea to stay on the latest rollup.)',
      p_solution               => 'For the most current recommendations, use the Patch Wizard or the Updates & Patches Tab in My Oracle Support.<br>
Further guidance can be found in the following documents:<br>
<ul>
<li>[11086538/KA747] How to Find EBS Patches and EBS Technology Patches</li>
<li>[976188/KB739927] R11i / R12 : Patch Wizard Utility</li>
<li>[10940175/KA580] Patch Wizard FAQ</li>
<li>[726226/KB627455] INV/WMS/RCV Family Patch Release History / Patchsets / RUPs</li>
<li>Best Practice: Always ensure that you are on the latest code with all recommended patches applied.</li>
<li>This will help avoid known issues, prevent potential data corruption and provide the latest features and functionality.</li>
<li>Having a proactive patching plan and periodic proactive patching process in place are the best ways to stay current.</li>
</ul>',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '12'
      );
   l_info.delete;
debug('end add_signature: INV_RUP_CHECK2_SQL_AD_BUGS');



debug('begin add_signature: INV_TXN_KEY_FILE_VERSIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6725',
      p_sig_id                 => 'INV_TXN_KEY_FILE_VERSIONS',
      p_sig_sql                => 'select o.object_name,
substr(ltrim(rtrim(substr(substr(s.text, instr(s.text,''Header: '')),
instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 1),
instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2) -
instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 1) ))), 1, 25) "FILE_NAME",
substr(ltrim(rtrim(substr(substr(s.text, instr(s.text,''Header: '')),
instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2),
instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 3) -
instr(substr(s.text, instr(s.text,''Header: '')), '' '', 1, 2) ))), 1, 30) "FILE_VERSION",
decode(o.object_type, ''PACKAGE'' , ''SPEC'', ''PACKAGE BODY'', ''BODY'') TYPE,
o.object_type PKG_TYPE,
o.status STATUS
from user_objects o , user_source s
where s.name = o.object_name
and s.type = o.object_type
and o.object_type in (''PACKAGE'' , ''PACKAGE BODY'')
and (o.object_name IN (
            ''INV_TXN_MANAGER_GRP'', 
            ''INV_PROCESS_TEMP'', 
            ''INV_QUANTITY_TREE_PVT'', 
            ''INV_PICK_RELEASE_PVT'', 
            ''INV_RCV_INTEGRATION_PVT'',
            ''INV_RESERVATION_PVT'') 
)
and s.line between 2 and 3
and s.text like ''%Header: %''
order by 1, 3 desc, 5 desc',
      p_title                  => 'Key File Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Information about inventory transaction processing related packages. These packages are often a good version to check if you see incorrect behavior to ensure you have any recent patches and code-fixes:
<ul>
<li>INV_TXN_MANAGER_GRP (INVTXGGB.pls) - This package does interface transaction (MTL_TRANSACTIONS_INTERFACE) validations on the transaction open interface table data.</li>

<li>INV_PROCESS_TEMP (INVMMTTB.pls) - This package does pending transaction (MTL_MATERIAL_TRANSACTIONS_TEMP) validations on the temporary table data.</li>

<li>INV_PICK_RELEASE_PVT (INVVPICB.pls) - This package is used in pick release processing including the main logic for pick release as well as related functions like creating and maintaining reservations.</li>


<li>INV_QUANTITY_TREE_PVT (INVVQTTB.pls) - This package is responsible for calculating onhand data by creating a tree structure of onhand results then returning those values to calling programs. The onhand quantity data (MTL_ONHAND_QUANTITIES_DETAIL) is queried and summarized.</li>
</ul>',
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
debug('end add_signature: INV_TXN_KEY_FILE_VERSIONS');



debug('begin add_signature: INV_INVALIDS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1562',
      p_sig_id                 => 'INV_INVALIDS',
      p_sig_sql                => 'SELECT a.object_name,
       a.status,
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
             WHERE c.owner = a.owner
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
    AND a.owner = ''APPS''
    AND (a.object_name like ''INV%'' OR
         a.object_name like ''MTL_%'' OR 
         a.object_name like ''WMS_%'' OR
         a.object_name like ''EGO_%'' OR
         a.object_name like ''CST_%'')
    AND a.status = ''INVALID''',
      p_title                  => 'Invalid Objects Exist Related to Inventory',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Checking if Invalid Objects exist related to Inventory.',
      p_solution               => 'The invalid objects are listed for information only. They may not impact your task, but it is advisable to review and address them as follows:<br>
<ul>
<li>Review any error messages provided.</li>
<li>Recompile the individual objects manually or recompile the entire APPS schema with adadmin utility.</li>
<li>If you still have invalid objects, please review steps from [1325394/KB401905] Troubleshooting Guide - Invalid Objects in the E-Business Suite Environment 11i and 12.</li>
</ul>',
      p_success_msg            => 'No invalid objects indicated. All objects beginning with INV, MTL_, WMS_, EGO_, and CST_, were validated.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '20'
      );
   l_info.delete;
debug('end add_signature: INV_INVALIDS');



debug('begin add_signature: LOGPR_ORDER_HEADER');
   l_info('##MASK##SHIP TO NAME'):= 'DISPLAY_BOTH_25_PCNT_WORD';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9964',
      p_sig_id                 => 'LOGPR_ORDER_HEADER',
      p_sig_sql                => 'Select  distinct ORD.HEADER_ID                "Header ID",
            ORD.ORDER_NUMBER                  "Order Number",
            ORD.ORDER_TYPE_ID                 "Order Type ID",
            TYP.NAME                          "Type Name",
            ORD.FLOW_STATUS_CODE              "Flow Status",
            nvl(ORD.BOOKED_FLAG,''N'')          "Booked",
            nvl(ORD.OPEN_FLAG,''N'')            "Open",
            nvl(ORD.CANCELLED_FLAG,''N'')       "Cancelled",
            nvl(ORD.PARTIAL_SHIPMENTS_ALLOWED,''Y'') "Partial Ship",
            ORD.SOLD_TO_ORG_ID                "Sold To ID",
            substr(CUS.CUSTOMER_NAME,1,20)    "Cust Name",
            ORD.SHIP_TO_ORG_ID                "Ship To Org ID",
            substr(SHP.NAME,1,12)             "Ship To Name",
            ORD.INVOICE_TO_ORG_ID             "Bill To ID",
            to_char(ORD.ORDERED_DATE,''DD-MON-RR_HH24:MI:SS'')  "Order Date",
            ORD.SHIP_FROM_ORG_ID                   "Ship From Org ID",
            PAR.ORGANIZATION_CODE                  "Ship From Org Code",
            ORD.ORDER_CATEGORY_CODE                "Order Category",
            ORD.PRICE_LIST_ID                      "Price List ID",
            PRC.NAME                               "Price List Name",
            ORD.CUST_PO_NUMBER                     "PO Number",
            ORD.ORIG_SYS_DOCUMENT_REF              "Orig Doc Reference",
            ORD.SHIP_TOLERANCE_ABOVE               "Ship Tol Above",
            ORD.SHIP_TOLERANCE_BELOW               "Ship Tol Below",
            HR.NAME                                "Operating Unit",
            ORD.ORG_ID                             "Operating Unit ID"
from
     OE_ORDER_HEADERS_ALL              ORD,
     MTL_PARAMETERS                    PAR,
     OE_TRANSACTION_TYPES_TL           TYP,
     AR_CUSTOMERS                      CUS,
     OE_SHIP_TO_ORGS_V                 SHP,
     QP_LIST_HEADERS_V                 PRC,
     HR_OPERATING_UNITS                HR,
     FND_LANGUAGES                     FLA
where
     ORD.HEADER_ID                 = ##$$SOHEADERID$$##
and  ORD.SHIP_FROM_ORG_ID          = PAR.ORGANIZATION_ID(+)
and  ORD.ORDER_TYPE_ID             = TYP.TRANSACTION_TYPE_ID(+)
and  ORD.SHIP_TO_ORG_ID            = SHP.SITE_USE_ID(+)
and  ORD.SOLD_TO_ORG_ID            = CUS.CUSTOMER_ID(+)
and  ORD.PRICE_LIST_ID             = PRC.LIST_HEADER_ID(+)
and  ORD.ORG_ID                    = HR.ORGANIZATION_ID(+)
and  TYP.LANGUAGE                  = FLA.LANGUAGE_CODE',
      p_title                  => 'Sales Order Header Information',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Sales order header information.',
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
debug('end add_signature: LOGPR_ORDER_HEADER');



debug('begin add_signature: LOGPR_ORDER_HOLD');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9965',
      p_sig_id                 => 'LOGPR_ORDER_HOLD',
      p_sig_sql                => 'SELECT 
  HDF.HOLD_ID                        "HOLD ID",
  HDF.NAME                           "HOLD NAME",
  HDF.TYPE_CODE                      "TYPE CODE",
  HDF.ITEM_TYPE                      "ITEM TYPE",
  HDF.ACTIVITY_NAME                  "ACTIVITY",
  HLD.ORDER_HOLD_ID                  "ORDER HOLD ID",
  HLD.HOLD_SOURCE_ID                 "HOLD SOURCE ID",
  HLD.HOLD_RELEASE_ID                "HOLD RELEASE ID",
  HLD.HEADER_ID                      "HEADER ID",
  HLD.RELEASED_FLAG                  "RELEASE 1",
  HSR.RELEASED_FLAG                  "RELEASE 2",
  HRL.RELEASE_REASON_CODE            "RELEASE CODE",
  decode(HSR.HOLD_ENTITY_CODE,
         ''B'',''Bill To'',
         ''C'',''Customer'',
         ''I'',''Item'',
         ''O'',''Order'',
         ''S'',''Ship To'',
         ''W'',''Warehouse'',
         HSR.HOLD_ENTITY_CODE)       "ENTITY",
  HSR.HOLD_ENTITY_ID                 "ENTITY ID",
  decode(HSR.HOLD_ENTITY_CODE2,
         ''B'',''Bill To'',
         ''C'',''Customer'',
         ''I'',''Item'',
         ''O'',''Order'',
         ''S'',''Ship To'',
         ''W'',''Warehouse'',
         HSR.HOLD_ENTITY_CODE2)      "ENTITY 2",
  HSR.HOLD_ENTITY_ID2                "ENTITY ID 2",
  to_char(HSR.HOLD_UNTIL_DATE,''DD-MON-RR_HH24:MI:SS'') "HOLD UNTIL"
from OE_ORDER_HOLDS_ALL    HLD,
     OE_HOLD_SOURCES_ALL   HSR,
     OE_HOLD_DEFINITIONS   HDF,
     OE_HOLD_RELEASES      HRL
where        HLD.HEADER_ID            = ##$$SOHEADERID$$##
        and  HLD.HOLD_SOURCE_ID       = HSR.HOLD_SOURCE_ID
        and  HSR.HOLD_ID              = HDF.HOLD_ID
        and  HLD.HOLD_RELEASE_ID      = HRL.HOLD_RELEASE_ID(+)
        and  HLD.LINE_ID              IS NULL',
      p_title                  => 'List of Sales Order Generic Holds',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No header level generic holds exist for this sales order.',
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
debug('end add_signature: LOGPR_ORDER_HOLD');



debug('begin add_signature: LOGPR_MTL_SALES_ORDER');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9966',
      p_sig_id                 => 'LOGPR_MTL_SALES_ORDER',
      p_sig_sql                => 'SELECT
     MSO.SALES_ORDER_ID            "Sales Order ID",
     ORD.HEADER_ID                 "Header ID",
     ORD.ORDER_NUMBER              "Order Number",
     TYP.NAME                      "Name",
     MSO.SEGMENT3
from
     MTL_SALES_ORDERS              MSO,
     OE_ORDER_HEADERS_ALL          ORD,
     OE_TRANSACTION_TYPES_TL       TYP
where
     ORD.ORDER_TYPE_ID             = TYP.TRANSACTION_TYPE_ID
and  TO_CHAR(ORD.ORDER_NUMBER)     = MSO.SEGMENT1
and  TYP.NAME(+)                   = MSO.SEGMENT2
and  MSO.SEGMENT1                  = ORD.ORDER_NUMBER
and typ.language = ''US''
and  ORD.HEADER_ID                 = ##$$SOHEADERID$$##
order by ORD.HEADER_ID',
      p_title                  => 'MTL Sales Orders',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Sales Orders in MTL_SALES_ORDERS for this Sales Order.',
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
debug('end add_signature: LOGPR_MTL_SALES_ORDER');



debug('begin add_signature: LOGPR_OE_SETS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9967',
      p_sig_id                 => 'LOGPR_OE_SETS',
      p_sig_sql                => 'SELECT distinct
ST1.SET_ID                               "SET ID",                         
       ST1.SET_NAME                      "SET NAME",                       
       ST1.SET_TYPE                      "SET TYPE",                       
       ST1.HEADER_ID                     "HEADER ID",
       ST1.INVENTORY_ITEM_ID             "ITEM ID",              
       ST1.ORDERED_QUANTITY_UOM          "UOM",           
       ST1.LINE_TYPE_ID                  "LINE TYPE ID",
       nvl(LST.SYSTEM_REQUIRED_FLAG,''N'') "SYS REQD",
       ST1.SET_STATUS                    "STATUS",                                                              
       to_char(ST1.SCHEDULE_SHIP_DATE,''DD-MON-RR_HH24:MI:SS'')  "SCH SHIP DATE",             
       to_char(ST1.SCHEDULE_ARRIVAL_DATE,''DD-MON-RR_HH24:MI:SS'')   "SCH ARV DATE",
       ST1.SHIP_FROM_ORG_ID              "SHIP FROM",      
       ST1.SHIP_TO_ORG_ID                "SHIP TO ID",
       ST1.SHIPMENT_PRIORITY_CODE        "SHIP PRIORITY", 
       ST1.FREIGHT_CARRIER_CODE          "CARRIER",
       ST1.SHIPPING_METHOD_CODE          "SHIP METHOD",
       ST1.SHIP_TOLERANCE_ABOVE          "SHIP TOL ABOVE",           
       ST1.SHIP_TOLERANCE_BELOW          "SHIP TOL BELOW"
from OE_SETS                       ST1,
     OE_LINE_SETS                  LST
where ST1.SET_ID              = LST.SET_ID(+)
and   ST1.HEADER_ID           = ##$$SOHEADERID$$##',
      p_title                  => 'OE Set(s) Information',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No OE Set(s) found for this sales order.',
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
debug('end add_signature: LOGPR_OE_SETS');



debug('begin add_signature: LOGPR_ORDER_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9968',
      p_sig_id                 => 'LOGPR_ORDER_LINES',
      p_sig_sql                => 'SELECT
substr(to_char(LIN.line_number) ||
decode(LIN.shipment_number, null, null, ''.'' || to_char(LIN.shipment_number))||
decode(LIN.option_number, null, null, ''.'' || to_char(LIN.option_number)) ||
decode(LIN.component_number, null, null,
decode(LIN.option_number, null, ''.'',null)||
''.''||to_char(LIN.component_number))||decode(LIN.service_number,null,null,
decode(LIN.component_number, null, ''.'' , null) ||
decode(LIN.option_number, null, ''.'', null ) ||
''.''|| to_char(LIN.service_number)),1,10) "Line Number",
LIN.LINE_ID "Line ID",
det.delivery_detail_id "Delivery Detail ID",
LIN.INVENTORY_ITEM_ID "Item ID",
substr(ITM.SEGMENT1,1,80) "Item Name",
substr(LIN.FLOW_STATUS_CODE,1,22) "Workflow Status",
nvl(LIN.OPEN_FLAG,''N'') "Open",
nvl(LIN.BOOKED_FLAG,''N'') "Booked",
nvl(LIN.SHIPPABLE_FLAG,''N'') "Shipped",
nvl(LIN.CANCELLED_FLAG,''N'') "Cancelled",
nvl(LIN.VISIBLE_DEMAND_FLAG,''N'') "Visual Demand",
nvl(LIN.SHIPPING_INTERFACED_FLAG,''N'') "Shipping Interface",
nvl(LIN.FULFILLED_FLAG, ''N'') "Fullfilled",
decode(nvl(LIN.ATO_LINE_ID,0),0,''N'',''Y'') "ATO Line",
nvl(LIN.SHIP_MODEL_COMPLETE_FLAG,''N'') "Ship Model Complete",
nvl(LIN.ORDERED_QUANTITY,0) "Ordered QTY",
 ( SELECT SUM(r.primary_reservation_quantity)
         FROM mtl_reservations r
         WHERE r.demand_source_header_id =  ##$$SOHEADERID$$##
		   AND R.DEMAND_SOURCE_LINE_ID = LIN.LINE_ID
           AND r.demand_source_type_id IN (2,8,9,21,22) ) "Reserved Qty",
LIN.ORDER_QUANTITY_UOM "Ordered UOM",
LIN.UNIT_SELLING_PRICE "Selling Price",
LIN.UNIT_LIST_PRICE "List Price",
LIN.CALCULATE_PRICE_FLAG "Calculate Price",
nvl(LIN.SHIPPING_QUANTITY,0) "Shipping QTY",
nvl(LIN.SHIPPED_QUANTITY,0) "Shipped QTY",
nvl(FULFILLED_QUANTITY,0) "Fulfilled QTY",
nvl(LIN.CANCELLED_QUANTITY,0) "Cancelled QTY",
nvl(LIN.INVOICED_QUANTITY,0) "Invoiced QTY",
substr(LIN.SCHEDULE_STATUS_CODE,1,5) "Schedule Code",
LIN.ORG_ID "Org ID",
LIN.SHIP_FROM_ORG_ID "Ship From ID",
to_char(LIN.CREATION_DATE,''DD-MON-RR_HH24:MI:SS'') "Create Date",
to_char(LIN.REQUEST_DATE,''DD-MON-RR_HH24:MI:SS'') "Request Date",
to_char(LIN.SCHEDULE_SHIP_DATE,''DD-MON-RR_HH24:MI:SS'') "Schedule Ship Date",
to_char(LIN.SCHEDULE_ARRIVAL_DATE,''DD-MON-RR_HH24:MI:SS'') "Schedule Arrival Date",
LIN.OVERRIDE_ATP_DATE_CODE "Override ATP",
to_char(LIN.ACTUAL_SHIPMENT_DATE,''DD-MON-RR_HH24:MI:SS'') "Actual Ship",
LIN.LINE_TYPE_ID "Line Type ID",
LIN.LINE_CATEGORY_CODE "Line Category",
LIN.ITEM_TYPE_CODE "Item Type",
LIN.ORDERED_ITEM_ID "Ordered Item ID",
substr(LIN.ORDERED_ITEM,1,45) "Ordered Item Name",
LIN.SOURCE_TYPE_CODE "Source Type",
LIN.PRICE_LIST_ID "Price List ID",
LIN.PRICING_QUANTITY "Pricing QTY",
LIN.PRICING_QUANTITY_UOM "Pricing QTY UOM",
to_char(LIN.PRICING_DATE,''DD-MON-RR_HH24:MI:SS'') "Pricing Date",
LIN.DEMAND_CLASS_CODE "Demand Class",
nvl(LIN.OPTION_FLAG,''N'') "Option Flag",
LIN.TOP_MODEL_LINE_ID "Top Model Line ID",
LIN.ATO_LINE_ID "Model Line ID",
LIN.LINK_TO_LINE_ID "Link to Line ID",
LIN.SPLIT_BY "Split By",
LIN.SPLIT_FROM_LINE_ID "Split From",
LIN.CONFIG_HEADER_ID "Config Header ID",
nvl(LIN.INVOICE_INTERFACE_STATUS_CODE,''N'') "Invoice Interface",
LIN.SHIP_TOLERANCE_ABOVE "Ship Tolerance Above",
LIN.SHIP_TOLERANCE_BELOW "Ship Tolerance Below",
LIN.SHIP_SET_ID "Ship Set ID",
ST2.SET_TYPE "Ship Set Type",
LIN.LINE_SET_ID "Line Set ID",
ST3.SET_TYPE "Line Set Type",
LIN.ARRIVAL_SET_ID "Arrival Set ID",
ST1.SET_TYPE "Arrival Set Type",
nvl(LIN.ORDERED_QUANTITY2,0) "Ordered QTY 2",
LIN.ORDERED_QUANTITY_UOM2 "Ordered UOM 2",
nvl(LIN.SHIPPED_QUANTITY2,0) "Shipped QTY 2",
nvl(LIN.SHIPPING_QUANTITY2,0) "Shipping QTY 2",
nvl(LIN.SHIPPING_QUANTITY_UOM2,0) "Shipping QTY UOM 2",
nvl(FULFILLED_QUANTITY2,0) "Fulfilled QTY 2",
nvl(LIN.CANCELLED_QUANTITY2,0) "Cancelled QTY 2",
to_char(LIN.LAST_UPDATE_DATE,''DD-MON-RR_HH24:MI:SS'') "Update Date",
ITM.TRACKING_QUANTITY_IND "Tracking QTY",
ITM.PRIMARY_UOM_CODE "Primary UOM",
ITM.DUAL_UOM_CONTROL "Dual UOM",
ITM.SECONDARY_DEFAULT_IND "Sec Def Ind",
ITM.SECONDARY_UOM_CODE "Sec UOM",
ITM.CHILD_LOT_FLAG "Child Lot",
ITM.PARENT_CHILD_GENERATION_FLAG "Par Child",
ITM.LOT_DIVISIBLE_FLAG "Lot Divisible",
ITM.GRADE_CONTROL_FLAG "Grad CTRL",
Decode(ITM.ONT_PRICING_QTY_SOURCE,
''P'',''Primary'', ''Secondary'') "ONT PR QTY",
ITM.dual_uom_deviation_high "Dual UOM DEV High",
ITM.dual_uom_deviation_low "Dual UOM DEV Low",
ITM.lot_control_code "Lot CTRL Code",
ITM.location_control_code "Location CTRL Code",
ITM.lot_status_enabled "Lot Status Enabled",
Decode(ITM.RESERVABLE_TYPE,1,''Reserv'', 2,''Non-Res'', ''Val: ''||to_char(ITM.RESERVABLE_TYPE)) "Reservable" ,
ITM.ATP_FLAG "Check ATP",
LIN.source_document_line_id "Source Doc Line ID",
LIN.subinventory   "Subinventory"
from
OE_ORDER_LINES_ALL LIN,
MTL_SYSTEM_ITEMS ITM,
OE_SETS ST1,
OE_SETS ST2,
OE_SETS ST3,
WSH_DELIVERY_DETAILS DET
where
LIN.HEADER_ID = ##$$SOHEADERID$$##
and NVL(''##$$SOLINEID$$##'',0) in (0,LIN.LINE_ID,
LIN.TOP_MODEL_LINE_ID,
LIN.ATO_LINE_ID,
LIN.LINK_TO_LINE_ID,
LIN.SERVICE_REFERENCE_LINE_ID)
and LIN.SHIP_FROM_ORG_ID = ITM.ORGANIZATION_ID(+)
and LIN.INVENTORY_ITEM_ID = ITM.INVENTORY_ITEM_ID(+)
and LIN.ARRIVAL_SET_ID = ST1.SET_ID(+)
and LIN.SHIP_SET_ID = ST2.SET_ID(+)
and LIN.LINE_SET_ID = ST3.SET_ID(+)
and LIN.LINE_ID = DET.SOURCE_LINE_ID(+)
order by LIN.line_number
, nvl(LIN.line_set_id, 0)
, nvl(LIN.shipment_number, -1)
, nvl(LIN.option_number, -1)
, nvl(LIN.service_number, -1)',
      p_title                  => 'Sales Order Line(s) Information',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No sales order lines exist for this sales order.',
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
debug('end add_signature: LOGPR_ORDER_LINES');



debug('begin add_signature: LOGPR_LINE_SPECIFIC_HOLDS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9969',
      p_sig_id                 => 'LOGPR_LINE_SPECIFIC_HOLDS',
      p_sig_sql                => 'SELECT 
  HLD.LINE_ID                        "Line ID",
    to_char(LIN.line_number) || 
          decode(LIN.shipment_number, null, null, ''.'' || to_char(LIN.shipment_number))|| 
          decode(LIN.option_number, null, null, ''.'' || to_char(LIN.option_number)) ||
          decode(LIN.component_number, null, null, 
                 decode(LIN.option_number, null, ''.'',null)||
                 ''.''||to_char(LIN.component_number))||
          decode(LIN.service_number,null,null,
                 decode(LIN.component_number, null, ''.'' , null) ||
                        decode(LIN.option_number, null, ''.'', null ) ||
                        ''.''|| to_char(LIN.service_number)) "Line Number",
  HDF.HOLD_ID                        "Hold ID",
  HDF.NAME                           "Hold Name",
  HDF.TYPE_CODE                      "Hold Type",
  HDF.ITEM_TYPE                      "Item Type",
  HDF.ACTIVITY_NAME                  "Activity Name",
  HLD.ORDER_HOLD_ID                  "Order Hold ID",
  HLD.HOLD_SOURCE_ID                 "Hold Source ID",
  HLD.HOLD_RELEASE_ID                "Hold Release ID",
  HLD.HEADER_ID                      "Header ID",
  HLD.RELEASED_FLAG                  "Header Released Flag",
  HSR.RELEASED_FLAG                  "Released Flag",
  HRL.RELEASE_REASON_CODE            "Release Reason",
  decode(HSR.HOLD_ENTITY_CODE,
         ''B'',''Bill To'',
         ''C'',''Customer'',
         ''I'',''Item'',
         ''O'',''Order'',
         ''S'',''Ship To'',
         ''W'',''Warehouse'',
         HSR.HOLD_ENTITY_CODE)       ENTITY,
  HSR.HOLD_ENTITY_ID                 ENTITY_ID,
  decode(HSR.HOLD_ENTITY_CODE2,
         ''B'',''Bill To'',
         ''C'',''Customer'',
         ''I'',''Item'',
         ''O'',''Order'',
         ''S'',''Ship To'',
         ''W'',''Warehouse'',
         HSR.HOLD_ENTITY_CODE2)      ENTITY2,
  HSR.HOLD_ENTITY_ID2                ENTITY_ID2,
  to_char(HSR.HOLD_UNTIL_DATE,''DD-MON-RR HH24:MI:SS'')    HOLD_UNTIL
from OE_ORDER_HOLDS_ALL    HLD,
     OE_HOLD_SOURCES_ALL   HSR,
     OE_HOLD_DEFINITIONS   HDF,
     OE_HOLD_RELEASES      HRL,
     OE_ORDER_LINES_ALL    LIN
where        HLD.HEADER_ID             = ##$$SOHEADERID$$##
        and  LIN.HEADER_ID             = ##$$SOHEADERID$$##
        and  HLD.LINE_ID               IS NOT NULL
        and  HLD.LINE_ID               = LIN.LINE_ID
        and  NVL(''##$$SOLINEID$$##'',0)  in (0,LIN.LINE_ID,
                                       LIN.TOP_MODEL_LINE_ID,
                                       LIN.ATO_LINE_ID,
                                       LIN.LINK_TO_LINE_ID,
                                       LIN.REFERENCE_LINE_ID,
                                       LIN.SERVICE_REFERENCE_LINE_ID)
        and  HLD.HOLD_SOURCE_ID       = HSR.HOLD_SOURCE_ID
        and  HSR.HOLD_ID              = HDF.HOLD_ID
        and  HLD.HOLD_RELEASE_ID      = HRL.HOLD_RELEASE_ID(+)',
      p_title                  => 'Line Specific Holds (Lines Only)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No line specific holds for this sales order.',
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
debug('end add_signature: LOGPR_LINE_SPECIFIC_HOLDS');



debug('begin add_signature: LOGPR_SO_WSH_NEW_DELIVERIES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9982',
      p_sig_id                 => 'LOGPR_SO_WSH_NEW_DELIVERIES',
      p_sig_sql                => 'select distinct
DEL.DELIVERY_ID ,
DEL.NAME ,
DEL.STATUS_CODE ,
DEL.WAYBILL ,
DEL.PLANNED_FLAG ,
to_char(DEL.INITIAL_PICKUP_DATE,''DD-MON-YYYY HH24:MI:SS'') Pickup_Date,
DEL.INITIAL_PICKUP_LOCATION_ID Pickup_Loc_ID,
to_char(DEL.ULTIMATE_DROPOFF_DATE,''DD-MON-YYYY HH24:MI:SS'') Drop_Off_Date,
DEL.ULTIMATE_DROPOFF_LOCATION_ID Drop_Off_Loc_ID,
DEL.SHIP_METHOD_CODE ,
to_char(DEL.CONFIRM_DATE,''DD-MON-YYYY HH24:MI:SS'') Confirm_Date
FROM
WSH_DELIVERY_DETAILS DET,
WSH_NEW_DELIVERIES DEL,
WSH_DELIVERY_ASSIGNMENTS ASG
where DET.source_code = ''OE''
and DEL.DELIVERY_ID = ASG.DELIVERY_ID
and ASG.DELIVERY_DETAIL_ID = DET.DELIVERY_DETAIL_ID
and det.source_header_id =  ##$$SOHEADERID$$##
and det.source_line_id = NVL(''##$$SOLINEID$$##'' , det.source_line_id)
order by Del.DELIVERY_ID',
      p_title                  => 'New Deliveries',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'New Deliveries associated with this Sales Order.',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: LOGPR_SO_WSH_NEW_DELIVERIES');



debug('begin add_signature: LOGPR_SO_WSH_DELIVERY_ASSIGNMENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9984',
      p_sig_id                 => 'LOGPR_SO_WSH_DELIVERY_ASSIGNMENTS',
      p_sig_sql                => 'select distinct
ASG.DELIVERY_ASSIGNMENT_ID ,
ASG.DELIVERY_ID ,
ASG.DELIVERY_DETAIL_ID ,
ASG.PARENT_DELIVERY_ID ,
ASG.PARENT_DELIVERY_DETAIL_ID 
FROM
WSH_DELIVERY_DETAILS DET,
WSH_DELIVERY_ASSIGNMENTS ASG
where ASG.DELIVERY_DETAIL_ID = DET.DELIVERY_DETAIL_ID
and  det.source_header_id = ##$$SOHEADERID$$##
and det.source_line_id = NVL(''##$$SOLINEID$$##'' , det.source_line_id)',
      p_title                  => 'Delivery Assignments',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Delivery Assignments for this Sales Order.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '9'
      );
   l_info.delete;
debug('end add_signature: LOGPR_SO_WSH_DELIVERY_ASSIGNMENTS');



debug('begin add_signature: LOGPR_SO_WSH_ORGANIZATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9985',
      p_sig_id                 => 'LOGPR_SO_WSH_ORGANIZATIONS',
      p_sig_sql                => 'SELECT distinct
mp.organization_id ,
mp.organization_code ,
decode(mp.wms_enabled_flag,
''Y'', ''Yes'',
''N'', ''No'') WMS_Enabled,
decode(mp.process_enabled_flag,
''Y'', ''Yes'',
''N'', ''No'') Process_Enabled,
decode(NVL(FND_PROFILE.VALUE(''WSH_OTM_INSTALLED''), ''N''),
''Y'', ''Yes'',
''N'', ''No'') OTM_Installed,
decode(NVL(wsp.otm_enabled,''N''),
''Y'', ''Yes'',
''N'', ''No'') OTM_Enabled,
decode(mp.NEGATIVE_INV_RECEIPT_CODE,
1, ''Yes'',
2, ''No'') Negative_Balance,
decode(mp.primary_cost_method,
1, ''Standard'',
2, ''Average'',
5, ''FIFO'',
6, ''LIFO'') Primary_Cost_Method,
mp.cost_organization_id ,
mp.master_organization_id ,
mp.default_cost_group_id ,
decode(mp.project_reference_enabled,
1, ''Yes'',
2, ''No'') Projects_Enabled,
to_char(mp.cost_cutoff_date,''DD-MON-YYYY'') Cost_Cutoff_Date,
decode(mp.eam_enabled_flag,
''Y'',''Yes'',
''N'',''No'') EAM_Enabled,
decode (mp.encumbrance_reversal_flag,
1, ''Yes'',
2, ''No'') Encumbrance_Reversal
FROM MTL_PARAMETERS MP,
WSH_DELIVERY_DETAILS DET,
WSH_SHIPPING_PARAMETERS WSP
where DET.SOURCE_CODE = ''OE''
and MP.ORGANIZATION_ID = DET.ORGANIZATION_ID
and WSP.ORGANIZATION_ID = DET.ORGANIZATION_ID
and det.source_header_id =  ##$$SOHEADERID$$##
and det.source_line_id = NVL(''##$$SOLINEID$$##'' , det.source_line_id)',
      p_title                  => 'Shipping Organizations for the Sales Order',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Shipping organization information for the Sales Order.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: LOGPR_SO_WSH_ORGANIZATIONS');



debug('begin add_signature: LOGPR_SO_WSH_ACCOUNTING_PERIODS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9986',
      p_sig_id                 => 'LOGPR_SO_WSH_ACCOUNTING_PERIODS',
      p_sig_sql                => 'SELECT distinct
mp.organization_id ,
mp.organization_code ,
to_char(STP.PLANNED_DEPARTURE_DATE,''DD-MON-YYYY HH24:MI:SS'') Plan_Dep_Date,
'''' Schedule_Date,
oac.acct_period_id Account_Period_ID,
oac.period_name ,
oac.open_flag ,
to_char(oac.period_start_date,''DD-MON-YYYY HH24:MI:SS'') Period_Start_Date,
to_char(oac.period_close_date,''DD-MON-YYYY HH24:MI:SS'') Period_Close_Date,
to_char(oac.schedule_close_date,''DD-MON-YYYY HH24:MI:SS'') Period_Schedule_Close_Date
FROM MTL_PARAMETERS MP,
ORG_ACCT_PERIODS OAC,
WSH_DELIVERY_DETAILS DET,
WSH_DELIVERY_LEGS LEG,
WSH_TRIP_STOPS STP,
WSH_DELIVERY_ASSIGNMENTS ASG,
WSH_TRIPS TRP
where ASG.DELIVERY_DETAIL_ID = DET.DELIVERY_DETAIL_ID
and STP.STOP_ID(+) = LEG.PICK_UP_STOP_ID
and STP.TRIP_ID = TRP.TRIP_ID(+)
and LEG.DELIVERY_ID(+) = ASG.DELIVERY_ID
and DET.SOURCE_CODE = ''OE''
and MP.ORGANIZATION_ID = OAC.ORGANIZATION_ID
and MP.ORGANIZATION_ID = DET.ORGANIZATION_ID
and DET.source_header_id =  ##$$SOHEADERID$$##
and det.source_line_id = NVL(''##$$SOLINEID$$##'' , det.source_line_id)
and STP.PLANNED_DEPARTURE_DATE BETWEEN OAC.PERIOD_START_DATE and NVL(OAC.PERIOD_CLOSE_DATE,OAC.SCHEDULE_CLOSE_DATE)
union
SELECT distinct
mp.organization_id ,
mp.organization_code ,
'''' Plan_Dep_Date,
to_char(LIN.SCHEDULE_SHIP_DATE,''DD-MON-YYYY HH24:MI:SS'') Schedule_Date,
oac.acct_period_id Account_Period_ID,
oac.period_name ,
oac.open_flag Open_Flag,
to_char(oac.period_start_date,''DD-MON-YYYY HH24:MI:SS'') Period_Start_Date,
to_char(oac.period_close_date,''DD-MON-YYYY HH24:MI:SS'') Period_Close_Date,
to_char(oac.schedule_close_date,''DD-MON-YYYY HH24:MI:SS'') Period_Schedule_Close_Date
FROM MTL_PARAMETERS MP,
ORG_ACCT_PERIODS OAC,
WSH_DELIVERY_DETAILS DET,
OE_ORDER_LINES_ALL LIN
where DET.SOURCE_LINE_ID = LIN.LINE_ID
and DET.SOURCE_CODE = ''OE''
and MP.ORGANIZATION_ID = OAC.ORGANIZATION_ID
and MP.ORGANIZATION_ID = DET.ORGANIZATION_ID
and DET.source_header_id =  ##$$SOHEADERID$$##
and det.source_line_id = NVL(''##$$SOLINEID$$##'' , det.source_line_id)
and LIN.SCHEDULE_SHIP_DATE BETWEEN OAC.PERIOD_START_DATE and NVL(OAC.PERIOD_CLOSE_DATE,OAC.SCHEDULE_CLOSE_DATE)',
      p_title                  => 'Shipping Accounting Periods',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'List of Shipping accounting periods.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: LOGPR_SO_WSH_ACCOUNTING_PERIODS');



debug('begin add_signature: LOGPR_SO_WSH_DELIVERY_DETAILS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9987',
      p_sig_id                 => 'LOGPR_SO_WSH_DELIVERY_DETAILS',
      p_sig_sql                => 'SELECT det.source_line_id "Line ID",
      to_char(LIN.line_number) ||
decode(LIN.shipment_number, null, null, ''.'' || to_char(LIN.shipment_number))||
decode(LIN.option_number, null, null, ''.'' || to_char(LIN.option_number)) ||
decode(LIN.component_number, null, null,
decode(LIN.option_number, null, ''.'',null)||
''.''||to_char(LIN.component_number))||
decode(LIN.service_number,null,null,
decode(LIN.component_number, null, ''.'' , null) ||
DECODE(LIN.OPTION_NUMBER, NULL, ''.'', NULL ) ||
''.''|| to_char(LIN.service_number)) "Line",
       det.delivery_detail_id "Delivery Detail ID",
       det.released_status|| '': ''|| 
         ( SELECT meaning FROM wsh_lookups WHERE lookup_type = ''PICK_STATUS'' AND lookup_code = det.released_status ) "Status",
       det.oe_interfaced_flag|| '': ''|| 
         decode(nvl(det.oe_interfaced_flag, ''N''),
                ''Y'', ''Yes'',
                ''N'', ''No'',
                ''P'', ''Pending'',
                ''X'', ''Not Applicable'',
                ''Unknown'') "OE Interfaced",
       det.inv_interfaced_flag|| '': ''|| 
         decode(nvl(det.inv_interfaced_flag, ''N''),
                ''Y'', ''Yes'',
                ''N'', ''No'',
                ''P'', ''Pending'',
                ''X'', ''Not Applicable'',
                ''Unknown'') "INV Interfaced",
       asg.delivery_id "Delivery ID", 
       --( SELECT name FROM wsh_new_deliveries wnd WHERE wnd.delivery_id=asg.delivery_id) "Delivery Name",

       trp.trip_id "Trip ID",
       stp.stop_id "Pick Up Stop ID",
       det.batch_id "Picking Batch ID",
       
       mtrl.header_id "Move Order Header ID",
       mtrh.request_number "Move Order No",
       det.move_order_line_id "MO Line ID",
       mtrl.line_number "MO Line",
       det.transaction_temp_id "Transaction Temp ID",

       det.org_id "Org ID",
       det.organization_id "Warehouse ID",
       det.subinventory "Subinventory",
       --det.ship_from_location_id "Ship From Location ID",
       ( SELECT location_code FROM wsh_locations WHERE wsh_location_id = det.ship_from_location_id ) "Ship From Location",
       
       det.inventory_item_id "Item ID",
       itm.segment1 "Item Name",
       det.container_flag "Container",
       det.lpn_id "LPN ID",
       
       nvl(det.src_requested_quantity, 0) "Ordered Qty",
       det.src_requested_quantity_uom "Ordered UOM",
       nvl(det.requested_quantity, 0) "Requested Qty",
       det.requested_quantity_uom "Requested UOM",
       nvl(det.picked_quantity, 0) "Picked Qty",
       nvl(det.shipped_quantity, 0) "Shipped Qty",
       nvl(det.cycle_count_quantity, 0) "Backordered Qty",
       nvl(det.delivered_quantity, 0) "Delivered Qty",
       nvl(det.cancelled_quantity, 0) "Cancelled Qty",
       nvl(det.received_quantity, 0) "Received Qty",
       nvl(det.quality_control_quantity, 0) "Quality Control Qty",
       nvl(det.returned_quantity, 0) "Returned Qty",
       nvl(det.src_requested_quantity2, 0) "Dual Ordered Qty",
       det.src_requested_quantity_uom2 "Dual Ordered UOM",
       nvl(det.requested_quantity2, 0) "Dual Requested Qty",
       det.requested_quantity_uom2 "Dual Requested UOM",
       nvl(det.picked_quantity2, 0) "Dual Picked Qty",
       nvl(det.shipped_quantity2, 0) "Dual Shipped Qty",
       nvl(det.cycle_count_quantity2, 0) "Dual Backordered Qty",
       nvl(det.delivered_quantity2, 0) "Dual Delivered Qty",
       nvl(det.cancelled_quantity2, 0) "Dual Cancelled Qty",
       nvl(det.received_quantity2, 0) "Dual Received Qty",
       nvl(det.quality_control_quantity2, 0) "Dual Quality Control Qty",
       nvl(det.returned_quantity2, 0) "Dual Returned Qty",
       det.revision "Revision",
       det.lot_number "Lot",
       det.serial_number "Serial Number",
       det.to_serial_number "To Serial Number",
       det.locator_id "Locator ID",
       
       det.ship_set_id "Ship Set ID",
       det.arrival_set_id "Arrival Set ID",
       det.source_line_set_id "Line Set ID",
       det.split_from_delivery_detail_id "Split From Del ID",
       det.ship_model_complete_flag "Ship Model Complete",
       det.ato_line_id "ATO Line ID",
       det.top_model_line_id "Top Model Line",
       
	   det.ignore_for_planning "Ignore for Planning",
       det.pickable_flag "Pickable",
       det.hold_code "Hold",
       
	   ( SELECT meaning FROM oe_lookups WHERE lookup_type = ''REQUEST_DATE_TYPE'' AND lookup_code = nvl(det.request_date_type_code, ''SHIP'') ) "Request Date Type",
       to_char(det.date_requested, ''DD-MON-RR_HH24:MI:SS'') "Date Requested",
       to_char(det.date_scheduled, ''DD-MON-RR_HH24:MI:SS'') "Date Scheduled",
       --to_char(det.earliest_pickup_date, ''DD-MON-RR_HH24:MI:SS'') "Earliest Pickup",
       --to_char(det.latest_pickup_date, ''DD-MON-RR_HH24:MI:SS'') "Latest Pickup",
       --to_char(det.earliest_dropoff_date, ''DD-MON-RR_HH24:MI:SS'') "Earliest Delivered",
       --to_char(det.latest_dropoff_date, ''DD-MON-RR_HH24:MI:SS'') "Latest Delivered",

       det.customer_id "Customer ID",
       --( SELECT account_name FROM hz_cust_accounts WHERE cust_account_id=det.customer_id ) "Customer",
       det.ship_to_location_id "Ship To Location ID",
       --( SELECT location_code FROM wsh_locations WHERE wsh_location_id=det.ship_to_location_id ) "Ship To Location",
       det.ship_to_site_use_id "Ship To Site Use ID",
       det.deliver_to_location_id "Deliver To Location ID",
       --( SELECT location_code FROM wsh_locations WHERE wsh_location_id=det.deliver_to_location_id ) "Deliver To Location",
       --det.deliver_to_site_use_id "Deliver To Site Use ID",

       del.initial_pickup_location_id "Initial Pickup Location",
       del.ultimate_dropoff_location_id "Ultimate Dropoff Location",
       stp.stop_location_id "Stop Location",
       det.ship_tolerance_above "Ship Tolerance Above",
       det.ship_tolerance_below "Ship Tolerance Below",
       det.ship_method_code "Ship Method",
       det.mode_of_transport "Mode of Transport",
       det.carrier_id "Freight Carrier",
       det.freight_terms_code "Freight Terms",
       det.shipment_priority_code "Shipment Priority Code",

       det.source_header_id "SO Header ID",
       det.source_header_number "SO No",
       det.source_header_type_id "SO Type ID",
       det.source_header_type_name "SO Type Name",
       det.source_line_id "SO Line ID",
       det.source_line_number "SO Line No",
       
       nvl2(det.line_direction, det.line_direction || '': ''|| 
         decode(det.line_direction, 
                ''I'', ''Inbound'', 
                ''O'', ''Outbound'',
                ''D'', ''Dropship'', 
                ''IO'', ''Internal Order''),
         '''') "Line Direction",
       nvl2(det.replenishment_status, det.replenishment_status|| '': ''|| 
         decode(det.replenishment_status, 
		        ''R'', ''Requested'', 
				''C'', ''Completed'',
                ''Not applicable''),
         '''') "Replenishment",
       det.customer_requested_lot_flag "Cust Requested Lot",
       det.dep_plan_required_flag "Dep Plan Required Flag",
       det.inspection_flag "Inspection",
       det.preferred_grade "Preferred Grade"

  FROM wsh_delivery_details det,
       oe_order_lines_all lin,
       wsh_delivery_assignments asg,
       wsh_new_deliveries del,
       wsh_delivery_legs leg,
       wsh_trip_stops stp,
       wsh_trips trp,
       mtl_system_items itm,
       mtl_txn_request_headers mtrh,
       mtl_txn_request_lines mtrl
 WHERE det.source_code = ''OE''
   AND det.delivery_detail_id = asg.delivery_detail_id
   AND asg.delivery_id = del.delivery_id (+)
   AND del.delivery_id = leg.delivery_id (+)
   AND leg.pick_up_stop_id = stp.stop_id (+)
   AND stp.trip_id = trp.trip_id (+)
   AND lin.ship_from_org_id = itm.organization_id (+)
   AND lin.inventory_item_id = itm.inventory_item_id (+)
   AND det.move_order_line_id = mtrl.line_id (+)
   AND mtrl.header_id = mtrh.header_id (+)
   AND det.source_line_id = lin.line_id
   AND det.source_header_id = ##$$SOHEADERID$$##
   AND det.source_line_id = NVL(''##$$SOLINEID$$##'',det.source_line_id)
 ORDER BY lin.line_number,
          nvl(lin.shipment_number, - 1),
          nvl(lin.option_number, - 1),
          nvl(lin.component_number, - 1),
          nvl(lin.service_number, - 1),
          det.delivery_detail_id',
      p_title                  => 'Delivery Details',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Delivery Details associated with this Sales Order.',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: LOGPR_SO_WSH_DELIVERY_DETAILS');



debug('begin add_signature: EBS_MFG_OM_LOGPR_WSH_PICK_GROUPING_RULES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '28055',
      p_sig_id                 => 'EBS_MFG_OM_LOGPR_WSH_PICK_GROUPING_RULES',
      p_sig_sql                => 'SELECT PICK_GROUPING_RULE_ID "Grouping Rule Id",
       NAME "Name",
       DESCRIPTION "Description",
       ORDER_NUMBER_FLAG "Order Number Flag",
       SUBINVENTORY_FLAG "Subinventory Flag",
       CUSTOMER_FLAG "Customer Flag",
       SHIP_TO_FLAG "Ship To Flag",
       CARRIER_FLAG "Carrier Flag",
       SHIPMENT_PRIORITY_FLAG "Shipment Priority Flag",
       TRIP_STOP_FLAG "Trip Stop Flag",
       DELIVERY_FLAG "Delivery_flag",
       START_DATE_ACTIVE "Start Date Active",
       END_DATE_ACTIVE "End Date Active",
       CREATION_DATE "Creation Date",
       last_update_date "Last Update Date"
from wsh_pick_grouping_rules',
      p_title                  => 'Grouping Rules for Pick Release',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Grouping Rules for Pick Release.',
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
debug('end add_signature: EBS_MFG_OM_LOGPR_WSH_PICK_GROUPING_RULES');



debug('begin add_signature: LOGPR_WSH_PICK_RELEASE_BATCH_SIZE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9749',
      p_sig_id                 => 'LOGPR_WSH_PICK_RELEASE_BATCH_SIZE',
      p_sig_sql                => 'SELECT FPO.USER_PROFILE_OPTION_NAME,
 FPO.PROFILE_OPTION_NAME,
 DECODE(FPOV.LEVEL_ID, 10001, ''Site'', 10002, ''Application'', 10003, ''Responsibility'', 10004, ''User'', 10005, ''Server'', 10006, ''Organization'', ''Unknown'')                       AS PROFILE_LEVEL ,
 DECODE(FPOV.level_id, 10001, ''Site'', 10002, FA.application_short_name, 10003, FR.RESPONSIBILITY_NAME, 10004, FU.USER_NAME, 10005, FN.NODE_NAME, 10006, HOU.name, ''Unknown'') AS Level_Value ,
 FPOV.PROFILE_OPTION_VALUE ,
 FPOV.PROFILE_OPTION_ID ,
 TO_CHAR(FPOV.LAST_UPDATE_DATE,''DD-MON-YYYY HH24:MI:SS'') AS UPDATED_DATE ,
 FU_UPD.user_name                                     AS updated_by
FROM FND_PROFILE_OPTIONS_VL FPO ,
 FND_PROFILE_OPTION_VALUES FPOV ,
 FND_USER FU_UPD ,
 FND_USER FU ,
 FND_RESPONSIBILITY_VL FR ,
 FND_APPLICATION FA ,
 FND_NODES FN ,
 HR_OPERATING_UNITS HOU
WHERE FPO.PROFILE_OPTION_ID   = FPOV.PROFILE_OPTION_ID
and FPO.PROFILE_OPTION_NAME  =''WSH_PICK_RELEASE_BATCH_SIZE''
and FPO.APPLICATION_ID        = FPOV.APPLICATION_ID
and FPOV.LAST_UPDATED_BY      = FU_UPD.USER_ID (+)    
AND FPOV.LEVEL_VALUE          = FU.USER_ID (+)    
and FPOV.LEVEL_VALUE          = FN.NODE_ID (+)   
and TO_CHAR(FPOV.LEVEL_VALUE) = FN.NODE_NAME (+)    
and FPOV.LEVEL_VALUE          = FR.RESPONSIBILITY_ID (+) 
AND FPOV.LEVEL_VALUE          = FA.APPLICATION_ID (+)  
and FPOV.LEVEL_VALUE          = HOU.ORGANIZATION_ID (+)
and upper(FPOV.PROFILE_OPTION_VALUE) <> lower(FPOV.PROFILE_OPTION_VALUE)
order by 1,  FPOV.LEVEL_ID,  4',
      p_title                  => 'Shipping Pick Release Batch Size',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Profile WSH: Pick Release Batch Size is not set to a valid value.',
      p_solution               => 'Refer to [947823/KB706353] - Launch Pick Release Ends in Error - ORA-06502: PL/SQL: numeric or value error: character to number conversion error, for full details.',
      p_success_msg            => 'No issue found with profile WSH: Pick Release Batch Size value.',
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
debug('end add_signature: LOGPR_WSH_PICK_RELEASE_BATCH_SIZE');



debug('begin add_signature: LOGPR_CORRUPTION_OPEN_DD_CLOSED_LINE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10001',
      p_sig_id                 => 'LOGPR_CORRUPTION_OPEN_DD_CLOSED_LINE',
      p_sig_sql                => 'Select
wdd.source_header_number Order_number, wdd.source_line_id, wdd.delivery_detail_id,
wda.delivery_id, wdd.released_status, wdd.creation_date,
wdd.oe_interfaced_flag, wdd.inv_interfaced_flag, ol.ship_from_org_id,
ol.flow_status_code, ol.open_flag , ol.shipping_interfaced_flag
FROM wsh_delivery_details wdd,
oe_order_lines_all ol,
wsh_delivery_assignments wda
WHERE wdd.source_line_id = ol.line_id            
and wdd.delivery_detail_id = wda.delivery_detail_id
and wdd.delivery_detail_id in
(select wdd1.delivery_detail_id
from wsh_delivery_details wdd1, oe_order_lines_all ol1
where wdd1.source_code = ''OE''            
and wdd1.released_status in (''R'',''B'')
and wdd1.source_line_id = ol1.line_id
and ol1.open_flag = ''N''
and wdd1.source_header_id = ##$$SOHEADERID$$##
and wdd1.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd1.source_line_id))',
      p_title                  => 'Delivery Lines Are Open While the Associated Order Lines Are Closed/Cancelled',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The Pick Release Batch consists of Open Delivery Lines for which the associated Order Lines are Closed/Cancelled. This will cause the Pick Release Batch to fail.',
      p_solution               => 'Open Delivery Details should not exist for order lines that are Closed/Cancelled.  A data fix script from Support will need to be applied.  Log an SR requesting a data fix for open delivery line(s) linked to closed/cancelled order line(s).  Refer to [2346819/KB721732] when logging the SR and upload this output to the SR.',
      p_success_msg            => 'There are no Open Delivery Lines for where the associated Order Lines are Closed/Cancelled.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: LOGPR_CORRUPTION_OPEN_DD_CLOSED_LINE');



debug('begin add_signature: LOGPR_SHIPPING_INTEREFACED_FLAG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9745',
      p_sig_id                 => 'LOGPR_SHIPPING_INTEREFACED_FLAG',
      p_sig_sql                => 'select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description,
ool.flow_status_code,
ool.open_flag,
ool.cancelled_flag,
ool.ordered_quantity,
ool.shipped_quantity,
ool.shipping_interfaced_flag
from wsh_delivery_details wdd,
     oe_order_lines_all ool
where wdd.source_code = ''OE''
and wdd.source_header_id  = ool.header_id
and wdd.source_line_id = ool.line_id
and wdd.released_status in ( ''R'',''B'')
and NVL(ool.shipping_interfaced_flag,''N'') = ''N''
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)',
      p_title                  => 'Sales Order Line Shipping Interfaced Flag Is No',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The Shipping Sales Order Line shipping interfaced flag is No, but delivery details exist.',
      p_solution               => '<ul><li>Review [1926478/KB759276] Can Not Pick Release Order Although Line Status Is "Ready To Release", for full details.</li></ul>',
      p_success_msg            => 'There is no issue with Shipping interfaced flag.',
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
debug('end add_signature: LOGPR_SHIPPING_INTEREFACED_FLAG');



debug('begin add_signature: LOGPR_PICKSLIP_NUMBER_NOT_GENERATED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9742',
      p_sig_id                 => 'LOGPR_PICKSLIP_NUMBER_NOT_GENERATED',
      p_sig_sql                => 'select wrs.report_set_id, wrs.name, wrs.description, wrs.start_date_active, wrs.end_date_active, fcp.user_concurrent_program_name
from WSH_REPORT_SETS wrs,
     WSH_REPORT_SET_LINES wrsl,
     fnd_concurrent_programs_vl fcp,
     fnd_application fa
where wrs.report_set_id = wrsl.report_set_id
  and wrs.usage_code = ''PICK_RELEASE''
  and SYSDATE BETWEEN wrs.start_date_active and NVL(wrs.end_date_active, SYSDATE+1)
  and fcp.concurrent_program_name like ''WSHRDPIK%''
  and fcp.enabled_flag = ''Y''
  and fcp.concurrent_program_id = wrsl.concurrent_program_id
  and fa.application_short_name = ''WSH''
  and fa.application_id = wrsl.application_id',
      p_title                  => 'Pick Slip Number not Generated',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Seeded Pick Slip Report was not enabled thus no pick slip number got generated.',
      p_solution               => '<ul><li>Refer to [1543491/KB724181] Pick Slip Number Not Being Generated When Doing Pick Release, for full details.</li></ul>',
      p_success_msg            => 'There exists at least one Seeded Pick Slip Report assignment.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_PICKSLIP_NUMBER_NOT_GENERATED');



debug('begin add_signature: LOGPR_DISTRIBUTED_WMS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9714',
      p_sig_id                 => 'LOGPR_DISTRIBUTED_WMS',
      p_sig_sql                => 'select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
mp.organization_code,
mp.distributed_organization_flag,
wdd.item_description
from wsh_delivery_details wdd,
     mtl_parameters mp
where wdd.source_code = ''OE''
and wdd.organization_id = mp.organization_id
and NVL(mp.distributed_organization_flag, ''N'') = ''Y''
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)
and EXISTS ( select 1
               from FND_PROFILE_OPTIONS_VL FPO,
                    FND_PROFILE_OPTION_VALUES FPOV
              where FPO.PROFILE_OPTION_ID   = FPOV.PROFILE_OPTION_ID
                and FPO.PROFILE_OPTION_NAME  =''WMS_DEPLOYMENT_MODE''
                and FPO.APPLICATION_ID        = FPOV.APPLICATION_ID
                and NVL(FPOV.profile_option_value,''1'') = ''2'')',
      p_title                  => 'Distributed WMS Organization Parameter Enabled',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'In a Distributed WMS instance,  the Organization  Parameter "Distributed" is enabled.',
      p_solution               => '<ul><li>Refer to [1485110/KB781659] Cannot Pick Release any Sales Orders In a Distributed WMS Instance, for full details. The Distributed Organization parameter should not be enabled</li></ul>',
      p_success_msg            => 'There are No Organizations enabled as Distributed in the Distributed WMS instance.',
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
debug('end add_signature: LOGPR_DISTRIBUTED_WMS');



debug('begin add_signature: LOGPR_DD_RR_MOLINEID_NOT_NULL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9712',
      p_sig_id                 => 'LOGPR_DD_RR_MOLINEID_NOT_NULL',
      p_sig_sql                => 'select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id
from wsh_delivery_details wdd
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.move_order_line_id is not null
and wdd.source_header_id =##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)',
      p_title                  => 'Delivery Detail(S) Ready to Release but Move Order Line ID Exists',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Delivery Detail(s) in a Released status "R" (Ready to Release), but the Move Order Line had already been stamped, and status did not change.',
      p_solution               => '<ul><li>Refer to [2195623/KB710551] Pick Release Errors With DELIVERY DETAIL LINE NOT FOUND: XXXXXXXX NO_DATA_FOUND Exception Has Occurred, for full details. A datafix will be required.</li></ul>',
      p_success_msg            => 'There are no problematic delivery details with this issue.',
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
debug('end add_signature: LOGPR_DD_RR_MOLINEID_NOT_NULL');



debug('begin add_signature: LOGPR_DEP_PLAN_REQUIRED_FLAG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9707',
      p_sig_id                 => 'LOGPR_DEP_PLAN_REQUIRED_FLAG',
      p_sig_sql                => 'select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description,
wda.delivery_id,
wda.delivery_assignment_id,
WDD.DEP_PLAN_REQUIRED_FLAG,
wnd.PLANNED_FLAG
from wsh_delivery_details wdd,
     wsh_delivery_assignments wda,
     wsh_new_deliveries wnd
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.delivery_detail_id = wda.delivery_detail_id
and wda.delivery_id = wnd.delivery_id
and NVL(WDD.DEP_PLAN_REQUIRED_FLAG,''N'') = ''Y'' 
AND NVL(wnd.PLANNED_FLAG,''N'') = ''N''
and wdd.source_header_id =  ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)',
      p_title                  => 'Delivery Detail Departure Plan Required Flag Set to Yes',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Delivery Detail departure plan required flag was set to "Yes", and the delivery planned flag is "N", so the Delivery Detail is not selected for picking.',
      p_solution               => '<ul><li>Refer to [2178795/KB735074] Pick Selection Completed Successfully but Delivery Detail Remains at ''Ready to Release'', for full details.</li></ul>',
      p_success_msg            => 'There are no delivery details with mismatched Shipment Priority.',
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
debug('end add_signature: LOGPR_DEP_PLAN_REQUIRED_FLAG');



debug('begin add_signature: LOGPR_DB_WRITER_PROCESSES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9706',
      p_sig_id                 => 'LOGPR_DB_WRITER_PROCESSES',
      p_sig_sql                => 'select *
from v$parameter
where name = ''db_writer_processes''',
      p_title                  => 'DB Parameter Writer Processes',
      p_fail_condition         => '[VALUE]<[16]',
      p_problem_descr          => 'DB Writer Processes are low. Low database writer processes can can cause the Pick Slip report to error when there are large amounts of serial numbers present in the report.',
      p_solution               => '<ul><li>Refer to [2021012/KB720586] - Pick Slip Report (PDF Version) Is Erroring out When Large Number of Serial Numbers Are Present (above 15000), for full details.</li></ul>',
      p_success_msg            => 'No issues found with DB Writer Processes.',
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
debug('end add_signature: LOGPR_DB_WRITER_PROCESSES');



debug('begin add_signature: LOGPR_ATO_ITEM_NOT_READY_TO_RELEASE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9705',
      p_sig_id                 => 'LOGPR_ATO_ITEM_NOT_READY_TO_RELEASE',
      p_sig_sql                => 'select wdd.source_header_number,wdd.source_line_number,
   wdd.source_line_id,wdd.delivery_detail_id,
   wdd.released_status,oel.flow_status_code
from wsh_delivery_details wdd,
   oe_order_lines_all oel
where wdd.source_line_id = oel.line_id
   and wdd.source_code = ''OE''
   and oel.shippable_flag = ''Y''
   and wdd.container_flag = ''N''
   and oel.ato_line_id is not null
   and wdd.released_status = ''N''
   and oel.flow_status_code IN(''AWAITING_SHIPPING'',''PRODUCTION_OPEN'')
   and wdd.source_header_id =  ##$$SOHEADERID$$##
   and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)',
      p_title                  => 'WSH Delivery Details associated with ATO Item are marked as Not ready to Release',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Delivery details associated with ATO items are marked as "Not Ready to Release".',
      p_solution               => 'Sales order lines containing ATO items are not progressing from Supply Eligible to Awaiting Shipping. The status for the associated delivery detail remains in a status of Not Ready to Release instead of Ready to Release.  Because of this the pick release program does not pick the lines. Refer to [551838/KB781389] for solution details.',
      p_success_msg            => 'There are no delivery details associated with ATO Items are marked as Not Ready to Release.',
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
debug('end add_signature: LOGPR_ATO_ITEM_NOT_READY_TO_RELEASE');



debug('begin add_signature: LOGPR_SETUP_REL_SEQ_RULE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9916',
      p_sig_id                 => 'LOGPR_SETUP_REL_SEQ_RULE',
      p_sig_sql                => 'Select wpsr.name,wpsr.pick_sequence_rule_id,wpsr.start_date_active,wpsr.end_date_active , ool.ship_from_org_id "Warehouse"
from
wsh_shipping_parameters wsp , wsh_pick_sequence_rules wpsr , oe_order_lines_all ool
where wpsr.pick_sequence_rule_id = wsp.pick_sequence_rule_id
and wsp.organization_id = ool.ship_from_org_id
and sysdate not between trunc(nvl(start_date_active, sysdate)) 
and nvl(end_date_active, trunc(sysdate)+1)
and ool.header_id = ##$$SOHEADERID$$##
and ool.line_id = NVL(''##$$SOLINEID$$##'' , ool.line_id)',
      p_title                  => 'Release Sequence Rule Effective Dates Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Release Sequence Rule attached to the Shipping Parameters of the Shipping Organization is end dated. This will cause the Picking Batch to fail.',
      p_solution               => 'Release Sequence Rule used on the Picking Batch should be effective as on Date.
<ul><li>Review [443365/KB764976] Pick Release Errors With Pick Sequence Rule ID Does Not Exist, for full details.</li></ul>',
      p_success_msg            => 'Release Sequence Rule attached to the Shipping Parameters of the Shipping Organization is active.',
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
debug('end add_signature: LOGPR_SETUP_REL_SEQ_RULE');



debug('begin add_signature: LOGPR_CORRUPTION_SI_YES_MISSING_DD');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9753',
      p_sig_id                 => 'LOGPR_CORRUPTION_SI_YES_MISSING_DD',
      p_sig_sql                => 'SELECT l.line_number || ''.'' || l.shipment_number || ''.''|| l.option_number || ''.'' || l.component_number || ''.''|| l.service_number "line",
  l.open_flag "Line Open",
  l.shipping_interfaced_flag "SO Line Shipping Interfaced"
 FROM OE_ORDER_LINES_ALL l
 WHERE l.open_flag = ''Y''
  AND l.shipping_interfaced_flag = ''Y''
  AND l.shippable_flag = ''Y''
  AND NOT EXISTS (SELECT ''Y''
  FROM WSH_DELIVERY_DETAILS
  WHERE source_header_id = l.header_id
  AND   source_line_id = l.line_id )
  AND l.header_id = ##$$SOHEADERID$$##
  and l.line_id = NVL(''##$$SOLINEID$$##'' , l.line_id)',
      p_title                  => 'Order Lines with Shipping Interface Done but Delivery Details Missing',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are Shippable Lines with the Shipping Interface completed, but Delivery Detail Lines are missing. Shipping Interface flag = Y on order line but there are no delivery details created.  This does not allow any Shipping activities for these Lines.',
      p_solution               => 'This corruption requires a data fix to recreate the missing Delivery Detail Lines.
<ul><li>Refer to [1928042/KB723331] for more details.</li> </ul>',
      p_success_msg            => 'There are no Lines in Awaiting Shipping status with missing Delivery Lines.',
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
debug('end add_signature: LOGPR_CORRUPTION_SI_YES_MISSING_DD');



debug('begin add_signature: LOGPR_CORRUPTION_DD_RELWHSE_MO_NOTEXISTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9741',
      p_sig_id                 => 'LOGPR_CORRUPTION_DD_RELWHSE_MO_NOTEXISTS',
      p_sig_sql                => 'SELECT wdd.source_header_number
      , wdd.delivery_detail_id
      , wdd.source_header_id
      , wdd.source_line_id
      , wdd.source_line_number
      , wdd.organization_id
   FROM wsh_delivery_details wdd
      , mtl_txn_request_lines mtrl
  WHERE mtrl.line_id = wdd.move_order_line_id
    AND wdd.source_code = ''OE''
    AND wdd.move_order_line_id IS NOT NULL
    AND wdd.released_status = ''S''
    AND NOT EXISTS ( SELECT 1
                       FROM mtl_txn_request_headers mtrh
                      WHERE mtrh.header_id = mtrl.header_id)
    AND wdd.source_header_id = ##$$SOHEADERID$$##
    and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)',
      p_title                  => 'Delivery Detail in Release to Warehouse Status with No Move Order',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are Delivery Line(s) in Released to Warehouse status but Move Order is missing.
The missing Move Order does not allow these Lines to be Staged/Backordered.',
      p_solution               => 'This corruption requires a data fix to re-create the missing Move Order.
<ul><li>Refer to [1165324/KB732682] for more details.</li> </ul>',
      p_success_msg            => 'There are no Delivery Lines in a Release to Warehouse status with missing Move Orders.',
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
debug('end add_signature: LOGPR_CORRUPTION_DD_RELWHSE_MO_NOTEXISTS');



debug('begin add_signature: LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_NOTEXISTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10064',
      p_sig_id                 => 'LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_NOTEXISTS',
      p_sig_sql                => 'SELECT wdd.source_header_number,wdd.delivery_detail_id
      , wdd.source_header_id
      , wdd.source_line_id
      , wdd.source_line_number
      , wdd.organization_id
FROM wsh_delivery_details wdd
WHERE source_code = ''OE''
    AND wdd.move_order_line_id IS NOT NULL
    AND released_status = ''S''
    AND NOT EXISTS (SELECT 1
                      FROM mtl_txn_request_lines mtrl
                     WHERE mtrl.line_id = wdd.move_order_line_id )
AND wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)',
      p_title                  => 'Delivery Detail in Release to Warehouse Status but Associated Move Order Line Does Not Exist',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Delivery Line(s) are in Release to Warehouse Status but associated Move Order Line(s) are missing. This corruption neither allows the Lines to be Staged nor be Backordered.',
      p_solution               => 'This corruption requires a data fix , to backorder the stuck Delivery Detail. Once backordered , the Delivery Details can be pick released again and shipped.
<ul><li>Refer to [1583914/KB627141] for more details.</li> </ul>',
      p_success_msg            => 'There are no Delivery Lines in Release to Warehouse status with missing Move Order Lines.',
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
debug('end add_signature: LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_NOTEXISTS');



debug('begin add_signature: LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_CLOSED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9740',
      p_sig_id                 => 'LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_CLOSED',
      p_sig_sql                => 'Select wdd.source_header_number "Order Number", wdd.source_line_id, wdd.delivery_detail_id, wdd.move_order_line_id,
mtrl.creation_date,mtrl.last_update_date
from wsh_delivery_details wdd,mtl_txn_request_lines mtrl
where wdd.source_code = ''OE''
and wdd.released_status = ''S''
and wdd.move_order_line_id = mtrl.line_id 
and mtrl.line_status = 5
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)',
      p_title                  => 'Delivery Detail in Release to Warehouse Status but Associated Move Order Line Is Closed',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Delivery Line(s) are in Release to Warehouse Status but associated Move Order Line(s) are Closed. This corruption neither allows the Lines to be Staged or Backordered.',
      p_solution               => 'This corruption requires a data fix , to backorder the stuck Delivery Detail. Once backordered , the Delivery Details can be pick released again and shipped.
<ul><li>Refer to [1583914/KB627141] for more details.</li></ul>',
      p_success_msg            => 'There are no Delivery Lines in Release to Warehouse status with Closed Move Order Lines.',
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
debug('end add_signature: LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_CLOSED');



debug('begin add_signature: LOGPR_CORRUPTION_DDS_ZERO_REQ_QTY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9695',
      p_sig_id                 => 'LOGPR_CORRUPTION_DDS_ZERO_REQ_QTY',
      p_sig_sql                => 'select wdd.source_header_number "Order Number", wdd.source_line_number "Order Line Number", wdd.source_line_id, wdd.delivery_detail_id, wdd.released_status, wdd.creation_date
from wsh_delivery_details wdd, oe_order_lines_all ol
where wdd.source_line_id = ol.line_id
and wdd.source_code = ''OE''
and wdd.released_status <> ''D''
and ol.open_flag = ''Y''
and ol.ordered_quantity = wdd.src_requested_quantity
and nvl(wdd.ship_tolerance_above, 0) = 0
and wdd.requested_quantity = 0
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)',
      p_title                  => 'Delivery Lines (Not Cancelled) with Zero Requested Quantity',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are non Cancelled Delivery Lines with Zero Requested Quantity , these will cause Pick Release to fail with "Exception occurred in WSH_PICK_LIST" error.',
      p_solution               => '<ul><li>Refer to [2346819/KB721732] Pick Batch Fails with WSH_PICK_LIST Exception, Unable to Inactivate Item, or Close Internal Requisition.</li> </ul>',
      p_success_msg            => 'There are no open Delivery Lines with zero requested quantity.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: LOGPR_CORRUPTION_DDS_ZERO_REQ_QTY');



debug('begin add_signature: LOGPR_INVALID_SHIPPING_PACKAGES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9979',
      p_sig_id                 => 'LOGPR_INVALID_SHIPPING_PACKAGES',
      p_sig_sql                => 'Select object_name , status
from dba_objects
where object_name in (''WSH_PICK_LIST'',''WSH_DELIVERY_DETAILS_UTILITIES'' , ''WSH_SHIPMENT_REQUEST_PKG'')
and status = ''INVALID''',
      p_title                  => 'Shipping Invalids Exist Related to Pick Release Process',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Invalid Shipping Objects that can cause Pick Release process to fail with ORA-06508 error.',
      p_solution               => 'Ensure these WSH Shipping Objects are Valid for Picking to be successful.
<ul><li>Refer to [757227/KB766994] for full details.</li></ul>',
      p_success_msg            => 'There are no WSH Shipping Invalids that can fail the Pick Release process.',
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
debug('end add_signature: LOGPR_INVALID_SHIPPING_PACKAGES');



debug('begin add_signature: LOGPR_HOUSEKEEPING_EXCEPTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10000',
      p_sig_id                 => 'LOGPR_HOUSEKEEPING_EXCEPTIONS',
      p_sig_sql                => 'SELECT count(*)
FROM wsh_exceptions
WHERE status <> ''CLOSED''',
      p_title                  => 'Open Shipping Exceptions',
      p_fail_condition         => '[count]>[0]',
      p_problem_descr          => 'Open Shipping Exceptions exist. Open Shipping Exceptions should be purged regularly. Keeping the size of WSH_EXCEPTIONS under 100,000 records will improve system performance and prevent wasting computer resources.',
      p_solution               => '<ul><li>Refer to [1576170/KB626443] - How To Purge Shipping Exceptions - WSH_EXCEPTIONS Master Note, for full details.</li></ul>',
      p_success_msg            => 'No open shipping exceptions exist.',
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
debug('end add_signature: LOGPR_HOUSEKEEPING_EXCEPTIONS');



debug('begin add_signature: LOGPR_CORRUPTION_ORPHAN_SHIPSETS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9999',
      p_sig_id                 => 'LOGPR_CORRUPTION_ORPHAN_SHIPSETS',
      p_sig_sql                => 'select wdd.source_header_number, wdd.delivery_detail_id, wdd.released_status, wdd.ship_set_id
from wsh_delivery_details wdd,oe_order_lines_all ool
where wdd.source_header_id = ool.header_id
and   wdd.source_line_id   = ool.line_id
and   wdd.source_code      = ''OE''
and   wdd.ship_set_id      = ool.ship_set_id
and   wdd.released_status in (''R'', ''B'')
and   wdd.ship_set_id is not null
and   wdd.source_header_id =  ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)
and   not exists (select ''Y''
from oe_sets os
where os.set_id = wdd.ship_set_id
and os.set_type = ''SHIP_SET'')',
      p_title                  => 'Order Lines/Delivery Lines Are Assigned to Ship Sets but the Sets Are Missing in OE_SETS',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Order Lines/Delivery Lines assigned to Ship Sets but the Set Information is missing. This corruption makes these Lines orphan , causing Pick Release to fail.',
      p_solution               => 'Remove the ship set from the order line and then put it back on. This will stop the error at the time of pick release.
<ul><li>Refer to [377059/KB706365] for more details.</li> </ul>',
      p_success_msg            => 'There are no orphan Order Lines/Delivery Lines assigned to Ship Sets, for which the Set Information is missing.',
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
debug('end add_signature: LOGPR_CORRUPTION_ORPHAN_SHIPSETS');



debug('begin add_signature: LOGPR_SETUP_SALESORDERS_FF');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9983',
      p_sig_id                 => 'LOGPR_SETUP_SALESORDERS_FF',
      p_sig_sql                => 'SELECT fs.segment_num SEGM_NUM, fs.segment_name SEGM_NAME, fs.required_flag REQUIRED,fs.application_column_name, fv.flex_value_set_name VALUE_SET, fv.validation_type VALIDATION
FROM fnd_id_flex_structures_vl ff, fnd_id_flex_segments fs, fnd_flex_value_sets fv
WHERE ff.id_flex_code = ''MKTS''
AND ff.application_id = fs.application_id
AND ff.id_flex_code = fs.id_flex_code
AND ff.id_flex_num = fs.id_flex_num
AND fv.flex_value_set_id(+) = fs.flex_value_set_id
AND (ff.enabled_flag <> ''Y'' 
     OR fs.enabled_flag <> ''Y''
     OR fs.application_column_name not in (''SEGMENT1'',''SEGMENT2'',''SEGMENT3''))',
      p_title                  => 'Sales Orders Key Flexfield Structure',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Segments are not correctly Mapped in Sales Order Flexfield Structure, this causes Pick Release to fail with "No Mtl_Sales_Order ID found for oe header".',
      p_solution               => 'Ensure the Sales Orders Key Flexfield has only 3 Segments and these are mapped correctly.
<ul><li>Review [398385/KB720416] Pick Release Backorders Sales Order Lines, Error in Log File "No Mtl_Sales_Order ID found for oe header", for full details.</li></ul>',
      p_success_msg            => 'Segments are correctly mapped for the Sales Order Flexfield.',
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
debug('end add_signature: LOGPR_SETUP_SALESORDERS_FF');



debug('begin add_signature: EBS_MFG_INV_LOGPR_WSH_TRANS_MOQD_SECONDARY_ZERO');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '23709',
      p_sig_id                 => 'EBS_MFG_INV_LOGPR_WSH_TRANS_MOQD_SECONDARY_ZERO',
      p_sig_sql                => 'SELECT
 moqd.inventory_item_id,
 moqd.organization_id,
 moqd.primary_transaction_quantity,
 moqd.secondary_transaction_quantity,
 moqd.subinventory_code,
 moqd.revision,
 moqd.locator_id,
 moqd.lot_number 
FROM
 mtl_onhand_quantities_detail moqd 
WHERE 
 moqd.secondary_transaction_quantity is not null
 AND exists (select 1 from mtl_system_items_b msib
            where msib.organization_id = moqd.organization_id
            and msib.inventory_item_id = moqd.inventory_item_id
            and msib.dual_uom_control = 1 )
 AND (moqd.organization_id,moqd.inventory_item_id) IN
            (SELECT wdd.organization_id,
              wdd.inventory_item_id
              FROM   wsh_delivery_details wdd
              WHERE  wdd.source_code    = ''OE''
              AND    wdd.released_status IN ( ''R'',''B'',''S'')
              AND    wdd.source_header_id = ##$$SOHEADERID$$##
              AND    wdd.source_line_id   = NVL(''##$$SOLINEID$$##'', wdd.source_line_id)) 
',
      p_title                  => 'No Secondary Controls',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There is one or more onhand record with zero quantity in the secondary quantity but the item has no secondary quantity controls. This may not have an immediate impact but long-term can cause issues with allocating quantities. Some users hit negative balance errors when the secondary quantity incorrectly has zero quantity. Note that the allocation error is more common after R12.2.9 but the data issue could exist in other releases. ',
      p_solution               => '<ul><li>One of two actions will need to be taken to resolve the issue. Either you could issue out the quantity and receive it again to ensure the secondary quantity is cleared or you can run a datafix to clear the secondary quantity. If a datafix is required, please log a service request to get assistance from Oracle Support. See the Solution in [2724982/KB793403]- Non Dual UOM Item With Secondary Quantity Showing 0 Causing Allocation or Pick Release Failure.</li></ul>
',
      p_success_msg            => 'There are no quantities found where the secondary quantity is incorrectly populated as zero for a non-secondary tracked item. Refer to [2724982/KB793403] for more details. 
',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_INV_LOGPR_WSH_TRANS_MOQD_SECONDARY_ZERO');



debug('begin add_signature: EBS_MFG_GEN_ONT_WSH_INV_SEQUENCES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24800',
      p_sig_id                 => 'EBS_MFG_GEN_ONT_WSH_INV_SEQUENCES',
      p_sig_sql                => 'SELECT sequence_owner "Owner",
       sequence_name "Name",
       cycle_flag "Cycle Flag", 
       last_number "Last Number",
       max_value "Max Value",
       round ((100 / max_value) * last_number, 2) AS "% Used",
       round (100 - ((100 / max_value) * last_number), 2) AS "% Available"
  FROM dba_sequences
 WHERE sequence_owner IN (''ONT'', ''WSH'', ''INV'', ''PO'', ''WMS'', ''QP'',''BOM'')
   AND round ((100 / max_value) * last_number, 2) >= 70
   AND sequence_name <> ''BOM_CTO_ORDER_LINES_S1''
 ORDER BY 5 DESC, 2',
      p_title                  => 'ONT WSH QP INV PO WMS BOM Sequences',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Highlighted lines are getting close (=>70%) to their Max Value defined in sequences.<br>
If assistance is needed, log an SR with Sequence Owner product. 


',
      p_solution               => 'Refer to [2989870/KA1025]',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '17'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_GEN_ONT_WSH_INV_SEQUENCES');



debug('begin add_signature: LOGPR_WSH_PICKING_BATCHES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9988',
      p_sig_id                 => 'LOGPR_WSH_PICKING_BATCHES',
      p_sig_sql                => 'SELECT BATCH_ID,      
NAME,      
BACKORDERS_ONLY_FLAG,
DOCUMENT_SET_ID,
EXISTING_RSVS_ONLY_FLAG,
SHIPMENT_PRIORITY_CODE,
SHIP_METHOD_CODE,
CARRIER_ID,
CUSTOMER_ID,
SHIP_TO_LOCATION_ID,
ORDER_HEADER_ID,
ORDER_LINE_ID,
SHIP_SET_NUMBER,
INVENTORY_ITEM_ID,
ORDER_TYPE_ID,
FROM_REQUESTED_DATE,
TO_REQUESTED_DATE,
FROM_SCHEDULED_SHIP_DATE,
TO_SCHEDULED_SHIP_DATE,
SUBINVENTORY,
SHIP_FROM_LOCATION_ID,
ORGANIZATION_ID,
DEFAULT_STAGE_SUBINVENTORY,
DEFAULT_STAGE_LOCATOR_ID,
PICK_FROM_SUBINVENTORY,
PICK_FROM_LOCATOR_ID,
AUTODETAIL_PR_FLAG,
AUTO_PICK_CONFIRM_FLAG,
TRIP_ID,
TRIP_STOP_ID,
DELIVERY_ID,
DELIVERY_DETAIL_ID,
PICK_GROUPING_RULE_ID,
PICK_SEQUENCE_RULE_ID,
PARTIAL_ALLOWED_FLAG,
INCLUDE_PLANNED_LINES,
AUTOCREATE_DELIVERY_FLAG,
ATTRIBUTE_CATEGORY,
CREATION_DATE,
CREATED_BY,
REQUEST_ID,
PROJECT_ID,
TASK_ID,
AUTO_SEND_DOC_FLAG,
NON_PICKING_FLAG,
SHIP_CONFIRM_RULE_ID,
AUTOPACK_FLAG,
AUTOPACK_LEVEL,
DELIVERY_NAME_LO,
DELIVERY_NAME_HI,
BOL_NUMBER_LO,
BOL_NUMBER_HI,
INTMED_SHIP_TO_LOC_ID,
POOLED_SHIP_TO_LOC_ID,
FOB_CODE,
FREIGHT_TERMS_CODE,
PICKUP_DATE_LO,
PICKUP_DATE_HI,
DROPOFF_DATE_LO,
DROPOFF_DATE_HI,
PLANNED_FLAG,
SELECTED_BATCH_ID,
TASK_PLANNING_FLAG,
APPEND_FLAG,
REGION_ID,
ZONE_ID,
CATEGORY_ID,
CATEGORY_SET_ID,
AC_DELIVERY_CRITERIA,
REL_SUBINVENTORY,
SHIP_SET_SMC_FLAG,
TASK_PRIORITY,
ALLOCATION_METHOD,
CROSSDOCK_CRITERIA_ID,
ACTUAL_DEPARTURE_DATE,
DYNAMIC_REPLENISHMENT_FLAG
from wsh_picking_batches
where batch_id = ##$$BATCHID$$##',
      p_title                  => 'Picking Batches',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'List of Picking Batch details per input Batch ID.',
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
debug('end add_signature: LOGPR_WSH_PICKING_BATCHES');



debug('begin add_signature: EBS_MFG_OM_LOGPR_BATCH_VERSES_DELIVERY_DETAIL');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '29033',
      p_sig_id                 => 'EBS_MFG_OM_LOGPR_BATCH_VERSES_DELIVERY_DETAIL',
      p_sig_sql                => 'select ''Picking Batch Info'' "Batch / Delivery Detail",
      BATCH_ID "Batch Id",  									        
      ORDER_HEADER_ID "SO Header Id",  								        
      ORDER_LINE_ID "SO Line Id",
      DELIVERY_DETAIL_ID "Delivery Detail Id",
      DELIVERY_ID "Delivery Id", 
      TRIP_ID "Trip Id",  										        
      TRIP_STOP_ID "Stop Id",
      DECODE(BACKORDERS_ONLY_FLAG, ''E'',''E: Unreleased'', ''I'', ''I: All'', ''O'', ''O: Backordered'', ''M'', ''M: Replenishment Completed'') "Back Orders Only/ Rel Status",  								        
      EXISTING_RSVS_ONLY_FLAG "Rerv Only?/ Reserv Exists?",  							        
      SHIPMENT_PRIORITY_CODE "Shipment Priority Code",  								        
      SHIP_METHOD_CODE "Ship Method Code",  								        
      CARRIER_ID "Carrier Id",  									        
      CUSTOMER_ID "Customer Id",  									        
      SHIP_TO_LOCATION_ID "Ship To Location Id",  								        
      SHIP_SET_NUMBER "Ship Set",  								        
      INVENTORY_ITEM_ID "Inventory Item Id",  								        
      ORDER_TYPE_ID "Order Type Id",  									        
      to_char(FROM_REQUESTED_DATE,''DD-MON-YYYY HH24:MI:SS'')      "Fm Req Date/ Date Requested",  	        
      to_char(TO_REQUESTED_DATE,''DD-MON-YYYY HH24:MI:SS'')        "To Req Date/ Date Requested",  	        
      to_char(FROM_SCHEDULED_SHIP_DATE,''DD-MON-YYYY HH24:MI:SS'') "Fm Sch Ship Dt/ Date Scheduled",      
     to_char(TO_SCHEDULED_SHIP_DATE,''DD-MON-YYYY HH24:MI:SS'')   "To Sch Ship Dt/ Date Scheduled",         
     SUBINVENTORY "SubInventory",  									        
     SHIP_FROM_LOCATION_ID "Ship From Location Id",  								        
     ORGANIZATION_ID "Organization Id",  									        								        
     INCLUDE_PLANNED_LINES "Inc Plnd Lines/ Delivery Id",  								        
     REQUEST_ID "Request Id",  									        
     PROJECT_ID "Project Id",  									        
     TASK_ID "Task Id" 										        
from   WSH_PICKING_BATCHES 									
where batch_id =  ##$$BATCHID$$##          								
union all										
select ''Delivery Detail Info'' "Batch / Delivery Detail",    
    wdd.BATCH_ID "Batch Id",
    wdd.source_header_id "SO Header Id",  
    wdd.source_line_id "SO Line Id",
    wda.delivery_detail_id "Delivery Detail Id",
    wde.delivery_id "Delivery Id",    
    wts.trip_id "Trip Id",    
    wts.stop_id "Stop Id",
    wdd.released_status|| '': ''
       || ( SELECT meaning
            FROM wsh_lookups
            WHERE lookup_type = ''PICK_STATUS''
              AND lookup_code = wdd.released_status ) "Back Orders Only/ Rel Status",  
    NVL((Select ''Y'' 
                  from MTL_SALES_ORDERS MSORD1,
                       MTL_RESERVATIONS MR , 
                       OE_TRANSACTION_TYPES_TL OTTT
                 where MSORD1.SEGMENT1 = WDD.SOURCE_HEADER_NUMBER 
                    AND MSORD1.SEGMENT2  = OTTT.NAME 
                    AND OTTT.TRANSACTION_TYPE_ID  = WDD.SOURCE_HEADER_TYPE_ID 
                    AND OTTT.LANGUAGE  = (SELECT language_code FROM fnd_languages WHERE installed_flag = ''B'')  
                    AND MSORD1.SEGMENT3 = ''ORDER ENTRY'' 
                    AND MR.DEMAND_SOURCE_HEADER_ID = MSORD1.SALES_ORDER_ID 
                    AND MR.DEMAND_SOURCE_LINE_ID   = WDD.SOURCE_LINE_ID 
                    AND NVL(MR.SHIP_READY_FLAG, 2) = 2 
                    AND MR.PRIMARY_RESERVATION_QUANTITY - NVL(MR.DETAILED_QUANTITY,0) > 0 
                    AND rownum = 1),''N'') "Rerv Only?/ Reserv Exists?",  
    wdd.shipment_priority_code "Shipment Priority Code",   
    wdd.ship_method_code "Ship Method Code",  
    wdd.carrier_id "Carrier Id",  
    wdd.customer_id  "Customer Id",  
    wdd.ship_to_location_id "Ship To Location Id",  
    wdd.ship_set_id "Ship Set",  
    wdd.inventory_item_id "Inventory Item Id",  
    wdd.source_header_type_id "Order Type Id",  
    to_char(wdd.date_requested,''DD-MON-YYYY HH24:MI:SS'') "Fm Req Date/ Date Requested", 
    to_char(wdd.date_requested,''DD-MON-YYYY HH24:MI:SS'') "To Req Date/ Date Requested", 
      to_char(wdd.date_scheduled,''DD-MON-YYYY HH24:MI:SS'') "Fm Sch Ship Dt/ Date Scheduled",
    to_char(wdd.date_scheduled,''DD-MON-YYYY HH24:MI:SS'') "To Sch Ship Dt/ Date Scheduled",
    wdd.subinventory "SubInventory",
    wdd.ship_from_location_id "Ship From Location Id", 
    wdd.organization_id "Organization Id",    
  to_char(wde.delivery_id) "Inc Plnd Lines/ Delivery Id",
  wdd.REQUEST_ID "Request Id", 
  wdd.project_id "Project Id", 
  wdd.task_id "Task Id"
          from   wsh_delivery_details     wdd,  
                 wsh_new_deliveries       wde,  
                 wsh_delivery_assignments wda,  
                 wsh_delivery_legs        wlg,  
                 wsh_trip_stops           wts 
          where  WTS.STOP_ID(+)                 = WLG.PICK_UP_STOP_ID  
          AND    WLG.DELIVERY_ID(+)             = WDE.DELIVERY_ID  
          AND    WDE.DELIVERY_ID(+)             = WDA.DELIVERY_ID  
          AND    WDA.DELIVERY_DETAIL_ID(+)      = WDD.DELIVERY_DETAIL_ID  
          and    wdd.source_code = ''OE''
          AND    WDD.source_header_id = ##$$SOHEADERID$$## 
          AND    wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id) ',
      p_title                  => 'Picking Batch Verses Delivery Detail Information',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Picking Batch Verses Delivery Detail Information',
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
debug('end add_signature: EBS_MFG_OM_LOGPR_BATCH_VERSES_DELIVERY_DETAIL');



debug('begin add_signature: LOGPR_DD_NON_TRANSACTABLE_ITEM');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9748',
      p_sig_id                 => 'LOGPR_DD_NON_TRANSACTABLE_ITEM',
      p_sig_sql                => 'select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
msi.inventory_item_id,
msi.description,
msi.MTL_TRANSACTIONS_ENABLED_FLAG
from wsh_delivery_details wdd,
     mtl_system_items msi
where wdd.source_code = ''OE''
and wdd.inventory_item_id = msi.inventory_item_id
and wdd.organization_id = msi.organization_id
and wdd.released_status in ( ''R'',''B'')
and msi.MTL_TRANSACTIONS_ENABLED_FLAG <> ''Y''
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)
and exists ( Select 1
               from wsh_picking_batches wpb
              where wpb.batch_id = ##$$BATCHID$$##
           )',
      p_title                  => 'Delivery Detail(S) with Non-transactable Item',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'WSH Delivery detail within the batch has non-transactable item.',
      p_solution               => '<ul><li>Refer to [1268622/KB736470] Pick Release Fails When Picking a Range of Orders That Includes a Non-Transactable Item, for full details.</li></ul>',
      p_success_msg            => 'There are no delivery details within the batch exist with non-transactable items.',
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
debug('end add_signature: LOGPR_DD_NON_TRANSACTABLE_ITEM');



debug('begin add_signature: LOGPR_CRITERIA_INCLUDE_PLANNED_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9744',
      p_sig_id                 => 'LOGPR_CRITERIA_INCLUDE_PLANNED_LINES',
      p_sig_sql                => 'select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description,
wda.delivery_id,
wda.delivery_assignment_id
from wsh_delivery_details wdd,
     wsh_delivery_assignments wda
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.delivery_detail_id = wda.delivery_detail_id
and wda.delivery_id is not null
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id) 
and exists ( Select 1
               from wsh_picking_batches wpb
              where NVL(wpb.include_planned_lines,''N'') = ''N''
                and wpb.batch_id = ##$$BATCHID$$##
           )',
      p_title                  => 'WSH Pick Release Criteria Mismatch - Include Assigned Lines',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Pick Release Criteria does not Include Assigned Lines but there exists delivery details already assigned to a delivery.',
      p_solution               => '<ul><li>Refer to [2064079/KB751370] Pick Release Succeeds but Nothing is Pick Released.</li> </ul>',
      p_success_msg            => 'There are no delivery details with delivery assigned Or criteria doest includes planned lines.',
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
debug('end add_signature: LOGPR_CRITERIA_INCLUDE_PLANNED_LINES');



debug('begin add_signature: LOGPR_WORKDAY_CALENDAR_NOT_ASSOICATED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9743',
      p_sig_id                 => 'LOGPR_WORKDAY_CALENDAR_NOT_ASSOICATED',
      p_sig_sql                => 'select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description
from wsh_delivery_details wdd
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id) 
and exists ( Select 1
               from wsh_picking_batches wpb
              where (wpb.from_scheduled_ship_date is not null Or wpb.to_scheduled_ship_date is not null)
                and wpb.batch_id = ##$$BATCHID$$##
           )
and not exists ( select 1
                   from WSH_CALENDAR_ASSIGNMENTS wca
                  where wca.association_type = ''ORGANIZATION''
                    and wca.organization_id = wdd.organization_id
                    and wca.calendar_type = ''SHIPPING''
                    and wca.calendar_code is not null
                    and enabled_flag = ''Y''
                )',
      p_title                  => 'WSH Workday calendar is not associated to the Shipping Calendar',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The Workday calendar is not associated to the Shipping Calendar at the Organization level.',
      p_solution               => '<ul><li>Refer to [467158/KB724971] Pick Release Rule Using Future Date Is Ignoring Workday Calendar, for full details.</li></ul>',
      p_success_msg            => 'There is no issue with Workday Calendar Association.',
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
debug('end add_signature: LOGPR_WORKDAY_CALENDAR_NOT_ASSOICATED');



debug('begin add_signature: LOGPR_PICKSLIP_REPORT_PRINT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9717',
      p_sig_id                 => 'LOGPR_PICKSLIP_REPORT_PRINT',
      p_sig_sql                => 'select wpb.batch_id, wpb.name,  wpb.organization_id, wpb.document_set_id, wrs.name
from wsh_picking_batches wpb,
     WSH_REPORT_SETS wrs
where wpb.document_set_id is not null
and wpb.document_set_id = wrs.report_set_id
and wpb.batch_id = ##$$BATCHID$$##',
      p_title                  => 'Pick Slip Is Printed with No Information When No Pick Data Is Processed',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Pick Slip Report prints empty report with only a header when no data is found from the picking process. If there is no data, the report should print with the message No Data Found, not be blank.',
      p_solution               => '<ul><li>Review [1354891/KB756522] Pick Slip Is Printed When No Data Is Found, for full details.</li></ul>',
      p_success_msg            => 'No pick data process setup issues exist.',
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
debug('end add_signature: LOGPR_PICKSLIP_REPORT_PRINT');



debug('begin add_signature: LOGPR_CRITERIA_SHIP_METHOD');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9716',
      p_sig_id                 => 'LOGPR_CRITERIA_SHIP_METHOD',
      p_sig_sql                => 'select wdd.ship_method_code,
wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description
from wsh_delivery_details wdd
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id) 
and exists ( Select 1
               from wsh_picking_batches wpb
              where wpb.ship_method_code is not null
                and NVL(wdd.ship_method_code, ''X'') <> wpb.ship_method_code
                and wpb.batch_id =  ##$$BATCHID$$##
           )',
      p_title                  => 'Pick Release Criteria Mismatch - Ship Method',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Ship Method on the Pick Release Criteria does not match with the Ship Method on the Delivery Detail(s).',
      p_solution               => '<ul><li>Refer to [2000129/KB733878] Null or Changed Ship Method Causes Line To Not Be Pick Released And Remain in Ready to Release Status, for full details.</li></ul>',
      p_success_msg            => 'There are no delivery details with mismatched Ship Method.',
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
debug('end add_signature: LOGPR_CRITERIA_SHIP_METHOD');



debug('begin add_signature: LOGPR_CRITERIA_REL_SUBINVENTORY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9715',
      p_sig_id                 => 'LOGPR_CRITERIA_REL_SUBINVENTORY',
      p_sig_sql                => 'select wdd.subinventory,
wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description
from wsh_delivery_details wdd
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id) 
and exists ( Select 1
               from wsh_picking_batches wpb
              where  wpb.rel_subinventory is not null
               and NVL(wdd.subinventory, ''X'') <> wpb.rel_subinventory
                and wpb.batch_id =  ##$$BATCHID$$##
           )',
      p_title                  => 'Pick Release Completes but Status Is Still Awaiting Shipping',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Release Subinventory on the Pick Release Criteria does not match with the Subinventory on the Shipping Delivery Detail(s).',
      p_solution               => '<ul><li>Follow the Solution in [1469465/KB765900] ''Pick Selection List Generation'' completes without error, but Line Status is still ''Awaiting Shipping".</li> </ul>',
      p_success_msg            => 'There are no delivery details with mismatched Release Subinventory.',
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
debug('end add_signature: LOGPR_CRITERIA_REL_SUBINVENTORY');



debug('begin add_signature: LOGPR_CRITERIA_SHIP_FROM_LOCATION');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9713',
      p_sig_id                 => 'LOGPR_CRITERIA_SHIP_FROM_LOCATION',
      p_sig_sql                => 'select wdd.Ship_From_Location_Id,
wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description
from wsh_delivery_details wdd
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)
and exists ( Select 1
               from wsh_picking_batches wpb
              where wpb.Ship_From_Location_Id is not null
                and NVL(wdd.Ship_From_Location_Id, -1) <> wpb.Ship_From_Location_Id
                and wpb.batch_id = ##$$BATCHID$$##
           )',
      p_title                  => 'Pick Release Criteria Mismatch - Ship From Location',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Ship From Location on the Pick Release Criteria does not match with the Ship From Location on the Delivery Detail(s).',
      p_solution               => '<ul><li>Refer to [1318666/KB732696] How to Pick Release Orders Where the Ship_From_Location_ID has Been Changed.</li></ul>',
      p_success_msg            => 'There are no delivery details with mismatched Ship From Location.',
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
debug('end add_signature: LOGPR_CRITERIA_SHIP_FROM_LOCATION');



debug('begin add_signature: LOGPR_CRITERIA_SHIPMENT_PRIORITY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9683',
      p_sig_id                 => 'LOGPR_CRITERIA_SHIPMENT_PRIORITY',
      p_sig_sql                => 'select wdd.shipment_priority_code,
wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description
from wsh_delivery_details wdd
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id) 
and exists ( Select 1
               from wsh_picking_batches wpb
              where wpb.shipment_priority_code is not null
                and NVL(wdd.shipment_priority_code, ''-X'') <> wpb.shipment_priority_code
                and wpb.batch_id = ##$$BATCHID$$## 
           )',
      p_title                  => 'Pick Release Criteria Mismatch - Shipment Priority',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Shipment Priority on the Pick Release Criteria does not match with the Shipment priority on the Delivery Detail(s).',
      p_solution               => 'Pick release criteria is defined in the Pick Release form or the Release Rules form which is not matching with the Shipment priority on the Delivery Detail(s).
<ul><li>Refer to [2064079/KB751370] Point# D. A Shipment Priority was specified for pick release, for full details.</li></ul>',
      p_success_msg            => 'There are no delivery details with mismatched Shipment Priority.',
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
debug('end add_signature: LOGPR_CRITERIA_SHIPMENT_PRIORITY');



debug('begin add_signature: LOGPR_SETUP_RESTRICT_SUBINV');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9915',
      p_sig_id                 => 'LOGPR_SETUP_RESTRICT_SUBINV',
      p_sig_sql                => 'Select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id
from wsh_delivery_details wdd,mtl_system_items_b msib
where wdd.source_code = ''OE''
and wdd.inventory_item_id = msib.inventory_item_id
and wdd.organization_id = msib.organization_id
and nvl(msib.restrict_subinventories_code,2) = 1
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)
and not exists ( Select 1 
                  from mtl_item_sub_inventories misv,wsh_picking_batches wpb
                  where misv.inventory_item_id = wdd.inventory_item_id 
                    and misv.organization_id = wdd.organization_id
     and (misv.secondary_inventory = nvl(wpb.subinventory,''Not_Exists'')
or misv.secondary_inventory = nvl(wpb.default_stage_subinventory,''Not_Exists''))
                    and wpb.batch_id = ##$$BATCHID$$##
               )',
      p_title                  => 'Checking If Restrict Subinventories Exist',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Restrict Subinventories is setup for the Item and the Pick From AND/OR the Staging Subinventory is not in the Item Subinventories list , this will cause the Picking Process to fail with no errors.',
      p_solution               => 'When using the Restrict Subinventories setup , ensure the Pick From and the Staging Subinventory is listed in the Item Subinventories List.
<ul><li>Refer to [748927/KB759092] Could not Create Move Order Line for Delivery Detail xxxxxx Error But Pick Release Completes Successfully and Line is not Picked, for full details.</li></ul>',
      p_success_msg            => 'Either the Restrict Subinventories option is not chosen or if enabled the Pick From and/or the Staging subinventories are included in the restricted subinventories list.',
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
debug('end add_signature: LOGPR_SETUP_RESTRICT_SUBINV');



debug('begin add_signature: LOGPR_SETUP_RESTRICT_LOCATOR');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9981',
      p_sig_id                 => 'LOGPR_SETUP_RESTRICT_LOCATOR',
      p_sig_sql                => 'Select wdd.source_header_number "Order Number",
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id
from wsh_delivery_details wdd,mtl_system_items_b msib
where wdd.source_code = ''OE''
and wdd.inventory_item_id = msib.inventory_item_id
and wdd.organization_id = msib.organization_id
and nvl(msib.restrict_locators_code,2) = 1
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)
and not exists ( Select 1 
                  from mtl_secondary_locators msl,wsh_picking_batches wpb
                  where msl.inventory_item_id = wdd.inventory_item_id 
                    and msl.organization_id = wdd.organization_id
     and (msl.secondary_locator = nvl(wpb.pick_from_locator_id,''Not_Exists'')
or msl.secondary_locator = nvl(wpb.default_stage_locator_id,''Not_Exists''))
                    and wpb.batch_id = ##$$BATCHID$$##
               )',
      p_title                  => 'Verify If Item Locators Are Available',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Checking if the default transaction locator for the item is defined in the specific subinventory for the Move Order Receipts default type in the Locators tab for the source inventory organization.',
      p_solution               => '<ul><li>Review [357735/KB751792] Pick Selection List Generation request completes with Warning for Item with Locator Control, for full details.</li></ul>',
      p_success_msg            => 'The default transaction locator for the item is defined in the specific subinventory for the Move Order Receipts default type in the Locators tab for the source inventory organization.',
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
debug('end add_signature: LOGPR_SETUP_RESTRICT_LOCATOR');



debug('begin add_signature: LOGPR_CRITERIA_SCHDATE_REQDATE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9685',
      p_sig_id                 => 'LOGPR_CRITERIA_SCHDATE_REQDATE',
      p_sig_sql                => 'Select wdd.DATE_SCHEDULED,
wdd.DATE_REQUESTED,
wdd.source_header_number Order_Number,
wdd.source_header_id,
wdd.source_line_number,
wdd.source_line_id,
wdd.released_status,
wdd.organization_id,
wdd.inventory_item_id,
wdd.item_description
from wsh_delivery_details wdd
where wdd.source_code = ''OE''
and wdd.released_status in ( ''R'',''B'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)
and exists ( Select 1
               from wsh_picking_batches wpb
              where ((wpb.from_Scheduled_Ship_Date is not null 
                and NVL(wdd.DATE_SCHEDULED, SYSDATE -10000) < wpb.from_Scheduled_Ship_Date)
                OR
                (wpb.to_Scheduled_Ship_Date is not null 
                and NVL(wdd.DATE_SCHEDULED, SYSDATE -10000) > wpb.to_Scheduled_Ship_Date)
                OR
                (wpb.from_Requested_Date is not null 
                and NVL(wdd.DATE_REQUESTED, SYSDATE -10000) < wpb.from_Requested_Date)
                OR
                (wpb.To_Requested_Date is not null 
                and NVL(wdd.DATE_REQUESTED, SYSDATE -10000) > wpb.To_Requested_Date))
                and wpb.batch_id = ##$$BATCHID$$##
           )',
      p_title                  => 'Pick Release Criteria Mismatch - Scheduled Ship Dates/Requested Dates',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Schedule Ship Date/Requested Date on the Delivery Line(s) do not match with the Scheduled Ship Date/Requested Date Pick Release criteria on the Picking Batch. This mismatch does not make these Lines eligible for Picking in this batch.',
      p_solution               => 'Verify the Scheduled Ship Date and/or the Requested Date range, specified during Pick Release, against the Lines expected to be picked and correct the date range.
<ul><li>Refer to [1606307/KB739266] for full details.</li></ul>',
      p_success_msg            => 'Lines selected for picking match with Scheduled Ship Date/Requested Date pick release criteria.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '8'
      );
   l_info.delete;
debug('end add_signature: LOGPR_CRITERIA_SCHDATE_REQDATE');



debug('begin add_signature: LOGPR_CRITERIA_EXISTING_RSVS_ONLY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9684',
      p_sig_id                 => 'LOGPR_CRITERIA_EXISTING_RSVS_ONLY',
      p_sig_sql                => 'Select WDD.DELIVERY_DETAIL_ID,WDD.RELEASED_STATUS  
FROM  WSH_DELIVERY_DETAILS WDD,
      OE_ORDER_LINES_ALL OL  
WHERE   WDD.DATE_SCHEDULED IS NOT NULL 
AND WDD.SOURCE_LINE_ID = OL.LINE_ID 
AND WDD.SOURCE_CODE  = ''OE''  
AND WDD.RELEASED_STATUS IN ( ''R'',''B'')  
AND not exists (Select ''1'' 
                  from MTL_SALES_ORDERS MSORD1,
                       MTL_RESERVATIONS MR , 
                       OE_TRANSACTION_TYPES_TL OTTT
                 where MSORD1.SEGMENT1 = WDD.SOURCE_HEADER_NUMBER 
                    AND MSORD1.SEGMENT2  = OTTT.NAME 
                    AND OTTT.TRANSACTION_TYPE_ID  = WDD.SOURCE_HEADER_TYPE_ID 
                    AND OTTT.LANGUAGE  = (SELECT language_code FROM fnd_languages WHERE installed_flag = ''B'')  
                    AND MSORD1.SEGMENT3 = ''ORDER ENTRY'' 
                    AND MR.DEMAND_SOURCE_HEADER_ID = MSORD1.SALES_ORDER_ID 
                    AND MR.DEMAND_SOURCE_LINE_ID   = WDD.SOURCE_LINE_ID 
                    AND NVL(MR.SHIP_READY_FLAG, 2) = 2 
                    AND MR.PRIMARY_RESERVATION_QUANTITY - NVL(MR.DETAILED_QUANTITY,0) > 0 
                ) 
AND wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(''##$$SOLINEID$$##'' , wdd.source_line_id)
and exists (Select 1
               from wsh_picking_batches wpb
              where nvl(wpb.Existing_RSVS_ONLY_FLAG,''N'') = ''Y''
               and wpb.batch_id = ##$$BATCHID$$##
           )',
      p_title                  => 'Shipping Pick Release Criteria Mismatch for Prior Reservations',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Prior Reservations Only is selected on the Pick Release Criteria but no reservation exists on the Line(s). This mismatched criteria does not make the Line(s) eligible for picking in this batch.',
      p_solution               => 'Prior Reservations Only check box should be enabled if ONLY the reserved Lines are expected to be Picked.
<ul><li>Refer to [956829/KB757441] for more details.</li> </ul>',
      p_success_msg            => 'Lines selected for picking have reservations and hence match the Prior Reservations Only criteria.',
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
debug('end add_signature: LOGPR_CRITERIA_EXISTING_RSVS_ONLY');



debug('begin add_signature: LOGPR_SUBINVENTORY_INFO');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10420',
      p_sig_id                 => 'LOGPR_SUBINVENTORY_INFO',
      p_sig_sql                => 'SELECT mp.organization_id,
  mp.organization_code,
  msi.secondary_inventory_name "Subinventory",
  msi.description "Description",
  TO_CHAR(msi.disable_date, ''DD-Mon-RR'') "Disable Date",
  DECODE(msi.reservable_type, 1, ''Yes'', 2, ''No'', msi.reservable_type) "Reservable Type",
  DECODE(msi.locator_type, 1, ''None'', 2, ''Prespecified'', 3, ''Dynamic'', 4, ''SubInv Level'', 5, ''Item Level'', msi.locator_type) "Locator Control",
  DECODE(msi.availability_type, 1, ''Nettable'', 2, ''Non-Nettable'', msi.availability_type) "Availability Type",
  DECODE(msi.inventory_atp_code, 1, ''Included'', 2, ''Not included'', msi.inventory_atp_code) "Include in ATP",
  DECODE(msi.asset_inventory, 1, ''Yes'', 2, ''No'', msi.asset_inventory) "Asset Inventory",
  DECODE(msi.quantity_tracked, 1, ''Yes'', 2, ''No'', msi.quantity_tracked) "Quantity Tracked" ,
  DECODE(msi.lpn_controlled_flag, 1, ''Yes'', 2, ''No'', msi.quantity_tracked) "LPN Controlled Flag" ,
  msi.picking_order "Picking Order",
  DECODE(msi.source_type, 1, ''Inventory'', 2, ''Supplier'', 3, ''Subinventory'', msi.source_type) "Source Type",
  msi.default_cost_group_id "Default Cost Group Id"
FROM mtl_secondary_inventories msi,
  mtl_parameters mp
WHERE mp.organization_id                                   = msi.organization_id
AND ( msi.organization_id, msi.secondary_inventory_name ) IN
  (SELECT DISTINCT moq.organization_id,
    moq.subinventory_code
  FROM mtl_onhand_quantities_detail moq
  WHERE (moq.organization_id ,moq.inventory_item_id) IN
    (SELECT wdd.organization_id,
      wdd.inventory_item_id
    FROM wsh_delivery_details wdd
    WHERE wdd.source_code    = ''OE''
    AND wdd.released_status IN ( ''R'',''B'',''S'')
    AND wdd.source_header_id = ##$$SOHEADERID$$##
    AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
    )
  )
ORDER BY msi.secondary_inventory_name',
      p_title                  => 'Subinventory Information',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Subinventory information for the sales order.',
      p_solution               => 'Subinventory information for the sales order. If no subinventory information exists for the sales order, no information will print.',
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
debug('end add_signature: LOGPR_SUBINVENTORY_INFO');



debug('begin add_signature: LOGPR_ONHAND_BY_PROJ_TASK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10430',
      p_sig_id                 => 'LOGPR_ONHAND_BY_PROJ_TASK',
      p_sig_sql                => 'select msik.segment1 "Item Name"
,x.inventory_item_id "Item ID"
,mp.organization_code "Org Code"
,mp.organization_id "Org ID"
,x.Revision "Revision"
,x.Subinventory_code "Subinventory Code"
,x.Locator_id "Locator ID"
,milk.concatenated_segments "Locator"
,x.Lot_number "Lot Number"
,x.COST_GROUP_ID "Cost Group ID"
,x.COST_GROUP	"Cost Group"
,x.LPN_ID	 "LPN ID"
,x.LPN_Number "LPN Number"
,x.PRIMARY_QUANTITY	"Primary Quantity"
,x.SECONDARY_QUANTITY	"Secondary Quantity"
,x.STATUS_ID	"Status ID"
,x.RESERVABLE_TYPE	"Reservable Type"
,x.DATE_RECEIVED	 "Date Received"
,nvl((
    SELECT
      meaning
    FROM
      fnd_lookup_values_vl
    WHERE
      lookup_type =''ASSEMBLY_PEGGING_CODE''
    /*and source_lang = ''US'' */
and
      lookup_code= msik.END_ASSEMBLY_PEGGING_FLAG
  ) , ''Not Pegged'')  "Item Pegging Info"
,x.MOQD_Project_ID "Onhand Project ID"
,x.project_number "Project Number"
,x.MOQD_Task_ID "Onhand Task ID"
,x.LOC_PROJECT_ID "Locator Project ID"
,x.LOC_TASK_ID "Locator Task ID"
,(select planning_group from pjm_project_parameters ppp where ppp.project_id = x.MOQD_Project_ID and ppp.organization_id = x.organization_id) "Onhand PROJ Planning Group"
,(select costing_group_id from pjm_project_parameters ppp where ppp.project_id = x.MOQD_Project_ID and ppp.organization_id = x.organization_id) "Onhand PROJ Costing Group"
,(select planning_group from pjm_project_parameters ppp where ppp.project_id = x.LOC_PROJECT_ID and ppp.organization_id = x.organization_id) "Locator PROJ Planning Group"
,(select costing_group_id from pjm_project_parameters ppp where ppp.project_id = x.LOC_PROJECT_ID and ppp.organization_id = x.organization_id) "Locator PROJ Costing Group"
from  mtl_system_items_vl msik, mtl_item_locations_kfv milk,mtl_parameters mp,(
SELECT
    moq.organization_id
    ,moq.inventory_item_id
    ,moq.revision
    ,moq.lot_number
    ,moq.subinventory_code
    ,moq.locator_id
    ,moq.cost_group_id
    ,csg.cost_group
    ,moq.lpn_id lpn_id
    ,(select license_plate_number from wms_license_plate_numbers where lpn_id = moq.lpn_id) LPN_Number
    ,min(NVL(moq.orig_date_received,moq.date_received)) date_received
    ,sum(moq.primary_transaction_quantity) primary_quantity
    ,sum(moq.secondary_transaction_quantity) secondary_quantity
    ,moq.status_id
    ,msub.reservable_type
    ,milk.project_id LOC_PROJECT_ID
    ,moq.project_id MOQD_Project_ID
    ,INV_PROJECT.GET_PROJECT_NUMBER(moq.project_id) project_number
    ,milk.task_id LOC_TASK_ID
    ,moq.task_id MOQD_TASK_ID
    ,INV_PROJECT.GET_TASK_NUMBER(moq.task_id) Task_number
FROM mtl_onhand_quantities_detail moq,
     mtl_system_items_vl msik,
     mtl_item_locations milk,
     mtl_secondary_inventories msub,
     mtl_lot_numbers mlot,
     mtl_material_statuses_vl mms4,
     cst_cost_groups csg
WHERE moq.organization_id = msik.organization_id
      AND moq.inventory_item_id = msik.inventory_item_id
      AND moq.organization_id   = msub.organization_id
      AND moq.subinventory_code = msub.secondary_inventory_name
      AND moq.organization_id   = milk.organization_id(+)
      AND moq.locator_id        = milk.inventory_location_id(+)
      AND moq.subinventory_code = milk.subinventory_code(+)
      AND moq.lot_number        = mlot.lot_number(+)
      AND moq.inventory_item_id = mlot.inventory_item_id(+)
      AND moq.organization_id   = mlot.organization_id(+)
      AND moq.cost_group_id     = csg.cost_group_id(+)
      AND moq.status_id	    = mms4.status_id(+)
        GROUP BY
            moq.organization_id, moq.inventory_item_id
            ,NVL(moq.orig_date_received, moq.date_received)
            ,moq.revision, moq.lot_number
            ,moq.subinventory_code
            ,moq.locator_id
            ,moq.cost_group_id
            ,csg.cost_group
            ,moq.status_id
            ,msub.reservable_type
            ,moq.lpn_id
            ,milk.project_id
            ,moq.project_id
            ,INV_PROJECT.GET_PROJECT_NUMBER(moq.project_id)
            ,milk.task_id
            ,moq.task_id
            ,INV_PROJECT.GET_TASK_NUMBER(moq.task_id)
        HAVING
             sum(moq.primary_transaction_quantity) > 0 ) x
where x.organization_id = mp.organization_id
and x.organization_id = msik.organization_id
AND x.inventory_item_id = msik.inventory_item_id
AND x.organization_id   = milk.organization_id(+)
AND x.locator_id        = milk.inventory_location_id(+)
AND x.subinventory_code = milk.subinventory_code(+)
and (x.organization_id, x.inventory_item_id ) in (SELECT wdd.organization_id ,
       wdd.inventory_item_id
FROM   wsh_delivery_details wdd
WHERE  wdd.source_code    = ''OE''
AND    wdd.released_status IN ( ''R'',''B'',''S'')
AND wdd.source_header_id = ##$$SOHEADERID$$##
AND wdd.source_line_id = NVL(##$$SOLINEID$$##, wdd.source_line_id)
)
order by 2,5,8,9',
      p_title                  => 'Onhand Quantity for the Sales Order Lines',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is no item onhand quantity available for lines associated with the sales order. When there is no item onhand available for lines associated with an order, the pick release process can fail.',
      p_solution               => 'Please make sure there is enough onhand quantity available to allocate the Sales Order Lines. When there is no Item Onhand available for lines associated with Order, the pick release process can fail.
<ul><li>Refer to section "6. Onhand/Available" in [2277206/KB736030#onhandavailable] for full details.</li></ul>',
      p_success_msg            => 'Onhand exists for items associated with the sales order lines.',
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
debug('end add_signature: LOGPR_ONHAND_BY_PROJ_TASK');



debug('begin add_signature: EBS_MFG_OM_ONT_ONTONESO_ITEM_CATEGORIES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '27861',
      p_sig_id                 => 'EBS_MFG_OM_ONT_ONTONESO_ITEM_CATEGORIES',
      p_sig_sql                => 'SELECT category_set_name "Category Set",
       control_level_disp "Control Level",
       category_concat_segs "Category"
  FROM mtl_item_categories_v
 WHERE inventory_item_id = ''##$$FK1$$##''
   AND organization_id = ''##$$FK2$$##''
 ORDER BY 2,1
',
      p_title                  => 'Category Assignment',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is no category assignment.',
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
debug('end add_signature: EBS_MFG_OM_ONT_ONTONESO_ITEM_CATEGORIES');



debug('begin add_signature: SALES_ORDER_LINE_MTL_SYSTEM_ITEMS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9785',
      p_sig_id                 => 'SALES_ORDER_LINE_MTL_SYSTEM_ITEMS',
      p_sig_sql                => 'SELECT DISTINCT 
       lin.line_id "Line ID",
       /* Master Item */
       /* Main */
       itm.inventory_item_id "Item ID",
       msik.concatenated_segments "Item Name",
       itm.organization_id "Organization ID",
       itm.primary_uom_code "Primary Unit of Measure",
       itm.tracking_quantity_ind "Tracking UOM Indicator",
       itm.ont_pricing_qty_source "Pricing UOM Indicator",
       itm.secondary_uom_code "Secondary Unit of Measure",
       itm.secondary_default_ind "Defaulting Control",
       decode(itm.allowed_units_lookup_code, 
	          1, ''Item specific'', 
			  2, ''Standard'',
              3, ''Both'', itm.allowed_units_lookup_code) "Conversions",
       itm.item_type "User Item Type",
       itm.inventory_item_status_code "Item Status"
       /* Inventory */
	   ,
       itm.inventory_item_flag "Inventory Item",
       itm.stock_enabled_flag "Stockable",
       itm.mtl_transactions_enabled_flag "Transactable",
       itm.inventory_asset_flag "Asset Flag",
       decode(itm.revision_qty_control_code, 
	          1, ''On'', 
			  2, ''Off'',
              itm.revision_qty_control_code) "Revision Control",
       decode(itm.reservable_type, 
	          1, ''On'', 
			  2, ''Off'',
              itm.reservable_type) "Reservable",
       itm.check_shortages_flag "Check Material Shortage",
       decode(itm.lot_control_code, 
	          1, ''No Control'', 
			  2, ''Full Control'',
              itm.lot_control_code) "Lot Control",
       itm.start_auto_lot_number "Starting Lot Number",
       itm.auto_lot_alpha_prefix "Starting Lot Prefix",
       itm.lot_divisible_flag "Lot Divisible Flag",
       itm.maturity_days "Maturity Days",
       itm.hold_days "Hold Days",
       decode(itm.serial_number_control_code, 
	          1, ''No Control'', 
			  5, ''At Receipt'',
              6, ''At Sales Order Issue'', 
			  2, ''Predefined'', itm.serial_number_control_code) "Serial Number Generation",
       itm.start_auto_serial_number "Starting Serial Number",
       itm.auto_serial_alpha_prefix "Starting Serial Prefix",
       decode(itm.location_control_code, 
	          1, ''No Control'', 
			  2, ''Prespecified'',
              3, ''Dynamic Entry'', itm.location_control_code) "Locator Control",
       decode(itm.restrict_subinventories_code, 
	          1, ''On'', 
			  2, ''Off'',
              itm.restrict_subinventories_code) "Restrict Subinventories",
       decode(itm.restrict_locators_code, 
	          1, ''On'', 
			  2, ''Off'',
              itm.restrict_locators_code) "Restrict Locators",
       /* BOM */
       itm.base_item_id "Base Item ID",
      /* Work In Process */
          itm.build_in_wip_flag "Build in WIP",
       /* Order Management */
       itm.customer_order_flag "Customer Ordered",
       itm.customer_order_enabled_flag "Customer Orders Enabled",
       itm.internal_order_flag "Internal Ordered",
       itm.internal_order_enabled_flag "Internal Orders Enabled",
       itm.shippable_item_flag "Shippable",
       itm.so_transactions_flag "OE Transactable",
       itm.indivisible_flag "Indivisible Flag",
       itm.picking_rule_id "Picking Rule",
       itm.pick_components_flag "Pick Components",
       itm.replenish_to_order_flag "Assemble to Order",
       itm.atp_flag "Check ATP",
       itm.atp_components_flag "ATP Components",
       itm.atp_rule_id "ATP Rule",
       itm.ship_model_complete_flag "Ship Model Complete",
       itm.default_shipping_org "Default Shipping Organization",
       itm.default_so_source_type "Default SO Source Type",
       itm.returnable_flag "Returnable",
       decode(itm.return_inspection_requirement, 
	          1, ''On'', 
			  2, ''Off'',
              itm.return_inspection_requirement) "RMA Inspection Required",
       itm.over_shipment_tolerance "Over Shipment Tolerance",
       itm.under_shipment_tolerance "Under Shipment Tolerance",
       itm.over_return_tolerance "Over Return Tolerance",
       itm.under_return_tolerance "Under Return Tolerance"
       /* Invoicing */
	   ,
       itm.invoiceable_item_flag "Invoiceable Item",
       itm.invoice_enabled_flag "Invoice Enabled",
       itm.costing_enabled_flag "Costing Enabled",
       itm.inventory_item_id "##$$FK1$$##",
       itm.organization_id "##$$FK2$$##"
  FROM mtl_system_items itm,
       oe_order_lines_all lin,
       mtl_parameters mp,
       mtl_system_items_kfv msik
 WHERE lin.header_id = ##$$HEADERID$$##
   AND NVL(''##$$LINEID$$##'',0) IN (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.service_reference_line_id)
   AND lin.inventory_item_id = itm.inventory_item_id
   AND lin.split_from_line_id is NULL
   AND itm.organization_id = mp.organization_id
   AND itm.organization_id = mp.master_organization_id
   AND msik.inventory_item_id = itm.inventory_item_id
   AND msik.organization_id = mp.organization_id
   AND msik.organization_id = mp.master_organization_id
 ORDER BY 1, 2',
      p_title                  => 'Item Attributes at Master Items',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is no item attributes at master items.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL('EBS_MFG_OM_ONT_ONTONESO_ITEM_CATEGORIES'),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '26'
      );
   l_info.delete;
debug('end add_signature: SALES_ORDER_LINE_MTL_SYSTEM_ITEMS');



debug('begin add_signature: LOGPR_WMS_RULE_RESTRICTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10427',
      p_sig_id                 => 'LOGPR_WMS_RULE_RESTRICTIONS',
      p_sig_sql                => 'SELECT Rule_type_meaning,
  Rule_id,
  rule_name,
  rule_description,
  Rule_organization_id,
  Sequence_number,
  LOGICAL_OPERATOR_meaning,
  left_object_name,
  Left_Parameter_name,
  Operator_meaning,
  OPerand_type_meaning,
  OPerand_constant_character,
  right_parameter_name
FROM wms_restrictions_v
WHERE rule_type_code     IN (1,2) -- putaway, pick
AND rule_organization_id IN
  (SELECT wdd.organization_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id)
  )',
      p_title                  => 'WMS Rule Restriction Setup Details for the Shipping Organization',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Displaying WMS rule restriction setup details for shipping organization in which this sales order and line has been created.',
      p_solution               => 'If no WMS rule restrictions print, none exist for the shipping organization.',
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
debug('end add_signature: LOGPR_WMS_RULE_RESTRICTIONS');



debug('begin add_signature: SALES_ORDER_MTL_RESERVATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1048',
      p_sig_id                 => 'SALES_ORDER_MTL_RESERVATIONS',
      p_sig_sql                => 'SELECT res.reservation_id "Reservation ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       lin.line_id "SO Line ID",
	   
       res.demand_source_type_id||'': ''||
       (SELECT meaning FROM mfg_lookups where lookup_type=''MTL_SUPPLY_DEMAND_SOURCE_TYPE'' and lookup_code=res.demand_source_type_id) "Demand Source Type",
       res.demand_source_header_id "Demand Source Header",
       res.demand_source_line_id "Demand Source Line",
       res.demand_source_delivery "Demand Source Delivery",
       --res.demand_source_name,

       res.supply_source_type_id||'': ''||
       (SELECT meaning FROM mfg_lookups where lookup_type=''MTL_SUPPLY_DEMAND_SOURCE_TYPE'' and lookup_code=res.supply_source_type_id) "Supply Source Type",
       res.supply_source_header_id "Supply Source Header",
       res.supply_source_line_id "Supply Source Line ID",
       res.supply_source_line_detail "Supply Source Line Detail",
       --res.supply_source_name,

       res.inventory_item_id "Item ID",
       msik.concatenated_segments "Item Name",

       res.reservation_quantity "Reservation Qty",
       res.reservation_uom_code "Reservation UOM",
       res.detailed_quantity "Detailed Qty",
       
       res.primary_reservation_quantity "Primary Reservation Qty",
       res.primary_uom_code "Primary UOM",

       res.secondary_reservation_quantity "Secondary Reservation Qty",
       res.secondary_uom_code "Secondary UOM",
       res.secondary_detailed_quantity "Secondary Detailed Qty",
     
       inv_convert.inv_um_convert(
         res.inventory_item_id, 
         res.lot_number, 
         res.organization_id, 
         5, 
         res.primary_reservation_quantity,
         res.primary_uom_code, 
         res.secondary_uom_code, 
         NULL, 
         NULL) "Calc Sec Res Qty",

       res.ship_ready_flag||'': ''||
       decode(res.ship_ready_flag,
         1,''Released'',
         2,''Submitted'') "Ship Ready", 
       res.staged_flag "Staged",

       to_char(res.requirement_date, ''DD-MON-RR_HH24:MI:SS'') "Required Date",

       res.organization_id "Org ID",
	   mp.organization_code "Org",
       res.subinventory_code "Subinventory",
       res.lot_number "Lot",
       res.revision "Revision",
       res.locator_id "Locator ID",
       res.serial_number "Serial Number",

       wip.wip_entity_id "WIP ID",
       wip.wip_entity_name "Job Name",
       job.status_type_disp "Job Start"
	   
  FROM mtl_reservations res,
       oe_order_lines_all lin,
       mtl_system_items_kfv msik,
	   mtl_parameters mp,
       wip_entities wip,
       wip_discrete_jobs_v job
 WHERE ##$$SALESORDERID$$## = res.demand_source_header_id 
   AND res.demand_source_type_id IN ( 2, 8, 9, 21, 22 ) 
   AND res.demand_source_line_id = lin.line_id 
   AND lin.header_id = ##$$HEADERID$$##
   AND nvl(''##$$LINEID$$##'', 0) IN ( 0, lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id )
   AND res.organization_id = msik.organization_id
   AND res.inventory_item_id = msik.inventory_item_id
   AND res.organization_id = mp.organization_id
   AND res.supply_source_header_id = wip.wip_entity_id (+)
   AND wip.wip_entity_id = job.wip_entity_id (+)
ORDER BY lin.line_number,
         nvl(lin.shipment_number, - 1),
         nvl(lin.option_number, - 1),
         nvl(lin.component_number, - 1),
         nvl(lin.service_number, - 1),
         res.reservation_id	',
      p_title                  => 'Material Reservations',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no material reservations. ',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: SALES_ORDER_MTL_RESERVATIONS');



debug('begin add_signature: SALES_ORDER_MTL_DEMAND');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '8306',
      p_sig_id                 => 'SALES_ORDER_MTL_DEMAND',
      p_sig_sql                => 'SELECT dem.demand_id "Demand ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       lin.line_id "SO Line ID",
       
	   dem.demand_source_type|| '': ''|| 
	   ( SELECT meaning FROM mfg_lookups WHERE lookup_type = ''MTL_SUPPLY_DEMAND_SOURCE_TYPE'' AND lookup_code = dem.demand_source_type) "Demand Source Type",
       dem.demand_source_header_id "Demand Source Header",
       dem.demand_source_line "Demand Source Line",
       dem.demand_source_delivery "Demand Source Delivery",
       --dem.demand_source_name,

       dem.organization_id "Org ID",
       mp.organization_code "Org",
       
       dem.inventory_item_id "Item ID",
       msik.concatenated_segments "Item Name",
       dem.ordered_item_id "Ordered Item",
       
	   dem.line_item_quantity "Quantity",
       dem.line_item_reservation_qty "Reserved Qty",
       dem.uom_code "UOM",
       dem.primary_uom_quantity "Qty in Primary UOM",
       dem.reservation_quantity "#Reserved Qty in Primary UOM",
       dem.completed_quantity "Shipped Qty in Primary UOM",
       itm.primary_uom_code "Primary UOM",

       dem.updated_flag "Updated Flag",
       decode(row_status_flag,
              1, ''1=Active'',
              2, ''2=Complete'',
              to_char(row_status_flag)) "Row Status",
       dem.order_change_report_flag "ATO Change Flag",
       dem.available_to_mrp "MRP Visible",
       dem.available_to_atp "ATP Visible",

	   to_char(dem.requirement_date, ''DD-MON-RR_HH24:MI:SS'') "Requirement Date",
       to_char(dem.estimated_release_date, ''DD-MON-RR_HH24:MI:SS'') "Estimated Release Date",
       to_char(dem.explosion_effectivity_date, ''DD-MON-RR_HH24:MI:SS'') "BOM Effectivity Date",
       --dem.mrp_date "MRP Date",

       dem.subinventory "Subinventory",
       dem.lot_number "Lot",
       dem.revision "Revision",
       dem.locator_id "Locator ID",
       dem.serial_number "Serial Number",
       dem.reservation_type||'': ''||
       (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_RESERVATION'' and lookup_code=dem.reservation_type) "Reservation Type",

       dem.parent_demand_id "Parent Demand ID",
       dem.external_source_code "External Source Code",
       dem.external_source_line_id "External Source Line ID",
       dem.user_line_num "User Line Num",
       dem.user_delivery "Usr Delivery",
       dem.schedule_id "Schedule ID",
       dem.autodetail_group_id "Autodetail Group ID",
       
       dem.supply_source_type "Supply Source Type",
       dem.supply_source_header_id "Supply Source Header",
       dem.supply_group_id "Supply Group",
       
       dem.component_sequence_id "Component Sequence ID",
       dem.parent_component_seq_id "Parent Component Seq ID",
       dem.rto_model_source_line "Model Row Source ID",
       dem.rto_previous_qty "Model Previous Qty",
       dem.demand_class "Demand Class",
       dem.atp_lead_time "ATP Lead Time",
       dem.bom_level "Bom Level",
       dem.config_status "Config Status",
       dem.config_group_id "Config Group ID",

       dem.customer_id "Customer ID",
       dem.territory_id "Territory ID",
       dem.bill_to_site_use_id "Bill To Site ID",
       dem.ship_to_site_use_id "Ship To Site ID",

       dem.demand_type "Demand Type",

       dem.mrp_date "MRP Date",
       dem.mrp_quantity "MRP Quantity"

  FROM mtl_demand dem,
       oe_order_lines_all lin,
       mtl_system_items_kfv msik,
       mtl_parameters mp,
       mtl_system_items itm,
       wip_entities wip,
       wip_discrete_jobs_v job
 WHERE ##$$SALESORDERID$$## = dem.demand_source_header_id  
   AND NVL(''##$$LINEID$$##'',0) in (0,LIN.LINE_ID, LIN.TOP_MODEL_LINE_ID, LIN.ATO_LINE_ID, LIN.LINK_TO_LINE_ID, LIN.REFERENCE_LINE_ID, LIN.SERVICE_REFERENCE_LINE_ID)
   AND dem.demand_source_line = lin.line_id
   AND lin.header_id = ##$$HEADERID$$##
   AND dem.organization_id = msik.organization_id
   AND dem.inventory_item_id = msik.inventory_item_id
   AND dem.organization_id = itm.organization_id
   AND dem.inventory_item_id = itm.inventory_item_id
   AND dem.organization_id = mp.organization_id
   AND dem.supply_source_header_id = wip.wip_entity_id (+)
   AND wip.wip_entity_id = job.wip_entity_id (+)
ORDER BY lin.line_number,
         nvl(lin.shipment_number, - 1),
         nvl(lin.option_number, - 1),
         nvl(lin.component_number, - 1),
         nvl(lin.service_number, - 1),
         dem.demand_id',
      p_title                  => 'Material Demand',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is no material demand.',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: SALES_ORDER_MTL_DEMAND');



debug('begin add_signature: SALES_ORDER_MTL_SUPPLY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1047',
      p_sig_id                 => 'SALES_ORDER_MTL_SUPPLY',
      p_sig_sql                => 'SELECT -- Drop Shipments - Req
       sup.supply_type_code "Supply Type",
       sup.supply_source_id "Supply Source ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       lin.line_id "SO Line ID",
       sup.req_header_id "Req Header ID",
       sup.req_line_id "Req Line ID",
       sup.po_header_id "PO Header ID",
       sup.po_release_id "PO Release ID",
       sup.po_line_id "PO Line ID",
       sup.po_line_location_id "PO Line Loc ID",
       sup.po_distribution_id "PO Distribution ID",
       sup.shipment_header_id "Shipment Header ID",
       sup.shipment_line_id "Shipment Line ID",
       sup.rcv_transaction_id "Receiving Trx ID",
       sup.item_id "Item ID",
       sup.quantity "Quantity",
       sup.unit_of_measure "UOM",
       sup.to_org_primary_quantity "Quantity in Primary UOM",
       sup.to_org_primary_uom "Primary UOM",
       to_char(sup.receipt_date, ''DD-MON-RR_HH24:MI:SS'') "Receipt Date",
       to_char(sup.need_by_date, ''DD-MON-RR_HH24:MI:SS'') "Need By Date",
       to_char(sup.expected_delivery_date, ''DD-MON-RR_HH24:MI:SS'') "Expected Delivery Date",
       sup.destination_type_code "Destination Type",
       sup.location_id "Location ID",
       sup.from_organization_id "From Org",
       sup.from_subinventory "From Sub",
       sup.to_organization_id "To Org",
       sup.to_subinventory "To Sub",
       sup.intransit_owning_org_id "Intrans Owning Org",
       lin.line_number "o1",
       nvl(lin.shipment_number, - 1) "o2",
       nvl(lin.option_number, - 1) "o3",
       nvl(lin.component_number, - 1) "o4",
       nvl(lin.service_number, - 1) "o5"
  FROM mtl_supply sup,
       oe_drop_ship_sources src,
       oe_order_lines_all lin
 WHERE src.line_id = lin.line_id
   AND src.requisition_line_id = sup.req_line_id
   AND src.requisition_header_id = sup.req_header_id
   AND lin.header_id = ##$$HEADERID$$##
   AND nvl(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.service_reference_line_id)
UNION ALL
SELECT -- Drop Shipments - PO
       sup.supply_type_code "Supply Type",
       sup.supply_source_id "Supply Source ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       lin.line_id "SO Line ID",
       sup.req_header_id "Req Header ID",
       sup.req_line_id "Req Line ID",
       sup.po_header_id "PO Header ID",
       sup.po_release_id "PO Release ID",
       sup.po_line_id "PO Line ID",
       sup.po_line_location_id "PO Line Loc ID",
       sup.po_distribution_id "PO Distribution ID",
       sup.shipment_header_id "Shipment Header ID",
       sup.shipment_line_id "Shipment Line ID",
       sup.rcv_transaction_id "Receiving Trx ID",
       sup.item_id "Item ID",
       sup.quantity "Quantity",
       sup.unit_of_measure "UOM",
       sup.to_org_primary_quantity "Quantity in Primary UOM",
       sup.to_org_primary_uom "Primary UOM",
       to_char(sup.receipt_date, ''DD-MON-RR_HH24:MI:SS'') "Receipt Date",
       to_char(sup.need_by_date, ''DD-MON-RR_HH24:MI:SS'') "Need By Date",
       to_char(sup.expected_delivery_date, ''DD-MON-RR_HH24:MI:SS'') "Expected Delivery Date",
       sup.destination_type_code "Destination Type",
       sup.location_id "Location ID",
       sup.from_organization_id "From Org",
       sup.from_subinventory "From Sub",
       sup.to_organization_id "To Org",
       sup.to_subinventory "To Sub",
       sup.intransit_owning_org_id "Intrans Owning Org",
       lin.line_number "o1",
       nvl(lin.shipment_number, - 1) "o2",
       nvl(lin.option_number, - 1) "o3",
       nvl(lin.component_number, - 1) "o4",
       nvl(lin.service_number, - 1) "o5"
  FROM mtl_supply sup,
       oe_drop_ship_sources src,
       oe_order_lines_all lin
 WHERE src.line_id = lin.line_id
   AND src.po_line_id = sup.po_line_id
   AND src.po_header_id = sup.po_header_id
   AND lin.header_id = ##$$HEADERID$$##
   AND nvl(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.service_reference_line_id)
UNION ALL
SELECT -- Internal Sales Order
       sup.supply_type_code "Supply Type",
       sup.supply_source_id "Supply Source ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       lin.line_id "SO Line ID",
       sup.req_header_id "Req Header ID",
       sup.req_line_id "Req Line ID",
       sup.po_header_id "PO Header ID",
       sup.po_release_id "PO Release ID",
       sup.po_line_id "PO Line ID",
       sup.po_line_location_id "PO Line Loc ID",
       sup.po_distribution_id "PO Distribution ID",
       sup.shipment_header_id "Shipment Header ID",
       sup.shipment_line_id "Shipment Line ID",
       sup.rcv_transaction_id "Receiving Trx ID",
       sup.item_id "Item ID",
       sup.quantity "Quantity",
       sup.unit_of_measure "UOM",
       sup.to_org_primary_quantity "Quantity in Primary UOM",
       sup.to_org_primary_uom "Primary UOM",
       to_char(sup.receipt_date, ''DD-MON-RR_HH24:MI:SS'') "Receipt Date",
       to_char(sup.need_by_date, ''DD-MON-RR_HH24:MI:SS'') "Need By Date",
       to_char(sup.expected_delivery_date, ''DD-MON-RR_HH24:MI:SS'') "Expected Delivery Date",
       sup.destination_type_code "Destination Type",
       sup.location_id "Location ID",
       sup.from_organization_id "From Org",
       sup.from_subinventory "From Sub",
       sup.to_organization_id "To Org",
       sup.to_subinventory "To Sub",
       sup.intransit_owning_org_id "Intrans Owning Org",
       lin.line_number "o1",
       nvl(lin.shipment_number, - 1) "o2",
       nvl(lin.option_number, - 1) "o3",
       nvl(lin.component_number, - 1) "o4",
       nvl(lin.service_number, - 1) "o5"
  FROM mtl_supply sup,
       oe_order_lines_all lin
 WHERE lin.source_document_line_id = sup.req_line_id
   AND lin.source_document_id = sup.req_header_id
   AND lin.source_document_type_id = 10
   AND lin.header_id = ##$$HEADERID$$##
   AND nvl(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.service_reference_line_id)
 ORDER BY 30, 31, 32, 33, 34, 1, 2',
      p_title                  => 'Material Supply',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is no material supply.',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: SALES_ORDER_MTL_SUPPLY');



debug('begin add_signature: SALES_ORDER_DROP_SHIP_MTL_TRX_INTERFACE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10023',
      p_sig_id                 => 'SALES_ORDER_DROP_SHIP_MTL_TRX_INTERFACE',
      p_sig_sql                => 'SELECT tmp.transaction_interface_id "Trans Interface ID",
       tmp.transaction_header_id "Trans Header ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       tmp.source_line_id "Source Line ID",
       tmp.picking_line_id "Pick Line ID",
       tmp.source_header_id "Source Header ID",
       tmp.source_code "Source Code",

       tmp.transaction_type_id|| '': ''|| mmtt.transaction_type_name "Trans Type",
       tmp.trx_source_line_id "Trx Source Line ID",
       tmp.trx_source_delivery_id "Trx Source Delivery ID",
       tmp.transaction_source_id "Trans Source ID",
       tmp.transaction_source_type_id|| '': ''|| mtst.transaction_source_type_name "Trans Source Type",
       tmp.transaction_source_name "Trans Source Name",
       tmp.transaction_action_id|| '': ''|| 
        ( SELECT meaning FROM mfg_lookups WHERE lookup_type = ''MTL_TRANSACTION_ACTION'' AND lookup_code = tmp.transaction_action_id ) "Trans Action",

       tmp.process_flag||'': ''||
         decode(tmp.process_flag,
                1, ''Ready'',
                2, ''Not Ready'',
                3, ''Error'') "Process Flag",
       tmp.transaction_mode||'': ''||
         decode(tmp.transaction_mode,
                2, ''Concurrent'',
                3, ''Background'') "Transaction Mode",
       tmp.lock_flag||'': ''||
         decode(nvl(tmp.lock_flag, 2),
                1, ''Locked'',
                2, ''Not Locked'') "Lock Flag",

       tmp.error_code "Error Code",
       tmp.error_explanation "Error Explanation",

       tmp.inventory_item_id "Inventory Item ID",
       msik.concatenated_segments "Item Name",
       tmp.transaction_quantity "Transaction Qty",
       tmp.transaction_uom "Trans UOM",
       tmp.primary_quantity "Primary Qty",
       tmp.secondary_transaction_quantity "Secondary Trx Qty",
       tmp.secondary_uom_code "Secondary UOM Code",

       tmp.organization_id "Org ID",
       mp.organization_code "Org",
       tmp.subinventory_code "From Subinventory",
       tmp.locator_id "From Locator ID",
       tmp.content_lpn_id "LPN ID",
       
       to_char(tmp.transaction_date, ''DD-MON-RR_HH24:MI:SS'') "Transaction Date",
       tmp.acct_period_id "Accounting Period ID",
       oac.period_name "Period Name",
       oac.open_flag "Period Open Flag",
       to_char(oac.period_start_date, ''DD-MON-RR_HH24:MI:SS'') "Period Start Date",
       to_char(oac.period_close_date, ''DD-MON-RR_HH24:MI:SS'') "Period Close Date",
       to_char(oac.schedule_close_date, ''DD-MON-RR_HH24:MI:SS'') "Schedule Close Date",
       
       tmp.created_by "Created By",
       to_char(tmp.creation_date, ''DD-MON-RR_HH24:MI:SS'') "Creation Date",
       tmp.last_updated_by "Last Updated By",
       to_char(tmp.last_update_date, ''DD-MON-RR_HH24:MI:SS'') "Last Update Date"

  FROM mtl_transactions_interface tmp,
       mtl_transaction_types mmtt,
       mtl_txn_source_types mtst,
       mtl_system_items_kfv msik,
       mtl_parameters mp,
       wsh_delivery_details det,
       oe_order_lines_all lin,
       mtl_system_items itm,
       org_acct_periods oac
 WHERE tmp.transaction_type_id = mmtt.transaction_type_id
   AND tmp.transaction_source_type_id = mtst.transaction_source_type_id
   AND tmp.organization_id = msik.organization_id
   AND tmp.inventory_item_id = msik.inventory_item_id
   AND tmp.organization_id = mp.organization_id
   AND tmp.source_line_id = lin.line_id
   AND lin.ship_from_org_id = itm.organization_id (+)
   AND lin.inventory_item_id = itm.inventory_item_id (+)
   AND det.source_line_id = lin.line_id
   AND tmp.picking_line_id = det.delivery_detail_id (+)
   AND tmp.acct_period_id = oac.acct_period_id (+)
   AND tmp.error_code is not null
   AND lin.header_id = ##$$HEADERID$$##
   AND nvl(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id)
ORDER BY 
       lin.line_number,
       nvl(lin.shipment_number, - 1),
       nvl(lin.option_number, - 1),
       nvl(lin.component_number, - 1),
       nvl(lin.service_number, - 1),
       1    
	   ',
      p_title                  => 'Material Transactions Interface Errors',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Errors being reported from the Transactions Interface.  ',
      p_solution               => 'Refer to [1063689/KB559654] for the most common interface errors.<br><br>
If Error Explanation shows "Error.. in INV_LOGICAL_TRANSACTIONS_PUB.create_logical_trx_wrapper
oracle.apps.inv.transaction.utilities.InvTrxException" refer to  [819554/KB308281] or [2093513/KB223016].',
      p_success_msg            => 'No material transaction interface records associated with this sales order have an error status.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '15'
      );
   l_info.delete;
debug('end add_signature: SALES_ORDER_DROP_SHIP_MTL_TRX_INTERFACE');



debug('begin add_signature: SALES_ORDER_MTL_TRANSACTIONS_INTERFACE');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1099',
      p_sig_id                 => 'SALES_ORDER_MTL_TRANSACTIONS_INTERFACE',
      p_sig_sql                => 'SELECT tmp.transaction_interface_id "Trans Interface ID",
       tmp.transaction_header_id "Trans Header ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       tmp.source_line_id "Source Line ID",
       tmp.picking_line_id "Pick Line ID",
       tmp.source_header_id "Source Header ID",
       tmp.source_code "Source Code",

       tmp.transaction_type_id|| '': ''|| mmtt.transaction_type_name "Trans Type",
       tmp.trx_source_line_id "Trx Source Line ID",
       tmp.trx_source_delivery_id "Trx Source Delivery ID",
       tmp.transaction_source_id "Trans Source ID",
       tmp.transaction_source_type_id|| '': ''|| mtst.transaction_source_type_name "Trans Source Type",
       tmp.transaction_source_name "Trans Source Name",
       tmp.transaction_action_id|| '': ''|| 
        ( SELECT meaning FROM mfg_lookups WHERE lookup_type = ''MTL_TRANSACTION_ACTION'' AND lookup_code = tmp.transaction_action_id ) "Trans Action",

       tmp.inventory_item_id "Inventory Item ID",
       msik.concatenated_segments "Item Name",
       tmp.transaction_quantity "Transaction Qty",
       tmp.transaction_uom "Trans UOM",
       tmp.primary_quantity "Primary Qty",
       tmp.secondary_transaction_quantity "Secondary Trx Qty",
       tmp.secondary_uom_code "Secondary UOM Code",

       tmp.organization_id "Org ID",
       mp.organization_code "Org",
       tmp.subinventory_code "From Subinventory",
       tmp.locator_id "From Locator ID",
       tmp.content_lpn_id "LPN ID",
       
       tmp.process_flag||'': ''||
         decode(tmp.process_flag,
                1, ''Ready'',
                2, ''Not Ready'',
                3, ''Error'') "Process Flag",
       tmp.transaction_mode||'': ''||
         decode(tmp.transaction_mode,
                2, ''Concurrent'',
                3, ''Background'') "Transaction Mode",
       tmp.lock_flag||'': ''||
         decode(nvl(tmp.lock_flag, 2),
                1, ''Locked'',
                2, ''Not Locked'') "Lock Flag",

       tmp.error_code "Error Code",
       tmp.error_explanation "Error Explanation",

       to_char(tmp.transaction_date, ''DD-MON-RR_HH24:MI:SS'') "Transaction Date",
       tmp.acct_period_id "Accounting Period ID",
       oac.period_name "Period Name",
       oac.open_flag "Period Open Flag",
       to_char(oac.period_start_date, ''DD-MON-RR_HH24:MI:SS'') "Period Start Date",
       to_char(oac.period_close_date, ''DD-MON-RR_HH24:MI:SS'') "Period Close Date",
       to_char(oac.schedule_close_date, ''DD-MON-RR_HH24:MI:SS'') "Schedule Close Date",
       
       tmp.created_by "Created By",
       to_char(tmp.creation_date, ''DD-MON-RR_HH24:MI:SS'') "Creation Date",
       tmp.last_updated_by "Last Updated By",
       to_char(tmp.last_update_date, ''DD-MON-RR_HH24:MI:SS'') "Last Update Date"

  FROM mtl_transactions_interface tmp,
       mtl_transaction_types mmtt,
       mtl_txn_source_types mtst,
       mtl_system_items_kfv msik,
       mtl_parameters mp,
       wsh_delivery_details det,
       oe_order_lines_all lin,
       mtl_system_items itm,
       org_acct_periods oac
 WHERE tmp.transaction_type_id = mmtt.transaction_type_id
   AND tmp.transaction_source_type_id = mtst.transaction_source_type_id
   AND tmp.organization_id = msik.organization_id
   AND tmp.inventory_item_id = msik.inventory_item_id
   AND tmp.organization_id = mp.organization_id
   AND tmp.source_line_id = lin.line_id
   AND lin.ship_from_org_id = itm.organization_id (+)
   AND lin.inventory_item_id = itm.inventory_item_id (+)
   AND det.source_line_id = lin.line_id
   AND tmp.picking_line_id = det.delivery_detail_id (+)
   AND tmp.acct_period_id = oac.acct_period_id (+)
   AND lin.header_id = ##$$HEADERID$$##
   AND nvl(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id)
ORDER BY 
       lin.line_number,
       nvl(lin.shipment_number, - 1),
       nvl(lin.option_number, - 1),
       nvl(lin.component_number, - 1),
       nvl(lin.service_number, - 1),
       1    ',
      p_title                  => 'Material Transactions Interface',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are material transactions to interface.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '12'
      );
   l_info.delete;
debug('end add_signature: SALES_ORDER_MTL_TRANSACTIONS_INTERFACE');



debug('begin add_signature: SALES_ORDER_MTL_MATERIAL_TRANSACTIONS_TEMP');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1100',
      p_sig_id                 => 'SALES_ORDER_MTL_MATERIAL_TRANSACTIONS_TEMP',
      p_sig_sql                => 'SELECT tmp.transaction_temp_id "Trans Temp ID",
       tmp.transaction_header_id "Trans Header ID",
       lin.line_id "SO Line ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",

       tmp.transaction_action_id||'': ''||
         (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_TRANSACTION_ACTION'' and lookup_code=tmp.transaction_action_id) "Trans Action",
       tmp.transaction_type_id||'': ''|| mmtt.transaction_type_name "Trans Type",
       tmp.transaction_source_type_id||'': ''|| mtst.transaction_source_type_name "Trans Source Type",
       tmp.transaction_source_id "Trans Source ID",
       tmp.transaction_source_name "Trans Source Name",

       tmp.inventory_item_id "Inventory Item ID",
       msik.concatenated_segments "Item Name",
       
       tmp.transaction_quantity "Trans Qty",
       tmp.transaction_uom "Trans UOM",
       tmp.primary_quantity "Primary Qty",
       tmp.secondary_transaction_quantity "Second Trx Qty",
       tmp.secondary_uom_code "Second UOM",
       
       tmp.transaction_date "Trans Date",
       oap.period_name "Period Name",

       tmp.move_order_line_id "Move Line ID",
       tmp.pick_slip_number "Pick Slip",
       tmp.reservation_id "Reservation ID",
       
       tmp.subinventory_code "From Subinventory",
       tmp.locator_id "From Loc ID",
       tmp.transfer_subinventory "To Subinventory",
       tmp.transfer_to_location "To Loc ID",

       tmp.process_flag "Process",
       tmp.lock_flag "Lock",
       tmp.transaction_mode||'': ''||
         (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_TRANSACTION_MODE'' and lookup_code=tmp.transaction_mode) "Transaction Mode",

       tmp.error_code "Error Code",
       tmp.error_explanation "Error Explanation",

       lot.lot_number "Lot Num",
       lot.primary_quantity "Lot Primary Qty",
       lot.secondary_quantity "Lot Secondary Qty",
       inv_convert.inv_um_convert(tmp.inventory_item_id, lot.lot_number, tmp.organization_id, 5, lot.primary_quantity,
                                  itm.primary_uom_code, tmp.secondary_uom_code, NULL, NULL) "Lot Calculated Second Qty",

       tmp.lpn_id "LPN ID",
       tmp.transfer_lpn_id "Transfer LPN",
                           
       tmp.created_by "Created By",
       to_char(tmp.creation_date, ''DD-MON-RR_HH24:MI:SS'') "Creation Date",
       tmp.last_updated_by "Last Updated By",
       to_char(tmp.last_update_date, ''DD-MON-RR_HH24:MI:SS'') "Last Update Date",
       
       lin.line_number "o1",
       nvl(lin.shipment_number, - 1) "o2",
       nvl(lin.option_number, - 1) "o3",
       nvl(lin.component_number, - 1) "o4",
       nvl(lin.service_number, - 1) "o5"
                                  
  FROM mtl_material_transactions_temp tmp,
       mtl_transaction_types mmtt,
       mtl_txn_source_types mtst,
       oe_order_lines_all lin,
       mtl_system_items itm,
       mtl_system_items_kfv msik,
       org_acct_periods oap,
       mtl_transaction_lots_temp lot
 WHERE tmp.transaction_type_id = mmtt.transaction_type_id
   AND tmp.transaction_source_type_id = mtst.transaction_source_type_id
   AND (tmp.demand_source_line = lin.line_id  or tmp.trx_source_line_id = lin.line_id)
   AND lin.line_category_code = ''ORDER''
   AND tmp.organization_id = itm.organization_id 
   AND tmp.inventory_item_id = itm.inventory_item_id 
   AND tmp.organization_id = msik.organization_id
   AND tmp.inventory_item_id = msik.inventory_item_id
   AND tmp.organization_id = oap.organization_id
   AND tmp.acct_period_id = oap.acct_period_id
   AND lot.transaction_temp_id (+) = tmp.transaction_temp_id
   AND lin.header_id = ##$$HEADERID$$## 
   AND nvl(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id)

UNION ALL

SELECT tmp.transaction_temp_id "Trans Temp ID",
       tmp.transaction_header_id "Trans Header ID",
       lin.line_id "SO Line ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       
       tmp.transaction_action_id|| '': ''|| (
         SELECT meaning FROM mfg_lookups WHERE lookup_type = ''MTL_TRANSACTION_ACTION'' AND lookup_code = tmp.transaction_action_id) "Trans Action",
       tmp.transaction_type_id|| '': ''|| mmtt.transaction_type_name "Trans Type",
       tmp.transaction_source_type_id|| '': ''|| mtst.transaction_source_type_name "Trans Source Type",
       tmp.transaction_source_id "Trans Source ID",
       tmp.transaction_source_name "Trans Source Name",

       tmp.inventory_item_id "Inventory Item ID",
       msik.concatenated_segments "Item Name",

       tmp.transaction_quantity "Trans Qty",
       tmp.transaction_uom "Trans UOM",
       tmp.primary_quantity "Primary Qty",
       tmp.secondary_transaction_quantity "Second Trx Qty",
       tmp.secondary_uom_code "Second UOM",

       tmp.transaction_date "Trans Date",
       oap.period_name "Period Name",

       tmp.move_order_line_id "Move Line ID",
       tmp.pick_slip_number "Pick Slip",
       tmp.reservation_id "Reservation ID",
       tmp.subinventory_code "From Subinventory",
       tmp.locator_id "From Loc ID",
       tmp.transfer_subinventory "To Subinventory",
       tmp.transfer_to_location "To Loc ID",

       tmp.process_flag "Process",
       tmp.lock_flag "Lock",
       tmp.transaction_mode|| '': ''|| 
        ( SELECT meaning FROM mfg_lookups WHERE lookup_type = ''MTL_TRANSACTION_MODE'' AND lookup_code = tmp.transaction_mode) "Transaction Mode",

       tmp.error_code "Error Code",
       tmp.error_explanation "Error Explanation",
	   
       '' '' "Lot Num",
       0 "Lot Primary Qty",
       0 "Lot Secondary Qty",
       0 "Lot Calculated Second Qty",

       tmp.lpn_id "LPN ID",
       tmp.transfer_lpn_id "Transfer LPN",
       
       tmp.created_by "Created By",
       to_char(tmp.creation_date, ''DD-MON-RR_HH24:MI:SS'') "Creation Date",
       tmp.last_updated_by "Last Updated By",
       to_char(tmp.last_update_date, ''DD-MON-RR_HH24:MI:SS'') "Last Update Date",
       
       lin.line_number "o1",
       nvl(lin.shipment_number, - 1) "o2",
       nvl(lin.option_number, - 1) "o3",
       nvl(lin.component_number, - 1) "o4",
       nvl(lin.service_number, - 1) "o5"
       
  FROM mtl_material_transactions_temp tmp,
       mtl_transaction_types mmtt,
       mtl_txn_source_types mtst,
       oe_order_lines_all lin,
       mtl_system_items itm,
       mtl_system_items_kfv msik,
       org_acct_periods oap
 WHERE tmp.transaction_type_id = mmtt.transaction_type_id
   AND tmp.transaction_source_type_id = mtst.transaction_source_type_id
   AND tmp.trx_source_line_id = lin.line_id
   AND lin.line_category_code = ''RETURN''
   AND lin.ship_from_org_id = itm.organization_id 
   AND lin.inventory_item_id = itm.inventory_item_id 
   AND tmp.organization_id = msik.organization_id
   AND tmp.inventory_item_id = msik.inventory_item_id
   AND tmp.organization_id = oap.organization_id
   AND tmp.acct_period_id = oap.acct_period_id
   AND LIN.HEADER_ID = ##$$HEADERID$$## 
   AND nvl(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id)

ORDER BY 41, 42, 43, 44, 45, 1',
      p_title                  => 'Material Transactions Temp - Unpicked Lines',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no material transactions temp - unpicked lines. ',
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
debug('end add_signature: SALES_ORDER_MTL_MATERIAL_TRANSACTIONS_TEMP');



debug('begin add_signature: SALES_ORDER_MTL_MATERIAL_TRANSACTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1101',
      p_sig_id                 => 'SALES_ORDER_MTL_MATERIAL_TRANSACTIONS',
      p_sig_sql                => 'SELECT trn.transaction_id "Trans ID",
       trn.trx_source_line_id "Trx Source Line ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",

       trn.transaction_action_id||'': ''||
         (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_TRANSACTION_ACTION'' and lookup_code=trn.TRANSACTION_ACTION_ID) "Trans Action",
       trn.transaction_type_id||'': ''||
         mmtt.transaction_type_name "Trans Type",
       trn.transaction_source_type_id||'': ''||
         mtst.transaction_source_type_name "Trans Source Type",
       trn.transaction_source_name "Trans Source Name",
       
       trn.inventory_item_id "Inventory Item ID",
       msik.concatenated_segments "Item Name",
       
       trn.transaction_quantity "Trans Quantity",
       trn.transaction_uom "Trans UOM",
       trn.primary_quantity "Primary Qty",
       trn.secondary_transaction_quantity "Secondary Trx Qty",
       trn.secondary_uom_code "Secondary UOM",
       
       lot.primary_quantity "Lot Primary Qty",
       lot.secondary_transaction_quantity "Lot Secondary Qty",
       inv_convert.inv_um_convert(lot.inventory_item_id, lot.lot_number, lot.organization_id, 5, lot.primary_quantity,
                                  itm.primary_uom_code, trn.secondary_uom_code, NULL, NULL) "Lot Calv Secondary Qty",
       
       trn.organization_id "Org ID",
       trn.subinventory_code "From Subinventory",              
       trn.locator_id "From Loc ID",
       trn.transfer_subinventory "To Subinventory",
       trn.transfer_locator_id "To Loc ID",

       trn.transaction_date "Trans Date",
       oap.period_name "Period Name",
       
       trn.move_order_line_id "Move Line ID",
       trn.picking_line_id "Picking Line ID",
       trn.pick_slip_number "Pick Slip",

       trn.transaction_mode||'': ''||
         (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_TRANSACTION_MODE'' and lookup_code=trn.transaction_mode) "Transaction Mode",
       trn.invoiced_flag "Invoiced Flag",
       
       trn.lpn_id "LPN ID",
       trn.transfer_lpn_id "Transfer LPN",
       
       trn.created_by "Created By",
       to_char(trn.creation_date, ''DD-MON-RR_HH24:MI:SS'') "Creation Date",
       trn.last_updated_by "Last Updated By",
       to_char(trn.last_update_date, ''DD-MON-RR_HH24:MI:SS'') "Last Update Date",
       
       lin.line_number "o1",
       nvl(lin.shipment_number, - 1) "o2",
       nvl(lin.option_number, - 1) "o3",
       nvl(lin.component_number, - 1) "o4",
       nvl(lin.service_number, - 1) "o5"

  FROM mtl_material_transactions trn,
       mtl_transaction_types mmtt,
       mtl_txn_source_types mtst,
       mtl_system_items itm,
       mtl_system_items_kfv msik,
       org_acct_periods oap,
       mtl_transaction_lot_numbers lot,
       oe_order_lines_all lin
WHERE trn.transaction_type_id = mmtt.transaction_type_id
  AND trn.transaction_source_type_id = mtst.transaction_source_type_id
  AND trn.trx_source_line_id = lin.line_id
  AND trn.organization_id = lin.ship_from_org_id
  AND trn.inventory_item_id = lin.inventory_item_id
  AND trn.organization_id = msik.organization_id
  AND trn.inventory_item_id = msik.inventory_item_id
  AND trn.organization_id = oap.organization_id
  AND trn.acct_period_id = oap.acct_period_id
  AND lin.header_id = ##$$HEADERID$$## 
  AND NVL(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id) 
  AND trn.organization_id = itm.organization_id
  AND trn.inventory_item_id = itm.inventory_item_id
  AND trn.transaction_id = lot.transaction_id (+) 

UNION ALL

SELECT /* DROP SHIP */ 
       trn.transaction_id "Trans ID",
       trn.trx_source_line_id "Trx Source Line ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",

       trn.transaction_action_id||'': ''||
         (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_TRANSACTION_ACTION'' and lookup_code=trn.TRANSACTION_ACTION_ID) "Trans Action",
       trn.transaction_type_id||'': ''||
         mmtt.transaction_type_name "Trans Type",
       trn.transaction_source_type_id||'': ''||
         mtst.transaction_source_type_name "Trans Source Type",
       trn.transaction_source_name "Trans Source Name",
       
       trn.inventory_item_id "Inventory Item ID",
       msik.concatenated_segments "Item Name",
       
       trn.transaction_quantity "Trans Quantity",
       trn.transaction_uom "Trans UOM",
       trn.primary_quantity "Primary Qty",
       trn.secondary_transaction_quantity "Secondary Trx Qty",
       trn.secondary_uom_code "Secondary UOM",
       
       0 "Lot Primary Qty", -- Only for OPM
       0 "Lot Secondary Qty", -- Only for OPM
       0 "Lot Calv Secondary Qty", -- Only for OPM
       
       trn.organization_id "Org ID",
       trn.subinventory_code "From Subinventory",              
       trn.locator_id "From Loc ID",
       trn.transfer_subinventory "To Subinventory",
       trn.transfer_locator_id "To Loc ID",

       trn.transaction_date "Trans Date",
       oap.period_name "Period Name",
       
       trn.move_order_line_id "Move Line ID",
       trn.picking_line_id "Picking Line ID",
       trn.pick_slip_number "Pick Slip",

       trn.transaction_mode||'': ''||
         (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_TRANSACTION_MODE'' and lookup_code=trn.transaction_mode) "Transaction Mode",
       trn.invoiced_flag "Invoiced Flag",
	   
       trn.lpn_id "LPN ID",
       trn.transfer_lpn_id "Transfer LPN",
       
       trn.created_by "Created By",
       to_char(trn.creation_date, ''DD-MON-RR_HH24:MI:SS'') "Creation Date",
       trn.last_updated_by "Last Updated By",
       to_char(trn.last_update_date, ''DD-MON-RR_HH24:MI:SS'') "Last Update Date",
       
       lin.line_number "o1",
       nvl(lin.shipment_number, - 1) "o2",
       nvl(lin.option_number, - 1) "o3",
       nvl(lin.component_number, - 1) "o4",
       nvl(lin.service_number, - 1) "o5"

FROM mtl_material_transactions trn,
     mtl_transaction_types mmtt,
     mtl_txn_source_types mtst,
     mtl_system_items itm,
     mtl_system_items_kfv msik,
     org_acct_periods oap,
     oe_drop_ship_sources drp,
     rcv_transactions rcv,
     po_headers_all poh,
     oe_order_lines_all lin
WHERE trn.transaction_type_id = mmtt.transaction_type_id
  AND trn.transaction_source_type_id = mtst.transaction_source_type_id
  AND trn.transaction_type_id = 18 -- PO Receipt
  AND trn.transaction_source_type_id = 1
  AND trn.transaction_source_id = poh.po_header_id
  AND poh.po_header_id = drp.po_header_id
  AND drp.header_id = ##$$HEADERID$$##
  AND trn.organization_id = itm.organization_id
  AND trn.inventory_item_id = itm.inventory_item_id
  AND trn.organization_id = msik.organization_id
  AND trn.inventory_item_id = msik.inventory_item_id
  AND trn.organization_id = oap.organization_id
  AND trn.acct_period_id = oap.acct_period_id
  AND drp.po_line_id = rcv.po_line_id 
  AND drp.line_location_id = rcv.po_line_location_id 
  AND rcv.transaction_type  = ''DELIVER'' 
  AND lin.line_id = drp.line_id
  AND lin.header_id = ##$$HEADERID$$##
  AND NVL(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id) 
  
UNION ALL

SELECT   /* PO receipt trx for ATO BUY ITEM */ 
       trn.transaction_id "Trans ID",
       trn.trx_source_line_id "Trx Source Line ID",
       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",

       trn.transaction_action_id||'': ''||
         (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_TRANSACTION_ACTION'' and lookup_code=trn.TRANSACTION_ACTION_ID) "Trans Action",
       trn.transaction_type_id||'': ''||
         mmtt.transaction_type_name "Trans Type",
       trn.transaction_source_type_id||'': ''||
         mtst.transaction_source_type_name "Trans Source Type",
       trn.transaction_source_name "Trans Source Name",
       
       trn.inventory_item_id "Inventory Item ID",
       msik.concatenated_segments "Item Name",
       
       trn.transaction_quantity "Trans Quantity",
       trn.transaction_uom "Trans UOM",
       trn.primary_quantity "Primary Qty",
       trn.secondary_transaction_quantity "Secondary Trx Qty",
       trn.secondary_uom_code "Secondary UOM",
       
       0 "Lot Primary Qty", -- Only for OPM
       0 "Lot Secondary Qty", -- Only for OPM
       0 "Lot Calv Secondary Qty", -- Only for OPM
       
       trn.organization_id "Org ID",
       trn.subinventory_code "From Subinventory",              
       trn.locator_id "From Loc ID",
       trn.transfer_subinventory "To Subinventory",
       trn.transfer_locator_id "To Loc ID",

       trn.transaction_date "Trans Date",
       oap.period_name "Period Name",
       
       trn.move_order_line_id "Move Line ID",
       trn.picking_line_id "Picking Line ID",
       trn.pick_slip_number "Pick Slip",
       
       trn.transaction_mode||'': ''||
         (SELECT meaning FROM mfg_lookups WHERE lookup_type=''MTL_TRANSACTION_MODE'' and lookup_code=trn.transaction_mode) "Transaction Mode",
       trn.invoiced_flag "Invoiced Flag",
	   
       trn.lpn_id "LPN ID",
       trn.transfer_lpn_id "Transfer LPN",

       trn.created_by "Created By",
       to_char(trn.creation_date, ''DD-MON-RR_HH24:MI:SS'') "Creation Date",
       trn.last_updated_by "Last Updated By",
       to_char(trn.last_update_date, ''DD-MON-RR_HH24:MI:SS'') "Last Update Date",
       
       lin.line_number "o1",
       nvl(lin.shipment_number, - 1) "o2",
       nvl(lin.option_number, - 1) "o3",
       nvl(lin.component_number, - 1) "o4",
       nvl(lin.service_number, - 1) "o5"
       
FROM mtl_material_transactions trn,
     mtl_transaction_types mmtt,
     mtl_txn_source_types mtst,
     mtl_system_items itm,
     mtl_system_items_kfv msik,
     org_acct_periods oap,
     mtl_reservations res,
     po_headers_all poh,
     oe_order_lines_all lin
WHERE
     trn.transaction_type_id = mmtt.transaction_type_id
  AND trn.transaction_source_type_id = mtst.transaction_source_type_id
  AND ##$$SALESORDERID$$## = res.demand_source_header_id
  AND res.demand_source_type_id = 2  -- SO
  AND res.supply_source_type_id IN ( 1, 13 )  -- PO or INV
  AND res.supply_source_header_id = poh.po_header_id  
  AND poh.po_header_id = trn.transaction_source_id
  AND trn.organization_id = itm.organization_id
  AND trn.inventory_item_id = itm.inventory_item_id
  AND trn.organization_id = msik.organization_id
  AND trn.inventory_item_id = msik.inventory_item_id
  AND trn.organization_id = oap.organization_id
  AND trn.acct_period_id = oap.acct_period_id
  AND trn.transaction_type_id = 18  -- PO Receipt
  AND trn.transaction_source_type_id = 1
  AND lin.line_id = trn.trx_source_line_id
  AND lin.header_id = ##$$HEADERID$$##
  AND NVL(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id) 
  
ORDER BY 36,37,38,39,40,1',
      p_title                  => 'Material Transactions - Picked Lines',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no material transactions - picked lines. ',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '16'
      );
   l_info.delete;
debug('end add_signature: SALES_ORDER_MTL_MATERIAL_TRANSACTIONS');



debug('begin add_signature: SALES_ORDER_MTL_TXN_REQUEST_LINES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1103',
      p_sig_id                 => 'SALES_ORDER_MTL_TXN_REQUEST_LINES',
      p_sig_sql                => 'SELECT trl.line_id "MO Line ID",
       trl.line_number "MO Line No",
       trl.header_id "MO Header ID",
       trh.request_number "MO Number",

       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       lin.line_id "SO Line ID",

       trh.move_order_type||'': ''||
        ( SELECT meaning FROM mfg_lookups WHERE lookup_type=''MOVE_ORDER_TYPE'' AND lookup_code=trh.move_order_type) "MO Type",
       trl.transaction_type_id||'': ''||mtt.transaction_type_name "Trx Type",
       trl.transaction_source_type_id|| '': ''|| mtst.transaction_source_type_name "Trans Source Type",

       trl.line_status|| '': ''|| 
        ( SELECT meaning FROM mfg_lookups WHERE lookup_type = ''MTL_TXN_REQUEST_STATUS'' AND lookup_code = trl.line_status) "Line Status",
       to_char(trl.status_date, ''DD-MON-RR_HH24:MI:SS'') "Status Changed",

       trl.txn_source_line_id "Trx Source Line ID",
       trl.txn_source_line_detail_id "Trx Source Line Det ID",
       trl.transaction_header_id "Trx Header ID",
       trl.txn_source_id "Txn Source ID",
       
       trl.inventory_item_id "Inventory Item ID",
       msik.concatenated_segments "Item Name",

       trl.quantity "Quantity",
       trl.uom_code "UOM",
       trl.primary_quantity "Primary Qty",
       trl.quantity_delivered "Qty Delivered",
       trl.quantity_detailed "Qty Detailed",
       trl.secondary_quantity "Secondary Qty",
       trl.secondary_uom_code "Secondary UOM",
       trl.secondary_quantity_delivered "Secondary Qty Delivered",
       trl.secondary_quantity_detailed "Secondary Qty Detailed",

       trl.lot_number "Lot Number",
       trl.serial_number_start "First Serial No",
       trl.serial_number_end "Last Serial No",

       to_char(trl.date_required, ''DD-MON-RR_HH24:MI:SS'') "Date Required",
       
       trl.organization_id "Org ID",
       mp.organization_code "Org",
       trl.from_subinventory_code "From Subinventory",
       trl.from_locator_id "From Loc ID",
       trl.to_subinventory_code "To Subinventory",
       trl.to_locator_id "To Loc ID",
 
       trl.created_by "Created By",
       to_char(trl.creation_date, ''DD-MON-RR_HH24:MI:SS'') "Creation Date",
       trl.last_updated_by "Last Updated By",
       to_char(trl.last_update_date, ''DD-MON-RR_HH24:MI:SS'') "Last Update Date"
 
  FROM mtl_txn_request_lines trl,
       mtl_txn_request_headers trh,
       wsh_delivery_details det,
       oe_order_lines_all lin,
       mtl_system_items_kfv msik,
       mtl_txn_source_types mtst,
       mtl_transaction_types mtt,
       mtl_parameters mp
 WHERE trl.line_id = det.move_order_line_id
   AND trl.organization_id = msik.organization_id
   AND trl.inventory_item_id = msik.inventory_item_id
   AND trl.organization_id = mp.organization_id
   AND trl.transaction_source_type_id = mtst.transaction_source_type_id
   AND trl.transaction_type_id = mtt.transaction_type_id
   AND det.source_line_id = lin.line_id
   AND trl.header_id = trh.header_id
   AND lin.header_id = ##$$HEADERID$$##
   AND NVL(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id)  
ORDER BY lin.line_number,
         nvl(lin.shipment_number, - 1),
         nvl(lin.option_number, - 1),
         nvl(lin.component_number, - 1),
         nvl(lin.service_number, - 1),
         1',
      p_title                  => 'Move Order Lines',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is no move order lines.',
      p_solution               => '',
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
debug('end add_signature: SALES_ORDER_MTL_TXN_REQUEST_LINES');



debug('begin add_signature: SALES_ORDER_MTL_UNIT_TRANSACTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '1102',
      p_sig_id                 => 'SALES_ORDER_MTL_UNIT_TRANSACTIONS',
      p_sig_sql                => 'SELECT unt.transaction_id "Trx ID",

       om_order_analyzer_pkg.line_shipment_option(lin.line_number, lin.shipment_number, lin.option_number, lin.component_number, lin.service_number) "SO Line",
       lin.line_id "SO Line ID",

       unt.inventory_item_id "Item ID",
       msik.concatenated_segments "Item Name",

       unt.serial_number "Serial Number",

       unt.transaction_source_id "Trx Source ID",
       unt.transaction_source_type_id||'': ''||
         mtst.transaction_source_type_name "Trans Source Type",
       unt.transaction_source_name "Trx Source Name",

       to_char(unt.transaction_date, ''DD-MON-RR_HH24:MI:SS'') "Trx Date",
       
       unt.organization_id "Org ID",
       mp.organization_code "Org",
       unt.subinventory_code "Subinventory",
       unt.locator_id "Locator ID",

       unt.status_id "Status ID",
       unt.receipt_issue_type "Receipt Issue Type",
       unt.customer_id "Customer ID",
       unt.ship_id "Ship ID"

  FROM mtl_unit_transactions unt,
       mtl_material_transactions trn,
       oe_order_lines_all lin,
       mtl_system_items_kfv msik,
       mtl_txn_source_types mtst,
       mtl_parameters mp
 WHERE unt.transaction_id = trn.transaction_id
   AND trn.trx_source_line_id = lin.line_id
   AND trn.organization_id = lin.ship_from_org_id
   AND trn.inventory_item_id = lin.inventory_item_id

   AND trn.transaction_source_type_id = mtst.transaction_source_type_id

   AND trn.organization_id = msik.organization_id
   AND trn.inventory_item_id = msik.inventory_item_id
   AND trn.organization_id = mp.organization_id
   AND lin.header_id = ##$$HEADERID$$## 
   AND nvl(''##$$LINEID$$##'',0) in (0,lin.line_id, lin.top_model_line_id, lin.ato_line_id, lin.link_to_line_id, lin.reference_line_id, lin.service_reference_line_id) 
ORDER BY lin.line_number,
         nvl(lin.shipment_number, - 1),
         nvl(lin.option_number, - 1),
         nvl(lin.component_number, - 1),
         nvl(lin.service_number, - 1),
         unt.transaction_id,
         unt.serial_number	',
      p_title                  => 'Material Unit Transactions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There are no material unit transactions. ',
      p_solution               => '',
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
debug('end add_signature: SALES_ORDER_MTL_UNIT_TRANSACTIONS');



debug('begin add_signature: LOGPR_ITEM_TXN_DEFAULT_SETUP');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10422',
      p_sig_id                 => 'LOGPR_ITEM_TXN_DEFAULT_SETUP',
      p_sig_sql                => 'SELECT MTP.organization_id "Organization ID",
  MTP.ORGANIZATION_CODE "Organization Code",
  MSIB.segment1 "Item Name",
  NULL "Default For Sub",
  NULL "Subinventory Defaults" ,
  MLSL.Meaning "Default For Loc",
  MILD.subinventory_code "Default Subinventory" ,
  MILK.CONCATENATED_SEGMENTS "Locator"
FROM MTL_ITEM_LOC_DEFAULTS MILD,
  MTL_SYSTEM_ITEMS_B MSIB,
  MTL_PARAMETERS MTP,
  MFG_LOOKUPS MLSL,
  MTL_ITEM_LOCATIONS_KFV MILK
WHERE MILD.INVENTORY_ITEM_ID                        = MSIB.INVENTORY_ITEM_ID
AND MILD.ORGANIZATION_ID                            = MSIB.ORGANIZATION_ID
AND MTP.ORGANIZATION_ID                             = MSIB.ORGANIZATION_ID
AND MILK.ORGANIZATION_ID                            = MILD.ORGANIZATION_ID
AND MILD.DEFAULT_TYPE                               = MLSL.Lookup_CODE
AND MLSL.LOOKUP_TYPE                                = ''MTL_DEFAULT_LOCATORS''
AND (MILD.organization_id, MILD.inventory_item_id) IN
  (SELECT wdd.organization_id,
    wdd.inventory_item_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
  )
AND MILD.DEFAULT_TYPE = 3 -- Move order receipt
AND MILD.LOCATOR_ID   = MILK.INVENTORY_LOCATION_ID
UNION
SELECT MTP.organization_id "Organization ID",
  MTP.ORGANIZATION_CODE "Organization Code",
  MSIB.SEGMENT1 "Item Name",
  MLSS.Meaning "Default For Sub",
  MISD.subinventory_code "Subinventory Defaults",
  NULL "Default For Loc",
  NULL "Default Subinventory" ,
  NULL "Locator"
FROM MTL_SYSTEM_ITEMS_B MSIB,
  mtl_parameters MTP,
  MTL_ITEM_SUB_DEFAULTS MISD,
  MFG_LOOKUPS MLSS
WHERE MISD.INVENTORY_ITEM_ID                        = MSIB.INVENTORY_ITEM_ID
AND MISD.ORGANIZATION_ID                            = MSIB.ORGANIZATION_ID
AND MTP.ORGANIZATION_ID                             = MSIB.ORGANIZATION_ID
AND MLSS.LOOKUP_TYPE                                = ''MTL_DEFAULT_SUBINVENTORY''
AND MISD.DEFAULT_TYPE                               = MLSS.LOOKUP_CODE
AND MISD.DEFAULT_TYPE                               = 3 -- Move order receipt
AND (MISD.organization_id, MISD.inventory_item_id) IN
  (SELECT wdd.organization_id,
    wdd.inventory_item_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
  )',
      p_title                  => 'Item Transaction Default Setup Details',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'This order contains one or more lines where there is a missing item transaction default setup. This situation may cause the INV#INV_NO_DEFAULT_LOC# error during the pick release process.',
      p_solution               => 'Review the item transaction defaults for the locator in Inventory.<br>
The pick release process can fail if item transaction defaults for the locator in Inventory are not setup properly.
<ul><li>Refer to [149926/KB767734] for full details.</li></ul>',
      p_success_msg            => 'There are no issues with the Item Transaction Default setup.',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: LOGPR_ITEM_TXN_DEFAULT_SETUP');



debug('begin add_signature: LOGPR_WMS_RULE_SETUP');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10424',
      p_sig_id                 => 'LOGPR_WMS_RULE_SETUP',
      p_sig_sql                => 'SELECT FROM_ORGANIZATION_ID "From Organization ID" ,
  FROM_ORGANIZATION_CODE "From Organization Code" ,
  TO_ORGANIZATION_ID "To Organization ID" ,
  TO_ORGANIZATION_CODE "To Organization Code" ,
  RULE_TYPE "Type" ,
  DECODE( RETURN_TYPE, ''R'', ''Rule'',''S'',''Strategy'') "Return Type" ,
  SEQUENCE_NUMBER "Seq#" ,
  RETURN_TYPE_ID "Return Type ID" ,
  RETURN_TYPE_NAME "Return Value" ,
  ENABLED_FLAG ,
  CUSTOMER_ID "Customer ID" ,
  CUSTOMER_NAME "Customer Name" ,
  INVENTORY_ITEM_ID "Inventory Item ID" ,
  ITEM "Item" ,
  CATEGORY_ID "Category ID" ,
  CATEGORY_SET_ID "category Set ID" ,
  CATEGORY_SET_NAME "Item Category" ,
  ITEM_TYPE "Item Type Code" ,
  ITEM_TYPE_NAME "Item Type Name" ,
  ASSIGNMENT_GROUP_ID "Assignment Group ID" ,
  ABC_CLASS_ID "ABC Class ID" ,
  ABC_GROUP_CLASS_NAME "ABC Class Name" ,
  ASSIGNMENT_GROUP_ID "Assignment Group ID" ,
  FROM_SUBINVENTORY_NAME "From Subinventory" ,
  TO_SUBINVENTORY_NAME "To Subinventory" ,
  VENDOR_ID "Vendor ID" ,
  VENDOR_NAME "Supplier Name" ,
  ORDER_TYPE_ID "Order Type ID" ,
  ORDER_TYPE_NAME "Order Type" ,
  FREIGHT_CODE "Freight Code" ,
  FREIGHT_CODE_NAME "Freight Name" ,
  PROJECT_ID "Project ID" ,
  PROJECT_NAME "Project Name" ,
  TASK_ID "Task ID" ,
  TASK_NAME "Task Name" ,
  USER_ID "User ID" ,
  USER_NAME "User Name" ,
  UOM_CODE "UOM Code" ,
  UNIT_OF_MEASURE "UOM" ,
  UOM_CLASS "UOM Class" ,
  UOM_CLASS_NAME "UOM Class Name" ,
  TRANSACTION_ACTION_ID "Transaction Action ID" ,
  TRANSACTION_ACTION_NAME "Transaction Action Name" ,
  REASON_ID "Reason ID" ,
  REASON_NAME "Reason Name" ,
  TRANSACTION_SOURCE_TYPE_ID "Transaction Src Type ID" ,
  TRANSACTION_SOURCE_TYPE_NAME "Transaction Src Type Name" ,
  TRANSACTION_TYPE_ID "Transaction Type ID" ,
  TRANSACTION_TYPE_NAME "Transaction Type" ,
  DATE_TYPE_CODE "Date Type Code" ,
  DATE_TYPE_FROM "From Date" ,
  DATE_TYPE_TO "Date To" ,
  LAST_UPDATE_DATE "Last Update Date" ,
  CREATED_BY "Last Updated By" ,
  CREATION_DATE "Creation Date" ,
  LAST_UPDATE_LOGIN "Last Update Login" ,
  LAST_UPDATED_BY "Last Updated by" ,
  WMS_ENABLED_FLAG "WMS Enabled Flag" ,
  LOCATION_ID "Location ID" ,
  LOCATION_NAME "Location Name"
FROM WMS_SELECTION_CRITERIA_TXN_V wsctv
WHERE wsctv.from_organization_id IN
  (SELECT DISTINCT wdd.organization_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id)
  )
AND wsctv.enabled_flag    = 1
AND wsctv.rule_type_code IN (1,2)
ORDER BY wsctv.from_organization_id,
  wsctv.rule_type_code ,
  wsctv.sequence_number ASC',
      p_title                  => 'Rules/Assignments Setup for the Organization',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No rules/assignments are setup for the organization.  This will cause WMS sales order picking to fail or not behave as expected.',
      p_solution               => 'You will need to perform the setup steps for the sales order picking. Refer to section 5.1 of [2325760/KB774607#outsopick] and follow the prerequisite setup steps provided in the video.',
      p_success_msg            => 'All rules/assignments are setup for the Organization.',
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
debug('end add_signature: LOGPR_WMS_RULE_SETUP');



debug('begin add_signature: INV_ORGANIZATIONS_FULL_OUTPUT_ORG');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5993',
      p_sig_id                 => 'INV_ORGANIZATIONS_FULL_OUTPUT_ORG',
      p_sig_sql                => 'select attribute, value from 
(SELECT 1 sequence, ''-- INVENTORY PARAMETERS --'' Attribute, '''' Value from dual
UNION 
SELECT 1.1 sequence, ''Organization Code'', organization_code || '' (ID: ''|| organization_id ||'')''  FROM mtl_parameters mp 
 where organization_id = ##$$ORGID$$##
union 
select 1.2 sequence, ''Item Master Organization'', NVL((select b.organization_code || '' (ID: '' || mp.master_organization_id || '')'' from mtl_parameters b where b.organization_id = mp.master_organization_id), mp.master_organization_id) master_organization_id from mtl_parameters mp
 where organization_id = ##$$ORGID$$## 
union
select 1.3 sequence, ''Calendar'', calendar_code  FROM mtl_parameters mp 
 where organization_id = ##$$ORGID$$##
union
select 1.4 sequence, ''Allow Negative Balances'', NVL((select lookup_code || '' (''|| meaning || '')'' from mfg_lookups where lookup_type = ''MTL_NEGATIVE_RECEIPT'' and lookup_code = negative_inv_receipt_code), negative_inv_receipt_code) negative_inv_receipt_code  from mtl_parameters mp
 where organization_id = ##$$ORGID$$## 
union
select 1.5 sequence, ''Locator Control'', NVL((select lookup_code || '' (''|| meaning || '')'' from mfg_lookups where lookup_type = ''MTL_LOCATION_CONTROL'' and lookup_code = stock_locator_control_code), stock_locator_control_code) stock_locator_control_code from mtl_parameters mp
 where organization_id = ##$$ORGID$$## 
 union
select 1.6 sequence, ''On-Hand Status Enabled'', decode(default_status_id, NULL, ''No'', ''Yes'') onhand_status_enabled from mtl_parameters mp
 where organization_id = ##$$ORGID$$## 
union
select 1.7 sequence, ''WMS (Warehouse Management System) Enabled'', wms_enabled_flag  from mtl_parameters mp
 where organization_id = ##$$ORGID$$## 
union
select 1.8 sequence, ''Process Manufacturing (OPM) Enabled'', process_enabled_flag  from mtl_parameters mp
 where organization_id = ##$$ORGID$$## 
union 
select 1.9 sequence, ''EAM (Enterprise Asset Management) Enabled'', eam_enabled_flag from mtl_parameters mp
 where organization_id = ##$$ORGID$$## 
union 
select 1.91  sequence, ''Project Enabled'', DECODE(project_reference_enabled, 1, ''1 (Yes)'', 2, ''2 (No)'', to_char(project_reference_enabled))  
from mtl_parameters mp
 where organization_id = ##$$ORGID$$## 
union
SELECT 2 sequence, '''' Attribute, '''' Value from dual
UNION 
SELECT 2.1 sequence, ''-- COSTING INFORMATION --'' Attribute, '''' Value from dual
union 
select 2.2 sequence, ''Costing Method'', NVL((select lookup_code || '' (''|| meaning || '')'' from mfg_lookups where lookup_type = ''MTL_PRIMARY_COST'' and lookup_code = primary_cost_method), primary_cost_method) primary_cost_method from mtl_parameters mp 
 where organization_id = ##$$ORGID$$##
union
select 2.3 sequence, ''Costing Organization'', NVL((select mp.cost_organization_id || '' ('' ||b.organization_code || '')'' from mtl_parameters b where b.organization_id = mp.cost_organization_id), mp.cost_organization_id) cost_organization_id from mtl_parameters mp 
 where organization_id = ##$$ORGID$$##
union
select 2.4 sequence, ''Default Cost Group ID'', DEFAULT_COST_GROUP_ID || '' (''|| (select COST_GROUP from CST_COST_GROUPS where COST_GROUP_ID = DEFAULT_COST_GROUP_ID) ||'')'' from mtl_parameters mp  
 where organization_id = ##$$ORGID$$##
union
SELECT 3 sequence, '''' Attribute, '''' Value from dual
union
SELECT 3.1 sequence, ''-- REVISION, LOT, SERIAL AND LPN -- '' Attribute, '''' Value from dual
union 
select 3.2 sequence, ''Serial Uniqueness (Serial_Type)'', Decode(serial_number_type, 
''1'', ''1 (Within inventory model and items)'', 
''2'', ''2 (Unique within organization)'', 
''3'', ''3 (Unique across organizations)'', 
''4'', ''4 (Unique within inventory items)'', serial_number_type) SERIAL_NUMBER_TYPE 
 from mtl_parameters mp 
 where organization_id = ##$$ORGID$$##
union 
select 3.3 sequence, ''Serial Generation'', NVL((select lookup_code || '' (''|| meaning || '')'' from mfg_lookups where lookup_type = ''MTL_SERIAL_GENERATION'' and lookup_code = serial_number_generation), serial_number_generation) serial_number_generation  from mtl_parameters mp 
 where organization_id = ##$$ORGID$$##
union 
select 3.4 sequence, ''Lot Uniqueness'', NVL((select lookup_code || '' (''|| meaning || '')'' from mfg_lookups where lookup_type = ''MTL_LOT_UNIQUENESS'' and lookup_code = lot_number_uniqueness), lot_number_uniqueness) lot_number_uniqueness  from mtl_parameters mp 
 where organization_id = ##$$ORGID$$##
union 
select 3.5 sequence, ''Lot Generation'', NVL((select lookup_code || '' (''|| meaning || '')'' from mfg_lookups where lookup_type = ''MTL_LOT_GENERATION'' and lookup_code = lot_number_generation), lot_number_generation) lot_number_generation  from mtl_parameters mp 
 where organization_id = ##$$ORGID$$##
 )
order by sequence',
      p_title                  => 'Key Current Warehouse Parameters',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Provide a listing of organization details as a reference. Note : See "SERIAL_NUMBER_TYPE" column for the serial number uniqueness. ',
      p_solution               => '',
      p_success_msg            => 'No organizations found.',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '29'
      );
   l_info.delete;
debug('end add_signature: INV_ORGANIZATIONS_FULL_OUTPUT_ORG');



debug('begin add_signature: LOGPR_ORG_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10379',
      p_sig_id                 => 'LOGPR_ORG_PARAMETERS',
      p_sig_sql                => 'SELECT mp.organization_code                                   "Org Code", 
       mp.organization_id                                     "Organization Id", 
       mpm.organization_code                                  "Master Org Code", 
       mp.master_organization_id 
       "Master Organization Id", 
       mpc.organization_code                                  "Cost Org Code", 
       mp.cost_organization_id 
       "Cost Organization Id", 
       mp.wms_enabled_flag                                    "WMS Enabled", 
       Decode(To_char(Nvl(mp.pregen_putaway_tasks_flag, 2)), 1, ''Yes'', 
                                                             2, ''No'', 
       To_char(mp.pregen_putaway_tasks_flag)) 
       || '' ('' 
       || Nvl(mp.pregen_putaway_tasks_flag, 2) 
       || '')'' 
       "Pregenerate after Receipt", 
       mp.regeneration_interval 
       "Regeneration Interval (Mins)", 
       Decode(mp.negative_inv_receipt_code, 1, ''Yes'', 
                                            ''No'') 
       "Negative Balances Allowed", 
       Decode(mp.primary_cost_method, 1, ''Standard'', -- valid for 11.5.10 
                                      2, ''Average'', 
                                      3, ''Periodic Average'', 
                                      4, ''Periodic Incremental LIFO'', 
                                      5, ''FIFO'', 
                                      6, ''LIFO'', 
                                      mp.primary_cost_method) 
       "Primary Cost Method", 
       mp.default_cost_group_id 
       "Default Cost Group Id", 
       mp.avg_rates_cost_type_id 
       "Avg.Rates Cost Type Id", 
       Decode(mp.serial_number_generation, 1, ''At organization level'', 
                                           -- valid for 11.5.10 
                                           2, ''At item level'', 
                                           3, ''User Defined'', 
                                           mp.serial_number_generation) 
       "Serial Number Generation", 
       Decode(mp.lot_number_uniqueness, 1, ''Unique for item'', 
                                        -- valid for 11.5.10 
                                        2, ''No uniqueness'', 
                                        mp.lot_number_uniqueness) 
       "Lot Number Uniqueness", 
       Decode(mp.lot_number_generation, 1, ''At organization level'', 
                                        -- valid for 11.5.10 
                                        2, ''At item level'', 
                                        3, ''User Defined'', 
                                        mp.lot_number_generation) 
       "Lot Number Generation", 
       Decode(mp.serial_number_type, 1, ''Unique within inventory items'', 
                                     2, ''Unique within organization'', 
                                     3, ''Unique across organizations'', 
                                     mp.serial_number_type) 
       "Serial Number Type", 
       Decode(mp.stock_locator_control_code, 1, ''None'', --/ valid for 11.5.10 
                                             2, ''Prespecified'', 
                                             3, ''Dynamic entry'', 
                                             4, ''At subinventory level'', 
                                             5, ''At item level'', 
                                             mp.stock_locator_control_code) 
                                                              "Locator Control", 
       mp.wsm_enabled_flag                                    "WSM Enabled", 
       Decode(To_char(Nvl(mp.project_reference_enabled, 2)), ''1'', ''Yes'', 
                                                             ''2'', ''No'', 
       To_char(mp.project_reference_enabled)) 
       || '' ('' 
       || mp.project_reference_enabled 
       || '')'' 
       "Project Reference Enabled", 
       Decode(To_char(Nvl(mp.crossdock_flag, 2)), 1, ''Yes'', 
                                                  2, ''No'', 
                                                  To_char(mp.crossdock_flag)) 
       || '' ('' 
       || Nvl(mp.crossdock_flag, 2) 
       || '')'' 
       "Opportunistic Crossdock", 
       mp.default_crossdock_criteria_id 
       "Crossdock Criteria ID", 
       mp.default_put_away_rule_id, 
       mp.default_crossdock_subinventory 
       "DEFAULT MFG CROSSDOCK SUBINV" 
FROM   mtl_parameters mp, 
       mtl_parameters mpc, 
       mtl_parameters mpm 
WHERE  mp.cost_organization_id = mpc.organization_id 
       AND mp.master_organization_id = mpm.organization_id 
       AND mp.organization_id IN (SELECT wdd.organization_id
FROM   wsh_delivery_details wdd
WHERE  wdd.source_code    = ''OE''
AND    wdd.source_header_id = ##$$SOHEADERID$$##
AND    wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id))
ORDER BY mp.organization_id',
      p_title                  => 'Organization Parameter Details',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Provide a listing of organization details as a reference.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: LOGPR_ORG_PARAMETERS');



debug('begin add_signature: LOGPR_PJM_ORG_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10534',
      p_sig_id                 => 'LOGPR_PJM_ORG_PARAMETERS',
      p_sig_sql                => 'select pop.ORGANIZATION_ID 
,mp.organization_Code "Org Code"
,pop.PROJECT_REFERENCE_ENABLED "Project References Enabled ?"	
,decode(pop.PROJECT_CONTROL_LEVEL,1,''Project'',2,''Task'')	"Project Control Level"
,pop.COMMON_PROJECT_ID	"Common Project ID"
,INV_PROJECT.GET_PROJECT_NUMBER(pop.COMMON_PROJECT_ID) "Common Project"
,COST_GROUP_ACCOUNTING "Cost Group Option"
,pop.ALLOW_CROSS_PROJ_ISSUES "Allow Cross Project Issues"	
,pop.ALLOW_CROSS_UNITNUM_ISSUES "Allow Cross Unit Number Issues"
,pop.ALLOW_CROSS_PROJ_PICKWAVEALLOC "Allow Cross Proj PickWaveAlloc"
from PJM_ORG_PARAMETERS_V pop, mtl_parameters mp
where pop.organization_id = mp.organization_id
and mp.project_reference_enabled = ''1''
and pop.organization_id in (Select distinct wdd.organization_id 
from wsh_delivery_details wdd, oe_order_lines_all ol
where wdd.source_line_id = ol.line_id
and wdd.source_header_id = ol.header_id
and wdd.source_code = ''OE''
and wdd.released_status in (''R'',''B'',''S'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
)',
      p_title                  => 'Sales Order Project Manufacturing Organizations',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Listing Organizations associated with the Sales Order that are Project Manufacturing (PJM) enabled.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: LOGPR_PJM_ORG_PARAMETERS');



debug('begin add_signature: LOGPR_WSH_SHIPPING_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11357',
      p_sig_id                 => 'LOGPR_WSH_SHIPPING_PARAMETERS',
      p_sig_sql                => 'select WSP.ORGANIZATION_ID "Org ID" ,
WSP.LOCATION_ID "Loc ID" ,
WSP.WEIGHT_UOM_CLASS "Weight UOM" ,
WSP.VOLUME_UOM_CLASS "Volume UOM" ,
WSP.WEIGHT_VOLUME_FLAG "Weight Flag" ,
WSP.INV_CONTROLS_CONTAINER_FLAG "INV Control" ,
WSP.PERCENT_FILL_BASIS_FLAG "Fill PC" ,
WSP.PACK_SLIP_REQUIRED_FLAG "Pack Slip Req" ,
WSP.PICK_SEQUENCE_RULE_ID "Pick Seq" ,
WSP.PICK_GROUPING_RULE_ID "Pick Group" ,
WSP.PRINT_PICK_SLIP_MODE "Print Mode" ,
WSP.DEFAULT_STAGE_SUBINVENTORY "Def Stage" ,
WSP.AUTODETAIL_PR_FLAG "Auto Allocate" ,
WSP.TASK_PLANNING_FLAG "Plan Task",
WSP.DYNAMIC_REPLENISHMENT_FLAG "Pull Replenishment",
WSP.ENFORCE_SHIP_SET_AND_SMC "Enforce Ship Set/Ship Models",
WSP.GROUP_BY_CUSTOMER_FLAG "Customer" ,
WSP.GROUP_BY_FOB_FLAG "FOB" ,
WSP.AUTOCREATE_DEL_ORDERS_FLAG "Autocreate Delivery Criteria",
WSP.APPENDING_LIMIT "Appending Limit",
WSP.GROUP_BY_FREIGHT_TERMS_FLAG "Freight Terms" ,
WSP.GROUP_BY_INTMED_SHIP_TO_FLAG "Intmed Shipto" ,
WSP.GROUP_BY_SHIP_METHOD_FLAG "Ship Method" ,
WSP.GROUP_BY_CARRIER_FLAG "Carrier" ,
WGP.DEFER_INTERFACE "Defer Inter" ,
WGP.ENFORCE_SHIP_METHOD "Enforce"
from WSH_SHIPPING_PARAMETERS WSP, WSH_GLOBAL_PARAMETERS WGP
WHERE
    WSP.organization_id IN (select distinct wdd.organization_id
from wsh_delivery_details wdd, oe_order_lines_all ol
where wdd.source_line_id = ol.line_id
and wdd.source_header_id = ol.header_id
and wdd.source_code = ''OE''
and wdd.released_status in (''R'',''B'',''S'')
and wdd.source_header_id = ##$$SOHEADERID$$##
and wdd.source_line_id = NVL(##$$SOLINEID$$##, wdd.source_line_id))',
      p_title                  => 'Shipping Organization Parameters',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Organization Shipping Parameters.',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '3'
      );
   l_info.delete;
debug('end add_signature: LOGPR_WSH_SHIPPING_PARAMETERS');



debug('begin add_signature: LOGPR_WIP_JOB_HEADER');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10715',
      p_sig_id                 => 'LOGPR_WIP_JOB_HEADER',
      p_sig_sql                => 'SELECT WDJ.ORGANIZATION_ID								ORG_ID,
       MP.ORGANIZATION_CODE								ORG_CODE,
       OOD.OPERATING_UNIT								OP_UNIT_ID,	   
       WDJ.WIP_ENTITY_ID,
       SUBSTRB(WE.WIP_ENTITY_NAME, 1, 30)						WIP_ENTITY_NAME,   
       DECODE(WDJ.FIRM_PLANNED_FLAG, 1, ''YES'', ''NO'')					FIRM,
       MLE.MEANING									ENTITY_TYPE,              
       DECODE(WDJ.JOB_TYPE, 1, ''Standard'', 3, ''NonStandard'')				JOB_TYPE,
       MLS.MEANING									STATUS_TYPE,
       PJM_PROJECT.ALL_PROJ_IDTONUM(WDJ.PROJECT_ID)					PROJECT_NUMBER,
       PJM_PROJECT.ALL_TASK_IDTONUM(WDJ.TASK_ID)					TASK_NUMBER,	   
       SERIALIZATION_START_OP								SER_START_OP,
       DECODE(WDJ.OVERCOMPLETION_TOLERANCE_TYPE, 1, ''PERCENT'', 2, ''AMOUNT'') TOL_TYPE,
       WDJ.OVERCOMPLETION_TOLERANCE_VALUE						TOL_VALUE,
       SUBSTRB(WDJ.DESCRIPTION, 1, 30)							DJ_DESC
  FROM WIP_DISCRETE_JOBS		WDJ,
       WIP_ENTITIES			WE,
       APPS.MTL_PARAMETERS		MP,
       MFG_LOOKUPS			MLE,
       MFG_LOOKUPS			MLS,
       APPS.ORG_ORGANIZATION_DEFINITIONS OOD	   
 WHERE WE.WIP_ENTITY_ID = ##$$JOBID$$##
   AND WE.WIP_ENTITY_ID = WDJ.WIP_ENTITY_ID
   AND WDJ.ORGANIZATION_ID = WE.ORGANIZATION_ID
   AND WDJ.ORGANIZATION_ID = MP.ORGANIZATION_ID
   AND WDJ.ORGANIZATION_ID = OOD.ORGANIZATION_ID   
   AND (WE.ENTITY_TYPE = MLE.LOOKUP_CODE AND MLE.LOOKUP_TYPE=''WIP_ENTITY'')
   AND (WDJ.STATUS_TYPE = MLS.LOOKUP_CODE AND MLS.LOOKUP_TYPE=''WIP_JOB_STATUS'')',
      p_title                  => 'Discrete Job Header Information',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Discrete Job Header information.',
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
debug('end add_signature: LOGPR_WIP_JOB_HEADER');



debug('begin add_signature: LOGPR_WIP_JOB_OPERATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10716',
      p_sig_id                 => 'LOGPR_WIP_JOB_OPERATIONS',
      p_sig_sql                => 'SELECT WO.OPERATION_SEQ_NUM AS OP_SEQ_NUM,
       WO.OPERATION_SEQUENCE_ID AS OP_SEQ_ID,
       WO.STANDARD_OPERATION_ID AS STD_OP_ID,
       BSO.OPERATION_CODE AS STD_OP_CODE,
       WO.DEPARTMENT_ID AS DEPT_ID,
       BD.DEPARTMENT_CODE AS DEPT,
       WO.FIRST_UNIT_START_DATE FUSD,
       WO.FIRST_UNIT_COMPLETION_DATE FUCD,
       WO.LAST_UNIT_START_DATE LUSD,
       WO.LAST_UNIT_COMPLETION_DATE LUCD,
       WO.SCHEDULED_QUANTITY SCHED_QTY,
       WO.QUANTITY_IN_QUEUE QQUEUE,
       WO.QUANTITY_RUNNING QRUNNING,
       WO.QUANTITY_WAITING_TO_MOVE QWAITMOVE,
       WO.QUANTITY_REJECTED QREJECTED,
       WO.QUANTITY_SCRAPPED QSCRAPED,
       WO.QUANTITY_COMPLETED QCOMPLETED,
       WO.PREVIOUS_OPERATION_SEQ_NUM PREV_OP_SEQ_NUM,
       WO.NEXT_OPERATION_SEQ_NUM NEXT_OP_SEQ_NUM,
       DECODE(WO.COUNT_POINT_TYPE, 1, ''YES'', ''NO'') COUNTPOINT,
       DECODE(WO.BACKFLUSH_FLAG, 1, ''YES'', ''NO'') BACKFLUSH,
       --DECODE(WO.CHECK_SKILL, 1, ''YES'', ''NO'') CHECKSKILL,
       WO.DATE_LAST_MOVED,
       SUBSTRB(WO.DESCRIPTION, 1, 30) OP_DESC
  FROM WIP_OPERATIONS WO, BOM_DEPARTMENTS BD, BOM_STANDARD_OPERATIONS BSO
 WHERE WO.WIP_ENTITY_ID = ##$$JOBID$$##
   AND WO.DEPARTMENT_ID = BD.DEPARTMENT_ID
   AND WO.ORGANIZATION_ID = BD.ORGANIZATION_ID
   AND WO.STANDARD_OPERATION_ID = BSO.STANDARD_OPERATION_ID(+)
   AND WO.ORGANIZATION_ID = BSO.ORGANIZATION_ID(+)
 ORDER BY 1',
      p_title                  => 'Discrete Job Operations',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Existing Discrete Job Operations.',
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
debug('end add_signature: LOGPR_WIP_JOB_OPERATIONS');



debug('begin add_signature: LOGPR_WIP_JOB_REQUIREMENTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10717',
      p_sig_id                 => 'LOGPR_WIP_JOB_REQUIREMENTS',
      p_sig_sql                => 'SELECT WRO.OPERATION_SEQ_NUM OP_SEQ_NUM,
       WRO.COMPONENT_SEQUENCE_ID COMP_SEQ_ID,
       WRO.INVENTORY_ITEM_ID ITEM_ID,
       SUBSTRB(MSI.CONCATENATED_SEGMENTS, 1, 30) ITEM_NAME,
       DECODE(MSI.STOCK_ENABLED_FLAG, ''Y'', ''YES'', ''NO'') STOCKABLE,
       DECODE(WRO.WIP_SUPPLY_TYPE,
              1,''PUSH'',
              2,''ASSEMBLY PULL'',
              3,''OPERATION PULL'',
              4,''BULK'',
              5,''SUPPLIER'',
              6,''PHANTOM'',
              7,''BASED ON BILL'',
              WRO.WIP_SUPPLY_TYPE) SUPPLY_TYPE,
       WRO.REQUIRED_QUANTITY QREQ,
       WRO.QUANTITY_ISSUED QISS,
       WRO.QUANTITY_PER_ASSEMBLY Q_PER_ASS,
       WRO.QUANTITY_ALLOCATED QALLOC,
       WRO.QUANTITY_BACKORDERED QBACK,
       WRO.QUANTITY_RELIEVED QRELIEVED,
       WRO.SUPPLY_SUBINVENTORY SUPPLY_SUBINV,
       (SELECT CONCATENATED_SEGMENTS FROM MTL_ITEM_LOCATIONS_KFV WHERE INVENTORY_LOCATION_ID = WRO.SUPPLY_LOCATOR_ID) SUPPLY_LOCATOR,
       DECODE(MSI.LOT_CONTROL_CODE, 1, ''No'', ''Yes'') LOT_CONTROL,
       DECODE(MSI.SERIAL_NUMBER_CONTROL_CODE,1,''No'',2,''Predefined'',6,''At Sales Order Issue'',5,''At Receipt'') SERIAL_CONT
  FROM WIP_REQUIREMENT_OPERATIONS WRO, MTL_SYSTEM_ITEMS_KFV MSI
 WHERE WRO.WIP_ENTITY_ID = ##$$JOBID$$##
   AND WRO.INVENTORY_ITEM_ID = MSI.INVENTORY_ITEM_ID(+)
   AND WRO.ORGANIZATION_ID = MSI.ORGANIZATION_ID(+)
 ORDER BY 1, 3',
      p_title                  => 'Discrete Job Material Requirements',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Discrete Job Material Requirements.',
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
debug('end add_signature: LOGPR_WIP_JOB_REQUIREMENTS');



debug('begin add_signature: LOGPR_WIP_JOB_TXN_MMT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10718',
      p_sig_id                 => 'LOGPR_WIP_JOB_TXN_MMT',
      p_sig_sql                => 'SELECT MMT.TRANSACTION_ID TRANS_ID,
       MMT.TRANSACTION_DATE TRANS_DATE,
       MMT.TRANSACTION_TYPE_ID TRANS_TYPE_ID,
       MMT.TRANSACTION_ACTION_ID TRANS_ACT_ID,
       MTT.TRANSACTION_TYPE_NAME TRANS_MEANING,
       MMT.INVENTORY_ITEM_ID ITEM_ID,
       SUBSTRB(MSI.CONCATENATED_SEGMENTS, 1, 30) ITEM_NAME,
       MMT.SUBINVENTORY_CODE SUBINV,
       MMT.LOCATOR_ID LOC_ID,
       MMT.OPERATION_SEQ_NUM OP_SEQ_NUM,
       MMT.TRANSACTION_QUANTITY TRANS_QTY,
       MMT.PRIMARY_QUANTITY PRIM_QTY,
       MMT.TRANSACTION_UOM TRANS_UOM,
       MMT.MOVE_TRANSACTION_ID MOVE_TRANS_ID,
       MMT.COMPLETION_TRANSACTION_ID COMPL_TRANS_ID,
       MMT.SOURCE_CODE,
       MMT.SOURCE_LINE_ID,
       MMT.MOVE_ORDER_LINE_ID,
       MMT.ACTUAL_COST,
       MMT.ACCT_PERIOD_ID ACC_PER_ID,
       DECODE(MMT.COSTED_FLAG, ''N'', ''UNCOSTED'', ''E'', ''ERROR'', ''COSTED'') COSTED,
       MMT.CREATION_DATE,
       MMT.LAST_UPDATE_DATE,
       MMT.ERROR_CODE,
       SUBSTR(MMT.ERROR_EXPLANATION, 1, 100) ERROR_EXPLANATION
  FROM MTL_MATERIAL_TRANSACTIONS MMT,
       MTL_SYSTEM_ITEMS_KFV      MSI,
       MTL_TRANSACTION_TYPES     MTT
 WHERE MMT.TRANSACTION_SOURCE_TYPE_ID in (5,13)
   AND MMT.TRANSACTION_SOURCE_ID = ##$$JOBID$$##
   AND MMT.INVENTORY_ITEM_ID = MSI.INVENTORY_ITEM_ID(+)
   AND MMT.ORGANIZATION_ID = MSI.ORGANIZATION_ID(+)
   AND MMT.TRANSACTION_TYPE_ID = MTT.TRANSACTION_TYPE_ID
   AND MMT.TRANSACTION_ACTION_ID = MTT.TRANSACTION_ACTION_ID
 ORDER BY MMT.TRANSACTION_ID',
      p_title                  => 'Discrete Job Material Transactions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Existing Discrete Job Material Transactions.',
      p_solution               => 'MMT records.',
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
debug('end add_signature: LOGPR_WIP_JOB_TXN_MMT');



debug('begin add_signature: LOGPR_WIP_JOB_TXN_MMTT');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10719',
      p_sig_id                 => 'LOGPR_WIP_JOB_TXN_MMTT',
      p_sig_sql                => 'SELECT TRANSACTION_TEMP_ID		TRANS_TEMP_ID,
       TRANSACTION_HEADER_ID		TRANS_HEADER_ID,
       SOURCE_CODE			SRC_CODE,
       SOURCE_LINE_ID			SRC_LINE_ID,
       TRANSACTION_MODE			TRANS_MODE,
       LOCK_FLAG			LOCKFLAG,
       TRANSACTION_DATE			TRANS_DATE,
       MMTT.TRANSACTION_TYPE_ID		TRANS_TYPE_ID,   
       MMTT.TRANSACTION_ACTION_ID	TRANS_ACT_ID,
       MTT.TRANSACTION_TYPE_NAME	TRANS_TYPE_NAME,
       MMTT.TRANSACTION_SOURCE_ID	TRANS_SOURCE_ID,
       INVENTORY_ITEM_ID 		ITEM_ID,
       SUBINVENTORY_CODE		SUBINV_CODE,
       LOCATOR_ID			LOC_ID,
       REVISION,
       TRANSACTION_QUANTITY		TRANS_QTY,
       TRANSACTION_UOM			TRANS_UOM,
       PRIMARY_QUANTITY			PRIM_QTY,
       ACCT_PERIOD_ID,	   
       TRX_SOURCE_LINE_ID,
       TRX_SOURCE_DELIVERY_ID,
       OVERCOMPLETION_TRANSACTION_QTY	OVERCOMPL_TRANS_QTY,
       OVERCOMPLETION_PRIMARY_QTY	OVERCOMPL_PRIM_QTY,
       OVERCOMPLETION_TRANSACTION_ID	OVERCOMPL_TRANS_ID,
       MOVE_TRANSACTION_ID		MOVE_TRANS_ID,
       COMPLETION_TRANSACTION_ID	COMPL_TRANS_ID,
       SOURCE_CODE,
       SOURCE_LINE_ID,
       TRANSFER_ORGANIZATION		TRF_ORG,
       TRANSFER_SUBINVENTORY		TRF_SUBINV,
       TRANSFER_TO_LOCATION		TRF_LOC,
       MOVE_ORDER_LINE_ID,
       RESERVATION_ID,
       MMTT.CREATION_DATE,
       MMTT.LAST_UPDATE_DATE,
       ERROR_CODE,
       SUBSTR(ERROR_EXPLANATION, 1, 100) ERROR_MESSAGE          
  FROM MTL_MATERIAL_TRANSACTIONS_TEMP MMTT, MTL_TRANSACTION_TYPES MTT
 WHERE MMTT.TRANSACTION_SOURCE_TYPE_ID in (5,13)
   AND MMTT.TRANSACTION_SOURCE_ID = ##$$JOBID$$##
   AND MMTT.TRANSACTION_TYPE_ID = MTT.TRANSACTION_TYPE_ID
   AND MMTT.TRANSACTION_ACTION_ID = MTT.TRANSACTION_ACTION_ID	   
 ORDER BY 1',
      p_title                  => 'Discrete Job Temporary Material Transaction(s)',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Existing temporary Discrete Job Material Transactions.',
      p_solution               => 'MMTT records.',
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
debug('end add_signature: LOGPR_WIP_JOB_TXN_MMTT');



debug('begin add_signature: LOGPR_WIP_JOB_ITEMS_DJ');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '9946',
      p_sig_id                 => 'LOGPR_WIP_JOB_ITEMS_DJ',
      p_sig_sql                => 'SELECT MSIK.CONCATENATED_SEGMENTS,
       WRO.INVENTORY_ITEM_ID,
       WRO.ORGANIZATION_ID,
       MP.ORGANIZATION_CODE,
       WRO.OPERATION_SEQ_NUM,
       DECODE(WRO.WIP_SUPPLY_TYPE,1,''Push'',2,''Assembly Pull'',3,''Operation Pull'') Supply_Type,
       WRO.SUPPLY_SUBINVENTORY,
       WRO.SUPPLY_LOCATOR_ID,
       WRO.QUANTITY_ALLOCATED,
       WRO.QUANTITY_BACKORDERED,
       WRO.QUANTITY_RELIEVED,
       WRO.REQUIRED_QUANTITY,
       WE.WIP_ENTITY_NAME,
       WE.WIP_ENTITY_ID
  FROM WIP_REQUIREMENT_OPERATIONS WRO,
       MTL_SYSTEM_ITEMS_KFV       MSIK,
       WIP_OPERATIONS             WO,
       WIP_ENTITIES               WE,
       MTL_PARAMETERS             MP,
       WIP_DISCRETE_JOBS          WDJ
 WHERE WE.WIP_ENTITY_ID = WRO.WIP_ENTITY_ID
   AND WDJ.WIP_ENTITY_ID = WRO.WIP_ENTITY_ID
   AND WRO.WIP_ENTITY_ID = ##$$JOBID$$##
   AND (WRO.REQUIRED_QUANTITY -
       (NVL(WIP_PICKING_PUB.QUANTITY_ALLOCATED(WRO.WIP_ENTITY_ID,
                                                WRO.OPERATION_SEQ_NUM,
                                                WRO.ORGANIZATION_ID,
                                                WRO.INVENTORY_ITEM_ID,
                                                WRO.REPETITIVE_SCHEDULE_ID,
                                                WRO.QUANTITY_ISSUED),
             0) + WRO.QUANTITY_ISSUED)) >= 0.00001
   AND WRO.WIP_SUPPLY_TYPE IN (1, 2, 3)
   AND WRO.INVENTORY_ITEM_ID = MSIK.INVENTORY_ITEM_ID
   AND MSIK.ORGANIZATION_ID = ##$$JOBORGID$$##
   AND WRO.WIP_ENTITY_ID = WO.WIP_ENTITY_ID(+)
   AND WRO.OPERATION_SEQ_NUM = WO.OPERATION_SEQ_NUM(+)
   AND (WO.COUNT_POINT_TYPE IS NULL OR WO.COUNT_POINT_TYPE IN (1, 2))
   AND MSIK.MTL_TRANSACTIONS_ENABLED_FLAG = ''Y''
   AND MP.ORGANIZATION_ID = WRO.ORGANIZATION_ID
   AND ((WE.ENTITY_TYPE != 6 AND (WRO.WIP_ENTITY_ID in (Select WIP_ENTITY_ID from WIP_JOB_OPEN_ALLOCATIONS_V))) OR
       (WE.ENTITY_TYPE = 6  AND WDJ.STATUS_TYPE in (3, 4)))
 ORDER BY WRO.OPERATION_SEQ_NUM, MSIK.CONCATENATED_SEGMENTS',
      p_title                  => 'Items To Be Picked For Discrete Job Number',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Items to be picked for this Discrete Job.',
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
debug('end add_signature: LOGPR_WIP_JOB_ITEMS_DJ');



debug('begin add_signature: LOGPR_WIP_JOB_PICKING_JOBS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10398',
      p_sig_id                 => 'LOGPR_WIP_JOB_PICKING_JOBS',
      p_sig_sql                => 'SELECT distinct we.wip_entity_name,
                we.organization_id,
                we.wip_entity_id,
                wdj.description job_description,
                msik.concatenated_segments primary_item,
                msik.description primary_item_description,
                we.primary_item_id,
                decode (wdj.status_type, 3, ''3 - RELEASED'', 4, ''4 - COMPLETE'') status_type,
            --    ml.meaning status,
                min(wro.date_required) first_open_requirements_date,
                wdj.scheduled_start_date start_date,
                wdj.scheduled_completion_date completion_date,
                wdj.end_item_unit_number,
                wdj.project_id,
                wdj.task_id,
                wl.line_code,
                wsg.schedule_group_name,
                wdj.build_sequence
  from wip_entities               we,
       mtl_system_items_kfv       msik,
       wip_discrete_jobs          wdj,
       wip_requirement_operations wro,
   --    mfg_lookups                ml,
       wip_parameters             wp,
       wip_lines                  wl,
       wip_operations             wo,
       wip_schedule_groups        wsg
 where we.organization_id = ##$$JOBORGID$$##
   and we.wip_entity_id = wdj.wip_entity_id
   and we.primary_item_id = msik.inventory_item_id(+)
   and we.organization_id = msik.organization_id(+)
   and we.entity_type = 1
   and wdj.schedule_group_id = wsg.schedule_group_id(+)
   and wdj.organization_id = wsg.organization_id(+)
 --  and wdj.status_type = ml.lookup_code
   and wdj.status_type in (3, 4)
   and wdj.line_id = wl.line_id(+)
 --  and ml.lookup_type = ''WIP_JOB_STATUS''
   and wro.wip_entity_id = we.wip_entity_id
   and wp.organization_id = we.organization_id
   and wro.wip_entity_id = wo.wip_entity_id(+)
   and wro.operation_seq_num = wo.operation_seq_num(+)
   and (wo.count_point_type in (1, 2) or wo.count_point_type is null)
   and ((wro.supply_subinventory is null and
       (wro.required_quantity -
       (nvl(wro.quantity_issued, 0) +
       nvl((select sum(nvl(mtrl.quantity, 0) -
                          nvl(mtrl.quantity_delivered, 0))
                 from mtl_txn_request_lines mtrl
                where mtrl.txn_source_id = wro.wip_entity_id
                  and mtrl.txn_source_line_id = wro.operation_seq_num
                  and mtrl.organization_id = wro.organization_id
                  and inventory_item_id = wro.inventory_item_id
                  and mtrl.line_status in 7
                  and mtrl.transaction_type_id = 35
                group by mtrl.organization_id,
                         mtrl.txn_source_id,
                         mtrl.txn_source_line_id,
                         mtrl.inventory_item_id),
               0))) >= 0.00001) or
       (wro.supply_subinventory is not null and
       (wro.required_quantity -
       (greatest(nvl(wro.quantity_issued, 0),
                    nvl((select sum(nvl(mtrl.quantity, 0))
                          from mtl_txn_request_lines mtrl
                         where mtrl.txn_source_id = wro.wip_entity_id
                           and mtrl.txn_source_line_id =
                               wro.operation_seq_num
                           and mtrl.organization_id = wro.organization_id
                           and inventory_item_id = wro.inventory_item_id
                           and mtrl.line_status in (5, 7)
                           and mtrl.transaction_type_id = 51
                         group by mtrl.organization_id,
                                  mtrl.txn_source_id,
                                  mtrl.txn_source_line_id,
                                  mtrl.inventory_item_id),
                        0)))) >= 0.00001))
   and ((wp.allocate_backflush_components = ''Y'' and
       wro.wip_supply_type in (1, 2, 3)) or ((wp.allocate_backflush_components = ''N'' or
       wp.allocate_backflush_components is null) and
       wro.wip_supply_type = 1))
 group by we.wip_entity_name,
          we.organization_id,
          we.wip_entity_id,
          wdj.description,
          msik.concatenated_segments,
          msik.description,
          we.primary_item_id,
          wdj.status_type,
  --        ml.meaning,
          wdj.scheduled_start_date,
          wdj.scheduled_completion_date,
          wdj.end_item_unit_number,
          wdj.project_id,
          wdj.task_id,
          wl.line_code,
          wsg.schedule_group_name,
          wdj.build_sequence',
      p_title                  => 'WIP Jobs With Open Requirements',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Returns jobs having open requirements. If no jobs returned then there is no job eligible for WIP Component Pick Release.',
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
debug('end add_signature: LOGPR_WIP_JOB_PICKING_JOBS');



debug('begin add_signature: LOGPR_WIP_JOB_RESERVABLE_SUB_JOB');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10325',
      p_sig_id                 => 'LOGPR_WIP_JOB_RESERVABLE_SUB_JOB',
      p_sig_sql                => 'select msi.secondary_inventory_name Supply_Subinventory,
       decode (msi.reservable_type, 1, ''RESERVABLE'', ''NON-RESERVABLE''),
       mp.organization_code,
       msik.concatenated_segments,
       decode ( wro.wip_supply_type, 1, ''Push'', 2, ''Assembly Pull'', 3, ''Operation Pull'') Supply_Type, 
       wp.allocate_backflush_components
  from mtl_system_items_kfv msik,
       mtl_parameters mp,
       wip_requirement_operations wro,
       wip_parameters wp,
       mtl_secondary_inventories msi
 where msik.organization_id = wro.organization_id
   and msi.secondary_inventory_name = wro.supply_subinventory
   and msi.organization_id = mp.organization_id
   and wro.organization_id = mp.organization_id
   and mp.organization_id = wp.organization_id
   and wro.wip_entity_id = ##$$JOBID$$##
   and wro.organization_id  = ##$$JOBORGID$$##
   and wro.inventory_item_id = msik.inventory_item_id
   and ((wro.wip_supply_type = 1 and nvl(wp.allocate_backflush_components, ''N'') = ''N'') 
   OR (wro.wip_supply_type in (2,3) and nvl(wp.allocate_backflush_components, ''N'') = ''Y''))',
      p_title                  => 'Reservable Subinventories In WIP Material Requirements',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'For the given Job(s), one or more material requirements are using a reservable supply subinventory. WIP Pick Release cannot work when they need to perform Backflush Transfer to a reservable subinventory. Please note that supply subinventory is the staging subinventory where the materials resides after moving them from the source subinventories. 
Source subinventories are the ones to be set to allow reservations.',
      p_solution               => 'Please change the supply subinventory to a non-reservable subinventory or change the definition of the subinventory (not to allow reservations). See [1075181/KB751535] for full details.',
      p_success_msg            => '',
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
debug('end add_signature: LOGPR_WIP_JOB_RESERVABLE_SUB_JOB');



debug('begin add_signature: LOGPR_WIP_JOB_RESERVABLE_SUB_WIP_PARAM');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10395',
      p_sig_id                 => 'LOGPR_WIP_JOB_RESERVABLE_SUB_WIP_PARAM',
      p_sig_sql                => 'select msi.secondary_inventory_name Supply_Subinventory,
       decode(msi.reservable_type, 1, ''RESERVABLE'', ''NON-RESERVABLE'') Reservable,
       mp.organization_code
  from mtl_parameters mp, wip_parameters wp, mtl_secondary_inventories msi
 where msi.organization_id = mp.organization_id
   and wp.organization_id = mp.organization_id
   and wp.default_pull_supply_subinv = msi.secondary_inventory_name
   and nvl(wp.allocate_backflush_components, ''N'') = ''Y''
   and msi.reservable_type = 1
   and mp.organization_id = ##$$JOBORGID$$##',
      p_title                  => 'Reservable Subinventories In WIP Parameters',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'This Organization has a Reservable Subinventory set for the "Default Supply Subinventory" parameter in WIP Parameters form. This setup is not supported for WIP Component Picking process. (WIP Pick/Release cannot be used when supply subinventory is reservable).',
      p_solution               => 'Please set the Default Supply Subinventory as Non-Reservable. See [1075181/KB751535] for full details.',
      p_success_msg            => '',
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
debug('end add_signature: LOGPR_WIP_JOB_RESERVABLE_SUB_WIP_PARAM');



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



debug('begin add_signature: LANGUAGES_INSTALLED_DETAILS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '362',
      p_sig_id                 => 'LANGUAGES_INSTALLED_DETAILS',
      p_sig_sql                => 'SELECT language_code,
decode(INSTALLED_FLAG ,''B'',''Base Installed Language'',''I'',''Additional Installed Language'',''D'',''Not Installed'') "Type",
nls_language "Language",
nls_territory "Territory"
FROM FND_LANGUAGES
where INSTALLED_FLAG in (''B'',''I'')
order by LANGUAGE_CODE',
      p_title                  => 'Languages Installed',
      p_fail_condition         => 'RSGT1',
      p_problem_descr          => 'This is a data collection of languages installed.<br>
Useful documentation: [399789/FAQ6955] NLS Frequently Asked Questions<br>
Advice: If you have untranslated issues, follow [252422/KB860741] Requesting Translation Synchronization Patches<br>
-> this will synchronize your languages with actual US level<br>
Note! This is just an advice. This does not mean your NLS is not synchronized! Follow this step ONLY if you have translation issues.',
      p_solution               => '',
      p_success_msg            => 'This is a data collection of languages installed.
',
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
debug('end add_signature: LANGUAGES_INSTALLED_DETAILS');



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



debug('begin add_signature: AC_OTHER_FILE_VERSIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5501',
      p_sig_id                 => 'AC_OTHER_FILE_VERSIONS',
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
and (af.app_short_name = ''##$$FK2$$##'') 
/* or fa.application_id = ##$$FK1$$## ) */
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
af.filename


/*
select distinct
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
   af.filename
*/',
      p_title                  => 'Other File Versions',
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
      p_version                => '22'
      );
   l_info.delete;
debug('end add_signature: AC_OTHER_FILE_VERSIONS');



debug('begin add_signature: AC_INVALID_OBJECTS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '6055',
      p_sig_id                 => 'AC_INVALID_OBJECTS',
      p_sig_sql                => 'SELECT a.object_name "Object Name",
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
             WHERE c.owner = a.owner
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
    AND a.owner = ''APPS''
    AND REGEXP_LIKE (a.object_name, ''^##$$FK2$$##\w+|oracle/apps/##$$FK2$$##/.+'',''i'')
    AND a.status = ''INVALID''',
      p_title                  => 'Invalid Objects',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Invalid objects exist.',
      p_solution               => '<ul>
      <li>NOTE: These may have no impact on your instance. These
          are listed for your information.</li>      
      <li>Recompile the individual objects or recompile the 
          entire APPS schema using the adadmin utility.</li>
      <li>Review any error messages provided and see [1527251/KB724238]
          for details on compiling these invalid objects.</li>
</ul>',
      p_success_msg            => 'No invalid ##$$FK2$$## objects were found.',
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
debug('end add_signature: AC_INVALID_OBJECTS');



debug('begin add_signature: PORCVANLAZ_AC_FILE_VERISONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '11370',
      p_sig_id                 => 'PORCVANLAZ_AC_FILE_VERISONS',
      p_sig_sql                => 'select fa.application_short_name as "##$$FK2$$##", fa.application_short_name as APPLICATION_SHORT_NAME, fal.APPLICATION_NAME
from fnd_application fa, fnd_application_all_view fal
where fa.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
and fa.application_short_name = fal.application_short_name
union
select distinct substr(ft.table_name, 1, instr(ft.table_name, ''_'')-1) as "##$$FK2$$##", substr(ft.table_name, 1, instr(ft.table_name, ''_'')-1) as APPLICATION_SHORT_NAME, fal.APPLICATION_NAME
from fnd_tables ft, fnd_application_all_view fal
where ft.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
and substr(ft.table_name, 1, instr(ft.table_name, ''_'')-1) = fal.application_short_name
union
select ''MTL'' as "##$$FK2$$##", ''MTL'' as APPLICATION_SHORT_NAME, fal.APPLICATION_NAME
from dual, fnd_application_all_view fal
where 401 in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
and ''INV'' = fal.application_short_name
union
select ''ECX'' as "##$$FK2$$##", ''ECX'' as APPLICATION_SHORT_NAME, fal.APPLICATION_NAME
from dual, fnd_application_all_view fal
where 201 in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
and ''ECX'' = fal.application_short_name
union
select ''RCV'' as "##$$FK2$$##", ''RCV'' as APPLICATION_SHORT_NAME, ''Receiving'' as APPLICATION_NAME
from dual, fnd_application_all_view fal
where 201 in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
and ''PO'' = fal.application_short_name
union
select ''CTO'' as "##$$FK2$$##", ''CTO'' as APPLICATION_SHORT_NAME, fal.APPLICATION_NAME
from dual, fnd_application_all_view fal
where 702 in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
and ''CTO'' = fal.application_short_name
union
select ''OM'' as "##$$FK2$$##", ''OM'' as APPLICATION_SHORT_NAME, fal.APPLICATION_NAME
from dual, fnd_application_all_view fal
where 660 in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
and ''OM'' = fal.application_short_name
union
select ''CST'' as "##$$FK2$$##", ''CST'' as APPLICATION_SHORT_NAME, ''Cost Management'' as APPLICATION_NAME
from dual, fnd_application_all_view fal
where 701 in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
and ''BOM'' = fal.application_short_name ',
      p_title                  => 'File Versions',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'File Versions',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL('AC_PLSQL_FILE_VERSIONS','AC_OTHER_FILE_VERSIONS','AC_INVALID_OBJECTS'),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '30'
      );
   l_info.delete;
debug('end add_signature: PORCVANLAZ_AC_FILE_VERISONS');



debug('begin add_signature: AC_PRODUCT_PROFILE_VALUES');
   l_info('##MASK##LEVEL VALUE'):= 'NO_MASK';
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5504',
      p_sig_id                 => 'AC_PRODUCT_PROFILE_VALUES',
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
WHERE e.application_id like ##$$FK8$$##
AND a.profile_option_id = e.profile_option_id
AND a.level_value = b.application_id(+)
AND a.level_value = c.responsibility_id(+)
AND a.level_value = d.user_id(+)
AND t.profile_option_name = e.profile_option_name
AND t.LANGUAGE = ''US''
AND nvl(c.LANGUAGE,''US'') = ''US''
AND ((a.level_id = 10003 AND a.level_value = nvl(fnd_profile.value(''resp_id''), a.level_value))
OR (a.level_id = 10004 AND a.level_value = nvl(fnd_profile.value(''user_id''), a.level_value))
OR (a.level_id = 10001 )
OR (a.level_id = 10002 ))
ORDER BY user_profile_option_name, a.level_id ',
      p_title                  => 'Profile Values',
      p_fail_condition         => 'RS',
      p_problem_descr          => ' Profile Values',
      p_solution               => '',
      p_success_msg            => '',
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
debug('end add_signature: AC_PRODUCT_PROFILE_VALUES');



debug('begin add_signature: AC_PROFILE_OPTIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5503',
      p_sig_id                 => 'AC_PROFILE_OPTIONS',
      p_sig_sql                => 'SELECT tl.Application_name, 
        b.application_short_name,
            b.application_id "##$$FK8$$##",
            b.product_code "##$$FK9$$##"
       FROM fnd_application_tl tl, fnd_application b
      WHERE b.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
        AND tl.application_id = b.application_id
        AND tl.language = ''US''',
      p_title                  => 'Profile Options',
      p_fail_condition         => 'RS',
      p_problem_descr          => ' Profile Options',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('ALWAYS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL('AC_PRODUCT_PROFILE_VALUES'),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '30'
      );
   l_info.delete;
debug('end add_signature: AC_PROFILE_OPTIONS');



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



debug('begin add_signature: AC_CUSTOM_DATABASE_TRIGGERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5507',
      p_sig_id                 => 'AC_CUSTOM_DATABASE_TRIGGERS',
      p_sig_sql                => 'SELECT atrg.table_owner,
       atrg.table_name,
       atrg.trigger_name,
       atrg.trigger_type,
       atrg.triggering_event,
       atrg.status
FROM all_triggers atrg, fnd_application fa
WHERE fa.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
AND atrg.table_owner = fa.application_short_name
AND atrg.trigger_name like ''XX%''
AND atrg.status <> ''DISABLED''
ORDER BY atrg.table_owner, atrg.table_name, atrg.trigger_type',
      p_title                  => 'Potential Custom Database Triggers',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Potential Custom Database Triggers.',
      p_solution               => 'Disable custom database triggers.

For assistance, see the following <a href="https://docs.oracle.com/cd/B28359_01/server.111/b28310/general004.htm" target="_blank">Oracle documentation</a>',
      p_success_msg            => 'No custom database triggers detected.',
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
debug('end add_signature: AC_CUSTOM_DATABASE_TRIGGERS');



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



debug('begin add_signature: AC_DATABASE_TRIGGERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5506',
      p_sig_id                 => 'AC_DATABASE_TRIGGERS',
      p_sig_sql                => 'SELECT  atrg.table_owner, 
        atrg.table_name, 
        atrg.trigger_name, 
        atrg.trigger_type, 
        atrg.triggering_event, 
        atrg.status
FROM  all_triggers atrg, fnd_application fa
WHERE fa.application_id in (##$$APPS_PARAM1$$##,##$$APPS_PARAM2$$##,##$$APPS_PARAM3$$##,##$$APPS_PARAM4$$##,##$$APPS_PARAM5$$##)
AND   atrg.table_owner  = fa.application_short_name
ORDER BY atrg.table_owner, atrg.table_name, atrg.trigger_type',
      p_title                  => 'Database Triggers',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Database triggers do not exist.',
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
debug('end add_signature: AC_DATABASE_TRIGGERS');



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



debug('begin add_signature: AC_CUSTOM_PACKAGES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '13352',
      p_sig_id                 => 'AC_CUSTOM_PACKAGES',
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
and   (o.object_name like ''XX\_%'' escape ''\'')
and   s.line between 2 and 3
and   s.text like ''%Header: %''
order by 1, 3 desc, 5 desc',
      p_title                  => 'Custom Packages',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Per the EBS Development Standards'' Guide, Custom File Naming Standard are prefixed with "XX". <br><br>
NOTE: The following are NOT custom.  Per Bug 8707567, these are not custom, these were created to preserve backward compatibility. <br>
XX_BPEL_CALLPROCESSORDEREBS11I <br>
XX_BPEL_EBS11I10ATPCHECK',
      p_solution               => 'Refer to Guidance for Integrating Custom and Third-Party Products With Oracle E-Business Suite Release 12.2 [1916149/KB443952] for customizing EBS.
',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: AC_CUSTOM_PACKAGES');



debug('begin add_signature: EBS_MFG_OM_AC_CUSTOM_APPLICATIONS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '24722',
      p_sig_id                 => 'EBS_MFG_OM_AC_CUSTOM_APPLICATIONS',
      p_sig_sql                => 'SELECT fav.application_name app_name,
       fav.application_short_name app_s_name,
       fav.application_id app_id
  FROM fnd_application_vl fav
 WHERE ( ( fav.application_name LIKE ''XX\_%'' ESCAPE ''\'' )
    OR ( fav.application_short_name LIKE ''XX\_%'' ESCAPE ''\'' )
    OR ( fav.application_name LIKE ''%Custom %'' ESCAPE ''\'' ) )',
      p_title                  => 'Custom Applications',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Custom Products installed.  ',
      p_solution               => 'Refer to [1916149/KB443952] for integrating custom and third-party products.',
      p_success_msg            => '',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('Y','N'),
      p_version                => '7'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_OM_AC_CUSTOM_APPLICATIONS');



debug('begin add_signature: BOM_VPD_POLICY_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '14977',
      p_sig_id                 => 'BOM_VPD_POLICY_CHECK',
      p_sig_sql                => 'SELECT V.object_owner
      ,V.object_name
      ,o.object_type
      ,V.policy_group
      ,V.POLICY
      ,V.predicate
      ,P.PACKAGE
      ,P.FUNCTION, P.ENABLE
FROM
    (  -- From signature "DISABLE ANY CUSTOM VPD POLICIES"
     SELECT DISTINCT object_owner, object_name, policy_group, POLICY, predicate
       FROM v$vpd_policy 
      WHERE object_owner IN(''BOM'',''ENG'',''INV'',''WMS'',''EGO'')
        AND POLICY <> ''ZD_SEED'' 
        AND POLICY <> ''FND_VAULT''
   ) V
  , dba_objects o
  , dba_policies P
WHERE V.object_owner = o.OWNER
  AND V.object_name = o.object_name
  AND V.object_name = P.object_name
  AND V.object_owner = P.object_owner
ORDER BY V.object_owner, V.object_name, o.object_type',
      p_title                  => 'Virtual Private Database Policies',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'One or more custom Virtual Database Policy (VPD) has been detected.
In some cases, it may be required to temporarily disable these when testing certain issues involving the database object (e.g. table) for which the VPD Policy was created.',
      p_solution               => 'Refer to the following document for an example of disabling a VPD policy.
<ul>
<li>[2542049/KB778230] - How To Use Database Policies / Virtual Private Database (VPD) To Restrict Data In Application and SQL (Subinventory Example)?</li>
</ul>',
      p_success_msg            => 'No Virtual Database Policies were detected.',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: BOM_VPD_POLICY_CHECK');



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



debug('begin add_signature: ONT_DB_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5401',
      p_sig_id                 => 'ONT_DB_PARAMETERS',
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
      p_title                  => 'Database Parameter Settings',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Database Parameter Settings.',
      p_solution               => '',
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
debug('end add_signature: ONT_DB_PARAMETERS');



debug('begin add_signature: ONT_DB_RELEASE_INFO');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5397',
      p_sig_id                 => 'ONT_DB_RELEASE_INFO',
      p_sig_sql                => 'select ''Hostname = '' || host_name "Details" FROM v$instance
union
SELECT ''Platform = '' ||SUBSTR(REPLACE(REPLACE(pcv1.product, ''TNS for ''), '':'' )||pcv2.status, 1, 80)
FROM product_component_version pcv1,
product_component_version pcv2
WHERE UPPER(pcv1.product) LIKE ''%TNS%''
AND UPPER(pcv2.product) LIKE ''%ORACLE%''
AND ROWNUM = 1
union
SELECT ''DB Name = '' ||instance_name ||  ''   ''||  sys_context(''USERENV'',''DB_NAME'') "Instance" from v$instance
union
SELECT ''Database               = '' || '||mask_text(g_DBbanner, nvl( upper(''), 'NO_MASK') )||' db_version from v$version where rownum = 1
union
SELECT ''Language = ''||value FROM V$NLS_PARAMETERS WHERE parameter in (''NLS_LANGUAGE'',''NLS_CHARACTERSET'')
union
SELECT ''Creation Date = '' ||to_char(created, ''DD-MON-YYYY HH:MI:SS'') created from v$database
union 
select ''EBS Release = '' ||OE_CODE_CONTROL.Get_Code_Release_Level from dual',
      p_title                  => 'Database / Release / Tools Information',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'No Database / Release / Tools Details found.',
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
debug('end add_signature: ONT_DB_RELEASE_INFO');



debug('begin add_signature: ONT_PATCHES_APPLIED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5413',
      p_sig_id                 => 'ONT_PATCHES_APPLIED',
      p_sig_sql                => 'select
    distinct
    aap.patch_name
  , substr(aap.patch_type, 1, 8) patch_type
  , aap.creation_date
  , ab.application_short_name
  from  ad_applied_patches aap,
        ad_patch_run_bugs ab
  where ab.application_short_name in (''QP'',''RLM'',''ONT'',''INV'',''WSH'' )
   and   ab.orig_bug_number        = aap.patch_name
  order by ab.application_short_name, aap.creation_date desc',
      p_title                  => 'Patches Applied',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'Patches Applied',
      p_solution               => '',
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
debug('end add_signature: ONT_PATCHES_APPLIED');



debug('begin add_signature: ONT_SHIPPING_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5411',
      p_sig_id                 => 'ONT_SHIPPING_PARAMETERS',
      p_sig_sql                => 'SELECT DISTINCT
       wsp.organization_id "Org ID",
       ood.organization_code "Org Code",
       wsp.weight_uom_class "Weight UOM Class",
       muom1.description "Weight UOM",
       wsp.volume_uom_class "Volume UOM Class",
       muom2.description "Volume UOM",
       decode(wsp.percent_fill_basis_flag,
              ''W'', ''Weight'',
              ''V'', ''Volume'',
              ''Q'', ''Quantity'',
              ''N'', ''None'') "Percent Fill Basis",
       wpsr.name "Release Sequence Rule",
       wpgr.name "Pick Slip Grouping Rule",
       decode(wsp.print_pick_slip_mode,
              ''I'', ''Immediate'',
              ''E'', ''At the End'') "Print Pick Slip",
       wrs1.name "Default Pick Release Doc Set",
       wsp.default_stage_subinventory "Default Stage Subinventory",
       wsp.autocreate_deliveries_flag "Autocreate Deliveries",
       wsp.autodetail_pr_flag "Auto Allocate",
       wsp.enforce_ship_set_and_smc "Enforce Ship Sets and Models",
       wrs2.name "Default Ship Confirm Doc Set",
       wscr.name "Ship Confirm Rule",
       
       wsp.group_by_customer_flag "Delivery Grp: Customer",
       wsp.group_by_intmed_ship_to_flag "Delivery Grp: Int med Ship To",
       wsp.group_by_freight_terms_flag "Delivery Grp: Freight Terms",
       wsp.group_by_ship_method_flag "Delivery Grp: Ship Method",
       wsp.group_by_fob_flag "Delivery Grp: FOB",
       --wsp.group_by_header_type_flag "Delivery Grp: Order Type",
       --wsp.group_by_ship_set_flag "Delivery Grp: Ship Set",
       --wsp.group_by_ship_priority_flag "Delivery Grp: Ship Priority",
       
       decode(wsp.autocreate_del_orders_flag,
              ''Y'', ''Within an Order'',
              ''N'', ''Across Orders'') "Autocreate Delivery Crit",
       wsp.otm_enabled "OTM Enabled"
FROM wsh_shipping_parameters wsp,
     org_organization_definitions ood,
     mtl_units_of_measure_vl muom1,
     mtl_units_of_measure_vl muom2,
     wsh_pick_sequence_rules wpsr,
     wsh_pick_grouping_rules wpgr,
     wsh_report_sets wrs1,
     wsh_report_sets wrs2,
     wsh_ship_confirm_rules wscr
 WHERE wsp.organization_id = ood.organization_id
   AND wsp.weight_uom_class = muom1.uom_class
   AND muom1.base_uom_flag=''Y''
   AND wsp.volume_uom_class = muom2.uom_class
   AND muom2.base_uom_flag=''Y''
   AND wsp.pick_sequence_rule_id = wpsr.pick_sequence_rule_id(+)      
   AND wsp.pick_grouping_rule_id = wpgr.pick_grouping_rule_id(+)      
   AND wsp.pick_release_report_set_id = wrs1.report_set_id(+)
   AND wsp.delivery_report_set_id = wrs2.report_set_id(+)
   AND wsp.ship_confirm_rule_id = wscr.ship_confirm_rule_id(+)
ORDER BY 2',
      p_title                  => 'Shipping Parameters',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'There is no shipping parameters.',
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
debug('end add_signature: ONT_SHIPPING_PARAMETERS');



debug('begin add_signature: ONT_SYSTEM_PARAMETERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '5409',
      p_sig_id                 => 'ONT_SYSTEM_PARAMETERS',
      p_sig_sql                => 'select decode(t1.seeded_flag, ''Y'', ''Yes'', ''N'', ''No'', NULL) "Seeded Flag",
decode(t1.enabled_flag, ''Y'', ''Yes'', ''N'', ''No'', NULL) "Enabled Flag",
decode(t1.open_orders_check_flag, ''W'', ''Give Warning'', ''E'', ''Error'', ''N'', ''Allow'', NULL) "Open Orders Check Flag",
t1.category_code "Category Code", 
t2.name "Name"
from OE_SYS_PARAMETER_DEF_TL t2,
OE_SYS_PARAMETER_DEF_B t1
where t2.parameter_code = t1.parameter_code
and t2.language = USERENV(''LANG'')
order by  t1.category_code , t2.Name',
      p_title                  => 'OM System Parameters',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'System Parameters',
      p_solution               => '',
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
debug('end add_signature: ONT_SYSTEM_PARAMETERS');



debug('begin add_signature: EBS_MFG_OM_ONT_ONTSO_SYSTEM_PARAMETERS_VALUES');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '22531',
      p_sig_id                 => 'EBS_MFG_OM_ONT_ONTSO_SYSTEM_PARAMETERS_VALUES',
      p_sig_sql                => 'SELECT  t3.org_id "Org ID",
    ol1.meaning "Category",
       t2.name "Name",
       oe_sys_parameters_util.get_value(t1.value_set_id, t3.parameter_value) "Value"
FROM oe_sys_parameters_all   t3,
     oe_sys_parameter_def_tl t2,
     oe_sys_parameter_def_b  t1,
     oe_lookups ol1
WHERE t2.parameter_code = t1.parameter_code
      AND t2.language = ''US''
      AND t3.parameter_code = t2.parameter_code
      AND ol1.lookup_type=''OM_PARAMETER_CATEGORY''
      AND ol1.lookup_code=t1.category_code
order by t3.org_id, t1.category_code, t2.name
',
      p_title                  => 'OM System Parameter Values',
      p_fail_condition         => 'NRS',
      p_problem_descr          => 'OM System Parameters Values ',
      p_solution               => '',
      p_success_msg            => '',
      p_print_condition        => nvl('SUCCESS','ALWAYS'),
      p_fail_type              => nvl('I','W'),
      p_print_sql_output       => nvl('RS','RS'),
      p_limit_rows             => nvl('N','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '2'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_OM_ONT_ONTSO_SYSTEM_PARAMETERS_VALUES');



debug('begin add_signature: LOGPR_DEFAULT_STAGING_SETUP');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10421',
      p_sig_id                 => 'LOGPR_DEFAULT_STAGING_SETUP',
      p_sig_sql                => 'SELECT mp.organization_id,
  mp.organization_Code,
  mp.wms_enabled_flag,
  wsp.default_stage_subinventory,
  wsp.default_stage_locator_id
FROM wsh_shipping_parameters wsp,
  mtl_parameters mp
WHERE wsp.organization_id = mp.organization_id
AND wsp.organization_id  IN
  (SELECT wdd.organization_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
  )
AND ( wsp.default_stage_subinventory IS NULL
OR ( wsp.default_stage_subinventory  IS NOT NULL
AND EXISTS
  (SELECT 1
  FROM mtl_secondary_inventories msi
  WHERE msi.secondary_inventory_name = wsp.default_stage_subinventory
  AND msi.organization_id            = wsp.organization_id
  AND msi.locator_type              IN (2,3)
  )
AND wsp.default_stage_locator_id IS NULL ))',
      p_title                  => 'Missing Default Staging Subinventory/Locator Setup',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Default Staging Subinventory/Locator Setup is missing, this will cause the Picking Process to fail.',
      p_solution               => 'Review Default Staging Subinventory/Locator setup and ensure that default values are setup as necessary.
<ul><li>Refer to [579969/KB765639] for full details.</li></ul>',
      p_success_msg            => 'No missing Default Staging Subinventory/Locator Setup was found. ',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_DEFAULT_STAGING_SETUP');



debug('begin add_signature: LOGPR_INVALID_RULE_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10425',
      p_sig_id                 => 'LOGPR_INVALID_RULE_CHECK',
      p_sig_sql                => 'SELECT OWNER,
  Object_name,
  Object_type,
  Created,
  Last_DDL_TIME,
  STATUS
FROM all_objects
WHERE status     = ''INVALID''
AND object_name IN
  (SELECT upper(''WMS_RULE_PUT_PKG''
    ||package_name_count)
  FROM wms_rule_list_package
  WHERE rule_type = ''PUTAWAY''
  )
UNION
SELECT OWNER,
  Object_name,
  Object_type,
  Created,
  Last_DDL_TIME,
  STATUS
FROM all_objects
WHERE status     = ''INVALID''
AND object_name IN
  (SELECT upper(''WMS_RULE_PICK_PKG''
    ||package_name_count)
  FROM wms_rule_list_package
  WHERE rule_type = ''PICK''
  )',
      p_title                  => 'Invalid WMS_Rule Packages Exist',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'If there are any invalid WMS_RULE packages, it can result in errors during pick release process.',
      p_solution               => '<ul><li>Refer to [761810/KB711729] Pick Release Fails Due To Invalid Rule Packages Following Upgrade for full details.</li></ul>',
      p_success_msg            => 'There are no invalid WMS_RULE packages.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_INVALID_RULE_CHECK');



debug('begin add_signature: LOGPR_EXPIRED_LOT_ONHAND');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10426',
      p_sig_id                 => 'LOGPR_EXPIRED_LOT_ONHAND',
      p_sig_sql                => 'SELECT DISTINCT ood.organization_code "Organization Code",
  kfv.concatenated_segments "Item Name",
  kfv.description "Item Description",
  moqd.subinventory_code "Subinventory Code",
  (SELECT concatenated_segments
  FROM mtl_item_locations_kfv k
  WHERE k.inventory_location_id = moqd.locator_id
  AND k.organization_id         = moqd.organization_id
  )"Locator",
  lot.lot_number "Lot Number",
  TRUNC(lot.origination_date) "Origination Date",
  TRUNC(lot.expiration_date) "Expiration Date",
  (TRUNC(lot.expiration_date) - TRUNC(sysdate)) "Number of Days to expire"
FROM mtl_lot_numbers lot,
  mtl_system_items_kfv kfv,
  mtl_onhand_quantities_detail moqd,
  org_organization_definitions ood
WHERE lot.inventory_item_id                        =kfv.inventory_item_id
AND lot.organization_id                            =kfv.organization_id
AND lot.inventory_item_id                          =moqd.inventory_item_id
AND lot.organization_id                            =moqd.organization_id
AND lot.lot_number                                 =moqd.lot_number
AND kfv.SHELF_LIFE_CODE                           IN (2,4)
AND ood.organization_id                            = moqd.organization_id
AND (moqd.organization_id,moqd.inventory_item_id) IN
  (SELECT wdd.organization_id ,
    wdd.inventory_item_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id)
  )
AND (TRUNC(lot.expiration_date) - TRUNC(sysdate)) <= NVL(1, (TRUNC(lot.expiration_date) - TRUNC(sysdate)))
ORDER BY ood.organization_code,
  (TRUNC(lot.expiration_date) - TRUNC(sysdate))',
      p_title                  => 'Onhand Quantity in Lot Numbers Which are Expired',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There exists onhand quantity related to this Order/Line in lots which are expired.',
      p_solution               => 'Expired lots are not able to be auto allocated. Review [1569895/KB732324] for full details.',
      p_success_msg            => 'There does not exist any onhand quantity related to this Order/Line in expired lots.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_EXPIRED_LOT_ONHAND');



debug('begin add_signature: LOGPR_INVALID_ONHAND_STATUS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10432',
      p_sig_id                 => 'LOGPR_INVALID_ONHAND_STATUS',
      p_sig_sql                => 'SELECT moqd.organization_id,mtp.organization_code,mtp.default_status_id default_org_material_status, decode(moqd.status_id, -1, ''-1'', NULL, ''NULL'', ''OTHER VALUE'') onhand_status, count(*)
FROM mtl_onhand_quantities_detail moqd ,mtl_parameters mtp
WHERE (moqd.status_id = -1 or moqd.status_id IS NULL)
 AND mtp.organization_id = moqd.organization_id
 AND moqd.organization_id IN (
SELECT wdd.organization_id
FROM   wsh_delivery_details wdd
WHERE  wdd.source_code    = ''OE''
AND    wdd.released_status IN ( ''R'',''B'',''S'')
AND    wdd.source_header_id = NVL(##$$SOHEADERID$$##, wdd.source_header_id)
AND    wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id))
AND EXISTS (SELECT ''X'' FROM mtl_parameters
   WHERE organization_id = moqd.organization_id
    AND default_status_id IS NOT NULL)
  GROUP BY moqd.organization_id,mtp.organization_code,mtp.default_status_id, decode(moqd.status_id, -1, ''-1'', NULL, ''NULL'', ''OTHER VALUE'')',
      p_title                  => 'Onhand with Invalid Status',
      p_fail_condition         => '[VALUE]<[0]',
      p_problem_descr          => 'There is at least one item that has an onhand quantity record in the MTL_ONHAND_QUANTITIES_DETAIL (MOQD) Table with an invalid STATUS_ID.',
      p_solution               => 'See [1458327/KB782178] - Unable To Transact Move Order Where Onhand Quantity With STATUS_ID = -1 OR NULL, for full details.',
      p_success_msg            => 'No items exist with an invalid onhand status.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: LOGPR_INVALID_ONHAND_STATUS');



debug('begin add_signature: LOGPR_MATERIAL_STATUS_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10419',
      p_sig_id                 => 'LOGPR_MATERIAL_STATUS_CHECK',
      p_sig_sql                => 'SELECT mp.Organization_code "Organization Code",
  moqd.organization_id "Org ID",
  SUBSTR(msi.segment1,1,15) "Item Name",
  moqd.inventory_item_id "Item ID",
  moqd.subinventory_code "Subinventory",
  moqd.revision "Revision",
  moqd.locator_id "Locator ID",
  milk.concatenated_segments "Locator",
  moqd.cost_group_id "cost group id",
  moqd.lot_number "Lot Number",
  moqd.lpn_id "LPN ID",
  SUM(moqd.transaction_quantity) "Transaction Quantity",
  (SELECT status_code FROM mtl_material_statuses WHERE status_id = moqd.status_id
  ) "Onhand Status"
FROM mtl_onhand_quantities_detail moqd,
  mtl_system_items_b msi,
  mtl_parameters mp,
  MTL_ITEM_LOCATIONS_KFV milk
WHERE moqd.organization_id                              = msi.organization_id
AND moqd.inventory_item_id                              = msi.inventory_item_id
AND milk.inventory_location_id (+)                   = moqd.locator_id
AND milk.organization_id (+)                         = moqd.organization_id
AND msi.organization_id                                = mp.organization_id
AND moqd.organization_id                                = mp.organization_id
AND msi.serial_number_control_code                    IN (1,6)
AND mp.default_status_id                            IS NOT NULL
AND NVL(FND_PROFILE.VALUE(''INV_MATERIAL_STATUS''), 2) = 1
AND (moqd.organization_id, moqd.inventory_item_id)        IN
  (SELECT wdd.organization_id,
    wdd.inventory_item_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
  )
AND ((inv_detail_util_pvt.is_onhand_status_trx_allowed(52,moqd.organization_id , moqd.inventory_item_id , moqd.subinventory_code, moqd.locator_id, moqd.lot_number, moqd.lpn_id ) = ''N'')
OR (inv_detail_util_pvt.is_onhand_status_trx_allowed(53,moqd.organization_id , moqd.inventory_item_id , moqd.subinventory_code, moqd.locator_id, moqd.lot_number, moqd.lpn_id )   = ''N'') )
GROUP BY mp.Organization_code ,
  moqd.organization_id ,
  SUBSTR(msi.segment1,1,15),
  moqd.inventory_item_id ,
  moqd.subinventory_code ,
  moqd.revision ,
  moqd.locator_id ,
  milk.concatenated_segments ,
  moqd.cost_group_id ,
  moqd.lot_number ,
  moqd.lpn_id,
  moqd.Status_id',
      p_title                  => 'Onhand Material Status Exists Which Disallows Pick Release',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There exists on hand with material status which disallows Pick Release staging transfer transactions, these will cause Pick Release to fail.',
      p_solution               => '<ul><li>Refer to [2073542/KB732801] How to Troubleshoot Insufficient Quantity Errors from Pick Release, for full details.</li></ul>',
      p_success_msg            => 'There is no on hand with material status which disallows Pick Release staging transfer transactions.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_MATERIAL_STATUS_CHECK');



debug('begin add_signature: LOGPR_ORPHAN_MO_ALLOC');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10437',
      p_sig_id                 => 'LOGPR_ORPHAN_MO_ALLOC',
      p_sig_sql                => 'select
 mmtt.trx_source_line_id
,mmtt.transaction_source_id
,mmtt.transaction_temp_id
,mmtt.move_order_header_id
,mmtt.move_order_line_id
,mmtt.organization_id
,mmtt.inventory_item_id
,mmtt.transaction_type_id
,mmtt.primary_quantity
from
 mtl_material_transactions_temp mmtt
where mmtt.move_order_line_id is not null
and (mmtt.organization_id ,mmtt.inventory_item_id) IN
      (SELECT wdd.organization_id,
        wdd.inventory_item_id
      FROM wsh_delivery_details wdd
      WHERE wdd.source_code    = ''OE''
      AND wdd.released_status IN ( ''R'',''B'',''S'')
      AND wdd.source_header_id = NVL(##$$SOHEADERID$$##, wdd.source_header_id)
      AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
      )
and not exists (
select null
from mtl_txn_request_lines mtrl
where mtrl.line_id = mmtt.move_order_line_id
)
order by
 mmtt.trx_source_line_id
,mmtt.transaction_temp_id',
      p_title                  => 'Checking for Orphan Move Orders in Pending Transactions',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Identifies pick wave move orders that exist in the Pending Transactions Table MTL_MATERIAL_TRANSACTIONS_TEMP but are missing from the Move Orders Table MTL_TXN_REQUEST_LINES. This scenario makes it not possible to process the move order.',
      p_solution               => 'There are two datafix scripts that need to be ran for this issue, i2471362.sql and INVCLRMO.sql. See [1471606/KB162436] for full details.',
      p_success_msg            => 'There is no move order missing from the MTL_TXN_REQUEST_LINES Move Order Table.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '6'
      );
   l_info.delete;
debug('end add_signature: LOGPR_ORPHAN_MO_ALLOC');



debug('begin add_signature: LOGPR_ORPHAN_RSV');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10433',
      p_sig_id                 => 'LOGPR_ORPHAN_RSV',
      p_sig_sql                => 'select * from (
select ''a. Extraneous reservations but order line canceled'' explanation,
l.line_id
,l.header_id
,m.reservation_id
,m.organization_id
,m.inventory_item_id
,m.primary_reservation_quantity
from
oe_order_lines_all l
,mtl_reservations m
where  l.header_id = ##$$SOHEADERID$$##
and l.line_id  = NVL(##$$SOLINEID$$##, l.line_id)
AND m.demand_source_line_id = l.line_id
and m.demand_source_type_id in (2,8)
and m.primary_reservation_quantity > 0
and nvl(l.cancelled_flag,''N'')=''Y''
and l.cancelled_quantity is not null
and not exists (
select null
from mtl_transactions_interface mti
where mti.trx_source_line_id = l.line_id
and mti.source_header_id = l.header_id
and mti.source_code = ''ORDER ENTRY''
)
UNION
select ''b. Extraneous reservations but order line has been closed or delivery detail is canceled'' explanation,
l.line_id
,l.header_id
,m.reservation_id
,m.organization_id
,m.inventory_item_id
,m.primary_reservation_quantity
from
oe_order_lines_all l
,mtl_reservations m
where l.header_id = ##$$SOHEADERID$$##
and l.line_id  = NVL(##$$SOLINEID$$##, l.line_id)
AND m.demand_source_line_id = l.line_id
and m.demand_source_type_id in (2,8)
and m.primary_reservation_quantity > 0
and nvl(l.open_flag,''Y'')=''N''
and not exists (
select null
from mtl_transactions_interface mti
where mti.trx_source_line_id = l.line_id
and mti.source_header_id = l.header_id
and mti.source_code = ''ORDER ENTRY''
)
and not exists (
select null
from wsh_delivery_details wdd
where wdd.source_line_id = l.line_id
and wdd.source_code =''OE''
and wdd.inv_interfaced_flag in (''N'',''P'')
and wdd.released_status <> ''D''
)
UNION
select ''c. Extraneous reservations but order line is deleted'' explanation,
m.demand_source_line_id line_id
,m.demand_source_header_id
,m.reservation_id
,m.organization_id
,m.inventory_item_id
,m.primary_reservation_quantity
from mtl_sales_orders mso
,mtl_reservations m
where m.demand_source_header_id = mso.sales_order_id
and m.demand_source_type_id in (2,8)
and (m.organization_id ,m.inventory_item_id) IN
      (SELECT wdd.organization_id,
        wdd.inventory_item_id
      FROM wsh_delivery_details wdd
      WHERE wdd.source_code    = ''OE''
      AND wdd.released_status IN ( ''R'',''B'',''S'')
      AND wdd.source_header_id = NVL(##$$SOHEADERID$$##, wdd.source_header_id)
      AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
      )
and not exists (
select null
from oe_order_lines_all l
where l.line_id = m.demand_source_line_id
))
order by
line_id
,reservation_id',
      p_title                  => 'Orphan Reservations',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'One or more Orphan reservations exist. This may cause errors like "The material sourcing process failed to create picking suggestions for line" or "Pick Release process could not allocate # of item XXX for order NNNN as there was insufficient quantity available Or Inventory allocations have failed, and the line has been back ordered". These reservations can affect the onhand available picture, which can cause material allocation to fail.',
      p_solution               => 'There are two datafix scripts that need to be ran for this issue, i2471362.sql and INVCLRMO.sql. See [1471606/KB162436] for full details.',
      p_success_msg            => 'There are no orphaned reservations.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '5'
      );
   l_info.delete;
debug('end add_signature: LOGPR_ORPHAN_RSV');



debug('begin add_signature: LOGPR_ORPHAN_MO_NO_SHP_TRAN');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10560',
      p_sig_id                 => 'LOGPR_ORPHAN_MO_NO_SHP_TRAN',
      p_sig_sql                => 'select
 mtrl.txn_source_line_id
,mtrl.txn_source_id
,mtrl.header_id
,mtrh.request_number
,mtrl.line_number
,mtrl.line_id
,mtrl.organization_id
,mtrl.inventory_item_id
,mtrl.primary_quantity
from
 mtl_txn_request_headers mtrh
,mtl_txn_request_lines mtrl
where mtrl.line_status = 7
and mtrl.header_id = mtrh.header_id
and mtrh.move_order_type = 3
and (mtrl.organization_id ,mtrl.inventory_item_id) IN
      (SELECT wdd.organization_id,
        wdd.inventory_item_id
      FROM wsh_delivery_details wdd
      WHERE wdd.source_code    = ''OE''
      AND wdd.released_status IN ( ''R'',''B'',''S'')
      AND wdd.source_header_id = ##$$SOHEADERID$$##
      AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
      )
and not exists (
select null
from wsh_delivery_details wdd
where wdd.move_order_line_id = mtrl.line_id
and wdd.released_status = ''S''
)
order by
 mtrl.txn_source_line_id
,mtrl.line_id',
      p_title                  => 'Invalid Open Pick Wave Move Order Lines',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'There are Open Sales Order Pick Wave Move Order lines when there is no Pending Shipping Transaction.',
      p_solution               => 'There are two datafix scripts that need to be ran for this issue, i2471362.sql and INVCLRMO.sql. See [1471606/KB162436] for full details.',
      p_success_msg            => 'No open pick wave move order lines exist where there are no pending shipping transactions.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_ORPHAN_MO_NO_SHP_TRAN');



debug('begin add_signature: LOGPR_ORPHAN_MO_ALLOC_CLOSED_MO');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10439',
      p_sig_id                 => 'LOGPR_ORPHAN_MO_ALLOC_CLOSED_MO',
      p_sig_sql                => 'select
 mtrl.txn_source_line_id
,mtrl.txn_source_id
,mmtt.transaction_temp_id
,mtrl.header_id
,mtrl.line_number
,mtrl.line_id
,mmtt.organization_id
,mmtt.inventory_item_id
,mmtt.transaction_type_id
,mmtt.primary_quantity
from
 mtl_txn_request_lines mtrl
,mtl_material_transactions_temp mmtt
where mmtt.move_order_line_id = mtrl.line_id
and mtrl.line_status = 5
and (mmtt.organization_id ,mmtt.inventory_item_id) IN
      (SELECT wdd.organization_id,
        wdd.inventory_item_id
      FROM wsh_delivery_details wdd
      WHERE wdd.source_code    = ''OE''
      AND wdd.released_status IN ( ''R'',''B'',''S'')
      AND wdd.source_header_id = NVL(##$$SOHEADERID$$##, wdd.source_header_id)
      AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
      )
order by
 mtrl.txn_source_line_id
,mmtt.transaction_temp_id',
      p_title                  => 'Invalid Allocation For Closed Move Order Lines',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Identifies invalid allocation records where the move order line is closed.',
      p_solution               => 'Review [1471606/KB162436] Inventory Standard Datafix Instruction #16: Fixing Stuck Transaction With Error Occurred While Relieving Reservations Due To Incorrect Or Negative Availability : Fix: i2471362.sql + INVCLRMO.sql, for full details.',
      p_success_msg            => 'There are No invalid allocation records where the move order line is missing.',
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
debug('end add_signature: LOGPR_ORPHAN_MO_ALLOC_CLOSED_MO');



debug('begin add_signature: LOGPR_MARKED_SERIAL_NUMBERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10431',
      p_sig_id                 => 'LOGPR_MARKED_SERIAL_NUMBERS',
      p_sig_sql                => 'SELECT msn.serial_number, 
msn.inventory_item_id, 
msn.current_organization_id,
msn.current_subinventory_code, 
msn.current_locator_id,
msn.current_status,
msn.group_mark_id, 
msn.line_mark_id, 
msn.lot_line_mark_id
FROM mtl_serial_numbers msn
WHERE (msn.current_organization_id ,msn.inventory_item_id) IN (SELECT wdd.organization_id,
        wdd.inventory_item_id
      FROM wsh_delivery_details wdd
      WHERE wdd.source_code    = ''OE''
      AND wdd.released_status IN ( ''R'',''B'',''S'')
      AND wdd.source_header_id = ##$$SOHEADERID$$## 
      AND wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id)
      )
AND (msn.group_mark_id IS NOT NULL
AND msn.group_mark_id <> -1)
AND NOT EXISTS
(SELECT 1
FROM mtl_serial_numbers_temp msnt
WHERE msn.group_mark_id = msnt.transaction_temp_id OR msn.group_mark_id = msnt.group_header_id)
AND NOT EXISTS
(SELECT 1
FROM wsh_delivery_details wdd
WHERE wdd.inv_interfaced_flag <> ''Y''
AND wdd.released_status IN(''Y'', ''C'')
AND wdd.transaction_temp_id IS NOT NULL
AND msn.group_mark_id = wdd.transaction_temp_id)
AND NOT EXISTS
(SELECT 1
FROM wsh_delivery_details wdd
WHERE wdd.inv_interfaced_flag <> ''Y''
AND wdd.released_status IN(''Y'', ''C'')
AND msn.inventory_item_id = wdd.inventory_item_id
AND msn.serial_number = wdd.serial_number)
AND NOT EXISTS
(SELECT 1
FROM mtl_cycle_count_entries mcce
WHERE mcce.cycle_count_header_id = msn.group_mark_id
AND mcce.cycle_count_entry_id = msn.line_mark_id
AND mcce.entry_status_code IN(1,2))',
      p_title                  => 'Locked Serial Numbers',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The Header and/or Line record(s) reference serial numbers that are locked so other processes cannot use them.',
      p_solution               => '<ul><li>Review [1472005/KB472235] Inventory Standard Datafix Instruction #4: Fixing Marked Serial Numbers (MSN), Orphan Pending Serials (MSNT), and Orphan Status 6 Serials, for full details.</li></ul>',
      p_success_msg            => 'The Header and/or Line record(s) do not reference any serial numbers that are currently locked so other processes cannot use them.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_MARKED_SERIAL_NUMBERS');



debug('begin add_signature: LOGPR_ORPHANED_SERIAL_NUMBERS');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10434',
      p_sig_id                 => 'LOGPR_ORPHANED_SERIAL_NUMBERS',
      p_sig_sql                => 'SELECT msnt.fm_serial_number,
  msnt.to_serial_number,
  msnt.TRANSACTION_TEMP_ID
FROM mtl_serial_numbers_temp msnt
WHERE NOT EXISTS
  (SELECT 1
  FROM mtl_material_transactions_temp mmtt
  WHERE mmtt.transaction_temp_id = msnt.transaction_temp_id
  )
AND NOT EXISTS
  (SELECT 1
  FROM MTL_TRANSACTION_LOTS_TEMP mtlt
  WHERE mtlt.SERIAL_TRANSACTION_TEMP_ID = msnt.transaction_temp_id
  )
AND NOT EXISTS
  (SELECT 1
  FROM wsh_delivery_details wdd
  WHERE wdd.transaction_temp_id IS NOT NULL
  AND wdd.transaction_temp_id    = msnt.transaction_temp_id
  AND wdd.released_status       IN (''Y'',''C'')
  AND wdd.inv_interfaced_flag   <> ''Y''
  )
AND NOT EXISTS
  (SELECT 1
  FROM rcv_transactions_interface rti
  WHERE interface_transaction_id = msnt.transaction_temp_id
  )',
      p_title                  => 'Locked Serial Numbers Due To Orphan Temporary Serials',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'One or more orphaned pending serial numbers exist, without related inventory transactions, deliveries, or receiving transactions.<br> 
Orphan pending serials may prevent users from selecting or transacting the listed serial numbers. Keep in mind that the serials listed may not be related to your organization and item because the serial temporary table does not have columns for organization and item.',
      p_solution               => '<ul><li>Review [1472005/KB472235] Inventory Standard Datafix Instruction #4: Fixing Marked Serial Numbers (MSN), Orphan Pending Serials (MSNT), and Orphan Status 6 Serials, for full details.</li></ul>',
      p_success_msg            => 'There are no serial numbers locked by orphan temporary serial records.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_ORPHANED_SERIAL_NUMBERS');



debug('begin add_signature: LOGPR_INV_PERIOD_STATUS_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10423',
      p_sig_id                 => 'LOGPR_INV_PERIOD_STATUS_CHECK',
      p_sig_sql                => 'SELECT mp.organization_Code ,
  oap.ACCT_PERIOD_ID ,
  oap.ORGANIZATION_ID ,
  oap.PERIOD_SET_NAME ,
  oap.PERIOD_YEAR ,
  oap.PERIOD_NUM ,
  oap.PERIOD_NAME ,
  oap.DESCRIPTION ,
  oap.OPEN_FLAG ,
  oap.PERIOD_START_DATE ,
  oap.SCHEDULE_CLOSE_DATE ,
  oap.PERIOD_CLOSE_DATE ,
  oap.LAST_UPDATE_DATE ,
  oap.CREATION_DATE
FROM org_acct_periods oap ,
  mtl_parameters mp
WHERE oap.organization_id = mp.organization_id
AND oap.open_flag         = ''N''
AND (TRUNC(sysdate) BETWEEN TRUNC(oap.period_start_date) AND TRUNC(NVL(oap.period_close_date, oap.schedule_close_date)))
AND oap.organization_id IN
  (SELECT DISTINCT wdd.organization_id
  FROM wsh_delivery_details wdd,
    oe_order_lines_all ol
  WHERE wdd.source_line_id = ol.line_id
  AND wdd.source_header_id = ol.header_id
  AND wdd.source_code      = ''OE''
  AND wdd.released_status IN (''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$##, wdd.source_line_id)
  AND ol.open_flag         = ''Y''
  )',
      p_title                  => 'Inventory period status not opened',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The Inventory (INV) Period for the current date is not OPEN.',
      p_solution               => 'Open the Inventory Period to allow users to perform inventory transactions for the current date. Review [298432/KB771668] Sales Orders will not Pick - No open period found for date entered, for full details.',
      p_success_msg            => 'The Inventory Period is OPEN for the current date.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '4'
      );
   l_info.delete;
debug('end add_signature: LOGPR_INV_PERIOD_STATUS_CHECK');



debug('begin add_signature: LOGPR_LOC_CAPACITY_CHECK');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '10564',
      p_sig_id                 => 'LOGPR_LOC_CAPACITY_CHECK',
      p_sig_sql                => 'SELECT organization_id,
  subinventory_code,
  inventory_location_id,
  description,
  location_maximum_units max_units,
  '''' unit,
  location_current_units current_units,
  location_available_units available_units,
  empty_flag,
  mixed_items_flag,
  inventory_item_id
FROM mtl_item_locations
WHERE location_maximum_units IS NOT NULL
AND location_current_units   >=location_maximum_units
AND location_available_units  =0
AND organization_id          IN
  (SELECT DISTINCT wdd.organization_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id)
  )
UNION
SELECT organization_id,
  subinventory_code,
  inventory_location_id,
  description,
  max_weight max_units,
  LOCATION_WEIGHT_UOM_CODE unit,
  current_weight current_units,
  available_weight available_units,
  empty_flag,
  mixed_items_flag,
  inventory_item_id
FROM mtl_item_locations
WHERE MAX_WEIGHT             IS NOT NULL
AND LOCATION_WEIGHT_UOM_CODE IS NOT NULL
AND CURRENT_WEIGHT           >= MAX_WEIGHT
AND AVAILABLE_WEIGHT          =0
AND organization_id          IN
  (SELECT DISTINCT wdd.organization_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id)
  )
UNION
SELECT organization_id,
  subinventory_code,
  inventory_location_id,
  description,
  max_cubic_area max_units,
  VOLUME_UOM_CODE unit,
  CURRENT_CUBIC_AREA current_units,
  AVAILABLE_CUBIC_AREA available_units,
  empty_flag,
  mixed_items_flag,
  inventory_item_id
FROM mtl_item_locations
WHERE MAX_CUBIC_AREA   IS NOT NULL
AND VOLUME_UOM_CODE    IS NOT NULL
AND CURRENT_CUBIC_AREA >= MAX_CUBIC_AREA
AND AVAILABLE_CUBIC_AREA=0
AND organization_id    IN
  (SELECT DISTINCT wdd.organization_id
  FROM wsh_delivery_details wdd
  WHERE wdd.source_code    = ''OE''
  AND wdd.released_status IN ( ''R'',''B'',''S'')
  AND wdd.source_header_id = ##$$SOHEADERID$$##
  AND wdd.source_line_id   = NVL(##$$SOLINEID$$## , wdd.source_line_id)
  )',
      p_title                  => 'Locator Capacity Check',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'Stock locator form capacity current units do not match the onhand quantity form. Current Units are only used for calculating available capacity in WMS enabled organizations only. Current Units do not apply to Inventory only organizations.',
      p_solution               => 'Review [316479/KB765836] - Stock Locator Form Capacity Units Do Not Match Onhand Quantity Form, for full details.',
      p_success_msg            => 'There is no mismatch between the stock locator form capacity current units and onhand quantity form.',
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
debug('end add_signature: LOGPR_LOC_CAPACITY_CHECK');



debug('begin add_signature: EBS_MFG_INV_LOGPR_CORRUPT_RSV');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '23861',
      p_sig_id                 => 'EBS_MFG_INV_LOGPR_CORRUPT_RSV',
      p_sig_sql                => 'SELECT
    ''Corrupt reservations exist with detailed_quantity not null''  explanation,
    mr.demand_source_line_id   line_id,
    mr.demand_source_header_id,
    mr.reservation_id,
    mr.organization_id,
    mr.inventory_item_id,
    mr.primary_reservation_quantity
FROM
    mtl_reservations      mr,
    wsh_delivery_details  wdd
WHERE
    wdd.released_status IN ( ''B'', ''R'' )
    AND mr.detailed_quantity > 0
    AND mr.demand_source_type_id IN ( 2, 8 )
    AND mr.orig_demand_source_line_id = wdd.source_line_id
    AND wdd.source_header_id = nvl (##$$SOHEADERID$$##, wdd.source_header_id)
    AND wdd.source_line_id   = NVL(##$$SOLINEID$$##,wdd.source_line_id ) ',
      p_title                  => 'Corrupt Reservation',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'One or more corrupt reservations exist. This may cause errors like "Error occurred in Inv_Pick_Release_Pub.Pick_Release
SQLCODE: -6502 SQLERRM: ORA-06502: PL/SQL: numeric or value error
Exception occurred in WSH_PICK_LIST.Release_Batch_Sub
  Unexpected error has occured. Oracle error message is ORA-06502: PL/SQL: numeric or value error
". These reservations can affect the onhand available picture, which can cause material allocation to fail.',
      p_solution               => 'Please open new datafix bug with the above information to get datafix. 
See [2778390/KB750232] for full details',
      p_success_msg            => 'There are no corrupt reservations.',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('E','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_INV_LOGPR_CORRUPT_RSV');



debug('begin add_signature: EBS_MFG_INV_WMSIBT_INDIVISIBLE_QTY');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '23864',
      p_sig_id                 => 'EBS_MFG_INV_WMSIBT_INDIVISIBLE_QTY',
      p_sig_sql                => 'SELECT ''Decimal quantity loaded when Item is set with OM Indivisible attribute as Yes ''  explanation,
    mmtt.transaction_temp_id,
    mmtt.primary_quantity,
    mmtt.transaction_quantity,
    mmtt.transaction_uom,
    msi.indivisible_flag,
    msi.primary_uom_code,
    mmtt.transaction_header_id,
    mmtt.organization_id,
    mmtt.transaction_source_id,
    mmtt.inventory_item_id,
    mmtt.subinventory_code,
    mmtt.locator_id,
    mmtt.transaction_date
FROM
    mtl_material_transactions_temp  mmtt,
    mtl_system_items_b              msi,
    oe_order_lines_all              lin
WHERE
        mmtt.inventory_item_id = msi.inventory_item_id
    AND mmtt.organization_id = msi.organization_id
    AND abs(transaction_quantity) - abs(trunc(transaction_quantity)) > 0
    AND msi.indivisible_flag = ''Y''
    AND mmtt.TRX_SOURCE_LINE_ID = LIN.LINE_ID
    AND LIN.LINE_CATEGORY_CODE = ''ORDER'' 
    AND LIN.SHIP_FROM_ORG_ID   = msi.ORGANIZATION_ID(+) 
    and LIN.INVENTORY_ITEM_ID  = msi.INVENTORY_ITEM_ID(+)  
    and LIN.HEADER_ID          = ##$$SOHEADERID$$##
    AND nvl(##$$SOLINEID$$##, 0) IN ( 0, lin.line_id, lin.top_model_line_id,
                                  lin.ato_line_id,
                                  lin.link_to_line_id,
                                  lin.reference_line_id,
                                  lin.service_reference_line_id )',
      p_title                  => 'The Quantity Entered Does Not Meet The Decimal Quantity Standard',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'The OM Indivisible flag was checked as Yes for item and can prevent fractional pick drop quantities from transacting.',
      p_solution               => 'Review [1306049/KB415507] Pick Drop Fails With Error: "The Quantity Entered Does Not Meet The Decimal Quantity Standard"',
      p_success_msg            => 'No records found with  fractional pick drop quantities when OM Indivisible flag is checked as Yes for item',
      p_print_condition        => nvl('FAILURE','ALWAYS'),
      p_fail_type              => nvl('W','W'),
      p_print_sql_output       => nvl('Y','RS'),
      p_limit_rows             => nvl('Y','Y'),
      p_extra_info             => l_info,
      p_child_sigs             => VARCHAR_TBL(),
      p_include_in_dx_summary  => nvl('P','N'),
      p_version                => '1'
      );
   l_info.delete;
debug('end add_signature: EBS_MFG_INV_WMSIBT_INDIVISIBLE_QTY');



debug('begin add_signature: EBS_MFG_INV_INVTAZ_MO_LINE_NOT_BACKORDERED');
   l_info('##SHOW_SQL##'):= 'Y';
  add_signature(
      p_sig_repo_id            => '26159',
      p_sig_id                 => 'EBS_MFG_INV_INVTAZ_MO_LINE_NOT_BACKORDERED',
      p_sig_sql                => 'select  mtrl.line_id, mtrl.line_number, mtrl.quantity, mtrl.quantity_detailed, mtrl.quantity_delivered, mso.segment1 "Order Number", mso.segment2, mso.segment3 , oel.line_number, oel.ordered_item,
mtrl.txn_source_id, mtrl.txn_source_line_id  
from mtl_txn_request_lines mtrl , mtl_sales_orders mso , oe_order_lines_all oel
where mtrl.txn_source_id = mso.sales_order_id
and oel.line_id = mtrl.txn_source_line_id
and mtrl.line_status = 7
and nvl(mtrl.quantity_delivered , 0) > 0
and mtrl.transaction_type_id = 52
and mtrl.ORGANIZATION_ID = ##$$ORGID$$##
and mtrl.INVENTORY_ITEM_ID = NVL(''##$$ITEMID$$##'', mtrl.INVENTORY_ITEM_ID)
and exists (Select 1 from mtl_material_transactions mmt
            where mmt.move_order_line_id = mtrl.line_id)  -- Picked transactions
and exists (Select 1 from wsh_delivery_details det
            where det.move_order_line_id = mtrl.line_id
            and det.released_status  in (''C''))   -- Shipped
and exists (Select 1 from wsh_delivery_details det
            where det.move_order_line_id = mtrl.line_id
            and det.released_status  in (''S''))  -- Released to warehouse',
      p_title                  => 'Move Order Was Created but There Is No Pick Task for the Item',
      p_fail_condition         => 'RS',
      p_problem_descr          => 'A move order was created but there is no pick task for the item/sales order in warehouse control board.  The following error is encountered:<br>
Move order line could not be back ordered. Rolling back the changes. Error: Zero is not allowed. Please enter a number greater than zero.
',
      p_solution               => 'Create an SR with Inventory Support referencing [2893344/KB707549] and include the Inventory Transactions Analyzer output to receive a data fix.',
      p_success_msg            => 'Issue not present.  See [2893344/KB707549] for details.',
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
debug('end add_signature: EBS_MFG_INV_INVTAZ_MO_LINE_NOT_BACKORDERED');



EXCEPTION WHEN OTHERS THEN
  print_log('Error in load_signatures');
  raise;
END load_signatures;


---------------------------------
-- MAIN ENTRY POINT
---------------------------------
PROCEDURE main(
            p_diag_type                    IN VARCHAR2    DEFAULT NULL
           ,p_batch_id                     IN NUMBER      DEFAULT NULL
           ,p_header_id                    IN NUMBER      DEFAULT NULL
           ,p_so_line_id                   IN NUMBER      DEFAULT NULL
           ,p_wip_entity_id                IN NUMBER      DEFAULT NULL
           ,p_print_appscheck              IN VARCHAR2    DEFAULT 'Y'
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

  IF (p_diag_type IS NOT NULL) THEN
    g_params_string := g_params_string || to_char(p_diag_type) || '_';
  END IF;


  l_step := '10';
  initialize_files;

  analyzer_title := 'Logistics Pick Release Analyzer';
  analyzer_title := regexp_replace('EBS ' || analyzer_title, '(\S+\s)\1', '\1', 1, 0, 'i');  -- EBSAF-243

  l_step := '15';
   validate_parameters(
     p_diag_type                    => upper(p_diag_type)
    ,p_batch_id                     => p_batch_id
    ,p_header_id                    => p_header_id
    ,p_so_line_id                   => p_so_line_id
    ,p_wip_entity_id                => p_wip_entity_id
    ,p_print_appscheck              => upper(p_print_appscheck)
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

debug('begin section: PROACTIVE');
IF p_diag_type = 'LOGISTICS' THEN
   start_section('Proactive Recommendations', 'PROACTIVE');
      set_item_result(run_stored_sig('INV_RUP_CHECK2_SQL_AD_BUGS'));
      set_item_result(run_stored_sig('INV_TXN_KEY_FILE_VERSIONS'));
      set_item_result(run_stored_sig('INV_INVALIDS'));
   end_section;
END IF;
debug('end section: PROACTIVE');

debug('begin section: OM_WSH');
IF p_diag_type <> 'WIP' THEN
   start_section('Order Management and Shipping', 'OM_WSH');
      set_item_result(run_stored_sig('LOGPR_ORDER_HEADER'));
      set_item_result(run_stored_sig('LOGPR_ORDER_HOLD'));
      set_item_result(run_stored_sig('LOGPR_MTL_SALES_ORDER'));
      set_item_result(run_stored_sig('LOGPR_OE_SETS'));
      set_item_result(run_stored_sig('LOGPR_ORDER_LINES'));
      set_item_result(run_stored_sig('LOGPR_LINE_SPECIFIC_HOLDS'));
      set_item_result(run_stored_sig('LOGPR_SO_WSH_NEW_DELIVERIES'));
      set_item_result(run_stored_sig('LOGPR_SO_WSH_DELIVERY_ASSIGNMENTS'));
      set_item_result(run_stored_sig('LOGPR_SO_WSH_ORGANIZATIONS'));
      set_item_result(run_stored_sig('LOGPR_SO_WSH_ACCOUNTING_PERIODS'));
      set_item_result(run_stored_sig('LOGPR_SO_WSH_DELIVERY_DETAILS'));
      set_item_result(run_stored_sig('EBS_MFG_OM_LOGPR_WSH_PICK_GROUPING_RULES'));
      set_item_result(run_stored_sig('LOGPR_WSH_PICK_RELEASE_BATCH_SIZE'));
      set_item_result(run_stored_sig('LOGPR_CORRUPTION_OPEN_DD_CLOSED_LINE'));
      set_item_result(run_stored_sig('LOGPR_SHIPPING_INTEREFACED_FLAG'));
      set_item_result(run_stored_sig('LOGPR_PICKSLIP_NUMBER_NOT_GENERATED'));
      set_item_result(run_stored_sig('LOGPR_DISTRIBUTED_WMS'));
      set_item_result(run_stored_sig('LOGPR_DD_RR_MOLINEID_NOT_NULL'));
      set_item_result(run_stored_sig('LOGPR_DEP_PLAN_REQUIRED_FLAG'));
      set_item_result(run_stored_sig('LOGPR_DB_WRITER_PROCESSES'));
      set_item_result(run_stored_sig('LOGPR_ATO_ITEM_NOT_READY_TO_RELEASE'));
      set_item_result(run_stored_sig('LOGPR_SETUP_REL_SEQ_RULE'));
      set_item_result(run_stored_sig('LOGPR_CORRUPTION_SI_YES_MISSING_DD'));
      set_item_result(run_stored_sig('LOGPR_CORRUPTION_DD_RELWHSE_MO_NOTEXISTS'));
      set_item_result(run_stored_sig('LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_NOTEXISTS'));
      set_item_result(run_stored_sig('LOGPR_CORRUPTION_DD_RELWHSE_MOLINE_CLOSED'));
      set_item_result(run_stored_sig('LOGPR_CORRUPTION_DDS_ZERO_REQ_QTY'));
      set_item_result(run_stored_sig('LOGPR_INVALID_SHIPPING_PACKAGES'));
      set_item_result(run_stored_sig('LOGPR_HOUSEKEEPING_EXCEPTIONS'));
      set_item_result(run_stored_sig('LOGPR_CORRUPTION_ORPHAN_SHIPSETS'));
      set_item_result(run_stored_sig('LOGPR_SETUP_SALESORDERS_FF'));
      set_item_result(run_stored_sig('EBS_MFG_INV_LOGPR_WSH_TRANS_MOQD_SECONDARY_ZERO'));
      set_item_result(run_stored_sig('EBS_MFG_GEN_ONT_WSH_INV_SEQUENCES'));
   end_section;
END IF;
debug('end section: OM_WSH');

debug('begin section: OM_WSH_CRITERIA_MISMTACHES');
IF p_diag_type <> 'WIP' and g_sql_tokens('##$$BATCHID$$##') IS NOT NULL THEN
   start_section('Pick Selection Criteria Mismatches', 'OM_WSH_CRITERIA_MISMTACHES');
      set_item_result(run_stored_sig('LOGPR_WSH_PICKING_BATCHES'));
      set_item_result(run_stored_sig('EBS_MFG_OM_LOGPR_BATCH_VERSES_DELIVERY_DETAIL'));
      set_item_result(run_stored_sig('LOGPR_DD_NON_TRANSACTABLE_ITEM'));
      set_item_result(run_stored_sig('LOGPR_CRITERIA_INCLUDE_PLANNED_LINES'));
      set_item_result(run_stored_sig('LOGPR_WORKDAY_CALENDAR_NOT_ASSOICATED'));
      set_item_result(run_stored_sig('LOGPR_PICKSLIP_REPORT_PRINT'));
      set_item_result(run_stored_sig('LOGPR_CRITERIA_SHIP_METHOD'));
      set_item_result(run_stored_sig('LOGPR_CRITERIA_REL_SUBINVENTORY'));
      set_item_result(run_stored_sig('LOGPR_CRITERIA_SHIP_FROM_LOCATION'));
      set_item_result(run_stored_sig('LOGPR_CRITERIA_SHIPMENT_PRIORITY'));
      set_item_result(run_stored_sig('LOGPR_SETUP_RESTRICT_SUBINV'));
      set_item_result(run_stored_sig('LOGPR_SETUP_RESTRICT_LOCATOR'));
      set_item_result(run_stored_sig('LOGPR_CRITERIA_SCHDATE_REQDATE'));
      set_item_result(run_stored_sig('LOGPR_CRITERIA_EXISTING_RSVS_ONLY'));
   end_section;
END IF;
debug('end section: OM_WSH_CRITERIA_MISMTACHES');

debug('begin section: LOG_WMS_INV');
IF p_diag_type = 'LOGISTICS' THEN
   start_section('Inventory and WMS', 'LOG_WMS_INV');
      set_item_result(run_stored_sig('LOGPR_SUBINVENTORY_INFO'));
      set_item_result(run_stored_sig('LOGPR_ONHAND_BY_PROJ_TASK'));
      set_item_result(run_stored_sig('SALES_ORDER_LINE_MTL_SYSTEM_ITEMS'));
      set_item_result(run_stored_sig('LOGPR_WMS_RULE_RESTRICTIONS'));
      set_item_result(run_stored_sig('SALES_ORDER_MTL_RESERVATIONS'));
      set_item_result(run_stored_sig('SALES_ORDER_MTL_DEMAND'));
      set_item_result(run_stored_sig('SALES_ORDER_MTL_SUPPLY'));
      set_item_result(run_stored_sig('SALES_ORDER_DROP_SHIP_MTL_TRX_INTERFACE'));
      set_item_result(run_stored_sig('SALES_ORDER_MTL_TRANSACTIONS_INTERFACE'));
      set_item_result(run_stored_sig('SALES_ORDER_MTL_MATERIAL_TRANSACTIONS_TEMP'));
      set_item_result(run_stored_sig('SALES_ORDER_MTL_MATERIAL_TRANSACTIONS'));
      set_item_result(run_stored_sig('SALES_ORDER_MTL_TXN_REQUEST_LINES'));
      set_item_result(run_stored_sig('SALES_ORDER_MTL_UNIT_TRANSACTIONS'));
      set_item_result(run_stored_sig('LOGPR_ITEM_TXN_DEFAULT_SETUP'));
      set_item_result(run_stored_sig('LOGPR_WMS_RULE_SETUP'));
   end_section;
END IF;
debug('end section: LOG_WMS_INV');

debug('begin section: COMMON_DATA_VALIDATIONS');
IF p_diag_type = 'LOGISTICS' THEN
   start_section('Common Data Validations', 'COMMON_DATA_VALIDATIONS');
      IF p_diag_type = 'LOGISTICS'
 THEN
         set_item_result(run_stored_sig('LOGPR_DEFAULT_STAGING_SETUP'));
         set_item_result(run_stored_sig('LOGPR_INVALID_RULE_CHECK'));
         set_item_result(run_stored_sig('LOGPR_EXPIRED_LOT_ONHAND'));
         set_item_result(run_stored_sig('LOGPR_INVALID_ONHAND_STATUS'));
         set_item_result(run_stored_sig('LOGPR_MATERIAL_STATUS_CHECK'));
         set_item_result(run_stored_sig('LOGPR_ORPHAN_MO_ALLOC'));
         set_item_result(run_stored_sig('LOGPR_ORPHAN_RSV'));
         set_item_result(run_stored_sig('LOGPR_ORPHAN_MO_NO_SHP_TRAN'));
         set_item_result(run_stored_sig('LOGPR_ORPHAN_MO_ALLOC_CLOSED_MO'));
         set_item_result(run_stored_sig('LOGPR_MARKED_SERIAL_NUMBERS'));
         set_item_result(run_stored_sig('LOGPR_ORPHANED_SERIAL_NUMBERS'));
         set_item_result(run_stored_sig('LOGPR_INV_PERIOD_STATUS_CHECK'));
         set_item_result(run_stored_sig('LOGPR_LOC_CAPACITY_CHECK'));
         set_item_result(run_stored_sig('EBS_MFG_INV_LOGPR_CORRUPT_RSV'));
         set_item_result(run_stored_sig('EBS_MFG_INV_WMSIBT_INDIVISIBLE_QTY'));
         set_item_result(run_stored_sig('EBS_MFG_INV_INVTAZ_MO_LINE_NOT_BACKORDERED'));
      END IF;
   end_section;
END IF;
debug('end section: COMMON_DATA_VALIDATIONS');

debug('begin section: ORGANIZATION_DETAILS');
IF p_diag_type = 'LOGISTICS' THEN
   start_section('Organization Details', 'ORGANIZATION_DETAILS');
      set_item_result(run_stored_sig('INV_ORGANIZATIONS_FULL_OUTPUT_ORG'));
      set_item_result(run_stored_sig('LOGPR_ORG_PARAMETERS'));
      set_item_result(run_stored_sig('LOGPR_PJM_ORG_PARAMETERS'));
      set_item_result(run_stored_sig('LOGPR_WSH_SHIPPING_PARAMETERS'));
   end_section;
END IF;
debug('end section: ORGANIZATION_DETAILS');

debug('begin section: WIP');
IF p_diag_type = 'WIP' THEN
   start_section('Work In Process', 'WIP');
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_HEADER'));
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_OPERATIONS'));
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_REQUIREMENTS'));
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_TXN_MMT'));
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_TXN_MMTT'));
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_ITEMS_DJ'));
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_PICKING_JOBS'));
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_RESERVABLE_SUB_JOB'));
      set_item_result(run_stored_sig('LOGPR_WIP_JOB_RESERVABLE_SUB_WIP_PARAM'));
   end_section;
END IF;
debug('end section: WIP');

debug('begin section: APPS_CHECK');
IF p_print_appscheck = 'Y' THEN
   start_section('Diagnostics: Apps Check', 'APPS_CHECK');
      set_item_result(run_stored_sig('AC_DB_INFO'));
      set_item_result(run_stored_sig('LANGUAGES_INSTALLED_DETAILS'));
      set_item_result(run_stored_sig('PORCVANLAZ_AC_FILE_VERISONS'));
      set_item_result(run_stored_sig('AC_PROFILE_OPTIONS'));
      set_item_result(run_stored_sig('AC_APPLICATION_INSTALL_DETAILS'));
      set_item_result(run_stored_sig('AC_CUSTOM_DATABASE_TRIGGERS'));
      set_item_result(run_stored_sig('AC_CUSTOM_TABLE_INDEXES'));
      set_item_result(run_stored_sig('AC_DATABASE_TRIGGERS'));
      set_item_result(run_stored_sig('AC_INVALID_TABLE_INDEXES'));
      set_item_result(run_stored_sig('AC_TABLE_INDEXES'));
      IF p_diag_type = 'WSH' THEN
         set_item_result(run_stored_sig('ONT_DB_PARAMETERS'));
         set_item_result(run_stored_sig('ONT_DB_RELEASE_INFO'));
         set_item_result(run_stored_sig('ONT_PATCHES_APPLIED'));
         set_item_result(run_stored_sig('ONT_SHIPPING_PARAMETERS'));
         set_item_result(run_stored_sig('ONT_SYSTEM_PARAMETERS'));
         set_item_result(run_stored_sig('EBS_MFG_OM_ONT_ONTSO_SYSTEM_PARAMETERS_VALUES'));
      END IF;
      set_item_result(run_stored_sig('AC_CUSTOM_PACKAGES'));
      set_item_result(run_stored_sig('EBS_MFG_OM_AC_CUSTOM_APPLICATIONS'));
      set_item_result(run_stored_sig('BOM_VPD_POLICY_CHECK'));
   end_section;
END IF;
debug('end section: APPS_CHECK');

debug('begin section: Critical_Alerts');
start_section('Critical Alerts', 'Critical_Alerts');
   set_item_result(run_stored_sig('PREMIER_SUPPORT_11.5'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_12.0'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_12.1'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_DB_CHECK_11'));
   set_item_result(run_stored_sig('PREMIER_SUPPORT_DB_CHECK_12.1'));
   set_item_result(run_stored_sig('EBS_ATG_ECC_12_2_7'));
   set_item_result(run_stored_sig('EBS_ATG_UGLE_32BIT_SEQUENCES_CLOSE_TO_MAX'));
   set_item_result(run_stored_sig('EBS_ATG_UGLE_SEQUENCES_CLOSE_TO_MAXIMUM_VALUE'));
end_section;
debug('end section: Critical_Alerts');



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
           ,p_diag_type                    IN VARCHAR2    DEFAULT NULL
           ,p_batch_id                     IN NUMBER      DEFAULT NULL
           ,p_header_id                    IN NUMBER      DEFAULT NULL
           ,p_so_line_id                   IN NUMBER      DEFAULT NULL
           ,p_wip_entity_id                IN NUMBER      DEFAULT NULL
           ,p_print_appscheck              IN VARCHAR2    DEFAULT 'Y'
           ,p_max_output_rows              IN NUMBER      DEFAULT 20
           ,p_debug_mode                   IN VARCHAR2    DEFAULT 'Y'
)
 IS

BEGIN
  g_retcode := 0;
  g_errbuf := null;

   main(
     p_diag_type                    => upper(p_diag_type)
    ,p_batch_id                     => p_batch_id
    ,p_header_id                    => p_header_id
    ,p_so_line_id                   => p_so_line_id
    ,p_wip_entity_id                => p_wip_entity_id
    ,p_print_appscheck              => upper(p_print_appscheck)
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );


  retcode := g_retcode;
  errbuf  := g_errbuf;
EXCEPTION WHEN OTHERS THEN
  retcode := '2';
  errbuf := 'Error in main_cp: '||sqlerrm||' : '||g_errbuf;
END main_cp;


END logistic_pick_rel_analyzer_pkg;
/
show errors
exit;
-- Exit required for bundling project so do not remove
