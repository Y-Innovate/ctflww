       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM017.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST, PUT and DELETE /admin/announcements: publish, read,     *
      * correct or delete an announcement of an event, by OPCODE C,   *
      * R, U or D. Also on a DRAFT, not in a CLOSED event. U changes  *
      * title and body only: CREATEDDATE, the publish time, stays.    *
      * The caller (the admin wrapper) has checked CTF.ADMIN, and     *
      * commits or rolls back.                                        *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Announcement not found                                *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: title missing or too long                      *
      * 08 03 = Error: body missing or too long                       *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 13 = Error: event not found                                *
      * 08 31/41 = Error: update or delete of a missing announcement  *
      * 08 53 = Error: the event is closed                            *
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

           EXEC SQL INCLUDE TBCTF017 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-STATUS     PIC N.
          05 W-MISSING    PIC N(2).

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM017.
           COPY LCTFM017.

       PROCEDURE DIVISION USING P-LCTFM017.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM017 = N'00'
              EVALUATE OPCODE OF P-LCTFM017
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
           IF RETURNCODE OF P-LCTFM017 = N'00'
           AND (OPCODE OF P-LCTFM017 = N'C'
             OR OPCODE OF P-LCTFM017 = N'U')
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM017
           MOVE N'00' TO REASONCODE OF P-LCTFM017
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM017
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM017 NOT = N'C'
             AND OPCODE OF P-LCTFM017 NOT = N'R'
             AND OPCODE OF P-LCTFM017 NOT = N'U'
             AND OPCODE OF P-LCTFM017 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM017
              MOVE N'01' TO REASONCODE OF P-LCTFM017
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM017
           END-IF

           IF RETURNCODE OF P-LCTFM017 = N'00'
           AND (OPCODE OF P-LCTFM017 = N'C'
             OR OPCODE OF P-LCTFM017 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM017 = N'00'
           AND (ANNOUNCETITLE-LEN OF P-LCTFM017 < 1
             OR ANNOUNCETITLE-LEN OF P-LCTFM017 > 100)
              MOVE N'08' TO RETURNCODE OF P-LCTFM017
              MOVE N'02' TO REASONCODE OF P-LCTFM017
              MOVE N'announceTitle is required, up to 100 characters'
                TO INFOMESSAGE OF P-LCTFM017
           END-IF

           IF RETURNCODE OF P-LCTFM017 = N'00'
           AND (BODY-LEN OF P-LCTFM017 < 1
             OR BODY-LEN OF P-LCTFM017 > 1000)
              MOVE N'08' TO RETURNCODE OF P-LCTFM017
              MOVE N'03' TO REASONCODE OF P-LCTFM017
              MOVE N'announceBody is required, up to 1000 characters'
                TO INFOMESSAGE OF P-LCTFM017
           END-IF

           MOVE ANNOUNCETITLE OF P-LCTFM017 TO
                ANNOUNCETITLE OF DCLTBCTF017
           MOVE BODY OF P-LCTFM017 TO BODY OF DCLTBCTF017
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R030-CHECK-EVENT: The event of DCLTBCTF017 exists and is not  *
      * closed                                                        *
      *===============================================================*
       R030-CHECK-EVENT SECTION.
           EXEC SQL
              SELECT EVENTSTATUS
                INTO :W-STATUS
                FROM TBCTF002
               WHERE EVENTID = :DCLTBCTF017.EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF W-STATUS = C-C
                 MOVE N'08' TO RETURNCODE OF P-LCTFM017
                 MOVE N'53' TO REASONCODE OF P-LCTFM017
                 MOVE N'The event is closed' TO
                      INFOMESSAGE OF P-LCTFM017
              END-IF
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM017
              MOVE N'13' TO REASONCODE OF P-LCTFM017
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM017
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM017
              MOVE N'21' TO REASONCODE OF P-LCTFM017
              STRING N'SELECT event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM017
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R030-CHECK-EVENT-END.
           EXIT.

      *===============================================================*
      * R031-GET-EVENT: The event of the announcement, then           *
      * R030-CHECK-EVENT. W-MISSING is the reason code when the       *
      * announcement does not exist (31 or 41).                       *
      *===============================================================*
       R031-GET-EVENT SECTION.
           MOVE ANNOUNCEID OF P-LCTFM017 TO ANNOUNCEID OF DCLTBCTF017

           EXEC SQL
              SELECT EVENTID
                INTO :DCLTBCTF017.EVENTID
                FROM TBCTF017
               WHERE ANNOUNCEID = :DCLTBCTF017.ANNOUNCEID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R030-CHECK-EVENT
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM017
              MOVE W-MISSING TO REASONCODE OF P-LCTFM017
              MOVE N'Announcement not found' TO
                   INFOMESSAGE OF P-LCTFM017
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM017
              MOVE N'21' TO REASONCODE OF P-LCTFM017
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM017
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R031-GET-EVENT-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           MOVE EVENTID OF P-LCTFM017 TO EVENTID OF DCLTBCTF017

           PERFORM R030-CHECK-EVENT

           IF RETURNCODE OF P-LCTFM017 = N'00'
              EXEC SQL
                 SELECT ANNOUNCEID
                   INTO :DCLTBCTF017.ANNOUNCEID
                   FROM FINAL TABLE
                      (
                 INSERT
                   INTO TBCTF017
                        (EVENTID,
                         ANNOUNCETITLE,
                         BODY,
                         CREATEDBY,
                         CREATEDDATE,
                         UPDATEDBY,
                         UPDATEDDATE)
                 VALUES(:DCLTBCTF017.EVENTID,
                        :DCLTBCTF017.ANNOUNCETITLE,
                        :DCLTBCTF017.BODY,
                        :W-USERID,
                        CURRENT TIMESTAMP,
                        :W-USERID,
                        CURRENT TIMESTAMP)
                        )
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE ANNOUNCEID OF DCLTBCTF017 TO
                      ANNOUNCEID OF P-LCTFM017
              WHEN -530
                 MOVE N'08' TO RETURNCODE OF P-LCTFM017
                 MOVE N'13' TO REASONCODE OF P-LCTFM017
                 MOVE N'Event not found' TO
                      INFOMESSAGE OF P-LCTFM017
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM017
                 MOVE N'12' TO REASONCODE OF P-LCTFM017
                 STRING N'INSERT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM017
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
           MOVE ANNOUNCEID OF P-LCTFM017 TO ANNOUNCEID OF DCLTBCTF017

           EXEC SQL
              SELECT ANNOUNCEID,
                     EVENTID,
                     ANNOUNCETITLE,
                     BODY,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF017.ANNOUNCEID,
                     :DCLTBCTF017.EVENTID,
                     :DCLTBCTF017.ANNOUNCETITLE,
                     :DCLTBCTF017.BODY,
                     :DCLTBCTF017.CREATEDBY,
                     :DCLTBCTF017.CREATEDDATE,
                     :DCLTBCTF017.UPDATEDBY,
                     :DCLTBCTF017.UPDATEDDATE
                FROM TBCTF017
               WHERE ANNOUNCEID = :DCLTBCTF017.ANNOUNCEID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM017
              MOVE N'01' TO REASONCODE OF P-LCTFM017
              MOVE N'Announcement not found' TO
                   INFOMESSAGE OF P-LCTFM017
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM017
              MOVE N'21' TO REASONCODE OF P-LCTFM017
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM017
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R130-UPDATE: Update title and body, unless the event is       *
      * closed                                                        *
      *===============================================================*
       R130-UPDATE SECTION.
           MOVE N'31' TO W-MISSING
           PERFORM R031-GET-EVENT

           IF RETURNCODE OF P-LCTFM017 = N'00'
              EXEC SQL
                 UPDATE TBCTF017
                    SET ANNOUNCETITLE = :DCLTBCTF017.ANNOUNCETITLE,
                        BODY          = :DCLTBCTF017.BODY,
                        UPDATEDBY     = :W-USERID,
                        UPDATEDDATE   = CURRENT TIMESTAMP
                  WHERE ANNOUNCEID = :DCLTBCTF017.ANNOUNCEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM017
                 MOVE N'31' TO REASONCODE OF P-LCTFM017
                 MOVE N'Announcement not found' TO
                      INFOMESSAGE OF P-LCTFM017
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM017
                 MOVE N'32' TO REASONCODE OF P-LCTFM017
                 STRING N'UPDATE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM017
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R130-UPDATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row, unless the event is closed       *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE N'41' TO W-MISSING
           PERFORM R031-GET-EVENT

           IF RETURNCODE OF P-LCTFM017 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF017
                  WHERE ANNOUNCEID = :DCLTBCTF017.ANNOUNCEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM017
                 MOVE N'41' TO REASONCODE OF P-LCTFM017
                 MOVE N'Announcement not found' TO
                      INFOMESSAGE OF P-LCTFM017
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM017
                 MOVE N'42' TO REASONCODE OF P-LCTFM017
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM017
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
           MOVE ANNOUNCEID OF DCLTBCTF017 TO ANNOUNCEID OF P-LCTFM017
           MOVE EVENTID OF DCLTBCTF017 TO EVENTID OF P-LCTFM017
           MOVE ANNOUNCETITLE OF DCLTBCTF017 TO
                ANNOUNCETITLE OF P-LCTFM017
           MOVE BODY OF DCLTBCTF017 TO BODY OF P-LCTFM017
           MOVE CREATEDBY OF DCLTBCTF017 TO CREATEDBY OF P-LCTFM017
           MOVE CREATEDDATE OF DCLTBCTF017 TO CREATEDDATE OF P-LCTFM017
           MOVE UPDATEDBY OF DCLTBCTF017 TO UPDATEDBY OF P-LCTFM017
           MOVE UPDATEDDATE OF DCLTBCTF017 TO UPDATEDDATE OF P-LCTFM017
           .
       R121-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM017==.

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

       END PROGRAM CTFM017.
