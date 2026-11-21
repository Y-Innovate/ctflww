       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTFW290.
      *===============================================================*
      * This program is a local wrapper for REST program CTFC290.     *
      * GET /me: LWW links here, in the routing region. CTFC290 runs  *
      * as DPL program in a target region (DYNAMIC(YES)), where       *
      * EXEC CICS ASSIGN USERNAME is not allowed. This wrapper does   *
      * the ASSIGN USERID USERNAME here, puts the result in container *
      * LCTFW290 on the LWW channel and links to CTFC290 with that    *
      * channel. CTFC290 reads LCTFW290 and puts the LWW response     *
      * containers, which come back on the same channel.              *
      * CTFW290 must be defined DYNAMIC(NO) so it runs locally.       *
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
           05  C-PGM-CTFC290         PIC X(8)  VALUE 'CTFC290'.
           05  W-TRANSID             PIC X(4).
           05  W-CHNL-NAME           PIC X(16).
           05  W-CONT-NAME           PIC X(16).
           05  W-CONT-POINTER        POINTER.
           05  W-CONT-LENGTH         PIC S9(9) USAGE COMP-5.
           05  W-RETURNCODE          PIC X(2)  VALUE '00'.
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
           PERFORM R001-ASSIGN

           IF W-RETURNCODE = '00'
              PERFORM R005-LINK
           END-IF

           IF W-RETURNCODE NOT = '00'
              PERFORM R008-SET-ERROR
           END-IF

           EXEC CICS
              RETURN
           END-EXEC
           .

      *===============================================================*
      * R001-ASSIGN: ASSIGN USERID USERNAME, put container LCTFW290.  *
      * A failing ASSIGN is passed on in W290-RC: CTFC290 builds the  *
      * error response for it, as it did before.                      *
      *===============================================================*
       R001-ASSIGN SECTION.
           INITIALIZE W-LCTFW290

           EXEC CICS
              ASSIGN USERID(W290-USERID OF W-LCTFW290)
                     USERNAME(W290-USERNAME OF W-LCTFW290)
                     NOHANDLE
           END-EXEC

           MOVE EIBRESP  TO W290-EIBRESP  OF W-LCTFW290
           MOVE EIBRESP2 TO W290-EIBRESP2 OF W-LCTFW290

           IF EIBRESP = DFHRESP(NORMAL)
              MOVE '00' TO W290-RC OF W-LCTFW290
           ELSE
              MOVE '08' TO W290-RC OF W-LCTFW290
              MOVE SPACES TO W290-USERID   OF W-LCTFW290
                             W290-USERNAME OF W-LCTFW290
           END-IF

           MOVE C-CHNL-NAME-LWW      TO W-CHNL-NAME
           MOVE C-CONT-NAME-W290     TO W-CONT-NAME
           MOVE LENGTH OF W-LCTFW290 TO W-CONT-LENGTH
           SET W-CONT-POINTER TO ADDRESS OF W-LCTFW290

           PERFORM R920-PUT-CONTAINER
           .
       R001-ASSIGN-END.
           EXIT.

      *===============================================================*
      * R005-LINK: Link to CTFC290 with the LWW channel. No SYSID, so *
      * the dynamic routing program picks the target region. TRANSID: *
      * the mirror in the target region runs under our own tranid,    *
      * which must be defined there with PROGRAM(DFHMIRS).            *
      *===============================================================*
       R005-LINK SECTION.
           MOVE EIBTRNID TO W-TRANSID

           EXEC CICS
              LINK PROGRAM(C-PGM-CTFC290)
                   CHANNEL(C-CHNL-NAME-LWW)
                   TRANSID(W-TRANSID)
                   NOHANDLE
           END-EXEC

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE '08' TO W-RETURNCODE

              MOVE EIBRESP  TO W-EIBRESP
              MOVE EIBRESP2 TO W-EIBRESP2
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'LINK CTFC290 ERROR ' W-EIBRESP ' ' W-EIBRESP2
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           END-IF
           .
       R005-LINK-END.
           EXIT.

      *===============================================================*
      * R008-SET-ERROR: CTFC290 did not run (or a container could not *
      * be put): answer 500 with 08 91 (docs/04-api.md).              *
      *===============================================================*
       R008-SET-ERROR SECTION.
           INITIALIZE W-LCTFM290
           MOVE N'08' TO RETURNCODE OF W-LCTFM290
           MOVE N'91' TO REASONCODE OF W-LCTFM290
           MOVE N'LINK to CTFC290 failed' TO INFOMESSAGE OF W-LCTFM290

      *    Keep the LWW fields LWW put in LWW-LINK-PAR-00.
           INITIALIZE W-LINKPAR
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

           MOVE 500 TO STSCODE OF W-LINKPAR
           MOVE 21  TO STSTXTL OF W-LINKPAR
           MOVE 'Internal Server Error' TO STSTXTT OF W-LINKPAR

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
           .
       R008-SET-ERROR-END.
           EXIT.

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

       END PROGRAM CTFW290.
