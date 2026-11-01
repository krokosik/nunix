#!/usr/bin/env bash
set -euo pipefail
workspace=$(mktemp --directory)
trap 'rm --recursive --force "$workspace"' EXIT
export VOXTYPE_REMOTE_ENDPOINT=http://unused.invalid
export VOXTYPE_LOCAL_CLI="$workspace/local-cli"
export TEST_WORKSPACE="$workspace"
export PATH="$workspace:$PATH"
cat > "$workspace/curl" <<'MOCK'
#!/usr/bin/env bash
case "$TEST_CASE" in
  success) printf '%s' '{"segments":[{"text":"Zażółć gęślą jaźń"}]}' ;;
  split) printf '%s' '{"text":"Zażółć gę\nślą\n jaźń\n","segments":[{"text":"Zażółć gę"},{"text":"ślą"},{"text":" jaźń"}]}' ;;
  empty) printf '%s' '{"segments":[]}' ;;
  bad_segment) printf '%s' '{"segments":[{"text":42}]}' ;;
  malformed) printf '{"error":"not ready"}' ;;
  invalid) printf 'not json' ;;
  offline) exit 7 ;;
  timeout) exit 28 ;;
esac
MOCK
cat > "$workspace/local-cli" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_WORKSPACE/local-args"
exit "${TEST_LOCAL_STATUS:-0}"
MOCK
chmod +x "$workspace/curl" "$workspace/local-cli"
for TEST_CASE in success split empty bad_segment malformed invalid offline timeout; do
  export TEST_CASE
  rm --force "$workspace/local-args" "$workspace/result.json"
  bash hosts/isis/voxtype-fallback.sh \
    --model '/model with spaces.bin' --file "$workspace/audio file.wav" \
    --output-json --output-file "$workspace/result" --threads 4 --no-prints
  case "$TEST_CASE" in
    success|split|empty)
      test ! -e "$workspace/local-args"
      jq --exit-status '.transcription[0].text | type == "string"' "$workspace/result.json" > /dev/null
      if [[ "$TEST_CASE" != empty ]]; then
        jq --exit-status '.transcription[0].text == "Zażółć gęślą jaźń"' "$workspace/result.json" > /dev/null
      else
        jq --exit-status '.transcription[0].text == ""' "$workspace/result.json" > /dev/null
      fi
      ;;
    *)
      test ! -e "$workspace/result.json"
      test "$(tail --lines=2 "$workspace/local-args")" = "$(printf '%s\n' --language auto)"
      [[ "$(cat "$workspace/local-args")" == *'/model with spaces.bin'* ]]
      [[ "$(cat "$workspace/local-args")" == *"$workspace/audio file.wav"* ]]
      ;;
  esac
  printf 'Passed: %s\n' "$TEST_CASE"
done
export TEST_CASE=offline TEST_LOCAL_STATUS=42
if bash hosts/isis/voxtype-fallback.sh --file audio --output-file result; then
  echo 'Local failure was swallowed' >&2
  exit 1
else
  test "$?" -eq 42
fi
printf 'Passed: local error propagation\n'
