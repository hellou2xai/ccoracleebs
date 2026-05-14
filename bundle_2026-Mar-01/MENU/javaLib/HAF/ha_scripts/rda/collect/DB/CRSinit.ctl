# CRSinit.ctl: Determine the CRS Home Location
# $Id: CRSinit.ctl,v 1.4 2013/10/30 07:18:23 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/DB/CRSinit.ctl,v 1.4 2013/10/30 07:18:23 RDA Exp $
#
# Change History
# 20130422  MSC  Improve the validation.

=head1 NAME

DB:CRSinit - Determine the CRS Home Location

=head1 DESCRIPTION

This module tries to determine the Cluster Ready Services (CRS) home directory.

It first tries to get the CRS home from the C<GRID_HOME> or C<ORA_CRS_HOME>
environment variables, whichever is present.

=head2 For UNIX

When not available from the environment, it extracts the CRS home from the
either of the following:

=over 3

=item o The value assigned to F<crs_home> in F</etc/oracle/olr.loc> file

=item o The output of the F<$ORACLE_HOME/srvm/admin/getcrshome> command

=item o The value assigned to F<ORA_CRS_HOME> in F<$ORACLE_HOME/bin/crsctl>

=item o The value assigned to F<ORA_CRS_HOME> in the F<init.ohasd> init file

=item o The value assigned to F<ORA_CRS_HOME> in the F<init.cssd> init file

=item o The path of the F<ocssd.bin> daemon

=back

=head2 For Windows

When not available from the environment, it extracts the CRS home from the
either of the following:

=over 3

=item o The output of the F<%ORACLE_HOME%\srvm\admin\getcrshome> command

=item o The C<OracleCRService> definition in the Windows registry

=back

=cut

# Make the module persistent
keep $KEEP_BLOCK

# Define the macro to determine the CRS home
macro get_crs_home
{import $ORACLE_HOME

 # Use the environment variables when set
 loop $key ('GRID_HOME','ORA_CRS_HOME')
 {if and(defined($dir = getEnv($key)),testDir('d',catDir($dir)))
   return lastDir()
 }

 if ${RDA.B_UNIX}
 {# Try olr.loc
  if grepFile('/etc/oracle/olr.loc','^\s*crs_home=','f')
   return value(last)

  # Try getcrshome
  if ?testFile('fx',catFile($ORACLE_HOME,'srvm','admin','getcrshome'))
  {var ($dir) = command(concat(lastTestCommand(),' 2>/dev/null'))
   if ?testDir('d',$dir)
    return $dir
  }

  # Try to extract it from crsctl
  if grepFile(catFile($ORACLE_HOME,'bin','crsctl'),'^ORA_CRS_HOME=','f')
  {var $dir = value(last)
   if ?testDir('d',$dir)
    return $dir
  }

  # Try to locate it from the start script
  var $PS_ARG
  if ${OS.aix}
  {if grepFile('/etc/init.ohasd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   if grepFile('/etc/init.cssd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   run OS:OSaix('PS')
  }
  elsif ${OS.dec_osf}
  {if grepFile('/sbin/init.d/init.ohasd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   if grepFile('/sbin/init.d/init.cssd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   run OS:OSosf('PS')
  }
  elsif ${OS.hpux}
  {if grepFile('/sbin/init.d/init.ohasd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   if grepFile('/sbin/init.d/init.cssd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   run OS:OShpux('PS')
  }
  elsif ${OS.linux}
  {if grepFile('/etc/init.d/init.ohasd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   if grepFile('/etc/init.d/init.cssd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   run OS:OSlinux('PS')
  }
  elsif ${OS.solaris}
  {if grepFile('/etc/init.d/init.ohasd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   if grepFile('/etc/init.d/init.cssd','^\s*ORA_CRS_HOME=','f')
    return value(last)
   run OS:OSsunos('PS')
  }

  # Try to locate it from the daemon path
  if $PS_ARG
  {var $cmd = replace($PS_ARG,'comm\,','')
   var ($lin) = grepCommand($cmd,'\/bin\/ocssd\.bin','f')
   if match($lin,'^(.*)\/bin\/ocssd\.bin')
    return first(last)
  }
 }
 elsif or(${RDA.B_WINDOWS},${RDA.B_CYGWIN})
 {# Try getcrshome
  if ?testFile('f',catFile($ORACLE_HOME,'srvm','admin','getcrshome.exe'))
  {var ($dir) = command(lastTestCommand())
   if ?testDir('d',$dir)
    return catDir($dir)
  }

  # Try to locate from the Windows service
  var $key = 'HKLM\SYSTEM\CurrentControlSet\Services\OracleCRService'
  if match(getRegValue($key,'ImagePath'),'^(.*)\s+service\s*$',true)
  {var @tbl = splitDir(dirname(catFile(trim(last))))
   var $tbl[-1] = curDir()
   return catDir(@tbl)
  }
 }

 # Give up
 return undef
}

# Determine the CRS home on first call
var (\$crs) = @arg
var $crs = ${REG.D_CRS_HOME:get_crs_home()}

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
