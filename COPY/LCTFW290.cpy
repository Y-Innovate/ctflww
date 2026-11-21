      *===============================================================*
      * LCTFW290: Container LCTFW290, put by CTFW290 in the routing   *
      * region and read by CTFC290 in the target region. Holds the    *
      * result of EXEC CICS ASSIGN USERID USERNAME, which a DPL       *
      * program cannot do itself.                                     *
      * W290-RC: 00 = ASSIGN NORMAL, 08 = ASSIGN failed (see RESP).   *
      * Character data only, so the container is passed as BIT.      *
      *===============================================================*
          05 LCTFW290.
             10 W290-RC            PIC X(02).
             10 W290-EIBRESP       PIC 9(08).
             10 W290-EIBRESP2      PIC 9(08).
             10 W290-USERID        PIC X(08).
             10 W290-USERNAME      PIC X(20).
