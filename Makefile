.PHONY: gen ln init release-android release-apk release-apk-fat \
        aux-setup-android-signing \
        ci-lint-dart ci-test-flutter \
        ci-build-android-apk ci-build-android-aab \
        ci-setup-ruby ci-setup-gpr \
        ci-fastlane-build-ipa ci-fastlane-build-simulator \
        ci-fastlane-build-ios ci-fastlane-build-ios-simulator \
        ci-setup-ruby-macos

gen:
	@echo "* Starting code generation... *"
	@dart run build_runner build
	@$(MAKE) -C plugins/vpn_plugin gen
	@echo "* Code generation successful *"

ln:
	@echo "* Generating localizations *"
	@dart run intl_utils:generate

init:
	@echo "* Running flutter clean *"
	@flutter clean
	@echo "* Getting latest dependencies *"
	@flutter pub get --enforce-lockfile
	@echo "* Running build runner *"
	@dart run build_runner build
	@dart pub run intl_utils:generate
	@$(MAKE) -C plugins/vpn_plugin init

.dart_tool/package_config.json: pubspec.yaml pubspec.lock
	@echo "* Resolving dependencies... *"
	@flutter pub get --enforce-lockfile 2>&1 | \
		grep -v 'untranslated message' | \
		grep -v 'To see a detailed report' | \
		grep -v 'untranslated-messages-file' | \
		grep -v 'This will generate' | cat
	@echo "* Dependencies resolved. *"

lib/common/localization/generated/l10n.dart: .dart_tool/package_config.json lib/common/localization/arb/*.arb
	@echo "* Generating localization... *"
	@dart run intl_utils:generate 2>&1 | \
		grep -v 'untranslated message' | \
		grep -v 'untranslated-messages-file' | \
		grep -v 'This will generate' | cat
	@flutter gen-l10n 2>&1 | \
		grep -v 'untranslated message' | \
		grep -v 'untranslated-messages-file' | \
		grep -v 'This will generate' | cat
	@echo "* Localization generated. *"

.dart_tool/build/entrypoint/build.dart: lib/common/localization/generated/l10n.dart
	@echo "* Starting code generation... *"
	@dart run build_runner build
	@$(MAKE) -C plugins/vpn_plugin gen
	@echo "* Code generation successful *"

# Keystore lives in HOME (not the repo): ~/.config/moreprivate/tt-mobile/
# Survives git clone/delete; never committed. Back it up yourself.
TT_MOBILE_SIGN_DIR ?= $(HOME)/.config/moreprivate/tt-mobile
TT_MOBILE_KEYSTORE ?= $(TT_MOBILE_SIGN_DIR)/tt-mobile.keystore

# Interactive; must use bash (dash has no `read -s`). Requires a real password.
aux-setup-android-signing:
	@bash -euo pipefail -c '\
	  echo "Enter password for Android keystore (store + key)."; \
	  echo "Written only under $$HOME/.config/moreprivate/tt-mobile (not git)."; \
	  read -r -s -p "Password: " PASSWORD; echo; \
	  if [ -z "$$PASSWORD" ]; then echo "ERROR: password must not be empty." >&2; exit 1; fi; \
	  read -r -s -p "Confirm:  " PASSWORD2; echo; \
	  if [ "$$PASSWORD" != "$$PASSWORD2" ]; then echo "ERROR: passwords do not match." >&2; exit 1; fi; \
	  mkdir -p "$(TT_MOBILE_SIGN_DIR)"; \
	  echo "* Generating $(TT_MOBILE_KEYSTORE) (alias: tt-mobile) *"; \
	  if [ -e "$(TT_MOBILE_KEYSTORE)" ]; then echo "ERROR: $(TT_MOBILE_KEYSTORE) already exists; refusing to overwrite it." >&2; exit 1; fi; \
	  keytool -genkeypair -v \
	    -keystore "$(TT_MOBILE_KEYSTORE)" \
	    -alias tt-mobile \
	    -keyalg RSA \
	    -keysize 2048 \
	    -validity 10500 \
	    -sigalg SHA256withRSA \
	    -storepass "$$PASSWORD" \
	    -keypass "$$PASSWORD" \
	    -dname "CN=tt-mobile, OU=moreprivate, O=moreprivate, L=Unknown, ST=Unknown, C=US"; \
	  chmod 600 "$(TT_MOBILE_KEYSTORE)"; \
	  echo "* Updating $(TT_MOBILE_SIGN_DIR)/local.properties *"; \
	  touch "$(TT_MOBILE_SIGN_DIR)/local.properties"; \
	  grep -vE "^[[:space:]]*signingConfigKey(Alias|Password|StorePath|StorePassword)[[:space:]]*=" "$(TT_MOBILE_SIGN_DIR)/local.properties" \
	    > "$(TT_MOBILE_SIGN_DIR)/local.properties.tmp" || true; \
	  mv "$(TT_MOBILE_SIGN_DIR)/local.properties.tmp" "$(TT_MOBILE_SIGN_DIR)/local.properties"; \
	  printf "%s\n" \
	    "signingConfigKeyAlias=tt-mobile" \
	    "signingConfigKeyPassword=$$PASSWORD" \
	    "signingConfigKeyStorePath=$(TT_MOBILE_KEYSTORE)" \
	    "signingConfigKeyStorePassword=$$PASSWORD" \
	    >> "$(TT_MOBILE_SIGN_DIR)/local.properties"; \
	  chmod 600 "$(TT_MOBILE_SIGN_DIR)/local.properties"; \
	  echo "* Done. Keystore: $(TT_MOBILE_KEYSTORE)"; \
	  echo "* Back this file + password up offline. Not in git."; \
	  echo "* CI: base64 -w0 $(TT_MOBILE_KEYSTORE) → secret ANDROID_KEYSTORE_BASE64" \
	'

release-android:
	@echo "* Building Android release (AAB) *"
	@flutter build appbundle --release
	@echo "* Android release build done *"

# Preferred installable APKs: one file per ABI (phones → arm64-v8a, ~15–25MB).
# Fat single-APK (~90MB) is only for convenience / mixed fleets: make release-apk-fat
release-apk: .dart_tool/build/entrypoint/build.dart
	@echo "* Building Android release APKs (split per ABI) *"
	@flutter build apk --release --split-per-abi \
		$(if $(PROJECT_VERSION),--build-name=$(PROJECT_VERSION),) \
		$(if $(BUILD_NUMBER),--build-number=$(BUILD_NUMBER),) \
		$(if $(TT_CLIENT_VERSION),--dart-define=TT_CLIENT_VERSION=$(TT_CLIENT_VERSION),)
	@ls -lah build/app/outputs/flutter-apk/app-*-release.apk
	@echo "* Prefer: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk *"

release-apk-fat: .dart_tool/build/entrypoint/build.dart
	@echo "* Building fat Android release APK (all ABIs, larger) *"
	@flutter build apk --release \
		$(if $(PROJECT_VERSION),--build-name=$(PROJECT_VERSION),) \
		$(if $(BUILD_NUMBER),--build-number=$(BUILD_NUMBER),) \
		$(if $(TT_CLIENT_VERSION),--dart-define=TT_CLIENT_VERSION=$(TT_CLIENT_VERSION),)
	@ls -lah build/app/outputs/flutter-apk/app-release.apk

ci-lint-dart:
	@echo "* Running flutter analyze *"
	@flutter analyze
	@echo "* Lint OK *"

ci-test-flutter:
	@echo "* Running flutter test *"
	@flutter test
	@echo "* Tests OK *"

ci-setup-gpr:
	@if [ -z "$$GPR_KEY" ]; then \
		echo "ERROR: GPR_KEY env var is not set"; exit 1; \
	fi
	@echo "* GPR_KEY is set *"

ci-setup-ruby:
	@echo "* Setting up Ruby gems (ios/) *"
	@cd ios && bundle config set --local path '.bundle/vendor' && bundle install
	@echo "* Ruby setup done *"

ci-setup-ruby-macos:
	@echo "* Setting up Ruby gems (macos/) *"
	@cd macos && bundle config set --local path '.bundle/vendor' && bundle install
	@echo "* Ruby setup done *"

ci-build-android-apk: .dart_tool/build/entrypoint/build.dart
	@if [ -z "$$PROJECT_VERSION" ]; then \
		echo "ERROR: PROJECT_VERSION env var is not set"; exit 1; \
	fi
	@if [ -z "$$BUILD_NUMBER" ]; then \
		echo "ERROR: BUILD_NUMBER env var is not set"; exit 1; \
	fi
	@echo "* Building Android APK (release, split per ABI) *"
	@flutter build apk --release --split-per-abi \
		--build-name=$$PROJECT_VERSION \
		--build-number=$$BUILD_NUMBER
	@ls -lah build/app/outputs/flutter-apk/app-*-release.apk
	@echo "* Android APK build done *"

ci-build-android-aab: .dart_tool/build/entrypoint/build.dart
	@if [ -z "$$PROJECT_VERSION" ]; then \
		echo "ERROR: PROJECT_VERSION env var is not set"; exit 1; \
	fi
	@if [ -z "$$BUILD_NUMBER" ]; then \
		echo "ERROR: BUILD_NUMBER env var is not set"; exit 1; \
	fi
	@echo "* Building Android AAB (release) *"
	@flutter build appbundle --release \
		--build-name=$$PROJECT_VERSION \
		--build-number=$$BUILD_NUMBER
	@echo "* Android AAB build done *"

ci-fastlane-build-ipa: ci-setup-gpr ci-setup-ruby
	@echo "* Building iOS IPA via fastlane *"
	@cd ios && bundle exec fastlane build_ipa type:"$${BUILD_TYPE:-adhoc}"
	@echo "* iOS IPA build done *"

ci-fastlane-build-simulator: ci-setup-gpr ci-setup-ruby
	@echo "* Building iOS Simulator app via fastlane *"
	@cd ios && bundle exec fastlane build_simulator_app_and_zip
	@echo "* iOS Simulator build done *"

ci-fastlane-build-ios: ci-fastlane-build-ipa

ci-fastlane-build-ios-simulator: ci-fastlane-build-simulator

ci-fastlane-build-macos: ci-setup-gpr ci-setup-ruby-macos
	@echo "* Building macOS app via fastlane *"
	@cd macos && bundle exec fastlane build_and_package type:"$${BUILD_TYPE:-developer_id}"
	@echo "* macOS build done *"
