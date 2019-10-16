@echo off

::This script is run in the bakcground to deploy an application when it's transferred to an ftp server under \deploy
::This is run with conjunction with nexusPull.sh

set remoteHost="FTPHost"
set remoteDrive="\\%FTPHost%\Deploy"
set APP="APP"
set zipName="%remoteDrive%\%APP%.zip"
set goFile="%remoteDrive%\start"
set logFile="%remoteDrive%\log.txt"
set doneFile="%remoteDrive%\FINISHED"
set zZip="C:\Program Files\7-Zip\7z.exe"
set artifacts="%cd%\artifacts"
set FTP="C:/Program Files (x86)/WinSCP/WinSCP.com"
set putty="C:/Program Files (x86)/PuTTY/plink.exe"
set pd="_d.py"
set bd="_b.sh"
set td="_t.sh"
set fs="_f.py"

echo Process created. Detecting start File

:: PING 1.1.1.1 -w 500 is a hacky way for the system to pause
:detectStartFile
if not exist %goFile% (
PING 1.1.1.1 -n 10 -w 500 >nul 2>&1
GOTO detectStartFile
)

:: Delete done file and start running MAIN function
if exist %doneFile% (del /s /q %doneFile%)
call :MAIN >%logFile%
echo done >%doneFile%
GOTO detectStartFile

:MAIN
::Failsafe check for the go file just in case...
	if exist %goFile% (

		del /s /q %goFile%
		if not exist %zipName% (
			echo Please ensure zip file is called %APP%.zip and recreate start file
			goto detectStartFile
		)
		echo Zip file detected. Starting Deployment...

		if exist %artifacts% (
			echo Removing previous artifacts
			del /s /q %artifacts%
		)
			echo Creating artifact directory
			mkdir %artifacts%

		if exist %zZip% (
			echo Extracting with 7-Zip
			%zZip% x %zipName% -o%artifacts%
		) ELSE  (
			echo Extracting with VB
			Call :Unzip "%artifacts%\" %zipName%
		)

::Mac files won't cause a crash, just ugly messages
		if exist %artifacts%\__MACOSX (
			echo Discovered mac files, deleting...
			del /s /q %artifacts%\__MACOSX
			del /s /q %artifacts%\MACOSX
		)

::Remove version numbers if they're present
		FOR /F "skip=2" %%G in ('dir /b %artifacts%') do (
			if "%%G"=="application.war" goto skipRename
		)

::This will also remove any other exentions in the zip file buttttt lazy
			echo Removing version numbers from files
			cd %artifacts%\
			powershell.exe -Command "get-Childitem | rename-item -NewName { $_.name -replace('[^a-zA-Z-]', '')}"
			powershell.exe -Command "get-Childitem | rename-item -NewName { $_.name -replace('(.*)-(.*)','$1.$2')}"
			cd ..\

			:skipRename
			echo Artifacts okay
			echo Reading Config file
:: Exessive statement to pull host name from config file
			FOR /f "delims=" %%x in ('powershell.exe -Command "get-content %artifacts%\config | where {$_ -match \"host\"} | forEach-Object {$_.Split(\":\")[-1]}"') do set "host=%%x"
			echo host name is %host%
			goto %host%

::In order to only transfer the one deployment file around all of the SQL/SH scripts are at the bottom of this file
			:posthost
			echo Creating remote scripts
::Calling a function puts the script back up here when it's complete rather than exessive gotos
			Call :initFiles

			echo Transferring files to %host%
			set FTPString=%user%:%password%@%WLhostName%:22
			%FTP% /command "open sftp://%FTPString%" "option confirm off" "put %pd% %UIdeploymentLocation%/" "exit"
			%FTP% /command "open sftp://%FTPString%" "option confirm off" "put %fs% %UIdeploymentLocation%/" "exit"
			%FTP% /command "open sftp://%FTPString%" "option confirm off" "put %artifacts%\ui.war %UIdeploymentLocation%/" "exit"
			%FTP% /command "open sftp://%FTPString%" "option confirm off" "put %artifacts%\liquibase.jar %LBdeploymentLocation%/" "exit"
			%FTP% /command "open sftp://%FTPString%" "option confirm off" "put %artifacts%\batchjob.jar %batchLocation%/" "exit"

			echo Truncating DB...
			%putty% -t -ssh %DBuser%@%DBhostName% -pw %DBpassword% -m %td%
			echo Running shell scriptt...
			%putty% -t -ssh %user%@%WLhostName% -pw %password% -m %bd%

			echo cleaning files...
			del /f /q %td% %pd% %bd%
			echo DEPLOYMENT COMPLETE

		)

::This kills off the called main method gracefully and rechecks for when start file is there again
exit /b

::This is an example of the host configuration, the value straight after : is what will be used for the hostname
::In this case the config file will say weblogicHost for the deployment location
::TODO refactor this bit out of the bat file and into a seperate configurationFile
::WLhostName needs to be in octal format
:weblogicHost
	set WLhostName=***.***.***.***
	set domainLocation=/opt/user_projects/domains/myDomain
	set UIdeploymentLocation=%domainLocation%/deployment/UI
	set LBdeploymentLocation=%domainLocation%/liquibase
	set batchLocation=/opt/properties/batch
	set mw_home=/opt/wlserver_10.3
	set wlst=%mw_home%/common/bin/wlst.sh
	set wlse=%mw_home%/server/bin/setWLSEnv.sh
	set serverName=FrontEnd_01
	set appName=ui
	set user=user
	set password=password
	set DBhostName=DBHost
	set DBuser=DBUser
	set DBpassword=password
	set DBSID=sid
	set schema=liquibaseSchema
	set schemaPassword=liquibasePassword
	goto posthost


:initFiles
echo Cleaning previous temp files
if exist %td% del /f /q %td%
if exist %bd% del /f /q %bd%
if exist %fs% del /f /q %fs%
if exist %pd% del /f /q %pd%

echo Creating WLST python script...
Call :pythonDeployment >%pd%

echo Creating Remote shell script...
Call :bashDeployment >%bd%

echo Creating Trunc script...
Call :trunc >%td%
::Extra forcestart script for testing
Call :forceStart >%fs%
echo Scripts created
exit /b

::Truncate script for DB maintenance
:trunc
echo:su -c "sqlplus / as sysdba" - oracle ^<^<EOF
echo:set linesize 120
echo:set heading on
echo:set termout on
echo:truncate table *TABLENAME* drop storage;
echo:exit;
echo:EOF
exit /b

:bashDeployment
echo:BATCHPROP=%batchLocation%/BatchScheduling.properties
echo:filePath=%UIdeploymentLocation%/%appName%
echo:chown oracle:oinstall %UIdeploymentLocation%/ui.war
echo:chmod -R 777 %UIdeploymentLocation%/ui.war
echo:chown oracle:oinstall %LBdeploymentLocation%/liquibase.jar
echo:chmod -R 777 %LBdeploymentLocation%/liquibase.jar
echo:chown oracle:oinstall %UIdeploymentLocation%/deployment.py
echo:chmod -R 777 %UIdeploymentLocation%/deployment.py
echo:chown oracle:oinstall %batchLocation%/batchjob.jar
echo:chmod -R 777 %batchLocation%/batchjob.jar
echo:username=$(sed -n 2p %domainLocation%/servers/AdminServer/security/boot.properties ^| sed 's/^^[^^=]*=//g')
echo:password=$(sed -n 3p %domainLocation%/servers/AdminServer/security/boot.properties ^| sed 's/^^[^^=]*=//g')
echo:sudo -u oracle %wlst% %UIdeploymentLocation%/%pd% $username $password %WLhostName% deploy %serverName% %appName% $filePath
echo:sudo -u oracle java -jar %LBdeploymentLocation%/liquibase.jar --driver=oracle.jdbc.OracleDriver --classpath="%mw_home%/server/lib/ojdbc6.jar:%LBdeploymentLocation%/liquibase.jar" --changeLogFile=db/changelog/db.changelog-master.xml --url=jdbc:oracle:thin:@//%DBhostName%:1521/%DBSID% --username=%schema% --password=%schemaPassword% --contexts="dev-data" --logLevel=debug --logFile=%LBdeploymentLocation%/logUpdateAll.log update
echo:REPLACE1=$(sed '5q;d' $BATCHPROP)
echo:DATE1=$(date --date="+3 minutes" +"cronScheduler=00 %%M %%H * * *")
echo:sudo -u oracle sed -i "/${REPLACE1}/c ${DATE1}" $BATCHPROP
echo:cd %batchLocation%
echo:java -Xmx1024m -Denvironment.config="%batchLocation%/" -Dis.sql=true -Dspring.batch.job.enabled=false -jar "%batchLocation%/batchjob.jar"
exit /b

:forceStart
echo:  state(%serverName%)
echo:  try:
echo:    start(%serverName%)
echo:  except Exception, e:
echo:    print('Failed to start, maybe it was already running')
echo:  try:
echo:    startApplication('ui')
echo:  except Exception, e:
echo:    print 'Error deploying or starting application',e
echo:    dumpStack()
exit /b

:pythonDeployment
echo:import sys
echo:def stopServer(serverName):
echo:  state(serverName)
echo:  try:
echo:    shutdown(serverName, force='true')
echo:  except Exception, e:
echo:    print('failed to shutdown, maybe was shutdown already')
echo:def startServer(serverName):
echo:  state(serverName)
echo:  try:
echo:    start(serverName)
echo:  except Exception, e:
echo:    print('Failed to start, maybe it was already running')
echo:  try:
echo:    startApplication('ui')
echo:  except Exception, e:
echo:    print ("Error deploying or starting application")
echo:    dumpStack()
echo:def Redeploy(appName, filePath, server):
echo:  edit()
echo:  startEdit()
echo:  try:
echo:    undeploy(appName)
echo:  except Exception, e:
echo:    print ("Error undeploying application")
echo:    dumpStack()
echo:  try:
echo:    deploy(appName, filePath, targets=server, timeout=120000)
echo:  except Exception, e:
echo:    print ("Error deploying or starting application")
echo:  print("Activating application deployments")
echo:  try:
echo:    activate()
echo:  except Exception, e:
echo:    print ("Error Activating but starting it deploys it so shrug")
echo:def decrypt(crypto):
echo:  domain = '%domainLocation%/'
echo:  service = weblogic.security.internal.SerializedSystemIni.getEncryptionService(domain)
echo:  encryption = weblogic.security.internal.encryption.ClearOrEncryptedService(service)
echo:  return encryption.decrypt(crypto)
echo:def main():
echo:  encryptedUser = sys.argv[1]
echo:  encryptedPass = sys.argv[2]
echo:  username = decrypt(encryptedUser)
echo:  password = decrypt(encryptedPass)
echo:  host = 't3://%%s:7001' %% (sys.argv[3])
echo:  serverName = sys.argv[5]
echo:  appName = sys.argv[6]
echo:  filePath = sys.argv[7]
echo:  connect(username, password, host)
echo:  stopServer(serverName)
echo:  Redeploy(appName, filePath, serverName)
echo:  startServer(serverName)
echo:  disconnect()
echo:  exit()
echo:main()
echo:exit()
exit /b

::VB to unzip file if z-zip isn't detected - since this is rarley applicable keep all references to it at the bottom
:Unzip <to> <from>
set vbs="_.vbs"
if exist %vbs% del /f /q %vbs%
>%vbs% echo set fso = CreateObject("Scripting.FileSystemObject")
>>%vbs% echo if NOT fso.FolderExists(%1) Then
>>%vbs% echo fso.CreateFolder(%1)
>>%vbs% echo End If
>>%vbs% echo set objShell = CreateObject("Shell.Application")
>>%vbs% echo objShell.NameSpace(%1).CopyHere objShell.NameSpace(%2).Items
>>%vbs% echo set objShell = Nothing
cscript //nologo %vbs%
if exist %vbs% del /f /q %vbs%
exit /b
