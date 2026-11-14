      *===============================================================*
      * CTFADMW: Working storage for CTFADMP, the admin check in the  *
      * CICS programs.                                                *
      *===============================================================*
       01 W-ADMIN-CHECK.
          05 W-READ             PIC S9(8) USAGE BINARY.
          05 C-FACILITY         PIC X(8)  VALUE 'FACILITY'.
          05 C-ADMINRES         PIC X(9)  VALUE 'CTF.ADMIN'.
          05 C-ADMINRES-LEN     PIC S9(8) USAGE BINARY VALUE 9.
          05 W-IS-ADMIN         PIC X     VALUE 'N'.
