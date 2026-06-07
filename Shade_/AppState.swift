import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum Mode: String {
        case readingTransform
        case overlayFallback
    }

    enum Defaults {
        static let mode = Mode.overlayFallback
        static let readingTransformDevModeEnvironmentKey = "SHADE_READING_TRANSFORM_DEV_MODE"
        static let intensity = 0.35
        static let blueReduction = 0.45
        static let dim = 0.10
        static let contrastProtect = true
        static let showPerformanceHUD = true
        static let overlayHue = 0.11
        static let overlayOpacity = 0.25
        static let overlayDim = 0.15
        static let overlayPreset = OverlayPreset.balanced
        static let overlayUseCustomColour = false
        static let overlayKelvin = 2500.0
        static let overlayBlueCut = 0.6
        static let overlaySaturation = 0.35
        static let passthroughApps: [PassthroughApp] = []
        static let passthroughLeadTime: Double = 0.009
        static let passthroughRestMargin: Double = 2.5
        static let passthroughMotionMargin: Double = 7.5
        static let schedule = ShadeSchedule(
            isEnabled: false,
            startTime: ShadeClockTime(hour: 20, minute: 0)!,
            endTime: ShadeClockTime(hour: 8, minute: 0)!
        )
        static let customSlots: [CustomOverlaySlot] = [
            CustomOverlaySlot(name: "Custom 1", inputs: nil),
            CustomOverlaySlot(name: "Custom 2", inputs: nil),
            CustomOverlaySlot(name: "Custom 3", inputs: nil)
        ]
        static let selectedCustomSlotIndex: Int? = nil
    }

    enum PersistenceKey {
        static let mode = "shade.settings.mode"
        static let intensity = "shade.settings.intensity"
        static let blueReduction = "shade.settings.blueReduction"
        static let dim = "shade.settings.dim"
        static let contrastProtect = "shade.settings.contrastProtect"
        static let showPerformanceHUD = "shade.settings.showPerformanceHUD"
        static let overlayHue = "shade.settings.overlayHue"
        static let overlayOpacity = "shade.settings.overlayOpacity"
        static let overlayDim = "shade.settings.overlayDim"
        static let overlayPreset = "shade.settings.overlay.preset"
        static let overlayUseCustomColour = "shade.settings.overlay.useCustomColour"
        static let overlayKelvin = "shade.settings.overlay.kelvin"
        static let overlayBlueCut = "shade.settings.overlay.blueCut"
        static let overlaySaturation = "shade.settings.overlay.saturation"
        static let passthroughApps = "shade.settings.passthroughApps"
        static let passthroughLeadTime = "shade.settings.passthrough.leadTime"
        static let passthroughRestMargin = "shade.settings.passthrough.restMargin"
        static let passthroughMotionMargin = "shade.settings.passthrough.motionMargin"
        static let scheduleEnabled = "shade.settings.schedule.enabled"
        static let scheduleStartTime = "shade.settings.schedule.startTime"
        static let scheduleEndTime = "shade.settings.schedule.endTime"
        static let customSlots = "shade.settings.customSlots"
        static let selectedCustomSlotIndex = "shade.settings.customSlots.selected"
        static let scheduleSource = "shade.settings.schedule.source"
        static let scheduleSunLocation = "shade.settings.schedule.sunLocation"
        static let scheduleSunOffsetMinutes = "shade.settings.schedule.sunOffsetMinutes"
    }

    @ObservationIgnored private let userDefaults: UserDefaults
    let isReadingTransformDevModeEnabled: Bool
    private var storedMode: Mode = Defaults.mode
    private var storedIntensity: Double = Defaults.intensity
    private var storedBlueReduction: Double = Defaults.blueReduction
    private var storedDim: Double = Defaults.dim
    private var storedOverlayHue: Double = Defaults.overlayHue
    private var storedOverlayOpacity: Double = Defaults.overlayOpacity
    private var storedOverlayDim: Double = Defaults.overlayDim
    private var storedOverlayPreset: OverlayPreset = Defaults.overlayPreset
    private var storedOverlayUseCustomColour: Bool = Defaults.overlayUseCustomColour
    private var storedOverlayKelvin: Double = Defaults.overlayKelvin
    private var storedOverlayBlueCut: Double = Defaults.overlayBlueCut
    private var storedOverlaySaturation: Double = Defaults.overlaySaturation
    private var storedPassthroughApps: [PassthroughApp] = Defaults.passthroughApps
    private var storedPassthroughLeadTime: Double = Defaults.passthroughLeadTime
    private var storedPassthroughRestMargin: Double = Defaults.passthroughRestMargin
    private var storedPassthroughMotionMargin: Double = Defaults.passthroughMotionMargin
    private var storedSchedule: ShadeSchedule = Defaults.schedule
    private var storedCustomSlots: [CustomOverlaySlot] = Defaults.customSlots
    private var storedSelectedCustomSlotIndex: Int? = Defaults.selectedCustomSlotIndex

    var isTransformEnabled: Bool = false
    var mode: Mode {
        get {
            storedMode
        }
        set {
            storedMode = Self.safeMode(newValue, readingTransformDevMode: isReadingTransformDevModeEnabled)
            userDefaults.set(storedMode.rawValue, forKey: PersistenceKey.mode)
        }
    }
    var intensity: Double {
        get {
            storedIntensity
        }
        set {
            storedIntensity = Self.sanitize(newValue, defaultValue: Defaults.intensity, lower: 0, upper: 1)
            userDefaults.set(storedIntensity, forKey: PersistenceKey.intensity)
        }
    }
    var blueReduction: Double {
        get {
            storedBlueReduction
        }
        set {
            storedBlueReduction = Self.sanitize(newValue, defaultValue: Defaults.blueReduction, lower: 0, upper: 1)
            userDefaults.set(storedBlueReduction, forKey: PersistenceKey.blueReduction)
        }
    }
    var dim: Double {
        get {
            storedDim
        }
        set {
            storedDim = Self.sanitize(newValue, defaultValue: Defaults.dim, lower: 0, upper: 0.8)
            userDefaults.set(storedDim, forKey: PersistenceKey.dim)
        }
    }
    var overlayHue: Double {
        get {
            storedOverlayHue
        }
        set {
            storedOverlayHue = Self.sanitize(newValue, defaultValue: Defaults.overlayHue, lower: 0, upper: 1)
            userDefaults.set(storedOverlayHue, forKey: PersistenceKey.overlayHue)
            markCustom()
        }
    }
    var overlayOpacity: Double {
        get {
            storedOverlayOpacity
        }
        set {
            storedOverlayOpacity = Self.sanitize(newValue, defaultValue: Defaults.overlayOpacity, lower: 0, upper: 0.8)
            userDefaults.set(storedOverlayOpacity, forKey: PersistenceKey.overlayOpacity)
            markCustom()
        }
    }
    var overlayDim: Double {
        get {
            storedOverlayDim
        }
        set {
            storedOverlayDim = Self.sanitize(newValue, defaultValue: Defaults.overlayDim, lower: 0, upper: 0.8)
            userDefaults.set(storedOverlayDim, forKey: PersistenceKey.overlayDim)
            markCustom()
        }
    }

    var overlayPreset: OverlayPreset { storedOverlayPreset }

    var overlayUseCustomColour: Bool {
        get { storedOverlayUseCustomColour }
        set {
            storedOverlayUseCustomColour = newValue
            userDefaults.set(newValue, forKey: PersistenceKey.overlayUseCustomColour)
            markCustom()
        }
    }
    var overlayKelvin: Double {
        get { storedOverlayKelvin }
        set {
            storedOverlayKelvin = Self.sanitize(newValue, defaultValue: Defaults.overlayKelvin, lower: 1900, upper: 6500)
            userDefaults.set(storedOverlayKelvin, forKey: PersistenceKey.overlayKelvin)
            markCustom()
        }
    }
    var overlayBlueCut: Double {
        get { storedOverlayBlueCut }
        set {
            storedOverlayBlueCut = Self.sanitize(newValue, defaultValue: Defaults.overlayBlueCut, lower: 0, upper: 1)
            userDefaults.set(storedOverlayBlueCut, forKey: PersistenceKey.overlayBlueCut)
            markCustom()
        }
    }
    var overlaySaturation: Double {
        get { storedOverlaySaturation }
        set {
            storedOverlaySaturation = Self.sanitize(newValue, defaultValue: Defaults.overlaySaturation, lower: 0, upper: 1)
            userDefaults.set(storedOverlaySaturation, forKey: PersistenceKey.overlaySaturation)
            markCustom()
        }
    }

    var overlayTintInputs: OverlayTintInputs {
        OverlayTintInputs(
            useCustomColour: storedOverlayUseCustomColour,
            kelvin: storedOverlayKelvin,
            blueCut: storedOverlayBlueCut,
            hue: storedOverlayHue,
            saturation: storedOverlaySaturation,
            strength: storedOverlayOpacity,
            dim: storedOverlayDim
        )
    }

    var customSlots: [CustomOverlaySlot] { storedCustomSlots }
    var selectedCustomSlotIndex: Int? { storedSelectedCustomSlotIndex }

    func setPreset(_ preset: OverlayPreset) {
        storedSelectedCustomSlotIndex = nil
        persistSelectedCustomSlotIndex()
        storedOverlayPreset = preset
        userDefaults.set(preset.rawValue, forKey: PersistenceKey.overlayPreset)
        guard let values = preset.values else { return }
        storedOverlayUseCustomColour = values.useCustomColour
        storedOverlayKelvin = values.kelvin
        storedOverlayBlueCut = values.blueCut
        storedOverlayHue = values.hue
        storedOverlaySaturation = values.saturation
        storedOverlayOpacity = values.strength
        storedOverlayDim = values.dim
        userDefaults.set(storedOverlayUseCustomColour, forKey: PersistenceKey.overlayUseCustomColour)
        userDefaults.set(storedOverlayKelvin, forKey: PersistenceKey.overlayKelvin)
        userDefaults.set(storedOverlayBlueCut, forKey: PersistenceKey.overlayBlueCut)
        userDefaults.set(storedOverlayHue, forKey: PersistenceKey.overlayHue)
        userDefaults.set(storedOverlaySaturation, forKey: PersistenceKey.overlaySaturation)
        userDefaults.set(storedOverlayOpacity, forKey: PersistenceKey.overlayOpacity)
        userDefaults.set(storedOverlayDim, forKey: PersistenceKey.overlayDim)
    }

    func saveCustomSlot(index: Int) {
        guard storedCustomSlots.indices.contains(index) else { return }
        storedCustomSlots[index].inputs = overlayTintInputs
        storedSelectedCustomSlotIndex = index
        storedOverlayPreset = .custom
        userDefaults.set(OverlayPreset.custom.rawValue, forKey: PersistenceKey.overlayPreset)
        persistCustomSlots()
        persistSelectedCustomSlotIndex()
    }

    func renameCustomSlot(index: Int, name: String) {
        guard storedCustomSlots.indices.contains(index) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        storedCustomSlots[index].name = trimmed.isEmpty ? "Custom \(index + 1)" : trimmed
        persistCustomSlots()
    }

    func applyCustomSlot(index: Int) {
        guard storedCustomSlots.indices.contains(index),
              let inputs = storedCustomSlots[index].inputs else { return }

        storedOverlayUseCustomColour = inputs.useCustomColour
        storedOverlayKelvin = inputs.kelvin
        storedOverlayBlueCut = inputs.blueCut
        storedOverlayHue = inputs.hue
        storedOverlaySaturation = inputs.saturation
        storedOverlayOpacity = inputs.strength
        storedOverlayDim = inputs.dim
        storedOverlayPreset = .custom
        storedSelectedCustomSlotIndex = index

        userDefaults.set(storedOverlayUseCustomColour, forKey: PersistenceKey.overlayUseCustomColour)
        userDefaults.set(storedOverlayKelvin, forKey: PersistenceKey.overlayKelvin)
        userDefaults.set(storedOverlayBlueCut, forKey: PersistenceKey.overlayBlueCut)
        userDefaults.set(storedOverlayHue, forKey: PersistenceKey.overlayHue)
        userDefaults.set(storedOverlaySaturation, forKey: PersistenceKey.overlaySaturation)
        userDefaults.set(storedOverlayOpacity, forKey: PersistenceKey.overlayOpacity)
        userDefaults.set(storedOverlayDim, forKey: PersistenceKey.overlayDim)
        userDefaults.set(storedOverlayPreset.rawValue, forKey: PersistenceKey.overlayPreset)
        persistSelectedCustomSlotIndex()
    }

    private func markCustom() {
        storedOverlayPreset = .custom
        userDefaults.set(OverlayPreset.custom.rawValue, forKey: PersistenceKey.overlayPreset)
        storedSelectedCustomSlotIndex = nil
        persistSelectedCustomSlotIndex()
    }
    var contrastProtect: Bool = Defaults.contrastProtect {
        didSet {
            userDefaults.set(contrastProtect, forKey: PersistenceKey.contrastProtect)
        }
    }
    var showPerformanceHUD: Bool = Defaults.showPerformanceHUD {
        didSet {
            userDefaults.set(showPerformanceHUD, forKey: PersistenceKey.showPerformanceHUD)
        }
    }
    var passthroughApps: [PassthroughApp] {
        storedPassthroughApps
    }
    var passthroughLeadTime: Double {
        get { storedPassthroughLeadTime }
        set {
            storedPassthroughLeadTime = Self.sanitize(newValue, defaultValue: Defaults.passthroughLeadTime, lower: 0, upper: 0.032)
            userDefaults.set(storedPassthroughLeadTime, forKey: PersistenceKey.passthroughLeadTime)
        }
    }
    var passthroughRestMargin: Double {
        get { storedPassthroughRestMargin }
        set {
            storedPassthroughRestMargin = Self.sanitize(newValue, defaultValue: Defaults.passthroughRestMargin, lower: 0, upper: 20)
            userDefaults.set(storedPassthroughRestMargin, forKey: PersistenceKey.passthroughRestMargin)
        }
    }
    var passthroughMotionMargin: Double {
        get { storedPassthroughMotionMargin }
        set {
            storedPassthroughMotionMargin = Self.sanitize(newValue, defaultValue: Defaults.passthroughMotionMargin, lower: 0, upper: 30)
            userDefaults.set(storedPassthroughMotionMargin, forKey: PersistenceKey.passthroughMotionMargin)
        }
    }
    var motionPredictionConfig: MotionPredictionConfig {
        MotionPredictionConfig(
            leadTimeSeconds: passthroughLeadTime,
            restMargin: CGFloat(passthroughRestMargin),
            motionMargin: CGFloat(passthroughMotionMargin)
        )
    }
    var schedule: ShadeSchedule {
        get {
            storedSchedule
        }
        set {
            storedSchedule = newValue
            persistSchedule()
        }
    }
    var shouldShowOverlayFallback: Bool {
        isTransformEnabled
    }
    var framesPerSecond: Double = 0
    var frameLatencyMilliseconds: Double = 0
    /// Latency in milliseconds from when the hole-tracking tick fires to when the overlay update completes.
    /// Read-only metric — must NOT affect isTransformEnabled.
    var holeTrackingLatencyMilliseconds: Double = 0
    /// True when holeTrackingLatencyMilliseconds exceeds one 60Hz frame (16ms), indicating trailing.
    /// Read-only metric — must NOT affect isTransformEnabled.
    var holeTrackingTrailing: Bool = false
    var lastError: String?

    init(
        userDefaults: UserDefaults = .standard,
        readingTransformDevMode: Bool? = nil
    ) {
        self.userDefaults = userDefaults
        let resolvedReadingTransformDevMode = readingTransformDevMode ?? Self.defaultReadingTransformDevMode()
        self.isReadingTransformDevModeEnabled = resolvedReadingTransformDevMode
        storedMode = Self.safeMode(
            Self.mode(forKey: PersistenceKey.mode, in: userDefaults, defaultValue: Defaults.mode),
            readingTransformDevMode: resolvedReadingTransformDevMode
        )
        storedIntensity = Self.double(
            forKey: PersistenceKey.intensity,
            in: userDefaults,
            defaultValue: Defaults.intensity,
            lower: 0,
            upper: 1
        )
        storedBlueReduction = Self.double(
            forKey: PersistenceKey.blueReduction,
            in: userDefaults,
            defaultValue: Defaults.blueReduction,
            lower: 0,
            upper: 1
        )
        storedDim = Self.double(
            forKey: PersistenceKey.dim,
            in: userDefaults,
            defaultValue: Defaults.dim,
            lower: 0,
            upper: 0.8
        )
        storedOverlayHue = Self.double(
            forKey: PersistenceKey.overlayHue,
            in: userDefaults,
            defaultValue: Defaults.overlayHue,
            lower: 0,
            upper: 1
        )
        storedOverlayOpacity = Self.double(
            forKey: PersistenceKey.overlayOpacity,
            in: userDefaults,
            defaultValue: Defaults.overlayOpacity,
            lower: 0,
            upper: 0.8
        )
        storedOverlayDim = Self.double(
            forKey: PersistenceKey.overlayDim,
            in: userDefaults,
            defaultValue: Defaults.overlayDim,
            lower: 0,
            upper: 0.8
        )
        storedOverlayUseCustomColour = Self.bool(
            forKey: PersistenceKey.overlayUseCustomColour,
            in: userDefaults,
            defaultValue: Defaults.overlayUseCustomColour
        )
        storedOverlayKelvin = Self.double(
            forKey: PersistenceKey.overlayKelvin,
            in: userDefaults,
            defaultValue: Defaults.overlayKelvin,
            lower: 1900,
            upper: 6500
        )
        storedOverlayBlueCut = Self.double(
            forKey: PersistenceKey.overlayBlueCut,
            in: userDefaults,
            defaultValue: Defaults.overlayBlueCut,
            lower: 0,
            upper: 1
        )
        storedOverlaySaturation = Self.double(
            forKey: PersistenceKey.overlaySaturation,
            in: userDefaults,
            defaultValue: Defaults.overlaySaturation,
            lower: 0,
            upper: 1
        )
        contrastProtect = Self.bool(
            forKey: PersistenceKey.contrastProtect,
            in: userDefaults,
            defaultValue: Defaults.contrastProtect
        )
        showPerformanceHUD = Self.bool(
            forKey: PersistenceKey.showPerformanceHUD,
            in: userDefaults,
            defaultValue: Defaults.showPerformanceHUD
        )
        storedPassthroughApps = Self.passthroughApps(
            forKey: PersistenceKey.passthroughApps,
            in: userDefaults,
            defaultValue: Defaults.passthroughApps
        )
        storedPassthroughLeadTime = Self.double(
            forKey: PersistenceKey.passthroughLeadTime,
            in: userDefaults,
            defaultValue: Defaults.passthroughLeadTime,
            lower: 0,
            upper: 0.032
        )
        storedPassthroughRestMargin = Self.double(
            forKey: PersistenceKey.passthroughRestMargin,
            in: userDefaults,
            defaultValue: Defaults.passthroughRestMargin,
            lower: 0,
            upper: 20
        )
        storedPassthroughMotionMargin = Self.double(
            forKey: PersistenceKey.passthroughMotionMargin,
            in: userDefaults,
            defaultValue: Defaults.passthroughMotionMargin,
            lower: 0,
            upper: 30
        )
        storedSchedule = Self.schedule(in: userDefaults, defaultValue: Defaults.schedule)
        storedCustomSlots = Self.customSlots(
            forKey: PersistenceKey.customSlots,
            in: userDefaults,
            defaultValue: Defaults.customSlots
        )
        storedSelectedCustomSlotIndex = Self.selectedCustomSlotIndex(
            in: userDefaults,
            slots: storedCustomSlots
        )
        if userDefaults.object(forKey: PersistenceKey.overlayPreset) == nil {
            // Fresh install or pre-preset user: select Balanced without clobbering
            // pre-existing overlayHue or overlaySaturation (kept as custom-colour seeds).
            let retainedHue = storedOverlayHue
            let retainedSaturation = storedOverlaySaturation
            setPreset(.balanced)
            storedOverlayHue = retainedHue
            userDefaults.set(storedOverlayHue, forKey: PersistenceKey.overlayHue)
            storedOverlaySaturation = retainedSaturation
            userDefaults.set(storedOverlaySaturation, forKey: PersistenceKey.overlaySaturation)
        } else {
            storedOverlayPreset = OverlayPreset(
                rawValue: userDefaults.string(forKey: PersistenceKey.overlayPreset) ?? ""
            ) ?? .balanced
        }
        persistUserFacingSettings()
    }

    func disableTransform() {
        isTransformEnabled = false
        lastError = nil
    }

    func resetReadingDefaults() {
        intensity = Defaults.intensity
        blueReduction = Defaults.blueReduction
        dim = Defaults.dim
        contrastProtect = Defaults.contrastProtect
    }

    func resetOverlayDefaults() {
        setPreset(.balanced)
    }

    func addPassthroughApp(label: String, bundleIdentifier: String) {
        guard let label = Self.sanitizedLabel(label),
              let bundleIdentifier = Self.sanitizedBundleIdentifier(bundleIdentifier) else {
            return
        }

        storedPassthroughApps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        storedPassthroughApps.append(
            PassthroughApp(
                label: label,
                scope: .application,
                bundleIdentifier: bundleIdentifier
            )
        )
        persistPassthroughApps()
    }

    func removePassthroughApp(id: UUID) {
        storedPassthroughApps.removeAll { $0.id == id }
        persistPassthroughApps()
    }

    func removePassthroughApp(bundleIdentifier: String) {
        guard let bundleIdentifier = Self.sanitizedBundleIdentifier(bundleIdentifier) else {
            return
        }

        storedPassthroughApps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        persistPassthroughApps()
    }

    func isPassthroughApp(bundleIdentifier: String) -> Bool {
        guard let bundleIdentifier = Self.sanitizedBundleIdentifier(bundleIdentifier) else {
            return false
        }

        return storedPassthroughApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func applySchedule(at date: Date = Date()) {
        guard storedSchedule.isEnabled else {
            return
        }

        isTransformEnabled = ShadeScheduleEvaluator.shouldEnable(schedule: storedSchedule, at: date)
    }

    var parameters: ReadingTransformParameters {
        ReadingTransformParameters(
            intensity: Float(intensity),
            blueReduction: Float(blueReduction),
            dim: Float(dim),
            contrastProtect: contrastProtect
        )
    }

    private func persistUserFacingSettings() {
        userDefaults.set(storedMode.rawValue, forKey: PersistenceKey.mode)
        userDefaults.set(storedIntensity, forKey: PersistenceKey.intensity)
        userDefaults.set(storedBlueReduction, forKey: PersistenceKey.blueReduction)
        userDefaults.set(storedDim, forKey: PersistenceKey.dim)
        userDefaults.set(contrastProtect, forKey: PersistenceKey.contrastProtect)
        userDefaults.set(showPerformanceHUD, forKey: PersistenceKey.showPerformanceHUD)
        userDefaults.set(storedOverlayHue, forKey: PersistenceKey.overlayHue)
        userDefaults.set(storedOverlayOpacity, forKey: PersistenceKey.overlayOpacity)
        userDefaults.set(storedOverlayDim, forKey: PersistenceKey.overlayDim)
        userDefaults.set(storedOverlayPreset.rawValue, forKey: PersistenceKey.overlayPreset)
        userDefaults.set(storedOverlayUseCustomColour, forKey: PersistenceKey.overlayUseCustomColour)
        userDefaults.set(storedOverlayKelvin, forKey: PersistenceKey.overlayKelvin)
        userDefaults.set(storedOverlayBlueCut, forKey: PersistenceKey.overlayBlueCut)
        userDefaults.set(storedOverlaySaturation, forKey: PersistenceKey.overlaySaturation)
        persistPassthroughApps()
        userDefaults.set(storedPassthroughLeadTime, forKey: PersistenceKey.passthroughLeadTime)
        userDefaults.set(storedPassthroughRestMargin, forKey: PersistenceKey.passthroughRestMargin)
        userDefaults.set(storedPassthroughMotionMargin, forKey: PersistenceKey.passthroughMotionMargin)
        persistCustomSlots()
        persistSelectedCustomSlotIndex()
        persistSchedule()
    }

    private static func mode(forKey key: String, in userDefaults: UserDefaults, defaultValue: Mode) -> Mode {
        guard let rawValue = userDefaults.object(forKey: key) as? String,
              let mode = Mode(rawValue: rawValue) else {
            return defaultValue
        }

        return mode
    }

    private static func safeMode(_ mode: Mode, readingTransformDevMode: Bool) -> Mode {
        switch mode {
        case .readingTransform:
            return readingTransformDevMode ? .readingTransform : .overlayFallback
        case .overlayFallback:
            return .overlayFallback
        }
    }

    private static func defaultReadingTransformDevMode() -> Bool {
        ProcessInfo.processInfo.environment[Defaults.readingTransformDevModeEnvironmentKey] == "1"
    }

    private static func double(
        forKey key: String,
        in userDefaults: UserDefaults,
        defaultValue: Double,
        lower: Double,
        upper: Double
    ) -> Double {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return sanitize(userDefaults.double(forKey: key), defaultValue: defaultValue, lower: lower, upper: upper)
    }

    private static func bool(forKey key: String, in userDefaults: UserDefaults, defaultValue: Bool) -> Bool {
        guard let storedValue = userDefaults.object(forKey: key) as? Bool else {
            return defaultValue
        }

        return storedValue
    }

    private func persistPassthroughApps() {
        guard let data = try? JSONEncoder().encode(storedPassthroughApps) else {
            return
        }

        userDefaults.set(data, forKey: PersistenceKey.passthroughApps)
    }

    private func persistCustomSlots() {
        guard let data = try? JSONEncoder().encode(storedCustomSlots) else {
            return
        }

        userDefaults.set(data, forKey: PersistenceKey.customSlots)
    }

    private func persistSelectedCustomSlotIndex() {
        userDefaults.set(storedSelectedCustomSlotIndex ?? -1, forKey: PersistenceKey.selectedCustomSlotIndex)
    }

    private func persistSchedule() {
        userDefaults.set(storedSchedule.isEnabled, forKey: PersistenceKey.scheduleEnabled)
        userDefaults.set(storedSchedule.startTime.storageString, forKey: PersistenceKey.scheduleStartTime)
        userDefaults.set(storedSchedule.endTime.storageString, forKey: PersistenceKey.scheduleEndTime)
        userDefaults.set(storedSchedule.source.rawValue, forKey: PersistenceKey.scheduleSource)
        userDefaults.set(storedSchedule.sunOffsetMinutes, forKey: PersistenceKey.scheduleSunOffsetMinutes)
        if let location = storedSchedule.sunLocation,
           let data = try? JSONEncoder().encode(location) {
            userDefaults.set(data, forKey: PersistenceKey.scheduleSunLocation)
        } else {
            userDefaults.removeObject(forKey: PersistenceKey.scheduleSunLocation)
        }
    }

    private static func passthroughApps(
        forKey key: String,
        in userDefaults: UserDefaults,
        defaultValue: [PassthroughApp]
    ) -> [PassthroughApp] {
        guard let data = userDefaults.data(forKey: key),
              let storedValue = try? JSONDecoder().decode([PassthroughApp].self, from: data) else {
            return defaultValue
        }

        return storedValue.filter {
            sanitizedLabel($0.label) != nil && sanitizedBundleIdentifier($0.bundleIdentifier) != nil
        }
    }

    private static func customSlots(
        forKey key: String,
        in userDefaults: UserDefaults,
        defaultValue: [CustomOverlaySlot]
    ) -> [CustomOverlaySlot] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomOverlaySlot].self, from: data),
              decoded.count == 3 else {
            return defaultValue
        }

        return decoded
    }

    private static func selectedCustomSlotIndex(
        in userDefaults: UserDefaults,
        slots: [CustomOverlaySlot]
    ) -> Int? {
        guard userDefaults.object(forKey: PersistenceKey.selectedCustomSlotIndex) != nil else {
            return nil
        }

        let raw = userDefaults.integer(forKey: PersistenceKey.selectedCustomSlotIndex)
        guard slots.indices.contains(raw), slots[raw].inputs != nil else {
            return nil
        }

        return raw
    }

    private static func schedule(in userDefaults: UserDefaults, defaultValue: ShadeSchedule) -> ShadeSchedule {
        let isEnabled = bool(
            forKey: PersistenceKey.scheduleEnabled,
            in: userDefaults,
            defaultValue: defaultValue.isEnabled
        )
        let startTime = clockTime(
            forKey: PersistenceKey.scheduleStartTime,
            in: userDefaults,
            defaultValue: defaultValue.startTime
        )
        let endTime = clockTime(
            forKey: PersistenceKey.scheduleEndTime,
            in: userDefaults,
            defaultValue: defaultValue.endTime
        )

        let source: ScheduleSource = {
            guard let raw = userDefaults.string(forKey: PersistenceKey.scheduleSource),
                  let value = ScheduleSource(rawValue: raw) else {
                return .manualTimes
            }
            return value
        }()

        let sunLocation: ScheduleLocation? = {
            guard let data = userDefaults.data(forKey: PersistenceKey.scheduleSunLocation),
                  let value = try? JSONDecoder().decode(ScheduleLocation.self, from: data) else {
                return nil
            }
            return value
        }()

        let sunOffset: Int = {
            guard userDefaults.object(forKey: PersistenceKey.scheduleSunOffsetMinutes) != nil else {
                return 0
            }
            return userDefaults.integer(forKey: PersistenceKey.scheduleSunOffsetMinutes)
        }()

        return ShadeSchedule(
            isEnabled: isEnabled,
            startTime: startTime,
            endTime: endTime,
            source: source,
            sunLocation: sunLocation,
            sunOffsetMinutes: sunOffset
        )
    }

    private static func clockTime(
        forKey key: String,
        in userDefaults: UserDefaults,
        defaultValue: ShadeClockTime
    ) -> ShadeClockTime {
        guard let storedValue = userDefaults.object(forKey: key) as? String,
              let time = ShadeClockTime(storageString: storedValue) else {
            return defaultValue
        }

        return time
    }

    private static func sanitizedLabel(_ label: String) -> String? {
        let sanitizedValue = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizedValue.isEmpty ? nil : sanitizedValue
    }

    private static func sanitizedBundleIdentifier(_ bundleIdentifier: String) -> String? {
        let sanitizedValue = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizedValue.isEmpty ? nil : sanitizedValue
    }

    private static func sanitize(
        _ value: Double,
        defaultValue: Double,
        lower: Double,
        upper: Double
    ) -> Double {
        guard value.isFinite else {
            return defaultValue
        }

        return min(max(value, lower), upper)
    }
}
