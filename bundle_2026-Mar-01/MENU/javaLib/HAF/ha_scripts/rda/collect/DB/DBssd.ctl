# DBssd.ctl: Analyzes System State Dumps
# $Id: DBssd.ctl,v 1.6 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/DB/DBssd.ctl,v 1.5 2015/02/20 18:44:54 RDA Exp $
#
# Change History
# 20230628  DXM  Remove potentially insensitive words.
# 20150220  KRA  Improve list management.

=head1 NAME

DB:DBssd - Analyzes System State Dumps

=head1 DESCRIPTION

This module provides an overview of the content of system state dump files.

The following macro is available:

=cut

# Make the module persistent and share macros
keep $KEEP_BLOCK,@SHARE_MACROS,@TB_EVT,%TB_CMD,%TB_STA
var @SHARE_MACROS = ('analyze_ssd')

# Define the command list
var %TB_CMD = (1,"Create Table",\
               2,"Insert",\
               3,"Select",\
               4,"Create Cluster",\
               5,"Alter Cluster",\
               6,"Update",\
               7,"Delete",\
               8,"drop Cluster",\
               9,"Create Index",\
               10,"Drop Index",\
               11,"Alter Index",\
               12,"Drop Table",\
               13,"Create Sequence",\
               14,"Alter Sequence",\
               15,"Alter Table",\
               16,"Drop Sequence",\
               17,"Grant",\
               18,"Revoke",\
               19,"Create Synonym",\
               21,"Create View",\
               22,"Drop View",\
               24,"Create Procedure",\
               25,"Alter Procedure",\
               25,"ALter Procedure",\
               40,"Alter Tablespace",\
               42,"Alter Session",\
               44,"Commit",\
               45,"Rollback",\
               47,"PL/SQL Execute",\
               50,"Explain",\
               53,"Drop User",\
               54,"Drop Role",\
               62,"Analyze Table",\
               63,"Analyze Index",\
               64,"Analyze Cluster",\
               67,"Alter Profile",\
               68,"Drop Procedure",\
               85,"Truncate Table",\
               88,"Alter View",\
               94,"Create Pkg",\
               95,"Alter Pkg",\
               170,"Call Method",\
               189,"Upsert")

# Define patterns of events to skip in stuck analysis
var @TB_EVT = ("'rdbms ipc message'",\
               "'[ps]mon timer'",\
               "Net message (from|to) client'",\
               "Net message from dblink'")

# Define the status description
var %TB_STA = ('DEQ','buffer has been dequeued',\
               'EML','buffer on emergency message list',\
               'ENQ','buffer has been enqueued',\
               'FLST','buffer is on SGA freelist',\
               'FRE','buffer is free (unused)',\
               'GEB','buffer has been gotten for enqueuing',\
               'GDB','buffer has been gotten',\
               'INV','buffer is invalid (nonexistent)',\
               'NOFL','not on freelist (just removed)',\
               'QUE','buffer on queue message list',\
               'RCV','buffer has been received')

# -- Define the reporting macros ----------------------------------------------
macro rpt_end
{import $TOP

 # Highlight processes that seem to be stuck accros any two adjacent dumps
 prefix
 {write '---+ List of Processes That May Be Stuck'
  write '| *ID*|*Process Status*| *Sequence*|'
 }
 loop $pid (getDataIndex('STK'))
 {var $grp = $pid
  loop $key (getDataKeys('STK',$pid))
  {var ($seq,$evt) = split('\|',$key,2)
   write '| ',$grp,'|',$evt,' | ',$seq,'|'
   var $grp = ''
  }
 }
 if hasOutput(true)
  write $TOP
}

macro rpt_state
{var ($fil,$cnt,$ver,$all) = @arg
 var ($ltc,@tb_blk,@tb_obj,%blk) = (false)
 import $TOC,$TOP,@TB_EVT,%TB_CMD,%TB_STA
 keep $TOC,$TOP,@TB_EVT,%TB_CMD,%TB_STA

 # Initialise the report on first call
 if !isCreated()
 {write '---+!! System State Dump Analysis'
  if $fil
   write '---## Information Taken from ',encode($fil)
  write $TOC
 }
 write '---+ Summary of System State ',$cnt

 # Indicate a warning in case of aborted subdumps
 prefix
  write 'WARNING: The following processes had a corrupted state object tree:\
         %BR%'
 loop $pid (getDataIndex('ABT'))
  write '   * Process ',$pid,' at line ',getDataValue('ABT',$pid)
 unprefix

 # Treat all processes found in the current system state dump
 prefix
 {write '---++ Processes'
  write 'List of all processes. If they are waiting for a resource then it \
         will be given in square brackets.%BR%&nbsp;'
  write '| *ID*|*Process Status*|*Resource*| *Dead Status*| *Sequence*|'
 }
 var $flg = true
 loop $pid (getDataIndex('PRC'))
 {var $evt = getDataValue('PRC',$pid,'evt')
  var $oct = getDataValue('PRC',$pid,'oct')
  var $res = getDataValue('PRC',$pid,'res')
  var $seq = getDataValue('PRC',$pid,'seq')
  if !$oct
   var $cmd = undef
  elsif exists($TB_CMD{$oct})
   var $cmd = concat('Cmd: ',$TB_CMD{$oct})
  else
   var $cmd = concat('Cmd: Unknown(',$oct,')')
  write '| ',$pid,'|',\
        join('%BR%',$evt,$cmd),' |',\
        $res,' |',\
        cond(getDataValue('PRC',$pid,'isd'),' DEAD ',' '),'| ',\
        $seq,'|'

  if $evt
   var $flg = false

  if and($res,missing($blk{$res}))
  {var $blk{$res} = true
   call push(@tb_blk,$res)
   if $all
    call push(@tb_obj,$res)
  }

  # Check if it is in stuck across two adjacent system states
  loop $pat (@TB_EVT)
  {if match($evt,$pat)
   {var $seq = undef
    break
   }
  }
  if $seq
  {var $key = join('|',$seq,$evt)
   if getDataValue('PRV',$pid,$key)
    call setDataValue('STK',$pid,$key,true)
   call setDataValue('CUR',$pid,$key,true)
  }
 }
 if hasOutput(true)
 {write $TOP

  # Issue a warning if system state level seems too low
  if $flg
   write '%BR%%BR%\
          Warning: No wait information seen. The systemstate level may have \
          been too low. Use 10 or above.%BR%'
 }
 call renameData('CUR','PRV')

 # Provide the summary of blocking resources
 var $flg = false
 prefix
 {write '---++ Blockers'
  write 'Summary of the waited upon resources, together with the holder of \
         that resource.%BR%&nbsp;'
  write '|*Resource*| *Holder*|*State*|'
 }
 loop $blk (@tb_blk)
 {if match($blk,'Latch')
   var $ltc = true
  if getDataValue('BLK',$blk)
  {loop $pid (last)
   {if getDataValue('PRC',$pid,'res')
    {var $src = last
     if getDataValue('BLK',$src)
      var $src = join(', ',last)
     if compare('eq',$pid,$src)
      write '|',$blk,' | ',$pid,'|Self-Deadlock|'
     else
      write '|',$blk,' | ',$pid,'|',$pid,' is waiting for ',$src,'|'
    }
    elsif getDataValue('PRC',$pid,'evt')
     write '|',$blk,' | ',$pid,'|',last,' |'
    else
     write '|',$blk,' | ',$pid,'|Blocker|'
   }
  }
  else
  {write '|',$blk,' | ???|Blocker|'
   var $flg = true
  }
 }
 if $flg
  write 'Note: A process id of ``???`` implies that the holder was not found \
         in the system state dump. The holder may have released the resource \
         before we dumped the state object tree of the blocking process.%BR%'
 if !hasOutput(true)
 {write '---++ Blockers'
  write 'No blocking processes found%BR%'
 }
 write $TOP

 # Processes with a PIN INSTANCE LOCK set with "resource=T" may block other
 # processes as the pin cannot be granted until this setting is released. Since
 # this is only seen under RAC just record that these have the -potential- to
 # block other users across all nodes.
 prefix
 {write '---++ Pin Instances'
  write "The following processes have the PIN INSTANCE LOCK set in a way in \
         which other pin requesters may be blocked. Use the 'id=' column to \
         correlate potential blockers across nodes.%BR%&nbsp;"
  write '| *Process ID*| *Pin Instance*|'
 }
 loop $pid (getDataIndex('PIN'))
  write '| ',$pid,'|',join(' ',getDataValue('PIN',$pid)),' |'
 if hasOutput(true)
  write $TOP

 if $ltc
  write "%BR%%BR%\
         Some of the above latches may be child latches. Check the section \
         named 'Child Latch Report' below for further notes.%BR%&nbsp;"

 # Alert the user of multiple session processes
 prefix
 {write '---++ Multiple Sessions'
  write 'Warning: The following processes have multiple sessions and may not \
         be properly represented above:%BR%&nbsp;'
  write '|*Process Identifiers*|'
 }
 if getDataValue('MLT')
  write '| %COL16%',join('%BR%',last),'%ENDCOL%|'
 if hasOutput(true)
  write $TOP

 if expr('>=',$ver,8)
 {prefix
  {write '---++ Blockers According to 8i/9i Wait Information'
   write 'This may not work for 64bit platforms where the session state \
          object dump may show an incomplete address.\
          %BR%&nbsp;'
   write '| *Process*| *Blocked by Process*|'
  }
  loop $pid (getDataIndex('PRC'))
  {if getDataValue('PRC',$pid,'b8i')
    write '| ',$pid,'| ',\
          nvl(getDataValue('S8I',getDataValue('PRC',$pid,'b8i')),0),'|'
  }
  if hasOutput(true)
   write $TOP
 }

 # Report extra information
 if $all
 {var $chl = false
  prefix
  {write '---++ Object Names'
   write '|*ID*|*Name*|'
  }
  loop $obj (@tb_obj)
  {var $key = replace($obj,'^(LOCK|PIN): ')
   write '|',$obj,' |',substr(getDataValue('OBJ',$key),0,48),' |'
   next $chl
   if and(match($tmp,'Latch'),match(getDataValue('OBJ',$key),'Child'))
    var $chl = true
  }
  if hasOutput(true)
   write $TOP

  # Report the list of processes with skipped branches
  if getDataValue('BRC')
   write "%BR%%BR%\
          WARNING: The following is a list of process id's that have state \
          objects that are NOT owned by the parent state object and as such \
          such have been SKIPPED during processing. These are typically \
          SQL*Net loopback sessions.%BR%",join(', ',last),'%BR%'

  # If we see child latches then just make this fact obvious for now rather
  # than trying to deduce the parent. The child and parent addresses will
  # differ and this will not be properly detected by our blocker list.
  if $ltc
  {write '---++ Child Latch Report'
   if $chl
   {write "Some processes are being blocked waiting for child latches. At \
           the moment this script does not detect the blocker because the \
           child latch address differs to the parent latch address. To \
           manually detect the blocker, take the following steps:"
    write "   1 Determine the TYPE of latch (Eg library cache) that is \
                involved."
    write "   1 Search the source trace file for a target of:%BR%\
                holding.*Parent.*library cache%BR%\
                (Assuming we have a child library cache and have vi-like \
                regular expressions)"
    write "If this shows nothing then the blocker may have released the \
           resource before we got to dump the state object tree of the \
           blocked process. A list of processes that hold parent latches is \
           given below:%BR%%BR%"
    if refData('PL')
    {write '| *Process ID*|*Parent Latch*|'
     loop $pid (getDataIndex('PL'))
      write '|',$pid,'|',getDataValue('PL',$pid),' |'
    }
    else
     write 'No processes found%BR%'
   }
   else
    write 'No child latches seen%BR%'
   write $TOP
  }
 }

 # Report Query Coordinator information
 prefix
  write '---++ Query Coordinator to Query Worker Mapping'
 var %sta = ()
 loop $pid (getDataIndex('QC'))
 {# Report the query coordinator communication
  var (@tbl,@lin) = getDataValue('QC',$pid)
  loop $enq (getDataValue('PQE',$pid))
  {var @enq = split('-',$enq)
   call push(@lin,concat('Worker ``',$enq[2],'`` (hex) on instance ``',\
                         $enq[1],'`` (``',$enq,'``)'))
  }
  if hasOutput()
   write '%BR%'
  write '| *QC*| *Count*|*Communicates with ...*|'
  write '| ',$pid,'| ',scalar(@tbl),'|',join('%BR%',@lin),' |'

  # Report the worker mapping
  prefix
  {write '%BR%'
   write '| *QC*| *Worker*|*Info*| *Msg*|*State*| *From*| *To*|*Type*|*Status*|\
            *Mode*| *Err*|'
  }
  var $top = $pid
  loop $ref (reverse(@tbl))
  {var $sid = getDataValue('SLV',$ref)
   var $grp = $sid
   for $i (0,1)
   {next !getDataValue('PQD',$sid,$i)
    var @tmp = split('\s',last)
    var ($enq) = getDataValue('PQE',$sid)
    write '| ',$top,'| ',$grp,' |',$enq,' | ',$i,'|',\
          $tmp[0],' | ',\
          nvl(getDataValue('SLV',$tmp[1]),$tmp[1]),'| ',\
          nvl(getDataValue('SLV',$tmp[2]),$tmp[2]),'|',\
          $tmp[3],' |',\
          $tmp[4],' |',\
          $tmp[5],' | ',\
          $tmp[6],'|'
    var ($top,$grp,$sta{$tmp[4]}) = ('','',true)
   }
  }
  unprefix
 }

 # Include the description of the status present in the mapping tables
 if hasOutput(true)
 {prefix
  {write '%BR%'
   write '|*Status*|*Description*|'
  }
  loop $key (keys(%sta))
   write '|',$key,'|',nvl($TB_STA{$key},'?'),'|'
  unprefix
  write $TOP
 }
}

# -- Define the parsing macros ------------------------------------------------
macro debug
 debug @arg

macro echo
 echo @arg

# Detect branches
macro beg_branch
{var ($lin) = @arg
 call addDataValue('BRC',$pid)
 return concat('^',replace($lin,'branch of.*'))
}

# Initialisation for new process
macro beg_proc
{var ($lin,$cnt,\$cso,\$qid,\$skp) = @arg
 keep $dbg

 # Get the process identifier
 var ($pid) = match($lin,'^PROCESS (\d*):')
 incr $dbg
 if !expr('%',$pid,8)
  debug 'System state ',$cnt,', process ',$pid

 # Process initialisation
 call setDataValue('PRC',$pid,'b8i',0)
 call setDataValue('PRC',$pid,'evt','')
 call setDataValue('PRC',$pid,'isd',false)
 call setDataValue('PRC',$pid,'oct',0)
 call setDataValue('PRC',$pid,'res','')
 call setDataValue('PRC',$pid,'seq','')

 var $cso = 0      # The current state object
 var $qid = undef  # No current QC
 var $skp = 0      # Don't skip lines

 # Return the process identifier
 return $pid
}

# Initialisation of a new system state dump
macro beg_state
{var (\$cnt) = @arg

 incr $cnt
 debug 'Starting System State ',$cnt
 call deleteData('ABT')
 call deleteData('BLK')
 call deleteData('BRC')
 call deleteData('MLT')
 call deleteData('PIN')
 call deleteData('PL')
 call deleteData('PQD')
 call deleteData('PQE')
 call deleteData('QC')
 call deleteData('PRC')
 call deleteData('S8I')
 call deleteData('SLV')
 call deleteData('TMP')

 # Indicate that there is no current process
 return 0
}

# Extract abort information
macro parse_abort
{var ($lin,$pid) = @arg
 call setDataValue('ABT',$pid,inputLine())
 return -1
}

# (process) Oracle pid=6, calls cur/top: 22060e34/22060e34, flag: (3) DEAD
macro parse_dead
{call setDataValue('PRC',$arg[0],'isd',true)
 return 0
}

# Extract dictionary object cache enqueue
#   dictionary object cache enqueue
#   address: 7000002754e8858 next: 7000002754e88b8 prev: 700000000020038
#   process: 7000002623f2400 state: WAIT
macro parse_dict
{var ($pid) = @arg
 var $lin = parseLine(1)
 if match($lin,'\bREPL$')
  call addDataValue('BLK','Dictobj',$pid)
 else
  call setDataValue('PRC',$pid,'res','Dictobj')
 return 0
}

# Extract resource enqueue
#   (enqueue) TX-00030007-00004170
#   lv: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
#   res:c07c3e90, mode: X, prv: c07c3e98, sess: c1825fc8, proc: c180d338
macro parse_enqueue
{var ($lin,$pid,$all) = @arg
 var $enq = field('\s+',1,$lin)
 var $key = concat('Enq ',$enq)
 var $lin = parseLine(1)
 if $all
  call setDataValue('OBJ',$key,'')
 if match($lin,'\bmode:')
 {call addDataValue('BLK',$key,$pid)
  if match($enq,'^PS')
   call addDataValue('PQE',$pid,replace($enq,'-0+','-0',true))
 }
 if match($lin,'\breq:')
  call setDataValue('PRC',$pid,'res',$key)
 return -1
}

# Extract the wait event
macro parse_event
{var ($lin,$pid) = @arg
 if getDataValue('PRC',$pid,'evt')
 {call addDataValue('MLT',$pid)
  var $skp = -1
 }
 call setDataValue('PRC',$pid,'evt',get_event($pid,match($lin,"^(.*?') ")))
 # Temp fix for 11g
 if match($lin,'seq_num=(\d*)\s')
 {var ($val) = (last)
  call setDataValue('PRC',$pid,'seq',$val)
  var $lin = parseLine(4)
  var ($val) = match($lin,'^blocking_sess=(\S*)')
  if compare('!=',$val,'(nil)')
   call setDataValue('PRC',$pid,'blk',$val)
 }
 # Go to next line
 return -1
}

macro get_ascii
{var $val = hex2dec($arg[0])
 if or(expr('<',$val,65),expr('>',$val,90))
  return '?'
 decr $val,65
 return substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ',$val,1)
}

macro get_event
{var ($pid,$nam) = @arg
 var $str = replace(replace($nam,"^.* for '","'"),'(holding|acquiring) ',true)
 if match($str,"^'(db file (sequential|scattered) read|\
                   db file (parallel|sequential) write|\
                   buffer busy waits|\
                   free buffer waits|\
                   buffer deadlock|\
                   parallel query qref latch)'$")
 {var $lin = parseLine()
  var @fld = split('[=\s]+',$lin,7)
  return concat($nam,' (',$fld[1],$fld[3],$fld[5],')')
 }
 if match($str,"^'pipe get'$")
 {var $lin = parseLine()
  return concat($nam,' (',field('\s',1,$lin),')')
 }
 if match($str,"^'parallel query dequeue wait'$")
 {var $lin = parseLine()
  var @fld = split('[=\s]+',$lin,7)
  return concat($nam,' (',$fld[1],$fld[3],$fld[5],')')
 }
 if match($str,"^'(enqueue|DFS lock acquisition)'$")
 {var $lin = parseLine()
  var @fld = split('[=\s]+',$lin,7)
  return concat($nam,' (',get_ascii(substr($fld[1],0,2)),\
                get_ascii(substr($fld[1],2,2)),' id=',$fld[3],$fld[5],')')
 }
 if match($str,"^'rdbms ipc reply'$")
 {var $lin = parseLine()
  var @fld = split('[=\s]+',$lin,3)
  var $prc = hex2dec(replace($fld[1],','))
  var $str = concat('IPC ',$prc)
  call setDataValue('PRC',$pid,'res',$str)
  call addDataValue('BLK',$str,$prc)
  return concat($nam,' (',$fld[0],$prc,')')
 }
 return $nam
}

# Extract resource cache buffer information
#   (buffer) (CR) PR: 37290 FLG:    0
#   kcbbfbp    : [BH: befd8, LINK: 7836c] (WAITING)
#   BH #1067 (0xbefd8) dba: 5041865 class 1 ba: a03800
#     hash: [7f2d8,b47d0],  lru: [16380,b1b50]
#     use:  [78eb4,78eb4], wait: [79cf4,78664]
#     st: READING, md: EXCL, rsop: 0
#     cr:[[scn: 0.00000000],[xid: 00.00.00],[uba: 00.00.00], sfl: 0]
#     flags: only_sequential_access
#     L:[0.0.0] H:[0.0.0] R:[0.0.0]
#     Using State Objects
macro parse_buffer
{var ($lin,$pid) = @arg
 var $mod = field('\s+',6,$lin)
 var $lin = parseLine()
 var $key = concat('Buffer ',field('\s+',4,$lin))
 if match($mod,'^\((EXCLUSIVE|WAITING)\)$')
  call setDataValue('PRC',$pid,'res',$key)
 else
  call addDataValue('BLK',$key,$pid)
 return 0
}

# Extract latch information
#   waiting for  80108e04 shared pool level=7 state=free
#      wtr=80108e04, next waiter 0
#   holding     80108eec library cache pin level=6 state=busy
macro parse_latch_hold
{var ($lin,$pid,$all) = @arg
 var $key = concat('Latch ',field('\s+',1,$lin))
 call addDataValue('BLK',$key,$pid)
 if and($all,not(getDataValue('OBJ',$key)))
 {var $key = concat('Latch ',field('\s+',2,$lin))
  var $lin = replace(replace($lin,'^ *waiting for *[a-f0-9]* '),' level.*$')
  call setDataValue('OBJ',$key,$lin)
 }
 return 0
}

macro parse_latch_wait
{var ($lin,$pid,$all) = @arg
 var $key = concat('Latch ',field('\s+',2,$lin))
 call setDataValue('PRC',$pid,'res',$key)
 if and($all,not(getDataValue('OBJ',$key)))
 {var $key = concat('Latch ',field('\s+',2,$lin))
  var $lin = replace(replace($lin,'^ *waiting for *[a-f0-9]* '),' level.*$')
  call setDataValue('OBJ',$key,$lin)
 }
 return 0
}

# LIBRARY OBJECT PIN: pin=c0f3aa90 handle=c15bcac0 mode=S lock=c0f3b840
# LIBRARY OBJECT LOCK: lock=c0f3b840 handle=c15bcac0 mode=N
macro parse_lib_mode
{var ($lin,$pid) = @arg
 if !match($lin,'mod(e)?=N')
 {var @fld = split('\s+',$lin,6)
  var $key = concat($fld[2],' ',$fld[4])
  call addDataValue('BLK',$key,$pid)
 }
 return 0
}

macro parse_lib_request
{var ($lin,$pid) = @arg
 var @fld = split('\s+',$lin,6)
 call setDataValue('PRC',$pid,'res',concat($fld[2],' ',$fld[4]))
 return 0
}

# LIBRARY OBJECT LOAD LOCK: lock=c00000007a366fe8
# process=c000000077bc1148 object=c00000007baac6c8 request=X mask=0101
macro parse_load
{var ($lin,$pid) = @arg
 var $lin = parseLine()
 var @fld = split('[\s=]+',$lin,6)
 var $key = concat('LOAD: ',$fld[3])
 if compare('eq',$fld[4],'request')
  call setDataValue('PRC',$pid,'res',$key)
 else
  call addDataValue('BLK',$key,$pid)
 return 0
}

# Extract resource: Lock Element Dump
# pre-9i Example:
#   LOCK CONTEXT DUMP (address: 0x90ceab20):
#   op: 2 nmd: EXCLUSIVE  dba: 0x5400004f cls: DATA       cvt: 0 cln: 1
#      LOCK ELEMENT DUMP (number: 14048, address: 0x91212498):
#      mod: NULL       rls:0x00 acq:03 inv:0 lch:0x921a366c,0x921a366c
#      lcp: 0x90ceab20 lnk: 0x90ceab30,0x90ceab30
# Complete: Always assumes waiting AND just identifies one resource !!
#
# 9i Example:
#   LOCK CONTEXT DUMP (address: 0x5f720b778):
#   op: 3 nmd: S tsn: 6 rdba: 0xd300e0fb cls: DATA type: 1
#     GLOBAL CACHE ELEMENT DUMP (address: 0x3f0fb07a0):
#     id1: 0xd2c0e0fb id2: 0x8000 lock: SG rls: 0x000 acq: 0x01
#                                       ^^
# This is actually two strings. kcllemode and kcllelocal. The first is the
# lock mode and the second a one letter code to denote a [G]lobal or [L]ocal
# lock.
macro parse_lock
{var ($lin,$pid,$ver,$all) = @arg
 var $ver = expr('>=',$ver,9)
 var $lin = parseLine()
 var $fld = field('\s+',3,$lin)
 var $flg = match($fld,cond($ver,'^N(ULL)?$','^NULL$'))
 var $lin = parseLine()
 var $key = concat('Elem ',field('\s+',cond($ver,5,4),$lin))
 if $flg
  call addDataValue('BLK',$key,$pid)
 else
  call setDataValue('PRC',$pid,'res',$key)
 if $all
 {var $lin = parseLine()
  # For 9i+, use the entire lock code even a G or L is appended for its scope
  var $lin = parseLine(5)
  call addDataValue('OBJ',$key,field('\s+',1,$lin))
 }
 return 0
}

# Handle to Object Mapping (Verbose mode)
#   LIBRARY OBJECT HANDLE: handle=40e25e08
#   name=TEST.CRSMESSAGELOG
#   hash=e2deff52 timestamp=11-22-1995 17:53:55
#   namespace=TABL/PRCD flags=TIM/SML/[02000000]
macro parse_mapping
{var ($lin) = @arg
 var $key = field('\s+',3,$lin) # handle

 var $lin = parseLine()
 if !getDataValue('OBJ',$key)
 {# Skip child cursors for now
  if !match($lin,'namespace=')
  {var $lin = replace($lin,'^name=')
   if !length($lin)
    var $lin = parseLine()
   var $txt = $lin
   while !match($lin,'namespace')
    var $lin = parseLine()
   var $typ = field('\s+',0,$lin)
   call setDataValue('OBJ',$key,concat($typ,':',$txt))
  }
 }
 return -1
}

# Handle to Object Mapping for 11g(Verbose mode)
#   LIBRARY HANDLE:2F6090C8 bid=72300 hid=535d1a6c lmd=N pmd=0 sta=VALD
#   name=select text from view$ where rowid=:1
#   hash=f0cfa2e63e1fda46fbf3cdf9535d1a6c idn=0
#   tim=11-10-2008 19:29:53      kkkk-dddd-llll=0000-0001-0001
#   exc=843 ivc=1 ldc=4 cbb=1 rpr=1 kdp=2 slc=4 dbg=0
#   dmtx=2F609124(0, 0, 0) mtx=2F609148(0, 381, 0)
#   nsp=CRSR(00) typ=CRSR(00) flg=RON/KGHP/TIM/PN0/SML/KST/DBN/MTX/[120108d0]

macro parse_mapping_11g
{var ($lin) = @arg
 var (undef,$key) = split(':',field('\s+',1,$lin),2) # handle

 var $lin = parseLine()
 if !getDataValue('OBJ',$key)
 {# Skip child cursors for now
  var $lin = replace($lin,'^name=')
  if !length($lin)
   var $lin = "Unknown"
  var $txt = $lin
  while !match($lin,'nsp=')
   var $lin = parseLine()
  var $typ = field('\s+',0,$lin)
  call setDataValue('OBJ',$key,concat($typ,':',$txt))
 }
 return -1
}

# Extract the parent session's command
macro parse_oct
{var ($lin,$pid) = @arg
 if !getDataValue('PRC',$pid,'oct')
  call setDataValue('PRC',$pid,'oct',field(',?\s+',1,$lin))
 return 0
}

# Extract pin instance lock information
#   LOCK INSTANCE LOCK: id=LB3791b1418e1e06ff
#   PIN INSTANCE LOCK: id=NB3791b1418e1e06ff mode=S release=T flags=[00]
#   INVALIDATION INSTANCE LOCK: id=IV006ed60b11172935 mode=S
macro parse_pin
{var ($lin,$pid) = @arg
 call addDataValue('PIN',$pid,field('\s+',3,$lin))
 return 0
}

# Extract parent latch information
macro parse_platch
{var ($lin,$pid) = @arg
 call setDataValue('PL',$pid,replace($lin,'^holding *'))
 return 0
}

# PQO QC <-> QS Code
#   A QC can be identified within a systemstate by any of the following
#   methods :
#   - Look for 'flags' being set to ISQC when dumped as part of the Process
#     Queue state object dump (not the Message Buffer state object dump).
#   - Look for PS enqueues being held in EXCLUSIVE mode.
#     (Null is used for the query workers).
#     We can then pick up the 'proc:' address of the enqeueue s.o. and link
#   - Check to see whether the Process Queue state object hangs under the
#     Session state object (QC) rather than the process state object (Worker).
#   One QC can have TWO Process Queue state objects with flag ISQC if the QC
#   manipulates two query worker sets (producer/consumer).
macro parse_pqo
{var ($lin,$pid) = @arg
 var @fld = split(',?\s',$lin,7)
 call setDataValue('PQD',$pid,getDataValue('TMP','pqo_buf'),\
   join(' ',getDataValue('TMP','pqo_ste'),\
            $fld[5],\
            $fld[2],\
            getDataValue('TMP','pqo_typ'),\
            getDataValue('TMP','pqo_sta'),\
            getDataValue('TMP','pqo_mod'),\
            getDataValue('TMP','pqo_err')))
 return -1
}

#state: 00000, flags: SMEM OPEN COPE, nulls 0, hint 0x0
macro parse_pqo1
{var ($lin) = @arg
 call setDataValue('TMP','pqo_ste',field(',?\s',1,$lin))
 return -1
}


#ser: 23040, seq: 1, flags: DIAL CLR, status: FRE, err: 0
macro parse_pqo2
{var ($lin) = @arg
 var $lin = replace($lin,':\s','=',true)
 var @fld = split(',',$lin,6)
 call setDataValue('TMP','pqo_mod',value($fld[2]))
 call setDataValue('TMP','pqo_sta',value($fld[3]))
 call setDataValue('TMP','pqo_err',value($fld[4]))
 return -1
}

#
macro parse_pqo3
{var ($lin) = @arg
 var @fld = split(',?\s',$lin,8)
 call setDataValue('TMP','pqo_typ',$fld[4])
 call setDataValue('TMP','pqo_buf',$fld[6])
 return -1
}

# Extract QC information (in two phases because of Sequent 'feature')
#   opp qref: 0x67dd950, process: 0x7046ae4, bufs: {0x0, 0x65ff6f8}
macro parse_qc1
{var (\$qid,$pid,$tso) = @arg
 if !match($tso,'Process Queue')
  return 0
 var $qid = $pid
 return -1
}
macro parse_qc2
{var ($lin,$qid) = @arg
 if !defined($qid)
  return 0
 call addDataValue('QC',$qid,field(',?\s',2,$lin))
 return -1
}

# Extract the worker reference
#   Queue Reference--kxfpqr: 0x67d4244, ser: 23040, seq: 31066, error: 0
#   client 1, detached proc: 0x726899c, QC qref 0x67dd950, flags: -none-
macro parse_qref
{var ($lin,$pid,$off) = @arg
 call setDataValue('SLV',field(',?\s',$off,$lin),$pid)
 return -1
}

# Extract row cache enqueue information
#   row cache enqueue: count=1 session=c1825fc8 object=c146e960, request=S
#   row cache parent object: address=c146e960 type=9(dc_tables)
macro parse_row
{var ($lin,$pid,$all) = @arg
 var $key = concat('Rcache ',field('\s+',5,$lin))
 if match($lin,'mode')
  call addDataValue('BLK',$key,$pid)
 else
  call setDataValue('PRC',$pic,'res',$key)
 if and($all,not(getDataValue('OBJ',$key)))
 {var $lin = parseLine()
  if !match($lin,'^ *row cache parent')
   var $lin = parseLine()
  var $str = field('\s+',5,$lin)
  var $str = replace($str,'.*type=.*dc_','\(dc_')
  call setDataValue('OBJ',$key,replace($str,'.*type=.*dc_','\(dc_'))
 }
 return 0
}

# Parse sequence information
#   last wait for 'db file sequential read' seq=39279 wait_time=4
# Note: 10g appends 'seconds since wait started=15'
# Note: For 11g
#   Dumping Wait Stack:
#    0: waiting for 'DIAG idle wait' wait_id=79380 seq_num=13844 snap_id=1
#       component=5, where=1, wait time(millisec)=3e8
#       wait times (usecs) - snap=2905 exc=2905 total=2905 max=1000000
#       wait counts (snap/exc) - calls=1/1 os=1/1
#       in_wait=1 iflags=0x7a8
#       blocking_sess=(nil)
macro parse_seq
{var ($lin,$pid) = @arg
 var ($seq) = match($lin,'seq=(.*?)\s+wait_time')
 call setDataValue('PRC',$pid,'seq',$seq)
 if match($lin,'blocking sess=(\S+)')
 {var ($blk) = (last)
  if !match($blk,'^0x')
   call setDataValue('PRC',$pid,'b8i',$blk)
 }
 return 0
}

# Parse sequence and event information for 11g
# 0: waiting for 'pmon timer'
#    duration=12c, =0, =0
#    wait_id=2215 seq_num=2216 snap_id=1
macro parse_seq_11g
{var ($lin,$pid) = @arg
 if getDataValue('PRC',$pid,'evt')
 {call addDataValue('MLT',$pid)
  var $skp = -1
 }
 call setDataValue('PRC',$pid,'evt',get_event($pid,match($lin,"^0: (.*?')$")))
 var $lin = parseLine(1)
 var ($seq) = match($lin,'seq_num=(.*?)\ssnap_id')
 call setDataValue('PRC',$pid,'seq',$seq)
 if match($lin,'blocking sess=(\S+)')
 {var ($blk) = (last)
  if !match($blk,'^0x')
   call setDataValue('PRC',$pid,'b8i',$blk)
 }
 return -1
}

# Parse session information
#   SO: 800620e4, type: 3, owner: 80053418, flag: INIT/-/-/0x00
#   (session) trans: 801382dc, creator: 80053418, flag: (41) USR/- BSY/-/-/-/-/-
macro parse_session
{var ($cso,$pid) = @arg
 call setDataValue('S8I',$cso,$pid)
 return 0
}

# Parse SO information
macro parse_so
{var ($lin,\$cso,\$tso) = @arg
 var $cso = field(',?\s+',1,$lin)
 var $lin = parseLine()
 var @fld = split('\s',$lin,3)
 var $tso = concat($fld[0],' ',$fld[1])
 return 0
}

=head2 analyze_ssd($fil,...)

This macro analyzes the specified system dump files.

=cut

macro analyze_ssd
{# Initialisation
 var $all = 1  # Complete analysis
 var $brc = 1  # Skip branches
 var $ora = 0  # Oracle database version
 var $sst = 0  # System state counter

 var $cso = 0
 var $ini = 1
 var $pat = undef
 var $qid = 0
 var $tso = ''
 var $ttl = cond(expr('>',scalar(@arg),1),undef,$arg[0])

 # Define the parsing rules
 call parseReset()
 call parseInfo('TOP','ltr',true)
 call parseInfo('TOP','rtr',true)
 call parseInfo('TOP','ini','ORA')
 call parseBegin('TOP','^SYSTEM STATE','SST','GRP0')

 call parsePattern('ORA','^Oracle(7|8i?|9i)?\s',\
  code($ora = check(line,'^Oracle7\s',  '7',\
                         '^Oracle8\s',  '8.0',\
                         '^Oracle8i\s', '8.1',\
                         '^Oracle9i\s', check(line,'\s9\.2\.','9.2','9.0'),\
                         '^Oracle\s',   check(line,'\s11\.1\.','11.1',\
                                                   '\s10\.2\.','10.2',\
                                                   '\s10\.1\.','10.1',\
                                                   '10')),\
       debug('Oracle version is: ',$ora),\
       1))

 call parseBegin('SST','^PROCESS \d*:','PRC','GRP1')
 call parseEnd('SST','^(END OF SYSTEM STATE|PROCESS STATE)')
 call parseInfo('SST','beg',$pid = beg_state(\$sst))
 call parseInfo('SST','end',rpt_state($ttl,$sst,$ora,$all))

 call parseInfo('PRC','beg',$pid = beg_proc(line,$sst,\$cso,\$qid,\$skp))
 call parseInfo('PRC','flp',false)

 call parsePattern('PRC','^SO:',parse_so(line,\$cso,\$tso))
 call parsePattern('PRC','SHUTDOWN: waiting for logins to complete',-1)

 # Skip 'branch of' state objects
 if $brc
 {call parseBegin('PRC','^branch of','SKP')
  call parseInfo('SKP','beg',$pat = beg_branch(line))
  call parseInfo('SKP','flp',false)
  call parseInfo('SKP','llp',true)
  #call parseCode('SKP',cond(match(replace(line,$pat),'^ '),-1,1))
  call parseCode('SKP',cond(match(line,$pat),1,-1))
 }

 # Skip multiple sessions
 call parseCode('PRC',$skp)

 # Deal with patterns that may involve multiple processing
 call parsePattern('PRC','waiting for .*seq=.*wait_time',parse_seq(line,$pid),\
                         "0: waiting for '.*'$",parse_seq_11g(line,$pid))
 call parsePattern('PRC','^.session. .*trans',parse_session($cso,$pid))
 call parsePattern('PRC','^holding .*Parent.*level=',parse_platch(line,$pid))
 call parsePattern('PRC','(process).*flag:.*DEAD',parse_dead($pid))
 call parsePattern('PRC','LIBRARY OBJECT LOAD',parse_load(line))
 call parsePattern('PRC','^PIN INSTANCE LOCK:.*release=T',parse_pin(line))

 # Mutually exclusive options are listed below
 call parsePattern('PRC',\
  "(acquiring|holding|last wait for|^(0: )?waiting for) .*'",\
   parse_event(line,$pid),\
  'LIBRARY OBJECT .*mod(e)?',parse_lib_mode(line,$pid),\
  'LIBRARY OBJECT .*request',parse_lib_request(line,$pid),\
  '^kcbbfbp',parse_buffer(line,$pid),\
  'LOCK CONTEXT DUMP',parse_lock(line,$pid,$ora,$all),\
  '\(enqueue\) <no resource>',-1,\
  '\(enqueue\)',parse_enqueue(line,$pid,$all),\
  'row cache enqueue:',parse_row(line,$pid,$all),\
  '^dictionary object cache enqueue',parse_dict($pid),\
  '^(0: )?waiting for *[a-f0-9]* ',parse_latch_wait(line,$pid,$all),\
  '(acquiring|holding) *[a-f0-9]* ',parse_latch_hold(line,$pid,$all),\
  '^oct: .*, prv:',parse_oct(line,$pid),\
  '^Aborting this subtree dump',parse_abort(line,$pid))
 if $all
  call parsePattern('PRC',\
   'LIBRARY OBJECT HANDLE:',parse_mapping(line),\
   'LIBRARY HANDLE:',parse_mapping_11g(line),\
   'Queue Reference--kxfpqr',parse_qref(line,$pid,2),\
   'flags: ISQC',parse_qc1(\$qid,$pid,$tso),\
   'opp qref:.*process:',parse_qc2(line,$qid),\
   'client.*QC qref 0x0',-1,\
   'client.*QC qref',parse_qref(line,$pid,7),\
   'state.*hint',parse_pqo1(line),\
   '^ser:.*seq:.*flags:.*err:',parse_pqo2(line),\
   'Message Buffer--',parse_pqo3(line),\
   'to qref.*from qref',parse_pqo(line,$pid))

 # Parse the system state dump file
 loop $fil (@arg)
 {if createBuffer('TRC','V',$fil)
  {call parse('TRC')
   call parseInfo('TOP','ini','')
  }
 }

 # Close the report
 call rpt_end()
}

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
