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
mkdir -p /sdcard/Download/morphe-apk-builder/

if [ -d morphe-apk-builder ] || [ -f config.toml ]; then
	if [ -d morphe-apk-builder ]; then cd morphe-apk-builder; fi
	pr "Checking for morphe-apk-builder updates"
	git fetch
	if git status | grep -q 'is behind\|fatal'; then
		pr "morphe-apk-builder is not synced with upstream."
		pr "Cloning morphe-apk-builder. config.toml will be preserved."
		cd ..
		cp -f morphe-apk-builder/config.toml .
		rm -rf morphe-apk-builder
		git clone --recurse --depth 1 https://github.com/zebz213/Morphe-APK-Builder morphe-apk-builder
		mv -f config.toml morphe-apk-builder/config.toml
		cd morphe-apk-builder
	fi
else
	pr "Cloning morphe-apk-builder."
	git clone --depth 1 https://github.com/zebz213/Morphe-APK-Builder morphe-apk-builder
	cd morphe-apk-builder
	grep -q 'morphe-apk-builder' ~/.gitconfig 2>/dev/null ||
		git config --global --add safe.directory ~/morphe-apk-builder
fi

[ -f ~/storage/downloads/morphe-apk-builder/config.toml ] ||
	cp config.toml ~/storage/downloads/morphe-apk-builder/config.toml

if ask "Open rvmm-config-gen to generate a config?"; then
	am start -a android.intent.action.VIEW -d https://j-hc.github.io/rvmm-config-gen/
fi
printf "\n"
until
	if ask "Open 'config.toml' to adjust which apps are built?"; then
		am start -a android.intent.action.VIEW -d file:///sdcard/Download/morphe-apk-builder/config.toml -t text/plain
	fi
	ask "Setup is done. Do you want to start building?"
do :; done
cp -f ~/storage/downloads/morphe-apk-builder/config.toml config.toml

./build.sh

cd build
PWD=$(pwd)
for op in *; do
	[ "$op" = "*" ] && {
		pr "glob fail"
		exit 1
	}
	mv -f "${PWD}/${op}" ~/storage/downloads/morphe-apk-builder/"${op}"
done

pr "Outputs are available in /sdcard/Download/morphe-apk-builder folder"
am start -a android.intent.action.VIEW -d file:///sdcard/Download/morphe-apk-builder -t resource/folder
sleep 2
am start -a android.intent.action.VIEW -d file:///sdcard/Download/morphe-apk-builder -t resource/folder
