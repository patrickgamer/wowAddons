"""Development-only: run lua-language-server over the addons and the kit with WoW API definitions.

    python3 tools/check-types.py --wow-api <path to Ketho/vscode-wow-api Annotations folder>

The definitions are community generated from Blizzard's documentation and may trail the live build, so a
finding is a prompt to check tools/check-api.py and Blizzard's source, not proof. Needs lua-language-server
on the search path (macOS: brew install lua-language-server). Writes only to a temporary folder.
"""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--wow-api', required=True, type=Path)
args = parser.parse_args()
if not args.wow_api.is_dir():
    sys.exit(f'not a folder: {args.wow_api}')
with tempfile.TemporaryDirectory() as tmp:
    config = Path(tmp) / 'luarc.json'
    config.write_text(json.dumps({
        'runtime.version': 'Lua 5.1',
        'workspace.library': [str(args.wow_api.resolve())],
        'workspace.ignoreDir': ['tools', '.git'],
        'diagnostics.disable': ['lowercase-global', 'duplicate-set-field', 'inject-field', 'missing-fields'],
    }), encoding='utf-8')
    result = subprocess.run(['lua-language-server', '--check', str(root), '--checklevel=Warning',
                             f'--configpath={config}', f'--logpath={tmp}'], text=True)
sys.exit(result.returncode)
