#!/bin/bash
# seed.sh — ZASIEW: jedyny plik uruchamiany SPOZA repozytorium
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/Arkadiusz-Czubik/macbook-seed/main/seed.sh)
#
# Realizuje D-030. Odpowiada na pytanie, na które przez trzy sesje nie było
# odpowiedzi: CZYM ŚCIĄGNĄĆ PIERWSZY PLIK. Testy z sesji 2 i 3 montowały katalog
# z hosta (tart --dir), czyli startowały ze stanu, w którym deklaracja JUŻ LEŻAŁA
# na maszynie. Przy prawdziwej odbudowie ten stan nie zachodzi — to była luka 3.
#
# ŹRÓDŁO PRAWDY tego pliku to control-plane/bootstrap/seed.sh. Kopia w publicznym
# repo macbook-seed jest publikacją, nie oryginałem. Rozjazd = błąd publikacji.
# Repo nazywało się macbook-setup do 2026-08-02 — nazwa zmieniona w D-038, bo
# „setup" nie znaczyło nic i repo zbierało wszystko. Teraz trzyma jeden plik.
#
# ═══════════════════════════════════════════════════════════════════════════
# KOLEJNOŚĆ JEST WIĄŻĄCA i ustalona przez Ariusza (D-030):
#
#   1Password → Homebrew (Xcode CLT bezgłowo) → git → klon prywatnego repo
#
# Wariant odrzucony szedł najpierw Homebrew, a poświadczenie do prywatnego repo
# wklejało się ręcznie jako token. Przyjęty jest lepszy, bo ŻADNE POŚWIADCZENIE
# NIE OPUSZCZA SEJFU — cel 5 Chartera. Agent SSH oddaje przez socket wyłącznie
# klucze PUBLICZNE; podpisuje u siebie, materiał prywatny nigdy go nie opuszcza.
# ═══════════════════════════════════════════════════════════════════════════
#
# CO TEN PLIK MOŻE, A CZEGO NIE:
#   może   — położyć 1Password, zasiać ~/.ssh/config i known_hosts, postawić
#            Homebrew, sklonować repo i oddać sterowanie bootstrap.sh
#   nie może — zalogować do 1Password ani włączyć agenta SSH. To jest TCC
#            i biometria, czyli poza zasięgiem skryptu bez MDM (R-013).
#
# Publiczny, więc: ZERO sekretów, zero referencji op://, zero nazw kont firmowych.
# Nazwa konta prywatnego i tak jest w adresie repozytorium; konto firmowe jest
# WYKRYWANE, nie wpisane, żeby publiczny plik nie łączył obu tożsamości.
#
# bash 3.2 — świeży macOS, przed Homebrew.

set -euo pipefail

REPO_OWNER="Arkadiusz-Czubik"
REPO_NAME="control-plane"
# ~/src-private/, nie ~/ (D-042). Ten katalog jest już nazwany w dot_gitconfig
# przez [includeIf "gitdir:~/src-private/"], więc klon od razu łapie właściwą
# tożsamość gita i przestaje być wyjątkiem stojącym samotnie w katalogu domowym
# obok ~/src-volume/. 'git clone' tworzy katalogi nadrzędne sam — 'mkdir -p'
# byłby tu zbędny (sprawdzone 2026-08-02).
CLONE_DIR="$HOME/src-private/$REPO_NAME"

OP_TEAM_ID="2BUA8C4S2C"
OP_PKG_URL="https://downloads.1password.com/mac/1Password.pkg"
OP_AGENT_SOCK="$HOME/Library/Group Containers/${OP_TEAM_ID}.com.1password/t/agent.sock"

GITHUB_META="https://api.github.com/meta"
BREW_INSTALL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# --assume-agent: pomija Z1–Z3 i używa agenta wskazanego przez SSH_AUTH_SOCK.
# Po to, żeby dało się przetestować Z4–Z7 w maszynie wirtualnej BEZ SESJI
# GRAFICZNEJ — agent jest wtedy przekazany z hosta przez 'ssh -A'. Kroki Z1–Z3
# wymagają klikania i tak (R-013), więc test bezgłowy ich nie obejmie nigdy.
ASSUME_AGENT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --assume-agent) ASSUME_AGENT=1 ;;
    --repo-owner)   REPO_OWNER="$2"; shift ;;
    --clone-dir)    CLONE_DIR="$2";  shift ;;
    *) printf 'nieznany argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\n\033[1;33m/!\\\033[0m %s\n' "$1"; }
die()  { printf '\n\033[1;31m✗\033[0m %s\n' "$1" >&2; exit 1; }

# Skrypt biegnie przez potok, więc STDIN to on sam — 'read' zjadłby własny kod
# zamiast czekać na człowieka. Wejście człowieka idzie z /dev/tty.
# To ta sama klasa błędu co A0 z R-018: krok zakładał terminal tam, gdzie go nie było.
#
# TESTUJEMY OTWARCIEM, nie prawami dostępu. '[ -r /dev/tty ]' zwraca prawdę
# w sesji BEZ terminala: plik urządzenia istnieje i ma prawa rw, ale otwarcie
# kończy się 'Device not configured' (ENXIO). Zmierzone w VM przez ssh bez -t:
# zasiew uznawał, że terminal jest, i umierał na 'exec … < /dev/tty'.
# Jedyny wiarygodny test to próba otwarcia — w podpowłoce, żeby nie zaśmiecić
# deskryptorów skryptu.
TTY=""
if (exec 3<>/dev/tty) 2>/dev/null; then TTY=/dev/tty; fi

manual() {
  printf '\n\033[1;35m[RĘCZNIE]\033[0m %s\n' "$1"
  [ -n "$TTY" ] || die "krok ręczny bez terminala — uruchom zasiew z okna Terminala.
   W trybie bezgłowym użyj --assume-agent (pomija Z1–Z3)."
  printf '   Naciśnij Enter, gdy skończysz. Ctrl-C przerywa.\n'
  read -r _ < "$TTY"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ "$(uname -s)" = "Darwin" ] || die "ten zasiew jest dla macOS"

# ═══════════════════════════════════════════════════════════════════════════
# Z1 — 1Password
# ═══════════════════════════════════════════════════════════════════════════
# Instalujemy z .pkg przez 'installer', NIE z .zip.
# Sprawdzone 2026-08-02: 1Password.zip (24,9 MB) to STUB GUI — rozpakowuje się
# jako „1Password Installer.app", którą trzeba kliknąć. Dokładałby krok ręczny
# tam, gdzie system radzi sobie bez człowieka (ten sam błąd co dawne
# 'xcode-select --install', R-014 ustalenie 4). .pkg (382 MB) idzie bezgłowo.
if [ "$ASSUME_AGENT" -eq 1 ]; then
  say "Z1–Z3 pominięte (--assume-agent): agent przekazany z zewnątrz"
else
  if [ -d /Applications/1Password.app ]; then
    say "Z1. 1Password już jest w /Applications — pomijam"
  else
    say "Z1. 1Password — pobieranie (382 MB) i instalacja"
    curl -fL --progress-bar -o "$TMP/1Password.pkg" "$OP_PKG_URL" \
      || die "nie udało się pobrać 1Password"

    # Weryfikacja podpisu PRZED instalacją. Ten plik przychodzi z sieci i dostaje
    # roota, więc zaufanie musi być sprawdzone, nie założone.
    # Wynik przypisany do zmiennej, nie przepuszczony przez 'grep -q': grep
    # zamyka potok po pierwszym trafieniu, pkgutil dostaje SIGPIPE, a 'pipefail'
    # zamienia UDANĄ weryfikację w błąd skryptu.
    SIG="$(pkgutil --check-signature "$TMP/1Password.pkg" 2>&1 || true)"
    case "$SIG" in
      *"$OP_TEAM_ID"*) : ;;
      *) die "podpis 1Password.pkg nie wskazuje AgileBits ($OP_TEAM_ID). PRZERWANE." ;;
    esac
    case "$SIG" in
      *"trusted by the Apple notary service"*) : ;;
      *) die "1Password.pkg nie jest notaryzowany. PRZERWANE." ;;
    esac
    say "    podpis OK: AgileBits Inc. ($OP_TEAM_ID), notaryzowany"

    # sudo czyta hasło z /dev/tty, nie ze STDIN — więc działa także przez potok.
    sudo installer -pkg "$TMP/1Password.pkg" -target / \
      || die "installer nie położył 1Password"
  fi

  # ═════════════════════════════════════════════════════════════════════════
  # Z2 — logowanie · RĘCZNIE
  # ═════════════════════════════════════════════════════════════════════════
  manual "Z2. Zaloguj się do 1Password (otwórz je z /Applications).

   1. logowanie do konta 1Password.com
   2. adres logowania:  my.1password.com
   3. e-mail konta
   4. SECRET KEY — z Emergency Kitu, format A3-XXXXXX-…
   5. hasło główne
   6. drugi składnik — Authy

   Secret Key, hasło główne i 2FA są POZA 1Password i tak musi być: korzeń
   zaufania nie może zawierać sam siebie. To jest cały sens Z-004.
   Jeśli nie masz teraz Emergency Kitu — przerwij (Ctrl-C). Bez niego dalej
   nie ma jak przejść, a odbudowa bez sejfu jest bezcelowa."

  # ═════════════════════════════════════════════════════════════════════════
  # Z3 — agent SSH · RĘCZNIE
  # ═════════════════════════════════════════════════════════════════════════
  manual "Z3. Włącz agenta SSH w 1Password.

   • Ustawienia → Developer → Use the SSH agent
   • Ustawienia → Security → odblokowanie przez Touch ID

   Agent jest jedyną drogą do prywatnego repo w kroku Z6. Bez niego zasiew
   zatrzyma się na braku socketu."
fi

# ═══════════════════════════════════════════════════════════════════════════
# Z4 — klucze publiczne z agenta i zasiew ~/.ssh
# ═══════════════════════════════════════════════════════════════════════════
say "Z4. Odczyt kluczy publicznych z agenta i zasiew ~/.ssh"

if [ "$ASSUME_AGENT" -eq 1 ]; then
  SOCK="${SSH_AUTH_SOCK:-}"
  [ -n "$SOCK" ] || die "--assume-agent, ale SSH_AUTH_SOCK jest pusty"
else
  SOCK="$OP_AGENT_SOCK"
fi
[ -S "$SOCK" ] || die "brak socketu agenta: $SOCK
   Jeśli 1Password jest zalogowany, sprawdź Ustawienia → Developer → Use the SSH agent."

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# ─── known_hosts z api.github.com ──────────────────────────────────────────
# Klucze hosta bierzemy z API po TLS, NIE przez 'StrictHostKeyChecking=accept-new'.
# accept-new to zaufanie pierwszemu, kto odpowie (TOFU) — na czystej maszynie
# w nieznanej sieci to najgorszy możliwy moment na taki skrót. Tu zaufanie
# opiera się na certyfikacie api.github.com, który system już zna.
# Nie na wpisanych na sztywno kluczach: GitHub rotował klucz RSA w 2023 i wpis
# w skrypcie zamieniłby się wtedy w cichą awarię.
say "    klucze hosta github.com z $GITHUB_META"
curl -fsSL --max-time 30 "$GITHUB_META" \
  | sed -n '/"ssh_keys"/,/]/p' \
  | grep -o '"[a-z0-9-]* AAAA[^"]*"' \
  | tr -d '"' \
  | sed 's/^/github.com /' > "$TMP/known_hosts.github" || true

[ -s "$TMP/known_hosts.github" ] \
  || die "nie udało się pobrać kluczy hosta GitHuba — bez nich nie weryfikujemy serwera"

KH="$HOME/.ssh/known_hosts"
touch "$KH"
grep -v '^github\.com ' "$KH" > "$TMP/known_hosts.rest" || true
cat "$TMP/known_hosts.rest" "$TMP/known_hosts.github" > "$KH"
chmod 600 "$KH"
say "    known_hosts: $(grep -c '^github\.com ' "$KH") kluczy hosta github.com"

# ─── rozpoznanie kluczy ────────────────────────────────────────────────────
# Które konto jest które — ustalamy ODPOWIEDZIĄ SERWERA, nie nazwą pozycji
# w sejfie. Nazwa jest opisem, odpowiedź jest faktem (D-025). Na M1 nazwy były
# zresztą mylące: pozycja „GitHub" nie należała do żadnego z dwóch kont (R-016).
#
# Zmierzone na M1, 2026-08-02, na żywym agencie — wszystkie trzy przypadki:
#   „GitHub"                             → agent ODMAWIA podpisu, klucz pomijany
#   „GitHub - Volume - M1"               → konto firmowe
#   „GitHub Personal (Arkadiusz-Czubik)" → konto prywatne
# Klucz, którym nie da się podpisać, wypada z rozpoznania sam — nie trzeba go
# nigdzie wymieniać. To jest zaleta pytania serwera zamiast czytania nazw.
#
# Przy pierwszym użyciu każdego klucza 1Password może poprosić o zatwierdzenie
# biometrią. Przy prawdziwej odbudowie człowiek stoi obok (właśnie skończył Z2/Z3),
# więc to nie jest zatrzymanie — ale warto wiedzieć, czego się spodziewać.
KEYS="$(SSH_AUTH_SOCK="$SOCK" ssh-add -L 2>/dev/null || true)"
[ -n "$KEYS" ] || die "agent nie zwrócił żadnych kluczy.
   Sejf odblokowany? Agent SSH włączony w Ustawieniach → Developer?"

PERSONAL_KEY=""
WORK_KEY=""
PERSONAL_WHO=""
WORK_WHO=""

while IFS= read -r KEY; do
  [ -n "$KEY" ] || continue
  printf '%s\n' "$KEY" > "$TMP/probe.pub"
  chmod 600 "$TMP/probe.pub"

  # -F /dev/null: ignorujemy konfigurację użytkownika, żeby próba nie zależała od
  # tego, co już leży w ~/.ssh/config. Determinizm testu.
  # ssh -T do GitHuba kończy się kodem 1 nawet przy sukcesie — stąd '|| true'.
  #
  # Agent podawany przez SSH_AUTH_SOCK, NIE przez '-o IdentityAgent='.
  # Ścieżka socketu 1Password zawiera spacje („Group Containers"), a ssh przy
  # '-o' nie przyjmuje wartości ze spacjami inaczej niż w cudzysłowie WEWNĄTRZ
  # argumentu — inaczej wywala 'keyword identityagent extra arguments at end of
  # line'. Zmienna środowiskowa nie ma tego problemu.
  # (W PLIKU konfiguracyjnym cudzysłów jest i tam jest właściwym rozwiązaniem.)
  # '-n' JEST KONIECZNE, nie kosmetyczne: bez niego ssh czyta STDIN, a STDIN tej
  # pętli to heredoc z listą kluczy. Pierwsze wywołanie ssh zjadałoby resztę
  # listy, więc pętla kończyła się po pierwszym kluczu — a pierwszy w agencie
  # („GitHub") nie daje się podpisać. Objaw: „żaden klucz nie uwierzytelnia się",
  # przy w pełni sprawnym agencie i sprawnym kluczu na trzeciej pozycji.
  # Znalezione w VM 2026-08-02; ta sama klasa co usterki drugiego rzędu z R-018.
  OUT="$(SSH_AUTH_SOCK="$SOCK" ssh -n -T \
          -F /dev/null \
          -o IdentitiesOnly=yes \
          -o IdentityFile="$TMP/probe.pub" \
          -o UserKnownHostsFile="$KH" \
          -o StrictHostKeyChecking=yes \
          -o PasswordAuthentication=no \
          -o ConnectTimeout=15 \
          git@github.com 2>&1 || true)"

  WHO="$(printf '%s' "$OUT" | sed -n 's/^Hi \([^!]*\)!.*/\1/p' | head -1)"
  [ -n "$WHO" ] || continue

  if [ "$WHO" = "$REPO_OWNER" ]; then
    [ -n "$PERSONAL_KEY" ] || { PERSONAL_KEY="$KEY"; PERSONAL_WHO="$WHO"; }
  else
    [ -n "$WORK_KEY" ] || { WORK_KEY="$KEY"; WORK_WHO="$WHO"; }
  fi
done <<EOF
$KEYS
EOF

[ -n "$PERSONAL_KEY" ] || die "żaden klucz z agenta nie uwierzytelnia się jako $REPO_OWNER.
   Bez niego prywatnego repo nie da się sklonować — a w nim jest cała deklaracja."

printf '%s\n' "$PERSONAL_KEY" > "$HOME/.ssh/id_personal.pub"
chmod 644 "$HOME/.ssh/id_personal.pub"
say "    konto prywatne: $PERSONAL_WHO → ~/.ssh/id_personal.pub"

if [ -n "$WORK_KEY" ]; then
  printf '%s\n' "$WORK_KEY" > "$HOME/.ssh/id_work.pub"
  chmod 644 "$HOME/.ssh/id_work.pub"
  say "    konto drugie:   $WORK_WHO → ~/.ssh/id_work.pub"
else
  warn "nie znaleziono drugiego konta GitHuba. Zasiew idzie dalej — do klonowania
      deklaracji wystarcza konto prywatne — ale alias github.com-work nie powstanie."
fi

# ─── ~/.ssh/config, wersja na czas klonowania ──────────────────────────────
# TO NIE JEST wersja docelowa. Pełna, opisana wersja przychodzi z chezmoi
# w kroku B5, z repo macbook-dotfiles (private_dot_ssh/private_config).
# Tutaj jest minimum potrzebne, by
# Z6 przeszedł: agent plus jawne przypisanie klucza do konta.
#
# Dlaczego IdentityFile wskazuje plik .pub: przy agencie SSH plik publiczny jest
# ETYKIETĄ WYBORU — wstawia właściwy klucz na początek listy prób. Na dysku nie
# ma sekretu. Bez tego ssh bierze pierwszy klucz z agenta i uwierzytelnia się
# złym kontem — to było Z-005, i prywatne repo było wtedy NIEWIDOCZNE (D-031).
if [ -f "$HOME/.ssh/config" ]; then
  cp "$HOME/.ssh/config" "$HOME/.ssh/config.bak-seed-$(date +%Y%m%d%H%M%S)"
  warn "istniejący ~/.ssh/config zachowany jako config.bak-seed-*"
fi

{
  printf '# ~/.ssh/config — ZASIEW, wersja tymczasowa.\n'
  printf '# Nadpisze ją chezmoi w kroku B5 (repo macbook-dotfiles).\n'
  printf '# Wygenerowane przez seed.sh — nie edytuj tutaj, popraw skrypt.\n\n'
  printf 'Host *\n    IdentityAgent "%s"\n\n' "$SOCK"
  printf 'Host github.com-personal\n'
  printf '    HostName github.com\n    User git\n'
  printf '    IdentityFile ~/.ssh/id_personal.pub\n    IdentitiesOnly yes\n\n'
  if [ -n "$WORK_KEY" ]; then
    printf 'Host github.com-work\n'
    printf '    HostName github.com\n    User git\n'
    printf '    IdentityFile ~/.ssh/id_work.pub\n    IdentitiesOnly yes\n\n'
    printf '# Repozytoria obce — tożsamość bez znaczenia, ale klucz musi być prawidłowy.\n'
    printf 'Host github.com\n'
    printf '    HostName github.com\n    User git\n'
    printf '    IdentityFile ~/.ssh/id_work.pub\n    IdentitiesOnly yes\n'
  else
    printf 'Host github.com\n'
    printf '    HostName github.com\n    User git\n'
    printf '    IdentityFile ~/.ssh/id_personal.pub\n    IdentitiesOnly yes\n'
  fi
} > "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"
say "    ~/.ssh/config zasiany"

# ═══════════════════════════════════════════════════════════════════════════
# Z5 — Homebrew (przy okazji Xcode CLT, bezgłowo)
# ═══════════════════════════════════════════════════════════════════════════
# git przychodzi z Xcode Command Line Tools, a te ściąga instalator Homebrew sam
# przez 'softwareupdate' — bez okna dialogowego (R-014, ustalenie 4). Dlatego
# Homebrew MUSI być przed Z6, a nie po nim.
#
# Sprawdzamy PLIK, nie 'command -v brew'. Homebrew wstawia się do PATH przez
# /etc/paths.d/homebrew, który czyta 'path_helper' — a ten działa wyłącznie
# w powłoce LOGOWANIA. W powłoce nielogowania (krok skryptu, 'ssh host komenda')
# brew jest zainstalowany i niewidoczny jednocześnie, więc 'command -v' kazałby
# instalować go po raz drugi. Zmierzone w VM 2026-08-02.
if [ -x /opt/homebrew/bin/brew ]; then
  say "Z5. Homebrew już jest — pomijam"
else
  say "Z5. Homebrew — instaluje przy okazji Xcode Command Line Tools"
  # NONINTERACTIVE=1: bez niego instalator czeka na Enter, którego nie ma jak
  # podać przez potok. Hasło sudo i tak idzie z /dev/tty.
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$BREW_INSTALL")" \
    || die "instalacja Homebrew nie przeszła"
fi
[ -x /opt/homebrew/bin/brew ] || die "brak /opt/homebrew/bin/brew po instalacji"
eval "$(/opt/homebrew/bin/brew shellenv)"
command -v git >/dev/null 2>&1 || die "brak git po instalacji Homebrew/CLT"
say "    Xcode CLT: $(xcode-select -p 2>/dev/null || echo '?')  ·  git: $(git --version)"

# ═══════════════════════════════════════════════════════════════════════════
# Z6 — klon prywatnego repo po SSH
# ═══════════════════════════════════════════════════════════════════════════
say "Z6. Klonowanie $REPO_OWNER/$REPO_NAME po SSH"
if [ -d "$CLONE_DIR/.git" ]; then
  say "    $CLONE_DIR już istnieje — pomijam klonowanie"
else
  git clone "git@github.com-personal:$REPO_OWNER/$REPO_NAME.git" "$CLONE_DIR" \
    || die "klonowanie nie przeszło. Sprawdź: ssh -T git@github.com-personal"
fi

BOOTSTRAP="$CLONE_DIR/bootstrap/bootstrap.sh"
[ -x "$BOOTSTRAP" ] || die "brak wykonywalnego $BOOTSTRAP"

# ═══════════════════════════════════════════════════════════════════════════
# Z7 — oddanie sterowania deklaracji
# ═══════════════════════════════════════════════════════════════════════════
# Zasiew kończy się tutaj i więcej nie wraca. Od tego miejsca wszystko, co się
# dzieje, jest opisane w repozytorium — a to jest kryterium akceptacji projektu.
#
# STDIN MUSI zostać przełożony na /dev/tty. Bez tego bootstrap.sh odziedziczyłby
# potok z curla, a jego kroki ręczne czytają Enter ze STDIN — czyli przeleciałyby
# przez wszystkie zatrzymania naraz, na resztkach kodu zasiewu.
say "Z7. Oddaję sterowanie: $BOOTSTRAP"
if [ -n "$TTY" ]; then
  exec "$BOOTSTRAP" < "$TTY"
else
  warn "brak /dev/tty — bootstrap.sh dostanie STDIN z /dev/null.
      Blok A przejdzie, blok B zatrzyma się na pierwszym kroku ręcznym."
  exec "$BOOTSTRAP" < /dev/null
fi
