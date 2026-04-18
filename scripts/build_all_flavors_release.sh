#!/usr/bin/env bash
# Build every flavor: iOS IPA + Android App Bundle (release).
# iOS xcschemes use kebab-case; Android productFlavors use camelCase for unlisted.
# Outputs: build/ios/ipa/*.ipa, build/app/outputs/bundle/*Release/*.aab
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

while IFS='|' read -r flavor_ios flavor_android target; do
  [[ -z "${flavor_ios:-}" || "${flavor_ios}" =~ ^# ]] && continue

  echo "========== IPA  ios_flavor=$flavor_ios target=$target =========="
  flutter build ipa --release --flavor "$flavor_ios" -t "$target"

  echo "========== App Bundle  android_flavor=$flavor_android target=$target =========="
  flutter build appbundle --release --flavor "$flavor_android" -t "$target"
done <<'EOF'
client|client|lib/main_client.dart
coach|coach|lib/main_coach.dart
client-unlisted|clientUnlisted|lib/main_client_unlisted.dart
coach-unlisted|coachUnlisted|lib/main_coach_unlisted.dart
EOF

echo "All release builds finished."
