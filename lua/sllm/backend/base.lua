---@module "sllm.backend.base"
--- Abstract base interface for sllm backends.
--- All backend implementations must implement these methods.

-- Module definition ==========================================================
local Base = {}

-- Type definitions ===========================================================

---@class BackendConfig
---@field cmd string? Command path for CLI-based backends.
---@field api_key string? API key for direct API backends.
---@field base_url string? Base URL for API backends.

---@class BackendCommandOptions
---@field prompt string User input prompt.
---@field continue boolean|string|nil Continuation mode (true = continue last, string = conversation ID).
---@field show_usage boolean? Show usage statistics.
---@field model string? Model name to use.
---@field ctx_files string[]? Context file paths.
---@field tools string[]? Tool names to enable.
---@field functions string[]? Python function definitions.
---@field system_prompt string? System prompt text.
---@field model_options table<string,any>? Model-specific options.
---@field chain_limit integer? Maximum tool chain responses.
---@field template string? Template name to use.

---@class BackendHistoryEntry
---@field id string Unique log ID.
---@field conversation_id string Conversation ID.
---@field model string Model name used.
---@field prompt string User's prompt.
---@field response string LLM's response.
---@field system string? System prompt used.
---@field timestamp string ISO timestamp.
---@field usage table? Token usage information.

---@class BackendHistoryOptions
---@field count integer? Number of entries to fetch.
---@field query string? Search query to filter logs.
---@field model string? Filter by model name.

---@class BackendTemplateEntry
---@field name string Template name.
---@field content string Template YAML content.

---@class BackendInterface
---@field name string Backend identifier.
---@field get_models fun(config: BackendConfig): string[] Get available models.
---@field get_default_model fun(config: BackendConfig): string Get default model name.
---@field get_tools fun(config: BackendConfig): string[] Get available tools.
---@field build_command fun(config: BackendConfig, options: BackendCommandOptions): string Build execution command.
---@field get_history fun(config: BackendConfig, options: BackendHistoryOptions?): BackendHistoryEntry[]?
---@field get_session fun(config: BackendConfig, session_id: string): BackendHistoryEntry[]?
---@field supports_tools fun(): boolean Whether backend supports tool calling.
---@field supports_history fun(): boolean Whether backend supports history.
---@field supports_templates fun(): boolean Whether backend supports templates.
---@field get_templates fun(config: BackendConfig): string[] Get available templates.
---@field get_template fun(config: BackendConfig, name: string): BackendTemplateEntry? Get template details.
---@field get_templates_path fun(config: BackendConfig): string? Get templates directory path.
---@field edit_template fun(config: BackendConfig, name: string): boolean Open template for editing.

-- Public API =================================================================

---Backend name identifier.
---@type string
Base.name = 'base'

---Get list of available models.
---@param config BackendConfig Backend configuration.
---@return string[] List of model names.
function Base.get_models(_config) error('Backend must implement get_models()') end

---Get the default model name.
---@param config BackendConfig Backend configuration.
---@return string Default model name.
function Base.get_default_model(_config) error('Backend must implement get_default_model()') end

---Get list of available tools.
---@param config BackendConfig Backend configuration.
---@return string[] List of tool names.
function Base.get_tools(_config) error('Backend must implement get_tools()') end

---Build the command string to execute.
---@param config BackendConfig Backend configuration.
---@param options BackendCommandOptions Command options.
---@return string The assembled command string.
function Base.build_command(_config, _options) error('Backend must implement build_command()') end

---Check if backend supports tool calling.
---@return boolean True if tools are supported.
function Base.supports_tools() return false end

---Check if backend supports history.
---@return boolean True if history is supported.
function Base.supports_history() return false end

---Fetch history entries.
---@param config BackendConfig Backend configuration.
---@param options BackendHistoryOptions? History options.
---@return BackendHistoryEntry[]? List of history entries or nil.
function Base.get_history(_config, _options) return nil end

---Fetch a specific conversation.
---@param config BackendConfig Backend configuration.
---@param session_id string Session/conversation ID to fetch.
---@return BackendHistoryEntry[]? List of session entries or nil.
function Base.get_session(_config, _session_id) return nil end

---Check if backend supports templates.
---@return boolean True if templates are supported.
function Base.supports_templates() return false end

---Get list of available templates.
---@param config BackendConfig Backend configuration.
---@return string[] List of template names.
function Base.get_templates(_config) return {} end

---Get template details.
---@param config BackendConfig Backend configuration.
---@param name string Template name.
---@return BackendTemplateEntry? Template entry or nil.
function Base.get_template(_config, _name) return nil end

---Get templates directory path.
---@param config BackendConfig Backend configuration.
---@return string? Path to templates directory or nil.
function Base.get_templates_path(_config) return nil end

---Open template for editing.
---@param config BackendConfig Backend configuration.
---@param name string Template name.
---@return boolean Success status.
function Base.edit_template(_config, _name) return false end

---Parse token usage from a stderr line.
---@param line string The line to parse.
---@return table|nil Token usage table or nil.
function Base.parse_token_usage(_line) return nil end

---Check if a line is a Tool call header.
---@param line string The line to check.
---@return boolean True if it's a Tool call header.
function Base.is_tool_call_header(_line) return false end

---Check if a line is tool call output.
---@param line string The line to check.
---@return boolean True if it's tool output.
function Base.is_tool_call_output(_line) return false end

---Create a new backend instance that inherits from base.
---@param impl table Backend implementation table.
---@return BackendInterface New backend instance.
function Base.extend(impl)
  vim.validate({ impl = { impl, 'table' } })
  return vim.tbl_extend('force', Base, impl)
end

return Base
