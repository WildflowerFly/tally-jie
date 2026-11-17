"""Local WSL -> Windows DevEco build helper. Pass Studio Windows directory and optional module target.
Does not configure signing, install or push. Requires powershell.exe on PATH.
"""
import base64
import subprocess
import sys

studio = sys.argv[1].replace("'", "''")
target = sys.argv[2] if len(sys.argv) > 2 else 'default'
if target not in ('default', 'ohosTest'):
    raise SystemExit('target must be default or ohosTest')
script = r"""
@D@s = '__STUDIO__'
@D@env:JAVA_HOME = "@D@s\jbr"
@D@env:DEVECO_SDK_HOME = "@D@s\sdk"
Set-Location '__PROJECT__'
& "@D@s\tools\node\node.exe" "@D@s\tools\hvigor\bin\hvigorw.js" --mode module -p product=default -p module=entry@__TARGET__ assembleHap --no-daemon
exit @D@LASTEXITCODE
"""
from pathlib import Path
project = subprocess.check_output(['wslpath', '-w', str(Path(__file__).resolve().parents[1])], text=True).strip().replace("'", "''")
script = script.replace('__STUDIO__', studio).replace('__PROJECT__', project).replace('__TARGET__', target).replace('@D@', chr(36))
result = subprocess.run(['powershell.exe', '-NoProfile', '-EncodedCommand', base64.b64encode(script.encode('utf-16le')).decode()], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
print(result.stdout.decode(errors='replace'))
raise SystemExit(result.returncode)
