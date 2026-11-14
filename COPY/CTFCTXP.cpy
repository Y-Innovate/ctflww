      *===============================================================*
      * CTFCTXP: Player context for the player modules. Copy with     *
      *    COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFMnnn==.         *
      * Needs CTFCTXW, W-SQLCODE and section R900-DSNTIAR. Every      *
      * section does nothing when RETURNCODE is not 00 already, so    *
      * they can be performed one after the other.                    *
      * Codes set here:                                               *
      * 04 01 = Challenge not found or not visible (R106)             *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 50 = Error: not in the event, no active place, no team, or *
      *         challenge locked                                      *
      * 08 53 = Error: not a team event, not started, not running     *
      * 08 90 = Error: CTFA990 failed                                 *
      *===============================================================*

      *===============================================================*
      * R090-GET-USERID: The CICS userid of the player                *
      *===============================================================*
       R090-GET-USERID SECTION.
           IF RETURNCODE OF :IO: = N'00'
              CALL W-CTX-PGM USING W-LCTFA990

              IF RETURNCODE OF W-LCTFA990 NOT = N'00'
                 MOVE N'08' TO RETURNCODE OF :IO:
                 MOVE N'90' TO REASONCODE OF :IO:
                 MOVE INFOMESSAGE OF W-LCTFA990 TO
                      INFOMESSAGE OF :IO:
              ELSE
                 MOVE USERID OF W-LCTFA990 TO W-USERID
              END-IF
           END-IF
           .
       R090-GET-USERID-END.
           EXIT.

      *===============================================================*
      * R100-GET-CONTEXT: Who is playing, place and team in event     *
      * W-EVENTID, and what phase the event is in                     *
      *===============================================================*
       R100-GET-CONTEXT SECTION.
           PERFORM R090-GET-USERID

           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT P.PLAYERID,
                        PA.TEAMID,
                        PA.PARTSTATUS,
                        E.PLAYMODE,
                        E.MAXTEAMSIZE,
                        CASE WHEN CURRENT TIMESTAMP >= E.STARTTS
                             THEN 'Y' ELSE 'N' END,
                        CASE WHEN CURRENT TIMESTAMP <  E.ENDTS
                              AND E.EVENTSTATUS = :C-P
                             THEN 'Y' ELSE 'N' END,
                        CASE WHEN CURRENT TIMESTAMP >= E.REGFROMTS
                              AND CURRENT TIMESTAMP <  E.REGTOTS
                              AND E.EVENTSTATUS = :C-P
                             THEN 'Y' ELSE 'N' END,
                        CHAR(COALESCE(
                           CASE WHEN E.FREEZETS <= CURRENT TIMESTAMP
                                THEN E.FREEZETS END,
                           TIMESTAMP('9999-12-31-23.59.59.999999')))
                   INTO :W-PLAYERID,
                        :W-TEAMID :W-TEAMID-IND,
                        :W-PARTSTATUS,
                        :W-PLAYMODE,
                        :W-MAXTEAMSIZE,
                        :W-STARTED,
                        :W-NOTENDED,
                        :W-REGOPEN,
                        :W-CUTOFF
                   FROM TBCTF003 P
                   JOIN TBCTF006 PA
                     ON PA.PLAYERID = P.PLAYERID
                   JOIN TBCTF002 E
                     ON E.EVENTID = PA.EVENTID
                  WHERE P.RACFUSERID = :W-USERID
                    AND P.PLAYERSTATUS = :C-A
                    AND PA.EVENTID = :W-EVENTID
                    AND E.EVENTSTATUS <> :C-D
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF :IO:
                 MOVE N'50' TO REASONCODE OF :IO:
                 MOVE N'You did not join this event' TO
                      INFOMESSAGE OF :IO:
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF :IO:
                 MOVE N'21' TO REASONCODE OF :IO:
                 STRING N'SELECT context gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF :IO:
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R100-GET-CONTEXT-END.
           EXIT.

      *===============================================================*
      * R101-NEED-TEAM: An active place in a team                     *
      *===============================================================*
       R101-NEED-TEAM SECTION.
           IF  RETURNCODE OF :IO: = N'00'
           AND (W-TEAMID-IND < 0 OR W-PARTSTATUS NOT = C-A)
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'50' TO REASONCODE OF :IO:
              MOVE N'You have no active place in a team here' TO
                   INFOMESSAGE OF :IO:
           END-IF
           .
       R101-NEED-TEAM-END.
           EXIT.

      *===============================================================*
      * R102-NEED-STARTED: The event has started                      *
      *===============================================================*
       R102-NEED-STARTED SECTION.
           IF  RETURNCODE OF :IO: = N'00'
           AND W-STARTED NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'53' TO REASONCODE OF :IO:
              MOVE N'This event has not started yet' TO
                   INFOMESSAGE OF :IO:
           END-IF
           .
       R102-NEED-STARTED-END.
           EXIT.

      *===============================================================*
      * R103-NEED-RUNNING: The event has not ended (running, frozen)  *
      *===============================================================*
       R103-NEED-RUNNING SECTION.
           IF  RETURNCODE OF :IO: = N'00'
           AND W-NOTENDED NOT = 'Y'
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'53' TO REASONCODE OF :IO:
              MOVE N'This event is not running' TO
                   INFOMESSAGE OF :IO:
           END-IF
           .
       R103-NEED-RUNNING-END.
           EXIT.

      *===============================================================*
      * R104-NEED-ACTIVE: An active place, with or without a team     *
      *===============================================================*
       R104-NEED-ACTIVE SECTION.
           IF  RETURNCODE OF :IO: = N'00'
           AND W-PARTSTATUS NOT = C-A
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'50' TO REASONCODE OF :IO:
              MOVE N'Your place in this event is not active yet' TO
                   INFOMESSAGE OF :IO:
           END-IF
           .
       R104-NEED-ACTIVE-END.
           EXIT.

      *===============================================================*
      * R105-NEED-TEAMMODE: A team event                              *
      *===============================================================*
       R105-NEED-TEAMMODE SECTION.
           IF  RETURNCODE OF :IO: = N'00'
           AND W-PLAYMODE NOT = C-T
              MOVE N'08' TO RETURNCODE OF :IO:
              MOVE N'53' TO REASONCODE OF :IO:
              MOVE N'This is not a team event' TO
                   INFOMESSAGE OF :IO:
           END-IF
           .
       R105-NEED-TEAMMODE-END.
           EXIT.

      *===============================================================*
      * R106-CHECK-CHALLENGE: W-CHALLENGEID is visible in the event,  *
      * and not locked unless W-ALLOW-LOCKED = Y. Sets W-SOLVED and   *
      * W-LOCKED for the team.                                        *
      *===============================================================*
       R106-CHECK-CHALLENGE SECTION.
           IF RETURNCODE OF :IO: = N'00'
              EXEC SQL
                 SELECT CASE WHEN EXISTS
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
                                      AND S.CHALLENGEID =
                                          Q.REQCHALLENGEID
                                      AND S.TEAMID = :W-TEAMID))
                        THEN 'Y' ELSE 'N' END
                   INTO :W-SOLVED,
                        :W-LOCKED
                   FROM TBCTF011 EC
                  WHERE EC.EVENTID = :W-EVENTID
                    AND EC.CHALLENGEID = :W-CHALLENGEID
                    AND EC.ISVISIBLE = :C-Y
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 IF  W-LOCKED = 'Y'
                 AND W-ALLOW-LOCKED NOT = 'Y'
                    MOVE N'08' TO RETURNCODE OF :IO:
                    MOVE N'50' TO REASONCODE OF :IO:
                    MOVE N'This challenge is still locked' TO
                         INFOMESSAGE OF :IO:
                 END-IF
              WHEN 100
                 MOVE N'04' TO RETURNCODE OF :IO:
                 MOVE N'01' TO REASONCODE OF :IO:
                 MOVE N'Challenge not found' TO
                      INFOMESSAGE OF :IO:
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF :IO:
                 MOVE N'21' TO REASONCODE OF :IO:
                 STRING N'SELECT challenge gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF :IO:
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R106-CHECK-CHALLENGE-END.
           EXIT.
