       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM002.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST, GET, PUT and DELETE /admin/events: create, read, update *
      * or delete an event, by OPCODE C, R, U or D. A new event is a  *
      * DRAFT. Publishing needs a visible challenge; back to DRAFT    *
      * only without places; CLOSED only through CTFM502, and then    *
      * read-only. Once anyone has a place, play mode and RACF group  *
      * are locked, and team size and cap cannot go below what is     *
      * taken. Only a DRAFT can be deleted, with its challenges,      *
      * prerequisites and announcements. The caller (the admin        *
      * wrapper) has checked CTF.ADMIN, and commits or rolls back.    *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Event not found                                       *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: name, description or code missing or too long  *
      * 08 03 = Error: invalid status or play mode                    *
      * 08 04 = Error: invalid team size or cap                       *
      * 08 05 = Error: dates missing, invalid or in the wrong order   *
      * 08 06 = Error: RACF group not in RACFGRP                      *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 31/41 = Error: update or delete of a missing event         *
      * 08 53 = Error: not possible in this state, see the message    *
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
          05 W-ONE        PIC S9(9) COMP-5.
          05 W-COUNT      PIC S9(9) COMP-5.
          05 C-RACFGRP    PIC N(8) VALUE N'RACFGRP'.
          05 W-BLANK8     PIC N(8) VALUE SPACES.
          05 W-PHASE      PIC X.
          05 W-OK1        PIC X.
          05 W-OK2        PIC X.
          05 W-OK3        PIC X.
          05 W-NEW-GROUP  PIC N(8).
          05 W-OLD-STATUS PIC N.
          05 W-OLD-PLAYMODE PIC N.
          05 W-OLD-GROUP  PIC N(8).
          05 W-OLD-GROUP-IND PIC S9(4) COMP-5.
          05 W-OLD-COUNT  PIC S9(9) COMP-5.
          05 W-PLACES     PIC S9(9) COMP-5.
          05 W-MAX-MEMBERS PIC S9(9) COMP-5.
          05 W-VISIBLE    PIC S9(9) COMP-5.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM002.
           COPY LCTFM002.

       PROCEDURE DIVISION USING P-LCTFM002.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM002 = N'00'
              EVALUATE OPCODE OF P-LCTFM002
              WHEN N'C'
                 PERFORM R110-CREATE
              WHEN N'R'
                 PERFORM R120-READ
              WHEN N'U'
                 PERFORM R130-UPDATE
              WHEN N'D'
                 PERFORM R140-DELETE
              END-EVALUATE
           END-IF

      *    Answer with the row as it is now
           IF RETURNCODE OF P-LCTFM002 = N'00'
           AND (OPCODE OF P-LCTFM002 = N'C'
             OR OPCODE OF P-LCTFM002 = N'U')
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM002
           MOVE N'00' TO REASONCODE OF P-LCTFM002
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM002
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM002 NOT = N'C'
             AND OPCODE OF P-LCTFM002 NOT = N'R'
             AND OPCODE OF P-LCTFM002 NOT = N'U'
             AND OPCODE OF P-LCTFM002 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'01' TO REASONCODE OF P-LCTFM002
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM002
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
           AND (OPCODE OF P-LCTFM002 = N'C'
             OR OPCODE OF P-LCTFM002 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM002 = N'00'
           AND (EVENTNAME-LEN OF P-LCTFM002 < 1
             OR EVENTNAME-LEN OF P-LCTFM002 > 100)
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'02' TO REASONCODE OF P-LCTFM002
              MOVE N'eventName is required, up to 100 characters' TO
                   INFOMESSAGE OF P-LCTFM002
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
           AND (DESCRIPTION-LEN OF P-LCTFM002 < 0
             OR DESCRIPTION-LEN OF P-LCTFM002 > 1000)
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'02' TO REASONCODE OF P-LCTFM002
              MOVE N'eventDescription has up to 1000 characters' TO
                   INFOMESSAGE OF P-LCTFM002
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
           AND (REGCODE-LEN OF P-LCTFM002 < 1
             OR REGCODE-LEN OF P-LCTFM002 > 32)
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'02' TO REASONCODE OF P-LCTFM002
              MOVE N'regCode is required, up to 32 characters' TO
                   INFOMESSAGE OF P-LCTFM002
           END-IF

           INSPECT EVENTSTATUS OF P-LCTFM002
                   REPLACING ALL NX'0000' BY N' '
           IF OPCODE OF P-LCTFM002 = N'C'
              IF EVENTSTATUS OF P-LCTFM002 = SPACE
                 MOVE N'D' TO EVENTSTATUS OF P-LCTFM002
              END-IF
              IF RETURNCODE OF P-LCTFM002 = N'00'
              AND (EVENTSTATUS OF P-LCTFM002 NOT = N'D')
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'03' TO REASONCODE OF P-LCTFM002
                 STRING N'A new event is a DRAFT: eventStatus must '
                        N'be D'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
              END-IF
           ELSE
              IF RETURNCODE OF P-LCTFM002 = N'00'
              AND EVENTSTATUS OF P-LCTFM002 = N'C'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 STRING N'Close an event with POST '
                        N'/admin/eventClosures'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
              END-IF
              IF RETURNCODE OF P-LCTFM002 = N'00'
              AND (EVENTSTATUS OF P-LCTFM002 NOT = N'D'
                AND EVENTSTATUS OF P-LCTFM002 NOT = N'P')
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'03' TO REASONCODE OF P-LCTFM002
                 MOVE N'eventStatus must be D or P' TO
                      INFOMESSAGE OF P-LCTFM002
              END-IF
           END-IF

           INSPECT PLAYMODE OF P-LCTFM002
                   REPLACING ALL NX'0000' BY N' '
           IF RETURNCODE OF P-LCTFM002 = N'00'
           AND (PLAYMODE OF P-LCTFM002 NOT = N'I'
             AND PLAYMODE OF P-LCTFM002 NOT = N'T')
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'03' TO REASONCODE OF P-LCTFM002
              MOVE N'playMode must be I or T' TO
                   INFOMESSAGE OF P-LCTFM002
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
              EVALUATE TRUE
              WHEN PLAYMODE OF P-LCTFM002 = N'I'
               AND MAXTEAMSIZE OF P-LCTFM002 = 0
                 MOVE 1 TO MAXTEAMSIZE OF P-LCTFM002
              WHEN PLAYMODE OF P-LCTFM002 = N'I'
               AND MAXTEAMSIZE OF P-LCTFM002 NOT = 1
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'04' TO REASONCODE OF P-LCTFM002
                 MOVE N'An individual event has maxTeamSize 1' TO
                      INFOMESSAGE OF P-LCTFM002
              WHEN PLAYMODE OF P-LCTFM002 = N'T'
               AND MAXTEAMSIZE OF P-LCTFM002 < 2
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'04' TO REASONCODE OF P-LCTFM002
                 MOVE N'A team event has maxTeamSize 2 or more' TO
                      INFOMESSAGE OF P-LCTFM002
              END-EVALUATE
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
           AND MAXPLAYERS OF P-LCTFM002 < 1
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'04' TO REASONCODE OF P-LCTFM002
              MOVE N'maxPlayers must be 1 or more' TO
                   INFOMESSAGE OF P-LCTFM002
           END-IF

           INSPECT RACFGROUP OF P-LCTFM002
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION UPPER-CASE(RACFGROUP OF P-LCTFM002)
             TO RACFGROUP OF P-LCTFM002
           MOVE RACFGROUP OF P-LCTFM002 TO W-NEW-GROUP
           MOVE RACFGROUP OF P-LCTFM002 TO RACFGROUP OF DCLTBCTF002
           IF RACFGROUP OF P-LCTFM002 = SPACES
              MOVE -1 TO RACFGROUP-IND OF DCLTBCTF002
           ELSE
              MOVE 0 TO RACFGROUP-IND OF DCLTBCTF002
              IF RETURNCODE OF P-LCTFM002 = N'00'
                 PERFORM R022-CHECK-GROUP
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
              PERFORM R021-CHECK-DATES
           END-IF
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           EXEC SQL
              SELECT EVENTID
                INTO :DCLTBCTF002.EVENTID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF002
                     (EVENTNAME,
                      DESCRIPTION,
                      EVENTSTATUS,
                      PLAYMODE,
                      MAXTEAMSIZE,
                      STARTTS,
                      ENDTS,
                      FREEZETS,
                      REGCODE,
                      REGFROMTS,
                      REGTOTS,
                      MAXPLAYERS,
                      PLAYERCOUNT,
                      RACFGROUP,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF002.EVENTNAME,
                     :DCLTBCTF002.DESCRIPTION
                        :DCLTBCTF002.DESCRIPTION-IND,
                     :C-D,
                     :DCLTBCTF002.PLAYMODE,
                     :DCLTBCTF002.MAXTEAMSIZE,
                     :DCLTBCTF002.STARTTS,
                     :DCLTBCTF002.ENDTS,
                     :DCLTBCTF002.FREEZETS :DCLTBCTF002.FREEZETS-IND,
                     :DCLTBCTF002.REGCODE,
                     :DCLTBCTF002.REGFROMTS,
                     :DCLTBCTF002.REGTOTS,
                     :DCLTBCTF002.MAXPLAYERS,
                     0,
                     :DCLTBCTF002.RACFGROUP :DCLTBCTF002.RACFGROUP-IND,
                     :W-USERID,
                     CURRENT TIMESTAMP,
                     :W-USERID,
                     CURRENT TIMESTAMP)
                     )
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN -803
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'11' TO REASONCODE OF P-LCTFM002
              MOVE N'This row exists already' TO
                   INFOMESSAGE OF P-LCTFM002
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'12' TO REASONCODE OF P-LCTFM002
              STRING N'INSERT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM002
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM002 = N'00'
              MOVE EVENTID OF DCLTBCTF002 TO EVENTID OF P-LCTFM002
           END-IF
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R120-READ: Read the row                                       *
      *===============================================================*
       R120-READ SECTION.
           MOVE EVENTID OF P-LCTFM002 TO EVENTID OF DCLTBCTF002

           EXEC SQL
              SELECT EVENTID,
                     EVENTNAME,
                     DESCRIPTION,
                     EVENTSTATUS,
                     PLAYMODE,
                     MAXTEAMSIZE,
                     STARTTS,
                     ENDTS,
                     FREEZETS,
                     REGCODE,
                     REGFROMTS,
                     REGTOTS,
                     MAXPLAYERS,
                     PLAYERCOUNT,
                     RACFGROUP,
                     CASE WHEN EVENTSTATUS <> :C-P THEN ' '
                          WHEN CURRENT TIMESTAMP < STARTTS THEN 'U'
                          WHEN CURRENT TIMESTAMP >= ENDTS THEN 'E'
                          WHEN FREEZETS <= CURRENT TIMESTAMP THEN 'F'
                          ELSE 'R' END,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF002.EVENTID,
                     :DCLTBCTF002.EVENTNAME,
                     :DCLTBCTF002.DESCRIPTION
                        :DCLTBCTF002.DESCRIPTION-IND,
                     :DCLTBCTF002.EVENTSTATUS,
                     :DCLTBCTF002.PLAYMODE,
                     :DCLTBCTF002.MAXTEAMSIZE,
                     :DCLTBCTF002.STARTTS,
                     :DCLTBCTF002.ENDTS,
                     :DCLTBCTF002.FREEZETS :DCLTBCTF002.FREEZETS-IND,
                     :DCLTBCTF002.REGCODE,
                     :DCLTBCTF002.REGFROMTS,
                     :DCLTBCTF002.REGTOTS,
                     :DCLTBCTF002.MAXPLAYERS,
                     :DCLTBCTF002.PLAYERCOUNT,
                     :DCLTBCTF002.RACFGROUP :DCLTBCTF002.RACFGROUP-IND,
                     :W-PHASE,
                     :DCLTBCTF002.CREATEDBY,
                     :DCLTBCTF002.CREATEDDATE,
                     :DCLTBCTF002.UPDATEDBY,
                     :DCLTBCTF002.UPDATEDDATE
                FROM TBCTF002
               WHERE EVENTID = :DCLTBCTF002.EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM002
              MOVE N'01' TO REASONCODE OF P-LCTFM002
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM002
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'21' TO REASONCODE OF P-LCTFM002
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM002
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R130-UPDATE: Update the row                                   *
      *===============================================================*
       R130-UPDATE SECTION.
           MOVE EVENTID OF P-LCTFM002 TO EVENTID OF DCLTBCTF002

           PERFORM R131-CHECK-STATE

           IF RETURNCODE OF P-LCTFM002 = N'00'
      *       The checks of R131 again, so a registration at the same
      *       moment cannot slip past them
              EXEC SQL
                 UPDATE TBCTF002
                    SET EVENTNAME   = :DCLTBCTF002.EVENTNAME,
                        DESCRIPTION = :DCLTBCTF002.DESCRIPTION
                                      :DCLTBCTF002.DESCRIPTION-IND,
                        EVENTSTATUS = :DCLTBCTF002.EVENTSTATUS,
                        PLAYMODE    = :DCLTBCTF002.PLAYMODE,
                        MAXTEAMSIZE = :DCLTBCTF002.MAXTEAMSIZE,
                        STARTTS     = :DCLTBCTF002.STARTTS,
                        ENDTS       = :DCLTBCTF002.ENDTS,
                        FREEZETS    = :DCLTBCTF002.FREEZETS
                                      :DCLTBCTF002.FREEZETS-IND,
                        REGCODE     = :DCLTBCTF002.REGCODE,
                        REGFROMTS   = :DCLTBCTF002.REGFROMTS,
                        REGTOTS     = :DCLTBCTF002.REGTOTS,
                        MAXPLAYERS  = :DCLTBCTF002.MAXPLAYERS,
                        RACFGROUP   = :DCLTBCTF002.RACFGROUP
                                      :DCLTBCTF002.RACFGROUP-IND,
                        UPDATEDBY   = :W-USERID,
                        UPDATEDDATE = CURRENT TIMESTAMP
                  WHERE EVENTID = :DCLTBCTF002.EVENTID
                    AND EVENTSTATUS <> :C-C
                    AND PLAYERCOUNT <= :DCLTBCTF002.MAXPLAYERS
                    AND :DCLTBCTF002.MAXTEAMSIZE >=
                       (SELECT COALESCE(MAX(T.MEMBERCOUNT), 0)
                          FROM TBCTF005 T
                         WHERE T.EVENTID = :DCLTBCTF002.EVENTID)
                    AND (:DCLTBCTF002.EVENTSTATUS = :C-D
                     OR  EVENTSTATUS = :C-P
                     OR  EXISTS
                        (SELECT 1
                           FROM TBCTF011 EC
                          WHERE EC.EVENTID = :DCLTBCTF002.EVENTID
                            AND EC.ISVISIBLE = :C-Y))
                    AND (NOT EXISTS
                        (SELECT 1
                           FROM TBCTF006 PA
                          WHERE PA.EVENTID = :DCLTBCTF002.EVENTID)
                     OR (EVENTSTATUS = :C-P
                     AND :DCLTBCTF002.EVENTSTATUS = :C-P
                     AND PLAYMODE = :DCLTBCTF002.PLAYMODE
                     AND COALESCE(RACFGROUP, :W-BLANK8)
                         = :W-NEW-GROUP))
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 MOVE N'The event changed meanwhile: read it again' TO
                      INFOMESSAGE OF P-LCTFM002
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'32' TO REASONCODE OF P-LCTFM002
                 STRING N'UPDATE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R130-UPDATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row                                   *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE EVENTID OF P-LCTFM002 TO EVENTID OF DCLTBCTF002

           EXEC SQL
              SELECT EVENTSTATUS
                INTO :W-OLD-STATUS
                FROM TBCTF002
               WHERE EVENTID = :DCLTBCTF002.EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              IF W-OLD-STATUS NOT = C-D
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 MOVE N'Only a DRAFT event can be deleted' TO
                      INFOMESSAGE OF P-LCTFM002
              END-IF
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'41' TO REASONCODE OF P-LCTFM002
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM002
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'21' TO REASONCODE OF P-LCTFM002
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM002
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM002 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF012
                  WHERE EVENTID = :DCLTBCTF002.EVENTID
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'42' TO REASONCODE OF P-LCTFM002
                 STRING N'DELETE prerequisites gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF011
                  WHERE EVENTID = :DCLTBCTF002.EVENTID
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'42' TO REASONCODE OF P-LCTFM002
                 STRING N'DELETE challenges gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF017
                  WHERE EVENTID = :DCLTBCTF002.EVENTID
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'42' TO REASONCODE OF P-LCTFM002
                 STRING N'DELETE announcements gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF002
                  WHERE EVENTID = :DCLTBCTF002.EVENTID
                    AND EVENTSTATUS = :C-D
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'41' TO REASONCODE OF P-LCTFM002
                 MOVE N'The event changed meanwhile: read it again' TO
                      INFOMESSAGE OF P-LCTFM002
              WHEN -532
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 MOVE N'Other rows still refer to this one' TO
                      INFOMESSAGE OF P-LCTFM002
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'42' TO REASONCODE OF P-LCTFM002
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R140-DELETE-END.
           EXIT.

      *===============================================================*
      * R021-CHECK-DATES: Dates present, valid and in order           *
      *===============================================================*
       R021-CHECK-DATES SECTION.
           INSPECT STARTTS OF P-LCTFM002
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION DISPLAY-OF(STARTTS OF P-LCTFM002)
             TO STARTTS OF DCLTBCTF002
           INSPECT ENDTS OF P-LCTFM002
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION DISPLAY-OF(ENDTS OF P-LCTFM002)
             TO ENDTS OF DCLTBCTF002
           INSPECT FREEZETS OF P-LCTFM002
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION DISPLAY-OF(FREEZETS OF P-LCTFM002)
             TO FREEZETS OF DCLTBCTF002
           INSPECT REGFROMTS OF P-LCTFM002
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION DISPLAY-OF(REGFROMTS OF P-LCTFM002)
             TO REGFROMTS OF DCLTBCTF002
           INSPECT REGTOTS OF P-LCTFM002
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION DISPLAY-OF(REGTOTS OF P-LCTFM002)
             TO REGTOTS OF DCLTBCTF002

           IF STARTTS OF P-LCTFM002 = SPACES
           OR ENDTS OF P-LCTFM002 = SPACES
           OR REGFROMTS OF P-LCTFM002 = SPACES
           OR REGTOTS OF P-LCTFM002 = SPACES
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'05' TO REASONCODE OF P-LCTFM002
              STRING N'startTS, endTS, regFromTS and regToTS are '
                     N'required'
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM002
           END-IF

      *    Without a freeze, the start stands in for it, so that
      *    TIMESTAMP() below has something valid to work on
           IF FREEZETS OF P-LCTFM002 = SPACES
              MOVE -1 TO FREEZETS-IND OF DCLTBCTF002
              MOVE STARTTS OF DCLTBCTF002 TO FREEZETS OF DCLTBCTF002
           ELSE
              MOVE 0 TO FREEZETS-IND OF DCLTBCTF002
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
              EXEC SQL
                 SELECT CASE WHEN TIMESTAMP(:DCLTBCTF002.STARTTS)
                                < TIMESTAMP(:DCLTBCTF002.ENDTS)
                             THEN 'Y' ELSE 'N' END,
                        CASE WHEN :DCLTBCTF002.FREEZETS-IND < 0 THEN 'Y'
                             WHEN TIMESTAMP(:DCLTBCTF002.FREEZETS)
                                > TIMESTAMP(:DCLTBCTF002.STARTTS)
                              AND TIMESTAMP(:DCLTBCTF002.FREEZETS)
                                < TIMESTAMP(:DCLTBCTF002.ENDTS)
                             THEN 'Y' ELSE 'N' END,
                        CASE WHEN TIMESTAMP(:DCLTBCTF002.REGFROMTS)
                                < TIMESTAMP(:DCLTBCTF002.REGTOTS)
                             THEN 'Y' ELSE 'N' END
                   INTO :W-OK1,
                        :W-OK2,
                        :W-OK3
                   FROM SYSIBM.SYSDUMMY1
              END-EXEC

              EVALUATE TRUE
              WHEN SQLCODE = -180 OR SQLCODE = -181
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'05' TO REASONCODE OF P-LCTFM002
                 MOVE N'A date is not a valid timestamp' TO
                      INFOMESSAGE OF P-LCTFM002
              WHEN SQLCODE NOT = 0
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'21' TO REASONCODE OF P-LCTFM002
                 STRING N'SELECT dates gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
                 PERFORM R900-DSNTIAR
              WHEN W-OK1 NOT = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'05' TO REASONCODE OF P-LCTFM002
                 MOVE N'startTS must be before endTS' TO
                      INFOMESSAGE OF P-LCTFM002
              WHEN W-OK2 NOT = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'05' TO REASONCODE OF P-LCTFM002
                 STRING N'freezeTS must be after startTS and before '
                        N'endTS'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
              WHEN W-OK3 NOT = 'Y'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'05' TO REASONCODE OF P-LCTFM002
                 MOVE N'regFromTS must be before regToTS' TO
                      INFOMESSAGE OF P-LCTFM002
              END-EVALUATE
           END-IF

           MOVE EVENTNAME OF P-LCTFM002 TO EVENTNAME OF DCLTBCTF002
           MOVE DESCRIPTION OF P-LCTFM002 TO DESCRIPTION OF DCLTBCTF002
           IF DESCRIPTION-LEN OF P-LCTFM002 = 0
              MOVE -1 TO DESCRIPTION-IND OF DCLTBCTF002
           ELSE
              MOVE 0 TO DESCRIPTION-IND OF DCLTBCTF002
           END-IF
           MOVE EVENTSTATUS OF P-LCTFM002 TO EVENTSTATUS OF DCLTBCTF002
           MOVE PLAYMODE OF P-LCTFM002 TO PLAYMODE OF DCLTBCTF002
           MOVE MAXTEAMSIZE OF P-LCTFM002 TO MAXTEAMSIZE OF DCLTBCTF002
           MOVE REGCODE OF P-LCTFM002 TO REGCODE OF DCLTBCTF002
           MOVE MAXPLAYERS OF P-LCTFM002 TO MAXPLAYERS OF DCLTBCTF002
           .
       R021-CHECK-DATES-END.
           EXIT.

      *===============================================================*
      * R022-CHECK-GROUP: The RACF group is in RACFGRP                *
      *===============================================================*
       R022-CHECK-GROUP SECTION.
           EXEC SQL
              SELECT 1
                INTO :W-ONE
                FROM TBCTF001
               WHERE TABLEID = :C-RACFGRP
                 AND TABKEY  = :DCLTBCTF002.RACFGROUP
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'06' TO REASONCODE OF P-LCTFM002
              MOVE N'racfGroup is not in the RACFGRP list' TO
                   INFOMESSAGE OF P-LCTFM002
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'21' TO REASONCODE OF P-LCTFM002
              STRING N'SELECT RACFGRP gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM002
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R022-CHECK-GROUP-END.
           EXIT.

      *===============================================================*
      * R121-COPY-ROW: Copy the row to the IO area                    *
      *===============================================================*
       R121-COPY-ROW SECTION.
           MOVE EVENTID OF DCLTBCTF002 TO EVENTID OF P-LCTFM002
           MOVE EVENTNAME OF DCLTBCTF002 TO EVENTNAME OF P-LCTFM002
           IF DESCRIPTION-IND OF DCLTBCTF002 < 0
              MOVE 0 TO DESCRIPTION-LEN OF P-LCTFM002
           ELSE
              MOVE DESCRIPTION OF DCLTBCTF002 TO
                   DESCRIPTION OF P-LCTFM002
           END-IF
           MOVE EVENTSTATUS OF DCLTBCTF002 TO EVENTSTATUS OF P-LCTFM002
           MOVE PLAYMODE OF DCLTBCTF002 TO PLAYMODE OF P-LCTFM002
           MOVE MAXTEAMSIZE OF DCLTBCTF002 TO MAXTEAMSIZE OF P-LCTFM002
           MOVE STARTTS OF DCLTBCTF002 TO STARTTS OF P-LCTFM002
           MOVE ENDTS OF DCLTBCTF002 TO ENDTS OF P-LCTFM002
           IF FREEZETS-IND OF DCLTBCTF002 < 0
              MOVE SPACES TO FREEZETS OF P-LCTFM002
           ELSE
              MOVE FREEZETS OF DCLTBCTF002 TO FREEZETS OF P-LCTFM002
           END-IF
           MOVE REGCODE OF DCLTBCTF002 TO REGCODE OF P-LCTFM002
           MOVE REGFROMTS OF DCLTBCTF002 TO REGFROMTS OF P-LCTFM002
           MOVE REGTOTS OF DCLTBCTF002 TO REGTOTS OF P-LCTFM002
           MOVE MAXPLAYERS OF DCLTBCTF002 TO MAXPLAYERS OF P-LCTFM002
           MOVE PLAYERCOUNT OF DCLTBCTF002 TO PLAYERCOUNT OF P-LCTFM002
           IF RACFGROUP-IND OF DCLTBCTF002 < 0
              MOVE SPACES TO RACFGROUP OF P-LCTFM002
           ELSE
              MOVE RACFGROUP OF DCLTBCTF002 TO RACFGROUP OF P-LCTFM002
           END-IF
           MOVE FUNCTION NATIONAL-OF(W-PHASE) TO PHASE OF P-LCTFM002
           MOVE CREATEDBY OF DCLTBCTF002 TO CREATEDBY OF P-LCTFM002
           MOVE CREATEDDATE OF DCLTBCTF002 TO CREATEDDATE OF P-LCTFM002
           MOVE UPDATEDBY OF DCLTBCTF002 TO UPDATEDBY OF P-LCTFM002
           MOVE UPDATEDDATE OF DCLTBCTF002 TO UPDATEDDATE OF P-LCTFM002
           .
       R121-COPY-ROW-END.
           EXIT.

      *===============================================================*
      * R131-CHECK-STATE: Status changes and locks (U)                *
      *===============================================================*
       R131-CHECK-STATE SECTION.
           EXEC SQL
              SELECT E.EVENTSTATUS,
                     E.PLAYMODE,
                     E.RACFGROUP,
                     E.PLAYERCOUNT,
                    (SELECT COUNT(*)
                       FROM TBCTF006 PA
                      WHERE PA.EVENTID = E.EVENTID),
                    (SELECT COALESCE(MAX(T.MEMBERCOUNT), 0)
                       FROM TBCTF005 T
                      WHERE T.EVENTID = E.EVENTID),
                    (SELECT COUNT(*)
                       FROM TBCTF011 EC
                      WHERE EC.EVENTID = E.EVENTID
                        AND EC.ISVISIBLE = :C-Y)
                INTO :W-OLD-STATUS,
                     :W-OLD-PLAYMODE,
                     :W-OLD-GROUP :W-OLD-GROUP-IND,
                     :W-OLD-COUNT,
                     :W-PLACES,
                     :W-MAX-MEMBERS,
                     :W-VISIBLE
                FROM TBCTF002 E
               WHERE E.EVENTID = :DCLTBCTF002.EVENTID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'31' TO REASONCODE OF P-LCTFM002
              MOVE N'Event not found' TO
                   INFOMESSAGE OF P-LCTFM002
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM002
              MOVE N'21' TO REASONCODE OF P-LCTFM002
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM002
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF W-OLD-GROUP-IND < 0
              MOVE SPACES TO W-OLD-GROUP
           END-IF

           IF RETURNCODE OF P-LCTFM002 = N'00'
              EVALUATE TRUE
              WHEN W-OLD-STATUS = C-C
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 MOVE N'A closed event cannot be changed' TO
                      INFOMESSAGE OF P-LCTFM002
              WHEN EVENTSTATUS OF DCLTBCTF002 = C-P
               AND W-OLD-STATUS = C-D
               AND W-VISIBLE = 0
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 STRING N'Publishing needs at least one visible '
                        N'challenge'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
              WHEN W-PLACES > 0
               AND EVENTSTATUS OF DCLTBCTF002 = C-D
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 STRING N'Players have joined: the event stays '
                        N'published'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
              WHEN W-PLACES > 0
               AND (PLAYMODE OF DCLTBCTF002 NOT = W-OLD-PLAYMODE
                OR  W-NEW-GROUP NOT = W-OLD-GROUP)
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 STRING N'Players have joined: play mode and RACF '
                        N'group are locked'
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM002
              WHEN MAXTEAMSIZE OF DCLTBCTF002 < W-MAX-MEMBERS
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 MOVE N'maxTeamSize is below the size of a team' TO
                      INFOMESSAGE OF P-LCTFM002
              WHEN MAXPLAYERS OF DCLTBCTF002 < W-OLD-COUNT
                 MOVE N'08' TO RETURNCODE OF P-LCTFM002
                 MOVE N'53' TO REASONCODE OF P-LCTFM002
                 MOVE N'maxPlayers is below the places taken' TO
                      INFOMESSAGE OF P-LCTFM002
              END-EVALUATE
           END-IF
           .
       R131-CHECK-STATE-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM002==.

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

       END PROGRAM CTFM002.
