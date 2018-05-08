# Dockerized VistA instances

## Requirements
This has only been tested using:

* Docker for Mac
* Docker on Linux (Thanks: George Lilly)
* Docker Toolkit on Windows 7 (Thanks: Sam Habiel)

## Pre-requisites
A working [Docker](https://www.docker.com/community-edition#/download) installation on the platform of choice.

## Note
You cannot use docker exec -it osehravista bash to get access to the mumps prompt. This is likely due to how docker permission schemes for shared memory access works. Instead always gain access via the ssh commands below

## Pre-built images
Pre-built images using this repository are available on [docker hub](https://hub.docker.com/r/krmassociates/)

### Running a Pre-built image
1) Pull the image

    ```
    docker pull krmassociates/osehravista # subsitute worldvista or vxvista if you want one of those instead
    ```

2) Run the image
  Non QEWD enabled images

    ```
    docker run -p 9430:9430 -p 8001:8001 -p 2222:22 -d -P --name=osehravista krmassociates/osehravista # subsitute worldvista or vxvista if you want one of those instead
    ```

QEWD enabled images: Add `-p 8080:8080` to access QEWD/Panorama at port 8080.

```
docker run -p 9430:9430 -p 8001:8001 -p 2222:22 -p 8080:8080 -d -P --name=osehravista krmassociates/osehravista-qewd
```

## Docker Build

### Build Commands
1) Build the docker image

    ```
    docker build -t osehra .
    ```

2) Run the created image

    ```
    docker run -p 9430:9430 -p 8001:8001 -p 2222:22 -d -P --name=osehravista osehra
    ```

## Build Steps for Caché installs
Caché will not have any pre-built images due to license restrictions and needing licensed versions of Caché to be used.

The Caché install assumes that you are using a pre-built CACHE.DAT and will perform no configuration to the CACHE.DAT. The default install is done with "minimal" security.

The initial docker container startup will take a bit of time as it needs to perform a workaround due to limitations of the OverlayFS that docker uses (see: https://docs.docker.com/engine/userguide/storagedriver/overlayfs-driver/#limitations-on-overlayfs-compatibility)

Also, many options (EWD, Panorama, etc) are not valid for Caché installs and will be ignored.

1) Copy the Caché installer (.tar.gz RHEL kit) to the root of this repository
2) Copy your cache.key to the cache-files directory of this repository
3) Copy your CACHE.DAT to the cache-files directory of this repository
4) Build the image

   ```
   docker build --build-arg flags="-c -b -s" --build-arg instance="cachevista" --build-arg postInstallScript="-p ./Common/pvPostInstall.sh" --build-arg entry="/opt/cachesys" -t cachevista .
   ```

5) Run the image:

   ```
   docker run -p9430:9430 -p8001:8001 -p2222:22 -p57772:57772 -d --name=cache cachevista
   ```

### Build Options

#### instance
Default: `oshera`

The `instance` argument allows you to define the instance Name Space and directory inside the docker container.

Example:

    docker build --build-arg instance=vxvista -t vxvista .

#### postInstallScript
Default: `NULL`

The `postInstallScript` argument allows you to define a post install shell script that you want to run.

Example:

    docker build --build-arg postInstallScript="-p ./Common/vxvistaPostInstall.sh" -t vxvista .

#### flags
Default: `-c -b -s`

The `flags` argument allows you to adjust which flags you want to send to the autoInstaller.sh.

Example:

    docker build --build-arg flags="-y -b -s -a https://github.com/OSEHRA/vxVistA-M/archive/master.zip" -t vxvista .

### entry
Default: `/home`

The `entry` argument allows you to adjust where docker looks for the entryfile.

Example:

    docker build --build-arg entry="/opt/cachesys" -t cache .

### Build Examples
Default: "OSEHRA VistA (YottaDB, no bootstrap, with QEWD and Panorama)"

    docker build -t osehra-vista .
    docker run -d -p 9430:9430 -p 8001:8001 -p 2222:22 -p 8080:8080 --name=osehravista osehra-vista

WorldVistA (GTM, no boostrap, skip testing):

    docker build --build-arg flags="-g -b -s -a https://github.com/glilly/wvehr2-dewdrop/archive/master.zip" --build-arg instance="worldvista" --build-arg postInstallScript="-p ./Common/removeVistaSource.sh" -t worldvista .
    docker run -d -p 2222:22 -p 8001:8001 -p 9430:9430 --name=worldvista worldvista

vxVistA (YottaDB, no boostrap, skip testing, and do post-install as well):

    docker build --build-arg flags="-y -b -s -a https://github.com/OSEHRA/vxVistA-M/archive/master.zip" --build-arg instance="vxvista" --build-arg postInstallScript="-p ./Common/vxvistaPostInstall.sh" -t vxvista .
    docker run -d -p 2222:22 -p 8001:8001 -p 9430:9430 --name=vxvista vxvista

VEHU (GTM, no bootstrap, skip testing, Panorama)

    docker build --build-arg flags="-g -b -s -m -a https://github.com/OSEHRA-Sandbox/VistA-VEHU-M/archive/master.zip" --build-arg instance="vehu" --build-arg postInstallScript="-p ./Common/removeVistaSource.sh" -t vehu .
    docker run -d -p 2222:22 -p 8001:8001 -p 9430:9430 -p 8080:8080 --name=vehu vehu

RPMS (RPMS, YottaDB, no boostrap, skip testing, and do post-install as well)

    docker build --build-arg flags="-w -y -b -s -a https://github.com/shabiel/FOIA-RPMS/archive/master.zip" --build-arg instance="rpms" --build-arg postInstallScript="-p ./Common/rpmsPostInstall.sh" -t rpms .
    docker run -d -p 2222:22 -p 9100:9100 -p 9101:9101 --name=rpms rpms

Caché Install with local DAT file. You need to supply your own CACHE.DAT and CACHE.key and .tar.gz installer for RHEL.  These files need to be added to the cache-files directories.

    docker build --build-arg flags="-c -b -s" --build-arg instance="cachevista" --build-arg postInstallScript="-p ./Common/pvPostInstall.sh" --build-arg entry="/opt/cachesys" -t cachevista .
    docker run -p 9430:9430 -p 8001:8001 -p2222:22 -p57772:57772 -d -P --name=cache cachevista

### Building ViViAn and Dox with Docker

Utilizing the "-v" argument flag, the system will attempt to execute the tasks which will
install a MUMPS environment, execute tasks to gather data and generate HTML pages, then
set up a web server on the container to display the data.  These steps have been
documented as part of the OSEHRA/VistA repository found [here](https://github.com/OSEHRA/VistA/blob/master/Documentation/generateDockerViViaNAndDox.rst)


## Roll-and-Scroll Access for non Caché installs

1) Tied VistA user:

    ssh osehratied@localhost -p 2222 # subsitute worldvistatied or vxvistatied if you used one of those images

password tied

2) Programmer VistA user:

    ssh osehraprog@localhost -p 2222 # subsitute worldvistaprog or vxvistaprog if you used one of those images

password: prog

3) Root access:

    ssh root@localhost -p 2222

password: docker

## VistA Access/Verify codes for non Caché installs

OSEHRA VistA:

Regular doctor:
Access Code: FakeDoc1
Verify Code: 1Doc!@#$

System Manager:
Access Code: SM1234
Verify Code: SM1234!!!

WorldVistA:

Displayed in the VistA greeting message

vxVistA:

Displayed in the VistA greeting message

## QEWD passwords for non Caché installs

Monitor:
keepThisSecret!

## Tests
Deployment tests are written using [bats](https://github.com/sstephenson/bats)
The tests make sure that deployment directories, scripts, RPC Broker, VistALink
are all working and how they should be.

There are two special tests:
 * fifo

   The fifo test is for docker containers and assumes that the tests are ran as root
   (currently) as that is who owns the fifo
 * VistALink

   This test installs java, retrieves a zip file of a github repo and makes a VistALink
   connection. This test does take a few seconds to complete and modifies the installed
   packages of the system. It also needs to have 2 environemnt variables defined: accessCode
   and verifyCode. These should be a valid access/verify code of a system manager user
   that has access to VistALink

