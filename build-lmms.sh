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
cmake -S "$SRC" -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DTARGET_UARCH=none \
  -DCMAKE_C_FLAGS="-O3 -mcpu=cortex-a76 -march=armv8.2-a+dotprod+crypto -fopenmp -pipe" \
  -DCMAKE_CXX_FLAGS="-O3 -mcpu=cortex-a76 -march=armv8.2-a+dotprod+crypto -fopenmp -pipe" \
  -DCMAKE_CXX_FLAGS_RELEASE="-DNDEBUG" \
  -DWANT_QT6=ON -DWANT_VST=OFF \
  -DWANT_ALSA=ON -DWANT_PULSEAUDIO=ON -DWANT_JACK=ON -DWANT_SNDFILE=ON -DWANT_SF2=ON \
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
