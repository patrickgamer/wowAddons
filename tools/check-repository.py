"""Dependency-free structural checks; run from anywhere with Python 3."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
names = ('DuoBags', 'DuoUI', 'DuoSupport', 'DuoSocial', 'DuoAdventure')
count = 0

# Captain's rule: "we don't trigger the default/standard hold functionality either directly or
# indirectly." No addon may start, join, answer, stop or supertrack WoW's native Party Sync, or answer
# the native invitation/confirmation dialogs that can join it. Native state is read only in
# DuoAdventure/Native.lua through these queries, its constants and its lifecycle events.
NATIVE_READER = 'DuoAdventure/Native.lua'
NATIVE_READS = re.compile(
    r'C_QuestSession\.(?:Exists|HasJoined|HasPendingCommand|GetPendingCommand)\b|C_QuestSession(?![\w.\[:])'
    r'|Enum\.QuestSessionCommand\b|"QUEST_SESSION_(?:CREATED|DESTROYED|JOINED|LEFT|ENABLED_STATE_CHANGED|NOTIFICATION)"')
NATIVE_TRIGGERS = re.compile(
    r'RequestSession|SessionBeginResponse|SetQuestIsSuperTracked|StaticPopup|AcceptGroup|ConfirmBNRequestInvite'
    r'|\bConfirm(?:InviteUnit|RequestInviteFromUnit|InviteTravelPass|LeaveParty|ConvertToRaid|ReadyCheck)\b|:Click\s*\(')


def native_violations(relative, code):
    code = re.sub(r'--[^\n]*', '', code)
    found = []
    if NATIVE_TRIGGERS.search(code):
        found.append('native Party Sync or confirmation trigger')
    if re.search(r'(?i)quest_?session', code) and relative != NATIVE_READER:
        found.append('native Party Sync reference outside ' + NATIVE_READER)
    if re.search(r'(?i)quest_?session', NATIVE_READS.sub('', code)):
        found.append('native Party Sync access beyond the read-only queries')
    if re.search(r'\bInviteUnit\s*\(', code) and relative != 'DuoSocial/Main.lua':
        found.append('invitation outside DuoSocial explicit invite')
    return found


for sample in ('C_QuestSession.RequestSessionStart()', 'C_QuestSession.SendSessionBeginResponse(true)',
               'C_QuestSession["RequestSessionStop"]()', 'local api = C_QuestSession; api.RequestSessionStart()',
               'QuestSessionManager:ExecuteSessionCommand()', 'C_QuestSession.SetQuestIsSuperTracked(1, true)',
               'StaticPopup1Button1:Click()', 'C_PartyInfo.ConfirmInviteUnit(name)', 'AcceptGroup()',
               'frame:RegisterEvent("QUEST_SESSION_MEMBER_CONFIRM")'):
    assert native_violations(NATIVE_READER, sample), ('native guard misses', sample)
assert not native_violations(NATIVE_READER, 'if type(C_QuestSession) == "table" then return C_QuestSession.Exists() end')
assert native_violations('DuoAdventure/Main.lua', 'C_QuestSession.Exists()')
for name in names:
    folder = root / name
    toc = folder / f'{name}.toc'
    data = toc.read_text(encoding='utf-8')
    assert f'## SavedVariables: {name}DB' in data, toc
    assert '## Interface: 120105' in data, toc
    assert (folder / 'README.md').is_file(), folder
    for line in data.splitlines():
        if not line or line.startswith('#'):
            continue
        path = folder
        for part in line.replace('\\', '/').split('/'):
            assert part in {p.name for p in path.iterdir()}, (toc, line, 'missing or wrong case')
            path /= part
        assert path.is_file(), path
        assert path.suffix == '.lua', path
        count += 1
    for path in folder.glob('*.lua'):
        code = path.read_text(encoding='utf-8')
        assert not re.search(r'[A-Z]:\\', code), (path, 'machine path in runtime')
        assert not re.search(r'\b(SendChatMessage|LootSlot|TargetUnit|CastSpellByID)\s*\(', code), (path, 'unexpected direct gameplay/chat call')
        problems = native_violations(f'{name}/{path.name}', code)
        assert not problems, (path, problems)
        if re.search(r'\bSendAddonMessage\s*\(', code):
            assert name == 'DuoAdventure' and path.name == 'Sync.lua', (path, 'addon comms outside scoped protocol')
            assert 'SendAddonMessage(PREFIX, packet.text, "PARTY")' in code, path
    entries = [p.name.lower() for p in folder.iterdir()]
    assert len(entries) == len(set(entries)), folder
# Developer-only recorder: outside the five runtime addons and outside WoW's AddOns scan, but held to the same
# rules. It may read Party Sync (it is the reader here) and nothing else, and never sends or acts.
kit = root / 'devkit' / 'DuoTestKit'
kit_toc = (kit / 'DuoTestKit.toc').read_text(encoding='utf-8')
assert '## SavedVariables: DuoTestKitDB' in kit_toc and '## Interface: 120105' in kit_toc, kit
for line in kit_toc.splitlines():
    if line and not line.startswith('#'):
        assert (kit / line).is_file(), (kit, line)
for path in kit.glob('*.lua'):
    code = path.read_text(encoding='utf-8')
    problems = native_violations(NATIVE_READER, code)
    assert not problems, (path, problems)
    assert not re.search(r'\b(SendAddonMessage|SendChatMessage|InviteUnit|CastSpellByID|TargetUnit|LootSlot)\s*\(', re.sub(r'--[^\n]*', '', code).replace('"SendAddonMessage"', '')), (path, 'kit must never act or send')
assert (root / 'devkit' / 'README.md').is_file()
common = [(root / n / 'Common.lua').read_bytes() for n in names]
assert all(c == common[0] for c in common), 'standalone Common.lua copies differ'
for folder in [root, *(root / n for n in names), root / 'docs', root / 'tools', root / 'docs' / 'run-sheets', root / 'devkit', kit]:
    for path in folder.iterdir():
        if path.is_file() and path.suffix in ('.lua', '.toc', '.md', '.py', '.ps1'):
            raw = path.read_bytes()
            assert not raw.startswith(b'\xef\xbb\xbf'), (path, 'BOM')
            assert b'\r' not in raw, (path, 'not LF')
            raw.decode('utf-8')
            text = raw.decode('utf-8')
            assert not re.search(r'(?i)\b[A-Z]:[\\/]|/(?:Users|home)/[^\s<>]+', text), (path, 'specific local path in public source')
            assert not re.search(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', text), (path, 'email address in public source')
print(f'PASS: five direct addon folders; {count} TOC load entries; exact filename case; UTF-8/LF; standalone helpers; runtime paths/action scan; no native Party Sync triggers.')
