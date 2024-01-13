#!/bin/bash
# Needs a parameter: instance name ($1)
instance=$1
iris start IRIS
iris session IRIS -U $instance <<END
; Recompile
W "Recompiling Routines",!
D Compile^%R("*.*")
D Compile^%R("%*.*")
;
; Save vivianPostInstall Routine
W "Saving vivianPostInstall...",!
d \$SYSTEM.Process.SetZEOF(1)
ZR  ZS vivianPostInstall
S F="/opt/vista/Common/vivianPostInstall.m"
O F U F ZL  ZS vivianPostInstall C F
W "Running vivianPostInstall...",!
D ^vivianPostInstall
;
HALT
END
iris stop IRIS quietly
