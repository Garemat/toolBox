# toolBox

Simple toolbox to house some Scripts

### nexusPull
This script will pull artifacts from a nexus repo based on a configuration file. A secrets file contains the ftp user and ftp password. This script currently rusn from a mac, because of the SFTP issues i've had it opens a FileZilla window, so some manual input is required atm. For unix replace all fillzilla mentions with sftp (or other protocol) and use -b batchfile to move artifacts over
Configuration is in XML - example items:
`<version>52.0.2</version> - version to download
<host>Hostname</host> - Current WIP to work alongside automate deployment.bat
<dirname>deploy/</dirname> - Remote directory
<zipName>application.zip</zipName> - Zip file name, WIP to work alongside automate deployment.bat`

### CheckPackages
This has a few functions that are highlighted from the top of the shell script
The main use is to pull package length from an sql databse to ensure that the same packages are deployed in different environments. This is purely a discovery tool and will tell you if there are any discrepancies

### Automate deployment.bat
This is designed to run in the background on a remote host that will deploy to a different remote host. This is handy when working with remote desktop connections that restrict direct access to a unix box. For example:

Working machine ---> RDP session ----> remote unix box

When transferring files to the RDP session this script will pick up the artifacts and deploy them to the remote unix box based on a configuration file

### Download.py
This works alongside nexusPull to retrieve artifacts from a nexus repo. This works from an XML config file in the format of:
`<?xml version="1.0"?>
  <applications>
    <application>APPNAME</application>
      <repo>http://repourl/repo/foo/blah</repo>
      <artifact>
        <name>FirstartifactName</name>
        <extension>.war</extension>
      </artifact>
      <artifact>
        <name>secondartifactName</name>
        <extension>.jar</extension>
      </artifact>
  </applications>`
Add extra artifact blobs for each artifact you want to download
