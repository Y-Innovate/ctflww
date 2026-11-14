-- Create players table in ctf database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create players tablespace
   CREATE TABLESPACE {{PLAYERS_TBSNAME}}
                       IN {{DBNAME}}
                       USING STOGROUP {{STOGROUP}}
                       PRIQTY 40 SECQTY 40
                       ERASE  NO
                       FREEPAGE 0 PCTFREE 5 FOR UPDATE 0
                       GBPCACHE CHANGED
                       TRACKMOD YES
                       MAXPARTITIONS 254
                       LOGGED
                       DSSIZE 4 G
                       SEGSIZE 4
                       BUFFERPOOL BP0
                       LOCKSIZE ANY
                       LOCKMAX SYSTEM
                       CLOSE YES
                       COMPRESS NO
                       CCSID      UNICODE
                       DEFINE YES
                       MAXROWS 255
                       INSERT ALGORITHM 0;

-- Create players table
   CREATE TABLE {{SCHEMA}}.{{PLAYERS_TBNAME}}
      (PLAYERID     INTEGER NOT NULL GENERATED ALWAYS
          AS IDENTITY
             (START WITH 1, INCREMENT BY 1, CACHE 20, NO CYCLE,
              NO ORDER, MAXVALUE 2147483647, MINVALUE 1),
       RACFUSERID   GRAPHIC(8) NOT NULL,
       DISPLAYNAME  VARGRAPHIC(30) NOT NULL,
       DISPLAYKEY   VARGRAPHIC(30) NOT NULL,
       PLAYERSTATUS GRAPHIC(1) NOT NULL,
       CLAIMHASH    BINARY(32),
       CLAIMEXPIRES TIMESTAMP,
       CREATEDBY    GRAPHIC(8) NOT NULL,
       CREATEDDATE  TIMESTAMP NOT NULL,
       UPDATEDBY    GRAPHIC(8) NOT NULL,
       UPDATEDDATE  TIMESTAMP NOT NULL,
       CONSTRAINT PLAYERSKEY
       PRIMARY KEY (PLAYERID))
      IN {{DBNAME}}.{{PLAYERS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create players index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{PLAYERS_IXNAME1}}
      ON {{SCHEMA}}.{{PLAYERS_TBNAME}}
      (PLAYERID ASC)
     USING STOGROUP {{STOGROUP}}
     PRIQTY -1 SECQTY -1
     ERASE  NO
     FREEPAGE 0 PCTFREE 10
     GBPCACHE CHANGED
     NOT CLUSTER
     COMPRESS NO
     INCLUDE NULL KEYS
     BUFFERPOOL BP0
     CLOSE NO
     COPY NO
     DEFER NO
     DEFINE YES
     PIECESIZE 2 G;

-- Create players index on RACFUSERID
   CREATE UNIQUE INDEX {{SCHEMA}}.{{PLAYERS_IXNAME2}}
      ON {{SCHEMA}}.{{PLAYERS_TBNAME}}
      (RACFUSERID ASC)
     USING STOGROUP {{STOGROUP}}
     PRIQTY -1 SECQTY -1
     ERASE  NO
     FREEPAGE 0 PCTFREE 10
     GBPCACHE CHANGED
     NOT CLUSTER
     COMPRESS NO
     INCLUDE NULL KEYS
     BUFFERPOOL BP0
     CLOSE NO
     COPY NO
     DEFER NO
     DEFINE YES
     PIECESIZE 2 G;

-- Create players index on DISPLAYKEY
   CREATE UNIQUE INDEX {{SCHEMA}}.{{PLAYERS_IXNAME3}}
      ON {{SCHEMA}}.{{PLAYERS_TBNAME}}
      (DISPLAYKEY ASC)
     USING STOGROUP {{STOGROUP}}
     PRIQTY -1 SECQTY -1
     ERASE  NO
     FREEPAGE 0 PCTFREE 10
     GBPCACHE CHANGED
     NOT CLUSTER
     COMPRESS NO
     INCLUDE NULL KEYS
     BUFFERPOOL BP0
     CLOSE NO
     COPY NO
     DEFER NO
     DEFINE YES
     PIECESIZE 2 G;

-- Create players index on PLAYERSTATUS, CLAIMEXPIRES
   CREATE INDEX {{SCHEMA}}.{{PLAYERS_IXNAME4}}
      ON {{SCHEMA}}.{{PLAYERS_TBNAME}}
      (PLAYERSTATUS ASC,
       CLAIMEXPIRES ASC)
     USING STOGROUP {{STOGROUP}}
     PRIQTY -1 SECQTY -1
     ERASE  NO
     FREEPAGE 0 PCTFREE 10
     GBPCACHE CHANGED
     NOT CLUSTER
     COMPRESS NO
     INCLUDE NULL KEYS
     BUFFERPOOL BP0
     CLOSE NO
     COPY NO
     DEFER NO
     DEFINE YES
     PIECESIZE 2 G;

-- Create sequence for generating RACF userids (CTF + 4 digits). Each
-- environment has its own range (envs/*.yaml), so environments that
-- share a RACF database never hand out the same userid.
   CREATE SEQUENCE {{SCHEMA}}.{{PLAYERS_SEQNAME}}
      AS INTEGER
      START WITH {{PLAYERS_SEQ_START}} INCREMENT BY 1
      MINVALUE {{PLAYERS_SEQ_START}} MAXVALUE {{PLAYERS_SEQ_MAX}}
      NO CYCLE CACHE 20 NO ORDER;

   COMMIT;