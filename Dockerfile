FROM centos

RUN echo "multilib_policy=best" >> /etc/yum.conf
RUN yum  -y update && \
    yum install -y \
                   gcc-c++ \
                   git \
                   xinetd \
                   perl \
                   curl \
                   python \
                   openssh-server \
                   openssh-clients \
                   expect \
                   man \
                   python-argparse \
                   sshpass \
                   wget \
                   make \
                   cmake \
                   dos2unix \
                   which \
                   file \
                   unzip \
                   lsof \
                   net-tools \
                   java-devel \
                   libicu \
                   libicu-devel \
                   recode \
                   bzip2 \
                   || true && \
    yum install -y http://libslack.org/daemon/download/daemon-0.6.4-1.i686.rpm > /dev/null && \
    package-cleanup --cleandupes && \
    yum  -y clean all && \
    rm -rf /var/cache/yum

RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa && \
    ssh-keygen -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key && \
    ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key && \
    sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    echo 'root:docker' | chpasswd

WORKDIR /opt/vista
# Add each folder individually to improve rebuild times
ADD ./Cache /opt/vista/Cache
ADD ./cache-files /opt/vista/cache-files
ADD ./Common /opt/vista/Common
ADD ./Dashboard /opt/vista/Dashboard
ADD ./EWD /opt/vista/EWD
ADD ./GTM /opt/vista/GTM
ADD ./tests /opt/vista/tests
ADD ./test.cmake /opt/vista/
ADD ./ViViaN /opt/vista/ViViaN
ADD ./*.sh /opt/vista/

ARG instance=osehra
ENV instance_name=$instance
ARG flags="-y -b -e -m -p ./Common/ovydbPostInstall.sh"
ARG entry="/home"
ENV entry_path="${entry}/${instance_name}"
ENV install_flags="$flags -i ${instance_name}"

RUN dos2unix /opt/vista/* && \
    dos2unix /opt/vista/Cache/* && \
    dos2unix /opt/vista/Cache/etc/init.d/* && \
    dos2unix /opt/vista/Common/* && \
    dos2unix /opt/vista/Dashboard/* && \
    dos2unix /opt/vista/EWD/* && \
    dos2unix /opt/vista/EWD/etc/init.d/* && \
    dos2unix /opt/vista/GTM/* && \
    dos2unix /opt/vista/GTM/bin/* && \
    dos2unix /opt/vista/GTM/etc/init.d/* && \
    dos2unix /opt/vista/ViViaN/*

RUN ./autoInstaller.sh ${install_flags}
ENTRYPOINT ${entry_path}/bin/start.sh
EXPOSE 22 8001 9100 9101 61012 9430 8080 8081 9080 57772
