# Permissions System

This document describes how Onit handles macOS permissions, including the permission flow, entry points, and implementation details.

## Overview

Onit (QuickEdit) requires two macOS permissions to function properly:

| Permission | Required For | Manager Class |
|------------|--------------|---------------|
| **Accessibility** | Reading selected text, inserting edits, window positioning | `AccessibilityPermissionManager` |
| **Screen Recording** | Screenshot-based trigger detection (non-accessibility apps) | `ScreenRecordingPermissionManager` |

## Permission Managers

### AccessibilityPermissionManager

**File:** `Onit/Accessibility/Permission/AccessibilityPermissionManager.swift`

**Key Methods:**

| Method | Description |
|--------|-------------|
| `requestPermission()` | Shows native macOS dialog via `AXIsProcessTrustedWithOptions()` |
| `openAccessibilitySettingsWindow()` | Opens System Settings > Privacy & Security > Accessibility |

**Permission Check:**
- Uses `AXIsProcessTrusted()` to check current status
- Timer-based polling every 0.5 seconds to detect permission changes
- Published property: `@Published var accessibilityPermissionStatus: AccessibilityPermissionStatus`

**Native Dialog Trigger:**
```swift
let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
AXIsProcessTrustedWithOptions(options)
```

---

### ScreenRecordingPermissionManager

**File:** `Onit/ScreenRecording/ScreenRecordingPermissionManager.swift`

**Key Methods:**

| Method | Description |
|--------|-------------|
| `requestScreenRecordingPermission()` | Shows native dialog, falls back to Settings if denied |
| `openScreenRecordingSettings()` | Opens System Settings > Privacy & Security > Screen Recording |
| `hasScreenRecordingPermission()` | Returns current permission status |
| `ensurePermission()` | Throws if permission is missing (used by capture paths) |

**Permission Check:**
- Uses `CGPreflightScreenCaptureAccess()` to check current status
- Published property: `@Published var isScreenRecordingEnabled: Bool`

**Native Dialog Trigger:**
```swift
_ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
```

**Flow:**
1. Attempts to trigger native dialog via ScreenCaptureKit API
2. If permission denied, automatically opens System Settings
3. Sets `Defaults[.screenRecordingPermissionAsked] = true` after first request

---

### KeyboardPermissionManager (not a TCC permission)

**File:** `Onit/Keyboard/KeyboardPermissionManager.swift`

Despite its name, this manager does not handle a macOS privacy permission. It polls the
built-in macOS keyboard suggestion settings (e.g. `NSAutomaticInlinePredictionEnabled`)
that may interfere with Onit features, and exposes their state to Settings.

---

## Entry Points

All permission entry points use native dialogs when possible, with automatic fallback to System Settings when the permission has already been denied.

### Onboarding

| Screen | File | Permission | Method Called |
|--------|------|------------|---------------|
| Permissions Page | `OnboardingPermissions.swift` | Accessibility | `requestPermission()` |
| Permissions Page | `OnboardingPermissions.swift` | Screen Recording | `requestScreenRecordingPermission()` |

### Settings

| Page | File | Permission | Method Called |
|------|------|------------|---------------|
| Setup | `SettingsSetup.swift` | Accessibility | `requestPermission()` |
| Setup | `SettingsSetup.swift` | Screen Recording | `requestScreenRecordingPermission()` |

### Menu Bar

| Component | File | Permission | Method Called |
|-----------|------|------------|---------------|
| "Allow access..." item | `MenuBarCheckForPermissions.swift` | Accessibility | `requestPermission()` |
| Status message click | `AppState+Status.swift` | Accessibility | `requestPermission()` |

---

## Status System

### Menu Bar Status Dot

The menu bar icon displays a colored status dot indicating the app's permission state:

| Color | Meaning |
|-------|---------|
| **Red** | Critical permission missing (Accessibility) |
| **Orange** | Warning state (app disabled) |
| **Gray** | All features disabled |
| **Green** | All permissions granted, app running normally |

### Status Priority

Statuses are checked in priority order (defined in `AppState+Status.swift`):

1. **Priority -1:** Dev build running alongside the production build
2. **Priority 0:** Accessibility not granted
3. **Priority 4:** Feature disable statuses (globally or per app, temporarily or indefinitely)
4. **Priority 5:** All features disabled

### Status Messages

| Status | Display Text | Actionable |
|--------|--------------|------------|
| `accessibilityRequired` | "Grant Accessibility →" | Yes |
| `running` | "Running" | No |

---

## Permission Flow

### First-Time Permission Request

```
User clicks "Grant Access"
         │
         ▼
┌─────────────────────────────┐
│ Check current status        │
│ (notDetermined/denied/etc)  │
└─────────────────────────────┘
         │
         ▼
    ┌────────────┐
    │notDetermined│───────────────┐
    └────────────┘                │
         │                        ▼
         │              ┌─────────────────────┐
         │              │ Show native dialog  │
         │              │ (system alert)      │
         │              └─────────────────────┘
         │                        │
         ▼                        ▼
    ┌────────────┐        ┌──────────────┐
    │  denied    │        │ User grants  │
    └────────────┘        │ or denies    │
         │                └──────────────┘
         ▼
┌─────────────────────────────┐
│ Open System Settings        │
│ (user must enable manually) │
└─────────────────────────────┘
```

### Permission State Monitoring

Permission managers use timer-based polling (0.5 second intervals) to detect when users grant permissions in System Settings:

```swift
// Example from AccessibilityPermissionManager
processTrustedTimer = Timer.scheduledTimer(
    timeInterval: 0.5,
    target: self,
    selector: #selector(checkProcessTrusted),
    userInfo: nil,
    repeats: true
)
```

This ensures the UI updates immediately when permissions change, even if the user grants them directly in System Settings.

---

## System Settings URLs

The app uses deep links to open specific System Settings sections:

### macOS 26+ (Tahoe)
```
x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility
x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture
```

### macOS < 26
```
x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture
```

---

## Testing Permissions

### Reset Permissions (Debug Builds)

```bash
# Reset all permissions for dev build
tccutil reset All inc.synth.onit.quickedit.dev

# Reset specific permission
tccutil reset ScreenCapture inc.synth.onit.quickedit.dev
tccutil reset Accessibility inc.synth.onit.quickedit.dev

# Reset for production build
tccutil reset All inc.synth.onit.quickedit

# Reset for beta build
tccutil reset All inc.synth.onit.quickedit.beta
```

### Reset UserDefaults

```bash
defaults delete inc.synth.onit.quickedit.dev
```

---

## Related Files

| File | Description |
|------|-------------|
| `AppState+Status.swift` | Status computation, dot color, badge count |
| `MenuBarController.swift` | Menu bar permission checks, `anyPermissionMissing` |
| `MenuBarCheckForPermissions.swift` | "Allow access..." menu item |
| `OnboardingPermissions.swift` | Onboarding permission page |
| `SettingsSetup.swift` | Settings > Setup permission sections |
