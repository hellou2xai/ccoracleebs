# DCbrm.ctl:380:Collects Billing and Revenue Management Information
# $Id: DCbrm.ctl,v 1.4 2014/03/12 11:17:39 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCbrm.ctl,v 1.4 2014/03/12 11:17:39 RDA Exp $
#
# Change History
# 20140312  KRA  Improve description.

=head1 NAME

CGBU:DCbrm - Collects Billing and Revenue Management Information

=head1 DESCRIPTION

This module collects Oracle Communications Billing and Revenue
Management-related information through a release-specific submodule. It
detects the Oracle Communications Billing and Revenue Management release
automatically.

=cut

echo tput('bold'),'Processing CGBU.BRM module ...',tput('off')

# Determine the product release
macro get_release
{if ?$dir = testFile('d',${ENV.IFW_HOME})
 {if grepCommand(concat(catCommand($dir,'bin','ifw'),' -v 2>&1'),\
                 'Pipeline\s+Server\s+\/\s+Version\s+(\d+(\.\d+){1,})','f1')
   return first
  var @lin = command(concat(catCommand($dir,'bin','pinrev'),' 2>&1'))
  while @lin
  {if match(shift(@lin),'^PRODUCT_NAME="?(Infranet|Portal)_Base')
   {if match(shift(@lin),'^VERSION="?(\d+(\.\d+){1,})')
     return first
   }
  }
 }
 loop $prf (@{SET.K_PRF})
 {if match($prf,'^CGBU\.SupportInformer(7)(\d+)\b')
   return join('.',first,second)
 }
 loop $pth (${ENV.IFW_HOME},${ENV.INT_HOME},${ENV.PIN_HOME})
 {if match($pth,'\/(brm|portal)\/?(\d+(\.\d+){1,})($|\/)')
   return second
 }
 return undef
}
var $ver = get_release()

# Execute the collection based on the identified release
if match($ver,'^7\.5\b')
 run CGBU:BRMr7('7.5')
elsif match($ver,'^7\.4\b')
 run CGBU:BRMr7('7.4')
elsif match($ver,'^7\.3\b')
 run CGBU:BRMr7('7.3')
elsif match($ver,'^7\.2\b')
 run CGBU:BRMr7('7.2')
elsif match($ver,'^7\.0\b')
 run CGBU:BRMr7('7.0')
else
 run CGBU:BRMr7($ver)

=head1 SEE ALSO

L<CGBU:BRMr7|collect::CGBU:BRMr7>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
