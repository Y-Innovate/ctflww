      *===============================================================*
      * CTFCTXW: Working storage for CTFCTXP, the player context.     *
      * The module sets W-EVENTID before R100-GET-CONTEXT, and        *
      * W-CHALLENGEID and W-ALLOW-LOCKED before R106-CHECK-CHALLENGE. *
      *===============================================================*
       01 W-CTX.
          05 W-CTX-PGM       PIC X(8) VALUE 'CTFA990'.
          05 W-USERID        PIC N(8).
          05 W-EVENTID       PIC S9(9) COMP-5.
          05 W-PLAYERID      PIC S9(9) COMP-5.
          05 W-TEAMID        PIC S9(9) COMP-5.
          05 W-TEAMID-IND    PIC S9(4) COMP-5.
          05 W-PARTSTATUS    PIC N.
          05 W-PLAYMODE      PIC N.
          05 W-MAXTEAMSIZE   PIC S9(4) COMP-5.
          05 W-STARTED       PIC X.
          05 W-NOTENDED      PIC X.
          05 W-REGOPEN       PIC X.
          05 W-CUTOFF        PIC X(26).
          05 W-CHALLENGEID   PIC S9(9) COMP-5.
          05 W-ALLOW-LOCKED  PIC X.
          05 W-SOLVED        PIC X.
          05 W-LOCKED        PIC X.

       01 W-LCTFA990.
           COPY LCTFA990.

       01 C-CODES.
          05 C-A          PIC N VALUE N'A'.
          05 C-C          PIC N VALUE N'C'.
          05 C-D          PIC N VALUE N'D'.
          05 C-F          PIC N VALUE N'F'.
          05 C-I          PIC N VALUE N'I'.
          05 C-M          PIC N VALUE N'M'.
          05 C-N          PIC N VALUE N'N'.
          05 C-P          PIC N VALUE N'P'.
          05 C-Q          PIC N VALUE N'Q'.
          05 C-R          PIC N VALUE N'R'.
          05 C-S          PIC N VALUE N'S'.
          05 C-T          PIC N VALUE N'T'.
          05 C-U          PIC N VALUE N'U'.
          05 C-V          PIC N VALUE N'V'.
          05 C-X          PIC N VALUE N'X'.
          05 C-Y          PIC N VALUE N'Y'.
          05 C-CATEGORY   PIC N(8) VALUE N'CATEGORY'.
          05 C-SETTINGS   PIC N(8) VALUE N'SETTINGS'.
