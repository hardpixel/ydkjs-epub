#!/bin/sh

# NOTE: this file is a modified version of gist:
# https://gist.github.com/bmaupin/6e3649af73120fac2b6907169632be2c

# Clean up redundant headings that end up getting split into separate chapters by themselves
find . -iname "*.md" -exec sed -i '/# You Don'\''t Know JS.*/d' {} \;
# Fix <br> tags which pandoc won't convert to <br />
find . -iname "*.md" -exec sed -i 's#<br>#<br />#' {} \;
# Close img tags
find . -iname "*.md" -exec sed -i -r 's#(<img.*[^/])>#\1 />#' {} \;
