       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM304.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /registrations/{registrationID}: only the status, so a    *
      * guessed ID reveals nothing of value.                          *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Not found                                             *
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

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

       01 WORK.
          05 W-PGMNAME    PIC X(8).
          05 W-SQLCODE    PIC -99999.


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
       01 P-LCTFM304.
           COPY LCTFM304.

       PROCEDURE DIVISION USING P-LCTFM304.
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM304
           MOVE N'00' TO REASONCODE OF P-LCTFM304
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM304
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-SELECT: SELECT the status                                *
      *===============================================================*
       R120-SELECT SECTION.
           MOVE REGISTRATIONID OF P-LCTFM304 TO PLAYERID OF DCLTBCTF003

           EXEC SQL
              SELECT PLAYERSTATUS
                INTO :DCLTBCTF003.PLAYERSTATUS
                FROM TBCTF003
               WHERE PLAYERID = :DCLTBCTF003.PLAYERID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE PLAYERSTATUS OF DCLTBCTF003 TO
                   REGSTATUS OF P-LCTFM304
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM304
              MOVE N'01' TO REASONCODE OF P-LCTFM304
              MOVE N'Registration not found' TO
                   INFOMESSAGE OF P-LCTFM304
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM304
              MOVE N'21' TO REASONCODE OF P-LCTFM304
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM304
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

       END PROGRAM CTFM304.
