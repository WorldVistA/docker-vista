FROM rockylinux:9

RUN echo "multilib_policy=best" >> /etc/yum.conf

# Unified package list for the Rocky 9 pathway.
# Superset of what the Dockerfile-built image and the Vagrant bootstrap need
# so per-subsystem install scripts (GTM/install.sh, IRIS/install.sh) don't
# have to run their own yum. Keep this list in sync with the identical list
# in autoInstaller.sh (the "if $bootstrap" block).
RUN yum update -y && \
    yum install -y epel-release && \
    yum install --enablerepo=crb -y \
                   bind-utils \
                   bison \
                   bzip2 \
                   cmake \
                   dos2unix \
                   elfutils-libelf-devel \
                   expect \
                   file \
                   flex \
                   gawk \
                   gcc-c++ \
                   git \
                   gpgme-devel \
                   gzip \
                   httpd \
                   iproute \
                   jansson \
                   jansson-devel \
                   java-devel \
                   libconfig-devel \
                   libcurl-devel \
                   libgcrypt-devel \
                   libicu \
                   libicu-devel \
                   libsodium-devel \
                   lsof \
                   make \
                   man \
                   ncurses-devel \
                   net-tools \
                   nodejs \
                   openssh-clients \
                   openssh-server \
                   openssl \
                   openssl-devel \
                   perl \
                   perl-Digest-SHA \
                   procps-ng \
                   python3 \
                   python3-pip \
                   readline-devel \
                   recode \
                   socat \
                   sshpass \
                   tcsh \
                   unzip \
                   util-linux \
                   vim \
                   vim-common \
                   wget \
                   which && \
    yum -y clean all && \
    rm -rf /var/cache/yum

RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key && \
    ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    rm -f /run/nologin

WORKDIR /opt/vista
# Add each folder individually to improve rebuild times
ADD ./IRIS /opt/vista/IRIS
ADD ./iris-files /opt/vista/iris-files
ADD ./zwr-zip /opt/vista/zwr-zip
ADD ./Common /opt/vista/Common
ADD ./Dashboard /opt/vista/Dashboard
ADD ./GTM /opt/vista/GTM
ADD ./tests /opt/vista/tests
ADD ./test.cmake /opt/vista/
ADD ./*.sh /opt/vista/

ARG instance=foia
ENV instance_name=$instance
ARG flags="-y -b -e -m -p ./Common/ovydbPostInstall.sh"
ARG entry="/home"
ENV entry_path="${entry}/${instance_name}"
ENV install_flags="$flags -i ${instance_name}"

RUN dos2unix /opt/vista/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/IRIS/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/IRIS/etc/init.d/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/Common/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/Dashboard/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/GTM/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/GTM/bin/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/GTM/etc/init.d/* >/dev/null 2>&1

RUN ./autoInstaller.sh ${install_flags} && \
    ln -sf ${entry_path}/bin/start.sh /start.sh
ENTRYPOINT ["/start.sh"]
EXPOSE 22 1338 5001 8001 8089 8090 9080 9100 9101 9430 57772
