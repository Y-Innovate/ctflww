       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFC910.
      *===============================================================*
      * This program submits a provisioning job with the CICS SPOOL   *
      * commands to the JES internal reader, under the batch userid.  *
      * Initial program of the submit transaction, started by CTFC303,*
      * CTFC306, CTFC510 and CTFC520 under the submit userid, the     *
      * only one with surrogate access to the batch userid. Container *
      * LCTFC911 holds the job and its token: the claim token for     *
      * CREATE and RESET, the job token for the rest. It trusts       *
      * nothing else: CTFM910 checks the token and reads the job from *
      * DB2, so a START from anywhere else can't submit anything.     *
      * Only generated values and the SETTINGS reftable go into the   *
      * JCL, never anything a user typed.                             *
      * CREATE has two steps: ADDUSER, then ALTUSER with the phrase,  *
      * NOINTERVAL and the event group. Only the second decides the   *
      * result, so a retry works when the userid exists already.      *
      * The other actions have one step with one RACF command.        *
      * Output is suppressed: the job holds a one-time passphrase, so *
      * SYSTSPRT is DUMMY and S-MSGCLASS has to be a purge class.     *
      * ------------------------------------------------------------- *
      * C910-RC in LCTFC910:                                          *
      *   00 = Submitted                                              *
      *   01 = PROVACTION is invalid, or the group is missing         *
      *   08 = A CICS command or CTFM910 failed                       *
      * After a failure a claimed job is set to failed. A job that    *
      * was not claimed is left alone and only gets a message.        *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WORK.
           05  C-CHNL-NAME-SUBMIT    PIC X(16) VALUE 'CTFSUBMIT'.
           05  C-CONT-NAME-SUBMIT    PIC X(16) VALUE 'LCTFC911'.
           05  W-PGMNAME             PIC X(8).
           05  W-CONT-LENGTH         PIC S9(9) USAGE COMP-5.
           05  W-CLAIMED             PIC X     VALUE 'N'.
           05  W-TOKEN               PIC X(8).
           05  W-EIBRESP             PIC 9(8).
           05  W-EIBRESP2            PIC 9(8).
           05  W-JOBID-D             PIC 9(7).
           05  W-JOBID-E             PIC Z(8)9.
           05  W-JOBID-9             PIC 9(9).
           05  W-JOBNAME             PIC X(8).
           05  W-REC                 PIC X(80).
           05  W-LEN80               PIC S9(9) USAGE COMP-5 VALUE 80.
           05  W-RESULT              PIC X.
           05  W-APOS                PIC X     VALUE "'".
           05  W-LASTSTEP            PIC X(5).

           05  W-MSGPTR              PIC S9(4) BINARY.
           05  MSGDEST               PIC S9(9) BINARY VALUE 2.
           05  FC.
               10  Condition-Token-Value.
               COPY  CEEIGZCT.
                   15  Case-1-Condition-ID.
                       20  Severity    PIC S9(4) BINARY.
                       20  Msg-No      PIC S9(4) BINARY.
                   15  Case-2-Condition-ID
                             REDEFINES Case-1-Condition-ID.
                       20  Class-Code  PIC S9(4) BINARY.
                       20  Cause-Code  PIC S9(4) BINARY.
                   15  Case-Sev-Ctl    PIC X.
                   15  Facility-ID     PIC XXX.
               10  I-S-Info            PIC S9(9) BINARY.
           05  MSGSTR.
               10  Vstring-length    PIC S9(4) BINARY.
               10  Vstring-text.
                   15  Vstring-char  PIC X
                               OCCURS 0 TO 256 TIMES
                               DEPENDING ON Vstring-length
                                  of MSGSTR.

       01  W-LCTFC910.
           COPY LCTFC910.
       01  W-LCTFC911.
           COPY LCTFC911.
       01  W-LCTFM910.
           COPY LCTFM910.

       PROCEDURE DIVISION.
       MAIN SECTION.
           PERFORM R001-INIT

           IF C910-RC OF W-LCTFC910 = '00'
              PERFORM R050-CLAIM-JOB
           END-IF

           IF C910-RC OF W-LCTFC910 = '00'
              PERFORM R100-OPEN
           END-IF

           IF C910-RC OF W-LCTFC910 = '00'
              PERFORM R200-JOBCARD
              IF PROVACTION OF W-LCTFC910 = 'C'
                 PERFORM R300-CREATE-USER
              ELSE
                 PERFORM R310-ONE-COMMAND
              END-IF
              PERFORM R400-RESULT-STEPS
              MOVE '/*EOF' TO W-REC
              PERFORM R900-WRITE
              PERFORM R190-CLOSE
           END-IF

           IF  W-CLAIMED = 'Y'
           AND C910-RC OF W-LCTFC910 NOT = '00'
              PERFORM R060-SET-FAILED
           END-IF

           EXEC CICS
              RETURN
           END-EXEC
           .

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
           INITIALIZE W-LCTFC910
           MOVE '00' TO C910-RC OF W-LCTFC910
           MOVE LENGTH OF W-LCTFC911 TO W-CONT-LENGTH

           EXEC CICS
              GET CONTAINER(C-CONT-NAME-SUBMIT)
                  CHANNEL(C-CHNL-NAME-SUBMIT)
                  INTO(W-LCTFC911)
                  FLENGTH(W-CONT-LENGTH)
                  NOHANDLE
           END-EXEC

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE '08' TO C910-RC OF W-LCTFC910

              MOVE EIBRESP  TO W-EIBRESP
              MOVE EIBRESP2 TO W-EIBRESP2
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'GET CONTAINER ERROR ' W-EIBRESP ' ' W-EIBRESP2
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           ELSE
              MOVE PROVJOBID OF W-LCTFC911 TO W-JOBID-D
              MOVE PROVJOBID OF W-LCTFC911 TO W-JOBID-E
              MOVE PROVJOBID OF W-LCTFC911 TO W-JOBID-9
              STRING 'C' W-JOBID-D DELIMITED BY SIZE INTO W-JOBNAME
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R050-CLAIM-JOB: Check the token and get the job and settings. *
      * Commits the claim first, so a job is never submitted twice    *
      *===============================================================*
       R050-CLAIM-JOB SECTION.
           MOVE N'C' TO OPCODE OF W-LCTFM910
           MOVE PROVJOBID OF W-LCTFC911 TO PROVJOBID OF W-LCTFM910
           MOVE CLAIMTOKEN OF W-LCTFC911 TO CLAIMTOKEN OF W-LCTFM910

           MOVE 'CTFM910' TO W-PGMNAME
           CALL W-PGMNAME USING W-LCTFM910 W-LCTFC910

           MOVE SPACES TO CLAIMTOKEN OF W-LCTFC911
           MOVE SPACES TO CLAIMTOKEN OF W-LCTFM910

           IF RETURNCODE OF W-LCTFM910 = N'00'
              MOVE 'Y' TO W-CLAIMED

              EXEC CICS
                 SYNCPOINT
                 NOHANDLE
              END-EXEC

              IF EIBRESP NOT = DFHRESP(NORMAL)
                 MOVE '08' TO C910-RC OF W-LCTFC910

                 MOVE EIBRESP  TO W-EIBRESP
                 MOVE EIBRESP2 TO W-EIBRESP2
                 MOVE 256 TO Vstring-length
                 MOVE 1 TO W-MSGPTR
                 STRING 'SYNCPOINT ERROR ' W-EIBRESP ' ' W-EIBRESP2
                        DELIMITED BY SIZE
                   INTO Vstring-text
                   WITH POINTER W-MSGPTR
                 COMPUTE Vstring-length = W-MSGPTR - 1
                 CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
              END-IF
           ELSE
              PERFORM R950-M910-MESSAGE
           END-IF

           IF C910-RC OF W-LCTFC910 = '00'
           AND W-CLAIMED = 'Y'
              MOVE N'R' TO OPCODE OF W-LCTFM910
              CALL W-PGMNAME USING W-LCTFM910 W-LCTFC910

              IF RETURNCODE OF W-LCTFM910 NOT = N'00'
                 PERFORM R950-M910-MESSAGE
              ELSE
                 EVALUATE TRUE
                 WHEN PROVACTION OF W-LCTFC910 = 'N'
                 WHEN PROVACTION OF W-LCTFC910 = 'M'
                    IF EVENTGROUP OF W-LCTFC910 = SPACES
                       MOVE '01' TO C910-RC OF W-LCTFC910
                    END-IF
                 WHEN PROVACTION OF W-LCTFC910 = 'C'
                 WHEN PROVACTION OF W-LCTFC910 = 'P'
                 WHEN PROVACTION OF W-LCTFC910 = 'V'
                 WHEN PROVACTION OF W-LCTFC910 = 'U'
                 WHEN PROVACTION OF W-LCTFC910 = 'X'
                    CONTINUE
                 WHEN OTHER
                    MOVE '01' TO C910-RC OF W-LCTFC910
                 END-EVALUATE
              END-IF
           END-IF
           .
       R050-CLAIM-JOB-END.
           EXIT.

      *===============================================================*
      * R060-SET-FAILED: Job row and player are failed                *
      *===============================================================*
       R060-SET-FAILED SECTION.
           MOVE N'F' TO OPCODE OF W-LCTFM910
           MOVE PROVJOBID OF W-LCTFC911 TO PROVJOBID OF W-LCTFM910
           MOVE PLAYERID OF W-LCTFC910 TO PLAYERID OF W-LCTFM910

           CALL W-PGMNAME USING W-LCTFM910 W-LCTFC910

           IF RETURNCODE OF W-LCTFM910 NOT = N'00'
              PERFORM R950-M910-MESSAGE
           END-IF

           EXEC CICS
              SYNCPOINT
              NOHANDLE
           END-EXEC
           .
       R060-SET-FAILED-END.
           EXIT.

      *===============================================================*
      * R100-OPEN: Open the internal reader                           *
      *===============================================================*
       R100-OPEN SECTION.
           EXEC CICS
              SPOOLOPEN OUTPUT
                        TOKEN(W-TOKEN)
                        USERID('INTRDR')
                        NODE('LOCAL')
                        RECORDLENGTH(80)
                        NOCC
                        NOHANDLE
           END-EXEC

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE '08' TO C910-RC OF W-LCTFC910

              MOVE EIBRESP  TO W-EIBRESP
              MOVE EIBRESP2 TO W-EIBRESP2
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'SPOOLOPEN ERROR ' W-EIBRESP ' ' W-EIBRESP2
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           END-IF
           .
       R100-OPEN-END.
           EXIT.

      *===============================================================*
      * R190-CLOSE: KEEP releases the job to JES. After a failure a   *
      * partial job is deleted                                        *
      *===============================================================*
       R190-CLOSE SECTION.
           IF C910-RC OF W-LCTFC910 = '00'
              EXEC CICS
                 SPOOLCLOSE TOKEN(W-TOKEN)
                            KEEP
                            NOHANDLE
              END-EXEC
           ELSE
              EXEC CICS
                 SPOOLCLOSE TOKEN(W-TOKEN)
                            DELETE
                            NOHANDLE
              END-EXEC
           END-IF

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE '08' TO C910-RC OF W-LCTFC910

              MOVE EIBRESP  TO W-EIBRESP
              MOVE EIBRESP2 TO W-EIBRESP2
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'SPOOLCLOSE ERROR ' W-EIBRESP ' ' W-EIBRESP2
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           END-IF
           .
       R190-CLOSE-END.
           EXIT.

      *===============================================================*
      * R200-JOBCARD: JOB statement                                   *
      *===============================================================*
       R200-JOBCARD SECTION.
           MOVE SPACES TO W-REC
           STRING '//' W-JOBNAME ' JOB ' W-APOS 'CTF' W-APOS
                  ',CLASS=' S-JOBCLASS OF W-LCTFC910
                  ',MSGCLASS=' S-MSGCLASS OF W-LCTFC910
                  ',MSGLEVEL=(0,0),' DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING '//         USER=' DELIMITED BY SIZE
                  S-BATCHUSR OF W-LCTFC910 DELIMITED BY SPACE
             INTO W-REC
           PERFORM R900-WRITE
           .
       R200-JOBCARD-END.
           EXIT.

      *===============================================================*
      * R300-CREATE-USER: CREATE. ADDUSER without a passphrase, so    *
      * the userid is protected until RACF2 gives it one; it ends in  *
      * RC 8 on a retry, when the userid exists already. RACF2 always *
      * runs and decides the result                                   *
      *===============================================================*
       R300-CREATE-USER SECTION.
           MOVE '//RACF1 EXEC PGM=IKJEFT1B' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSTSPRT DD DUMMY' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSTSIN DD *' TO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING ' ADDUSER ' RACFUSERID OF W-LCTFC910
                  ' DFLTGRP(' DELIMITED BY SIZE
                  S-PLAYGRP OF W-LCTFC910 DELIMITED BY SPACE
                  ') OWNER(' DELIMITED BY SIZE
                  S-PLAYGRP OF W-LCTFC910 DELIMITED BY SPACE
                  ') -' DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING '  NAME(' W-APOS 'CTF PLAYER' W-APOS ') NOPASSWORD'
                  DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE '//RACF2 EXEC PGM=IKJEFT1B' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSTSPRT DD DUMMY' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSTSIN DD *' TO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING ' ALTUSER ' RACFUSERID OF W-LCTFC910
                  ' PHRASE(' W-APOS ONETIMEPHRASE OF W-LCTFC910
                  W-APOS ')' DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING ' PASSWORD USER(' RACFUSERID OF W-LCTFC910
                  ') NOINTERVAL' DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           IF EVENTGROUP OF W-LCTFC910 NOT = SPACES
              MOVE SPACES TO W-REC
              STRING ' CONNECT ' RACFUSERID OF W-LCTFC910
                     ' GROUP(' EVENTGROUP OF W-LCTFC910 ')'
                     DELIMITED BY SIZE
                INTO W-REC
              PERFORM R900-WRITE
           END-IF

           MOVE 'RACF2' TO W-LASTSTEP
           .
       R300-CREATE-USER-END.
           EXIT.

      *===============================================================*
      * R310-ONE-COMMAND: The other actions, one RACF command each    *
      *===============================================================*
       R310-ONE-COMMAND SECTION.
           MOVE '//RACF1 EXEC PGM=IKJEFT1B' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSTSPRT DD DUMMY' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSTSIN DD *' TO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           EVALUATE PROVACTION OF W-LCTFC910
           WHEN 'N'
              STRING ' CONNECT ' RACFUSERID OF W-LCTFC910
                     ' GROUP(' EVENTGROUP OF W-LCTFC910 ')'
                     DELIMITED BY SIZE
                INTO W-REC
           WHEN 'M'
              STRING ' REMOVE ' RACFUSERID OF W-LCTFC910
                     ' GROUP(' EVENTGROUP OF W-LCTFC910 ')'
                     DELIMITED BY SIZE
                INTO W-REC
           WHEN 'P'
              STRING ' ALTUSER ' RACFUSERID OF W-LCTFC910
                     ' PHRASE(' W-APOS ONETIMEPHRASE OF W-LCTFC910
                     W-APOS ') RESUME' DELIMITED BY SIZE
                INTO W-REC
           WHEN 'V'
              STRING ' ALTUSER ' RACFUSERID OF W-LCTFC910
                     ' REVOKE' DELIMITED BY SIZE
                INTO W-REC
           WHEN 'U'
              STRING ' ALTUSER ' RACFUSERID OF W-LCTFC910
                     ' RESUME' DELIMITED BY SIZE
                INTO W-REC
           WHEN 'X'
              STRING ' DELUSER ' RACFUSERID OF W-LCTFC910
                     DELIMITED BY SIZE
                INTO W-REC
           END-EVALUATE
           PERFORM R900-WRITE

           MOVE 'RACF1' TO W-LASTSTEP
           .
       R310-ONE-COMMAND-END.
           EXIT.

      *===============================================================*
      * R400-RESULT-STEPS: Last steps report the result to DB2        *
      *===============================================================*
       R400-RESULT-STEPS SECTION.
           MOVE SPACES TO W-REC
           STRING '// IF (' W-LASTSTEP '.RC = 0) THEN'
                  DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE
           MOVE 'O' TO W-RESULT
           PERFORM R410-RESULT-STEP

           MOVE '// ELSE' TO W-REC
           PERFORM R900-WRITE
           MOVE 'F' TO W-RESULT
           PERFORM R410-RESULT-STEP

           MOVE '// ENDIF' TO W-REC
           PERFORM R900-WRITE
           .
       R400-RESULT-STEPS-END.
           EXIT.

      *===============================================================*
      * R410-RESULT-STEP: One step that runs CTFM915                  *
      *===============================================================*
       R410-RESULT-STEP SECTION.
           MOVE SPACES TO W-REC
           STRING '//RESULT' W-RESULT ' EXEC PGM=IKJEFT1B'
                  DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING '//STEPLIB DD DISP=SHR,DSN=' DELIMITED BY SIZE
                  S-LOADLIB OF W-LCTFC910 DELIMITED BY SPACE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING '//        DD DISP=SHR,DSN=' DELIMITED BY SIZE
                  S-DB2SSHLQ OF W-LCTFC910 DELIMITED BY SPACE
                  '.SDSNEXIT' DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING '//        DD DISP=SHR,DSN=' DELIMITED BY SIZE
                  S-DB2HLQ OF W-LCTFC910 DELIMITED BY SPACE
                  '.SDSNLOAD' DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE '//SYSTSPRT DD SYSOUT=*' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSPRINT DD SYSOUT=*' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSOUT DD SYSOUT=*' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSTSIN DD *' TO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING ' DSN SYSTEM(' S-DB2SSID OF W-LCTFC910 ')'
                  DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING ' RUN PROGRAM(CTFM915) PLAN(' DELIMITED BY SIZE
                  S-CTFPLAN OF W-LCTFC910 DELIMITED BY SPACE
                  ')' DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE

           MOVE ' END' TO W-REC
           PERFORM R900-WRITE
           MOVE '//SYSIN DD *' TO W-REC
           PERFORM R900-WRITE

           MOVE SPACES TO W-REC
           STRING W-JOBID-9 ' ' W-RESULT DELIMITED BY SIZE
             INTO W-REC
           PERFORM R900-WRITE
           .
       R410-RESULT-STEP-END.
           EXIT.

      *===============================================================*
      * R900-WRITE: Write one JCL record                              *
      *===============================================================*
       R900-WRITE SECTION.
           IF C910-RC OF W-LCTFC910 = '00'
              EXEC CICS
                 SPOOLWRITE TOKEN(W-TOKEN)
                            FROM(W-REC)
                            FLENGTH(W-LEN80)
                            NOHANDLE
              END-EXEC

              IF EIBRESP NOT = DFHRESP(NORMAL)
                 MOVE '08' TO C910-RC OF W-LCTFC910

                 MOVE EIBRESP  TO W-EIBRESP
              MOVE EIBRESP2 TO W-EIBRESP2
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'SPOOLWRITE ERROR ' W-EIBRESP ' ' W-EIBRESP2
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
              END-IF
           END-IF
           .
       R900-WRITE-END.
           EXIT.

      *===============================================================*
      * R950-M910-MESSAGE: CTFM910 failed. Never logs the token       *
      *===============================================================*
       R950-M910-MESSAGE SECTION.
           MOVE '08' TO C910-RC OF W-LCTFC910

           MOVE 256 TO Vstring-length
           MOVE 1 TO W-MSGPTR
           STRING 'CTFM910 ERROR JOB ' W-JOBID-E ' RC '
                  FUNCTION DISPLAY-OF(RETURNCODE OF W-LCTFM910) ' '
                  FUNCTION DISPLAY-OF(REASONCODE OF W-LCTFM910)
                  DELIMITED BY SIZE
             INTO Vstring-text
             WITH POINTER W-MSGPTR
           COMPUTE Vstring-length = W-MSGPTR - 1
           CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           .
       R950-M910-MESSAGE-END.
           EXIT.

       END PROGRAM CTFC910.
