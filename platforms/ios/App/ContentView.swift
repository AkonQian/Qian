import SwiftUI

enum MotoScreen: Hashable {
    case routePreview
    case activeNavigation
}

/// One primary flow: destination → route → ride. Device management is secondary.
struct ContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @FocusState private var searchFocused: Bool
    @State private var showsDeviceDetails = false
    @State private var showsMapDownloads = false
    @State private var showsGatewaySettings = false
    @State private var showsBadgeGallery = false

    var body: some View {
        NavigationStack(path: navigationPath) {
            homeScreen
                .navigationDestination(for: MotoScreen.self) { screen in
                    switch screen {
                    case .routePreview: routePreviewScreen
                    case .activeNavigation: activeNavigationScreen
                    }
                }
        }
        .tint(QianTheme.accent)
        .onChange(of: model.destinationQuery) { _, _ in model.destinationQueryDidChange() }
        .onChange(of: model.selectedPlace) { _, place in
            if place != nil { searchFocused = false }
        }
        .onChange(of: model.isNavigationActive) { _, active in
            if active { searchFocused = false }
        }
        .sheet(isPresented: $showsDeviceDetails) { deviceDetails }
        .sheet(isPresented: $showsMapDownloads) {
            MapDownloadsView(
                store: model.surroundingMap,
                gatewayBaseURL: model.mapGatewayBaseURL,
                route: model.mapDownloadRoute,
                destinationName: model.selectedPlace?.name
            )
        }
        .sheet(isPresented: $showsGatewaySettings) { GatewaySettingsView(model: model) }
        .sheet(isPresented: $showsBadgeGallery) { BadgeGalleryView(client: model.badgeClient) }
    }

    // Derive the stack from the session instead of synchronizing two mutable
    // paths with onChange. A system Back gesture uses the same cleanup as End.
    private var navigationPath: Binding<[MotoScreen]> {
        Binding(
            get: {
                if model.isNavigationActive { return [.activeNavigation] }
                if model.selectedPlace != nil { return [.routePreview] }
                return []
            },
            set: { path in
                if model.isNavigationActive, !path.contains(.activeNavigation) {
                    model.stopNavigation()
                } else if model.selectedPlace != nil, !path.contains(.routePreview) {
                    model.clearDestination()
                }
            }
        )
    }

    // MARK: - Destination search

    private var homeScreen: some View {
        List {
            if model.destinationQuery.isEmpty {
                Section { rideDashboard(active: false) }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section {
                searchField
            } header: {
                Text("今天去哪里？").font(.headline).foregroundStyle(Color.primary).textCase(nil)
            } footer: {
                if !model.isGatewayConfigured {
                    Text("导航服务待配置，请通过骑行工具中的网关设置完成。")
                }
            }
            if !model.destinationQuery.isEmpty {
                searchResultsSection
            } else {
                if !model.recentPlaces.isEmpty { recentPlacesSection }
                Section {
                    deviceSummaryButton
                    mapDownloadsButton
                    Button { showsBadgeGallery = true } label: {
                        Label("徽章图库", systemImage: "photo.on.rectangle.angled")
                            .foregroundStyle(Color.primary).padding(.vertical, 7)
                    }
                    .accessibilityIdentifier("badge-gallery-button")
                    Button {
                        searchFocused = false
                        showsGatewaySettings = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("网关设置").foregroundStyle(Color.primary)
                                Text("服务地址 · 隐私与数据")
                                    .font(.subheadline).foregroundStyle(Color.secondary)
                            }
                        } icon: {
                            Image(systemName: "slider.horizontal.3").foregroundStyle(QianTheme.accent)
                        }
                        .padding(.vertical, 7)
                    }
                    .accessibilityIdentifier("gateway-settings-button")
                } header: {
                    Text("骑行工具").font(.caption.weight(.bold)).tracking(2)
                } footer: {
                    Text("连接圆屏，导航指引随骑行同步。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .modifier(QianInstrumentSurface())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { searchFocused = false }
            }
        }
    }

    private func rideDashboard(active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(active ? "LIVE RIDE" : "READY TO RIDE")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(3).foregroundStyle(QianTheme.accent)
                    Text(active ? (model.isDemoActive ? "模拟骑行" : "骑行进行中") : "准备出发")
                        .font(.title3.weight(.bold))
                }
                Spacer(minLength: 8)
                QianStatusBadge(title: model.deviceReady ? "圆屏已连接" : "圆屏未连接", active: model.deviceReady)
            }
            speedReadout(active: active)
                .frame(maxWidth: .infinity)
            Rectangle().fill(QianTheme.border).frame(height: 1).accessibilityHidden(true)
            if active {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.navigation.instructionText.isEmpty ? navigationTitle : model.navigation.instructionText)
                        .font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text(model.navigation.hasNextManeuver ? turnDistanceText : navigationDetail)
                        .font(.subheadline).foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { dashboardStatuses }
                    VStack(alignment: .leading, spacing: 12) { dashboardStatuses }
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text("总骑行公里数").font(.caption).foregroundStyle(Color.secondary)
                Spacer(minLength: 8)
                Text(String(format: "%.1f", model.totalRideDistanceM / 1_000))
                    .font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                Text("km").font(.caption).foregroundStyle(Color.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("total-ride-distance")
        }
        .padding(22)
        .background(LinearGradient(colors: [QianTheme.elevated, QianTheme.panel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(QianTheme.border))
        .overlay(alignment: .topLeading) {
            Capsule().fill(QianTheme.accent).frame(width: 36, height: 3)
                .padding(.leading, 22).accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(active ? "active-ride-dashboard" : "home-ride-dashboard")
    }

    private func speedReadout(active: Bool) -> some View {
        VStack(spacing: 7) {
            Text(active && model.navigation.hasUsableFix && !model.navigation.gnssStale
                 ? String(format: "%.0f", max(0, model.navigation.speedMPS * 3.6)) : (active ? "—" : "0"))
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 96 : 120, weight: .bold, design: .rounded))
                .monospacedDigit().tracking(-4).lineLimit(1).minimumScaleFactor(0.65)
                .contentTransition(.numericText())
                .accessibilityIdentifier("ride-speed-value")
            VStack(spacing: 5) {
                Text("KM/H").font(.system(.caption, design: .monospaced).weight(.bold)).tracking(1)
                Text(active ? (model.navigation.gnssStale ? "位置待更新" : "当前速度") : "导航后显示速度")
                    .font(.caption2).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var dashboardStatuses: some View {
        Group {
            Label(model.searchBiasAvailable ? "定位已就绪" : "定位待就绪", systemImage: "location")
            Label("深圳底图已内置", systemImage: "map")
        }
        .font(.caption.weight(.medium)).foregroundStyle(Color.secondary)
    }

    private var turnDistanceText: String {
        let metres = max(0, model.navigation.distanceToManeuverM)
        let distance = metres >= 1000 ? String(format: "%.1f km", metres / 1000) : "\(Int(metres.rounded())) m"
        return "\(distance) 后 · \(model.navigation.roadName.isEmpty ? "按路线行驶" : model.navigation.roadName)"
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
            TextField("搜索地点或地址", text: $model.destinationQuery)
                .font(.body)
                .accessibilityIdentifier("destination-search-field")
                .accessibilityLabel("搜索目的地")
                .focused($searchFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    model.submitDestinationSearch()
                    searchFocused = false
                }
            if !model.destinationQuery.isEmpty {
                Button {
                    model.clearDestination()
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                        .frame(minWidth: 28, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("清空搜索")
            }
        }
        .frame(minHeight: 44)
    }

    private var searchResultsSection: some View {
        Section {
            if model.isSearchingPlaces {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("正在搜索…").foregroundStyle(Color.secondary)
                }
                .frame(minHeight: 56)
                .accessibilityElement(children: .combine)
            } else if !model.placeResults.isEmpty {
                ForEach(Array(model.placeResults.enumerated()), id: \.offset) { index, place in
                    Button { select(place) } label: {
                        placeRow(place, symbol: "mappin.circle.fill")
                    }
                    .accessibilityIdentifier("place-result-\(index)")
                }
            } else {
                ContentUnavailableView {
                    Label {
                        Text(model.placeSearchFailure == nil ? "输入地点名称" : "暂无结果")
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: { Image(systemName: "magnifyingglass") }
                } description: {
                    Text(model.placeSearchFailure ?? "至少输入两个字，例如“奥体中心”。")
                } actions: {
                    if model.placeSearchFailure != nil {
                        Button("重新搜索", action: model.submitDestinationSearch)
                    }
                }
            }
        } header: {
            Text("搜索结果")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.searchScopeText)
                if model.searchLocationStatus == .permissionDenied {
                    Button("前往设置开启定位", action: openSystemSettings)
                }
            }
        }
    }

    private var recentPlacesSection: some View {
        Section {
            ForEach(Array(model.recentPlaces.enumerated()), id: \.offset) { index, place in
                Button { select(place) } label: { placeRow(place, symbol: "clock") }
                    .accessibilityIdentifier("recent-place-\(index)")
            }
        } header: {
            HStack {
                Text("最近搜索")
                Spacer()
                Button("清空", action: model.clearRecentPlaces)
                    .textCase(nil)
                    .accessibilityLabel("清空最近搜索")
            }
        }
    }

    private func placeRow(_ place: PlaceSearchResult, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(symbol == "clock" ? Color.secondary : QianTheme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(place.name)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(placeSubtitle(place))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 7)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func select(_ place: PlaceSearchResult) {
        searchFocused = false
        model.selectPlace(place)
    }

    // MARK: - Route selection

    private var mapDownloadsButton: some View {
        Button { showsMapDownloads = true } label: {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("地图与离线下载").foregroundStyle(Color.primary)
                    Text("深圳底图已内置 · 管理地图与下载")
                        .font(.subheadline).foregroundStyle(Color.secondary)
                }
            } icon: { Image(systemName: "map").foregroundStyle(QianTheme.accent) }
            .padding(.vertical, 5)
        }
        .accessibilityIdentifier("map-downloads-button")
    }

    private var routePreviewScreen: some View {
        List {
            if let place = model.selectedPlace {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(place.name).font(.headline)
                            Text(placeSubtitle(place))
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.red)
                    }
                    .padding(.vertical, 5)
                } header: {
                    Label("从我的位置出发", systemImage: "location.fill").textCase(nil)
                }

                if model.isPlanningRoutePreview {
                    Section {
                        HStack(spacing: 14) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("正在规划路线")
                                Text("获取当前位置与路况…")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("route-preview-loading")
                    }
                } else if model.hasRoutePreview {
                    Section {
                        RouteOverviewMap(
                            candidates: model.routePreviewCandidates,
                            selectedID: model.selectedRoutePreviewID,
                            origin: model.routePreviewOrigin,
                            destination: place.location
                        )
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 270)
                        .listRowInsets(EdgeInsets())
                        .accessibilityIdentifier("route-preview-map")
                        .accessibilityLabel("前往\(place.name)的路线全览")
                    }
                    Section {
                        ForEach(model.routePreviewCandidates) { candidate in routeOptionRow(candidate) }
                    } header: {
                        Text("选择路线")
                    } footer: {
                        Text("高德驾车路线 · 预计时间会随路况变化")
                    }
                    Section { mapDownloadsButton }
                } else if let failure = model.routePreviewFailure {
                    Section {
                        ContentUnavailableView {
                            Label {
                                Text("无法规划路线")
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: { Image(systemName: "exclamationmark.triangle") }
                        } description: {
                            Text(failure)
                        } actions: {
                            if model.searchLocationStatus == .permissionDenied {
                                Button("前往设置", action: openSystemSettings)
                            }
                        }
                    }
                }
                if let failure = model.navigationFailure {
                    Section { failureMessage(failure) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .modifier(QianInstrumentSurface())
        .navigationTitle("路线")
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("更换") {
                    model.clearDestination()
                    searchFocused = true
                }
                .accessibilityLabel("更换目的地")
                .accessibilityIdentifier("destination-change-button")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { navigationActionBar }
    }

    private func routeOptionRow(_ candidate: RoutePreviewCandidate) -> some View {
        let selected = candidate.id == model.selectedRoutePreviewID
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                model.selectRoutePreview(candidate.id)
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(candidate.title)
                        .font(.subheadline)
                        .foregroundStyle(selected ? QianTheme.accent : .secondary)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            routeDuration(candidate)
                            routeDistance(candidate)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            routeDuration(candidate)
                            routeDistance(candidate)
                        }
                    }
                    Label(candidate.trafficSummary, systemImage: "car.side")
                        .font(.subheadline)
                        .foregroundStyle(trafficTint(candidate))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? QianTheme.accent : Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("route-option-\(candidate.ordinal)")
        .accessibilityLabel("\(candidate.title)，\(candidate.durationText)，\(candidate.distanceText)，\(candidate.trafficSummary)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func routeDuration(_ candidate: RoutePreviewCandidate) -> some View {
        Text(candidate.durationText)
            .font(.title2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Color.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func routeDistance(_ candidate: RoutePreviewCandidate) -> some View {
        Text(candidate.distanceText)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Color.secondary)
    }

    // MARK: - Ride in progress

    private var activeNavigationScreen: some View {
        List {
            Section { rideDashboard(active: true) }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            Section {
                if dynamicTypeSize.isAccessibilitySize {
                    rideMetric("剩余时间", value: remainingDuration)
                    rideMetric("剩余路程", value: remainingDistance)
                } else {
                    HStack(spacing: 24) {
                        rideMetric("剩余时间", value: remainingDuration)
                        rideMetric("剩余路程", value: remainingDistance)
                    }
                }
                Label(model.activeDestinationName, systemImage: "flag.checkered")
                    .font(.subheadline.weight(.medium)).padding(.vertical, 6)
            } header: { Text(model.isDemoActive ? "演示目的地" : "本次骑行").tracking(2) }
            Section("骑行状态") {
                deviceSummaryButton
                statusRow("手机定位", symbol: "location", value: locationStatus,
                          color: model.navigation.hasUsableFix && !model.navigation.gnssStale ? QianTheme.accent : .secondary)
                statusRow("路况", symbol: "car.side", value: trafficStatus, color: .secondary)
                SurroundingMapStatusRow(store: model.surroundingMap)
                Button("管理离线地图") { showsMapDownloads = true }
            }
            if model.isDemoActive {
                Section {
                    Label("演示中的位置与行驶过程为模拟数据。", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(Color.secondary)
                } footer: { Text("道路数据 © OpenStreetMap contributors") }
            }
        }
        .listStyle(.insetGrouped)
        .modifier(QianInstrumentSurface())
        .navigationTitle(model.isDemoActive ? "演示导航" : "导航中")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { navigationActionBar }
    }

    private func rideMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text(title).font(.subheadline).foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)，\(value)")
    }

    private var navigationActionBar: some View {
        VStack(spacing: 10) {
            Button(action: model.toggleNavigation) {
                HStack(spacing: 9) {
                    if model.isPlanningRoutePreview {
                        ProgressView().tint(QianTheme.background)
                    } else {
                        Image(systemName: model.isNavigationActive ? "stop.fill" : "location.fill")
                    }
                    Text(model.primaryActionTitle).fixedSize(horizontal: false, vertical: true)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 34)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.large)
            .tint(model.isNavigationActive ? .red : QianTheme.accent)
            .foregroundStyle(model.isNavigationActive ? Color.white : QianTheme.background)
            .disabled(!model.isNavigationActive && (model.selectedPlace == nil || model.isPlanningRoutePreview))
            .accessibilityIdentifier("primary-navigation-action")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: - Device sheet

    private var deviceSummaryButton: some View {
        Button {
            searchFocused = false
            showsDeviceDetails = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "circle.circle")
                    .font(.title3)
                    .foregroundStyle(QianTheme.accent)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的圆屏").foregroundStyle(Color.primary)
                    Text(deviceStatus).font(.subheadline).foregroundStyle(Color.secondary)
                }
                Spacer(minLength: 4)
                if model.deviceReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("device-summary-button")
    }

    private var deviceDetails: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "location.north.circle")
                            .font(.system(size: 64, weight: .ultraLight))
                            .foregroundStyle(QianTheme.accent)
                            .accessibilityHidden(true)
                        Text(deviceName).font(.title2.weight(.semibold))
                        Text(deviceDetail)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .listRowBackground(Color.clear)
                Section {
                    statusRow("连接状态", symbol: "antenna.radiowaves.left.and.right", value: deviceStatus,
                              color: model.deviceReady ? .green : .secondary)
                    Button(connectionActionTitle, action: model.toggleDeviceConnection)
                        .accessibilityIdentifier("device-connection-action")
                    if case .bluetoothUnavailable = model.device.connection {
                        Button("打开系统设置", action: openSystemSettings)
                    }
                } footer: {
                    Text("圆屏保持开机并靠近 iPhone。连接成功后，当前导航会自动同步。")
                }
                Section("定位") {
                    statusRow("搜索位置", symbol: "location", value: searchLocationStatus, color: .secondary)
                    if model.searchLocationStatus == .permissionDenied {
                        Button("前往设置开启定位", action: openSystemSettings)
                    }
                }
                Section("汽水音乐与蓝牙歌词") {
                    Text("在 iPhone 系统蓝牙中配对圆屏，然后在汽水音乐的设置里开启“外接设备蓝牙时展示歌词”。")
                    Text("配套固件会接收音乐 App 通过蓝牙媒体信息输出的文字。歌词是否可用取决于播放器与系统实际输出；没有歌词时显示收到的歌曲信息。")
                        .font(.footnote).foregroundStyle(Color.secondary)
                }
            }
            .modifier(QianInstrumentSurface())
            .navigationTitle("我的圆屏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showsDeviceDetails = false }
                        .accessibilityIdentifier("device-details-done")
                }
            }
            .accessibilityIdentifier("device-details-sheet")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func statusRow(_ title: String, symbol: String, value: String, color: Color) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(color).multilineTextAlignment(.trailing)
        } label: {
            Label(title, systemImage: symbol).foregroundStyle(Color.primary)
        }
        .font(.body)
        .padding(.vertical, 4)
    }

    private func failureMessage(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    // MARK: - User-facing state

    private func placeSubtitle(_ place: PlaceSearchResult) -> String {
        let area = place.displayArea.isEmpty
            ? [place.city, place.district].filter { !$0.isEmpty }.joined(separator: " · ")
            : place.displayArea
        var parts = [area, place.address].filter { !$0.isEmpty }
        if let distance = place.distanceM, distance >= 0 {
            let distanceText = distance >= 1_000
                ? String(format: "%.1f km", distance / 1_000)
                : "\(Int(distance.rounded())) m"
            parts.append("距你 \(distanceText)")
        }
        return parts.isEmpty ? "查看路线" : parts.joined(separator: " · ")
    }

    private var deviceStatus: String {
        switch model.device.connection {
        case .connected: return model.deviceReady ? "已连接" : "正在准备"
        case .scanning: return "正在寻找圆屏"
        case .connecting: return "正在连接"
        case .failed: return "连接未成功"
        case .bluetoothUnavailable: return "蓝牙不可用"
        case .idle: return "未连接"
        }
    }

    private var deviceName: String {
        switch model.device.connection {
        case let .connected(name), let .connecting(name): return name
        default: return "Qian GPS"
        }
    }

    private var deviceDetail: String {
        switch model.device.connection {
        case .connected:
            return model.deviceReady ? "圆屏已就绪，可以接收导航指引。" : "正在准备导航同步，请稍候。"
        case .failed:
            return "暂时无法连接。请确认圆屏已开机并靠近手机，再试一次。"
        case .bluetoothUnavailable:
            return "请开启手机蓝牙，并允许 Qian GPS 使用蓝牙。"
        case .scanning, .connecting:
            return "请将已开机的圆屏放在手机附近。"
        case .idle:
            return "连接你的圆屏，在车把上查看导航。"
        }
    }

    private var connectionActionTitle: String {
        switch model.device.connection {
        case .connected: return "断开连接"
        case .scanning: return "停止搜索"
        case .connecting: return "取消连接"
        case .failed: return "重新连接"
        case .idle, .bluetoothUnavailable: return "连接圆屏"
        }
    }

    private var searchLocationStatus: String {
        switch model.searchLocationStatus {
        case .available: return "已获取"
        case .preparing: return "获取中"
        case .permissionDenied: return "未获授权"
        case .unavailable: return "暂不可用"
        }
    }

    private var navigationTitle: String {
        if model.navigationFailure != nil { return "导航需要处理" }
        switch model.navigation.stateName {
        case "acquiring": return "正在获取位置"
        case "planning": return "正在规划路线"
        case "rerouting": return "正在重新规划"
        case "arrived": return "已到达目的地"
        case "navigating": return model.isDemoActive ? "正在演示" : "正在导航"
        default: return "准备出发"
        }
    }

    private var navigationDetail: String {
        if let failure = model.navigationFailure { return failure }
        if model.navigation.stateName == "navigating" {
            if model.isDemoActive { return "预览行驶过程与圆屏上的导航指引。" }
            return model.deviceReady
                ? "圆屏已连接，手机可锁屏收好。"
                : "圆屏连接后，导航指引会自动同步。"
        }
        return model.phaseDetail
    }

    private var navigationSymbol: String {
        if model.navigationFailure != nil { return "exclamationmark.triangle" }
        switch model.navigation.stateName {
        case "arrived": return "flag.checkered"
        case "rerouting": return "arrow.triangle.2.circlepath"
        case "navigating": return "location.north.fill"
        default: return "location.magnifyingglass"
        }
    }

    private var hasNavigationEstimate: Bool {
        ["navigating", "rerouting", "arrived"].contains(model.navigation.stateName)
    }

    private var remainingDuration: String {
        hasNavigationEstimate ? model.remainingDurationText : "—"
    }

    private var remainingDistance: String {
        hasNavigationEstimate ? model.remainingDistanceText : "—"
    }

    private var locationStatus: String {
        if model.isDemoActive { return "演示位置" }
        return model.navigation.hasUsableFix ? "已获取" : "获取中"
    }

    private var trafficStatus: String {
        if model.isDemoActive { return "演示中" }
        if model.navigation.trafficRequestInFlight { return "更新中" }
        return model.navigation.networkName == "online" ? "在线" : "离线"
    }

    private func trafficTint(_ candidate: RoutePreviewCandidate) -> Color {
        switch candidate.trafficSummary {
        case "拥堵较多": return .red
        case "部分路段缓行": return .orange
        case "路况顺畅": return .green
        default: return .secondary
        }
    }
}
