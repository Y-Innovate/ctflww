      ******************************************************************
      * DCLGEN TABLE(TBCTF016)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF016 TABLE
           ( AWARDID                        INTEGER NOT NULL,
             EVENTID                        INTEGER NOT NULL,
             TEAMID                         INTEGER NOT NULL,
             POINTS                         INTEGER NOT NULL,
             REASON                         VARGRAPHIC(255) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF016.
           10 AWARDID              PIC S9(9) USAGE COMP-5.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 TEAMID               PIC S9(9) USAGE COMP-5.
           10 POINTS               PIC S9(9) USAGE COMP-5.
           10 REASON.
              49 REASON-LEN PIC S9(4) USAGE COMP-5.
              49 REASON-TEXT PIC N(255).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
