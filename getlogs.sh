#!/bin/bash
# parms:
#       channel year month
#
# Download all logs for the channel for the given year/month
#
for option in "$@"; do
    case "$option" in
    -h | --help)
    echo "Download irclogs from any ubuntu channel for a specific month"
    echo "Usage: bash getlogs.sh channel year month"
    echo "For example, to download logs from #ubuntu in August 2012,"
    echo "and store them in ~/irclogs/ubuntu/2012/08/ ..."
    echo "       bash getlogs.sh ubuntu 2012 08"
    exit 0 ;;
    esac
done

### Present Y/N questions and check response 
### (a valid response is required)
### Parameter: the question requiring an answer
### Returns: 0 = Yes, 1 = No
test_YN ()
{
    while true; do 
      echo "$@"
      read input
      case "$input" in 
        "y" | "Y" )
          return 0 ;;
        "n" | "N" )
          return 1 ;;
        * )
          echo "Invalid response ('$input')"
      esac
    done
}

# strip off any leading # from the channel name
channel=${1##\#}

# check the 4 digit year is numeric and >= 2004
year=$2
if ! [[ "$year" =~ ^[0-9]+$ ]] ; then
  exec >&2
  echo "Year $year has to be a valid year"
  exit 1
fi
if [ $year -lt 2004 ]; then
  exec >&2
  echo "Earliest year is 2004; inputted value invalid:$year "
  exit 1  
fi

# check the month is valid and determine the last day of the month
month=$3
case $month in 
1|3|5|7|8|10|12)
 lastday=31
 ;;
4|6|9|11)
 lastday=30
 ;;
2)
 lastday=28
 if [ $[$year % 400] -eq "0" ]; then
   lastday=29
 elif [ $[$year % 4] -eq "0" ]; then
   if [ $[$year % 100] -ne 0 ]; then
     lastday=29
   fi
 fi
 ;;
*)
 exec >&2
 echo "Invalid month: "$month""
 exit 1
 ;;
esac
month=$(printf %02d "$3") #make month two digits
day=1

# if the current month, don't request logs for days in the future (UTC)
# and make sure the year/month isn't in the future
currentDate=`date -u +%s`
startDate=`date -d $year$month$(printf %02d "$day") -u +%s`
if [ $startDate -gt $currentDate ]; then
  exec >&2
  echo "Can't download logs in the future"
  exit 1
fi

# get the no. days between startdate and current date
maxDays=$((((currentDate-startDate)/86400)+1))
#echo $maxDays
if [ $maxDays -le $lastday ]; then
    lastday=$maxDays
fi

echo ""
if [ "$4" != "y" ]; then
 message="Download logs from #"$channel" for "$year"-"$month"-$(printf %02d "$day") to "$year"-"$month"-$(printf %02d "$lastday")"
 test_YN ""$message" (Y/N)"
 # User pressed N
 if [ "$?" -eq "1" ]; then
   echo "Canceled"
   exit 0
 fi
fi

# Don't redownload for a month that exists already (just check if the 
# directory exists)
mkdir -p ~/irclogs/$channel/$year
mkdir ~/irclogs/$channel/$year/$month > /dev/null 2>&1
# can quick exit here, but we also check the log file prior to
# downloading so, this is better (to recover from previous time out with partial download)
#if [ $? -ne 0 ]; then
#  exec >&2
#  echo "Already downloaded for $year/$month"
#  exit 1
#fi

# download the .txt log for each day of the month
while [ "$day" -le $lastday ]
do
  twodigitday=$(printf %02d "$day")
  logaddress=http://irclogs.ubuntu.com/$year/$month/$twodigitday/%23$channel.txt
  savefile=~/irclogs/$channel/$year/$month/$channel$year-$month-$twodigitday.txt
  if [ -f "$savefile" ]; then
   # already downloaded so skip
    echo Already downloaded $logaddress
  else
    echo downloading $logaddress
    wget --output-document=$savefile --progress=dot $logaddress > /dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
#      grep -i $searchterm $savefile > /dev/null 2>&1
#      rc=$?
#      if [ "$rc" -ne 0 ]; then
#        rm $savefile > /dev/null 2>&1
#      else
#        echo Found $searchterm in $savefile
#      fi
#    else
      echo Download of $logaddress failed
    fi
  fi
  day=$[$day+1]
done

