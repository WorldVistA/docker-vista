#!/bin/bash
#
#  This is a file to run VistA HL7 v2.X as a Linux service
#
export HOME=/home/foia
export REMOTE_HOST=`echo $REMOTE_HOST | sed 's/::ffff://'`
source $HOME/etc/env

LOG=$HOME/log/hl7.log

echo "$$ Job begin `date`"                                      >>  ${LOG}
echo "$$  ${gtm_dist}/mumps -run GTMLNX^HLCSGTM"                >>  ${LOG}

${gtm_dist}/mumps -run GTMLNX^HLCSGTM                          2>>  ${LOG}
echo "$$  HL7 Listner stopped with exit code $?"                >>  ${LOG}
echo "$$ Job ended `date`"                                      >>  ${LOG}
