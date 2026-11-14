       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM313.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /submissions: compares the flag with all flags of the    *
      * challenge and records the attempt and, if correct, the solve. *
      * A wrong flag is not an error: 00 00 with ISCORRECT N.         *
      * The primary key of TBCTF014 guarantees one solve per team,    *
      * also for teammates submitting at the same moment.             *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Challenge not found or not visible                    *
      * 08 02 = Error: flag required                                  *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 50 = Error: no active place in a team, or locked           *
      * 08 53 = Error: event is not running                           *
      * 08 54 = Error: team already solved this challenge             *
      * 08 55 = Error: attempts used up                               *
      * 08 61/62/63 = Error: SQL error on OPEN/CLOSE/FETCH            *
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

           EXEC SQL INCLUDE TBCTF008 END-EXEC.

           EXEC SQL INCLUDE TBCTF011 END-EXEC.

           EXEC SQL INCLUDE TBCTF013 END-EXEC.

           EXEC SQL INCLUDE TBCTF014 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-WRONG      PIC S9(9) COMP-5.
          05 W-MATCH      PIC X.
          05 W-FLAG-START PIC S9(4) COMP-5.
          05 W-FLAG-END   PIC S9(4) COMP-5.
          05 W-FLAG-LEN   PIC S9(4) COMP-5.
          05 W-TRIMMED    PIC N(255).
          05 W-STORED     PIC N(255).
          05 W-A          PIC N(255).
          05 W-B          PIC N(255).

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM313.
           COPY LCTFM313.

       PROCEDURE DIVISION USING P-LCTFM313.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R100-GET-CONTEXT
           PERFORM R101-NEED-TEAM
           PERFORM R102-NEED-STARTED
           PERFORM R103-NEED-RUNNING

           IF RETURNCODE OF P-LCTFM313 = N'00'
              PERFORM R120-CHECK-CHALLENGE
           END-IF

           IF RETURNCODE OF P-LCTFM313 = N'00'
              PERFORM R130-COMPARE-FLAGS
           END-IF

           IF RETURNCODE OF P-LCTFM313 = N'00'
              PERFORM R140-INSERT-SUBMISSION
           END-IF

           IF  RETURNCODE OF P-LCTFM313 = N'00'
           AND W-MATCH = 'Y'
              PERFORM R150-INSERT-SOLVE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Initialisations; trim the submitted flag           *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM313
           MOVE N'00' TO REASONCODE OF P-LCTFM313
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM313
           MOVE EVENTID OF P-LCTFM313 TO W-EVENTID

           MOVE CHALLENGEID OF P-LCTFM313 TO W-CHALLENGEID
           MOVE 'N' TO W-MATCH
           MOVE 0 TO W-FLAG-LEN
           MOVE SPACES TO W-TRIMMED
           MOVE FLAG-LEN OF P-LCTFM313 TO W-FLAG-END
           IF W-FLAG-END > 255
              MOVE 255 TO W-FLAG-END
           END-IF
           MOVE 1 TO W-FLAG-START

           PERFORM UNTIL W-FLAG-START > W-FLAG-END
              OR FLAG-TEXT OF P-LCTFM313(W-FLAG-START:1) NOT = SPACE
              ADD 1 TO W-FLAG-START
           END-PERFORM

           PERFORM UNTIL W-FLAG-END < W-FLAG-START
              OR FLAG-TEXT OF P-LCTFM313(W-FLAG-END:1) NOT = SPACE
              SUBTRACT 1 FROM W-FLAG-END
           END-PERFORM

           IF W-FLAG-END < W-FLAG-START
              MOVE N'08' TO RETURNCODE OF P-LCTFM313
              MOVE N'02' TO REASONCODE OF P-LCTFM313
              MOVE N'A flag is required' TO
                   INFOMESSAGE OF P-LCTFM313
           ELSE
              COMPUTE W-FLAG-LEN = W-FLAG-END - W-FLAG-START + 1
              MOVE FLAG-TEXT OF P-LCTFM313(W-FLAG-START:W-FLAG-LEN)
                TO W-TRIMMED
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R120-CHECK-CHALLENGE: Is this submission allowed              *
      *===============================================================*
       R120-CHECK-CHALLENGE SECTION.
           EXEC SQL
              SELECT EC.MAXATTEMPTS,
                     (SELECT COUNT(*) FROM TBCTF013 U
                       WHERE U.EVENTID = EC.EVENTID
                         AND U.CHALLENGEID = EC.CHALLENGEID
                         AND U.TEAMID = :W-TEAMID
                         AND U.ISCORRECT = :C-N),
                     CASE WHEN EXISTS
                       (SELECT 1 FROM TBCTF014 S
                         WHERE S.EVENTID = EC.EVENTID
                           AND S.CHALLENGEID = EC.CHALLENGEID
                           AND S.TEAMID = :W-TEAMID)
                     THEN 'Y' ELSE 'N' END,
                     CASE WHEN EXISTS
                       (SELECT 1 FROM TBCTF012 Q
                         WHERE Q.EVENTID = EC.EVENTID
                           AND Q.CHALLENGEID = EC.CHALLENGEID
                           AND NOT EXISTS
                               (SELECT 1 FROM TBCTF014 S
                                 WHERE S.EVENTID = Q.EVENTID
                                   AND S.CHALLENGEID = Q.REQCHALLENGEID
                                   AND S.TEAMID = :W-TEAMID))
                     THEN 'Y' ELSE 'N' END
                INTO :DCLTBCTF011.MAXATTEMPTS
                       :DCLTBCTF011.MAXATTEMPTS-IND,
                     :W-WRONG,
                     :W-SOLVED,
                     :W-LOCKED
                FROM TBCTF011 EC
               WHERE EC.EVENTID = :W-EVENTID
                 AND EC.CHALLENGEID = :W-CHALLENGEID
                 AND EC.ISVISIBLE = :C-Y
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              EVALUATE TRUE
              WHEN W-LOCKED = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM313
                 MOVE N'50' TO REASONCODE OF P-LCTFM313
                 MOVE N'This challenge is still locked' TO
                      INFOMESSAGE OF P-LCTFM313
              WHEN W-SOLVED = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM313
                 MOVE N'54' TO REASONCODE OF P-LCTFM313
                 MOVE N'Your team already solved this challenge' TO
                      INFOMESSAGE OF P-LCTFM313
              WHEN MAXATTEMPTS-IND OF DCLTBCTF011 >= 0
               AND W-WRONG >= MAXATTEMPTS OF DCLTBCTF011
                 MOVE N'08' TO RETURNCODE OF P-LCTFM313
                 MOVE N'55' TO REASONCODE OF P-LCTFM313
                 MOVE N'Your team has used up its attempts' TO
                      INFOMESSAGE OF P-LCTFM313
              END-EVALUATE
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM313
              MOVE N'01' TO REASONCODE OF P-LCTFM313
              MOVE N'Challenge not found' TO
                   INFOMESSAGE OF P-LCTFM313
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM313
              MOVE N'21' TO REASONCODE OF P-LCTFM313
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM313
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-CHECK-CHALLENGE-END.
           EXIT.

      *===============================================================*
      * R130-COMPARE-FLAGS: Compare with every flag of the challenge  *
      *===============================================================*
       R130-COMPARE-FLAGS SECTION.
           EXEC SQL
              DECLARE C1 CURSOR FOR
              SELECT FLAGVALUE,
                     CASESENSITIVE
                FROM TBCTF008
               WHERE CHALLENGEID = :W-CHALLENGEID
                 FOR FETCH ONLY
           END-EXEC

           EXEC SQL
              OPEN C1
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM313
              MOVE N'61' TO REASONCODE OF P-LCTFM313
              STRING N'OPEN CURSOR gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM313
              PERFORM R900-DSNTIAR
           ELSE
              PERFORM UNTIL RETURNCODE OF P-LCTFM313 NOT = N'00'
                         OR SQLCODE NOT = 0
                         OR W-MATCH = 'Y'
                 EXEC SQL
                    FETCH C1
                     INTO :DCLTBCTF008.FLAGVALUE,
                          :DCLTBCTF008.CASESENSITIVE
                 END-EXEC

                 EVALUATE SQLCODE
                 WHEN 0
                    PERFORM R135-COMPARE-ONE
                 WHEN 100
                    CONTINUE
                 WHEN OTHER
                    MOVE SQLCODE TO W-SQLCODE
                    MOVE N'08' TO RETURNCODE OF P-LCTFM313
                    MOVE N'63' TO REASONCODE OF P-LCTFM313
                    STRING N'FETCH CURSOR gave SQLCODE='
                           FUNCTION NATIONAL-OF(W-SQLCODE)
                       DELIMITED BY SIZE
                       INTO INFOMESSAGE OF P-LCTFM313
                    PERFORM R900-DSNTIAR
                 END-EVALUATE
              END-PERFORM

              EXEC SQL
                 CLOSE C1
              END-EXEC
           END-IF
           .
       R130-COMPARE-FLAGS-END.
           EXIT.

      *===============================================================*
      * R135-COMPARE-ONE: Compare with the fetched flag               *
      *===============================================================*
       R135-COMPARE-ONE SECTION.
           MOVE SPACES TO W-STORED
           IF FLAGVALUE-LEN OF DCLTBCTF008 > 0
              MOVE FLAGVALUE-TEXT OF DCLTBCTF008
                 (1:FLAGVALUE-LEN OF DCLTBCTF008) TO W-STORED
           END-IF

           IF CASESENSITIVE OF DCLTBCTF008 = C-Y
              MOVE W-STORED TO W-A
              MOVE W-TRIMMED TO W-B
           ELSE
              MOVE FUNCTION UPPER-CASE(W-STORED) TO W-A
              MOVE FUNCTION UPPER-CASE(W-TRIMMED) TO W-B
           END-IF

           IF W-A = W-B
              MOVE 'Y' TO W-MATCH
           END-IF
           .
       R135-COMPARE-ONE-END.
           EXIT.

      *===============================================================*
      * R140-INSERT-SUBMISSION: Record the attempt                    *
      *===============================================================*
       R140-INSERT-SUBMISSION SECTION.
           MOVE W-FLAG-LEN TO SUBMITTEDTEXT-LEN OF DCLTBCTF013
           MOVE W-TRIMMED TO SUBMITTEDTEXT-TEXT OF DCLTBCTF013
           MOVE FUNCTION NATIONAL-OF(W-MATCH) TO
                ISCORRECT OF DCLTBCTF013

           EXEC SQL
              SELECT SUBMISSIONID
                INTO :DCLTBCTF013.SUBMISSIONID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF013
                     (EVENTID,
                      CHALLENGEID,
                      TEAMID,
                      PLAYERID,
                      SUBMITTEDTEXT,
                      ISCORRECT,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:W-EVENTID,
                     :W-CHALLENGEID,
                     :W-TEAMID,
                     :W-PLAYERID,
                     :DCLTBCTF013.SUBMITTEDTEXT,
                     :DCLTBCTF013.ISCORRECT,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
                     )
           END-EXEC

           IF SQLCODE = 0
              MOVE SUBMISSIONID OF DCLTBCTF013 TO
                   SUBMISSIONID OF P-LCTFM313
              MOVE ISCORRECT OF DCLTBCTF013 TO
                   ISCORRECT OF P-LCTFM313
              IF W-MATCH = 'N'
                 ADD 1 TO W-WRONG
              END-IF
              IF MAXATTEMPTS-IND OF DCLTBCTF011 < 0
                 MOVE -1 TO ATTEMPTSLEFT OF P-LCTFM313
              ELSE
                 COMPUTE ATTEMPTSLEFT OF P-LCTFM313 =
                    FUNCTION MAX(0,
                       MAXATTEMPTS OF DCLTBCTF011 - W-WRONG)
              END-IF
           ELSE
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM313
              MOVE N'12' TO REASONCODE OF P-LCTFM313
              STRING N'INSERT submission gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM313
              PERFORM R900-DSNTIAR
           END-IF
           .
       R140-INSERT-SUBMISSION-END.
           EXIT.

      *===============================================================*
      * R150-INSERT-SOLVE: Record the solve; -803 = teammate was first *
      *===============================================================*
       R150-INSERT-SOLVE SECTION.
           EXEC SQL
              INSERT
                INTO TBCTF014
                     (EVENTID,
                      CHALLENGEID,
                      TEAMID,
                      PLAYERID,
                      SUBMISSIONID,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:W-EVENTID,
                     :W-CHALLENGEID,
                     :W-TEAMID,
                     :W-PLAYERID,
                     :DCLTBCTF013.SUBMISSIONID,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN -803
              MOVE N'08' TO RETURNCODE OF P-LCTFM313
              MOVE N'54' TO REASONCODE OF P-LCTFM313
              MOVE N'Your team already solved this challenge' TO
                   INFOMESSAGE OF P-LCTFM313
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM313
              MOVE N'12' TO REASONCODE OF P-LCTFM313
              STRING N'INSERT solve gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM313
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R150-INSERT-SOLVE-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM313==.

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

       END PROGRAM CTFM313.
