.PHONY: check previews icon

check:
	swift run -c release SomedayChecks
	swift run -c release SecurityChecks
	python3 Tools/SecurityAudit.py
	python3 Tools/ValidateProject.py
	xcrun swiftc -frontend -parse App/*.swift Shared/*.swift Widget/*.swift
	plutil -lint Someday.xcodeproj/project.pbxproj Config/App-Info.plist Config/Widget-Info.plist Config/Someday.entitlements Config/PrivacyInfo.xcprivacy

icon:
	swift Tools/RenderIcon.swift

# Native macOS rendering of the same SwiftUI views with development fixtures.
# These images are design previews, not iOS simulator screenshots.
previews:
	mkdir -p .build
	xcrun swiftc -target arm64-apple-macosx14.0 -parse-as-library Sources/SomedayCore/*.swift Shared/PixelArt.swift App/Design.swift App/RootView.swift App/TodayView.swift App/CollectionView.swift App/HitDetailView.swift App/SettingsView.swift Tools/PreviewSupport.swift Tools/RenderPreviews.swift -o .build/RenderPreviews
	.build/RenderPreviews
