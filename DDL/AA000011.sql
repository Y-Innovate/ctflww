-- Create flags table in ctf database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create flags tablespace
   CREATE TABLESPACE {{FLAGS_TBSNAME}}
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

-- Create flags table
   CREATE TABLE {{SCHEMA}}.{{FLAGS_TBNAME}}
      (FLAGID        INTEGER NOT NULL GENERATED ALWAYS
          AS IDENTITY
             (START WITH 1, INCREMENT BY 1, CACHE 20, NO CYCLE,
              NO ORDER, MAXVALUE 2147483647, MINVALUE 1),
       CHALLENGEID   INTEGER NOT NULL,
       FLAGVALUE     VARGRAPHIC(255) NOT NULL,
       CASESENSITIVE GRAPHIC(1) NOT NULL,
       CREATEDBY     GRAPHIC(8) NOT NULL,
       CREATEDDATE   TIMESTAMP NOT NULL,
       UPDATEDBY     GRAPHIC(8) NOT NULL,
       UPDATEDDATE   TIMESTAMP NOT NULL,
       CONSTRAINT FLAGSKEY
       PRIMARY KEY (FLAGID))
      IN {{DBNAME}}.{{FLAGS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create flags index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{FLAGS_IXNAME1}}
      ON {{SCHEMA}}.{{FLAGS_TBNAME}}
      (FLAGID ASC)
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

-- Create flags index on CHALLENGEID
   CREATE INDEX {{SCHEMA}}.{{FLAGS_IXNAME2}}
      ON {{SCHEMA}}.{{FLAGS_TBNAME}}
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
   ALTER TABLE {{SCHEMA}}.{{FLAGS_TBNAME}}
     FOREIGN KEY FLAGS_FK1 (CHALLENGEID)
     REFERENCES {{SCHEMA}}.{{CHALLENGES_TBNAME}}
       (CHALLENGEID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;