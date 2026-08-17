# LMMS dla Raspberry Pi 5 — cloud build (GitHub Actions)

Buduje LMMS ze źródeł na **darmowym arm64 runnerze** GitHub Actions,
zoptymalizowany pod **Cortex-A76** (Pi 5) + **OpenMP** (wielowątkowość).

## Jak uruchomić cloud build

1. Załóż repozytorium na GitHub (może być prywatne; arm64 runnery mają darmowy
   limit minut, **publiczne repo = w pełni darmowe**).
2. Wgraj do niego zawartość tego folderu:
   ```
   .github/workflows/lmms-pi.yml
   ```
   (możesz to zrobić np. przez `git init`, `git add`, `git push`).
3. Wejdź na GitHub → Actions → wybierz workflow **"Build LMMS for Raspberry Pi 5"** → **Run workflow**.
4. Po skończeniu pobierz artifact **`lmms-pi5-arm64`** (`.tar.gz`).

## Instalacja na Pi

```bash
# zależności RUNTIME na Pi (Debian trixie)
sudo apt-get install -y libqt6core6 libqt6gui6 libqt6widgets6 libqt6xml6 \
  libsndfile1 libsamplerate0 libfftw3-double3 libflac12 libogg0 libvorbis0a \
  libmp3lame0 libpulse0 libasound2 libjack0 libfluidsynth3 zlib1g \
  libsqlite3-0 libarchive13 liblilv-0-0 libsuil-0-0 libsndio7

# rozpakuj artifact i zainstaluj do /opt/lmms
tar -xzf lmms-pi5-arm64.tar.gz -C /tmp
sudo cp -a /tmp/lmms-install/. /opt/lmms/

# DŹWIĘK: wgraj domyślny config (wymusza backend PulseAudio -> działa z PipeWire)
cp /opt/lmms/lmmsrc.xml ~/.lmmsrc.xml

# uruchom
/opt/lmms/bin/lmms
```

## ⚠️ Brak dźwięku — najważniejsze

Na Pi z **PipeWire** (KDE Plasma 6 / Debian trixie) LMMS przy pustym
`audiodev` wybiera backend **ALSA**, który pomija routing PipeWire — LMMS
„gra", ale nic nie słychać. **Rozwiązanie: wymusić backend PulseAudio**
(łączy się przez `pipewire-pulse`, potwierdzony strumień 48 kHz / 2ch).

Wgrywa się to plikiem `~/.lmmsrc.xml` (dostarczonym jako `lmmsrc.xml`
w artifactcie / w `/opt/lmms/lmmsrc.xml`):

```bash
cp /opt/lmms/lmmsrc.xml ~/.lmmsrc.xml
```

> **Ważne**: jeśli wcześniej uruchamiałeś LMMS, masz już stary
> `~/.lmmsrc.xml` z zapisanym (złym) backendem — ta komenda go nadpisuje.

Zweryfikuj działający backend (powinno być `PulseAudio`):

```bash
grep -o 'audiodev="[^"]*"' ~/.lmmsrc.xml
```

W razie potrzeby możesz zmienić backend ręcznie w Ustawienia → Audio
(Edit → Settings → Audio interface). Alternatywne nazwy backendów:
`"PulseAudio"`, `"ALSA (Advanced Linux Sound Architecture)"`,
`"JACK (JACK Audio Connection Kit)"`, `"SDL (Simple DirectMedia Layer)"`.

Opcjonalnie (niska latencja, bez zmiany systemowego PipeWire) uruchamiaj przez:

```bash
PIPEWIRE_LATENCY=256/48000 /opt/lmms/bin/lmms
```

## Budowa lokalnie na Pi (alternatywa)

Jeśli wolisz (pewniejsze dopasowanie bibliotek do Debiana trixie):

```bash
cd lmms-pi-build
./build-lmms.sh
```

## Optymalizacja builda pod Pi 5

Build jest nastawiony na: płynność, lekkość, brak OOM, sprawną matematykę (NEON)
i wielowątkowość.

- **Mikroarchitektura** — `TARGET_UARCH=custom` + `TARGET_UARCH_FLAGS`
  `-mcpu=cortex-a76 -march=armv8.2-a+dotprod+crypto -mtune=cortex-a76 -O3 -fopenmp`.
  LMMS aplikuje je przez `add_compile_options` do **wszystkich** targetów
  (rdzeń + wtyczki + 3rdparty). `official` dla ARM64 to tylko `-march=armv8-a`
  (zbyt zachowawcze), `native` na runnerze dałby kod Ampere (nie A76).
- **Matematyka / FFTW** — LMMS wymaga systemowego FFTW (`fftw3f`). Na Debianie
  trixie / Ubuntu 24.04 arm64 to **FFTW 3.3.10 z NEON**, a `-mcpu=cortex-a76`
  włącza NEON. To najszybsza FFT dla Pi 5.
- **Wielowątkowość** — silnik LMMS sam tworzy `nproc−1` wątków roboczych
  (`AudioEngineWorkerThread`) + OpenMP. Nic dodatkowego nie trzeba.
- **Lekkość i brak OOM** — wyłączone ciężkie/opcjonalne podsystemy:
  `LV2`/`SUIL`, `VST`, `GIG`, `Carla`, `Stk`, `Sid`, pakiety LADSPA
  (`CALF`/`CAPS`/`CMT`/`SWH`/`TAP`) i `MP3Lame`. Efekt: dużo mniej linkowania
  (mniejsze ryzyko **out of memory** na runnerze), **szybszy start** (LV2 to
  ~184 wtyczek systemowych skanowanych przy starcie — główna przyczyna wolnego
  startu na Pi) i mniejsze zużycie RAM. Wszystkie **natywne** instrumenty i
  efekty LMMS (TripleOscillator, Watsyn, BitInvader, Kicker, ZynAddSubFx,
  Sf2Player, EQ, Reverb, Delay, Compressor itd.) pozostają.
- **Bez LTO** — `-flto` linkuje dużo RAM-em i bywa wolne na małych maszynach;
  wyłączone dla bezpieczeństwa pamięci.
- **Strippping** — `Release` automatycznie stripuje binaria (mniejszy artifact).

### Jak przywrócić wyłączone funkcje

W `build-lmms.sh` / `.github/workflows/lmms-pi.yml` zmień odpowiedni `WANT_*=OFF`
na `ON` (i doinstaluj deps):
- LV2 + UI: `-DWANT_LV2=ON -DWANT_SUIL=ON` (uwaga: wolniejszy start),
- VST: `-DWANT_VST=ON` (wymaga wine),
- GIG: `-DWANT_GIG=ON`, Carla: `-DWANT_CARLA=ON`, Stk: `-DWANT_STK=ON`, Sid: `-DWANT_SID=ON`,
- pakiety LADSPA: `-DWANT_CALF=ON -DWANT_CAPS=ON -DWANT_CMT=ON -DWANT_SWH=ON -DWANT_TAP=ON`,
- MP3 export: `-DWANT_MP3LAME=ON`.

## Uwagi / ograniczenia

- **Wersja Qt**: runner to Ubuntu 24.04 (Qt 6.4), Pi to Debian trixie (Qt 6.8).
  Qt zachowuje ABI w obrębie serii 6.x, więc zwykle działa, ale najpewniejsze
  jest budowanie lokalnie na Pi (skrypt `build-lmms.sh`).
- **Audio**: LMMS samo jest w dużej mierze jednowątkowe (DSP), ale silnik tworzy
  wątki robocze (`nproc−1`) i build włącza OpenMP; akceleracja zależy od backendu
  (ALSA/Pulse/JACK).
- **Dźwięk**: build zawiera wszystkie backendy (ALSA/PulseAudio/JACK/SDL),
  a artifact dołącza domyślny `lmmsrc.xml` wymuszający **PulseAudio**
  (działa z PipeWire). Bez niego LMMS na Pi wybiera ALSA → brak dźwięku.
- Config LMMS zachowany w `~/.lmmsrc.xml.bak-cloud` (z poprzedniej instalacji).
