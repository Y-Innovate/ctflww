-- Iteration 3: hash of the job token, for provisioning jobs that have
-- no claim token. Run this before the BIND: the packages use the new
-- column. The setting JOBMINS is in SETTINGS.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

   ALTER TABLE {{SCHEMA}}.{{PROVJOBS_TBNAME}}
     ADD JOBHASH BINARY(32);

   COMMIT;
