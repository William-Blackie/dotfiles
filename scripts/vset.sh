#!/usr/bin/env bash
# Native secret setter for local dotfile hydration.
set -euo pipefail

usage() {
  echo "Usage: vset [work|personal] <key-name> [value]"
  echo ""
  echo "Stores a config blob or secret in 1Password or Bitwarden."
  echo "Use stable keys like F_AWS_CONFIG or F_KUBECONFIG so your local bootstrap scripts can restore files consistently."
  echo ""
  echo "  work     -> Stores in 1Password 'Employee' vault as a Secure Note."
  echo "  personal -> Stores in Bitwarden as a Secure Note."
  echo ""
  echo "If [value] is omitted, you will be prompted to enter it securely."
  exit 1
}

if [[ "$#" -lt 2 ]]; then
  usage
fi

ENV_TYPE=$1
KEY=$2
VALUE=${3:-}

# Handle piped input or multiline strings
if [[ -z "$VALUE" ]]; then
  if [[ ! -t 0 ]]; then
    VALUE=$(cat)
  else
    read -r -s -p "Enter value for $KEY: " VALUE
    echo ""
  fi
fi

if [[ -z "$VALUE" ]]; then
  echo "❌ Error: No value provided (arg or stdin)."
  exit 1
fi

if [[ "$ENV_TYPE" == "work" ]]; then
  echo "🔒 Storing '$KEY' in 1Password (Employee Vault)..."
  if ! command -v op > /dev/null 2>&1; then
    echo "❌ Error: 1password-cli (op) is not installed."
    exit 1
  fi

  TMP_VAL=$(mktemp)
  echo "$VALUE" > "$TMP_VAL"

  if op item get "$KEY" --vault="Employee" > /dev/null 2>&1; then
    echo "⚠️  Item '$KEY' already exists. Updating..."
    # op item edit can take field=value, but for large blocks it's better to use field=stdin or similar
    # or just use the field=. to read from file if op supports or just quoting carefully
    op item edit "$KEY" "notesPlain=$VALUE" --vault="Employee" > /dev/null
  else
    op item create --category="Secure Note" --title="$KEY" "notesPlain=$VALUE" --vault="Employee" > /dev/null
  fi
  rm "$TMP_VAL"

  echo "✅ Saved to 1Password as $KEY"

elif [[ "$ENV_TYPE" == "personal" ]]; then
  echo "🔒 Storing '$KEY' in Bitwarden (Personal)..."
  if ! command -v bw > /dev/null 2>&1; then
    echo "❌ Error: bitwarden-cli (bw) is not installed."
    exit 1
  fi

  # Check login status
  if ! bw status | grep -q '"status":"unlocked"\|"status":"locked"'; then
    echo "❌ Error: You are not logged into Bitwarden CLI. Run 'bw login' first."
    exit 1
  fi

  EXISTING_ID=$(bw get item "$KEY" 2> /dev/null | jq -r 'if type == "array" then .[0].id else .id end' 2> /dev/null || bw get item "$KEY" 2> /dev/null | grep '"id":' | head -1 | sed -E 's/.*"id": ?"([^"]+)".*/\1/' || true)

  if [[ -n "$EXISTING_ID" ]]; then
    echo "⚠️  Item '$KEY' already exists. Updating notes..."
    # Robustly update only the notes field using jq if available, else sed
    if command -v jq > /dev/null 2>&1; then
      bw get item "$EXISTING_ID" | jq ".notes = $(printf '%s' "$VALUE" | jq -Rs .)" | bw encode | bw edit item "$EXISTING_ID" > /dev/null
    else
      # Fallback to sed if jq is missing, but with a more careful replacement
      # (Note: This is risky for complex JSON but works for basic notes)
      bw get item "$EXISTING_ID" | sed -E 's/"notes": ?".*"/"notes": "'"$VALUE"'"/' | bw encode | bw edit item "$EXISTING_ID" > /dev/null
    fi
  else
    # Create new secure note payload
    # Type 2 is Secure Note
    ITEM_JSON=$(
      cat << EOF
{
  "organizationId": null,
  "folderId": null,
  "type": 2,
  "name": "$KEY",
  "notes": "$VALUE",
  "favorite": false,
  "secureNote": {
    "type": 0
  },
  "reprompt": 0
}
EOF
    )
    echo "$ITEM_JSON" | bw encode | bw create item > /dev/null
  fi

  echo "✅ Saved to Bitwarden as $KEY"

else
  echo "❌ Error: Unknown environment type '$ENV_TYPE'."
  usage
fi
