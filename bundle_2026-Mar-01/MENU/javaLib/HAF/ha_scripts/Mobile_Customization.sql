
SET LINESIZE 200
SET SERVEROUTPUT ON SIZE 1000000 
declare 

p_path VARCHAR2(4000) := '/oracle/apps/per'; 

p_recursive boolean := true;
  
    -- Selects documents in the current directory
    CURSOR c_docs
	IS
    WITH func_mob
as(
   SELECT DECODE(function_name,'WMS_MANUAL_PICKING_MOB',concat('Mobile Pick Load - '
,user_function_name),'WMS_DROP_LOADED_LPNS_MOB',concat('Mobile Pick Drop - '
,user_function_name),user_function_name) user_function_name,function_name
,DECODE(function_name,'WMS_UPDATE','oracle.apps.wms.pup.server.UpdateLPNPage'
,'INV_MOB_PO_RCPT','oracle.apps.inv.rcv.server.RcptGenPage_INV_MOB_PO_RCPT'
,'WMS_MANUAL_PICKING_MOB','oracle.apps.wms.td.server.MainPickPage','WMS_DROP_LOADED_LPNS_MOB'
,'oracle.apps.wms.td.server.PickDropPage','WMS_IN_MANLD_MOB','oracle.apps.wms.td.server.PutawayPage_WMS_IN_MANLD_MOB'
,'WMS_PUTAWAY','oracle.apps.wms.td.server.PutawayPage_WMS_PUTAWAY','WMS_LPN_SHIP'
,'oracle.apps.inv.wshtxn.server.ShipLPNPage','WMS_MOVE_ANY_LPN_MOB','oracle.apps.wms.td.server.PutawayPage_WMS_MOVE_ANY_LPN_MOB'
,'oracle.apps.wms.default','WMS_ASN_RECEIPT','oracle.apps.inv.rcv.server.RcptGenPage_WMS_ASN_RECEIPT'
) path_name
     FROM fnd_form_functions_vl
    WHERE type = 'MOBILE'
      AND function_name IN (
       'WMS_UPDATE','INV_MOB_PO_RCPT','WMS_MANUAL_PICKING_MOB','WMS_DROP_LOADED_LPNS_MOB'
,'WMS_IN_MANLD_MOB','WMS_LPN_SHIP','WMS_MOVE_ANY_LPN_MOB','WMS_ASN_RECEIPT'
   )
   UNION
   SELECT DECODE(function_name,'INV_MOB_PO_RCPT',concat(user_function_name,
' Information'),'WMS_IN_MANLD_MOB',concat(user_function_name,' - Select Contents'
),'WMS_MANUAL_PICKING_MOB',concat('Mobile Pick Load - ',user_function_name
),'WMS_DROP_LOADED_LPNS_MOB',concat('Mobile Pick Drop - ',user_function_name
),user_function_name) user_function_name,function_name,DECODE(function_name
,'WMS_UPDATE','oracle.apps.wms.pup.server.UpdateLPNPage','INV_MOB_PO_RCPT'
,'oracle.apps.inv.rcv.server.RcptInfoPage','WMS_MANUAL_PICKING_MOB','oracle.apps.wms.td.server.MainPickPage'
,'WMS_DROP_LOADED_LPNS_MOB','oracle.apps.wms.td.server.PickDropPage','WMS_IN_MANLD_MOB'
,'oracle.apps.wms.td.server.ItemLoadPage','WMS_PUTAWAY','oracle.apps.wms.td.server.PutawayPage_WMS_PUTAWAY'
,'WMS_DROP_ALL_LPNS_MOB','oracle.apps.wms.td.server.PutawayPage_WMS_DROP_ALL_LPNS_MOB'
,'WMS_LPN_SHIP','oracle.apps.inv.wshtxn.server.ShipLPNPage','WMS_MOVE_ANY_LPN_MOB'
,'oracle.apps.wms.td.server.PutawayPage_WMS_MOVE_ANY_LPN_MOB','oracle.apps.wms.default'
)
     FROM fnd_form_functions_vl
    WHERE type = 'MOBILE'
      AND function_name IN (
       'WMS_UPDATE','INV_MOB_PO_RCPT','WMS_MANUAL_PICKING_MOB','WMS_DROP_LOADED_LPNS_MOB'
,'WMS_IN_MANLD_MOB','WMS_LPN_SHIP','WMS_MOVE_ANY_LPN_MOB'
   )
   UNION
   SELECT concat(user_function_name,' - Ship Confirm') user_function_name,function_name
,'oracle.apps.inv.wshtxn.server.DeliveryLPNPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_LPN_SHIP'
   UNION
   SELECT concat(user_function_name,' (Select Item)') user_function_name,function_name
,'oracle.apps.wms.td.server.PutawayDropPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_MOVE_ANY_LPN_MOB'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wip.wma.page.LpnCompletionPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMA_LPN_CMPASSY'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.gme.invtxn.server.IssueIngredientPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'GME_MOBILE_ISSUE_ING'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.gme.invtxn.server.CompleteProductPage'
     FROM fnd_form_functions_vl
    WHERE function_name LIKE 'GME_MOBILE_CMPLT_PROD'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.gme.invtxn.server.CreatePendingLotPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'GME_MOBILE_CREATE_PND_LOT'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.gme.invtxn.server.BackflushMaterialPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'GME_MOBILE_BACKFLUSH'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.wms.td.server.DetailPickPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_MANUAL_PICKING_MOB'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.inv.invinq.server.ItemOnhandQueryPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_INQUIRY'
   UNION
   SELECT concat(user_function_name,' - Details'),function_name,'oracle.apps.inv.utilities.server.LPNDetailPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_LPN_INQUIRY'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wms.pup.server.PackUnpackSplitPage_WMS_UNPACK'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_UNPACK'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wms.pup.server.PackUnpackSplitPage_WMS_SPLIT'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_SPLIT'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.rcv.server.InspectPage_WMS_INSPECT'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_INSPECT'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.inv.count.server.CycleCountPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_CYCL_COUNT'
   UNION
   SELECT 'Lot Attributes Page - PO Receipt' user_function_name,function_name
,'oracle.apps.inv.utilities.server.LotAttPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_PO_RCPT'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.inv.invtxn.server.RcptTrxPage_INV_MOB_ALIAS_RCPT'
     FROM fnd_form_functions_vl
    WHERE function_name = 'INV_MOB_ALIAS_RCPT'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.count.server.PhyInvPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_PHYS_COUNT'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wms.pup.server.PackUnpackSplitPage_WMS_PACK'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_PACK'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.invtxn.server.IssueTrxPage_INV_MOB_ALIAS_ISS'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_ALIAS_ISS'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.invtxn.server.SubXferPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SUB_XFER'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.invtxn.server.OrgTransferPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_ORG_XFER'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.mo.server.QueryMinMaxReplPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_MO_REPL'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.kanban.server.RpKBPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_REPL_KANBAN'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.wshtxn.server.EasyShipPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_EZSHIP'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.wshtxn.server.LoadTruckPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_LOAD_TRUCK'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wms.td.server.DropByLocationPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DROP_BY_LOCATION'
   UNION
   SELECT concat(user_function_name,' - View Update'),function_name,'oracle.apps.yms.inq.server.ViewUpdateEqpPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_EQP_INQ'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.yms.inq.server.EqpInquiryPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_EQP_INQ'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.yms.tasks.server.EqpMovePage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_MOB_EQP_MOVE'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.yms.seals.server.SealUnsealPage_YMS_MOB_SEAL'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_MOB_SEAL'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.yms.seals.server.SealUnsealPage_YMS_MOB_UNSEAL'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_MOB_UNSEAL'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.wshtxn.server.ShipLPNPage_WMS_DOCK_LOAD'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DOCK_LOAD'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.wshtxn.server.ShipDeliveryPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SHIP'
   UNION
   SELECT concat(user_function_name,' - Delivery Lines'),function_name,'oracle.apps.inv.wshtxn.server.DeliveryLinePage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SHIP'
   UNION
   SELECT concat(user_function_name,' - Delivery'),function_name,'oracle.apps.inv.wshtxn.server.DeliveryPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SHIP'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.count.server.ScheduleCCPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SCHEDULE_CC'
   UNION
   SELECT concat(user_function_name,' (Putaway Load)'),function_name,'oracle.apps.wms.td.server.PutawayPage_WMS_DISPATCH_PUTAWAY_TASKS'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DISPATCH_PUTAWAY_TASKS'
   UNION
   SELECT concat(user_function_name,' (Putaway Drop)'),function_name,'oracle.apps.wms.td.server.PutawayPage_WMS_DISPATCH_PUTAWAY_TASKS_DROP'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DISPATCH_PUTAWAY_TASKS'
   UNION
   SELECT concat(user_function_name,' (Item Drop)'),function_name,'oracle.apps.wms.td.server.PutawayDropPage_WMS_DISPATCH_PUTAWAY_TASKS'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DISPATCH_PUTAWAY_TASKS'),
     path_Doc_tbl
    AS (
 select  jdr_mds_internal.getdocumentname(jp.path_docid)doc_path,path_docid
 from apps.jdr_paths jp 
 WHERE jp.path_docid in (select distinct comp_docid 
                         from   jdr_components 
                         where  comp_seq     = 0 
                         and    comp_element = 'customization'
                         and    comp_id      is null)
                         )
SELECT * from path_Doc_tbl b
WHERE EXISTS (SELECT  1 FROM func_mob a WHERE doc_path like  '%'||function_name||'%');



CURSOR cur_function (v_path VARCHAR2)
IS

SELECT *
 FROM (
   SELECT DECODE(function_name,'WMS_MANUAL_PICKING_MOB',concat('Mobile Pick Load - '
,user_function_name),'WMS_DROP_LOADED_LPNS_MOB',concat('Mobile Pick Drop - '
,user_function_name),user_function_name) user_function_name,function_name
,DECODE(function_name,'WMS_UPDATE','oracle.apps.wms.pup.server.UpdateLPNPage'
,'INV_MOB_PO_RCPT','oracle.apps.inv.rcv.server.RcptGenPage_INV_MOB_PO_RCPT'
,'WMS_MANUAL_PICKING_MOB','oracle.apps.wms.td.server.MainPickPage','WMS_DROP_LOADED_LPNS_MOB'
,'oracle.apps.wms.td.server.PickDropPage','WMS_IN_MANLD_MOB','oracle.apps.wms.td.server.PutawayPage_WMS_IN_MANLD_MOB'
,'WMS_PUTAWAY','oracle.apps.wms.td.server.PutawayPage_WMS_PUTAWAY','WMS_LPN_SHIP'
,'oracle.apps.inv.wshtxn.server.ShipLPNPage','WMS_MOVE_ANY_LPN_MOB','oracle.apps.wms.td.server.PutawayPage_WMS_MOVE_ANY_LPN_MOB'
,'oracle.apps.wms.default','WMS_ASN_RECEIPT','oracle.apps.inv.rcv.server.RcptGenPage_WMS_ASN_RECEIPT'
) path_name
     FROM fnd_form_functions_vl
    WHERE type = 'MOBILE'
      AND function_name IN (
       'WMS_UPDATE','INV_MOB_PO_RCPT','WMS_MANUAL_PICKING_MOB','WMS_DROP_LOADED_LPNS_MOB'
,'WMS_IN_MANLD_MOB','WMS_LPN_SHIP','WMS_MOVE_ANY_LPN_MOB','WMS_ASN_RECEIPT'
   )
   UNION
   SELECT DECODE(function_name,'INV_MOB_PO_RCPT',concat(user_function_name,
' Information'),'WMS_IN_MANLD_MOB',concat(user_function_name,' - Select Contents'
),'WMS_MANUAL_PICKING_MOB',concat('Mobile Pick Load - ',user_function_name
),'WMS_DROP_LOADED_LPNS_MOB',concat('Mobile Pick Drop - ',user_function_name
),user_function_name) user_function_name,function_name,DECODE(function_name
,'WMS_UPDATE','oracle.apps.wms.pup.server.UpdateLPNPage','INV_MOB_PO_RCPT'
,'oracle.apps.inv.rcv.server.RcptInfoPage','WMS_MANUAL_PICKING_MOB','oracle.apps.wms.td.server.MainPickPage'
,'WMS_DROP_LOADED_LPNS_MOB','oracle.apps.wms.td.server.PickDropPage','WMS_IN_MANLD_MOB'
,'oracle.apps.wms.td.server.ItemLoadPage','WMS_PUTAWAY','oracle.apps.wms.td.server.PutawayPage_WMS_PUTAWAY'
,'WMS_DROP_ALL_LPNS_MOB','oracle.apps.wms.td.server.PutawayPage_WMS_DROP_ALL_LPNS_MOB'
,'WMS_LPN_SHIP','oracle.apps.inv.wshtxn.server.ShipLPNPage','WMS_MOVE_ANY_LPN_MOB'
,'oracle.apps.wms.td.server.PutawayPage_WMS_MOVE_ANY_LPN_MOB','oracle.apps.wms.default'
)
     FROM fnd_form_functions_vl
    WHERE type = 'MOBILE'
      AND function_name IN (
       'WMS_UPDATE','INV_MOB_PO_RCPT','WMS_MANUAL_PICKING_MOB','WMS_DROP_LOADED_LPNS_MOB'
,'WMS_IN_MANLD_MOB','WMS_LPN_SHIP','WMS_MOVE_ANY_LPN_MOB'
   )
   UNION
   SELECT concat(user_function_name,' - Ship Confirm') user_function_name,function_name
,'oracle.apps.inv.wshtxn.server.DeliveryLPNPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_LPN_SHIP'
   UNION
   SELECT concat(user_function_name,' (Select Item)') user_function_name,function_name
,'oracle.apps.wms.td.server.PutawayDropPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_MOVE_ANY_LPN_MOB'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wip.wma.page.LpnCompletionPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMA_LPN_CMPASSY'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.gme.invtxn.server.IssueIngredientPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'GME_MOBILE_ISSUE_ING'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.gme.invtxn.server.CompleteProductPage'
     FROM fnd_form_functions_vl
    WHERE function_name LIKE 'GME_MOBILE_CMPLT_PROD'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.gme.invtxn.server.CreatePendingLotPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'GME_MOBILE_CREATE_PND_LOT'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.gme.invtxn.server.BackflushMaterialPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'GME_MOBILE_BACKFLUSH'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.wms.td.server.DetailPickPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_MANUAL_PICKING_MOB'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.inv.invinq.server.ItemOnhandQueryPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_INQUIRY'
   UNION
   SELECT concat(user_function_name,' - Details'),function_name,'oracle.apps.inv.utilities.server.LPNDetailPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_LPN_INQUIRY'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wms.pup.server.PackUnpackSplitPage_WMS_UNPACK'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_UNPACK'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wms.pup.server.PackUnpackSplitPage_WMS_SPLIT'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_SPLIT'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.rcv.server.InspectPage_WMS_INSPECT'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_INSPECT'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.inv.count.server.CycleCountPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_CYCL_COUNT'
   UNION
   SELECT 'Lot Attributes Page - PO Receipt' user_function_name,function_name
,'oracle.apps.inv.utilities.server.LotAttPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_PO_RCPT'
   UNION
   SELECT description user_function_name,function_name,'oracle.apps.inv.invtxn.server.RcptTrxPage_INV_MOB_ALIAS_RCPT'
     FROM fnd_form_functions_vl
    WHERE function_name = 'INV_MOB_ALIAS_RCPT'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.count.server.PhyInvPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_PHYS_COUNT'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wms.pup.server.PackUnpackSplitPage_WMS_PACK'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_PACK'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.invtxn.server.IssueTrxPage_INV_MOB_ALIAS_ISS'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_ALIAS_ISS'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.invtxn.server.SubXferPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SUB_XFER'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.invtxn.server.OrgTransferPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_ORG_XFER'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.mo.server.QueryMinMaxReplPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_MO_REPL'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.kanban.server.RpKBPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_REPL_KANBAN'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.wshtxn.server.EasyShipPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_EZSHIP'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.wshtxn.server.LoadTruckPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_LOAD_TRUCK'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.wms.td.server.DropByLocationPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DROP_BY_LOCATION'
   UNION
   SELECT concat(user_function_name,' - View Update'),function_name,'oracle.apps.yms.inq.server.ViewUpdateEqpPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_EQP_INQ'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.yms.inq.server.EqpInquiryPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_EQP_INQ'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.yms.tasks.server.EqpMovePage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_MOB_EQP_MOVE'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.yms.seals.server.SealUnsealPage_YMS_MOB_SEAL'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_MOB_SEAL'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.yms.seals.server.SealUnsealPage_YMS_MOB_UNSEAL'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'YMS_MOB_UNSEAL'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.wshtxn.server.ShipLPNPage_WMS_DOCK_LOAD'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DOCK_LOAD'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.wshtxn.server.ShipDeliveryPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SHIP'
   UNION
   SELECT concat(user_function_name,' - Delivery Lines'),function_name,'oracle.apps.inv.wshtxn.server.DeliveryLinePage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SHIP'
   UNION
   SELECT concat(user_function_name,' - Delivery'),function_name,'oracle.apps.inv.wshtxn.server.DeliveryPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SHIP'
   UNION
   SELECT user_function_name,function_name,'oracle.apps.inv.count.server.ScheduleCCPage'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'INV_MOB_SCHEDULE_CC'
   UNION
   SELECT concat(user_function_name,' (Putaway Load)'),function_name,'oracle.apps.wms.td.server.PutawayPage_WMS_DISPATCH_PUTAWAY_TASKS'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DISPATCH_PUTAWAY_TASKS'
   UNION
   SELECT concat(user_function_name,' (Putaway Drop)'),function_name,'oracle.apps.wms.td.server.PutawayPage_WMS_DISPATCH_PUTAWAY_TASKS_DROP'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DISPATCH_PUTAWAY_TASKS'
   UNION
   SELECT concat(user_function_name,' (Item Drop)'),function_name,'oracle.apps.wms.td.server.PutawayDropPage_WMS_DISPATCH_PUTAWAY_TASKS'
     FROM fnd_form_functions_vl
    WHERE function_name IN 'WMS_DISPATCH_PUTAWAY_TASKS'
) qrslt
 WHERE      v_path like '%'||function_name ||'%'
ORDER BY 2,3 desc;

rec_function cur_function%rowtype;

v_level_id NUMBER;
v_level_name VARCHAR2(1000);
  v_level VARCHAR2(1000);
  
    docID    JDR_PATHS.PATH_DOCID%TYPE;
    pathSeq  JDR_PATHS.PATH_SEQ%TYPE;
    pathType JDR_PATHS.PATH_TYPE%TYPE;
    docname  VARCHAR2(1024);
	
		
  BEGIN
  
 -- dbms_output.enable(9999999);
  
 dbms_output.put_line('***************************************************************');
 dbms_output.put_line('Customizations exist for following');
 dbms_output.put_line('***************************************************************');
  
  FOR rec_docs IN c_docs
	LOOP



OPEN cur_function (rec_docs.doc_path);
LOOP 
FETCH cur_function INTO rec_function;
EXIT WHEN cur_function%NOTFOUND;
END LOOP;    

 CLOSE cur_function;
	
	IF rec_docs.doc_path like '%/function/%' THEN
	v_level := 'Function';
	v_level_name := rec_function.USER_FUNCTION_NAME;
	
	ELSIF rec_docs.doc_path like '%/org/%' THEN
	
		v_level := 'Organization';
		
		
		SELECT REGEXP_SUBSTR(rec_docs.doc_path, '/org/([0-9]+)', 1, 1, NULL, 1) AS org_id
		INTO v_level_id
FROM dual;

IF v_level_id IS NOT NULL
THEN
select name
INTO v_level_name
from hr_organization_units
where organization_id= v_level_id;
END IF;
ELSIF rec_docs.doc_path like '%/responsibility/%' THEN
	
		v_level := 'Responsibility';
		
			SELECT REGEXP_SUBSTR(rec_docs.doc_path, '/responsibility/([0-9]+)', 1, 1, NULL, 1) AS org_id
		INTO v_level_id
FROM dual;

IF v_level_id IS NOT NULL
THEN
select responsibility_name
INTO v_level_name
from fnd_responsibility_vl
where responsibility_id= v_level_id;
END IF;

END IF;
	
	
	
dbms_output.put_line('***************************************************************');
dbms_output.put_line('Function Name:'||rec_function.FUNCTION_NAME);
dbms_output.put_line('User Function Name:'||rec_function.USER_FUNCTION_NAME);
dbms_output.put_line('Level:'||v_level);
dbms_output.put_line('Name:'||v_level_name);
dbms_output.put_line('Path:'||rec_docs.doc_path);
dbms_output.put_line('***************************************************************');


   	
        jdr_utils.listCustomizations(rec_docs.doc_path);
		
		    jdr_utils.printdocument(rec_docs.doc_path);
		

  
    
	END LOOP;
  END;
 /
  
  