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

### Architektura
Docker container (Ubuntu 24.04) z:
- Claude Code zainstalowany globalnie
- Network firewall (iptables) — tylko Claude API, GitHub, npm, pypi
- Non-root user `dev`
- Projekt zamontowany w `/workspace`
- Auth token z `~/.claude-{personal,work}/.claude.json` zamontowany read-only

### Pliki
- `Dockerfile` — Ubuntu 24.04, Node 22, Claude Code, user dev
- `firewall.sh` — iptables allowlist (api.anthropic.com, api.claude.ai, github.com, registry.npmjs.org, pypi.org)
- `run-yolo.sh` — orchestrator, parametr `personal`/`work`

### Użycie
```bash
clyp                          # yolo personal, bieżący dir
clyw                          # yolo work, bieżący dir
clyp ~/src-private/projekt    # yolo personal, konkretny projekt
```

### Bezpieczeństwo
- `.claude.json` read-only — kontener nie może zmienić auth
- Brak dostępu do: `~/.ssh`, `~/.aws`, 1Password, Keychain, home dir
- Sieć: tylko whitelistowane domeny
- Po `docker run --rm` — kontener znika, nic nie zostaje

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

## 12. Otwarte tematy (nie zrobione)

- [ ] 1Password SSH Agent — usunięcie kluczy prywatnych z dysku (po walidacji stabilności)
- [ ] Autofill wyłączenie dla vault Migration (w rozszerzeniu przeglądarkowym 1P)
- [ ] Duplikat vault "Personal" w 1P — wyczyszczenie
- [ ] Duplikat "GitHub Work" SSH key w vault Personal — usunięcie (ma być tylko w Work)
- [ ] chezmoi templates — multi-machine (M1 vs M4 differences)
- [ ] 1Password + chezmoi integration (`onepasswordRead` w templates)
- [ ] Homelab wrapper scripts
- [ ] MCP server whitelist
- [ ] Przetestowanie bootstrap.sh na czystym userze
- [ ] Przetestowanie devcontainer yolo mode
- [ ] gh do Brewfile (zainstalowane ręcznie, nie w Brewfile)
- [ ] `~/dotfiles/wg.conf` — WireGuard config to sekret, nie powinien być w plaintext repo
