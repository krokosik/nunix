#!/usr/bin/env bash
set -euo pipefail

# VoxType's CLI backend supplies these paths; preserve all arguments for fallback.
audio_file=
output_file=
args=("$@")
while (( $# )); do
  case "$1" in
    --file) audio_file=$2; shift 2 ;;
    --output-file) output_file=$2; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$audio_file" || -z "$output_file" ]]; then
  echo 'Missing VoxType audio or output path' >&2
  exit 1
fi

# Only publish valid JSON. An empty transcription is a successful result.
if response=$(curl --silent --show-error --fail --noproxy '*' \
  --connect-timeout 2 --max-time 30 \
  --form "file=@$audio_file" \
  --form 'response_format=json' --form 'language=auto' \
  "$VOXTYPE_REMOTE_ENDPOINT/inference") && \
  result=$(jq --compact-output --exit-status \
    'if (.text | type) == "string" then {transcription: [{text: .text}]} else error("Invalid transcription") end' \
    <<< "$response"); then
  printf '%s\n' "$result" > "$output_file.json"
else
  echo 'Remote transcription unavailable; using local Vulkan medium model' >&2
  # VoxType omits --language for auto-detection; whisper-cli defaults to English.
  exec "$VOXTYPE_LOCAL_CLI" "${args[@]}" --language auto
fi
