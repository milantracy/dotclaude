#!/bin/sh
# Links each item in this repo into ~/.claude. Safe to run again.
# An existing non-link target is moved to <target>.bak.<timestamp> first.
set -eu
repo=$(cd "$(dirname "$0")" && pwd)
dest=${CLAUDE_HOME:-$HOME/.claude}

link() {
	src=$repo/$1
	dst=$dest/$1
	mkdir -p "$(dirname "$dst")"
	if [ -L "$dst" ]; then
		rm "$dst"
	elif [ -e "$dst" ]; then
		bak=$dst.bak.$(date +%Y%m%d%H%M%S)
		mv "$dst" "$bak"
		echo "moved existing $dst to $bak"
	fi
	ln -s "$src" "$dst"
	echo "linked $dst -> $src"
}

for d in "$repo"/skills/*/; do link "skills/$(basename "$d")"; done
for f in "$repo"/agents/*.md; do link "agents/$(basename "$f")"; done
link review-kit
