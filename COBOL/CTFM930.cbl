       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM930.
      *===============================================================*
      * This program is a DB2 batch program of the CTF application.   *
      * First step of the scheduled batch (JCL/CTFBATCH):             *
      * S4: READY players whose claim has expired get a queued REVOKE *
      *     and their claim hash is cleared. Their places without a   *
      *     team, or in a team of one without any activity, are       *
      *     deleted with that team, and PLAYERCOUNT goes down, so     *
      *     they no longer count towards the cap.                     *
      * S3: jobs submitted longer than setting JOBMINS ago without a  *
      *     result become FAILED. Jobs still new after that time were *
      *     never submitted: CREATE and RESET become FAILED, because  *
      *     their one-time phrase is gone; the other actions go to    *
      *     the batch. A pending player without a live CREATE job     *
      *     becomes FAILED.                                           *
      * Then every queued row, and those old new rows, goes to file   *
      * CMDS for the REXX step, and is set SUBMITTED. CTFM915 records *
      * the results in the last step.                                 *
      * All in one unit of work. Static SQL, linked with DSNELI: run  *
      * it with DSN RUN under IKJEFT1B, under the batch userid.       *
      * ------------------------------------------------------------- *
      * Output: file CMDS, one record per job                         *
      * Col 1-9   = PROVJOBID, with leading zeros                     *
      * Col 11    = PROVACTION                                        *
      * Col 13-20 = RACF userid                                       *
      * Col 22-29 = RACF group, for CONNECT and REMOVE                *
      * RETURN-CODE                                                   *
      *  0 = Success                                                  *
      *  8 = An error; everything is rolled back. See SYSOUT          *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CMDS ASSIGN TO CMDS
                  FILE STATUS IS W-FS.

       DATA DIVISION.
       FILE SECTION.
       FD CMDS
           RECORDING MODE F.
       01 CMD-REC         PIC X(80).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBCTF001 END-EXEC.

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

           EXEC SQL INCLUDE TBCTF004 END-EXEC.

       01 WORK.
          05 W-PGMNAME    PIC X(8).
          05 W-SQLCODE    PIC -99999.
          05 W-FS         PIC XX.
          05 W-EOF        PIC X.
          05 W-RC         PIC S9(4) COMP-5 VALUE 0.
          05 W-NOW        PIC X(26).
          05 W-LIMIT      PIC X(26).
          05 W-MINS       PIC S9(9) COMP-5 VALUE 60.
          05 W-VALUE      PIC X(255).
          05 W-PLAYERID   PIC S9(9) COMP-5.
          05 W-EXPIRED    PIC S9(9) COMP-5 VALUE 0.
          05 W-STUCK      PIC S9(9) COMP-5 VALUE 0.
          05 W-ROWS       PIC S9(9) COMP-5 VALUE 0.
          05 W-COUNT-E    PIC Z(8)9.

       01 W-CMD.
          05 W-CMD-JOBID   PIC 9(9).
          05 FILLER        PIC X VALUE SPACE.
          05 W-CMD-ACTION  PIC X.
          05 FILLER        PIC X VALUE SPACE.
          05 W-CMD-USERID  PIC X(8).
          05 FILLER        PIC X VALUE SPACE.
          05 W-CMD-GROUP   PIC X(8).
          05 FILLER        PIC X(51) VALUE SPACES.

       01 W-LCTFA990.
           COPY LCTFA990.

       01 C-CODES.
          05 C-C          PIC N VALUE N'C'.
          05 C-D          PIC N VALUE N'D'.
          05 C-F          PIC N VALUE N'F'.
          05 C-M          PIC N VALUE N'M'.
          05 C-N          PIC N VALUE N'N'.
          05 C-P          PIC N VALUE N'P'.
          05 C-Q          PIC N VALUE N'Q'.
          05 C-R          PIC N VALUE N'R'.
          05 C-S          PIC N VALUE N'S'.
          05 C-U          PIC N VALUE N'U'.
          05 C-V          PIC N VALUE N'V'.
          05 C-X          PIC N VALUE N'X'.
          05 C-SETTINGS   PIC N(8) VALUE N'SETTINGS'.
          05 C-JOBMINS    PIC N(8) VALUE N'JOBMINS '.
          05 C-MSG-STUCK.
             49 C-MSG-STUCK-LEN  PIC S9(4) COMP-5 VALUE 31.
             49 C-MSG-STUCK-TEXT PIC N(31)
                VALUE N'No result within the time limit'.
          05 C-MSG-NEVER.
             49 C-MSG-NEVER-LEN  PIC S9(4) COMP-5 VALUE 44.
             49 C-MSG-NEVER-TEXT PIC N(44)
                VALUE N'Never submitted; retry for a new claim token'.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       PROCEDURE DIVISION.
       MAIN SECTION.
           PERFORM R001-INIT

           IF W-RC = 0
              PERFORM R100-S4-EXPIRE
           END-IF

           IF W-RC = 0
              PERFORM R200-S3-STUCK
           END-IF

           IF W-RC = 0
              PERFORM R300-PICK-ROWS
           END-IF

           PERFORM R009-FINISH
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Open the output, userid, time limit                *
      *===============================================================*
       R001-INIT SECTION.
           OPEN OUTPUT CMDS

           IF W-FS NOT = '00'
              MOVE 8 TO W-RC
              DISPLAY 'CTFM930 OPEN CMDS FILE STATUS ' W-FS
           END-IF

           IF W-RC = 0
              MOVE 'CTFA990' TO W-PGMNAME
              CALL W-PGMNAME USING W-LCTFA990
              IF RETURNCODE OF W-LCTFA990 NOT = N'00'
                 MOVE 8 TO W-RC
                 DISPLAY 'CTFM930 CTFA990 FAILED'
              END-IF
           END-IF

           IF W-RC = 0
              EXEC SQL
                 SELECT TABVALUE
                   INTO :DCLTBCTF001.TABVALUE
                          :DCLTBCTF001.TABVALUE-IND
                   FROM TBCTF001
                  WHERE TABLEID = :C-SETTINGS
                    AND TABKEY = :C-JOBMINS
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 IF  TABVALUE-IND OF DCLTBCTF001 >= 0
                 AND TABVALUE-LEN OF DCLTBCTF001 > 0
                    MOVE FUNCTION DISPLAY-OF(TABVALUE-TEXT OF
                       DCLTBCTF001(1:TABVALUE-LEN OF DCLTBCTF001))
                      TO W-VALUE
                    IF FUNCTION TEST-NUMVAL(W-VALUE) = 0
                       COMPUTE W-MINS = FUNCTION NUMVAL(W-VALUE)
                    END-IF
                 END-IF
              WHEN 100
                 DISPLAY 'CTFM930 SETTING JOBMINS MISSING, USING 60'
              WHEN OTHER
                 MOVE 8 TO W-RC
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF

           IF W-RC = 0
              EXEC SQL
                 SELECT CURRENT TIMESTAMP,
                        CURRENT TIMESTAMP - :W-MINS MINUTES
                   INTO :W-NOW,
                        :W-LIMIT
                   FROM SYSIBM.SYSDUMMY1
              END-EXEC

              IF SQLCODE NOT = 0
                 MOVE 8 TO W-RC
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R100-S4-EXPIRE: Unclaimed accounts, one player at a time      *
      *===============================================================*
       R100-S4-EXPIRE SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT PLAYERID
                FROM TBCTF003
               WHERE PLAYERSTATUS = :C-R
                 AND CLAIMHASH IS NOT NULL
                 AND CLAIMEXPIRES < :W-NOW
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           MOVE 'N' TO W-EOF
           IF SQLCODE NOT = 0
              MOVE 8 TO W-RC
              PERFORM R900-DSNTIAR
           END-IF

           PERFORM UNTIL W-RC NOT = 0
                      OR W-EOF = 'Y'
              EXEC SQL
                 FETCH C1
                  INTO :W-PLAYERID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 ADD 1 TO W-EXPIRED
                 PERFORM R110-EXPIRE-ONE
              WHEN 100
                 MOVE 'Y' TO W-EOF
              WHEN OTHER
                 MOVE 8 TO W-RC
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-PERFORM

           EXEC SQL
              CLOSE C1
           END-EXEC

           MOVE W-EXPIRED TO W-COUNT-E
           DISPLAY 'CTFM930 EXPIRED CLAIMS: ' W-COUNT-E
           .
       R100-S4-EXPIRE-END.
           EXIT.

      *===============================================================*
      * R110-EXPIRE-ONE: Queue a REVOKE, give up the quiet places and *
      * teams of one, clear the claim hash. A place in a team with    *
      * other members stays, so MEMBERCOUNT stays right               *
      *===============================================================*
       R110-EXPIRE-ONE SECTION.
           EXEC SQL
              INSERT
                INTO TBCTF004
                     (PLAYERID,
                      PROVACTION,
                      JOBSTATUS,
                      RETRYCOUNT,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:W-PLAYERID,
                     :C-V,
                     :C-Q,
                     0,
                     :W-LCTFA990.USERID,
                     CURRENT TIMESTAMP,
                     :W-LCTFA990.USERID,
                     CURRENT TIMESTAMP)
           END-EXEC
           PERFORM R190-CHECK-SQL

      *    Places that can go: no team, or a team of one of this
      *    player without any activity
           IF W-RC = 0
              EXEC SQL
                 UPDATE TBCTF002 E
                    SET PLAYERCOUNT = PLAYERCOUNT - 1,
                        UPDATEDBY   = :W-LCTFA990.USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE EXISTS
                       (SELECT 1 FROM TBCTF006 PA
                         WHERE PA.EVENTID = E.EVENTID
                           AND PA.PLAYERID = :W-PLAYERID
                           AND (PA.TEAMID IS NULL
                            OR  EXISTS
                               (SELECT 1 FROM TBCTF005 T
                                 WHERE T.TEAMID = PA.TEAMID
                                   AND T.CAPTAINID = PA.PLAYERID
                                   AND T.MEMBERCOUNT = 1
                                   AND NOT EXISTS
                                      (SELECT 1 FROM TBCTF013 S
                                        WHERE S.TEAMID = T.TEAMID)
                                   AND NOT EXISTS
                                      (SELECT 1 FROM TBCTF015 H
                                        WHERE H.TEAMID = T.TEAMID)
                                   AND NOT EXISTS
                                      (SELECT 1 FROM TBCTF016 A
                                        WHERE A.TEAMID = T.TEAMID))))
              END-EXEC
              PERFORM R190-CHECK-SQL
           END-IF

           IF W-RC = 0
              EXEC SQL
                 DELETE
                   FROM TBCTF006 PA
                  WHERE PA.PLAYERID = :W-PLAYERID
                    AND (PA.TEAMID IS NULL
                     OR  EXISTS
                        (SELECT 1 FROM TBCTF005 T
                          WHERE T.TEAMID = PA.TEAMID
                            AND T.CAPTAINID = PA.PLAYERID
                            AND T.MEMBERCOUNT = 1
                            AND NOT EXISTS
                               (SELECT 1 FROM TBCTF013 S
                                 WHERE S.TEAMID = T.TEAMID)
                            AND NOT EXISTS
                               (SELECT 1 FROM TBCTF015 H
                                 WHERE H.TEAMID = T.TEAMID)
                            AND NOT EXISTS
                               (SELECT 1 FROM TBCTF016 A
                                 WHERE A.TEAMID = T.TEAMID)))
              END-EXEC
              PERFORM R190-CHECK-SQL
           END-IF

      *    Teams of one that no place refers to any more
           IF W-RC = 0
              EXEC SQL
                 DELETE
                   FROM TBCTF005 T
                  WHERE T.CAPTAINID = :W-PLAYERID
                    AND T.MEMBERCOUNT = 1
                    AND NOT EXISTS
                       (SELECT 1 FROM TBCTF006 PA
                         WHERE PA.TEAMID = T.TEAMID)
                    AND NOT EXISTS
                       (SELECT 1 FROM TBCTF013 S
                         WHERE S.TEAMID = T.TEAMID)
                    AND NOT EXISTS
                       (SELECT 1 FROM TBCTF015 H
                         WHERE H.TEAMID = T.TEAMID)
                    AND NOT EXISTS
                       (SELECT 1 FROM TBCTF016 A
                         WHERE A.TEAMID = T.TEAMID)
              END-EXEC
              PERFORM R190-CHECK-SQL
           END-IF

           IF W-RC = 0
              EXEC SQL
                 UPDATE TBCTF003
                    SET CLAIMHASH   = NULL,
                        UPDATEDBY   = :W-LCTFA990.USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE PLAYERID = :W-PLAYERID
              END-EXEC
              PERFORM R190-CHECK-SQL
           END-IF
           .
       R110-EXPIRE-ONE-END.
           EXIT.

      *===============================================================*
      * R190-CHECK-SQL: 0 and 100 are fine, anything else is an error *
      *===============================================================*
       R190-CHECK-SQL SECTION.
           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE 8 TO W-RC
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CHECK-SQL-END.
           EXIT.

      *===============================================================*
      * R200-S3-STUCK: Jobs without a result within the limit         *
      *===============================================================*
       R200-S3-STUCK SECTION.
           EXEC SQL
              UPDATE TBCTF004
                 SET JOBSTATUS     = :C-F,
                     JOBHASH       = NULL,
                     JOBMESSAGE    = :C-MSG-STUCK,
                     COMPLETEDDATE = CURRENT TIMESTAMP,
                     UPDATEDBY     = :W-LCTFA990.USERID,
                     UPDATEDDATE   = CURRENT TIMESTAMP
               WHERE JOBSTATUS = :C-S
                 AND SUBMITTEDDATE < :W-LIMIT
           END-EXEC
           PERFORM R190-CHECK-SQL
           IF SQLCODE = 0
              ADD SQLERRD(3) TO W-STUCK
           END-IF

           IF W-RC = 0
              EXEC SQL
                 UPDATE TBCTF004
                    SET JOBSTATUS     = :C-F,
                        JOBHASH       = NULL,
                        JOBMESSAGE    = :C-MSG-NEVER,
                        COMPLETEDDATE = CURRENT TIMESTAMP,
                        UPDATEDBY     = :W-LCTFA990.USERID,
                        UPDATEDDATE   = CURRENT TIMESTAMP
                  WHERE JOBSTATUS = :C-N
                    AND PROVACTION IN (:C-C, :C-P)
                    AND UPDATEDDATE < :W-LIMIT
              END-EXEC
              PERFORM R190-CHECK-SQL
              IF SQLCODE = 0
                 ADD SQLERRD(3) TO W-STUCK
              END-IF
           END-IF

           IF W-RC = 0
              EXEC SQL
                 UPDATE TBCTF003 P
                    SET PLAYERSTATUS = :C-F,
                        UPDATEDBY    = :W-LCTFA990.USERID,
                        UPDATEDDATE  = CURRENT TIMESTAMP
                  WHERE P.PLAYERSTATUS = :C-P
                    AND NOT EXISTS
                       (SELECT 1 FROM TBCTF004 J
                         WHERE J.PLAYERID = P.PLAYERID
                           AND J.PROVACTION = :C-C
                           AND J.JOBSTATUS IN (:C-N, :C-Q, :C-S, :C-D))
              END-EXEC
              PERFORM R190-CHECK-SQL
           END-IF

           MOVE W-STUCK TO W-COUNT-E
           DISPLAY 'CTFM930 JOBS FAILED BY TIME LIMIT: ' W-COUNT-E
           .
       R200-S3-STUCK-END.
           EXIT.

      *===============================================================*
      * R300-PICK-ROWS: Queued rows, and old new rows of the actions  *
      * the batch can carry out, to CMDS                              *
      *===============================================================*
       R300-PICK-ROWS SECTION.
           EXEC SQL
              DECLARE C2 CURSOR FOR
              SELECT J.PROVJOBID,
                     J.PROVACTION,
                     J.RACFGROUP,
                     P.RACFUSERID
                FROM TBCTF004 J
                JOIN TBCTF003 P
                  ON P.PLAYERID = J.PLAYERID
               WHERE J.JOBSTATUS = :C-Q
                  OR (J.JOBSTATUS = :C-N
                 AND  J.PROVACTION IN (:C-N, :C-M, :C-V, :C-U, :C-X)
                 AND  J.UPDATEDDATE < :W-LIMIT)
               ORDER BY J.PROVJOBID
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C2
           END-EXEC

           MOVE 'N' TO W-EOF
           IF SQLCODE NOT = 0
              MOVE 8 TO W-RC
              PERFORM R900-DSNTIAR
           END-IF

           PERFORM UNTIL W-RC NOT = 0
                      OR W-EOF = 'Y'
              EXEC SQL
                 FETCH C2
                  INTO :DCLTBCTF004.PROVJOBID,
                       :DCLTBCTF004.PROVACTION,
                       :DCLTBCTF004.RACFGROUP
                         :DCLTBCTF004.RACFGROUP-IND,
                       :DCLTBCTF003.RACFUSERID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R310-ONE-ROW
              WHEN 100
                 MOVE 'Y' TO W-EOF
              WHEN OTHER
                 MOVE 8 TO W-RC
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-PERFORM

           EXEC SQL
              CLOSE C2
           END-EXEC

           MOVE W-ROWS TO W-COUNT-E
           DISPLAY 'CTFM930 ROWS FOR THE RACF STEP: ' W-COUNT-E
           .
       R300-PICK-ROWS-END.
           EXIT.

      *===============================================================*
      * R310-ONE-ROW: Write the line, set the row SUBMITTED           *
      *===============================================================*
       R310-ONE-ROW SECTION.
           MOVE PROVJOBID OF DCLTBCTF004 TO W-CMD-JOBID
           MOVE FUNCTION DISPLAY-OF(PROVACTION OF DCLTBCTF004) TO
                W-CMD-ACTION
           MOVE FUNCTION DISPLAY-OF(RACFUSERID OF DCLTBCTF003) TO
                W-CMD-USERID
           IF RACFGROUP-IND OF DCLTBCTF004 < 0
              MOVE SPACES TO W-CMD-GROUP
           ELSE
              MOVE FUNCTION DISPLAY-OF(RACFGROUP OF DCLTBCTF004) TO
                   W-CMD-GROUP
           END-IF

           WRITE CMD-REC FROM W-CMD

           IF W-FS NOT = '00'
              MOVE 8 TO W-RC
              DISPLAY 'CTFM930 WRITE CMDS FILE STATUS ' W-FS
           ELSE
              ADD 1 TO W-ROWS
              EXEC SQL
                 UPDATE TBCTF004
                    SET JOBSTATUS     = :C-S,
                        JOBHASH       = NULL,
                        SUBMITTEDDATE = CURRENT TIMESTAMP,
                        UPDATEDBY     = :W-LCTFA990.USERID,
                        UPDATEDDATE   = CURRENT TIMESTAMP
                  WHERE PROVJOBID = :DCLTBCTF004.PROVJOBID
              END-EXEC
              PERFORM R190-CHECK-SQL
           END-IF
           .
       R310-ONE-ROW-END.
           EXIT.

      *===============================================================*
      * R009-FINISH: Commit or roll back, close, set the return code  *
      *===============================================================*
       R009-FINISH SECTION.
           IF W-RC = 0
              EXEC SQL
                 COMMIT
              END-EXEC
              IF SQLCODE NOT = 0
                 MOVE 8 TO W-RC
                 PERFORM R900-DSNTIAR
              END-IF
           ELSE
              EXEC SQL
                 ROLLBACK
              END-EXEC
           END-IF

           CLOSE CMDS

           MOVE W-RC TO RETURN-CODE
           .
       R009-FINISH-END.
           EXIT.

      *===============================================================*
      * R900-DSNTIAR: Format SQLCA information when error             *
      *===============================================================*
       R900-DSNTIAR SECTION.
           MOVE SQLCODE TO W-SQLCODE
           DISPLAY 'CTFM930 SQLCODE=' W-SQLCODE

           CALL 'DSNTIAR' USING SQLCA ERROR-MESSAGE ERROR-TEXT-LEN

           PERFORM VARYING ERROR-INDEX
              FROM 1 BY 1 UNTIL ERROR-INDEX = 10
                   DISPLAY ERROR-TEXT(ERROR-INDEX)
           END-PERFORM
           .
       R900-DSNTIAR-END.
           EXIT.

       END PROGRAM CTFM930.
