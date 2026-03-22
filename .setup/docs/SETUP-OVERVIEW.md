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

---

## YOLO Mode — Devcontainer

### Co to jest

Izolowany kontener Docker w którym Claude Code działa z pełnymi uprawnieniami (`--dangerously-skip-permissions`) — zero pytań o pozwolenia. Bezpieczny bo kontener nie ma dostępu do niczego poza projektem.

### Jak to działa (architektura)

```
Mac (host)
├── ~/.claude-personal/          ← auth token (NIE montowany do kontenera)
├── ~/src-private/moj-projekt/   ← montowany jako /workspace
│
└── Docker Desktop
    └── Kontener (Ubuntu 24.04)
        ├── /workspace/          ← Twój projekt (read-write, montowany z hosta)
        ├── /home/dev/           ← Docker volume z auth tokenem (przeżywa restarty)
        ├── Claude Code          ← zainstalowany globalnie w kontenerze
        └── user: dev (non-root)
```

### Mechanizmy bezpieczeństwa

| Warstwa | Co chroni |
|---------|-----------|
| **Docker filesystem isolation** | Kontener nie widzi hosta — brak dostępu do `~/.ssh`, `~/.aws`, 1Password, Keychain, home dir |
| **Non-root user** | Claude działa jako `dev`, nie jako root |
| **Montowanie tylko projektu** | Jedyny katalog z hosta to Twój projekt w `/workspace` |
| **Auth w Docker volume** | Token w nazwanym volume, nie kopiowany z hosta — osobny login per profil |
| **--rm flag** | Kontener znika po zakończeniu — nie zostają żadne śmieci |
| **Firewall (TODO)** | Iptables allowlist — tylko Claude API, GitHub, npm, pypi |

### Zweryfikowane testy izolacji

```
Host home dir:  BLOCKED
SSH keys:       BLOCKED
AWS creds:      BLOCKED
1Password:      BLOCKED
.env files:     BLOCKED
Mac Keychain:   BLOCKED
User:           dev (non-root, uid 1001)
```

### Użycie

**Pierwszy raz — login (raz per profil):**
```bash
~/.local/share/chezmoi/.setup/devcontainer/run-yolo.sh personal --login
# W Claude wpisz /login, przejdź auth flow, potem /exit
```

**Normalny workflow:**
```bash
# 1. Napisz plan z normalnym Claude (na Macu)
clp
# > napisz plan, stwórz task file, etc.

# 2. Odpal implementację w yolo kontenerze
clyp ~/src-private/moj-projekt
# Claude czyta plan, implementuje bez pytania o pozwolenia

# 3. Wróć do normalnego Claude, zrób review
clp
# > review zmian, commit, push
```

**Aliasy:**
```bash
clyp                          # yolo personal, bieżący katalog
clyp ~/src-private/projekt    # yolo personal, konkretny projekt
clyw                          # yolo work, bieżący katalog
clyw ~/src-volume/projekt     # yolo work, konkretny projekt
```

### Pliki devcontainera

```
.setup/devcontainer/
├── Dockerfile      # Ubuntu 24.04 + Node 22 + Claude Code + user dev
├── entrypoint.sh   # Startuje claude --dangerously-skip-permissions
├── firewall.sh     # Iptables allowlist (TODO: do naprawienia)
└── run-yolo.sh     # Orchestrator — buduje image, zarządza volumes, odpala kontener
```

### Docker volumes (auth)

```bash
# Listuj volumes z auth tokenami:
docker volume ls | grep claude-yolo

# Wymuś ponowne logowanie (usuń volume):
docker volume rm claude-yolo-auth-personal
docker volume rm claude-yolo-auth-work
```
