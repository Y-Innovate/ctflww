# ctflww

The backend of the Y-Innovate CTF: a Capture the Flag platform that runs
entirely on z/OS. Players register for an event, get a RACF userid, solve
challenges and submit flags; organizers build a challenge library, run events
and look after players. The scoring, the leaderboard and the accounts all live
in CICS, DB2 and RACF.

The REST API is served by **LWW**, a CICS extension that maps JSON requests to
COBOL copybooks, holds the browser sessions and hosts the web UI. The web UI
itself is a React app in its own repository,
[ctflww-frontend](https://github.com/Y-Innovate/ctflww-frontend); its build
output is committed here, in `LWWAdmin/`.

## How it fits together

```
Browser ──► LWW (in CICS) ──► COBOL wrapper CTFCnnn ──► module CTFMnnn ──► DB2
              │  serves the web UI (LWWAdmin/)                │
              │  sign-in: RACF passphrase (players),          └─► provisioning job
              │           Entra ID (organizers)                    (z/OS batch: RACF)
              └─ one CICS transaction per audience:
                 CTFP public, CTFU player, CTFA admin
```

- **Players** sign in with a RACF userid and passphrase; **organizers** with
  Entra ID, mapped to a RACF userid in the admin group. CICS and RACF decide who
  may call which path.
- **Accounts are real RACF userids.** Registering, resetting, revoking and
  removing players is done by provisioning jobs that the backend submits.
  The one-time passphrase of a new account is never stored: it is derived from
  a random claim token that only the registrant gets
  ([docs/03-data-model.md](docs/03-data-model.md#the-one-time-passphrase-is-not-stored)).
- **A daily batch** (`JCL/CTFBATCH.jcl`) cleans up stuck jobs and unclaimed
  accounts.

## Repository layout

| Folder | What it holds |
|---|---|
| `COBOL/` | `CTFCnnn`: CICS wrappers, one per API operation. `CTFMnnn`: the modules with the logic and the SQL |
| `ASM/` | `CTFA990` (find the userid) and `CTFA991` (random bytes and SHA-256 with CPACF) |
| `COPY/` | Copybooks: `LCTFMnnn` IO areas, `TBCTFnnn` table declarations, shared logic |
| `DDL/` | DB2 DDL, run in order (`AA0000nn`, see `$INFO.txt`), plus seed data and settings |
| `JCL/` | RACF definitions, CICS CSD definitions, plan binds, DDL runner, the daily batch |
| `LKED/`, `OPTFILE/` | Link-edit and compile options per program |
| `ZMAKE/` | Build and deploy definitions (`BUILD.zmake`, `DEPLOY.zmake`) |
| `envs/` | Values per environment (`t01.yaml`, `t02.yaml`), filled into the DDL, JCL and builds |
| `openapi/` | The API spec (`ctf_1.0.0.yaml`) and LWW's processing steps for it (`ctf_2_1.0.0.yaml`) |
| `LWWAdmin/` | What LWW serves under `/ctf`: the built web UI, LWW's sign-in pages, and one placeholder per API path whose hidden `.name` file sets its CICS transaction |
| `python/` | Build, deploy and upload scripts, and the API tests |
| `docs/` | Design and build documentation, see below |

## Documentation

| Document | Contents |
|---|---|
| [01-actors.md](docs/01-actors.md) | Who uses the system and how each is identified |
| [02-use-cases.md](docs/02-use-cases.md) | All use cases: visitor, registrant, player, team captain, organizer, system |
| [03-data-model.md](docs/03-data-model.md) | The DB2 tables, scoring and the leaderboard query |
| [04-api.md](docs/04-api.md) | REST conventions, access per path, status and reason codes |
| [05](docs/05-iteration-1.md) to [09](docs/09-iteration-5.md) | The five build iterations: what each added, design decisions, setup and tests |

## Requirements

- z/OS with CICS TS, Db2 for z/OS and RACF. The modules use CPACF for random
  numbers and hashing.
- LWW installed in the CICS region, with its Admin API reachable.
- Microsoft Entra ID, if organizers sign in with single sign-on.
- Python 3 with `jinja2`, `requests` and `PyYAML`: on z/OS (Unix System
  Services) for rendering, building and deploying, and on a workstation for
  uploading to LWW and running the API tests.

## Setting it up

[docs/05-iteration-1.md](docs/05-iteration-1.md#setting-it-up-on-t01) has the
full first-time setup; each later iteration lists what it adds. In short:

1. Copy `envs/t01.yaml` for your environment and set your dataset names, DB2
   subsystem, CICS names, RACF groups and userids.
2. Define the RACF groups and userids, render the DDL and JCL
   (`python python/deploy.py DEPLOY_DDL`), and run the DDL members in order.
3. Build (`. ./setenv`, then `build`) and deploy (`python python/deploy.py`):
   this copies the load modules and binds the packages. Then bind the plans
   (`BINDPLAN`) and load `SEEDDATA` and `SETTINGS`.
4. Install the CICS definitions (`CICSCSD`) and the RACF access (`RACF`).
5. Register the API in LWW (`python/processYAML.py`) and upload `LWWAdmin/`
   (`python/uploadLWW.py`).

The scripts in `python/` that talk to LWW read their host and sign-in from
`python/runtimeTargets.yaml`, which stays out of git: copy
[runtimeTargets.example.yaml](python/runtimeTargets.example.yaml) and fill it
in. Passwords are always asked for at run time.

## Testing

`python/testIteration1.py` to `testIteration5.py` walk through the API of each
iteration against a running environment and check the results, from
registration to closing an event. They create real RACF userids;
`python python/testIteration3.py --cleanup` removes the test players again. Use
`--target <name>` to pick an entry of `runtimeTargets.yaml`. Each iteration
document describes what its script covers.

The web UI has its own unit tests and a mock backend in
[ctflww-frontend](https://github.com/Y-Innovate/ctflww-frontend).

## License

Source-available, not open source: you may use the software, run it (also
modified) for others, redistribute it unmodified, and modify it for your own
use, but you may not distribute modified versions. See [LICENSE](LICENSE) for
the exact terms, and [THIRD-PARTY-NOTICES](THIRD-PARTY-NOTICES) for the
open-source components in the built web UI.
