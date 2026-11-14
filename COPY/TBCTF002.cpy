      ******************************************************************
      * DCLGEN TABLE(TBCTF002)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF002 TABLE
           ( EVENTID                        INTEGER NOT NULL,
             EVENTNAME                      VARGRAPHIC(100) NOT NULL,
             DESCRIPTION                    VARGRAPHIC(1000),
             EVENTSTATUS                    GRAPHIC(1) NOT NULL,
             PLAYMODE                       GRAPHIC(1) NOT NULL,
             MAXTEAMSIZE                    SMALLINT NOT NULL,
             STARTTS                        TIMESTAMP NOT NULL,
             ENDTS                          TIMESTAMP NOT NULL,
             FREEZETS                       TIMESTAMP,
             REGCODE                        VARGRAPHIC(32) NOT NULL,
             REGFROMTS                      TIMESTAMP NOT NULL,
             REGTOTS                        TIMESTAMP NOT NULL,
             MAXPLAYERS                     INTEGER NOT NULL,
             PLAYERCOUNT                    INTEGER NOT NULL,
             RACFGROUP                      GRAPHIC(8),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF002.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 EVENTNAME.
              49 EVENTNAME-LEN PIC S9(4) USAGE COMP-5.
              49 EVENTNAME-TEXT PIC N(100).
           10 DESCRIPTION.
              49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
              49 DESCRIPTION-TEXT PIC N(1000).
           10 DESCRIPTION-IND      PIC S9(4) USAGE COMP-5.
           10 EVENTSTATUS          PIC N(1).
           10 PLAYMODE             PIC N(1).
           10 MAXTEAMSIZE          PIC S9(4) USAGE COMP-5.
           10 STARTTS              PIC X(26).
           10 ENDTS                PIC X(26).
           10 FREEZETS             PIC X(26).
           10 FREEZETS-IND         PIC S9(4) USAGE COMP-5.
           10 REGCODE.
              49 REGCODE-LEN PIC S9(4) USAGE COMP-5.
              49 REGCODE-TEXT PIC N(32).
           10 REGFROMTS            PIC X(26).
           10 REGTOTS              PIC X(26).
           10 MAXPLAYERS           PIC S9(9) USAGE COMP-5.
           10 PLAYERCOUNT          PIC S9(9) USAGE COMP-5.
           10 RACFGROUP            PIC N(8).
           10 RACFGROUP-IND        PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
