       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM011.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST, PUT and DELETE /admin/eventChallenges: put a challenge  *
      * in an event, change its scoring and visibility, or take it    *
      * out, by OPCODE C, R, U or D. S static scoring uses INITPOINTS *
      * only; D dynamic needs INITPOINTS >= MINPOINTS >= 0 and        *
      * DECAYSOLVES > 0. MAXATTEMPTS 0 means no limit, as do MINPOINTS*
      * and DECAYSOLVES 0 when static. Visible needs a flag. Not in a *
      * CLOSED event. Taking a challenge out is refused once it has   *
      * submissions or hint unlocks in the event; its prerequisites go*
      * with it. The caller (the admin wrapper) has checked CTF.ADMIN,*
      * and commits or rolls back.                                    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Not in this event                                     *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 03 = Error: invalid scoreType or isVisible                 *
      * 08 04 = Error: invalid points, decay or attempts              *
      * 08 11 = Error: in the event already                           *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 13 = Error: event or challenge not found                   *
      * 08 31/41 = Error: update or delete of a missing row           *
      * 08 53 = Error: event closed, no flag, or submissions          *
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

           EXEC SQL INCLUDE TBCTF007 END-EXEC.

           EXEC SQL INCLUDE TBCTF011 END-EXEC.

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
       01 P-LCTFM011.
           COPY LCTFM011.

       PROCEDURE DIVISION USING P-LCTFM011.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM011 = N'00'
              EVALUATE OPCODE OF P-LCTFM011
              WHEN N'C'
                 PERFORM R110-CREATE
              WHEN N'R'
                 PERFORM R120-READ
              WHEN N'U'
                 PERFORM R130-UPDATE
              WHEN N'D'
                 PERFORM R140-DELETE
              END-EVALUATE
           END-IF

      *    Answer with the row as it is now
           IF RETURNCODE OF P-LCTFM011 = N'00'
           AND (OPCODE OF P-LCTFM011 = N'C'
             OR OPCODE OF P-LCTFM011 = N'U')
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM011
           MOVE N'00' TO REASONCODE OF P-LCTFM011
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM011
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM011 NOT = N'C'
             AND OPCODE OF P-LCTFM011 NOT = N'R'
             AND OPCODE OF P-LCTFM011 NOT = N'U'
             AND OPCODE OF P-LCTFM011 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'01' TO REASONCODE OF P-LCTFM011
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM011
           END-IF

           IF RETURNCODE OF P-LCTFM011 = N'00'
           AND (OPCODE OF P-LCTFM011 = N'C'
             OR OPCODE OF P-LCTFM011 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           INSPECT SCORETYPE OF P-LCTFM011
                   REPLACING ALL NX'0000' BY N' '
           IF RETURNCODE OF P-LCTFM011 = N'00'
           AND (SCORETYPE OF P-LCTFM011 NOT = N'S'
             AND SCORETYPE OF P-LCTFM011 NOT = N'D')
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'03' TO REASONCODE OF P-LCTFM011
              MOVE N'scoreType must be S or D' TO
                   INFOMESSAGE OF P-LCTFM011
           END-IF

           INSPECT ISVISIBLE OF P-LCTFM011
                   REPLACING ALL NX'0000' BY N' '
           IF ISVISIBLE OF P-LCTFM011 = SPACE
              MOVE N'N' TO ISVISIBLE OF P-LCTFM011
           END-IF
           IF RETURNCODE OF P-LCTFM011 = N'00'
           AND (ISVISIBLE OF P-LCTFM011 NOT = N'Y'
             AND ISVISIBLE OF P-LCTFM011 NOT = N'N')
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'03' TO REASONCODE OF P-LCTFM011
              MOVE N'isVisible must be Y or N' TO
                   INFOMESSAGE OF P-LCTFM011
           END-IF

           IF RETURNCODE OF P-LCTFM011 = N'00'
              EVALUATE TRUE
              WHEN INITPOINTS OF P-LCTFM011 < 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'04' TO REASONCODE OF P-LCTFM011
                 MOVE N'initPoints must be 0 or more' TO
                      INFOMESSAGE OF P-LCTFM011
              WHEN MAXATTEMPTS OF P-LCTFM011 < 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'04' TO REASONCODE OF P-LCTFM011
                 MOVE N'maxAttempts must be 0 (no limit) or more' TO
                      INFOMESSAGE OF P-LCTFM011
              WHEN SCORETYPE OF P-LCTFM011 = N'D'
               AND (MINPOINTS OF P-LCTFM011 < 0
                OR  MINPOINTS OF P-LCTFM011 > INITPOINTS OF P-LCTFM011)
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'04' TO REASONCODE OF P-LCTFM011
                 MOVE N'Dynamic: initPoints >= minPoints >= 0' TO
                      INFOMESSAGE OF P-LCTFM011
              WHEN SCORETYPE OF P-LCTFM011 = N'D'
               AND DECAYSOLVES OF P-LCTFM011 < 1
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'04' TO REASONCODE OF P-LCTFM011
                 MOVE N'Dynamic: decaySolves must be 1 or more' TO
                      INFOMESSAGE OF P-LCTFM011
              END-EVALUATE
           END-IF

           MOVE EVENTID OF P-LCTFM011 TO EVENTID OF DCLTBCTF011
           MOVE CHALLENGEID OF P-LCTFM011 TO CHALLENGEID OF DCLTBCTF011

           IF RETURNCODE OF P-LCTFM011 = N'00'
              PERFORM R030-CHECK-EVENT
           END-IF

           MOVE SCORETYPE OF P-LCTFM011 TO SCORETYPE OF DCLTBCTF011
           MOVE INITPOINTS OF P-LCTFM011 TO INITPOINTS OF DCLTBCTF011
           MOVE MINPOINTS OF P-LCTFM011 TO MINPOINTS OF DCLTBCTF011
           MOVE DECAYSOLVES OF P-LCTFM011 TO DECAYSOLVES OF DCLTBCTF011
           IF SCORETYPE OF P-LCTFM011 = N'D'
              MOVE 0 TO MINPOINTS-IND OF DCLTBCTF011
              MOVE 0 TO DECAYSOLVES-IND OF DCLTBCTF011
           ELSE
              MOVE -1 TO MINPOINTS-IND OF DCLTBCTF011
              MOVE -1 TO DECAYSOLVES-IND OF DCLTBCTF011
           END-IF
           MOVE ISVISIBLE OF P-LCTFM011 TO ISVISIBLE OF DCLTBCTF011
           MOVE SORTORDER OF P-LCTFM011 TO SORTORDER OF DCLTBCTF011
           MOVE MAXATTEMPTS OF P-LCTFM011 TO MAXATTEMPTS OF DCLTBCTF011
           IF MAXATTEMPTS OF P-LCTFM011 = 0
              MOVE -1 TO MAXATTEMPTS-IND OF DCLTBCTF011
           ELSE
              MOVE 0 TO MAXATTEMPTS-IND OF DCLTBCTF011
           END-IF

           IF RETURNCODE OF P-LCTFM011 = N'00'
           AND ISVISIBLE OF P-LCTFM011 = N'Y'
              EXEC SQL
                 SELECT 1
                   INTO :W-ONE
                   FROM TBCTF008
                  WHERE CHALLENGEID = :DCLTBCTF011.CHALLENGEID
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'53' TO REASONCODE OF P-LCTFM011
                 MOVE N'A challenge needs a flag to be visible' TO
                      INFOMESSAGE OF P-LCTFM011
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'21' TO REASONCODE OF P-LCTFM011
                 STRING N'SELECT flags gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM011
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           EXEC SQL
              INSERT
                INTO TBCTF011
                     (EVENTID,
                      CHALLENGEID,
                      SCORETYPE,
                      INITPOINTS,
                      MINPOINTS,
                      DECAYSOLVES,
                      ISVISIBLE,
                      SORTORDER,
                      MAXATTEMPTS,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF011.EVENTID,
                     :DCLTBCTF011.CHALLENGEID,
                     :DCLTBCTF011.SCORETYPE,
                     :DCLTBCTF011.INITPOINTS,
                     :DCLTBCTF011.MINPOINTS :DCLTBCTF011.MINPOINTS-IND,
                     :DCLTBCTF011.DECAYSOLVES
                        :DCLTBCTF011.DECAYSOLVES-IND,
                     :DCLTBCTF011.ISVISIBLE,
                     :DCLTBCTF011.SORTORDER,
                     :DCLTBCTF011.MAXATTEMPTS
                        :DCLTBCTF011.MAXATTEMPTS-IND,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN -530
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'13' TO REASONCODE OF P-LCTFM011
              MOVE N'Event or challenge not found' TO
                   INFOMESSAGE OF P-LCTFM011
           WHEN -803
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'11' TO REASONCODE OF P-LCTFM011
              MOVE N'This row exists already' TO
                   INFOMESSAGE OF P-LCTFM011
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'12' TO REASONCODE OF P-LCTFM011
              STRING N'INSERT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM011
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R120-READ: Read the row                                       *
      *===============================================================*
       R120-READ SECTION.
           MOVE EVENTID OF P-LCTFM011 TO EVENTID OF DCLTBCTF011
           MOVE CHALLENGEID OF P-LCTFM011 TO CHALLENGEID OF DCLTBCTF011

           EXEC SQL
              SELECT EC.EVENTID,
                     EC.CHALLENGEID,
                     C.CHALLENGETITLE,
                     EC.SCORETYPE,
                     EC.INITPOINTS,
                     EC.MINPOINTS,
                     EC.DECAYSOLVES,
                     EC.ISVISIBLE,
                     EC.SORTORDER,
                     EC.MAXATTEMPTS,
                     EC.CREATEDBY,
                     EC.CREATEDDATE,
                     EC.UPDATEDBY,
                     EC.UPDATEDDATE
                INTO :DCLTBCTF011.EVENTID,
                     :DCLTBCTF011.CHALLENGEID,
                     :DCLTBCTF007.CHALLENGETITLE,
                     :DCLTBCTF011.SCORETYPE,
                     :DCLTBCTF011.INITPOINTS,
                     :DCLTBCTF011.MINPOINTS :DCLTBCTF011.MINPOINTS-IND,
                     :DCLTBCTF011.DECAYSOLVES
                        :DCLTBCTF011.DECAYSOLVES-IND,
                     :DCLTBCTF011.ISVISIBLE,
                     :DCLTBCTF011.SORTORDER,
                     :DCLTBCTF011.MAXATTEMPTS
                        :DCLTBCTF011.MAXATTEMPTS-IND,
                     :DCLTBCTF011.CREATEDBY,
                     :DCLTBCTF011.CREATEDDATE,
                     :DCLTBCTF011.UPDATEDBY,
                     :DCLTBCTF011.UPDATEDDATE
                FROM TBCTF011 EC
                JOIN TBCTF007 C
                  ON C.CHALLENGEID = EC.CHALLENGEID
               WHERE EC.EVENTID = :DCLTBCTF011.EVENTID
                 AND EC.CHALLENGEID = :DCLTBCTF011.CHALLENGEID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM011
              MOVE N'01' TO REASONCODE OF P-LCTFM011
              MOVE N'The challenge is not in this event' TO
                   INFOMESSAGE OF P-LCTFM011
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'21' TO REASONCODE OF P-LCTFM011
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM011
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R130-UPDATE: Update the row                                   *
      *===============================================================*
       R130-UPDATE SECTION.
           EXEC SQL
              UPDATE TBCTF011
                 SET SCORETYPE   = :DCLTBCTF011.SCORETYPE,
                     INITPOINTS  = :DCLTBCTF011.INITPOINTS,
                     MINPOINTS   = :DCLTBCTF011.MINPOINTS
                                   :DCLTBCTF011.MINPOINTS-IND,
                     DECAYSOLVES = :DCLTBCTF011.DECAYSOLVES
                                   :DCLTBCTF011.DECAYSOLVES-IND,
                     ISVISIBLE   = :DCLTBCTF011.ISVISIBLE,
                     SORTORDER   = :DCLTBCTF011.SORTORDER,
                     MAXATTEMPTS = :DCLTBCTF011.MAXATTEMPTS
                                   :DCLTBCTF011.MAXATTEMPTS-IND,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE EVENTID = :DCLTBCTF011.EVENTID
                 AND CHALLENGEID = :DCLTBCTF011.CHALLENGEID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'31' TO REASONCODE OF P-LCTFM011
              MOVE N'The challenge is not in this event' TO
                   INFOMESSAGE OF P-LCTFM011
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'32' TO REASONCODE OF P-LCTFM011
              STRING N'UPDATE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM011
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R130-UPDATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row                                   *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE EVENTID OF P-LCTFM011 TO EVENTID OF DCLTBCTF011
           MOVE CHALLENGEID OF P-LCTFM011 TO CHALLENGEID OF DCLTBCTF011

           PERFORM R030-CHECK-EVENT

           IF RETURNCODE OF P-LCTFM011 = N'00'
              EXEC SQL
                 SELECT 1
                   INTO :W-ONE
                   FROM TBCTF013
                  WHERE EVENTID = :DCLTBCTF011.EVENTID
                    AND CHALLENGEID = :DCLTBCTF011.CHALLENGEID
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'53' TO REASONCODE OF P-LCTFM011
                 STRING N'The challenge has submissions: hide it '
                        N'instead'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM011
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'21' TO REASONCODE OF P-LCTFM011
                 STRING N'SELECT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM011
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LCTFM011 = N'00'
              EXEC SQL
                 SELECT 1
                   INTO :W-ONE
                   FROM TBCTF015 HU
                   JOIN TBCTF009 H
                     ON H.HINTID = HU.HINTID
                  WHERE HU.EVENTID = :DCLTBCTF011.EVENTID
                    AND H.CHALLENGEID = :DCLTBCTF011.CHALLENGEID
                  FETCH FIRST 1 ROW ONLY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'53' TO REASONCODE OF P-LCTFM011
                 MOVE N'Teams unlocked its hints: hide it instead' TO
                      INFOMESSAGE OF P-LCTFM011
              WHEN 100
                 CONTINUE
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'21' TO REASONCODE OF P-LCTFM011
                 STRING N'SELECT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM011
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LCTFM011 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF012
                  WHERE EVENTID = :DCLTBCTF011.EVENTID
                    AND (CHALLENGEID = :DCLTBCTF011.CHALLENGEID
                     OR  REQCHALLENGEID = :DCLTBCTF011.CHALLENGEID)
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'42' TO REASONCODE OF P-LCTFM011
                 STRING N'DELETE prerequisites gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM011
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM011 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF011
                  WHERE EVENTID = :DCLTBCTF011.EVENTID
                    AND CHALLENGEID = :DCLTBCTF011.CHALLENGEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'41' TO REASONCODE OF P-LCTFM011
                 MOVE N'The challenge is not in this event' TO
                      INFOMESSAGE OF P-LCTFM011
              WHEN -532
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'53' TO REASONCODE OF P-LCTFM011
                 MOVE N'Other rows still refer to this one' TO
                      INFOMESSAGE OF P-LCTFM011
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'42' TO REASONCODE OF P-LCTFM011
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM011
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
               WHERE EVENTID = :DCLTBCTF011.EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF W-STATUS = C-C
                 MOVE N'08' TO RETURNCODE OF P-LCTFM011
                 MOVE N'53' TO REASONCODE OF P-LCTFM011
                 MOVE N'The event is closed' TO
                      INFOMESSAGE OF P-LCTFM011
              END-IF
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'13' TO REASONCODE OF P-LCTFM011
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM011
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM011
              MOVE N'21' TO REASONCODE OF P-LCTFM011
              STRING N'SELECT event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM011
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R030-CHECK-EVENT-END.
           EXIT.

      *===============================================================*
      * R121-COPY-ROW: Copy the row to the IO area                    *
      *===============================================================*
       R121-COPY-ROW SECTION.
           MOVE EVENTID OF DCLTBCTF011 TO EVENTID OF P-LCTFM011
           MOVE CHALLENGEID OF DCLTBCTF011 TO CHALLENGEID OF P-LCTFM011
           MOVE CHALLENGETITLE OF DCLTBCTF007 TO
                CHALLENGETITLE OF P-LCTFM011
           MOVE SCORETYPE OF DCLTBCTF011 TO SCORETYPE OF P-LCTFM011
           MOVE INITPOINTS OF DCLTBCTF011 TO INITPOINTS OF P-LCTFM011
           IF MINPOINTS-IND OF DCLTBCTF011 < 0
              MOVE 0 TO MINPOINTS OF P-LCTFM011
           ELSE
              MOVE MINPOINTS OF DCLTBCTF011 TO MINPOINTS OF P-LCTFM011
           END-IF
           IF DECAYSOLVES-IND OF DCLTBCTF011 < 0
              MOVE 0 TO DECAYSOLVES OF P-LCTFM011
           ELSE
              MOVE DECAYSOLVES OF DCLTBCTF011 TO
                   DECAYSOLVES OF P-LCTFM011
           END-IF
           MOVE ISVISIBLE OF DCLTBCTF011 TO ISVISIBLE OF P-LCTFM011
           MOVE SORTORDER OF DCLTBCTF011 TO SORTORDER OF P-LCTFM011
           IF MAXATTEMPTS-IND OF DCLTBCTF011 < 0
              MOVE 0 TO MAXATTEMPTS OF P-LCTFM011
           ELSE
              MOVE MAXATTEMPTS OF DCLTBCTF011 TO
                   MAXATTEMPTS OF P-LCTFM011
           END-IF
           MOVE CREATEDBY OF DCLTBCTF011 TO CREATEDBY OF P-LCTFM011
           MOVE CREATEDDATE OF DCLTBCTF011 TO CREATEDDATE OF P-LCTFM011
           MOVE UPDATEDBY OF DCLTBCTF011 TO UPDATEDBY OF P-LCTFM011
           MOVE UPDATEDDATE OF DCLTBCTF011 TO UPDATEDDATE OF P-LCTFM011
           .
       R121-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM011==.

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

       END PROGRAM CTFM011.
