#!/bin/bash
# Version 6

# This script detects if the widget is already installed.
# If it is, it will use --upgrade instead and restart plasmashell.

metadataFile="$PWD/package/metadata.json"
if [ ! -f "$metadataFile" ]; then
	echo "[install] Error: Missing package/metadata.json"
	exit 1
fi

function build_oauth_helper() {
	# Optional: build the helper used for the Google OAuth loopback flow.
	# If it fails, the widget still installs but Google login may fall back to manual instructions.
	if ! command -v cmake >/dev/null 2>&1; then
		echo "[install] cmake not found, skipping oauth helper build."
		return 0
	fi

	local build_dir="$PWD/cmake-build"
	mkdir -p "$build_dir" || return 0

	# Configure (idempotent)
	cmake -S "$PWD" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "[install] Warning: Failed to configure CMake (oauth helper will not be built)."
		return 0
	fi

	# Build only the helper target.
	local jobs=1
	if command -v nproc >/dev/null 2>&1; then
		jobs=$(nproc)
	fi
	cmake --build "$build_dir" --target eventcalendar-google-oauth -j "$jobs" >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "[install] Warning: Failed to build oauth helper (eventcalendar-google-oauth)."
		return 0
	fi
	return 0
}

build_oauth_helper

function metadataValue() {
	local key="$1"
	grep -oP "\"${key}\"\\s*:\\s*\"\\K[^\"]+" "$metadataFile" | head -n 1
}

packageNamespace=`metadataValue "Id"`
packageServiceType="Plasma/Applet"

kpackagetoolCmd="kpackagetool6"
if ! command -v "${kpackagetoolCmd}" >/dev/null 2>&1; then
	kpackagetoolCmd="kpackagetool5"
fi

kstartCmd="kstart6"
if ! command -v "${kstartCmd}" >/dev/null 2>&1; then
	kstartCmd="kstart5"
fi

restartPlasmashell=false

for arg in "$@"; do
	case "$arg" in
		-r) restartPlasmashell=true;;
		--restart) restartPlasmashell=true;;
		*) ;;
	esac
done

isAlreadyInstalled=false
"${kpackagetoolCmd}" --type="${packageServiceType}" --show="$packageNamespace" &> /dev/null
if [ $? == 0 ]; then
	isAlreadyInstalled=true
fi

if $isAlreadyInstalled; then
	# Eg: kpackagetool6 -t "Plasma/Applet" -u package
	"${kpackagetoolCmd}" -t "${packageServiceType}" -u package
	restartPlasmashell=true
else
	# Eg: kpackagetool6 -t "Plasma/Applet" -i package
	"${kpackagetoolCmd}" -t "${packageServiceType}" -i package
fi

if $restartPlasmashell; then
	killall plasmashell
	if command -v plasmashell >/dev/null 2>&1; then
		nohup plasmashell >/dev/null 2>&1 &
	else
		"${kstartCmd}" plasmashell
	fi
fi
