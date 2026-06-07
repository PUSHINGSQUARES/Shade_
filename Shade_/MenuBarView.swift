import SwiftUI

struct MenuBarView: View {
    @Bindable var state: AppState
    let presenter: PanelPresenter

    var body: some View {
        let presentation = MenuBarModePresentation(
            mode: state.mode,
            isEnabled: state.isTransformEnabled
        )
        let schedulePresentation = SchedulePresentation(schedule: state.schedule)
        let passthroughPresentation = PassthroughPresentation(
            appCount: state.passthroughApps.count
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Shade_")
                    .font(.headline)

                Text(presentation.status)
                    .font(.caption)
                    .foregroundStyle(presentation.statusColor)

                Spacer()

                Toggle(state.isTransformEnabled ? "On" : "Off", isOn: $state.isTransformEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Divider()

            if state.isReadingTransformDevModeEnabled {
                Picker("Mode", selection: $state.mode) {
                    ForEach(
                        MenuBarModePresentation.availableModes(
                            readingTransformDevMode: state.isReadingTransformDevModeEnabled
                        ),
                        id: \.self
                    ) { mode in
                        Text(MenuBarModePresentation.modePickerTitle(for: mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if presentation.showsUnsafeWarning {
                    Text("Reading Transform is unsafe Dev Mode. It can recurse during manual smoke. Use Turn Off Now if mirrored windows appear.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if presentation.showsReadingControls {
                ControlSlider(title: "Intensity", value: $state.intensity, range: 0...1)
                ControlSlider(title: "Blue Reduction", value: $state.blueReduction, range: 0...1)
                ControlSlider(title: "Dim", value: $state.dim, range: 0...0.8)

                Toggle("Contrast Protect", isOn: $state.contrastProtect)
                Toggle("Show Performance HUD", isOn: $state.showPerformanceHUD)

                Button("Reset Reading Defaults") {
                    state.resetReadingDefaults()
                }
            }

            if presentation.showsOverlayControls {
                OverlayPresetPicker(state: state)
                CustomPresetRow(state: state) {
                    presenter.show(id: "customPresets", title: "My Presets", size: NSSize(width: 360, height: 240)) {
                        CustomPresetsView(state: state, onClose: { presenter.close(id: "customPresets") })
                    }
                }

                DisclosureGroup("Advanced") {
                    Toggle("Use custom colour", isOn: $state.overlayUseCustomColour)

                    if state.overlayUseCustomColour {
                        ControlSlider(title: "Hue", value: $state.overlayHue, range: 0...1)
                        ControlSlider(title: "Saturation", value: $state.overlaySaturation, range: 0...1)
                    } else {
                        ControlSlider(
                            title: "Warmth",
                            value: $state.overlayKelvin,
                            range: 1900...6500,
                            step: 50,
                            format: { String(format: "%.0f K", $0) }
                        )
                        ControlSlider(title: "Blue Cut", value: $state.overlayBlueCut, range: 0...1)
                    }

                    ControlSlider(title: "Strength", value: $state.overlayOpacity, range: 0...0.8)
                    ControlSlider(title: "Dim", value: $state.overlayDim, range: 0...0.8)
                }

                Button("Reset Overlay Defaults") {
                    state.resetOverlayDefaults()
                }
            }

            Divider()

            Button {
                presenter.show(id: "schedule", title: "Schedule", size: NSSize(width: 360, height: 300)) {
                    ScheduleView(state: state, onClose: { presenter.close(id: "schedule") })
                }
            } label: {
                HStack {
                    Text("Schedule\u{2026}")
                    Spacer()
                    Text(schedulePresentation.trailingStatus)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button {
                presenter.show(id: "passthrough", title: "Passthrough", size: NSSize(width: 460, height: 480)) {
                    PassthroughView(state: state, onClose: { presenter.close(id: "passthrough") })
                }
            } label: {
                HStack {
                    Text("Passthrough\u{2026}")
                    Spacer()
                    Text(passthroughPresentation.trailingStatus)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button {
                presenter.show(id: "settings", title: "Settings", size: NSSize(width: 360, height: 200)) {
                    SettingsView(onClose: { presenter.close(id: "settings") })
                }
            } label: {
                HStack {
                    Text("Settings\u{2026}")
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if presentation.showsPerformanceDiagnostics && state.showPerformanceHUD {
                Divider()

                if presentation.showsOverlayControls {
                    Text("Hole Tracking: \(state.holeTrackingLatencyMilliseconds, specifier: "%.1f") ms")
                    if state.holeTrackingTrailing {
                        Text("Trailing")
                            .foregroundStyle(.orange)
                    }

                    Divider()

                    Text("Prediction Tuning")
                        .font(.caption.weight(.semibold))

                    ControlSlider(
                        title: "Lead Time",
                        value: $state.passthroughLeadTime,
                        range: 0...0.032,
                        step: 0.001,
                        format: { String(format: "%.0f ms", $0 * 1000) }
                    )
                    ControlSlider(
                        title: "Rest Margin",
                        value: $state.passthroughRestMargin,
                        range: 0...20,
                        step: 0.5,
                        format: { String(format: "%.1f pt", $0) }
                    )
                    ControlSlider(
                        title: "Motion Margin",
                        value: $state.passthroughMotionMargin,
                        range: 0...30,
                        step: 0.5,
                        format: { String(format: "%.1f pt", $0) }
                    )
                } else {
                    Text("FPS: \(state.framesPerSecond, specifier: "%.1f")")
                    Text("Latency: \(state.frameLatencyMilliseconds, specifier: "%.1f") ms")
                        .foregroundStyle(.secondary)
                }
            }

            if let lastError = state.lastError {
                Divider()

                Text(lastError)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button(state.isTransformEnabled ? "Turn Off Now" : "Transform Off") {
                state.disableTransform()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(!state.isTransformEnabled && state.lastError == nil)

            Button("Quit Shade_") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct MenuBarModePresentation {
    let mode: AppState.Mode
    let isEnabled: Bool

    static func availableModes(readingTransformDevMode: Bool) -> [AppState.Mode] {
        if readingTransformDevMode {
            return [.overlayFallback, .readingTransform]
        }

        return [.overlayFallback]
    }

    static func modePickerTitle(for mode: AppState.Mode) -> String {
        switch mode {
        case .readingTransform:
            return "Reading Transform Dev Mode"
        case .overlayFallback:
            return "Overlay Fallback"
        }
    }

    var title: String {
        switch mode {
        case .readingTransform:
            return "Reading Transform Dev Mode"
        case .overlayFallback:
            return "Overlay Fallback"
        }
    }

    var status: String {
        if isUnsafe {
            return "Unsafe"
        }

        return isEnabled ? "On" : "Off"
    }

    var statusColor: Color {
        if isUnsafe {
            return .red
        }

        return isEnabled ? .green : .secondary
    }

    var showsReadingControls: Bool {
        mode == .readingTransform
    }

    var showsOverlayControls: Bool {
        mode == .overlayFallback
    }

    var showsPerformanceDiagnostics: Bool {
        true
    }

    var isUnsafe: Bool {
        mode == .readingTransform
    }

    var showsUnsafeWarning: Bool {
        isUnsafe
    }
}

struct SettingsView: View {
    let onClose: () -> Void
    private let controller = LoginItemController()
    @State private var status: LoginItemStatus = .notEnabled
    @State private var pendingEnable: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }

            Text("Startup")
                .font(.caption.weight(.semibold))

            Toggle("Launch Shade_ at login", isOn: loginToggleBinding)

            Text(LoginItemStatusPresentation.text(status))
                .font(.caption)
                .foregroundStyle(LoginItemStatusPresentation.isError(status) ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding()
        .frame(width: 360)
        .onAppear { status = controller.refreshStatus() }
        .alert(alertTitle, isPresented: confirmPresented) {
            Button("Cancel", role: .cancel) { pendingEnable = nil }
            Button(alertConfirmLabel) {
                if let enable = pendingEnable {
                    status = controller.setEnabled(enable)
                }
                pendingEnable = nil
            }
        }
    }

    private var loginToggleBinding: Binding<Bool> {
        Binding(
            get: { LoginItemStatusPresentation.displayedToggleValue(pendingEnable: pendingEnable, status: status) },
            set: { newValue in pendingEnable = newValue }
        )
    }

    private var confirmPresented: Binding<Bool> {
        Binding(
            get: { pendingEnable != nil },
            set: { if !$0 { pendingEnable = nil } }
        )
    }

    private var alertTitle: String {
        (pendingEnable ?? false) ? "Enable launch at login?" : "Disable launch at login?"
    }

    private var alertConfirmLabel: String {
        (pendingEnable ?? false) ? "Enable" : "Disable"
    }
}

struct PassthroughPresentation {
    let appCount: Int

    var buttonTitle: String { "Passthrough..." }

    var summary: String {
        if appCount == 0 {
            return "Passthrough app windows stay clear while Shade_ stays on."
        }
        let label = appCount == 1 ? "app" : "apps"
        return "\(appCount) passthrough \(label) stay clear while Shade_ stays on."
    }

    var trailingStatus: String {
        switch appCount {
        case 0: return "Off"
        case 1: return "1 app"
        default: return "\(appCount) apps"
        }
    }
}

struct SchedulePresentation {
    let schedule: ShadeSchedule

    var buttonTitle: String {
        "Schedule..."
    }

    var summary: String {
        switch schedule.source {
        case .manualTimes:
            guard schedule.isEnabled else { return "Manual local schedule is off." }
            return "Manual local schedule: \(schedule.startTime.storageString) to \(schedule.endTime.storageString)."
        case .sunsetToSunrise:
            guard schedule.isEnabled else { return "Sunset to sunrise schedule is off." }
            guard let location = schedule.sunLocation else { return "Sunset to sunrise: no location set." }
            let base = "Sunset to sunrise: \(location.label)"
            if schedule.sunOffsetMinutes != 0 {
                let sign = schedule.sunOffsetMinutes > 0 ? "+" : ""
                return "\(base), \(sign)\(schedule.sunOffsetMinutes) min offset."
            }
            return "\(base)."
        }
    }

    var trailingStatus: String {
        guard schedule.isEnabled else { return "Off" }
        switch schedule.source {
        case .manualTimes:
            return "\(schedule.startTime.storageString)\u{2013}\(schedule.endTime.storageString)"
        case .sunsetToSunrise:
            return schedule.sunLocation == nil ? "Sun" : "Sun \u{00B7} on"
        }
    }

    var detail: String {
        "Uses this Mac's local time. Sunrise, sunset, and city lookup are not in this phase."
    }
}

struct ScheduleView: View {
    @Bindable var state: AppState
    let onClose: () -> Void
    @State private var startTimeText = ""
    @State private var endTimeText = ""
    @State private var validationMessage: String?
    @State private var citySearch = ""
    @State private var latText = ""
    @State private var lonText = ""
    @State private var locationMessage: String?
    private let cityDatabase = CityDatabase.bundled()
    private let locationProvider: LocationProvider = CoreLocationProvider()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Schedule").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { onClose() }.keyboardShortcut(.defaultAction)
            }

            Toggle("Enable schedule", isOn: scheduleEnabledBinding)

            Picker("Source", selection: sourceBinding) {
                Text("Manual times").tag(ScheduleSource.manualTimes)
                Text("Sunset to sunrise").tag(ScheduleSource.sunsetToSunrise)
            }
            .pickerStyle(.segmented)

            if state.schedule.source == .manualTimes {
                manualControls
            } else {
                sunControls
            }

            if let validationMessage {
                Text(validationMessage).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear(perform: syncFromState)
    }

    @ViewBuilder private var manualControls: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("Start")
                TextField("20:00", text: $startTimeText).textFieldStyle(.roundedBorder).frame(width: 90)
            }
            GridRow {
                Text("End")
                TextField("08:00", text: $endTimeText).textFieldStyle(.roundedBorder).frame(width: 90)
            }
        }
        Button("Apply Times") { applyTimes() }
    }

    @ViewBuilder private var sunControls: some View {
        TextField("Search city", text: $citySearch).textFieldStyle(.roundedBorder)
        if !citySearch.isEmpty {
            ForEach(cityDatabase.search(citySearch).prefix(5)) { city in
                Button(city.displayLabel) { selectCity(city) }.buttonStyle(.plain)
            }
        }
        DisclosureGroup("Enter coordinates manually") {
            HStack {
                TextField("Lat", text: $latText).textFieldStyle(.roundedBorder).frame(width: 80)
                TextField("Long", text: $lonText).textFieldStyle(.roundedBorder).frame(width: 80)
                Button("Use") { applyManualCoordinates() }
            }
        }
        Button("Use my current location") {
            Task {
                let result = await locationProvider.requestCurrentLocation()
                switch result {
                case .success(let loc):
                    var s = state.schedule
                    s.sunLocation = loc
                    state.schedule = s
                    locationMessage = nil
                    state.applySchedule()
                case .failure(.denied):
                    locationMessage = "Location permission denied. Use a city or coordinates instead."
                case .failure(.unavailable):
                    locationMessage = "Location is unavailable on this Mac."
                case .failure(.failed(let message)):
                    locationMessage = "Location failed: \(message)"
                }
            }
        }
        if let locationMessage {
            Text(locationMessage).font(.caption).foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        Stepper("Offset: \(state.schedule.sunOffsetMinutes) min", value: offsetBinding, in: -120...120, step: 5)
        Text(previewLine).font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var previewLine: String {
        guard state.schedule.sunLocation != nil else { return "Set a location" }
        guard let times = ShadeScheduleResolver.effectiveTimes(schedule: state.schedule, at: Date()) else {
            return "No sunset/sunrise at this location today."
        }
        return "Tonight: on \(times.start.storageString) \u{2192} off \(times.end.storageString)"
    }

    private var scheduleEnabledBinding: Binding<Bool> {
        Binding(
            get: { state.schedule.isEnabled },
            set: { var s = state.schedule; s.isEnabled = $0; state.schedule = s; state.applySchedule() }
        )
    }

    private var sourceBinding: Binding<ScheduleSource> {
        Binding(
            get: { state.schedule.source },
            set: { var s = state.schedule; s.source = $0; state.schedule = s; state.applySchedule() }
        )
    }

    private var offsetBinding: Binding<Int> {
        Binding(
            get: { state.schedule.sunOffsetMinutes },
            set: { var s = state.schedule; s.sunOffsetMinutes = $0; state.schedule = s; state.applySchedule() }
        )
    }

    private func selectCity(_ city: City) {
        var s = state.schedule
        s.sunLocation = ScheduleLocation(label: city.displayLabel, latitude: city.latitude, longitude: city.longitude)
        state.schedule = s
        citySearch = ""
        state.applySchedule()
    }

    private func applyManualCoordinates() {
        guard let lat = Double(latText), let lon = Double(lonText),
              (-90...90).contains(lat), (-180...180).contains(lon) else {
            validationMessage = "Latitude must be -90...90 and longitude -180...180."
            return
        }
        var s = state.schedule
        s.sunLocation = ScheduleLocation(label: "Custom location", latitude: lat, longitude: lon)
        state.schedule = s
        validationMessage = nil
        state.applySchedule()
    }

    private func syncFromState() {
        startTimeText = state.schedule.startTime.storageString
        endTimeText = state.schedule.endTime.storageString
        validationMessage = nil
    }

    private func applyTimes() {
        guard let startTime = ShadeClockTime(storageString: startTimeText),
              let endTime = ShadeClockTime(storageString: endTimeText) else {
            validationMessage = "Use HH:mm times, for example 20:00."
            return
        }

        var s = state.schedule
        s.startTime = startTime
        s.endTime = endTime
        state.schedule = s
        validationMessage = nil
        state.applySchedule()
    }
}

struct CustomPresetsView: View {
    @Bindable var state: AppState
    let onClose: () -> Void
    @State private var names: [String] = []
    @State private var pendingOverwriteIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("My Presets")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }

            Text("Save the current overlay settings into a slot, or rename a slot.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                ForEach(Array(state.customSlots.enumerated()), id: \.offset) { index, slot in
                    GridRow {
                        TextField("Custom \(index + 1)", text: nameBinding(index))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                            .onSubmit { commitName(index) }

                        Button("Save current here") {
                            if slot.inputs == nil {
                                state.saveCustomSlot(index: index)
                            } else {
                                pendingOverwriteIndex = index
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear { names = state.customSlots.map(\.name) }
        .alert(
            "Replace this preset?",
            isPresented: overwriteAlertPresented,
            presenting: pendingOverwriteIndex
        ) { index in
            Button("Cancel", role: .cancel) { pendingOverwriteIndex = nil }
            Button("Replace") {
                state.saveCustomSlot(index: index)
                pendingOverwriteIndex = nil
            }
        } message: { index in
            Text("Replace \u{201C}\(state.customSlots[index].name)\u{201D} with the current overlay settings?")
        }
    }

    private func nameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { index < names.count ? names[index] : state.customSlots[index].name },
            set: { newValue in
                if index < names.count { names[index] = newValue }
            }
        )
    }

    private func commitName(_ index: Int) {
        guard index < names.count else { return }
        state.renameCustomSlot(index: index, name: names[index])
        names[index] = state.customSlots[index].name
    }

    private var overwriteAlertPresented: Binding<Bool> {
        Binding(
            get: { pendingOverwriteIndex != nil },
            set: { if !$0 { pendingOverwriteIndex = nil } }
        )
    }
}

struct PassthroughView: View {
    @Bindable var state: AppState
    let onClose: () -> Void
    @State private var candidates: [PassthroughCandidate] = []
    private let catalog = PassthroughCatalog()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Passthrough")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("Refresh") {
                    reloadCandidates()
                }

                Button("Done") {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }

            Text("Choose running apps whose windows should pass through untouched while Shade_ stays on.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List {
                if candidates.isEmpty {
                    Text("No running apps found.")
                        .foregroundStyle(.secondary)
                }

                ForEach(candidates) { candidate in
                    PassthroughCandidateRow(candidate: candidate) {
                        toggle(candidate)
                    }
                }

                ForEach(unresolvedPassthroughApps) { app in
                    HStack(spacing: 10) {
                        Image(systemName: "app.dashed")
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.label)
                            Text("Saved passthrough")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Remove") {
                            state.removePassthroughApp(id: app.id)
                            reloadCandidates()
                        }
                    }
                    .padding(.vertical, 4)
                }

                HStack(spacing: 10) {
                    Image(systemName: "rectangle.dashed")
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Window Picking")
                        Text("Coming later. This phase protects all windows from a selected app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Unavailable") {}
                        .disabled(true)
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 300)
        }
        .padding()
        .frame(width: 460, height: 480)
        .onAppear(perform: reloadCandidates)
    }

    private var unresolvedPassthroughApps: [PassthroughApp] {
        let candidateBundleIdentifiers = Set(candidates.map(\.bundleIdentifier))
        return state.passthroughApps.filter { !candidateBundleIdentifiers.contains($0.bundleIdentifier) }
    }

    private func reloadCandidates() {
        candidates = catalog.candidates(passthroughApps: state.passthroughApps)
    }

    private func toggle(_ candidate: PassthroughCandidate) {
        if candidate.isPassthrough {
            state.removePassthroughApp(bundleIdentifier: candidate.bundleIdentifier)
        } else {
            state.addPassthroughApp(label: candidate.label, bundleIdentifier: candidate.bundleIdentifier)
        }

        reloadCandidates()
    }
}

private struct PassthroughCandidateRow: View {
    let candidate: PassthroughCandidate
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            appIcon

            Text(candidate.presentation.label)

            Spacer()

            Button(candidate.presentation.isPassthrough ? "Remove" : "Passthrough", action: toggle)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = candidate.presentation.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "app")
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OverlayPresetPicker: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Warmth")
                .font(.caption.weight(.semibold))
            HStack(spacing: 6) {
                ForEach(OverlayPresetPresentation.warmthPresets, id: \.self) { preset in
                    presetButton(preset)
                }
            }

            Text("Reading")
                .font(.caption.weight(.semibold))
            HStack(spacing: 6) {
                ForEach(OverlayPresetPresentation.readingPresets, id: \.self) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: OverlayPreset) -> some View {
        Button(OverlayPresetPresentation.title(preset)) {
            state.setPreset(preset)
        }
        .buttonStyle(.bordered)
        .tint(state.overlayPreset == preset ? Color.accentColor : nil)
        .font(.caption)
    }
}

private struct CustomPresetRow: View {
    @Bindable var state: AppState
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("My Presets")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("Manage\u{2026}", action: onManage)
                    .buttonStyle(.plain)
                    .font(.caption)
            }

            HStack(spacing: 6) {
                ForEach(Array(state.customSlots.enumerated()), id: \.offset) { index, slot in
                    Button(slot.name) {
                        state.applyCustomSlot(index: index)
                    }
                    .buttonStyle(.bordered)
                    .tint(state.selectedCustomSlotIndex == index ? Color.accentColor : nil)
                    .font(.caption)
                    .disabled(slot.inputs == nil)
                }
            }
        }
    }
}

private struct ControlSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.01
    var format: ((Double) -> String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range, step: step)
        }
    }

    private var formattedValue: String {
        if let format { return format(value) }
        return "\(Int((value * 100).rounded()))%"
    }
}
