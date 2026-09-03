#!/bin/sh
# One-off: repair comment text that was written through a Latin-1 round trip.
# Only sequences actually observed in the tree are listed, longest first so a
# shorter prefix cannot eat a longer match. Comments only — a project-wide grep
# confirmed no string literal is affected, so nothing garbled reached the screen.
set -e
cd "$(dirname "$0")/.."
FILES="scripts/minigames_v2/MicrogameShell.gd
scripts/cutscenes/beats/BucketBrigadeLoseOutro.gd
scripts/cutscenes/beats/CoverTheDrumLoseOutro.gd
scripts/cutscenes/beats/CoverTheDrumWinOutro.gd
scripts/cutscenes/beats/FixLeakLoseOutro.gd
scripts/cutscenes/beats/GreywaterSorterIntro.gd"
for f in $FILES; do
  sed -i \
    -e 's/Ã¢â‚¬â€/—/g' \
    -e 's/â€”/—/g' \
    -e 's/â”€/─/g' \
    -e 's/â†’/→/g' \
    -e 's/â€¦/…/g' \
    "$f"
done
