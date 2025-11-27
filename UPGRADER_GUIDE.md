# Upgrader Implementation Guide

## What Was Fixed

1. **Removed `debugDisplayAlways: true`** - This was preventing the upgrader from working in production
2. **Added proper configuration** - Created a centralized upgrader config with proper settings
3. **Removed `Upgrader.clearSavedSettings()`** - This was clearing the upgrader's memory and preventing it from working
4. **Added country code** - Set to 'IN' for Indian Play Store

## How It Works Now

The upgrader will:
- Check Google Play Store for your app updates
- Show an alert dialog when a newer version is available
- Allow users to ignore or update later (configurable)
- Remember user choices to avoid showing the same alert repeatedly

## Testing the Upgrader

### Option 1: Use Test Page (Development Only)
1. Import the test page in your main app
2. Navigate to `TestUpgraderPage()` 
3. This will show the upgrade dialog immediately for testing

### Option 2: Test with Real App Store Data
1. Publish your app to Google Play Store (even as internal testing)
2. Install the app on a device
3. Update the version in `pubspec.yaml` to a higher version (e.g., 1.0.6+6)
4. Publish the new version to Play Store
5. The upgrader will detect the difference and show the dialog

## Configuration Options

### Production Configuration (Current)
- `debugLogging: false` - No debug output
- `durationUntilAlertAgain: Duration(days: 1)` - Show alert again after 1 day if ignored
- `countryCode: 'IN'` - Indian Play Store
- `languageCode: 'en'` - English language

### Testing Configuration
- `debugDisplayAlways: true` - Always show dialog for testing
- `durationUntilAlertAgain: Duration(seconds: 10)` - Short duration for testing
- `debugLogging: true` - Enable debug output

## Common Issues & Solutions

### 1. Dialog Not Showing
**Causes:**
- App version on Play Store is same or older than current
- User recently dismissed the dialog (respects `durationUntilAlertAgain`)
- App not published on Play Store yet

**Solutions:**
- Ensure Play Store has a newer version
- Use test configuration during development
- Clear app data to reset upgrader memory

### 2. Wrong App Store Region
**Cause:** Wrong country code configuration

**Solution:** Change `countryCode` in `UpgraderConfig`:
- 'US' for United States Play Store
- 'IN' for Indian Play Store
- 'GB' for UK Play Store, etc.

### 3. App Not Found on Play Store
**Cause:** Package ID mismatch or app not published

**Solution:** 
- Ensure your `applicationId` in `android/app/build.gradle` matches your Play Store listing
- Verify app is published (at least as internal testing)

## Current App Configuration

**Package ID:** `com.avisunavi.avi`  
**Current Version:** `1.0.5+5`  
**Target Store:** Google Play Store (India)

## Important Notes

1. **Remove Test Code in Production** - Don't use `getTestUpgrader()` in production builds
2. **Version Format** - Use semantic versioning (e.g., 1.0.5+5 where +5 is build number)
3. **Play Store Delays** - It can take a few hours for Play Store API to reflect new versions
4. **Internet Required** - Upgrader needs internet connection to check for updates

## Monitoring

Check your app logs for upgrader activity:
```
I/flutter: Upgrader: checking for updates...
I/flutter: Upgrader: found newer version 1.0.6 vs current 1.0.5
```

## Force Updates (Optional)

To force users to update for critical fixes, modify the configuration:
```dart
static Upgrader getUpgrader() {
  return Upgrader(
    // ... other config
    canDismissDialog: false, // Users cannot dismiss dialog
    // Uncomment below to set minimum required version
    // minAppVersion: '1.0.5', // Users below this version must update
  );
}
```
