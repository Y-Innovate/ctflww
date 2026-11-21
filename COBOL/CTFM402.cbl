       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM402.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/events: all events, by EVENTID, also drafts and    *
      * closed ones. Filter, optional: status. Without it, archived   *
      * events are left out; filter A lists them. The caller (the     *
      * admin wrapper) has checked CTF.ADMIN.                         *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no rows                  *
      * 08 61/62/63 = Error: SQL error on OPEN/CLOSE/FETCH            *
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
          05 W-STATUS-PAT.
             49 W-STATUS-PAT-LEN  PIC S9(4) COMP-5.
             49 W-STATUS-PAT-TEXT PIC N(2).
          05 W-PHASE      PIC X.
          05 W-EVENT-SINCE PIC S9(9) COMP-5.
          05 W-I          PIC S9(4) COMP-5.
          05 W-NOT-STATUS PIC N.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM402.
           COPY LCTFM402.

       PROCEDURE DIVISION USING P-LCTFM402.
       MAIN SECTION.
           PERFORM R001-INIT



           IF RETURNCODE OF P-LCTFM402 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM402 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM402 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR EVENT-COUNT OF P-LCTFM402 >= 20
                 PERFORM R210-FETCH-CURSOR
              END-PERFORM

              PERFORM R190-CLOSE-CURSOR
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM402
           MOVE N'00' TO REASONCODE OF P-LCTFM402
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM402
           MOVE 0 TO EVENT-COUNT OF P-LCTFM402
           MOVE 1 TO W-STATUS-PAT-LEN
           MOVE N'%' TO W-STATUS-PAT-TEXT
      *    No filter: everything but archived (W-NOT-STATUS A). With a
      *    filter, W-NOT-STATUS is a space, which no status equals.
           MOVE C-A TO W-NOT-STATUS
           INSPECT EVENTSTATUS-FILTER OF P-LCTFM402
                   REPLACING ALL NX'0000' BY N' '
           IF EVENTSTATUS-FILTER OF P-LCTFM402 NOT = SPACES
              STRING FUNCTION UPPER-CASE(
                        EVENTSTATUS-FILTER OF P-LCTFM402)
                        DELIMITED BY SPACE
                     N'%' DELIMITED BY SIZE
                INTO W-STATUS-PAT-TEXT
                WITH POINTER W-STATUS-PAT-LEN
              SUBTRACT 1 FROM W-STATUS-PAT-LEN
              MOVE SPACE TO W-NOT-STATUS
           END-IF
           MOVE EVENTID-SINCE OF P-LCTFM402 TO W-EVENT-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT EVENTID,
                     EVENTNAME,
                     EVENTSTATUS,
                     PLAYMODE,
                     MAXTEAMSIZE,
                     STARTTS,
                     ENDTS,
                     FREEZETS,
                     REGFROMTS,
                     REGTOTS,
                     MAXPLAYERS,
                     PLAYERCOUNT,
                     RACFGROUP,
                     CASE WHEN EVENTSTATUS <> :C-P THEN ' '
                          WHEN CURRENT TIMESTAMP < STARTTS THEN 'U'
                          WHEN CURRENT TIMESTAMP >= ENDTS THEN 'E'
                          WHEN FREEZETS <= CURRENT TIMESTAMP THEN 'F'
                          ELSE 'R' END,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                FROM TBCTF002
               WHERE EVENTSTATUS LIKE :W-STATUS-PAT
                 AND EVENTSTATUS <> :W-NOT-STATUS
                 AND EVENTID > :W-EVENT-SINCE
               ORDER BY EVENTID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM402
              MOVE N'61' TO REASONCODE OF P-LCTFM402
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM402
              PERFORM R900-DSNTIAR
           END-IF
           .
       R007-OPEN-CURSOR-END.
           EXIT.

      *===============================================================*
      * R190-CLOSE-CURSOR: Close the cursor                           *
      *===============================================================*
       R190-CLOSE-CURSOR SECTION.
           EXEC SQL
              CLOSE C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM402
              MOVE N'62' TO REASONCODE OF P-LCTFM402
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM402
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one event                            *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF002.EVENTID,
                    :DCLTBCTF002.EVENTNAME,
                    :DCLTBCTF002.EVENTSTATUS,
                    :DCLTBCTF002.PLAYMODE,
                    :DCLTBCTF002.MAXTEAMSIZE,
                    :DCLTBCTF002.STARTTS,
                    :DCLTBCTF002.ENDTS,
                    :DCLTBCTF002.FREEZETS :DCLTBCTF002.FREEZETS-IND,
                    :DCLTBCTF002.REGFROMTS,
                    :DCLTBCTF002.REGTOTS,
                    :DCLTBCTF002.MAXPLAYERS,
                    :DCLTBCTF002.PLAYERCOUNT,
                    :DCLTBCTF002.RACFGROUP :DCLTBCTF002.RACFGROUP-IND,
                    :W-PHASE,
                    :DCLTBCTF002.CREATEDBY,
                    :DCLTBCTF002.CREATEDDATE,
                    :DCLTBCTF002.UPDATEDBY,
                    :DCLTBCTF002.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO EVENT-COUNT OF P-LCTFM402
              MOVE EVENT-COUNT OF P-LCTFM402 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM402
              MOVE N'63' TO REASONCODE OF P-LCTFM402
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM402
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched event                         *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE EVENTID OF DCLTBCTF002 TO
                EVENTID OF P-LCTFM402(W-I)
           MOVE EVENTNAME OF DCLTBCTF002 TO
                EVENTNAME OF P-LCTFM402(W-I)
           MOVE EVENTSTATUS OF DCLTBCTF002 TO
                EVENTSTATUS OF P-LCTFM402(W-I)
           MOVE PLAYMODE OF DCLTBCTF002 TO
                PLAYMODE OF P-LCTFM402(W-I)
           MOVE MAXTEAMSIZE OF DCLTBCTF002 TO
                MAXTEAMSIZE OF P-LCTFM402(W-I)
           MOVE STARTTS OF DCLTBCTF002 TO
                STARTTS OF P-LCTFM402(W-I)
           MOVE ENDTS OF DCLTBCTF002 TO
                ENDTS OF P-LCTFM402(W-I)
           IF FREEZETS-IND OF DCLTBCTF002 < 0
              MOVE SPACES TO FREEZETS OF P-LCTFM402(W-I)
           ELSE
              MOVE FREEZETS OF DCLTBCTF002 TO
                   FREEZETS OF P-LCTFM402(W-I)
           END-IF
           MOVE REGFROMTS OF DCLTBCTF002 TO
                REGFROMTS OF P-LCTFM402(W-I)
           MOVE REGTOTS OF DCLTBCTF002 TO
                REGTOTS OF P-LCTFM402(W-I)
           MOVE MAXPLAYERS OF DCLTBCTF002 TO
                MAXPLAYERS OF P-LCTFM402(W-I)
           MOVE PLAYERCOUNT OF DCLTBCTF002 TO
                PLAYERCOUNT OF P-LCTFM402(W-I)
           IF RACFGROUP-IND OF DCLTBCTF002 < 0
              MOVE SPACES TO RACFGROUP OF P-LCTFM402(W-I)
           ELSE
              MOVE RACFGROUP OF DCLTBCTF002 TO
                   RACFGROUP OF P-LCTFM402(W-I)
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-PHASE) TO
                PHASE OF P-LCTFM402(W-I)
           MOVE CREATEDBY OF DCLTBCTF002 TO
                CREATEDBY OF P-LCTFM402(W-I)
           MOVE CREATEDDATE OF DCLTBCTF002 TO
                CREATEDDATE OF P-LCTFM402(W-I)
           MOVE UPDATEDBY OF DCLTBCTF002 TO
                UPDATEDBY OF P-LCTFM402(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF002 TO
                UPDATEDDATE OF P-LCTFM402(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM402==.

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

       END PROGRAM CTFM402.
