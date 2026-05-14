-- EBS_ATG_fversions.sql version 200.6 2023-APR-18
set feedb off
set termout off
set pages 40000
set lines 152

spool EBS_ATG_fversions.txt

select msg "FILE VERSIONS" from (
select 'A' seq, 'ATG Files Versions from AD Snapshot View (version 200.6, snapshot G view was updated '||trunc(sysdate - snapshot_update_date)||' days ago on '||snapshot_update_date||')' msg
from AD_SNAPSHOTS s, fnd_product_groups pg
where s.snapshot_type='G'
union all
select 'B',' >>> Snapshot G view has not been updated after last patch, update using adadmin: Maintain Snapshot Information / Update current view snapshot,'||chr(10)||'     and run this script again. <<< '
from AD_SNAPSHOTS s where s.snapshot_type='G'
and snapshot_update_date < (select max(last_update_date) from ad_applied_patches)
union all
select 'C', f.app_short_name||' '||f.subdir|| ' '|| f.filename||' '|| v.version  File_versions
from ad_files f, ad_file_versions v
  , AD_SNAPSHOT_FILES sf
  , AD_SNAPSHOTS s
where 
v.file_id=f.file_id
and sf.file_version_id = v.file_version_id
and f.file_id = sf.file_id
and sf.snapshot_id = s.snapshot_id 
and s.snapshot_type ='G'
and f.APP_SHORT_NAME in ('FND','JTF')
and subdir not like 'help/%'
and subdir not like '%driver%'
and subdir not like '%readme%'
and subdir not like '%template'
union all
select 'D', 'End of File Version List' from dual
)
order by seq, msg
;

spool off
exit
