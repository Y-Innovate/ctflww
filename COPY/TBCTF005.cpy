      ******************************************************************
      * DCLGEN TABLE(TBCTF005)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF005 TABLE
           ( TEAMID                         INTEGER NOT NULL,
             EVENTID                        INTEGER NOT NULL,
             TEAMNAME                       VARGRAPHIC(30) NOT NULL,
             TEAMKEY                        VARGRAPHIC(30) NOT NULL,
             JOINCODE                       GRAPHIC(12) NOT NULL,
             CAPTAINID                      INTEGER NOT NULL,
             MEMBERCOUNT                    SMALLINT NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF005.
           10 TEAMID               PIC S9(9) USAGE COMP-5.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 TEAMNAME.
              49 TEAMNAME-LEN PIC S9(4) USAGE COMP-5.
              49 TEAMNAME-TEXT PIC N(30).
           10 TEAMKEY.
              49 TEAMKEY-LEN PIC S9(4) USAGE COMP-5.
              49 TEAMKEY-TEXT PIC N(30).
           10 JOINCODE             PIC N(12).
           10 CAPTAINID            PIC S9(9) USAGE COMP-5.
           10 MEMBERCOUNT          PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
