#!/usr/bin/env bash
# Publishes trustpin_attest from a copy outside the repository.
#
# pub applies every .pubignore from the repository root down, and the root
# one leaves this directory out of the trustpin_sdk package; publishing from
# here would leave this package empty. The copy has no parent ignore files and
# no pubspec_overrides.yaml, so it resolves trustpin_sdk from pub.dev: publish
# trustpin_sdk at the same version first.
#
# Usage: trustpin_attest/tool/publish.sh [--dry-run] [other `dart pub publish` flags]
set -euo pipefail

package_dir="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# The files git would track here: tracked or new, minus ignored ones.
git -C "$package_dir" ls-files --cached --others --exclude-standard -z . |
  (cd "$package_dir" && xargs -0 tar -cf - --exclude pubspec_overrides.yaml) |
  (mkdir -p "$work_dir/trustpin_attest" && cd "$work_dir/trustpin_attest" && tar -xf -)

cd "$work_dir/trustpin_attest"
flutter pub get
dart pub publish "$@"
