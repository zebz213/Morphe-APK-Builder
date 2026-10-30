#!/usr/bin/env bash

set -e

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
ask() {
	local y
	for ((n = 0; n < 3; n++)); do
		pr "$1 [y/n]"
		if read -r y; then
			if [ "$y" = y ]; then
				return 0
			elif [ "$y" = n ]; then
				return 1
			fi
		fi
		pr "Asking again..."
	done
	return 1
}

pr "Ask for storage permission"
until
	yes | termux-setup-storage >/dev/null 2>&1
	ls /sdcard >/dev/null 2>&1
do sleep 1; done
if [ ! -f ~/.rvmm_"$(date '+%Y%m')" ]; then
	pr "Setting up environment..."
	yes "" | pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" && pkg install -y git curl jq openjdk-21 zip
	: >~/.rvmm_"$(date '+%Y%m')"
fi
mkdir -p /sdcard/Download/revanced-apk/

if [ -d revanced-apk ] || [ -f config.toml ]; then
	if [ -d revanced-apk ]; then cd revanced-apk; fi
	pr "Checking for revanced-apk updates"
	git fetch
	if git status | grep -q 'is behind\|fatal'; then
		pr "revanced-apk is not synced with upstream."
		pr "Cloning revanced-apk. config.toml will be preserved."
		cd ..
		cp -f revanced-apk/config.toml .
		rm -rf revanced-apk
		git clone https://github.com/zebz213/revanced-apk --recurse --depth 1
		mv -f config.toml revanced-apk/config.toml
		cd revanced-apk
	fi
else
	pr "Cloning revanced-apk."
	git clone https://github.com/zebz213/revanced-apk --depth 1
	cd revanced-apk
	grep -q 'revanced-apk' ~/.gitconfig 2>/dev/null ||
		git config --global --add safe.directory ~/revanced-apk
fi

[ -f ~/storage/downloads/revanced-apk/config.toml ] ||
	cp config.toml ~/storage/downloads/revanced-apk/config.toml

if ask "Open rvmm-config-gen to generate a config?"; then
	am start -a android.intent.action.VIEW -d https://j-hc.github.io/rvmm-config-gen/
fi
printf "\n"
until
	if ask "Open 'config.toml' to adjust which apps are built?"; then
		am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced-apk/config.toml -t text/plain
	fi
	ask "Setup is done. Do you want to start building?"
do :; done
cp -f ~/storage/downloads/revanced-apk/config.toml config.toml

./build.sh

cd build
PWD=$(pwd)
for op in *; do
	[ "$op" = "*" ] && {
		pr "glob fail"
		exit 1
	}
	mv -f "${PWD}/${op}" ~/storage/downloads/revanced-apk/"${op}"
done

pr "Outputs are available in /sdcard/Download/revanced-apk folder"
am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced-apk -t resource/folder
sleep 2
am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced-apk -t resource/folder
