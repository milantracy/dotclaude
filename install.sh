#!/bin/sh
# Links each item in this repo into ~/.claude, and removes links to items that
# are gone. Safe to run again.
# An existing non-link target is moved to <target>.bak.<timestamp> first,
# except CLAUDE.md, which is left in place with a warning.
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

# Like link, but leaves an existing target in place unless it is our own link
# (or a broken one), so that a CLAUDE.md you set up yourself, as a file or as
# a link to your own file, is never moved aside or replaced.
link_keep() {
	dst=$dest/$1
	if [ -e "$dst" ] && [ "$(readlink "$dst" || true)" != "$repo/$1" ]; then
		echo "skipped $dst: it exists and is not a link to this repo." \
			"Merge it into $repo/$1, remove it, and run again." >&2
		return 0
	fi
	link "$1"
}

for d in "$repo"/skills/*/; do link "skills/$(basename "$d")"; done
for f in "$repo"/agents/*.md; do link "agents/$(basename "$f")"; done
link review-kit
link_keep CLAUDE.md

# Remove links left behind by skills or agents that were renamed or deleted.
for l in "$dest"/skills/* "$dest"/agents/*; do
	[ -L "$l" ] && [ ! -e "$l" ] || continue
	case $(readlink "$l") in
	"$repo"/*) rm "$l" && echo "removed stale $l" ;;
	esac
done
