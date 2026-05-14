# DCems.ctl:531:Collects Email Marketing Server Information
# $Id: DCems.ctl,v 1.3 2013/10/30 07:18:21 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCems.ctl,v 1.3 2013/10/30 07:18:21 RDA Exp $
#
# Change History
# 20130422  MSC  Improve the validation.

=head1 NAME

APPS:DCems - Collects Email Marketing Server Information

=head1 DESCRIPTION

This module collects Email Marketing Server information for any or all of the
following:

=over 2

=item o Click Through Daemon

=item o Email Server Daemon

=item o Web Survey Daemon

=back

The following reports can be generated and are regrouped under
C<Email Marketing Server>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing APPS.EMS module ...',tput('off')

# Initialization
var $CTD_HOME = ${D_CTD_HOME:''}
var $ESD_HOME = ${D_ESD_HOME:''}
var $WSD_HOME = ${D_WSD_HOME:''}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'
pretoc '1:Email Marketing Server'

=head1 CLICK THROUGH DAEMON

=head2 ctd_cfgpar - Configuration Parameters

Collects key configuration parameters from the F<$CTD_HOME/ctd.properties> file.

=cut

if ?testDir('d',$CTD_HOME)
{pretoc '2:Click Through Daemon'
 if ?testFile('fr',$fil = catFile($CTD_HOME,'ctd.properties'))
 {debug ' Inside EMS Module, getting CTD configuration parameters'
  report ctd_cfgpar
  prefix
  {write '---+ Key Configuration Parameters'
   write '---## Information Extracted from ',encode($fil)
   write '|*Name*|*Value*|'
  }
  loop $lin (grepFile($fil,'^\s*ctd\.(tomcatPort|webservice\.url)','i'))
   write '|',key($lin),' |',value($lin),' |'
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][Configuration Parameters]]'
 }
 unpretoc
}

=head1 EMAIL SERVER DAEMON

=head2 esd_cfgpar - Configuration Parameters

Collects key configuration parameters from the F<$ESD_HOME/esd.properties> file.

=cut

if ?testDir('d',$ESD_HOME)
{pretoc '2:Email Server Daemon'
 if ?testFile('fr',$fil = catFile($ESD_HOME,'esd.properties'))
 {debug ' Inside EMS Module, getting ESD configuration parameters'
  report esd_cfgpar
  prefix
  {write '---+ Key Configuration Parameters'
   write '---## Information Extracted from ',encode($fil)
   write '|*Name*|*Value*|'
  }
  loop $lin (grepFile($fil,\
    '^\s*esd\.(handler\.webservice\.url|mailServers|mountpoint|tomcatPort)',\
    'i'))
   write '|',key($lin),' |',value($lin),' |'
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][Configuration Parameters]]'
 }
 unpretoc
}

=head1 WEB SURVEY DAEMON

=head2 wsd_cfgpar - Configuration Parameters

Collects key configuration parameters from the
F<$WSD_HOME/webapps/websurveys/config/websurvey.properties> file.

=cut

if ?testDir('d',$WSD_HOME)
{pretoc '2:Web Survey Daemon'
 if ?testFile('fr',$fil = \
   catFile($WSD_HOME,'webapps','websurveys','config','websurvey.properties'))
 {debug ' Inside EMS Module, getting WSD configuration parameters'
  report wsd_cfgpar
  prefix
  {write '---+ Key Configuration Parameters'
   write '---## Information Extracted from ',encode($fil)
   write '|*Name*|*Value*|'
  }
  var $pat = cond(isFiltered(),'(password|user|username)$','(password)$')
  var %msk = (password => '%R:PASSWORD%',\
              user     => '%R:USER%',\
              username => '%R:USER%')
  loop $lin (grepFile($fil,\
    '^\s*(db\.WEBSURVEY\.(password|url|user)|\
          SIEBEL_(PASSWORD|URL|USERNAME)|\
          survey\.baseURL)','i'))
  {var $key = key($lin)
   var $val = value($lin)
   if match($key,$pat,true)
    write '|',$key,' |',$msk{lc(last)},' |'
   else
    write '|',$key,' |',$val,' |'
  }
  if isCreated(true)
   toc '3:[[',getFile(),'][rda_report][Configuration Parameters]]'
 }
 unpretoc
}

unpretoc

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
