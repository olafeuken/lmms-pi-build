#!/bin/bash
# build-lmms.sh — kompilacja LMMS pod Raspberry Pi 5 (Cortex-A76) + OpenMP.
# Działa: (a) lokalnie na Pi, (b) w GitHub Actions (ubuntu-24.04-arm).
# Użycie: ./build-lmms.sh [katalog-zrodel]
set -e
SRC="${1:-src}"
NPROC=$(nproc)

echo "=== zależności (Debian/Ubuntu) ==="
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config \
  qt6-base-dev qt6-base-dev-tools qt6-tools-dev \
  qt6-tools-dev-tools qt6-svg-dev \
  libsndfile1-dev libsamplerate0-dev libfftw3-dev \
  libflac-dev libogg-dev libvorbis-dev libmp3lame-dev \
  libpulse-dev libasound2-dev libjack-jackd2-dev \
  libfluidsynth-dev zlib1g-dev libsqlite3-dev \
  libarchive-dev liblilv-dev libsuil-dev libsndio-dev libgl-dev \
  libfltk1.3-dev fluid libgig-dev libsdl2-dev \
  libsoundio-dev portaudio19-dev libstk-dev libx11-dev \
  liblist-moreutils-perl

[ -d "$SRC" ] || { git clone --depth 1 https://github.com/LMMS/lmms.git "$SRC"; }

echo "=== konfiguracja (Cortex-A76 + OpenMP, bez LTO) ==="
# TARGET_UARCH=custom + TARGET_UARCH_FLAGS: LMMS aplikuje te flagi przez
# add_compile_options do WSZYSTKICH targetów (rdzeń + wtyczki + 3rdparty).
# official=armv8-a (zbyt zachowawcze), native da kod Ampere na runnerze (nie A76).
# Wyłączamy ciężkie/opcjonalne podsystemy (LV2/SUIL, VST, GIG, Carla, Stk, Sid,
# pakiety LADSPA CALF/CAPS/CMT/SWH/TAP, MP3Lame) => lżejszy build, szybszy start,
# mniej RAM, mniejsze ryzyko OOM. Backendy audio wszystkie (na Pi dźwięk = PulseAudio).
cmake -S "$SRC" -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DTARGET_UARCH=custom \
  -DTARGET_UARCH_FLAGS="-mcpu=cortex-a76;-march=armv8.2-a+dotprod+crypto;-mtune=cortex-a76;-O3;-fopenmp;-pipe" \
  -DWANT_QT6=ON \
  -DWANT_ALSA=ON -DWANT_PULSEAUDIO=ON -DWANT_JACK=ON \
  -DWANT_SNDIO=ON -DWANT_PORTAUDIO=ON -DWANT_SOUNDIO=ON -DWANT_SDL=ON \
  -DWANT_SNDFILE=ON -DWANT_SF2=ON -DWANT_OGGVORBIS=ON \
  -DWANT_LV2=OFF -DWANT_SUIL=OFF \
  -DWANT_VST=OFF -DWANT_GIG=OFF -DWANT_CARLA=OFF -DWANT_STK=OFF -DWANT_SID=OFF \
  -DWANT_CALF=OFF -DWANT_CAPS=OFF -DWANT_CMT=OFF -DWANT_SWH=OFF -DWANT_TAP=OFF \
  -DWANT_MP3LAME=OFF \
  -DCMAKE_INSTALL_PREFIX=/opt/lmms

echo "=== kompilacja (${NPROC} wątków) ==="
cmake --build build -j"$NPROC"

echo "=== instalacja do /opt/lmms ==="
sudo cmake --install build --prefix /opt/lmms

echo "=== domyślny config dźwięku (PulseAudio przez pipewire-pulse) ==="
# Wymusza backend PulseAudio - bez tego LMMS wybiera ALSA (pomija PipeWire) => cisza.
sudo cp -f config/lmmsrc.xml /opt/lmms/lmmsrc.xml
echo "Skopiuj go do swojego katalogu domowego (nadpisze ewentualny stary config):"
echo "    cp /opt/lmms/lmmsrc.xml ~/.lmmsrc.xml"

echo "Gotowe. Uruchom: /opt/lmms/bin/lmms"
