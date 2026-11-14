      *===============================================================*
      * R050-CHECK-ADMIN: W-IS-ADMIN = Y if the CICS userid has READ  *
      * on FACILITY CTF.ADMIN. NOLOG: a player calling an admin path  *
      * is refused, not a security event. Needs CTFADMW.              *
      *===============================================================*
       R050-CHECK-ADMIN SECTION.
           MOVE 'N' TO W-IS-ADMIN

           EXEC CICS
              QUERY SECURITY RESCLASS(C-FACILITY)
                    RESID(C-ADMINRES)
                    RESIDLENGTH(C-ADMINRES-LEN)
                    LOGMESSAGE(DFHVALUE(NOLOG))
                    READ(W-READ)
                    NOHANDLE
           END-EXEC

           IF  EIBRESP = DFHRESP(NORMAL)
           AND W-READ = DFHVALUE(READABLE)
              MOVE 'Y' TO W-IS-ADMIN
           END-IF
           .
       R050-CHECK-ADMIN-END.
           EXIT.
