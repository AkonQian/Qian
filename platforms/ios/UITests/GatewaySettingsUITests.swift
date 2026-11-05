import XCTest

final class GatewaySettingsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSaveGatewayPersistsAcrossLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway"]
        app.launch()
        let setup = app.buttons["gateway-settings-toolbar"]
        XCTAssertTrue(setup.waitForExistence(timeout: 10))
        setup.tap()
        let field = app.textFields["gateway-address-field"].exists
            ? app.textFields["gateway-address-field"] : app.textViews["gateway-address-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("https://nav.example.com/moto-gps/api")
        keepScreenshot(app, "Gateway address entry")
        app.buttons["gateway-save-button"].tap()
        XCTAssertTrue(app.textFields["destination-search-field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["gateway-setup-button"].exists)
        app.terminate()
        app.launchArguments = ["--moto-ui-offline"]
        app.launch()
        let settings = app.buttons["gateway-settings-toolbar"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let saved = app.descendants(matching: .any).matching(identifier: "gateway-address-field").firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertEqual(saved.value as? String, "https://nav.example.com/moto-gps/api/")
        keepScreenshot(app, "Saved gateway settings")
    }

    func testInvalidAddressStaysInSettingsAndExplainsError() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway"]
        app.launch()
        let setup = app.buttons["gateway-settings-toolbar"]
        XCTAssertTrue(setup.waitForExistence(timeout: 10))
        setup.tap()
        let field = app.descendants(matching: .any).matching(identifier: "gateway-address-field").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("http://nav.example.com")
        app.buttons["gateway-save-button"].tap()
        let error = app.staticTexts["gateway-status-message"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("HTTPS"))
        keepScreenshot(app, "Invalid gateway address")
    }

    func testInstrumentHomeMovesPrivacyIntoTopLeftSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["home-ride-dashboard"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["qian-brand-title"].label, "Qian GPS")
        XCTAssertFalse(app.buttons["gateway-setup-button"].exists)
        XCTAssertFalse(app.buttons["gateway-settings-button"].exists)
        XCTAssertFalse(app.buttons["privacy-data-button"].exists)
        keepScreenshot(app, "Qian GPS instrument home")
        app.buttons["gateway-settings-toolbar"].tap()
        let privacy = app.buttons["privacy-data-button"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        for _ in 0..<4 where !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.isHittable)
        keepScreenshot(app, "Qian GPS settings and privacy entry")
        privacy.tap()
        let done = app.buttons["privacy-data-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        keepScreenshot(app, "Qian GPS privacy screen")
        done.tap()
        XCTAssertTrue(app.buttons["gateway-save-button"].waitForExistence(timeout: 5))
    }

    func testInstrumentHomeAccessibilityLayoutAndDeviceSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["gateway-settings-toolbar"].waitForExistence(timeout: 10))
        let search = app.textFields["destination-search-field"]
        for _ in 0..<4 where !search.isHittable { app.swipeUp() }
        XCTAssertTrue(search.isHittable)
        keepScreenshot(app, "Qian GPS large text home")
        app.buttons["device-details-button"].tap()
        XCTAssertTrue(app.buttons["device-details-done"].waitForExistence(timeout: 5))
        keepScreenshot(app, "Qian GPS instrument device details")
    }

    func testInstrumentDemoRideKeepsEndActionReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway"]
        app.launch()
        let demo = app.buttons["demo-navigation-button"]
        XCTAssertTrue(demo.waitForExistence(timeout: 10))
        for _ in 0..<4 where !demo.isHittable { app.swipeUp() }
        demo.tap()
        let dashboard = app.descendants(matching: .any)["active-ride-dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 10))
        let end = app.buttons["primary-navigation-action"]
        XCTAssertTrue(end.isHittable)
        keepScreenshot(app, "Qian GPS active ride instrument")
        end.tap()
        XCTAssertTrue(app.textFields["destination-search-field"].waitForExistence(timeout: 5))
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
