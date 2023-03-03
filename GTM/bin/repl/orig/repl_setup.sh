#!/bin/bash
$gtm_dist/mupip set -replication=on -region DEFAULT
$gtm_dist/mupip replicate -instance_create -noreplace -name=primary
