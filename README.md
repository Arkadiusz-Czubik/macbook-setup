# macbook-seed

Publiczny **punkt wejścia** odbudowy stacji roboczej macOS. Repo trzyma jeden plik,
`seed.sh`, i nic więcej — bo tylko on musi być osiągalny **bez żadnego
poświadczenia**. Reszta procedury żyje w repozytoriach prywatnych i przychodzi
dopiero po zalogowaniu do menedżera sekretów.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Arkadiusz-Czubik/macbook-seed/main/seed.sh)
```

Ta postać, nie `curl … | bash`: przy potoku STDIN skryptu jest samym skryptem, więc
kroki wymagające człowieka nie mają skąd czytać Entera.

## Co robi zasiew

Instaluje 1Password z `.pkg`, weryfikując podpis AgileBits **przed** instalacją →
czeka na zalogowanie i włączenie agenta SSH → odczytuje z agenta klucze
**publiczne** → zasiewa `~/.ssh/config` i `known_hosts` (klucze hosta
z `api.github.com/meta` po TLS, nie przez `accept-new`) → instaluje Homebrew, przy
okazji Xcode CLT bezgłowo → klonuje prywatne repo z deklaracją → oddaje mu
sterowanie i znika.

**Żadne poświadczenie nie opuszcza sejfu.** Agent SSH podpisuje wyzwanie u siebie
i oddaje wyłącznie podpis; materiał prywatny nie przechodzi przez socket. Na dysku
nie ląduje żaden klucz prywatny.

## Dlaczego to repo jest puste poza jednym plikiem

Do 2026-08-02 nazywało się `macbook-setup` i trzymało trzy niepowiązane rzeczy: ten
zasiew, źródło konfiguracji dla chezmoi oraz katalog `.setup/` z porzuconym
wcześniejszym podejściem. Nazwa „setup" nie znaczyła nic konkretnego, więc
przyjmowała wszystko.

Zawartość historyczna nie zniknęła — jest dostępna pod tagiem:

```bash
git checkout prior-art-2026-08
```

Powód porzucenia tamtego podejścia, warty zapisania: `.setup/Brewfile` powstał ze
**zrzutu stanu maszyny**, więc nie kodował żadnej intencji — był listą tego, co
akurat było zainstalowane. Deklaracja, która nie mówi *po co*, nie daje się ani
utrzymywać, ani zrewidować. Obecna powstała od zera, wpis po wpisie, i jest
prywatna.
