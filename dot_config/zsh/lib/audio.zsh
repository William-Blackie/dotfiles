# Bluetooth & Audio Management (macOS)
# Requires: blueutil, switchaudio-osx

# Bluetooth management with fzf
bt() {
  if ! command -v blueutil >/dev/null 2>&1; then
    echo "❌ blueutil not found. Install it: brew install blueutil"
    return 1
  fi

  local devices=$(blueutil --paired | awk -F', ' '{
    for (i=1; i<=NF; i++) {
      if ($i ~ /address: /) { a=$i; sub(/.*address: /, "", a) }
      if ($i ~ /name: /) { n=$i; sub(/.*name: /, "", n); gsub(/"/, "", n) }
    }
    if (a && n) print n " | " a
  }')
  local selected=$(echo "$devices" | fzf --height=20% --layout=reverse --border --header "Bluetooth Devices")

  if [[ -n "$selected" ]]; then
    local mac=$(echo "$selected" | awk -F' | ' '{print $NF}')
    local name=$(echo "$selected" | awk -F' | ' '{print $1}')
    local conn_status=$(blueutil --is-connected "$mac")

    if [[ "$conn_status" == "1" ]]; then
      echo "🔌 Disconnecting $name..."
      blueutil --disconnect "$mac"
    else
      echo "🔋 Connecting to $name..."
      blueutil --connect "$mac"
    fi
  fi
}

# Audio input/output switching with fzf
audio() {
  if ! command -v SwitchAudioSource >/dev/null 2>&1; then
    echo "❌ switchaudio-osx not found. Install it: brew install switchaudio-osx"
    return 1
  fi

  local mode=$(echo "Output (Everything)\nInput (Mic)\n🔇 Mute All\n🔊 Unmute All\n🔄 Nuclear Reset (Restart Audio Engine)" | fzf --height=15% --layout=reverse --border --header "Audio Management")

  if [[ -z "$mode" ]]; then return; fi

  # Mute/Unmute options
  if [[ "$mode" == *"Mute All"* ]]; then
    echo "🔇 Muting system audio..."
    SwitchAudioSource -m mute -t output
    SwitchAudioSource -m mute -t input
    osascript -e "set volume with output muted"
    return
  fi

  if [[ "$mode" == *"Unmute All"* ]]; then
    echo "🔊 Unmuting system audio..."
    SwitchAudioSource -m unmute -t output
    SwitchAudioSource -m unmute -t input
    osascript -e "set volume without output muted"
    return
  fi

  # Nuclear option for stubborn apps

  if [[ "$mode" == *"Nuclear Reset"* ]]; then
    echo "☢️  Restarting coreaudiod (requires sudo)..."
    sudo killall coreaudiod
    echo "✅ Audio engine restarted. Apps may take a moment to reconnect."
    return
  fi

  local type="output"
  [[ "$mode" == *"Input"* ]] && type="input"

  local current=$(SwitchAudioSource -c -t "$type")
  local devices=$(SwitchAudioSource -a -t "$type" | grep -v "$current")

  local selected=$(echo "$devices" | fzf --height=20% --layout=reverse --border --header "Switch $mode to:")

  if [[ -n "$selected" ]]; then
    if [[ "$type" == "output" ]]; then
      # Force both main output and system alerts to the same device
      SwitchAudioSource -s "$selected" -t output
      SwitchAudioSource -s "$selected" -t system
      echo "✅ Switched ALL output (System + Alerts) to: $selected"
    else
      SwitchAudioSource -s "$selected" -t input
      echo "✅ Switched Mic to: $selected"
    fi
  fi
}
