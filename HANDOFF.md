# Overload — handoff / current state

Paste this as your first message in a new session and attach the project files.
Current as of commit `d1cb96d`. Start with [`README.md`](README.md) — it covers
setup, tests and the data-layer reasoning. This file covers what's *left*.

---

## Who I am and how to work with me

I have **little to no coding background**. Explain decisions in plain language,
don't assume I know tooling, and don't hand me a half-finished thing and call it
done. If something needs my input (an account, a key, a password), tell me
exactly where to click.

---

## The project

**Overload** is a workout tracker. It began as a single self-contained HTML file
— every screen, style and line of logic in one place, all data in browser
`localStorage`. Zero libraries, 177 built-in exercises, four tabs plus 11
sub-screens, canvas-drawn charts and share cards.

`CLAUDE.md` is the original migration brief and still governs intent:

- Treat the original app as **the spec, not something to redesign**. Feature
  parity with a new persistence layer underneath.
- **PRs are computed, never stored.** Don't add a cached PR table.
- Preserve the design language: graphite/orange, JetBrains Mono for
  numbers/headings, Inter for body, gradient `#ffab5e` → `#ff7a1a`. The dark
  "streak hero" on Home is intentionally fixed-dark regardless of the theme
  toggle.

## Decisions already made (don't re-litigate)

| | |
|---|---|
| Backend | **Supabase** — Postgres + auth + RLS |
| App type | **Real store app reusing the existing web UI** (brief says twice not to redesign) |
| Wrapper | **Capacitor**, not Expo/React Native |
| Platforms | iOS and Android |
| Store submission | **Not yet** — store-ready, not submitted |
| Data strategy | **Working app first, then relational.** Phase 1 stores per-user JSON blobs; Phase 3 migrates to `schema.sql` |
| Existing user data | **None to preserve** — no import script needed |

---

## Phase 1 is complete

Accounts, cloud sync, PWA and native scaffolding all work.

- Restructured to `docs/`; `@supabase/supabase-js` 2.116.0 vendored locally
  (no build step, works offline). **There is deliberately no bundler.**
- `phase1-schema.sql` — `user_state(owner_id, key, value jsonb, updated_at)`,
  PK `(owner_id, key)`, with **per-operation** RLS policies. They're split
  rather than one `for all` because a bare `using` clause isn't applied to
  inserts, so a single policy would let a user insert rows owned by someone
  else. `value` is nullable on purpose (`activeWorkout`/`account` are
  legitimately null).
- `loadState`/`saveKey`/`deleteKeySafe` rewritten local-first — see the README
  section on this, and **don't collapse it into plain awaited network writes.**
- Auth: register, login, sign-out, forgot-password, set-new-password, and the
  confirm-email path. Gate screens for all of it.
- PWA manifest, service worker, and icons generated from the app's own barbell
  mark by `tools/make-icons.py`.
- Capacitor configured; `android/` and `ios/` committed per Capacitor's
  recommendation (they hold icons, permissions, signing config).

### Tests — all passing

A mock Supabase server means the cloud path is testable without real keys.

- `npm run test:smoke` — local-only mode, 9 checks
- `npm run test:cloud` — full round trip, 17 checks. Wipes local storage before
  signing back in, so restored data can only have come from the server
- `npm run test:confirm` — the no-session confirm-email signup path, 7 checks

---

## Read this first: the GitHub repo already has an older deployed copy

The repo is **`https://github.com/jammake9/overload-app`**, and its `main`
branch is already live on GitHub Pages at
`https://jammake9.github.io/overload-app/`.

`main` contains an **older** build of the app — `index.html`, `sw.js`,
`manifest.json` and icons, all at the repo root. Verified rather than assumed:

- The file this work is based on has **24 functions that `main` lacks** (rest-timer
  wheel picker, swipe gestures, note editor, retro workouts, measurement-field
  manager, week stats, canvas share cards).
- `main` has two functions this version lacks, and both were **superseded, not
  dropped**: `getWorkoutsThisWeek` → `getWeekActivityMap`/`getWeekStreak`/
  `getWeekPRCount`; `showFinishSummary` → the richer `shareWorkout` /
  `generateShareCardImage` flow.

So this branch is strictly ahead. **The two histories share no common ancestor**
(`main` was built by "Add files via upload" through the web UI), so this cannot
be a fast-forward. Push to a **new branch** — do not force-push over `main`.

### The web app lives in `docs/` so GitHub Pages can serve it — already done

Pages can only serve from the repo root or a `/docs` folder, and Capacitor needs
the web files isolated in their own directory. Those two constraints meet at
`docs/`, so the app directory was renamed from `www/` to `docs/`,
`capacitor.config.json`'s `webDir` updated to match, and a `.nojekyll` file
added (without it, GitHub ignores files beginning with an underscore).

**The remaining step is on the GitHub side:** repo → Settings → Pages → set the
source to the `main` branch, `/docs` folder. Until that's changed it will still
be serving the old root-level `index.html`.

---

## What's left

### 1. Verify against a real Supabase project — blocking, and mine to do

Everything so far is tested against the mock. **Nothing has touched real
Supabase.** I need to follow the README's setup section: create the project, run
`phase1-schema.sql`, paste the URL and anon key into `docs/supabase-config.js`.

Ask me for this. Then check the things the mock can't:

- **RLS actually works.** The mock enforces none. The real test is signing in as
  user B and confirming you cannot read user A's rows.
- Email confirmation and password-reset emails genuinely arrive.
- The `updated_at` trigger fires.

### 2. Known gaps

- **Two devices on one account can clobber each other.** Conflict handling is
  last-write-wins per key, and `updated_at` is recorded but never compared. Two
  phones editing the same key means one silently loses. Fine for one person on
  one device; needs addressing before anyone shares an account.
- **The sync dot is the only sync UI.** No "retry now", no queue view.
- **`history` is rewritten wholesale on every change.** Harmless now, but it's
  the main argument for Phase 3 — after a year of training that blob is
  megabytes, rewritten every time you tick a set.
- **`appId` is still `com.overload.app`** in `capacitor.config.json`. Must
  change to something I control before store submission.
- **The PWA install path is untested on a real phone** — nothing has been
  deployed from this branch yet.
- **This work is not yet on GitHub.** The repo exists
  (`jammake9/overload-app`) but no GitHub account is linked to Claude, so
  sessions get read-only access to it and every push is refused by the proxy
  with `not in this session's authorized repository set`. That is why this
  arrives as a zip. Linking the GitHub account in claude.ai settings, then
  starting a session with that repo as its source, is what unblocks it.

### 3. Phase 3 — the relational migration

Move storage from one-row-per-state-key to the tables in `schema.sql`:
`workouts` → `workout_exercises` → `sets`. Worth doing for `history`; the small
rarely-changing slices (settings, goals, measurement fields) are fine as blobs.

Keep computing PRs by query. Don't cache them.

---

## Environment notes

- `gh` CLI was unavailable, so pushing needs my help.
- Chromium for the tests lives at
  `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`; pass it via `CHROME=`.
  Don't run `playwright install`.
- `@capacitor/assets` **breaks `docs/manifest.json`** when run — wrong icon
  paths, wrong MIME types, everything marked maskable — and deletes
  `docs/favicon-32.png`. Documented at the top of `tools/make-icons.py`.
