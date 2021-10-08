#!/usr/bin/env bats

@test "instance directories and files exist" {
    # Directories
    [ -d /home/${instance} ]
    [ -d /home/${instance}/bin ]
    [ -d /home/${instance}/etc ]
    [ -d /home/${instance}/etc/init.d ]
    [ -d /home/${instance}/etc/xinetd.d ]
    [ -d /home/${instance}/g ]
    [ -d /home/${instance}/r ]
    [ -d /home/${instance}/r/${gtmver} ]
    [ -d /home/${instance}/lib ]
    [ -d /home/${instance}/lib/gtm ]
    [ -d /home/${instance}/log ]
    [ -d /home/${instance}/tmp ]
    [ -d /home/${instance}/www ]

    # Script created files
    [ -e /home/${instance}/bin/disableJournal.sh ]
    [ -e /home/${instance}/bin/enableJournal.sh ]
    [ -e /home/${instance}/bin/prog.sh ]
    [ -e /home/${instance}/bin/removeVistaInstanceMinimal.sh ]
    [ -e /home/${instance}/bin/rotateJournal.sh ]
    [ -e /home/${instance}/bin/rpcbroker.sh ]
    [ -e /home/${instance}/bin/tied.sh ]
    [ -e /home/${instance}/bin/vistalink.sh ]
    [ -e /home/${instance}/etc/db.gde ]
    [ -e /home/${instance}/etc/env ]
    [ -e /home/${instance}/etc/init.d/vista ]
    [ -e /home/${instance}/etc/xinetd.d/vista-rpcbroker ]
    [ -e /home/${instance}/etc/xinetd.d/vista-vistalink ]
    [ -e /home/${instance}/g/${instance}.dat ]
    [ -e /home/${instance}/g/${instance}.gld ]
    [ -e /home/${instance}/g/temp.dat ]

    # This only exists on docker
    [ -e /home/${instance}/bin/start.sh ]
}

@test "GT.M/YDB installation exist" {

    # does it exist in the instance?
    [ -e /home/${instance}/lib/gtm/mumps ]
    [ -e /home/${instance}/lib/gtm/mupip ]

}

@test "relink control permissions" {
    gtmrelinkctl=$(ls -1 /home/${instance}/tmp/*-relinkctl-* | head -1)
    [ -e ${gtmrelinkctl} ]
    [ "$(stat -c %a ${gtmrelinkctl})" -eq "664" ]
}

@test "fifo exists" {
    [ -e /root/fifo ]
}

@test "GT.M/YDB install works as intended" {
    # Test the intreperter
    [[ "$(mumps -run %XCMD 'W "Hello World"')" == "Hello World" ]]
    # Test datbase set
    [[ "$(mumps -run %XCMD 'S ^KBBO="Hello World" W ^KBBO K ^KBBO')" == "Hello World" ]]
}

@test "VistA FileMan access works" {
    output=$(mumps -run %XCMD 'S DUZ=.5 D P^DI' << EOF
INQ



EOF
)
    [ $(expr "$output" : ".*File.*") -ne 0 ]
}

@test "RPC Broker connection works" {
    run mumps -run %XCMD 'D HOME^%ZIS W $$TEST^XWBTCPMT("127.0.0.1",9430,1)'
    echo "output :"$output
    [ $(expr "$output" : ".*1^accept.*") -ne 0 ]
}

@test "VistALink connection works" {
    run yum -y install java
    [ $(expr "$output" : ".*[I,i]nstalled.*") -ne 0 ]
    run java -version
    [ $(expr "$output" : ".*1.8.*") -ne 0 ]
    pushd /tmp
    rm -rf vistalink-tester-for-linux-master
    curl -LO https://github.com/shabiel/vistalink-tester-for-linux/archive/master.zip
    unzip -q master.zip
    rm -f master.zip
    cd vistalink-tester-for-linux-master/samples-J2SE/
    echo 'LocalServer {' > jaas1.config
    echo '    gov.va.med.vistalink.security.VistaLoginModule requisite' >> jaas1.config
    echo '    gov.va.med.vistalink.security.ServerAddressKey="127.0.0.1"' >> jaas1.config
    echo '    gov.va.med.vistalink.security.ServerPortKey="8001";' >> jaas1.config
    echo '};' >> jaas1.config

    accessCode=$(mumps -r ^%XCMD 'W $P(^VA(200,1,0),"^",3)')
    verifyCode=$(mumps -r ^%XCMD 'W $P(^VA(200,1,.1),"^",2)')
    if [[ -z "$accessCode" || -z "$verifyCode" ]]; then
       loopdone=false
       accessCode=""
       while ! $loopdone ; do
          accessCode=$(mumps -r ^%XCMD 'W $O(^VA(200,"A","'${accessCode}'"),-1)')
          ien=$(mumps -r ^%XCMD 'W $O(^VA(200,"A","'${accessCode}'",""))')
          verifyCode=$(mumps -r ^%XCMD 'W $P(^VA(200,'${ien}',.1),"^",2)')
          if ! [[ -z "$accessCode" || -z "$verifyCode" ]]; then loopdone=true; fi
       done
    fi

    run java -Djava.security.auth.login.config="./jaas1.config" -cp "./*" gov.va.med.vistalink.samples.VistaLinkRpcConsole -s LocalServer -a ${accessCode} -v ${verifyCode}
    cd ../..
    rm -rf vistalink-tester-for-linux-master
    [ $(expr "$output" : ".*sending AV.GetUserDemographics.*") -ne 0 ]
}

@test "HL7 Listener works" {
    run mumps -run %XCMD 'D CALL^%ZISTCP("127.0.0.1",5001) U IO W $C(11)_"MSH^PING^OSEHRA"_$C(10,28,13) R X:1 C IO U 0 W X'
    [ $(expr "$output" : ".*OSEHRA.*") -ne 0 ]
}

@test "Octo works" {
    run octo <<END
SELECT P.NAME AS PATIENT_NAME, P.PATIENT_ID as PATIENT_ID,
       P.WARD_LOCATION,
       TOKEN(REPLACE(TOKEN(REPLACE(P.WARD_LOCATION,"WARD ",""),"-",1),"WARD ","")," ",2) AS PCU,
       CONCAT(TOKEN(REPLACE(TOKEN(REPLACE(P.WARD_LOCATION,"WARD ",""),"-",2),"WARD ","")," ",1)," ",TOKEN(P.WARD_LOCATION,"-",3)) AS UNIT,
       P.ROOM_BED as ROOM_BED,
       REPLACE(P.DIVISION,"VEHU","") as FACILTY,
       P.SEX as SEX,
       P.CURRENT_ADMISSION as CURRENT_ADMISSION,
       P.CURRENT_MOVEMENT as CURRENT_MOVEMENT,
       DATEFORMAT(P.DATE_OF_BIRTH,"5Z") as DATE_OF_BIRTH,
       P.Age,
       PM.PATIENT_MOVEMENT_ID as Current_Patient_Movement,
       PM.TYPE_OF_MOVEMENT as Current_Movement_Type,
       AM.PATIENT_MOVEMENT_ID as Admission_Movement,
       AM.TYPE_OF_MOVEMENT as Admission_Type
FROM PATIENT P
left join patient_movement PM on P.CURRENT_MOVEMENT=PM.PATIENT_MOVEMENT_ID
left join patient_movement AM on P.CURRENT_ADMISSION=AM.PATIENT_MOVEMENT_ID
where P.CURRENT_MOVEMENT is not null
and P.ward_location not like "ZZ%" and P.NAME not like "ZZ%";
END
     [ "$status" -eq 0 ]
}
