-- Krastorio 2 (2.1): data stage. K2 is loaded before FF, so its KR table exists.
if not mods["Krastorio2"] then return end

-- FF sets its own stack sizes (prototypes/stack-sizes.lua); K2's adjustments would be overwritten anyway
if KR then KR.adjust_stack_sizes = false end
