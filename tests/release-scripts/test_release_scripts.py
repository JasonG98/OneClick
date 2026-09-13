import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[2]
CASK_SCRIPT = ROOT / "script" / "generate_cask.sh"
RELEASE_SCRIPT = ROOT / "script" / "release.sh"
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


class GenerateCaskTests(unittest.TestCase):
    def test_emits_executable_cask_with_archive_hash_and_platform_requirements(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "OneClick-1.2.3.zip"
            archive.write_bytes(b"a controlled OneClick archive\n")

            result = run(
                [
                    CASK_SCRIPT,
                    "1.2.3",
                    "https://github.com/example/oneclick/releases/download/v1.2.3/OneClick-1.2.3.zip",
                    "https://github.com/example/oneclick",
                    archive,
                ]
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            cask_path = Path(directory) / "oneclick.rb"
            cask_path.write_text(result.stdout)
            syntax = run(["ruby", "-c", cask_path])
            self.assertEqual(syntax.returncode, 0, syntax.stderr)

            evaluation = run(["ruby", CASK_PROBE, cask_path])
            self.assertEqual(evaluation.returncode, 0, evaluation.stderr)
            values = json.loads(evaluation.stdout)
            self.assertEqual(values["token"], "oneclick")
            self.assertEqual(values["version"], "1.2.3")
            self.assertEqual(
                values["sha256"], hashlib.sha256(archive.read_bytes()).hexdigest()
            )
            self.assertEqual(
                values["url"],
                "https://github.com/example/oneclick/releases/download/v1.2.3/OneClick-1.2.3.zip",
            )
            self.assertEqual(values["homepage"], "https://github.com/example/oneclick")
            self.assertEqual(values["depends_on"], {"arch": "arm64", "macos": "tahoe"})
            self.assertEqual(values["app"], "OneClick.app")

    def test_rejects_malformed_inputs_without_emitting_a_partial_cask(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "OneClick.zip"
            archive.write_bytes(b"archive")
            cases = [
                (
                    "version interpolation",
                    ["1.2.3#{raise 'injected'}", "https://example.com/OneClick.zip", "https://example.com", archive],
                ),
                (
                    "version prefix",
                    ["v1.2.3", "https://example.com/OneClick.zip", "https://example.com", archive],
                ),
                (
                    "non-HTTPS release URL",
                    ["1.2.3", "http://example.com/OneClick.zip", "https://example.com", archive],
                ),
                (
                    "Ruby interpolation in release URL",
                    ["1.2.3", "https://example.com/#{system('id')}.zip", "https://example.com", archive],
                ),
                (
                    "quote in homepage",
                    ["1.2.3", "https://example.com/OneClick.zip", 'https://example.com/"bad', archive],
                ),
                (
                    "missing archive",
                    ["1.2.3", "https://example.com/OneClick.zip", "https://example.com", Path(directory) / "missing.zip"],
                ),
            ]

            for label, arguments in cases:
                with self.subTest(label=label):
                    result = run([CASK_SCRIPT, *arguments])
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, "")

    def test_archive_path_may_be_omitted_and_defaults_to_the_release_output(self):
        """The documented flow should not need the path repeated.

        release.sh always writes dist/OneClick-<version>.zip, so the Cask for that
        release can be generated from the same three arguments rather than from a
        path the caller has to look up -- and looking it up is how a Cask ends up
        hashing the wrong file.
        """
        with tempfile.TemporaryDirectory() as directory:
            dist = Path(directory) / "dist"
            dist.mkdir()
            archive = dist / "OneClick-1.2.3.zip"
            archive.write_bytes(b"a controlled OneClick archive\n")

            environment = os.environ.copy()
            environment["ONECLICK_DIST_DIR"] = str(dist)
            arguments = ["1.2.3", "https://example.com/OneClick-1.2.3.zip", "https://example.com"]

            defaulted = run([CASK_SCRIPT, *arguments], env=environment)
            self.assertEqual(defaulted.returncode, 0, defaulted.stderr)
            explicit = run([CASK_SCRIPT, *arguments, archive], env=environment)

            self.assertIn(f'sha256 "{hashlib.sha256(archive.read_bytes()).hexdigest()}"',
                          defaulted.stdout)
            self.assertEqual(defaulted.stdout, explicit.stdout)

    def test_omitted_archive_that_does_not_exist_says_how_to_get_it(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = os.environ.copy()
            environment["ONECLICK_DIST_DIR"] = str(Path(directory) / "dist")

            result = run(
                [CASK_SCRIPT, "9.9.9", "https://example.com/OneClick.zip", "https://example.com"],
                env=environment,
            )

            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "")
            self.assertIn("release.sh 9.9.9", result.stderr)
            self.assertIn("ARCHIVE_PATH", result.stderr)

    def test_wrong_argument_count_exits_two(self):
        for arguments in ([], ["1.2.3"], ["1.2.3", "https://example.com", "https://example.com", "a", "b"]):
            with self.subTest(arguments=arguments):
                result = run([CASK_SCRIPT, *arguments])
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")


class ReleaseScriptTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.temp = Path(self.temporary_directory.name)
        self.bin = self.temp / "bin"
        self.bin.mkdir()
        self.log = self.temp / "commands.jsonl"
        self.derived_data = self.temp / "ReleaseDerivedData"
        self.dist = self.temp / "dist"
        self._install_fake_tools()

        self.environment = os.environ.copy()
        self.environment.update(
            {
                "PATH": f"{self.bin}:{self.environment['PATH']}",
                "ONECLICK_TEAM_ID": "AB12CD34EF",
                "ONECLICK_SIGNING_IDENTITY": "Developer ID Application: Example Developer (AB12CD34EF)",
                "ONECLICK_NOTARY_PROFILE": "oneclick-release-profile",
                "ONECLICK_DERIVED_DATA_PATH": str(self.derived_data),
                "ONECLICK_DIST_DIR": str(self.dist),
                "FAKE_COMMAND_LOG": str(self.log),
            }
        )

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_missing_required_inputs_stop_before_building(self):
        cases = [
            ("version", None),
            ("ONECLICK_TEAM_ID", "ONECLICK_TEAM_ID"),
            ("ONECLICK_SIGNING_IDENTITY", "ONECLICK_SIGNING_IDENTITY"),
            ("ONECLICK_NOTARY_PROFILE", "ONECLICK_NOTARY_PROFILE"),
        ]

        for label, missing_environment_name in cases:
            with self.subTest(label=label):
                if self.log.exists():
                    self.log.unlink()
                environment = self.environment.copy()
                arguments = [] if label == "version" else ["1.2.3"]
                if missing_environment_name:
                    environment.pop(missing_environment_name)

                result = run([RELEASE_SCRIPT, *arguments], env=environment)

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(label, result.stderr)
                self.assertFalse(self.log.exists(), "an external release command ran")

    def test_rejects_unsafe_release_configuration_before_building(self):
        cases = [
            ("version", "1.2;touch-pwned", None),
            ("team", "1.2.3", ("ONECLICK_TEAM_ID", "not a team")),
            ("identity", "1.2.3", ("ONECLICK_SIGNING_IDENTITY", "-")),
        ]

        for label, version, replacement in cases:
            with self.subTest(label=label):
                environment = self.environment.copy()
                if replacement:
                    environment[replacement[0]] = replacement[1]
                result = run([RELEASE_SCRIPT, version], env=environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.log.exists(), "an external release command ran")

    def test_exit_status_separates_a_bad_invocation_from_a_failed_release(self):
        """2 means "you called it wrong", 1 means "the work could not be done".

        Scripts and operators both branch on that difference, so it is pinned
        here rather than left to whatever `fail` happens to use.
        """
        cases = [
            ("no version", [], {}, 2),
            ("too many arguments", ["1.2.3", "extra"], {}, 2),
            ("missing inputs", ["1.2.3"], {"ONECLICK_TEAM_ID", "ONECLICK_SIGNING_IDENTITY"}, 2),
            ("malformed version", ["1.2;touch-pwned"], {}, 1),
            ("malformed team", ["1.2.3"], {"ONECLICK_TEAM_ID": "not a team"}, 1),
        ]

        for label, arguments, replacements, expected in cases:
            with self.subTest(label=label):
                environment = self.environment.copy()
                for name in (replacements if isinstance(replacements, set) else ()):
                    environment.pop(name)
                if isinstance(replacements, dict):
                    environment.update(replacements)
                result = run([RELEASE_SCRIPT, *arguments], env=environment)
                self.assertEqual(result.returncode, expected, result.stderr)
                if "version" in label:
                    self.assertIn("version", result.stderr)

    def test_prepares_signed_notarized_stapled_arm64_archive_in_order(self):
        result = run([RELEASE_SCRIPT, "1.2.3"], env=self.environment)

        self.assertEqual(result.returncode, 0, result.stderr)
        final_archive = self.dist / "OneClick-1.2.3.zip"
        self.assertTrue(final_archive.is_file())
        records = [json.loads(line) for line in self.log.read_text().splitlines()]

        build = next(record for record in records if record[0] == "xcodebuild")
        self.assertIn("-project", build)
        self.assertIn(str(ROOT / "OneClick.xcodeproj"), build)
        self.assertIn("-scheme", build)
        self.assertIn("OneClick", build)
        self.assertIn("ARCHS=arm64", build)
        self.assertIn("ONLY_ACTIVE_ARCH=NO", build)
        self.assertIn("DEVELOPMENT_TEAM=AB12CD34EF", build)
        self.assertIn(
            "CODE_SIGN_IDENTITY=Developer ID Application: Example Developer (AB12CD34EF)",
            build,
        )
        self.assertIn("ONECLICK_APP_GROUP=AB12CD34EF.local.oneclick.shared", build)
        self.assertIn("MARKETING_VERSION=1.2.3", build)

        names = [record[0] for record in records]
        self.assertEqual(names.count("lipo"), 2)
        first_codesign = names.index("codesign")
        notary = names.index("xcrun:notarytool")
        staple = names.index("xcrun:stapler:staple")
        staple_validation = names.index("xcrun:stapler:validate")
        gatekeeper = names.index("spctl")
        self.assertLess(first_codesign, notary)
        self.assertLess(notary, staple)
        self.assertLess(staple, staple_validation)
        self.assertLess(staple_validation, gatekeeper)
        self.assertEqual(names[-1], "ditto")

        notary_record = records[notary]
        self.assertIn("--keychain-profile", notary_record)
        self.assertIn("oneclick-release-profile", notary_record)
        self.assertIn("--wait", notary_record)
        self.assertIn("--deep", records[first_codesign])
        self.assertIn("--strict", records[first_codesign])
        self.assertIn("--type", records[gatekeeper])
        self.assertIn("execute", records[gatekeeper])

    def test_wrong_executable_architecture_stops_before_notarization(self):
        environment = self.environment.copy()
        environment["FAKE_LIPO_ARCHS"] = "x86_64 arm64"

        result = run([RELEASE_SCRIPT, "1.2.3"], env=environment)

        self.assertNotEqual(result.returncode, 0)
        records = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertNotIn("xcrun:notarytool", [record[0] for record in records])
        self.assertFalse((self.dist / "OneClick-1.2.3.zip").exists())

    def _install_fake_tools(self):
        self._write_executable(
            "xcodebuild",
            r'''#!/bin/bash
set -euo pipefail
python3 - "$FAKE_COMMAND_LOG" "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps(["xcodebuild", *sys.argv[2:]]) + "\n")
PY
arguments=("$@")
for ((index=0; index < ${#arguments[@]}; index++)); do
  if [[ "${arguments[$index]}" == "-derivedDataPath" ]]; then
    derived="${arguments[$((index + 1))]}"
  fi
done
app="$derived/Build/Products/Release/OneClick.app"
extension="$app/Contents/PlugIns/OneClickFinder.appex"
mkdir -p "$app/Contents/MacOS" "$extension/Contents/MacOS"
touch "$app/Contents/MacOS/OneClick" "$extension/Contents/MacOS/OneClickFinder"
chmod +x "$app/Contents/MacOS/OneClick" "$extension/Contents/MacOS/OneClickFinder"
for plist in "$app/Contents/Info.plist" "$extension/Contents/Info.plist"; do
  /usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 1.2.3' "$plist" >/dev/null
done
''',
        )
        self._write_executable(
            "lipo",
            r'''#!/bin/bash
python3 - "$FAKE_COMMAND_LOG" "$@" <<'PY'
import json, os, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps(["lipo", *sys.argv[2:]]) + "\n")
print(os.environ.get("FAKE_LIPO_ARCHS", "arm64"))
PY
''',
        )
        self._write_logging_tool("codesign")
        self._write_logging_tool("spctl")
        self._write_executable(
            "ditto",
            r'''#!/bin/bash
set -euo pipefail
python3 - "$FAKE_COMMAND_LOG" "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps(["ditto", *sys.argv[2:]]) + "\n")
PY
touch "${@: -1}"
''',
        )
        self._write_executable(
            "xcrun",
            r'''#!/bin/bash
set -euo pipefail
name="xcrun:$1"
if [[ "$1" == "stapler" ]]; then
  name="$name:$2"
fi
python3 - "$FAKE_COMMAND_LOG" "$name" "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps([sys.argv[2], *sys.argv[3:]]) + "\n")
PY
''',
        )

    def _write_logging_tool(self, name):
        self._write_executable(
            name,
            f'''#!/bin/bash
python3 - "$FAKE_COMMAND_LOG" "$@" <<'PY'
import json, sys
with open(sys.argv[1], "a") as stream:
    stream.write(json.dumps([{name!r}, *sys.argv[2:]]) + "\\n")
PY
''',
        )

    def _write_executable(self, name, content):
        path = self.bin / name
        path.write_text(textwrap.dedent(content))
        path.chmod(path.stat().st_mode | stat.S_IXUSR)


if __name__ == "__main__":
    unittest.main()
