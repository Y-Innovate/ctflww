       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM403.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/players: find players, by PLAYERID. Filters, each  *
      * optional: display name and userid from the start of the name, *
      * regardless of case; status; a place in an event. The caller   *
      * (the admin wrapper) has checked CTF.ADMIN.                    *
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

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-PLAYER-SINCE PIC S9(9) COMP-5.
          05 W-EVENT-FILTER PIC S9(9) COMP-5.
          05 W-FILTER     PIC N(8).
          05 W-EXPIRES-IND PIC S9(4) COMP-5.
          05 W-NAME-PAT.
             49 W-NAME-PAT-LEN  PIC S9(4) COMP-5.
             49 W-NAME-PAT-TEXT PIC N(31).
          05 W-USERID-PAT.
             49 W-USERID-PAT-LEN  PIC S9(4) COMP-5.
             49 W-USERID-PAT-TEXT PIC N(9).
          05 W-STATUS-PAT.
             49 W-STATUS-PAT-LEN  PIC S9(4) COMP-5.
             49 W-STATUS-PAT-TEXT PIC N(2).
          05 W-I          PIC S9(4) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM403.
           COPY LCTFM403.

       PROCEDURE DIVISION USING P-LCTFM403.
       MAIN SECTION.
           PERFORM R001-INIT

      *    The admin wrapper has checked CTF.ADMIN already

           IF RETURNCODE OF P-LCTFM403 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM403 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM403 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR PLAYER-COUNT OF P-LCTFM403 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM403
           MOVE N'00' TO REASONCODE OF P-LCTFM403
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM403
           MOVE 0 TO PLAYER-COUNT OF P-LCTFM403
           MOVE PLAYERID-SINCE OF P-LCTFM403 TO W-PLAYER-SINCE
           MOVE EVENTID-FILTER OF P-LCTFM403 TO W-EVENT-FILTER

           MOVE 1 TO W-NAME-PAT-LEN
           MOVE N'%' TO W-NAME-PAT-TEXT
           IF  DISPLAYNAME-FILTER-LEN OF P-LCTFM403 > 0
           AND DISPLAYNAME-FILTER-LEN OF P-LCTFM403 <= 30
              MOVE 1 TO W-NAME-PAT-LEN
              STRING FUNCTION UPPER-CASE(
                        DISPLAYNAME-FILTER-TEXT OF P-LCTFM403(1:
                           DISPLAYNAME-FILTER-LEN OF P-LCTFM403))
                     N'%'
                     DELIMITED BY SIZE
                INTO W-NAME-PAT-TEXT
                WITH POINTER W-NAME-PAT-LEN
              SUBTRACT 1 FROM W-NAME-PAT-LEN
           END-IF

           MOVE 1 TO W-USERID-PAT-LEN
           MOVE N'%' TO W-USERID-PAT-TEXT
           MOVE RACFUSERID-FILTER OF P-LCTFM403 TO W-FILTER
           INSPECT W-FILTER REPLACING ALL NX'0000' BY N' '
           IF W-FILTER NOT = SPACES
              STRING FUNCTION UPPER-CASE(W-FILTER) DELIMITED BY SPACE
                     N'%' DELIMITED BY SIZE
                INTO W-USERID-PAT-TEXT
                WITH POINTER W-USERID-PAT-LEN
              SUBTRACT 1 FROM W-USERID-PAT-LEN
           END-IF

           MOVE 1 TO W-STATUS-PAT-LEN
           MOVE N'%' TO W-STATUS-PAT-TEXT
           MOVE PLAYERSTATUS-FILTER OF P-LCTFM403 TO W-FILTER
           INSPECT W-FILTER REPLACING ALL NX'0000' BY N' '
           IF W-FILTER NOT = SPACES
              STRING FUNCTION UPPER-CASE(W-FILTER) DELIMITED BY SPACE
                     N'%' DELIMITED BY SIZE
                INTO W-STATUS-PAT-TEXT
                WITH POINTER W-STATUS-PAT-LEN
              SUBTRACT 1 FROM W-STATUS-PAT-LEN
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT P.PLAYERID,
                     P.RACFUSERID,
                     P.DISPLAYNAME,
                     P.PLAYERSTATUS,
                     P.CLAIMEXPIRES,
                     P.CREATEDBY,
                     P.CREATEDDATE,
                     P.UPDATEDBY,
                     P.UPDATEDDATE
                FROM TBCTF003 P
               WHERE P.DISPLAYKEY LIKE :W-NAME-PAT
                 AND P.RACFUSERID LIKE :W-USERID-PAT
                 AND P.PLAYERSTATUS LIKE :W-STATUS-PAT
                 AND (:W-EVENT-FILTER = 0
                  OR  EXISTS
                     (SELECT 1 FROM TBCTF006 PA
                       WHERE PA.PLAYERID = P.PLAYERID
                         AND PA.EVENTID = :W-EVENT-FILTER))
                 AND P.PLAYERID > :W-PLAYER-SINCE
               ORDER BY P.PLAYERID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM403
              MOVE N'61' TO REASONCODE OF P-LCTFM403
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM403
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM403
              MOVE N'62' TO REASONCODE OF P-LCTFM403
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM403
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one player                           *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF003.PLAYERID,
                    :DCLTBCTF003.RACFUSERID,
                    :DCLTBCTF003.DISPLAYNAME,
                    :DCLTBCTF003.PLAYERSTATUS,
                    :DCLTBCTF003.CLAIMEXPIRES :W-EXPIRES-IND,
                    :DCLTBCTF003.CREATEDBY,
                    :DCLTBCTF003.CREATEDDATE,
                    :DCLTBCTF003.UPDATEDBY,
                    :DCLTBCTF003.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO PLAYER-COUNT OF P-LCTFM403
              MOVE PLAYER-COUNT OF P-LCTFM403 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM403
              MOVE N'63' TO REASONCODE OF P-LCTFM403
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM403
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched player                        *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE PLAYERID OF DCLTBCTF003 TO PLAYERID OF P-LCTFM403(W-I)
           MOVE RACFUSERID OF DCLTBCTF003 TO
                RACFUSERID OF P-LCTFM403(W-I)
           MOVE DISPLAYNAME OF DCLTBCTF003 TO
                DISPLAYNAME OF P-LCTFM403(W-I)
           MOVE PLAYERSTATUS OF DCLTBCTF003 TO
                PLAYERSTATUS OF P-LCTFM403(W-I)
           IF W-EXPIRES-IND < 0
              MOVE SPACES TO CLAIMEXPIRES OF P-LCTFM403(W-I)
           ELSE
              MOVE CLAIMEXPIRES OF DCLTBCTF003 TO
                   CLAIMEXPIRES OF P-LCTFM403(W-I)
           END-IF
           MOVE CREATEDBY OF DCLTBCTF003 TO CREATEDBY OF P-LCTFM403(W-I)
           MOVE CREATEDDATE OF DCLTBCTF003 TO
                CREATEDDATE OF P-LCTFM403(W-I)
           MOVE UPDATEDBY OF DCLTBCTF003 TO UPDATEDBY OF P-LCTFM403(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF003 TO
                UPDATEDDATE OF P-LCTFM403(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM403==.

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

       END PROGRAM CTFM403.
