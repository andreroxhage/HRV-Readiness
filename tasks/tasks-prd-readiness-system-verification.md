## Relevant Files

- `Ready 2.0/Features/Readiness/Services/ReadinessService.swift` - Main calculation engine with verified baseline calculation logic and progressive import
- `Ready 2.0/Core/Models/CoreData/HealthMetrics.swift` - Data validation rules with consistent HRV, RHR, and sleep validation
- `Ready 2.0/Core/Services/Storage/CoreDataManager.swift` - Data retrieval and storage operations with verified as-of date logic
- `Ready 2.0/Core/Services/Storage/UserDefaultsManager.swift` - Configuration settings management with correct minimumDaysForBaseline setting
- `Ready 2.0/Core/Models/Enums/ReadinessError.swift` - Error handling and messaging system (needs improvement)
- `Ready 2.0/Core/ViewModels/ReadinessViewModel.swift` - UI state management with verified initial setup flow
- `Ready 2.0/Features/Readiness/ViewModels/ReadinessCalculationViewModel.swift` - Calculation coordination with verified FR-3 thresholds
- `Ready 2.0/Core/Models/Enums/BaselinePeriod.swift` - Baseline period configuration with verified minimum days requirements
- `Ready 2.0/Core/Services/HealthKit/HealthKitManager.swift` - HealthKit data import with enhanced error handling and cancellation support
- `Ready 2.0Tests/ReadinessServiceTests.swift` - Comprehensive unit tests covering all verification scenarios
- `Ready 2.0Tests/ReadinessViewModelTests.swift` - Unit tests for ReadinessViewModel that need verification

### Notes

- Unit tests should be run using `xcodebuild test` or through Xcode's test navigator
- The system is already implemented but needs verification that it works according to documented business rules
- Focus is on debugging and fixing existing functionality rather than building new features

## Tasks

- [x] 1.0 Verify and Fix Baseline Calculation Logic
  - [x] 1.1 Verify that minimumDaysForBaseline is correctly set to 2 (currently defaults to 2 in UserDefaultsManager)
  - [x] 1.2 Check if HRV upper bound validation (≤200ms) is properly implemented in HealthMetrics.hasValidHRV
  - [x] 1.3 Verify progressive baseline building logic in calculateHRVBaseline() method works with insufficient data
  - [x] 1.4 Test baseline stability checking using coefficient of variation (<30%) - may need implementation
  - [x] 1.5 Verify as-of date logic in calculateHRVBaseline(asOf:) excludes target date from baseline window
  - [x] 1.6 Test baseline calculation with edge cases (exactly 2 days, exactly 3 days, mixed valid/invalid data)

- [x] 2.0 Verify and Fix Data Validation Rules
  - [x] 2.1 Confirm HRV validation range is 10-200ms in HealthMetrics.hasValidHRV extension
  - [x] 2.2 Verify RHR validation range is 30-120 bpm (optional when RHR adjustment disabled)
  - [x] 2.3 Confirm sleep validation is >0 hours (optional when sleep adjustment disabled)
  - [x] 2.4 Test that invalid data is properly filtered before baseline calculation
  - [x] 2.5 Verify system can calculate readiness scores using ONLY HRV data (RHR=0, Sleep=0 when adjustments disabled)
  - [x] 2.6 Test data validation with boundary values (exactly 10ms HRV, exactly 200ms HRV, etc.)

- [x] 3.0 Verify and Fix Readiness Score Calculation
  - [x] 3.1 Test FR-3 research thresholds are correctly implemented in calculateReadinessScore()
  - [x] 3.2 Verify HRV deviation calculations are accurate (primary scoring method)
  - [x] 3.3 Test optional RHR and sleep adjustments work when enabled (secondary adjustments)
  - [x] 3.4 Verify scores are generated for all days with valid HRV data regardless of RHR/sleep availability
  - [x] 3.5 Test that system works with RHR=0 and Sleep=0 when adjustments are disabled
  - [x] 3.6 Verify historical score calculation using as-of baselines works correctly

- [ ] 4.0 Improve Error Handling and User Feedback
  - [ ] 4.1 Review and improve error messages in ReadinessError enum for clarity
  - [ ] 4.2 Add logging for baseline calculation failures with detailed debugging information
  - [ ] 4.3 Implement clear messaging when using partial baseline data
  - [ ] 4.4 Add error handling for edge cases without crashing
  - [ ] 4.5 Verify error messages are user-friendly and actionable
  - [ ] 4.6 Test error handling with various data insufficiency scenarios

- [x] 5.0 Verify Onboarding Flow and Data Import
  - [x] 5.1 Test 90-day historical data import process in bulkImportHistoricalData()
  - [x] 5.2 Verify baseline calculations happen progressively during import
  - [x] 5.3 Test that readiness scores are generated for valid historical days
  - [x] 5.4 Verify today's score appears immediately if baseline is available after import
  - [x] 5.5 Test initial setup flow in performInitialDataImportAndSetup()
  - [x] 5.6 Verify background context handling for bulk operations works correctly

- [x] 6.0 Settings Persistence and Management
  - [x] 6.1 Implement refreshFromUserDefaults() method in ReadinessSettingsManager to reload settings when view appears
  - [x] 6.2 Add onAppear handler to SettingsView to refresh settings from UserDefaults
  - [x] 6.3 **REMOVED**: Rolling mode eliminated - system now only supports morning mode
  - [x] 6.4 Verify baseline period (7/14/30 days) persists between app sessions
  - [x] 6.5 Verify RHR and Sleep adjustment toggles persist between app sessions
  - [x] 6.6 Verify minimum days for baseline persists between app sessions
  - [x] 6.7 Verify morning end hour setting (9-12) persists between app sessions
  - [x] 6.8 Test unsaved changes indicator appears when settings are modified
  - [x] 6.9 Test discard changes functionality works correctly
  - [x] 6.10 Auto-recalculation implemented (no prompt) - fixed gesture timeout issue
  
- [x] 7.0 Settings UI Organization & Simplification
  - [x] 7.1 Move Debug Data section from main SettingsView to AdvancedSettingsView
  - [x] 7.2 Verify settings view sections are organized correctly (Morning Window, Baseline, Score Adjustments, Advanced, Data Sources, Information)
  - [x] 7.3 Verify Advanced Settings includes minimum baseline days, recalculation tools, and debug data
  - [x] 7.4 Add logging to track settings changes and persistence
  - [x] 7.5 **REMOVED**: Mode picker eliminated - only morning mode supported
  - [x] 7.6 Implement auto-recalculation without prompt - fixes gesture timeout
  - [x] 7.7 Update UnderstandingScore.swift to remove rolling mode references
  
- [x] 8.0 Code Refactoring & Fixes (Pre-Manual Testing)
  - [x] 8.1 Fix gesture timeout by making saveSettings() synchronous (removed unnecessary Task.detached)
  - [x] 8.2 Remove rolling mode from ReadinessMode enum (only morning mode supported)
  - [x] 8.3 Update SettingsView to auto-recalculate without confirmation dialog
  - [x] 8.4 Remove mode picker from SettingsView UI
  - [x] 8.5 Update ReadinessSettingsManager to remove readinessMode property
  - [x] 8.6 Update ReadinessModeTests.swift to remove rolling mode tests
  - [x] 8.7 Update UnderstandingScore.swift to remove rolling mode documentation
  - [x] 8.8 Remove readinessMode from SettingsChangeType enum
  - [x] 8.9 Update PRD and tasks documents with new requirements
  - [x] 8.10 Verify all linter errors are resolved

- [ ] 9.0 UI/UX Quality Improvements (iOS 18 Glass Design + Native SwiftUI)
  
  - [ ] 9.1 Layout & Hierarchy Refinements
    - [ ] Text baseline alignment using `HStack(alignment: .firstTextBaseline)` for:
      - [ ] Score title and value ("Today's Readiness" + "92 / 100")
      - [ ] HRV Analysis metrics (baseline, today's HRV, deviation)
      - [ ] Score Details rows (base score, adjustments, final score)
    - [ ] Apply `.monospacedDigit()` to all numeric values for consistent width
    - [ ] Use grid-based layout with consistent `.padding(.horizontal, 20)` for sections (Readiness, History, HRV)
    - [ ] Replace manual `.padding()` with `.safeAreaPadding(.horizontal)` for adaptive layout
    - [ ] Apply `.scrollContentBackground(.hidden)` and keep existing glassy gradient backgrounds
  
  - [ ] 9.2 Spacing System Standardization (8-point grid)
    - [ ] Define spacing scale: 4, 8, 12, 16, 24, 32, 40
    - [ ] Apply consistent vertical rhythm across all VStacks (use 8, 12, 16, 24 only)
    - [ ] Standardize section padding in ContentView
    - [ ] Unify spacing in SettingsView and AdvancedSettingsView
    - [ ] Use `.padding(.all, 16)` consistently inside cards
  
  - [ ] 9.3 Typography Hierarchy (SF Pro + Dynamic Type)
    - [ ] Score title ("Today's Readiness") → `.title2.bold()` or `.system(.title2, design: .rounded, weight: .semibold)`
    - [ ] Score value ("92") → `.system(size: 64, weight: .semibold, design: .rounded)`
    - [ ] Category description → `.callout` with `.secondary` color
    - [ ] Section titles ("History", "HRV Analysis") → `.headline.weight(.semibold)`
    - [ ] Label/value pairs → `.body` with `.semibold` on values
    - [ ] Add `.minimumScaleFactor(0.8)` to large numbers for Dynamic Type support
    - [ ] Test with all Dynamic Type sizes
  
  - [ ] 9.4 iOS 18 Glass Aesthetic & Materials
    - [ ] Keep existing custom gradient colors for readiness score backgrounds (DO NOT CHANGE)
    - [ ] Apply `.ultraThinMaterial` to card backgrounds with subtle borders:
      ```swift
      .overlay(
          RoundedRectangle(cornerRadius: 16)
              .strokeBorder(Color.white.opacity(0.15))
      )
      ```
    - [ ] Use layered blur hierarchy:
      - Background →  the tint of the score color as already implemented
      - Foreground elements → `.thinMaterial`
      - Cards → `.ultraThinMaterial`
    - [ ] Add subtle text shadows for contrast: `.shadow(color: .black.opacity(0.2), radius: 2, y: 1)`
    - [ ] Slightly desaturate bright greens: `Color.green.opacity(0.9)`
    - [ ] Corner radii: 12–20pt for glass style consistency
  
  - [ ] 9.5 Controls, Buttons & Reachability (Fitts's Law)
    - [ ] Move settings cog (⚙️) to bottom floating button with label ("Settings")
      ```swift
      Button(action: {}) {
          Label("Settings", systemImage: "gear")
      }
      .buttonStyle(.borderedProminent)
      .tint(.accentColor)
      .controlSize(.large)
      .background(.ultraThinMaterial, in: Circle())
      .shadow(radius: 5)
      ```
    - [ ] Move "Cancel" and "Save" in SettingsView to fixed bottom bar using `.safeAreaInset(edge: .bottom)` with glass background
    - [ ] Apply visual weight contrast:
      - Save → `.tint(.green)`
      - Cancel → `.tint(.gray)` or `.tint(.red.opacity(0.8))`
    - [ ] Ensure all interactive elements are minimum 44x44pt (native buttons handle this)
    - [ ] Use `.controlSize(.large)` for primary actions
  
  - [ ] 9.6 Score Visualization, Animations & Motion
    - [ ] Keep existing readiness category colors (already defined):
      - Fatigue (0–29) → `.red`
      - Low (30–49) → `.orange`
      - Moderate (50–79) → `.yellow`
      - Optimal (80–100) → `.green`
    - [ ] Enhance InitialSetupView progress indicator:
      - [ ] Make animations identical for each step
      - [ ] Improve typography sizing padding etc. to use our uniform spacing scales
      - [ ] Keep variation of icons and colors
    - [ ] Add smooth transitions for state changes with `.animation(.easeInOut)`
    - [ ] Wrap animations in Reduce Motion check:
      ```swift
      withAnimation(.easeInOut(duration: 0.6).disabled(UIAccessibility.isReduceMotionEnabled))
      ```
  
  - [ ] 9.7 Accessibility & Haptics
    - [ ] Add haptic feedback on score load/category change:
      ```swift
      let generator = UINotificationFeedbackGenerator()
      generator.notificationOccurred(.success)
      ```
    - [ ] Add accessibility labels to all interactive elements
    - [ ] Add accessibility hints for complex controls (pickers, steppers)
    - [ ] Test with VoiceOver
    - [ ] Verify all colors meet WCAG contrast requirements
    - [ ] Test on light + dark modes with large text settings
  
  - [ ] 9.8 Empty States & User Guidance
    - [ ] Add empty state for calendar when no historical data exists
    - [ ] Provide helpful messaging when baseline is insufficient (with icon + call-to-action)
    - [ ] Show placeholder text for missing health metrics
    - [ ] Guide users to enable permissions when data is missing
    - [ ] Use uniform card style for empty states (`.ultraThinMaterial` + subtle border)
  
  - [ ] 9.9 SwiftUI Best Practices & Code Quality
    - [ ] Use Environment modifiers (`.tint`, `.font`, `.preferredColorScheme`) at top level
    - [ ] Respect system tint: use `.tint(.accentColor)` consistently
    - [ ] Avoid hardcoded sizes; use `DynamicTypeSize`, `LayoutPriority`
    - [ ] Use `.background(.bar)` for toolbars
    - [ ] Use `.safeAreaInset` for bottom actions
    - [ ] Use `containerBackground(for:)` for scrollable views
    - [ ] Prefer soft contrast over hard borders (z-stacks instead of drop shadows)
    - [ ] Use color gradients in highlights:
      ```swift
      .foregroundStyle(.linearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
      ```

 
- [ ] 10.0 Manual Test Code Verification (Before Xcode Testing)
  - [ ] Really analyse abd remove unused methods etc.
  - [ ] Code quality assurance based on latest swift version and recommendations
  - [ ] 10.1 Review ReadinessServiceTests.swift for completeness and correctness (2681 lines, comprehensive coverage)
  - [ ] 10.2 Verify ReadinessViewModelTests.swift covers all published properties and computed values
  - [ ] 10.3 Check ReadinessSettingsManagerTests.swift covers save/discard/change detection logic
  - [ ] 10.4 Review MorningWindowTests.swift for morningEndHour configuration edge cases
  - [ ] 10.5 Verify ReadinessModeTests.swift covers morning mode time range calculations
  - [ ] 10.6 Check OnboardingTests.swift validates partial permissions flow
  - [ ] 10.7 Verify all test methods call existing ViewModel/Service methods (no missing method errors)
  - [ ] 10.8 Review test assertions align with updated business rules from PRD
  - [ ] 10.9 Verify no rolling mode references remain in test files
  - [ ] 10.10 Confirm linter shows no errors in any test files
