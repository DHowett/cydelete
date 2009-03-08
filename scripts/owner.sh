#!/bin/bash
cd /var/lib/dpkg/info
OUT=$(grep "^$*\$" *.list | cut -d':' -f1)
if [[ -z "$OUT" ]]; then exit 1;
else echo -n ${OUT%.list}; exit 0; fi
