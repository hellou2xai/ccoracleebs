# DBinfo.ctl: Collects Key Information about the Database
# $Id: DBinfo.ctl,v 1.17 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/DB/DBinfo.ctl,v 1.14 2015/08/28 09:27:16 RDA Exp $
#
# Change History
# 20240430  DXM  Remove reference to OWB module.
# 20190213  SJC  Allow get_db_version to return any version.
# 20181206  TSO  Add support for DB version 18c.
# 20140828  KRA  Extend directory detection.

=head1 NAME

DB:DBinfo - Collects Key RDBMS Information

=head1 DESCRIPTION

This module collects key RDBMS information that is required for
database-related modules.

The following macros are available:

=cut

# Make the module persistent and share macros
keep $KEEP_BLOCK,@RESET_MACROS,@SHARE_MACROS
var @RESET_MACROS = ('separator')
var @SHARE_MACROS = ('find_base','find_dest','find_diag',\
                     'get_adr_base','get_adr_home','get_alert_name',\
                     'get_db_full_version','get_db_version','get_param',\
                     'get_bdump','get_cdump','get_udump','separator')

# Initialization
keep $ADR_BASE,$ADR_HOME,$DB_FIND,$DB_FULL_VERSION,$DB_INFO,$DB_VERSION,\
     $BDUMP_DIR,$CDUMP_DIR,$UDUMP_DIR,$DIAG_DIR

if !$DB_INFO
{var $DB_INFO = true

 # Define some variables that are shared between macros
 var $ADR_BASE
 var $ADR_HOME
 var $DB_FIND
 var $DB_FULL_VERSION
 var $DB_VERSION
 var $BDUMP_DIR
 var $CDUMP_DIR
 var $UDUMP_DIR
 var $DIAG_DIR
}

# Define the separator macro
macro separator
{var $cur = $arg[0]
 import $TOC,$TOP,$TTL,@DBG,@HDR,@TTL,@TXT
 keep $cur,$sep,$TOC,$TOP,$TTL,@DBG,@HDR,@TTL,@TXT
 if $cur
 {if hasOutput(true)
   write $TOP
  var $sep = $cur
  if ?$DBG[$sep]
   debug last
  prefix
  {if !isCreated()
   {write $TTL
    write $TOC
   }
   if ?$TTL[$sep]
    write last
   if ?$TXT[$sep]
    write last,'%BR%&nbsp;'
   if ?$HDR[$sep]
    write last
  }
  return 1
 }
 if getSqlMessage()
  write last,'%BR%'
 if hasOutput(true)
  write $TOP
 if isCreated()
  toc nvl($arg[2],2),':[[',getFile(),'][rda_report][',$arg[1],']]'
}

=head2 find_base()

Gets and returns the Oracle base directory.

=cut

macro find_base
{import $ORACLE_HOME

 debug ' Inside DBinfo, finding the Oracle base directory '
 var $ORACLE_BASE = undef

 if ${SET.DB.DB.I_DB}
 {var $tgt = setCurrent(last)
  set $sql
  {SELECT '|oracle_base|' || b.ksppstvl || '|'
  " FROM x$ksppi a,x$ksppsv b
  " WHERE a.indx = b.indx
  "   AND LOWER(a.ksppinm) LIKE '%oracle_base%';
  }
  if loadSql($sql)
   var $ORACLE_BASE = get_param('\|oracle_base\|')
  call setCurrent($tgt)
 }

 if !?$ORACLE_BASE
 {if ${SET.DB.DB.D_ORACLE_BASE/P}
   var $ORACLE_BASE = last
  elsif ?testDir('d',${ENV.ORACLE_BASE})
   var $ORACLE_BASE = last
  elsif isVms()
   var $ORACLE_BASE = ${ENV.ORA_ROOT}
  else
  {var @bas = splitDir(catDir($ORACLE_HOME))
   call pop(@bas)
   while @bas
   {var $ORACLE_BASE = cleanNative([@bas, ''])
    break ?testDir('d',catDir($ORACLE_BASE,'admin'))
    call pop(@bas)
   }
  }
 }
 return $ORACLE_BASE
}

=head2 find_dest()

Determines the background, core, and user destinations. It checks
C<v$parameter> first. If the information is not available there, then
the macro looks in C<pfile> or in other known places.

For Oracle Database 11g and later, it retrieves the ADR base and home
directories.

=cut

macro find_dest
{import $ORACLE_HOME,$ORACLE_SID,$DB_FIND,$BDUMP_DIR,$CDUMP_DIR,$UDUMP_DIR,\
        $DIAG_DIR,$ADR_BASE,$ADR_HOME
 var $DB_FIND = true

 debug ' Inside DBinfo, finding dump destinations'
 set $sql
 {SELECT '|' || p.name || '|' || p.value || '|'
 " FROM v$parameter p
 " WHERE p.name LIKE '%_dump_dest'
 "    OR p.name = 'diagnostic_dest'
 "    OR p.name = 'spfile';
 "SELECT '|' || p.name || '|' || p.value || '|'
 " FROM v$diag_info p
 " WHERE p.name = 'ADR Base'
 "    OR p.name = 'ADR Home';
 "SELECT '|oracle_base|' || b.ksppstvl || '|'
 " FROM x$ksppi a,x$ksppsv b
 " WHERE a.indx = b.indx
 "   AND lower(a.ksppinm) LIKE '%oracle_base%';
 }

 if loadSql($sql)
 {var $ORACLE_BASE = get_param('\|oracle_base\|')
  var $BDUMP_DIR   = get_param('\|background_dump_dest\|')
  var $CDUMP_DIR   = get_param('\|core_dump_dest\|')
  var $UDUMP_DIR   = get_param('\|user_dump_dest\|')
  var $DIAG_DIR    = get_param('\|diagnostic_dest\|')
  var $ADR_BASE    = get_param('\|ADR Base\|')
  var $ADR_HOME    = get_param('\|ADR Home\|')
 }
 else
  var ($ORACLE_BASE,$BDUMP_DIR,$CDUMP_DIR,$UDUMP_DIR,$DIAG_DIR,\
       $ADR_BASE,$ADR_HOME) = ()

 #-----------------------------------------------------------------------------
 # If we do not have a dump directory yet, then it's because we either could
 # not read the vparameter outputfile, or we could not connect to the database.
 # Therefore, we should not have found the cdump or udump directories either.
 # Follow the same series of searches to get cdump and udump as we do for bdump.
 #-----------------------------------------------------------------------------
 if !$BDUMP_DIR
 {# Determine if pfile should be considered
  if grepLastSql('\|spfile\|','f')
   var $use = false
  elsif ${B_PFILE_LOCAL/P}
  {var $fil = ${F_PFILE_LOCATION/P}
   var $use = testFile('r',$fil)
  }
  else
   var $use = false

  # Look in pfile
  if $use
  {macro get_dump
   {var ($fil,$key) = @arg
    import $ORACLE_HOME
    var $str = trim(value(grepFile($fil,$key,'fi')),"'")
    var $str = replace($str,'\?',$ORACLE_HOME)
    var $str = replace($str,'\$ORACLE_HOME',$ORACLE_HOME)
    var $str = replace($str,'\$\{ORACLE_HOME\}',$ORACLE_HOME)
    var $str = replace($str,'%ORACLE_HOME%',$ORACLE_HOME)
    return $str
   }

   # Check in the INIT.ORA file
   debug ' Inside DBinfo, looking for dump dir in ORACLE_HOME'
   var $BDUMP_DIR = get_dump($fil,'^[^#]*background_dump_dest')
   var $CDUMP_DIR = get_dump($fil,'^[^#]*core_dump_dest')
   var $UDUMP_DIR = get_dump($fil,'^[^#]*user_dump_dest')
   var $DIAG_DIR  = get_dump($fil,'^[^#]*diagnostic_dest')

   # If any directory is still empty, check for included file and scan it
   if !and($BDUMP_DIR,$CDUMP_DIR,$UDUMP_DIR,$DIAG_DIR)
   {var $treated{$fil} = 1

    # Treat included file, ignoring comments
    debug ' Inside DBinfo, grepping for IFILE/SPFILE for dump directories'
    while value(grepFile($fil,'^[^#]*(i|sp)file','fi'))
    {var $fil = trim(last)
     var $fil = replace($fil,"'",'',true)
     var $fil = replace($fil,'\?',$ORACLE_HOME)
     var $fil = replace($fil,'\$ORACLE_HOME',$ORACLE_HOME)
     var $fil = replace($fil,'\$\{ORACLE_HOME\}',$ORACLE_HOME)
     var $fil = replace($fil,'%ORACLE_HOME%',$ORACLE_HOME)
     break exists($treated{$fil})
     if !$BDUMP_DIR
      var $BDUMP_DIR = get_dump($fil,'^[^#]*background_dump_dest')
     if !$CDUMP_DIR
      var $CDUMP_DIR = get_dump($fil,'^[^#]*core_dump_dest')
     if !$UDUMP_DIR
      var $UDUMP_DIR = get_dump($fil,'^[^#]*user_dump_dest')
     if !$DIAG_DIR
      var $DIAG_DIR  = get_dump($fil,'^[^#]*diagnostic_dest')
     var $treated{$fil} = 1
    }
   }
  }
 }

 # Determine the ORACLE_BASE
 var @dir = ()
 if !?$ORACLE_BASE
 {if ${SET.DB.DB.D_ORACLE_BASE/P}
   var $ORACLE_BASE = last
  elsif ${ENV.ORACLE_BASE}
   var $ORACLE_BASE = last
  elsif isVms()
  {var $ORACLE_BASE = ${ENV.ORA_ROOT}
   if ${ENV.ORA_DUMP}
    var @dir = (last)
   elsif ?testDir('d',catDir($ORACLE_BASE,concat('db_',$ORACLE_SID),'trace'))
    var @dir = (lastDir())
  }
  else
  {var @bas = splitDir(catDir($ORACLE_HOME))
   call pop(@bas)
   while @bas
   {var $ORACLE_BASE = cleanNative([@bas,''])
    break ?testDir('d',catDir($ORACLE_BASE,'admin'))
    call pop(@bas)
   }
  }
 }

 # If we still do not have the directories, try some well known spots
 if !$DIAG_DIR
 {debug ' Inside DBinfo, still no diagnostic dir, look in basic spots'
  if ?testDir('d',catDir($ORACLE_BASE,'diag'))
   var $DIAG_DIR = $ORACLE_BASE
 }
 var $dia = find_diag()
 if !$BDUMP_DIR
 {debug ' Inside DBinfo, still no dump dir, look in basic spots'
  if and(defined($ADR_HOME),\
         testFile('fr',catFile(catDir($ADR_HOME,'trace'),get_alert_name())))
   var $UDUMP_DIR = lastDir()
  elsif ?$dia
   var $BDUMP_DIR = catDir($dia,'trace')
  else
  {var $log = get_alert_name()
   loop $dir (\
     catDir($ORACLE_BASE,'admin',$ORACLE_SID,'bdump'),\
     catDir($ORACLE_HOME,'rdbms','log'),\
     @dir)
   {if ?testFile('r',catFile($dir,$log))
    {var $BDUMP_DIR = $dir
     break
    }
   }
  }
 }
 if !$CDUMP_DIR
 {debug ' Inside DBinfo, still no core dump dir, look in basic spots'
  if and(defined($ADR_HOME),\
         testDir('d',catDir($ADR_HOME,'cdump')))
   var $UDUMP_DIR = lastDir()
  elsif ?$dia
   var $CDUMP_DIR = catDir($dia,'cdump')
  else
  {loop $dir (\
     catDir($ORACLE_BASE,'admin',$ORACLE_SID,'cdump'),\
     catDir($ORACLE_HOME,'dbs'),\
     @dir)
   {if ?testDir('d',$dir)
    {var $CDUMP_DIR = $dir
     break
    }
   }
  }
 }
 if !$UDUMP_DIR
 {debug ' Inside DBinfo, still no user dump dir, look in basic spots'
  if and(defined($ADR_HOME),\
         testDir('d',catDir($ADR_HOME,'trace')))
   var $UDUMP_DIR = lastDir()
  elsif ?$dia
   var $UDUMP_DIR = catDir($dia,'trace')
  else
  {loop $dir (\
     catDir($ORACLE_BASE,'admin',$ORACLE_SID,'udump'),\
     catDir($ORACLE_HOME,'rdbms','log'),\
     @dir)
   {if ?testDir('d',$dir)
    {var $UDUMP_DIR = $dir
     break
    }
   }
  }
 }
 if !?$ADR_BASE
  var $ADR_BASE = $DIAG_DIR
 if !?$ADR_HOME
  var $ADR_HOME = $dia
}

=head2 find_diag()

Finds the diagnostic directories.

=cut

macro find_diag
{import $DB_FIND,$DIAG_DIR,$ORACLE_SID
 if !$DB_FIND
  call find_dest()
 if $DIAG_DIR
 {loop $dir (grepDir(catDir($DIAG_DIR,'diag'),\
                     concat('^',quote($ORACLE_SID),'$'),'ir'))
  {if and(testFile('fr',catFile($dir,'alert','log.xml')),\
          testDir('d',catDir($dir,'cdump')),\
          testDir('d',catDir($dir,'trace')))
    return $dir
  }
 }
 return undef
}

=head2 get_adr_base()

Gets and returns the ADR base directory.

=cut

macro get_adr_base
{import $DB_FIND,$ADR_BASE
 if !$DB_FIND
  call find_dest()
 return $ADR_BASE
}

=head2 get_adr_home()

Gets and returns the ADR home directory.

=cut

macro get_adr_home
{import $DB_FIND,$ADR_HOME
 if !$DB_FIND
  call find_dest()
 return $ADR_HOME
}

=head2 get_alert_name()

Gets the name of the alert log.

=cut

macro get_alert_name
{import $ORACLE_SID

 if isVms()
  return concat(${RDA.T_NODE},'_',$ORACLE_SID,'_alert.log')
 return concat('alert_',$ORACLE_SID,'.log')
}

=head2 get_bdump()

Gets and returns the background dump destination.

=cut

macro get_bdump
{import $DB_FIND,$BDUMP_DIR
 if !$DB_FIND
  call find_dest()
 return $BDUMP_DIR
}

=head2 get_cdump()

Gets and returns the core dump destination.

=cut

macro get_cdump
{import $DB_FIND,$CDUMP_DIR
 if !$DB_FIND
  call find_dest()
 return $CDUMP_DIR
}

=head2 get_udump()

Gets and returns the user dump destination.

=cut

macro get_udump
{import $DB_FIND,$UDUMP_DIR
 if !$DB_FIND
  call find_dest()
 return $UDUMP_DIR
}

=head2 get_db_full_version($flg)

Determines the database full version. When the flag is set, it forces a new
detection but does not save the results.

=cut

# Determine which version the database says we are dealing.
macro get_db_full_version
{var ($flg) = @arg

 debug ' Inside DBinfo, gathering product full version'

 # Determine the database version
 if $flg
 {set $sql
  {SELECT '|' || v.banner || '|'
  "  FROM v$version v;
  }
  call loadSql($sql)
  var ($lin) = grepLastSql('Oracle','f')
  var (undef,$ver) = match($lin,'^\|Oracle(7|8i?|9i)?\s.*?(\d+(\.\d+){4})')
  return $ver
 }

 # Determine the version from a previous detection
 import $DB_FULL_VERSION
 if !?$DB_FULL_VERSION
  call get_db_version()
 return $DB_FULL_VERSION
}

=head2 get_db_version($flg,$dft)

Determines the database version. When the flag is set, it forces a new
detection but does not save the results. A default value can be provided as a
second argument.

=cut

# Determine which version the database says we are dealing.
macro get_db_version
{var ($flg,$ver) = @arg

 debug ' Inside DBinfo, gathering product versions'

 # Determine the version from a previous detection
 if !$flg
 {import $DB_VERSION
  if ?$DB_VERSION
   return $DB_VERSION
  import $DB_FULL_VERSION
 }

 # Determine the database version
 set $sql
 {SELECT '|' || v.banner || '|'
 "  FROM v$version v;
 }
 call loadSql($sql)
 var ($lin) = grepLastSql('Oracle','f')
 # Check for versions up to 12
 var $num = check($lin,'^\|Oracle7\s',  '7',\
                       '^\|Oracle8\s',  '80',\
                       '^\|Oracle8i\s', '81',\
                       '^\|Oracle9i\s', check($lin,'\s9\.2\.','92','90'),\
                       '^\|Oracle\s',   check($lin,'\s12\.2\.','122',\
                                                   '\s12\.1\.','121',\
                                                   '\s11\.2\.','112',\
                                                   '\s11\.1\.','111',\
                                                   '\s10\.2\.','102',\
                                                   '\s10\.1\.','101',\
                                                   '-1'),\
                       $ver)

 # Check for versions above 12
 if compare('eq',$num,'-1')
 {($num) = match($lin,'^\|Oracle\s.*?(\d+)\.')
  if compare('ne',nvl($num,'-1'),'-1')
   $num = concat($num,'0')
 }
 if compare('ne',nvl($num,'-1'),'-1')
  $ver = $num

 # Save the database version for a next call
 if !$flg
  var ($DB_VERSION,undef,$DB_FULL_VERSION) = \
    ($ver,match($lin,'^\|Oracle(7|8i?|9i)?\s.*?(\d+(\.\d+){4})'))

 # Return the database version
 return $ver
}

=head2 get_param($nam[,$flg])

Extracts a parameter value from the last SQL load. Unless the flag is set, it
resolves C<ORACLE_HOME> references.

=cut

macro get_param
{import $ORACLE_HOME
 var $str = trim(field('\|',2,grepLastSql($arg[0],'f')),"'")
 if !$arg[1]
 {var $str = replace($str,'\?',$ORACLE_HOME)
  var $str = replace($str,'\$ORACLE_HOME',$ORACLE_HOME)
  var $str = replace($str,'\$\{ORACLE_HOME\}',$ORACLE_HOME)
  var $str = replace($str,'%ORACLE_HOME%',$ORACLE_HOME)
 }
 return $str
}

=head1 SEE ALSO

L<DB:DCasm|collect::DB:DCasm>,
L<DB:DCbr|collect::DB:DCbr>,
L<DB:DCdb|collect::DB:DCdb>,
L<DB:DCdba|collect::DB:DCdba>,
L<DB:DClog|collect::DB:DClog>,
L<DB:DCodm|collect::DB:DCodm>,
L<DB:DCsso|collect::DB:DCsso>,
L<DB:DCstc|collect::DB:DCstc>,
L<DB:DCstm|collect::DB:DCstm>,
L<RDA:DCconfig|collect::RDA:DCconfig>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
