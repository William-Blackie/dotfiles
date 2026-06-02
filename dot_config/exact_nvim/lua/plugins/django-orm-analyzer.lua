---@type LazyPluginSpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/django-orm-analyzer",
  name = "django-orm-analyzer",
  lazy = false,
  config = function()
    local function env_or_default(name, default)
      local value = vim.env[name]
      if value == nil or value == "" then
        return default
      end
      return value
    end

    require("django-orm-analyzer").setup({
      docker_container = env_or_default(
        "DJANGO_ORM_ANALYZER_DOCKER_CONTAINER",
        "django-admin"
      ),
      docker_project_root = env_or_default(
        "DJANGO_ORM_ANALYZER_DOCKER_PROJECT_ROOT",
        "/www/mabyduck/django"
      ),
    })
  end,
}
