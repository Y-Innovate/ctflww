       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM520.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /admin/jobRetries/{provJobID}: a failed job goes back to *
      * N, or to Q for a REMOVE, which only the batch carries out.    *
      * RETRYCOUNT goes up. CREATE and RESET get a new claim token,   *
      * returned in CLAIMTOKEN, because the old one-time phrase is    *
      * gone; a CREATE also puts the player back to P. The other      *
      * actions get a new job token. Except for REMOVE, the token goes*
      * in LCTFC910 for the caller, who commits and starts the submit *
      * task. The caller (the admin wrapper) has checked CTF.ADMIN.   *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Job not found                                         *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 53 = Error: job not failed, or another job is open         *
      * 08 90 = Error: CTFA990, CTFA991 or settings failed            *
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

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

           EXEC SQL INCLUDE TBCTF004 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-PGMNAME    PIC X(8).
          05 W-JOBID      PIC S9(9) COMP-5.
          05 W-COUNT      PIC S9(9) COMP-5.
          05 W-HOURS      PIC S9(4) COMP-5.
          05 W-JOBHASH-IND PIC S9(4) COMP-5.
          05 W-NEWSTATUS  PIC N.

           COPY CTFCTXW.

       01 W-CLAIMHASH     USAGE SQL TYPE IS BINARY(32).
       01 W-JOBHASH       USAGE SQL TYPE IS BINARY(32).

       01 W-LCTFM910.
           COPY LCTFM910.

           COPY CTFSECW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM520.
           COPY LCTFM520.
       01 P-LCTFC910.
           COPY LCTFC910.

       PROCEDURE DIVISION USING P-LCTFM520 P-LCTFC910.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM520 = N'00'
              PERFORM R110-SELECT-JOB
           END-IF

           IF RETURNCODE OF P-LCTFM520 = N'00'
              PERFORM R130-NO-OPEN-JOB
           END-IF

           IF   RETURNCODE OF P-LCTFM520 = N'00'
           AND PROVACTION OF DCLTBCTF004 NOT = C-M
              PERFORM R140-SECRETS
           END-IF

           IF   RETURNCODE OF P-LCTFM520 = N'00'
           AND (PROVACTION OF DCLTBCTF004 = C-C
            OR PROVACTION OF DCLTBCTF004 = C-P)
              PERFORM R150-NEW-CLAIM
           END-IF

           IF RETURNCODE OF P-LCTFM520 = N'00'
              PERFORM R160-UPDATE-JOB
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM520
           MOVE N'00' TO REASONCODE OF P-LCTFM520
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM520
           MOVE SPACES TO JOBSTATUS OF P-LCTFM520
           MOVE SPACES TO CLAIMTOKEN OF P-LCTFM520
           INITIALIZE P-LCTFC910
           MOVE PROVJOBID OF P-LCTFM520 TO W-JOBID
           MOVE -1 TO W-JOBHASH-IND
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R110-SELECT-JOB: The job, only if it failed                   *
      *===============================================================*
       R110-SELECT-JOB SECTION.
           EXEC SQL
              SELECT PLAYERID,
                     PROVACTION,
                     JOBSTATUS
                INTO :W-PLAYERID,
                     :DCLTBCTF004.PROVACTION,
                     :DCLTBCTF004.JOBSTATUS
                FROM TBCTF004
               WHERE PROVJOBID = :W-JOBID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF JOBSTATUS OF DCLTBCTF004 NOT = C-F
                 MOVE N'08' TO RETURNCODE OF P-LCTFM520
                 MOVE N'53' TO REASONCODE OF P-LCTFM520
                 MOVE N'Only a failed job can be retried' TO
                      INFOMESSAGE OF P-LCTFM520
              END-IF
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM520
              MOVE N'01' TO REASONCODE OF P-LCTFM520
              MOVE N'Job not found' TO
                   INFOMESSAGE OF P-LCTFM520
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM520
              MOVE N'21' TO REASONCODE OF P-LCTFM520
              STRING N'SELECT job gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM520
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF PROVACTION OF DCLTBCTF004 = C-M
              MOVE C-Q TO W-NEWSTATUS
           ELSE
              MOVE C-N TO W-NEWSTATUS
           END-IF
           .
       R110-SELECT-JOB-END.
           EXIT.

      *===============================================================*
      * R130-NO-OPEN-JOB: One open job per player                     *
      *===============================================================*
       R130-NO-OPEN-JOB SECTION.
           EXEC SQL
              SELECT COUNT(*)
                INTO :W-COUNT
                FROM TBCTF004
               WHERE PLAYERID = :W-PLAYERID
                 AND JOBSTATUS IN (:C-N, :C-Q, :C-S)
           END-EXEC

           EVALUATE TRUE
           WHEN SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM520
              MOVE N'21' TO REASONCODE OF P-LCTFM520
              STRING N'SELECT jobs gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM520
              PERFORM R900-DSNTIAR
           WHEN W-COUNT > 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM520
              MOVE N'53' TO REASONCODE OF P-LCTFM520
              MOVE N'A job for this player is still open' TO
                   INFOMESSAGE OF P-LCTFM520
           END-EVALUATE
           .
       R130-NO-OPEN-JOB-END.
           EXIT.

      *===============================================================*
      * R140-SECRETS: Settings, and a claim or job token              *
      *===============================================================*
       R140-SECRETS SECTION.
           MOVE N'R' TO OPCODE OF W-LCTFM910
           MOVE 'CTFM910' TO W-PGMNAME
           CALL W-PGMNAME USING W-LCTFM910 P-LCTFC910
           IF RETURNCODE OF W-LCTFM910 NOT = N'00'
              MOVE N'08' TO RETURNCODE OF P-LCTFM520
              MOVE N'90' TO REASONCODE OF P-LCTFM520
              MOVE INFOMESSAGE OF W-LCTFM910 TO
                   INFOMESSAGE OF P-LCTFM520
           END-IF

           IF RETURNCODE OF P-LCTFM520 = N'00'
              PERFORM R800-NEW-TOKEN
              IF A991-OK
                 PERFORM R810-DERIVE
              END-IF
              IF A991-OK
                 MOVE W-TOKEN TO JOBTOKEN OF P-LCTFC910
                 MOVE W-PLAYERID TO PLAYERID OF P-LCTFC910
                 IF PROVACTION OF DCLTBCTF004 = C-C
                 OR PROVACTION OF DCLTBCTF004 = C-P
      *             CREATE and RESET: a claim token for the player
                    MOVE W-TOKENHASH TO W-CLAIMHASH
                    MOVE FUNCTION NATIONAL-OF(W-TOKEN) TO
                         CLAIMTOKEN OF P-LCTFM520
                    COMPUTE W-HOURS =
                       FUNCTION NUMVAL(S-CLAIMHRS OF P-LCTFC910)
                    MOVE -1 TO W-JOBHASH-IND
                 ELSE
                    MOVE W-TOKENHASH TO W-JOBHASH
                    MOVE 0 TO W-JOBHASH-IND
                 END-IF
              ELSE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM520
                 MOVE N'90' TO REASONCODE OF P-LCTFM520
                 MOVE N'CTFA991 failed' TO
                      INFOMESSAGE OF P-LCTFM520
              END-IF
           END-IF

           MOVE SPACES TO W-PHRASE
           .
       R140-SECRETS-END.
           EXIT.

      *===============================================================*
      * R150-NEW-CLAIM: New claim hash and expiry for the player      *
      *===============================================================*
       R150-NEW-CLAIM SECTION.
           EXEC SQL
              UPDATE TBCTF003
                 SET CLAIMHASH    = :W-CLAIMHASH,
                     CLAIMEXPIRES = CURRENT TIMESTAMP + :W-HOURS HOURS,
                     PLAYERSTATUS =
                        CASE WHEN PLAYERSTATUS = :C-F
                              AND :DCLTBCTF004.PROVACTION = :C-C
                             THEN :C-P
                             ELSE PLAYERSTATUS END,
                     UPDATEDBY    = :W-USERID,
                     UPDATEDDATE  = CURRENT TIMESTAMP
               WHERE PLAYERID = :W-PLAYERID
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM520
              MOVE N'32' TO REASONCODE OF P-LCTFM520
              STRING N'UPDATE player gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM520
              PERFORM R900-DSNTIAR
           END-IF
           .
       R150-NEW-CLAIM-END.
           EXIT.

      *===============================================================*
      * R160-UPDATE-JOB: The job is new again                         *
      *===============================================================*
       R160-UPDATE-JOB SECTION.
           EXEC SQL
              UPDATE TBCTF004
                 SET JOBSTATUS     = :W-NEWSTATUS,
                     RETRYCOUNT    = RETRYCOUNT + 1,
                     JOBHASH       = :W-JOBHASH :W-JOBHASH-IND,
                     JESJOBID      = NULL,
                     SUBMITTEDDATE = NULL,
                     COMPLETEDDATE = NULL,
                     JOBRC         = NULL,
                     JOBMESSAGE    = NULL,
                     UPDATEDBY     = :W-USERID,
                     UPDATEDDATE   = CURRENT TIMESTAMP
               WHERE PROVJOBID = :W-JOBID
                 AND JOBSTATUS = :C-F
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE W-NEWSTATUS TO JOBSTATUS OF P-LCTFM520
              IF W-NEWSTATUS = C-N
                 MOVE W-JOBID TO PROVJOBID OF P-LCTFC910
              END-IF
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM520
              MOVE N'53' TO REASONCODE OF P-LCTFM520
              MOVE N'Only a failed job can be retried' TO
                   INFOMESSAGE OF P-LCTFM520
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM520
              MOVE N'32' TO REASONCODE OF P-LCTFM520
              STRING N'UPDATE job gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM520
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R160-UPDATE-JOB-END.
           EXIT.

           COPY CTFSECP.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM520==.

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

       END PROGRAM CTFM520.
