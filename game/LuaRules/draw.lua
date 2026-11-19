-- Entry point for the UNSYNCED half of LuaRules. The engine needs both main.lua (synced)
-- and draw.lua (unsynced); if either is missing LuaRules is discarded entirely.
VFS.Include("LuaGadgets/gadgets.lua", nil, VFS.BASE)
