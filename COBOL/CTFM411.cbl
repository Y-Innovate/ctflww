       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM411.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/eventChallenges: the challenges of an event with   *
      * their scoring, hidden ones too, by CHALLENGEID. MINPOINTS,    *
      * DECAYSOLVES and MAXATTEMPTS are 0 when empty. The caller (the *
      * admin wrapper) has checked CTF.ADMIN.                         *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success, also when there are no rows                  *
      * 08 01 = Error: a required filter is missing                   *
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

           EXEC SQL INCLUDE TBCTF007 END-EXEC.

           EXEC SQL INCLUDE TBCTF011 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-EVENT      PIC S9(9) COMP-5.
          05 W-SINCE      PIC S9(9) COMP-5.
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
       01 P-LCTFM411.
           COPY LCTFM411.

       PROCEDURE DIVISION USING P-LCTFM411.
       MAIN SECTION.
           PERFORM R001-INIT

           IF EVENTID-FILTER OF P-LCTFM411 = 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM411
              MOVE N'01' TO REASONCODE OF P-LCTFM411
              MOVE N'eventID is required' TO
                   INFOMESSAGE OF P-LCTFM411
           END-IF

           IF RETURNCODE OF P-LCTFM411 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM411 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM411 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR EVENTCHALL-COUNT OF P-LCTFM411 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM411
           MOVE N'00' TO REASONCODE OF P-LCTFM411
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM411
           MOVE 0 TO EVENTCHALL-COUNT OF P-LCTFM411
           MOVE EVENTID-FILTER OF P-LCTFM411 TO W-EVENT
           MOVE CHALLENGEID-SINCE OF P-LCTFM411 TO W-SINCE
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R007-OPEN-CURSOR: Open the cursor                             *
      *===============================================================*
       R007-OPEN-CURSOR SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT EC.EVENTID,
                     EC.CHALLENGEID,
                     C.CHALLENGETITLE,
                     EC.SCORETYPE,
                     EC.INITPOINTS,
                     COALESCE(EC.MINPOINTS, 0),
                     COALESCE(EC.DECAYSOLVES, 0),
                     EC.ISVISIBLE,
                     EC.SORTORDER,
                     COALESCE(EC.MAXATTEMPTS, 0),
                     EC.CREATEDBY,
                     EC.CREATEDDATE,
                     EC.UPDATEDBY,
                     EC.UPDATEDDATE
                FROM TBCTF011 EC
                JOIN TBCTF007 C
                  ON C.CHALLENGEID = EC.CHALLENGEID
               WHERE EC.EVENTID = :W-EVENT
                 AND EC.CHALLENGEID > :W-SINCE
               ORDER BY EC.CHALLENGEID
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM411
              MOVE N'61' TO REASONCODE OF P-LCTFM411
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM411
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM411
              MOVE N'62' TO REASONCODE OF P-LCTFM411
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM411
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one challenge                        *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF011.EVENTID,
                    :DCLTBCTF011.CHALLENGEID,
                    :DCLTBCTF007.CHALLENGETITLE,
                    :DCLTBCTF011.SCORETYPE,
                    :DCLTBCTF011.INITPOINTS,
                    :DCLTBCTF011.MINPOINTS,
                    :DCLTBCTF011.DECAYSOLVES,
                    :DCLTBCTF011.ISVISIBLE,
                    :DCLTBCTF011.SORTORDER,
                    :DCLTBCTF011.MAXATTEMPTS,
                    :DCLTBCTF011.CREATEDBY,
                    :DCLTBCTF011.CREATEDDATE,
                    :DCLTBCTF011.UPDATEDBY,
                    :DCLTBCTF011.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO EVENTCHALL-COUNT OF P-LCTFM411
              MOVE EVENTCHALL-COUNT OF P-LCTFM411 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM411
              MOVE N'63' TO REASONCODE OF P-LCTFM411
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM411
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched challenge                     *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE EVENTID OF DCLTBCTF011 TO
                EVENTID OF P-LCTFM411(W-I)
           MOVE CHALLENGEID OF DCLTBCTF011 TO
                CHALLENGEID OF P-LCTFM411(W-I)
           MOVE CHALLENGETITLE OF DCLTBCTF007 TO
                CHALLENGETITLE OF P-LCTFM411(W-I)
           MOVE SCORETYPE OF DCLTBCTF011 TO
                SCORETYPE OF P-LCTFM411(W-I)
           MOVE INITPOINTS OF DCLTBCTF011 TO
                INITPOINTS OF P-LCTFM411(W-I)
           MOVE MINPOINTS OF DCLTBCTF011 TO
                MINPOINTS OF P-LCTFM411(W-I)
           MOVE DECAYSOLVES OF DCLTBCTF011 TO
                DECAYSOLVES OF P-LCTFM411(W-I)
           MOVE ISVISIBLE OF DCLTBCTF011 TO
                ISVISIBLE OF P-LCTFM411(W-I)
           MOVE SORTORDER OF DCLTBCTF011 TO
                SORTORDER OF P-LCTFM411(W-I)
           MOVE MAXATTEMPTS OF DCLTBCTF011 TO
                MAXATTEMPTS OF P-LCTFM411(W-I)
           MOVE CREATEDBY OF DCLTBCTF011 TO
                CREATEDBY OF P-LCTFM411(W-I)
           MOVE CREATEDDATE OF DCLTBCTF011 TO
                CREATEDDATE OF P-LCTFM411(W-I)
           MOVE UPDATEDBY OF DCLTBCTF011 TO
                UPDATEDBY OF P-LCTFM411(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF011 TO
                UPDATEDDATE OF P-LCTFM411(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM411==.

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

       END PROGRAM CTFM411.
