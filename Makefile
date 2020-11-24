export EXTENSION_NAME = AEPAudience
PROJECT_NAME = $(EXTENSION_NAME)
TARGET_NAME_XCFRAMEWORK = $(EXTENSION_NAME).xcframework
SCHEME_NAME_XCFRAMEWORK = AEPAudience

SIMULATOR_ARCHIVE_PATH = ./build/ios_simulator.xcarchive/Products/Library/Frameworks/
IOS_ARCHIVE_PATH = ./build/ios.xcarchive/Products/Library/Frameworks/

setup-tools: install-swiftlint install-githook

open:
	open $(PROJECT_NAME).xcworkspace

test:
	@echo "######################################################################"
	@echo "### Unit Testing iOS"
	@echo "######################################################################"
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -destination 'platform=iOS Simulator,name=iPhone 8' -enableCodeCoverage YES

install-swiftlint:
	HOMEBREW_NO_AUTO_UPDATE=1 brew install swiftlint && brew cleanup swiftlint

archive:
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -archivePath "./build/ios.xcarchive" -sdk iphoneos -destination="iOS" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/ios_simulator.xcarchive" -sdk iphonesimulator -destination="iOS Simulator" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild -create-xcframework -framework $(IOS_ARCHIVE_PATH)$(PROJECT_NAME).framework -output ./build/$(TARGET_NAME_XCFRAMEWORK)

clean:
	rm -rf ./build

lint:
	swiftlint lint

lint-autocorrect:
	swiftlint autocorrect

checkFormat:
	swiftformat . --lint --swiftversion 5.2

format:
	swiftformat . --swiftversion 5.2
