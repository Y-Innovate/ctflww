       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM305.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST /activations/{registrationID}, in two calls around the   *
      * CHANGE PHRASE in CTFC305:                                     *
      * OPCODE V: check claim token; give userid and one-time phrase  *
      * OPCODE A: player becomes ACTIVE and the claim hash is cleared *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 08 01 = Error: OPCODE invalid                                 *
      * 08 02 = Error: claim token or passphrase required             *
      * 08 21 = Error: SQL error in SELECT                            *
      * 08 32 = Error: SQL error in UPDATE                            *
      * 08 53 = Error: registration is not ready                      *
      * 08 57 = Error: wrong or expired claim token                   *
      * 08 90 = Error: CTFA991 failed                                 *
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
          05 W-PGMNAME    PIC X(8).
          05 W-SQLCODE    PIC -99999.
          05 W-EXPIRED    PIC X.

       01 W-CLAIMHASH     USAGE SQL TYPE IS BINARY(32).
       01 W-LCTFA990.
           COPY LCTFA990.

           COPY CTFSECW.

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
       01 P-LCTFM305.
           COPY LCTFM305.
       01 P-ONETIMEPHRASE PIC X(32).

       PROCEDURE DIVISION USING P-LCTFM305 P-ONETIMEPHRASE.
       MAIN SECTION.
           PERFORM R001-INIT

           IF RETURNCODE OF P-LCTFM305 = N'00'
              EVALUATE OPCODE OF P-LCTFM305
              WHEN N'V'
                 PERFORM R110-VERIFY
              WHEN N'A'
                 PERFORM R130-ACTIVATE
              WHEN OTHER
                 MOVE N'08' TO RETURNCODE OF P-LCTFM305
                 MOVE N'01' TO REASONCODE OF P-LCTFM305
                 MOVE N'OPCODE is invalid' TO
                      INFOMESSAGE OF P-LCTFM305
              END-EVALUATE
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM305
           MOVE N'00' TO REASONCODE OF P-LCTFM305
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM305

           MOVE SPACES TO P-ONETIMEPHRASE
           MOVE REGISTRATIONID OF P-LCTFM305 TO PLAYERID OF DCLTBCTF003
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R110-VERIFY: Check the claim token                            *
      *===============================================================*
       R110-VERIFY SECTION.
           IF CLAIMTOKEN OF P-LCTFM305 = SPACES
           OR CLAIMTOKEN OF P-LCTFM305 = LOW-VALUES
           OR PASSPHRASE-LEN OF P-LCTFM305 <= 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM305
              MOVE N'02' TO REASONCODE OF P-LCTFM305
              MOVE N'Claim token and passphrase are required' TO
                   INFOMESSAGE OF P-LCTFM305
           ELSE
              EXEC SQL
                 SELECT RACFUSERID,
                        PLAYERSTATUS,
                        CLAIMHASH,
                        CASE WHEN CLAIMEXPIRES < CURRENT TIMESTAMP
                             THEN 'Y' ELSE 'N' END
                   INTO :DCLTBCTF003.RACFUSERID,
                        :DCLTBCTF003.PLAYERSTATUS,
                        :W-CLAIMHASH
                          :DCLTBCTF003.CLAIMHASH-IND,
                        :W-EXPIRED
                   FROM TBCTF003
                  WHERE PLAYERID = :DCLTBCTF003.PLAYERID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 PERFORM R120-CHECK-HASH
              WHEN 100
      *          Same answer as a wrong token: reveals nothing
                 MOVE N'08' TO RETURNCODE OF P-LCTFM305
                 MOVE N'57' TO REASONCODE OF P-LCTFM305
                 MOVE N'Wrong or expired claim token' TO
                      INFOMESSAGE OF P-LCTFM305
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM305
                 MOVE N'21' TO REASONCODE OF P-LCTFM305
                 STRING N'SELECT gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM305
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R110-VERIFY-END.
           EXIT.

      *===============================================================*
      * R120-CHECK-HASH: Compare the hash, derive the phrase          *
      *===============================================================*
       R120-CHECK-HASH SECTION.
           EVALUATE TRUE
           WHEN CLAIMHASH-IND OF DCLTBCTF003 < 0
           WHEN W-EXPIRED = 'Y'
              MOVE N'08' TO RETURNCODE OF P-LCTFM305
              MOVE N'57' TO REASONCODE OF P-LCTFM305
              MOVE N'Wrong or expired claim token' TO
                   INFOMESSAGE OF P-LCTFM305
           WHEN PLAYERSTATUS OF DCLTBCTF003 NOT = C-R
              MOVE N'08' TO RETURNCODE OF P-LCTFM305
              MOVE N'53' TO REASONCODE OF P-LCTFM305
              MOVE N'This registration is not ready' TO
                   INFOMESSAGE OF P-LCTFM305
           WHEN OTHER
              MOVE FUNCTION DISPLAY-OF(CLAIMTOKEN OF P-LCTFM305)
                TO W-TOKEN
              PERFORM R810-DERIVE
              EVALUATE TRUE
              WHEN NOT A991-OK
                 MOVE N'08' TO RETURNCODE OF P-LCTFM305
                 MOVE N'90' TO REASONCODE OF P-LCTFM305
                 MOVE N'CTFA991 failed' TO
                      INFOMESSAGE OF P-LCTFM305
              WHEN W-TOKENHASH NOT = W-CLAIMHASH
                 MOVE N'08' TO RETURNCODE OF P-LCTFM305
                 MOVE N'57' TO REASONCODE OF P-LCTFM305
                 MOVE N'Wrong or expired claim token' TO
                      INFOMESSAGE OF P-LCTFM305
              WHEN OTHER
                 MOVE W-PHRASE TO P-ONETIMEPHRASE
                 MOVE RACFUSERID OF DCLTBCTF003 TO
                      RACFUSERID OF P-LCTFM305
              END-EVALUATE
           END-EVALUATE
           .
       R120-CHECK-HASH-END.
           EXIT.

      *===============================================================*
      * R130-ACTIVATE: Player becomes ACTIVE, token is used up        *
      *===============================================================*
       R130-ACTIVATE SECTION.
           MOVE 'CTFA990' TO W-PGMNAME
           CALL W-PGMNAME USING W-LCTFA990

           EXEC SQL
              UPDATE TBCTF003
                 SET PLAYERSTATUS = :C-A,
                     CLAIMHASH    = NULL,
                     CLAIMEXPIRES = NULL,
                     UPDATEDBY    = :W-LCTFA990.USERID,
                     UPDATEDDATE  = CURRENT TIMESTAMP
               WHERE PLAYERID = :DCLTBCTF003.PLAYERID
                 AND PLAYERSTATUS = :C-R
           END-EXEC

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM305
              MOVE N'32' TO REASONCODE OF P-LCTFM305
              STRING N'UPDATE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM305
              PERFORM R900-DSNTIAR
           END-IF
           .
       R130-ACTIVATE-END.
           EXIT.

           COPY CTFSECP.

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

       END PROGRAM CTFM305.
