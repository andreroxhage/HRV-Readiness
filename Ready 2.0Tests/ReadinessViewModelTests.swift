import XCTest
import SwiftUI
@testable import Ready_2_0

class ReadinessViewModelTests: XCTestCase {
    
    func testReadinessViewModelInitialization() {
        let viewModel = ReadinessViewModel()
        
        // Initial values should be set to defaults
        XCTAssertEqual(viewModel.readinessScore, 0)
        XCTAssertEqual(viewModel.readinessCategory, .moderate)
        XCTAssertEqual(viewModel.hrvBaseline, 0)
        XCTAssertEqual(viewModel.hrvDeviation, 0)
        XCTAssertEqual(viewModel.rhrAdjustment, 0)
        XCTAssertEqual(viewModel.sleepAdjustment, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.pastScores.isEmpty)
    }
    
    func testCategoryColor() {
        let viewModel = ReadinessViewModel()
        
        // Test color for each category
        viewModel.readinessCategory = .optimal
        XCTAssertEqual(viewModel.categoryColor, Color.green)
        
        viewModel.readinessCategory = .moderate
        XCTAssertEqual(viewModel.categoryColor, Color.yellow)
        
        viewModel.readinessCategory = .low
        XCTAssertEqual(viewModel.categoryColor, Color.orange)
        
        viewModel.readinessCategory = .fatigue
        XCTAssertEqual(viewModel.categoryColor, Color.red)
    }
    
    func testFormattedScore() {
        let viewModel = ReadinessViewModel()
        
        viewModel.readinessScore = 85.7
        XCTAssertEqual(viewModel.formattedScore, "86")
        
        viewModel.readinessScore = 42.2
        XCTAssertEqual(viewModel.formattedScore, "42")
        
        viewModel.readinessScore = 0
        XCTAssertEqual(viewModel.formattedScore, "0")
    }
    
    func testFormattedHRVDeviation() {
        let viewModel = ReadinessViewModel()
        
        viewModel.hrvDeviation = 5.25
        XCTAssertEqual(viewModel.formattedHRVDeviation, "+5.3%")
        
        viewModel.hrvDeviation = -3.75
        XCTAssertEqual(viewModel.formattedHRVDeviation, "-3.8%")
        
        viewModel.hrvDeviation = 0
        XCTAssertEqual(viewModel.formattedHRVDeviation, "+0.0%")
    }
    
    func testHRVDeviationColor() {
        let viewModel = ReadinessViewModel()
        
        viewModel.hrvDeviation = 5
        XCTAssertEqual(viewModel.hrvDeviationColor, Color.green)
        
        viewModel.hrvDeviation = -5
        XCTAssertEqual(viewModel.hrvDeviationColor, Color.yellow)
        
        viewModel.hrvDeviation = -8
        XCTAssertEqual(viewModel.hrvDeviationColor, Color.orange)
        
        viewModel.hrvDeviation = -12
        XCTAssertEqual(viewModel.hrvDeviationColor, Color.red)
    }
} 
