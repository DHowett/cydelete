#!/bin/bash
export PATH=/usr/bin:/bin:/sbin:/usr/sbin
rm /tmp/cydiapipe &> /dev/null
exec 3<>/tmp/cydiapipe
export CYDIA="3 1"
/usr/bin/dpkg -r $1 &>/dev/null
exitcode=$?
echo -n $(cat /tmp/cydiapipe | cut -d':' -f2)
rm /tmp/cydiapipe &> /dev/null
exit $exitcode
