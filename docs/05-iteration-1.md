# Iteration 1: from registration to the leaderboard

The first COBOL slice. It proves the riskiest parts: the provisioning job, the
passphrase flow, public transactions and the scoring query. Nothing here has been
compiled or run yet.

## What is built

| Method and path | Access | Wrapper | Module | Use case |
|---|---|---|---|---|
| POST `/token` | Public | `LWWADPLI` (LWW's own) | | P1 |
| GET `/events` | Public | `CTFC202` | `CTFM202` | V1 |
| GET `/events/{eventID}` | Public | `CTFC302` | `CTFM302` | V1 |
| GET `/leaderboard/{eventID}` | Public | `CTFC314` | `CTFM314` | V2 |
| POST `/registrations` | Public | `CTFC303` | `CTFM303` | R1, S1 |
| GET `/registrations/{registrationID}` | Public | `CTFC304` | `CTFM304` | R2 |
| POST `/activations/{registrationID}` | Public | `CTFC305` | `CTFM305` | R3 |
| GET `/me` | Player | `CTFC290` | `CTFM290` | P1 |
| GET `/challenges` | Player | `CTFC311` | `CTFM311` | P4 |
| GET `/challenges/{challengeID}` | Player | `CTFC312` | `CTFM312` | P5 |
| POST `/submissions` | Player | `CTFC313` | `CTFM313` | P6 |

Support programs:

| Program | Purpose |
|---|---|
| `CTFC910` | Submits a provisioning job through CICS SPOOL; initial program of transaction `CTFS`, started by `CTFC303` |
| `CTFM910` | Reads the `SETTINGS` reftable; checks the claim token and claims a job for submission; records a failure |
| `CTFM915` | Batch: last step of a provisioning job, records the result in DB2. Linked with `DSNELI` |
| `CTFA990` | Finds the userid, a copy of `PETA990` |
| `CTFA991` | Random bytes (`PRNO`) and SHA-256 (`KLMD`) with CPACF |

Copybooks `CTFSECW` and `CTFSECP` hold the token and passphrase logic shared by
`CTFM303` and `CTFM305`.

The numbers follow the table where it helps: `2nn` lists, `3nn` game operations and
`9nn` support.

## Not built yet

- Team events: registering works, but a player without a team gets `08 50`. Individual
  events work, because registration creates the team of one.
- Hints, links, prerequisites listing, announcements, player progress, joining another
  event, changing a passphrase. Prerequisites are enforced, and hint costs and awards
  count on the leaderboard.
- The admin API. `SEEDDATA.sql` fills in what is needed for now.
- The scheduled batch of S3 and S4, so stuck jobs and unclaimed accounts aren't cleaned
  up yet.
- The provisioning actions other than create.

## DB2 plans and collections

| Plan | Collection | Transactions | Packages |
|---|---|---|---|
| `CTFT01P` | `CTFT01P` | `CTFP` | `CTFM202`, `CTFM302`, `CTFM303`, `CTFM304`, `CTFM305`, `CTFM314`, `CTFM910` |
| `CTFT01` | `CTFT01` | `CTFU`, `CTFA`, `CTFS`, provisioning jobs | All others, and `CTFM910`, `CTFM314` |

The CICS default userid can only execute `CTFT01P`. A module that a public path
calls has to be added to the lists at the top of `DEPLOY.zmake`, or that path gets
SQLCODE -805.

## Setting it up on t01

Check the values at the end of `envs/t01.yaml` first; see below.

1. Create the RACF group `PLAYERGROUP`, the batch userid `BATCHUSER`, with
   `CLAUTH(USER)` and group-special in that group, and the submit userid `SUBMITUSER`: protected
   (`NOPASSWORD`), without special authority, and with access to the CICS region if
   the `APPL` class is active. `BATCHUSER` also needs READ on the load library.
2. `python python/deploy.py DEPLOY_DDL`. This renders the DDL and JCL only.
3. Run DDL members `AA000001` to `AA000020`, if not done yet, and then `AA000022` with
   `RUNDDL`. The packages refer to the renamed columns, so this comes before the BIND.
4. `. ./setenv`, then `build`.
5. `python python/deploy.py`. This copies the modules and binds the packages.
6. Submit `BINDPLAN`, then run `SEEDDATA` and `SETTINGS` with `RUNDDL`. (Until
   2026-11-11 the settings were spread over `SEEDDATA`, `AA000023`, `AA000024` and
   `AA000026`; `SETTINGS.sql` now holds them all and can be run again.)
7. Submit `CICSCSD` and `RACF`, and install group `GCTFT01`. DB2 is RACF controlled, so
   `RACF` also gives the access to the plans and tables; there are no `GRANT`s for this.
8. Copy both specs in `openapi/` to LWW and register `ctf_1.0.0.yaml` with path prefix
   `/ctf/API/v1`, as `processYAML.py` does.
9. In LWW, assign `CTFP` to the public paths and `CTFU` to the player paths above.

## Trying it

With event 1 from the seed data and code `DEMO-CODE`:

1. `GET /events`
2. `POST /registrations` with `eventID`, `regCode` and `displayName`. Note the
   `registrationID` and `claimToken`.
3. Check that the job ran, then poll `GET /registrations/{id}` until the status is `R`.
4. `POST /activations/{id}` with `claimToken` and a `passphrase` of 14 to 100 characters.
   The answer has the userid.
5. `POST /token` with that userid and passphrase.
6. `GET /challenges?eventID=1`. The second challenge is locked.
7. `POST /submissions` with a wrong flag, then with `FIRST-FLAG`.
8. `GET /challenges?eventID=1` again: the second challenge is open.
9. `GET /leaderboard/1`, without a token.

`python python/testIteration1.py [--target <name>]` runs these steps and checks the
results, against a host of `python/runtimeTargets.yaml` (its default target without
`--target`; `--list` shows them). Every run creates a real RACF userid and takes a seat
in the event, and nothing cleans those up yet.

## Values to check in `envs/t01.yaml`

| Key | Value now | What it is |
|---|---|---|
| `PLAYERGROUP` | `CTFPLAY` | Default group of the players; placeholder |
| `BATCHUSER` | `CTFBATCH` | Userid of the provisioning jobs; placeholder |
| `SUBMITUSER` | `CTFSUBM` | Userid of the job submission task; placeholder |
| `DB2PLAN_PUBLIC`, `PKGCOLLID_PUBLIC` | `CTFT01P` | Plan and collection of the public transaction; the same names are in `DEPLOY.zmake` |
| `CICSTXN_SUBMIT` | `CTFS` | Transaction of the job submission task; not assigned to a path in LWW |
| `CICSDFLTUSER` | `CICSUSER` | CICS default userid; placeholder |
| `CICSREGIONUSER` | `STCMAS` | Userid of the CICS region |
| `ADMINGROUP` | `YINADMIN` | RACF group of the admins |
| `JOBMSGCLASS` | `X` | Must be a class that purges output; placeholder |
| `JOBCLASS` | `A` | Job class of the provisioning jobs |
| `CICSCSD`, `CICSLST` | As in `envs/t01.yaml` | CSD and group list |

The settings used by the job are also in the `SETTINGS` reftable (`SETTINGS.sql`), so
they can be changed without a rebuild.
