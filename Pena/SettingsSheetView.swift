import SwiftUI

public struct SettingsSheetView: View {
    @Bindable public var viewModel: TunerViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(viewModel: TunerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Preset Selection
                Section {
                    Picker("Akort Düzeni", selection: $viewModel.currentPreset) {
                        ForEach(TuningPreset.allPresets) { preset in
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .tag(preset)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Text(viewModel.currentPreset.turkishDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Akort Düzeni (Preset)", systemImage: "music.note.list")
                }
                
                // Calibration A4
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Referans A4:")
                                .font(.body)
                            Spacer()
                            Text(String(format: "%.1f Hz", viewModel.a4Frequency))
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                        }
                        
                        Slider(value: $viewModel.a4Frequency, in: 432.0...448.0, step: 0.5)
                            .tint(Color(red: 0.85, green: 0.72, blue: 0.35))
                        
                        HStack(spacing: 8) {
                            quickA4Button(432.0, title: "432 Hz (Verdi)")
                            quickA4Button(440.0, title: "440 Hz (Standart)")
                            quickA4Button(442.0, title: "442 Hz (Klasik)")
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("A4 Kalibrasyonu", systemImage: "tuningfork")
                }
                
                // Notation Style
                Section {
                    Picker("Nota Gösterimi", selection: $viewModel.notationStyle) {
                        ForEach(NotationStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Nota Gösterimi", systemImage: "textformat")
                }
                
                // Sensitivity & Noise Gate
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Gürültü Filtresi Eşiği:")
                                .font(.body)
                            Spacer()
                            Text(String(format: "%.3f", viewModel.noiseGateThreshold))
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $viewModel.noiseGateThreshold, in: 0.005...0.040, step: 0.002)
                    }
                    .padding(.vertical, 4)
                    
                    Picker("Hassasiyet (Tolerans)", selection: $viewModel.inTuneTolerance) {
                        Text("±2 cent (Çok Hassas)").tag(2.0)
                        Text("±3 cent (Standart)").tag(3.0)
                        Text("±5 cent (Gevşek)").tag(5.0)
                    }
                } header: {
                    Label("Mikrofon ve Hassasiyet", systemImage: "mic.fill")
                }
                
                // Classical Guitar Tuning Tips
                Section {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 10) {
                            tipRow(number: "1", title: "Aşağıdan Yukarı Akort Edin", text: "Telin tonunu her zaman pes (gevşek) taraftan sıkarak hedef sese getirin. Böylece kulakçık mekanizması boşluk yapmaz.")
                            tipRow(number: "2", title: "Naylon Teller Esner", text: "Klasik gitar naylon telleri sıcaklık ve neme duyarlıdır. Yeni takılan telleri hafifçe esnetip tekrar akort edin.")
                            tipRow(number: "3", title: "Sessiz Ortam", text: "Gitarın gövdesine yakın tutarak ve sessiz bir ortamda akort yapmak en net frekans algısını sağlar.")
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label("Klasik Gitar Akort İpuçları", systemImage: "lightbulb.fill")
                            .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tamam") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func quickA4Button(_ freq: Double, title: String) -> some View {
        Button {
            viewModel.a4Frequency = freq
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
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
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color(red: 0.85, green: 0.72, blue: 0.35)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
