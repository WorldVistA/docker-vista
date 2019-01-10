#!/bin/bash
mkdir /tmp/loader
pushd /tmp/loader
# Download Synthea loader multibuild
curl -fsSL --progress-bar https://github.com/OSEHRA/VistA-FHIR-Data-Loader/releases/download/0.1/VISTA_SYNTHETIC_DATA_LOADER_BUNDLE_0P2T1.KID.zip -o loader.zip
unzip -q loader.zip -d /tmp/loader/Synthea
echo "Installing Synthea ingestor patch"
# Set up arguments for PatchSequenceApply scrip based upon system
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
python $vistaDir/PatchSequenceApply.py -S $system -p /tmp/loader/Synthea $instanceName -l /tmp/loader -i -n ALL -d 1
popd
rm -r /tmp/loader