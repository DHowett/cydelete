#!/bin/bash
export PATH=/usr/bin:/bin:/sbin:/usr/sbin
export CYDIA="2 1"
apt-get -y remove $1 2>/tmp/aptoutput 1>/dev/null
exitcode=$?
grep finish /tmp/aptoutput > /tmp/cydiapipe
rm -rf /tmp/aptoutput &> /dev/null
echo -n $(cat /tmp/cydiapipe | cut -d':' -f2)
rm -rf /tmp/cydiapipe &> /dev/null
exit $exitcode
