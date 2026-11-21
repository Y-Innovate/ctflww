       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFC290.
      *===============================================================*
      * This program is a REST program of the CTF application.        *
      * GET /me: RACF userid and name, the role from the FACILITY     *
      * resource CTF.ADMIN, and the player record if there is one.    *
      * Runs as DPL program, where ASSIGN USERNAME is not allowed:    *
      * LWW links to wrapper CTFW290 in the routing region, which     *
      * does the ASSIGN and passes the result in container LCTFW290.  *
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
           05  C-CHNL-NAME-LWW       PIC X(16) VALUE 'LWW-LINK-CHL-00'.
           05  C-CONT-NAME-LWW-00    PIC X(16) VALUE 'LWW-LINK-PAR-00'.
           05  C-CONT-NAME-LWW-03    PIC X(16) VALUE 'LWW-LINK-PAR-03'.
           05  C-CONT-NAME-W290      PIC X(16) VALUE 'LCTFW290'.
           05  W-CHNL-NAME           PIC X(16).
           05  W-CONT-NAME           PIC X(16).
           05  W-CONT-POINTER        POINTER.
           05  W-CONT-LENGTH         PIC S9(9) USAGE COMP-5.
           05  W-RETURNCODE          PIC X(2)  VALUE '00'.
           05  W-PGMNAME             PIC X(8)  VALUE SPACES.
           05  W-OK-CODE             PIC S9(4) COMP-5 VALUE 200.
           05  W-EIBRESP             PIC 9(8).
           05  W-EIBRESP2            PIC 9(8).

           05  SW-CONT-FOUND-VAL     PIC X     VALUE 'N'.
               88  SW-CONT-FOUND               VALUE 'Y'.
               88  SW-CONT-MISSING             VALUE 'N'.

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

           COPY CTFADMW.

       01  W-LCTFW290.
           COPY LCTFW290.
       01  W-LCTFM290.
           COPY LCTFM290.
       01  W-LINKPAR.
           COPY LINKPAR.

       LINKAGE SECTION.
       01  P-CHAR                    PIC X.

       PROCEDURE DIVISION.
       MAIN SECTION.
           PERFORM R001-INIT

           PERFORM R005-PROCESS

           PERFORM R009-FINISH
           .

      *===============================================================*
      * R001-INIT: Program initialisations                            *
      *===============================================================*
       R001-INIT SECTION.
      *    There is no input: the IO area is filled here.
           INITIALIZE W-LCTFM290

           MOVE C-CHNL-NAME-LWW    TO W-CHNL-NAME
           MOVE C-CONT-NAME-LWW-00 TO W-CONT-NAME

           PERFORM R910-GET-CONTAINER

           IF SW-CONT-FOUND
              SET ADDRESS OF P-CHAR TO W-CONT-POINTER
              IF W-CONT-LENGTH > LENGTH OF W-LINKPAR
                 MOVE LENGTH OF W-LINKPAR TO W-CONT-LENGTH
              END-IF
              MOVE P-CHAR(1:W-CONT-LENGTH) TO W-LINKPAR
           END-IF
           .
       R001-INIT-END.
           EXIT.

      *===============================================================*
      * R005-PROCESS: Call the module                                 *
      *===============================================================*
       R005-PROCESS SECTION.
      *    USERID and USERNAME come from CTFW290 (ASSIGN in the
      *    routing region). Missing container: treated as failed.
           INITIALIZE W-LCTFW290
           MOVE '08' TO W290-RC OF W-LCTFW290

           MOVE C-CHNL-NAME-LWW  TO W-CHNL-NAME
           MOVE C-CONT-NAME-W290 TO W-CONT-NAME

           PERFORM R910-GET-CONTAINER

           IF SW-CONT-FOUND
              SET ADDRESS OF P-CHAR TO W-CONT-POINTER
              IF W-CONT-LENGTH > LENGTH OF W-LCTFW290
                 MOVE LENGTH OF W-LCTFW290 TO W-CONT-LENGTH
              END-IF
              MOVE P-CHAR(1:W-CONT-LENGTH) TO W-LCTFW290
           END-IF

           IF W290-RC OF W-LCTFW290 = '00'
              MOVE FUNCTION NATIONAL-OF(W290-USERID OF W-LCTFW290)
                TO RACFUSERID OF W-LCTFM290
              MOVE FUNCTION NATIONAL-OF(W290-USERNAME OF W-LCTFW290)
                TO USERNAME OF W-LCTFM290
              MOVE 'CTFM290' TO W-PGMNAME
              CALL W-PGMNAME USING W-LCTFM290

              PERFORM R050-CHECK-ADMIN

              IF W-IS-ADMIN = 'Y'
                 MOVE N'A' TO ROLE OF W-LCTFM290
              ELSE
                 MOVE N'P' TO ROLE OF W-LCTFM290
              END-IF
           ELSE
              MOVE N'08' TO RETURNCODE OF W-LCTFM290
              MOVE N'90' TO REASONCODE OF W-LCTFM290
              MOVE N'ASSIGN USERID/USERNAME failed'
                TO INFOMESSAGE OF W-LCTFM290

              IF SW-CONT-FOUND
                 MOVE W290-EIBRESP  OF W-LCTFW290 TO W-EIBRESP
                 MOVE W290-EIBRESP2 OF W-LCTFW290 TO W-EIBRESP2
              ELSE
                 MOVE ZERO TO W-EIBRESP W-EIBRESP2
              END-IF
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'ASSIGN USERID ERROR ' W-EIBRESP ' ' W-EIBRESP2
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           END-IF

           PERFORM R006-SET-STATUS
           .
       R005-PROCESS-END.
           EXIT.

      *===============================================================*
      * R006-SET-STATUS: Map return and reason code to HTTP status    *
      *===============================================================*
       R006-SET-STATUS SECTION.
           IF RETURNCODE OF W-LCTFM290 = N'00'
              MOVE W-OK-CODE TO STSCODE OF W-LINKPAR
              IF W-OK-CODE = 201
                 MOVE 7   TO STSTXTL OF W-LINKPAR
                 MOVE 'Created' TO STSTXTT OF W-LINKPAR
              ELSE
                 MOVE 2   TO STSTXTL OF W-LINKPAR
                 MOVE 'OK' TO STSTXTT OF W-LINKPAR
              END-IF
           ELSE
      *       The codes are explained in docs/04-api.md
              EVALUATE TRUE
              WHEN RETURNCODE OF W-LCTFM290 = N'04'
              WHEN REASONCODE OF W-LCTFM290 = N'13'
              WHEN REASONCODE OF W-LCTFM290 = N'31'
              WHEN REASONCODE OF W-LCTFM290 = N'33'
              WHEN REASONCODE OF W-LCTFM290 = N'41'
                 MOVE 404 TO STSCODE OF W-LINKPAR
                 MOVE 9   TO STSTXTL OF W-LINKPAR
                 MOVE 'Not Found' TO STSTXTT OF W-LINKPAR
              WHEN REASONCODE OF W-LCTFM290 = N'11'
              WHEN REASONCODE OF W-LCTFM290 = N'52'
              WHEN REASONCODE OF W-LCTFM290 = N'53'
              WHEN REASONCODE OF W-LCTFM290 = N'54'
                 MOVE 409 TO STSCODE OF W-LINKPAR
                 MOVE 8   TO STSTXTL OF W-LINKPAR
                 MOVE 'Conflict' TO STSTXTT OF W-LINKPAR
              WHEN REASONCODE OF W-LCTFM290 = N'50'
              WHEN REASONCODE OF W-LCTFM290 = N'51'
              WHEN REASONCODE OF W-LCTFM290 = N'55'
              WHEN REASONCODE OF W-LCTFM290 = N'57'
                 MOVE 403 TO STSCODE OF W-LINKPAR
                 MOVE 9   TO STSTXTL OF W-LINKPAR
                 MOVE 'Forbidden' TO STSTXTT OF W-LINKPAR
              WHEN REASONCODE OF W-LCTFM290(1:1) = N'0'
              WHEN REASONCODE OF W-LCTFM290 = N'56'
                 MOVE 400 TO STSCODE OF W-LINKPAR
                 MOVE 11  TO STSTXTL OF W-LINKPAR
                 MOVE 'Bad Request' TO STSTXTT OF W-LINKPAR
              WHEN OTHER
                 MOVE 500 TO STSCODE OF W-LINKPAR
                 MOVE 21  TO STSTXTL OF W-LINKPAR
                 MOVE 'Internal Server Error' TO STSTXTT OF W-LINKPAR
              END-EVALUATE
           END-IF
           .
       R006-SET-STATUS-END.
           EXIT.

      *===============================================================*
      * R009-FINISH: Program finalisations                            *
      *===============================================================*
       R009-FINISH SECTION.
           MOVE C-CHNL-NAME-LWW      TO W-CHNL-NAME
           MOVE C-CONT-NAME-LWW-03   TO W-CONT-NAME
           MOVE LENGTH OF W-LCTFM290 TO W-CONT-LENGTH
           SET W-CONT-POINTER TO ADDRESS OF W-LCTFM290

           PERFORM R920-PUT-CONTAINER

           MOVE C-CHNL-NAME-LWW     TO W-CHNL-NAME
           MOVE C-CONT-NAME-LWW-00  TO W-CONT-NAME
           MOVE LENGTH OF W-LINKPAR TO W-CONT-LENGTH
           SET W-CONT-POINTER TO ADDRESS OF W-LINKPAR

           PERFORM R920-PUT-CONTAINER

           EXEC CICS
              RETURN
           END-EXEC
           .
       R009-FINISH-END.
           EXIT.

           COPY CTFADMP.

      *===============================================================*
      * R910-GET-CONTAINER: Get container W-CONT-NAME                 *
      *===============================================================*
       R910-GET-CONTAINER SECTION.
           EXEC CICS
              GET CONTAINER(W-CONT-NAME)
                  CHANNEL(W-CHNL-NAME)
                  SET(W-CONT-POINTER)
                  FLENGTH(W-CONT-LENGTH)
                  NOHANDLE
           END-EXEC

           IF EIBRESP = DFHRESP(NORMAL)
              SET SW-CONT-FOUND TO TRUE
           ELSE
              SET SW-CONT-MISSING TO TRUE

              IF  EIBRESP NOT = DFHRESP(CHANNELERR)
              AND EIBRESP NOT = DFHRESP(CONTAINERERR)
                 MOVE '08' TO W-RETURNCODE

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
              END-IF
           END-IF
           .
       R910-GET-CONTAINER-END.
           EXIT.

      *===============================================================*
      * R920-PUT-CONTAINER: Put container W-CONT-NAME                 *
      *===============================================================*
       R920-PUT-CONTAINER SECTION.
           SET ADDRESS OF P-CHAR TO W-CONT-POINTER

           EXEC CICS
              PUT CONTAINER(W-CONT-NAME)
                  CHANNEL(W-CHNL-NAME)
                  FROM(P-CHAR)
                  FLENGTH(W-CONT-LENGTH)
                  NOHANDLE
           END-EXEC

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE '08' TO W-RETURNCODE

              MOVE EIBRESP  TO W-EIBRESP
              MOVE EIBRESP2 TO W-EIBRESP2
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'PUT CONTAINER ERROR ' W-EIBRESP ' ' W-EIBRESP2
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           END-IF
           .
       R920-PUT-CONTAINER-END.
           EXIT.

       END PROGRAM CTFC290.
