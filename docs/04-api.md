# REST API

A guide to [`openapi/ctf_1.0.0.yaml`](../openapi/ctf_1.0.0.yaml), the public contract
of the CTF backend, with base path `/ctf/API/v1`. It has 83 operations:
7 public, 20 player and 56 admin. The LWW processing steps
(`ctf_2_1.0.0.yaml`) follow together with the copybooks.

## Conventions

Some of these follow from LWW and the fixed copybooks behind it:

- **Envelope:** every response body has `retCode`, `reasonCode` and `infoMessage`.
  The exception is `POST /token`, which is LWW's own `LWWADPLI` and returns only the
  token.
- **Paths:** at most one ID, always at the end of the path. Other keys go in the query
  string, as in `/challenges/{challengeID}?eventID=`. This is an LWW
  requirement: a URI with an ID has to end with it.
- **Lists:** at most 20 rows, one array per response, and never nested. To get the
  next page, pass the last row's keys as `*_since`. Fewer than 20 rows means the end.
- **Filters:** optional `*_filter` query parameters.
- **Text:** every string has a `maxLength` that matches its DB2 column.
- **Timestamps:** strings in DB2 format, `2026-01-01-00.00.00.000000`.
- **Empty values:** an empty string means NULL. In responses, LWW returns an empty
  variable-length text field as `null`, for example `hintText` of a hint that isn't
  unlocked. Clients treat `null` and `""` alike.
- **Missing request fields:** LWW refuses a request body that lacks a field, unless
  its mapping marks it `required: false`. Optional are: `eventDescription`,
  `maxTeamSize`, `freezeTS` and `racfGroup` of an event (and `eventStatus` when
  creating one, which defaults to D); `challengeType` (S) and `verifierPgm`;
  `sortOrder` of a hint; `tabValue`; and `minPoints`, `decaySolves`, `maxAttempts`,
  `isVisible` (N) and `sortOrder` of a challenge in an event. A missing text field
  is empty, a missing number 0.
- **Empty numbers:** `minPoints`, `decaySolves` and `maxAttempts` use 0 for "empty"
  (no limit, or not dynamic), in requests and responses.
- **Required text:** `reverseReason` of a reversal and `reason` of an award can't be
  empty, although their schemas allow `""`, as every string does.
- **Single characters:** codes such as `Y`/`N` are explained in the field's description.

## Access

Each access level gets its own CICS transaction, assigned per URI in LWW.

| Tag | Who | Transaction | Userid | Extra check |
|---|---|---|---|---|
| `public` | Anyone | `CTFP` | CICS default userid | None |
| `player` | Signed-in player | `CTFU` | The player's RACF userid | COBOL looks the player up from the CICS userid, and checks they are in the event |
| `admin` | Entra admin | `CTFA` | The mapped RACF userid | COBOL checks the FACILITY resource `CTF.ADMIN` with `EXEC CICS QUERY SECURITY` |

Rules for the backend:

- The player always comes from the CICS userid. No request can name who is acting.
- The CICS default userid may use `CTFP` only. It must have no access to `CTFU` or
  `CTFA`, otherwise a call without a token could reach them.
- Flags, event codes, RACF groups and submitted text appear in `/admin` responses only.
- A team's join code is returned only to its captain.
- LWW logging must leave out request bodies on `/token`, `/activations` and
  `/myPassphrase`, because they carry passphrases.

## Status and reason codes

The general codes, with `08 5x` added for the game rules:

| Return, reason | HTTP | Meaning |
|---|---|---|
| `00 00` | 200, 201 | OK |
| `04 01` | 404 | Not found |
| `08 0x` | 400 | Invalid input |
| `08 11` | 409 | Duplicate |
| `08 12`, `21`, `32`, `42` | 500 | SQL error |
| `08 13`, `33` | 404 | Missing parent |
| `08 31`, `41` | 404 | Update or delete of a missing key |
| `08 50` | 403 | Not allowed: not in the event, not captain, not admin, or challenge locked |
| `08 51` | 403 | Registration refused: wrong code or closed, with one message for both |
| `08 52` | 409 | Full: event cap or team size |
| `08 53` | 409 | Not possible in this state: event phase, job state, or still in use (the message says what) |
| `08 54` | 409 | Already solved |
| `08 55` | 403 | Attempts used up |
| `08 56` | 400 | Passphrase refused by RACF |
| `08 57` | 403 | Wrong claim token |
| `08 90` | 500 | Security or userid routine failed |
| `08 91` | 500 | Local wrapper could not reach the DPL program (`CTFW290` LINK to `CTFC290` failed) |

A wrong flag isn't an error: `POST /submissions` returns 201 with `isCorrect` set to `N`.

## Public

| Method | Path | What it does | Use cases |
|---|---|---|---|
| POST | `/token` | Sign in with RACF userid and passphrase | P1 |
| GET | `/events` | List published and closed events; with `eventStatus_filter=A` the archived ones | V1 |
| GET | `/events/{eventID}` | Get an event | V1 |
| GET | `/leaderboard/{eventID}` | Get the leaderboard, honouring the freeze | V2 |
| POST | `/registrations` | Register with an event code and display name | R1 |
| GET | `/registrations/{registrationID}` | Get the status of a registration | R2 |
| POST | `/activations/{registrationID}` | Choose a passphrase with the claim token | R3 |

## Player

| Method | Path | What it does | Use cases |
|---|---|---|---|
| GET | `/me` | Get the signed-in user | P1 |
| PUT | `/myPassphrase` | Change own passphrase | P3 |
| GET | `/myEvents` | List the events the player joined | P2, P8 |
| POST | `/participants` | Join another event with its code | P2 |
| GET | `/challenges` | Get the challenge board | P4 |
| GET | `/challenges/{challengeID}` | Get a challenge | P5 |
| GET | `/challengeLinks` | List the links of a challenge | P5 |
| GET | `/prerequisites` | List what a locked challenge requires | P5 |
| GET | `/hints` | List the hints of a challenge; text only if unlocked | P5, P7 |
| POST | `/hintUnlocks` | Unlock a hint for the team | P7 |
| POST | `/submissions` | Submit a flag | P6 |
| GET | `/progress/{eventID}` | Get own team summary; true score, also during a freeze | P8, T4 |
| GET | `/progressSolves` | List own team solves | P8 |
| GET | `/progressAwards` | List own team awards and penalties | P8 |
| GET | `/announcements` | List announcements, newest first | P9 |
| POST | `/teams` | Create a team and become captain | T1 |
| POST | `/teamMembers` | Join a team with its join code | T2 |
| GET | `/teamMembers` | List own team members | P8, T4 |
| DELETE | `/teamMembers/{playerID}` | Leave the team, or remove a member as captain | T3, T4 |
| PUT | `/teamCaptains/{eventID}` | Hand over captaincy | T4 |

## Admin

| Method | Path | What it does | Use cases |
|---|---|---|---|
| GET | `/admin/events` | List Events; without `eventStatus_filter` the archived ones are left out | A1, A10 |
| POST | `/admin/events` | Create Event | A1 |
| GET | `/admin/events/{eventID}` | Get Event | A1 |
| PUT | `/admin/events/{eventID}` | Update Event | A1 |
| DELETE | `/admin/events/{eventID}` | Delete Event | A1 |
| POST | `/admin/eventClosures/{eventID}` | Close an event and queue the offboarding | A9 |
| POST | `/admin/eventArchives/{eventID}` | Archive a closed event | A10 |
| DELETE | `/admin/eventArchives/{eventID}` | Restore an archived event to closed | A10 |
| GET | `/admin/challenges` | List Challenges | A2 |
| POST | `/admin/challenges` | Create Challenge | A2 |
| GET | `/admin/challenges/{challengeID}` | Get Challenge | A2 |
| PUT | `/admin/challenges/{challengeID}` | Update Challenge | A2 |
| DELETE | `/admin/challenges/{challengeID}` | Delete Challenge | A2 |
| GET | `/admin/flags` | List Flags | A2 |
| POST | `/admin/flags` | Create Flag | A2 |
| PUT | `/admin/flags/{flagID}` | Update Flag | A2 |
| DELETE | `/admin/flags/{flagID}` | Delete Flag | A2 |
| GET | `/admin/hints` | List Hints | A2 |
| POST | `/admin/hints` | Create Hint | A2 |
| PUT | `/admin/hints/{hintID}` | Update Hint | A2 |
| DELETE | `/admin/hints/{hintID}` | Delete Hint | A2 |
| GET | `/admin/links` | List Links | A2 |
| POST | `/admin/links` | Create Link | A2 |
| PUT | `/admin/links/{linkID}` | Update Link | A2 |
| DELETE | `/admin/links/{linkID}` | Delete Link | A2 |
| GET | `/admin/eventChallenges` | List the challenges of an event | A3 |
| POST | `/admin/eventChallenges` | Put a challenge in an event | A3 |
| PUT | `/admin/eventChallenges/{challengeID}` | Update scoring and visibility | A3 |
| DELETE | `/admin/eventChallenges/{challengeID}` | Take a challenge without solves out of an event | A3 |
| GET | `/admin/prerequisites` | List prerequisites | A3 |
| POST | `/admin/prerequisites` | Add a prerequisite | A3 |
| DELETE | `/admin/prerequisites/{challengeID}` | Remove a prerequisite | A3 |
| GET | `/admin/submissions` | List attempts | A4 |
| GET | `/admin/solves` | List solves | A4 |
| POST | `/admin/solveReversals` | Reverse a solve, giving a reason | A4 |
| GET | `/admin/leaderboard/{eventID}` | Get the live leaderboard | A4 |
| GET | `/admin/teams` | List the teams of an event | A4, A7 |
| GET | `/admin/players` | Find players | A5 |
| GET | `/admin/players/{playerID}` | Get a player | A5 |
| DELETE | `/admin/players/{playerID}` | Delete the RACF userid of a revoked player; the row stays | A5, A9 |
| POST | `/admin/playerResets/{playerID}` | Reset a passphrase and get a new claim token | A5 |
| POST | `/admin/playerRevocations/{playerID}` | Revoke a userid | A5 |
| POST | `/admin/playerResumptions/{playerID}` | Resume a revoked userid | A5 |
| GET | `/admin/provisioningJobs` | List provisioning jobs | A6 |
| POST | `/admin/jobRetries/{provJobID}` | Retry a failed job; a CREATE or RESET also returns a new claim token | A6 |
| GET | `/admin/awards` | List awards and penalties | A7 |
| POST | `/admin/awards` | Give an award or penalty | A7 |
| DELETE | `/admin/awards/{awardID}` | Delete an award or penalty | A7 |
| GET | `/admin/announcements` | List announcements | A8 |
| POST | `/admin/announcements` | Publish an announcement | A8 |
| PUT | `/admin/announcements/{announceID}` | Correct an announcement | A8 |
| DELETE | `/admin/announcements/{announceID}` | Delete an announcement | A8 |
| GET | `/admin/refTables` | List categories, allowed RACF groups and settings | A1, A2 |
| POST | `/admin/refTables` | Create a reference entry | A1, A2 |
| PUT | `/admin/refTables/{tableID}` | Update a reference entry | A1, A2 |
| DELETE | `/admin/refTables/{tableID}` | Delete a reference entry | A1, A2 |

The system use cases S1-S4 run in CICS or batch and have no endpoint of their own.

## Scenarios walked through

| Scenario | Calls |
|---|---|
| New player | `POST /registrations`, poll `GET /registrations/{id}`, `POST /activations/{id}`, `POST /token` |
| Team solves after a hint | `GET /challenges`, `GET /hints`, `POST /hintUnlocks`, `POST /submissions`, `GET /progress/{id}` |
| Teammates submit together | Both `POST /submissions`; the second gets 409 with `08 54` |
| Read during a freeze | `GET /leaderboard/{id}` has `isFrozen` = `Y`; `GET /admin/leaderboard/{id}` is live |
