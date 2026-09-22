"""Test dry-run, ownership checks and failure handling in an isolated temporary home.

System actions are replaced; legacy containers and repository data must survive.
"""

import json
import os
import plistlib
import shutil
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
        [str(Path(env["ONECLICK_TEST_REPO"]) / "script/uninstall.sh"), *arguments],
        cwd=env["ONECLICK_TEST_REPO"],
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
        # The script discovers its repository from its own path. A fake HOME alone
        # would still let --apply delete this checkout's real build products.
        self.repository = self.temp / "repository"
        (self.repository / "script").mkdir(parents=True)
        (self.repository / ".build").mkdir()
        for name in ("uninstall.sh",):
            shutil.copy2(ROOT / "script" / name, self.repository / "script" / name)
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
                "ONECLICK_TEST_REPO": str(self.repository),
                "ONECLICK_APPLICATIONS_DIR": str(self.temp / "Applications"),
            }
        )

    def tearDown(self):
        self.temporary_directory.cleanup()

    # ------------------------------------------------------------- fixtures

    def _seed_machine(self):
        """One of everything the script claims, plus two things it must not."""
        self.shared = self.home / "Library/Application Support/OneClick"
        self.shared.mkdir(parents=True)
        (self.shared / "settings.json").write_text('{"version":1}')
        (self.shared / ".oneclick-owner.plist").write_bytes(
            plistlib.dumps({"CFBundleIdentifier": APP_ID})
        )
        ours = (
            self.home / "Library" / "Group Containers" / "legacy.local.oneclick.shared"
        )
        ours.mkdir(parents=True)
        (ours / "settings.json").write_text('{"version":1}')
        self._write_metadata(
            ours / ".com.apple.containermanagerd.metadata.plist", APP_ID
        )

        # Same name, different owner: an older project's container that has
        # nothing to do with this app.
        foreign = (
            self.home / "Library" / "Group Containers" / "group.local.oneclick.shared"
        )
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
            r"""#!/bin/bash
set -euo pipefail
python3 - "$FAKE_COMMAND_LOG" lsregister "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps([sys.argv[2], *sys.argv[3:]]) + "\n")
PY
""",
        )
        self._write_executable(
            "pluginkit",
            r"""#!/bin/bash
set -euo pipefail
python3 - "$FAKE_COMMAND_LOG" pluginkit "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps([sys.argv[2], *sys.argv[3:]]) + "\n")
PY
""",
        )
        for name in ("pgrep", "pkill"):
            self._write_executable(
                name,
                f"""#!/bin/bash
python3 - "$FAKE_COMMAND_LOG" {name} "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps([sys.argv[2], *sys.argv[3:]]) + "\\n")
PY
# Nothing is running in these tests, but the exit status must be the one the
# real tool would give: pgrep's non-zero "no match" must not trip `set -e`.
exit 1
""",
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
            (
                self.home
                / "Library"
                / "Group Containers"
                / "legacy.local.oneclick.shared"
            ).exists()
        )
        self.assertTrue(
            (self.home / "Library" / "Preferences" / f"{APP_ID}.plist").exists()
        )
        self.assertTrue((self.home / "Library" / "Containers" / EXTENSION_ID).exists())
        self.assertTrue(self.shared.exists())
        self.assertIn(str(self.shared), result.stdout)
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
        self.assertTrue(
            (
                self.home
                / "Library"
                / "Group Containers"
                / "legacy.local.oneclick.shared"
            ).exists()
        )
        self.assertFalse((self.home / "Library" / "Containers" / APP_ID).exists())
        self.assertFalse((self.home / "Library" / "Containers" / EXTENSION_ID).exists())
        self.assertFalse(
            (self.home / "Library" / "Preferences" / f"{APP_ID}.plist").exists()
        )
        self.assertFalse(self.shared.exists())

        # The container named like ours but owned by another app is untouched.
        foreign = (
            self.home / "Library" / "Group Containers" / "group.local.oneclick.shared"
        )
        self.assertTrue(foreign.exists())
        self.assertEqual((foreign / "settings.json").read_text(), '{"legacy":true}')

    def test_apply_retires_registrations_through_the_injected_tools(self):
        run(["--apply"], env=self.environment)

        names = [record[0] for record in self._records()]
        self.assertIn("pluginkit", names)
        self.assertIn("lsregister", names)
        elections = [record for record in self._records() if record[0] == "pluginkit"]
        self.assertIn(EXTENSION_ID, elections[0])

    def test_shared_directory_without_our_marker_is_preserved(self):
        marker = self.shared / ".oneclick-owner.plist"
        for owner in (None, "another.app"):
            with self.subTest(owner=owner):
                if owner is None:
                    marker.unlink()
                else:
                    marker.write_bytes(plistlib.dumps({"CFBundleIdentifier": owner}))
                result = run(["--apply"], env=self.environment)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((self.shared / "settings.json").exists())
                self.assertIn("preserved", result.stdout)

    def test_shared_directory_symlink_is_never_followed(self):
        other = self.home / "other"
        self.shared.rename(other)
        self.shared.symlink_to(other, target_is_directory=True)
        result = run(["--apply"], env=self.environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.shared.is_symlink())
        self.assertTrue((other / "settings.json").exists())

    def test_marker_symlink_is_not_ownership_proof(self):
        marker = self.shared / ".oneclick-owner.plist"
        other = self.home / "foreign-marker.plist"
        marker.rename(other)
        marker.symlink_to(other)
        result = run(["--apply"], env=self.environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.shared / "settings.json").exists())

    def test_apply_is_idempotent(self):
        first = run(["--apply"], env=self.environment)
        second = run(["--apply"], env=self.environment)

        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("Removed 0 item(s)", second.stdout)

    def test_uninstall_preserves_build_products_and_legacy_configuration(self):
        config = self.repository / "config/Local.xcconfig"
        config.parent.mkdir()
        config.write_text("private configuration")
        result = run(["--apply"], env=self.environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.repository / ".build").exists())
        self.assertEqual(config.read_text(), "private configuration")
        for argument in ("--build", "--local-config"):
            self.assertEqual(run([argument], env=self.environment).returncode, 2)

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
