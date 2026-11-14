       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM502.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /admin/eventClosures/{eventID}: closes a published event *
      * after its end. In the same unit of work it queues (Q) a REMOVE*
      * from the event group for every active place if the event has a*
      * RACF group, and a REVOKE for every ACTIVE or READY player     *
      * without a place in another open event. The scheduled batch    *
      * carries them out. The caller (the admin wrapper) has checked  *
      * CTF.ADMIN.                                                    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Event not found                                       *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 53 = Error: event not published, or not ended              *
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

           EXEC SQL INCLUDE TBCTF002 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-SECOK      PIC X.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM502.
           COPY LCTFM502.

       PROCEDURE DIVISION USING P-LCTFM502.
       MAIN SECTION.
           PERFORM R001-INIT
           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM502 = N'00'
              PERFORM R110-CLOSE
           END-IF

           IF   RETURNCODE OF P-LCTFM502 = N'00'
           AND RACFGROUP-IND OF DCLTBCTF002 >= 0
              PERFORM R130-QUEUE-REMOVE
           END-IF

           IF RETURNCODE OF P-LCTFM502 = N'00'
              PERFORM R140-QUEUE-REVOKE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM502
           MOVE N'00' TO REASONCODE OF P-LCTFM502
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM502
           MOVE SPACES TO EVENTSTATUS OF P-LCTFM502
           MOVE EVENTID OF P-LCTFM502 TO W-EVENTID
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R110-CLOSE: Only a published event after its end              *
      *===============================================================*
       R110-CLOSE SECTION.
           EXEC SQL
              SELECT RACFGROUP
                INTO :DCLTBCTF002.RACFGROUP
                       :DCLTBCTF002.RACFGROUP-IND
                FROM FINAL TABLE
                   (
              UPDATE TBCTF002
                 SET EVENTSTATUS = :C-C,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE EVENTID = :W-EVENTID
                 AND EVENTSTATUS = :C-P
                 AND ENDTS <= CURRENT TIMESTAMP
                   )
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE C-C TO EVENTSTATUS OF P-LCTFM502
           WHEN 100
              PERFORM R115-WHY-NOT
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM502
              MOVE N'32' TO REASONCODE OF P-LCTFM502
              STRING N'UPDATE event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM502
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R110-CLOSE-END.
           EXIT.

      *===============================================================*
      * R115-WHY-NOT: Unknown, or not possible                        *
      *===============================================================*
       R115-WHY-NOT SECTION.
           EXEC SQL
              SELECT EVENTSTATUS
                INTO :DCLTBCTF002.EVENTSTATUS
                FROM TBCTF002
               WHERE EVENTID = :W-EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM502
              MOVE N'53' TO REASONCODE OF P-LCTFM502
              MOVE N'Only a published event after its end' TO
                   INFOMESSAGE OF P-LCTFM502
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM502
              MOVE N'01' TO REASONCODE OF P-LCTFM502
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM502
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM502
              MOVE N'21' TO REASONCODE OF P-LCTFM502
              STRING N'SELECT event gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM502
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R115-WHY-NOT-END.
           EXIT.

      *===============================================================*
      * R130-QUEUE-REMOVE: REMOVE from the group, per place           *
      *===============================================================*
       R130-QUEUE-REMOVE SECTION.
           EXEC SQL
              INSERT
                INTO TBCTF004
                     (PLAYERID,
                      EVENTID,
                      PROVACTION,
                      RACFGROUP,
                      JOBSTATUS,
                      RETRYCOUNT,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              SELECT PA.PLAYERID,
                     PA.EVENTID,
                     :C-M,
                     :DCLTBCTF002.RACFGROUP,
                     :C-Q,
                     0,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP
                FROM TBCTF006 PA
                JOIN TBCTF003 P
                  ON P.PLAYERID = PA.PLAYERID
               WHERE PA.EVENTID = :W-EVENTID
                 AND PA.PARTSTATUS = :C-A
                 AND P.PLAYERSTATUS IN (:C-A, :C-R)
           END-EXEC

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM502
              MOVE N'12' TO REASONCODE OF P-LCTFM502
              STRING N'INSERT remove jobs gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM502
              PERFORM R900-DSNTIAR
           END-IF
           .
       R130-QUEUE-REMOVE-END.
           EXIT.

      *===============================================================*
      * R140-QUEUE-REVOKE: REVOKE, if in no other open event          *
      *===============================================================*
       R140-QUEUE-REVOKE SECTION.
           EXEC SQL
              INSERT
                INTO TBCTF004
                     (PLAYERID,
                      EVENTID,
                      PROVACTION,
                      JOBSTATUS,
                      RETRYCOUNT,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              SELECT PA.PLAYERID,
                     PA.EVENTID,
                     :C-V,
                     :C-Q,
                     0,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP
                FROM TBCTF006 PA
                JOIN TBCTF003 P
                  ON P.PLAYERID = PA.PLAYERID
               WHERE PA.EVENTID = :W-EVENTID
                 AND P.PLAYERSTATUS IN (:C-A, :C-R)
                 AND NOT EXISTS
                     (SELECT 1
                        FROM TBCTF006 PB
                        JOIN TBCTF002 EB
                          ON EB.EVENTID = PB.EVENTID
                       WHERE PB.PLAYERID = PA.PLAYERID
                         AND PB.EVENTID <> PA.EVENTID
                         AND EB.EVENTSTATUS = :C-P
                         AND EB.ENDTS > CURRENT TIMESTAMP)
           END-EXEC

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM502
              MOVE N'12' TO REASONCODE OF P-LCTFM502
              STRING N'INSERT revoke jobs gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM502
              PERFORM R900-DSNTIAR
           END-IF
           .
       R140-QUEUE-REVOKE-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM502==.

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

       END PROGRAM CTFM502.
