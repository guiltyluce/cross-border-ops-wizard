#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/secrets.sh"

# 随机路径：12 位字母数字
p="$(gen_path)"; assert_eq "path len" "${#p}" "12"
case "$p" in *[!a-zA-Z0-9]*) _fail "path charset: $p";; esac; TESTS_RUN=$((TESTS_RUN+1))

# subid：sub- 前缀 + 16 hex
s="$(gen_subid)"; assert_contains "subid prefix" "$s" "sub-"
assert_eq "subid len" "${#s}" "20"
case "${s#sub-}" in *[!a-f0-9]*) _fail "subid hex charset: $s";; esac; TESTS_RUN=$((TESTS_RUN+1))

# basic auth：user:passhash 形式（htpasswd bcrypt 以 $2 开头）；此处用占位 hasher 注入
hash_password(){ printf 'HASHED(%s)' "$1"; }   # 测试用桩
ba="$(gen_basic_auth opsadmin)"
assert_contains "basic user" "$ba" "opsadmin:"
assert_contains "basic hashed" "$ba" "HASHED("

# reality 密钥：用桩 xray 注入，验证解析出 private/public
xray(){ [ "$1" = "x25519" ] && printf 'Private key: PRIV111\nPublic key: PUB222\n'; }
export -f xray
read -r priv pub < <(gen_reality_keys)
assert_eq "reality priv" "$priv" "PRIV111"
assert_eq "reality pub"  "$pub"  "PUB222"

finish
