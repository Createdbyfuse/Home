# Nightdrive — Terminal Setup

Everything needed to rebuild this Windows Terminal + PowerShell environment from
scratch on a fresh machine. Originally built 2026-08-25 on Windows 11 with
Windows PowerShell 5.1.

The result is a dark "deep-space" terminal with a two-line powerline prompt, a
startup system dashboard, colourised listings, git shorthands, and a pane/tab
keybinding layout.

```
╭─  ADMIN ▶ user@host ▶ ~\dev\project ▶  main ~2 ?1 ▶  v24.19.0 ────── 1.4s ▸ ✗ 1 ▸ 19:22
╰─❯
```

---

## What's in this folder

| Path | What it is | Where it goes on the target machine |
|---|---|---|
| `files/nightdrive.ps1` | The whole theme — palette, prompt, dashboard, helper commands, PSReadLine config. 634 lines. | `%USERPROFILE%\Documents\WindowsPowerShell\nightdrive.ps1` |
| `files/profile.ps1` | Six-line PowerShell auto-load hook that dot-sources the theme. | `%USERPROFILE%\Documents\WindowsPowerShell\profile.ps1` |
| `files/windows-terminal-settings.json` | Full Windows Terminal config — colour schemes, profiles, keybindings, font, acrylic. | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |

Copy this `Terminal` folder to the new machine (USB, git clone, OneDrive — doesn't
matter) and work through the steps below.

---

## Prerequisites

| Needs | Why | Check with |
|---|---|---|
| Windows 10 1903+ / Windows 11 | Windows Terminal, 24-bit colour | `winver` |
| Windows Terminal | The colour scheme, keybindings and acrylic all live here | `wt --version` |
| `winget` | Used to install the font (and Terminal itself if missing) | `winget --version` |
| Git *(optional)* | The prompt's git segment and the `gs`/`ga`/`gp` shorthands | `git --version` |
| Node *(optional)* | The prompt's node segment, shown only in folders with a `package.json` | `node --version` |

Nothing here *requires* git or node — those prompt segments just stay hidden when
the tools aren't present.

If Windows Terminal is missing:

```powershell
winget install --id Microsoft.WindowsTerminal -e
```

---

## Step 1 — Install the Nerd Font

The prompt uses powerline separators and dev icons, which live in the Private Use
Area of a patched "Nerd Font". Without one you get tofu boxes.

```powershell
winget install --id DEVCOM.JetBrainsMonoNerdFont -e
```

That installs **JetBrainsMono Nerd Font 3.3.0** (96 .ttf files — 6 families ×
16 weights) to `C:\Windows\Fonts`.

The three families that matter:

| Family | Font face name to use | Notes |
|---|---|---|
| `JetBrainsMonoNerdFont` | `JetBrainsMono NF` | Variable-width glyphs |
| `JetBrainsMonoNerdFontMono` | **`JetBrainsMono NFM`** | **This is what the config uses.** Every glyph is exactly one cell wide, which is what keeps the prompt's right-hand side aligned. |
| `JetBrainsMonoNerdFontPropo` | `JetBrainsMono NFP` | Proportional |

`NL` in a filename means "No Ligatures" — ignore those; the config enables
ligatures via the font `features` block instead.

Verify the font registered:

```powershell
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts').PSObject.Properties.Name |
  Where-Object { $_ -match 'JetBrainsMono' } | Select-Object -First 5
```

> **Restart Windows Terminal after installing fonts.** It caches the font list at
> launch and will silently fall back to Cascadia if it hasn't seen the new one yet.

---

## Step 2 — Allow local scripts to run

PowerShell refuses to load *any* profile under the default `Restricted` policy.
`RemoteSigned` allows local scripts while still requiring a signature on anything
downloaded from the internet — the normal setting for a dev box.

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Confirm with `Y`. Verify:

```powershell
Get-ExecutionPolicy -List
# CurrentUser should read RemoteSigned
```

This is a **per-user** change and does not need an elevated shell.

---

## Step 3 — Install the PowerShell profile

Windows PowerShell 5.1 reads its per-user, all-hosts profile from
`Documents\WindowsPowerShell\profile.ps1`. Confirm the exact path on the target
machine first — it moves if Documents is redirected to OneDrive:

```powershell
$PROFILE.CurrentUserAllHosts
# C:\Users\<you>\Documents\WindowsPowerShell\profile.ps1
```

Then copy both files, running this from *this* `Terminal` folder:

```powershell
$dest = Split-Path $PROFILE.CurrentUserAllHosts -Parent
New-Item -ItemType Directory -Force $dest | Out-Null

Copy-Item .\files\profile.ps1    -Destination $dest -Force
Copy-Item .\files\nightdrive.ps1 -Destination $dest -Force
```

`profile.ps1` is deliberately tiny — it just finds and dot-sources the theme
sitting next to it:

```powershell
$NightdrivePath = Join-Path $PSScriptRoot 'nightdrive.ps1'
if (Test-Path $NightdrivePath) { . $NightdrivePath }
```

> ### Keep the BOM
>
> `nightdrive.ps1` is saved as **UTF-8 with BOM**, and must stay that way.
> Windows PowerShell 5.1 assumes a BOM-less file is ANSI-encoded, which mangles
> every box-drawing character and Nerd Font glyph in the file into mojibake.
>
> `Copy-Item` preserves it. Re-saving the file from an editor might not — VS Code
> needs "UTF-8 with BOM" chosen explicitly in the encoding picker. Verify:
>
> ```powershell
> Format-Hex "$dest\nightdrive.ps1" -Count 3
> # must start EF BB BF
> ```

### Why two files instead of one

Putting the theme in a separate file means `profile.ps1` stays a hook you can
comment out to get the stock prompt back, without losing the theme. It also
leaves `profile.ps1` free for machine-specific lines (`$env:` vars, PATH edits)
that shouldn't travel between machines.

### If PowerShell 7 is also installed

pwsh 7 uses a *different* profile directory: `Documents\PowerShell\` (no
"Windows"). To theme both shells, copy the same two files there as well —
`nightdrive.ps1` runs fine under both. Check the path with
`$PROFILE.CurrentUserAllHosts` from inside `pwsh`.

---

## Step 4 — Install the Windows Terminal config

Windows Terminal keeps its live settings at:

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

(That path is for the Store build. An unpackaged/portable install instead uses
`%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json`.)

**Launch Windows Terminal once before this step** so it creates the folder and a
default settings file, then back that up and overwrite it:

```powershell
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

Copy-Item $wt "$wt.orig" -Force          # keep the stock file
Copy-Item .\files\windows-terminal-settings.json -Destination $wt -Force
```

Windows Terminal watches this file and reloads within a second — no restart
needed unless you just installed the font.

### Before overwriting, check the Git Bash profile

The config defines a Git Bash profile pointing at
`%ProgramFiles%\Git\bin\bash.exe`. If Git isn't installed on the new machine, or
sits elsewhere, that tab will fail to launch. Either install Git
(`winget install --id Git.Git -e`), fix the `commandline` value, or delete that
profile entry from the `list` array. The same applies to the Claude Code profile,
which runs `claude` and expects the CLI on PATH.

### What the config contains

**Two colour schemes**

| Scheme | Background | Used by |
|---|---|---|
| `Nightdrive` | `#0B0E14` | PowerShell, Git Bash |
| `Nightdrive Void` | `#05070B` — darker, magenta cursor | Claude Code, Command Prompt |

Both share the accent palette the prompt is built on: cyan `#4DE8E0`, blue
`#5AA9FF`, violet `#C792EA`, magenta `#FF6FD8`, green `#5CE6A6`, yellow
`#FFD166`, red `#FF5C7A`.

**Shared profile defaults** — font `JetBrainsMono NFM` at 11pt with `calt`/`liga`
ligatures on, acrylic at 88% opacity, `14, 12, 14, 12` padding, 20 000-line
scrollback, grayscale antialiasing, filled-box cursor, bell off, starts in
`%USERPROFILE%`.

**A custom app theme** (`"theme": "nightdrive"`) darkening the tab row to
`#0B0E14` so the chrome matches the terminal body.

**Four visible profiles**

| Profile | Command | Notes |
|---|---|---|
| PowerShell ⚡ | `powershell.exe -NoLogo` | The default profile |
| Claude Code 🧠 | `powershell.exe -NoLogo -NoExit -Command "claude"` | Sets `NIGHTDRIVE_QUIET=1` so the dashboard doesn't print; 94% opacity |
| Git Bash 🌿 | `"%ProgramFiles%\Git\bin\bash.exe" --login -i` | |
| Command Prompt 🖥️ | `cmd.exe` | |

**Window** — opens at 140×36, `copyOnSelect` on, `trimPaste` on, and `│` added to
the word delimiters so double-click doesn't select across box-drawing characters.

### Keybindings

| Keys | Action |
|---|---|
| `alt+shift+d` / `alt+shift+s` | Split pane right / down |
| `alt+←↑↓→` | Move focus between panes |
| `ctrl+alt+←↑↓→` | Resize the focused pane |
| `ctrl+shift+w` | Close pane |
| `ctrl+shift+z` | Zoom the focused pane |
| `ctrl+shift+1` / `2` / `3` | New PowerShell / Claude Code / Git Bash tab |
| `ctrl+shift+c` / `ctrl+shift+v` | Copy / paste |
| `ctrl+shift+f` | Find |
| `ctrl+shift+p` | Command palette |
| `ctrl+shift+k` | Clear scrollback |
| `ctrl+home` / `ctrl+end` | Scroll to top / bottom |
| `ctrl+,` | Open settings.json |
| `ctrl+=` / `ctrl+-` / `ctrl+0` | Font size up / down / reset |
| `f11` | Fullscreen |

The three `ctrl+shift+<n>` tab bindings reference profiles by **name** through
action IDs (`User.newTab.*`). If you rename a profile in the config, update the
matching `action` block or the key stops working.

---

## Step 5 — Verify

Open a new Windows Terminal tab. You should get the gradient `NIGHTDRIVE` logo,
then SYSTEM / NETWORK / TOOLCHAIN panels, then the two-line prompt.

```powershell
sysinfo      # redraw the dashboard
help-me      # list the custom commands
ll           # colourised listing
```

`cd` into a git repo — a branch segment should appear, green when clean and amber
when dirty. `cd` into a folder with a `package.json` — a node version segment
should appear.

---

## Step 6 (optional) — Upgrade PSReadLine

The theme configures PSReadLine syntax colours, `MenuComplete` on Tab, and
prefix-search on the arrow keys. Two extras — **inline history prediction** and
the **ListView** predictor popup — are gated behind a version check for
PSReadLine ≥ 2.1.0.

Windows 11 ships **2.0.0**, so those stay off by default. To enable them:

```powershell
Install-Module PSReadLine -MinimumVersion 2.3.4 -Scope CurrentUser -Force -AllowClobber
```

Restart the shell. `nightdrive.ps1` detects the new version and turns the
predictor on with no edits needed. Check with `(Get-Module PSReadLine).Version`.

---

## Reference — what the theme gives you

### Prompt segments

Each appears only when it applies:

- **ADMIN** — the shell is elevated
- **user@host** — always
- **path** — home collapses to `~`; paths deeper than four levels ellipsize in the middle
- **git** — branch, `↑`/`↓` ahead/behind, `+` staged, `~` modified, `?` untracked, `!` conflicts, `✓` when clean
- **node** — only in a directory containing `package.json`
- **venv** — only when `$env:VIRTUAL_ENV` is set
- **right side** — duration of the last command (only if it took over 200 ms), its exit code if it failed, and a clock

### Commands

| Command | Does |
|---|---|
| `sysinfo` | Redraw the startup dashboard |
| `ll` / `la` | Colourised listing — folders first, files coloured by extension |
| `help-me` | List these commands |
| `reload` | Re-read the profile without restarting the shell |
| `mkcd <dir>` | `mkdir` + `cd` |
| `touch <file>` | Create a file, or bump its timestamp |
| `which <cmd>` | Resolve a command to its path |
| `..` `...` `....` | Jump up 2 / 3 / 4 directories |
| `gs ga gp gl gd gco gb` | git status / add / push / log-graph / diff / checkout / branch |

`gc` is *not* aliased — it's PowerShell's built-in alias for `Get-Content`, and
shadowing it breaks scripts. The commit shorthand is `gc_`.

### Environment variables

| Variable | Effect |
|---|---|
| `NIGHTDRIVE_QUIET=1` | Skip the startup dashboard. Already set on the Claude Code profile. |

---

## Design notes worth knowing before you edit

**Graceful degradation.** The prompt only emits Nerd Font glyphs when it detects
*both* `$env:WT_SESSION` (so, running under Windows Terminal) *and* a Nerd Font
in the registry. Everywhere else — VS Code's terminal, conhost, an SSH session —
it falls back to plain Unicode (`▶ › § >`) automatically. This is why it stays
readable on machines that never went through Step 1.

**PowerShell variables are case-insensitive.** A loop variable `$k` will silently
overwrite a script-scope `$K`. That is why internals use names like `$script:FGC`
rather than `$script:F` — a real bug hit during the original build.

**Colours are precomputed.** Every palette entry is converted to a 24-bit ANSI
escape sequence once at load, into `$script:FGC`, so rendering the prompt is
string concatenation rather than arithmetic. Keeps it fast enough not to feel
laggy between commands.

**Column widths are coupled.** The dashboard box is 66 columns (`$script:BoxW`),
the `ll` header pads to `6 + 9 + 2 + 18`, and `BRow` uses a 9-wide label column.
Changing one without the others misaligns the box borders.

**`$LASTEXITCODE` is reset.** The prompt function reads the last exit code for the
right-hand error segment, then sets `$global:LASTEXITCODE = 0` so a single failure
doesn't paint every subsequent prompt red.

---

## Undoing it

**Prompt only** — comment out the last line of `profile.ps1`, or delete the file:

```powershell
Remove-Item $PROFILE.CurrentUserAllHosts
```

**Terminal look** — restore the backup made in Step 4:

```powershell
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Copy-Item "$wt.orig" $wt -Force
```

Or just delete `settings.json` — Windows Terminal regenerates a default on next
launch.

**Execution policy**:

```powershell
Set-ExecutionPolicy Restricted -Scope CurrentUser
```

**Font**:

```powershell
winget uninstall --id DEVCOM.JetBrainsMonoNerdFont
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Boxes / tofu instead of icons | Font not installed, or Terminal not restarted since installing it | Step 1, then fully quit and reopen Windows Terminal |
| Prompt shows `▶ § >` instead of powerline glyphs | Not running under Windows Terminal, or the Nerd Font check failed — this is the intentional fallback | Check `$env:WT_SESSION` is set; confirm the font is in the registry |
| Profile doesn't load at all | Execution policy still `Restricted`, or the file is in the wrong folder | Step 2; compare against `$PROFILE.CurrentUserAllHosts` |
| Garbled `â•­â”€` characters everywhere | BOM lost on `nightdrive.ps1` | Re-copy the file, or re-save as UTF-8 **with BOM** |
| Prompt right side is misaligned | Using `JetBrainsMono NF` (variable width) rather than `NFM` (mono) | Set the font face to `JetBrainsMono NFM` |
| Colours look flat / wrong | Colour scheme name mismatch between `profiles.defaults` and the `schemes` array | Both must say `Nightdrive` exactly |
| Git Bash tab won't open | Git installed somewhere other than `%ProgramFiles%\Git` | Fix `commandline` on that profile, or remove it |
| No history predictions | PSReadLine 2.0.0 | Step 6 |
| Dashboard prints on every new Claude Code tab | `NIGHTDRIVE_QUIET` not set on that profile | Check the `environment` block on the Claude Code profile |
