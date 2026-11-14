       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM202.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /events: published and closed events, newest first.       *
      * EVENTID-SINCE: paging, entries before this ID (0 = start).    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no events                *
      * 08 01/02/03 = Error: SQL error on OPEN/CLOSE/FETCH            *
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
          05 W-PGMNAME    PIC X(8).
          05 W-SQLCODE    PIC -99999.
          05 W-EVENTID-SINCE PIC S9(9) COMP-5.
          05 W-PHASE      PIC X.
          05 W-REGOPEN    PIC X.

       01 C-CODES.
          05 C-A          PIC N VALUE N'A'.
          05 C-C          PIC N VALUE N'C'.
          05 C-D          PIC N VALUE N'D'.
          05 C-F          PIC N VALUE N'F'.
          05 C-I          PIC N VALUE N'I'.
          05 C-N          PIC N VALUE N'N'.
          05 C-P          PIC N VALUE N'P'.
          05 C-R          PIC N VALUE N'R'.
          05 C-S          PIC N VALUE N'S'.
          05 C-Y          PIC N VALUE N'Y'.
          05 C-CATEGORY   PIC N(8) VALUE N'CATEGORY'.
          05 C-SETTINGS   PIC N(8) VALUE N'SETTINGS'.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM202.
           COPY LCTFM202.

       PROCEDURE DIVISION USING P-LCTFM202.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R007-OPEN-CURSOR

           IF RETURNCODE OF P-LCTFM202 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM202 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR EVENT-COUNT OF P-LCTFM202 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM202
           MOVE N'00' TO REASONCODE OF P-LCTFM202
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM202

           MOVE 0 TO EVENT-COUNT OF P-LCTFM202
           MOVE EVENTID-SINCE OF P-LCTFM202 TO W-EVENTID-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open cursor on TBCTF002                     *
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
                     CASE WHEN EVENTSTATUS <> :C-P THEN ' '
                          WHEN CURRENT TIMESTAMP < STARTTS THEN 'U'
                          WHEN CURRENT TIMESTAMP >= ENDTS THEN 'E'
                          WHEN FREEZETS <= CURRENT TIMESTAMP THEN 'F'
                          ELSE 'R' END,
                     CASE WHEN EVENTSTATUS = :C-P
                           AND CURRENT TIMESTAMP >= REGFROMTS
                           AND CURRENT TIMESTAMP <  REGTOTS
                          THEN 'Y' ELSE 'N' END
                FROM TBCTF002
               WHERE EVENTSTATUS <> :C-D
                 AND (:W-EVENTID-SINCE = 0
                  OR  EVENTID < :W-EVENTID-SINCE)
               ORDER BY EVENTID DESC
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM202
              MOVE N'01' TO REASONCODE OF P-LCTFM202
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM202
              PERFORM R900-DSNTIAR
           END-IF
           .
       R007-OPEN-CURSOR-END.
           EXIT.

      *===============================================================*
      * R190-CLOSE-CURSOR: Close cursor                               *
      *===============================================================*
       R190-CLOSE-CURSOR SECTION.
           EXEC SQL
              CLOSE C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM202
              MOVE N'02' TO REASONCODE OF P-LCTFM202
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM202
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
                     :DCLTBCTF002.FREEZETS
                       :DCLTBCTF002.FREEZETS-IND,
                     :DCLTBCTF002.REGFROMTS,
                     :DCLTBCTF002.REGTOTS,
                     :W-PHASE,
                     :W-REGOPEN
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO EVENT-COUNT OF P-LCTFM202
              PERFORM R220-COPY-EVENT
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM202
              MOVE N'03' TO REASONCODE OF P-LCTFM202
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM202
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-EVENT: Copy the fetched event                       *
      *===============================================================*
       R220-COPY-EVENT SECTION.
           MOVE EVENTID OF DCLTBCTF002 TO
                EVENTID OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE EVENTNAME OF DCLTBCTF002 TO
                EVENTNAME OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE EVENTSTATUS OF DCLTBCTF002 TO
                EVENTSTATUS OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE PLAYMODE OF DCLTBCTF002 TO
                PLAYMODE OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE MAXTEAMSIZE OF DCLTBCTF002 TO
                MAXTEAMSIZE OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE STARTTS OF DCLTBCTF002 TO
                STARTTS OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE ENDTS OF DCLTBCTF002 TO
                ENDTS OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE REGFROMTS OF DCLTBCTF002 TO
                REGFROMTS OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE REGTOTS OF DCLTBCTF002 TO
                REGTOTS OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           IF FREEZETS-IND OF DCLTBCTF002 < 0
              MOVE SPACES TO
                   FREEZETS OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           ELSE
              MOVE FREEZETS OF DCLTBCTF002 TO
                   FREEZETS OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-PHASE) TO
                PHASE OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           MOVE FUNCTION NATIONAL-OF(W-REGOPEN) TO
                REGOPEN OF P-LCTFM202(EVENT-COUNT OF P-LCTFM202)
           .
       R220-COPY-EVENT-END.
           EXIT.

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

       END PROGRAM CTFM202.
