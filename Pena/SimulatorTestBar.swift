import SwiftUI

public struct SimulatorTestBar: View {
    @Bindable public var viewModel: TunerViewModel
    @State private var simulatedOffsetCents: Double = 0.0
    
    public init(viewModel: TunerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Simülatör / Tel Test Paneli", systemImage: "guitars.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                
                Spacer()
                
                // Offset preview
                Text(String(format: "%+.0f cent", simulatedOffsetCents))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(simulatedOffsetCents == 0 ? Color(red: 0.15, green: 0.85, blue: 0.40) : (simulatedOffsetCents < 0 ? Color(red: 0.95, green: 0.5, blue: 0.15) : Color(red: 0.35, green: 0.65, blue: 0.95)))
            }
            
            // Offset Quick Buttons
            HStack(spacing: 8) {
                offsetButton(title: "Pes (-18¢)", offset: -18.0)
                offsetButton(title: "Hafif Pes (-6¢)", offset: -6.0)
                offsetButton(title: "Tam (0¢)", offset: 0.0)
                offsetButton(title: "Hafif Tiz (+6¢)", offset: 6.0)
                offsetButton(title: "Tiz (+18¢)", offset: 18.0)
            }
            
            // 6 Strings Quick Pluck Trigger Row
            HStack(spacing: 6) {
                // Reverse so 6th string (kalın) is on left, 1st (ince) on right
                ForEach(viewModel.currentPreset.strings.reversed()) { string in
                    Button {
                        viewModel.simulatePluck(for: string, offsetCents: simulatedOffsetCents)
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(string.id)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(string.noteLetter)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(viewModel.activeString.id == string.id ? .black : .white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.activeString.id == string.id ? Color(red: 0.85, green: 0.72, blue: 0.35) : Color(white: 0.16))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
    
    private func offsetButton(title: String, offset: Double) -> some View {
        Button {
            simulatedOffsetCents = offset
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(simulatedOffsetCents == offset ? Color.white.opacity(0.25) : Color(white: 0.14))
                )
                .foregroundStyle(simulatedOffsetCents == offset ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
