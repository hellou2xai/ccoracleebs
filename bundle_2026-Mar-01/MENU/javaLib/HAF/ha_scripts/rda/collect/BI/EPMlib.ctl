# EPMlib.ctl: Defines Common Macros for Enterprise Performance Management
# $Id: EPMlib.ctl,v 1.11 2014/10/24 12:00:27 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/BI/EPMlib.ctl,v 1.11 2014/10/24 12:00:27 RDA Exp $
#
# Change History
# 20141022  JGS  Enhance temporary file removal.

=head1 NAME

EPMlib - Defines Common Macros for Enterprise Performance Management

=head1 DESCRIPTION

This persistent submodule regroups macros that are common to several Oracle
Enterprise Performance Management System related-modules.

The following macros are available:

=cut

use Buffer

# Make the module persistent and share macros
keep $KEEP_BLOCK,@SHARE_MACROS
var @SHARE_MACROS = ('collect_cssconfig','create_epm_script',\
                     'extract_db_connections','filter_db_connections',\
                     'get_db_connections','get_epm_version',\
                     'parse_db_connections')

=head2 S<collect_cssconfig($lvl,$dir,$pwd)>

This macro exports the CSS configuration using the F<epmsys_registry.sh> or
F<epmsys_registry.sh> script.

=cut

macro collect_cssconfig
{var ($lvl,$dir,$pwd) = @arg
 var $MOD = cond(isWindows(),'f',\
                 isCygwin(), 'f',\
                             'fx')
 if ?testFile($MOD,catFile($dir,${AS.BAT:'epmsys_registry'}))
 {var ($cmd,$tmp) = (lastCommand(),'EPMSYS_REG')
  if ?create_epm_script($tmp,lastFile(),$pwd)
   var $cmd = quote(last)
  else
   var $tmp = undef
  if ?testFile($MOD,catFile($dir,${AS.BAT:'setEnv'}))
   call sourceContext(getNativePath(lastFile()))
  if grepCommand(concat($cmd,' view SYSTEM9'),'FOUNDATION_SERVICES_PRODUCT','f')
  {var $box = catDir(${CFG.D_CWD},cleanBox())
   var $exe = concat($cmd,' view \
     SYSTEM9/FOUNDATION_SERVICES_PRODUCT/SHARED_SERVICES_PRODUCT/@CSSConfig')
   debug ' Inside EPM module, gathering CSS Configuration'
   report cssconfig
   prefix
   {write '---+ CSS Configuration'
    write '---## Using: ',encode($exe)
   }
   if or(isWindows(),isCygwin())
   {var $job = createTemp('CSS','.bat',true)
    call writeTemp('CSS','@echo off')
    call writeTemp('CSS','cd /d "',getNativePath($box),'"')
    call writeTemp('CSS',$exe)
    call closeTemp('CSS')
    call command($job)
    call unlinkTemp('CSS')
   }
   elsif isUnix()
   {var $job = createTemp('CSS','.sh',true)
    call writeTemp('CSS','cd "',$box,'"')
    call writeTemp('CSS',$exe)
    call closeTemp('CSS')
    call command($job)
    call unlinkTemp('CSS')
   }
   loop $fil (grepDir($box,'CSSConfig','p'))
    call writeFile($fil)
   call cleanBox()
   if isCreated(true)
    toc $lvl,':[[',getFile(),'][rda_report][CSS Configuration]]'
  }

  # Unlink the temporary file
  if ?$tmp
   call unlinkTemp($tmp)
 }
}

=head2 S<create_epm_script($tmp,$fil[,$pwd])>

This macro generates a new script to provide the required password.

=cut

macro create_epm_script
{var ($tmp,$fil,$pwd) = @arg

 if ?$pwd
  var $pwd = catFile(${CFG.D_CWD},$pwd)
 if !createBuffer('EPM','R',$fil)
  return undef
 var $job = createTemp($tmp,\
   cond(isUnix(),'.sh',isWindows(),'.bat',isCygwin(),'.bat'),true)
 while getLine('EPM')
 {var $lin = chomp(last)
  if match($lin,'^(set\s+)?SCRIPT_DIR=')
   call writeTemp($tmp,replace($lin,'SCRIPT_DIR=.*$',\
     concat('SCRIPT_DIR=',\
            cond(isUnix(),quote(dirname($fil)),\
                          concat(getShortPath(dirname($fil)),'\')))))
  else
   call writeTemp($tmp,cond($pwd,replace($lin,'\s+\-DEPM_ORACLE_HOME=',\
     concat(' -DpasswordFile=',cond(isUnix(),quote($pwd),getShortPath($pwd)),\
            ' -DEPM_ORACLE_HOME=')),\
                                 $lin))
 }
 call closeTemp($tmp)
 call deleteBuffer('EPM')
 return catFile(${CFG.D_CWD},$job)
}

=head2 S<extract_db_connections($fil[,$pwd])>

This macro runs the F<epmsys_registry> Hyperion script to generate a list of
available Hyperion JDBC database connections for the system. It parses the
connection data and returns the results as a hash of types with its connection
information. Subsequent calls use the initial results.

=cut

macro extract_db_connections
{var ($fil,$pwd) = @arg

 if ${RUN.BI.T_DB_CON/E}
  return ${RUN.BI.T_DB_CON}

 # Generate connections list when not yet defined
 var $con = {}
 if ?create_epm_script('EPMREQ',$fil,$pwd)
 {var $cmd = last
  var $out = createTemp('EPMOUT')
  call command(concat(quote($cmd),' view DATABASE_CONN >',quote($out)),2)

  # Parse all available connections
  if ?$buf = new('Buffer','R',$out)
  {var $con = parse_db_connections($buf)
   call $buf->close
  }
  call unlinkTemp('EPMOUT')
  call unlinkTemp('EPMREQ')
 }
 return ${RUN.BI.T_DB_CON} = $con
}

=head2 S<filter_db_connections($hsh,@typ)>

This macro returns the connections of the requested types.

=cut

macro filter_db_connections
{var ($con,@typ) = @arg

 var %con = ()
 loop $typ (@typ)
 {if exists($con->{$typ})
   var $con{$con->{$typ,'cmp'}} = $con->{$typ}
 }
 return values(%con,'IA')
}

=head2 S<get_db_connections($hsh)>

This macro returns all the connections.

=cut

macro get_db_connections
{var ($con) = @arg

 var %con = ()
 loop $typ (keys($con))
  var $con{$con->{$typ,'cmp'}} = $con->{$typ}
 return values(%con,'IA')
}

=head2 S<get_epm_version($hom)>

This macro gets the Enterprise Performance Management System version.

=cut

macro get_epm_version
{var ($hom) = @arg
 if ?testFile('fr',catFile($hom,'.oracle.products'))
 {var $obj = xmlLoadFile(lastFile(),xmlDisable(xmlParser(),'BCDEPR'))
  loop $xml (xmlFind($obj,'softwareRegistry/hyperionHome'))
  {var $pth = catDir(xmlData(xmlFind($xml,'installLocation')))
   if or(isCygwin(),isWindows())
    var $pth = getNativePath($pth)
   next !sameDir($hom,$pth)
   if xmlFind($xml,'products/installableItem \
                    uid="^productCommonComponents$"/version')
    return xmlData(last)
  }
 }
 return ''
}

=head2 S<parse_db_connections($buf[,$lim])>

This macro parses and returns the available Hyperion JDBC database connections
for the system, as a reference to a hash structure. When a type array is
provided as an extra argument, it limits the results to the specified types.

=cut

macro parse_db_connections
{var ($buf,$lim) = @arg

 var ($con,$rec) = ({},{})
 var %key = (dbJdbcUrl            => 'url',\
             dbJDBCDriverProperty => 'drv',\
             dbUserName           => 'usr')
 var $pat = concat('^(COMPONENT\s-\s*\d+|\
                      \s+(',join('|',keys(%key)),')\s=|\
                      \s+TYPE\s-\s\s\w+)')
 while $buf->grep($pat,'fr')
 {if match($lin = first,'^COMPONENT\s-\s*(\d+)\s*$')  # New connection
   var $rec = {cmp => first}
  elsif match($lin,concat('^\s+(\w+)\s=\s?(\S+)'))
   var $rec->{$key{first}} = second
  elsif match($lin,'^\s+TYPE\s-\s\s(\w+)')
  {var $typ = first
   next match($typ,'^(HOST|DB_TYPE)$')
   if ?$lim
    next !grep($lim,verbatim($typ,'e')) # Filter by the requested types
   if and(exists($rec->{'cmp'}),\
          exists($rec->{'drv'}),\
          exists($rec->{'url'}),\
          exists($rec->{'usr'}))
   {call push($rec->{'typ'},$typ)
    var $con->{$typ} = $rec
   }
  }
 }

 # Return the connections
 return $con
}

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
