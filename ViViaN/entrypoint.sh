#!/bin/bash
#---------------------------------------------------------------------------
# Copyright 2026 Sam Habiel
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#---------------------------------------------------------------------------
# Runs as irisowner. Uses passwordless sudo (configured in Dockerfile) to
# start apache/php-fpm as root, then execs the InterSystems IRIS entrypoint
# directly (already irisowner, so it can touch the IRIS registry).
set -e

PHP_VER=$(ls /etc/php 2>/dev/null | head -n1)
if [ -z "$PHP_VER" ]; then
    echo "No PHP install found under /etc/php" >&2
    exit 1
fi

sudo -n mkdir -p /run/php
sudo -n "/usr/sbin/php-fpm${PHP_VER}"
sudo -n apache2ctl start

for candidate in /iris-main /opt/irissys/dev/Cloud/ICM/iris-main /usr/irissys/dev/Cloud/ICM/iris-main; do
    if [ -x "$candidate" ]; then
        exec "$candidate" "$@"
    fi
done

echo "Could not find IRIS base entrypoint" >&2
exit 1
