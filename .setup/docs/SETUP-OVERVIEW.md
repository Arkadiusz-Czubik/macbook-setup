# Macbook Setup — Overview

## Aliasy

| Alias | Co robi |
|-------|---------|
| `clp` | Claude Code — konto personal (max) |
| `clw` | Claude Code — konto work (teams) |
| `clyp` | Claude Code YOLO w kontenerze (personal) |
| `clyw` | Claude Code YOLO w kontenerze (work) |
| `bbi` | Brew bundle install z Brewfile |
| `bbe` | Edytuj Brewfile |

## Repozytoria (prywatne, GitHub: Arkadiusz-Czubik)

| Repo | Co zawiera | Gdzie na dysku |
|------|-----------|---------------|
| `macbook-setup` | Dotfiles (chezmoi), Brewfile, bootstrap, security, devcontainer | `~/.local/share/chezmoi/` |
| `claude-personal` | Settings, skills, plugins — konto personal | `~/.claude-personal/` |
| `claude-work` | Settings, skills, hooks, plugins — konto work | `~/.claude-work/` |

## Czysty Mac → gotowe

```bash
xcode-select --install
# install Homebrew
# install 1password, 1password-cli, chezmoi
chezmoi init --apply git@github.com-personal:Arkadiusz-Czubik/macbook-setup.git
~/.local/share/chezmoi/.setup/bootstrap.sh
```

Szczegóły w `bootstrap.sh`.

## SSH

- Dwa klucze: work (`id_ed25519`) i personal (`id_ed25519_github_personal`)
- Oba w 1Password, serwowane przez 1Password SSH Agent
- `~/.ssh/config` routuje: `github.com` → work, `github.com-personal` → personal

## Git

- `~/.gitconfig` — domyślny email: `arek.czubik@gmail.com`
- `~/src-volume/` → automatycznie email `arek@getvolume.com` (includeIf)
- `~/src-private/` → `pull.rebase = true`

## Security

- Deny rules w obu Claude configs: `~/.ssh`, `~/.aws`, `.env*`, `*.pem`, `*.key`, curl/wget/nc
- macOS hardening: firewall + stealth, screensaver lock, auto-updates, Gatekeeper
- YOLO mode tylko w Docker kontenerze z firewallem sieciowym

## 1Password

- Vaults: Personal, Work, AI, HomeLab, Migration (import z Bitwarden)
- SSH Agent: serwuje klucze z Personal i Work vaultów
- CLI: `op` zintegrowany z desktop app (biometric auth)

## Dotfiles (chezmoi)

Zarządzane pliki: `.zshrc`, `.gitconfig`, `.gitconfig-work`, `.gitconfig-personal`, `.ideavimrc`, `.vimrc`, `.p10k.zsh`, `.config/zsh/oh-my-zsh-p10k.zsh`, `.zprofile`, `.bash_profile`, `.ssh/config`
