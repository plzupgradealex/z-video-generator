import SwiftUI

/// Default settings for new jobs (⌘,). Each control binds straight to the
/// matching `AppModel.default*` value (persisted to UserDefaults). These seed
/// jobs created afterwards; existing jobs keep their own settings.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("New jobs start with") {
                Picker("Model", selection: $model.defaultModel) {
                    ForEach(model.models, id: \.self) { Text($0).tag($0) }
                }
                Picker("Aspect", selection: $model.defaultAspect) {
                    ForEach(model.aspectOptions) { Text($0.label).tag($0.value) }
                }
                Picker("Resolution", selection: $model.defaultSize) {
                    ForEach(model.sizes, id: \.self) { Text($0).tag($0) }
                }
                Picker("Duration", selection: $model.defaultDuration) {
                    ForEach(model.durations, id: \.self) { Text("\($0)s").tag($0) }
                }
                Picker("FPS", selection: $model.defaultFPS) {
                    ForEach(model.fpsOptions, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Quality", selection: $model.defaultQuality) {
                    ForEach(model.qualities, id: \.self) { Text($0.capitalized).tag($0) }
                }
                Picker("Motion", selection: $model.defaultMovement) {
                    ForEach(model.movements, id: \.self) { Text($0.capitalized).tag($0) }
                }
                Toggle("Include audio", isOn: $model.defaultAudio)
            }

            Section("Demo mode") {
                Toggle("Demo mode (no API key needed)", isOn: $model.isDemoMode)
                Text("When on, generation runs a short simulated flow with a sample video — no key, no credit spent. Turns off automatically when you add a Z.AI key.")
                    .font(.app(AppType.caption)).foregroundStyle(.secondary)
            }

            Section {
                Text("Existing jobs keep their own settings — these only apply to new ones.")
                    .font(.app(AppType.caption)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 540)
    }
}
