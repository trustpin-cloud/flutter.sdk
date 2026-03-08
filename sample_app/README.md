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

## Note

This sample app is independent of the main SDK's CI/CD pipeline and is intended for development and testing purposes only.