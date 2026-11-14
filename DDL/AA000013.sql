-- Create challlinks table in ctf database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create challlinks tablespace
   CREATE TABLESPACE {{CHALLLINKS_TBSNAME}}
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

-- Create challlinks table
   CREATE TABLE {{SCHEMA}}.{{CHALLLINKS_TBNAME}}
      (LINKID      INTEGER NOT NULL GENERATED ALWAYS
          AS IDENTITY
             (START WITH 1, INCREMENT BY 1, CACHE 20, NO CYCLE,
              NO ORDER, MAXVALUE 2147483647, MINVALUE 1),
       CHALLENGEID INTEGER NOT NULL,
       LINKNAME    VARGRAPHIC(60) NOT NULL,
       LINKURL     VARGRAPHIC(500) NOT NULL,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT CHALLLINKSKEY
       PRIMARY KEY (LINKID))
      IN {{DBNAME}}.{{CHALLLINKS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create challlinks index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{CHALLLINKS_IXNAME1}}
      ON {{SCHEMA}}.{{CHALLLINKS_TBNAME}}
      (LINKID ASC)
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

-- Create challlinks index on CHALLENGEID
   CREATE INDEX {{SCHEMA}}.{{CHALLLINKS_IXNAME2}}
      ON {{SCHEMA}}.{{CHALLLINKS_TBNAME}}
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

-- Create foreign key on CHALLENGEID
   ALTER TABLE {{SCHEMA}}.{{CHALLLINKS_TBNAME}}
     FOREIGN KEY CHALLL_FK1 (CHALLENGEID)
     REFERENCES {{SCHEMA}}.{{CHALLENGES_TBNAME}}
       (CHALLENGEID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;