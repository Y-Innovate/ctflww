//CTFRACF  JOB 'RACF',CLASS=A,MSGCLASS=A,NOTIFY=&SYSUID
//*
//* Needs: group {{PLAYERGROUP}} and batch userid {{BATCHUSER}}, with
//* CLAUTH(USER) and group-special in {{PLAYERGROUP}}, to exist already,
//* and the submit
//* userid {{SUBMITUSER}} (protected: NOPASSWORD, no special authority).
//* {{BATCHUSER}} also needs READ on {{LOADLIB}}. {{ZWSUSER}} is the
//* userid of ZWS, which submits CTFBATCH.
//* DB2 is RACF controlled: access to the plan is given here and not
//* with GRANT. The packages use static SQL, so nobody needs access to
//* the tables. Uses the multi-subsystem scope class MDSNPN.
//* RDEF gives a message if a profile exists already.
//*
//STEP001 EXEC PROC=BATREXX
//COPY.SYSUT1 DD *,DLM=$$
/* REXX */
ADDRESS TSO "RDEF FACILITY DFHDB2.AUTHTYPE.{{CICSTXN_PUBLIC}}" || ,
            " UACC(NONE)"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_PUBLIC}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{CICSDFLTUSER}},{{PLAYERGROUP}},{{ADMINGROUP}},{{CICSREGIONUSER}})"
ADDRESS TSO "RDEF FACILITY DFHDB2.AUTHTYPE.{{CICSTXN_PLAYER}}" || ,
            " UACC(NONE)"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_PLAYER}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{PLAYERGROUP}},{{ADMINGROUP}},{{CICSREGIONUSER}})"
ADDRESS TSO "RDEF FACILITY DFHDB2.AUTHTYPE.{{CICSTXN_ADMIN}}" || ,
            " UACC(NONE)"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_ADMIN}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{ADMINGROUP}},{{CICSREGIONUSER}})"
ADDRESS TSO "RDEF FACILITY DFHDB2.AUTHTYPE.{{CICSTXN_SUBMIT}}" || ,
            " UACC(NONE)"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_SUBMIT}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{SUBMITUSER}},{{CICSREGIONUSER}})"

ADDRESS TSO "RDEF GCICSTRN CTFPUB UACC(NONE)"
ADDRESS TSO "RALT GCICSTRN CTFPUB ADDMEM({{CICSTXN_PUBLIC}})"
ADDRESS TSO "PE CTFPUB CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{CICSDFLTUSER}},{{PLAYERGROUP}},{{ADMINGROUP}})"

ADDRESS TSO "RDEF GCICSTRN CTFPLY UACC(NONE)"
ADDRESS TSO "RALT GCICSTRN CTFPLY ADDMEM({{CICSTXN_PLAYER}})"
ADDRESS TSO "PE CTFPLY CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{PLAYERGROUP}},{{ADMINGROUP}})"

ADDRESS TSO "RDEF GCICSTRN CTFADM UACC(NONE)"
ADDRESS TSO "RALT GCICSTRN CTFADM ADDMEM({{CICSTXN_ADMIN}})"
ADDRESS TSO "PE CTFADM CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{ADMINGROUP}})"

ADDRESS TSO "RDEF GCICSTRN CTFSUB UACC(NONE)"
ADDRESS TSO "RALT GCICSTRN CTFSUB ADDMEM({{CICSTXN_SUBMIT}})"
ADDRESS TSO "PE CTFSUB CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{SUBMITUSER}})"

ADDRESS TSO "RDEF FACILITY CTF.ADMIN UACC(NONE)"
ADDRESS TSO "PE CTF.ADMIN CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{ADMINGROUP}})"

/* CONNECT and REMOVE of event groups need CONNECT authority in the  */
/* group: the group-special of the batch userid covers the player    */
/* userids, not the event groups. Repeat for every RACFGRP group.    */
ADDRESS TSO "CONNECT {{BATCHUSER}} GROUP({{EVENTGROUP}})" || ,
            " AUTHORITY(CONNECT)"

/* Only the submit userid, and ZWS for the scheduled batch, can      */
/* submit as the batch userid. Tasks under the CICS default userid,  */
/* players and admins can only start a task as the submit userid,    */
/* and it checks the claim or job token before it submits anything.  */
ADDRESS TSO "RDEF SURROGAT {{BATCHUSER}}.SUBMIT UACC(NONE)"
ADDRESS TSO "PE {{BATCHUSER}}.SUBMIT CLASS(SURROGAT) ACCESS(READ)" || ,
            " ID({{SUBMITUSER}},{{ZWSUSER}})"
ADDRESS TSO "RDEF SURROGAT {{SUBMITUSER}}.DFHSTART UACC(NONE)"
ADDRESS TSO "PE {{SUBMITUSER}}.DFHSTART CLASS(SURROGAT) ACCESS(READ)" || ,
            " ID({{CICSDFLTUSER}},{{PLAYERGROUP}},{{ADMINGROUP}})"

/* DB2: the plans. AUTHTYPE(USERID) makes RACF check each caller, so  */
/* the player group is enough for new player userids. The CICS        */
/* default userid only gets the plan of the public transaction, which */
/* holds only the packages of the public paths.                       */
plan = "{{DB2SSID}}.{{DB2PLAN_PUBLIC}}.EXECUTE"
ADDRESS TSO "RDEF MDSNPN" plan "UACC(NONE)"
ADDRESS TSO "PE" plan "CLASS(MDSNPN) ACCESS(READ)" || ,
            " ID({{CICSDFLTUSER}},{{PLAYERGROUP}},{{ADMINGROUP}})"
plan = "{{DB2SSID}}.{{DB2PLAN}}.EXECUTE"
ADDRESS TSO "RDEF MDSNPN" plan "UACC(NONE)"
ADDRESS TSO "PE" plan "CLASS(MDSNPN) ACCESS(READ)" || ,
            " ID({{PLAYERGROUP}},{{ADMINGROUP}})"
ADDRESS TSO "PE" plan "CLASS(MDSNPN) ACCESS(READ)" || ,
            " ID({{SUBMITUSER}},{{BATCHUSER}})"

/* DB2: the last steps of the provisioning jobs run CTFM915 in batch */
ADDRESS TSO "PE {{DB2SSID}}.BATCH CLASS(DSNR) ACCESS(READ)" || ,
            " ID({{BATCHUSER}})"

ADDRESS TSO "SETR RACLIST(MDSNPN) REFRESH"
ADDRESS TSO "SETR RACLIST(DSNR) REFRESH"
ADDRESS TSO "SETR RACLIST(FACILITY) REFRESH"
ADDRESS TSO "SETR RACLIST(TCICSTRN) REFRESH"
ADDRESS TSO "SETR RACLIST(SURROGAT) REFRESH"
$$
