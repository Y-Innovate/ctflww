//CTFBATCH JOB 'CTF BATCH',CLASS={{JOBCLASS}},MSGCLASS=A,
//         USER={{BATCHUSER}}
//*
//* Scheduled batch of the CTF application (S3 and S4), once a day
//* from ZWS. Runs under the batch userid, whose group-special
//* authority carries out the RACF commands. The ZWS userid needs
//* surrogate access to it: {{BATCHUSER}}.SUBMIT in RACF.jcl.
//* STEP1 CTFM930: expire claims, fail stuck jobs, write the commands
//* REXX  IEBGENER: copy the REXX below into a temporary library
//* STEP2 CTFR931: carry out the RACF commands, write the results
//* STEP3 CTFM915: record the results in DB2
//* Rows that STEP1 handed on but that got no result, because a later
//* step failed, are failed by STEP1 of a later run (S3).
//*
//STEP1    EXEC PGM=IKJEFT1B
//STEPLIB  DD DISP=SHR,DSN={{LOADLIB}}
//         DD DISP=SHR,DSN={{DB2SSHLQ}}.SDSNEXIT
//         DD DISP=SHR,DSN={{DB2HLQ}}.SDSNLOAD
//CMDS     DD DSN=&&CMDS,DISP=(NEW,PASS),UNIT=SYSDA,
//            SPACE=(TRK,(5,5)),RECFM=FB,LRECL=80
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//SYSTSIN  DD *
 DSN SYSTEM({{DB2SSID}})
 RUN PROGRAM(CTFM930) PLAN({{DB2PLAN}})
 END
/*
//REXX     EXEC PGM=IEBGENER,COND=(4,LT,STEP1)
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//SYSUT2   DD DSN=&&EXEC(CTFR931),DISP=(NEW,PASS),UNIT=SYSDA,
//            SPACE=(TRK,(1,1,1)),RECFM=FB,LRECL=80
//SYSUT1   DD *,DLM=$$
/* REXX ------------------------------------------------------------ */
/* CTFR931: RACF commands of the scheduled CTF batch.                */
/* Reads CMDS from CTFM930: job ID (1-9), action (11), userid        */
/* (13-20), group (22-29). Runs one command per line and writes      */
/* RESULTS for CTFM915: job ID (1-9), O or F (11), return code       */
/* (13-15), first line of the command output (17-72).                */
/* Never gets CREATE or RESET: those carry a passphrase.             */
/* ----------------------------------------------------------------- */
"EXECIO * DISKR CMDS (STEM in. FINIS"
if rc <> 0 then do
   say 'CTFR931 READ CMDS RC' rc
   exit 8
end

out.0 = 0
do i = 1 to in.0
   jobid  = substr(in.i, 1, 9)
   action = substr(in.i, 11, 1)
   userid = strip(substr(in.i, 13, 8))
   group  = strip(substr(in.i, 22, 8))

   select
      when action = 'N' & group <> '' then
         cmd = 'CONNECT' userid 'GROUP('group')'
      when action = 'M' & group <> '' then
         cmd = 'REMOVE' userid 'GROUP('group')'
      when action = 'V' then cmd = 'ALTUSER' userid 'REVOKE'
      when action = 'U' then cmd = 'ALTUSER' userid 'RESUME'
      when action = 'X' then cmd = 'DELUSER' userid
      otherwise cmd = ''
   end

   if cmd = '' then do
      cmdrc = 8
      msg = 'Not an action for the batch, or no group'
   end
   else do
      lines.0 = 0
      call outtrap 'lines.'
      address TSO cmd
      cmdrc = rc
      call outtrap 'OFF'
      msg = ''
      if lines.0 > 0 then msg = strip(lines.1)
   end

   if cmdrc = 0 then result = 'O'
   else result = 'F'
   if cmdrc < 0 | cmdrc > 999 then rcout = '999'
   else rcout = right(cmdrc, 3, '0')
   say jobid action userid group 'RC' cmdrc

   n = out.0 + 1
   out.n = jobid result rcout left(msg, 56)
   out.0 = n
end

"EXECIO" out.0 "DISKW RESULTS (STEM out. FINIS"
if rc <> 0 then do
   say 'CTFR931 WRITE RESULTS RC' rc
   exit 8
end

say 'CTFR931 COMMANDS:' out.0
exit 0
$$
//STEP2    EXEC PGM=IKJEFT1B,COND=(4,LT,STEP1)
//SYSEXEC  DD DSN=&&EXEC,DISP=(OLD,DELETE)
//CMDS     DD DSN=&&CMDS,DISP=(OLD,DELETE)
//RESULTS  DD DSN=&&RES,DISP=(NEW,PASS),UNIT=SYSDA,
//            SPACE=(TRK,(5,5)),RECFM=FB,LRECL=80
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
 %CTFR931
/*
//STEP3    EXEC PGM=IKJEFT1B,COND=(4,LT,STEP1)
//STEPLIB  DD DISP=SHR,DSN={{LOADLIB}}
//         DD DISP=SHR,DSN={{DB2SSHLQ}}.SDSNEXIT
//         DD DISP=SHR,DSN={{DB2HLQ}}.SDSNLOAD
//SYSIN    DD DSN=&&RES,DISP=(OLD,DELETE)
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//SYSTSIN  DD *
 DSN SYSTEM({{DB2SSID}})
 RUN PROGRAM(CTFM915) PLAN({{DB2PLAN}})
 END
/*
