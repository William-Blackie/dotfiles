local M = {}

local groups = {
  {
    scope = "vorssaint",
    title = "Vorssaint",
    mappings = {
      { "Command + Space", "Open searchable Command Bar" },
      { "Control + Option + Command + Q", "Open quick panel" },
      { "Control + Option + Command + V", "Open clipboard history" },
      { "Control + Option + Shift + Command + V", "Paste plain text" },
      { "Control + Option + Command + D", "Open shelf" },
      { "Control + Option + Command + L", "Open snippet library" },
      { "Control + Option + Command + N", "Open scratchpad" },
      { "Control + Option + Command + 3", "Capture full screen" },
      { "Control + Option + Command + 4", "Capture a region or window" },
      { "Control + Option + Command + 5", "Open screen recorder" },
      { "Control + Option + Command + E", "Edit last capture" },
      { "Control + Option + Command + H", "Open recent captures" },
      { "Control + Option + Command + P", "Edit image from clipboard" },
      { "Control + Option + Command + T", "Copy text from screen (OCR)" },
      { "Control + Option + Command + C", "Pick a color" },
      { "Control + Option + Command + W", "Open camera preview" },
      { "Control + Option + Command + M", "Toggle microphone mute" },
      { "Control + Option + Command + S", "Switch sound output" },
      { "Control + Option + Command + K", "Toggle keep awake" },
      { "Control + Option + Command + I", "Toggle Dynamic Island" },
      { "Control + Option + Command + - / =", "Decrease / increase display brightness" },
      {
        "Control + Option + Shift + Command + - / =",
        "Decrease / increase keyboard brightness",
      },
      { "Control + Option + Command + Space", "Open radial menu" },
    },
  },
  {
    scope = "aerospace",
    title = "AeroSpace · after Option + Space",
    mappings = {
      { "h / j / k / l", "Focus left / down / up / right" },
      { "y / u / i / o", "Move window left / down / up / right" },
      { "\\ / v", "Join container right / down" },
      { "e or /", "Tile or rotate tiled orientation" },
      { "s / w", "Vertical / horizontal accordion" },
      { ",", "Rotate accordion orientation" },
      { "b", "Balance window sizes" },
      { "Space", "Toggle floating / tiled" },
      { "f", "Toggle fullscreen" },
      { "1 … 0", "Switch to workspace 1 … 10" },
      { "Shift + 1 … 0", "Move window to workspace 1 … 10" },
      { "p / n", "Previous / next workspace" },
      { "Shift + p / n", "Move window to previous / next workspace" },
      { "[ / ]", "Previous / next workspace" },
      { "Shift + [ / ]", "Move window to previous / next workspace" },
      { "Tab", "Switch to previous workspace" },
      { "Shift + Tab", "Move workspace to next monitor" },
      { "m", "Focus next monitor" },
      { "Shift + m", "Move window to next monitor" },
      { "Enter", "Open Kitty" },
      { "c", "Reload AeroSpace" },
      { "g", "Open the complete key guide" },
      { "r", "Enter resize mode" },
      { ";", "Enter service mode" },
      { "Escape", "Cancel" },
    },
  },
  {
    scope = "aerospace",
    title = "AeroSpace resize mode",
    mappings = {
      { "h / l", "Decrease / increase width" },
      { "j / k", "Increase / decrease height" },
      { "b", "Balance window sizes" },
      { "Enter or Escape", "Exit resize mode" },
    },
  },
  {
    scope = "aerospace",
    title = "AeroSpace service mode",
    mappings = {
      { "h / j / k / l", "Join left / down / up / right" },
      { "r", "Flatten workspace tree" },
      { "f", "Toggle floating / tiled" },
      { "b", "Balance window sizes" },
      { "Backspace", "Close every window except focused" },
      { "Escape", "Reload and exit service mode" },
    },
  },
  {
    scope = "tmux",
    title = "tmux · after Control + Space",
    mappings = {
      { "|", "Split left / right" },
      { "-", "Split top / bottom" },
      { "c", "New window in current directory" },
      { "h / j / k / l", "Focus pane left / down / up / right" },
      { "H / J / K / L", "Resize pane left / down / up / right" },
      { "x", "Kill pane" },
      { "&", "Kill window" },
      { "s", "Choose session" },
      { "Control + j", "Switch session with fuzzy search" },
      { "z", "Toggle pane zoom" },
      { "[", "Enter copy mode" },
      { "R", "Reload tmux configuration" },
      { "g", "Open this tmux guide" },
      { "?", "Open tmux's native complete key list" },
    },
  },
  {
    scope = "tmux",
    title = "tmux · copy mode",
    mappings = {
      { "v", "Begin selection" },
      { "y", "Copy selection to macOS clipboard" },
      { "r", "Toggle rectangle selection" },
      { "Control + h / j / k / l", "Focus adjacent pane" },
    },
  },
  {
    scope = "tmux",
    title = "tmux · no prefix",
    mappings = {
      { "Control + h / j / k / l", "Move between Neovim and tmux panes" },
      { "Control + b", "Fallback tmux prefix" },
    },
  },
  {
    scope = "neovim",
    title = "Neovim · discovery and review",
    mappings = {
      { "Space, then s, then k", "Search every active Neovim keymap" },
      { "Space, then ?", "Show buffer-local keymaps" },
      { "Space, then g, then p", "Open GitHub pull requests" },
      { "Space, then g, then R", "PRs awaiting your review" },
      { "Space, then g, then r", "Resume GitHub review" },
      { "Space, then g, then d", "Diffview working changes" },
      { "Space, then g, then D", "Compare local main or master" },
      { "Space, then g, then M", "Compare remote main or master" },
      { "Space, then g, then q", "Close Diffview" },
      { "Control + h / j / k / l", "Move between Neovim and tmux panes" },
      { "Tab / Shift + Tab", "Next / previous buffer" },
    },
  },
  {
    scope = "kitty",
    title = "Kitty",
    mappings = {
      { "—", "No custom Kitty mappings; terminal navigation is owned by tmux" },
    },
  },
}

local function choices(scope)
  local result = {}
  for _, group in ipairs(groups) do
    if scope == "all" or scope == group.scope then
      for _, mapping in ipairs(group.mappings) do
        result[#result + 1] = {
          text = mapping[1] .. "    " .. mapping[2],
          subText = group.title,
        }
      end
    end
  end
  return result
end

function M.count(scope)
  return #choices(scope or "all")
end

function M.show(scope)
  scope = scope or "all"
  if M.chooser then
    M.chooser:hide()
  end

  M.chooser = hs.chooser.new(function() end)
  M.chooser:choices(choices(scope))
  M.chooser:placeholderText("Search " .. scope .. " keymaps")
  M.chooser:searchSubText(true)
  M.chooser:rows(18)
  M.chooser:width(70)
  M.chooser:show()
end

return M
