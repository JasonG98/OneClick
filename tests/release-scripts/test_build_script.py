"""Run modes must reach an ad hoc build without querying Apple credentials."""

import json
import os
import plistlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildScriptTests(unittest.TestCase):
    def test_verify_requires_both_app_and_extension(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "script").mkdir()
            (root / "bin").mkdir()
            app = root / ".build/DerivedData/Build/Products/Debug/OneClick.app"
            extension = app / "Contents/PlugIns/OneClickFinder.appex"
            for bundle, identifier in (
                (app, "local.oneclick.app"),
                (extension, "local.oneclick.app.finder"),
            ):
                (bundle / "Contents").mkdir(parents=True, exist_ok=True)
                (bundle / "Contents/Info.plist").write_bytes(
                    plistlib.dumps({"CFBundleIdentifier": identifier})
                )
            source = (ROOT / "script/build_and_run.sh").read_text()
            # Substitute absolute OS command boundaries in this disposable copy.
            # Keep every branch of the production script, but never open an app
            # or mutate the host's real extension registrations.
            for absolute in (
                "/usr/bin/open",
                "/usr/bin/codesign",
                "/usr/bin/pluginkit",
                "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister",
            ):
                source = source.replace(
                    absolute, str(root / "bin" / Path(absolute).name)
                )
            (root / "script/build_and_run.sh").write_text(source)
            commands = {
                "open": 'touch "$FAKE_STARTED"\n',
                "ps": 'printf "%s\\n" "$FAKE_APP_BINARY"\n',
                "pluginkit": """if [[ "$1" == -m && "$FAKE_LOOKUP_FAIL" == 1 ]]; then exit 1; fi
if [[ "$1" == -a ]]; then
  count=0
  [[ ! -f "$FAKE_REGISTRATIONS" ]] || count="$(cat "$FAKE_REGISTRATIONS")"
  echo "$((count + 1))" > "$FAKE_REGISTRATIONS"
fi
""",
                "pgrep": """[[ -e "$FAKE_STARTED" ]] || exit 1
if [[ "$*" == "-x OneClick" || "$FAKE_EXTENSION_RUNNING" == 1 ]]; then
  echo 999999999
elif [[ "$FAKE_EXTENSION_RUNNING" == retry && -f "$FAKE_REGISTRATIONS" && "$(cat "$FAKE_REGISTRATIONS")" -ge 2 ]]; then
  echo 999999999
else
  exit 1
fi
""",
            }
            for name in (
                "xcodebuild",
                "open",
                "codesign",
                "pluginkit",
                "lsregister",
                "sleep",
                "pgrep",
                "ps",
            ):
                tool = root / "bin" / name
                tool.write_text("#!/bin/bash\n" + commands.get(name, "exit 0\n"))
                tool.chmod(0o755)
            started = root / "started"
            registrations = root / "registrations"
            env = {
                **os.environ,
                "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
                "FAKE_STARTED": str(started),
                "FAKE_APP_BINARY": str(app / "Contents/MacOS/OneClick"),
                "FAKE_REGISTRATIONS": str(registrations),
            }
            for running, lookup_fail, expected in (
                ("0", "0", 1),
                ("1", "0", 0),
                ("retry", "0", 0),
                ("retry", "1", 0),
            ):
                with self.subTest(extension_running=running, lookup_fail=lookup_fail):
                    if started.exists():
                        started.unlink()
                    if registrations.exists():
                        registrations.unlink()
                    result = subprocess.run(
                        ["bash", str(root / "script/build_and_run.sh")],
                        env={
                            **env,
                            "FAKE_EXTENSION_RUNNING": running,
                            "FAKE_LOOKUP_FAIL": lookup_fail,
                        },
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(
                        result.returncode, expected, result.stdout + result.stderr
                    )

    def test_all_modes_build_without_team_and_stop_safely_on_build_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "script").mkdir()
            (root / "bin").mkdir()
            for name in ("build_and_run.sh",):
                shutil.copy2(ROOT / "script" / name, root / "script" / name)
            log = root / "arguments.json"
            build = root / "bin/xcodebuild"
            build.write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ["FAKE_BUILD_LOG"], "w") as stream:
    json.dump(sys.argv[1:], stream)
sys.exit(42)
""")
            build.chmod(0o755)
            pgrep = root / "bin/pgrep"
            pgrep.write_text("#!/bin/sh\nexit 1\n")
            pgrep.chmod(0o755)
            env = {
                **os.environ,
                "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
                "FAKE_BUILD_LOG": str(log),
            }
            env.pop("ONECLICK_TEAM_ID", None)
            for arguments in ([], ["--build-only"]):
                with self.subTest(arguments=arguments):
                    if log.exists():
                        log.unlink()
                    result = subprocess.run(
                        [str(root / "script/build_and_run.sh"), *arguments],
                        env=env,
                        capture_output=True,
                        text=True,
                    )
                    self.assertTrue(log.exists(), result.stderr)
                    self.assertEqual(result.returncode, 1)
                    settings = json.loads(log.read_text())
                    self.assertIn("CODE_SIGN_IDENTITY=-", settings)
                    self.assertIn("DEVELOPMENT_TEAM=", settings)
                    self.assertIn("CODE_SIGNING_ALLOWED=YES", settings)
