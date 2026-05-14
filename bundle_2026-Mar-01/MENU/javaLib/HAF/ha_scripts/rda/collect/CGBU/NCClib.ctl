# NCClib.ctl: Defines Common Macros for Network Charging and Control
# $Id: NCClib.ctl,v 1.7 2014/10/31 08:01:45 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/NCClib.ctl,v 1.7 2014/10/31 08:01:45 RDA Exp $
#
# Change History
# 20141030  KRA  Remove 'sort_all_files' macro.

=head1 NAME

CGBU:NCClib - Defines Common Macros for Network Charging and Control

=head1 DESCRIPTION

This persistent submodule regroups macros that are common to Network Charging
and Control module.

The following macros are available:

=cut

# Make the module persistent and share macros
keep $KEEP_BLOCK,@SHARE_MACROS
var @SHARE_MACROS = ('get_chksum','get_files','get_scripts','get_sum',\
                     'stat_tree')

=head2 S<get_chksum($dir,$lvl,$pre)>

This macro gathers the check sum information for the specified directory.

=cut

macro get_chksum
{var ($dir,$lvl,$pre) = @arg
 import $TOP
 keep $TOP

 report chksum
 prefix
 {write "---+ '",$pre,"' Check Sum Information"
  write '| *Checksum*| *Size*|*Filename*|'
 }
 loop $fil (grepDir($dir,'^\.+$','npv'))
 {if ?testFile('fr',$fil)
  {var ($val) = command(concat('cksum ',quote($fil)))
   if ?$val
   {var ($chk,$siz,$pth) = split('\s+',$val,3)
    write '| ',$chk,'| ',$siz,'|',$pth,' |'
   }
  }
 }
 if isCreated(true)
 {write $TOP
  toc $lvl,':[[',getFile(),'][rda_report][Check Sum Information]]'
 }
}

=head2 S<get_files($dir,...)>

This macro gathers the plain files in the specified directories recursively
(depth 10) and of size less than 2 MB.

=cut

macro get_files
{var @fil = ()
 loop $dir (@arg)
 {loop $fil (grepDir($dir,'^\.+$','drv',10))
  {if and(testFile('fr',$fil),expr('<=',getSize($fil),2097152))
    call push(@fil,$fil)
  }
 }
 return @fil
}

=head2 S<get_scripts($dir,$flg)>

This macro gathers the related script files for the specified directory.

=cut

macro get_scripts
{var ($dir,$flg) = @arg

 var @fil = ()
 loop $fil (grepDir($dir,'^\.+$','npv'))
 {next !?testFile('fr',$fil)
  var ($lin) = command(concat('file ',quote($fil)))
  var (undef,$typ) = split('\:\s+',$lin,2)
  if $flg
  {if match($typ,'executable\s.*?\sscript|commands text')
    call push(@fil,$fil)
  }
  elsif or(match($fil,'\.(sh|awk|pl|sql)$'),\
           match($typ,'executable\s.*?\sscript|commands text'))
   call push(@fil,$fil)
 }
 return @fil
}

=head2 S<get_sum($dir,$lvl,$pre)>

This macro gathers the sum information for the specified directory.

=cut

macro get_sum
{var ($dir,$lvl,$pre) = @arg
 import $TOP
 keep $TOP

 report sum
 prefix
 {write "---+!! '",$pre,"' Sum Information"
  write '%TOC3-2%'
 }
 loop $fil (grepDir($dir,'^\.+$','npv'))
 {if ?testFile('fr',$fil)
  {write '---++ ',encode(basename($fil))
   call statFile('b',$fil)
   write '---++++!! sum: (sum size filename)'
   call writeCommand(concat('sum ',quote($fil)))
   write $TOP
  }
 }
 if isCreated(true)
  toc $lvl,':[[',getFile(),'][rda_report][Sum Information]]'
}

=head2 S<stat_tree($dir)>

This macro lists the content of the specified directory recursively.

=cut

macro stat_tree
{var ($dir) = @arg
 import $TOP
 keep $TOP

 if expr('>',statDir('n',$dir),0)
  write $TOP

 loop $pth (findDir($dir,'^\.+$','npv'))
 {next ?testFile('l',$pth)
  call stat_tree($pth)
 }
}

=head1 SEE ALSO

L<CGBU:DCncc|collect::CGBU:DCncc>,
L<CGBU:MCncc|collect::CGBU:MCncc>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
