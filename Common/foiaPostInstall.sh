#!/bin/bash
# NB NB NB: There are tabs in this code. They MUST be kept.
# Needs a parameter: instance name ($1)
#  Modifications made to FOIA release:
#
#  S ^%ZIS(1,"G","SYS..|TNT|",22)="" -> Adds |TNT| device for all namespaces
#  and points it to the IEN of the TELNET device
#

#  S XTV(8989.3,1,"XUCP")="N" -> Turns off "LOG RESOURCE USAGE" to prevent
#  attempt to find ZOSVKR on GT.M
#

#  K ^XTV(8989.3,1,"DEV") -> Empties the "PRIMARY HFS DIR" which will let the
#  ZGO routine write out the files in a temp dir that exists locally.
#

instance=$1
ccontrol start CACHE
csession CACHE -U $instance <<END

S ^%ZIS(1,"G","SYS..|TNT|",22)=""
S ^XTV(8989.3,1,"XUCP")="N"
K ^XTV(8989.3,1,"DEV")
END
ccontrol stop CACHE quietly
