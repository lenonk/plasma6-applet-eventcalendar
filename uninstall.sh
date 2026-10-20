#!/bin/sh
# Version 7

metadataJsonFile="$PWD/package/metadata.json"
metadataDesktopFile="$PWD/package/metadata.desktop"
packageServiceType="Plasma/Applet"

# Hide KPackage warnings about unrelated plasmoids it scans along the way.
QT_LOGGING_RULES="kf.package*=false${QT_LOGGING_RULES:+;$QT_LOGGING_RULES}"
export QT_LOGGING_RULES

metadataJsonValue() {
	sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$metadataJsonFile" | head -n 1
}

metadataDesktopValue() {
	sed -n "s/^$1=//p" "$metadataDesktopFile" | head -n 1
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
if "${kpackagetoolCmd}" --type="${packageServiceType}" --show="$packageNamespace" >/dev/null 2>&1; then
	isInstalled=true
fi

if $isInstalled; then
	# Eg: kpackagetool6 -t "Plasma/Applet" -r org.kde.plasma.eventcalendar
	"${kpackagetoolCmd}" -t "${packageServiceType}" -r "$packageNamespace"
else
	echo "[uninstall] Package not installed: $packageNamespace"
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
