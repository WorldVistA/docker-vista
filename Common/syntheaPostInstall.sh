#!/bin/bash
mkdir -p /tmp/loader/Synthea
pushd /tmp/loader
pip3 install --user chardet future pexpect

# Download loader multibuild
curl -fsSL --progress-bar https://github.com/OSEHRA/VistA-FHIR-Data-Loader/releases/download/0.4/VISTA_FHIR_DATA_LOADER_BUNDLE_0P4.KID.zip -o loader.zip
unzip -q loader.zip -d /tmp/loader/Synthea
recode -f iso8859-1..ascii /tmp/loader/Synthea/*

echo "Installing Synthea ingestor patch"
# Set up arguments for PatchSequenceApply script based upon system
system=1
instanceName='-cn $instance'
if ($installgtm || $installYottaDB); then
  system=2
  instanceName=''
fi
# Assume that '-s' was not supplied to Docker build
vistaDir="$basedir/Dashboard/VistA/Scripts"
# But check to be sure and download VistA if necessary
if [ ! -d $vistaDir ]; then
  echo "Downloading OSEHRA VistA Tester Repo"
  curl -fsSL --progress-bar https://github.com/OSEHRA/VistA/archive/master.zip -o VistA-master.zip
  unzip -q VistA-master.zip
  rm VistA-master.zip
  mv VistA-master VistA
  vistaDir="/tmp/loader/VistA/Scripts"
fi
# Installs as the DUZ=1 user
# Installs the single KIDS build for Synthea loader as DUZ=1 user.
python3 $vistaDir/PatchSequenceApply.py -S $system -p /tmp/loader/Synthea $instanceName -l /tmp/loader -i -n ALL -d 1
popd
