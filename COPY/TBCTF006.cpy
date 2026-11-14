      ******************************************************************
      * DCLGEN TABLE(TBCTF006)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF006 TABLE
           ( EVENTID                        INTEGER NOT NULL,
             PLAYERID                       INTEGER NOT NULL,
             TEAMID                         INTEGER,
             PARTSTATUS                     GRAPHIC(1) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF006.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 PLAYERID             PIC S9(9) USAGE COMP-5.
           10 TEAMID               PIC S9(9) USAGE COMP-5.
           10 TEAMID-IND           PIC S9(4) USAGE COMP-5.
           10 PARTSTATUS           PIC N(1).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
