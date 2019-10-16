#! /bin/bash
#This script will check package length from an SQL database and has a few different options for checking against:
#A local instance, a generated file or a remote databse connection
#/bin/bash/
#Workign directory on both host and remote
wd=/tmp

out=$wd/out.info
out2=$wd/out2.info
#SQL script name
sscript=$wd/_tmp.sh

#If local file for local comapre is enbaled (irrelevant for just generating info file)
lf=false

####################################Instruction guide###################################
##TODO make this blob output as part of the help screen
#Where I mention host, it's the server that the script is being run on
#Currently there's specification of the oracle_sid, it will pick it up from the environment vars
#This script will default run a package info grab on the host the script it's being run on
#In order to run it either needs the -r flag or the -l flag
#-r will specify that you're running it against a remote host, so it will run the package grab on the host then to the specified remote
#-l (folloed by a filename) will comapre it against a local file generated with the -g flag, it will run on the host then diff the specified file
#Running with -g will specify that it won't run a compare, using -l when the -g flag is active will spcify the name of the file
#-u is the username for the host DB
#-p is the password the host db
#-y is the username for the remote host, if unspecified it wil use the same username from -u
#-t is the password for the remote host, if unspecified it will use the same password from -p
#-g doesn't take a parameter, it highlights that will generate a comapre file, this is usefull if you want to move it across envrionments
#########################################################################################


#Help function due to how many params this could take - this is more of an example screen, need to flesh out the help bit a tad more
function helpOptions {
  div========================
  div=$div$div$div

  header="\n %-10s %18s %20s %15s\n"
  format=" %-10s %18s %20s %7s\n"

  width=61

  printf "$header" "PARAMETER" "ARUGMENT" "EXAMPLE" "REQUIRED (Y/N)"
  printf "%$width.${width}s\n" "$div"

  printf "$format" \
  -u username DBUser Y \
  -p password Pa22w0rd Y \
  -l localFile tableDump.sql N \
  -r remotDBHost mySite N \
  -y remoteDBUsername DBUser2 N \
  -t remoteDBPassword Pa22w0rd2 N \
  -g generateLocal "Use with -l" N \
  -h Help "This screen" N
}

#Define parameters
while getopts ":u:p:r:y:t:l:gh" opt; do
  case $opt in
    u) user=$OPTARG >&2;;
    p) pass=$OPTARG >&2;;
    r) remoteHost=$OPTARG >&2;;
    y) remoteDBUser=$OPTARG >&2;;
    t) remoteDBPass=$OPTARG >&2;;
    l) localFile=$OPTARG >&2;;
    h) helpOptions; exit 1;;
    g) generateLocal=true >&2;;
    \?) echo "Uknown option -$OPTARG. Use -h for help" >&2; exit 1;;
    :) echo "Option -$OPTARG requires an argument. Use -h for help" >&2; exit 1;;
  esac
done

#Checks if username and password have been added, if not tell user
if [ "$user" = "" ] || [ "$pass" = "" ]; then
  echo "Mising credentials"
   if [ "$user" = "" ]; then
       echo "use -u to specify database connection username"
   fi
   if [ "$pass" = "" ]; then
      echo "Use -p to specify database connection password"
  fi
 exit 1
fi

#Check if remote host has been specified, if not check local file name is empty, then check if -g flag has been set
if [ "$remoteHost" = "" ]; then
  if [ "$localFile" = "" ]; then
   if [ "$generateLocal" = "true" ]; then
     echo "Use -l to specify local file name"
     exit 1
   else
     echo "Use -r to specify remote host to compare against or -l to specify local file"
     exit 1
   fi
  echo "Using local file"
  lf=true
 fi
fi

##TODO update exit tokens to output message too reduce some bulk

#Sets the output name if it's only generating a local file
if ! [ "$generateLocal" = "" ]; then
  out=$localFile
fi

#Creates script file to connet to SQL, saves writing out the block twice
printf "Pulling package infromation from "
hostname -s
echo Connecting to SID: $ORACLE_SID
cat <<EOC >$sscript
sqlplus $user/$pass <<EOF >/dev/null 2>&1

SET HEAD OFF
SET ECHO OFF
SET FEED OFF
SET TERM OFF
SET NEWPAGE NONE
SPOOL $out
PROMPT CREATE OR REPLACE
select name,sum(length(text)) from user_source where type like 'PACKAGE%' group by name;
SPOOL OFF
exit
EOF
EOC

source $sscript

if ! [ "$generateLocal" = "" ]; then
  echo "output saved as: $(readlink -f $localFile)"
  exit 1
fi

if [ $lf = "false" ]; then
  echo Move output and shells script

  scp $out $sscript root@$remoteHost:$wd/

  #Check optional parameters
  if ! [ "$remoteDBUser" = "" ]; then
    echo remote user detected
    user=$remoteDBUser
  fi

  if ! [ "$remoteDBPass" = "" ]; then
    pass=$remoteDBPass
  fi

#Using SED rather than rebuilding sql file because quicker
  #Note that the exessive amount of /\ are required to escape characters in replacement strings and user/pass
  if ! [ "$remoteDBUser" = "" ] || ! [ "$remoteDBPass" = "" ]; then
    replaceString=$(sed '1q;d' $sscript)
    replaceWith="sqlplus ${user}/${pass} <<EOF >/dev/null 2>&1"
    sed -i "/${replaceString//\//\\/}/c ${replaceWith//\//\/}" $sscript
  fi

  echo Connecting to remote host

  ssh root@$remoteHost sscript="$sscript" out="$out" out2="$out2" bash -s <<'EORS'
    su -c "source $sscript" - oracle
    diff -y $out $out2
EORS

else
  diff -y $out $localFile
fi
