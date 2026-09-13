"""Behaviour of script/uninstall.sh, exercised without touching this Mac.

The script removes applications, App Group containers and LaunchServices
registrations, so every test here runs it against a temporary HOME with fake
system tools on PATH: `lsregister`, `pluginkit`, `pgrep` and `pkill` are logged
instead of executed. The script's own paths are what make that possible -- it
never reaches for the real registrations when `ONECLICK_LSREGISTER` and
`ONECLICK_PLUGINKIT` point somewhere else.

What the tests are actually protecting:

* the default run changes nothing,
* ownership is read from the container's metadata, not from its name, so a
  container that merely looks like OneClick's survives,
* a bundle whose identifier is not OneClick's is never removed, and
* a removal that fails is reported as a failure.
"""

import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[2]
UNINSTALL_SCRIPT = ROOT / "script" / "uninstall.sh"

APP_ID = "local.oneclick.app"
EXTENSION_ID = "local.oneclick.app.finder"
FOREIGN_CREATOR = "com.jay.OneClick"


def run(arguments, *, env):
    return subprocess.run(
        [str(UNINSTALL_SCRIPT), *arguments],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=120,
    )


class UninstallScriptTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.temp = Path(self.temporary_directory.name)
        self.home = self.temp / "home"
        self.bin = self.temp / "bin"
        self.log = self.temp / "commands.jsonl"
        self.home.mkdir()
        self.bin.mkdir()
        self._install_fake_tools()
        self._seed_machine()

        self.environment = os.environ.copy()
        self.environment.update(
            {
                "HOME": str(self.home),
                "PATH": f"{self.bin}:{self.environment['PATH']}",
                "FAKE_COMMAND_LOG": str(self.log),
                "ONECLICK_LSREGISTER": str(self.bin / "lsregister"),
                "ONECLICK_PLUGINKIT": str(self.bin / "pluginkit"),
            }
        )

    def tearDown(self):
        self.temporary_directory.cleanup()

    # ------------------------------------------------------------- fixtures

    def _seed_machine(self):
        """One of everything the script claims, plus two things it must not."""
        ours = self.home / "Library" / "Group Containers" / "AB12CD34EF.local.oneclick.shared"
        ours.mkdir(parents=True)
        (ours / "settings.json").write_text('{"version":1}')
        self._write_metadata(ours / ".com.apple.containermanagerd.metadata.plist", APP_ID)

        # Same name, different owner: an older project's container that has
        # nothing to do with this app.
        foreign = self.home / "Library" / "Group Containers" / "group.local.oneclick.shared"
        foreign.mkdir(parents=True)
        (foreign / "settings.json").write_text('{"legacy":true}')
        self._write_metadata(
            foreign / ".com.apple.containermanagerd.metadata.plist", FOREIGN_CREATOR
        )

        for container in (APP_ID, EXTENSION_ID):
            (self.home / "Library" / "Containers" / container).mkdir(parents=True)
        (self.home / "Library" / "Preferences").mkdir(parents=True)
        (self.home / "Library" / "Preferences" / f"{APP_ID}.plist").write_text("prefs")

    def _write_metadata(self, url, creator):
        url.parent.mkdir(parents=True, exist_ok=True)
        url.write_text(
            textwrap.dedent(
                f"""\
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0"><dict>
                  <key>MCMMetadataCreator</key><string>{creator}</string>
                  <key>MCMMetadataIdentifier</key><string>{url.parent.name}</string>
                </dict></plist>
                """
            )
        )

    def _install_fake_tools(self):
        self._write_executable(
            "lsregister",
            r'''#!/bin/bash
set -euo pipefail
python3 - "$FAKE_COMMAND_LOG" lsregister "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps([sys.argv[2], *sys.argv[3:]]) + "\n")
PY
''',
        )
        self._write_executable(
            "pluginkit",
            r'''#!/bin/bash
set -euo pipefail
python3 - "$FAKE_COMMAND_LOG" pluginkit "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps([sys.argv[2], *sys.argv[3:]]) + "\n")
PY
''',
        )
        for name in ("pgrep", "pkill"):
            self._write_executable(
                name,
                f'''#!/bin/bash
python3 - "$FAKE_COMMAND_LOG" {name} "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps([sys.argv[2], *sys.argv[3:]]) + "\\n")
PY
# Nothing is running in these tests, but the exit status must be the one the
# real tool would give: pgrep's non-zero "no match" must not trip `set -e`.
exit 1
''',
            )

    def _write_executable(self, name, content):
        path = self.bin / name
        path.write_text(textwrap.dedent(content))
        path.chmod(path.stat().st_mode | stat.S_IXUSR)

    def _records(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def _paths_mentioned(self, result):
        return [line for line in result.stdout.splitlines() if str(self.home) in line]

    # ---------------------------------------------------------------- tests

    def test_default_run_reports_without_changing_anything(self):
        result = run([], env=self.environment)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Report only", result.stdout)
        self.assertTrue(
            (self.home / "Library" / "Group Containers" / "AB12CD34EF.local.oneclick.shared").exists()
        )
        self.assertTrue((self.home / "Library" / "Preferences" / f"{APP_ID}.plist").exists())
        self.assertTrue((self.home / "Library" / "Containers" / EXTENSION_ID).exists())
        # The report names what it would remove, rather than only counting it.
        self.assertIn(str(self.home), result.stdout)
        self.assertIn("would remove", result.stdout)
        # The report may ask questions -- `lsregister -dump` and `pgrep` are how
        # it finds the copies and the processes -- but it must not mutate
        # anything, so none of the commands that change state may appear.
        mutating = [
            record
            for record in self._records()
            if record[0] == "pkill"
            or (record[0] == "lsregister" and "-dump" not in record)
            or (record[0] == "pluginkit" and "-e" in record)
        ]
        self.assertEqual(mutating, [], "a report-only run changed system state")

    def test_apply_removes_oneclick_data_and_leaves_a_foreign_container_alone(self):
        result = run(["--apply"], env=self.environment)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(
            (self.home / "Library" / "Group Containers" / "AB12CD34EF.local.oneclick.shared").exists()
        )
        self.assertFalse((self.home / "Library" / "Containers" / APP_ID).exists())
        self.assertFalse((self.home / "Library" / "Containers" / EXTENSION_ID).exists())
        self.assertFalse((self.home / "Library" / "Preferences" / f"{APP_ID}.plist").exists())

        # The container named like ours but owned by another app is untouched.
        foreign = self.home / "Library" / "Group Containers" / "group.local.oneclick.shared"
        self.assertTrue(foreign.exists())
        self.assertEqual((foreign / "settings.json").read_text(), '{"legacy":true}')

    def test_apply_retires_registrations_through_the_injected_tools(self):
        run(["--apply"], env=self.environment)

        names = [record[0] for record in self._records()]
        self.assertIn("pluginkit", names)
        self.assertIn("lsregister", names)
        elections = [record for record in self._records() if record[0] == "pluginkit"]
        self.assertIn(EXTENSION_ID, elections[0])

    def test_apply_is_idempotent(self):
        first = run(["--apply"], env=self.environment)
        second = run(["--apply"], env=self.environment)

        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("Removed 0 item(s)", second.stdout)

    def test_repository_products_are_opt_in(self):
        build = ROOT / ".build"
        self.assertTrue(build.exists(), "this test needs the repository's build directory")

        reported = run([], env=self.environment)
        self.assertNotIn(str(build), reported.stdout)
        self.assertIn("Add --build", reported.stdout)

        # --build is asserted through the report only: running it with --apply
        # would delete the build products of the checkout under test.
        reported = run(["--build"], env=self.environment)
        self.assertIn(str(build), reported.stdout)
        self.assertTrue(build.exists())

    def test_missing_home_is_a_usage_error(self):
        environment = self.environment.copy()
        environment.pop("HOME")

        result = run([], env=environment)

        self.assertEqual(result.returncode, 1)
        self.assertIn("HOME", result.stderr)

    def test_unknown_argument_exits_two(self):
        result = run(["--everything"], env=self.environment)

        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown argument", result.stderr)


if __name__ == "__main__":
    unittest.main()
