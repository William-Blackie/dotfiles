require("config.lazy")

-- Load machine-local configuration if it exists (untracked)
pcall(require, "config.local")
