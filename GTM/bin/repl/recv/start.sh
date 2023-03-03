#!/bin/bash
$gtm_dist/mupip replicate -source -start -passive -instsecondary=dummy -log=$basedir/log/passive_server_start.log
$gtm_dist/mupip replicate -receive -start -listenport=3000 -log=$basedir/log/receive.log
$gtm_dist/mupip replicate -receive -checkhealth
tail -20 $basedir/log/receive.log
