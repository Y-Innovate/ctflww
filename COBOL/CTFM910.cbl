       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM910.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * Provisioning job support:                                     *
      * OPCODE R: read the SETTINGS reftable into LCTFC910            *
      * OPCODE C: claim a job for submission. The job must be new and *
      *           the token must match: for CREATE and RESET the      *
      *           claim token and the player's hash, for the other    *
      *           actions the job token and JOBHASH. So only whoever  *
      *           made the job can submit it, and only once. Sets the *
      *           job submitted and clears JOBHASH; returns the job   *
      *           in LCTFC910, for CREATE and RESET with the phrase   *
      *           derived from the token.                             *
      * OPCODE F: job row is failed, and a pending player too         *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Job not found, or not new any more                    *
      * 08 01 = Error: OPCODE invalid                                 *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 57 = Error: wrong claim token                              *
      * 08 61/63 = Error: SQL error on OPEN/FETCH                     *
      * 08 90 = Error: CTFA991 failed                                 *
      * 08 91 = Error: a setting is missing                           *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBCTF001 END-EXEC.

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

           EXEC SQL INCLUDE TBCTF004 END-EXEC.

       01 WORK.
          05 W-PGMNAME    PIC X(8).
          05 W-SQLCODE    PIC -99999.
          05 W-JOBID      PIC S9(9) COMP-5.
          05 W-PLAYERID   PIC S9(9) COMP-5.
          05 W-USERID     PIC N(8).
          05 W-VALUE      PIC X(255).

       01 W-CLAIMHASH     USAGE SQL TYPE IS BINARY(32).
       01 W-JOBHASH       USAGE SQL TYPE IS BINARY(32).

       01 W-LCTFA990.
           COPY LCTFA990.

           COPY CTFSECW.

       01 C-CODES.
          05 C-A          PIC N VALUE N'A'.
          05 C-C          PIC N VALUE N'C'.
          05 C-D          PIC N VALUE N'D'.
          05 C-F          PIC N VALUE N'F'.
          05 C-I          PIC N VALUE N'I'.
          05 C-N          PIC N VALUE N'N'.
          05 C-P          PIC N VALUE N'P'.
          05 C-R          PIC N VALUE N'R'.
          05 C-S          PIC N VALUE N'S'.
          05 C-Y          PIC N VALUE N'Y'.
          05 C-CATEGORY   PIC N(8) VALUE N'CATEGORY'.
          05 C-SETTINGS   PIC N(8) VALUE N'SETTINGS'.
          05 C-NOTSUBMITTED.
             49 C-NOTSUBMITTED-LEN  PIC S9(4) COMP-5 VALUE 28.
             49 C-NOTSUBMITTED-TEXT PIC N(28)
                VALUE N'The job could not be started'.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM910.
           COPY LCTFM910.
       01 P-LCTFC910.
           COPY LCTFC910.

       PROCEDURE DIVISION USING P-LCTFM910 P-LCTFC910.
       MAIN SECTION.
           PERFORM R001-INIT

           EVALUATE OPCODE OF P-LCTFM910
           WHEN N'R'
              PERFORM R110-READ-SETTINGS
           WHEN N'C'
              PERFORM R140-CLAIM-JOB
           WHEN N'F'
              PERFORM R130-SET-FAILED
           WHEN OTHER
              MOVE N'08' TO RETURNCODE OF P-LCTFM910
              MOVE N'01' TO REASONCODE OF P-LCTFM910
              MOVE N'OPCODE is invalid' TO
                   INFOMESSAGE OF P-LCTFM910
           END-EVALUATE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM910
           MOVE N'00' TO REASONCODE OF P-LCTFM910
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM910

           MOVE PROVJOBID OF P-LCTFM910 TO W-JOBID
           MOVE PLAYERID OF P-LCTFM910 TO W-PLAYERID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R110-READ-SETTINGS: Read the SETTINGS reftable                *
      *===============================================================*
       R110-READ-SETTINGS SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT TABKEY,
                     TABVALUE
                FROM TBCTF001
               WHERE TABLEID = :C-SETTINGS
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM910
              MOVE N'61' TO REASONCODE OF P-LCTFM910
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM910
              PERFORM R900-DSNTIAR
           ELSE
              PERFORM UNTIL SQLCODE NOT = 0
                 EXEC SQL
                    FETCH C1
                     INTO :DCLTBCTF001.TABKEY,
                          :DCLTBCTF001.TABVALUE
                            :DCLTBCTF001.TABVALUE-IND
                 END-EXEC

                 EVALUATE SQLCODE
                 WHEN 0
                    PERFORM R115-STORE-SETTING
                 WHEN 100
                    CONTINUE
                 WHEN OTHER
                    MOVE SQLCODE TO W-SQLCODE
                    MOVE N'08' TO RETURNCODE OF P-LCTFM910
                    MOVE N'63' TO REASONCODE OF P-LCTFM910
                    STRING N'FETCH CURSOR gave SQLCODE='
                           FUNCTION NATIONAL-OF(W-SQLCODE)
                       DELIMITED BY SIZE
                       INTO INFOMESSAGE OF P-LCTFM910
                    PERFORM R900-DSNTIAR
                 END-EVALUATE
              END-PERFORM

              EXEC SQL
                 CLOSE C1
              END-EXEC
           END-IF

           IF RETURNCODE OF P-LCTFM910 = N'00'
              IF S-BATCHUSR OF P-LCTFC910 = SPACES
              OR S-PLAYGRP OF P-LCTFC910 = SPACES
              OR S-JOBCLASS OF P-LCTFC910 = SPACES
              OR S-MSGCLASS OF P-LCTFC910 = SPACES
              OR S-DB2SSID OF P-LCTFC910 = SPACES
              OR S-DB2HLQ OF P-LCTFC910 = SPACES
              OR S-DB2SSHLQ OF P-LCTFC910 = SPACES
              OR S-CTFPLAN OF P-LCTFC910 = SPACES
              OR S-LOADLIB OF P-LCTFC910 = SPACES
              OR S-CLAIMHRS OF P-LCTFC910 = SPACES
              OR S-SUBMUSR OF P-LCTFC910 = SPACES
              OR S-SUBMTXN OF P-LCTFC910 = SPACES
                 MOVE N'08' TO RETURNCODE OF P-LCTFM910
                 MOVE N'91' TO REASONCODE OF P-LCTFM910
                 MOVE N'A SETTINGS entry in TBCTF001 is missing' TO
                      INFOMESSAGE OF P-LCTFM910
              END-IF
           END-IF
           .
       R110-READ-SETTINGS-END.
           EXIT.

      *===============================================================*
      * R115-STORE-SETTING: Store one setting                         *
      *===============================================================*
       R115-STORE-SETTING SECTION.
           IF  TABVALUE-IND OF DCLTBCTF001 >= 0
           AND TABVALUE-LEN OF DCLTBCTF001 > 0
              MOVE FUNCTION DISPLAY-OF(TABVALUE-TEXT OF DCLTBCTF001
                 (1:TABVALUE-LEN OF DCLTBCTF001)) TO W-VALUE

              EVALUATE TABKEY OF DCLTBCTF001
              WHEN N'BATCHUSR'
                 MOVE W-VALUE TO S-BATCHUSR OF P-LCTFC910
              WHEN N'PLAYGRP '
                 MOVE W-VALUE TO S-PLAYGRP OF P-LCTFC910
              WHEN N'JOBCLASS'
                 MOVE W-VALUE TO S-JOBCLASS OF P-LCTFC910
              WHEN N'MSGCLASS'
                 MOVE W-VALUE TO S-MSGCLASS OF P-LCTFC910
              WHEN N'DB2SSID '
                 MOVE W-VALUE TO S-DB2SSID OF P-LCTFC910
              WHEN N'DB2HLQ  '
                 MOVE W-VALUE TO S-DB2HLQ OF P-LCTFC910
              WHEN N'DB2SSHLQ'
                 MOVE W-VALUE TO S-DB2SSHLQ OF P-LCTFC910
              WHEN N'CTFPLAN '
                 MOVE W-VALUE TO S-CTFPLAN OF P-LCTFC910
              WHEN N'LOADLIB '
                 MOVE W-VALUE TO S-LOADLIB OF P-LCTFC910
              WHEN N'CLAIMHRS'
                 MOVE W-VALUE TO S-CLAIMHRS OF P-LCTFC910
              WHEN N'SUBMUSR '
                 MOVE W-VALUE TO S-SUBMUSR OF P-LCTFC910
              WHEN N'SUBMTXN '
                 MOVE W-VALUE TO S-SUBMTXN OF P-LCTFC910
              END-EVALUATE
           END-IF
           .
       R115-STORE-SETTING-END.
           EXIT.

      *===============================================================*
      * R120-SET-SUBMITTED: Job row is submitted                      *
      *===============================================================*
       R120-SET-SUBMITTED SECTION.
           EXEC SQL
              UPDATE TBCTF004
                 SET JOBSTATUS     = :C-S,
                     JOBHASH       = NULL,
                     SUBMITTEDDATE = CURRENT TIMESTAMP,
                     UPDATEDDATE   = CURRENT TIMESTAMP
               WHERE PROVJOBID = :W-JOBID
                 AND JOBSTATUS = :C-N
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM910
              MOVE N'01' TO REASONCODE OF P-LCTFM910
              MOVE N'The job is not new any more' TO
                   INFOMESSAGE OF P-LCTFM910
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM910
              MOVE N'32' TO REASONCODE OF P-LCTFM910
              STRING N'UPDATE job gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM910
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-SET-SUBMITTED-END.
           EXIT.

      *===============================================================*
      * R130-SET-FAILED: Job row and player are failed                *
      *===============================================================*
       R130-SET-FAILED SECTION.
           EXEC SQL
              UPDATE TBCTF004
                 SET JOBSTATUS     = :C-F,
                     JOBHASH       = NULL,
                     JOBMESSAGE    = :C-NOTSUBMITTED,
                     COMPLETEDDATE = CURRENT TIMESTAMP,
                     UPDATEDDATE   = CURRENT TIMESTAMP
               WHERE PROVJOBID = :W-JOBID
           END-EXEC

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM910
              MOVE N'32' TO REASONCODE OF P-LCTFM910
              STRING N'UPDATE job gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM910
              PERFORM R900-DSNTIAR
           END-IF

           IF RETURNCODE OF P-LCTFM910 = N'00'
              EXEC SQL
                 UPDATE TBCTF003
                    SET PLAYERSTATUS = :C-F,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE PLAYERID = :W-PLAYERID
                    AND PLAYERSTATUS = :C-P
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM910
                 MOVE N'32' TO REASONCODE OF P-LCTFM910
                 STRING N'UPDATE player gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM910
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF
           .
       R130-SET-FAILED-END.
           EXIT.

      *===============================================================*
      * R140-CLAIM-JOB: Check the token, set the job submitted and    *
      * return the job                                                *
      *===============================================================*
       R140-CLAIM-JOB SECTION.
           EXEC SQL
              SELECT J.PROVACTION,
                     J.RACFGROUP,
                     J.PLAYERID,
                     J.JOBHASH,
                     P.RACFUSERID,
                     P.PLAYERSTATUS,
                     P.CLAIMHASH
                INTO :DCLTBCTF004.PROVACTION,
                     :DCLTBCTF004.RACFGROUP
                       :DCLTBCTF004.RACFGROUP-IND,
                     :W-PLAYERID,
                     :W-JOBHASH
                       :DCLTBCTF004.JOBHASH-IND,
                     :DCLTBCTF003.RACFUSERID,
                     :DCLTBCTF003.PLAYERSTATUS,
                     :W-CLAIMHASH
                       :DCLTBCTF003.CLAIMHASH-IND
                FROM TBCTF004 J,
                     TBCTF003 P
               WHERE J.PROVJOBID = :W-JOBID
                 AND J.JOBSTATUS = :C-N
                 AND P.PLAYERID = J.PLAYERID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE CLAIMTOKEN OF P-LCTFM910 TO W-TOKEN
              PERFORM R810-DERIVE
              EVALUATE TRUE
              WHEN NOT A991-OK
                 MOVE N'08' TO RETURNCODE OF P-LCTFM910
                 MOVE N'90' TO REASONCODE OF P-LCTFM910
                 MOVE N'CTFA991 failed' TO
                      INFOMESSAGE OF P-LCTFM910
              WHEN PROVACTION OF DCLTBCTF004 = C-C
               AND PLAYERSTATUS OF DCLTBCTF003 NOT = C-P
                 MOVE N'04' TO RETURNCODE OF P-LCTFM910
                 MOVE N'01' TO REASONCODE OF P-LCTFM910
                 MOVE N'The player is not pending any more' TO
                      INFOMESSAGE OF P-LCTFM910
      *       CREATE and RESET (P): the claim token
              WHEN PROVACTION OF DCLTBCTF004 = C-C
              WHEN PROVACTION OF DCLTBCTF004 = C-P
                 IF  CLAIMHASH-IND OF DCLTBCTF003 >= 0
                 AND W-TOKENHASH = W-CLAIMHASH
                    PERFORM R120-SET-SUBMITTED
                 ELSE
                    MOVE N'08' TO RETURNCODE OF P-LCTFM910
                    MOVE N'57' TO REASONCODE OF P-LCTFM910
                    MOVE N'Wrong claim token' TO
                         INFOMESSAGE OF P-LCTFM910
                 END-IF
      *       All other actions: the job token
              WHEN OTHER
                 IF  JOBHASH-IND OF DCLTBCTF004 >= 0
                 AND W-TOKENHASH = W-JOBHASH
                    PERFORM R120-SET-SUBMITTED
                 ELSE
                    MOVE N'08' TO RETURNCODE OF P-LCTFM910
                    MOVE N'57' TO REASONCODE OF P-LCTFM910
                    MOVE N'Wrong job token' TO
                         INFOMESSAGE OF P-LCTFM910
                 END-IF
              END-EVALUATE
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM910
              MOVE N'01' TO REASONCODE OF P-LCTFM910
              MOVE N'Job not found, or not new any more' TO
                   INFOMESSAGE OF P-LCTFM910
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM910
              MOVE N'21' TO REASONCODE OF P-LCTFM910
              STRING N'SELECT job gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM910
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM910 = N'00'
              MOVE FUNCTION DISPLAY-OF(PROVACTION OF DCLTBCTF004) TO
                   PROVACTION OF P-LCTFC910
              MOVE W-JOBID TO PROVJOBID OF P-LCTFC910
              MOVE W-PLAYERID TO PLAYERID OF P-LCTFC910
              MOVE FUNCTION DISPLAY-OF(RACFUSERID OF DCLTBCTF003) TO
                   RACFUSERID OF P-LCTFC910
              IF PROVACTION OF DCLTBCTF004 = C-C
              OR PROVACTION OF DCLTBCTF004 = C-P
                 MOVE W-PHRASE TO ONETIMEPHRASE OF P-LCTFC910
              ELSE
                 MOVE SPACES TO ONETIMEPHRASE OF P-LCTFC910
              END-IF
              IF RACFGROUP-IND OF DCLTBCTF004 < 0
                 MOVE SPACES TO EVENTGROUP OF P-LCTFC910
              ELSE
                 MOVE FUNCTION DISPLAY-OF(RACFGROUP OF DCLTBCTF004) TO
                      EVENTGROUP OF P-LCTFC910
              END-IF
           END-IF

           MOVE SPACES TO W-PHRASE
           MOVE SPACES TO W-TOKEN
           .
       R140-CLAIM-JOB-END.
           EXIT.

           COPY CTFSECP.

      *===============================================================*
      * R900-DSNTIAR: Format SQLCA information when error             *
      *===============================================================*
       R900-DSNTIAR SECTION.
           CALL 'DSNTIAR' USING SQLCA ERROR-MESSAGE ERROR-TEXT-LEN

           PERFORM VARYING ERROR-INDEX
              FROM 1 BY 1 UNTIL ERROR-INDEX = 10
                   DISPLAY ERROR-TEXT(ERROR-INDEX)
           END-PERFORM
           .
       R900-DSNTIAR-END.
           EXIT.

       END PROGRAM CTFM910.
