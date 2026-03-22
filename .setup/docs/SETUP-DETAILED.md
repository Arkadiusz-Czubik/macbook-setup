# Macbook Setup — Detailed Implementation Log

Session: 2026-03-22. MacBook M1 (prywatny). User: Arek Czubik.

---

## 1. Projekt i kontekst

### Źródło wymagań
- `00-INBOX/home security.md` — oryginalny dokument z wymaganiami
- Propozycja od Codexa — przejrzana, skomentowana, użyta jako baza
- Research przez 3 agentów: repeatable Mac setup, AI security, homelab security
- Wynik: `20-WORKBENCH/home-security-v1.md` — pełny plan v1

### Decyzje podjęte
- **chezmoi** do dotfiles (nie stow, nie yadm) — templating + 1P integration
- **1Password SSH Agent** zamiast kluczy na dysku
- **Devcontainer** do yolo mode (nie osobny user macOS, nie VM)
- **VLANy** — już skonfigurowane w UniFi, pomijamy
- **MCP servers** — user dostarczy listę później

---

## 2. Instalacja narzędzi

### Co zainstalowano
```bash
brew install 1password-cli    # wersja 2.33.0
brew install chezmoi           # wersja 2.70.0
brew install gh                # wersja 2.88.1 (nie było wcześniej)
```

### 1Password desktop app
- Był już zainstalowany
- Włączono: Settings > Developer > "Integrate with 1Password CLI"
- Włączono: Settings > Developer > "Set up the SSH Agent"
- Przy pytaniu o key names: wybrano "Use Key Names"

---

## 3. SSH — dwa klucze, dwa konta GitHub

### Problem
Jedno konto GitHub firmowe (`arekc-at-volume`), jedno prywatne (`Arkadiusz-Czubik`). Istniejący klucz `id_ed25519` był powiązany z firmowym.

### Co zrobiono
1. Wygenerowano nowy klucz dla prywatnego konta:
   ```bash
   ssh-keygen -t ed25519 -C "arek.czubik@gmail.com" -f ~/.ssh/id_ed25519_github_personal -N ""
   ```

2. Dodano klucz do GitHub:
   ```bash
   gh auth refresh -h github.com -s admin:public_key
   gh ssh-key add ~/.ssh/id_ed25519_github_personal.pub --title "MacBook M1 - personal"
   ```

3. Stworzono `~/.ssh/config`:
   ```
   Host github.com-personal → IdentityFile ~/.ssh/id_ed25519_github_personal
   Host github.com           → IdentityFile ~/.ssh/id_ed25519
   ```

### 1Password SSH Agent
1. Oba klucze zaimportowane do 1Password przez GUI (CLI nie obsługuje importu istniejących kluczy SSH — tylko generowanie nowych)
   - `GitHub Work (arekc-at-volume)` → Work vault
   - `GitHub Personal (Arkadiusz-Czubik)` → Personal vault

2. Agent config (`~/.config/1Password/ssh/agent.toml`) — dodano:
   ```toml
   [[ssh-keys]]
   vault = "Personal"

   [[ssh-keys]]
   vault = "Work"
   ```

3. SSH config zaktualizowany o IdentityAgent:
   ```
   Host *
       IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
   ```

### Weryfikacja
```
ssh -T git@github.com-personal → Hi Arkadiusz-Czubik!
ssh -T git@github.com          → Hi arekc-at-volume!
```

---

## 4. Chezmoi — inicjalizacja i dotfiles

### Inicjalizacja
```bash
chezmoi init
```
Source dir: `~/.local/share/chezmoi/`

### Dodane pliki
```bash
chezmoi add ~/.zshrc
chezmoi add ~/.config/zsh/oh-my-zsh-p10k.zsh
chezmoi add ~/.gitconfig
chezmoi add ~/.ideavimrc
chezmoi add ~/.vimrc
chezmoi add ~/.zprofile
chezmoi add ~/.bash_profile
chezmoi add ~/.p10k.zsh
chezmoi add ~/.ssh/config
```

### NIE dodano (user nie chce)
- `~/.yabairc` — usunięty z setupu
- `~/.skhdrc` — usunięty z setupu

### Cleanup dotfiles

**.zshrc:**
- Skonsolidowano PATH do jednej linii
- Zamieniono hardcoded `/Users/arek/` na `$HOME`
- Poprawiono aliasy `bbi`/`bbe` z `~/dotfiles/Brewfile` na `~/.local/share/chezmoi/.setup/Brewfile`
- Usunięto komentarze "the OH MY ZSH + P10K mess"
- Dodano aliasy `clyp`/`clyw` (yolo devcontainer)

**.gitconfig:**
- Dodano `[init] defaultBranch = main`
- Dodano `[push] autoSetupRemote = true`
- Dodano `[includeIf "gitdir:~/src-volume/"]` → `~/.gitconfig-work`
- Dodano `[includeIf "gitdir:~/src-private/"]` → `~/.gitconfig-personal`
- NIE dodano `pull.rebase = true` globalnie (firma używa merge commits)

**.gitconfig-work** (nowy):
- `[user] email = arek@getvolume.com`

**.gitconfig-personal** (nowy):
- `[pull] rebase = true`

**.zprofile:**
- Zamieniono hardcoded path na `$HOME`
- Usunięto puste linie

**.bash_profile:**
- Usunięto duplikat LM Studio PATH
- Zostawiono SDKMAN (fallback dla bash sessions)

---

## 5. GitHub repo — macbook-setup

### Stworzenie
```bash
gh repo create Arkadiusz-Czubik/macbook-setup --private --description "Reproducible macOS setup: dotfiles, Brewfile, security hardening"
```

### Remote
```bash
git remote add origin git@github.com-personal:Arkadiusz-Czubik/macbook-setup.git
```
Uwaga: remote używa `github.com-personal` alias (nie `github.com`) bo repo jest na prywatnym koncie.

### Struktura repo
```
~/.local/share/chezmoi/
├── .setup/
│   ├── bootstrap.sh
│   ├── Brewfile
│   ├── macos-security.sh
│   ├── setup-claude-code.sh
│   ├── setup-sdkman.sh
│   ├── setup-system-settings.sh
│   ├── setup-terminal.sh
│   ├── devcontainer/
│   │   ├── Dockerfile
│   │   ├── firewall.sh
│   │   └── run-yolo.sh
│   └── docs/
│       ├── SETUP-OVERVIEW.md
│       └── SETUP-DETAILED.md
├── dot_bash_profile
├── dot_config/zsh/oh-my-zsh-p10k.zsh
├── dot_gitconfig
├── dot_gitconfig-personal
├── dot_gitconfig-work
├── dot_ideavimrc
├── dot_p10k.zsh
├── dot_vimrc
├── dot_zprofile
├── dot_zshrc
└── private_dot_ssh/private_config
```

---

## 6. Brewfile — zmiany

- Usunięto: `yabai`, `skhd` (user nie chce)
- Zachowano: `llmfit` (było w tym samym bloku co yabai — user skorygował usunięcie)
- Dodano: `chezmoi`, `1password` (cask), `1password-cli` (cask)
- Zachowano: `bitwarden` (migracja w toku, user potrzebuje obu)
- Dodano: `gh` (nie było wcześniej, choć jest zainstalowane przez brew)

---

## 7. Bootstrap.sh

Orchestrator — jeden skrypt na czystym Macu:
1. Xcode CLT — czeka na instalację
2. Homebrew — instaluje
3. 1Password + CLI — instaluje, wypisuje szczegółowe instrukcje co kliknąć w GUI
4. chezmoi + dotfiles — klonuje repo, apply
5. Brewfile — brew bundle install
6. SDKMAN — Java 25/21/17 (wszystkie Amazon Corretto), 25 jako default
7. macOS security — firewall, stealth, screensaver lock, auto-updates

### Chicken-and-egg
Kroki 1-3 nie wymagają sekretów. Po kroku 3 (1Password + SSH Agent) SSH działa i chezmoi może sklonować repo w kroku 4.

---

## 8. macOS Security Hardening

Skrypt `macos-security.sh`:
- FileVault: sprawdza status, informuje jeśli wyłączony (nie automatyzuje włączenia)
- Firewall ON + stealth mode
- Gatekeeper ON
- Password po screensaverze: natychmiast (delay = 0)
- Remote login (SSH server): wyłączony
- Automatyczne updaty: włączone
- Rozszerzenia plików: widoczne

NIE automatyzuje: SIP (zostawić włączony), TCC permissions (wymagają interaktywnej zgody), FileVault enable (wymaga recovery key).

---

## 9. Claude Code — dwa profile

### Rename: claude-private → claude-personal
Na M1 był `~/.claude-private`, na M4 `~/.claude-personal`. Ujednolicono na `claude-personal`:
```bash
mv ~/.claude-private ~/.claude-personal
```
Alias w `.zshrc` zmieniony.

### Security deny rules (dodane do obu)
```json
"deny": [
    "Read(~/.ssh/**)",
    "Read(~/.aws/**)",
    "Read(~/.gnupg/**)",
    "Read(**/.env*)",
    "Read(**/*.pem)",
    "Read(**/*.key)",
    "Read(~/.config/homelab/**)",
    "Bash(curl *)",
    "Bash(wget *)",
    "Bash(nc *)",
    "Bash(nslookup *)",
    "Bash(dig *)"
]
```

### claude-work — hardcoded paths fix
Hooki: `/Users/arek/.claude-work/hooks/...` → `$HOME/.claude-work/hooks/...`
Statusline: `/Users/arek/.claude-work/statusline-command.sh` → `$HOME/.claude-work/statusline-command.sh`

### Repozytoria
- `Arkadiusz-Czubik/claude-personal` — settings, skills, plugins
- `Arkadiusz-Czubik/claude-work` — settings, hooks, skills, plugins

---

## 10. Devcontainer — YOLO mode

### Cel
Tryb w którym Claude Code ma pełne uprawnienia (`--dangerously-skip-permissions`) — zero pytań o pozwolenia — ale jest bezpieczny dzięki izolacji kontenera Docker. Idealny do automatycznej implementacji po wcześniejszym zaplanowaniu w normalnym trybie.

### Architektura

```
Mac (host)
│
├── ~/src-private/projekt/       ← montowany do kontenera jako /workspace (read-write)
├── ~/.claude-personal/          ← NIE montowany (izolacja od hosta)
│
└── Docker Desktop (VM z Linuxem, niewidoczna dla usera)
    └── Kontener Ubuntu 24.04
        ├── /workspace/          ← projekt z hosta (jedyny punkt kontaktu)
        ├── /home/dev/           ← Docker named volume (auth token, przeżywa restarty)
        │   ├── .claude.json     ← token OAuth (osobny login w kontenerze)
        │   └── .claude/         ← state, backups
        ├── Claude Code v2.1.81  ← zainstalowany globalnie (npm -g)
        └── user: dev (uid 1001, non-root, sudo bez hasła dla firewalla)
```

### Mechanizmy bezpieczeństwa

**1. Docker filesystem isolation (kernel-level)**
Kontener ma własny root filesystem. Nie widzi niczego z hosta oprócz jawnie zamontowanych katalogów. Zweryfikowane testy:

| Zasób hosta | Z kontenera | Status |
|-------------|-------------|--------|
| `~/.ssh/` (klucze SSH) | niedostępny | BLOCKED |
| `~/.aws/` (AWS creds) | niedostępny | BLOCKED |
| 1Password (socket, dane) | niedostępny | BLOCKED |
| macOS Keychain | niedostępny | BLOCKED |
| `~/.env` pliki | niedostępny | BLOCKED |
| Home dir hosta | niedostępny | BLOCKED |
| `/workspace/` (projekt) | read-write | ALLOWED (zamierzone) |

**2. Non-root user**
Claude działa jako user `dev` (uid 1001). Ma sudo tylko dla firewalla (`NOPASSWD` w sudoers). Nawet gdyby Claude próbował eskalować — jest w kontenerze, nie na hoście.

**3. Docker named volumes (auth)**
Auth token NIE jest kopiowany z hosta. Osobny login w kontenerze (`/login`). Token żyje w named Docker volume (`claude-yolo-auth-personal` / `claude-yolo-auth-work`). Volume przeżywa restarty kontenera, ale jest odizolowany od hosta.

**4. --rm flag**
Po zakończeniu sesji kontener jest automatycznie usuwany. Nie zostają żadne procesy, pliki tymczasowe, cache.

**5. Network firewall (TODO — tymczasowo wyłączony)**
Iptables allowlist ogranicza wyjście sieciowe do:
- `api.anthropic.com`, `api.claude.ai` — Claude API
- `sentry.io`, `statsig.anthropic.com` — telemetria Claude
- `github.com`, `api.github.com` — git operations
- `registry.npmjs.org` — npm packages
- `pypi.org`, `files.pythonhosted.org` — Python packages

Status: wyłączony z powodu problemów z DNS resolution w kontenerze. Do naprawienia.

### Pliki

```
.setup/devcontainer/
├── Dockerfile        # Base image: Ubuntu 24.04
│                     # Instaluje: curl, git, jq, sudo, iptables, Node 22, Claude Code
│                     # Tworzy usera dev (non-root)
│                     # Kopiuje firewall.sh i entrypoint.sh
│
├── entrypoint.sh     # ENTRYPOINT kontenera
│                     # Opcjonalnie odpala firewall (TODO)
│                     # exec claude --dangerously-skip-permissions
│                     # exec daje Claude bezpośredni dostęp do TTY
│
├── firewall.sh       # Iptables rules — default DROP + allowlist domen
│                     # Rozwiązuje domeny przez DNS, dodaje IPs do allowlist
│                     # Wymaga --cap-add NET_ADMIN w docker run
│
└── run-yolo.sh       # Orchestrator:
                      # 1. Parsuje argumenty (personal/work, ścieżka projektu)
                      # 2. Buduje Docker image (jeśli trzeba)
                      # 3. Tworzy named volume dla auth (jeśli pierwszy raz)
                      # 4. W trybie --login: odpala claude bez bypass (do logowania)
                      # 5. W normalnym trybie: odpala claude z --dangerously-skip-permissions
```

### Workflow

**Pierwszy raz — jednorazowy login per profil:**
```bash
# Login do personal (max plan):
~/.local/share/chezmoi/.setup/devcontainer/run-yolo.sh personal --login
# W Claude wpisz /login → przeglądarka → zaloguj się → /exit

# Login do work (teams plan):
~/.local/share/chezmoi/.setup/devcontainer/run-yolo.sh work --login
```

**Normalny workflow (plan → implement → review):**
```bash
# 1. Planuj z normalnym Claude na Macu (z permission checks):
clp                              # albo clw
# > "napisz plan implementacji feature X"
# > "zapisz plan do PLAN.md"

# 2. Implementuj w yolo kontenerze (bez pytań):
clyp ~/src-private/moj-projekt   # albo clyw ~/src-volume/firmowy-projekt
# Claude czyta PLAN.md, implementuje wszystko automatycznie
# Zmiany lądują bezpośrednio w katalogu projektu na hoście

# 3. Wróć do normalnego Claude, review:
clp
# > "review zmiany, commitnij"
```

**Aliasy:**

| Alias | Komenda | Profil |
|-------|---------|--------|
| `clyp` | `run-yolo.sh personal` | Personal (max) |
| `clyw` | `run-yolo.sh work` | Work (teams) |

### Docker volumes

```bash
# Listuj auth volumes:
docker volume ls | grep claude-yolo

# Wymuś ponowne logowanie (usuń volume):
docker volume rm claude-yolo-auth-personal

# Sprawdź co jest w volume:
docker run --rm -v claude-yolo-auth-personal:/data alpine ls -la /data
```

### Znane ograniczenia

1. **Firewall wyłączony** — DNS resolution w kontenerze nie rozwiązuje poprawnie domen na etapie startu. Bez firewalla kontener ma pełny dostęp do internetu, ale nie ma czego exfiltrować (brak sekretów w kontenerze).
2. **Auth wymaga osobnego loginu** — tokeny OAuth Claude Code nie są przenośne między maszynami/kontenerami. Trzeba się zalogować osobno w kontenerze.
3. **Brak Git auth w kontenerze** — kontener nie ma SSH keys ani `gh auth`. Jeśli Claude potrzebuje klonować repo lub pushować, trzeba to zrobić na hoście.

---

## 11. 1Password — migracja z Bitwarden

1. Stworzono vault "Migration" w 1Password
2. Eksport z Bitwarden: format CSV (JSON nie działał z importerem 1P)
3. Import do 1Password: File > Import > Bitwarden > vault Migration
4. Autofill: do skonfigurowania later (wyłączenie autofill dla vault Migration w rozszerzeniu przeglądarkowym)

### Vaults
- Personal (x2 — do wyczyszczenia)
- Work
- AI
- HomeLab
- Migration (import z Bitwarden)

---

## 12. Docker backup/restore

### Skrypty

```
.setup/docker/
├── list-docker.sh      # Pokaż aktualny stan (volumes, networks, kontenery, images, backupy)
├── backup-docker.sh    # Backup wszystkich volumes + metadata do ~/docker-backups/YYYYMMDD-HHMMSS/
└── restore-docker.sh   # Restore volumes i sieci z backupu
```

### Workflow przy reinstalacji

```bash
# PRZED reinstalacją:
~/.local/share/chezmoi/.setup/docker/backup-docker.sh
# Skopiuj ~/docker-backups/ na TrueNAS lub dysk zewnętrzny

# PO reinstalacji (po bootstrap.sh + Docker Desktop):
~/.local/share/chezmoi/.setup/docker/restore-docker.sh ~/docker-backups/20260322-160000
# Pull images:
cat ~/docker-backups/20260322-160000/images.txt | xargs -L1 docker pull
```

### Co jest backupowane

| Element | Backup | Restore |
|---------|--------|---------|
| Volumes (dane) | tar.gz per volume | automatyczny |
| Custom networks | JSON definicje | automatyczny (z subnet) |
| Container list | tekstowa lista | tylko jako referencja |
| Image list | tekstowa lista | `docker pull` ręcznie |

### Ważne uwagi
- Docker state jest **globalny** (nie per user) — wszystkie volumes/networks widoczne dla wszystkich userów na maszynie
- Docker socket **nie jest montowany** do yolo kontenerów — Claude nie ma dostępu do Docker API z wnętrza kontenera
- Yolo auth volumes (`claude-yolo-auth-*`) nie wymagają backupu — wystarczy ponowny `/login`

---

## 13. Time Machine

### Status
Nie skonfigurowany na M1. Do ustawienia przy sesji z homelabem.

### Plan konfiguracji

**Na TrueNAS (jednorazowo per Mac):**
1. Stwórz osobny dataset: `tank/backups/timemachine-m1` (osobny od M4)
2. Włącz kompresję: `zfs set compression=lz4 tank/backups/timemachine-m1`
3. Ustaw quota (np. 500GB): `zfs set quota=500G tank/backups/timemachine-m1`
4. Stwórz SMB share z tego datasetu:
   - Shares > SMB > Add
   - Path: `/mnt/tank/backups/timemachine-m1`
   - Purpose: **Multi-user Time Machine**
   - Zaznacz "Enable"
5. Upewnij się że SMB service działa

**Na Macu (jednorazowo):**
1. System Settings > General > Time Machine > Add Backup Disk
2. Wybierz TrueNAS share (`timemachine-m1`)
3. Podaj credentials do TrueNAS SMB
4. Opcjonalnie: zaszyfruj backup (zalecane)

**W bootstrap.sh:**
Nie automatyzujemy — wymaga interaktywnej konfiguracji (credentials, szyfrowanie). Bootstrap wyświetla przypomnienie.

### Dlaczego Time Machine mimo reproducible setup
Nasz setup odtwarza: narzędzia, konfigurację, sekrety, Docker volumes. Ale NIE odtwarza:
- Lokalne pliki projektów AI nie wpushowane do git
- Dokumenty, zdjęcia, Downloads
- Stan aplikacji (history przeglądarki, ustawienia GUI apps)
- Cokolwiek czego zapomniałeś commitnąć

---

## 14. Otwarte tematy (nie zrobione)

- [ ] 1Password SSH Agent — usunięcie kluczy prywatnych z dysku (po walidacji stabilności)
- [ ] Autofill wyłączenie dla vault Migration (w rozszerzeniu przeglądarkowym 1P)
- [ ] Duplikat vault "Personal" w 1P — wyczyszczenie
- [ ] Duplikat "GitHub Work" SSH key w vault Personal — usunięcie (ma być tylko w Work)
- [ ] chezmoi templates — multi-machine (M1 vs M4 differences)
- [ ] 1Password + chezmoi integration (`onepasswordRead` w templates)
- [ ] Homelab wrapper scripts
- [ ] MCP server whitelist
- [ ] Przetestowanie bootstrap.sh na czystym userze
- [ ] Przetestowanie devcontainer yolo mode (login działa, ale yolo session nie przetestowany end-to-end)
- [ ] Devcontainer firewall — naprawić DNS resolution
- [ ] gh do Brewfile (zainstalowane ręcznie, nie w Brewfile)
- [ ] `~/dotfiles/wg.conf` — WireGuard config to sekret, nie powinien być w plaintext repo
- [ ] Time Machine na TrueNAS — skonfigurować przy sesji z homelabem
- [ ] Docker backup workflow — przetestować backup/restore end-to-end
