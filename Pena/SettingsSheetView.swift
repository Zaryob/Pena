import SwiftUI

public struct SettingsSheetView: View {
    @Bindable public var viewModel: TunerViewModel
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .caption) private var tipBadgeSize: CGFloat = 22

    public init(viewModel: TunerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Preset Selection
                Section {
                    Picker(String(localized: "settings.preset.picker", defaultValue: "Akort Düzeni"), selection: $viewModel.currentPreset) {
                        ForEach(TuningPreset.allPresets) { preset in
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .tag(preset)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Text(viewModel.currentPreset.presetDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Label(String(localized: "settings.preset.header", defaultValue: "Akort Düzeni (Preset)"), systemImage: "music.note.list")
                }

                // Calibration A4
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(String(localized: "settings.a4.label", defaultValue: "Referans A4:"))
                                .font(.body)
                            Spacer()
                            Text("\(viewModel.a4Frequency, format: .number.precision(.fractionLength(1))) Hz")
                                .font(.body.bold().monospaced())
                                .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                        }

                        Slider(value: $viewModel.a4Frequency, in: 415.0...466.0, step: 0.5)
                            .tint(Color(red: 0.85, green: 0.72, blue: 0.35))
                            .accessibilityValue(
                                Text("\(viewModel.a4Frequency, format: .number.precision(.fractionLength(1))) Hz")
                            )

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                quickA4Buttons
                            }
                            VStack(spacing: 8) {
                                quickA4Buttons
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label(String(localized: "settings.a4.header", defaultValue: "A4 Kalibrasyonu"), systemImage: "tuningfork")
                }

                // Notation Style
                Section {
                    Picker(String(localized: "settings.notation.picker", defaultValue: "Nota Gösterimi"), selection: $viewModel.notationStyle) {
                        ForEach(NotationStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label(String(localized: "settings.notation.header", defaultValue: "Nota Gösterimi"), systemImage: "textformat")
                }

                // Sensitivity & Tolerance
                Section {
                    Picker(String(localized: "settings.sensitivity.picker", defaultValue: "Ortam Gürültüsü"), selection: $viewModel.sensitivity) {
                        ForEach(ListeningSensitivity.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(String(localized: "settings.tolerance.picker", defaultValue: "Hassasiyet (Tolerans)"), selection: $viewModel.inTuneTolerance) {
                        Text(String(localized: "settings.tolerance.tight", defaultValue: "±2 cent (Çok Hassas)")).tag(2.0)
                        Text(String(localized: "settings.tolerance.standard", defaultValue: "±3 cent (Standart)")).tag(3.0)
                        Text(String(localized: "settings.tolerance.loose", defaultValue: "±5 cent (Gevşek)")).tag(5.0)
                    }
                } header: {
                    Label(String(localized: "settings.mic.header", defaultValue: "Mikrofon ve Hassasiyet"), systemImage: "mic.fill")
                } footer: {
                    Text(String(localized: "settings.sensitivity.footer", defaultValue: "Gürültülü bir mekandaysanız 'Gürültülü Ortam' seçeneği, gitarınızın sessiz sesli ortam sesleriyle karışmasını önler."))
                }

                // Classical Guitar Tuning Tips
                Section {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 10) {
                            tipRow(
                                number: "1",
                                title: String(localized: "settings.tip1.title", defaultValue: "Aşağıdan Yukarı Akort Edin"),
                                text: String(localized: "settings.tip1.text", defaultValue: "Telin tonunu her zaman pes (gevşek) taraftan sıkarak hedef sese getirin. Böylece kulakçık mekanizması boşluk yapmaz.")
                            )
                            tipRow(
                                number: "2",
                                title: String(localized: "settings.tip2.title", defaultValue: "Naylon Teller Esner"),
                                text: String(localized: "settings.tip2.text", defaultValue: "Klasik gitar naylon telleri sıcaklık ve neme duyarlıdır. Yeni takılan telleri hafifçe esnetip tekrar akort edin.")
                            )
                            tipRow(
                                number: "3",
                                title: String(localized: "settings.tip3.title", defaultValue: "Sessiz Ortam"),
                                text: String(localized: "settings.tip3.text", defaultValue: "Gitarın gövdesine yakın tutarak ve sessiz bir ortamda akort yapmak en net frekans algısını sağlar.")
                            )
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label(String(localized: "settings.tips.header", defaultValue: "Klasik Gitar Akort İpuçları"), systemImage: "lightbulb.fill")
                            .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                    }
                }
            }
            .navigationTitle(String(localized: "settings.title", defaultValue: "Ayarlar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Tamam")) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    @ViewBuilder
    private var quickA4Buttons: some View {
        quickA4Button(415.0, title: String(localized: "settings.a4.baroque", defaultValue: "415 Hz (Barok)"))
        quickA4Button(440.0, title: String(localized: "settings.a4.standard", defaultValue: "440 Hz (Standart)"))
        quickA4Button(442.0, title: String(localized: "settings.a4.classical", defaultValue: "442 Hz (Klasik)"))
        quickA4Button(446.0, title: String(localized: "settings.a4.orchestral", defaultValue: "446 Hz (Orkestra)"))
    }

    private func quickA4Button(_ freq: Double, title: String) -> some View {
        Button {
            viewModel.a4Frequency = freq
        } label: {
            Text(title)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(viewModel.a4Frequency == freq ? Color(red: 0.85, green: 0.72, blue: 0.35) : Color(white: 0.2))
                )
                .foregroundStyle(viewModel.a4Frequency == freq ? .black : .white)
        }
        .buttonStyle(.plain)
    }

    private func tipRow(number: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.black)
                .frame(width: tipBadgeSize, height: tipBadgeSize)
                .background(Circle().fill(Color(red: 0.85, green: 0.72, blue: 0.35)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
