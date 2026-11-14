-- Rename the TITLE columns of the challenges and announcements tables.
-- TITLE is a reserved word in COBOL, also in the DCLGEN of the tables.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

   ALTER TABLE {{SCHEMA}}.{{CHALLENGES_TBNAME}}
     RENAME COLUMN TITLE TO CHALLENGETITLE;

   ALTER TABLE {{SCHEMA}}.{{ANNOUNCEMENTS_TBNAME}}
     RENAME COLUMN TITLE TO ANNOUNCETITLE;

   COMMIT;