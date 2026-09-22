import hashlib
import json
import os
import sys
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
RELEASE_SCRIPT = ROOT / "script" / "release.py"
CASK_PROBE = Path(__file__).with_name("cask_probe.rb")


def run(command, *, env=None):
    return subprocess.run(
        [str(part) for part in command],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


class ReleaseScriptTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory(
            prefix="oneclick release "
        )
        self.addCleanup(self.temporary_directory.cleanup)
        self.temp = Path(self.temporary_directory.name)
        self.bin = self.temp / "bin"
        self.bin.mkdir()
        self.log = self.temp / "commands.jsonl"
        self.dist = self.temp / "dist"
        self.environment = os.environ.copy()
        for name in (
            "ONECLICK_TEAM_ID",
            "ONECLICK_SIGNING_IDENTITY",
            "ONECLICK_NOTARY_PROFILE",
        ):
            self.environment.pop(name, None)
        self.environment.update(
            {
                "PATH": f"{self.bin}:{self.environment['PATH']}",
                "ONECLICK_DERIVED_DATA_PATH": str(self.temp / "Derived Data"),
                "ONECLICK_DIST_DIR": str(self.dist),
                "FAKE_COMMAND_LOG": str(self.log),
                "GH_REPO": "example/oneclick",
                "GH_TOKEN": "fixture",
            }
        )
        fake = Path(__file__).with_name("fake_release_tool.py").read_text()
        for name in (
            "xcodebuild",
            "lipo",
            "codesign",
            "ditto",
            "hdiutil",
            "xcrun",
            "spctl",
            "gh",
            "git",
        ):
            tool = self.bin / name
            tool.write_text(fake)
            tool.chmod(0o755)

    def records(self):
        return (
            [json.loads(line) for line in self.log.read_text().splitlines()]
            if self.log.exists()
            else []
        )

    def test_builds_verified_adhoc_dmg_without_apple_configuration(self):
        result = run([sys.executable, RELEASE_SCRIPT, "1.2.3"], env=self.environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        archive = self.dist / "OneClick-1.2.3.dmg"
        self.assertEqual(archive.read_bytes(), b"controlled DMG")
        checksum = (self.dist / "OneClick-1.2.3.dmg.sha256").read_text()
        self.assertEqual(
            checksum,
            f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n",
        )
        records = self.records()
        build = records[0]
        for setting in (
            "ARCHS=arm64",
            "ONLY_ACTIVE_ARCH=NO",
            "DEVELOPMENT_TEAM=",
            "CODE_SIGN_IDENTITY=-",
            "CODE_SIGN_STYLE=Manual",
            "CODE_SIGNING_ALLOWED=YES",
            "MARKETING_VERSION=1.2.3",
        ):
            self.assertIn(setting, build)
        self.assertFalse(any("ONECLICK_APP_GROUP" in arg for arg in build))
        names = [record[0] for record in records]
        self.assertNotIn("xcrun", names)
        self.assertNotIn("spctl", names)
        create = next(
            record for record in records if record[:2] == ["hdiutil", "create"]
        )
        self.assertIn("UDZO", create)
        self.assertIn(["hdiutil", "verify"], [record[:2] for record in records])
        cask = self.dist / "oneclick.rb"
        probe = run(["ruby", CASK_PROBE, cask])
        self.assertEqual(probe.returncode, 0, probe.stderr)
        metadata = json.loads(probe.stdout)
        self.assertEqual(metadata["version"], "1.2.3")
        self.assertEqual(
            metadata["sha256"], hashlib.sha256(archive.read_bytes()).hexdigest()
        )
        self.assertEqual(
            metadata["url"],
            "https://github.com/example/oneclick/releases/download/v1.2.3/OneClick-1.2.3.dmg",
        )
        self.assertEqual(metadata["depends_on"], {"arch": "arm64", "macos": "tahoe"})
        self.assertLess(names.index("codesign"), names.index("ditto"))
        self.assertEqual(list(self.dist.glob(".oneclick-*")), [])

    def test_invalid_version_or_invocation_never_builds(self):
        for arguments, status in (
            ([], 2),
            (["1.2.3", "extra"], 2),
            (["v1.2.3"], 2),
            (["01.2.3"], 2),
            (["1.2;touch-pwned"], 2),
        ):
            with self.subTest(arguments=arguments):
                result = run(
                    [sys.executable, RELEASE_SCRIPT, *arguments], env=self.environment
                )
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(self.records(), [])

    def test_failures_preserve_previous_release_and_remove_staging(self):
        self.dist.mkdir()
        archive = self.dist / "OneClick-1.2.3.dmg"
        archive.write_bytes(b"previous verified release")
        for failure in (
            "xcodebuild",
            "codesign",
            "ditto",
            "hdiutil:create",
            "hdiutil:verify",
        ):
            with self.subTest(failure=failure):
                environment = {**self.environment, "FAKE_FAIL": failure}
                result = run([sys.executable, RELEASE_SCRIPT, "1.2.3"], env=environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(archive.read_bytes(), b"previous verified release")
                self.assertEqual(list(self.dist.glob(".oneclick-*")), [])

    def test_wrong_architecture_version_or_signature_stops_before_packaging(self):
        for key, value in (
            ("FAKE_ARCHS", "x86_64 arm64"),
            ("FAKE_VERSION", "9.9.9"),
            ("FAKE_SIGNATURE", "Apple Development"),
        ):
            with self.subTest(key=key):
                if self.log.exists():
                    self.log.unlink()
                result = run(
                    [sys.executable, RELEASE_SCRIPT, "1.2.3"],
                    env={**self.environment, key: value},
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("hdiutil", [record[0] for record in self.records()])
                self.assertFalse((self.dist / "OneClick-1.2.3.dmg").exists())

    def test_repository_injection_never_reaches_build_or_cask(self):
        result = run(
            [sys.executable, RELEASE_SCRIPT, "1.2.3"],
            env={**self.environment, "GH_REPO": "example/#{abort}"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.records(), [])

    def test_draft_create_update_and_published_release_protection(self):
        for state, action in (
            ("missing", "create"),
            ("true", "upload"),
            ("false", None),
            ("invalid", None),
        ):
            with self.subTest(state=state):
                if self.log.exists():
                    self.log.unlink()
                result = run(
                    [sys.executable, RELEASE_SCRIPT, "1.2.3", "--draft"],
                    env={**self.environment, "FAKE_STATE": state},
                )
                changes = [
                    r
                    for r in self.records()
                    if r[:2] == ["gh", "release"] and r[2] != "view"
                ]
                if action is None:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(changes, [])
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(
                        changes[0][:4], ["gh", "release", action, "v1.2.3"]
                    )
                    if action == "create":
                        self.assertIn("--draft", changes[0])
                        self.assertIn("--verify-tag", changes[0])
                    self.assertIn(str(self.dist / "oneclick.rb"), changes[0])

    def test_draft_rejects_mismatched_tag_before_build(self):
        result = run(
            [sys.executable, RELEASE_SCRIPT, "1.2.3", "--draft"],
            env={**self.environment, "FAKE_TAG_REVISION": "different"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("xcodebuild", [r[0] for r in self.records()])

    def test_draft_rejects_worktree_changes_before_build(self):
        for status in (
            "?? src/app/NewFeature.swift",
            " M config/OneClick-Info.plist",
            "A  src/app/NewFeature.swift",
        ):
            with self.subTest(status=status):
                if self.log.exists():
                    self.log.unlink()
                result = run(
                    [sys.executable, RELEASE_SCRIPT, "1.2.3", "--draft"],
                    env={**self.environment, "FAKE_GIT_STATUS": status},
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("xcodebuild", [r[0] for r in self.records()])
                self.assertNotIn("gh", [r[0] for r in self.records()])
