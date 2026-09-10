#!/usr/bin/env python3
"""Generate the small Xcode project using only the Python standard library."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
objects = {}

def add(object_key, kind, **fields):
    key = hashlib.sha256(object_key.encode()).hexdigest()[:24].upper()
    objects[key] = {"isa": kind, **fields}
    return key

def configs(name, settings):
    ids = []
    for mode in ("Debug", "Release"):
        values = dict(settings)
        values.update(SWIFT_OPTIMIZATION_LEVEL="-Onone" if mode == "Debug" else "-O",
                      DEBUG_INFORMATION_FORMAT="dwarf" if mode == "Debug" else "dwarf-with-dsym")
        if mode == "Debug":
            values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        ids.append(add(name + mode, "XCBuildConfiguration", name=mode, buildSettings=values,
                       baseConfigurationReference=signing_config))
    return add(name + "Configs", "XCConfigurationList", buildConfigurations=ids,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")

common = dict(ARCHS="arm64", ONLY_ACTIVE_ARCH="NO", SDKROOT="macosx", MACOSX_DEPLOYMENT_TARGET="26.0",
              SWIFT_VERSION="6.0", SWIFT_STRICT_CONCURRENCY="complete", CLANG_ENABLE_MODULES="YES",
              MARKETING_VERSION="0.1.0", CURRENT_PROJECT_VERSION="1", ENABLE_HARDENED_RUNTIME="YES",
              CODE_SIGN_STYLE="Manual", CODE_SIGN_IDENTITY="Apple Development", CODE_SIGNING_ALLOWED="YES",
              ONECLICK_APP_GROUP="$(DEVELOPMENT_TEAM).local.oneclick.shared", GENERATE_INFOPLIST_FILE="NO",
              COMBINE_HIDPI_IMAGES="YES", ENABLE_USER_SCRIPT_SANDBOXING="YES")
shared = add("SharedGroup", "PBXFileSystemSynchronizedRootGroup", path="Shared", sourceTree="<group>")
appgroup = add("AppGroup", "PBXFileSystemSynchronizedRootGroup", path="OneClick", sourceTree="<group>")
extgroup = add("ExtensionGroup", "PBXFileSystemSynchronizedRootGroup", path="FinderExtension", sourceTree="<group>")
appproduct = add("AppProduct", "PBXFileReference", explicitFileType="wrapper.application", path="OneClick.app", sourceTree="BUILT_PRODUCTS_DIR")
extproduct = add("ExtProduct", "PBXFileReference", explicitFileType="wrapper.app-extension", path="OneClickFinder.appex", sourceTree="BUILT_PRODUCTS_DIR")
products = add("Products", "PBXGroup", children=[appproduct, extproduct], name="Products", sourceTree="<group>")
signing_config = add("SigningConfig", "PBXFileReference", lastKnownFileType="text.xcconfig", path="Config/Signing.xcconfig", sourceTree="<group>")
root = add("RootGroup", "PBXGroup", children=[appgroup, extgroup, shared, signing_config, products], sourceTree="<group>")
project_id = hashlib.sha256(b"Project").hexdigest()[:24].upper()

def phases(name):
    return [add(name + kind, kind, buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
            for kind in ("PBXSourcesBuildPhase", "PBXFrameworksBuildPhase", "PBXResourcesBuildPhase")]

ext = add("Extension", "PBXNativeTarget", name="OneClickFinder", productName="OneClickFinder",
          productReference=extproduct, productType="com.apple.product-type.app-extension",
          buildPhases=phases("Ext"), buildRules=[], dependencies=[],
          fileSystemSynchronizedGroups=[extgroup, shared],
          buildConfigurationList=configs("Extension", dict(common,
              PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="local.oneclick.app.finder",
              INFOPLIST_FILE="Config/FinderExtension-Info.plist", CODE_SIGN_ENTITLEMENTS="Config/FinderExtension.entitlements",
              APPLICATION_EXTENSION_API_ONLY="YES", SKIP_INSTALL="YES", ENABLE_APP_SANDBOX="YES")))
proxy = add("ExtensionProxy", "PBXContainerItemProxy", containerPortal=project_id, proxyType=1,
            remoteGlobalIDString=ext, remoteInfo="OneClickFinder")
dep = add("ExtensionDependency", "PBXTargetDependency", target=ext, targetProxy=proxy)
embedfile = add("EmbeddedExtension", "PBXBuildFile", fileRef=extproduct,
                settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})
embed = add("Embed", "PBXCopyFilesBuildPhase", buildActionMask=2147483647, dstPath="", dstSubfolderSpec=13,
            files=[embedfile], name="Embed App Extensions", runOnlyForDeploymentPostprocessing=0)
app = add("App", "PBXNativeTarget", name="OneClick", productName="OneClick", productReference=appproduct,
          productType="com.apple.product-type.application", buildPhases=phases("App") + [embed],
          buildRules=[], dependencies=[dep], fileSystemSynchronizedGroups=[appgroup, shared],
          buildConfigurationList=configs("App", dict(common,
              PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="local.oneclick.app",
              INFOPLIST_FILE="Config/OneClick-Info.plist", CODE_SIGN_ENTITLEMENTS="Config/OneClick.entitlements")))
add("Project", "PBXProject", attributes={"LastUpgradeCheck": "2660", "BuildIndependentTargetsInParallel": "YES"},
    buildConfigurationList=configs("Project", common), compatibilityVersion="Xcode 16.0",
    developmentRegion="zh-Hans", hasScannedForEncodings=0, knownRegions=["en", "zh-Hans", "Base"],
    mainGroup=root, productRefGroup=products, projectDirPath="", projectRoot="", targets=[app, ext],
    preferredProjectObjectVersion=77)

def encode(value, indent=0):
    pad = "\t" * indent
    if isinstance(value, dict):
        return "{\n" + "".join(f"{pad}\t{json.dumps(k)} = {encode(v, indent+1)};\n" for k, v in value.items()) + pad + "}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(x, indent) for x in value) + ")"
    return json.dumps(value, ensure_ascii=False)

project = ROOT / "OneClick.xcodeproj"
project.mkdir(exist_ok=True)
(project / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode(dict(archiveVersion=1, classes={}, objectVersion=77, objects=objects, rootObject=project_id)) + "\n")
schemes = project / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="OneClick.app" BlueprintName="OneClick" ReferencedContainer="container:OneClick.xcodeproj"/>'
(schemes / "OneClick.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(project)
