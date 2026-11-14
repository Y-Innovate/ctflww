       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM510.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /admin/playerResets, playerRevocations and               *
      * playerResumptions and DELETE /admin/players: makes a          *
      * provisioning job for a player. PROVACTION P reset, V revoke, U*
      * resume, X delete; LWW sets it per path. Allowed from          *
      * PLAYERSTATUS: P from A, R or V; V from A or R; U and X from V.*
      * One open job per player. A reset gets a new claim token,      *
      * returned in CLAIMTOKEN, and the phrase is derived from it; the*
      * other actions get a job token. The token goes in LCTFC910 for *
      * the caller, who commits and starts the submit task. The player*
      * changes when the job reports success (CTFM915). The caller    *
      * (the admin wrapper) has checked CTF.ADMIN.                    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Player not found                                      *
      * 08 01 = Error: PROVACTION invalid                             *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 53 = Error: not possible with this status, or a job is open*
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
          05 W-COUNT      PIC S9(9) COMP-5.
          05 W-HOURS      PIC S9(4) COMP-5.
          05 W-JOBHASH-IND PIC S9(4) COMP-5.
          05 W-ACTION     PIC N.

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
       01 P-LCTFM510.
           COPY LCTFM510.
       01 P-LCTFC910.
           COPY LCTFC910.

       PROCEDURE DIVISION USING P-LCTFM510 P-LCTFC910.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM510 = N'00'
              PERFORM R110-SELECT-PLAYER
           END-IF

           IF RETURNCODE OF P-LCTFM510 = N'00'
              PERFORM R120-CHECK-STATUS
           END-IF

           IF RETURNCODE OF P-LCTFM510 = N'00'
              PERFORM R130-NO-OPEN-JOB
           END-IF

           IF RETURNCODE OF P-LCTFM510 = N'00'
              PERFORM R140-SECRETS
           END-IF

           IF   RETURNCODE OF P-LCTFM510 = N'00'
           AND W-ACTION = C-P
              PERFORM R150-NEW-CLAIM
           END-IF

           IF RETURNCODE OF P-LCTFM510 = N'00'
              PERFORM R160-INSERT-JOB
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM510
           MOVE N'00' TO REASONCODE OF P-LCTFM510
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM510
           MOVE 0 TO PROVJOBID OF P-LCTFM510
           MOVE SPACES TO CLAIMTOKEN OF P-LCTFM510
           INITIALIZE P-LCTFC910
           MOVE PLAYERID OF P-LCTFM510 TO W-PLAYERID
           MOVE PROVACTION OF P-LCTFM510 TO W-ACTION

           IF  W-ACTION NOT = C-P
           AND W-ACTION NOT = C-V
           AND W-ACTION NOT = C-U
           AND W-ACTION NOT = C-X
              MOVE N'08' TO RETURNCODE OF P-LCTFM510
              MOVE N'01' TO REASONCODE OF P-LCTFM510
              MOVE N'PROVACTION is invalid' TO
                   INFOMESSAGE OF P-LCTFM510
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R110-SELECT-PLAYER: The player and its status                 *
      *===============================================================*
       R110-SELECT-PLAYER SECTION.
           EXEC SQL
              SELECT PLAYERSTATUS
                INTO :DCLTBCTF003.PLAYERSTATUS
                FROM TBCTF003
               WHERE PLAYERID = :W-PLAYERID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM510
              MOVE N'01' TO REASONCODE OF P-LCTFM510
              MOVE N'Player not found' TO
                   INFOMESSAGE OF P-LCTFM510
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM510
              MOVE N'21' TO REASONCODE OF P-LCTFM510
              STRING N'SELECT player gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM510
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R110-SELECT-PLAYER-END.
           EXIT.

      *===============================================================*
      * R120-CHECK-STATUS: Is this action possible now                *
      *===============================================================*
       R120-CHECK-STATUS SECTION.
           EVALUATE TRUE
           WHEN W-ACTION = C-P
            AND (PLAYERSTATUS OF DCLTBCTF003 = C-A
              OR PLAYERSTATUS OF DCLTBCTF003 = C-R
              OR PLAYERSTATUS OF DCLTBCTF003 = C-V)
           WHEN W-ACTION = C-V
            AND (PLAYERSTATUS OF DCLTBCTF003 = C-A
              OR PLAYERSTATUS OF DCLTBCTF003 = C-R)
           WHEN W-ACTION = C-U
            AND PLAYERSTATUS OF DCLTBCTF003 = C-V
           WHEN W-ACTION = C-X
            AND PLAYERSTATUS OF DCLTBCTF003 = C-V
              CONTINUE
           WHEN OTHER
              MOVE N'08' TO RETURNCODE OF P-LCTFM510
              MOVE N'53' TO REASONCODE OF P-LCTFM510
              MOVE N'Not possible for a player with this status' TO
                   INFOMESSAGE OF P-LCTFM510
           END-EVALUATE
           .
       R120-CHECK-STATUS-END.
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM510
              MOVE N'21' TO REASONCODE OF P-LCTFM510
              STRING N'SELECT jobs gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM510
              PERFORM R900-DSNTIAR
           WHEN W-COUNT > 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM510
              MOVE N'53' TO REASONCODE OF P-LCTFM510
              MOVE N'A job for this player is still open' TO
                   INFOMESSAGE OF P-LCTFM510
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM510
              MOVE N'90' TO REASONCODE OF P-LCTFM510
              MOVE INFOMESSAGE OF W-LCTFM910 TO
                   INFOMESSAGE OF P-LCTFM510
           END-IF

           IF RETURNCODE OF P-LCTFM510 = N'00'
              PERFORM R800-NEW-TOKEN
              IF A991-OK
                 PERFORM R810-DERIVE
              END-IF
              IF A991-OK
                 MOVE W-TOKEN TO JOBTOKEN OF P-LCTFC910
                 MOVE W-PLAYERID TO PLAYERID OF P-LCTFC910
                 IF W-ACTION = C-P
      *             CREATE and RESET: a claim token for the player
                    MOVE W-TOKENHASH TO W-CLAIMHASH
                    MOVE FUNCTION NATIONAL-OF(W-TOKEN) TO
                         CLAIMTOKEN OF P-LCTFM510
                    COMPUTE W-HOURS =
                       FUNCTION NUMVAL(S-CLAIMHRS OF P-LCTFC910)
                    MOVE -1 TO W-JOBHASH-IND
                 ELSE
                    MOVE W-TOKENHASH TO W-JOBHASH
                    MOVE 0 TO W-JOBHASH-IND
                 END-IF
              ELSE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM510
                 MOVE N'90' TO REASONCODE OF P-LCTFM510
                 MOVE N'CTFA991 failed' TO
                      INFOMESSAGE OF P-LCTFM510
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
                     UPDATEDBY    = :W-USERID,
                     UPDATEDDATE  = CURRENT TIMESTAMP
               WHERE PLAYERID = :W-PLAYERID
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM510
              MOVE N'32' TO REASONCODE OF P-LCTFM510
              STRING N'UPDATE player gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM510
              PERFORM R900-DSNTIAR
           END-IF
           .
       R150-NEW-CLAIM-END.
           EXIT.

      *===============================================================*
      * R160-INSERT-JOB: INSERT the job row                           *
      *===============================================================*
       R160-INSERT-JOB SECTION.
           EXEC SQL
              SELECT PROVJOBID
                INTO :DCLTBCTF004.PROVJOBID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF004
                     (PLAYERID,
                      PROVACTION,
                      JOBSTATUS,
                      RETRYCOUNT,
                      JOBHASH,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:W-PLAYERID,
                     :W-ACTION,
                     :C-N,
                     0,
                     :W-JOBHASH :W-JOBHASH-IND,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
                     )
           END-EXEC

           IF SQLCODE = 0
              MOVE PROVJOBID OF DCLTBCTF004 TO PROVJOBID OF P-LCTFM510
              MOVE PROVJOBID OF DCLTBCTF004 TO PROVJOBID OF P-LCTFC910
           ELSE
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM510
              MOVE N'12' TO REASONCODE OF P-LCTFM510
              STRING N'INSERT job gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM510
              PERFORM R900-DSNTIAR
           END-IF
           .
       R160-INSERT-JOB-END.
           EXIT.

           COPY CTFSECP.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM510==.

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

       END PROGRAM CTFM510.
