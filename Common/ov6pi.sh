#!/bin/bash
# Postinstall for OSEHRA VistA Plan 6
# See IMPORTANT notes in the .m file.
cp ./Common/ov6piko.m $basedir/r/
$gtm_dist/mumps -r ov6piko
