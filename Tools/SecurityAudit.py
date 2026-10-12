"""Read-only production-boundary checks, complementary to runtime attack tests."""
from pathlib import Path
import json
import plistlib
import subprocess

root = Path(__file__).resolve().parents[1]
shipping = [p for d in ("App", "Widget", "Shared", "Sources/SomedayCore")
            for p in (root / d).glob("*.swift")]
texts = {p.relative_to(root).as_posix(): p.read_text() for p in shipping}

# Trusted decoding is confined to the protected-storage adapter.
for path, source in texts.items():
    if "fromProtectedRepresentation(" in source:
        assert path in ("Shared/KeychainAuthority.swift", "Sources/SomedayCore/DrawAuthority.swift"), path
    assert "URLSession" not in source and "URLRequest" not in source, path
    assert "UserDefaults" not in source, path
    assert "SecItemDelete" not in source, path
    assert "Data(0..<32)" not in source, f"Test key in {path}"
    assert "LuckyJournal.decoded" not in source, f"Legacy unsigned import in {path}"

keychain = texts["Shared/KeychainAuthority.swift"]
assert "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly" in keychain
assert "kSecAttrSynchronizable as String: false" in keychain
assert "if status == errSecItemNotFound { return nil }" in keychain
assert "guard status == errSecSuccess else { throw" in keychain
widget = texts["Widget/SomedayWidget.swift"]
assert "DailyDraw" not in widget and ".result(on:" not in widget
assert "snapshot.today" in widget
storage = texts["Shared/SharedStorage.swift"]
assert "LOCK_EX | LOCK_NB" in storage
assert "try KeychainAuthority.update(authority)" in storage
assert "trigger: nil" in storage and "UNCalendarNotificationTrigger" not in storage
settings = texts["App/SettingsView.swift"]
assert "BoundedFile.read(url)" in settings
assert "SharedStorage.validateRecovery(data)" in settings
assert "Data(contentsOf:" not in settings

with (root / "Config/Someday.entitlements").open("rb") as f:
    entitlements = plistlib.load(f)
assert entitlements["keychain-access-groups"] == ["$(SOMEDAY_KEYCHAIN_GROUP)"]
for filename in ("App-Info.plist", "Widget-Info.plist"):
    with (root / "Config" / filename).open("rb") as f:
        assert plistlib.load(f)["SomedayKeychainGroup"] == "$(SOMEDAY_KEYCHAIN_GROUP)"

with (root / "Config/PrivacyInfo.xcprivacy").open("rb") as f:
    reasons = {item["NSPrivacyAccessedAPIType"]: item["NSPrivacyAccessedAPITypeReasons"]
               for item in plistlib.load(f)["NSPrivacyAccessedAPITypes"]}
assert "3B52.1" in reasons["NSPrivacyAccessedAPICategoryFileTimestamp"]
assert "35F9.1" in reasons["NSPrivacyAccessedAPICategorySystemBootTime"]

project = json.loads(subprocess.check_output([
    "plutil", "-convert", "json", "-o", "-", str(root / "Someday.xcodeproj/project.pbxproj")]))
for obj in project["objects"].values():
    assert obj.get("path") not in ("Tools", "PreviewSupport.swift", "LegacyAttackProbe.swift", "main.swift")
    if obj.get("isa") == "XCBuildConfiguration" and obj.get("name") == "Release":
        settings = obj.get("buildSettings", {})
        assert "DEBUG" not in settings.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "")
print("PASS  Production trust boundaries, device-only Keychain, bounded imports, no future-win payloads, and fixture exclusion")
