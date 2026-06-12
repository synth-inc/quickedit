Overview

 This document contains a ready-to-use prompt for implementing localization in this macOS Swift/SwiftUI codebase. Copy the prompt below and paste it into Claude Code when you need to localize a feature.
 
 MAKE SURE to replace [DESCRIBE FEATURE/FILES HERE] below with the specific feature to localize.

 ---
 THE PROMPT

 I need you to localize a feature in this macOS Swift/SwiftUI codebase. This will be done in THREE PHASES.

 ---

 ## PHASE 1: Add Localization to Code (DO THIS FIRST)

 In this phase, ONLY modify the feature's Swift files. Do NOT touch Localizable.xcstrings yet.

 ### Core Localization Files (Reference Only - Do Not Modify)

 1. **String.localized()** - Primary method for localizing strings
    - Location: `macos/Onit/General/Extensions/String+Localized.swift`
    - Basic usage: `String.localized("Your text here")`
    - With format args: `String.localized("Hello %@", userName)`
    - With multiple args: `String.localized("In %@, between %@ - %@", appName, startTime, endTime)`

 2. **LocalizationManager** - Manages runtime language switching
    - Location: `macos/Onit/Localization/LocalizationManager.swift`
    - Singleton: `LocalizationManager.shared`
    - Published property: `currentLanguage` triggers UI updates when language changes

 ### Pattern A: Standard SwiftUI Views

 For views that render text directly:

 1. Wrap ALL user-visible strings with `String.localized("...")`
 2. Add observation: `@ObservedObject private var localization = LocalizationManager.shared`
 3. Add view modifier to force re-render on language change: `.id(localization.currentLanguage)`
 4. Place `.id()` as HIGH as possible in the view hierarchy (ideally on the outermost container)

 ```swift
 struct MyView: View {
     @ObservedObject private var localization = LocalizationManager.shared

     var body: some View {
         VStack {
             Text(String.localized("Hello"))
             Text(String.localized("Welcome to the app"))
         }
         .id(localization.currentLanguage) // Forces entire VStack to re-render
     }
 }
 ```

 ### Pattern B: Root-Level Views (Feature Entry Points)

 For views that serve as the root of a feature (like ContentView, OnboardingWindowView):

 - Add observation AND .id() at this level
 - This ensures the ENTIRE feature hierarchy re-renders on language change
 - Child views may not need their own observation if the root handles it

 Example from ContentView.swift:
 struct ContentView: View {
     @ObservedObject private var localization = LocalizationManager.shared

     var body: some View {
         ZStack {
             // ... all child views
         }
         .background(Color.baseBG.opacity(0.7))
         .cornerRadius(14)
         .id(localization.currentLanguage) // Entire feature re-renders
         .edgesIgnoringSafeArea(.top)
     }
 }

 ### Pattern C: Views Created at Init Time (CRITICAL)

 For views that receive text as parameters and are created once (like notification windows, alerts, dialogs hosted in NSHostingController):

 PROBLEM: If you pass pre-localized strings at creation time, they become constants and won't update when language changes.

 SOLUTION: Pass localization KEYS instead of pre-localized strings. Evaluate String.localized() inside the view body, not at creation time.

 Example - NotificationWindowView:
 // WRONG - strings are pre-localized at creation, won't update
 NotificationWindowManager.shared.createWindow(
     title: String.localized("Success"),  // Pre-localized - BAD
     caption: String.localized("Done")    // Pre-localized - BAD
 )

 // CORRECT - pass keys, localize inside the view
 NotificationWindowManager.shared.createWindow(
     titleKey: "Success",   // Key - GOOD
     captionKey: "Done"     // Key - GOOD
 )

 // Inside the view:
 struct NotificationWindowView: View {
     @ObservedObject private var localization = LocalizationManager.shared

     private let titleKey: String
     private let captionKey: String?

     var body: some View {
         VStack {
             Text(String.localized(self.titleKey))      // Evaluated at render time
             if let captionKey = self.captionKey {
                 Text(String.localized(captionKey))     // Evaluated at render time
             }
         }
         .id(localization.currentLanguage)
     }
 }

 ### Pattern D: AppKit Components

 For AppKit components that display text:

 1. Use String.localized("...") for all text
 2. Subscribe to LocalizationManager.shared.$currentLanguage via Combine
 3. Update text properties when language changes

 ### What NOT to Localize

 - Analytics event names (e.g., "improve", "free_limit", "onboarding_auth_completed")
 - Technical identifiers and keys
 - Brand names: "Onit", "Tavily", "Google", "Apple"
 - Keyboard shortcuts and key names: "ESC", "DELETE", "⌘", "⌥"
 - File extensions and technical terms in code context
 - URLs and email addresses

 ### Phase 1 Checklist

 Before moving to Phase 2, verify:
 - All user-visible strings wrapped with String.localized()
 - Views have @ObservedObject private var localization = LocalizationManager.shared
 - Views have .id(localization.currentLanguage) on appropriate container
 - Dynamic/init-time views use key-based pattern (Pattern C)
 - Brand names and technical strings are NOT localized

 ### Phase 1 Deliverable

 After completing Phase 1, provide me a LIST of all localization keys you added (every string passed to String.localized()). I will then ask you to proceed to Phase 2.

 ---
 ## PHASE 2: Add Keys to Localizable.xcstrings (DO THIS SECOND)

 Only proceed to this phase after Phase 1 is complete and verified.

 File Location

 macos/Onit/Localizable.xcstrings

 ### Process

 1. For each key from Phase 1, check if it already exists in the file
 2. For any MISSING keys, add them in alphabetical order with this structure:

 "Your English text" : {
   "extractionState" : "manual",
   "localizations" : {
     "en" : {
       "stringUnit" : {
         "state" : "translated",
         "value" : "Your English text"
       }
     },
     "fr" : {
       "stringUnit" : {
         "state" : "translated",
         "value" : "Votre texte en français"
       }
     }
   }
 }

 ### Format String Keys

 For strings with format specifiers (%@, %d, etc.), ensure the French translation maintains the same specifiers:

 "Hello %@" : {
   "extractionState" : "manual",
   "localizations" : {
     "en" : {
       "stringUnit" : {
         "state" : "translated",
         "value" : "Hello %@"
       }
     },
     "fr" : {
       "stringUnit" : {
         "state" : "translated",
         "value" : "Bonjour %@"
       }
     }
   }
 }

 ### Phase 2 Validation

 - Every String.localized() key has a matching entry in Localizable.xcstrings
 - Every entry has "extractionState": "manual"
 - Every entry has BOTH en and fr translations
 - Keys are inserted in alphabetical order
 - Format specifiers are preserved in both languages

 ---
 ## PHASE 3: Build Verification (DO THIS LAST)

 After completing Phases 1 and 2, you MUST build the app to verify everything compiles:

 xcodebuild -project macos/Onit.xcodeproj -scheme Onit -configuration Debug build 2>&1 | tail -20

 Expected Result

 The build should end with ** BUILD SUCCEEDED **

 ### If Build Fails

 - Read the error messages carefully
 - Fix any Swift compilation errors (missing imports, type mismatches, etc.)
 - Re-run the build until it succeeds

 ---
 ### Current Task

 Please localize the following feature: [DESCRIBE FEATURE/FILES HERE]

 Start with PHASE 1 only. List all keys when done, then I'll confirm before you proceed to Phase 2.

 ---

 ## Key Implementation Files Reference

 | File | Purpose |
 |------|---------|
 | `macos/Onit/General/Extensions/String+Localized.swift` | `String.localized()` extension |
 | `macos/Onit/Localization/LocalizationManager.swift` | Manages current language, publishes changes |
 | `macos/Onit/Localizable.xcstrings` | All localization keys with en/fr translations |

 ## Pattern Quick Reference

 | Scenario | Pattern |
 |----------|---------|
 | Standard SwiftUI view | `@ObservedObject` + `String.localized()` + `.id()` |
 | Root/entry-point view | Same as above, place `.id()` at top level |
 | View created at init (alerts, notifications) | Store keys, evaluate `String.localized()` in body |
 | AppKit component | Combine subscription to `$currentLanguage` |

 ## Common Mistakes to Avoid

 1. **Pre-localizing strings passed to init** - Pass keys instead, localize in body
 2. **Missing `.id(localization.currentLanguage)`** - View won't re-render on language change
 3. **Forgetting French translation** - Both en and fr are required
 4. **Localizing brand names** - "Onit", "Google", etc. should not be localized
 5. **Not building after changes** - Always verify the build succeeds
