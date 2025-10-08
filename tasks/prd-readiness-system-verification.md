# Product Requirements Document: Readiness System Verification & Bug Fixes

## Introduction/Overview

This PRD addresses the critical issue where the readiness calculation system is not functioning according to its documented business rules and expected behaviors. After importing 90 days of health data, users are not seeing baseline calculations or readiness scores, despite the underlying functionality being implemented. This is a **verification and debugging effort** to ensure existing features work correctly rather than building new functionality.

**Problem**: The readiness system has all the necessary components implemented but is failing to produce expected outputs (baseline calculations and readiness scores) after data import.

**Goal**: Verify and fix the existing readiness calculation system to work according to documented business rules and expected behaviors.

## Goals

1. **Primary Goal**: Ensure baseline calculation works immediately after 90-day data import
2. **Secondary Goal**: Verify all existing business rules are functioning correctly
3. **Tertiary Goal**: Implement progressive baseline building for immediate user feedback
4. **Quality Goal**: Ensure system handles edge cases and provides clear error messaging

## User Stories

### Primary User Story
- **As a new user** during onboarding, **I want** to see readiness scores calculated immediately after importing 90 days of health data **so that** I can understand my readiness status without waiting.
- **As a user**, **I want** to get readiness scores using only my HRV data **so that** I don't need to provide RHR or sleep data to see my readiness status.

### Secondary User Stories
- **As a user with insufficient data**, **I want** clear error messages explaining what data is missing **so that** I know what to expect.
- **As a user with partial data**, **I want** the system to use progressive baseline building **so that** I get scores as soon as possible.
- **As a user**, **I want** the system to validate my HRV data properly **so that** I get accurate readiness scores.

## Functional Requirements

### 1. Baseline Calculation Verification
1.1. The system must calculate HRV baseline from valid data (≥10ms, ≤200ms) within the configured period
1.2. The system must use a minimum of 2 days of valid HRV data (reduced from current 3)
1.3. The system must implement progressive baseline building when insufficient data is available
1.4. The system must validate baseline stability using coefficient of variation (<30%)

### 2. Data Validation Verification
2.1. The system must validate HRV values between 10ms and 200ms (REQUIRED for baseline calculation)
2.2. The system must validate RHR values between 30-120 bpm (OPTIONAL - only when RHR adjustment is enabled)
2.3. The system must validate sleep hours > 0 (OPTIONAL - only when sleep adjustment is enabled)
2.4. The system must filter out invalid data before baseline calculation
2.5. **CRITICAL**: The system must be able to calculate readiness scores using ONLY HRV data (RHR and sleep are optional enhancements)

### 3. Readiness Score Calculation Verification
3.1. The system must calculate readiness scores using FR-3 research thresholds based on HRV deviation
3.2. The system must apply HRV deviation calculations correctly (primary scoring method)
3.3. The system must handle optional RHR and sleep adjustments when enabled (secondary adjustments)
3.4. The system must generate scores for all days with valid HRV data (RHR and sleep are NOT required)
3.5. **CRITICAL**: The system must work with RHR=0 and Sleep=0 when these adjustments are disabled

### 4. Error Handling & User Feedback
4.1. The system must provide clear error messages when insufficient data is available
4.2. The system must indicate when using partial baseline data
4.3. The system must log detailed debugging information for troubleshooting
4.4. The system must handle edge cases gracefully without crashing

### 5. Onboarding Flow Verification
5.1. The system must process 90-day historical data import correctly
5.2. The system must calculate baselines progressively during import
5.3. The system must generate readiness scores for valid historical days
5.4. The system must show today's score immediately if baseline is available

### 6. Settings Persistence & Management
6.1. The system must correctly save all user settings to UserDefaults when the user taps "Save"
6.2. The system must reload settings from UserDefaults when the settings view appears
6.3. The system must persist the baseline period (7/14/30 days) between app sessions
6.4. The system must persist RHR and Sleep adjustment toggles between app sessions
6.5. The system must persist minimum days for baseline between app sessions
6.6. The system must persist morning end hour setting (9-12 hours) between app sessions
6.7. The system must show unsaved changes indicator when settings are modified
6.8. The system must allow users to discard unsaved changes
6.9. The system must automatically trigger recalculations when settings that affect scoring are changed (no user prompt)
6.10. **REMOVED**: Rolling mode has been removed - system now only supports morning mode (HRV during sleep)

### 7. Settings UI Organization
7.1. The settings view must be organized into clear sections (Morning Window, Baseline, Score Adjustments, Advanced, Data Sources, Information)
7.2. Debug data and diagnostics must be located in Advanced Settings, not the main settings view
7.3. Advanced settings must include: minimum baseline days, recalculation tools, and debug data
7.4. The system must automatically recalculate when settings are changed (no confirmation dialog)
7.5. **REMOVED**: Morning/Rolling mode picker has been removed - system only supports morning mode

## Non-Goals (Out of Scope)

- Building new UI components or major UX changes
- Implementing machine learning or advanced algorithms
- Adding new data sources beyond HealthKit
- Creating new configuration options beyond existing settings
- Performance optimization (unless it's causing the core issues)

## Design Considerations

### Existing Implementation Status
Based on codebase analysis, the following components are already implemented:
- ✅ CoreData threading fixes (EXC_BAD_ACCESS resolved)
- ✅ ReadinessScore Sendable conformance
- ✅ Basic HRV validation (≥10ms)
- ✅ FR-3 threshold calculations
- ✅ As-of date logic for historical calculations
- ✅ Background context handling for bulk operations
- ✅ Auto-recalculation on settings changes (gesture timeout fixed)
- ✅ Morning-only mode (rolling mode removed for consistency)

### Areas Requiring Verification
- ❓ Minimum days requirement (currently 3, should be 2)
- ❓ HRV upper bound validation (currently missing)
- ❓ Progressive baseline building (may be implemented but not working)
- ❓ Baseline stability checking (may be missing)
- ❓ Error messaging quality (needs verification)

## Technical Considerations

### Current Architecture
- **ReadinessService**: Main calculation engine (implemented)
- **ReadinessStorageService**: Data persistence layer (implemented)
- **CoreDataManager**: Thread-safe CoreData operations (fixed)
- **UserDefaultsManager**: Configuration management (implemented)

### Key Files to Verify
- `ReadinessService.swift`: Baseline calculation logic
- `CoreDataManager.swift`: Data retrieval and storage
- `UserDefaultsManager.swift`: Configuration settings
- `HealthMetrics.swift`: Data validation rules

### Dependencies
- HealthKit integration (existing)
- CoreData stack (existing)
- UserDefaults configuration (existing)

## Success Metrics

### Primary Success Criteria
1. **Immediate Results**: Users see readiness scores within 5 minutes of completing 90-day data import
2. **Data Quality**: 90% of users with valid HRV data (≥2 days) see calculated scores
3. **Error Reduction**: Zero "no baseline available" errors for users with sufficient data
4. **System Stability**: No crashes or threading issues during calculation

### Secondary Success Criteria
1. **User Feedback**: Clear error messages when data is insufficient
2. **Progressive Building**: Scores appear as soon as 2 days of valid data are available
3. **Data Validation**: Invalid HRV values are properly filtered out
4. **Historical Accuracy**: Past scores are calculated correctly using as-of date logic

## Testing & Verification Plan

### Phase 1: Manual Testing (User-Driven)
1. **Data Import Test**: Import 90 days of health data and verify baseline calculation
2. **Score Generation Test**: Verify readiness scores appear for valid days
3. **Edge Case Test**: Test with insufficient data and verify error handling
4. **Configuration Test**: Verify settings changes trigger recalculation

### Phase 2: Code Verification (Developer-Driven)
1. **Baseline Logic Review**: Verify `calculateHRVBaseline()` implementation
2. **Data Validation Review**: Check HRV validation rules in `HealthMetrics.swift`
3. **Configuration Review**: Verify `minimumDaysForBaseline` setting
4. **Error Handling Review**: Check error messages and logging

### Phase 3: Bug Fixes (As Needed)
1. **Fix identified issues** based on testing results
2. **Implement missing features** (progressive baseline, upper bound validation)
3. **Improve error messaging** based on user feedback
4. **Verify all business rules** are working correctly

## Open Questions

1. **Data Quality**: What HRV values are actually being imported? (Need to check logs)
2. **Configuration**: Is `minimumDaysForBaseline` actually set to 3 in the current build?
3. **Progressive Building**: Is the progressive baseline logic implemented but not working?
4. **Error Logging**: Are there any error messages in the console during calculation?
5. **Data Import**: Is the 90-day import actually completing successfully?

## Implementation Notes

### Already Implemented (Verified)
- CoreData threading safety
- ReadinessScore Sendable conformance
- Basic calculation framework
- Historical data processing

### Needs Verification/Fixing
- Minimum days requirement
- HRV upper bound validation
- Progressive baseline building
- Error messaging quality
- Baseline stability checking

### Testing Instructions for User
1. **Start**: Import 90 days of health data
2. **Check**: Look for baseline calculation logs in console
3. **Verify**: Check if readiness scores appear in UI
4. **Report**: Provide feedback on what works/doesn't work
5. **Stop**: When baseline calculation is confirmed working or major issues identified

---

**Note**: This is a verification and debugging effort, not a new feature implementation. The goal is to ensure existing functionality works according to documented business rules.
