# DBalert.ctl: Analyzes Alert Log
# $Id: DBalert.ctl,v 1.4 2015/09/01 10:33:37 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/DB/DBalert.ctl,v 1.4 2015/09/01 10:33:37 RDA Exp $
#
# Change History
# 20150901  MSC  Improve the restart time detection.

=head1 NAME

DB:DBalert - Analyzes Alert Log File

=head1 DESCRIPTION

This module analyzes the alert log file and produces an analysis summary. Times
are truncated at the second level.

=cut

# Make the module persistent and share macros
keep $KEEP_BLOCK,@SHARE_MACROS
var @SHARE_MACROS = ('analyze_alert')

# Macros to format a time stamp
macro fmt_time
 return replace(getLocalTime($arg[0]),' ','&nbsp;',true)

# Macro for reading the alert.log
macro analyze_alert
{var ($fil,$xml) = @arg
 var %sta = ('fil',$fil)
 var (@cmd,@err,@swt,@trc,%err) = ()

 debug ' Inside DBalert module, analyzing the alert.log data (can take time)'
 if createBuffer('ALS','V',$fil)
 {# Define parsing macros
  code parse_cmd = -1
   call push(@cmd,concat(fmt_time(last),'|',line))

  code parse_cnt = -1
   incr $sta{last}

  code parse_err = -1
  {if !$sta{'err'}
   {var $sta{'err'} = true
    call push(@err,[eval(&log_tsp($sta{'cur'}))])
   }
   call push(@err,line)
   if match(line,'^((ORA|PLS)-\d+)')
    incr $err{first(last)}
  }

  code parse_str = -1
  {var $tim = [nvl(first,&log_tsp($sta{'beg'} = $sta{'cur'} = getLine('ALS')))]
   incr $sta{'str'}
   # Add the event in the error summary
   if !$sta{'err'}
   {var $sta{'err'} = true
    call push(@err,$tim)
   }
   call push(@err,'Instance was restarted')
   # Add the event in the trace summary
   if !$sta{'trc'}
   {var $sta{'trc'} = true
    call push(@trc,$tim)
   }
   call push(@trc,'Instance was restarted')
  }

  code parse_swt = -1
   call push(@swt,last)

  code parse_trc = -1
  {if !$sta{'trc'}
   {var $sta{'trc'} = true
    call push(@trc,[eval(&log_tsp($sta{'cur'}))])
   }
   call push(@trc,line)
  }

  # Define the code blocks to parse and to decode a time stamp
  if $xml
  {code parse_tsp = -1
   {var $sta{'cur'} = $sta{'end'} = $tim = \
      first(match(line,"<msg time='([^']+)'"))
    var $sta{'beg'} = nvl($sta{'beg'},$tim)
    var $sta{'err'} = $sta{'trc'} = false
   }
   code log_tsp
   {var ($yer,$mon,$day,$hur,$min,$sec) = \
      match(last,'^(\d{4})-(\d+)-(\d+)T(\d+):(\d+):(\d+)')
    decr $mon
    call mktime($sec,$min,$hur,$day,$mon,$yer)
   }
  }
  elsif isVirtualVms()
  {code parse_tsp = -1
   {var $sta{'cur'} = $sta{'end'} = $tim = replace(parseHit(0),'^\s','0')
    var $sta{'beg'} = nvl($sta{'beg'},$tim)
    var $sta{'err'} = $sta{'trc'} = false
   }
   code log_tsp
   {var ($day,$mon,$yer,$hur,$min,$sec) = split('-|\s+|:',last)
    call mktime($sec,$min,$hur,$day,$mon,$yer)
   }
  }
  else
  {code parse_tsp = -1
   {var $sta{'cur'} = $sta{'end'} = $tim = line
    var $sta{'beg'} = nvl($sta{'beg'},$tim)
    var $sta{'err'} = $sta{'trc'} = false
   }
   code log_tsp
   {var (undef,$mon,$day,$hur,$min,$sec,$yer,$oth) = split('\s+|:',last)
    if !match($yer,'\d+')
     var $yer = $oth
    call mktime($sec,$min,$hur,$day,$mon,$yer)
   }
  }

  # Parse the alert.log
  var %key = ('Checkpoint not complete'  => 'chk',\
              'IPC Send timeout'         => 'ipc',\
              'Reconfiguration started'  => 'rcb',\
              'Reconfiguration complete' => 'rce')
  call parseReset()
  if $xml
  {call parsePattern('TOP','<msg time=',&parse_tsp())
   call parseBegin('TOP','^\s*<txt>','TXT')
   call parseInfo('TXT','beg',parseReplace(replace(line,'^\s*<txt>')))
   call parseInfo('TXT','flp',true)
   call parsePattern('TXT',\
     '^Thread .* advanced to log sequence',\
       &parse_swt(&log_tsp($sta{'cur'})),\
     '^(ORA-|PLS-|SVR4 Error:|Additional information:|Linux Error:|\
        IBM AIX RISC System\/6000 Error:|O\/S-Error:|OSD-)',\
       &parse_err(),\
     '^(Errors in file|Details in trace file)',\
       &parse_trc(),\
     'Starting ORACLE instance',\
       &parse_str(&log_tsp($sta{'cur'})),\
     '^ALTER SYSTEM',\
       &parse_cmd(&log_tsp($sta{'cur'})),\
     '^Thread .* cannot allocate new log',\
       &parse_cnt('non'),\
     '^(Checkpoint not complete|\
        IPC Send timeout|\
        Reconfiguration started|\
        Reconfiguration complete)',\
       &parse_cnt($key{parseHit(0)}))
   call parseEnd('TXT','^\s*</txt>')
  }
  elsif isVirtualVms()
   call parsePattern('TOP',\
     '^(\s?\d{1,2}-[A-Za-z]{3}-\d{4}\s+\d{2}:\d{2}:\d{2})\.\d+',\
       &parse_tsp(),\
     '^Thread .* advanced to log sequence',\
       &parse_swt(&log_tsp($sta{'cur'})),\
     '^(ORA-|PLS-|SVR4 Error:|Additional information:|Linux Error:|\
        IBM AIX RISC System\/6000 Error:|O\/S-Error:|OSD-)',\
       &parse_err(),\
     '^(Errors in file|Details in trace file)',\
       &parse_trc(),\
     '^(ALTER\s+DATABASE\s+MOUNT|alter\s+database\s+mount)',\
       &parse_str(&log_tsp($sta{'cur'})),\
     '^ALTER SYSTEM',\
       &parse_cmd(&log_tsp($sta{'cur'})),\
     '^Thread .* cannot allocate new log',\
       &parse_cnt('non'),\
     '^(Checkpoint not complete|\
        IPC Send timeout|\
        Reconfiguration started|\
        Reconfiguration complete)',\
       &parse_cnt($key{parseHit(0)}))
  else
   call parsePattern('TOP',\
     '^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\b',\
       &parse_tsp(),\
     '^Thread .* advanced to log sequence',\
       &parse_swt(&log_tsp($sta{'cur'})),\
     '^(ORA-|PLS-|SVR4 Error:|Additional information:|Linux Error:|\
        IBM AIX RISC System\/6000 Error:|O\/S-Error:|OSD-)',\
       &parse_err(),\
     '^(Errors in file|Details in trace file)',\
       &parse_trc(),\
     'Starting ORACLE instance',\
       &parse_str(&log_tsp($sta{'cur'})),\
     '^ALTER SYSTEM',\
       &parse_cmd(&log_tsp($sta{'cur'})),\
     '^Thread .* cannot allocate new log',\
       &parse_cnt('non'),\
     '^(Checkpoint not complete|\
        IPC Send timeout|\
        Reconfiguration started|\
        Reconfiguration complete)',\
       &parse_cnt($key{parseHit(0)}))
  call parse('ALS')
  var $sta{'lin'} = inputLine('ALS')

  # Report the analysis
  call write_alert_summary(\%sta,\%err,\@cmd,\@err,\@swt,\@trc,\
    eval(&log_tsp($sta{'beg'})),eval(&log_tsp($sta{'end'})),$xml)
 }
}

# Macro for writing the alert.log summary
macro write_alert_summary
{var (\%sta,\%err,\@cmd,\@err,\@swt,\@trc,$beg,$end,$xml) = @arg
 import $TOP,$TOC

 # Define a macro to report events, while merging duplicates
 macro write_nodup
 {# Define a macro to report an event
  macro write_event
  {var ($beg,$end,$cnt,$evt) = @arg
   if $cnt
   {incr $cnt
    write '|',fmt_time($beg),' |',\
              fmt_time($end),' | ',$cnt,'|',$evt,' |'
   }
   else
    write '|',fmt_time($beg),' |||',$evt,' |'
  }

  # Merge duplicates
  var ($cnt,$old,$new) = (0)
  loop $lin (@arg,[])
  {if ref($lin) # Compare event list
   {if compare('eq',$new,$old)
    {incr $cnt
     var ($end,$new) = ($lst)
    }
    else
    {if $old
      call write_event($beg,$end,$cnt,$old)
     var ($old,$beg,$cnt,$new) = ($new,$lst,0)
    }
    var $lst = $lin->[0]
   }
   else # Add to the new list until a time stamp is found
    var $new = join('%BR%',$new,$lin)
  }

  # Treat the remaining occurrences
  if $old
   call write_event($beg,$end,$cnt,$old)
 }

 # Define a macro to report the last 10 shortest redo log switches
 macro write_redo
 {var ($beg,@tbl) = @arg
  var ($cnt,$max,$nul,@tb_nul,%tb_dur,%tb_rec) = (10)
  import $TOP

  # Get the begin time
  var $beg = $beg

  loop $cur (@tbl)
  {# Determine the redo log switch time interval
   var $end = $cur
   var $dur = difftime($end,$beg)

   # Treat the switch
   if $dur
   {# Adjust duration for usual time correction
    if expr('<',$dur,0)
     incr $dur,3600

    # Keep the 10 shortest ones
    if $cnt
    {decr $cnt
     var $key = getTimeStamp($end)
     var $tb_dur{$key} = $dur
     var $tb_rec{$key} = [$end,$beg,$dur]
     var $max = max($dur,$max)
    }
    elsif expr('<',$dur,$max)
    {var ($del,$lst) = keys(%tb_dur,'ND')
     delete $tb_dur{$del},$tb_rec{$del}
     var $key = getTimeStamp($end)
     var $tb_dur{$key} = $dur
     var $tb_rec{$key} = [$end,$beg,$dur]
     var $max = max($dur,$tb_dur{$lst})
    }

    # Keep the switch time
    var $beg = $end
   }
   else
   {# Store time stamps of null duration
    if !compare('eq',$nul,$end)
    {var $nul = $end
     call push(@tb_nul,fmt_time($end))
    }
   }
  }

  # Report the shortest durations
  loop $tim (keys(%tb_dur,'NA'))
  {var $rec = $tb_rec{$tim}
   write '|',fmt_time($rec->[1]),' |',fmt_time($rec->[0]),' | ',$rec->[2],'|'
  }

  # Report null durations
  if $nul
  {if hasOutput(true)
    write $TOP
   write '---+ Times for Redo Log Switches of 0 Seconds'
   write '%COL5%',join('%BR%',@tb_nul),'%ENDCOL%'
  }
 }

 debug ' Inside DBalert module, reporting alert.log analysis results'
 write '---+!! Alert.log Analysis'
 write '---## For ',$sta{'fil'}
 write $TOC

 write '---+ Processing Totals'
 write '|*Total alert.log records(lines) read*| ',nvl($sta{'lin'},0),'|'
 write '|*Start time*|',fmt_time($beg),' |'
 write '|*End time*|',fmt_time($end),' |'
 write '|*Total instance startups encountered*| ',nvl($sta{'str'},0),'|'
 write '|*Total log switches found*| ',scalar(@swt),'|'
 write '|*Total ``Checkpoint not complete`` messages found*| ',\
       nvl($sta{'chk'},0),'|'
 write '|*Total ``Cannot allocate new log`` messages found*| ',\
       nvl($sta{'non'},0),'|'
 write '|*Total ``IPC Send timeout`` messages found*| ',\
       nvl($sta{'ipc'},0),'|'
 write '|*Total ``Reconfiguration started`` events found*| ',\
       nvl($sta{'rcb'},0),'|'
 write '|*Total ``Reconfiguration complete`` events found*| ',\
       nvl($sta{'rce'},0),'|'
 write $TOP

 if @swt
 {prefix
  {write '---+ 10 Shortest Redo Log Switch Times'
   write '|*Event Time Stamp*|* Previous Event Time Stamp*| \
           *Duration(seconds)*|'
  }
  call write_redo(@swt)
  if hasOutput(true)
   write $TOP
 }

 prefix
 {write '---+ Alter System Commands'
  write '|*Time Stamp*|*Command*|'
 }
 loop $lin (@cmd)
  write '|',$lin,'|'
 if hasOutput(true)
  write $TOP

 prefix
 {write '---+ Counts by Error'
  write '|*Error*| *Count*|*Error*| *Count*|*Error*| *Count*|'
 }
 var @tbl = keys(%err,'ND')
 while scalar(@tbl)
 {var ($key1,$key2,$key3,@tbl) = @tbl
  write '|',$key1,' | ',\
            $err{$key1},'|',\
            $key2,' | ',\
            $err{$key2},'|',\
            $key3,' | ',\
            $err{$key3},'|'
 }
 if hasOutput(true)
  write $TOP

 prefix
 {write '---+ Error Summary'
  write '|*First Occurrence*|*Last Occurrence*|*Count*|*Event*|'
 }
 call write_nodup(@err)
 if hasOutput(true)
  write $TOP

 prefix
 {write '---+ Trace Summary'
  write '|*First Occurrence*|*Last Occurrence*|*Count*|*Event*|'
 }
 call write_nodup(@trc)
 if hasOutput(true)
  write $TOP
}

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
