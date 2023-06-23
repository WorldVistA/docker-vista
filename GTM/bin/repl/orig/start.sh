#!/bin/bash
instsecondary=$1
$gtm_dist/mupip replicate -source -start -instsecondary=$1 -secondary=$1:3000 -log=$basedir/log/origin_start.log
