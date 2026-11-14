       01 W-SECRETS.
          05 W-A991-PGM         PIC X(8) VALUE 'CTFA991'.
          05 C-HEX              PIC X(16) VALUE '0123456789ABCDEF'.
          05 C-LETTERS          PIC X(26)
                                VALUE 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
          05 C-DIGITS           PIC X(10) VALUE '0123456789'.
          05 W-TOKEN            PIC X(64).
          05 W-PHRASE           PIC X(32).
          05 W-TOKENHASH        PIC X(32).
          05 W-SEC-I            PIC S9(4) USAGE COMP-5.
          05 W-SEC-J            PIC S9(4) USAGE COMP-5.
          05 W-SEC-K            PIC S9(4) USAGE COMP-5.
          05 W-SEC-BYTE-PAIR.
             10 FILLER          PIC X VALUE LOW-VALUE.
             10 W-SEC-BYTE      PIC X.
          05 W-SEC-BYTE-NUM REDEFINES W-SEC-BYTE-PAIR
                                PIC S9(4) USAGE COMP-5.
       01 W-LCTFA991.
           COPY LCTFA991.
