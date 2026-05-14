# DCpweb.ctl:730:Collects PeopleSoft Information from Web Application Server
# $Id: DCpweb.ctl,v 1.9 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/APPS/DCpweb.ctl,v 1.8 2015/05/20 17:44:44 RDA Exp $
#
# Change History
# 20180108  DXM Enhance log collection.
# 20150518  KRA Improve the documentation.

=head1 NAME

APPS:DCpweb - Collects PeopleSoft Information from Web Application Server

=head1 DESCRIPTION

This module collects PeopleSoft diagnostic information from Web Application
Server. This module is applicable for Oracle Application Server, Oracle
WebLogic Server, and IBM WebSphere only.

The following reports can be generated and are regrouped under C<PeopleSoft/Web
Application Server>:

=cut

echo tput('bold'),'Processing APPS.PWEB module ...',tput('off')

# Initialization
var $PWEB_CFG  = ${GRP.PSFT.D_CFG_HOME:${ENV.PS_CFG_HOME:''}}
var $PWEB_HOME = ${GRP.PSFT.D_HOME:${ENV.PS_HOME:''}}
var $PWEB_PATH = ${D_WAS_HOME:''}
var $PWEB_TYPE = ${W_WAS}
var $PWEB_VERS = ${V_WAS}
var $TAIL      = ${GRP.PSFT.N_TAIL:1000}
var $AGE       = ${GRP.PSFT.R_AGE/T:1}

var $TOC = '%TOC%'
var $TOP = '[[#Top][Back to top]]'

var %tbl = (oas       => 'Oracle Application Server',\
            weblogic  => 'Oracle WebLogic Server',\
            websphere => 'IBM WebSphere Server')

# Validate the Web server type
if !match($PWEB_TYPE,'(oas|weblogic|websphere)')
{echo 'Invalid web server type'
 return
}

# Initialize the table of content
pretoc '^1:PeopleSoft'
pretoc '1+:',nvl($tbl{$PWEB_TYPE},'Web Application Server')

# Load the common macros
run RDA:library()

# Set the PWEB symbols
call setSymbol('$PS_HOME',$PWEB_HOME)
call setSymbol('$AS_HOME',$PWEB_PATH)
if length($PWEB_CFG)
 call setSymbol('$PS_CFG_HOME',$PWEB_CFG)
else
 var $PWEB_CFG = $PWEB_HOME

=head2 generic - General Information

Reports the PeopleSoft home directory and displays information about the Web
Application Server.

=cut

report generic
write '---+!! General Information'
write '|*PeopleSoft Home*|',$PWEB_HOME,'|'
if length($PWEB_CFG)
 write '|*PeopleSoft Configuration Home*|',$PWEB_CFG,'|'
write '|*Web Application Server Home*|',$PWEB_PATH,'|'
write '|*Web Application Server Type*|',nvl($tbl{$PWEB_TYPE},$PWEB_TYPE),'|'
write '|*Web Application Server Version*|',$PWEB_VERS,'|'
toc '2:[[',getFile(),'][rda_report][General Information]]'

=head1 FOR ORACLE APPLICATION SERVER

=head2 info - Information

Reports that Oracle Application Server information is collected by the OFM.IAS
module.

=cut

if compare('eq',$PWEB_TYPE,'oas')
{report info
 write 'Web Application Server to be collected by the OFM.IAS module'
 toc '2:[[',getFile(),'][rda_report][Information]]'
}

=head1 FOR ORACLE WEBLOGIC SERVER

Collects PeopleSoft information from Oracle WebLogic Server domains. It looks
for all domains containing a file F<piaInstallLog.xml>. For each of them, it
collects the related configuration and log files.

=cut

elsif compare('eq',$PWEB_TYPE,'weblogic')
{# Identify the relevant domains
 var @dom = ()
 loop $dom (findDir(catDir($PWEB_CFG,'webserv'),'^\.+$','nv'))
 {if ?nvl(testFile('f',catFile($PWEB_CFG,'webserv',$dom,'piaInstallLog.xml')),\
          testFile('f',catFile($PWEB_CFG,'webserv',$dom,'piaconfig',\
                               'properties','piaInstallLog.xml')))
   call push(@dom,$dom)
 }

 # Get domain information
 loop $dom (@dom)
 {var $dir = catDir($PWEB_CFG,'webserv',$dom)
  pretoc '%SPLIT%'
  pretoc "1++:'",$dom,"' Domain"

  # Collect configuration files
  pretoc '2: Configuration Files'
  var @fil = ()
  loop $pth (grepDir(catDir($dir,'applications','peoplesoft','PORTAL',\
                            'WEB-INF','psftdocs'),'^\.+$','pv'))
  {if ?testDir('d',$pth)
    call push(@fil,catFile($pth,'configuration.properties'),\
                  catFile($pth,'pstools.properties'),\
                  grepDir(catDir($pth,'webprof'),'^\.+$','rv'))
  }
  call sort_files(3,0,@fil,\
    catFile($dir,'config.xml'),\
    catFile($dir,'setEnv.sh'),\
    catFile($dir,'bin','setEnv.sh'),\
    catFile($dir,'config','config.xml'),\
    catFile($dir,'applications','peoplesoft','PORTAL','WEB-INF','web.xml'),\
    catFile($dir,'applications','peoplesoft','PORTAL','WEB-INF',\
            'weblogic.xml'),\
    catFile($dir,'applications','peoplesoft','PORTAL.war','WEB-INF','web.xml'),\
    catFile($dir,'applications','peoplesoft','PORTAL.war','WEB-INF',\
            'weblogic.xml'),\
    catFile($dir,'applications','peoplesoft','PSIGW','WEB-INF','web.xml'),\
    catFile($dir,'applications','peoplesoft','PSIGW','WEB-INF','weblogic.xml'),\
    catFile($dir,'applications','peoplesoft','PSIGW','WEB-INF',\
            'integrationGateway.properties'),\
    catFile($dir,'applications','peoplesoft','PSIGW.war','WEB-INF','web.xml'),\
    catFile($dir,'applications','peoplesoft','PSIGW.war','WEB-INF','weblogic.xml'),\
    catFile($dir,'applications','peoplesoft','PSIGW.war','WEB-INF',\
            'integrationGateway.properties'))
  unpretoc

  # Collect log files
  pretoc '2: Domain and Server Log Files'
  call sort_files(3,$TAIL,\
    grepDir(catDir($dir,'logs'),'\.log$',concat('npm',$AGE)),\
    grepDir(catDir($dir,'servers','PIA','logs'),'\.log(\.\d+)?$',concat('npm',$AGE)),\
    grepDir(catDir($dir,'applications','peoplesoft','PSIGW'),'\.*Log.html(\.\d+)?$',concat('npm',$AGE)),\
    grepDir(catDir($dir,'applications','peoplesoft','PSIGW.war'),'\.*Log.html(\.\d+)?$',concat('npm',$AGE)))
   unpretoc 3
   pretoc '2: Applications Log Files'
   call sort_files(3,0,\
    grepDir(catDir($dir,'applications','peoplesoft','PSIGW','WEB-INF'),'\.*Log.html(\.\d+)?$',concat('npm',$AGE)),\
    grepDir(catDir($dir,'applications','peoplesoft','PSIGW.war','WEB-INF'),'\.*Log.html(\.\d+)?$',concat('npm',$AGE)))
   unpretoc 3
 }
}

=head1 FOR IBM WEBSPHERE SERVER

Collects cell and application configuration files and log files.

=cut

elsif compare('eq',$PWEB_TYPE,'websphere')
{if compare('same',$PWEB_VERS,'5.1')
 {# Get data for WebSphere 5.1

  pretoc '%SPLIT%'
  pretoc '1++:Generic Information'

  # Collect the configuration files
  pretoc '2: Configuration Files'
  var @fil = ()
  loop $cel (findDir(catDir($PWEB_PATH,'config','cells'),'^\.+$','pv'))
  {call push(@fil,catFile($cel,'virtualhosts.xml'))
   loop $nod (findDir(catDir($cel,'nodes'),'^\.+$','pv'))
    call push(@fil,catFile($nod,'serverindex.xml'),\
                   grepDir(catDir($nod,'servers'),'^server\.xml$','r',2))
  }
  call sort_files(3,0,@fil)
  unpretoc

  # Collect the log files
  pretoc '2: Log Files'
  call sort_files(3,$TAIL,grepDir(catDir($PWEB_PATH,'logs'),'\.log$',concat('rm',$AGE),2))
  unpretoc 3

  # Identify the relevant domains/applications
  var @tbl = ()
  loop $dom (findDir(catDir($PWEB_HOME,'webserv'),'^\.+$','nv'))
  {loop $app (findDir(catDir($PWEB_HOME,'webserv',$dom),'^\.+$','nv'))
   {if ?testFile('f',catFile($PWEB_HOME,'webserv',$dom,$app,'setEnv.sh'))
     call push(@tbl,[$dom,$app])
   }
  }

  # Get application information
  loop $itm (@tbl)
  {var ($dom,$app) = @{$itm}
   var $dir = catDir($PWEB_HOME,'webserv',$dom,$app)
   pretoc '%SPLIT%'
   pretoc "1++:'",$dom,"/",$app,"' Domain/Application"

   # Collect application configuration files
   pretoc '2: Configuration Files'
   var @fil = ()
   loop $pth (grepDir(catDir($dir,'PORTAL','WEB-INF','psftdocs'),'^\.+$','pv'))
   {if ?testDir('d',$pth)
     call push(@fil,catFile($pth,'configuration.properties'),\
                    catFile($pth,'pstools.properties'),\
                    grepDir(catDir($pth,'webprof'),'^\.+$','rv'))
   }
   call sort_files(3,0,@fil,\
     catFile($dir,'setEnv.sh'),\
     catFile($dir,'PORTAL','WEB-INF','web.xml'),\
     catFile($dir,'PSIGW','WEB-INF','web.xml'),\
     catFile($dir,'PSIGW','WEB-INF','integrationGateway.properties'),\
     catFile($dir,'PSIGW','msgLog.html'),\
     catFile($dir,'PSIGW','errorLog.html'))
   unpretoc 3
  }
 }
 elsif compare('same',$PWEB_VERS,'6.1')
 {# Collect generic log files for IBM WebSphere 6.1
  pretoc '%SPLIT%'
  pretoc '1++:Generic Information'
  pretoc '2: Log Files'
  var @fil = ()
  loop $dom (findDir(catDir($PWEB_HOME,'webserv'),'^\.+$','pv'))
   call push(@fil,grepDir(catDir($dom,'logs'),'\.log$',concat('rm',$AGE),2))
  call sort_files(3,$TAIL,@fil)
  unpretoc 3

  # Identify the relevant cells
  var @tbl = ()
  loop $dom (findDir(catDir($PWEB_HOME,'webserv'),'^\.+$','nv'))
  {loop $cel (findDir(catDir($PWEB_HOME,'webserv',$dom,'config','cells'),\
                      '^\.+$','nv'))
   {if ?testFile('f',catFile($PWEB_HOME,'webserv',$dom,'config','cells',$cel,\
                            'virtualhosts.xml'))
     call push(@tbl,[$dom,$cel])
   }
  }

  # Get cell information
  loop $itm (@tbl)
  {var ($dom,$cel) = @{$itm}
   var $dir = catDir($PWEB_HOME,'webserv',$dom,'config','cells',$cel)

   pretoc '%SPLIT%'
   pretoc "1+:'",$dom,"/",$cel,"' Domain/Cell"
   pretoc '2: Configuration Files'
   var @fil = ()
   loop $pth (findDir(catDir($dir,'nodes'),'^\.+$','pv'))
    call push(@fil,catFile($pth,'serverindex.xml'),\
                   grepDir(catDir($pth,'servers'),'^server\.xml$','r',2))
   call sort_files(3,0,@fil,catFile($dir,'virtualhosts.xml'),\
                            catFile($dir,'security.xml'))
   unpretoc 3
  }

  # Identify the relevant applications
  var @tbl = ()
  loop $dom (findDir(catDir($PWEB_HOME,'webserv'),'^\.+$','nv'))
  {loop $nod (findDir(catDir($PWEB_HOME,'webserv',$dom,'installedApps'),\
                      '^\.+$','nv'))
   {loop $app (findDir(catDir($PWEB_HOME,'webserv',$dom,'installedApps',$nod),\
                       '^\.+$','nv'))
    {if ?testDir('d',catDir($PWEB_HOME,'webserv',$dom,'installedApps',$nod,\
                           $app,'PORTAL.war'))
      call push(@tbl,[$dom,$nod,$app])
    }
   }
  }

  # Collects the application configuration files
  loop $itm (@tbl)
  {var ($dom,$nod,$app) = @{$itm}
   var $dir = catDir($PWEB_HOME,'webserv',$dom,'installedApps',$nod,$app)

   pretoc '%SPLIT%'
   pretoc "1+:'",$dom,"/",$nod,"/",$app,"' Domain/Node/Application"
   pretoc '2: Configuration and Log Files'
   var @fil = ()
   loop $pth (findDir(catDir($dir,'PORTAL.war','WEB-INF','psftdocs'),'^\.+$',\
                      'pv'))
    call push(@fil,catFile($pth,'configuration.properties'),\
                   catFile($pth,'pstools.properties'),\
                   grepDir(catDir($pth,'webprof'),'^\.+$','rv'))
   call sort_files(3,0,@fil,\
     catFile($dir,'setEnv.sh'),\
     catFile($dir,'PORTAL.war','WEB-INF','web.xml'),\
     catFile($dir,'PSIGW.war','WEB-INF','web.xml'),\
     catFile($dir,'PSIGW.war','WEB-INF','integrationGateway.properties'),\
     catFile($dir,'PSIGW.war','msgLog.html'),\
     catFile($dir,'PSIGW.war','errorLog.html'))
   unpretoc 3
  }
 }
}

# Disable the group title in next index
if isTocCreated(true)
 toc '-:PeopleSoft'

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
