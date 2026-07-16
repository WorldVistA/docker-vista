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
# IRIS post-install for ViViaN: strip proprietary routines (DSI*, VEJD*,
# VEN*, DSS*), scrub HL7 messages, activate User One, fix invalid DD fields,
# reset primary HFS dir. Runs the M code in vivianPostInstall.m
# against an already-running IRIS.

set -e

mkdir -p /opt/viv-out/prd

iris session IRIS -U FOIA <<'END'
; Recompile
W "Recompiling Routines",!
D Compile^%R("*.*")
D Compile^%R("%*.*")
;
W "Saving vivianPostInstall...",!
d $SYSTEM.Process.SetZEOF(1)
ZR  ZS vivianPostInstall
S F="/tmp/vivianPostInstall.m"
O F U F ZL  ZS vivianPostInstall C F
W "Running vivianPostInstall...",!
D ^vivianPostInstall
;
W "Export Reminders Definitions PRD files to /opt/viv-out/prd/"
S U="^"
F I=0:0 S I=$O(^PXD(811.8,I)) Q:'I  S NAME=$P(^(I,0),U),NAME=$TR(NAME,"/","-"),GBL=$NA(^PXD(811.8,I,100,1,0)) W I," ",$$GATF^%ZISH(GBL,4,"/opt/viv-out/prd/",NAME_".PRD"),!
;
HALT
END
