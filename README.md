# macbook-setup

Publiczny **punkt wejścia** odbudowy stacji roboczej macOS. To jedyny plik, który
musi być osiągalny bez żadnego poświadczenia — reszta procedury żyje w prywatnych
repozytoriach i przychodzi dopiero po zalogowaniu do menedżera sekretów.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Arkadiusz-Czubik/macbook-setup/main/seed.sh)
```

Zasiew: instaluje 1Password → czeka na zalogowanie i włączenie agenta SSH →
odczytuje z agenta klucze **publiczne** → zasiewa `~/.ssh/config` i `known_hosts`
→ instaluje Homebrew (przy okazji Xcode CLT, bezgłowo) → klonuje prywatne repo
z deklaracją → oddaje mu sterowanie i znika.

Żadne poświadczenie nie opuszcza sejfu: agent SSH podpisuje u siebie, a materiał
prywatny nie przechodzi przez socket.

## Uwaga o zawartości tego repo

Katalog `.setup/` i pliki `dot_*` to **porzucone poprzednie podejście**, zachowane
wyłącznie jako materiał historyczny. Nie są punktem wyjścia i nie należy ich
uruchamiać — w szczególności `.setup/install.sh`, na który wskazywała poprzednia
wersja tego README. Powód porzucenia: `.setup/Brewfile` powstał ze zrzutu stanu
maszyny, więc nie kodował żadnej intencji.

Aktualna, świadomie zbudowana deklaracja jest prywatna.
