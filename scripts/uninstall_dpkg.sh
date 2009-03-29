#!/bin/bash
export PATH=/usr/bin:/bin:/sbin:/usr/sbin
export CYDIA="2 1"
apt-get -y remove $1 2>&1 1>/dev/null | grep finish > /tmp/cydiapipe
exitcode=$?
echo -n $(cat /tmp/cydiapipe | cut -d':' -f2)
rm -rf /tmp/cydiapipe &> /dev/null
exit $exitcode
