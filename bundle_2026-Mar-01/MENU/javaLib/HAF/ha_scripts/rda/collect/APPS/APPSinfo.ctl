# APPSinfo.ctl: Collects ACT Information
# $Id: APPSinfo.ctl,v 1.8 2015/08/21 15:33:37 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/APPSinfo.ctl,v 1.8 2015/08/21 15:33:37 RDA Exp $
#
# Change History
# 20150821  MSC  Improve time consistency.

=head1 NAME

APPS:APPSinfo - Defines Common Oracle Applications Macros

=head1 DESCRIPTION

This persistent submodule regroups macros that are common to Oracle
Applications modules.

The following macros are available:

=cut

# Make the module persistent and share macros
keep $KEEP_BLOCK,@SHARE_MACROS
var @SHARE_MACROS = ('chk_apps_column','chk_apps_object','dsp_patches',\
                     'find_prod_dir2','fmt_version','get_apps_version',\
                     'get_class_version','get_file_version','get_prod_version',\
                     'get_profile_value','get_ssfw_version')

# Define module variables
keep $RE_ASC,$RE_HDR

var $RE_ASC = '[\040-\176]*'
var $RE_HDR = '[\040-\176]*\$Header:?\s*[\w\\\/\-\.]+\s+[\d\.]+\s[\040-\176]*'

=head2 S<chk_apps_column($own,$obj,$col)>

This macro indicates if the specified column exists in a table. It returns the
list of occurrences.

=cut

macro chk_apps_column
{var ($own,$tbl,$col) = @arg

 set $sql
 {SELECT column_name
 " FROM all_tab_columns
 " WHERE owner = ':1'
 "   AND table_name = ':2';
 "   AND column_name = ':3';
 }
 return grepSql(bindSql($sql,$own,$tbl,$col),$col,'f')
}

=head2 S<chk_apps_object($own,$obj)>

This macro indicates if an object exists in the database. It returns the list
of occurrences.

=cut

macro chk_apps_object
{var ($own,$obj) = @arg

 set $sql
 {SELECT object_name,object_type
 " FROM all_objects
 " WHERE owner = ':1'
 "   AND object_name = ':2';
 }
 return grepSql(bindSql($sql,$own,$obj),$obj,'f')
}

=head2 S<chk_apps_patch($num)>

This macro checks whether a specified patch has been applied.

=cut

macro chk_apps_patch
{var ($num) = @arg
 import %PATCH_LIST
 keep %PATCH_LIST

 return $PATCH_LIST{$num}
}

=head2 S<dsp_patches($fil,$typ,$mod,$lst)>

This macro determines whether patches from the list are applied. It displays the
latest patch, which must be the first in the list. It returns the name of the
patch.

=cut

macro dsp_patches
{var ($xml,$typ,$mod,$lst) = @arg
 import %PATCH_LIST
 keep %PATCH_LIST

 loop $itm (xmlFind($xml,concat('.../pack id="^',verbatim($lst),'$"/patchset')))
 {var $num = xmlData(xmlFind($itm,'number'))
  if $PATCH_LIST{$num}
  {var $nam = xmlData(xmlFind($itm,'name'))
   write '   * ',ucfirst($typ),' ',$nam,' (',$num,') is installed'
   return $nam
  }
 }
 write '   * No known ',$mod,' ',$typ,' is installed'
}

=head2 S<find_prod_dir2($prd,$sub,$nam)>

This macro returns the list of directories that match the
C<E<lt>subE<gt>/*/E<lt>namE<gt>> pattern in the product directory structure.

=cut

macro find_prod_dir2
{var ($prd,$sub,$nam) = @arg

 var @tbl = ()
 if getEnv(concat($prd,'_TOP'))
 {var $dir = catDir(last,$sub)
  var $tgt = concat('^',verbatim($nam),'$')
  loop $fil (grepDir($dir,'^\.+$','nv'))
  {if grepDir(catDir($dir,$fil),$tgt)
    call push(@tbl,catDir($sub,$fil,$nam))
  }
 }
 return @tbl
}

=head2 S<fmt_version($str)>

This macro formats a version number that is accepted in the security filter.

=cut

macro fmt_version
 return replace($arg[0],'\.','&#46;',true)

=head2 S<get_apps_version()>

This macro retrieves the Oracle Applications versions and product list.

=cut

macro get_apps_version
{# Get the information from the database
 set $sql
 {SELECT 'A|' || release_name
 " FROM fnd_product_groups;
 "SELECT 'C|' ||
 "       SUBSTRB((SUBSTR(a.basepath,1,INSTR(basepath,'_TOP')-1)),
 "               1,10)  || '|' ||
 "       SUBSTR(t.application_name,1,50) || '|' ||
 "       SUBSTR(a.application_id,1,10)
 " FROM fnd_application a,fnd_application_tl t,fnd_product_installations i
 " WHERE a.application_id = t.application_id
 "   AND a.application_id = i.application_id
 "   AND i.status in ('I','S')
 "   AND t.language = 'US'
 " ORDER BY 1;
 }
 if loadSql($sql)
 {import $REL107,$REL110,$REL115,$REL120,$REL121,%ALL_IDS,%ALL_NAMES

  # Determine the Apps version
  var ($rel) = grepLastSql('^A\|.*\d')
  var $rel = substr($rel,2)
  var ($REL107,$REL110,$REL115,$REL120,$REL121) = \
    (false,false,false,false,false)
  if match($rel,'10\.7')
   var $REL107 = true
  elsif match($rel,'11\.0')
   var $REL110 = true
  elsif match($rel,'^12\.0')
   var $REL120 = true
  elsif match($rel,'^12\.1')
   var $REL121 = true
  else
   var $REL115 = true

  # Extract the applications short names, names and ids
  loop $lin (grepLastSql('^C\|'))
  {var (undef,$abr,$nam,$id) = split('\|',$lin,4)
   var $ALL_NAMES{$abr} = $nam
   var $ALL_IDS{$id}    = $abr
  }
 }
 else
  write getSqlMessage()
}

=head2 S<get_class_version($fil)>

This macro gets the version of the Application Java classes.

=cut

macro get_class_version
{var ($top,@dir) = @arg
 import $FILTERED,$RE_HDR,$TTL

 var $cnt = 0
 if or(defined(testDir('d',catDir($top,'oracle','aurora'))),\
       not(defined(testFile('e',catFile($top,'apps.zip')))))
 {# apps.zip was extracted if $JAVA_TOP/oracle/aurora exists
  prefix
  {if $TTL
   {write $TTL
    var $TTL = undef
   }
   write '---++ Java Classes ',join('.',@dir)
   write '|*Class Name*|*Version*|*File Timestamp*|'
  }
  loop $fil (grepDir(catDir($top,@dir),'(^\.+$|\$|\.gif$|\.jar$|\.xml$)','drv'))
  {next !?testFile('f',$fil)
   var @sub = splitDir(dirname($fil),$top)
   call loadString($fil,$RE_HDR)
   var ($lvl,$nam,$ver) = find_strings_version()
   var $dat = getLastModify($fil,'<UTC>')
   write '|',encode(join('.',@sub,nvl($nam,'?'))),' |',\
         cond($FILTERED,fmt_version($ver),$ver),' |',$dat,' |'
  }
  if hasOutput(true)
   incr $cnt
 }
 elsif ?findCommand('unzip')
 {# Analyze the apps.zip content
  var $pgm = last
  var $dir = catDir(@dir)
  var $tmp = getTemp('ACT')
  var $zip = catCommand($top,'apps.zip')
  var @tbl = grepCommand(concat($pgm,' -l ',$zip),verbatim($dir),'i')
  var @tbl = grep(@tbl,'(^\.+$|\$|\.gif$|\.jar$|\.xml$)','iv')
  prefix
  {if $TTL
   {write $TTL
    var $TTL = undef
   }
   write '---++ Java Classes ',encode(join('.',@dir))
   write '|*Class Name*|*Version*|*File Timestamp*|'
  }
  loop $lin (@tbl)
  {var (undef,$dat,$tim,$fil) = split('\s+',trim($lin),4)
   next !$fil
   var @sub = splitDir(dirname($fil))
   call command(concat($pgm,' -c ',$zip,' ',quote($fil),' >',$tmp))
   call loadString($tmp,$RE_HDR)
   var ($lvl,$nam,$ver) = find_strings_version()
   write '|',encode(join('.',@sub,$nam)),'|',\
         cond($FILTERED,fmt_version($ver),$ver),' |',$dat,' ',$tim,'|'
   call unlinkTemp('ACT')
  }
  if hasOutput(true)
   incr $cnt
 }
 else
 {write 'No unzip (unzip must be installed and set in the path)%BR%'
  incr $cnt
 }
 return $cnt
}

=head2 S<get_file_version($fil)>

This macro gets the version of a file using the C<adident> command or by
extracting the strings from the file.

=cut

macro get_file_version
{var ($fil) = @arg
 var ($hdr,$ver) = ()
 import $ADIDENT,$RE_HDR
 keep $ADIDENT,$RE_HDR

 if ?testFile('r',$fil)
 {# Try with adident first, otherwise extract the strings
  var ($hdr) = grepCommand(concat($ADIDENT,' ',quote($fil)),' \d')
  if $hdr
   var $hdr = replace($hdr,'.*\$Header:?\s*')
  else
  {if loadString($fil,$RE_HDR)
   {loop $lin (getLines())
    {next match($lin,'(INSERT|SELECT)')
     var $lin = replace($lin,'.*\$Header:\s*')
     next match($lin,'\$Header')
     if match($lin,' (no)?sh')
     {var $hdr = $lin
      break
     }
    }
   }
  }

  # Sometimes the version is in third part; always starts with 10, 11, or 12
  var $ver = field('\s+',1,$hdr)
  if !match($ver,'^1[012]')
   var $ver = field('\s+',2,$hdr)
 }
 else
  var $ver = 'N/A'
 return $ver
}

=head2 S<get_prod_version($rec,$prd,$sub,$pat,$dat,$ext,$mlt,$nbf,@lng)>

This macro displays file versions matching the pattern under the specified
product top and subdirectory. It processes files for each language also.

=cut

macro get_prod_version
{var ($rec,$prd,$sub,$pat,$dat,$ext,$mlt,$nbf,@lng) = @arg
 import $TTL

 var $cnt = 0
 var $top = concat($prd,'_TOP')
 if getEnv($top)
 {var $dir = catDir(last,$sub)
  if and($dat,$mlt)
   var $hdr = '|*File Name*|*Built from*|*Last Modification*|'
  elsif $dat
   var $hdr = '|*File Name*|*Version*|*Last Modification*|'
  elsif $mlt
   var $hdr = '|*File Name*|*Built from*|'
  else
   var $hdr = '|*File Name*|*Version*|'
  if match($pat,'^\*(\..*)$')
   var $re = concat('\',last,'$')
  elsif compare('eq',$pat,'*')
   var $re = '.'
  else
   var $re = concat('^',replace($pat,'\*\.','.*\.',true),'$')

  prefix
  {if $TTL
   {write $TTL
    var $TTL = undef
   }
   write '---++ Files in ',encode(catDir($top,$sub)),' (',$pat,')'
   write $hdr
  }
  if $mlt
   call dsp_multiple_versions($rec,$dir,$re,$dat,$ext,$nbf)
  else
   call dsp_single_versions($rec,$dir,$re,$dat,$ext,$nbf)
  if hasOutput(true)
   incr $cnt

  loop $cod (@lng)
  {next !?testDir('dr',catDir($dir,$cod))
   prefix
   {if $TTL
    {write $TTL
     var $TTL = undef
    }
    write '---++ Files in ',encode(catDir($top,$sub,$cod)),' (',$pat,')'
    write $hdr
   }
   if $mlt
    call dsp_multiple_versions($rec,lastDir(),$re,$dat,$ext,$nbf)
   else
    call dsp_single_versions($rec,lastDir(),$re,$dat,$ext,$nbf)
   if hasOutput(true)
    incr $cnt
  }
 }
 return $cnt
}

=head2 S<get_profile_value($nam,$uid,$rid,$aid)>

This macro retrieves a profile value for the specified user, responsibility,
and application identifiers.

=cut

macro get_profile_value
{var ($nam,$uid,$rid,$aid) = @arg
 set $sql
 {SELECT NVL(u.profile_option_value,
 "       NVL(r.profile_option_value,
 "       NVL(a.profile_option_value,s.profile_option_value)))
 " FROM fnd_profile_options_vl p,
 "      fnd_profile_option_values s,
 "      fnd_profile_option_values a,
 "      fnd_profile_option_values r,
 "      fnd_profile_option_values u
 " WHERE p.profile_option_id = s.profile_option_id(+)
 "   AND p.application_id = s.application_id(+)
 "   AND p.profile_option_id = a.profile_option_id(+)
 "   AND p.application_id = a.application_id(+)
 "   AND p.profile_option_id = r.profile_option_id(+)
 "   AND p.application_id = r.application_id(+)
 "   AND p.profile_option_id = u.profile_option_id(+)
 "   AND p.application_id = u.application_id(+)
 "   AND p.profile_option_name = ':1'
 "   AND s.level_id(+) = 10001
 "   AND a.level_id(+) = 10002
 "   AND a.level_value(+) = :2
 "   AND r.level_id(+) = 10003
 "   AND r.level_value(+) = :3
 "   AND u.level_id(+) = 10004
 "   AND u.level_value(+) = :4;
 }
 var $sql = bindSql($sql,$nam,$aid,$rid,$uid)
 var ($val) = grepSql($sql,'.*')
 return $val
}

=head2 S<get_ssfw_version($ver)>

This macro gets the version of Oracle Framework.

=cut

macro get_ssfw_version
{var ($xml,$ver,$flg) = @arg
 import %PATCH_LIST
 keep %PATCH_LIST

 if isNumber($ver)
 {# First try to identify the version from the patch list
  if $flg
  {loop $itm (xmlFind($xml,'.../pack id="^FRAMEWORK_PATCH_LIST$"/patchset'))
   {if expr('==',$ver,xmlData(xmlFind($itm,'fileVersion')))
    {var $num = xmlData(xmlFind($itm,'number'))
     if $PATCH_LIST{$num}
      return xmlData(xmlFind($itm,'release'))
    }
   }
  }

  # Next, based on the specified file version number
  if expr('==',$ver,120.21)
   return '12.0.0'
  if expr('==',$ver,115.56)  # patch 3875569
   return '5.10.K'
  if expr('==',$ver,115.54)  # patch 3661164
   return '5.10.J'
  if expr('==',$ver,115.39)  # patch 3875569
   return '5.10.I'
  if expr('==',$ver,115.38)  # patch 2990280
   return '5.10.B'
  if expr('==',$ver,115.36)  # patch 2771817
   return '5.7.0H'
  if expr('==',$ver,115.27)  # patch 2278688
   return '5.6.0E'
  if expr('==',$ver,115.26)  # patch 2227335
   return '5.5.2E'
  if expr('==',$ver,115.20)  # patch 2085104
   return '5.5.2C'
  if expr('==',$ver,115.19)  # patch 2041847
   return '5.5.2B'
  if expr('==',$ver,115.11)
   return '5.5.1E'
  if expr('==',$ver,115.10)
   return '5.5.1B'
  if expr('==',$ver,115.9)
   return '5.5.1A'
  if expr('==',$ver,115.8)
   return '5.5.0E'
  if expr('==',$ver,115.7)
   return '5.5.0D'
  if expr('==',$ver,115.6)
   return '5.5.0C'
  if expr('==',$ver,115.5)
   return '5.2.3D'
  if expr('==',$ver,115.4)
   return '5.2.3C'
 }

 if match($ver,'^(\d+(\.\d*)?)')
 {var ($ver) = (last)
  if expr('>',$ver,120.21)
   return 'NEW'
 }
 return ''
}

# --- Internal Macros ---------------------------------------------------------

# Display the version information contained in one or more files. Each file can
# contain multiple lines of version information. This pertains mostly to
# compiled binaries comprised of many object files.
macro dsp_multiple_versions
{var ($rec,$dir,$pat,$dat,$ext,$nbf) = @arg
 import $FILTERED,$RE_HDR
 keep $FILTERED,$RE_HDR

 var @fil = grepDir($dir,$pat,cond($rec,'ir','ip'))
 if $nbf
  var @fil = grep(@fil,'[\-\_\.]','bv')

 loop $fil (@fil)
 {if ?testFile('f',$fil)
  {var $bas = basename($fil)
   var ($flg,$ver,%ver) = (false)

   call loadString($fil,$RE_HDR)
   loop $lin (getLines())
   {next match($lin,'(INSERT|SELECT)')
    var $lin = replace($lin,'^.*\$Header:?\s*')
    next match($lin,'\$Header')
    var @tbl = split('\s+',trim($lin))
    if match($tbl[1],'^\d+(\.\d+)*$')
    {var $ver{$tbl[0]} = \
       concat(':&nbsp;',cond($FILTERED,fmt_version($tbl[1]),$tbl[1]),'%BR%')
     var $flg = true
    }
   }
   if $flg
    var $ver = substr(join('',%ver),0,-4)
   if $dat
    write '|',encode($bas),'|%COL5%',$ver,'%ENDCOL%|',\
          getLastModify($fil,'<UTC>'),'|'
   else
    write '|',encode($bas),'|%COL5%',$ver,'%ENDCOL%|'
  }
 }
}

# Display the version information contained in one or more files. Each file
# contains a single line of version information ($Header). This pertains mostly
# to NON PRO*C files like forms, reports, scripts, etc.
macro dsp_single_versions
{var ($rec,$dir,$pat,$dat,$ext,$nbf) = @arg
 import $ADIDENT,$FILTERED,$RE_ASC
 keep $ADIDENT,$FILTERED,$RE_ASC

 var @fil = grepDir($dir,$pat,cond($rec,'inr','inp'))
 if $nbf
  var @fil = grep(@fil,'[\-\_\.]','bv')

 if and($ADIDENT,isUnix())
 {loop $fil (@fil)
  {var $bas = basename($fil)
   if $ext
    var $ref = concat(field('\.',0,$bas),'\.',$ext,':?\s+')
   else
    var $ref = concat('\b',verbatim($bas),':?\s+')
   var ($lvl,$nam,$ver) = find_adident_version($fil,$ref)
   if $dat
    write '|',encode($bas),'|',\
          $nam,': ',cond($FILTERED,fmt_version($ver),$ver),' ',$lvl,'|',\
          getLastModify($fil,'<UTC>'),'|'
   else
    write '|',encode($bas),'|',\
          $nam,': ',cond($FILTERED,fmt_version($ver),$ver),' ',$lvl,'|'
  }
 }
 else
 {loop $fil (@fil)
  {var $bas = basename($fil)
   if $ext
    call loadString($fil,concat(join('\.',field('\.',0,$bas),$ext),$RE_ASC))
   else
    call loadString($fil,concat(verbatim($bas),$RE_ASC))
   var ($lvl,$nam,$ver) = find_strings_version()
   if $dat
    write '|',encode($bas),'|',\
          $nam,': ',cond($FILTERED,fmt_version($ver),$ver),' ',$lvl,'|',\
          getLastModify($fil,'<UTC>'),'|'
   else
    write '|',encode($bas),'|',\
          $nam,': ',cond($FILTERED,fmt_version($ver),$ver),' ',$lvl,'|'
  }
 }
}

# Find the file version from adident output
macro find_adident_version
{var ($fil,$pat) = @arg
 import $ADIDENT
 keep $ADIDENT

 loop $lin (grepCommand(concat($ADIDENT,' ',quote($fil),' 2>&1'),$pat))
 {var $lin = replace($lin,'^.*\$Header:?\s*')
  next match($lin,'\$Header')
  var ($lvl) = match($lin,'\slevel:(\S+)\s')
  var @tbl = split(':?\s+',trim($lin))
  if match($tbl[1],'^\d+(\.\d+)*$')
   return ($lvl,@tbl)
 }
 return ()
}

# Find the file version from strings that have been extracted from the file
macro find_strings_version
{loop $lin (getLines())
 {next match($lin,'(INSERT|SELECT)')
  var $lin = replace($lin,'^.*\$Header:?\s*')
  next match($lin,'\$Header')
  var ($lvl) = match($lin,'\slevel:(\S+)\s')
  var @tbl = split('\s+',trim($lin))
  if match($tbl[1],'^\d+(\.\d+)*$')
   return ($lvl,@tbl)
 }
 return ()
}

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
