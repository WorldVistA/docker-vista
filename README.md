# Dockerized VistA/RPMS instances
Code in this repository enables you to create VistA or RPMS instances on
Caché or GT.M/YottaDB.  A working [Docker](https://www.docker.com/community-edition#/download) installation on
the platform of choice is required in order to be able to create instances.

# Table of Contents

* [Pre-built images](#pre-built-images)
* [Quick Reference for building &amp; running images](#quick-reference-for-building--running-images)
* [Detailed Discussion and Reference](#detailed-discussion-and-reference)
  * [Build Options](#build-options)
  * [Tagging an image to upload to Docker Hub](#tagging-an-image-to-upload-to-docker-hub)
  * [Building ViViaN and DOX with Docker](#building-vivian-and-dox-with-docker)
  * [Post Installs that you can apply with -p flag](#post-installs-that-you-can-apply-with--p-flag)
  * [Installing SQL Mapping](#installing-sql-mapping)

## Pre-built images

Pre-built images for open source code are available on Docker Hub. Instrucions
for running them are available on the URL, including usernames/passwords:

| Image Name   | M Imp | Versions Available | Docker Hub URL |
| ----------   | ----- | ------------------ | -------------- |
| FOIA VistA   | YDB   | No New Images      | https://hub.docker.com/r/worldvista/foiavista |
| OSEHRA VistA | YDB   | No New Images      | https://hub.docker.com/r/worldvista/osehravista |
| vxVistA      | GTM   | 15.0               | https://hub.docker.com/r/worldvista/vxvista |
| VEHU         | YDB   | Monthly            | https://hub.docker.com/r/worldvista/vehu |
| RPMS         | YDB   | No New Images      | https://hub.docker.com/r/worldvista/rpms |
| OSEHRA Plan VI | YDB | 3; last 201902     | https://hub.docker.com/r/worldvista/ov6  |
| VEHU Plan VI | YDB   | 2; last 201901     | https://hub.docker.com/r/worldvista/vehu6 |
| WorldVistA   | YDB   | 3.0                | https://hub.docker.com/r/worldvista/worldvista-ehr |
| WorldVistA   | GTM   | 2.0                | https://hub.docker.com/r/krmassociates/worldvista  |

## Quick Reference for building & running images

Default: "OSEHRA VistA (YottaDB, no bootstrap, with QEWD and Panorama)"

    docker build -t foia .
    docker run -d -p 9430:9430 -p 8001:8001 -p 2222:22 -p 8080:8080 -p 9080:9080 --name=foia foia

Plan VI (Internationalized Version) OSEHRA VistA (YottaDB, UTF-8 enabled, no bootstrap, with QEWD and Panorama)

    docker build --build-arg flags="-byuma https://github.com/WorldVistA/VistA-M/archive/plan-vi.zip -p ./Common/ov6piko.sh" --build-arg instance="ov6" -t ov6 .
    docker run -d -p 2222:22 -p 8001:8001 -p 9430:9430 -p 8080:8080 -p 9080:9080 --name=ov6 ov6

WorldVistA (YottaDB, Panorama, no boostrap, skip testing):

    docker build --build-arg flags="-bymsa http://opensourcevista.net/NancysVistAServer/BetaWVEHR-3.0-Ver2-16Without-CPT-20181004/FileForDockerBuildWVEHR3.0WithoutCPT.zip -p Common/wvDemopi.sh" --build-arg instance="wv" -t wv .
    docker run -d -p 2222:22 -p 8001:8001 -p 9430:9430 -p 8080:8080 -p 9080:9080 --name=wv wv

VEHU (YottaDB with GUI, no bootstrap, skip testing, SQL Access)

    docker build --build-arg flags="-ybsqna https://github.com/WorldVistA/VistA-VEHU-M/archive/master.zip" --build-arg instance="vehu" -t vehu .
    docker run -d -p 2222:22 -p 8001:8001 -p 9430:9430 -p 8089-8090:8089-8090 -p 1338:1338 --name=vehu vehu

VEHU (YottaDB with GUI, build YottaDB from source, SQL Access)

    docker build --build-arg flags="-obsqna https://github.com/WorldVistA/VistA-VEHU-M/archive/master.zip" --build-arg instance="vehu" -t vehu .
    docker run -d -p 2222:22 -p 8001:8001 -p 9430:9430 -p 1338:1338 -p 8089-8090:8089-8090 --name=vehu vehu

VEHU Plan VI (Internationalized Version) (YottaDB, UTF-8 enabled, no bootstrap, skip testing, Panorama)

    docker build --build-arg flags="-bysuma https://github.com/WorldVistA/VistA-VEHU-M/archive/plan-vi.zip" --build-arg instance="vehu6" -t worldvista/vehu6:201808 -t worldvista/vehu6:latest .
    docker run -d -p 2222:22 -p 8001:8001 -p 9430:9430 -p 8080:8080 -p 9080:9080 --name=vehu worldvista/vehu6

RPMS (RPMS, YottaDB, no boostrap, skip testing, and do post-install as well)

    docker build --build-arg flags="-wfybsa https://github.com/shabiel/FOIA-RPMS/archive/master.zip -p ./Common/rpmsPostInstall.sh" --build-arg instance="rpms" -t rpms .
    docker run -d -p 2222:22 -p 9100:9100 -p 9101:9101 -p 9080:9080 --name=rpms rpms

Caché Install with local VistA DAT file. You need to supply your own CACHE.DAT and CACHE.key and .tar.gz installer for RHEL.  These files need to be added to the cache-files directories.

    docker build --build-arg flags="-cbsp ./Common/pvPostInstall.sh" --build-arg instance="foia" --build-arg entry="/opt/cachesys" -t cache .
    docker run -p 9430:9430 -p 8001:8001 -p2222:22 -p57772:57772 -p 9080:9080 -d -P --name=cache cache

Caché Install with local RPMS DAT file.

    docker build --build-arg flags="-cbswp ./Common/foiaRPMSPostInstall.sh" --build-arg instance="rpms" --build-arg entry="/opt/cachesys" -t rpms .
    docker run -d -p 2222:22 -p 9100:9100 -p 9101:9101 -p 9080:9080 --name=rpms rpms

Caché Install with local DAT file to stop after exporting the code from the Cache instance. You need to supply your own CACHE.DAT and .tar.gz installer for RHEL.
When available, the system will also install a "cache.key" file when the system is built.  If it is not present, the extraction will be performed serially.
These files need to be added to the cache-files directories.

    docker build --build-arg flags="-cbsxp ./Common/foiaPostInstall.sh" --build-arg instance="cachevista" --build-arg entry="/opt/cachesys" -t cachevista .
    docker run -p 9430:9430 -p 8001:8001 -p2222:22 -p57772:57772 -p 9080:9080 -d -P --name=cache cachevista

To capture the exported code from the container and remove the Docker objects, execute the following commands:

    docker cp cache:/opt/VistA-M /tmp/ # no need to put a cp -r
    docker stop cache
    docker rm cache
    docker rmi cachevista

A [volume](https://docs.docker.com/storage/volumes/) could also be mounted to the container.

### List of Ports

The exported ports are as follows:

| Docker Port | Mapped To? | Purpose         | Applicable to?    |
| ----------- | ---------- | -------         | ----------------- |
| 22          | 2222       | SSH             | All               |
| 9430        | 9430       | XWB  (CPRS etc) | VistA             |
| 8080        | 8080       | Panorama        | VistA             |
| 8001        | 8001       | VistALink       | VistA             |
| 9080        | 9080       | M Web Server    | VistA             |
| 9100        | 9100       | CIA (RPMS-EHR)  | RPMS              |
| 9101        | 9101       | BMX (iCare etc) | RPMS              |
| 57772       | 57772      | Caché Web Portal | Caché            |
| 1338        | 1338       | SQL Listener Port | YottaDB         |
| 8089        | 8089       | YottaDB GUI     | YottaDB           |
| 8090        | 8090       | YottaDB GUI Socket Server  | YottaDB           |

## Detailed Discussion and Reference

As shown above, there are two steps: the build step and and run step. There
are defaults if you don't supply arguments, which are discussed below. The
build step runs the script [autoInstaller.sh](./autoInstaller.sh) which does
the actual installation. Post-install scripts (supplied after the argument -p)
allow customization of the built image.

Caché will not have any pre-built images due to license restrictions.  The
Caché install assumes that you are using a pre-built CACHE.DAT. The default
install is done with "minimal" security.  Also, some options (EWD, Panorama,
etc) are not valid for Caché installs and will be ignored. The Cache Steps are
as follows:

1) Copy the Caché installer (.tar.gz RHEL kit) to the root of this repository
2) Copy your cache.key to the cache-files directory of this repository (optional)
3) Copy your CACHE.DAT to the cache-files directory of this repository
4) Build and run the image

   ```sh
   docker build --build-arg flags="-cbsp ./Common/pvPostInstall.sh" --build-arg instance="cachevista" --build-arg entry="/opt/cachesys" -t cachevista .
   docker run -p9430:9430 -p8001:8001 -p2222:22 -p57772:57772 -d --name=cache cachevista
   ```

### Build Options

[Dockerfile](./Dockerfile) options:

| Option Name | Default | Description | Example |
| ----------- | ------- | ----------- | ------- |
| instance    | `osehra` | The `instance` argument allows you to define the instance Name Space and directory inside the docker container. MUST BE lowercase. | `docker build --build-arg instance=vxvista -t vxvista` |
| flags       | `-y -b -e -m -p ./Common/ovydbPostInstall.sh` | Command Line arguments to [autoInstaller.sh](./autoInstaller.sh) | See table below for more details and examples above |
| entry       | `/home` | The `entry` argument allows you to adjust where docker looks for the entryfile | `docker build --build-arg entry="/opt/cachesys" -t cache .` |

[autoInstaller.sh](./autoInstaller.sh) options:

| Option | Default | Description |
| ------ | ------- | ----------- |
| a      | https://github.com/WorldVistA/VistA-M/archive/master.zip |  Alternate VistA-M repo (zip or git format) (Must be in OSEHRA format) |
| b      | n/a     | Skip bootstrapping system (used for docker) |
| c      | n/a     | Use Caché |
| d      | n/a     | Create development directories (s & p) (GT.M and YottaDB only) |
| e      | n/a     | Install QEWD (assumes development directories) |
| f      | n/a     | Apply Kernel-GTM fixes after import |
| g      | n/a     | Use GT.M |
| h      | n/a     | Show the list of options |
| i      | osehra  | Instance name (Namespace/Database for Caché) |
| m      | n/a     | Install Panorama (assumes development directories and QEWD) |
| n      | n/a     | Install YottaDB GUI. |
| o      | n/a     | Install YottaDB from source. Will also enable -y (YottaDB) |
| p      | n/a     | Post install hook (path to script) |
| q      | n/a     | Install SQL mapping for YottaDB |
| r      | n/a     | Alternate VistA-M repo branch (git format only) |
| s      | n/a     | Skip testing |
| t      | n/a     | Run BATS Tests |
| u      | n/a     | Install GTM/YottaDB with UTF-8 enabled |
| v      | n/a     | Build ViViaN Documentation |
| w      | n/a     | Install RPMS scripts (GT.M/YDB or Caché) |
| x      | n/a     | Extract Routines and Globals from GT.M/Caché into .m/.zwr |
| y      | n/a     | Use YottaDB |
| z      | n/a     | Dev Mode: Don't clean-up and set -x |

### Tagging an image to upload to Docker Hub

First, you need to login to Docker Hub using the command `docker login`.

MAKE SURE THAT WHAT YOU PUSH IS OPEN SOURCE CODE. Docker Hub is a public
resource. There are enterprise versions of Docker Hub; we are NOT providing
intructions for that here.

Then you need to tag your image. First find the image ID using `docker images`. For example,

    REPOSITORY           TAG                 IMAGE ID            CREATED             SIZE
    wv                   latest              4d088aa275ff        13 hours ago        6.06GB
    vehu                 latest              ed6175534a1c        20 hours ago        4.29GB
    vxvista              latest              3866735fcfc0        21 hours ago        2.96GB
    cachevista           latest              071386cb0e80        46 hours ago        15.4GB
    centos               latest              75835a67d134        11 days ago         200MB
    osehra/osehravista   latest              8d58b9b985d7        5 weeks ago         4.63GB
    hello-world          latest              e38bc07ac18e        6 months ago        1.85kB

So, if we want to push `wv` up, then we need to use the image ID `4d088aa275ff`
using our username on dockerhub plus the name of the image. If your username on
Docker Hub is `boo`, then you need to tag your image as follows:

    docker tag 4d088aa275ff boo/wv

If you plan to have more than one version of your images, you can use `:`
after the tag name. Not using a `:` automatically applies the version `latest`.
For example,

    docker tag 4d088aa275ff boo/wv:v3

... to deploy v3.

The last step is pushing to Docker Hub. To push the `latest` version, just
do this:

    docker push boo/wv

To push a specific version, you need to put the `:`.

    docker push boo/wv:v3

The push will take a long time depending on how fast your upload speed is. VistA
images are around 4GB big when uploaded; 1GB big when downloaded (as they are
downloaded gzipped).

### Building ViViaN and DOX with Docker

Utilizing the "-v" argument flag, the system will attempt to execute the tasks which will
install a MUMPS environment, execute tasks to gather data, generate HTML pages, and finally
set up a web server on the container to display the data.  The scripts are designed to
take and process a M[UMPS] system that is supplied by the user in one of two formats.

|     Platform      |                       Required Files                           |
| :---------------: | -------------------------------------------------------------- |
|   GT.M/YottaDB    | Not supported. Create an issue if interested.                  |
|     Caché         | The files used as part of the install will be used again. You need to supply your own CACHE.DAT and CACHE.key and .tar.gz installer for RHEL.  These files need to be added to the  cache-files directories.        |


The building of ViViaN is available to executed on all three of the platforms using the same
arguments as above: ``-c`` for Caché, ``-y`` for YottaDB, and ``-g`` for GT.M.  Each of these
options should be combined with the ``-v`` and ``-b`` options when the docker build command is
instantiated.

For a Caché instance, the command would look as follows:

    docker build --build-arg flags="-c -b -v -p ./Common/pvPostInstall.sh" --build-arg entry="/opt/cachesys" --build-arg instance="osehra" -t cacheviv .
    docker run -p 9430:9430 -p 8001:8001 -p 8080:8080 -p 2222:22 -p 57772:57772 -p 3080:80 -d -P --name=cache cacheviv

For a YottaDB instance, the command would look as follows:

    docker build --build-arg flags="-y -b -v -p ./Common/pvPostInstall.sh" --build-arg instance="osehra" -t yottaviv .
    docker run -p 9430:9430 -p 8001:8001 -p 8080:8080 -p 2222:22 -p 57772:57772 -p 3080:80 -d -P --name=cache yottaviv

Once the container is running, the ViViaN and DOX pages can be accessed via
a web browser at http://localhost:3080/vivian and http://localhost:3080/vivian/files/dox

### Post Installs that you can apply with -p flag

| Script                              | GTM-YDB/Caché? | What it does? |
| ----------------------------------- | ---------------| ------------- |
| `./Common/pvPostInstall.sh`         | Caché          | FOIA VistA Cache Set-up  |
| `./Common/syntheaPostInstall.sh`    | GTM-YDB        | Install Synthetic Patient Ingestor and FHIR Exporter |
| `./Common/vxvistaPostInstall.sh`    | GTM-YDB        | vxVistA GT.M/YDB specific set-up |
| `./Common/rpmsPostInstall.sh`       | GTM-YDB        | RPMS GT.M/YDB specific set-up |
| `./Common/foiaPostInstall.sh`       | Caché          | Fix FOIA Console Set-up |
| `./Common/ov6piko.sh`               | GTM-YDB        | Add Korean ICD-10 and Korean demo data for Plan VI images |
| `./Common/ovydbPostInstall.sh`      | Sample Only    | DO NOT USE |
| `./Common/wvDemopi.sh`              | GTM-YDB        | Create Demo Users for an instance (physician, pharmacist, and nurse) |
| `./Common/foiaRPMSPostInstall.sh`   | Caché          | FOIA RPMS CACHE.DAT Post-Installer |
| `./Common/vehu6piko.sh`             | GTM-YDB        | Add Korean ICD-10 to VEHU instance |

### Installing SQL Mapping
SQL Mapping of FileMan Files is at https://gitlab.com/YottaDB/DBMS/YDBOcto. SQL
Mapping is supported only for YottaDB. There are some special command line
arguments that are required for proper running:

#### Installation Command Line flag

The -q command line flag is used to install all required files for the SQL Mapping and set up processes for auto start when the container is started.
Development directories are automatically installed by specifing "-q"

An example build command:

    docker build --build-arg flags="-y -b -e -m -q -s" --build-arg instance="osehra" -t osehraocto .

#### Docker run Command Line flags

There is also an additional port that needs to be forwarded from the Host to the Guest:

    -p 1338:1338

example docker run command:

    docker run -p 9430:9430 -p 8001:8001 -p 2223:22 -p 1338:1338 -d -P --name=osehra osehraocto

#### Mapping FileMan Files

All FileMan files are automatically mapped when the container is built. If you need to re-run the mapping at any point you can run the following commands:

To map individual files:

    OSEHRA>D MAPONE^%YDBOCTOVISTAM("/path/for/ddl.sql",FileNumber)

Replace FileNumber with a valid parent File Number like 200 (NEW PERSON) or 2 (PATIENT)

    OSEHRA>D MAPFM^%YDBOCTOVISTAM("vista-200.sql",200)

Mapping all FileMan files can be accomplished by running:

    OSEHRA>D MAPALL^%YDBOCTOVISTAM("/path/for/ddl.sql")

Then load it using the octo command line tool:

    octo -f /path/for/ddl.sql

#### Connecting with SquirrelSQL

[SquirrelSQL](http://www.squirrelsql.org) is the preferred client to use with Octo as that is what is used in
development and testing. Other clients may have varying degress of success connecting to Octo due to certain
queries sent by the tool.

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
   packages of the system. It also needs to have 2 environment variables defined: accessCode
   and verifyCode. These should be a valid access/verify code of a system manager user
   that has access to VistALink
