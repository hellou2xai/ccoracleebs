# $Id: eccWLS.py 200.1 9:21 AM 9/6/2019 gbellot kjharris eslyter$
# *===========================================================================+
# |  Copyright (c) 2019 Oracle Corporation, Redwood Shores, California, USA  
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services
# +===========================================================================+
# | 
# | Place this file in your runtime env on the WLS_Home of the EBS Server
# | 
# | Check the status of an Application Deployment
# | Args: 
# | WLS User, Password, URL, App Name, App Server, wlsu main log 
# | 
# | additional contributing authors: rramirez, osarioglu 
# | 
# | History: 
# | 200.0: BETA
# | -----: Sep-2017 
# |        "getGII": Fixed CPU / Memory Print, HTML formatting fixes '
# |        "getServerStatus": Better formatting/grouping of deployed apps
# |        Added documents / checks to various sections
# | -----: Updated Java Heap info to include error_icon checks
# | -----: Updated getGII function for better HTML formatting & assurred output on all 4 major platforms (LINUX/SUN/HPUX/AIX) 
# | -----: Added some hidden <DIV> for Automation pickup 
# | 200.1: Fork of ebsWLS.py for ECC 12c checks 
# | -----: 
# +===========================================================================+
import sys
import os
from datetime import datetime
import re 

argLen = len(sys.argv)
if argLen > -1 and argLen < 6:
	print "ERROR: got ", argLen -1, " args."
	print "USAGE: wlst.sh test.py WLS_USER WLS_PASSWORD WLS_URL app_name target_server"
	sys.exit(255)
	
WLS_USER = sys.argv[1]
WLS_PW = sys.argv[2]
WLS_URL = sys.argv[3]
appname = sys.argv[4]
appserver = sys.argv[5]

#the WLSU Main Log 
mainLog = open(sys.argv[6], 'a')

# Connect to WLS
connect(WLS_USER, WLS_PW, WLS_URL)
####################################################################################


# +-------------------------------------------------------------------+
# | function:  mainRun
# +-------------------------------------------------------------------+
# | Desc: run the functions 
# +-------------------------------------------------------------------+
# | Args: nebytiye
# +-------------------------------------------------------------------+
# | Returns: nada
# +-------------------------------------------------------------------+
def mainRun():
	global mnd #master node dic{}
	mnd = mapServerToNode() 
	logfile = open('eccWLSUstatusInfo.log', 'w')

#9/9/2019 : remove other tasks to run only getECCInfo
	#tasks = [ getECCInfo, getGII, getNodeMGR, getServerStatus, getJHPS, getJDBCInfo, getJVMInfo, getICT, getDiagnosticsData, getThreadDump ]

	tasks = [ getECCInfo, getECCJDBCInfo]

	for i in tasks:
		print "\n\n  Running: \"%s\" " % i
		start =  datetime.now()
		curTask = "%s" % i; 
		logger("Running: " + curTask)
		i(logfile) 
		logger("DONE: " + curTask)
		end = datetime.now()
		print "\nDone with \"%s\ [elapsed time: %s]" % (i, end-start) 
		print >>logfile, '''<br>'''
		
	logfile.close()
	return 

# END: mainRun ################################################################

# +-------------------------------------------------------------------+
# | sub: mapServerToNode
# +-------------------------------------------------------------------+
# | Desc: maps WLS managed servers to a cluster, port and node 
# +-------------------------------------------------------------------+
# | Args: nebytiye
# +-------------------------------------------------------------------+
# | Returns: dictionary object with embedded list 
# | mnd[server][0] = node name 
# | mnd[server][1] = cluster name 
# | mnd[server][2] = listen port 
# +-------------------------------------------------------------------+
def mapServerToNode(): 
	#mnd = "master node dictionary" .. this is not an "Oracle thing", but just a variable name for this function 
	mnd = {} 
	domainRuntime()
	servers = domainRuntimeService.getServerRuntimes()
	for server in servers:
		serverName = "%s" % server.getName()
		nodeName = "%s" % server.getCurrentMachine()
		port = "%s" % server.getListenPort()
		#cluster name 
		clusterName=server.getClusterRuntime()
		clustStr = "%s" % (clusterName) 
		if re.search('Name=(.+?),', clustStr) is not None:
			matchObj = re.search('Name=(.+?),', clustStr)
			clusterName = matchObj.groups()[0]
		else: 
			clusterName = '[ No Assigned Cluster ]'
		
		mnd.setdefault(serverName, [])
		mnd[serverName].append(nodeName) 
		mnd[serverName].append(clusterName) 
		mnd[serverName].append(port) 

	return mnd 
#END: mapServerToNode


# +-------------------------------------------------------------------+
# | function:  getECCInfo
# +-------------------------------------------------------------------+
# | Desc: Generate the datasource, deployed appsServer and status
# |     : 
# +-------------------------------------------------------------------+
# | Args: HTML Output File 
# +-------------------------------------------------------------------+
# | Returns: nada
# +-------------------------------------------------------------------+
def getECCInfo(logfile):
	#import re 
	#Section Managed Server Status
	print >>logfile, '''<div class="divItem">
	<div class="divItemTitle">ECC Domain State and Managed Server Status</div>'''

	# Set Application run time object
	nav=getMBean('domainRuntime:/AppRuntimeStateRuntime/AppRuntimeStateRuntime')
	
	# should not get a critical flag for  "None" state 
	# need more handling for other conditions .. need to know what all possible states are here 
	
	state=nav.getCurrentState(appname,appserver)
	if state == 'STATE_ACTIVE':
		print >>logfile, '<img class="check_ico" />State: "%s" - %s on %s' % (state,appname,appserver)
		print >>logfile, '<p>Running and Available</p>'	
	elif state == 'STATE_ADMIN':
		print >>logfile, '<img class="warn_ico" />State: "%s" - %s on %s' % (state,appname,appserver)
		print >>logfile, '<p>Running but only accessible through admin port.</p>'
	elif state == 'STATE_FAILED': 
		print >>logfile, '<img class="error_ico" />State: "%s" - %s on %s' % (state,appname,appserver)
		print >>logfile, '<p>Configured but not deployed. This is the state of an application after it fails during dynamic deployment activate or during static deployment startup. This state can only be set as a current state, but not as an intended state.</p>'	
	elif state == 'STATE_NEW': 
		print >>logfile, '<img class="warn_ico" />State: "%s" - %s on %s' % (state,appname,appserver)
		print >>logfile, '<p>Configured but not deployed.</p>'	
	elif state == 'STATE_PREPARED': 
		print >>logfile, '<img class="warn_ico" />State: "%s" - %s on %s' % (state,appname,appserver)
		print >>logfile, '<p>Ready for activation.</p>'	
	elif state == 'STATE_RETIRED': 
		print >>logfile, '<img class="warn_ico" />State: "%s" - %s on %s' % (state,appname,appserver)
		print >>logfile, '<p>Configured but not deployed. This is the state of an application version after it is retired. The administrator is responsible for explicitly removing the retired app version from the configuration. This state can only be set as a current state, but not as an intended state.</p>'	
	elif state == 'STATE_UPDATE_PENDING': 
		print >>logfile, '<img class="check_ico" />State: "%s" - %s on %s' % (state,appname,appserver)
		print >>logfile, '<p>Running and being updated</p>'
	else: 
		print >>logfile, '<img class="check_ico" />State: "%s" - %s on %s' % (state, appname, appserver)
	
	# Get Environment Status
	servers=domainRuntimeService.getServerRuntimes()
	print >>logfile, ''' <table class="table1" id="managedServerStatus"><tbody>
  <tr> 
   <th class="sort" onclick="sortTable(0, 'managedServerStatus')">Node</th>
   <th class="sort" onclick="sortTable(1, 'managedServerStatus')">Cluster</th>
   <th class="sort" onclick="sortTable(2, 'managedServerStatus')">Managed Server Name</th>
   <th class="sort" onclick="sortTable(3, 'managedServerStatus')">TCP Port</th>
   <th class="sort" onclick="sortTable(4, 'managedServerStatus')">Status &amp; Health</th>
  </tr>'''
	
	ico = '<img class="check_ico">' 

	for server in servers:
		serverName = server.getName()
		nodeName=mnd[serverName][0] 
		clusterName=mnd[serverName][1] 
		port=mnd[serverName][2] 
		#the WLS Server name: 
		state = server.getState()
		health = server.getHealthState()
		my_Str = "%s" % (health) 
		matchObj = re.search("\State\:(\w+)\,", my_Str) 
		#need a string / regex on getHealthState to check if it' "HEALTH_OK" 
		if matchObj.groups()[0] != 'HEALTH_OK': 
			ico = '<img class="error_ico">'
			
		print >>logfile, "<tr>  <td> <b>%s</b> </td> <td>%s</td> <td>%s</td> <td>%s</td> <td>%s &nbsp; %s &nbsp; %s</td>  </tr>" % (nodeName, clusterName, serverName, port, ico, state, matchObj.groups()[0]) 

	print >>logfile, '</tbody></table>' 
	print >>logfile, '</div>' 

	# Get the status of the deployed applications
	domainConfig()
	apps=cmo.getAppDeployments()
	print >>logfile, '''<br><div class="divItem">
	<div class="divItemTitle">App Deployment Status</div>
	'''
	print >>logfile, '''
  <table class="table1" id="appDeployStatus">
  <tbody>
  <tr>
   <th class="sort" onclick="sortTable(0, 'appDeployStatus')">Application</th>
   <th class="sort" onclick="sortTable(1, 'appDeployStatus')">App Deployment Status</th>
   <th class="sort" onclick="sortTable(2, 'appDeployStatus')">WLS Server App is deployed to</th>
  </tr>
  <p>The Application Deployment Status sections displays the WLS applications that are deployed within the WLS Managed Server and their status. A status other than STATE_ACTIVE can indicate a config issue and sometimes result in Login Problems:</p>
 	<ul>
 		<li>See the document, Installing Oracle Enterprise Command Center Framework, Release 12.2 <a href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&amp;sourceId=2230225.1&amp;id=2495053.1" target="_blank" rel="noopener">[Doc ID 2495053.1]</a></li>
 	</ul>
   <p>&nbsp;</p>
''' 
	for appName in apps:
		domainConfig()
		cd ('/AppDeployments/'+appName.getName()+'/Targets')
		mytargets = ls(returnMap='true')
		domainRuntime()
		cd('AppRuntimeStateRuntime/AppRuntimeStateRuntime')
		for targetinst in mytargets: 
			curstate4=cmo.getCurrentState(appName.getName(),targetinst) 
			if(curstate4 == "STATE_ACTIVE"):
				print >>logfile, "<tr><td><img class=\"check_ico\">&nbsp;%s</td><td>%s</td><td>%s</td></tr>" % (appName.getName(), curstate4, targetinst) 
			elif(curstate4 == "STATE_NEW"): 
				print >>logfile, "<tr><td><img class=\"warn_ico\">&nbsp; %s</td><td>%s</td><td>%s</td></tr>" % (appName.getName(), curstate4, targetinst)  
			else: 
				print >>logfile, "<tr><td><img class=\"error_ico\">&nbsp; %s</td><td>%s</td><td>%s</td></tr>" % (appName.getName(), curstate4, targetinst)  
	print >>logfile, '</tbody></table>' 
	print >>logfile, '</div>' 

	#END: getECCInfo

# +-------------------------------------------------------------------+
# | function:  getECCJDBCInfo
# +-------------------------------------------------------------------+
# | Desc: ECC JDBC checking 
# +-------------------------------------------------------------------+
# | Args: nebytiye
# +-------------------------------------------------------------------+
# | Returns: nada
# +-------------------------------------------------------------------+
def getECCJDBCInfo(logfile):
	print >>logfile, '''<div class="divItem">
	<div class="divItemTitle"><b>ECC JDBC Information</b></div>
	<p>This data provides insight into the run-time performance of servers and applications and enables you to isolate and diagnose faults when they occur.It is a view of run-time statistics for a data source via the JBCDataSourceRuntimeMBean. This allows for getting the current state of the E-Business Suite Release 12.2 and ECC JDBC data sources within the Oracle WebLogic Server.<p/>'''

	domainRuntime()
	print >>logfile, '''
  <table id="JDBCDataSourceRunTime" class="table1">
   <tbody>
    <tr>
     <th class="sort" onclick="sortTable(0, 'JDBCDataSourceRunTime')">Node</th>
     <th class="sort" onclick="sortTable(1, 'JDBCDataSourceRunTime')">Managed Server Name</th>
     <th class="sort" onclick="sortTable(2, 'JDBCDataSourceRunTime')">Data Source Name</th>
     <th class="sort" onclick="sortTable(3, 'JDBCDataSourceRunTime')">Concurrent Connections</th>
    </tr>
'''

	servers=domainRuntimeService.getServerRuntimes()
	for server in servers:
		nodeName=server.getCurrentMachine()
		jdbcDSrcs=server.getJDBCServiceRuntime().getJDBCDataSourceRuntimeMBeans()
		print >>logfile, '''<tr> <td><b>%s</b></td> <td>%s</td> ''' % (nodeName, server.getName())

		if len(jdbcDSrcs) > 0: 
			for jdbaDSrc in jdbcDSrcs:
				# print >>logfile, '<Data Source Name #', % (jdbaDSrc.getName())
				print >>logfile, '''<td>%s</td><td>%s</td>''' % (jdbaDSrc.getName(), jdbaDSrc.getActiveConnectionsCurrentCount())
		else:
			print >>logfile, '''<td>[null]</td><td>[null]</td>'''

		print >>logfile, '</tr>'
		#end loop 
	#close the JDBCDataSourceRunTime table: 
	print >>logfile, '</tbody></table>'
	
	serverRuntime()
	ebsMBeans = cmo.getJDBCServiceRuntime().getJDBCDataSourceRuntimeMBeans()
	if (len(ebsMBeans) > 0): 
		print >>logfile, '''
  <table id="JDBCDataSource" class="table1">
   <tbody>
    <tr>
     <th class="sort" onclick="sortTable(0, 'JDBCDataSource')">JDBC Data Source Name</th>
     <th class="sort" onclick="sortTable(1, 'JDBCDataSource')">State</th>
     <th class="sort" onclick="sortTable(2, 'JDBCDataSource')">Test Pool</th>
    </tr>'''
		#ds_name = 'EBSDataSource'
		for ds in ebsMBeans:
			if (ds.getName() == 'ebsDB'):
				print >>logfile, '''<tr><td>%s</td><td>%s</td><td>%s</td></tr>''' % ( ds.getName(), ds.getState(), ds.testPool() )
				print >>logfile, '</tbody></table>'

	# servers=domainRuntimeService.getServerRuntimes()
	if (len(servers) > 0):
		print >>logfile, '''
  <table id="serverRunTimes" class="table1">
   <tbody>
    <tr> 
     <th class="sort" onclick="sortTable(0, 'serverRunTimes')">Node</th>
     <th class="sort" onclick="sortTable(1, 'serverRunTimes')">Server</th>
     <th class="sort" onclick="sortTable(2, 'serverRunTimes')">JDBC Data Sources (getJDBCDataSourceRuntimeMBeans)</th>
    </tr>'''
		for server in servers:
			nodeName=server.getCurrentMachine()
			jdbcServiceRT = server.getJDBCServiceRuntime()
			dataSources = jdbcServiceRT.getJDBCDataSourceRuntimeMBeans()
			if (len(dataSources) > 0):
				for ds in dataSources:
					if(ds.getName() == 'ebsDB'):
					
						#regex here on Name for dataSource 
							#cluster name 
						dsStr = "%s" % ds
						if re.search('Name=(.+?),', dsStr) is not None:
							matchObj = re.search('Name=(.+?),', dsStr)
							dsStr = matchObj.groups()[0]
						else: 
							dsStr = '[ none ]' 
						#servername regex to limit string down to Name 
						serverStr = "%s" % server	
						if re.search('Name=(.+?),', serverStr) is not None:
							matchObj = re.search('Name=(.+?),', serverStr)
							serverStr = matchObj.groups()[0]
						else: 
							serverStr = '[ none ]'
			
						print >>logfile, '''<tr><td><b>%s</b></td><td>%s</td>''' % (nodeName, serverStr) 
						print >>logfile, '''<td>%s</td>''' % (dsStr) 

				print >>logfile, '''</tr>'''
 
		print >>logfile, '''</tbody></table>'''
		print >>logfile, '''<br>'''
		print >>logfile, '''<h><b>ECC JDBC Information</b></h>'''
		print >>logfile, '''<br>'''

	RegisteredServers=domainRuntimeService.getServerRuntimes();
	if (len(RegisteredServers) > 0):
		for allServers in RegisteredServers:
			jdbcServiceRT = allServers.getJDBCServiceRuntime();
			dataSources = jdbcServiceRT.getJDBCDataSourceRuntimeMBeans();
			if (len(dataSources) > 0):
				for dataSource in dataSources:
					print >>logfile, '''============================================================='''
					print >>logfile, '''<br>'''
					print >>logfile, '''<br>Data Source ID:          '''  ,  dataSource.getModuleId()
					print >>logfile, '''<br>Data Source Name:        '''  ,  dataSource.getName()
					print >>logfile, '''<br>Parent:                  '''  ,  dataSource.getParent()
					print >>logfile, '''<br>User Properties:         '''  ,  dataSource.getProperties()
					print >>logfile, '''<br>Current State:           '''  ,  dataSource.getState()
					print >>logfile, '''<br>Data Source Type:        '''  ,  dataSource.getType()
					print >>logfile, '''<br>JDBC Driver Version:     '''  ,  dataSource.getVersionJDBCDriver()
					print >>logfile, '''<br>'''
#
	print >>logfile, '</div>' 
	return#END: getECCJDBCInfo

# +-------------------------------------------------------------------+
# | sub: getGII
# +-------------------------------------------------------------------+
# | Desc: Get Instance Info
# +-------------------------------------------------------------------+
# | Args: nebytiye
# +-------------------------------------------------------------------+
# | Returns: nada
# +-------------------------------------------------------------------+
def getGII(logfile):
	domainRuntime()
	cd('/ServerRuntimes/AdminServer')
	print >>logfile, '<div class="divItem">'
	print >>logfile, '<div class="divItemTitle">General System Information</div>' 
	# print >>logfile, '<p>'	#Get variables from WLS Server about the environment
	wlsversion=get('WeblogicVersion')
  
  #split the wlsversion stuff into a list on the TZ and YYYY 
	#WebLogic Server Temporary Patch for BUG20474010 Sun Mar 01 17:22:18 
	myLst=re.split("(\s\w{3}\s\d{4})", wlsversion) 
	wlssvrclass=get('ServerClasspath')
	myLst2=re.split("\:", wlssvrclass) 
	
	wlshmdir=get('WeblogicHome')
	ssloff=get('SSLListenPortEnabled')
	if ssloff == 0:
		ssl = 'FALSE' 
	else: ssl = 'TRUE'
	sslprt=get('SSLListenPort')
	ohme=get('OracleHome')
	fmwhme=get('MiddlewareHome')
	dftport=get('ListenPortEnabled')
	if dftport == 0:
		dft = 'FALSE' 
	else: dft = 'TRUE'
	lstprt=get('ListenPort')
	lstadd=get('ListenAddress')
	dfturl=get('DefaultURL')
	curdir=get('CurrentDirectory')
	admurl=get('AdministrationURL')
	cd('/ServerRuntimes/AdminServer/JVMRuntime/AdminServer')
	javend=get('JavaVendor')
	javer=get('JavaVersion')
	

	#CPU / MEM / Swap Info 
	opSys = os.environ['PLATFORM'] 
	opSysMatch = re.search(r'^\w{3}', opSys) 
	opSys = opSysMatch.group(0)
	opSys.upper() 
	
	tableList = ['','','',''] 
	if opSys == "AIX":
		tableList = getAIX()
		# ofsmem = os.popen("svmon -G", "r").read() 
		#oscpu needs updating 3:40 PM 9/1/2017 
		# oscpu = os.popen('ps aux | head -1; ps aux | sort -rn +2 | head -10',"r").read()
	elif opSys == "LIN": 
		tableList = getLinux()
		# tableList= getUnixGeneric() 
	elif opSys == "HPU": 
		# print "do HP stuff.." 
		tableList= getUnixGeneric() 
	elif opSys == "SOL" or opSys == "SUN": 
		# print "do SUN stuff.." 
		tableList= getUnixGeneric() 
	else: 
		tableList= getUnixGeneric() 
		# ofsmem = os.popen("vmstat -s | grep mem","r").read() 
		# oscpu = os.popen('iostat -c',"r").read() 

	# print >>logfile, "%s" % myNewStr
		
	# myLst3=re.split("\n",ofsmem)
	osver=get('OSVersion')
	#Get Disk Free from OS
	# osdf = os.popen("df -kh").read() 
	osdf = os.popen("df -m").read()
	osdf = re.sub('MB\sblocks','MB&nbsp;blocks' , osdf)
	osdf = re.sub('Mounted\son','Mounted&nbsp;on' , osdf)

	mySplitOsdf=re.split('\n',osdf)

	cnt = 0 
	osdf = '''\n\n<table class="table1">\n <tbody>'''
	for spl in mySplitOsdf: 
		if (len(spl) < 1):
			continue
		if re.search('^\/', spl) or cnt > 0:
			osdf += '\n <tr><td>'
			spl = re.sub('^\s+','' , spl)
			spl = re.sub('\s+','  </td>\n <td>' , spl)
			cnt = 1 
		else: 
			osdf += '\n <tr><th>'
			spl = re.sub('^\s+','' , spl)
			spl = re.sub('\s+','  </th>\n <th>' , spl)
		spl = re.sub('\s+$','', spl)
		osdf += spl
		if cnt == 1: 
			osdf += '</td>\n</tr>\n\n'
		else:
			osdf += '\n </th></tr>'
			
		osdf = re.sub('\<td\>\<\/td\>','',osdf) 
	osdf += '''\n\n </tbody>\n</table>\n <!-- END df -m --> \n\n'''

	print >>logfile, '''
    <table class="summaryTable" id="GII">
      <tbody>
       <tr> 
         <th class="sort" onclick="sortTable(0, 'GII')">Description</th>
         <th class="sort" onclick="sortTable(1, 'GII')">Value</th>
      </tr>'''
	
	#version split 
	print >>logfile, ''' <tr>  <td>WLS Version</td><td>'''

	for ln in myLst:
		if re.search('^\s\w{3}\s\d{4}',ln):
			print >>logfile, "%s<br>" % ln 
		else: 
			print >>logfile, "%s" % ln 
		
	print >>logfile, '''</td></tr><!--wlsversion data-->''' #end Version Row 
 
	#classpath split 
	print >>logfile, ''' <tr>  <td>WebLogic Server Classpath</td><td>''' 

	for ln in myLst2: 
		print >>logfile, "%s<br>" % ln 
		
	print >>logfile, '''</td></tr><!--END classpath-->''' #end cp Row 
 
 
	print >>logfile, '''
 <tr>  <td>WebLogic Home Dir</td> <td>%s</td> </tr> <!-- wlshmdir --> 
 <tr>  <td>SSL Enabled</td> <td>%s %s</td> </tr> <!-- ssloff ssl--> 
 <tr>  <td>SSL Port</td> <td>%s</td> </tr> <!-- sslprt --> 
 <tr>  <td>Oracle Home Dir</td> <td>%s</td> </tr> <!-- ohme --> 
 <tr>  <td>FMW Home Dir</td> <td>%s</td> </tr> <!-- fmwhme --> 
 <tr>  <td>WLS Default Port</td> <td>%s %s</td> </tr> <!-- dftport dft--> 
 <tr>  <td>WLS Listen Port</td> <td>%s</td> </tr> <!-- lstprt --> 
 <tr>  <td>WLS Listen Address</td> <td>%s</td> </tr> <!-- lstadd --> 
 <tr>  <td>Default URL</td> <td>%s</td> </tr> <!-- dfturl --> 
 <tr>  <td>Current Directory</td> <td>%s</td> </tr> <!-- curdir --> 
 <tr>  <td>Admin URL</td> <td>%s</td> </tr> <!-- admurl --> 
 <tr>  <td>Java Vendor</td> <td>%s</td> </tr> <!-- javend --> 
 <tr>  <td>Java Version</td> <td>%s</td> </tr> <!-- javer --> 
 <tr>  <td>Operating System</td> <td>%s</td> </tr> <!-- osnme --> 
 <tr>  <td>Operating System Version</td> <td>%s</td> </tr> <!-- osver -->
 ''' % (wlshmdir, ssloff, ssl, sslprt, ohme, fmwhme, dftport, dft, lstprt, lstadd, dfturl, curdir, admurl, javend, javer, os.environ['PLATFORM'], osver) 
 
	print >>logfile, '''<tr>  <td>Operating System Disk Free</td><td>'''
 
 #disk 
	print >>logfile, '''%s<br>''' % osdf 
 
	print >>logfile, '''</td></tr> <!--END OS Disk Space -->''' 
 
	print >>logfile, '''
 <tr>  <td>Top CPU Consuming Processes</td> <td>'''
	print >>logfile, "%s" % tableList[0]
	print >>logfile, '''</td></tr> <!-- Top CPU Proc -->'''
	
	print >>logfile, '''\n<tr>  <td>CPU Usage</td> <td>\n'''
	print >>logfile, "%s" % tableList[1]
	print >>logfile, '''\n</td></tr> <!-- Top CPU Usage -->\n'''
	
	print >>logfile, '''\n<tr>  <td>Memory</td> <td>\n'''
	print >>logfile, "%s" % tableList[2]
	print >>logfile, '''\n</td></tr> <!-- Memory Usage -->\n'''
	
	print >>logfile, '''\n<tr>  <td>Swap</td> <td>\n'''
	print >>logfile, "%s" % tableList[3]
	print >>logfile, '''\n</td></tr> <!-- Swap Usage -->\n'''

	print >>logfile, '''</tbody></table>''' 
	
	print >>logfile, '''<br><hr>'''
	print >>logfile, '''
    <div>Please run the EBS Technology Codelevel Checker (ETCC), Oracle E-Business Suite Release 12.2: Consolidated List of Patches and Technology Bug Fixes (Doc ID 1594274.1) for the latest technology bugfixes required for Oracle E-Business Suite Release 12.2: 
   <ul>
     <li><span style="color: #0f0f0f;">Oracle E-Business Suite Release 12.2: Consolidated List of Patches and Technology Bug Fixes <a href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&amp;sourceId=2230225.1&amp;id=1594274.1" target="_blank">[Doc ID 1594274.1]</a></span></li>
     <li><span style="color: #0f0f0f;">Also look at EBS 12.2 - Summary Of The Login Process And What To Expect When One Of The Components Fails <a href="https://support.oracle.com/epmos/faces/DocumentDisplay?parent=ANALYZER&amp;sourceId=2230225.1&amp;id=1984710.1" target="_blank">[Doc ID 1984710.1]</a></span></li>
     </ul> 
    </div> '''
	
	print >>logfile, '<hr></div>'
	return#END: getGII 

# +-------------------------------------------------------------------+
# | function:  getThreadDump
# +-------------------------------------------------------------------+
# | Desc: Generate the Thread Dump for AdminServer and oacore_server1
# +-------------------------------------------------------------------+
# | Args: HTML Output File 
# +-------------------------------------------------------------------+
# | Returns: nada
# +-------------------------------------------------------------------+
def getThreadDump(logfile):
	print >>logfile, '''<div class="divItem">
     <div class="divItemTitle">Thread Dump Info</div>'''
	
	print >>logfile, '''Thread Dumps have been dumped to the <a href="#top" onclick="activateTab('page2'); return true;" href="javascript:;">Thread Dump Button</a>
	<br><br>For a more detailed Thread Dump run: &quot; jstack -F $pid >jstack.$pid.$(date +%H%M%S.%N) &quot; or &quot; kill -3 &lt;pid&gt; &quot;''' 
#   5/15/2017 -- update for mutli-node system
	servers = domainRuntimeService.getServerRuntimes()
	for server in servers:
		threadDump()
		threadDump(serverName=server.getName())
		
	print >>logfile, '</div>'
	return
#END: getThreadDump 

# +-------------------------------------------------------------------+
# | function:  logger
# +-------------------------------------------------------------------+
# | Desc: write to main WLSU log (created by perl prog) 
# +-------------------------------------------------------------------+
# | Args: mesg to write 
# +-------------------------------------------------------------------+
# | Returns: nada
# | 
# +-------------------------------------------------------------------+
def logger(mesg):
	ts = datetime.now()  
	print >>mainLog, "###<Python Logger %s>" % ts  
	print >>mainLog, "%s" % mesg 
	print >>mainLog, "####"  
	return 
#END: logger 

# +-------------------------------------------------------------------+
# | function:  getAIX
# +-------------------------------------------------------------------+
# | Desc: get Linux CPU/mem/swap info from "top" and format into html 
# +-------------------------------------------------------------------+
# | Args: n/a
# +-------------------------------------------------------------------+
# | Returns: tableList[] 
# | 0 = top CPU consuming processes 
# | 1 = CPU usage total (none avail for AIX as of 11/15/2017 
# | 2 = Memory usage total 
# | 3 = swap usage total 
# +-------------------------------------------------------------------+
def getAIX():
	tableList = ['','','','']
	topProc = os.popen('ps aux | head -1; ps aux | sort -rn +2 | head -10',"r").read()
	tableList[1] = '''<p> No CPU Usage Info Available on AIX </p>''' 
	mem = os.popen("svmon | grep memory", "r").read() 
	swap = os.popen("svmon | grep '^pg'", "r").read()
	swap = re.sub('pg\sspace','pg&nbsp;space',swap)

	#gen proc table 
	tableList[0] = '''<table><!--START tables--> \n <table class="table1"><tbody>\n\n'''
	mySplit = re.split("\n", topProc) 
	cnt = 0; 
	for spl in mySplit:
		if (len(spl) < 1):
			continue
		cnt += 1 
		if cnt > 1: 
			tableList[0] += '\n <tr><td>';
			spl = re.sub('^\s+','' , spl);
			spl = re.sub('\s+','  </td>\n <td>' , spl);
			spl = re.sub('\s+$','', spl);
			tableList[0] += spl;
			tableList[0] += '</td>\n</tr>\n\n';
		else: 
			tableList[0] += '\n <tr><th>';
			spl = re.sub('^\s+','' , spl);
			spl = re.sub('\s+','  </th>\n <th>' , spl);
			spl = re.sub('\s+$','', spl);
			tableList[0] += spl;
			tableList[0] += '</th>\n</tr>\n\n';
		
		tableList[0] = re.sub('\<td\>\<\/td\>','',tableList[0]); 
	tableList[0] += '''\n\n</tbody></table>\n <!-- END topProc --> \n\n''';
	# print >>myOut, "%s" % tableList[0]

	#gen CPU table 
	# tableList[1] = '''<table class="table1"><tbody>\n\n'''; 
	# mySplit = re.split("\n", cpu) 
	# for spl in mySplit:
		# if (len(spl) < 1): 
			# continue 
		# spl = re.sub('\s+','</td><td>' , spl);
		# spl = re.sub('^','  <tr><td>', spl); 
		# spl = re.sub('$','</td></tr>\n', spl);
		# tableList[1] += spl; 
	# tableList[1] += '''\n\n</tbody></table>\n <!-- END CPU -->\n\n''';

	#gen mem table 
	tableList[2] = '''<table class="table1"><tbody>
	
	<tr>
	
	<th></th>
	<th>Size</th>
	<th>inuse</th>
	<th>free</th>
	<th>pin</th>
	<th>virtual</th>
	<th>mmode</th>
	
	</tr> 
	''' 
	
	mySplit = re.split("\n", mem) 
	for spl in mySplit:
		if (len(spl) < 1): 
			continue 
		spl = re.sub('\s+','</td><td>' , spl);
		spl = re.sub('^','  <tr><td>', spl); 
		spl = re.sub('$','</td></tr>\n', spl);
		tableList[2] += spl; 
	tableList[2] += '''\n\n</tbody></table>\n <!-- END mem -->\n\n''';

	#swap stats 
	tableList[3] = '''<table class="table1"><tbody>
	
	<tr>
	
	<th></th>
	<th>Size</th>
	<th>inuse</th>
	<th>free</th>
	<th>pin</th>
	<th>virtual</th>
	<th>mmode</th>
	
	</tr> 
	'''  
	mySplit = re.split("\n", swap) 
	for spl in mySplit:
		if (len(spl) < 1): 
			continue 
		spl = re.sub('\s+','</td><td>' , spl);
		spl = re.sub('^','  <tr><td>', spl); 
		spl = re.sub('$','</td></tr>\n', spl);
		tableList[3] += spl; 
	tableList[3] += '''\n\n</tbody></table>\n <!-- END swap -->\n\n</table><!--END OS tables --> ''';

	return tableList  
## END getAIX ## 


# +-------------------------------------------------------------------+
# | function:  getUnixGeneric
# +-------------------------------------------------------------------+
# | Desc: get UNIX CPU/mem/swap info from "top" and format into html 
# +-------------------------------------------------------------------+
# | Args: n/a
# +-------------------------------------------------------------------+
# | Returns: tableList[] 
# | 0 = top 5 CPU processes
# | 1 = cpu usage from "top" 
# | 2 = memory usage from "top" 
# | 3 = swap stats from "top" 
# +-------------------------------------------------------------------+
def getUnixGeneric():
	tableList = ['','','','']

	#later this can be fleshed out with HP & Sun / Solaris specific commands if needed
	# no access to Sun / HPUX at the time being to create those 
	# specific functions 
	# memory
	osMem = os.popen("vmstat -s | grep -i mem","r").read() 
	osMem = re.sub('\n','<br>',osMem) 
	tableList[2] = re.sub('\s','&nbsp;',osMem) 
	# swap 
	osSwap = os.popen("vmstat -s | grep -i swap","r").read() 
	osSwap = re.sub('\n','<br>',osSwap) 
	tableList[3]  = re.sub('\s','&nbsp;',osSwap) 
	# CPU 
	osCpu = os.popen('iostat -c',"r").read()
	osCpu = re.sub('\n','<br>',osCpu) 
	tableList[1] = re.sub('\s','&nbsp;',osCpu) 
	#top CPU processes 
	topProc = os.popen('ps -aux | head -10',"r").read() 
	topProc = re.sub('\n','<br>',topProc) 
	tableList[0] = re.sub('\s','&nbsp;',topProc) 
	
	return tableList
## END getUnixGeneric ## 

# +-------------------------------------------------------------------+
# | function:  getSun
# +-------------------------------------------------------------------+
# | Desc: get Sun/Solaris CPU/mem/swap info from "top" and format into html 
# +-------------------------------------------------------------------+
# | Args: n/a
# +-------------------------------------------------------------------+
# | Returns: tableList[] 
# | 0 = top 5 CPU processes
# | 1 = cpu usage from "top" 
# | 2 = memory usage from "top" 
# | 3 = swap stats from "top" 
# +-------------------------------------------------------------------+
def getSun():
	tableList = ['','','','']
	
	return tableList 

# +-------------------------------------------------------------------+
# | function:  getHP
# +-------------------------------------------------------------------+
# | Desc: get HP-UX CPU/mem/swap info from "top" and format into html 
# +-------------------------------------------------------------------+
# | Args: n/a
# +-------------------------------------------------------------------+
# | Returns: tableList[] 
# | 0 = top 5 CPU processes
# | 1 = cpu usage from "top" 
# | 2 = memory usage from "top" 
# | 3 = swap stats from "top" 
# +-------------------------------------------------------------------+
def getHP():
	tableList = ['','','','']

	return tableList 


# +-------------------------------------------------------------------+
# | function:  getLinux
# +-------------------------------------------------------------------+
# | Desc: get Linux CPU/mem/swap info from "top" and format into html 
# +-------------------------------------------------------------------+
# | Args: n/a
# +-------------------------------------------------------------------+
# | Returns: tableList[] 
# | 0 = top 5 CPU processes
# | 1 = cpu usage from "top" 
# | 2 = memory usage from "top" 
# | 3 = swap stats from "top" 
# +-------------------------------------------------------------------+
def getLinux():
	tableList = ['','','','']
	# topProc = os.popen(" top -n 1 -b | head -12 | tail -6", "r").read() 
	cmd = "top -c -bn 1 | grep \'^\' | awk \'{ printf(\"%-8s %-8s %-8s  %-8s  %-8s\\n\", $1, $2, $9, $10, $12); }\' | head -n 15 | tail -9"
	topProc = os.popen(cmd, "r").read() 
	cpu = os.popen("top -n 1 -b | grep \"^Cpu\"", "r").read() 
	mem = os.popen("top -n 1 -b | grep Mem:", "r").read() 
	swap = os.popen("top -n 1 -b | grep Swap:", "r").read() 
	mem = re.sub(',','',mem) 
	swap = re.sub(',','',swap) 
	mem = re.sub('k\s','k&nbsp;',mem) 
	swap = re.sub('k\s','k&nbsp;',swap) 
	
	#gen top proc table 
	tableList[0] = '''\n<table>\n  <!--START tables--> \n <table class="table1">\n<tbody>\n\n'''
	mySplit = re.split("\n", topProc) 
	cnt = 0 
	for spl in mySplit:
		if (len(spl) < 1):
			continue
		cnt += 1 
		if cnt == 1:
			tableList[0] += '\n <tr><th>';
			spl = re.sub('^\s+','' , spl);
			spl = re.sub('\s+','  </th>\n <th>' , spl);
			spl = re.sub('\s+$','', spl);
			tableList[0] += spl; 
			tableList[0] += '</th>\n</tr>\n\n';
		else:
			tableList[0] += '\n <tr><td>';
			spl = re.sub('^\s+','' , spl);
			spl = re.sub('\s+','  </td>\n <td>' , spl);
			spl = re.sub('\s+$','', spl);
			tableList[0] += spl; 
			tableList[0] += '</td>\n</tr>\n\n';
			
		tableList[0] = re.sub('\<th\>\<\/th\>','',tableList[0]); 
		tableList[0] = re.sub('\<td\>\<\/td\>','',tableList[0]); 
	tableList[0] += '''\n\n</tbody></table>\n <!-- END topProc --> \n\n''';
	# print >>myOut, "%s" % tableList[0]

	#gen CPU table 
	tableList[1] = '''<table class="table1"><tbody>\n\n'''; 
	mySplit = re.split("\n", cpu) 
	for spl in mySplit:
		if (len(spl) < 1): 
			continue 
		spl = re.sub('\s+','</td><td>' , spl);
		spl = re.sub('^','  <tr><td>', spl); 
		spl = re.sub('$','</td></tr>\n', spl);
		tableList[1] += spl; 
	tableList[1] += '''\n\n</tbody></table>\n <!-- END CPU -->\n\n''';

	#gen mem table 
	tableList[2] = '''<table class="table1"><tbody>\n\n'''; 
	mySplit = re.split("\n", mem) 
	for spl in mySplit:
		if (len(spl) < 1):  
			continue 
		spl = re.sub('\s+','</td><td>' , spl);
		spl = re.sub('^','  <tr><td>', spl); 
		spl = re.sub('$','</td></tr>\n', spl);
		tableList[2] += spl; 
	tableList[2] += '''\n\n</tbody></table>\n <!-- END mem -->\n\n''';

	#swap stats 
	tableList[3] = '''<table class="table1"><tbody>\n\n'''; 
	mySplit = re.split("\n", swap) 
	for spl in mySplit:
		if (len(spl) < 1): 
			continue 
		spl = re.sub('\s+','</td><td>' , spl);
		spl = re.sub('^','  <tr><td>', spl); 
		spl = re.sub('$','</td></tr>\n', spl);
		tableList[3] += spl; 
	tableList[3] += '''\n\n</tbody></table>\n <!-- END swap -->\n\n</table><!--END OS tables --> ''';

	return tableList  
## END getLinux ## 

#run main 
mainRun()
mainLog.close() 