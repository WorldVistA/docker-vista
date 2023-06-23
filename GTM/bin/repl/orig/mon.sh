#!/bin/bash
tail -10 $basedir/log/origin_start.log
$gtm_dist/mupip replicate -source -checkhealth
$gtm_dist/mupip replicate -source -showbacklog
