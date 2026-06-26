#!/usr/bin/env bash
# Per-node secret generation. Source-only.

_rand_alnum(){ LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$1"; }

gen_path(){ _rand_alnum 12; }
gen_subid(){ printf 'sub-%s' "$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c 16)"; }
gen_uuid(){
  if command -v xray >/dev/null 2>&1; then xray uuid
  elif command -v uuidgen >/dev/null 2>&1; then uuidgen | tr 'A-Z' 'a-z'
  elif [ -r /proc/sys/kernel/random/uuid ]; then cat /proc/sys/kernel/random/uuid
  else die "cannot generate UUID: install xray or uuidgen"
  fi
}

# hash_password may be overridden in tests; default uses htpasswd bcrypt.
hash_password(){ printf '%s' "$1" | htpasswd -niBC 10 "x" | cut -d: -f2; }
gen_basic_auth(){ local user="$1"; printf '%s:%s' "$user" "$(hash_password "$(_rand_alnum 20)")"; }

# gen_reality_keys -> "<private> <public>"
gen_reality_keys(){
  local out priv pub
  out="$(xray x25519)"
  priv="$(printf '%s' "$out" | sed -n 's/.*[Pp]rivate key: *//p')"
  pub="$(printf '%s' "$out" | sed -n 's/.*[Pp]ublic key: *//p')"
  printf '%s %s' "$priv" "$pub"
}
