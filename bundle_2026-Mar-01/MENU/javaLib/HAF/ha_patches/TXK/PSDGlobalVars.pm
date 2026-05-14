#
# $Header: GlobalVars.pm 120.14.12020000.168 2017/02/24 16:45:19 jvalenti ship $
# +==============================================================================+
# | Copyright (c) 2012, 2015 Oracle Corporation, Redwood Shores, California, USA
# |                             All Rights Reserved
# |                            Applications Division
# +==============================================================================+
# |
# | FILENAME
# |   GlobalVars.pm
# |
# | DESCRIPTION
# |   General routines for ADOP tool
# |
# | PLATFORM
# |   Generic
# |
# +==============================================================================+
#

package TXK::PSDGlobalVars;

######################################
# Standard Modules
######################################

use Exporter;
use strict;
use English;
use Carp;
use File::Copy;
use Cwd;
require 5.005;

######################################
# Constants
######################################

######################################
# Package Specific Modules
######################################

our $psdFileAgeThreshold;

1;
