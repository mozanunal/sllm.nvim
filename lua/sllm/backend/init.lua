---@module "sllm.backend"
--- Backend registry and factory for sllm.
--- Manages backend registration and instantiation.

-- Module definition ==========================================================
local Backend = {}
local H = {}

-- Helper data ================================================================
H.backends = {}

-- Public API =================================================================

---Register a backend implementation.
---@param name string Backend identifier.
---@param backend BackendInterface Backend implementation.
function Backend.register(name, backend)
  vim.validate({
    name = { name, 'string' },
    backend = { backend, 'table' },
  })
  H.backends[name] = backend
end

---Get a registered backend by name.
---@param name string Backend identifier.
---@return BackendInterface|nil Backend implementation or nil if not found.
function Backend.get(name) return H.backends[name] end

---List all registered backend names.
---@return string[] List of backend names.
function Backend.list()
  local names = {}
  for name, _ in pairs(H.backends) do
    table.insert(names, name)
  end
  return names
end

---Check if a backend is registered.
---@param name string Backend identifier.
---@return boolean True if backend is registered.
function Backend.has(name) return H.backends[name] ~= nil end

-- Auto-register built-in backends ============================================
local llm_backend = require('sllm.backend.llm')
Backend.register('llm', llm_backend)

return Backend
