--  EBS init.ora checks - osariogl , version 2.0.6
--  based on Note 396009.1
--  for EBS 12.X and database versions 11G ,12C and 19c. 
--  2.0.0 : 19C checks added
--  2.0.2 : O7_DICTIONARY_ACCESSIBILITY parameter is stored upper case all the time
--  2.0.2 : parallel_degree_policy is mandatory
--  2.0.2 : return warning to make sure values are checked manually too
--  2.0.3 : bug fixes
--  2.0.4 : service name for 19c 
--  2.0.5 : added _disable_actualization_for_grant
--  2.0.6 : changed 600M to 629145600 
--  Use bde_chk_cbo.sql from Note 174605.1 for EBS 11i and Database 10G

PROCEDURE db_parameter_details IS

 v_hostname       VARCHAR2(64);
 v_platform       VARCHAR2(80);
 v_instancename	  VARCHAR2(32);
 v_rdbms_version  VARCHAR2(17);
 v_user           VARCHAR2(30);
 v_sysdate        VARCHAR2(15);
 v_dbname         VARCHAR2(32);
 v_apps_release   VARCHAR2(50);
 v_cpu_count 	  NUMBER;
 v_db_unq_name    VARCHAR2(50);
 v_analyzer		  VARCHAR2(10) := '2.0.6';
 cnt			  number;
 l_result         VARCHAR(1) := 'S';


  /* local parameters to print */
 p_parameter_name sys.plan_table$.object_alias%TYPE;
 p_current_value  v$system_parameter2.value%TYPE;
 p_required_value sys.plan_table$.options%TYPE;
 p_db_default     sys.plan_table$.object_node%TYPE;
 p_check		  VARCHAR2(50);
 p_isses	      v$system_parameter2.isses_modifiable%TYPE;
 p_issys	      v$system_parameter2.issys_modifiable%TYPE; 
 p_description	  v$system_parameter2.description%TYPE;

 /* list of all mandatory and common parameters first */
/* since these are mandatory ,value should match */
/* if parameter is not set then s.value will be null , in that case compare to default value */
	cursor all_mandatory1 
	is
	select pt.object_alias "Parameter Name",nvl(s.value,'(not set)') "Current Value", pt.options "Required Value" , pt.object_node "DB Default",
      case pt.options  
			when upper(s.value) then 'OK'
			when nvl(s.value,pt.object_node) then 'NOT FOUND:OK'
			else 'ERROR' 
	  end "Check" ,
      s.description "Description"
	from sys.plan_table$ pt , v$system_parameter2 s
	where pt.operation =  'MANDATORY' 
	  and (pt.statement_id = 'ALL' OR pt.statement_id = substr(v_rdbms_version,1,6) ) 
	  and pt.object_alias = s.name(+)
	  and pt.plan_id = 123456789
	  order by "Check" , "Parameter Name";

	cursor db_removallist 
	is
	select pt.object_alias "Parameter Name",nvl(s.value,'(not set)') "Current Value",
      case  nvl(s.isdefault,'TRUE')
			when 'TRUE' then 'OK'
			else 'ERROR' 
	  end "Check" ,
      s.description "Description"
	from sys.plan_table$ pt , v$system_parameter2 s
	where pt.statement_id = substr(v_rdbms_version,1,6)
	  and pt.operation = 'REMOVE'
	  and pt.object_alias = s.name(+)
      and pt.object_alias <> 'event'
	  and pt.plan_id = 123456789
	  UNION /* check for events, value is important now */
      select pt.object_alias||'='||pt.options  "Parameter Name",nvl(s.value,'(not set)') "Current Value", 
            case  nvl(s.value,'TRUE')
			when 'TRUE' then 'OK'
			else 'ERROR' 
	  end "Check" ,
      s.description "Description"
	from sys.plan_table$ pt , v$system_parameter2 s
	where pt.statement_id = substr(v_rdbms_version,1,6)
	  and pt.operation = 'REMOVE'
	  and pt.object_alias = s.name(+)
      and pt.object_alias = 'event'
      and pt.options = s.value(+)
	  and pt.plan_id = 123456789
	order by "Check", "Parameter Name";

	cursor otherparams 
	is
	/* extra non-default parameters set that we don't have any recommendation */
	select s.name  "Parameter Name", s.value "Current Value",
        case substr(s.name,1,1)
           when '_' then 'Do not set hidden parameters' 
           else 'No Recommendation' 
        end "Required Value" ,  
			 s.description  "Description" , 'EXTRA' "Check",
			 s.isses_modifiable,s.issys_modifiable
	from v$system_parameter2 s
	where s.isdefault = 'FALSE'
	  and s.name not in ( select pt.object_alias from sys.plan_table$ pt 
						where (pt.statement_id = 'ALL' OR pt.statement_id = substr(v_rdbms_version,1,6) ) 
						and pt.plan_id = 123456789 )
	UNION
	/* current setting of non-mandatory , non-removal parameters */
	select pt.object_alias "Parameter Name",nvl(s.value,'(not set)') "Current Value", pt.options "Required Value" , 
	      s.description "Description",
		case pt.options  
			when upper(s.value) then 'OK'
			when nvl(s.value,pt.object_node) then 'NOT FOUND:OK'
			else pt.operation
	    end "Check" ,
		s.isses_modifiable,s.issys_modifiable
	from sys.plan_table$ pt , v$system_parameter2 s
	where pt.operation not in ( 'MANDATORY' , 'REMOVE' ) 
	  and (pt.statement_id = 'ALL' OR pt.statement_id = substr(v_rdbms_version,1,6) ) 
	  and pt.object_alias = s.name(+)
	  and pt.plan_id = 123456789 	
	  order by "Check", "Parameter Name" ;

	  
BEGIN

    print_log('Starting db_parameter_details');

    /* Find versions used : */
	SELECT i.host_name,
           i.version,
           i.instance_name,
		   user , 
		   TO_CHAR(SYSDATE, 'DD-MON-YY HH24:MI') ,
		   d.name||'('||TO_CHAR(d.dbid)||')' , 
		   f.release_name ,
		   cp.cpu_count,
		   ptcnt.cnt,
		   dun.value
    INTO v_hostname, v_rdbms_version, v_instancename, v_user, v_sysdate , v_dbname , v_apps_release, v_cpu_count, cnt,v_db_unq_name
    FROM v$instance i , v$database d , applsys.fnd_product_groups f , 
		(  SELECT SUBSTR(value, 1, 10) cpu_count FROM v$system_parameter WHERE name = 'cpu_count') cp ,
		(  SELECT count(*) cnt from sys.plan_table$ where plan_id = 123456789 ) ptcnt,
		(  SELECT value FROM v$system_parameter WHERE name = 'db_unique_name') dun;

print_out('<div class="clear"></div>');	
print_out('<div class="data sigcontainer signature DB_PARAMS_OLCAY ' ||  replace_chars(g_sec_detail(g_sec_detail.COUNT).name) || ' E section print analysis" level="1" sigid="DB_PARAMS_OLCAY" id="DB_PARAMS_OLCAY" style="display: none;">');
print_out('  
    <div class="divItemTitle">
        <input type="checkbox" rowid="DB_PARAMS_OLCAY" class="exportcheck data print">
        <a class="detail" toggle-data="restable_DB_PARAMS_OLCAY">
           <div class="arrowright data section fullsection print analysis">&#9654;</div><div class="arrowdown data" style="display: none">&#9660;</div>
           <div class="sigdescription" style="display:inline;"><table style="display:inline;"><tr class="Database_Overview DB_PARAMS_OLCAY S sigtitle"><td class="divItemTitlet">Recommendations for Database Parameter Details</td></tr></table></div>
        </a>
        <a class="detailsmall" href="javascript:;" onclick=''export2PaddedText("DB_PARAMS_OLCAY");return false;''><span class="export_txt_ico" title="Export to .txt" alt="Export to .txt"></span></a>
        <a class="detailsmall" href="javascript:;" onclick=''export2CSV("DB_PARAMS_OLCAY")''><span class="export_ico" title="Export to .csv" alt="Export to .csv"></span></a>
    </div>

    <div class="divtable">
    <table class="table1 data tabledata" id="restable_DB_PARAMS_OLCAY" style="display:none">
    <tr><td>');
  
  
	/* Load data into plan table */
	/* Mapping and example data 
	   plan_id        --> plan_id      : 123456789  - fixed value to clear old data incase temp table is not used.
	   parameter name --> object_alias  : db_block_buffers
	   parameter_type --> operation    : MANDATORY, SIZING, OTHERS , REMOVE
	   db version     --> statement_id : ALL, 11.2.0
	   ebs version    --> object_owner : ALL, 12.0.x , 12.1.x , 12.2.x
	   default_value  --> object_node  : 0  -->DB default. We should get this from database instead.
	   value 		  --> options      : 8  - recommended setting - all uppercase
	  
	*/
	/* SECTIONS :
		1 - all common mandatory parameters
		2 - others common parameters
		2.5 - specific to 11gR1    --> obsoleted by dev in 396009.1
		3 - removal list for 11gR1 --> obsoleted by dev in 396009.1
		4 - specific to 11gR2
		5 - removal list for 11gR2
		6 - specific to 12cR1
		7 - removal list for 12c1
		8 - special checks
  		9 - specific to 19c
		10 - removal list for 19c

	*/
	/* first clear previous runs - kinda redundant since plan table is a global temporary table */
	delete from sys.plan_table$ where plan_id = 123456789;

/* START SECTION1*/
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
		values ( 123456789,  'db_block_size', 'MANDATORY' , 'ALL', 'ALL', '8192', '8192');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_system_trig_enabled', 'MANDATORY' , 'ALL', 'ALL','TRUE', 'TRUE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'nls_date_format', 'MANDATORY' , 'ALL', 'ALL','DERIVED', 'DD-MON-RR');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'nls_sort', 'MANDATORY' , 'ALL', 'ALL', 'DERIVED', 'BINARY');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'nls_comp', 'MANDATORY' , 'ALL', 'ALL', 'DERIVED' ,'BINARY');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'nls_length_semantics', 'MANDATORY' , 'ALL', 'ALL', 'DERIVED', 'BYTE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'cursor_sharing', 'MANDATORY' , 'ALL', 'ALL', 'EXACT', 'EXACT');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_like_with_bind_as_equality', 'MANDATORY' , 'ALL', 'ALL', 'HIDDEN', 'TRUE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_sort_elimination_cost_ratio', 'MANDATORY' , 'ALL', 'ALL', 'HIDDEN', '5');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_fast_full_scan_enabled', 'MANDATORY' , 'ALL', 'ALL', 'HIDDEN', 'FALSE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_b_tree_bitmap_plans', 'MANDATORY' , 'ALL', 'ALL', 'HIDDEN', 'FALSE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'optimizer_secure_view_merging', 'MANDATORY' , 'ALL', 'ALL', 'TRUE', 'FALSE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'workarea_size_policy', 'MANDATORY' , 'ALL', 'ALL', 'AUTO', 'AUTO');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'undo_management', 'MANDATORY' , 'ALL', 'ALL', 'AUTO', 'AUTO');	
  
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_optimizer_autostats_job', 'MANDATORY' , 'ALL', 'ALL', 'TRUE', 'FALSE');	

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'compatible', 'MANDATORY' , 'ALL', 'ALL', substr(v_rdbms_version,1,6) ,substr(v_rdbms_version,1,6));

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'parallel_force_local', 'MANDATORY' , 'ALL', 'ALL', 'FALSE','TRUE');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'parallel_degree_policy', 'MANDATORY' , 'ALL', 'ALL', 'MANUAL','MANUAL');

         insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
            values ( 123456789, '_disable_actualization_for_grant', 'MANDATORY' , 'ALL', 'ALL', 'FALSE','TRUE');


/* END SECTION1 */

/* Other common parameters */ 
/* START SECTION2 */
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'db_name', 'OTHERS' , 'ALL', 'ALL','NODEFAULT', 'PROD');
	 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'control_files', 'OTHERS' , 'ALL', 'ALL', 'OS_DEPENDENT' ,'three copies of control file');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'filesystemio_options', 'OTHERS' , 'ALL', 'ALL', 'OS_DEPENDENT', 'SETALL');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'nls_territory', 'OTHERS' , 'ALL', 'ALL', 'DERIVED','AMERICA');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'nls_numeric_characters', 'OTHERS' , 'ALL', 'ALL', 'DERIVED', '.,');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'diagnostic_dest', 'OTHERS' , 'ALL', 'ALL', 'DERIVED', '?/prod12');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'max_dump_file_size', 'OTHERS' , 'ALL', 'ALL', 'UNLIMITED', '20480');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_trace_files_public', 'OTHERS' , 'ALL', 'ALL', 'FALSE', 'FALSE');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'processes', 'SIZING' , 'ALL', 'ALL', 'DERIVED', '200');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'sessions', 'SIZING' , 'ALL', 'ALL', 'DERIVED', '400');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'db_files', 'SIZING' , 'ALL', 'ALL', '200', '512');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'dml_locks', 'SIZING' , 'ALL', 'ALL', 'DERIVED', '10000');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'open_cursors', 'SIZING' , 'ALL', 'ALL', '50', '600');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'session_cached_cursors', 'SIZING' , 'ALL', 'ALL', '50', '500');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'db_block_checking', 'OTHERS' , 'ALL', 'ALL', 'FALSE', 'FALSE');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'db_block_checksum', 'OTHERS' , 'ALL', 'ALL', 'TYPICAL', 'TRUE');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'log_checkpoint_timeout', 'SIZING' , 'ALL', 'ALL', '1800', '1200');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'log_checkpoint_interval', 'SIZING' , 'ALL', 'ALL', '0', '100000');		  
		  
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'log_buffer', 'SIZING' , 'ALL', 'ALL', '5242880', '10485760');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'log_checkpoints_to_alert', 'SIZING' , 'ALL', 'ALL', 'FALSE', 'TRUE');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'shared_pool_size', 'SIZING' , 'ALL', 'ALL', 'DERIVED', '629145600');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'shared_pool_reserved_size', 'SIZING' , 'ALL', 'ALL', 'DERIVED', '60M');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'utl_file_dir', 'OTHERS' , 'ALL', 'ALL', 'DERIVED', '/ebiz/prodr12/utl_file_dir');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'aq_tm_processes', 'SIZING' , 'ALL', 'ALL', '10485760', '1');		  
		 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'job_queue_processes', 'SIZING' , 'ALL', 'ALL', '1000', '2');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'log_archive_dest_1', 'OTHERS' , 'ALL', 'ALL', 'DERIVED', 'LOCATION=/DISC1/ARC');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'log_archive_dest_2', 'OTHERS' , 'ALL', 'ALL', 'DERIVED', 'SERVICE=STANDBY1');		  

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'pga_aggregate_target', 'SIZING' , 'ALL', 'ALL', 'DERIVED', '1G');		  
	 
  	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'sga_target', 'SIZING' , 'ALL', 'ALL', '0', '2G');		  
  
   	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'shared_pool_size', 'SIZING' , 'ALL', 'ALL', 'DERIVED', '629145600');		  
  
   	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'shared_pool_reserved_size', 'SIZING' , 'ALL', 'ALL', 'DERIVED', '60M');		  
    
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'parallel_max_servers', 'SIZING' , 'ALL', 'ALL', 'DERIVED', 2 * v_cpu_count);

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'parallel_min_servers', 'SIZING' , 'ALL', 'ALL', 'DERIVED', 0);

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'sec_case_sensitive_logon', 'SIZING' , 'ALL', 'ALL', 'Note 1581584.1', 'FALSE');

/* END SECTION2 */




/* START SECTION2.5 */
/* Specific list for 11G R1 database */ 

if ( substr(v_rdbms_version,1,6) = '11.1.0') then 
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_sqlexec_progression_cost', 'MANDATORY' , 'ALL', 'ALL', 'HIDDEN', '2147483647');
     
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'O7_DICTIONARY_ACCESSIBILITY', 'MANDATORY' , '11.1.0', 'ALL', 'TRUE','FALSE');

end if;
/* END SECTION2.5 */

/* START SECTION3 */
/* Removal list for 11G R1 database */ 

if ( substr(v_rdbms_version,1,6) = '11.1.0') then 
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_always_anti_join', 'REMOVE' , '11.1.0', 'ALL');
    
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_always_semi_join', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_complex_view_merging', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_index_join_enabled', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_kks_use_mutex_pin', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_new_initial_join_orders', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_cost_based_transformation', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_cost_model', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_mode_force', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_undo_changes', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_or_expand_nvl_predicate', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_ordered_nested_loop', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_push_join_predicate', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_shared_pool_reserved_min_alloc', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_sortmerge_inequality_join_off', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_table_scan_cost_plus_one', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_unnest_subquery', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_use_column_stats_for_function', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'always_anti_join', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'always_semi_join', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'background_dump_dest', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'core_dump_dest', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_block_buffers', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_cache_size', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_file_multiblock_read_count', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'enqueue_resources', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '11.1.0', 'ALL','10932 trace name context level 32768');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '11.1.0', 'ALL','10933 trace name context level 512');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '11.1.0', 'ALL' ,'10943 trace name context forever, level 2');
		
    insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '11.1.0', 'ALL' ,'10943 trace name context level 16384');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, options)
	    values ( 123456789, 'event', 'REMOVE' , '11.1.0', 'ALL' ,'38004 trace name context forever, level 1');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'hash_area_size', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'java_pool_size', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'large_pool_size', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'max_enabled_roles', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'nls_language', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_dynamic_sampling', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_features_enable', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_index_caching', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_index_cost_adj', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_max_permutations', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_percent_parallel', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_compiler_flags', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_native_library_dir', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_native_library_subdir_count', 'REMOVE' , '11.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_optimize_level', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'query_rewrite_enabled', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'rollback_segments', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'row_locking', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'sort_area_size', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'sql_trace', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'timed_statistics', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'undo_retention', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'undo_suppress_errors', 'REMOVE' , '11.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'user_dump_dest', 'REMOVE' , '11.1.0', 'ALL');
end if;
 
/* END SECTION3 */

/* START SECTION4 */
if ( substr(v_rdbms_version,1,6) = '11.2.0') then 
          
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'olap_page_pool_size', 'SIZING' , '11.2.0', 'ALL', '0', '4194304');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'O7_DICTIONARY_ACCESSIBILITY', 'MANDATORY' , '11.2.0', 'ALL', 'TRUE','FALSE');
end if;

/* END SECTION4 */

/* START SECTION5*/
if ( substr(v_rdbms_version,1,6) = '11.2.0') then 

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_always_anti_join', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_always_semi_join', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_complex_view_merging', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_index_join_enabled', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_kks_use_mutex_pin', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_new_initial_join_orders', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_cost_based_transformation', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_cost_model', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_mode_force', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_undo_changes', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_or_expand_nvl_predicate', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_ordered_nested_loop', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_push_join_predicate', 'REMOVE' , '11.2.0', 'ALL');
	 
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_push_join_union_view', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_shared_pool_reserved_min_alloc', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_sortmerge_inequality_join_off', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_sqlexec_progression_cost', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_table_scan_cost_plus_one', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_unnest_subquery', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_use_column_stats_for_function', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'always_anti_join', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'always_semi_join', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'background_dump_dest', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'core_dump_dest', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_block_buffers', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_cache_size', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_file_multiblock_read_count', 'REMOVE' , '11.2.0', 'ALL');
		
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'drs_start', 'REMOVE' , '11.2.0', 'ALL');
	 
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'enqueue_resources', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '11.2.0', 'ALL','10932 trace name context level 32768');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '11.2.0', 'ALL','10933 trace name context level 512');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '11.2.0', 'ALL' ,'10943 trace name context forever, level 2');
		
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '11.2.0', 'ALL' ,'10943 trace name context level 16384');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, options)
	    values ( 123456789, 'event', 'REMOVE' , '11.2.0', 'ALL' ,'38004 trace name context forever, level 1');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'hash_area_size', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'java_pool_size', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'job_queue_interval', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'large_pool_size', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'max_enabled_roles', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'nls_language', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_dynamic_sampling', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_features_enable', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_index_caching', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_index_cost_adj', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_max_permutations', 'REMOVE' , '11.2.0', 'ALL');
	 
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_mode', 'REMOVE' , '11.2.0', 'ALL');
		
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_percent_parallel', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, ' parallel_instance_group', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'instance_groups', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_compiler_flags', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_native_library_dir', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_native_library_subdir_count', 'REMOVE' , '11.2.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_optimize_level', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'query_rewrite_enabled', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'rollback_segments', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'row_locking', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'sort_area_size', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'sql_trace', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'sql_version', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'timed_statistics', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'undo_retention', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'undo_suppress_errors', 'REMOVE' , '11.2.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'user_dump_dest', 'REMOVE' , '11.2.0', 'ALL');
end if;

/* END SECTION5 */


/* START SECTION6 */
if ( substr(v_rdbms_version,1,6) = '12.1.0') then 

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'O7_DICTIONARY_ACCESSIBILITY', 'MANDATORY' , '12.1.0', 'ALL', 'TRUE','FALSE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'optimizer_adaptive_features', 'MANDATORY' , '12.1.0', 'ALL', 'TRUE','FALSE');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'olap_page_pool_size', 'SIZING' , '12.1.0', 'ALL', '0', '4194304');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'temp_undo_enabled', 'SIZING' , '12.1.0', 'ALL', 'FALSE', 'FALSE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'pga_aggregate_limit', 'MANDATORY' , '12.1.0', 'ALL', 'DERIVED','0');

end if;

/* END SECTION6 */
/* START SECTION7 */

if ( substr(v_rdbms_version,1,6) = '12.1.0') then 

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_always_anti_join', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_always_semi_join', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_complex_view_merging', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_index_join_enabled', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_kks_use_mutex_pin', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_new_initial_join_orders', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_cost_based_transformation', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_cost_model', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_mode_force', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_optimizer_undo_changes', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_or_expand_nvl_predicate', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_ordered_nested_loop', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_push_join_predicate', 'REMOVE' , '12.1.0', 'ALL');
	 
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_push_join_union_view', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_shared_pool_reserved_min_alloc', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_sortmerge_inequality_join_off', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_sqlexec_progression_cost', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_table_scan_cost_plus_one', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_unnest_subquery', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_use_column_stats_for_function', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'always_anti_join', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'always_semi_join', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'background_dump_dest', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'core_dump_dest', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_block_buffers', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_cache_size', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'db_file_multiblock_read_count', 'REMOVE' , '12.1.0', 'ALL');
		
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'drs_start', 'REMOVE' , '12.1.0', 'ALL');
	 
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'enqueue_resources', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '12.1.0', 'ALL','10932 trace name context level 32768');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '12.1.0', 'ALL','10933 trace name context level 512');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '12.1.0', 'ALL' ,'10943 trace name context forever, level 2');
		
    insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner,options )
	    values ( 123456789, 'event', 'REMOVE' , '12.1.0', 'ALL' ,'10943 trace name context level 16384');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, options)
	    values ( 123456789, 'event', 'REMOVE' , '12.1.0', 'ALL' ,'38004 trace name context forever, level 1');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'hash_area_size', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'java_pool_size', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'job_queue_interval', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'large_pool_size', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'max_enabled_roles', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'nls_language', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_dynamic_sampling', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_features_enable', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_index_caching', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_index_cost_adj', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_max_permutations', 'REMOVE' , '12.1.0', 'ALL');
	 
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_mode', 'REMOVE' , '12.1.0', 'ALL');
		
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_percent_parallel', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, ' parallel_instance_group', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'instance_groups', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_compiler_flags', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_native_library_dir', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_native_library_subdir_count', 'REMOVE' , '12.1.0', 'ALL');
	
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_optimize_level', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'query_rewrite_enabled', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'rollback_segments', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'row_locking', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'sort_area_size', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'sql_trace', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'sql_version', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'timed_statistics', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'undo_retention', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'undo_suppress_errors', 'REMOVE' , '12.1.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'user_dump_dest', 'REMOVE' , '12.1.0', 'ALL');
		  
end if;

	/* END SECTION7 */
    /* START SECTION8 */
    /* Special checks here */
	if ( substr(v_apps_release,1,4) = '12.2' ) then
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
		values ( 123456789,  'recyclebin', 'MANDATORY' , '11.2.0', '12.2', 'ON', 'OFF');
	
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
		values ( 123456789,  'recyclebin', 'MANDATORY' , '12.1.0', '12.2', 'ON', 'OFF');

         insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
                values ( 123456789,  'result_cache_max_size', 'MANDATORY' , '11.2.0', '12.2', '', '629145600');

         insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
                values ( 123456789,  'result_cache_max_size', 'MANDATORY' , '12.1.0', '12.2', '', '629145600');

         insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
                values ( 123456789,  'result_cache_max_size', 'MANDATORY' , '19.0.0', '12.2', '', '629145600');

	 
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
		values ( 123456789,  'local_listener', 'MANDATORY' , '11.2.0', '12.2', '(ADDRESS = (PROTOCOL=TCP)(HOST=hostname)(PORT=1521))', v_instancename || '_LOCAL');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
		values ( 123456789,  'local_listener', 'MANDATORY' , '12.1.0', '12.2', '(ADDRESS = (PROTOCOL=TCP)(HOST=hostname)(PORT=1521))', v_instancename || '_LOCAL');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
		values ( 123456789,  'service_names', 'OTHERS' , '11.2.0', '12.2', v_db_unq_name, v_instancename || ',' || v_instancename||'_EBS_PATCH');

	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
		values ( 123456789,  'service_names', 'OTHERS' , '12.1.0', '12.2', v_db_unq_name, v_instancename || ',' || v_instancename||'_EBS_PATCH');
         
	end if;		
	/* END SECTION8 */

    /* START SECTION9 */
    /* 19c specific */
   if ( substr(v_rdbms_version,1,6) = '19.0.0') then 
    
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'optimizer_adaptive_plans', 'MANDATORY' , '19.0.0', 'ALL', 'TRUE','TRUE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'optimizer_adaptive_statistics', 'MANDATORY' , '19.0.0', 'ALL', 'FALSE','FALSE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'pga_aggregate_limit', 'MANDATORY' , '19.0.0', 'ALL', 'DERIVED','0');
          
	 insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'temp_undo_enabled', 'SIZING' , '19.0.0', 'ALL', 'FALSE', 'FALSE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, '_pdb_name_case_sensitive', 'MANDATORY' , '19.0.0', 'ALL', 'FALSE','TRUE');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
	    values ( 123456789, 'event', 'MANDATORY' , '19.0.0', 'ALL', '','10946 trace name context forever, level 8454144');


     /* ignore previous suggestions for service names */
     delete from sys.plan_table$ where plan_id = '123456789' and object_alias = 'service_names' ;
     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner, object_node, options  )
                values ( 123456789,  'service_names', 'OTHERS' , 'ALL', 'ALL', '', v_db_unq_name || '(no other values)');
 

    end if;

	/* END SECTION9 */

    /* START SECTION10 */
    /* removal list for 19c */

   if ( substr(v_rdbms_version,1,6) = '19.0.0') then 

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_kks_use_mutex_pin', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_shared_pool_reserved_min_alloc', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, '_sqlexec_progression_cost', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'exafusion_enabled', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'exclude_seed_cdb_view', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'global_context_pool_size', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'max_enabled_roles', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'O7_DICTIONARY_ACCESSIBILITY', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'olap_page_pool_size', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'optimizer_adaptive_features', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'parallel_automatic_tuning', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'parallel_degree_level', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'parallel_io_cap_enabled', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'parallel_server', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'parallel_server_instances', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_compiler_flags', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_native_library_dir', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_native_library_subdir_count', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'plsql_optimize_level', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'standby_archive_dest', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'timed_statistics', 'REMOVE' , '19.0.0', 'ALL');

     insert into sys.plan_table$  ( plan_id, object_alias , operation, statement_id, object_owner )
	    values ( 123456789, 'use_indirect_data_buffers', 'REMOVE' , '19.0.0', 'ALL');

     end if;

	/* END SECTION10 */


/* Since there are no contrainsts/indexes on sys.plan_table$, make sure that there are no duplicate inserts */
/* This section should be commented out after testing */
/* prompt "data check" */
/*   select object_alias , count(*) from sys.plan_table$ where plan_id =123456789  group by object_alias having count(*) > 1; */   

    /* Print Versions */
	print_out('<h3>Report Version : '|| v_analyzer || ' based on <a href="https://support.oracle.com/CSP/main/article?cmd=show\\\\&type=NOT\\\\&id=396009.1">Note 396009.1</a>' );
	print_out('<h3>System Identification</h3>');
	print_out('<table border="0"> <tr><td class="title">Date:</td><td class="left">'||v_sysdate||'</td></tr>');
	print_out(' <tr><td class="title">Host:</td><td class="left">'||v_hostname||'</td></tr>');
	print_out(' <tr><td class="title">DB Name:</td><td class="left">'||v_dbname||'</td></tr>');
	print_out(' <tr><td class="title">Instance:</td><td class="left">'||v_instancename||'</td></tr>');
	print_out(' <tr><td class="title">User:</td><td class="left">'||v_user||'</td></tr>');
	print_out(' <tr><td class="title">RDBMS Version:</td><td class="left">'||v_rdbms_version||'</td></tr>');
	print_out(' <tr><td class="title">e-Business Version:</td><td class="left">'||v_apps_release||'</td></tr>');
	print_out(' <tr><td class="title">CPU count:</td><td class="left">'||v_cpu_count||'</td></tr>');
	print_out(' <tr><td class="title">Plan table count:</td><td class="left">'|| cnt ||'</td></tr>');
	print_out('</table>');
		
	print_out('<h3>Mandatory Parameters</h3>');  
	print_out('<table border="0"><tr><th>Cnt</th><th>Parameter Name</th><th>Current Value</th><th>Required Value</th><th>Database Default</th><th>Check Status</th><th>Description</th></tr>' );
	open all_mandatory1;
	cnt := 1;
	loop
		fetch all_mandatory1 into p_parameter_name, p_current_value, p_required_value,p_db_default, p_check, p_description;
		EXIT WHEN all_mandatory1%NOTFOUND;
		if  ( instr( p_check, 'OK' ) <> 0 ) then
			p_check := '<td bgcolor="#76b418">'|| p_check;
		else
			p_check := '<td bgcolor="#ffd6cc">'|| p_check;
			l_result := 'E'; 
		end if;

		print_out('<tr><td>'|| cnt ||'</td><td>'|| p_parameter_name ||'</td><td>' || p_current_value || '</td><td>' || p_required_value||'</td>');
		print_out('<td>'|| p_db_default     ||'</td>' || p_check || '</td><td>' || p_description||'</td></tr>');
		cnt := cnt +1;
	end loop;
	close all_mandatory1;
	print_out('</table>');

	print_out('<h3>Removal Parameters for '|| v_rdbms_version ||'</h3>');  
	print_out('<table border="0"><tr><th>Cnt</th><th>Parameter Name</th><th>Current Value</th><th>Check Status</th><th>Description</th></tr>' );

	open db_removallist;
	cnt := 1;

	loop
		fetch db_removallist into p_parameter_name, p_current_value, p_check, p_description;
		EXIT WHEN db_removallist%NOTFOUND;
		if  ( instr( p_check, 'OK' ) <> 0 ) then
			p_check := '<td bgcolor="#76b418">'|| p_check;
		else
			p_check := '<td bgcolor="#ffd6cc">'|| p_check;
			if ( l_result <> 'E' ) then l_result := 'W'; end if;
		end if;

		print_out('<tr><td>'|| cnt ||'</td><td>'|| p_parameter_name ||'</td><td>' || p_current_value || '</td>');
		print_out(p_check || '</td><td>' || p_description||'</td></tr>');
		cnt := cnt +1;

	end loop;
	close db_removallist;
	print_out('</table>');

	print_out('<h3>Additonal Parameters for '|| v_rdbms_version ||'</h3>');  
	print_out('<table border="0"><tr><th>Cnt</th><th>Parameter Name</th><th>Current Value</th><th>Required Value</th>');
	print_out('<th>Description</th><th>Check</th><th>Session</th><th>System</th></tr>' );

	open otherparams;
	cnt := 1;

	loop
		fetch otherparams into p_parameter_name, p_current_value, p_required_value, p_description,p_check,p_isses, p_issys;
		EXIT WHEN otherparams%NOTFOUND;

		if  ( instr( p_check, 'OK' ) <> 0 ) then
			p_check := '<td bgcolor="#76b418">'|| p_check;
		else
			p_check := '<td bgcolor=" #fcce4b">'|| p_check;
			if ( l_result <> 'E' ) then l_result := 'W'; end if; 
		end if;

		print_out('<tr><td>' || cnt ||'</td><td>'|| p_parameter_name ||'</td><td>' || p_current_value || '</td>');
		print_out('<td>' || p_required_value || '</td><td>' || p_description||'</td>'|| p_check || '</td>');
		print_out('<td>' || p_isses || '</td><td>' || p_issys ||'</td></tr>');
		cnt := cnt +1;

	end loop;
	close otherparams;
    
    
    g_results(l_result) := g_results(l_result) + 1;     
	g_sec_detail(g_sec_detail.LAST).results(l_result) := g_sec_detail(g_sec_detail.LAST).results(l_result) + 1;
    set_item_result(l_result);
	print_out('</table>');
			
			
  print_out('</td></tr></table>');

print_out('</div><br>');
print_out('<div style="display:none" class="sigrescode ' || replace_chars(g_sec_detail(g_sec_detail.COUNT).name) || ' DB_PARAMS_OLCAY ' || l_result || '" level="1"></div>');
print_out('</div><br>');

print_out('<div class="clear"></div>');	    

--BILL ADD  -> If incorrect replace signature id and name as needed 
     g_sec_detail(g_sec_detail.COUNT).sigs.extend();     
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_id := 'DB_PARAMS_OLCAY';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_name := 'Database Parameter Details';
     g_sec_detail(g_sec_detail.COUNT).sigs(g_sec_detail(g_sec_detail.COUNT).sigs.COUNT).sig_result := l_result;
--END BILL ADD   

EXCEPTION WHEN OTHERS THEN
  print_log('Error in db_parameter_details'||sqlerrm);
  raise;	

end db_parameter_details;
