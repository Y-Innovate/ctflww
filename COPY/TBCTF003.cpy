      ******************************************************************
      * DCLGEN TABLE(TBCTF003)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF003 TABLE
           ( PLAYERID                       INTEGER NOT NULL,
             RACFUSERID                     GRAPHIC(8) NOT NULL,
             DISPLAYNAME                    VARGRAPHIC(30) NOT NULL,
             DISPLAYKEY                     VARGRAPHIC(30) NOT NULL,
             PLAYERSTATUS                   GRAPHIC(1) NOT NULL,
             CLAIMHASH                      BINARY(32),
             CLAIMEXPIRES                   TIMESTAMP,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF003.
           10 PLAYERID             PIC S9(9) USAGE COMP-5.
           10 RACFUSERID           PIC N(8).
           10 DISPLAYNAME.
              49 DISPLAYNAME-LEN PIC S9(4) USAGE COMP-5.
              49 DISPLAYNAME-TEXT PIC N(30).
           10 DISPLAYKEY.
              49 DISPLAYKEY-LEN PIC S9(4) USAGE COMP-5.
              49 DISPLAYKEY-TEXT PIC N(30).
           10 PLAYERSTATUS         PIC N(1).
           10 CLAIMHASH            PIC X(32).
           10 CLAIMHASH-IND        PIC S9(4) USAGE COMP-5.
           10 CLAIMEXPIRES         PIC X(26).
           10 CLAIMEXPIRES-IND     PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
