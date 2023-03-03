#!/bin/bash
$gtm_dist/mupip replicate -receive -shutdown -timeout=0
$gtm_dist/mupip replicate -source -shutdown -timeout=0
$gtm_dist/mupip rundown -region "*"
