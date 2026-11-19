-- Entry point for synced + unsynced LuaRules. Without this file the engine never creates
-- LuaRules, so NONE of the gadgets in LuaRules/Gadgets/ load (no commander spawn, no
-- weapon toggles, no factory rules, no win condition).
VFS.Include("LuaGadgets/gadgets.lua", nil, VFS.BASE)
