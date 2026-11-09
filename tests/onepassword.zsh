#!/bin/zsh
set -eu

source_dir="${0:A:h:h}"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

cat >"$test_dir/op" <<'EOF'
#!/bin/sh
printf '%s\n' "$*"
EOF
cat >"$test_dir/chezmoi" <<'EOF'
#!/bin/sh
printf '%s\n' "$OP_ACCOUNT:$*"
EOF
chmod +x "$test_dir/op" "$test_dir/chezmoi"
export PATH="$test_dir:$PATH"
source "$source_dir/dot_config/zsh/onepassword.zsh"

export OP_WORK_ACCOUNT=work-id OP_PERSONAL_ACCOUNT=personal-id
[[ "$(opwork vault list)" == '--account work-id vault list' ]]
[[ "$(oppersonal item list)" == '--account personal-id item list' ]]
[[ "$(opsignin work)" == 'whoami --account work-id' ]]
opswitch work >/dev/null
[[ "$OP_ACCOUNT" == work-id ]]
export CHEZMOI_1PASSWORD_ACCOUNT=personal-id
[[ "$(chezmoi status)" == 'personal-id:status' ]]
[[ "$OP_ACCOUNT" == work-id ]]
unset CHEZMOI_1PASSWORD_ACCOUNT
[[ "$(chezmoi status)" == 'work-id:status' ]]
opswitch personal >/dev/null
[[ "$OP_ACCOUNT" == personal-id ]]
unset OP_WORK_ACCOUNT
if opwork vault list 2>/dev/null; then
  print -u2 'Missing account mapping must fail closed'
  exit 1
fi
print '1Password account helper tests passed'
