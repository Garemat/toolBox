#! /bin/bash
if ! command -v python3 &>/dev/null; then
  echo "Python 3 not detected, please install"
  exit 1;
fi

#sets current path that THE SCRIPT is running from, equiv of running pwd from the script directoy
path="$( cd "$(dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

GRMT=$(echo onfr64 --qrpbqr | tr '[a-z]' '[n-za-m]')

#Config file in the format of var:value
configFile=$(cat $path/config)
secrets=$(cat secrets | $GRMT)


#ftp method here from mac using FileZilla
ftpUser=$(echo secrets | sed 's/ftpUser://')
ftpPass=$(echo secrets | sed 's/ftpPass://')

#Variables from config file
version=$(echo $configFile | sed 's/version://')
remoteDirectory=$(echo $configFile | sed 's/dirname://')
zipName=$(echo $configFile | sed 's/zipName://')

ftpConfig=~/.config/filezilla/sitemanager.xml

#This will strip the XML node from the FileZilla config file, if you have another host using 'net' in your saved files add some unique values until it only pulls the right one
#Yes this is lazy but it works for me
node=$(perl -ne 'BEGIN{$/="</Server>\n";} print m|(<Host>.*net*$/)|ms' $ftpConfig)
host=$(echo $node | sed 's/^.*<Host>//;s/<\/Host>.*//')
user=$(echo $node | sed 's/^.*<User>//;s/<\/User>.*//')
password=$(echo $node | sed 's/^.*">//g;s/<\/Pass>.*//' | $GRMT)

echo "Lazily cleaning directories"
rm -rf $path/artifacts/
rm -rf $path/ftp/
mkdir $path/artifacts
mkdir ftp

echo "Pulling $version from nexus"
echo python3 download.py -v $version -u "$ftpUser" -p "$ftpPass"

echo "Zipping file"
zip -r -j -q $path/ftp/$zipName $path/artifacts/*

#Remote .bat file waits for 'start' file so it doens't start deploying while the zip is half transfered
touch $path/ftp/start
echo "FTPES restriction through comamnd line. Copy $zipName to opened directory"
echo "After transfer has finished copy start file to host"
/Applications/FileZilla.app/Contents/MacOS/filezilla -a $path/ftp ftpes://$user:$password@$host/$remoteDirectory
