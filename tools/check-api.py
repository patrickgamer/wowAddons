"""Development-only: check the API names the addons and the test kit use against Blizzard's generated
API documentation (the Blizzard_APIDocumentationGenerated folder of Blizzard's published UI source).

    python3 tools/check-api.py --api-dir <path to Blizzard_APIDocumentationGenerated>

Checks, for DuoBags, DuoUI, DuoSupport, DuoSocial, DuoAdventure and devkit/DuoTestKit:
  * C_Namespace.Function calls name a documented namespace and function;
  * Enum.Name[.Field] references name a documented enumeration and field;
  * RegisterEvent("EVENT") names a documented event;
  * capitalised global function calls are documented, defined by the addon, or called by Blizzard's own
    UI source (evidence a C-side global the documentation does not describe exists in that build).
This proves names exist in the documented build, not signatures, secrecy rules or runtime behaviour.
Exit status is 1 when any name is unknown.
"""
import argparse
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
targets = ['DuoBags', 'DuoUI', 'DuoSupport', 'DuoSocial', 'DuoAdventure', 'devkit/DuoTestKit']
# Names neither documented nor called by Blizzard's 12.1.5 UI source. They stay allowed so the check can
# gate everything else, but are printed on every run until a real client settles them.
UNVERIFIED = {
    'GetGuildRosterInfo': 'DuoSocial guild roster; absent from Blizzard 12.1.5 docs and UI source; settle in the guild session',
}


def parse_docs(folder):
    functions, namespaces, events, enums = set(), {}, set(), {}
    for path in sorted(folder.glob('*Documentation.lua')):
        text = path.read_text(encoding='utf-8', errors='replace')
        for match in re.finditer(r'\bNamespace = "(\w+)"', text):
            namespaces.setdefault(match.group(1), set())
        space = re.search(r'\bNamespace = "(\w+)"', text)
        fn_block = re.search(r'\n\tFunctions =\n(.*?)\n\t\},?\n\n\tEvents|\n\tFunctions =\n(.*?)\n\t\},?\n\n\tTables', text, re.S)
        fn_text = (fn_block.group(1) or fn_block.group(2)) if fn_block else ''
        if not fn_block:
            m = re.search(r'\n\tFunctions =\n(.*?)\n\t\},?\n(?=\n\t\w+ =|\n\}|\Z)', text, re.S)
            fn_text = m.group(1) if m else ''
        names = set(re.findall(r'\n\t\t\tName = "(\w+)",\n\t\t\tType = "Function"', fn_text))
        functions |= names
        if space:
            namespaces[space.group(1)] |= names
        events |= set(re.findall(r'LiteralName = "(\w+)"', text))
        for match in re.finditer(r'Name = "(\w+)",\n\t\t\tType = "Enumeration",.*?Fields =\n\t\t\t\{\n(.*?)\n\t\t\t\}', text, re.S):
            enums[match.group(1)] = set(re.findall(r'\{ Name = "(\w+)"', match.group(2)))
    return functions, namespaces, events, enums


def blank_strings(code):
    return re.sub(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', '""', code)


def ui_calls(folder):
    """Capitalised names Blizzard's own UI source calls: evidence a C-side global exists."""
    names = set()
    for path in folder.rglob('*.lua'):
        if 'APIDocumentation' not in str(path.parent):
            names |= set(re.findall(r'(?<![\w.:])([A-Z][A-Za-z0-9]+)\s*\(', path.read_text(encoding='utf-8', errors='replace')))
    return names


def strip(code):
    code = re.sub(r'--\[\[.*?\]\]', '', code, flags=re.S)
    return re.sub(r'--[^\n]*', '', code)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--api-dir', required=True, type=Path)
    parser.add_argument('--ui-dir', type=Path, help='Blizzard UI AddOns folder; default is the parent of --api-dir')
    args = parser.parse_args()
    if not args.api_dir.is_dir():
        sys.exit(f'not a folder: {args.api_dir}')
    functions, namespaces, events, enums = parse_docs(args.api_dir)
    if not functions or not namespaces or not events or not enums:
        sys.exit('API documentation parse found nothing; the folder is wrong or its format changed')
    ui_names = ui_calls(args.ui_dir or args.api_dir.parent)
    problems, checked, unverified = [], 0, set()
    for target in targets:
        folder = root / target
        if not folder.is_dir():
            continue
        sources = {p: strip(p.read_text(encoding='utf-8')) for p in sorted(folder.glob('*.lua'))}
        defined = set()
        for code in sources.values():
            defined |= set(re.findall(r'\bfunction\s+(\w+)\s*\(', code))
            defined |= set(re.findall(r'\b(\w+)\s*=\s*function\b', code))
        for path, code in sources.items():
            where = path.relative_to(root)
            for ns, fn in re.findall(r'\b(C_[A-Za-z]+)\.([A-Za-z]+)\b', code):
                checked += 1
                if ns not in namespaces:
                    problems.append(f'{where}: unknown namespace {ns}')
                elif fn not in namespaces[ns] and not re.search(rf'\b{ns}\.{fn}\b\s*=', code):
                    problems.append(f'{where}: {ns}.{fn} is not documented')
            for enum, field in re.findall(r'\bEnum\.([A-Za-z]+)(?:\.([A-Za-z_]+))?', code):
                checked += 1
                if enum not in enums:
                    problems.append(f'{where}: unknown enumeration Enum.{enum}')
                elif field and field not in enums[enum]:
                    problems.append(f'{where}: Enum.{enum}.{field} is not documented')
            for event in re.findall(r'RegisterEvent\(\s*"(\w+)"', code):
                checked += 1
                if event not in events:
                    problems.append(f'{where}: event {event} is not documented')
            for fn in set(re.findall(r'(?<![\w.:])([A-Z][A-Za-z0-9]+)\s*\(', blank_strings(code))):
                checked += 1
                if fn not in functions and fn not in defined and fn not in ui_names:
                    if fn in UNVERIFIED:
                        unverified.add(f'{where}: {fn}() - {UNVERIFIED[fn]}')
                        continue
                    problems.append(f'{where}: global {fn}() is not documented or defined')
    for problem in sorted(set(problems)):
        print('UNKNOWN', problem)
    for note in sorted(unverified):
        print('UNVERIFIED', note)
    print(f'{checked} name checks, {len(set(problems))} unknown; {len(functions)} documented functions, '
          f'{len(events)} events, {len(enums)} enumerations in {args.api_dir.name}')
    sys.exit(1 if problems else 0)


main()
