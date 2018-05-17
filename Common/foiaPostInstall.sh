#!/bin/bash
# NB NB NB: There are tabs in this code. They MUST be kept.
# Needs a parameter: instance name ($1)
instance=$1
ccontrol start CACHE
csession CACHE -U $instance <<END

S ^%ZIS(1,"G","SYS..|TNT|",22)=""
K ^XTV(8989.3,1,"DEV")

ccontrol stop CACHE quietly
