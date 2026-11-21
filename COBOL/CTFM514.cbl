       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM514.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /admin/solveReversals: reverses the solve of a team, by  *
      * event, challenge and team. The SOLVES row is deleted, so the  *
      * points go and the team may solve the challenge again; the     *
      * submission keeps ISCORRECT Y and gets REVERSEDBY, REVERSEDDATE*
      * and REVERSEREASON. Scores are calculated, so dynamic values   *
      * go back up by themselves. Hint unlocks stay. Not in a CLOSED  *
      * event. The caller (the admin wrapper) has checked CTF.ADMIN,  *
      * and commits or rolls back.                                    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 02 = Error: reason missing or too long                     *
      * 08 21/32/42 = Error: SQL error                                *
      * 08 31 = Error: the submission of the solve is missing         *
      * 08 41 = Error: no solve to reverse                            *
      * 08 53 = Error: the event is closed or archived                *
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

           EXEC SQL INCLUDE TBCTF013 END-EXEC.

           EXEC SQL INCLUDE TBCTF014 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-STATUS     PIC N.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM514.
           COPY LCTFM514.

       PROCEDURE DIVISION USING P-LCTFM514.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM514 = N'00'
              PERFORM R030-CHECK-EVENT
           END-IF

           IF RETURNCODE OF P-LCTFM514 = N'00'
              PERFORM R110-DELETE-SOLVE
           END-IF

           IF RETURNCODE OF P-LCTFM514 = N'00'
              PERFORM R120-MARK-SUBMISSION
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM514
           MOVE N'00' TO REASONCODE OF P-LCTFM514
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM514

           MOVE EVENTID OF P-LCTFM514 TO EVENTID OF DCLTBCTF014
           MOVE CHALLENGEID OF P-LCTFM514 TO CHALLENGEID OF DCLTBCTF014
           MOVE TEAMID OF P-LCTFM514 TO TEAMID OF DCLTBCTF014
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
      *    The schema allows an empty reason, the use case does not
           IF REVERSEREASON-LEN OF P-LCTFM514 < 1
           OR REVERSEREASON-LEN OF P-LCTFM514 > 255
              MOVE N'08' TO RETURNCODE OF P-LCTFM514
              MOVE N'02' TO REASONCODE OF P-LCTFM514
              MOVE N'reverseReason is required, up to 255 characters'
                TO INFOMESSAGE OF P-LCTFM514
           ELSE
              MOVE REVERSEREASON OF P-LCTFM514 TO
                   REVERSEREASON OF DCLTBCTF013
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R030-CHECK-EVENT: The event is not closed. An event that does *
      * not exist has no solve to reverse.                            *
      *===============================================================*
       R030-CHECK-EVENT SECTION.
           EXEC SQL
              SELECT EVENTSTATUS
                INTO :W-STATUS
                FROM TBCTF002
               WHERE EVENTID = :DCLTBCTF014.EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF W-STATUS = C-C OR W-STATUS = C-A
                 MOVE N'08' TO RETURNCODE OF P-LCTFM514
                 MOVE N'53' TO REASONCODE OF P-LCTFM514
                 MOVE N'The event is closed or archived' TO
                      INFOMESSAGE OF P-LCTFM514
              END-IF
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM514
              MOVE N'41' TO REASONCODE OF P-LCTFM514
              MOVE N'No solve to reverse' TO
                   INFOMESSAGE OF P-LCTFM514
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM514
              MOVE N'21' TO REASONCODE OF P-LCTFM514
              STRING N'SELECT event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM514
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R030-CHECK-EVENT-END.
           EXIT.

      *===============================================================*
      * R110-DELETE-SOLVE: Delete the solve and keep its submission   *
      * ID, in one statement, so two admins cannot both reverse it    *
      *===============================================================*
       R110-DELETE-SOLVE SECTION.
           EXEC SQL
              SELECT SUBMISSIONID
                INTO :DCLTBCTF014.SUBMISSIONID
                FROM OLD TABLE
                   (
              DELETE FROM TBCTF014
               WHERE EVENTID = :DCLTBCTF014.EVENTID
                 AND CHALLENGEID = :DCLTBCTF014.CHALLENGEID
                 AND TEAMID = :DCLTBCTF014.TEAMID
                   )
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM514
              MOVE N'41' TO REASONCODE OF P-LCTFM514
              MOVE N'No solve to reverse' TO
                   INFOMESSAGE OF P-LCTFM514
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM514
              MOVE N'42' TO REASONCODE OF P-LCTFM514
              STRING N'DELETE solve gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM514
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R110-DELETE-SOLVE-END.
           EXIT.

      *===============================================================*
      * R120-MARK-SUBMISSION: Who reversed it, when and why           *
      *===============================================================*
       R120-MARK-SUBMISSION SECTION.
           MOVE SUBMISSIONID OF DCLTBCTF014 TO
                SUBMISSIONID OF DCLTBCTF013

           EXEC SQL
              UPDATE TBCTF013
                 SET REVERSEDBY    = :W-USERID,
                     REVERSEDDATE  = CURRENT TIMESTAMP,
                     REVERSEREASON = :DCLTBCTF013.REVERSEREASON,
                     UPDATEDBY     = :W-USERID,
                     UPDATEDDATE   = CURRENT TIMESTAMP
               WHERE SUBMISSIONID = :DCLTBCTF013.SUBMISSIONID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM514
              MOVE N'31' TO REASONCODE OF P-LCTFM514
              MOVE N'Submission of the solve not found' TO
                   INFOMESSAGE OF P-LCTFM514
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM514
              MOVE N'32' TO REASONCODE OF P-LCTFM514
              STRING N'UPDATE submission gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM514
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-MARK-SUBMISSION-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM514==.

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

       END PROGRAM CTFM514.
