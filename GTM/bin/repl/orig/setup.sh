#!/bin/bash
$gtm_dist/mupip set -replication=on -region DEFAULT
if [ ! -f ${gtm_repl_instance} ]; then
	$gtm_dist/mupip replicate -instance_create -noreplace -name=primary
fi
rm -f $basedir/log/repl_setup.log
$gtm_dist/mupip replicate -source -start -passive -updok -instsecondary=dummy -log=$basedir/log/repl_setup.log
tail -10 $basedir/log/repl_setup.log
