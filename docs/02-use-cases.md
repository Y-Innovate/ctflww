# Use cases

Actors are described in [01-actors.md](01-actors.md). Open points are listed at
the [end of this document](#open-points).

## Terms

| Term | Meaning |
|---|---|
| Event | One competition, with its own dates, players and leaderboard |
| Library | All challenges, independent of any event |
| Team | The unit that scores. In an individual event, each player is a team of one |
| Solve | A team's first correct flag for a challenge in an event |
| Provisioning job | A z/OS batch job that changes RACF on behalf of the application |
| Freeze | Moment after which the non-admin view of the scores stops changing |
| Password | For players, always a RACF passphrase: passphrases are required here |

An event has a stored status, set by admins, and a phase that follows from the
clock:

| Status | Meaning | | Phase (only while PUBLISHED) | Meaning |
|---|---|---|---|---|
| DRAFT | Only admins see it | | Upcoming | Before start |
| PUBLISHED | Everyone sees it | | Running | Between start and end |
| CLOSED | Finished and offboarded; still visible | | Frozen | Running, after the freeze time |
| | | | Ended | After end |

## Visitor

### V1 Browse events
- **Goal:** see which events exist and when they run.
- **Preconditions:** none.
- **Main flow:** 1. The visitor opens the site. 2. The system lists events, newest
  first. 3. The visitor opens one and sees its description, dates, phase, play
  mode and whether registration is open.
- **Exceptions:** no events: an empty list.
- **Rules:** DRAFT events are hidden. Registration codes and RACF groups are never
  shown.

### V2 View leaderboard
- **Goal:** see the standings of an event.
- **Preconditions:** the event is PUBLISHED or CLOSED.
- **Main flow:** 1. The visitor opens the leaderboard. 2. The system shows rank,
  team or player name, score and number of solves, 20 rows at a time.
- **Exceptions:** event hidden or unknown: not found. No scores yet: empty list.
- **Rules:**
  - Score = solve values + awards - hint costs.
  - On equal scores, whoever reached the score first ranks higher.
  - During a freeze, everything after the freeze time is left out, including its
    effect on dynamic values.
  - The freeze stays in place after the event ends, until an admin lifts it (A1),
    so results can be revealed at a closing ceremony.
  - RACF userids are never shown.

## Registrant

### R1 Register
- **Goal:** request an account and a place in an event.
- **Preconditions:** the registrant has the event's code; registration is open.
- **Main flow:**
  1. The registrant enters the event code and a display name.
  2. The system checks the code, the registration window, the cap and the name.
  3. The system generates a userid and claim token, derives a one-time passphrase
     from the token, and stores the player as PENDING, with a place in the event
     and a provisioning job.
  4. The system submits the job (S1).
  5. The system returns a registration ID and a one-time claim token. The UI tells
     the registrant to note the token.
- **Exceptions:** wrong code, or registration closed: rejected, with the same
  message for both. Cap reached: rejected. Name taken: asked for another name.
- **Rules:**
  - Display names are unique across the application.
  - Pending registrations count towards the cap.
  - The display name never goes into JCL.
  - LWW can't limit the attempt rate per client address, so event codes must be
    long enough not to be guessed. Admins choose them, up to 32 characters.

### R2 Follow registration status
- **Goal:** know when the account is ready.
- **Preconditions:** the registrant has a registration ID.
- **Main flow:** 1. The UI polls the status. 2. The system answers PENDING, READY
  or FAILED.
- **Exceptions:** FAILED: the UI says to contact an organizer (A6). Unknown ID: not
  found.
- **Rules:** the answer contains only the status, so a guessed ID reveals nothing
  of value.

### R3 Choose password
- **Goal:** finish the account and learn the userid.
- **Preconditions:** status READY; the registrant has the claim token.
- **Main flow:**
  1. The registrant enters a password, with the claim token sent along.
  2. The system changes the one-time passphrase to the chosen one in RACF
     (`EXEC CICS CHANGE PHRASE`).
  3. The system clears the claim token hash, and sets the player to ACTIVE.
  4. The system shows the userid, which the player signs in with from now on.
- **Exceptions:** wrong claim token: rejected. Password refused by RACF rules: the
  reason is shown and the registrant can retry. Claim token lost: admin reset (A5).
- **Rules:**
  - The chosen password is not stored or logged by the application or LWW.
  - Claim tokens work once and are stored only as a hash. The one-time passphrase
    isn't stored at all: it is derived from the token again at this point.
  - Unclaimed accounts expire (S4).

## Player

### P1 Sign in and out
- **Goal:** get a session.
- **Preconditions:** player ACTIVE.
- **Main flow:** 1. The player enters userid and password. 2. LWW checks them
  with RACF, starts a session and gives the browser a cookie. 3. Signing out
  ends the session on LWW.
- **Exceptions:** wrong credentials: one generic message. Userid revoked by RACF
  after too many attempts: same message; an admin can resume it (A5).
- **Rules:** the browser only gets LWW's session cookie. Guessing is limited by
  RACF, which revokes a userid after too many wrong passphrases.
  Player userids are set to `NOINTERVAL`, so a passphrase can't expire mid-event.

### P2 Join another event
- **Goal:** take part in another event with the existing account.
- **Preconditions:** signed in; the player has the event's code; registration is
  open; the player is not in the event yet.
- **Main flow:** 1. The player enters the code. 2. The system checks the code, the
  window and the cap, and adds the player. 3. If the event has a RACF group the
  player isn't connected to, the system submits a CONNECT job and the place stays
  pending until it completes. 4. In an individual event, the team of one is
  created.
- **Exceptions:** as in R1. Job failed: the place stays pending and the admin is
  shown it (A6).
- **Rules:** same code, window and cap as R1.

### P3 Change password
- **Goal:** set a new password.
- **Preconditions:** signed in.
- **Main flow:** 1. The player enters the current and new password. 2. The system
  changes it in RACF.
- **Exceptions:** current password wrong or new password refused: reason shown.
- **Rules:** passwords are not stored or logged. A forgotten password goes through
  A5.

### P4 View challenge board
- **Goal:** see what can be played.
- **Preconditions:** signed in; the player is in the event; the event has started.
- **Main flow:** 1. The player opens the board. 2. The system lists the visible
  challenges with title, category, current value, number of solves, and whether
  the team has solved it or it is locked.
- **Exceptions:** not in the event: forbidden. Upcoming: no challenges yet.
- **Rules:**
  - During a freeze, values and solve counts stay as they were at the freeze time,
    because they would otherwise reveal what other teams are doing.
  - The team always sees its own solves, including those after the freeze.
  - After the end, the board stays readable.

### P5 View a challenge
- **Goal:** read a challenge.
- **Preconditions:** as P4; the challenge is visible and not locked.
- **Main flow:** 1. The player opens the challenge. 2. The system shows the
  description, links, the hints with their cost, attempts left, and the text of
  hints the team has unlocked.
- **Exceptions:** locked: forbidden, with the names of the required challenges.
- **Rules:** a flag is never returned to a player, in any response.

### P6 Submit a flag
- **Goal:** score points.
- **Preconditions:** as P5; the event is Running or Frozen; the team hasn't solved
  this challenge.
- **Main flow:**
  1. The player submits text.
  2. The system trims surrounding spaces and compares it to all the challenge's
     flags, honouring each flag's case-sensitivity setting.
  3. The system records the attempt.
  4. If correct, the system records the solve for the team and reports success.
- **Exceptions:**
  - Wrong: reported, with attempts left.
  - Attempts used up: rejected and not recorded.
  - Already solved, including a teammate who got there a moment earlier: reported
    as already solved, with no extra points.
  - Event not running: rejected.
- **Rules:**
  - The database guarantees one solve per team per challenge, so simultaneous
    correct submissions can't score twice.
  - Attempts are counted per team per challenge. Only wrong attempts count.
  - Solves during a freeze count, but stay hidden from others until it is lifted.

### P7 Unlock a hint
- **Goal:** get help at a known price.
- **Preconditions:** as P5; the event is Running or Frozen.
- **Main flow:** 1. The player sees the cost and confirms. 2. The system records
  the unlock for the team and deducts the cost. 3. The hint is shown to all team
  members.
- **Exceptions:** already unlocked: shown again, at no extra cost.
- **Rules:** the cost is fixed at the moment of unlocking, so later edits don't
  change it. A score can go below zero (decision 1).

### P8 View own progress
- **Goal:** see how the team is doing.
- **Preconditions:** signed in; the player is in the event.
- **Main flow:** the system shows the team's score, solves, hints unlocked, awards
  with their reasons, and who on the team solved what.
- **Exceptions:** not in the event: forbidden.
- **Rules:** during a freeze the team sees all its own solves, awards and hint
  costs, at the challenge values of the board, which count solves up to the freeze.
  Values computed from every solve would show when other teams solve the same
  challenges after the freeze. Once the freeze is lifted, this is the leaderboard
  score. Other teams' details are never shown.

### P9 Read announcements
- **Goal:** stay informed.
- **Preconditions:** signed in; the player is in the event.
- **Main flow:** the UI polls and shows announcements, newest first, and marks new
  ones.
- **Exceptions:** none.
- **Rules:** what counts as "new" is remembered in the browser, not in DB2.

## Team

These apply to team events only. In an individual event, the system rejects them.

### T1 Create a team
- **Goal:** start a team.
- **Preconditions:** the player is in the event, without a team; registration is
  open.
- **Main flow:** 1. The player enters a team name. 2. The system creates the team
  and a join code, and makes the player captain.
- **Exceptions:** name taken in this event: asked for another.
- **Rules:** a player is in at most one team per event. Team names are unique per
  event.

### T2 Join a team
- **Goal:** join teammates.
- **Preconditions:** the player is in the event, without a team; registration is
  open.
- **Main flow:** 1. The player enters the join code. 2. The system adds the player.
- **Exceptions:** wrong code: rejected. Team full: rejected.
- **Rules:** the event sets the maximum team size. Players without a team can't see
  challenges or score.

### T3 Leave a team
- **Goal:** leave before the competition starts.
- **Preconditions:** the player is in a team; the event hasn't started.
- **Main flow:** 1. The player confirms. 2. The system removes the player.
- **Exceptions:** captain with other members: must hand over first. Last member:
  the team is deleted.
- **Rules:** nobody can leave once the event has started (decision 2).

### T4 Manage the team as captain
- **Goal:** keep the team in order.
- **Preconditions:** the player is the team's captain.
- **Main flow:** the captain removes a member, hands over captaincy to a member, or
  views the join code.
- **Exceptions:** after the start: members can't be removed.
- **Rules:** handing over is possible at any time.

## Admin and challenge author

### A1 Manage event lifecycle
- **Goal:** set up and run an event.
- **Preconditions:** signed in as admin.
- **Main flow:** 1. Create a DRAFT with name, description, dates, freeze time, play
  mode, maximum team size, registration code and window, cap and RACF group.
  2. Edit it. 3. Publish it. 4. During or after the event: move or lift the freeze,
  extend the end, change the code.
- **Exceptions:** invalid dates: rejected. Publishing with no visible challenge:
  rejected. Deleting anything but an empty DRAFT: rejected.
- **Rules:**
  - Start < freeze < end.
  - Play mode and RACF group are locked once someone has joined.
  - The RACF group comes from the admin-maintained allowlist.

### A2 Maintain the challenge library
- **Goal:** have good, reusable challenges.
- **Preconditions:** signed in as admin or author.
- **Main flow:** 1. Create or edit a challenge: title, category, description.
  2. Add flags, with case sensitivity. 3. Add hints with a cost and order. 4. Add
  links to files.
- **Exceptions:** deleting a challenge linked to any event: rejected.
- **Rules:**
  - Changes also apply to events already using the challenge; the UI warns about
    this when one is running.
  - Changing a flag doesn't undo existing solves.
  - In v1 every challenge has type STATIC.

### A3 Put challenges in an event
- **Goal:** compose the game.
- **Preconditions:** the event and challenge exist.
- **Main flow:** 1. Link a challenge to the event. 2. Set scoring: fixed value, or
  dynamic with initial value, minimum and decay. 3. Optionally set the attempt
  limit, order and prerequisites. 4. Make it visible.
- **Exceptions:** no flag on the challenge: can't be made visible. Prerequisite
  outside the event, on itself, or forming a cycle: rejected. Unlinking a challenge
  with solves: rejected; hide it instead.
- **Rules:**
  - Initial >= minimum >= 0, and decay > 0.
  - A locked challenge opens when the team has solved all its prerequisites.

### A4 Monitor and correct
- **Goal:** see what's going on and fix mistakes.
- **Preconditions:** signed in as admin.
- **Main flow:** 1. List submissions and solves, filtered by event, team, player or
  challenge. 2. See the live leaderboard. 3. Reverse a solve, giving a reason.
- **Exceptions:** nothing to reverse: not found.
- **Rules:** reversing keeps the original attempt on record and notes who reversed
  it and why. The team may solve the challenge again. Dynamic values go back up.

### A5 Manage players
- **Goal:** help players and remove those who misbehave.
- **Preconditions:** signed in as admin.
- **Main flow:** look up a player by display name or userid, then:
  - **Reset password:** a job sets a new one-time passphrase, the admin gets a new
    claim token to hand over, and the player repeats R3.
  - **Revoke:** a job revokes the userid. Scores stay.
  - **Resume:** a job restores a revoked userid.
- **Exceptions:** job failed: shown in A6.
- **Rules:** admins can't see or set a player's password.

### A6 Follow provisioning jobs
- **Goal:** know that RACF matches what the application thinks.
- **Preconditions:** signed in as admin.
- **Main flow:** 1. List jobs by status, event or player. 2. See action, JES job ID,
  return code and message. 3. Retry a failed job.
- **Exceptions:** job not in a failed state: can't be retried.
- **Rules:**
  - Retried jobs must be safe to run twice, for example if the userid already
    exists.
  - Retrying a CREATE or RESET produces a new claim token for the admin to hand
    over, because the old one-time passphrase can't be recovered.

### A7 Give awards and penalties
- **Goal:** adjust a score fairly.
- **Preconditions:** the team is in the event.
- **Main flow:** 1. Enter team, points (may be negative) and a reason. 2. The score
  changes.
- **Exceptions:** zero points or no reason: rejected.
- **Rules:** awards are removed only by deleting them, and the team sees the reason.
  They respect the freeze like solves do.

### A8 Publish announcements
- **Goal:** tell players something.
- **Preconditions:** the event exists.
- **Main flow:** 1. Write a title and text. 2. Publish it. 3. Correct or delete it
  if needed.
- **Exceptions:** none beyond normal validation.
- **Rules:** announcements reach players by polling (P9), not push.

### A9 Close and offboard an event
- **Goal:** leave no unneeded access behind.
- **Preconditions:** the event has ended.
- **Main flow:** 1. The admin closes the event. 2. The system queues job rows that
  remove players from the event's RACF group, and revoke players who aren't in
  another open event. 3. The scheduled batch carries them out (S3). 4. The event
  becomes CLOSED and the leaderboard stays visible.
- **Exceptions:** job failed: shown in A6, and closing still counts as done.
- **Rules:** deleting userids altogether is a separate, manual admin action after
  closing. See decision 3.

## System

### S1 Submit a provisioning job
- **Goal:** get a RACF change carried out.
- **Trigger:** R1, P2, A5, A6.
- **Preconditions:** the job row is committed to DB2 first, so nothing can be
  submitted without a record.
- **Main flow:** 1. The trigger commits the job row and starts a separate task under
  the submit userid, passing the job and its token on a channel: the claim token for
  CREATE and RESET, a random job token for the other actions. 2. The task checks the
  token against the player's claim hash or the job's JOBHASH, and sets the job
  SUBMITTED, only if it is still NEW.
  3. It fills in the JCL template with generated values only, with `USER=` the
  batch userid. 4. It submits the job to `INTRDR` with the CICS SPOOL commands.
- **Exceptions:** submit failed: job marked FAILED. Wrong token or a job that isn't
  NEW: nothing is submitted, the job is left alone and a message is written. Crash
  before submitting: found by S3.
- **Rules:** no user-typed text ever goes into JCL. Output is suppressed or purged,
  so a one-time passphrase doesn't stay on the spool. The job name contains the
  PROVJOBS key, so a job on the spool can be matched to its row.

### S2 Record the job result
- **Goal:** let the application know the outcome.
- **Trigger:** the last step of the job, which always runs.
- **Main flow:** 1. The step updates the job row with the result. 2. On success of
  a CREATE, the player becomes READY; for a CONNECT, the place in the event
  becomes active.
- **Exceptions:** the step itself doesn't run, for example after a JCL error: found
  by S3.
- **Rules:** the step runs a COBOL program with static SQL (`CTFM915`), so the job's
  userid needs the plan but no access to the tables. The scheduled batch records its
  results with the same program. The effect on the player or place is recorded only
  on success; see [07-iteration-3.md](07-iteration-3.md) for the table per action.

### S3 Scheduled batch: queued and stuck jobs
- **Goal:** queued work gets done, and no registration waits forever without anyone
  knowing.
- **Trigger:** a scheduled batch job.
- **Main flow:** 1. Mark jobs not finished within the limit as FAILED, so they appear
  in A6. 2. Carry out queued rows (from A9 and S4), and NEW rows of the other actions
  that were never submitted, directly in this batch job: a REXX step issues the RACF
  commands and `CTFM915` records the results.
- **Exceptions:** a late result still updates the row. A CREATE or RESET stuck
  before submission can't be carried out, because its one-time passphrase is gone:
  it is marked FAILED.
- **Rules:** the limit is a setting. Doing bulk work here means closing a big event
  doesn't flood JES with one job per player.

### S4 Expire unclaimed registrations
- **Goal:** no live userids with a one-time passphrase left lying around.
- **Trigger:** the scheduled batch job of S3.
- **Main flow:** READY accounts not claimed within the limit get a queued REVOKE
  row, and their claim token hash is cleared. Their places without a team, or in a
  team of one without any activity, are deleted with that team. A place in a team
  with other members stays, so team sizes stay right.
- **Exceptions:** an admin can issue a reset (A5) afterwards.
- **Rules:** the limit is a setting. The expired player's place no longer counts
  towards the cap.

## Open points

### Decided

1. **Hints can take a score below zero.** Otherwise a team on zero points could
   never use a hint, and dynamic values can lower a score anyway.
2. **Teams can't lose members after the start.** New players can still join a team
   while registration is open, but nobody can leave or be removed once the event
   has started, so points can't move between teams. An admin can't override this
   in v1.
3. **Userids are revoked at closing and deleted by hand afterwards.** There is no
   automatic deletion.
4. **Public pages are events and leaderboards only, for now.** Announcements are
   for joined players. Extra public pages can be added later.
5. **Challenges stay readable after the end, but nobody can submit.** There is no
   practice mode.

### Mainframe decisions

| # | Topic | Decision |
|---|---|---|
| M1 | Anonymous access | LWW can assign a CICS transaction to each URI, with access set in RACF. So: separate transactions for public, player and admin paths. Public transactions run under the CICS default userid |
| M2 | Job submission | Submission through CICS SPOOL in a separate task, under a submit userid with surrogate access to a batch userid with group-special. The CICS default userid may only start that task, which checks the claim token |
| M3 | Secure random | CPACF, since ICSF is only on some systems: a small HLASM routine (`PRNO`, `KIMD`) |
| M4 | Passphrases | Required, default RACF rules: `EXEC CICS CHANGE PHRASE` |
| M5 | Admin or player | COBOL checks a FACILITY resource (`EXEC CICS QUERY SECURITY`) |
| M6 | Environments | `t01` only for now; others follow later |
| M7 | Expiry | `NOINTERVAL` on player userids |
| M8 | Periodic work | A scheduled batch job |

### Still to confirm

- **RACF group names:** the player base group and the event groups aren't named yet.
  They are needed for the provisioning job, not for the DDL or the API. The batch
  userid needs CONNECT authority in every group in the `RACFGRP` allowlist
  (`CONNECT CTFBATCH GROUP(g) AUTHORITY(CONNECT)`), and player userids need `OWNER`
  set to a group in its group-special scope, so they can be altered and deleted.

## Changes to the plan

Writing the use cases showed that some of the approved first-cut model is
incomplete. These go into step 2:

| Table | Change | Because of |
|---|---|---|
| PROVJOBS | Actions RESET and RESUME added | A5 |
| PARTICIPANTS | Status added (pending/active); team becomes nullable | P2, T1, T2 |
| PLAYERS, PROVJOBS | One-time passphrase not stored; derived from the claim token | Safer than a live credential in DB2 |
| EVENTS, TEAMS | PLAYERCOUNT and MEMBERCOUNT added | Cap can't be overshot |
| Leaderboard | One query with a cutoff host variable, not a view | Same query for frozen and live |
| API paths | At most one ID per path, at the end, instead of nested paths | LWW requires a URI with an ID to end with it |
| SUBMISSIONS | Reversal details added | A4 |
| New use case | S4 Expire unclaimed registrations | R3 |

## Out of scope for v1

Live z/OS verification, regex flags, files in DB2, brackets, email, 3270 emergency
transaction, pushed notifications, practice mode after an event, changing a
display name.
