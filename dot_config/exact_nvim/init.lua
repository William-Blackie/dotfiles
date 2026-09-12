require("lib.project_env").setup()
require("config.lazy")
pcall(require, "config.local")
