       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM915.
      *===============================================================*
      * This program is a DB2 batch program of the CTF application.   *
      * Records the results of provisioning jobs in DB2: in the last  *
      * step of each job from CTFC910, and in the last step of the    *
      * scheduled batch (CTFBATCH) for all its rows at once. A result *
      * that comes late, after S3 set the job failed, still counts.   *
      * Effect of a job that went well:                               *
      *   C create  player R (from P or F), pending places A          *
      *   N connect the place in the job's event A                    *
      *   M remove  nothing                                           *
      *   P reset   player R                                          *
      *   V revoke  player V                                          *
      *   U resume  player A                                          *
      *   X delete  player X                                          *
      * A failed CREATE sets the player F; other failures change only *
      * the job row.                                                  *
      * Static SQL, so the batch userid only needs the plan and no    *
      * access to the tables. Linked with DSNELI, not DSNCLI: run it  *
      * with DSN RUN under IKJEFT1B.                                  *
      * ------------------------------------------------------------- *
      * Input: one record per job on SYSIN                            *
      * Col 1-9   = PROVJOBID, with leading zeros                     *
      * Col 11    = O the job went well, F it failed                  *
      * Col 13-15 = return code, optional                             *
      * Col 17-72 = message, optional                                 *
      * Each record is committed on its own.                          *
      * ------------------------------------------------------------- *
      * Output: RETURN-CODE, the highest of all records               *
      *  0 = Success, also when there are no records                  *
      *  4 = Job not found                                            *
      *  8 = Invalid input, or an error; that record is rolled back.  *
      *      See SYSOUT                                               *
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
           SELECT CARDS ASSIGN TO SYSIN
                  FILE STATUS IS W-FS.

       DATA DIVISION.
       FILE SECTION.
       FD CARDS
           RECORDING MODE F.
       01 CARD-REC        PIC X(80).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

           EXEC SQL INCLUDE TBCTF004 END-EXEC.

           EXEC SQL INCLUDE TBCTF006 END-EXEC.

       01 WORK.
          05 W-PGMNAME    PIC X(8).
          05 W-SQLCODE    PIC -99999.
          05 W-FS         PIC XX.
          05 W-EOF        PIC X VALUE 'N'.
          05 W-RC         PIC S9(4) COMP-5 VALUE 0.
          05 W-MAXRC      PIC S9(4) COMP-5 VALUE 0.
          05 W-JOBID      PIC S9(9) COMP-5.
          05 W-PLAYERID   PIC S9(9) COMP-5.
          05 W-JOBST      PIC N.
          05 W-MSGLEN     PIC S9(4) COMP-5.

       01 W-CARD.
          05 W-CARD-JOBID  PIC 9(9).
          05 FILLER        PIC X.
          05 W-CARD-RESULT PIC X.
          05 FILLER        PIC X.
          05 W-CARD-RC     PIC X(3).
          05 W-CARD-RC9 REDEFINES W-CARD-RC PIC 9(3).
          05 FILLER        PIC X.
          05 W-CARD-MSG    PIC X(56).
          05 FILLER        PIC X(8).

       01 W-LCTFA990.
           COPY LCTFA990.

       01 C-CODES.
          05 C-A          PIC N VALUE N'A'.
          05 C-C          PIC N VALUE N'C'.
          05 C-D          PIC N VALUE N'D'.
          05 C-F          PIC N VALUE N'F'.
          05 C-M          PIC N VALUE N'M'.
          05 C-N          PIC N VALUE N'N'.
          05 C-P          PIC N VALUE N'P'.
          05 C-R          PIC N VALUE N'R'.
          05 C-U          PIC N VALUE N'U'.
          05 C-V          PIC N VALUE N'V'.
          05 C-X          PIC N VALUE N'X'.

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

           IF W-MAXRC = 0
              PERFORM R010-READ
              PERFORM UNTIL W-EOF = 'Y'
                 PERFORM R100-ONE-RESULT
                 PERFORM R010-READ
              END-PERFORM
              CLOSE CARDS
           END-IF

           MOVE W-MAXRC TO RETURN-CODE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Open the input, find the userid                    *
      *===============================================================*
       R001-INIT SECTION.
           OPEN INPUT CARDS

           IF W-FS NOT = '00'
              MOVE 8 TO W-MAXRC
              DISPLAY 'CTFM915 OPEN SYSIN FILE STATUS ' W-FS
           ELSE
              MOVE 'CTFA990' TO W-PGMNAME
              CALL W-PGMNAME USING W-LCTFA990
              IF RETURNCODE OF W-LCTFA990 NOT = N'00'
                 MOVE 8 TO W-MAXRC
                 DISPLAY 'CTFM915 CTFA990 FAILED'
                 CLOSE CARDS
              END-IF
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R010-READ: Read the next record                               *
      *===============================================================*
       R010-READ SECTION.
           READ CARDS INTO W-CARD
              AT END
                 MOVE 'Y' TO W-EOF
           END-READ

           IF W-EOF NOT = 'Y' AND W-FS NOT = '00'
              MOVE 'Y' TO W-EOF
              MOVE 8 TO W-MAXRC
              DISPLAY 'CTFM915 READ SYSIN FILE STATUS ' W-FS
           END-IF
           .
       R010-READ-END.
           EXIT.

      *===============================================================*
      * R100-ONE-RESULT: Check, record and commit one result          *
      *===============================================================*
       R100-ONE-RESULT SECTION.
           MOVE 0 TO W-RC

           EVALUATE TRUE
           WHEN W-CARD-JOBID NOT NUMERIC
              MOVE 8 TO W-RC
           WHEN W-CARD-RESULT = 'O'
              MOVE C-D TO W-JOBST
           WHEN W-CARD-RESULT = 'F'
              MOVE C-F TO W-JOBST
           WHEN OTHER
              MOVE 8 TO W-RC
           END-EVALUATE

           IF W-RC NOT = 0
              DISPLAY 'CTFM915 INVALID INPUT: ' W-CARD
           ELSE
              MOVE W-CARD-JOBID TO W-JOBID
              PERFORM R110-SELECT-JOB
           END-IF

           IF W-RC = 0
              PERFORM R120-UPDATE-JOB
           END-IF

           IF W-RC = 0
              PERFORM R130-APPLY
           END-IF

           PERFORM R190-COMMIT

           IF W-RC > W-MAXRC
              MOVE W-RC TO W-MAXRC
           END-IF
           .
       R100-ONE-RESULT-END.
           EXIT.

      *===============================================================*
      * R110-SELECT-JOB: Action, player and event of the job          *
      *===============================================================*
       R110-SELECT-JOB SECTION.
           EXEC SQL
              SELECT PLAYERID,
                     EVENTID,
                     PROVACTION
                INTO :W-PLAYERID,
                     :DCLTBCTF004.EVENTID
                       :DCLTBCTF004.EVENTID-IND,
                     :DCLTBCTF004.PROVACTION
                FROM TBCTF004
               WHERE PROVJOBID = :W-JOBID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE 4 TO W-RC
              DISPLAY 'CTFM915 JOB NOT FOUND: ' W-CARD-JOBID
           WHEN OTHER
              MOVE 8 TO W-RC
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R110-SELECT-JOB-END.
           EXIT.

      *===============================================================*
      * R120-UPDATE-JOB: Record the result, return code and message   *
      *===============================================================*
       R120-UPDATE-JOB SECTION.
           IF W-CARD-RC9 NUMERIC
              MOVE W-CARD-RC9 TO JOBRC OF DCLTBCTF004
              MOVE 0 TO JOBRC-IND OF DCLTBCTF004
           ELSE
              MOVE -1 TO JOBRC-IND OF DCLTBCTF004
           END-IF

           MOVE 0 TO JOBMESSAGE-IND OF DCLTBCTF004
           MOVE SPACES TO JOBMESSAGE-TEXT OF DCLTBCTF004
           EVALUATE TRUE
           WHEN W-CARD-MSG NOT = SPACES
              MOVE 56 TO W-MSGLEN
              PERFORM UNTIL W-MSGLEN = 1
                 OR W-CARD-MSG(W-MSGLEN:1) NOT = SPACE
                 SUBTRACT 1 FROM W-MSGLEN
              END-PERFORM
              MOVE W-MSGLEN TO JOBMESSAGE-LEN OF DCLTBCTF004
              MOVE FUNCTION NATIONAL-OF(W-CARD-MSG(1:W-MSGLEN)) TO
                   JOBMESSAGE-TEXT OF DCLTBCTF004
           WHEN W-CARD-RESULT = 'O'
              MOVE 25 TO JOBMESSAGE-LEN OF DCLTBCTF004
              MOVE N'The RACF commands went OK' TO
                   JOBMESSAGE-TEXT OF DCLTBCTF004
           WHEN OTHER
              MOVE 21 TO JOBMESSAGE-LEN OF DCLTBCTF004
              MOVE N'A RACF command failed' TO
                   JOBMESSAGE-TEXT OF DCLTBCTF004
           END-EVALUATE

           EXEC SQL
              UPDATE TBCTF004
                 SET JOBSTATUS     = :W-JOBST,
                     JOBRC         = :DCLTBCTF004.JOBRC
                                       :DCLTBCTF004.JOBRC-IND,
                     JOBMESSAGE    = :DCLTBCTF004.JOBMESSAGE
                                       :DCLTBCTF004.JOBMESSAGE-IND,
                     JOBHASH       = NULL,
                     COMPLETEDDATE = CURRENT TIMESTAMP,
                     UPDATEDBY     = :W-LCTFA990.USERID,
                     UPDATEDDATE   = CURRENT TIMESTAMP
               WHERE PROVJOBID = :W-JOBID
           END-EXEC

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE 8 TO W-RC
              PERFORM R900-DSNTIAR
           END-IF
           .
       R120-UPDATE-JOB-END.
           EXIT.

      *===============================================================*
      * R130-APPLY: What the job means for the player or the place    *
      *===============================================================*
       R130-APPLY SECTION.
           EVALUATE TRUE
           WHEN W-CARD-RESULT = 'F'
              IF PROVACTION OF DCLTBCTF004 = C-C
                 PERFORM R140-CREATE-FAILED
              END-IF
           WHEN PROVACTION OF DCLTBCTF004 = C-C
              PERFORM R150-CREATE-DONE
           WHEN PROVACTION OF DCLTBCTF004 = C-N
              PERFORM R160-CONNECT-DONE
           WHEN PROVACTION OF DCLTBCTF004 = C-P
              MOVE C-R TO PLAYERSTATUS OF DCLTBCTF003
              PERFORM R170-SET-PLAYER
           WHEN PROVACTION OF DCLTBCTF004 = C-V
              MOVE C-V TO PLAYERSTATUS OF DCLTBCTF003
              PERFORM R170-SET-PLAYER
           WHEN PROVACTION OF DCLTBCTF004 = C-U
              MOVE C-A TO PLAYERSTATUS OF DCLTBCTF003
              PERFORM R170-SET-PLAYER
           WHEN PROVACTION OF DCLTBCTF004 = C-X
              MOVE C-X TO PLAYERSTATUS OF DCLTBCTF003
              PERFORM R170-SET-PLAYER
           WHEN OTHER
      *       REMOVE: nothing to record besides the job row
              CONTINUE
           END-EVALUATE
           .
       R130-APPLY-END.
           EXIT.

      *===============================================================*
      * R140-CREATE-FAILED: A pending player becomes FAILED           *
      *===============================================================*
       R140-CREATE-FAILED SECTION.
           EXEC SQL
              UPDATE TBCTF003
                 SET PLAYERSTATUS = :C-F,
                     UPDATEDBY    = :W-LCTFA990.USERID,
                     UPDATEDDATE  = CURRENT TIMESTAMP
               WHERE PLAYERID = :W-PLAYERID
                 AND PLAYERSTATUS = :C-P
           END-EXEC

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE 8 TO W-RC
              PERFORM R900-DSNTIAR
           END-IF
           .
       R140-CREATE-FAILED-END.
           EXIT.

      *===============================================================*
      * R150-CREATE-DONE: Player READY, also after S3 set it FAILED,  *
      * and the pending places active                                 *
      *===============================================================*
       R150-CREATE-DONE SECTION.
           EXEC SQL
              UPDATE TBCTF003
                 SET PLAYERSTATUS = :C-R,
                     UPDATEDBY    = :W-LCTFA990.USERID,
                     UPDATEDDATE  = CURRENT TIMESTAMP
               WHERE PLAYERID = :W-PLAYERID
                 AND PLAYERSTATUS IN (:C-P, :C-F)
           END-EXEC

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE 8 TO W-RC
              PERFORM R900-DSNTIAR
           END-IF

           IF W-RC = 0
              EXEC SQL
                 UPDATE TBCTF006
                    SET PARTSTATUS  = :C-A,
                        UPDATEDBY   = :W-LCTFA990.USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE PLAYERID = :W-PLAYERID
                    AND PARTSTATUS = :C-P
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE 8 TO W-RC
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF
           .
       R150-CREATE-DONE-END.
           EXIT.

      *===============================================================*
      * R160-CONNECT-DONE: The place in the job's event is active     *
      *===============================================================*
       R160-CONNECT-DONE SECTION.
           IF EVENTID-IND OF DCLTBCTF004 >= 0
              EXEC SQL
                 UPDATE TBCTF006
                    SET PARTSTATUS  = :C-A,
                        UPDATEDBY   = :W-LCTFA990.USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE EVENTID = :DCLTBCTF004.EVENTID
                    AND PLAYERID = :W-PLAYERID
                    AND PARTSTATUS = :C-P
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE 8 TO W-RC
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF
           .
       R160-CONNECT-DONE-END.
           EXIT.

      *===============================================================*
      * R170-SET-PLAYER: Player gets PLAYERSTATUS of DCLTBCTF003      *
      *===============================================================*
       R170-SET-PLAYER SECTION.
           EXEC SQL
              UPDATE TBCTF003
                 SET PLAYERSTATUS = :DCLTBCTF003.PLAYERSTATUS,
                     UPDATEDBY    = :W-LCTFA990.USERID,
                     UPDATEDDATE  = CURRENT TIMESTAMP
               WHERE PLAYERID = :W-PLAYERID
           END-EXEC

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE 8 TO W-RC
              PERFORM R900-DSNTIAR
           END-IF
           .
       R170-SET-PLAYER-END.
           EXIT.

      *===============================================================*
      * R190-COMMIT: Commit this result, or roll it back              *
      *===============================================================*
       R190-COMMIT SECTION.
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
           .
       R190-COMMIT-END.
           EXIT.

      *===============================================================*
      * R900-DSNTIAR: Format SQLCA information when error             *
      *===============================================================*
       R900-DSNTIAR SECTION.
           MOVE SQLCODE TO W-SQLCODE
           DISPLAY 'CTFM915 SQLCODE=' W-SQLCODE ' JOB ' W-CARD-JOBID

           CALL 'DSNTIAR' USING SQLCA ERROR-MESSAGE ERROR-TEXT-LEN

           PERFORM VARYING ERROR-INDEX
              FROM 1 BY 1 UNTIL ERROR-INDEX = 10
                   DISPLAY ERROR-TEXT(ERROR-INDEX)
           END-PERFORM
           .
       R900-DSNTIAR-END.
           EXIT.

       END PROGRAM CTFM915.
