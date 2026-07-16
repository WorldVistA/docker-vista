# ViViaN on the InterSystems IRIS Community image

This Dockerfile-set builds ViViaN.

The final ViViaN will be at http://localhost:3080/

## Steps

1. Get IRIS.DAT, and put in the current directory. E.g.

```
wget https://foia-vista.worldvista.org/DBA_VistA_FOIA_System_Files/DBA_VISTA_FOIA_2026/DBA_VISTA_FOIA_20260409.zip
unzip DBA_VISTA_FOIA_20260409.zip
```

`IRIS.DAT` has to sit next to this `Dockerfile`.

2. Get the current FOIA Integration Control Agreements (ICR) listing. The
   filename changes month-to-month — browse
   https://foia-vista.worldvista.org/VistA_Integration_Agreement/ for the
   latest and save it here as `ICRDescription.txt`:

```
wget -O ICRDescription.txt https://foia-vista.worldvista.org/VistA_Integration_Agreement/2026_May_21_IA_Listing_Description.txt
```

3. Build

```
docker build -t vivian .
```

Fast Dockerfile iteration (skips the pipeline, drops a stub page):

```
docker build --build-arg PIPELINE_MODE=skip -t vivian:stub .
```

`PIPELINE_MODE` also accepts `extract` — stops after `VistAMComponentExtractor`
(~15 min), useful for validating IRIS + Python wiring without the full CTest
run.

4. Run

```
docker run --name viv -d -p 3080:80 -p 1972:1972 -p 52773:52773 vivian
```

- `3080` → ViViaN + DOX (Apache)
- `1972` → IRIS SuperServer
- `52773` → IRIS Management Portal (`http://localhost:52773/csp/sys/%25CSP.Portal.Home.zen`)

## Copying ViViaN output out of the container

The build tars up three artifacts into `/opt/viv-out/` for easy extraction:

- `vivian-www.tar.gz` — everything under `/var/www/html` (ViViaN, DOX, vivian-data, and the landing `index.html`)
- `prd.tar.gz` — the Reminder Definitions (`.PRD`) exported by `postinstall.sh`
- `build.log` — full transcript of every `RUN` step (apt install, `postinstall.sh`, `pipeline.sh`, tarring, apt purge). Useful when newer Docker versions truncate the build output shown in the terminal.

Copy both out at once:

```
docker cp viv:/opt/viv-out/. ./viv-out/
mkdir www prd
tar -I pigz -xf ./viv-out/vivian-www.tar.gz -C ./www/
tar -I pigz -xf ./viv-out/prd.tar.gz        -C ./prd/
```

`pigz` is kept in the runtime image, so you can also re-roll the archives
inside the container (e.g. after a manual data refresh):

```
docker exec viv tar -I pigz -cf /opt/viv-out/vivian-www.tar.gz -C /var/www/html .
```

## Smoke tests

```
curl -sI http://localhost:3080/vivian/                # 200 OK
curl -s  http://localhost:3080/dox/ | head            # HTML
curl -s  http://localhost:3080/vivian-data/filemanDBCall.json | jq '. | keys | length'   # non-zero
docker exec viv ls /var/www/html/vivian-data | wc -l  # several hundred artifacts
docker exec -it viv iris session IRIS -U FOIA        # M shell works
```
