//
//  DemiurgeUITests.swift
//  DemiurgeUITests
//
//  Created by Max PRUDHOMME on 08/04/2025.
//
import XCTest

final class DemiurgeUITests: XCTestCase {

    var app: XCUIApplication!
    var screen: XCUIScreen!

    override func setUpWithError() throws {
        super.setUp()
        
        // Set up the app and screen recording
        continueAfterFailure = false
        app = XCUIApplication()
        screen = XCUIScreen.main
    }

    override func tearDownWithError() throws {
        // Stop the screen recording if it's active
        if screen.isRecording {
            screen.stopRecording()
        }
        super.tearDown()
    }

    @MainActor
    func testExample() throws {
        app.launch()
        
        // Start screen recording
        screen.startRecording()

        // Example UI interactions (replace with your actual app's features)
        let button = app.buttons["Start Button"]
        XCTAssertTrue(button.exists)
        button.tap()

        // Add more UI actions here as needed

        // Stop recording after test actions
        screen.stopRecording()

        // Optionally, save or process the recording
        let videoURL = screen.recordedVideoURL
        print("Video saved to: \(videoURL.path)")

        // Use assertions to verify that the app behaves as expected
        XCTAssertTrue(app.staticTexts["Expected Text"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                app.launch()
            }
        }
    }
}
