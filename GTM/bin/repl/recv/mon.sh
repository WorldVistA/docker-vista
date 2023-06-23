#!/bin/bash
$gtm_dist/mupip replicate -receive -checkhealth
tail -20 $basedir/log/receive.log
$gtm_dist/mupip replicate -receive -showbacklog
