-- fnd_patches.sql version 1.1
set lines 120
set pages 2000
set define off
SET MARKUP HTML ON SPOOL ON

spool atg_checkins.html

select 'The following list of patches is provided as information only so that to verify their status in the target instance; it is not required that these patches are applied, Oracle Support will review as part of the troublehsooting process for a service request, if one was logged.' Disclosure 
 , 'Jan-2021' Update_date
from dual;

select 31818510 nug_number, ad_patch.is_patch_applied('R12',-1,31818510) patch_status, 'ATG ECC ADAPTER PATCH - V6' description from dual union all
select 31818502 nug_number, ad_patch.is_patch_applied('R12',-1,31818502) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V6 SUPPORT IN 12.2.10' description from dual union all
select 31818494 nug_number, ad_patch.is_patch_applied('R12',-1,31818494) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V6 SUPPORT IN 12.2.9' description from dual union all
select 31818482 nug_number, ad_patch.is_patch_applied('R12',-1,31818482) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V6 SUPPORT IN 12.2.8' description from dual union all
select 31818475 nug_number, ad_patch.is_patch_applied('R12',-1,31818475) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V6 SUPPORT IN 12.2.7' description from dual union all
select 31818462 nug_number, ad_patch.is_patch_applied('R12',-1,31818462) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V6 SUPPORT IN 12.2.6' description from dual union all
select 31818454 nug_number, ad_patch.is_patch_applied('R12',-1,31818454) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V6 SUPPORT IN 12.2.5' description from dual union all
select 31818449 nug_number, ad_patch.is_patch_applied('R12',-1,31818449) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V6 SUPPORT IN 12.2.4' description from dual union all
select 30535550 nug_number, ad_patch.is_patch_applied('R12',-1,30535550) patch_status, 'ATG ECC ADAPTER PATCH - V5' description from dual union all
select 30535546 nug_number, ad_patch.is_patch_applied('R12',-1,30535546) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V5 SUPPORT IN 12.2.10' description from dual union all
select 30535540 nug_number, ad_patch.is_patch_applied('R12',-1,30535540) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V5 SUPPORT IN 12.2.9' description from dual union all
select 30535538 nug_number, ad_patch.is_patch_applied('R12',-1,30535538) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V5 SUPPORT IN 12.2.8' description from dual union all
select 30535536 nug_number, ad_patch.is_patch_applied('R12',-1,30535536) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V5 SUPPORT IN 12.2.7' description from dual union all
select 30535535 nug_number, ad_patch.is_patch_applied('R12',-1,30535535) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V5 SUPPORT IN 12.2.6' description from dual union all
select 30535533 nug_number, ad_patch.is_patch_applied('R12',-1,30535533) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V5 SUPPORT IN 12.2.5' description from dual union all
select 30535522 nug_number, ad_patch.is_patch_applied('R12',-1,30535522) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V5 SUPPORT IN 12.2.4' description from dual union all
select 30399978 nug_number, ad_patch.is_patch_applied('R12',-1,30399978) patch_status, 'ORACLE E-BUSINESS SUITE APPLICATIONS TECHNOLOGY ONLINE HELP FOR 12.2.10 (ATG_PF)' description from dual union all
select 30399994 nug_number, ad_patch.is_patch_applied('R12',-1,30399994) patch_status, 'R12.ATG_PF.C.delta.9' description from dual union all
select 30144012 nug_number, ad_patch.is_patch_applied('R12',-1,30144012) patch_status, 'ATG - 12.1 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 9' description from dual union all
select 30144032 nug_number, ad_patch.is_patch_applied('R12',-1,30144032) patch_status, 'ATG - 12.2 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 9' description from dual union all
select 30297232 nug_number, ad_patch.is_patch_applied('R12',-1,30297232) patch_status, 'ATG ECC ADAPTER PATCH - V4' description from dual union all
select 30297212 nug_number, ad_patch.is_patch_applied('R12',-1,30297212) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V4 SUPPORT IN 12.2.9' description from dual union all
select 30297178 nug_number, ad_patch.is_patch_applied('R12',-1,30297178) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V4 SUPPORT IN 12.2.8' description from dual union all
select 30297090 nug_number, ad_patch.is_patch_applied('R12',-1,30297090) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V4 SUPPORT IN 12.2.7' description from dual union all
select 30297069 nug_number, ad_patch.is_patch_applied('R12',-1,30297069) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V4 SUPPORT IN 12.2.6' description from dual union all
select 30297040 nug_number, ad_patch.is_patch_applied('R12',-1,30297040) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V4 SUPPORT IN 12.2.5' description from dual union all
select 30296675 nug_number, ad_patch.is_patch_applied('R12',-1,30296675) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V4 SUPPORT IN 12.2.4' description from dual union all
select 28780241 nug_number, ad_patch.is_patch_applied('R12',-1,28780241) patch_status, 'ATG ECC ADAPTER PATCH - V2' description from dual union all
select 28780020 nug_number, ad_patch.is_patch_applied('R12',-1,28780020) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V2 SUPPORT IN 12.2.8' description from dual union all
select 28780017 nug_number, ad_patch.is_patch_applied('R12',-1,28780017) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V2 SUPPORT IN 12.2.7' description from dual union all
select 28779999 nug_number, ad_patch.is_patch_applied('R12',-1,28779999) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V2 SUPPORT IN 12.2.6' description from dual union all
select 28780005 nug_number, ad_patch.is_patch_applied('R12',-1,28780005) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V2 SUPPORT IN 12.2.5' description from dual union all
select 28779977 nug_number, ad_patch.is_patch_applied('R12',-1,28779977) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V2 SUPPORT IN 12.2.4' description from dual union all
select 29499071 nug_number, ad_patch.is_patch_applied('R12',-1,29499071) patch_status, 'ATG ECC ADAPTER PATCH - V3' description from dual union all
select 28780011 nug_number, ad_patch.is_patch_applied('R12',-1,28780011) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V3 SUPPORT IN 12.2.9' description from dual union all
select 29499036 nug_number, ad_patch.is_patch_applied('R12',-1,29499036) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V3 SUPPORT IN 12.2.8' description from dual union all
select 29499012 nug_number, ad_patch.is_patch_applied('R12',-1,29499012) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V3 SUPPORT IN 12.2.7' description from dual union all
select 29498991 nug_number, ad_patch.is_patch_applied('R12',-1,29498991) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V3 SUPPORT IN 12.2.6' description from dual union all
select 29498976 nug_number, ad_patch.is_patch_applied('R12',-1,29498976) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V3 SUPPORT IN 12.2.5' description from dual union all
select 29498961 nug_number, ad_patch.is_patch_applied('R12',-1,29498961) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V3 SUPPORT IN 12.2.4' description from dual union all
select 28840884 nug_number, ad_patch.is_patch_applied('R12',-1,28840884) patch_status, 'Oracle E-Business Suite ATG Online Help for 12.2.9 (atg_pf)' description from dual union all
select 28840844 nug_number, ad_patch.is_patch_applied('R12',-1,28840844) patch_status, 'Oracle Applications Technology 12.2.9 Product Family Release Update Pack' description from dual union all
select 28045225 nug_number, ad_patch.is_patch_applied('R12',-1,28045225) patch_status, 'ATG ECC ADAPTER PATCH - V1' description from dual union all
select 28517038 nug_number, ad_patch.is_patch_applied('R12',-1,28517038) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V1 SUPPORT IN 12.2.8' description from dual union all
select 28045214 nug_number, ad_patch.is_patch_applied('R12',-1,28045214) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V1 SUPPORT IN 12.2.7' description from dual union all
select 28045200 nug_number, ad_patch.is_patch_applied('R12',-1,28045200) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V1 SUPPORT IN 12.2.6' description from dual union all
select 28045185 nug_number, ad_patch.is_patch_applied('R12',-1,28045185) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V1 SUPPORT IN 12.2.5' description from dual union all
select 28045170 nug_number, ad_patch.is_patch_applied('R12',-1,28045170) patch_status, 'ATG CONSOLIDATED PATCH FOR ECC V1 SUPPORT IN 12.2.4' description from dual union all
select 26974010 nug_number, ad_patch.is_patch_applied('R12',-1,26974010) patch_status, 'Consolidated Online Help Updates On Top Of ATG Online Help For 12.2.7' description from dual union all
select 26924701 nug_number, ad_patch.is_patch_applied('R12',-1,26924701) patch_status, 'CONSOLIDATED BUNDLE PATCH ON TOP OF R12.ATG_PF.C.Delta.7' description from dual union all
select 26728355 nug_number, ad_patch.is_patch_applied('R12',-1,26728355) patch_status, 'ATG - 12.1 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 8' description from dual union all
select 26728820 nug_number, ad_patch.is_patch_applied('R12',-1,26728820) patch_status, 'ATG - 12.2 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 8' description from dual union all
select 25185917 nug_number, ad_patch.is_patch_applied('R12',-1,25185917) patch_status, 'ORACLE E-BUSINESS SUITE APPLICATIONS TECHNOLOGY ONLINE HELP FOR 12.2.7' description from dual union all
select 24690680 nug_number, ad_patch.is_patch_applied('R12',-1,24690680) patch_status, 'R12.ATG_PF.C.DELTA.7' description from dual union all
select 24383252 nug_number, ad_patch.is_patch_applied('R12',-1,24383252) patch_status, 'ATG - 12.1 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 7' description from dual union all
select 24383477 nug_number, ad_patch.is_patch_applied('R12',-1,24383477) patch_status, 'ATG - 12.2 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 7' description from dual union all
select 26052406 nug_number, ad_patch.is_patch_applied('R12',-1,26052406) patch_status, 'BACK PORT FND/AD CORE SECURITY FIX PREREQ COMBO PATCH -1223' description from dual union all
select 26052406 nug_number, ad_patch.is_patch_applied('R12',-1,26052406) patch_status, 'BACK PORT FND/AD CORE SECURITY FIX PREREQ COMBO PATCH -1223' description from dual union all
select 25475909 nug_number, ad_patch.is_patch_applied('R12',-1,25475909) patch_status, 'FND CORE SECURITY FIX AND AD PREREQ COMBO PATCH' description from dual union all
select 25475909 nug_number, ad_patch.is_patch_applied('R12',-1,25475909) patch_status, 'FND CORE SECURITY FIX AND AD PREREQ COMBO PATCH' description from dual union all
select 22569528 nug_number, ad_patch.is_patch_applied('R12',-1,22569528) patch_status, 'ORACLE E-BUSINESS SUITE APPLICATIONS TECHNOLOGY ONLINE HELP FOR 12.2.6' description from dual union all
select 21900895 nug_number, ad_patch.is_patch_applied('R12',-1,21900895) patch_status, 'R12.ATG_PF.C.DELTA.6' description from dual union all
select 22465404 nug_number, ad_patch.is_patch_applied('R12',-1,22465404) patch_status, 'ATG - 12.1 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 6' description from dual union all
select 22465795 nug_number, ad_patch.is_patch_applied('R12',-1,22465795) patch_status, 'ATG - 12.2 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 6' description from dual union all
select 21270466 nug_number, ad_patch.is_patch_applied('R12',-1,21270466) patch_status, 'ATG - 12.2 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 5' description from dual union all
select 21270998 nug_number, ad_patch.is_patch_applied('R12',-1,21270998) patch_status, 'ATG - 12.1 CONSOLIDATED PATCH FOR MOBILE APPLICATIONS FOUNDATION RELEASE 5' description from dual union all
select 21520765 nug_number, ad_patch.is_patch_applied('R12',-1,21520765) patch_status, 'ATG - 12.2 Consolidated Patch For Mobile Applications Foundation V4.1' description from dual union all
select 21520630 nug_number, ad_patch.is_patch_applied('R12',-1,21520630) patch_status, 'ATG - 12.1 Consolidated Patch For Mobile Applications Foundation V4.1' description from dual union all
select 20518433 nug_number, ad_patch.is_patch_applied('R12',-1,20518433) patch_status, 'ATG - 12.2 Consolidated Patch For Mobile Applications Foundation V4' description from dual union all
select 20518343 nug_number, ad_patch.is_patch_applied('R12',-1,20518343) patch_status, 'ATG - 12.1 Consolidated Patch For Mobile Applications Foundation V4' description from dual union all
select 19681454 nug_number, ad_patch.is_patch_applied('R12',-1,19681454) patch_status, 'ORACLE E-BUSINESS SUITE APPLICATIONS TECHNOLOGY ONLINE HELP FOR 12.2.5' description from dual union all
select 19245366 nug_number, ad_patch.is_patch_applied('R12',-1,19245366) patch_status, 'R12.ATG_PF.C.Delta.5' description from dual union all
select 20007896 nug_number, ad_patch.is_patch_applied('R12',-1,20007896) patch_status, 'ATG - 12.1.3 Consolidated Patch For Mobile Applications Foundation V2.1' description from dual union all
select 20007902 nug_number, ad_patch.is_patch_applied('R12',-1,20007902) patch_status, 'ATG - 12.2 Consolidated Patch For Mobile Applications Foundation V2.1' description from dual union all
select 20049515 nug_number, ad_patch.is_patch_applied('R12',-1,20049515) patch_status, 'ATG - 12.2 Consolidated Patch For Mobile Applications Foundation V3' description from dual union all
select 20049511 nug_number, ad_patch.is_patch_applied('R12',-1,20049511) patch_status, 'ATG - 12.1.3 Consolidated Patch For Mobile Applications Foundation V3' description from dual union all
select 18815242 nug_number, ad_patch.is_patch_applied('R12',-1,18815242) patch_status, 'ATG Consolidated Patch for Oracle E-Business Suite mobile applications foundation, Release 12.2 V2' description from dual union all
select 18815177 nug_number, ad_patch.is_patch_applied('R12',-1,18815177) patch_status, 'ATG Consolidated Patch for Oracle E-Business Suite mobile applications foundation, Release 12.1 V2' description from dual union all
select 19025292 nug_number, ad_patch.is_patch_applied('R12',-1,19025292) patch_status, 'CATALAN AND BULGARIAN SUPPORT CONSOLIDATE PATCH FOR 12.2.3' description from dual union all
select 18964716 nug_number, ad_patch.is_patch_applied('R12',-1,18964716) patch_status, 'ATG Consolidated Patch for Oracle E-Business Suite mobile applications foundation, Release 12.2 V1' description from dual union all
select 18964693 nug_number, ad_patch.is_patch_applied('R12',-1,18964693) patch_status, 'ATG Consolidated Patch for Oracle E-Business Suite mobile applications foundation, Release 12.1 V1' description from dual union all
select 14069503 nug_number, ad_patch.is_patch_applied('R12',-1,14069503) patch_status, 'ATG CONSOLIDATED PATCH FOR R12.1 HRMS RUP5' description from dual union all
select 17912683 nug_number, ad_patch.is_patch_applied('R12',-1,17912683) patch_status, 'ORACLE E-BUSINESS SUITE APPLICATIONS TECHNOLOGY ONLINE HELP FOR 12.2.4' description from dual union all
select 14594958 nug_number, ad_patch.is_patch_applied('R12',-1,14594958) patch_status, 'NLS: KAZAKH LANGUAGE SUPPORT CONSOLIDATE PATCH FOR R12.1.3' description from dual union all
select 18849118 nug_number, ad_patch.is_patch_applied('R12',-1,18849118) patch_status, 'NLS: KAZAKH LANGUAGE SUPPORT CONSOLIDATE PATCH FOR R12.1.3' description from dual union all
select 17909318 nug_number, ad_patch.is_patch_applied('R12',-1,17909318) patch_status, 'R12.ATG_PF.C.delta.4' description from dual union all
select 9817770 nug_number, ad_patch.is_patch_applied('R12',-1,9817770) patch_status, 'POST-R12.ATG_PF.B.DELTA.3 CONSOLIDATED PATCH' description from dual union all
select 14161287 nug_number, ad_patch.is_patch_applied('R12',-1,14161287) patch_status, 'NLS: ALBANIAN LANGUAGE SUPPORT CONSOLIDATE PATCH FOR R12.1.3' description from dual union all
select 8511125 nug_number, ad_patch.is_patch_applied('R12',-1,8511125) patch_status, 'Consolidate patch for Vietnamese language support in 12.0.4' description from dual union all
select 11056513 nug_number, ad_patch.is_patch_applied('R12',-1,11056513) patch_status, 'SERBIAN SUPPORT IN EBS 12.1.3' description from dual union all
select 9400185 nug_number, ad_patch.is_patch_applied('R12',-1,9400185) patch_status, 'ORACLE EBS APPLICATIONS TECHNOLOGY ONLINE HELP FOR 12.1.3 RELEASE UPDATE PACK' description from dual union all
select 8919491 nug_number, ad_patch.is_patch_applied('R12',-1,8919491) patch_status, 'Oracle Applications Technology 12.1.3 Product Family Release Update Pack' description from dual union all
select 9679310 nug_number, ad_patch.is_patch_applied('R12',-1,9679310) patch_status, 'Release 12.0.3: April 2010 CPU Patch for Customers at 12.0.4 or Higher level for ATG' description from dual union all
select 8599794 nug_number, ad_patch.is_patch_applied('R12',-1,8599794) patch_status, 'ORACLE E-BUSINESS SUITE APPLICATIONS TECHNOLOGY ONLINE HELP FOR RELEASE 12.1.2' description from dual union all
select 7651091 nug_number, ad_patch.is_patch_applied('R12',-1,7651091) patch_status, 'Oracle Applications Technology Release Update Pack 2 for 12.1 (R12.ATG_PF.B.DELTA.2)' description from dual union all
select 8939644 nug_number, ad_patch.is_patch_applied('R12',-1,8939644) patch_status, 'Consolidated technology update for Lithuanian (LT) language support in EBS Release 12.1.1' description from dual union all
select 7345901 nug_number, ad_patch.is_patch_applied('R12',-1,7345901) patch_status, 'ORACLE APPLICATIONS TECHNOLOGY ONLINE HELP RELEASE UPDATE PACK 6 FOR 12.0' description from dual union all
select 7237006 nug_number, ad_patch.is_patch_applied('R12',-1,7237006) patch_status, 'R12.ATG_PF.A.DELTA.6' description from dual union all
select 6496142 nug_number, ad_patch.is_patch_applied('R12',-1,6496142) patch_status, 'ORACLE APPLICATIONS TECHNOLOGY ONLINE HELP RELEASE UPDATE PACK 4 FOR 12.0' description from dual union all
select 6272680 nug_number, ad_patch.is_patch_applied('R12',-1,6272680) patch_status, 'R12.ATG_PF.A.DELTA.4' description from dual;

spool off
exit