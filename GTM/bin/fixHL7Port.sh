#!/bin/bash
set -x
port=$($gtm_dist/mumps -r %XCMD 'W $P(^HLCS(870,$O(^HLCS(870,"E","M",0)),400),"^",2)')
perl -pi -e 's/5030/'$port'/g' /etc/xinetd.d/*vista-hl7*
