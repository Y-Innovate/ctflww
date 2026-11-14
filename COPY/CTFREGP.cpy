      *===============================================================*
      * CTFREGP: Taking a place in an event, shared by CTFM303        *
      * (POST /registrations) and CTFM306 (POST /participants). Copy  *
      * with COPY CTFREGP REPLACING ==:IO:== BY ==P-LCTFMnnn==.       *
      * The IO area has EVENTID and REGCODE. Needs CTFREGW, the       *
      * DCLGENs of TBCTF002 to TBCTF006, W-LCTFA990, C-CODES,         *
      * W-SQLCODE, R900-DSNTIAR and linkage P-LCTFC910.               *
      * R150 needs PLAYERID, DISPLAYNAME and DISPLAYKEY in DCLTBCTF003 *
      * and W-JOINCODE; R160 W-NEW-PARTSTATUS, and W-NEW-TEAMID from  *
      * R150; R170 W-NEW-ACTION and W-JOBHASH with its indicator.     *
      *===============================================================*

      *===============================================================*
      * R110-CHECK-EVENT: Code and window; same answer for both       *
      *===============================================================*
       R110-CHECK-EVENT SECTION.
           MOVE EVENTID OF :IO: TO EVENTID OF DCLTBCTF002
           MOVE REGCODE OF :IO: TO REGCODE OF DCLTBCTF002

           EXEC SQL
              SELECT PLAYMODE,
                     RACFGROUP
                INTO :DCLTBCTF002.PLAYMODE,
                     :DCLTBCTF002.RACFGROUP
                       :DCLTBCTF002.RACFGROUP-IND
                FROM TBCTF002
               WHERE EVENTID = :DCLTBCTF002.EVENTID
                 AND EVENTSTATUS = :C-P
                 AND REGCODE = :DCLTBCTF002.REGCODE
                 AND CURRENT TIMESTAMP >= REGFROMTS
                 AND CURRENT TIMESTAMP <  REGTOTS
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'51' TO REASONCODE OF :IO:
              MOVE N'Wrong code or registration is closed' TO
                   INFOMESSAGE OF :IO:
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'21' TO REASONCODE OF :IO:
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF :IO:
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R110-CHECK-EVENT-END.
           EXIT.

      *===============================================================*
      * R120-TAKE-PLACE: Take a place; the WHERE keeps the cap        *
      *===============================================================*
       R120-TAKE-PLACE SECTION.
           EXEC SQL
              UPDATE TBCTF002
                 SET PLAYERCOUNT = PLAYERCOUNT + 1
               WHERE EVENTID = :DCLTBCTF002.EVENTID
                 AND PLAYERCOUNT < MAXPLAYERS
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'52' TO REASONCODE OF :IO:
              MOVE N'This event is full' TO
                   INFOMESSAGE OF :IO:
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'32' TO REASONCODE OF :IO:
              STRING N'UPDATE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF :IO:
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-TAKE-PLACE-END.
           EXIT.

      *===============================================================*
      * R150-INSERT-TEAM: Team of one for an individual event         *
      *===============================================================*
       R150-INSERT-TEAM SECTION.
           EXEC SQL
              SELECT TEAMID
                INTO :W-NEW-TEAMID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF005
                     (EVENTID,
                      TEAMNAME,
                      TEAMKEY,
                      JOINCODE,
                      CAPTAINID,
                      MEMBERCOUNT,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF002.EVENTID,
                     :DCLTBCTF003.DISPLAYNAME,
                     :DCLTBCTF003.DISPLAYKEY,
                     :W-JOINCODE,
                     :DCLTBCTF003.PLAYERID,
                     1,
                     :W-LCTFA990.USERID,
                     CURRENT TIMESTAMP,
                     :W-LCTFA990.USERID,
                     CURRENT TIMESTAMP)
                     )
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'12' TO REASONCODE OF :IO:
              STRING N'INSERT team gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF :IO:
              PERFORM R900-DSNTIAR
           END-IF
           .
       R150-INSERT-TEAM-END.
           EXIT.

      *===============================================================*
      * R160-INSERT-PLACE: INSERT the place; pending until job is done *
      *===============================================================*
       R160-INSERT-PLACE SECTION.
           IF PLAYMODE OF DCLTBCTF002 = C-I
              MOVE 0 TO TEAMID-IND OF DCLTBCTF006
              MOVE W-NEW-TEAMID TO TEAMID OF DCLTBCTF006
           ELSE
              MOVE -1 TO TEAMID-IND OF DCLTBCTF006
           END-IF

           EXEC SQL
              INSERT
                INTO TBCTF006
                     (EVENTID,
                      PLAYERID,
                      TEAMID,
                      PARTSTATUS,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF002.EVENTID,
                     :DCLTBCTF003.PLAYERID,
                     :DCLTBCTF006.TEAMID
                       :DCLTBCTF006.TEAMID-IND,
                     :W-NEW-PARTSTATUS,
                     :W-LCTFA990.USERID,
                     CURRENT TIMESTAMP,
                     :W-LCTFA990.USERID,
                     CURRENT TIMESTAMP)
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'12' TO REASONCODE OF :IO:
              STRING N'INSERT place gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF :IO:
              PERFORM R900-DSNTIAR
           END-IF
           .
       R160-INSERT-PLACE-END.
           EXIT.

      *===============================================================*
      * R170-INSERT-JOB: INSERT job row, fill in the job area         *
      *===============================================================*
       R170-INSERT-JOB SECTION.
           EXEC SQL
              SELECT PROVJOBID
                INTO :DCLTBCTF004.PROVJOBID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF004
                     (PLAYERID,
                      EVENTID,
                      PROVACTION,
                      RACFGROUP,
                      JOBSTATUS,
                      RETRYCOUNT,
                      JOBHASH,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF003.PLAYERID,
                     :DCLTBCTF002.EVENTID,
                     :W-NEW-ACTION,
                     :DCLTBCTF002.RACFGROUP
                       :DCLTBCTF002.RACFGROUP-IND,
                     :C-N,
                     0,
                     :W-JOBHASH :W-JOBHASH-IND,
                     :W-LCTFA990.USERID,
                     CURRENT TIMESTAMP,
                     :W-LCTFA990.USERID,
                     CURRENT TIMESTAMP)
                     )
           END-EXEC

           IF SQLCODE = 0
              MOVE PROVJOBID OF DCLTBCTF004 TO PROVJOBID OF P-LCTFC910
           ELSE
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'12' TO REASONCODE OF :IO:
              STRING N'INSERT job gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF :IO:
              PERFORM R900-DSNTIAR
           END-IF
           .
       R170-INSERT-JOB-END.
           EXIT.
