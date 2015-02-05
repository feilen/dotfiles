#!/bin/bash
CONFIG="dx9frames"

if [ -z "$EDITOR" ]; then
	EDITOR="nano"
fi

if [ -z "${1}" ]; then
	echo "Usage: ${0} yourusername <config>"
	echo "Default config is dx9frames. Editor can be changed with the EDITOR environment variable."
	echo "When the config has downloaded, the script will launch EDITOR to let you uncomment the configuration options you want."
	exit
else
	STEAMUSER="${1}"
fi

if [ -n "${2}" ]; then
	CONFIG="${2}"
fi

URL="https://raw.github.com/cdown/tf2configs/master/${CONFIG}"
OUTDIR="${HOME}/.local/share/Steam/SteamApps/${STEAMUSER}/Team Fortress 2/tf/cfg/"
mkdir -p "${OUTDIR}"
OUTLOCATION="${OUTDIR}autoexec.cfg"

wget -q "${URL}" -O "${OUTLOCATION}"

"${EDITOR}" "${OUTLOCATION}"

echo "Chris' ${CONFIG} config should be loaded now. All that's left is to add launch options."
echo "Add the following options to your TF2 launch options (Library>Rclick TF2>Properties>Launch Options):"
echo ""
cat "${OUTLOCATION}"|grep novid|sed 's/-dxlevel [0-9]*//g;s/\/\/ //g'
