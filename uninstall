#!/bin/bash
# Version 6

metadataJsonFile="$PWD/package/metadata.json"
metadataDesktopFile="$PWD/package/metadata.desktop"
packageServiceType="Plasma/Applet"

function metadataJsonValue() {
	local key="$1"
	grep -oP "\"${key}\"\\s*:\\s*\"\\K[^\"]+" "$metadataJsonFile" | head -n 1
}

function metadataDesktopValue() {
	local key="$1"
	grep -oP "^${key}=\\K.*" "$metadataDesktopFile" | head -n 1
}

packageNamespace=""
if [ -f "$metadataJsonFile" ]; then
	packageNamespace="$(metadataJsonValue "Id")"
fi
if [ -z "$packageNamespace" ] && [ -f "$metadataDesktopFile" ]; then
	packageNamespace="$(metadataDesktopValue "X-KDE-PluginInfo-Name")"
fi
if [ -z "$packageNamespace" ]; then
	echo "[uninstall] Error: Could not determine package id from package/metadata.json or package/metadata.desktop"
	exit 1
fi

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
		-r) restartPlasmashell=true ;;
		--restart) restartPlasmashell=true ;;
		*) ;;
	esac
done

isInstalled=false
"${kpackagetoolCmd}" --type="${packageServiceType}" --show="$packageNamespace" &> /dev/null
if [ $? == 0 ]; then
	isInstalled=true
fi

if $isInstalled; then
	# Eg: kpackagetool6 -t "Plasma/Applet" -r org.kde.plasma.eventcalendar
	"${kpackagetoolCmd}" -t "${packageServiceType}" -r "$packageNamespace"
else
	echo "[uninstall] Package not installed: $packageNamespace"
fi

if $restartPlasmashell; then
	killall plasmashell
	if command -v plasmashell >/dev/null 2>&1; then
		nohup plasmashell >/dev/null 2>&1 &
	else
		"${kstartCmd}" plasmashell
	fi
fi
