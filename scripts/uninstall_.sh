#!/bin/bash
echo Uninstalling $1...
export PATH=/usr/bin:/bin:/sbin:/usr/sbin
rm /tmp/cydiapipe &> /dev/null
exec 3<>/tmp/cydiapipe
export CYDIA="3 1"
/usr/bin/dpkg -r $1 2>&1
exitcode=$?
cat /tmp/cydiapipe
rm /tmp/cydiapipe &> /dev/null
exit $exitcode
