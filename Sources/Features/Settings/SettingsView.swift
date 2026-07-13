import SwiftUI

/// The parent-facing Settings screen: TTS on/off, voice picker, quick presets, pitch/speed
/// sliders, Save, and credits. Reached only via the hidden square gesture on `MainView`.
/// Ported from the Android `SettingsScreen`.
struct SettingsView: View {
    let onDone: () -> Void
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("settings").uppercased())
                    .font(.system(size: 32))
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Text(L("speak_animal_name").uppercased())
                    Spacer()
                    Toggle("", isOn: $viewModel.ttsEnabled).labelsHidden()
                }

                // Voice tuning only matters when the intro is spoken.
                if viewModel.ttsEnabled {
                    voicePicker
                    presets
                    sliderRow(L("voice_pitch").uppercased(), value: $viewModel.voicePitch)
                    sliderRow(L("voice_speed").uppercased(), value: $viewModel.voiceSpeed)
                }

                Button {
                    viewModel.save()
                    onDone()
                } label: {
                    Text(L("save_btn").uppercased()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)

                credits
            }
            .padding(24)
            .frame(maxWidth: 480)            // cap width so tablets don't spread edge-to-edge
            .frame(maxWidth: .infinity)      // then center the capped column
        }
        .navigationBarTitleDisplayMode(.inline)   // keep the back button as a secondary exit
    }

    // MARK: - Voice picker (grouped by region, like the Android exposed dropdown)

    @ViewBuilder private var voicePicker: some View {
        if viewModel.voiceOptions.isEmpty {
            Text(L("voices").uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Menu {
                ForEach(voiceGroups, id: \.region) { group in
                    Section(group.region) {
                        ForEach(group.voices) { voice in
                            Button {
                                viewModel.selectedVoiceId = voice.id
                            } label: {
                                if voice.id == viewModel.selectedVoiceId {
                                    Label(voice.label, systemImage: "checkmark")
                                } else {
                                    Text(voice.label)
                                }
                            }
                        }
                    }
                }
            } label: {
                voiceField
            }
        }
    }

    private var voiceField: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("voices").uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectedVoiceLabel)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.4)))
        .contentShape(Rectangle())
    }

    private var voiceGroups: [(region: String, voices: [SettingsViewModel.VoiceOption])] {
        var order: [String] = []
        var byRegion: [String: [SettingsViewModel.VoiceOption]] = [:]
        for voice in viewModel.voiceOptions {
            if byRegion[voice.region] == nil { order.append(voice.region) }
            byRegion[voice.region, default: []].append(voice)
        }
        return order.map { ($0, byRegion[$0]!) }
    }

    private var selectedVoiceLabel: String {
        guard let selected = viewModel.voiceOptions.first(where: { $0.id == viewModel.selectedVoiceId })
        else { return "" }
        return "\(selected.region) — \(selected.label)"
    }

    // MARK: - Presets

    private var presets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("presets").uppercased())
            HStack(spacing: 8) {
                ForEach(SettingsViewModel.presets) { preset in
                    Button {
                        viewModel.applyPreset(preset)
                    } label: {
                        Text(L(String.LocalizationValue(preset.labelKey)).uppercased())
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Sliders

    private func sliderRow(_ label: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
            HStack {
                Slider(value: value, in: VoiceRange.closed)
                Text("\(Int(value.wrappedValue * 100))%")
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }

    // MARK: - Credits (verbatim from the Android SettingsScreen)

    private var credits: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                CircuitStitchLogo().frame(width: 56, height: 56)
                Text("Animal Spin\nby\nKyle Falconer\nCircuit Stitch\n2026")
                    .font(.system(size: 10))
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                GitHubLogo().frame(width: 56, height: 56)
            }
            .padding(.top, 24)

            Text("all sounds and images are public domain or CC BY-SA\n"
                 + "project source code is at\ngithub.com/Circuit-Stitch/AnimalSpin")
                .font(.system(size: 10))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }
}

/// Localized string for a catalog key (the animal/UI keys generated into Localizable.xcstrings).
private func L(_ key: String.LocalizationValue) -> String { String(localized: key) }
