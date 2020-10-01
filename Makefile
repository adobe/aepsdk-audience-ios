# Variables
PROJECT_NAME = AEPAudience
AEPAUDIENCE_TARGET_NAME = AEPAudience

IOS_ARCHIVE_PATH = ./build/ios.xcarchive/Products/Library/Frameworks/

unit-test:
	@echo "######################################################################"
	@echo "### Unit Testing iOS"
	@echo "######################################################################"
	xcodebuild test -project $(PROJECT_NAME).xcodeproj -scheme $(AEPAUDIENCE_TARGET_NAME) -destination 'platform=iOS Simulator,name=iPhone 8'


archive:
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -archivePath "./build/ios.xcarchive" -sdk iphoneos -destination="iOS" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild -create-xcframework -framework $(IOS_ARCHIVE_PATH)$(PROJECT_NAME).framework -output ./build/$(PROJECT_NAME).xcframework

clean:
	rm -rf ./build

format:
	swiftformat . --swiftversion 5.2

lint-autocorrect:
	swiftlint autocorrect

lint:
	swiftlint lint

checkFormat:
		swiftformat . --lint --swiftversion 5.2
