"""Repository hygiene: the real signing details never enter version control.

`config/Local.xcconfig` holds `DEVELOPMENT_TEAM`, and the App Group identifier
is that team id with a fixed suffix, so the same string also shows up in any
path written next to a container. Neither belongs in a commit: the team id
identifies the developer account, and the file exists precisely so that local
signing configuration can differ per machine.

What the tests are actually protecting:

* the ignored local configuration is never tracked, and
* the team id it holds appears nowhere in the working tree, so a path pasted
  into a document cannot carry it into history.

Build products are skipped, not exempt by accident: `.build/` contains the
signed extension with the expanded group identifier inside its binary.
"""

import os
from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
LOCAL_CONFIG = ROOT / "config" / "Local.xcconfig"

# Trees that are ignored, generated, or build output. `.build/` in particular
# embeds the expanded App Group id in the signed extension binary.
SKIPPED_DIRECTORIES = {".git", ".build", "dist", ".superpowers"}

TEAM_SETTING = re.compile(r"^\s*DEVELOPMENT_TEAM\s*=\s*(\S+)\s*$", re.MULTILINE)


def local_team_id():
    """The team id from the ignored local configuration, or None."""
    try:
        contents = LOCAL_CONFIG.read_text(encoding="utf-8")
    except OSError:
        return None
    match = TEAM_SETTING.search(contents)
    return match.group(1) if match else None


def working_tree_files():
    for directory, subdirectories, filenames in os.walk(ROOT):
        subdirectories[:] = [name for name in subdirectories if name not in SKIPPED_DIRECTORIES]
        for filename in filenames:
            path = Path(directory) / filename
            if path != LOCAL_CONFIG:
                yield path


class RepositoryHygieneTests(unittest.TestCase):
    def test_local_signing_config_is_never_tracked(self):
        """The team id lives in an ignored file; tracking it defeats that."""
        tracked = subprocess.run(
            ["git", "ls-files", "config/Local.xcconfig"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        self.assertEqual(
            tracked.stdout.strip(),
            "",
            "config/Local.xcconfig is tracked; it must stay in .gitignore",
        )

    def test_the_local_team_id_appears_nowhere_in_the_working_tree(self):
        """A path in a document must write the team id as a placeholder."""
        team = local_team_id()
        if team is None:
            self.skipTest("config/Local.xcconfig has no DEVELOPMENT_TEAM to guard")

        offenders = []
        needle = team.encode()
        for path in working_tree_files():
            try:
                contents = path.read_bytes()
            except OSError:
                continue
            if needle in contents:
                offenders.append(str(path.relative_to(ROOT)))

        self.assertEqual(
            offenders,
            [],
            "the real team id appears outside config/Local.xcconfig; "
            "write <Team ID> in documents and fixtures instead: " + ", ".join(sorted(offenders)),
        )


if __name__ == "__main__":
    unittest.main()
