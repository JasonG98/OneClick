#!/usr/bin/env python3
"""Release tools with temporary files and recorded arguments, never system effects."""

import json
import os
from pathlib import Path
import plistlib
import shutil
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["FAKE_COMMAND_LOG"], "a") as stream:
    stream.write(json.dumps([name, *args]) + "\n")
if os.environ.get("FAKE_FAIL") in (name, f"{name}:{args[0]}"):
    sys.exit(1)
if name == "xcodebuild":
    derived = Path(args[args.index("-derivedDataPath") + 1])
    mode = args[args.index("-configuration") + 1]
    app = derived / "Build/Products" / mode / "OneClick.app"
    extension = app / "Contents/PlugIns/OneClickFinder.appex"
    for bundle, executable in ((app, "OneClick"), (extension, "OneClickFinder")):
        binary = bundle / "Contents/MacOS" / executable
        binary.parent.mkdir(parents=True, exist_ok=True)
        binary.write_bytes(b"test binary")
        binary.chmod(0o755)
        (bundle / "Contents/Info.plist").write_bytes(
            plistlib.dumps(
                {"CFBundleShortVersionString": os.environ.get("FAKE_VERSION", "1.2.3")}
            )
        )
elif name == "lipo":
    print(os.environ.get("FAKE_ARCHS", "arm64"))
elif name == "codesign" and "-dv" in args:
    print("Signature=" + os.environ.get("FAKE_SIGNATURE", "adhoc"), file=sys.stderr)
elif name == "ditto":
    shutil.copytree(args[-2], args[-1], symlinks=True)
elif name == "hdiutil" and args[0] == "create":
    folder = Path(args[args.index("-srcfolder") + 1])
    assert (folder / "OneClick.app/Contents/MacOS/OneClick").is_file()
    assert (folder / "Applications").readlink() == Path("/Applications")
    assert "xattr" in (folder / "INSTALL.txt").read_text()
    Path(args[-1]).write_bytes(b"controlled DMG")

elif name == "git":
    if args[0] == "status":
        print(os.environ.get("FAKE_GIT_STATUS", ""))
    elif args[0] == "rev-parse":
        print(
            os.environ.get("FAKE_TAG_REVISION", "revision")
            if "refs/tags/" in args[-1]
            else "revision"
        )
elif name == "gh" and args[:2] == ["release", "view"]:
    state = os.environ.get("FAKE_STATE", "missing")
    if state == "missing":
        sys.exit(1)
    print(state)
