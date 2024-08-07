#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2021 Sam Habiel
# Copyright 2022 YottaDB LLC
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
# Script to install YottaDB GUI
set -e

#set -xv

# Ensure presence of required variables
if [ -z $instance ] || [ -z $basedir ]; then
    echo "The required variables are not set (instance, basedir)"
fi

# Options
# instance = name of instance
# used http://rsalveti.wordpress.com/2007/04/03/bash-parsing-arguments-with-getopts/
# for guidance

usage()
{
    cat << EOF
    usage: $0 options

    This script will automatically install YottaDB GUI for YottaDB

    OPTIONS:
      -h    Show this message
      -f    Skip setting firewall rules

EOF
}

while getopts ":hf" option
do
    case $option in
        h)
            usage
            exit 1
            ;;
        f)
            firewall=false
            ;;
    esac
done

if [ -z $firewall ]; then
    firewall=true
fi

# Create Certificates
mkdir -p /YDBGUI/certs
openssl genrsa -aes128 -passout pass:ydbgui -out /YDBGUI/certs/ydbgui.key 2048
openssl req -new -key /YDBGUI/certs/ydbgui.key -passin pass:ydbgui -subj '/C=US/ST=Pennsylvania/L=Malvern/CN=localhost' -out /YDBGUI/certs/ydbgui.csr
openssl req -x509 -days 365 -sha256 -in /YDBGUI/certs/ydbgui.csr -key /YDBGUI/certs/ydbgui.key -passin pass:ydbgui -out /YDBGUI/certs/ydbgui.pem

# YottaDB Certificate Config
cat <<EOF >> /YDBGUI/certs/ydbgui.ydbcrypt
tls: {
  session-timeout: 600;
  ydbgui: {
    format: "PEM";
    cert: "/YDBGUI/certs/ydbgui.pem";
    key:  "/YDBGUI/certs/ydbgui.key";
  };
  client: {
    CAfile: "/YDBGUI/certs/ydbgui.pem";
  };
};
EOF

# Needed because YottaDB server needs to read the key, which is rw and owned by root.
chown $instance:$instance /YDBGUI/certs/*

# Add additional YDBGUI items to env script
export USER=$instance # necessary so that the maskpass script would work. Also needed at runtime.
cat <<EOF >> $basedir/etc/env
export gtmroutines="\$gtmroutines /home/vehu/lib/gtm/plugin/o/_ydbgui.so /home/vehu/lib/gtm/plugin/o/_ydbmwebserver.so"
export gtmcrypt_config="/YDBGUI/certs/ydbgui.ydbcrypt"
export USER=$instance
export gtmtls_passwd_ydbgui="$(echo ydbgui | $gtm_dist/plugin/gtmcrypt/maskpass | cut -d ":" -f2 | tr -d '[:space:]')"
export NODE_TLS_REJECT_UNAUTHORIZED=0
EOF
unset USER

# Add users for the GUI
cat <<EOF >> $basedir/etc/users.json
[{
	"username": "admin",
	"password": "admin",
	"authorization": "RW"
}]
EOF
chown $instance:$instance $basedir/etc/users.json

# Modify init.d scripts to reflect $instance
perl -pi -e 's#/home/foia#'$basedir'#g' $basedir/etc/init.d/ydbgui
ln -s $basedir/etc/init.d/ydbgui /etc/init.d/${instance}vista-ydbgui

if [[ $ubuntu || -z $RHEL ]]; then
    update-rc.d ${instance}vista-ydbgui defaults
fi

if [[ $RHEL || -z $ubuntu ]]; then
    chkconfig --add ${instance}vista-ydbgui
fi

# Add firewall rules
if $firewall; then
  if [[ $RHEL || -z $ubuntu ]]; then
      firewall-cmd --zone=public --add-port=8089-8092/tcp --permanent
      firewall-cmd --reload
  fi
fi

echo "Done installing YottaDB GUI"
