-- Create challenges table in ctf database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create challenges tablespace
   CREATE TABLESPACE {{CHALLENGES_TBSNAME}}
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
                       BUFFERPOOL BP8K0
                       LOCKSIZE ANY
                       LOCKMAX SYSTEM
                       CLOSE YES
                       COMPRESS NO
                       CCSID      UNICODE
                       DEFINE YES
                       MAXROWS 255
                       INSERT ALGORITHM 0;

-- Create challenges table
   CREATE TABLE {{SCHEMA}}.{{CHALLENGES_TBNAME}}
      (CHALLENGEID   INTEGER NOT NULL GENERATED ALWAYS
          AS IDENTITY
             (START WITH 1, INCREMENT BY 1, CACHE 20, NO CYCLE,
              NO ORDER, MAXVALUE 2147483647, MINVALUE 1),
       TITLE         VARGRAPHIC(100) NOT NULL,
       CATEGORY      GRAPHIC(8) NOT NULL,
       DESCRIPTION   VARGRAPHIC(3000) NOT NULL,
       CHALLENGETYPE GRAPHIC(1) NOT NULL,
       VERIFIERPGM   GRAPHIC(8),
       CREATEDBY     GRAPHIC(8) NOT NULL,
       CREATEDDATE   TIMESTAMP NOT NULL,
       UPDATEDBY     GRAPHIC(8) NOT NULL,
       UPDATEDDATE   TIMESTAMP NOT NULL,
       CONSTRAINT CHALLENGESKEY
       PRIMARY KEY (CHALLENGEID))
      IN {{DBNAME}}.{{CHALLENGES_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create challenges index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{CHALLENGES_IXNAME1}}
      ON {{SCHEMA}}.{{CHALLENGES_TBNAME}}
      (CHALLENGEID ASC)
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

-- Create challenges index on CATEGORY
   CREATE INDEX {{SCHEMA}}.{{CHALLENGES_IXNAME2}}
      ON {{SCHEMA}}.{{CHALLENGES_TBNAME}}
      (CATEGORY ASC)
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

   COMMIT;