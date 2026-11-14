       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM303.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /registrations: creates the player, a place in the event, *
      * for an individual event a team of one, and the job row. The   *
      * caller commits and then starts the task that submits the job. *
      * Nothing is committed here; on any error the caller rolls back. *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 02 = Error: display name required                          *
      * 08 11 = Error: display name taken                             *
      * 08 12 = Error: SQL error in INSERT                            *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 51 = Error: wrong code or registration closed              *
      * 08 52 = Error: event full, or no userids left                 *
      * 08 90 = Error: CTFA990, CTFA991 or settings failed            *
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

           EXEC SQL INCLUDE TBCTF003 END-EXEC.

           EXEC SQL INCLUDE TBCTF004 END-EXEC.

           EXEC SQL INCLUDE TBCTF005 END-EXEC.

           EXEC SQL INCLUDE TBCTF006 END-EXEC.

       01 WORK.
          05 W-PGMNAME    PIC X(8).
          05 W-SQLCODE    PIC -99999.
          05 W-USERID-D   PIC 9(4).
          05 W-SEQ        PIC S9(9) COMP-5.
          05 W-HOURS      PIC S9(4) COMP-5.
          05 W-UPPER      PIC N(30).

       01 W-CLAIMHASH     USAGE SQL TYPE IS BINARY(32).

       01 W-LCTFA990.
           COPY LCTFA990.
       01 W-LCTFM910.
           COPY LCTFM910.

           COPY CTFSECW.

           COPY CTFREGW.

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
       01 P-LCTFM303.
           COPY LCTFM303.
       01 P-LCTFC910.
           COPY LCTFC910.

       PROCEDURE DIVISION USING P-LCTFM303 P-LCTFC910.
       MAIN SECTION.
           PERFORM R001-INIT

           IF RETURNCODE OF P-LCTFM303 = N'00'
              PERFORM R110-CHECK-EVENT
           END-IF

           IF RETURNCODE OF P-LCTFM303 = N'00'
              PERFORM R120-TAKE-PLACE
           END-IF

           IF RETURNCODE OF P-LCTFM303 = N'00'
              PERFORM R130-SECRETS
           END-IF

           IF RETURNCODE OF P-LCTFM303 = N'00'
              PERFORM R140-INSERT-PLAYER
           END-IF

           IF RETURNCODE OF P-LCTFM303 = N'00'
           AND PLAYMODE OF DCLTBCTF002 = C-I
              PERFORM R150-INSERT-TEAM
           END-IF

           IF RETURNCODE OF P-LCTFM303 = N'00'
              PERFORM R160-INSERT-PLACE
           END-IF

           IF RETURNCODE OF P-LCTFM303 = N'00'
              PERFORM R170-INSERT-JOB
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Initialisations, settings and input checks         *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM303
           MOVE N'00' TO REASONCODE OF P-LCTFM303
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM303
           MOVE 0 TO REGISTRATIONID OF P-LCTFM303
           MOVE SPACES TO CLAIMTOKEN OF P-LCTFM303
           INITIALIZE P-LCTFC910

      *    For CTFREGP: a pending place and a CREATE job, which is
      *    checked with the claim token, so without a job token
           MOVE C-P TO W-NEW-PARTSTATUS
           MOVE C-C TO W-NEW-ACTION
           MOVE -1 TO W-JOBHASH-IND

           IF DISPLAYNAME-LEN OF P-LCTFM303 <= 0
           OR DISPLAYNAME-LEN OF P-LCTFM303 > 30
           OR DISPLAYNAME-TEXT OF P-LCTFM303
                 (1:DISPLAYNAME-LEN OF P-LCTFM303) = SPACES
              MOVE N'08' TO RETURNCODE OF P-LCTFM303
              MOVE N'02' TO REASONCODE OF P-LCTFM303
              MOVE N'Display name is required' TO
                   INFOMESSAGE OF P-LCTFM303
           END-IF

           IF RETURNCODE OF P-LCTFM303 = N'00'
              MOVE N'R' TO OPCODE OF W-LCTFM910
              MOVE 'CTFM910' TO W-PGMNAME
              CALL W-PGMNAME USING W-LCTFM910 P-LCTFC910
              IF RETURNCODE OF W-LCTFM910 NOT = N'00'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM303
                 MOVE N'90' TO REASONCODE OF P-LCTFM303
                 MOVE INFOMESSAGE OF W-LCTFM910 TO
                      INFOMESSAGE OF P-LCTFM303
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM303 = N'00'
              MOVE 'CTFA990' TO W-PGMNAME
              CALL W-PGMNAME USING W-LCTFA990
              IF RETURNCODE OF W-LCTFA990 NOT = N'00'
                 MOVE N'08' TO RETURNCODE OF P-LCTFM303
                 MOVE N'90' TO REASONCODE OF P-LCTFM303
                 MOVE INFOMESSAGE OF W-LCTFA990 TO
                      INFOMESSAGE OF P-LCTFM303
              END-IF
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R130-SECRETS: Claim token, its hash and the passphrase        *
      *===============================================================*
       R130-SECRETS SECTION.
      *    The join code comes from its own random value
           PERFORM R800-NEW-TOKEN
           MOVE W-TOKEN(1:12) TO W-JOINCODE

           IF A991-OK
              PERFORM R800-NEW-TOKEN
           END-IF

           IF A991-OK
              PERFORM R810-DERIVE
           END-IF

           IF A991-OK
              MOVE W-TOKENHASH TO W-CLAIMHASH
              MOVE FUNCTION NATIONAL-OF(W-TOKEN) TO
                   CLAIMTOKEN OF P-LCTFM303
              MOVE W-TOKEN TO JOBTOKEN OF P-LCTFC910
              COMPUTE W-HOURS =
                 FUNCTION NUMVAL(S-CLAIMHRS OF P-LCTFC910)
           ELSE
              MOVE N'08' TO RETURNCODE OF P-LCTFM303
              MOVE N'90' TO REASONCODE OF P-LCTFM303
              MOVE N'CTFA991 failed' TO
                   INFOMESSAGE OF P-LCTFM303
           END-IF
           .
       R130-SECRETS-END.
           EXIT.

      *===============================================================*
      * R140-INSERT-PLAYER: Userid from the sequence, INSERT player   *
      *===============================================================*
       R140-INSERT-PLAYER SECTION.
           EXEC SQL
              SELECT NEXT VALUE FOR SQCTF003
                INTO :W-SEQ
                FROM SYSIBM.SYSDUMMY1
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE W-SEQ TO W-USERID-D
              STRING 'CTF' W-USERID-D DELIMITED BY SIZE
                INTO RACFUSERID OF P-LCTFC910
           WHEN -359
              MOVE N'08' TO RETURNCODE OF P-LCTFM303
              MOVE N'52' TO REASONCODE OF P-LCTFM303
              MOVE N'No more player userids available' TO
                   INFOMESSAGE OF P-LCTFM303
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM303
              MOVE N'21' TO REASONCODE OF P-LCTFM303
              STRING N'NEXT VALUE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM303
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM303 = N'00'
              MOVE FUNCTION NATIONAL-OF(RACFUSERID OF P-LCTFC910) TO
                   RACFUSERID OF DCLTBCTF003
              MOVE DISPLAYNAME OF P-LCTFM303 TO
                   DISPLAYNAME OF DCLTBCTF003
              MOVE DISPLAYNAME OF P-LCTFM303 TO
                   DISPLAYKEY OF DCLTBCTF003
              MOVE SPACES TO DISPLAYKEY-TEXT OF DCLTBCTF003
              MOVE FUNCTION UPPER-CASE(
                 DISPLAYNAME-TEXT OF P-LCTFM303
                    (1:DISPLAYNAME-LEN OF P-LCTFM303)) TO
                 DISPLAYKEY-TEXT OF DCLTBCTF003

              EXEC SQL
                 SELECT PLAYERID
                   INTO :DCLTBCTF003.PLAYERID
                   FROM FINAL TABLE
                      (
                 INSERT
                   INTO TBCTF003
                        (RACFUSERID,
                         DISPLAYNAME,
                         DISPLAYKEY,
                         PLAYERSTATUS,
                         CLAIMHASH,
                         CLAIMEXPIRES,
                         CREATEDBY,
                         CREATEDDATE,
                         UPDATEDBY,
                         UPDATEDDATE)
                 VALUES(:DCLTBCTF003.RACFUSERID,
                        :DCLTBCTF003.DISPLAYNAME,
                        :DCLTBCTF003.DISPLAYKEY,
                        :C-P,
                        :W-CLAIMHASH,
                        CURRENT TIMESTAMP + :W-HOURS HOURS,
                        :W-LCTFA990.USERID,
                        CURRENT TIMESTAMP,
                        :W-LCTFA990.USERID,
                        CURRENT TIMESTAMP)
                        )
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 MOVE PLAYERID OF DCLTBCTF003 TO
                      REGISTRATIONID OF P-LCTFM303
                 MOVE PLAYERID OF DCLTBCTF003 TO
                      PLAYERID OF P-LCTFC910
              WHEN -803
                 MOVE N'08' TO RETURNCODE OF P-LCTFM303
                 MOVE N'11' TO REASONCODE OF P-LCTFM303
                 MOVE N'This display name is already taken' TO
                      INFOMESSAGE OF P-LCTFM303
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM303
                 MOVE N'12' TO REASONCODE OF P-LCTFM303
                 STRING N'INSERT player gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM303
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R140-INSERT-PLAYER-END.
           EXIT.

           COPY CTFSECP.

           COPY CTFREGP REPLACING ==:IO:== BY ==P-LCTFM303==.

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

       END PROGRAM CTFM303.
