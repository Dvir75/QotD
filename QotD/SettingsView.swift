import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var selectedPreset: PresetOption = .day
    @State private var customAmount: Int = 30
    @State private var customUnit: CustomUnit = .minutes
    @State private var useCustom = false

    var body: some View {
        Form {
            Section("Rotation") {
                Picker("Mode", selection: rotationModeBinding) {
                    ForEach(RotationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Change Interval") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Interval")
                        Spacer()
                        Picker("Interval", selection: presetBinding) {
                            ForEach(PresetOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    if useCustom || selectedPreset == .custom {
                        HStack(spacing: 8) {
                            Spacer(minLength: 0)
                            TextField(
                                "",
                                text: Binding(
                                    get: { customAmount > 0 ? String(customAmount) : "" },
                                    set: { newValue in
                                        let digits = newValue.filter(\.isNumber)
                                        customAmount = Int(digits) ?? 0
                                    }
                                ),
                                prompt: Text("30")
                            )
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 64)
                            .multilineTextAlignment(.trailing)

                            Picker("Unit", selection: $customUnit) {
                                ForEach(CustomUnit.allCases) { unit in
                                    Text(unit.title).tag(unit)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 110)

                            Button("Apply") {
                                applyCustomInterval()
                            }
                            .disabled(customAmount <= 0)
                        }
                    }
                }
            }

            Section("New Quote Paste") {
                Toggle("Cleanup", isOn: pasteCleanupBinding)
                Toggle("Auto-capitalize", isOn: pasteAutoCapitalizeBinding)
            }

            Section("Updates") {
                Button("Check for Updates…") {
                    UpdateController.shared.checkForUpdates()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear {
            syncFromModel()
        }
    }

    private var rotationModeBinding: Binding<RotationMode> {
        Binding(
            get: { model.store.settings.rotationMode },
            set: { model.setRotationMode($0) }
        )
    }

    private var pasteCleanupBinding: Binding<Bool> {
        Binding(
            get: { model.store.settings.pasteCleanupEnabled },
            set: { model.setPasteCleanupEnabled($0) }
        )
    }

    private var pasteAutoCapitalizeBinding: Binding<Bool> {
        Binding(
            get: { model.store.settings.pasteAutoCapitalizeEnabled },
            set: { model.setPasteAutoCapitalizeEnabled($0) }
        )
    }

    private var presetBinding: Binding<PresetOption> {
        Binding(
            get: { selectedPreset },
            set: { option in
                selectedPreset = option
                useCustom = (option == .custom)
                if option != .custom, let seconds = option.seconds {
                    model.setIntervalSeconds(seconds)
                }
            }
        )
    }

    private func syncFromModel() {
        let seconds = model.store.settings.intervalSeconds
        if let match = PresetOption.allCases.first(where: { $0.seconds == seconds }) {
            selectedPreset = match
            useCustom = false
        } else {
            selectedPreset = .custom
            useCustom = true
            if seconds.truncatingRemainder(dividingBy: 3600) == 0, seconds >= 3600 {
                customUnit = .hours
                customAmount = Int(seconds / 3600)
            } else if seconds.truncatingRemainder(dividingBy: 60) == 0, seconds >= 60 {
                customUnit = .minutes
                customAmount = Int(seconds / 60)
            } else {
                customUnit = .seconds
                customAmount = max(1, Int(seconds.rounded()))
            }
        }
    }

    private func applyCustomInterval() {
        let seconds: TimeInterval
        switch customUnit {
        case .seconds:
            seconds = TimeInterval(customAmount)
        case .minutes:
            seconds = TimeInterval(customAmount * 60)
        case .hours:
            seconds = TimeInterval(customAmount * 3600)
        }
        guard seconds > 0 else { return }
        selectedPreset = .custom
        useCustom = true
        model.setIntervalSeconds(seconds)
    }
}

private enum PresetOption: String, CaseIterable, Identifiable {
    case fiveSecondsDebug
    case fifteenMinutes
    case hour
    case sixHours
    case day
    case week
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveSecondsDebug: "5 seconds (debug)"
        case .fifteenMinutes: "15 minutes"
        case .hour: "1 hour"
        case .sixHours: "6 hours"
        case .day: "1 day"
        case .week: "1 week"
        case .custom: "Custom…"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .fiveSecondsDebug: 5
        case .fifteenMinutes: 15 * 60
        case .hour: 60 * 60
        case .sixHours: 6 * 60 * 60
        case .day: 86_400
        case .week: 7 * 86_400
        case .custom: nil
        }
    }
}

private enum CustomUnit: String, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seconds: "seconds"
        case .minutes: "minutes"
        case .hours: "hours"
        }
    }
}
