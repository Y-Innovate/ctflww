      ******************************************************************
      * DCLGEN TABLE(TBCTF013)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF013 TABLE
           ( SUBMISSIONID                   INTEGER NOT NULL,
             EVENTID                        INTEGER NOT NULL,
             CHALLENGEID                    INTEGER NOT NULL,
             TEAMID                         INTEGER NOT NULL,
             PLAYERID                       INTEGER NOT NULL,
             SUBMITTEDTEXT                  VARGRAPHIC(255) NOT NULL,
             ISCORRECT                      GRAPHIC(1) NOT NULL,
             REVERSEDBY                     GRAPHIC(8),
             REVERSEDDATE                   TIMESTAMP,
             REVERSEREASON                  VARGRAPHIC(255),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF013.
           10 SUBMISSIONID         PIC S9(9) USAGE COMP-5.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 CHALLENGEID          PIC S9(9) USAGE COMP-5.
           10 TEAMID               PIC S9(9) USAGE COMP-5.
           10 PLAYERID             PIC S9(9) USAGE COMP-5.
           10 SUBMITTEDTEXT.
              49 SUBMITTEDTEXT-LEN PIC S9(4) USAGE COMP-5.
              49 SUBMITTEDTEXT-TEXT PIC N(255).
           10 ISCORRECT            PIC N(1).
           10 REVERSEDBY           PIC N(8).
           10 REVERSEDBY-IND       PIC S9(4) USAGE COMP-5.
           10 REVERSEDDATE         PIC X(26).
           10 REVERSEDDATE-IND     PIC S9(4) USAGE COMP-5.
           10 REVERSEREASON.
              49 REVERSEREASON-LEN PIC S9(4) USAGE COMP-5.
              49 REVERSEREASON-TEXT PIC N(255).
           10 REVERSEREASON-IND    PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
