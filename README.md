# Qaptly iOS Automation Dependencies

Pre-compiled iOS automation tools for macOS (Apple Silicon arm64).

## 📦 What's Included

- **libimobiledevice** (GPL v2+) - iOS device communication library
- **ios-deploy** (GPLv3) - iOS app installation and deployment tool

## 🎯 Purpose

This package provides the necessary tools for iOS device automation in Qaptly.
It is distributed separately from the main Qaptly application to comply with
open source license requirements.

## 📋 Requirements

- macOS 12.0 or later
- Apple Silicon (arm64) Mac
- USB cable to connect iOS device
- iOS device with Developer Mode enabled (iOS 16+)

## 🚀 Usage

This package is designed to be installed automatically by the Qaptly application.

### Automatic Installation (Recommended)

When you use iOS automation features in Qaptly, the application will prompt you
to download and install these tools automatically.

### Manual Installation

If you need to install manually:

1. Download the latest release from GitHub
2. Extract to: `~/Library/Application Support/qaptly/ios-tools/`
3. Set executable permissions (automatic in scripts)

## 🔍 Verification

To verify the installation:

```bash
~/Library/Application\ Support/qaptly/ios-tools/libimobiledevice/bin/idevice_id --version
~/Library/Application\ Support/qaptly/ios-tools/ios-deploy/ios-deploy --version
```

## 🛠️ Building from Source

### Prerequisites

Install build dependencies via Homebrew:

```bash
brew install autoconf automake libtool pkg-config openssl libplist libusbmuxd libimobiledevice-glue
```

### Build Commands

```bash
# Build all dependencies
bash scripts/build-all.sh

# Package the binaries
bash scripts/package.sh 1.0.0

# Verify the package
bash scripts/verify.sh dist/qaptly-ios-deps-macos-v1.0.0.tar.gz
```

## 📄 License

This package contains software under different open source licenses:

- **libimobiledevice**: GPL v2 or later (see LICENSE-GPL-v2)
- **ios-deploy**: GPLv3 (see LICENSE-GPL-v3)

## 🔗 Source Code

Complete source code is available at:
- Package: https://github.com/dbam-ai/qaptly-ios-deps
- See SOURCE.txt for individual component sources

## 🆘 Support

For issues related to:
- **These tools**: https://github.com/dbam-ai/qaptly-ios-deps/issues
- **Qaptly application**: Contact Qaptly support

## 🙏 Credits

This package bundles software created by:
- libimobiledevice Project: https://libimobiledevice.org
- ios-deploy contributors: https://github.com/ios-control/ios-deploy

We are grateful to these open source projects.
