# TrustPin Flutter Sample App

A comprehensive sample Flutter application demonstrating the TrustPin SDK capabilities with real HTTP connection testing.

## Features

- **TrustPin Configuration**: Configure organization credentials and public key
- **Real-time HTTP Testing**: Test actual HTTPS connections with TrustPin SSL certificate validation
- **Live Log Output**: View detailed timestamped logs of all TrustPin operations
- **Status Indicators**: Visual feedback on configuration and connection status
- **Multiple Log Levels**: Control logging verbosity for debugging

## Running the Sample

1. Navigate to the sample app directory:
   ```bash
   cd sample_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Usage

1. **Configure TrustPin**: Enter your organization ID, project ID, and public key
2. **Setup**: Tap "Setup TrustPin" to initialize the SDK
3. **Test Connection**: Enter a test URL and tap "Test Connection" to perform real HTTP requests
4. **Monitor Logs**: View real-time logs in the output section

## Configuration

Update the default values in `lib/main.dart` with your actual TrustPin credentials for testing.

## Building the macOS target

Always build through the Flutter CLI (`flutter run -d macos` or `flutter build macos`).
Building directly through Xcode without first running one of those commands will fail
with a Swift Package Manager platform error:

```
The package product 'trustpin-sdk' requires minimum platform version 13.0 for the
macOS platform, but this target supports 10.15
```

The Flutter CLI patches the generated `FlutterGeneratedPluginSwiftPackage` wrapper
on each build to match `MACOSX_DEPLOYMENT_TARGET` from the Xcode project (set to
13.0 in this sample). `flutter pub get` resets the wrapper to Flutter's default
(10.15); only `flutter build` / `flutter run` re-applies the patch.

If you hit the error after a `flutter clean` or `flutter pub get`, run:

```bash
flutter build macos --debug    # or: flutter run -d macos
```

…before opening Xcode.

## Note

This sample app is independent of the main SDK's CI/CD pipeline and is intended for development and testing purposes only.