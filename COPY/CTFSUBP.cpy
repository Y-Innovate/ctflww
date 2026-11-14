      *===============================================================*
      * R100-SUBMIT-JOB: Start the task that submits the job, under   *
      * the submit userid, after the job row has been committed. The  *
      * token goes on a channel, not START FROM, because that would   *
      * put it in a temporary storage queue. If the START fails, the  *
      * job is set failed. Needs CTFSUBW, and from the CICS program:  *
      * W-RETURNCODE, the container fields, R920-PUT-CONTAINER and    *
      * the CEEMOUT fields.                                           *
      *===============================================================*
       R100-SUBMIT-JOB SECTION.
           MOVE PROVJOBID OF W-LCTFC910 TO PROVJOBID OF W-LCTFC911
           MOVE JOBTOKEN OF W-LCTFC910 TO CLAIMTOKEN OF W-LCTFC911
           MOVE SPACES TO JOBTOKEN OF W-LCTFC910

           MOVE '00'                 TO W-RETURNCODE
           MOVE C-CHNL-NAME-SUBMIT   TO W-CHNL-NAME
           MOVE C-CONT-NAME-SUBMIT   TO W-CONT-NAME
           MOVE LENGTH OF W-LCTFC911 TO W-CONT-LENGTH
           SET W-CONT-POINTER TO ADDRESS OF W-LCTFC911

           PERFORM R920-PUT-CONTAINER

           MOVE SPACES TO CLAIMTOKEN OF W-LCTFC911

           IF W-RETURNCODE = '00'
              EXEC CICS
                 START TRANSID(S-SUBMTXN OF W-LCTFC910)
                       CHANNEL(C-CHNL-NAME-SUBMIT)
                       USERID(S-SUBMUSR OF W-LCTFC910)
                       NOHANDLE
              END-EXEC

              IF EIBRESP NOT = DFHRESP(NORMAL)
                 MOVE '08' TO W-RETURNCODE

                 MOVE EIBRESP  TO W-EIBRESP
                 MOVE EIBRESP2 TO W-EIBRESP2
                 MOVE 256 TO Vstring-length
                 MOVE 1 TO W-MSGPTR
                 STRING 'START ERROR ' W-EIBRESP ' ' W-EIBRESP2
                        DELIMITED BY SIZE
                   INTO Vstring-text
                   WITH POINTER W-MSGPTR
                 COMPUTE Vstring-length = W-MSGPTR - 1
                 CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
              END-IF
           END-IF

           IF W-RETURNCODE NOT = '00'
              MOVE PROVJOBID OF W-LCTFC910 TO PROVJOBID OF W-LCTFM910
              MOVE PLAYERID OF W-LCTFC910 TO PLAYERID OF W-LCTFM910
              MOVE N'F' TO OPCODE OF W-LCTFM910

              MOVE 'CTFM910' TO W-PGMNAME
              CALL W-PGMNAME USING W-LCTFM910 W-LCTFC910

              EXEC CICS
                 SYNCPOINT
                 NOHANDLE
              END-EXEC
           END-IF
           .
       R100-SUBMIT-JOB-END.
           EXIT.
