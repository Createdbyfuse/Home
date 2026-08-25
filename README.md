# Home

A master record of my working environment — the setups, configs and tooling I rely
on, documented in enough detail that I can rebuild any of them from scratch on any
machine, anywhere, without having to remember how I did it the first time.

Every area lives in its own folder with a README that walks through the setup
step by step, plus the actual files those steps put into place. Clone this repo
onto a fresh machine, pick the areas you need, and work through them.

---

## Areas

| Area | What it covers | Status |
|---|---|---|
| [`Terminal/`](Terminal/) | Windows Terminal + PowerShell — the Nightdrive theme, powerline prompt, startup dashboard, colour schemes, profiles and keybindings. | Documented |

More get added as they're worth capturing. See [Adding a new area](#adding-a-new-area)
below.

---

## Fresh machine, from zero

1. Install git and clone this repo somewhere sensible:

   ```powershell
   winget install --id Git.Git -e
   git clone https://github.com/Createdbyfuse/Home.git
   ```

2. Open the folder for the area you want to set up.
3. Work through its README top to bottom. Each one is self-contained — no
   cross-area dependencies, no assumed ordering.

There's deliberately no single bootstrap script. Setting up a machine is rare
enough, and varies enough between machines, that a script would rot faster than
it would save time. The READMEs are the source of truth.

---

## How this is organised

One folder per area of the environment. Each folder holds:

```
<Area>/
├── README.md      the replication guide — the point of the whole thing
└── files/         the configs and scripts the guide copies into place
```

The split matters. The README explains *what to do and why*; `files/` holds the
things that are too long or too fiddly to retype from instructions. A guide that
says "copy this file to that path" beats one that asks you to hand-transcribe 600
lines of PowerShell.

### What a good area README covers

Written for the version of me who has forgotten all of this and is sitting at an
unfamiliar machine:

- **Prerequisites** — what has to exist first, and which parts are genuinely
  optional versus load-bearing
- **Numbered steps** — copy-pasteable commands, each with a way to verify it
  worked before moving on
- **What the config actually contains** — so it can be adjusted, not just
  installed blindly
- **Design notes** — the decisions and the traps. Anything that cost time to
  figure out the first time gets written down so it doesn't cost time again.
- **How to undo it** — the reverse of every step, including anything it changed
  system-wide
- **Troubleshooting** — symptom, cause, fix

That last group is the part worth the effort. Reinstalling a font is easy;
remembering *why* a file has to keep its BOM is not.

---

## Adding a new area

1. Create the folder and a `files/` subfolder inside it.
2. Copy in the live configs from the machine they currently work on — not a
   cleaned-up idealised version. What's captured should be what actually runs.
3. Write the README following the structure above.
4. Add a row to the [Areas](#areas) table.
5. Commit on a branch, then push.

Candidates worth capturing when the time comes: VS Code settings, keybindings and
extensions; the Claude Code setup (settings, skills, MCP servers, hooks); git
config and global gitignore; SSH and GPG key setup; the winget baseline of
applications for a new machine; Windows itself (Explorer, PowerToys, taskbar,
power settings).

---

## Ground rules

**No secrets.** No keys, tokens, passwords, connection strings or private SSH
keys — not in `files/`, not in the READMEs, not in a commit that gets amended
away later. Document *how* to generate or install a credential; never commit the
credential itself. Git history is permanent, so anything committed once has to be
treated as leaked.

**Capture what's real.** Copy the live config off a working machine. An
aspirational config that was never actually run is worse than nothing, because
it'll be trusted and then fail on the machine where it matters.

**Explain the traps.** The value here isn't the config files — those could be
re-derived. It's the accumulated knowledge of what breaks and why.

**Keep it current.** When a setup changes on the machine, update the area here in
the same sitting. A guide that's quietly six months stale is a guide that wastes
an afternoon the next time it's needed.

---

## Machine of record

Everything here was captured from and verified on:

| | |
|---|---|
| OS | Windows 11 Home 25H2 (build 26200) |
| Shell | Windows PowerShell 5.1 |
| Terminal | Windows Terminal (Store build) |

Areas should stay portable where they reasonably can, but the steps are written
Windows-first and assume `winget` is available.
