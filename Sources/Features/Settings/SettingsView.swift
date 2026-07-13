import SwiftUI

/// The parent-facing Settings screen: TTS on/off, voice picker, quick presets, pitch/speed
/// sliders, Save, and credits. Reached only via the hidden square gesture on `MainView`.
/// Ported from the Android `SettingsScreen`.
///
/// Built as a standard grouped `Form` of native controls (Toggle, navigation-link Picker, Sliders,
/// Buttons) so it's accessible by construction: VoiceOver reads each control's role/label/value,
/// Full Keyboard Access can focus and operate everything, and Dynamic Type scales the whole screen.
/// Contrast is WCAG-AA in light *and* dark — text uses system label colors and the accent is the
/// appearance-aware `Color.brandAccent` (replacing the old fixed purple that failed on dark).
struct SettingsView: View {
    let onDone: () -> Void
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $viewModel.ttsEnabled) {
                    Text(Cap(L("speak_animal_name")))
                }
            }

            // Voice tuning only matters when the intro is spoken.
            if viewModel.ttsEnabled {
                // Only show the voice row when there's an actual choice to make; with no installed
                // voices for the language the engine uses its default, so a dead row would just be
                // a confusing dead end (and read "unavailable" to VoiceOver).
                if !viewModel.voiceOptions.isEmpty {
                    Section {
                        voicePicker
                    }
                }

                Section {
                    sliderRow(L("voice_pitch"), value: $viewModel.voicePitch)
                    sliderRow(L("voice_speed"), value: $viewModel.voiceSpeed)
                    presetsRow
                }
            }

            Section {
                saveButton
            }
            .listRowBackground(Color.clear)   // full-width filled button, not a list card

            Section {
                credits
            }
            .listRowBackground(Color.clear)   // credits float below, like the Android footer
        }
        .navigationTitle(Cap(L("settings")))
        .navigationBarTitleDisplayMode(.large)   // prominent, readable title; back button = 2nd exit
    }

    // MARK: - Voice picker (grouped by region, like the Android exposed dropdown)
    //
    // A navigation-link Picker: tapping pushes a grouped checkmark list. VoiceOver announces
    // "Voices, <selected>, button"; Full Keyboard Access can focus and open it. Replaces the old
    // custom `Menu` whose hand-built label VoiceOver read as disconnected fragments. Only shown
    // when `voiceOptions` is non-empty (guarded by the caller).

    private var voicePicker: some View {
        Picker(selection: $viewModel.selectedVoiceId) {
            ForEach(voiceGroups, id: \.region) { group in
                Section(group.region) {
                    ForEach(group.voices) { voice in
                        Text(voice.label).tag(Optional(voice.id))
                    }
                }
            }
        } label: {
            Text(Cap(L("voices")))
        }
        .pickerStyle(.navigationLink)
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

    // MARK: - Presets

    private var presetsRow: some View {
        // Three across at normal sizes; stack vertically once the user is at an accessibility text
        // size, where a long localized label (e.g. German "chipmunk") can't fit in a third of the
        // width. In a 3-column row keep labels on one line (shrink to fit); when stacked full-width
        // allow 2 lines. Either way the label shrinks before it ever truncates — no content loss.
        let isAccessibility = dynamicTypeSize.isAccessibilitySize
        let layout = isAccessibility
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return VStack(alignment: .leading, spacing: 8) {
            Text(Cap(L("presets")))
            layout {
                ForEach(SettingsViewModel.presets) { preset in
                    Button {
                        viewModel.applyPreset(preset)
                    } label: {
                        Text(Cap(L(String.LocalizationValue(preset.labelKey))))
                            .frame(maxWidth: .infinity)
                            .lineLimit(isAccessibility ? 2 : 1)
                            .minimumScaleFactor(0.6)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)               // ≥44pt tap target
                }
            }
        }
    }

    // MARK: - Sliders
    //
    // The *native* Slider stays the accessibility element (so Full Keyboard Access and Switch
    // Control get real, arrow-key-adjustable behavior for free); we just relabel it and override
    // its announced value to the app's percentage. The visible label + percentage are hidden from
    // VoiceOver so the row reads once as "Voice pitch, 100%, adjustable".

    private func sliderRow(_ labelKey: String, value: Binding<Float>) -> some View {
        let label = Cap(labelKey)
        let percent = Int((value.wrappedValue * 100).rounded())
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(percent)%")
                    .foregroundStyle(Color.secondaryAA)
                    .monospacedDigit()
            }
            .accessibilityHidden(true)
            Slider(value: value, in: VoiceRange.closed)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text("\(percent)%"))
        }
    }

    // MARK: - Save
    //
    // A `.plain` button we fill ourselves so the label can be `onBrandAccent` (black on the light
    // dark-mode purple) — `.borderedProminent` hard-codes white, which would fail contrast there.

    private var saveButton: some View {
        Button {
            viewModel.save()
            onDone()
        } label: {
            Text(Cap(L("save_btn")))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Color.onBrandAccent)
                .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    // MARK: - Credits (verbatim from the Android SettingsScreen)

    private var credits: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                CircuitStitchLogo().frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                Text("Animal Spin\nby\nKyle Falconer\nCircuit Stitch\n2026")
                    .font(.footnote)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)   // never truncate the credit lines
                    .frame(maxWidth: .infinity)
                GitHubLogo().frame(width: 56, height: 56)
                    .accessibilityHidden(true)
            }
            .padding(.top, 24)

            Text("all sounds and images are public domain or CC BY-SA\n"
                 + "project source code is at\ngithub.com/Circuit-Stitch/AnimalSpin")
                .font(.footnote)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryAA)   // AA on the light grouped background too
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }
}

/// Localized string for a catalog key (the animal/UI keys generated into Localizable.xcstrings).
private func L(_ key: String.LocalizationValue) -> String { String(localized: key) }

/// Sentence-cases a localized label (uppercases the first character only). The catalog stores the
/// UI strings lowercase; the old screen shouted them in ALL-CAPS, which is measurably harder to
/// read — sentence case keeps them legible while staying faithful to the source words. A no-op for
/// scripts without letter case (Arabic, Japanese, …).
private func Cap(_ key: String.LocalizationValue) -> String { Cap(L(key)) }
private func Cap(_ string: String) -> String {
    guard let first = string.first else { return string }
    return first.uppercased() + string.dropFirst()
}
