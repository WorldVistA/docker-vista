#!/bin/bash
$gtm_dist/mupip replicate -source -start -instsecondary=vista_replica -secondary=vista_replica:4000 -log=$basedir/log/origin_start.log
$gtm_dist/mupip replicate -source -checkhealth
tail -30 $basedir/log/origin_start.log
