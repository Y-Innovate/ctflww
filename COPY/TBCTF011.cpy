      ******************************************************************
      * DCLGEN TABLE(TBCTF011)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF011 TABLE
           ( EVENTID                        INTEGER NOT NULL,
             CHALLENGEID                    INTEGER NOT NULL,
             SCORETYPE                      GRAPHIC(1) NOT NULL,
             INITPOINTS                     INTEGER NOT NULL,
             MINPOINTS                      INTEGER,
             DECAYSOLVES                    INTEGER,
             ISVISIBLE                      GRAPHIC(1) NOT NULL,
             SORTORDER                      SMALLINT NOT NULL,
             MAXATTEMPTS                    SMALLINT,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF011.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 CHALLENGEID          PIC S9(9) USAGE COMP-5.
           10 SCORETYPE            PIC N(1).
           10 INITPOINTS           PIC S9(9) USAGE COMP-5.
           10 MINPOINTS            PIC S9(9) USAGE COMP-5.
           10 MINPOINTS-IND        PIC S9(4) USAGE COMP-5.
           10 DECAYSOLVES          PIC S9(9) USAGE COMP-5.
           10 DECAYSOLVES-IND      PIC S9(4) USAGE COMP-5.
           10 ISVISIBLE            PIC N(1).
           10 SORTORDER            PIC S9(4) USAGE COMP-5.
           10 MAXATTEMPTS          PIC S9(4) USAGE COMP-5.
           10 MAXATTEMPTS-IND      PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
