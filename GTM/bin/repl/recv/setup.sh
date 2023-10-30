#!/bin/bash
instname=$1
$gtm_dist/mupip set -replication=on -region DEFAULT
$gtm_dist/mupip replicate -editinstance -name=$instname $gtm_repl_instance
