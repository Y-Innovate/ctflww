       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFM007.
      *===============================================================*
      * This program is a DB2 module of the CTF application.          *
      * POST, GET, PUT and DELETE /admin/challenges: create, read,    *
      * update or delete a library challenge, by OPCODE C, R, U or D. *
      * The category must be in CATEGORY; the type is S and there is  *
      * no verifier program in v1. A challenge in an event cannot be  *
      * deleted; otherwise its flags, hints and links go with it. The *
      * caller (the admin wrapper) has checked CTF.ADMIN, and commits *
      * or rolls back.                                                *
      * ------------------------------------------------------------- *
      * Output: RETURNCODE and REASONCODE                             *
      * 00 00 = Success                                               *
      * 04 01 = Challenge not found                                   *
      * 08 01 = Error: invalid OPCODE                                 *
      * 08 02 = Error: title or description missing or too long       *
      * 08 03 = Error: invalid type, or a verifier program            *
      * 08 06 = Error: category not in CATEGORY                       *
      * 08 12/21/32/42 = Error: SQL error                             *
      * 08 31/41 = Error: update or delete of a missing challenge     *
      * 08 53 = Error: the challenge is in an event                   *
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

           EXEC SQL INCLUDE TBCTF007 END-EXEC.

       01 WORK.
          05 W-SQLCODE    PIC -99999.
          05 W-ONE        PIC S9(9) COMP-5.
          05 W-COUNT      PIC S9(9) COMP-5.
          05 C-RACFGRP    PIC N(8) VALUE N'RACFGRP'.
          05 W-BLANK8     PIC N(8) VALUE SPACES.

           COPY CTFCTXW.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.

       LINKAGE SECTION.
       01 P-LCTFM007.
           COPY LCTFM007.

       PROCEDURE DIVISION USING P-LCTFM007.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R002-CHECKPARM

           PERFORM R090-GET-USERID

           IF RETURNCODE OF P-LCTFM007 = N'00'
              EVALUATE OPCODE OF P-LCTFM007
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
           IF RETURNCODE OF P-LCTFM007 = N'00'
           AND (OPCODE OF P-LCTFM007 = N'C'
             OR OPCODE OF P-LCTFM007 = N'U')
              PERFORM R120-READ
           END-IF
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           MOVE N'00' TO RETURNCODE OF P-LCTFM007
           MOVE N'00' TO REASONCODE OF P-LCTFM007
           MOVE SPACES TO INFOMESSAGE OF P-LCTFM007
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R002-CHECKPARM: Check the input                               *
      *===============================================================*
       R002-CHECKPARM SECTION.
           IF OPCODE OF P-LCTFM007 NOT = N'C'
             AND OPCODE OF P-LCTFM007 NOT = N'R'
             AND OPCODE OF P-LCTFM007 NOT = N'U'
             AND OPCODE OF P-LCTFM007 NOT = N'D'
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'01' TO REASONCODE OF P-LCTFM007
              MOVE N'Invalid OPCODE' TO
                   INFOMESSAGE OF P-LCTFM007
           END-IF

           IF RETURNCODE OF P-LCTFM007 = N'00'
           AND (OPCODE OF P-LCTFM007 = N'C'
             OR OPCODE OF P-LCTFM007 = N'U')
              PERFORM R020-CHECK-FIELDS
           END-IF
           .
       R002-CHECKPARM-END.
           EXIT.

      *===============================================================*
      * R020-CHECK-FIELDS: Check the fields of C and U                *
      *===============================================================*
       R020-CHECK-FIELDS SECTION.
           IF RETURNCODE OF P-LCTFM007 = N'00'
           AND (CHALLENGETITLE-LEN OF P-LCTFM007 < 1
             OR CHALLENGETITLE-LEN OF P-LCTFM007 > 100)
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'02' TO REASONCODE OF P-LCTFM007
              STRING N'challengeTitle is required, up to 100 '
                     N'characters'
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM007
           END-IF

           IF RETURNCODE OF P-LCTFM007 = N'00'
           AND (DESCRIPTION-LEN OF P-LCTFM007 < 1
             OR DESCRIPTION-LEN OF P-LCTFM007 > 3000)
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'02' TO REASONCODE OF P-LCTFM007
              STRING N'challengeDescription is required, up to 3000 '
                     N'characters'
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM007
           END-IF

           INSPECT CHALLENGETYPE OF P-LCTFM007
                   REPLACING ALL NX'0000' BY N' '
           IF CHALLENGETYPE OF P-LCTFM007 = SPACE
              MOVE N'S' TO CHALLENGETYPE OF P-LCTFM007
           END-IF
           IF RETURNCODE OF P-LCTFM007 = N'00'
           AND (CHALLENGETYPE OF P-LCTFM007 NOT = N'S')
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'03' TO REASONCODE OF P-LCTFM007
              MOVE N'challengeType must be S' TO
                   INFOMESSAGE OF P-LCTFM007
           END-IF

           INSPECT VERIFIERPGM OF P-LCTFM007
                   REPLACING ALL NX'0000' BY N' '
           IF RETURNCODE OF P-LCTFM007 = N'00'
           AND VERIFIERPGM OF P-LCTFM007 NOT = SPACES
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'03' TO REASONCODE OF P-LCTFM007
              MOVE N'There is no verifierPgm in v1' TO
                   INFOMESSAGE OF P-LCTFM007
           END-IF

           INSPECT CATEGORY OF P-LCTFM007
                   REPLACING ALL NX'0000' BY N' '
           MOVE FUNCTION UPPER-CASE(CATEGORY OF P-LCTFM007)
             TO CATEGORY OF P-LCTFM007
           MOVE CATEGORY OF P-LCTFM007 TO CATEGORY OF DCLTBCTF007
           IF RETURNCODE OF P-LCTFM007 = N'00'
              EXEC SQL
                 SELECT 1
                   INTO :W-ONE
                   FROM TBCTF001
                  WHERE TABLEID = :C-CATEGORY
                    AND TABKEY  = :DCLTBCTF007.CATEGORY
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM007
                 MOVE N'06' TO REASONCODE OF P-LCTFM007
                 MOVE N'category is not in the CATEGORY list' TO
                      INFOMESSAGE OF P-LCTFM007
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM007
                 MOVE N'21' TO REASONCODE OF P-LCTFM007
                 STRING N'SELECT CATEGORY gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM007
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF

           MOVE CHALLENGETITLE OF P-LCTFM007 TO
                CHALLENGETITLE OF DCLTBCTF007
           MOVE DESCRIPTION OF P-LCTFM007 TO DESCRIPTION OF DCLTBCTF007
           MOVE CHALLENGETYPE OF P-LCTFM007 TO
                CHALLENGETYPE OF DCLTBCTF007
           MOVE -1 TO VERIFIERPGM-IND OF DCLTBCTF007
           .
       R020-CHECK-FIELDS-END.
           EXIT.

      *===============================================================*
      * R110-CREATE: Insert the row                                   *
      *===============================================================*
       R110-CREATE SECTION.
           EXEC SQL
              SELECT CHALLENGEID
                INTO :DCLTBCTF007.CHALLENGEID
                FROM FINAL TABLE
                   (
              INSERT
                INTO TBCTF007
                     (CHALLENGETITLE,
                      CATEGORY,
                      DESCRIPTION,
                      CHALLENGETYPE,
                      VERIFIERPGM,
                      CREATEDBY,
                      CREATEDDATE,
                      UPDATEDBY,
                      UPDATEDDATE)
              VALUES(:DCLTBCTF007.CHALLENGETITLE,
                     :DCLTBCTF007.CATEGORY,
                     :DCLTBCTF007.DESCRIPTION,
                     :DCLTBCTF007.CHALLENGETYPE,
                     :DCLTBCTF007.VERIFIERPGM
                        :DCLTBCTF007.VERIFIERPGM-IND,
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
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'11' TO REASONCODE OF P-LCTFM007
              MOVE N'This row exists already' TO
                   INFOMESSAGE OF P-LCTFM007
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'12' TO REASONCODE OF P-LCTFM007
              STRING N'INSERT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM007
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM007 = N'00'
              MOVE CHALLENGEID OF DCLTBCTF007 TO
                   CHALLENGEID OF P-LCTFM007
           END-IF
           .
       R110-CREATE-END.
           EXIT.

      *===============================================================*
      * R120-READ: Read the row                                       *
      *===============================================================*
       R120-READ SECTION.
           MOVE CHALLENGEID OF P-LCTFM007 TO CHALLENGEID OF DCLTBCTF007

           EXEC SQL
              SELECT CHALLENGEID,
                     CHALLENGETITLE,
                     CATEGORY,
                     DESCRIPTION,
                     CHALLENGETYPE,
                     VERIFIERPGM,
                     CREATEDBY,
                     CREATEDDATE,
                     UPDATEDBY,
                     UPDATEDDATE
                INTO :DCLTBCTF007.CHALLENGEID,
                     :DCLTBCTF007.CHALLENGETITLE,
                     :DCLTBCTF007.CATEGORY,
                     :DCLTBCTF007.DESCRIPTION,
                     :DCLTBCTF007.CHALLENGETYPE,
                     :DCLTBCTF007.VERIFIERPGM
                        :DCLTBCTF007.VERIFIERPGM-IND,
                     :DCLTBCTF007.CREATEDBY,
                     :DCLTBCTF007.CREATEDDATE,
                     :DCLTBCTF007.UPDATEDBY,
                     :DCLTBCTF007.UPDATEDDATE
                FROM TBCTF007
               WHERE CHALLENGEID = :DCLTBCTF007.CHALLENGEID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              PERFORM R121-COPY-ROW
           WHEN 100
              MOVE N'04' TO RETURNCODE OF P-LCTFM007
              MOVE N'01' TO REASONCODE OF P-LCTFM007
              MOVE N'Challenge not found' TO
                   INFOMESSAGE OF P-LCTFM007
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'21' TO REASONCODE OF P-LCTFM007
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM007
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R120-READ-END.
           EXIT.

      *===============================================================*
      * R130-UPDATE: Update the row                                   *
      *===============================================================*
       R130-UPDATE SECTION.
           MOVE CHALLENGEID OF P-LCTFM007 TO CHALLENGEID OF DCLTBCTF007

           EXEC SQL
              UPDATE TBCTF007
                 SET CHALLENGETITLE = :DCLTBCTF007.CHALLENGETITLE,
                     CATEGORY       = :DCLTBCTF007.CATEGORY,
                     DESCRIPTION    = :DCLTBCTF007.DESCRIPTION,
                     CHALLENGETYPE  = :DCLTBCTF007.CHALLENGETYPE,
                     VERIFIERPGM    = :DCLTBCTF007.VERIFIERPGM
                                      :DCLTBCTF007.VERIFIERPGM-IND,
                     UPDATEDBY   = :W-USERID,
                     UPDATEDDATE = CURRENT TIMESTAMP
               WHERE CHALLENGEID = :DCLTBCTF007.CHALLENGEID
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              CONTINUE
           WHEN 100
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'31' TO REASONCODE OF P-LCTFM007
              MOVE N'Challenge not found' TO
                   INFOMESSAGE OF P-LCTFM007
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'32' TO REASONCODE OF P-LCTFM007
              STRING N'UPDATE gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM007
              PERFORM R900-DSNTIAR
           END-EVALUATE
           .
       R130-UPDATE-END.
           EXIT.

      *===============================================================*
      * R140-DELETE: Delete the row                                   *
      *===============================================================*
       R140-DELETE SECTION.
           MOVE CHALLENGEID OF P-LCTFM007 TO CHALLENGEID OF DCLTBCTF007

           EXEC SQL
              SELECT 1
                INTO :W-ONE
                FROM TBCTF011
               WHERE CHALLENGEID = :DCLTBCTF007.CHALLENGEID
               FETCH FIRST 1 ROW ONLY
           END-EXEC

           EVALUATE SQLCODE
           WHEN 0
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'53' TO REASONCODE OF P-LCTFM007
              STRING N'The challenge is in an event; take it out '
                     N'first'
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM007
           WHEN 100
              CONTINUE
           WHEN OTHER
              MOVE SQLCODE TO W-SQLCODE
              MOVE N'08' TO RETURNCODE OF P-LCTFM007
              MOVE N'21' TO REASONCODE OF P-LCTFM007
              STRING N'SELECT gave SQLCODE='
                     FUNCTION NATIONAL-OF(W-SQLCODE)
                 DELIMITED BY SIZE
                 INTO INFOMESSAGE OF P-LCTFM007
              PERFORM R900-DSNTIAR
           END-EVALUATE

           IF RETURNCODE OF P-LCTFM007 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF008
                  WHERE CHALLENGEID = :DCLTBCTF007.CHALLENGEID
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM007
                 MOVE N'42' TO REASONCODE OF P-LCTFM007
                 STRING N'DELETE flags gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM007
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM007 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF009
                  WHERE CHALLENGEID = :DCLTBCTF007.CHALLENGEID
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM007
                 MOVE N'42' TO REASONCODE OF P-LCTFM007
                 STRING N'DELETE hints gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM007
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM007 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF010
                  WHERE CHALLENGEID = :DCLTBCTF007.CHALLENGEID
              END-EXEC

              IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM007
                 MOVE N'42' TO REASONCODE OF P-LCTFM007
                 STRING N'DELETE links gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM007
                 PERFORM R900-DSNTIAR
              END-IF
           END-IF

           IF RETURNCODE OF P-LCTFM007 = N'00'
              EXEC SQL
                 DELETE FROM TBCTF007
                  WHERE CHALLENGEID = :DCLTBCTF007.CHALLENGEID
              END-EXEC

              EVALUATE SQLCODE
              WHEN 0
                 CONTINUE
              WHEN 100
                 MOVE N'08' TO RETURNCODE OF P-LCTFM007
                 MOVE N'41' TO REASONCODE OF P-LCTFM007
                 MOVE N'Challenge not found' TO
                      INFOMESSAGE OF P-LCTFM007
              WHEN -532
                 MOVE N'08' TO RETURNCODE OF P-LCTFM007
                 MOVE N'53' TO REASONCODE OF P-LCTFM007
                 MOVE N'Other rows still refer to this one' TO
                      INFOMESSAGE OF P-LCTFM007
              WHEN OTHER
                 MOVE SQLCODE TO W-SQLCODE
                 MOVE N'08' TO RETURNCODE OF P-LCTFM007
                 MOVE N'42' TO REASONCODE OF P-LCTFM007
                 STRING N'DELETE gave SQLCODE='
                        FUNCTION NATIONAL-OF(W-SQLCODE)
                    DELIMITED BY SIZE
                    INTO INFOMESSAGE OF P-LCTFM007
                 PERFORM R900-DSNTIAR
              END-EVALUATE
           END-IF
           .
       R140-DELETE-END.
           EXIT.

      *===============================================================*
      * R121-COPY-ROW: Copy the row to the IO area                    *
      *===============================================================*
       R121-COPY-ROW SECTION.
           MOVE CHALLENGEID OF DCLTBCTF007 TO CHALLENGEID OF P-LCTFM007
           MOVE CHALLENGETITLE OF DCLTBCTF007 TO
                CHALLENGETITLE OF P-LCTFM007
           MOVE CATEGORY OF DCLTBCTF007 TO CATEGORY OF P-LCTFM007
           MOVE DESCRIPTION OF DCLTBCTF007 TO DESCRIPTION OF P-LCTFM007
           MOVE CHALLENGETYPE OF DCLTBCTF007 TO
                CHALLENGETYPE OF P-LCTFM007
           IF VERIFIERPGM-IND OF DCLTBCTF007 < 0
              MOVE SPACES TO VERIFIERPGM OF P-LCTFM007
           ELSE
              MOVE VERIFIERPGM OF DCLTBCTF007 TO
                   VERIFIERPGM OF P-LCTFM007
           END-IF
           MOVE CREATEDBY OF DCLTBCTF007 TO CREATEDBY OF P-LCTFM007
           MOVE CREATEDDATE OF DCLTBCTF007 TO CREATEDDATE OF P-LCTFM007
           MOVE UPDATEDBY OF DCLTBCTF007 TO UPDATEDBY OF P-LCTFM007
           MOVE UPDATEDDATE OF DCLTBCTF007 TO UPDATEDDATE OF P-LCTFM007
           .
       R121-COPY-ROW-END.
           EXIT.

           COPY CTFCTXP REPLACING ==:IO:== BY ==P-LCTFM007==.

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

       END PROGRAM CTFM007.
