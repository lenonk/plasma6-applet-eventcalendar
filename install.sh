#!/bin/sh
# Version 7

# This script detects if the widget is already installed.
# If it is, it will use --upgrade instead and restart plasmashell.

metadataFile="$PWD/package/metadata.json"
if [ ! -f "$metadataFile" ]; then
	echo "[install] Error: Missing package/metadata.json"
	exit 1
fi

# Hide KPackage warnings about unrelated plasmoids it scans along the way.
QT_LOGGING_RULES="kf.package*=false${QT_LOGGING_RULES:+;$QT_LOGGING_RULES}"
export QT_LOGGING_RULES

build_oauth_helper() {
	# Optional: build the helper used for the Google OAuth loopback flow.
	# If it fails, the widget still installs but Google login may fall back to manual instructions.
	if ! command -v cmake >/dev/null 2>&1; then
		echo "[install] cmake not found, skipping oauth helper build."
		return 0
	fi

	build_dir="$PWD/cmake-build"
	build_log="$build_dir/build.log"
	mkdir -p "$build_dir" || return 0

	# Configure (idempotent)
	if ! cmake -S "$PWD" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release >"$build_log" 2>&1; then
		echo "[install] Warning: Failed to configure CMake (oauth helper will not be built)."
		echo "[install] See $build_log for the missing dependency."
		echo "[install] Browser login will be unavailable; use the Advanced manual login method."
		return 0
	fi

	# Build only the helper target.
	jobs=1
	if command -v nproc >/dev/null 2>&1; then
		jobs=$(nproc)
	fi
	if ! cmake --build "$build_dir" --target eventcalendar-google-oauth -j "$jobs" >>"$build_log" 2>&1; then
		echo "[install] Warning: Failed to build oauth helper (eventcalendar-google-oauth)."
		echo "[install] See $build_log for details."
		echo "[install] Browser login will be unavailable; use the Advanced manual login method."
		return 0
	fi
	return 0
}

build_oauth_helper

metadataValue() {
	sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$metadataFile" | head -n 1
}

packageNamespace=$(metadataValue "Id")
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

# kpackagetool's -u/-i act on the user copy, but --show also finds system-wide
# (distro) copies, so look for the user copy directly.
userPackageDir="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$packageNamespace"
if [ -d "$userPackageDir" ]; then
	# Eg: kpackagetool6 -t "Plasma/Applet" -u package
	"${kpackagetoolCmd}" -t "${packageServiceType}" -u package
	restartPlasmashell=true
else
	# Eg: kpackagetool6 -t "Plasma/Applet" -i package
	"${kpackagetoolCmd}" -t "${packageServiceType}" -i package
	# A running system-wide copy only gets replaced after a restart.
	if "${kpackagetoolCmd}" --type="${packageServiceType}" --show="$packageNamespace" >/dev/null 2>&1; then
		restartPlasmashell=true
	fi
fi

if $restartPlasmashell; then
	if systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
		systemctl --user restart plasma-plasmashell.service
	else
		killall plasmashell
		if command -v plasmashell >/dev/null 2>&1; then
			nohup plasmashell >/dev/null 2>&1 &
		else
			"${kstartCmd}" plasmashell
		fi
	fi
fi
