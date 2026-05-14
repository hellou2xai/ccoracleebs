# ASMinit.ctl: Determine the ASM Home Location and System Identifier
# $Id: ASMinit.ctl,v 1.6 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/DB/ASMinit.ctl,v 1.5 2013/10/30 07:18:23 RDA Exp $
#
# Change History
# 20200924  PCW  Improve detection of ASM home.
# 20130606  MSC  Rename cluster variable.

=head1 NAME

DB:ASMinit - Determine the ASM Home Location and System Identifier

=head1 DESCRIPTION

This module tries to determine the ASM home directory and the ASM system
identifier in a cluster, using the following commands:

=over 3

=item o C<srvctl config asm>

=item o C<srvctl config asm -n E<lt>nodenameE<gt>>

=back

When the system identifier cannot be determined using those commands, it uses
F<crs_stat> to get it.

=cut

# Make the module persistent
keep $KEEP_BLOCK

# Define the macro to determine the ASM home and SID
macro get_asm
{var ($crs,$hom) = (${SET.DB.CRS.D_CRS_HOME})

 if !?$crs
  run DB:CRSinit(\$crs)
 if ?testDir('d',$crs)
 {# Try to determine the ASM home
  var $cmd = catCommand($crs = last,'bin','srvctl')
  if grepCommand(concat($cmd,' config asm'),'^(PRK[A-Z]\-\d{4}|\s*\[)','v')
  {loop $lin (last)
   {next !match($lin,'^ASM home:\s+(.*?)\s*$')
    var ($val) = last
    if compare('eq',$val,'<CRS home>')
    {var $hom = $crs
     break
    }
    elsif ?testDir('d',catDir($val))
    {var $hom = lastDir()
     break
    }
   }
  }
  elsif grepCommand(concat($cmd,' config asm -n ',verbatim(${RDA.T_NODE})),\
                    '^(PRK[A-Z]\-\d{4}|\s*\[)','fv')
  {var ($sid,$dir) = split('\s+',last,2)
   if ?testDir('d',catDir($dir))
    return [lastDir(),$sid]
  }

  # Try to resolve the ASM SID
  var $pat = concat('\.',verbatim(${RDA.T_NODE}),'\.([^\.]+)\.asm$')
  loop $lin (grepCommand(catCommand($crs,'bin','crs_stat'),'\.asm$'))
  {if match($lin,$pat)
    return [$hom,concat('+',last)]
  }
 }

 # Give up
 return [$hom,'+ASM']
}

# Determine the ASM home and SID on first call
var ($asm,\$hom,\$sid) = (${REG.ASM:get_asm()},@arg)
if ?$asm->[0]
 var $hom = last
if ?$asm->[1]
 var $sid = last

=head1 SEE ALSO

L<DB:CRSinit|collect::DB:CRSinit>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
