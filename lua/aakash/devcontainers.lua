-- [[ Host editor, container language servers ]]
-- Only container workspaces use the RPC path translator. Rootless buffers and
-- ordinary projects retain their local commands, environment, and working directory.
local M = {}

---@param root_dir? string
---@return boolean
function M.is_workspace(root_dir)
    -- Loading the manager starts Docker's event listener; inspect the marker directly.
    return root_dir ~= nil
        and not vim.uv.fs_stat '/.dockerenv'
        and vim.uv.fs_stat(vim.fs.joinpath(root_dir, '.devcontainer')) ~= nil
end

---@param local_cmd string[]|fun(config: vim.lsp.ClientConfig): string[]
---@param container_cmd? string[]|fun(config: vim.lsp.ClientConfig): string[]
---@return fun(dispatchers: vim.lsp.rpc.Dispatchers, config: vim.lsp.ClientConfig): vim.lsp.rpc.PublicClient
function M.lsp_cmd(local_cmd, container_cmd)
    if not container_cmd then
        container_cmd = vim.list_slice(local_cmd)
        container_cmd[1] = vim.fs.basename(container_cmd[1])
    end
    local remote
    return function(dispatchers, config)
        if M.is_workspace(config.root_dir) then
            remote = remote or require('devcontainers').lsp_cmd(container_cmd)
            return remote(dispatchers, config)
        end
        local cmd = type(local_cmd) == 'function' and local_cmd(config) or local_cmd
        return vim.lsp.rpc.start(cmd, dispatchers, {
            cwd = config.cmd_cwd,
            env = config.cmd_env,
            detached = config.detached,
        })
    end
end

return M
