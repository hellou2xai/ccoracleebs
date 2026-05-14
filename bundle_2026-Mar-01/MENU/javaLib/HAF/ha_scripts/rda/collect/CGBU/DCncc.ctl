# DCncc.ctl:491:Collects Network Charging and Control Information
# $Id: DCncc.ctl,v 1.7 2015/11/18 15:09:08 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCncc.ctl,v 1.7 2015/11/18 15:09:08 RDA Exp $
#
# Change History
# 20151116  KRA  Fix 'Routing Scheme Information' report.

=head1 NAME

CGBU:DCncc - Collects Network Charging and Control Information

=head1 DESCRIPTION

This module collects information related to Network Charging and Control.

The following reports can be generated and are regrouped under C<Network
Charging and Control>:

=head1 REPORTS

=cut

use Mrc

echo tput('bold'),'Processing CGBU.NCC module ...',tput('off')

# Initialization
var $HOME = ${D_HOME:'/IN/service_packages'}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
toc '1:Network Charging and Control'

# Set the NCC symbols
call setSymbol('$NCC_BASE','/IN')
call setSymbol('$NCC_HOME',$HOME)

=head2 abbr - Abbreviations

Displays the RDA abbreviations defined for the Network Charging and Control
home collection.

=cut

debug ' Inside NCC module, collecting defined abbreviations'
report abbr
prefix
{write '---+ Network Charging and Control Home Abbreviations'
 write '|*Abbreviation*|*Location*|'
}
var %hsh = getSymbols()
loop $key (keys(%hsh))
 write '|',$key,' |',$hsh{$key},' |'
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Abbreviations]]'

=head2 dbinfo - Database Information

Collects Oracle Database information.

=cut

if ${I_DB}
{# Set the database context
 call setSqlTarget(last)

 # Load the common macros
 run DB:DBinfo()

 # Test the database connection and collect information
 debug ' Inside NCC module, getting database information'
 report dbinfo

 if testSql()
 {echo ''
  echo tput('bold'),'The database is not accessible.',tput('off')
  if getSqlMessage()
  {echo last
   write '---+ Database Information'
   write 'Database not accessible (',getSqlMessage(),')'
   toc '2:[[',getFile(),'][rda_report][Database Information]]'
  }
  echo ''
 }
 else
 {var $TTL = '---+!! Database Information'
  var @TTL = ('',\
              '---+ Replication Node Numbers',\
              '---+ Replication Node Target',\
              '---+ CCS Domain Information')
  var @HDR = (\
    '',\
    '| *Node Number*|*IP Address Primary*|*IP Address Secondary*|\
       *Description*|',\
    '| *Node Number*|*Group Name*|',\
    '|*Domain ID*|*Domain Name*|*Number Of Accounts*|*Connection Retry*|\
      *Authentication Type*|*Minimum Queue Messages*|*Maximum Queue Messages*|\
      *Message Timeout*|*Charging*|*Subscriber*|*Voucher*|*Wallet*|*Tracking*|\
      *Allow Adaption*|*Enable Guidance*|*Guidance Cache Size*|*Node Number*|\
      *Node Name*|*Communication Address*|*Internal Port*|*Client Port*|\
      *Minimum Weight*|*Maximum Weight*|*Stable Weight*|*Unstable Weight*|\
      *Type*|*Protocol*|*Voucher Sequence*|')
  set $sql
  {SELECT '| ' ||
  "       node_number || '|' ||
  "       ip_addr_prim || ' |' ||
  "       ip_addr_sec || ' |' ||
  "       description || ' |'
  " FROM rep_cnf_node
  " ORDER BY node_number;
  "PROMPT ___Macro_separator(2)___
  "SELECT '| ' ||
  "       node_number || '|' ||
  "       group_name || ' |'
  " FROM rep_cnf_target
  " ORDER BY node_number,group_name;
  "PROMPT ___Macro_separator(3)___
  "SELECT '|' ||
  "       cd.domain_id || ' |' ||
  "       cd.name || ' |' ||
  "       cd.num_accounts || ' |' ||
  "       cd.connection_retry || ' |' ||
  "       cd.auth_type || ' |' ||
  "       cd.minqueuemessages || ' |' ||
  "       cd.maxqueuemessages || ' |' ||
  "       cd.message_timeout || ' |' ||
  "       cd.charging || ' |' ||
  "       cd.subscriber || ' |' ||
  "       cd.voucher || ' |' ||
  "       cd.wallet || ' |' ||
  "       cd.tracking || ' |' ||
  "       cd.allow_adaption || ' |' ||
  "       cd.enable_guidance || ' |' ||
  "       cd.guidance_cache_size || ' |' ||
  "       cdn.node_number || ' |' ||
  "       cdn.name || ' |' ||
  "       cdn.comm_address || ' |' ||
  "       cdn.internal_port || ' |' ||
  "       cdn.client_port || ' |' ||
  "       cdn.minweight || ' |' ||
  "       cdn.maxweight || ' |' ||
  "       cdn.stableweight || ' |' ||
  "       cdn.unstableweight || ' |' ||
  "       cdt.type || ' |' ||
  "       cdt.protocol || ' |' ||
  "       cdt.voucher_sequence || ' |'
  " FROM ccs_domain_nodes cdn,ccs_domain cd,ccs_domain_type cdt
  " WHERE cd.domain_type_id = cdt.domain_type_id
  "   AND cd.domain_id = cdn.domain_id;
  }
  call separator(1)
  call writeSql($sql)
  call separator(0,'Database Information')
 }

=head2 mmx_routing_scheme - Messaging Manager Schema Information

Collects messaging manager schema information.

=cut

 debug ' Inside NCC module, getting messaging manager schema information'
 call setSqlTarget(\
   addTarget('SQ_MMX',getSqlTarget(),usr=>'mmx_admin',dba=>false))
 var ($typ,$sid,$usr) = getSqlInfo()
 call setPassword($typ,$sid,$usr,$pwd = 'mmx_admin')
 if !testSql()
 {set $sql
  {SELECT '| ' ||
  "       id || '|' ||
  "       name || ' |'
  " FROM mmx_routing_scheme;
  }
  if loadSql($sql)
  {report mmx_routing_scheme
   prefix
   {write '---+ Messaging Manager Schema Information'
    write '| *ID*|*Name*|'
   }
   call writeLastSql()
   if isCreated(true)
   {write $TOP
    toc '2:[[',getFile(),'][rda_report][Messaging Manager Schema Information]]'
   }

=head3 mmxid - Routing Scheme Information

Collects routing scheme information.

=cut

   debug ' Inside NCC module, getting routing scheme information \
           (can take time)'
   var $key = ${CUR.W_SHLIB}
   loop $qid (grepLastSql('^\|\s(\d+)\|','1'))
   {var $out = catFile(${CFG.D_CWD},newTemp('MMX'))
    if loadCommand({\
      cmd => join(" ",catCommand($HOME,'XMS','bin','mmxSchemaTool'),\
                      '-i',$qid,'-f',quote($out),'-u mmx_admin -p mmx_admin'),\
      env => {$key => join(${RDA.T_SEPARATOR},\
                testDir('d',catDir($HOME,'SMS','lib')),@{SYS.${VAR.key}})}})
    {if ?testFile('s',$out)
     {report concat('mmxid_',$qid)
      write '---+ Routing Scheme Information (ID ',$qid,')'
      call writeFile($out,['C',concat('mmxSchemaTool -i ',$qid)])
      write $TOP
      toc '3:[[',getFile(),"][rda_report]['",$qid,"' Routing Scheme ID]]"
     }
    }
    call unlinkTemp('MMX')
   }
  }
 }
 call setSqlTarget()
}

=head2 Multi-run Collections

Collects Network Charging and Control-related information from both current
user and C<root> user.

=cut

collect CGBU:MCncc|NCC()

=head1 SEE ALSO

L<CGBU:MCncc|collect::CGBU:MCncc>,
L<CGBU:NCClib|collect::CGBU:NCClib>,
L<DB:DBinfo|collect::DB:DBinfo>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
