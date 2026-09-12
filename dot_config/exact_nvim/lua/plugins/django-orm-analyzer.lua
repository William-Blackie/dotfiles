---@type LazyPluginSpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/django-orm-analyzer",
  name = "django-orm-analyzer",
  lazy = false,
  config = function()
    local analyzer = require("django-orm-analyzer")
    analyzer.setup({})
    local function update()
      analyzer.config.docker_container = vim.env.DJANGO_ORM_ANALYZER_DOCKER_CONTAINER
      analyzer.config.docker_project_root =
        vim.env.DJANGO_ORM_ANALYZER_DOCKER_PROJECT_ROOT
    end
    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("orm_project_env", { clear = true }),
      pattern = "ProjectEnvChanged",
      callback = update,
    })
    update()
  end,
}
