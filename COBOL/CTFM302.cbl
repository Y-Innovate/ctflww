       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM302.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /events/{eventID}: a published or closed event.           *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Not found, or still a draft                           *
      * 08 21 = Error: SQL error in SELECT                            *
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
       01 P-LCTFM302.
           COPY LCTFM302.

       PROCEDURE DIVISION USING P-LCTFM302.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R120-SELECT
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM302
           MOVE N'00' TO REASONCODE OF P-LCTFM302
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM302
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-SELECT: SELECT the event                                 *
      *===============================================================*
       R120-SELECT SECTION.
           MOVE EVENTID OF P-LCTFM302 TO EVENTID OF DCLTBCTF002

           EXEC SQL
              SELECT DESCRIPTION,
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
                INTO :DCLTBCTF002.DESCRIPTION
                       :DCLTBCTF002.DESCRIPTION-IND,
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
                FROM TBCTF002
               WHERE EVENTID = :DCLTBCTF002.EVENTID
                 AND EVENTSTATUS <> :C-D
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
           MOVE EVENTID OF DCLTBCTF002 TO
                EVENTID OF P-LCTFM302
           MOVE EVENTNAME OF DCLTBCTF002 TO
                EVENTNAME OF P-LCTFM302
           MOVE EVENTSTATUS OF DCLTBCTF002 TO
                EVENTSTATUS OF P-LCTFM302
           MOVE PLAYMODE OF DCLTBCTF002 TO
                PLAYMODE OF P-LCTFM302
           MOVE MAXTEAMSIZE OF DCLTBCTF002 TO
                MAXTEAMSIZE OF P-LCTFM302
           MOVE STARTTS OF DCLTBCTF002 TO
                STARTTS OF P-LCTFM302
           MOVE ENDTS OF DCLTBCTF002 TO
                ENDTS OF P-LCTFM302
           MOVE REGFROMTS OF DCLTBCTF002 TO
                REGFROMTS OF P-LCTFM302
           MOVE REGTOTS OF DCLTBCTF002 TO
                REGTOTS OF P-LCTFM302
           IF FREEZETS-IND OF DCLTBCTF002 < 0
              MOVE SPACES TO
                   FREEZETS OF P-LCTFM302
           ELSE
              MOVE FREEZETS OF DCLTBCTF002 TO
                   FREEZETS OF P-LCTFM302
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-PHASE) TO
                PHASE OF P-LCTFM302
           MOVE FUNCTION NATIONAL-OF(W-REGOPEN) TO
                REGOPEN OF P-LCTFM302
              IF DESCRIPTION-IND OF DCLTBCTF002 < 0
                 MOVE 0 TO DESCRIPTION-LEN OF P-LCTFM302
              ELSE
                 MOVE DESCRIPTION OF DCLTBCTF002 TO
                      DESCRIPTION OF P-LCTFM302
              END-IF
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM302
              MOVE N'01' TO REASONCODE OF P-LCTFM302
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM302
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM302
              MOVE N'21' TO REASONCODE OF P-LCTFM302
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM302
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-SELECT-END.
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

       END PROGRAM CTFM302.
