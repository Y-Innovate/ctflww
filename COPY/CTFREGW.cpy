      *===============================================================*
      * CTFREGW: Working storage for CTFREGP                          *
      *===============================================================*
       01 W-REG.
          05 W-NEW-TEAMID       PIC S9(9) COMP-5.
          05 W-JOINCODE         PIC X(12).
          05 W-NEW-PARTSTATUS   PIC N.
          05 W-NEW-ACTION       PIC N.
          05 W-JOBHASH-IND      PIC S9(4) COMP-5.
       01 W-JOBHASH             USAGE SQL TYPE IS BINARY(32).
