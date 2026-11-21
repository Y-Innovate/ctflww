       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM016.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST and DELETE /admin/awards: give, read or delete an award  *
      * or penalty of a team, by OPCODE C, R or D. No update: delete  *
      * and give a new one. POINTS may be negative, not 0, and may    *
      * take the score below zero. Not in a CLOSED event. The caller  *
      * (the admin wrapper) has checked CTF.ADMIN, and commits or     *
      * rolls back.                                                   *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Award not found                                       *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: points 0                                       *
      * 08 03 = Error: reason missing or too long                     *
      * 08 12/21/42 = Error: SQL error                                *
      * 08 13 = Error: event not found, or team not in the event      *
      * 08 41 = Error: delete of a missing award                      *
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

           EXEC SQL INCLUDE TBCTF016 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-STATUS     PIC N.
          05 W-ONE        PIC S9(9) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM016.
           COPY LCTFM016.

       PROCEDURE DIVISION USING P-LCTFM016.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM016 = N'00'
              EVALUATE OPCODE OF P-LCTFM016
              WHEN N'C'
                 PERFORM R110-CREATE
              WHEN N'R'
                 PERFORM R120-READ
              WHEN N'D'
                 PERFORM R140-DELETE
              END-EVALUATE
           END-IF

      *    Answer with the row as it is now
           IF RETURNCODE OF P-LCTFM016 = N'00'
           AND OPCODE OF P-LCTFM016 = N'C'
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM016
           MOVE N'00' TO REASONCODE OF P-LCTFM016
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM016
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM016 NOT = N'C'
             AND OPCODE OF P-LCTFM016 NOT = N'R'
             AND OPCODE OF P-LCTFM016 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM016
              MOVE N'01' TO REASONCODE OF P-LCTFM016
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM016
           END-IF

           IF RETURNCODE OF P-LCTFM016 = N'00'
           AND OPCODE OF P-LCTFM016 = N'C'
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C                      *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM016 = N'00'
           AND POINTS OF P-LCTFM016 = 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM016
              MOVE N'02' TO REASONCODE OF P-LCTFM016
              MOVE N'points must not be 0' TO
                   INFOMESSAGE OF P-LCTFM016
           END-IF

           IF RETURNCODE OF P-LCTFM016 = N'00'
           AND (REASON-LEN OF P-LCTFM016 < 1
             OR REASON-LEN OF P-LCTFM016 > 255)
              MOVE N'08' TO RETURNCODE OF P-LCTFM016
              MOVE N'03' TO REASONCODE OF P-LCTFM016
              MOVE N'reason is required, up to 255 characters' TO
                   INFOMESSAGE OF P-LCTFM016
           END-IF

           MOVE EVENTID OF P-LCTFM016 TO EVENTID OF DCLTBCTF016
           MOVE TEAMID OF P-LCTFM016 TO TEAMID OF DCLTBCTF016
           MOVE POINTS OF P-LCTFM016 TO POINTS OF DCLTBCTF016
           MOVE REASON OF P-LCTFM016 TO REASON OF DCLTBCTF016
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R030-CHECK-EVENT: The event of DCLTBCTF016 exists and is not  *
      * closed                                                        *
      *===============================================================*
       R030-CHECK-EVENT SECTION.
           EXEC SQL
              SELECT EVENTSTATUS
                INTO :W-STATUS
                FROM TBCTF002
               WHERE EVENTID = :DCLTBCTF016.EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF W-STATUS = C-C OR W-STATUS = C-A
                 MOVE N'08' TO RETURNCODE OF P-LCTFM016
                 MOVE N'53' TO REASONCODE OF P-LCTFM016
                 MOVE N'The event is closed or archived' TO
                      INFOMESSAGE OF P-LCTFM016
              END-IF
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM016
              MOVE N'13' TO REASONCODE OF P-LCTFM016
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM016
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM016
              MOVE N'21' TO REASONCODE OF P-LCTFM016
              STRING N'SELECT event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM016
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R030-CHECK-EVENT-END.
           EXIT.

      *===============================================================*
      * R040-CHECK-TEAM: The team is in the event                     *
      *===============================================================*
       R040-CHECK-TEAM SECTION.
           IF RETURNCODE OF P-LCTFM016 = N'00'
              EXEC SQL
                 SELECT 1
                   INTO :W-ONE
                   FROM TBCTF005
                  WHERE TEAMID = :DCLTBCTF016.TEAMID
                    AND EVENTID = :DCLTBCTF016.EVENTID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM016
                 MOVE N'13' TO REASONCODE OF P-LCTFM016
                 MOVE N'Team not found in this event' TO
                      INFOMESSAGE OF P-LCTFM016
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM016
                 MOVE N'21' TO REASONCODE OF P-LCTFM016
                 STRING N'SELECT team gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM016
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R040-CHECK-TEAM-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           PERFORM R030-CHECK-EVENT

           PERFORM R040-CHECK-TEAM

           IF RETURNCODE OF P-LCTFM016 = N'00'
              EXEC SQL
                 SELECT AWARDID
                   INTO :DCLTBCTF016.AWARDID
                   FROM FINAL TABLE
                      (
                 INSERT
                   INTO TBCTF016
                        (EVENTID,
                         TEAMID,
                         POINTS,
                         REASON,
                         CREATEDBY,
                         CREATEDDATE,
                         UPDATEDBY,
                         UPDATEDDATE)
                 VALUES(:DCLTBCTF016.EVENTID,
                        :DCLTBCTF016.TEAMID,
                        :DCLTBCTF016.POINTS,
                        :DCLTBCTF016.REASON,
                        :W-USERID,
                        CURRENT TIMESTAMP,
                        :W-USERID,
                        CURRENT TIMESTAMP)
                        )
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE AWARDID OF DCLTBCTF016 TO AWARDID OF P-LCTFM016
              WHEN -530
                 MOVE N'08' TO RETURNCODE OF P-LCTFM016
                 MOVE N'13' TO REASONCODE OF P-LCTFM016
                 MOVE N'Event or team not found' TO
                      INFOMESSAGE OF P-LCTFM016
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM016
                 MOVE N'12' TO REASONCODE OF P-LCTFM016
                 STRING N'INSERT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM016
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R120-READ: Read the row                                       *
      *===============================================================*
       R120-READ SECTION.
           MOVE AWARDID OF P-LCTFM016 TO AWARDID OF DCLTBCTF016

           EXEC SQL
              SELECT AWARDID,
                     EVENTID,
                     TEAMID,
                     POINTS,
                     REASON,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF016.AWARDID,
                     :DCLTBCTF016.EVENTID,
                     :DCLTBCTF016.TEAMID,
                     :DCLTBCTF016.POINTS,
                     :DCLTBCTF016.REASON,
                     :DCLTBCTF016.CREATEDBY,
                     :DCLTBCTF016.CREATEDDATE,
                     :DCLTBCTF016.UPDATEDBY,
                     :DCLTBCTF016.UPDATEDDATE
                FROM TBCTF016
               WHERE AWARDID = :DCLTBCTF016.AWARDID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM016
              MOVE N'01' TO REASONCODE OF P-LCTFM016
              MOVE N'Award not found' TO
                   INFOMESSAGE OF P-LCTFM016
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM016
              MOVE N'21' TO REASONCODE OF P-LCTFM016
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM016
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row, unless its event is closed       *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE AWARDID OF P-LCTFM016 TO AWARDID OF DCLTBCTF016

           EXEC SQL
              SELECT EVENTID
                INTO :DCLTBCTF016.EVENTID
                FROM TBCTF016
               WHERE AWARDID = :DCLTBCTF016.AWARDID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R030-CHECK-EVENT
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM016
              MOVE N'41' TO REASONCODE OF P-LCTFM016
              MOVE N'Award not found' TO
                   INFOMESSAGE OF P-LCTFM016
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM016
              MOVE N'21' TO REASONCODE OF P-LCTFM016
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM016
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM016 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF016
                  WHERE AWARDID = :DCLTBCTF016.AWARDID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM016
                 MOVE N'41' TO REASONCODE OF P-LCTFM016
                 MOVE N'Award not found' TO
                      INFOMESSAGE OF P-LCTFM016
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM016
                 MOVE N'42' TO REASONCODE OF P-LCTFM016
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM016
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R140-DELETE-END.
           EXIT.

      *===============================================================*
      * R121-COPY-ROW: Copy the row to the IO area                    *
      *===============================================================*
       R121-COPY-ROW SECTION.
           MOVE AWARDID OF DCLTBCTF016 TO AWARDID OF P-LCTFM016
           MOVE EVENTID OF DCLTBCTF016 TO EVENTID OF P-LCTFM016
           MOVE TEAMID OF DCLTBCTF016 TO TEAMID OF P-LCTFM016
           MOVE POINTS OF DCLTBCTF016 TO POINTS OF P-LCTFM016
           MOVE REASON OF DCLTBCTF016 TO REASON OF P-LCTFM016
           MOVE CREATEDBY OF DCLTBCTF016 TO CREATEDBY OF P-LCTFM016
           MOVE CREATEDDATE OF DCLTBCTF016 TO CREATEDDATE OF P-LCTFM016
           MOVE UPDATEDBY OF DCLTBCTF016 TO UPDATEDBY OF P-LCTFM016
           MOVE UPDATEDDATE OF DCLTBCTF016 TO UPDATEDDATE OF P-LCTFM016
           .
       R121-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM016==.

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

       END PROGRAM CTFM016.
