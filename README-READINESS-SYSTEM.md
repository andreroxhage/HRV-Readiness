# Ready 2.0 - Readiness System Documentation

## Overview
This document tracks the readiness calculation system, its business rules, expected behaviors, and ongoing improvements for the Ready 2.0 app.

## System Architecture

### Core Components
- **ReadinessService**: Main business logic and calculation engine
- **ReadinessStorageService**: Data persistence abstraction layer
- **CoreDataManager**: Low-level CoreData operations (thread-safe)
- **ReadinessViewModel**: UI state management and user interactions
- **UserDefaultsManager**: Settings and configuration management

### Data Flow
```
HealthKit → ReadinessService → ReadinessStorageService → CoreDataManager → CoreData
                ↓
         ReadinessViewModel → SwiftUI Views
```

## Business Rules & Expected Behavior

### 1. Data Requirements
- **Minimum HRV Data**: 2 days of valid HRV data (configurable) - **REQUIRED**
- **Valid HRV Values**: HRV values must be ≥ 10ms and ≤ 200ms - **REQUIRED**
- **Baseline Period**: 7-day rolling window (configurable)
- **Onboarding Import**: 90 days of historical data on first use
- **RHR Data**: Optional - only used when RHR adjustment is enabled (default: disabled)
- **Sleep Data**: Optional - only used when sleep adjustment is enabled (default: disabled)

### 2. Baseline Calculation Process
- **HRV Baseline**: Average of valid HRV values from rolling window
- **As-of Date Logic**: Uses only data strictly before target date for historical calculations
- **Progressive Building**: Use partial baseline when insufficient data available
- **Stability Check**: Validate baseline reliability using coefficient of variation (< 30%)

### 3. Readiness Score Calculation
- **Primary Input**: HRV value for target date (REQUIRED)
- **Score Formula**: Based on HRV deviation from baseline using FR-3 research thresholds:
  - **-3% to +3%**: Optimal range (80-100 points)
  - **-7% to -3%**: Moderate (50-79 points)  
  - **-10% to -7%**: Low (30-49 points)
  - **< -10%**: Fatigue (0-29 points)
  - **> +10%**: Supercompensation (90-100 points)
- **Optional Adjustments**: RHR and sleep adjustments (if enabled, default: disabled)
- **CRITICAL**: System must work with RHR=0 and Sleep=0 when adjustments are disabled

### 4. Error Handling & User Feedback
- **Insufficient Data**: Clear messaging about missing requirements
- **Partial Baseline**: Indicate when using limited data
- **Graceful Degradation**: Fallback to population-based scoring when no personal baseline

### 5. HRV-Only Scoring (CRITICAL REQUIREMENT)
- **Primary Scoring**: Readiness scores are calculated using ONLY HRV data
- **RHR Optional**: RHR data is only used when RHR adjustment is enabled (default: disabled)
- **Sleep Optional**: Sleep data is only used when sleep adjustment is enabled (default: disabled)
- **Expected Behavior**: System must work with RHR=0 and Sleep=0 when adjustments are disabled
- **User Experience**: Users should see scores immediately after HRV data import, regardless of RHR/sleep availability

## Current Issues & Solutions

### Issue 1: No Baseline Calculation After Data Import
**Problem**: After importing 90 days of health data, no baseline points or readiness scores are calculated.

**Root Causes**:
- HRV values may be < 10ms (invalid)
- Minimum 3-day requirement too strict
- No progressive baseline building
- Poor error messaging

**Solutions Implemented**:
- [x] Fixed CoreData threading issues (EXC_BAD_ACCESS)
- [x] Made ReadinessScore Sendable for Swift 6 concurrency
- [ ] Lower minimum days from 3 to 2
- [ ] Add progressive baseline building
- [ ] Improve HRV validation (add upper bound)
- [ ] Add baseline stability checking
- [ ] Implement graceful degradation
- [ ] Better error messaging

### Issue 2: Threading Problems
**Problem**: EXC_BAD_ACCESS errors due to CoreData context crossing.

**Solutions Implemented**:
- [x] Wrapped all CoreData operations in `performAndWait`
- [x] Fixed context crossing in ReadinessService
- [x] Made CoreData entities thread-safe

## Implementation Plan

### Phase 1: Core Fixes (In Progress)
- [x] Fix threading issues
- [ ] Lower minimum days requirement
- [ ] Add progressive baseline building
- [ ] Improve HRV validation

### Phase 2: Enhanced Validation
- [ ] Add baseline stability checking
- [ ] Implement graceful degradation
- [ ] Better error messaging and user feedback

### Phase 3: User Experience
- [ ] Onboarding flow improvements
- [ ] Progress indicators for data import
- [ ] Clear status messages for baseline calculation

## Configuration Settings

### Current Defaults
```swift
static let minimumDaysForBaseline = 3  // Will change to 2
static let baselinePeriod = BaselinePeriod.sevenDays
static let useRHRAdjustment = false
static let useSleepAdjustment = false
static let morningEndHour = 11
```

### Recommended Changes
```swift
static let minimumDaysForBaseline = 2  // More lenient
// Add HRV validation bounds: 10-200ms
// Add baseline stability threshold: CV < 30%
```

## Data Validation Rules

### HRV Validation
- **Lower Bound**: ≥ 10ms (prevents bad sensor data)
- **Upper Bound**: ≤ 200ms (prevents unrealistic values)
- **Quality Check**: Coefficient of variation < 30% for baseline stability

### RHR Validation
- **Range**: 30-120 bpm (reasonable physiological range)

### Sleep Validation
- **Hours**: > 0 (must have some sleep data)

## Testing Scenarios

### Scenario 1: New User Onboarding
1. Import 90 days of historical data
2. System should calculate baselines progressively
3. Generate readiness scores for valid days
4. Show today's score immediately if possible

### Scenario 2: Insufficient Data
1. User has < 2 days of valid HRV
2. System should show clear error message
3. Suggest what data is needed
4. Offer population-based fallback

### Scenario 3: Partial Data
1. User has 1-2 days of valid HRV
2. System should use partial baseline
3. Clearly indicate limited reliability
4. Continue calculating scores

## Debugging & Monitoring

### Key Log Messages
- `📊 READINESS: Calculating HRV baseline...`
- `✅ READINESS: Valid HRV values (>= 10): [values]`
- `❌ READINESS: Not enough valid HRV values`
- `🎯 READINESS: Calculated HRV baseline: X ms from Y values`

### Data Quality Checks
- Count of valid HRV days
- Baseline stability metrics
- Score calculation success rate
- Error frequency and types

## Future Enhancements

### Short Term
- [ ] Real-time baseline updates
- [ ] Data quality indicators in UI
- [ ] Export/import settings

### Long Term
- [ ] Machine learning baseline optimization
- [ ] Personalized threshold adjustment
- [ ] Multi-metric readiness algorithms
- [ ] Integration with other health platforms

---

## Change Log

### 2024-12-19
- [x] Fixed CoreData threading issues causing EXC_BAD_ACCESS
- [x] Made ReadinessScore conform to Sendable protocol
- [x] Fixed @Sendable closure captures in ReadinessViewModel
- [x] Created comprehensive system documentation
- [x] **CRITICAL**: Clarified HRV-only scoring requirement (RHR and sleep are optional)
- [x] Lowered minimum days requirement from 3 to 2
- [x] Implemented progressive baseline building for insufficient data
- [x] Added HRV upper bound validation (10-200ms)
- [x] Updated documentation to emphasize HRV-only scoring capability

### Next Steps
- [ ] Fix HealthKit authorization issues (sharingDenied)
- [ ] Verify 90-day data import actually works
- [ ] Test progressive baseline building with current data
- [ ] Implement baseline stability checking
- [ ] Add graceful degradation for insufficient data
- [ ] Improve error messaging and user feedback
