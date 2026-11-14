       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM012.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST and DELETE /admin/prerequisites: CHALLENGEID stays locked*
      * until REQCHALLENGEID is solved, by OPCODE C or D. Both must be*
      * in the event, not the same challenge, and no cycle: a         *
      * recursive query follows the prerequisites of REQCHALLENGEID   *
      * and must not reach CHALLENGEID. Not in a CLOSED event. The    *
      * caller (the admin wrapper) has checked CTF.ADMIN, and commits *
      * or rolls back.                                                *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 03 = Error: a challenge cannot require itself              *
      * 08 11 = Error: the prerequisite exists already                *
      * 08 12/21/42 = Error: SQL error                                *
      * 08 13 = Error: event or challenges not in the event           *
      * 08 41 = Error: delete of a missing prerequisite               *
      * 08 53 = Error: event closed, or a cycle                       *
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

           EXEC SQL INCLUDE TBCTF012 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-ONE        PIC S9(9) COMP-5.
          05 W-COUNT      PIC S9(9) COMP-5.
          05 C-RACFGRP    PIC N(8) VALUE N'RACFGRP'.
          05 W-BLANK8     PIC N(8) VALUE SPACES.
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
       01 P-LCTFM012.
           COPY LCTFM012.

       PROCEDURE DIVISION USING P-LCTFM012.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM012 = N'00'
              EVALUATE OPCODE OF P-LCTFM012
              WHEN N'C'
                 PERFORM R110-CREATE
              WHEN N'D'
                 PERFORM R140-DELETE
              END-EVALUATE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM012
           MOVE N'00' TO REASONCODE OF P-LCTFM012
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM012
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM012 NOT = N'C'
             AND OPCODE OF P-LCTFM012 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM012
              MOVE N'01' TO REASONCODE OF P-LCTFM012
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM012
           END-IF

           IF RETURNCODE OF P-LCTFM012 = N'00'
           AND (OPCODE OF P-LCTFM012 = N'C'
             OR OPCODE OF P-LCTFM012 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM012 = N'00'
           AND CHALLENGEID OF P-LCTFM012 = REQCHALLENGEID OF P-LCTFM012
              MOVE N'08' TO RETURNCODE OF P-LCTFM012
              MOVE N'03' TO REASONCODE OF P-LCTFM012
              MOVE N'A challenge cannot require itself' TO
                   INFOMESSAGE OF P-LCTFM012
           END-IF
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           MOVE EVENTID OF P-LCTFM012 TO EVENTID OF DCLTBCTF012
           MOVE CHALLENGEID OF P-LCTFM012 TO CHALLENGEID OF DCLTBCTF012
           MOVE REQCHALLENGEID OF P-LCTFM012 TO
                REQCHALLENGEID OF DCLTBCTF012

           PERFORM R030-CHECK-EVENT

           IF RETURNCODE OF P-LCTFM012 = N'00'
      *       Would "CHALLENGEID requires REQCHALLENGEID" close a loop?
      *       Follow what REQCHALLENGEID requires, at most 100 deep
              EXEC SQL
                 WITH R (CID, LVL) AS
                    (SELECT P.REQCHALLENGEID, 1
                       FROM TBCTF012 P
                      WHERE P.EVENTID = :DCLTBCTF012.EVENTID
                        AND P.CHALLENGEID = :DCLTBCTF012.REQCHALLENGEID
                     UNION ALL
                     SELECT P.REQCHALLENGEID, R.LVL + 1
                       FROM R, TBCTF012 P
                      WHERE P.EVENTID = :DCLTBCTF012.EVENTID
                        AND P.CHALLENGEID = R.CID
                        AND R.LVL < 100)
                 SELECT 1
                   INTO :W-ONE
                   FROM R
                  WHERE R.CID = :DCLTBCTF012.CHALLENGEID
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'53' TO REASONCODE OF P-LCTFM012
                 MOVE N'This prerequisite would make a cycle' TO
                      INFOMESSAGE OF P-LCTFM012
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'21' TO REASONCODE OF P-LCTFM012
                 STRING N'SELECT cycle gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM012
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LCTFM012 = N'00'
              EXEC SQL
                 INSERT
                   INTO TBCTF012
                        (EVENTID,
                         CHALLENGEID,
                         REQCHALLENGEID,
                         CREATEDBY,
                         CREATEDDATE,
                         UPDATEDBY,
                         UPDATEDDATE)
                 VALUES(:DCLTBCTF012.EVENTID,
                        :DCLTBCTF012.CHALLENGEID,
                        :DCLTBCTF012.REQCHALLENGEID,
                        :W-USERID,
                        CURRENT TIMESTAMP,
                        :W-USERID,
                        CURRENT TIMESTAMP)
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN -530
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'13' TO REASONCODE OF P-LCTFM012
                 MOVE N'Both challenges must be in the event' TO
                      INFOMESSAGE OF P-LCTFM012
              WHEN -803
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'11' TO REASONCODE OF P-LCTFM012
                 MOVE N'This row exists already' TO
                      INFOMESSAGE OF P-LCTFM012
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'12' TO REASONCODE OF P-LCTFM012
                 STRING N'INSERT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM012
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row                                   *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE EVENTID OF P-LCTFM012 TO EVENTID OF DCLTBCTF012
           MOVE CHALLENGEID OF P-LCTFM012 TO CHALLENGEID OF DCLTBCTF012
           MOVE REQCHALLENGEID OF P-LCTFM012 TO
                REQCHALLENGEID OF DCLTBCTF012

           PERFORM R030-CHECK-EVENT

           IF RETURNCODE OF P-LCTFM012 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF012
                  WHERE EVENTID = :DCLTBCTF012.EVENTID
                    AND CHALLENGEID = :DCLTBCTF012.CHALLENGEID
                    AND REQCHALLENGEID = :DCLTBCTF012.REQCHALLENGEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'41' TO REASONCODE OF P-LCTFM012
                 MOVE N'Prerequisite not found' TO
                      INFOMESSAGE OF P-LCTFM012
              WHEN -532
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'53' TO REASONCODE OF P-LCTFM012
                 MOVE N'Other rows still refer to this one' TO
                      INFOMESSAGE OF P-LCTFM012
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'42' TO REASONCODE OF P-LCTFM012
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM012
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R140-DELETE-END.
           EXIT.

      *===============================================================*
      * R030-CHECK-EVENT: The event exists and is not closed          *
      *===============================================================*
       R030-CHECK-EVENT SECTION.
           EXEC SQL
              SELECT EVENTSTATUS
                INTO :W-STATUS
                FROM TBCTF002
               WHERE EVENTID = :DCLTBCTF012.EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF W-STATUS = C-C
                 MOVE N'08' TO RETURNCODE OF P-LCTFM012
                 MOVE N'53' TO REASONCODE OF P-LCTFM012
                 MOVE N'The event is closed' TO
                      INFOMESSAGE OF P-LCTFM012
              END-IF
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM012
              MOVE N'13' TO REASONCODE OF P-LCTFM012
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM012
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM012
              MOVE N'21' TO REASONCODE OF P-LCTFM012
              STRING N'SELECT event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM012
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R030-CHECK-EVENT-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM012==.

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

       END PROGRAM CTFM012.
