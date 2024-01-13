FROM rockylinux:8.9

RUN echo "multilib_policy=best" >> /etc/yum.conf
RUN yum update  -y && \
    yum install -y \
                   util-linux \
                   gcc-c++ \
                   git \
                   xinetd \
                   perl \
                   curl \
                   libcurl-devel \
                   python3 \
                   openssh-server \
                   openssh-clients \
                   expect \
                   man \
                   sshpass \
                   wget \
                   make \
                   cmake \
                   dos2unix \
                   which \
                   file \
                   unzip \
                   net-tools \
                   libicu \
                   libicu-devel \
                   recode \
                   bzip2 \
                   lsof \
                   openssl \
                   gzip \
                   vim \
                   bind-utils \
                   perl-Digest-SHA \
                   initscripts \
                   || true && \
    yum  -y clean all && \
    rm -rf /var/cache/yum

RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa && \
    ssh-keygen -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key && \
    ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key && \
    sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    echo 'root:docker' | chpasswd && \
    rm -f /run/nologin

WORKDIR /opt/vista
# Add each folder individually to improve rebuild times
ADD ./IRIS /opt/vista/IRIS
ADD ./iris-files /opt/vista/iris-files
ADD ./zwr-zip /opt/vista/zwr-zip
ADD ./Common /opt/vista/Common
ADD ./Dashboard /opt/vista/Dashboard
ADD ./EWD /opt/vista/EWD
ADD ./GTM /opt/vista/GTM
ADD ./tests /opt/vista/tests
ADD ./test.cmake /opt/vista/
ADD ./ViViaN /opt/vista/ViViaN
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
    dos2unix /opt/vista/EWD/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/EWD/etc/init.d/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/GTM/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/GTM/bin/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/GTM/etc/init.d/* >/dev/null 2>&1 && \
    dos2unix /opt/vista/ViViaN/* >/dev/null 2>&1

RUN ./autoInstaller.sh ${install_flags}
ENTRYPOINT ${entry_path}/bin/start.sh
EXPOSE 22 8001 9100 9101 61012 9430 8080 8081 8089 9080 57772 5001
