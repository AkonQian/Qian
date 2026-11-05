import XCTest

final class GatewaySettingsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSaveGatewayPersistsAcrossLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway"]
        app.launch()
        openGateway(in: app)
        let field = app.textFields["gateway-address-field"].exists
            ? app.textFields["gateway-address-field"] : app.textViews["gateway-address-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("https://nav.example.com/moto-gps/api")
        keepScreenshot(app, "Gateway address entry")
        app.buttons["gateway-save-button"].tap()
        for _ in 0..<6 where !app.textFields["destination-search-field"].isHittable { app.swipeDown() }
        XCTAssertTrue(app.textFields["destination-search-field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["gateway-setup-button"].exists)
        app.terminate()
        app.launchArguments = ["--moto-ui-offline"]
        app.launch()
        openGateway(in: app)
        let saved = app.descendants(matching: .any).matching(identifier: "gateway-address-field").firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertEqual(saved.value as? String, "https://nav.example.com/moto-gps/api/")
        keepScreenshot(app, "Saved gateway settings")
    }

    func testInvalidAddressStaysInSettingsAndExplainsError() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway"]
        app.launch()
        openGateway(in: app)
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

    func testInstrumentHomePlacesGatewayBelowBadgeAndPrivacyInsideSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["home-ride-dashboard"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["qian-brand-title"].exists)
        XCTAssertFalse(app.navigationBars.staticTexts["Qian GPS"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["total-ride-distance"].exists)
        XCTAssertFalse(app.buttons["gateway-setup-button"].exists)
        XCTAssertFalse(app.buttons["gateway-settings-toolbar"].exists)
        XCTAssertFalse(app.buttons["device-details-button"].exists)
        XCTAssertFalse(app.buttons["privacy-data-button"].exists)
        XCTAssertFalse(app.buttons["demo-navigation-button"].exists)
        keepScreenshot(app, "Qian GPS instrument home")
        let gateway = app.buttons["gateway-settings-button"]
        reveal(gateway, in: app)
        XCTAssertGreaterThan(gateway.frame.minY, app.buttons["badge-gallery-button"].frame.minY)
        gateway.tap()
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
        XCTAssertTrue(app.descendants(matching: .any)["home-ride-dashboard"].waitForExistence(timeout: 10))
        let search = app.textFields["destination-search-field"]
        for _ in 0..<4 where !search.isHittable { app.swipeUp() }
        XCTAssertTrue(search.isHittable)
        keepScreenshot(app, "Qian GPS large text home")
        let device = app.buttons["device-summary-button"]
        reveal(device, in: app)
        device.tap()
        XCTAssertTrue(app.buttons["device-details-done"].waitForExistence(timeout: 5))
        keepScreenshot(app, "Qian GPS instrument device details")
    }

    func testInstrumentDemoRideKeepsEndActionReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--moto-ui-offline", "--moto-reset-gateway", "--moto-demo-on-launch"]
        app.launch()
        let dashboard = app.descendants(matching: .any)["active-ride-dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 10))
        let end = app.buttons["primary-navigation-action"]
        for _ in 0..<4 where !end.isHittable { app.swipeUp() }
        XCTAssertTrue(end.isHittable)
        keepScreenshot(app, "Qian GPS active ride instrument")
        end.tap()
        XCTAssertTrue(app.textFields["destination-search-field"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func openGateway(in app: XCUIApplication) {
        let gateway = app.buttons["gateway-settings-button"]
        reveal(gateway, in: app)
        gateway.tap()
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
