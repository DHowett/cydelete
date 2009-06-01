#!/bin/bash
cd /var/lib/dpkg/info
BUNDLE=$1
TITLE=$2

if [[ -e "$BUNDLE.list" ]]; then
	echo -n $BUNDLE
	exit 0
elif [[ -e "$TITLE.list" ]]; then
	echo -n $TITLE
	exit 0
fi

shift 2
OUT=$(grep "^$*\$" *.list | cut -d':' -f1)
if [[ -z "$OUT" ]]; then exit 1;
else echo -n ${OUT%.list}; exit 0; fi
