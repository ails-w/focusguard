# focusguard

> Restrict a Linux user account to a schedule — gate it with PAM, enforce it with systemd,
> and lock the configuration with `chattr +i`.

![Linux](https://img.shields.io/badge/OS-Linux-informational)
![systemd](https://img.shields.io/badge/init-systemd-blue)
![PAM](https://img.shields.io/badge/auth-PAM-purple)
![License](https://img.shields.io/badge/license-MIT-green)

> **Status:** building in public, module by module.

## Problem it solves

Blocking an account by schedule is easy to get half-right — and the half that's missing is
the part that hurts. A timer that kicks the user out does nothing if they can log straight
back in. A login gate does nothing for the session that's already open. And the obvious way
to kick someone out (`pkill -KILL -u`) can leave your machine stuck on a **black screen with
a blinking cursor**, because the display manager never gets its greeter back.

`focusguard` combines three independent mechanisms so none of those holes is left open, and
it handles session teardown the way the display manager expects.

It is a **self-control** tool, not a security boundary: the honest promise is *deliberate,
reverted and audited* — not "unbreakable".

## How it works

| # | Layer | What it does | Module |
|---|-------|--------------|--------|
| 0 | Base | Single config source + shared audit helper | [`00-base`](modules/00-base/) |
| 1 | PAM gate | Denies login (graphical, console, ssh) and `sudo` outside the window | [`01-pam-gate`](modules/01-pam-gate/) |
| 2 | Enforcement | Terminates the session when the window ends — greeter watchdog + resume guard | [`02-enforce`](modules/02-enforce/) |
| 3 | Integrity | Golden copy + `chattr +i` + a minute-by-minute restore | [`03-integrity`](modules/03-integrity/) |
| 4 | Disarm | Deliberate, delayed, audited off-switch | [`04-disarm`](modules/04-disarm/) |

Diagrams: [enforcement flow](docs/diagrams/enforcement-flow.md) ·
[session lifecycle](docs/diagrams/session-lifecycle.md).

## Quickstart

```bash
git clone https://github.com/ails-w/focusguard.git
cd focusguard
sudo scripts/install.sh --dry-run   # see the plan
sudo scripts/install.sh             # install all five modules
sudo scripts/verify.sh              # check every layer
```

Then **edit `/etc/focusguard/policy.conf`** with your user and your windows, and re-arm:

```bash
sudo focusguard-disarm      # unlock to edit
sudo focusguard-apply       # regenerate time.conf
sudo focusguard-lock        # new golden + lock
sudo systemctl start focusguard-enforce.timer focusguard-integrity.timer
```

Prefer manual? Each layer is self-contained under [`modules/`](modules/) with its own
apply / verify / rollback README.

## What I learned / Key decisions

- **Two mechanisms, not one.** The PAM gate stops *entry*; the timer removes an *open
  session*. With only a timer the user logs back in instantly; with only PAM they stay in
  after the window ends. You need both.
- **Never `SIGKILL` a graphical session.** The display manager watches *how* its helper
  exits: cleanly (0) and it relaunches the greeter; abnormally (1) and it can hang. The
  first version used `pkill -KILL -u`; the result was a black screen with a blinking `_`.
  `loginctl terminate-user` does an ordered shutdown and escalates on its own.
- **Add a greeter watchdog anyway.** Even with the ordered path, verify the greeter came
  back; if not in 40 s, restart the display manager. Turn "black screen, force power-off"
  into "self-recovery".
- **Guard against suspend/resume races.** The original failure happened right after a lid
  open, while the DRM was re-initializing. Skipping the first pass after a resume costs one
  minute and removes the worst-case timing.
- **`chattr +i` is friction, not a boundary.** Root can remove it. Its value is making
  deactivation deliberate, self-reverting and audited.
- **Keep guards separate by lifecycle.** Config integrity for *network/browser* files lives
  in a different tool (`dns-doh-lockdown`'s `netguard`): editing the firewall must not
  disarm your usage block, and vice versa.
- **An emergency switch must not read the config it may need to repair.** `focusguard-disarm`
  deliberately does **not** source `policy.conf`: if you broke the policy file, you still
  need a way out.

## Known limitations

- **Not a wall against root**, `NOPASSWD`, or powerful groups (`docker` ≈ root).
- **Physical access / live USB / rescue boot** bypasses everything.
- **System clock changes** affect both the PAM rule and the timer.
- **One user per install** (`policy.conf` defines a single account).
- **Windows crossing midnight** are not supported by the current time check.

Full, honest list: [`docs/threat-model.md`](docs/threat-model.md).

## Documentation

| Area | Document |
|------|----------|
| How the layers fit together | [`docs/architecture.md`](docs/architecture.md) |
| What it protects — and what it does not | [`docs/threat-model.md`](docs/threat-model.md) |
| Install order | [`docs/install.md`](docs/install.md) |
| How to verify | [`docs/verification.md`](docs/verification.md) |
| Something broke | [`docs/troubleshooting.md`](docs/troubleshooting.md) |
| Concepts, module by module | [`docs/learning/`](docs/learning/) |
| Diagrams | [`docs/diagrams/`](docs/diagrams/) |

## Repository layout

```text
modules/   one self-contained module per capability (files + apply/verify README)
docs/      architecture, threat model, install, verification, learning, diagrams
scripts/   install / uninstall / verify helpers
```

## Roadmap

- [ ] Support multiple restricted users
- [ ] Windows crossing midnight
- [ ] CI: `shellcheck` + `markdownlint`
- [ ] `PKGBUILD` for the AUR
- [ ] Optional: lock additional files using full-path golden names

## License

MIT — see [LICENSE](LICENSE).
