#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2018-2019 The Open Source Electronic Health Record Alliance
# Copyright 2020-2026 Sam Habiel
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#---------------------------------------------------------------------------
# Ubuntu-adapted derivative of ViViaN/vivianInstall.sh:118-260. Runs inside
# the iris-community image against a live IRIS with the FOIA namespace
# already merged in.
#
# PIPELINE_MODE (env):
#   full     - default; run everything (~2 hours)
#   extract  - stop after VistAMComponentExtractor
#   skip     - drop stub artifacts only (~seconds, for fast Dockerfile iteration)

set -e

namespace=FOIA
basedir=/usr/irissys
connectionArg="-S 1 -CN FOIA"

: "${PIPELINE_MODE:=full}"

timestamp() { date +"%Y-%m-%d-%H:%M:%S"; }

if [[ "$PIPELINE_MODE" == "skip" ]]; then
    echo "PIPELINE_MODE=skip: creating stub artifacts"
    mkdir -p /var/www/html/vivian /var/www/html/vivian-data /var/www/html/dox
    cat > /var/www/html/vivian/index.php <<'EOF'
<h1>ViViaN stub (PIPELINE_MODE=skip)</h1>
<p>PHP: <?php echo PHP_VERSION; ?></p>
EOF
    exit 0
fi

# Append the FOIA namespace value to the CMakeCache we shipped
echo "
//Cache namespace to store VistA
VISTA_CACHE_NAMESPACE:STRING=$namespace" >> /tmp/CMakeCache.txt

mkdir -p /opt/VistA-docs /opt/viv-out
cd /opt

echo "Downloading OSEHRA VistA Testing Repository"
curl -fsSL https://github.com/WorldVistA/VistA/archive/master.zip -o VistA-master.zip
dir=$(zipinfo -1 VistA-master.zip | head -1 | cut -d/ -f1)
unzip -q VistA-master.zip
rm VistA-master.zip
mv "$dir" VistA

echo "Generating VistA-M-like directory"
mkdir -p /opt/VistA-M/Packages
cp /opt/VistA/Packages.csv /opt/VistA-M/

# MRoutineAnalyzer
git clone https://github.com/WorldVistA/rgivistatools.git /opt/VistA-docs/rgivistatools

# Python virtual env for pipeline scripts
# To activate venv if you do a docker exec -it, do this:
# > cd /opt/
# > . vivian-venv/bin/activate
python3 -m venv vivian-venv
. vivian-venv/bin/activate

# Install requirements from Testing repository
pip3 install -r /opt/VistA/requirements.txt

echo "Cloning ViViaN Repository"
curl -fsSL https://github.com/WorldVistA/vivian/archive/master.zip -o vivian-master.zip
dir=$(zipinfo -1 vivian-master.zip | head -1 | cut -d/ -f1)
unzip -q vivian-master.zip
rm vivian-master.zip
mv "$dir" /var/www/html/vivian

# Step 1: Export routines and globals via IRIS
# Uses IRIS. The ZGO routine makes sure not to exceed the job limit (8 jobs)
# To monitor, look at /tmp/VistAPExpect.log and worklist.log
# ZGO takes about 10 minutes
# Python splitting takes a longer time, but is potentially parallelizable
echo "Starting VistAMComponentExtractor at:" $(timestamp)
python3 /opt/VistA/Scripts/VistAMComponentExtractor.py $connectionArg -r /opt/VistA-M/ -o /tmp/ -l /tmp/
echo "Ending VistAMComponentExtractor at:" $(timestamp)

# Uncomment to debug VistAMComponentExtractor
# @TODO Make debugging a script option
#echo "Start of Log Dump:"
# cat /tmp/VistAPExpect.log
#echo "End of Log Dump"

if [ ! -f /tmp/Globals/DD.zwr ] || [ ! -f /tmp/Routines.ro ]; then
    echo "VistAMComponentExtractor failed!"
    exit 1
fi

if [[ "$PIPELINE_MODE" == "extract" ]]; then
    echo "PIPELINE_MODE=extract: stopping after VistAMComponentExtractor"
    deactivate
    exit 0
fi

cd VistA-docs
cp /tmp/CMakeCache.txt /opt/VistA-docs/CMakeCache.txt
/usr/bin/cmake .
mkdir -p /var/www/html/vivian-data

echo "Starting CTest at:" $(timestamp)

# Step 2: XINDEX patch install
# Uses IRIS. Now uses DefaultKIDSInstaller.py instead of PatchSequenceApply.py
# Instant
echo "Installing XINDEX patch"
/usr/bin/ctest -V -R "XINDEX"

# Step 3: XINDEX reports (CALLERGRAPH) — ~100 min
# Run XINDEX on all the routines and on the package entry + package files (probably from Packages.csv)
# Runs on IRIS
# Single user IRIS allows 8 jobs (and thus -j 8)
#
# Takes 100 minutes (5797.53: TOO LONG!)
# To monitor, run tail -f /opt/VistA-docs/Docs/CallerGraph/Log/*
echo "Executing XINDEX reports"
/usr/bin/ctest -V -j 8 -R "CALLERGRAPH"

# Vivian Step 4:
# - GetFilemanSchema (takes about 80 minutes - 4831.70 sec)
# This runs through the effective list of globals and if there are files there, run XINDEX on them.
# Uses IRIS. Only uses a single job right now to do the work.
# Potentially parallelizable. Even better if it is written in M.
# To monitor, run ls -l /opt/VistA-docs/Docs/Schema | wc -l
# The final count is around 3000 (cat /opt/VistA-docs/globals.lst | wc -l)
#
# Vivian Step 5:
# - MRoutineAnalyzer. Independent. Can be run without the other steps. Fast.
# This runs a Java program that goes through all the routines and gets a list of Fileman calls using DBS API into a a JSON file
# Monitor by looking at the generated file /var/www/html/vivian-data/filemanDBCall.json
#
# Vivian Step 6:
# - ICRParser. Independent. Can be run without the other steps. Fast.
# Converts the ICR file in /opt/ICRDescription.txt to /var/www/html/vivian-data/ICRDescription.JSON.
# Monitor by looking at the generated file.
#
# Vivian Step 7:
# - GenerateNameNumberDisplay. Independent. Can be run without the other steps. Fast.
# Creates /var/www/html/vivian-data/numberspace|namespace/xxx.html files from data in /opt/VistA/Utilities/Dox/Data
# Monitor by looking at the generated file.
#
# Vivian Step 8:
# - GenerateRepoInfo. Independent. Can be run without the other steps. Fast.
# Uses git to get the hash for /opt/VistA-M and stores at /var/www/html/vivian-data/filesInfo.json
#
# Vivian Step 9:
# - GeneratePackageDep. Depends on GetFilemanSchema and MRoutineAnalyzer completing first. Fast.
#
# Vivian Step 10:
# - FileManGlobalDataParser 
# This runs a Python program that creates:
# 1. Each fileman data output for each file as file/entry.html
# 2. Create file.json for the list of entries
# 3. Create Routine-Ref.json of all the Fileman files 
# Really slow, should be parallelized: 4681.99s (80 minutes)
#
# Vivian Step 11:
# - GraphGenerator (614.21s = 10 minutes)
# Generate Graphs for DOX pages. Relies on a lot of the previous steps. Needs to be run alone. Multiprocessor!
# Maybe convert over to each one manually
#
# Steps 4-11: FileMan schema, MRoutineAnalyzer, ICR parser, GraphGenerator, etc.
echo "Executing data-gathering tasks"
/usr/bin/ctest -V -E "CALLERGRAPH|XINDEX|WebPageGenerator"

# Step 12: Web page generation
# - WebPageGenerator (about 500 seconds)
# Create the webpages
echo "Generating ViViaN and DOX HTML"
/usr/bin/ctest -V -R "WebPageGenerator"
echo "Ending CTest at:" $(timestamp)

cd /var/www/html/vivian/scripts
python3 setup.py -fd /var/www/html/vivian-data -dd /var/www/html/dox

deactivate
