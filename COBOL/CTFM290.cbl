       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM290.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /me: the player record of the signed-in userid. An admin  *
      * has no player record: PLAYERID stays 0, which is not an error. *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
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
       01 P-LCTFM290.
           COPY LCTFM290.

       PROCEDURE DIVISION USING P-LCTFM290.
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM290
           MOVE N'00' TO REASONCODE OF P-LCTFM290
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM290

           MOVE 0 TO PLAYERID OF P-LCTFM290
           MOVE 0 TO DISPLAYNAME-LEN OF P-LCTFM290
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-SELECT: SELECT the player                                *
      *===============================================================*
       R120-SELECT SECTION.
           MOVE RACFUSERID OF P-LCTFM290 TO RACFUSERID OF DCLTBCTF003

           EXEC SQL
              SELECT PLAYERID,
                     DISPLAYNAME
                INTO :DCLTBCTF003.PLAYERID,
                     :DCLTBCTF003.DISPLAYNAME
                FROM TBCTF003
               WHERE RACFUSERID = :DCLTBCTF003.RACFUSERID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE PLAYERID OF DCLTBCTF003 TO PLAYERID OF P-LCTFM290
              MOVE DISPLAYNAME OF DCLTBCTF003 TO
                   DISPLAYNAME OF P-LCTFM290
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM290
              MOVE N'21' TO REASONCODE OF P-LCTFM290
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM290
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

       END PROGRAM CTFM290.
