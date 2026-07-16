#---------------------------------------------------------------------------
# Copyright 2026 Sam Habiel
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#---------------------------------------------------------------------------
#
# Instructions:
# Get latest FOIA IRIS.DAT (see IRIS/docker-iris/Dockerfile) and place it in
# the folder.
#
# Build (full ~2 hours; PIPELINE_MODE=skip for fast web-tier iteration):
# $ docker build -t vivian .
# $ docker build --build-arg PIPELINE_MODE=skip -t vivian:stub .
#
# Run:
# $ docker run --name viv -d -p 3080:80 -p 1972:1972 -p 52773:52773 vivian
# $ curl http://localhost:3080/vivian/
#
# IRIS management console at http://localhost:52773/csp/sys/%25CSP.Portal.Home.zen
# IRIS shell: docker exec -it viv iris session IRIS -U FOIA

FROM intersystems/iris-community:latest-em

ARG PIPELINE_MODE=full

USER root

# Route every RUN's stdout/stderr through /opt/viv-out/build.log so the full
# build transcript survives BuildKit output clipping and can be copied out
# alongside the other artifacts. pipefail so the tee pipe doesn't mask errors.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /opt/viv-out && \
    touch /opt/viv-out/build.log && \
    chmod 666 /opt/viv-out/build.log

# Build-only + runtime apt deps in one layer. Build-only packages get purged
# after the pipeline runs.
RUN { apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        build-essential cmake git rustc cargo \
        openjdk-8-jdk-headless \
        python3 python3-venv python3-dev python3-pip \
        libssl-dev libfreetype-dev \
        apache2 php-fpm php-cli \
        graphviz curl unzip ca-certificates \
        pigz \
        sudo && \
      rm -rf /var/lib/apt/lists/* ; \
    } 2>&1 | tee -a /opt/viv-out/build.log

RUN { mkdir -p /usr/irissys/mgr/FOIA /opt/VistA-docs /opt/VistA-M /opt/viv-out && \
      chown 51773:51773 /opt /var/www/html && \
      chown -R 51773:51773 /usr/irissys/mgr/FOIA /opt/VistA-docs /opt/VistA-M /opt/viv-out ; \
    } 2>&1 | tee -a /opt/viv-out/build.log

COPY apache-vivian.conf /etc/apache2/sites-available/000-default.conf
COPY index.html /var/www/html/index.html
RUN { a2enmod proxy_fcgi setenvif rewrite && \
      PHP_VER=$(ls /etc/php | head -n1) && \
      sed -i "s|/run/php/php[0-9.]*-fpm.sock|/run/php/php${PHP_VER}-fpm.sock|" \
          /etc/apache2/sites-available/000-default.conf && \
      echo "irisowner ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/irisowner && \
      chmod 0440 /etc/sudoers.d/irisowner ; \
    } 2>&1 | tee -a /opt/viv-out/build.log

USER 51773

COPY --chown=51773:51773 IRIS.DAT /usr/irissys/mgr/FOIA/IRIS.DAT
COPY --chown=51773:51773 ICRDescription.txt /opt/ICRDescription.txt
COPY --chown=51773:51773 merge.cpf pipeline.sh postinstall.sh vivianPostInstall.m CMakeCache.txt /tmp/

RUN { iris start IRIS \
   && iris merge IRIS /tmp/merge.cpf \
   && /tmp/postinstall.sh \
   && PIPELINE_MODE=${PIPELINE_MODE} /tmp/pipeline.sh \
   && iris stop IRIS quietly \
   && tar -I pigz -cf /opt/viv-out/vivian-www.tar.gz -C /var/www/html . \
   && tar -I pigz -cf /opt/viv-out/prd.tar.gz -C /opt/viv-out/prd . \
   && rm -f /tmp/merge.cpf /tmp/pipeline.sh /tmp/postinstall.sh \
            /tmp/vivianPostInstall.m /tmp/CMakeCache.txt ; \
    } 2>&1 | tee -a /opt/viv-out/build.log

USER root

RUN { DEBIAN_FRONTEND=noninteractive apt-get purge -y \
        build-essential cmake git rustc cargo \
        openjdk-8-jdk-headless \
        python3-dev python3-pip \
        libssl-dev libfreetype-dev && \
      apt-get autoremove -y && \
      rm -rf /root/.cargo /root/.rustup /opt/vivian-venv \
             /tmp/*.zip /tmp/*.tar.gz /var/lib/apt/lists/* ; \
    } 2>&1 | tee -a /opt/viv-out/build.log

COPY entrypoint.sh /entrypoint.sh
RUN { chmod 0755 /entrypoint.sh ; \
    } 2>&1 | tee -a /opt/viv-out/build.log

USER 51773

EXPOSE 80 1972 52773
ENTRYPOINT ["/entrypoint.sh"]
