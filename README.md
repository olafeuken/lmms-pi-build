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

## Uwagi / ograniczenia

- **Wersja Qt**: runner to Ubuntu 24.04 (Qt 6.4), Pi to Debian trixie (Qt 6.8).
  Qt zachowuje ABI w obrębie serii 6.x, więc zwykle działa, ale najpewniejsze
  jest budowanie lokalnie na Pi (skrypt `build-lmms.sh`).
- **Flagi**: `-mcpu=cortex-a76 -march=armv8.2-a+dotprod+crypto -O3 -fopenmp -flto`.
- **Audio**: LMMS samo jest w dużej mierze jednowątkowe (DSP), ale build włącza
  OpenMP i buduje wielowątkowo; akceleracja zależy od backendu (ALSA/Pulse/JACK).
- **Dźwięk**: build zawiera wszystkie backendy (ALSA/PulseAudio/JACK/SDL),
  a artifact dołącza domyślny `lmmsrc.xml` wymuszający **PulseAudio**
  (działa z PipeWire). Bez niego LMMS na Pi wybiera ALSA → brak dźwięku.
- Config LMMS zachowany w `~/.lmmsrc.xml.bak-cloud` (z poprzedniej instalacji).
