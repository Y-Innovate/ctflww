       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM503.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/players/{playerID}: one player. The caller (the    *
      * admin wrapper) has checked CTF.ADMIN.                         *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Player not found                                      *
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
          05 W-SQLCODE    PIC -99999.
          05 W-EXPIRES-IND PIC S9(4) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM503.
           COPY LCTFM503.

       PROCEDURE DIVISION USING P-LCTFM503.
       MAIN SECTION.
           PERFORM R001-INIT

           IF RETURNCODE OF P-LCTFM503 = N'00'
              PERFORM R120-SELECT
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM503
           MOVE N'00' TO REASONCODE OF P-LCTFM503
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM503
           MOVE PLAYERID OF P-LCTFM503 TO PLAYERID OF DCLTBCTF003
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-SELECT: The player                                       *
      *===============================================================*
       R120-SELECT SECTION.
           EXEC SQL
              SELECT RACFUSERID,
                     DISPLAYNAME,
                     PLAYERSTATUS,
                     CLAIMEXPIRES,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF003.RACFUSERID,
                     :DCLTBCTF003.DISPLAYNAME,
                     :DCLTBCTF003.PLAYERSTATUS,
                     :DCLTBCTF003.CLAIMEXPIRES :W-EXPIRES-IND,
                     :DCLTBCTF003.CREATEDBY,
                     :DCLTBCTF003.CREATEDDATE,
                     :DCLTBCTF003.UPDATEDBY,
                     :DCLTBCTF003.UPDATEDDATE
                FROM TBCTF003
               WHERE PLAYERID = :DCLTBCTF003.PLAYERID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE RACFUSERID OF DCLTBCTF003 TO RACFUSERID OF P-LCTFM503
              MOVE DISPLAYNAME OF DCLTBCTF003 TO
                   DISPLAYNAME OF P-LCTFM503
              MOVE PLAYERSTATUS OF DCLTBCTF003 TO
                   PLAYERSTATUS OF P-LCTFM503
              IF W-EXPIRES-IND < 0
                 MOVE SPACES TO CLAIMEXPIRES OF P-LCTFM503
              ELSE
                 MOVE CLAIMEXPIRES OF DCLTBCTF003 TO
                      CLAIMEXPIRES OF P-LCTFM503
              END-IF
              MOVE CREATEDBY OF DCLTBCTF003 TO CREATEDBY OF P-LCTFM503
              MOVE CREATEDDATE OF DCLTBCTF003 TO
                   CREATEDDATE OF P-LCTFM503
              MOVE UPDATEDBY OF DCLTBCTF003 TO UPDATEDBY OF P-LCTFM503
              MOVE UPDATEDDATE OF DCLTBCTF003 TO
                   UPDATEDDATE OF P-LCTFM503
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM503
              MOVE N'01' TO REASONCODE OF P-LCTFM503
              MOVE N'Player not found' TO
                   INFOMESSAGE OF P-LCTFM503
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM503
              MOVE N'21' TO REASONCODE OF P-LCTFM503
              STRING N'SELECT player gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM503
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-SELECT-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM503==.

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

       END PROGRAM CTFM503.
