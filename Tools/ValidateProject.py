"""Read-only checks for the hand-authored Xcode project; no dependencies."""
import json
from pathlib import Path
import plistlib
import subprocess

root = Path(__file__).resolve().parents[1]
raw = subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(root / "Someday.xcodeproj/project.pbxproj")])
project = json.loads(raw)
objects = project["objects"]

for obj in objects.values():
    for key in ("fileRef", "target", "targetProxy", "containerPortal", "productReference", "buildConfigurationList", "baseConfigurationReference"):
        if key in obj:
            assert obj[key] in objects, f"Dangling {key}: {obj[key]}"
    for key in ("children", "buildPhases", "files", "dependencies", "buildConfigurations", "targets"):
        for reference in obj.get(key, []):
            assert reference in objects, f"Dangling {key}: {reference}"

seen = set()
for group in objects.values():
    if group.get("isa") != "PBXGroup" or "path" not in group:
        continue
    for ref in group.get("children", []):
        child = objects[ref]
        if child.get("isa") == "PBXFileReference":
            path = root / group["path"] / child["path"]
            assert path.exists(), f"Missing project file: {path}"
            seen.add(path.relative_to(root).as_posix())

for folder in ("App", "Widget", "Shared", "Sources/SomedayCore"):
    for path in (root / folder).glob("*.swift"):
        assert path.relative_to(root).as_posix() in seen, f"Swift file omitted from project: {path}"

for target in (obj for obj in objects.values() if obj.get("isa") == "PBXNativeTarget"):
    sources = []
    for phase_ref in target["buildPhases"]:
        phase = objects[phase_ref]
        if phase["isa"] == "PBXSourcesBuildPhase":
            for build_ref in phase["files"]:
                sources.append(objects[objects[build_ref]["fileRef"]]["path"])
    assert len(sources) == len(set(sources)), f"Duplicate source in {target['name']}"
    for core in ("LuckyNumber.swift", "DayClock.swift", "DailyDraw.swift", "LuckyJournal.swift", "SharedStorage.swift", "PixelArt.swift", "ClockGate.swift", "DrawAuthority.swift", "BoundedFile.swift", "DeviceClock.swift", "KeychainAuthority.swift"):
        assert core in sources, f"Missing {core} in {target['name']}"
    expected_entry = "SomedayApp.swift" if target["name"] == "Someday" else "SomedayWidget.swift"
    assert expected_entry in sources
    print(f"PASS  {target['name']}: {len(sources)} source files; all shared core sources included")

for name in ("App-Info.plist", "Widget-Info.plist", "Someday.entitlements", "PrivacyInfo.xcprivacy"):
    with (root / "Config" / name).open("rb") as handle:
        plistlib.load(handle)

for catalog in (root / "App/Assets.xcassets").rglob("Contents.json"):
    contents = json.loads(catalog.read_text())
    for entry in contents.get("images", []):
        if "filename" in entry:
            assert (catalog.parent / entry["filename"]).exists(), "Missing asset image"

print("PASS  Project references, plist files, asset catalogs, app icon and both targets")
