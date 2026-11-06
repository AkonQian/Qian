import XCTest

final class PhoneGalleryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testExportPhoneScreens() {
        let app = XCUIApplication()
        launch(app, mode: "home")
        XCTAssertTrue(app.descendants(matching: .any)["home-ride-dashboard"].waitForExistence(timeout: 12))
        capture(app, "01-Home-GPS")
        reveal(app.buttons["gateway-settings-button"], app)
        capture(app, "02-Home-Tools")

        reveal(app.buttons["device-summary-button"], app)
        app.buttons["device-summary-button"].tap()
        XCTAssertTrue(app.buttons["device-details-done"].waitForExistence(timeout: 5))
        capture(app, "05-My-Device")
        app.buttons["device-details-done"].tap()

        reveal(app.buttons["map-downloads-button"], app)
        app.buttons["map-downloads-button"].tap()
        XCTAssertTrue(app.buttons["map-downloads-done"].waitForExistence(timeout: 5))
        capture(app, "06-Offline-Maps")
        app.buttons["map-download-city"].tap()
        XCTAssertTrue(app.navigationBars["下载城市地图"].waitForExistence(timeout: 5))
        capture(app, "07-City-Maps")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["map-downloads-done"].waitForExistence(timeout: 5))
        app.buttons["map-downloads-done"].tap()

        reveal(app.buttons["badge-gallery-button"], app)
        app.buttons["badge-gallery-button"].tap()
        XCTAssertTrue(app.navigationBars["电子吧唧"].waitForExistence(timeout: 5))
        capture(app, "08-Badge-Gallery")
        app.navigationBars.buttons["完成"].tap()

        reveal(app.buttons["gateway-settings-button"], app)
        app.buttons["gateway-settings-button"].tap()
        XCTAssertTrue(app.buttons["gateway-save-button"].waitForExistence(timeout: 5))
        capture(app, "09-Gateway-Settings")
        reveal(app.buttons["privacy-data-button"], app)
        app.buttons["privacy-data-button"].tap()
        XCTAssertTrue(app.buttons["privacy-data-done"].waitForExistence(timeout: 5))
        capture(app, "10-Privacy-Data")

        app.terminate()
        launch(app, mode: "preview")
        XCTAssertTrue(app.descendants(matching: .any)["route-preview-map"].waitForExistence(timeout: 12))
        capture(app, "03-Route-Preview")

        app.terminate()
        launch(app, mode: "ride")
        XCTAssertTrue(app.descendants(matching: .any)["active-ride-dashboard"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["前方右转"].waitForExistence(timeout: 12))
        capture(app, "04-Active-Navigation")
    }

    private func launch(_ app: XCUIApplication, mode: String) {
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway", "--qian-gallery-" + mode]
        app.launch()
        clearSystemAlerts()
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<7 where !element.isHittable { app.swipeUp() }
        if !element.isHittable {
            for _ in 0..<7 where !element.isHittable { app.swipeDown() }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
    }
    private func clearSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<4 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 0.5) else { return }
            if alert.buttons["Don’t Allow"].exists { alert.buttons["Don’t Allow"].tap() }
            else if alert.buttons["Don't Allow"].exists { alert.buttons["Don't Allow"].tap() }
            else { alert.buttons.firstMatch.tap() }
        }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        clearSystemAlerts()
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
