#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2011-2019 The Open Source Electronic Health Record Alliance
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#---------------------------------------------------------------------------

# Turn this flag on for debugging.
# set -x;

# Make sure we are root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Are we running on a local repo? If so, don't clone the "VistA" repo again!
currentDir=$(dirname "$(readlink -f "$0")")
parentDir=$(dirname $currentDir)
parentdirname=$(basename $parentDir)
if [ "$parentdirname" = "Install" ]; then
    localVistARepo="true"
else
    localVistARepo="false"
fi

# Options
# instance = name of instance
# used http://rsalveti.wordpress.com/2007/04/03/bash-parsing-arguments-with-getopts/
# for guidance

usage()
{
    cat << EOF
    usage: $0 options

    This script will automatically create a VistA instance for GT.M on
    RHEL-like Distros

    DEFAULTS:
      Alternate VistA-M repo = https://github.com/OSEHRA/VistA-M.git
      Install EWD.js = false
      Create Development Directories = false
      Instance Name = OSEHRA
      Post Install hook = none
      Skip Testing = false

    OPTIONS:
      -h    Show this message

      -a    Alternate VistA-M repo (zip or git format) (Must be in OSEHRA format)
      -b    Skip bootstrapping system (used for docker)
      -c    Use Caché
      -d    Create development directories (s & p) (GT.M and YottaDB only)
      -e    Install QEWD (assumes development directories)
      -f    Apply Kernel-GTM fixes after import
      -g    Use GT.M
      -h    Show this message
      -i    Instance name (Namespace/Database for Caché)
      -m    Install Panorama (assumes development directories and QEWD)
      -p    Post install hook (path to script)
      -q    Install SQL mapping for YottaDB
      -r    Alternate VistA-M repo branch (git format only)
      -s    Skip testing
      -u    Install GTM/YottaDB with UTF-8 enabled
      -v    Build ViViaN Documentation
      -w    Install RPMS scripts (GT.M/YDB or Caché)
      -x    Extract given M[UMPS] code
      -y    Use YottaDB
      -z    Dev Mode: Don't clean-up and set -x

    NOTE:
    The Caché install only supports using .DAT files for the VistA DB, and
    installs using minimal security. Most other options are not valid for
    Caché installation including EWD, Panorama, and development directories.

EOF
}

while getopts ":ha:cbxemdufgi:vp:sr:wyqz" option
do
    case $option in
        h)
            usage
            exit 1
            ;;
        a)
            repoPath=$OPTARG
            ;;
        b)
            bootstrap=false
            ;;
        c)
            installcache=true
            ;;
        d)
            developmentDirectories=true
            ;;
        e)
            installEWD=true
            developmentDirectories=true
            ;;
        f)
            kernelGTMFixes=true
            ;;
        m)
            installEWD=true
            developmentDirectories=true
            installPanorama=true
            ;;
        g)
            installgtm=true
            ;;
        i)
            instance=$(echo $OPTARG |tr '[:upper:]' '[:lower:]')
            ;;
        p)
            postInstall=true
            postInstallScript=$OPTARG
            ;;
        r)
            branch=$OPTARG
            ;;
        s)
            skipTests=true
            ;;
        u)
            utf8=true
            ;;
        v)
            generateViVDox=true
            ;;
        w)
            installRPMS=true
            ;;
        x)
            generateViVDox=true
            extractOnly=true
            ;;
        y)
            installYottaDB=true
            ;;
        q)
            developmentDirectories=true
            installSQL=true
            ;;
        z)
            devMode=true
            ;;
    esac
done

# Set defaults for options
if [[ -z $repoPath ]]; then
    repoPath="https://github.com/OSEHRA/VistA-M/archive/master.zip"
fi

if [[ -z $bootstrap ]]; then
    bootstrap=true
fi

if [[ -z $developmentDirectories ]]; then
    developmentDirectories=false
fi

if [[ -z $installEWD ]]; then
    installEWD=false
fi

if [[ -z $installPanorama ]]; then
    installPanorama=false
fi

if [[ -z $installgtm ]]; then
    installgtm=false
fi

if [[ -z $kernelGTMFixes ]]; then
    kernelGTMFixes=false
fi

if [[ -z $instance ]]; then
    instance=osehra
fi

if [[ -z $postInstall ]]; then
    postInstall=false
fi

if [ -z $skipTests ]; then
    skipTests=false
fi

if [ -z $localVistA ]; then
    localVistA=false
fi

if [ -z $installYottaDB ]; then
    installYottaDB=false
fi

if [ -z $installcache ]; then
    installcache=false;
fi

if [ -z $installRPMS ]; then
    installRPMS=false;
fi

if [ -z $generateViVDox ]; then
    generateViVDox=false;
fi

if [ -z $extractOnly ]; then
    extractOnly=false;
fi

if [ -z $installSQL ]; then
    installSQL=false;
fi

if [ -z $utf8 ]; then
    utf8=false;
fi

if [ -z $devMode ]; then
    devMode=false
fi

if $devMode; then
    set -x
fi

# Quit if no M environment viable
if [[ ! $installgtm || ! $installcache || ! $installYottaDB ]]; then
    echo "You need to either install Caché, GT.M or YottaDB!"
    exit 1
fi

# Summarize options
echo "Using $repoPath for routines and globals"
echo "Create development directories: $developmentDirectories"
echo "Installing an instance named: $instance"
echo "Installing QEWD: $installEWD"
echo "Installing Panorama: $installPanorama"
echo "Installing SQL Mapping: $installSQL"
echo "Post install hook: $postInstallScript"
echo "Skip Testing: $skipTests"
echo "Skip bootstrap: $bootstrap"
echo "Use Cache: $installcache"
echo "Use GT.M: $installgtm"
echo "Use YottaDB: $installYottaDB"
echo "GT.M/YDB in UTF-8: $utf8"
echo "Install RPMS scripts: $installRPMS"
echo "Running on local repo: $localVistARepo"

# Get primary username if using sudo, default to $username if not sudo'd
if $bootstrap; then
    if [[ -n "$SUDO_USER" ]]; then
        primaryuser=$SUDO_USER
    elif [[ -n "$USERNAME" ]]; then
        primaryuser=$USERNAME
    else
        echo Cannot find a suitable username to add to VistA group
        exit 1
    fi
else
    primaryuser="root"
fi

echo This script will add $primaryuser to the VistA group

# Abort provisioning if it appears that an instance is already installed.
test -d /home/$instance/g &&
{ echo "VistA already Installed. Aborting."; exit 0; }

# extra utils - used for cmake and dashboards and initial clones
if $bootstrap; then
    echo "Updating operating system"
    yum update -y > /dev/null
    yum install -y cmake unzip git dos2unix > /dev/null
    yum install -y http://libslack.org/daemon/download/daemon-0.6.4-1.i686.rpm > /dev/null
fi

# Clone repos - Dashboard
if ! $skipTests; then
    cd /usr/local/src
    rm -rf VistA-Dashboard
    git clone -q https://github.com/OSEHRA-Sandbox/VistA -b dashboard VistA-Dashboard
fi

# See if vagrant folder exists if it does use it. if it doesn't clone the repo
if [ -d /vagrant ]; then
    scriptdir=/vagrant

    # Fix line endings
    find /vagrant -name \"*.sh\" -type f -print0 | xargs -0 dos2unix > /dev/null 2>&1
    dos2unix /vagrant/EWD/etc/init.d/ewdjs > /dev/null 2>&1
    dos2unix /vagrant/GTM/etc/init.d/vista > /dev/null 2>&1
    dos2unix /vagrant/GTM/etc/xinetd.d/vista-rpcbroker > /dev/null 2>&1
    dos2unix /vagrant/GTM/etc/xinetd.d/vista-vistalink > /dev/null 2>&1
    dos2unix /vagrant/GTM/gtminstall_SHA1 > /dev/null 2>&1
else
    if $bootstrap; then
        if $localVistARepo; then
           scriptdir=$parentDir
        else
           git clone -q https://github.com/OSEHRA/VistA
           scriptdir=/usr/local/src/VistA/Scripts/Install
        fi
    else
        scriptdir=/opt/vista
    fi
fi

# bootstrap the system
if $bootstrap; then
    cd $scriptdir
    ./RHEL/bootstrapRHELserver.sh
else
    # move back to the /opt/vista directory
    cd /opt/vista
fi

# Ensure scripts know if we are RHEL like or Ubuntu like
export RHEL=true;

# Install GT.M or YottaDB
installydbOptions=""
createVistaInstanceOptions=""
if ! $bootstrap; then
   installydbOptions+="-s "
   createVistaInstanceOptions+="-f "
fi
if $installYottaDB; then
   installydbOptions+="-y "
   createVistaInstanceOptions+="-y "
fi
if $installRPMS; then
   createVistaInstanceOptions+="-r "
fi
if $utf8; then
   createVistaInstanceOptions+="-u "
fi

if $installgtm || $installYottaDB ; then
    cd GTM
    ./install.sh $installydbOptions
    ./createVistaInstance.sh -i $instance $createVistaInstanceOptions
fi

if $installcache; then
    cd Cache
    if $installRPMS; then
      ./install.sh -i $instance -r
    else
      ./install.sh -i $instance
    fi
    # Create the VistA instance
    #./createVistaInstance.sh
fi

# Modify the primary user to be able to use the VistA instance
if $installgtm || $installYottaDB; then
    usermod -a -G $instance $primaryuser
    chmod g+x /home/$instance
fi

# Setup environment variables so the dashboard can build
# have to assume $basedir since this sourcing of this script will provide it in
# future commands
if $installgtm || $installYottaDB; then
    source /home/$instance/etc/env
fi

# Get running user's home directory
# http://stackoverflow.com/questions/7358611/bash-get-users-home-directory-when-they-run-a-script-as-root
if $bootstrap && ($installgtm || $installYottaDB); then
    USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    USER_HOME=/root
fi

# number of cores - 1
# (works also on MacOS; on FreeBSD, omit underscore)
cores=$(($(getconf _NPROCESSORS_ONLN) - 1))
if (( cores < 1 )); then cores=1; fi

# source env script during running user's login
if $installgtm || $installYottaDB; then
    echo "source $basedir/etc/env" >> $USER_HOME/.bashrc
fi

if (($installgtm || $installYottaDB) && ! $generateViVDox); then

  echo "Getting the VistA-M Source Code"
  pushd /usr/local/src
  if [[ $repoPath == *.git ]]; then
      if ! [ -z $branch ]; then
          git clone --depth 1 $repoPath -b $branch VistA-Source
      else
          git clone --depth 1 $repoPath VistA-Source
      fi
  else
      echo "Downloading "$repoPath
      curl -fsSL --progress-bar $repoPath -o VistA-M-master.zip
      dir=$(zipinfo -1 VistA-M-master.zip | head -1 | cut -d/ -f1)
      unzip -q VistA-M-master.zip
      rm VistA-M-master.zip
      mv $dir VistA-Source
  fi

  # Make routines/globals importable if UTF-8
  if $utf8; then
      echo "Modifying zwr globals to contain UTF-8 in the first line"
      find VistA-Source -name '*.zwr' -print0 | xargs -0 -I{} -n 1 -P $cores \
        sed -i '1c\OSEHRA ZGO Export: THIS GLOBAL UTF-8' "{}"
      echo "Convert non-ASCII routines to UTF-8"
      find VistA-Source -name '*.m' -print0 | xargs -0 -I{} -n 1 -P $cores \
        recode -f iso8859-1..utf-8 "{}"
  fi
  popd

  if $skipTests; then
      # Go back to the $basedir
      cd $basedir

      # Perform the import
      export devMode       # Send this guy down
      su $instance -c "source $basedir/etc/env && $scriptdir/GTM/importVistA.sh"
      export -n devMode    # and not any further!

      if $kernelGTMFixes; then
        # Get GT.M Optimized Routines from Kernel-GTM project and unzip
        curl -fsSLO --progress-bar https://github.com/shabiel/Kernel-GTM/releases/download/XU-8.0-10004/virgin_install.zip

        # Unzip file, put routines, delete old objects
        su $instance -c "unzip -qo virgin_install.zip -d $basedir/r/"
        su $instance -c "unzip -l virgin_install.zip | awk '{print \$4}' | grep '\.m' | sed 's/.m/.o/' | xargs -i rm -fv r/$gtmver/{}"
        su $instance -c "rm -fv r/$gtmver/_*.o && rm -f virgin_install.zip"
      fi

      # Get the Auto-configurer for VistA/RPMS and run
      mv $scriptdir/Common/KBANTCLN.m $basedir/r/
      chown $instance:$instance $basedir/r/KBANTCLN.m

      # Run the auto-configurer accepting the defaults
      su $instance -c "source $basedir/etc/env && mumps -run START^KBANTCLN"
  else
      # Build a dashboard and run the tests to verify installation
      # These use the Dashboard branch of the VistA repository
      # The dashboard will clone VistA and VistA-M repos
      # run this as the $instance user
      #
      su $instance -c "source $basedir/etc/env && mkdir -p $basedir/Dashboard"
      cd $basedir/Dashboard
      echo "Downloading OSEHRA VistA Tester Repo"
      curl -fsSL --progress-bar https://github.com/OSEHRA/VistA/archive/master.zip -o VistA-master.zip
      unzip -q VistA-master.zip
      rm VistA-master.zip
      mv VistA-master VistA
      mv /usr/local/src/VistA-Source ./VistA-M

      # create random string for build identification
      # source: http://ubuntuforums.org/showthread.php?t=1775099&p=10901169#post10901169
      export buildid=`tr -dc "[:alpha:]" < /dev/urandom | head -c 8`

      # Import VistA and run tests using OSEHRA automated testing framework
      su $instance -c "source $basedir/etc/env && ctest -S $scriptdir/test.cmake -V"

      # Tell users of their build id
      echo "Your build id is: $buildid you will need this to identify your build on the VistA dashboard"
  fi

  echo "Compiling routines"
  cd $basedir/r/$gtmver
  find .. -name '*.m' | xargs --max-procs=$cores --max-args=1 $gtm_dist/mumps >> $basedir/log/compile.log 2>&1
  echo "Done compiling routines"

fi

# Enable journaling
if $installgtm || $installYottaDB; then
    su $instance -c "source $basedir/etc/env && $basedir/bin/enableJournal.sh"
fi

# if we are running on docker we must shutdown gracefully or else corruption will occur
# there is also no need to restart xinetd if we are running in docker as we are going to
# shut it down
if $bootstrap && ($installgtm || $installYottaDB); then
    # Restart xinetd
    service xinetd restart
elif ($installgtm || $installYottaDB); then
    service ${instance}vista stop
fi

# Add p and s directories to gtmroutines environment variable
if $developmentDirectories && ($installgtm || $installYottaDB); then
    su $instance -c "mkdir $basedir/{p,p/$gtmver,s,s/$gtmver}"
    perl -pi -e 's#export gtmroutines=\"#export gtmroutines=\"\$basedir/p/\$gtmver*\(\$basedir/p\) \$basedir/s/\$gtmver*\(\$basedir/s\) #' $basedir/etc/env
fi

# Install QEWD
if $installEWD && ($installgtm || $installYottaDB); then
    cd $scriptdir/EWD
    ./ewdjs.sh -f
    cd $basedir
fi

# Install Panorama
if $installPanorama && ($installgtm || $installYottaDB); then
    cd $scriptdir/EWD
    ./panorama.sh -f
    cd $basedir
fi

# Install PIP/SQL Mapping
if $installSQL && ($installgtm || $installYottaDB); then
    cd $scriptdir/GTM
    ./installPIP.sh
    cd $basedir
fi

# Post install hook
if $postInstall; then
  echo "Executing post install hook..."
  if $installgtm || $installYottaDB; then
    su $instance -c "source $basedir/etc/env && pushd $scriptdir && $postInstallScript && popd"
  elif $installcache; then
    pushd $scriptdir
    $postInstallScript $instance
    popd
  fi
fi

# Ensure group permissions are correct
if $installgtm || $installYottaDB; then
    echo "Please wait while I fix the group permissions on the files..."
    find /home/$instance -print0 | xargs -0 -I{} -n 1 -P $cores chmod g+rw "{}"
fi

extract=""
if $extractOnly; then
  extract="-x"
fi

# Generate ViViaN Documentation
if $generateViVDox; then
    $scriptdir/ViViaN/vivianInstall.sh -i $instance -s $scriptdir $extract
fi

# Clean up the VistA-M source directories to save space
echo "Cleaning up..."
if ! $devMode; then
    if $skipTests; then
        rm -rf /usr/local/src/VistA-Source
    else
        rm -rf $basedir/Dashboard/VistA-M
    fi
fi
