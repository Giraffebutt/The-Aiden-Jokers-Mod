BalatroAidenMod = BalatroAidenMod or {}
BalatroAidenMod.calculate_callbacks = BalatroAidenMod.calculate_callbacks or {}

function BalatroAidenMod.add_calculate(callback)
    BalatroAidenMod.calculate_callbacks[#BalatroAidenMod.calculate_callbacks + 1] = callback
end

SMODS.current_mod.calculate = function(self, context)
    for _, callback in ipairs(BalatroAidenMod.calculate_callbacks) do
        local result = callback(self, context)
        if result then
            return result
        end
    end
end

local modules = {
    'modules/aiden.lua',
    'modules/blue.lua',
    'modules/green.lua',
    'modules/purple.lua',
    'modules/red.lua',
    'modules/yellow.lua'
}

for _, path in ipairs(modules) do
    local chunk, err = SMODS.load_file(path)
    if not chunk then
        error(err)
    end
    chunk()
end
