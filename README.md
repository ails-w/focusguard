# focusguard

> Block a Linux user account to a schedule — gate it with PAM, enforce it with systemd,
> and lock the configuration with `chattr +i`.

> **Status:** building in public, module by module.

## How it works

| # | Layer | What it does | Module |
|---|-------|--------------|--------|
| 0 | Base | Single config source + shared audit helper | `modules/00-base` |
| 1 | PAM gate | Denies login and `sudo` outside the allowed window | `modules/01-pam-gate` |
| 2 | Enforcement | Terminates the session when the window ends (greeter watchdog + resume guard) | `modules/02-enforce` |
| 3 | Integrity | Golden copy + `chattr +i` + a minute-by-minute check | `modules/03-integrity` |
| 4 | Disarm | Deliberate, delayed, audited off-switch | `modules/04-disarm` |

Three mechanisms, one goal: make using the restricted account outside its window
**deliberate, reverted and audited** — not impossible (that would need removing `sudo`).

## Documentation

| Area | Document |
|------|----------|
| How the layers fit together | `docs/architecture.md` |
| What it protects — and what it does not | `docs/threat-model.md` |
| Install order | `docs/install.md` |
| How to verify | `docs/verification.md` |
| Something broke | `docs/troubleshooting.md` |
| Concepts, module by module | `docs/learning/` |
| Diagrams | `docs/diagrams/` |

## Repository layout

```text
modules/   one self-contained module per capability (files + apply/verify README)
docs/      architecture, threat model, install, verification, learning, diagrams
scripts/   install / uninstall / verify helpers
```

## License

MIT — see [LICENSE](LICENSE).
