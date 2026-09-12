-- [[ Profiling configuration menu ]]
-- Profiling configuration uses vim.ui, already backed by Snacks. Keep the
-- launch parameters in Overseer's schema; this is not another task registry.
local M = {}
local fields = require 'overseer.form.utils'

local function display(value)
    if value == nil then return '(required)' end
    if type(value) == 'table' and vim.tbl_isempty(value) then return '(none)' end
    return vim.json.encode(value)
end

local function select(title, items, callback)
    vim.ui.select(items, { prompt = title, kind = 'profile_config', format_item = function(item) return item.label end }, callback)
end

-- Each argument is one literal string. Environment entries are key/value
-- pairs. Neither editor splits shell words, commas, or empty arguments.
local function edit_entries(title, values, dictionary, accept, back)
    local menu
    local function update(key, value)
        local candidate = vim.deepcopy(values)
        if value == nil and not dictionary then
            table.remove(candidate, key)
        else
            candidate[key] = value
        end
        if accept(candidate) then values = candidate end
        menu()
    end
    local function edit_value(key)
        vim.ui.input({ prompt = dictionary and (key .. ' value: ') or (title .. ' entry: '), default = values[key] or '' }, function(value)
            if value == nil then return menu() end
            update(key, value)
        end)
    end
    menu = function()
        local items = {}
        local keys = dictionary and vim.tbl_keys(values) or {}
        if dictionary then
            table.sort(keys)
        else
            for i in ipairs(values) do
                keys[#keys + 1] = i
            end
        end
        for _, key in ipairs(keys) do
            items[#items + 1] = { key = key, label = tostring(key) .. ': ' .. display(values[key]) }
        end
        items[#items + 1] = { action = 'add', label = dictionary and 'Add variable' or 'Add entry' }
        items[#items + 1] = { action = 'back', label = 'Back' }
        select(title, items, function(item)
            if not item or item.action == 'back' then return back() end
            if item.action == 'add' then
                if not dictionary then return edit_value(#values + 1) end
                vim.ui.input({ prompt = 'Variable name: ' }, function(name)
                    if name == nil then return menu() end
                    -- Validate names before showing the value prompt, using the same
                    -- validator as the launch path. Do not save the placeholder value.
                    local candidate = vim.deepcopy(values)
                    candidate[name] = candidate[name] or ''
                    if accept(candidate, true) then
                        edit_value(name)
                    else
                        menu()
                    end
                end)
            else
                select(
                    title .. ': ' .. tostring(item.key),
                    { { label = 'Edit', action = 'edit' }, { label = 'Remove', action = 'remove' }, { label = 'Back' } },
                    function(action)
                        if action and action.action == 'edit' then
                            edit_value(item.key)
                        elseif action and action.action == 'remove' then
                            update(item.key, nil)
                        else
                            menu()
                        end
                    end
                )
            end
        end)
    end
    menu()
end

---@param template overseer.TemplateDefinition
---@param params table Per-target draft, kept only while this menu is open
---@param run fun(params: table)
---@param change_target fun()
function M.open(template, params, run, change_target)
    local schema = vim.deepcopy(type(template.params) == 'function' and template.params() or template.params or {})
    fields.validate_params(schema)
    local names = {}
    for name, field in pairs(schema) do
        if params[name] == nil then params[name] = vim.deepcopy(field.default) end
        if field.type ~= 'opaque' then names[#names + 1] = name end
    end
    -- JSON is only the existing template/serialization boundary. The menu
    -- always opens, including when every parameter already has a valid value.
    if schema.args then params.args = params.args or '[]' end
    table.sort(names, function(a, b)
        local left, right = schema[a].order or 100, schema[b].order or 100
        return left == right and a < b or left < right
    end)

    local menu, edit
    local function validate(name, value)
        local valid, reason = fields.validate_field(schema[name], value)
        if not valid then vim.notify(reason or ('Invalid value for ' .. (schema[name].name or name)), vim.log.levels.WARN) end
        return valid
    end
    local function set(name, value, check_only)
        if not validate(name, value) then return false end
        if not check_only then params[name] = value end
        return true
    end

    edit = function(name)
        local field = schema[name]
        local label = field.name or name
        if name == 'args' or name == 'env' or field.type == 'list' then
            local json = name == 'args' or name == 'env'
            local values = json and vim.json.decode(params[name]) or vim.deepcopy(params[name] or {})
            edit_entries(label, values, name == 'env', function(candidate, check_only)
                if name == 'env' and vim.tbl_isempty(candidate) then candidate = vim.empty_dict() end
                return set(name, json and vim.json.encode(candidate) or candidate, check_only)
            end, menu)
        elseif field.type == 'boolean' then
            set(name, not params[name])
            menu()
        elseif field.choices then
            local choices = {}
            if field.type == 'namedEnum' then
                for label, value in pairs(field.choices) do
                    choices[#choices + 1] = { label = label, value = value }
                end
                table.sort(choices, function(a, b) return a.label < b.label end)
            else
                for _, value in ipairs(field.choices) do
                    choices[#choices + 1] = { label = value, value = value }
                end
            end
            select(label, choices, function(choice)
                if choice then set(name, choice.value) end
                menu()
            end)
        else
            vim.ui.input(
                { prompt = label .. ': ', default = tostring(params[name] or ''), completion = (name == 'program' or name == 'cwd') and 'file' or nil },
                function(value)
                    if value ~= nil then
                        local parsed, result = fields.parse_value(field, value)
                        if parsed then set(name, result) end
                    end
                    menu()
                end
            )
        end
    end

    menu = function()
        local items = { { action = 'target', label = 'Target: ' .. template.name } }
        for _, name in ipairs(names) do
            local value = params[name]
            if name == 'args' or name == 'env' then value = vim.json.decode(value) end
            items[#items + 1] = { name = name, label = (schema[name].name or name) .. ': ' .. display(value) }
        end
        items[#items + 1] = { action = 'run', label = 'Run' }
        items[#items + 1] = { action = 'cancel', label = 'Cancel' }
        select('Configure ' .. template.name, items, function(item)
            if not item or item.action == 'cancel' then return end
            if item.action == 'target' then return change_target() end
            if item.action ~= 'run' then return edit(item.name) end
            for _, name in ipairs(names) do
                if not validate(name, params[name]) then return edit(name) end
            end
            local ok, err = pcall(run, params)
            if not ok then
                vim.notify(tostring(err), vim.log.levels.ERROR)
                menu()
            end
        end)
    end
    menu()
end

return M
