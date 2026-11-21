       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM540.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST and DELETE /admin/eventArchives/{eventID}: archive a     *
      * CLOSED event (OPCODE A) or restore an ARCHIVED one to CLOSED  *
      * (OPCODE R). Only EVENTSTATUS changes: an archived event keeps *
      * all its data and stays read-only, its leaderboard visible.    *
      * GET /events leaves archived events out unless asked for with  *
      * eventStatus_filter=A. The caller (the admin wrapper) has      *
      * checked CTF.ADMIN, and rolls back on an error.                *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Event not found                                       *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 53 = Error: archive: event not CLOSED; restore: event not  *
      *         ARCHIVED                                              *
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

           EXEC SQL INCLUDE TBCTF002 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-OLD-STATUS PIC N.
          05 W-NEW-STATUS PIC N.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM540.
           COPY LCTFM540.

       PROCEDURE DIVISION USING P-LCTFM540.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM540 = N'00'
              PERFORM R110-CHANGE-STATUS
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM540
           MOVE N'00' TO REASONCODE OF P-LCTFM540
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM540
           MOVE SPACES TO EVENTSTATUS OF P-LCTFM540
           MOVE EVENTID OF P-LCTFM540 TO W-EVENTID

           INSPECT OPCODE OF P-LCTFM540
                   REPLACING ALL NX'0000' BY N' '
           EVALUATE OPCODE OF P-LCTFM540
           WHEN N'A'
              MOVE C-C TO W-OLD-STATUS
              MOVE C-A TO W-NEW-STATUS
           WHEN N'R'
              MOVE C-A TO W-OLD-STATUS
              MOVE C-C TO W-NEW-STATUS
           WHEN OTHER
              MOVE N'08' TO RETURNCODE OF P-LCTFM540
              MOVE N'01' TO REASONCODE OF P-LCTFM540
              MOVE N'OPCODE must be A or R' TO
                   INFOMESSAGE OF P-LCTFM540
           END-EVALUATE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R110-CHANGE-STATUS: CLOSED to ARCHIVED, or back               *
      *===============================================================*
       R110-CHANGE-STATUS SECTION.
           EXEC SQL
              UPDATE TBCTF002
                 SET EVENTSTATUS = :W-NEW-STATUS,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE EVENTID = :W-EVENTID
                 AND EVENTSTATUS = :W-OLD-STATUS
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE W-NEW-STATUS TO EVENTSTATUS OF P-LCTFM540
           WHEN 100
              PERFORM R115-WHY-NOT
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM540
              MOVE N'32' TO REASONCODE OF P-LCTFM540
              STRING N'UPDATE event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM540
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R110-CHANGE-STATUS-END.
           EXIT.

      *===============================================================*
      * R115-WHY-NOT: Unknown, or not possible                        *
      *===============================================================*
       R115-WHY-NOT SECTION.
           EXEC SQL
              SELECT EVENTSTATUS
                INTO :DCLTBCTF002.EVENTSTATUS
                FROM TBCTF002
               WHERE EVENTID = :W-EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM540
              MOVE N'53' TO REASONCODE OF P-LCTFM540
              MOVE EVENTSTATUS OF DCLTBCTF002 TO
                   EVENTSTATUS OF P-LCTFM540
              IF W-NEW-STATUS = C-A
                 MOVE N'Only a closed event can be archived' TO
                      INFOMESSAGE OF P-LCTFM540
              ELSE
                 MOVE N'Only an archived event can be restored' TO
                      INFOMESSAGE OF P-LCTFM540
              END-IF
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM540
              MOVE N'01' TO REASONCODE OF P-LCTFM540
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM540
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM540
              MOVE N'21' TO REASONCODE OF P-LCTFM540
              STRING N'SELECT event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM540
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R115-WHY-NOT-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM540==.

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

       END PROGRAM CTFM540.
