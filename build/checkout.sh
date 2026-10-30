#!/bin/sh
# Fetch exact git objects; nested gitlinks retain their own pinned revisions.
set -eu
repo=$1 revision=$2 destination=$3
git init "$destination"
git -C "$destination" remote add origin "$repo"
git -C "$destination" fetch --depth 1 origin "$revision"
git -C "$destination" checkout --detach FETCH_HEAD
test "$(git -C "$destination" rev-parse HEAD)" = "$revision"
git -C "$destination" config url.https://github.com/FWGS/.insteadOf https://github.com/yohimik/
git -C "$destination" -c url.https://github.com/FWGS/.insteadOf=https://github.com/yohimik/ submodule update --init --recursive --depth 1
