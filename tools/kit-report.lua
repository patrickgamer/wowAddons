-- Development-only reader for DuoTestKit's SavedVariables file (run after logout, never in game):
--   lua5.1 tools/kit-report.lua <DuoTestKit.lua> [<second run to compare>]
-- The SavedVariables path lives in WoW's WTF folder and contains an account folder; pass it as an argument
-- and do not paste it into tracked files. Exit status is 1 when a safety invariant fails.
local M = {}

local function load(path)
    local chunk, err = loadfile(path)
    if not chunk then error(err, 0) end
    local env = {}
    setfenv(chunk, env)
    chunk()
    return env.DuoTestKitDB
end

local function strings(value, out)
    out = out or {}
    if type(value) == "string" then out[#out + 1] = value
    elseif type(value) == "table" then for k, v in pairs(value) do strings(k, out); strings(v, out) end end
    return out
end

local function state(s) return tostring(s.partySync.exists) .. "/" .. tostring(s.partySync.joined) end

-- Returns report lines and problem lines for one recording.
function M.analyse(db)
    local lines, problems = {}, {}
    local run = db and db.run
    if not run then return lines, {"no run recorded"} end
    lines[#lines + 1] = ("client %s build %s interface %s"):format(tostring(run.version), tostring(run.build), tostring(run.interface))
    for _, addon in ipairs(run.addons or {}) do
        lines[#lines + 1] = ("addon %s %s loaded=%s"):format(addon.name, addon.version, tostring(addon.loaded))
    end
    for _, step in ipairs(run.steps or {}) do
        local b, a = state(step.before), state(step.after)
        lines[#lines + 1] = ("step %-24s %-4s party-sync %s -> %s%s packets in %d->%d out %d->%d"):format(
            step.id, step.result, b, a, step.captainSync and " (captain change expected)" or "",
            step.before.counters.packetsReceived, step.after.counters.packetsReceived,
            step.before.counters.packetsSent, step.after.counters.packetsSent)
        if b ~= a and not step.captainSync then problems[#problems + 1] = "Party Sync changed during step " .. step.id .. " without a captain-flagged change" end
        if step.after.counters.canaryLeaks > 0 then problems[#problems + 1] = "private-note canary seen in a packet during step " .. step.id end
        if step.result == "fail" then problems[#problems + 1] = "step failed: " .. step.id end
    end
    for key, count in pairs(run.blocked or {}) do lines[#lines + 1] = ("%s x%d"):format(key, count) end
    for _, text in ipairs(strings(run)) do
        if text:find("%u%l+%-%u%l") or text:find("DTK%-CANARY") then problems[#problems + 1] = "possible name or canary text stored: " .. text end
    end
    return lines, problems
end

-- Compares two recordings (e.g. kit only versus all five addons): same steps, same Party Sync after-states.
function M.compare(a, b)
    local problems = {}
    local first, second = a.run.steps, b.run.steps
    if #first ~= #second then problems[#problems + 1] = ("step counts differ: %d vs %d"):format(#first, #second) end
    for i = 1, math.min(#first, #second) do
        if first[i].id ~= second[i].id then problems[#problems + 1] = "step order differs at " .. i
        elseif state(first[i].after) ~= state(second[i].after) then
            problems[#problems + 1] = ("Party Sync after-state differs in step %s: %s vs %s"):format(first[i].id, state(first[i].after), state(second[i].after))
        end
    end
    return problems
end

if arg and arg[0] and arg[0]:find("kit%-report") then
    local failed = false
    local runs = {}
    for i = 1, math.min(#arg, 2) do
        runs[i] = load(arg[i])
        local lines, problems = M.analyse(runs[i])
        print("== recording " .. i)
        for _, l in ipairs(lines) do print(l) end
        for _, p in ipairs(problems) do print("PROBLEM " .. p); failed = true end
    end
    if runs[2] then
        for _, p in ipairs(M.compare(runs[1], runs[2])) do print("PROBLEM " .. p); failed = true end
    end
    if not runs[1] then print("usage: lua5.1 tools/kit-report.lua <DuoTestKit.lua> [second.lua]"); os.exit(2) end
    os.exit(failed and 1 or 0)
end
return M
