local M = {}

function M.files(buf)
  local root = vim.fs.root(buf, { ".git" })
  if not root then
    return {}
  end
  return vim.fn.glob(root .. "/django/build/static/css/*/*.css", false, true)
end

function M.setup(opts)
  local cache = require("html-css.cache")
  local fetcher = require("html-css.fetcher")
  local attached = {}
  local group = vim.api.nvim_create_augroup("project_styles", { clear = true })
  local function update(buf)
    if vim.bo[buf].buftype ~= "" then
      return
    end
    local ext = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":e")
    if not vim.tbl_contains(opts.enable_on, ext) then
      return
    end
    local sources = {}
    -- Preserve upstream's linked and inline styles; replace only our project files.
    local current = cache._buffers[buf]
    for src in pairs(current and current._sources or {}) do
      if not (attached[buf] or {})[src] then
        sources[#sources + 1] = src
      end
    end
    attached[buf] = {}
    for _, file in ipairs(M.files(buf)) do
      sources[#sources + 1] = file
      attached[buf][file] = true
      if not cache:has_source(file) then
        fetcher:fetch(file, buf, false)
      end
    end
    cache:link_sources(buf, sources)
  end
  -- Registered after html-css so its linked styles are available to merge.
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePre" }, {
    group = group,
    callback = function(ev)
      update(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      update(vim.api.nvim_get_current_buf())
    end,
  })
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      attached[ev.buf] = nil
    end,
  })
  update(vim.api.nvim_get_current_buf())
end

return M
