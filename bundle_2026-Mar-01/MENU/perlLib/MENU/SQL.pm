# $Id: SQL.pm 200.0 2014/11/20 kjharris $
# +===========================================================================+
# |  Copyright (c) 2014 Oracle Corporation, Redwood Shores, California, USA 
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services  
# +===========================================================================+
# |
# | FILENAME: SQL.pm
# |
# | 
# | PLATFORM
# |   Unix Generic 
# |
# | NOTES
# |
# | HISTORY
# | 200.0 Creation (Nov-13-2014) 
# +===========================================================================+

package MENU::SQL; 

sub connectStrg 
{
  my $class = shift;
  my ($au, $ap) = @_;
  my $connStrg = {$cs};
  $cs = $au . '/' . $ap;
  bless $connStrg, $class;
  return $connStrg; 
}

sub getConnStrg
{
  my( $connStrg ) = @_;
  return $cs; 
}

return 1; 

__END__ 