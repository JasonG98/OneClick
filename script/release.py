#!/usr/bin/env python3
"""生成 DMG、校验和与 Cask; --draft 将同一份产物上传到 GitHub 草稿."""

import argparse
import hashlib
import os
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(*args: str) -> str:
    """调用系统工具, 失败时终止发布."""
    return subprocess.check_output(args, cwd=ROOT, text=True, stderr=subprocess.STDOUT)


def version(value: str) -> str:
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", value):
        raise argparse.ArgumentTypeError("版本格式为 MAJOR.MINOR.PATCH, 不带 v")
    return value


def cask(release: str, digest: str, repository: str) -> str:
    return f'''cask "oneclick" do
  version "{release}"
  sha256 "{digest}"
  url "https://github.com/{repository}/releases/download/v{release}/OneClick-{release}.dmg"
  name "OneClick"
  desc "Open Finder directories in your favorite applications and copy paths"
  homepage "https://github.com/{repository}"
  depends_on arch: :arm64
  depends_on macos: :tahoe
  app "OneClick.app"
  uninstall quit: ["local.oneclick.app", "local.oneclick.app.finder"]
  caveats <<~EOS
    OneClick is ad hoc signed and not notarized. If macOS blocks it,
    verify the download, then run:
      xattr -dr com.apple.quarantine "#{{appdir}}/OneClick.app"
    Open OneClick and enable its Finder extension in System Settings.
  EOS
end
'''


def package(release: str, repository: str) -> list[Path]:
    """先在临时目录准备所有产物, 验证成功后替换已有文件."""
    derived = Path(
        os.environ.get("ONECLICK_DERIVED_DATA_PATH", ROOT / ".build/ReleaseDerivedData")
    )
    output = Path(os.environ.get("ONECLICK_DIST_DIR", ROOT / "dist"))
    output.mkdir(parents=True, exist_ok=True)
    app = derived / "Build/Products/Release/OneClick.app"
    extension = app / "Contents/PlugIns/OneClickFinder.appex"
    run(
        "xcodebuild",
        "-project",
        str(ROOT / "OneClick.xcodeproj"),
        "-scheme",
        "OneClick",
        "-configuration",
        "Release",
        "-derivedDataPath",
        str(derived),
        "build",
        "ARCHS=arm64",
        "ONLY_ACTIVE_ARCH=NO",
        "CODE_SIGNING_ALLOWED=YES",
        "DEVELOPMENT_TEAM=",
        "CODE_SIGN_STYLE=Manual",
        "CODE_SIGN_IDENTITY=-",
        f"MARKETING_VERSION={release}",
    )
    for bundle, executable in ((app, "OneClick"), (extension, "OneClickFinder")):
        with (bundle / "Contents/Info.plist").open("rb") as stream:
            if plistlib.load(stream).get("CFBundleShortVersionString") != release:
                raise ValueError(f"版本不匹配: {bundle}")
        if "Signature=adhoc" not in run("codesign", "-dv", str(bundle)):
            raise ValueError(f"不是 ad hoc 签名: {bundle}")
        binary = bundle / "Contents/MacOS" / executable
        if (
            not os.access(binary, os.X_OK)
            or run("lipo", "-archs", str(binary)).strip() != "arm64"
        ):
            raise ValueError(f"不是可执行的 arm64 产物: {binary}")
    run("codesign", "--verify", "--deep", "--strict", str(app))
    with tempfile.TemporaryDirectory(prefix=".oneclick-", dir=output) as temp:
        staging = Path(temp)
        payload = staging / "payload"
        payload.mkdir()
        run("ditto", str(app), str(payload / "OneClick.app"))
        (payload / "Applications").symlink_to("/Applications")
        (payload / "INSTALL.txt").write_text(
            "Drag OneClick.app to Applications. Requires macOS 26+ and Apple Silicon.\n"
            "This app is ad hoc signed and not notarized. If macOS blocks it, verify the download and run:\n"
            "xattr -dr com.apple.quarantine /Applications/OneClick.app\n"
            "Open OneClick and enable its Finder extension in System Settings.\n"
        )
        archive = staging / f"OneClick-{release}.dmg"
        run(
            "hdiutil",
            "create",
            "-format",
            "UDZO",
            "-volname",
            "OneClick",
            "-srcfolder",
            str(payload),
            str(archive),
        )
        run("hdiutil", "verify", str(archive))
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        checksum = staging / f"{archive.name}.sha256"
        checksum.write_text(f"{digest}  {archive.name}\n")
        formula = staging / "oneclick.rb"
        formula.write_text(cask(release, digest, repository))
        run("ruby", "-c", str(formula))
        files = [output / p.name for p in (archive, checksum, formula)]
        for staged, destination in zip((archive, checksum, formula), files):
            staged.replace(destination)
    return files


def draft(release: str, repository: str, files: list[Path]) -> None:
    """只创建或更新草稿, 已公开的版本不覆盖."""
    tag = f"v{release}"
    state = subprocess.run(
        [
            "gh",
            "release",
            "view",
            tag,
            "--repo",
            repository,
            "--json",
            "isDraft",
            "--jq",
            ".isDraft",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if state.returncode == 0:
        if state.stdout.strip() != "true":
            raise ValueError("拒绝覆盖已公开的 release 或未知状态")
        run(
            "gh",
            "release",
            "upload",
            tag,
            *(str(p) for p in files),
            "--repo",
            repository,
            "--clobber",
        )
    else:
        # 查询失败也可能是网络错误; create 会拒绝重复版本, 不盲目覆盖.
        run(
            "gh",
            "release",
            "create",
            tag,
            *(str(p) for p in files),
            "--repo",
            repository,
            "--draft",
            "--verify-tag",
            "--title",
            f"OneClick {tag}",
            "--notes",
            "macOS 26+ · Apple Silicon. Ad hoc signed, not notarized. See README for installation.",
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", type=version)
    parser.add_argument(
        "--draft", action="store_true", help="打包后上传到对应 tag 的 GitHub 草稿"
    )
    args = parser.parse_args()
    repository = os.environ.get("GH_REPO", "JasonG98/OneClick")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        parser.error("GH_REPO 必须是 owner/repo")
    try:
        if args.draft:
            if run("git", "rev-parse", "HEAD") != run(
                "git", "rev-parse", f"refs/tags/v{args.version}^{{commit}}"
            ):
                raise ValueError("当前提交与发布 tag 不匹配")
            if run("git", "status", "--porcelain", "--untracked-files=normal").strip():
                raise ValueError("发布草稿要求工作区干净, 包括未跟踪文件")
        files = package(args.version, repository)
        if args.draft:
            draft(args.version, repository, files)
        print("\n".join(str(p) for p in files))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"release: {getattr(error, 'output', None) or error}\n")


if __name__ == "__main__":
    main()
