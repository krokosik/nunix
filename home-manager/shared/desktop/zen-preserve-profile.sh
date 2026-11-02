profile_root="$1"
state_root="$2"
marker="$state_root/zen-profile-preserved-v1"

if [[ ! -d "$profile_root" || -e "$marker" ]]; then
  exit 0
fi

if pgrep --uid "$(id --user)" --exact 'zen|zen-bin|zen-twilight|zen-beta' > /dev/null; then
  echo "Close Zen before activating: its profile must be backed up while offline." >&2
  exit 1
fi

umask 077
mkdir --parents "$state_root"
backup_dir="$(mktemp --directory "$state_root/zen-profile-backup.XXXXXXXX")"
mkdir "$backup_dir/profile"
# Browser locks can be dangling symlinks after shutdown. They are runtime state,
# so exclude them while dereferencing the managed configuration and extensions.
tar --create --dereference --file=- --directory="$profile_root" \
  --no-wildcards-match-slash \
  --exclude='./*/lock' --exclude='./*/.parentlock' --exclude='./*/parent.lock' . \
  | tar --extract --file=- --directory="$backup_dir/profile"
echo "Zen profile backup: $backup_dir/profile"

# Keep removed Home Manager files as writable browser-owned files. Profiles.ini
# and user.js remain managed for profile selection and Stylix respectively.
shopt -s nullglob
for managed_file in "$profile_root"/*/search.json.mozlz4 "$profile_root"/*/extensions/*; do
  if [[ ! -L "$managed_file" ]]; then
    continue
  fi
  case "$(readlink "$managed_file")" in
    /nix/store/*) ;;
    *) continue ;;
  esac
  temporary_file="$(mktemp "${managed_file}.XXXXXXXX")"
  cp --dereference --preserve=timestamps "$managed_file" "$temporary_file"
  chmod u+w "$temporary_file"
  mv --force "$temporary_file" "$managed_file"
done

printf '%s\n' "$backup_dir/profile" > "$marker"
