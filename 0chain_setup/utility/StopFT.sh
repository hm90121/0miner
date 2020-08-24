#!/bin/bash
FTPID=`ps -ef | grep faultTolerance.sh | grep -v grep | awk '{print $2}'`

if [[ -z "$FTPID" ]]; then
echo "No process id found"
else
echo -e "Killing the process ID: $FTPID \n"
kill -9 $FTPID
fi
