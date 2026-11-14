       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM404.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * GET /admin/provisioningJobs: provisioning jobs, newest first, *
      * so PROVJOBID-SINCE pages downwards; 0 = start. Filters, each  *
      * optional: status, event, player. EVENTID 0 = no event, JOBRC  *
      * -1 = no return code. The caller (the admin wrapper) has       *
      * checked CTF.ADMIN.                                            *
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

           EXEC SQL INCLUDE TBCTF004 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-JOB-SINCE  PIC S9(9) COMP-5.
          05 W-EVENT-FILTER PIC S9(9) COMP-5.
          05 W-FILTER     PIC N(8).
          05 W-PLAYER-FILTER PIC S9(9) COMP-5.
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
       01 P-LCTFM404.
           COPY LCTFM404.

       PROCEDURE DIVISION USING P-LCTFM404.
       MAIN SECTION.
           PERFORM R001-INIT

      *    The admin wrapper has checked CTF.ADMIN already

           IF RETURNCODE OF P-LCTFM404 = N'00'
              PERFORM R007-OPEN-CURSOR
           END-IF

           IF RETURNCODE OF P-LCTFM404 = N'00'
              PERFORM R210-FETCH-CURSOR

              PERFORM WITH TEST BEFORE
                UNTIL RETURNCODE OF P-LCTFM404 NOT = N'00'
                   OR SQLCODE NOT = 0
                   OR JOB-COUNT OF P-LCTFM404 >= 20
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
           MOVE N'00' TO RETURNCODE OF P-LCTFM404
           MOVE N'00' TO REASONCODE OF P-LCTFM404
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM404
           MOVE 0 TO JOB-COUNT OF P-LCTFM404
           MOVE PROVJOBID-SINCE OF P-LCTFM404 TO W-JOB-SINCE
           MOVE EVENTID-FILTER OF P-LCTFM404 TO W-EVENT-FILTER
           MOVE PLAYERID-FILTER OF P-LCTFM404 TO W-PLAYER-FILTER

           MOVE 1 TO W-STATUS-PAT-LEN
           MOVE N'%' TO W-STATUS-PAT-TEXT
           MOVE JOBSTATUS-FILTER OF P-LCTFM404 TO W-FILTER
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
              SELECT PROVJOBID,
                     PLAYERID,
                     EVENTID,
                     PROVACTION,
                     RACFGROUP,
                     JOBSTATUS,
                     JESJOBID,
                     SUBMITTEDDATE,
                     COMPLETEDDATE,
                     JOBRC,
                     JOBMESSAGE,
                     RETRYCOUNT,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                FROM TBCTF004
               WHERE JOBSTATUS LIKE :W-STATUS-PAT
                 AND (:W-EVENT-FILTER = 0
                  OR  EVENTID = :W-EVENT-FILTER)
                 AND (:W-PLAYER-FILTER = 0
                  OR  PLAYERID = :W-PLAYER-FILTER)
                 AND (:W-JOB-SINCE = 0
                  OR  PROVJOBID < :W-JOB-SINCE)
               ORDER BY PROVJOBID DESC
               FETCH FIRST 20 ROWS ONLY
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM404
              MOVE N'61' TO REASONCODE OF P-LCTFM404
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM404
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM404
              MOVE N'62' TO REASONCODE OF P-LCTFM404
              STRING N'CLOSE CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM404
              PERFORM R900-DSNTIAR
           END-IF
           .
       R190-CLOSE-CURSOR-END.
           EXIT.

      *===============================================================*
      * R210-FETCH-CURSOR: Fetch one job                              *
      *===============================================================*
       R210-FETCH-CURSOR SECTION.
           EXEC SQL
              FETCH C1
               INTO :DCLTBCTF004.PROVJOBID,
                    :DCLTBCTF004.PLAYERID,
                    :DCLTBCTF004.EVENTID
                      :DCLTBCTF004.EVENTID-IND,
                    :DCLTBCTF004.PROVACTION,
                    :DCLTBCTF004.RACFGROUP
                      :DCLTBCTF004.RACFGROUP-IND,
                    :DCLTBCTF004.JOBSTATUS,
                    :DCLTBCTF004.JESJOBID
                      :DCLTBCTF004.JESJOBID-IND,
                    :DCLTBCTF004.SUBMITTEDDATE
                      :DCLTBCTF004.SUBMITTEDDATE-IND,
                    :DCLTBCTF004.COMPLETEDDATE
                      :DCLTBCTF004.COMPLETEDDATE-IND,
                    :DCLTBCTF004.JOBRC
                      :DCLTBCTF004.JOBRC-IND,
                    :DCLTBCTF004.JOBMESSAGE
                      :DCLTBCTF004.JOBMESSAGE-IND,
                    :DCLTBCTF004.RETRYCOUNT,
                    :DCLTBCTF004.CREATEDBY,
                    :DCLTBCTF004.CREATEDDATE,
                    :DCLTBCTF004.UPDATEDBY,
                    :DCLTBCTF004.UPDATEDDATE
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              ADD 1 TO JOB-COUNT OF P-LCTFM404
              MOVE JOB-COUNT OF P-LCTFM404 TO W-I
              PERFORM R220-COPY-ROW
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM404
              MOVE N'63' TO REASONCODE OF P-LCTFM404
              STRING N'FETCH CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM404
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R210-FETCH-CURSOR-END.
           EXIT.

      *===============================================================*
      * R220-COPY-ROW: Copy the fetched job                           *
      *===============================================================*
       R220-COPY-ROW SECTION.
           MOVE PROVJOBID OF DCLTBCTF004 TO PROVJOBID OF P-LCTFM404(W-I)
           MOVE PLAYERID OF DCLTBCTF004 TO PLAYERID OF P-LCTFM404(W-I)
           IF EVENTID-IND OF DCLTBCTF004 < 0
              MOVE 0 TO EVENTID OF P-LCTFM404(W-I)
           ELSE
              MOVE EVENTID OF DCLTBCTF004 TO EVENTID OF P-LCTFM404(W-I)
           END-IF
           MOVE PROVACTION OF DCLTBCTF004 TO
                PROVACTION OF P-LCTFM404(W-I)
           IF RACFGROUP-IND OF DCLTBCTF004 < 0
              MOVE SPACES TO RACFGROUP OF P-LCTFM404(W-I)
           ELSE
              MOVE RACFGROUP OF DCLTBCTF004 TO
                   RACFGROUP OF P-LCTFM404(W-I)
           END-IF
           MOVE JOBSTATUS OF DCLTBCTF004 TO JOBSTATUS OF P-LCTFM404(W-I)
           IF JESJOBID-IND OF DCLTBCTF004 < 0
              MOVE SPACES TO JESJOBID OF P-LCTFM404(W-I)
           ELSE
              MOVE JESJOBID OF DCLTBCTF004 TO
                   JESJOBID OF P-LCTFM404(W-I)
           END-IF
           IF SUBMITTEDDATE-IND OF DCLTBCTF004 < 0
              MOVE SPACES TO SUBMITTEDDATE OF P-LCTFM404(W-I)
           ELSE
              MOVE SUBMITTEDDATE OF DCLTBCTF004 TO
                   SUBMITTEDDATE OF P-LCTFM404(W-I)
           END-IF
           IF COMPLETEDDATE-IND OF DCLTBCTF004 < 0
              MOVE SPACES TO COMPLETEDDATE OF P-LCTFM404(W-I)
           ELSE
              MOVE COMPLETEDDATE OF DCLTBCTF004 TO
                   COMPLETEDDATE OF P-LCTFM404(W-I)
           END-IF
           IF JOBRC-IND OF DCLTBCTF004 < 0
              MOVE -1 TO JOBRC OF P-LCTFM404(W-I)
           ELSE
              MOVE JOBRC OF DCLTBCTF004 TO JOBRC OF P-LCTFM404(W-I)
           END-IF
           IF JOBMESSAGE-IND OF DCLTBCTF004 < 0
              MOVE 0 TO JOBMESSAGE-LEN OF P-LCTFM404(W-I)
           ELSE
              MOVE JOBMESSAGE OF DCLTBCTF004 TO
                   JOBMESSAGE OF P-LCTFM404(W-I)
           END-IF
           MOVE RETRYCOUNT OF DCLTBCTF004 TO
                RETRYCOUNT OF P-LCTFM404(W-I)
           MOVE CREATEDBY OF DCLTBCTF004 TO CREATEDBY OF P-LCTFM404(W-I)
           MOVE CREATEDDATE OF DCLTBCTF004 TO
                CREATEDDATE OF P-LCTFM404(W-I)
           MOVE UPDATEDBY OF DCLTBCTF004 TO UPDATEDBY OF P-LCTFM404(W-I)
           MOVE UPDATEDDATE OF DCLTBCTF004 TO
                UPDATEDDATE OF P-LCTFM404(W-I)
           .
       R220-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM404==.

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

       END PROGRAM CTFM404.
