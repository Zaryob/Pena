import SwiftUI

public struct TunerMainView: View {
    @State private var viewModel = TunerViewModel()
    @State private var showSimulatorBar: Bool = false // Default to false on real device, can be toggled
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Background
            Color(red: 0.07, green: 0.07, blue: 0.09)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation & Header
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                // Mic Permission Warning Banner (if needed)
                if !viewModel.audioManager.hasMicrophonePermission {
                    micPermissionBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if !viewModel.audioManager.isRunning {
                    micInactiveBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                
                // Content Scrollable
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Gauge Meter
                        GaugeMeterView(
                            cents: viewModel.centsDifference,
                            status: viewModel.tuningStatus,
                            noteLetter: viewModel.displayNoteName,
                            octave: viewModel.displayOctave,
                            detectedHz: viewModel.detectedFrequency,
                            targetHz: viewModel.targetFrequency,
                            stringName: viewModel.activeString.turkishName,
                            amplitude: viewModel.audioManager.currentAmplitude,
                            isPluckDetected: viewModel.audioManager.isPluckDetected
                        )
                        .padding(.top, 4)
                        
                        // Classical Guitar Headstock
                        HeadstockView(
                            preset: viewModel.currentPreset,
                            activeString: viewModel.activeString,
                            status: viewModel.tuningStatus,
                            isPlayingTone: viewModel.isPlayingReferenceTone,
                            onSelectString: { string in
                                viewModel.selectString(string)
                            },
                            onPlayTone: { string in
                                viewModel.playReferenceTone(for: string)
                            }
                        )
                        
                        // Simulator Quick Test Bar
                        if showSimulatorBar {
                            SimulatorTestBar(viewModel: viewModel)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 90)
                }
            }
            
            // Bottom Action Bar
            VStack {
                Spacer()
                bottomActionBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsSheetView(viewModel: viewModel)
        }
        .onChange(of: viewModel.isInTune) { _, isInTune in
            if isInTune {
                viewModel.triggerHapticIfInTune()
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
    
    // MARK: - Top Header Bar
    private var topBar: some View {
        HStack(spacing: 12) {
            // Preset Dropdown Menu
            Menu {
                ForEach(TuningPreset.allPresets) { preset in
                    Button {
                        viewModel.currentPreset = preset
                    } label: {
                        HStack {
                            Text(preset.name)
                            if viewModel.currentPreset.id == preset.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                    
                    Text(viewModel.currentPreset.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(white: 0.14))
                )
            }
            
            Spacer()
            
            // Auto / Manual Mode Switcher
            Picker("Mod", selection: $viewModel.tuningMode) {
                ForEach(TuningMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            
            // Settings Button
            Button {
                viewModel.isSettingsPresented = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(white: 0.14)))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Mic Permission Banner
    private var micPermissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.15))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Mikrofon İzni Gerekli")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text("Gitar telinin sesini algılamak için mikrofona izin verin.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("İzin Ver") {
                viewModel.audioManager.requestMicrophonePermission { granted in
                    if granted {
                        viewModel.audioManager.start()
                    }
                }
            }
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(red: 0.85, green: 0.72, blue: 0.35)))
            .foregroundStyle(.black)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.2, green: 0.12, blue: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.95, green: 0.45, blue: 0.15).opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Mic Inactive Banner
    private var micInactiveBanner: some View {
        Button {
            viewModel.audioManager.start()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                Text("Mikrofon duraklatıldı. Dinlemeyi başlatmak için dokunun.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.14))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Floating Action Bar
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            // Play Reference Tone Button ("Dinle")
            Button {
                viewModel.playReferenceTone()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isPlayingReferenceTone ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Dinle (\(viewModel.activeString.noteLetter)\(viewModel.activeString.octave))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.85, green: 0.72, blue: 0.35),
                                    Color(red: 0.70, green: 0.55, blue: 0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .foregroundStyle(.black)
                .shadow(color: Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.3), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            
            // Microphone Active / Pause Button
            Button {
                viewModel.toggleListening()
            } label: {
                Image(systemName: viewModel.audioManager.isRunning ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(viewModel.audioManager.isRunning ? Color(red: 0.15, green: 0.85, blue: 0.40) : Color.secondary)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        viewModel.audioManager.isRunning ? Color(red: 0.15, green: 0.85, blue: 0.40).opacity(0.3) : Color(white: 0.2),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .buttonStyle(.plain)
            
            // Simulator Test Bar Toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSimulatorBar.toggle()
                }
            } label: {
                Image(systemName: showSimulatorBar ? "guitars.fill" : "guitars")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(showSimulatorBar ? Color(red: 0.85, green: 0.72, blue: 0.35) : Color.secondary)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        showSimulatorBar ? Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.4) : Color(white: 0.2),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(white: 0.10).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(white: 0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 15, y: 5)
        )
    }
}
