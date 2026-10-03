#!/usr/bin/env python3
"""
generate-xcodeproj.py — build zhen-app/Zhen.xcodeproj from scratch.

A `project.pbxproj` edited by hand becomes a file nobody dares touch: it is a plist of
cross-referenced 24-hex-digit IDs, and a merge conflict in it is unresolvable by
reading. So the project is GENERATED and this script is the owner. Regenerate with:

    python3 Scripts/generate-xcodeproj.py

── What changed, and why the old reasoning is now inverted ─────────────────────────

This script used to describe the app target as "a thin shell" that linked packages for
everything, and gave per-target actor isolation as the reason the views lived in a
SwiftPM package rather than here. That was a real constraint and it stopped being one.

The views are now app-target sources, edited in Xcode with a live canvas, which is what
a design system needs and what a package makes awkward. The isolation argument survives
intact because of how the split actually fell: every target that moved in here was
already `.defaultIsolation(MainActor.self)`, and the one non-isolated target — ZhenScan,
the scan adapter — has no SwiftUI in it at all and stayed in the `zhen` package. So the
app target sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor and nothing is lost. A socket
still cannot reach the main actor by someone forgetting an annotation, because the
boundary is still a target boundary.

── The two things the project must get right ───────────────────────────────────────

  * A real application product, so the bundle exists at build time and the Local Network
    grant attaches to `com.jctec.zhen` under its own name rather than to Xcode.

  * Synchronized root groups (PBXFileSystemSynchronizedRootGroup, objectVersion 77) for
    the source folders. A new view file is in the target the moment it is on disk — no
    pbxproj edit, so adding a screen does not regenerate this project and the
    byte-identical check in CI keeps meaning something. This script owns STRUCTURE;
    the folder owns FILES.

    A synchronized root group is recursive, so a second group over a subfolder of the
    first compiles everything under it twice. ZhenTests covers ZhenTests/Design.
"""

import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = ROOT / "zhen-app" / "Zhen.xcodeproj"

# Deterministic IDs, so regenerating produces a byte-identical file and a diff of this
# project is a diff of real changes rather than of shuffled UUIDs.
def oid(*parts: str) -> str:
    return hashlib.sha1("::".join(parts).encode()).hexdigest()[:24].upper()

APP = "Zhen"
BUNDLE_ID = "com.jctec.zhen"
DEPLOYMENT = "26.0"
SWIFT_VERSION = "6.0"

ids = {
    "project":        oid("project"),
    "mainGroup":      oid("group", "main"),
    "productsGroup":  oid("group", "products"),
    "supportGroup":   oid("group", "support"),
    "appSources":     oid("sync", "app-sources"),
    "appTarget":      oid("target", APP),
    "appProduct":     oid("product", APP),
    "infoPlist":      oid("file", "Info.plist"),
    "assets":         oid("file", "Assets.xcassets"),
    "assetsBuild":    oid("buildfile", "Assets.xcassets"),
    "readme":         oid("file", "README"),
    "sources":        oid("phase", "sources"),
    "frameworks":     oid("phase", "frameworks"),
    "resources":      oid("phase", "resources"),
    "projectCfgList": oid("cfglist", "project"),
    "appCfgList":     oid("cfglist", APP),
    "projectDebug":   oid("cfg", "project", "Debug"),
    "projectRelease": oid("cfg", "project", "Release"),
    "appDebug":       oid("cfg", APP, "Debug"),
    "appRelease":     oid("cfg", APP, "Release"),
    "pkgTool":        oid("pkg", "zhen"),
    "testTarget":     oid("target", "ZhenTests"),
    "testProduct":    oid("product", "ZhenTests"),
    "testAppSources": oid("sync", "test-app"),
    "testSources":    oid("phase", "test-sources"),
    "testFrameworks": oid("phase", "test-frameworks"),
    "testResources":  oid("phase", "test-resources"),
    "testCfgList":    oid("cfglist", "ZhenTests"),
    "testDebug":      oid("cfg", "ZhenTests", "Debug"),
    "testRelease":    oid("cfg", "ZhenTests", "Release"),
    "testDep":        oid("dep", "tests-on-app"),
    "testProxy":      oid("proxy", "tests-on-app"),
}
TESTS = "ZhenTests"

# The three products the app imports. Each becomes a package product dependency and a
# build file in the frameworks phase.
PRODUCTS = [
    ("ZhenCore", "pkgTool"),
    ("ZhenScan", "pkgTool"),
    ("ZhenPrivilege", "pkgTool"),
]
for name, _ in PRODUCTS:
    ids[f"dep{name}"] = oid("productdep", name)
    ids[f"bf{name}"] = oid("buildfile", name)
    ids[f"tdep{name}"] = oid("productdep", "test", name)
    ids[f"tbf{name}"] = oid("buildfile", "test", name)


def build_settings_common() -> dict[str, str]:
    return {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "MACOSX_DEPLOYMENT_TARGET": DEPLOYMENT,
        "SDKROOT": "macosx",
        "SWIFT_VERSION": SWIFT_VERSION,
    }


def app_settings(configuration: str) -> dict[str, str]:
    settings = {
        # The catalogue lives in Resources/, alongside the Info.plist, and belongs to THIS
        # project rather than to any SwiftPM target. SwiftPM does not compile asset
        # catalogues, and the design system's Corrections article records what happens
        # when one is added to a package anyway: every colour token resolved to white.
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CODE_SIGN_STYLE": "Automatic",
        # Ad-hoc is enough for the system to treat this as a stable identity across
        # launches, which is what TCC keys the Local Network grant on. Distribution needs
        # a Developer ID certificate, hardened runtime and notarization — document 03's
        # signing-identity section, and there is no code substitute for the certificate.
        "CODE_SIGN_IDENTITY": '"-"',
        "COMBINE_HIDPI_IMAGES": "YES",
        "CURRENT_PROJECT_VERSION": "1",
        "ENABLE_HARDENED_RUNTIME": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "Resources/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/../Frameworks"',
        "MARKETING_VERSION": "0.4.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        # The app half of the isolation split. `ZhenScan` sets the opposite in its
        # own manifest, and keeping them in separate modules is what makes that possible.
        "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_STRICT_CONCURRENCY": "complete",
    }
    if configuration == "Debug":
        settings["ENABLE_TESTABILITY"] = "YES"
        settings["SWIFT_OPTIMIZATION_LEVEL"] = '"-Onone"'
        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        settings["ONLY_ACTIVE_ARCH"] = "YES"
    else:
        settings["SWIFT_OPTIMIZATION_LEVEL"] = '"-O"'
        settings["SWIFT_COMPILATION_MODE"] = "wholemodule"
    return settings


def test_settings(configuration: str) -> dict[str, str]:
    settings = {
        "BUNDLE_LOADER": '"$(TEST_HOST)"',
        "CODE_SIGN_STYLE": "Automatic",
        "CODE_SIGN_IDENTITY": '"-"',
        "GENERATE_INFOPLIST_FILE": "YES",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID}.tests",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
        "SWIFT_EMIT_LOC_STRINGS": "NO",
        # Hosted by the app, so `@testable import Zhen` reaches the app's own
        # module rather than only the packages beneath it.
        "TEST_HOST": f'"$(BUILT_PRODUCTS_DIR)/{APP}.app/Contents/MacOS/{APP}"',
    }
    if configuration == "Debug":
        settings["SWIFT_OPTIMIZATION_LEVEL"] = '"-Onone"'
        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
    else:
        settings["SWIFT_OPTIMIZATION_LEVEL"] = '"-O"'
    return settings


def project_settings(configuration: str) -> dict[str, str]:
    settings = build_settings_common()
    if configuration == "Debug":
        settings |= {
            "DEBUG_INFORMATION_FORMAT": "dwarf",
            "ENABLE_TESTABILITY": "YES",
            "GCC_OPTIMIZATION_LEVEL": "0",
            "ONLY_ACTIVE_ARCH": "YES",
            "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        }
    else:
        settings |= {
            "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
            "ENABLE_NS_ASSERTIONS": "NO",
            "MTL_ENABLE_DEBUG_INFO": "NO",
        }
    return settings


def render_settings(settings: dict[str, str], indent: str) -> str:
    return "\n".join(f"{indent}{k} = {v};" for k, v in sorted(settings.items()))


def pbxproj() -> str:
    product_deps = "\n".join(
        f"\t\t\t\t{ids['dep' + name]} /* {name} */," for name, _ in PRODUCTS
    )
    frameworks_files = "\n".join(
        f"\t\t\t\t{ids['bf' + name]} /* {name} in Frameworks */," for name, _ in PRODUCTS
    )
    build_files = "\n".join(
        f"\t\t{ids['bf' + name]} /* {name} in Frameworks */ = {{isa = PBXBuildFile; "
        f"productRef = {ids['dep' + name]} /* {name} */; }};\n"
        f"\t\t{ids['tbf' + name]} /* {name} in Frameworks */ = {{isa = PBXBuildFile; "
        f"productRef = {ids['tdep' + name]} /* {name} */; }};"
        for name, _ in PRODUCTS
    )
    # The asset catalogue is a resource rather than a linked product, so it needs its
    # own build file entry beside the framework ones.
    build_files += (
        f"\n\t\t{ids['assetsBuild']} /* Assets.xcassets in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {ids['assets']} /* Assets.xcassets */; }};"
    )
    test_product_deps = "\n".join(
        f"\t\t\t\t{ids['tdep' + name]} /* {name} */," for name, _ in PRODUCTS
    )
    test_frameworks_files = "\n".join(
        f"\t\t\t\t{ids['tbf' + name]} /* {name} in Frameworks */," for name, _ in PRODUCTS
    )
    product_dep_objects = "\n".join(
        f"\t\t{ids['dep' + name]} /* {name} */ = {{\n"
        f"\t\t\tisa = XCSwiftPackageProductDependency;\n"
        f"\t\t\tpackage = {ids[pkg]} /* XCLocalSwiftPackageReference */;\n"
        f"\t\t\tproductName = {name};\n"
        f"\t\t}};\n"
        f"\t\t{ids['tdep' + name]} /* {name} */ = {{\n"
        f"\t\t\tisa = XCSwiftPackageProductDependency;\n"
        f"\t\t\tpackage = {ids[pkg]} /* XCLocalSwiftPackageReference */;\n"
        f"\t\t\tproductName = {name};\n"
        f"\t\t}};"
        for name, pkg in PRODUCTS
    )

    return f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 77;
	objects = {{

/* Begin PBXBuildFile section */
{build_files}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		{ids['appProduct']} /* {APP}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{ids['testProduct']} /* {TESTS}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {TESTS}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{ids['infoPlist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = Resources/Info.plist; sourceTree = "<group>"; }};
		{ids['assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = Resources/Assets.xcassets; sourceTree = "<group>"; }};
		{ids['readme']} /* README.md */ = {{isa = PBXFileReference; lastKnownFileType = net.daringfireball.markdown; path = README.md; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		{ids['appSources']} /* Zhen */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			explicitFileTypes = {{
			}};
			explicitFolders = (
			);
			path = "Zhen";
			name = "Zhen (app sources)";
			sourceTree = "<group>";
		}};
		{ids['testAppSources']} /* App tests */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			explicitFileTypes = {{
			}};
			explicitFolders = (
			);
			path = "ZhenTests";
			name = "App tests";
			sourceTree = "<group>";
		}};
			explicitFolders = (
			);
			path = "zhen-app/ZhenTests/Design";
			name = "Design tests";
			sourceTree = "<group>";
		}};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		{ids['frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
{frameworks_files}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['testFrameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
{test_frameworks_files}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{ids['mainGroup']} = {{
			isa = PBXGroup;
			children = (
				{ids['appSources']} /* Zhen (app sources) */,
				{ids['testAppSources']} /* App tests */,
				{ids['supportGroup']} /* Supporting Files */,
				{ids['productsGroup']} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{ids['supportGroup']} /* Supporting Files */ = {{
			isa = PBXGroup;
			children = (
				{ids['infoPlist']} /* Info.plist */,
				{ids['assets']} /* Assets.xcassets */,
				{ids['readme']} /* README.md */,
			);
			name = "Supporting Files";
			sourceTree = "<group>";
		}};
		{ids['productsGroup']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{ids['appProduct']} /* {APP}.app */,
				{ids['testProduct']} /* {TESTS}.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{ids['appTarget']} /* {APP} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['appCfgList']} /* Build configuration list for PBXNativeTarget "{APP}" */;
			buildPhases = (
				{ids['sources']} /* Sources */,
				{ids['frameworks']} /* Frameworks */,
				{ids['resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				{ids['appSources']} /* Zhen (app sources) */,
			);
			name = {APP};
			packageProductDependencies = (
{product_deps}
			);
			productName = {APP};
			productReference = {ids['appProduct']} /* {APP}.app */;
			productType = "com.apple.product-type.application";
		}};
		{ids['testTarget']} /* {TESTS} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['testCfgList']} /* Build configuration list for PBXNativeTarget "{TESTS}" */;
			buildPhases = (
				{ids['testSources']} /* Sources */,
				{ids['testFrameworks']} /* Frameworks */,
				{ids['testResources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{ids['testDep']} /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				{ids['testAppSources']} /* App tests */,
			);
			name = {TESTS};
			packageProductDependencies = (
{test_product_deps}
			);
			productName = {TESTS};
			productReference = {ids['testProduct']} /* {TESTS}.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
/* End PBXNativeTarget section */

/* Begin PBXContainerItemProxy section */
		{ids['testProxy']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {ids['project']} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {ids['appTarget']};
			remoteInfo = {APP};
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXTargetDependency section */
		{ids['testDep']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {ids['appTarget']} /* {APP} */;
			targetProxy = {ids['testProxy']} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin PBXProject section */
		{ids['project']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2660;
				LastUpgradeCheck = 2660;
				TargetAttributes = {{
					{ids['appTarget']} = {{
						CreatedOnToolsVersion = 26.6;
					}};
					{ids['testTarget']} = {{
						CreatedOnToolsVersion = 26.6;
						TestTargetID = {ids['appTarget']};
					}};
				}};
			}};
			buildConfigurationList = {ids['projectCfgList']} /* Build configuration list for PBXProject "{APP}" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {ids['mainGroup']};
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				{ids['pkgTool']} /* XCLocalSwiftPackageReference "zhen" */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = {ids['productsGroup']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids['appTarget']} /* {APP} */,
				{ids['testTarget']} /* {TESTS} */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{ids['resources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ids['assetsBuild']} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['testResources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{ids['sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['testSources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{ids['projectDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{render_settings(project_settings("Debug"), chr(9) * 4)}
			}};
			name = Debug;
		}};
		{ids['projectRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{render_settings(project_settings("Release"), chr(9) * 4)}
			}};
			name = Release;
		}};
		{ids['appDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{render_settings(app_settings("Debug"), chr(9) * 4)}
			}};
			name = Debug;
		}};
		{ids['appRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{render_settings(app_settings("Release"), chr(9) * 4)}
			}};
			name = Release;
		}};
		{ids['testDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{render_settings(test_settings("Debug"), chr(9) * 4)}
			}};
			name = Debug;
		}};
		{ids['testRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{render_settings(test_settings("Release"), chr(9) * 4)}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{ids['projectCfgList']} /* Build configuration list for PBXProject "{APP}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['projectDebug']} /* Debug */,
				{ids['projectRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['appCfgList']} /* Build configuration list for PBXNativeTarget "{APP}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['appDebug']} /* Debug */,
				{ids['appRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['testCfgList']} /* Build configuration list for PBXNativeTarget "{TESTS}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['testDebug']} /* Debug */,
				{ids['testRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		{ids['pkgTool']} /* XCLocalSwiftPackageReference "zhen" */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = "../zhen";
		}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
{product_dep_objects}
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {ids['project']} /* Project object */;
}}
"""


def scheme(*, configuration: str, run: bool) -> str:
    """One scheme.

    Both schemes build and test the same two targets; they differ in configuration. That
    is deliberate — a Release scheme is not decoration here, because the optimiser and
    whole-module compilation are exactly where a Swift 6 concurrency problem stops being
    theoretical, and because an archive has to be reachable from the scheme menu rather
    than from a build-settings excursion.

    Shared, never in `xcuserdata`: a scheme that lives in a user directory exists only on
    the machine that made it, and the next person opens the project to an empty menu.
    """
    def buildable(target_id: str, name: str, product: str) -> str:
        return f'''         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{product}"
            BlueprintName = "{name}"
            ReferencedContainer = "container:{APP}.xcodeproj">
         </BuildableReference>'''

    app_ref = buildable(ids["appTarget"], APP, f"{APP}.app")
    test_ref = buildable(ids["testTarget"], TESTS, f"{TESTS}.xctest")

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2660"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
{app_ref}
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "NO">
{test_ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "{configuration}"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
{test_ref}
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "{configuration}"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{app_ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{app_ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "{configuration}">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''


def main() -> int:
    if not (ROOT / "zhen" / "Package.swift").exists():
        print("generate-xcodeproj: run me from inside the repo", file=sys.stderr)
        return 1

    schemes = PROJECT / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    (PROJECT / "project.pbxproj").write_text(pbxproj())
    (schemes / f"{APP}.xcscheme").write_text(scheme(configuration="Debug", run=True))
    (schemes / f"{APP} (Release).xcscheme").write_text(
        scheme(configuration="Release", run=True)
    )

    # Shared, not per-user: a scheme in `xcuserdata` exists only on the machine that made
    # it, and the next person opens the project to an empty scheme menu.
    (PROJECT / "xcshareddata" / "IDEWorkspaceChecks.plist").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n<dict>\n'
        "\t<key>IDEDidComputeMac32BitWarning</key>\n\t<true/>\n"
        "</dict>\n</plist>\n"
    )
    print(f"generate-xcodeproj: wrote {PROJECT.relative_to(ROOT)}")
    print(f"  target   {APP}.app  ({BUNDLE_ID})")
    print(f"  package  zhen (../zhen)")
    print(f"  target   {TESTS}.xctest  (hosted by the app)")
    print(f"  schemes  {APP}, {APP} (Release)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
