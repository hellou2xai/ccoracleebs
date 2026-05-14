# TLepm.ctl: Collects Enterprise Performance Management Validation Information
# $Id: TLepm.ctl,v 1.7 2015/08/21 16:04:40 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/TLepm.ctl,v 1.7 2015/08/21 16:04:40 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

BI:TLepm - Collects Enterprise Performance Management Validation Information

=head1 DESCRIPTION

This tool executes the Enterprise Performance Management validation tool and
collects the result. It requires that the Enterprise Performance Management
setup is run before using this tool.

=head1 USAGE

This tool can be used to run in the following ways:

=over 3

=item a)

Runs interactively. It requests the user to enter the required information.

 <rda> -vT epm

 <sdci> -v run epm

=item b)

Runs from the command line. The input can be given in the command line using
the following syntax:

 <rda> -vT epm:<instances>

 <sdci> -v run epm <instances>

Where C<E<lt>instancesE<gt>> is a space-separated list of instance names. Such
a list is required for 11.1.2.0 and later.

=back

=cut

section tool

if ${RDA.B_CYGWIN}
{echo "This tool is applicable on UNIX and Windows"
 return
}

echo tput('bold'),'Collecting EPM validation data ...',tput('off')

# Initialisation
var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
var $VAL = ${AS.BAT:'validate'}
var $MOD = cond(isWindows(),'f',\
                isCygwin(), 'f',\
                            'fx')

if ${GRP.EPM.D_HOME}
 var $EPM_HOME = catDir(last)
else
{echo "The EPM module setup should be run before running the tool"
 return
}
var $EPM_ROOT = ${GRP.EPM.D_INSTANCE_ROOT}

# Purge old reports
call setAbbr('BI_EPMVAL_')
call purge('C','.',15,0)

# Set the abbreviation
var $cnt = 0
loop $fil (grepDir(${OUT.C},concat(${CUR.W_PREFIX},'c\d+_validate\.txt')))
 var $cnt = max($cnt,match($fil,'BI_EPMVAL_c(\d+)_validate\.txt$'))
call setPrefix(sprintf('c%02d',incr($cnt)))

# Extract the HTML content and write to report
macro write_validate_data
{var ($fil,$lvl) = @arg
 import $TOP
 keep $TOP

 if ?testFile('f',$fil)
 {var $htm = htmlLoadFile($fil,\
    htmlFilter(htmlDisable(htmlParser(),'DR'),'B','BR','P','TD','TH'))

  # Get the title
  prefix
   write $lvl,'Validation Context'
  loop $itm (htmlFind($htm,'p'))
  {loop $blk (htmlContent($itm,'S'))
   {var $txt = trim(htmlText($blk))
    if match(encode($txt),'^([^:]+):\s+(.*)$')
     write '|*',join('* |',last),' |'
    elsif match($txt,'^(.*\son)\s+(.*)$')
     write '|*',join('* |',last),' |'
   }
  }

  # Get the diagnostic result
  if htmlFind($htm,'table class="diagnostic"')
  {var ($tbl,$hdr) = (first(last))
   loop $row (htmlContent($tbl,'T'))
   {var $cls = htmlValue($row,'class','')
    if compare('eq',$cls,'product')
    {if hasOutput(true)
      write $TOP
     var $ttl = encode(trim(htmlText($row)))
     prefix
     {write $lvl,$ttl
      write $hdr
     }
    }
    elsif compare('eq',$cls,'header')
    {var @col
     loop $col (htmlContent($row))
      call push(@col,encode(trim(htmlText($col))))
     var $hdr = concat('|*',join('*|*',@col),'*|')
    }
    elsif compare('eq',$cls,'passed')
    {var @col
     loop $col (htmlContent($row))
     {var $txt = ''
      loop $itm (htmlContent($col))
      {var $tag = htmlName($itm)
       if compare('eq',$tag,'br')
        var $txt = concat($txt,'%BR%')
       else
        var $txt = concat($txt,\
          replace(encode(trim(htmlText($itm))),'\*','&#042;',true))
      }
      call push(@col,$txt)
     }
     if @col
      write '|',join(' |',@col),' |'
    }
    elsif compare('eq',$cls,'failed')
    {var @col
     loop $col (htmlContent($row))
     {var $txt = ''
      loop $itm (htmlContent($col))
      {var $tag = htmlName($itm)
       if compare('eq',$tag,'br')
        var $txt = concat($txt,'%BR%')
       elsif compare('eq',$tag,'b')
        var $txt = concat($txt,'**',\
          replace(encode(trim(htmlText($itm))),'\*','&#042;',true),'**')
       else
        var $txt = concat($txt,\
          replace(encode(trim(htmlText($itm))),'\*','&#042;',true))
      }
      call push(@col,$txt)
     }
     if @col
     {var $col[0] = concat('%RED%',$col[0],'%ENDCOLOR%')
      write '|',join(' |',@col),' |'
     }
    }
   }
  }
  if hasOutput(true)
   write $TOP
 }
}

# Perform the validation
report validate
if ?$EPM_ROOT
{# Get the instance list on 11.1.2 and later
 if @arg
  var @INSTANCES = last
 else
 {call requestInput('TLepm')
  var @INSTANCES = @{RUN.REQUEST.W_INSTANCES}
 }

 # Collect the validation information
 loop $ins (@INSTANCES)
 {if ?testFile($MOD,catFile($EPM_ROOT,$ins,'bin',$VAL))
  {debug ' Inside EPM tool, getting EPM validate information for ',$ins
   if loadCommand(concat(lastCommand(),' 2>&1'),0,-1)
   {if !isCreated()
    {title '---+!! Enterprise Performance Management Validation Collection'
     title $TOC
    }
    title '---+ EPM Validate Report for ',$ins
    var ($fil) = grepDir(catDir($EPM_ROOT,$ins,'diagnostics','reports'),\
                         '^instance_report_\d+_\d+.html$','pt')
    call write_validate_data($fil,'---++ ')

    # Functional server-related logs
    prefix
    {write '---++ EPM Functional Server Logs'
     write '|*File*| *Size*|*Last Modified*|'
    }
    var $fil = first(grepDir(catDir($EPM_ROOT,$ins,'diagnostics','ziplogs'),\
                             '^EPM_logs_.*_\S+\.zip$','pt'))
    if ?testFile('f',$fil)
    {var $lnk = encode($fil)
     var $siz = getSize($fil)
     if $siz
     {output b,basename($fil)
      if ${CUR.O_LAST}->write_data($fil)
       var $lnk = concat('[[',${CUR.O_LAST}->get_raw(true),\
                         '][_blank][',$lnk,']]')
      end ${CUR.O_LAST}
     }
     write '|',$lnk,' | ',$siz,'|',getLastModify($fil,'<UTC>'),' |'
    }
    if hasOutput(true)
     write $TOP
   }
  }
 }
}
else
{# Collect the information for 11.1.1.x from EPM_HOME
 if ?testFile($MOD,\
             catFile(catDir($EPM_HOME,'common','validation','9.5.0.0'),$VAL))
 {var $dir = lastDir()
  debug ' Inside EPM tool, getting EPM validate information'
  if loadCommand(concat(lastCommand(),' 2>&1'),0,-1)
  {title '---+!! Enterprise Performance Management Validation Collection'
   title $TOC
   var ($fil) = grepDir(catDir($dir,'reports'),\
                        '^validation_report_\d+_\d+.html$','pt')
   call write_validate_data($fil,'---+ ')
  }
 }
}

# Render the report
if isCreated()
{call getGroupFile('D_CWD',renderFile())
 echo 'Result file: ',last
}

=head1 SEE ALSO

L<BI:DCepm|collect::BI:DCepm>,
L<RDA:DCload|collect::RDA:DCload>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
