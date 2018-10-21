#!/bin/bash
# Postinstall for OSEHRA VistA Plan 6
# See IMPORTANT notes in the .m file.
cp ./Common/wvDemopi.m $basedir/r/
$gtm_dist/mumps -r wvDemopi
