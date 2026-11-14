       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM315.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /hintUnlocks: unlocks a hint for the team. COST is copied*
      * into TBCTF015, so later edits of the hint change nothing. A   *
      * hint that is unlocked already is returned with the cost paid  *
      * then and is not charged again: the primary key of TBCTF015    *
      * sees to that, also for teammates at the same moment.          *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when unlocked already                   *
      * 04 01 = Hint not found, or challenge not visible              *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 50 = Error: no active place in a team, or locked           *
      * 08 53 = Error: event is not running                           *
      * 08 90 = Error: CTFA990 failed                                 *
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

           EXEC SQL INCLUDE TBCTF009 END-EXEC.

           EXEC SQL INCLUDE TBCTF015 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-HINTID     PIC S9(9) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM315.
           COPY LCTFM315.

       PROCEDURE DIVISION USING P-LCTFM315.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R101-NEED-TEAM
           PERFORM R102-NEED-STARTED
           PERFORM R103-NEED-RUNNING

           IF RETURNCODE OF P-LCTFM315 = N'00'
              PERFORM R120-SELECT-HINT
           END-IF

           PERFORM R106-CHECK-CHALLENGE

           IF RETURNCODE OF P-LCTFM315 = N'00'
              PERFORM R130-INSERT-UNLOCK
           END-IF

           IF RETURNCODE OF P-LCTFM315 = N'00'
              PERFORM R140-COPY-HINT
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM315
           MOVE N'00' TO REASONCODE OF P-LCTFM315
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM315
           MOVE EVENTID OF P-LCTFM315 TO W-EVENTID
           MOVE HINTID OF P-LCTFM315 TO W-HINTID
           MOVE 'N' TO W-ALLOW-LOCKED
           MOVE 0 TO COST OF P-LCTFM315
           MOVE 0 TO HINTTEXT-LEN OF P-LCTFM315
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-SELECT-HINT: The hint and its challenge                  *
      *===============================================================*
       R120-SELECT-HINT SECTION.
           EXEC SQL
              SELECT CHALLENGEID,
                     HINTTEXT,
                     COST
                INTO :DCLTBCTF009.CHALLENGEID,
                     :DCLTBCTF009.HINTTEXT,
                     :DCLTBCTF009.COST
                FROM TBCTF009
               WHERE HINTID = :W-HINTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE CHALLENGEID OF DCLTBCTF009 TO W-CHALLENGEID
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM315
              MOVE N'01' TO REASONCODE OF P-LCTFM315
              MOVE N'Hint not found' TO
                   INFOMESSAGE OF P-LCTFM315
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM315
              MOVE N'21' TO REASONCODE OF P-LCTFM315
              STRING N'SELECT hint gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM315
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-SELECT-HINT-END.
           EXIT.

      *===============================================================*
      * R130-INSERT-UNLOCK: Record the unlock; -803 = done before     *
      *===============================================================*
       R130-INSERT-UNLOCK SECTION.
           MOVE COST OF DCLTBCTF009 TO COST OF DCLTBCTF015

           EXEC SQL
              INSERT
                INTO TBCTF015
                     (EVENTID,
                      HINTID,
                      TEAMID,
                      PLAYERID,
                      COST,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:W-EVENTID,
                     :W-HINTID,
                     :W-TEAMID,
                     :W-PLAYERID,
                     :DCLTBCTF015.COST,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN -803
              PERFORM R135-SELECT-UNLOCK
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM315
              MOVE N'12' TO REASONCODE OF P-LCTFM315
              STRING N'INSERT unlock gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM315
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R130-INSERT-UNLOCK-END.
           EXIT.

      *===============================================================*
      * R135-SELECT-UNLOCK: The cost paid when it was unlocked        *
      *===============================================================*
       R135-SELECT-UNLOCK SECTION.
           EXEC SQL
              SELECT COST
                INTO :DCLTBCTF015.COST
                FROM TBCTF015
               WHERE EVENTID = :W-EVENTID
                 AND HINTID = :W-HINTID
                 AND TEAMID = :W-TEAMID
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM315
              MOVE N'21' TO REASONCODE OF P-LCTFM315
              STRING N'SELECT unlock gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM315
              PERFORM R900-DSNTIAR
           END-IF
           .
       R135-SELECT-UNLOCK-END.
           EXIT.

      *===============================================================*
      * R140-COPY-HINT: Return the text and the cost                  *
      *===============================================================*
       R140-COPY-HINT SECTION.
           MOVE COST OF DCLTBCTF015 TO COST OF P-LCTFM315
           MOVE HINTTEXT OF DCLTBCTF009 TO HINTTEXT OF P-LCTFM315
           .
       R140-COPY-HINT-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM315==.

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

       END PROGRAM CTFM315.
