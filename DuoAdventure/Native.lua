local _, NS = ...
-- Read-only view of WoW's own Party Sync (C_QuestSession). DuoAdventure progress sharing is a
-- separate addon report exchange: it never starts, joins, answers, stops or supertracks a native
-- session, and never answers invitation confirmations. tools/check-repository.py rejects those calls
-- and keeps every QuestSession reference in this file.
NS.NativeEvents = {"QUEST_SESSION_CREATED", "QUEST_SESSION_DESTROYED", "QUEST_SESSION_JOINED",
    "QUEST_SESSION_LEFT", "QUEST_SESSION_ENABLED_STATE_CHANGED", "QUEST_SESSION_NOTIFICATION"}
local function public(value) return not issecretvalue or not issecretvalue(value) end
-- A flag is known only when WoW returns an accessible boolean; anything else stays unknown.
local function flag(read)
    if type(read) ~= "function" then return nil end
    local value = read()
    if not public(value) or type(value) ~= "boolean" then return nil end
    return value
end
function NS.NativePartySync()
    local api = C_QuestSession
    if type(api) ~= "table" then return "unknown" end
    local exists, joined, pending = flag(api.Exists), flag(api.HasJoined), flag(api.HasPendingCommand)
    if pending then
        local command = type(api.GetPendingCommand) == "function" and api.GetPendingCommand()
        local commands = Enum and Enum.QuestSessionCommand
        if commands and public(command) and type(command) == "number" then
            if command == commands.Start then return "pending-start" end
            if command == commands.Stop then return "pending-stop" end
        end
        return "pending"
    end
    if exists and joined then return "active" end
    if exists then return "exists" end
    if exists == false and pending == false then return "inactive" end
    return "unknown"
end
local LEAVE = "To leave, open Native quest log, choose Stop Party Sync at the bottom of the Map & Quest Log and confirm; if you only see its active status, the party member with that control must stop it."
local STATUS = {
    active = "ACTIVE for you. WoW can put quests on hold while your group does not meet their requirements; held quests cannot be completed until you leave Party Sync. ",
    exists = "a session exists in your group, but WoW does not report you as joined. ",
    ["pending-start"] = "a start request is pending. Answer it only in WoW's own dialog. ",
    ["pending-stop"] = "a stop request is pending. Answer it only in WoW's own dialog. ",
    pending = "a request is pending. Answer it only in WoW's own dialog. ",
    inactive = "not active, as reported by WoW.",
    unknown = "WoW did not report its state, so DuoAdventure cannot tell whether it is active. Check the bottom of the Map & Quest Log.",
}
local SEPARATE = "It is separate from DuoAdventure progress sharing, which never starts, joins, answers or stops it."
function NS.NativeStatus(state)
    state = state or NS.NativePartySync()
    local text = "WoW Party Sync (native, read-only): " .. (STATUS[state] or STATUS.unknown)
    if state == "active" then return text .. SEPARATE .. "\n" .. LEAVE end
    if state == "exists" or state:sub(1, 7) == "pending" then return text .. SEPARATE end
    return text
end
-- Extra prompt/notice text only when WoW reports a native session or request.
function NS.NativeNotice(state)
    state = state or NS.NativePartySync()
    if state == "inactive" or state == "unknown" then return "" end
    return NS.NativeStatus(state)
end
