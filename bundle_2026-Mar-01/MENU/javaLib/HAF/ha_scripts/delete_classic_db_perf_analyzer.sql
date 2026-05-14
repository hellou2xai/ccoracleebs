spool delete_db_stats.lst

delete from fnd_request_group_units
where  ( application_id, request_unit_id)
in (select 
      p.application_id,  p.concurrent_program_id
    --  , t.user_concurrent_program_name
    from fnd_concurrent_programs p, fnd_concurrent_programs_tl t
    where p.concurrent_program_name='DBSTATAZ'
    and t.user_concurrent_program_name='Database Performance and Statistics Analyzer'
    and p.concurrent_program_id = t.concurrent_program_id
    and t.language='US');

delete from fnd_concurrent_programs p
where p.concurrent_program_name='DBSTATAZ'
and exists
  (select 1 from  fnd_concurrent_programs_tl t
   where t.user_concurrent_program_name='Database Performance and Statistics Analyzer'
    and p.concurrent_program_id = t.concurrent_program_id
    and t.language='US');

delete from fnd_concurrent_programs_tl
where user_concurrent_program_name='Database Performance and Statistics Analyzer'
and language='US'
;

DROP PACKAGE db_performance_analyzer_pkg;

--select * from fnd_concurrent_programs_tl
--where user_concurrent_program_name='Database Performance and Statistics Analyzer'
--and language='US';
--
--select 
--  p.application_id,  p.concurrent_program_id
--  , t.user_concurrent_program_name
--from fnd_concurrent_programs p, fnd_concurrent_programs_tl t
--where p.concurrent_program_name='DBSTATAZ'
--and t.user_concurrent_program_name='Database Performance and Statistics Analyzer'
--and p.concurrent_program_id = t.concurrent_program_id
--and t.language='US'
--;
--
--select 
--  p.application_id,  p.concurrent_program_id
--from fnd_concurrent_programs p
--where p.concurrent_program_name='DBSTATAZ';

commit;
/

exit