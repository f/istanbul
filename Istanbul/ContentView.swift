import SwiftUI

private let warmOrange = Color(red: 0.93, green: 0.55, blue: 0.17)

private let soundIcons: [String: String] = [
    "cafe": "cup.and.saucer.fill",
    "ferry": "ferry.fill",
    "street": "figure.walk",
    "traffic": "car.fill",
    "market": "bag.fill",
    "spice": "leaf.fill",
    "bazaar": "storefront.fill",
    "shoreside": "water.waves",
    "quayside": "fish.fill",
    "skyline": "building.2.fill",
    "prayer": "moon.stars.fill",
    "mosque": "building.columns.fill",
    "church": "building.columns.fill",
    "university": "graduationcap.fill",
    "music": "music.note",
    "sidestreet": "road.lanes",
    "child": "figure.and.child.holdinghands",
]

private func iconForSound(_ sound: BBCSound) -> String {
    let lower = sound.description.lowercased()
    for (keyword, icon) in soundIcons {
        if lower.contains(keyword) { return icon }
    }
    return "waveform"
}

struct ContentView: View {
    @Environment(SoundManager.self) private var soundManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if let current = soundManager.currentSound {
                nowPlaying(current)
                Rectangle().fill(.quaternary).frame(height: 0.5)
            }

            if soundManager.isLoading {
                loadingView
            } else if soundManager.sounds.isEmpty {
                emptyView
            } else {
                soundList
            }

            Rectangle().fill(.quaternary).frame(height: 0.5)
            volumeBar
            Rectangle().fill(.quaternary).frame(height: 0.5)
            footer
        }
        .frame(width: 320)
        .task {
            if soundManager.sounds.isEmpty {
                await soundManager.fetchSounds()
            }
        }
    }

    // MARK: - Now Playing

    private func nowPlaying(_ sound: BBCSound) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(warmOrange.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconForSound(sound))
                    .font(.system(size: 14))
                    .foregroundStyle(warmOrange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(sound.shortTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    SoundWaveView()
                        .frame(width: 16, height: 10)
                    Text("Playing · \(sound.formattedDuration)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(duration: 0.25)) {
                    soundManager.stop()
                }
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(warmOrange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(warmOrange.opacity(0.04))
    }

    // MARK: - Sound List

    private var soundList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(soundManager.sounds) { sound in
                    SoundRow(sound: sound)
                        .environment(soundManager)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .frame(maxHeight: 360)
    }

    // MARK: - Volume

    private var volumeBar: some View {
        @Bindable var sm = soundManager
        return HStack(spacing: 8) {
            Image(systemName: sm.volume == 0 ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 4)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [warmOrange.opacity(0.5), warmOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(sm.volume), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let pct = Float(min(max(value.location.x / geo.size.width, 0), 1))
                            sm.setVolume(pct)
                        }
                )
            }
            .frame(height: 20)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(0.7)
            Text("Fetching sounds from Istanbul...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(height: 180)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text(soundManager.errorMessage ?? "No sounds available")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await soundManager.fetchSounds() }
            } label: {
                Text("Try Again")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.quaternary))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 180)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: "about")
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "info.circle").font(.system(size: 9))
                    Text("About").font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Sound Row

struct SoundRow: View {
    let sound: BBCSound
    @Environment(SoundManager.self) private var soundManager
    @State private var isHovering = false

    private var isCurrent: Bool {
        soundManager.currentSound?.id == sound.id
    }

    private var isDownloading: Bool {
        soundManager.downloading == sound.id
    }

    var body: some View {
        Button {
            Task { await soundManager.toggleSound(sound) }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isCurrent ? warmOrange.opacity(0.15) : Color.primary.opacity(isHovering ? 0.06 : 0.03))
                        .frame(width: 30, height: 30)

                    if isDownloading {
                        ProgressView().scaleEffect(0.4)
                    } else {
                        Image(systemName: iconForSound(sound))
                            .font(.system(size: 12))
                            .foregroundStyle(isCurrent ? warmOrange : .secondary)
                    }
                }

                Text(sound.shortTitle)
                    .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                    .lineLimit(1)

                Spacer()

                Text(sound.formattedDuration)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                if isCurrent {
                    SoundWaveView()
                        .frame(width: 16, height: 10)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCurrent ? warmOrange.opacity(0.06) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    Image("TrayIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .opacity(0.8)

                    Spacer().frame(height: 10)

                    Text("Istanbul")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Text("Ambient Soundscapes")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)

                    Text("Version 1.0")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.quaternary))
                        .padding(.top, 6)

                    Spacer().frame(height: 16)
                    Rectangle().fill(.quaternary).frame(height: 0.5).padding(.horizontal, 20)
                    Spacer().frame(height: 16)

                    VStack(alignment: .leading, spacing: 14) {
                        aboutSection(
                            icon: "waveform",
                            title: "Sound Source",
                            text: "All ambient sounds are sourced from the BBC Rewind Sound Effects library, recorded on location in Istanbul, Turkey.",
                            credit: "bbc.co.uk – © copyright 2026 BBC",
                            link: ("Browse BBC Sound Effects", URL(string: "https://sound-effects.bbcrewind.co.uk")!)
                        )

                        aboutSection(
                            icon: "lock.open",
                            title: "Open Source",
                            text: "Istanbul is free and open source software. Contributions, issues, and feedback are welcome on GitHub.",
                            credit: nil,
                            link: ("View on GitHub", URL(string: "https://github.com/f/istanbul")!)
                        )

                        aboutSection(
                            icon: "doc.text",
                            title: "License",
                            text: "BBC sound effects are provided under the RemArc licence for personal, educational, and research use. This app is non-commercial and ad-free.",
                            credit: nil,
                            link: ("Read RemArc Licence", URL(string: "https://sound-effects.bbcrewind.co.uk/licensing")!)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }

            Rectangle().fill(.quaternary).frame(height: 0.5)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 360, height: 400)
    }

    private func aboutSection(icon: String, title: String, text: String, credit: String?, link: (String, URL)) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(warmOrange)
                .frame(width: 18, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))

                Text(text)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let credit {
                    Text(credit)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }

                Link(destination: link.1) {
                    HStack(spacing: 3) {
                        Text(link.0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 7))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(warmOrange)
                }
            }
        }
    }
}

// MARK: - Sound Wave Animation

struct SoundWaveView: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(warmOrange)
                    .frame(width: 2)
                    .scaleEffect(
                        y: phase ? [0.4, 1.0, 0.6, 0.85][i] : [0.85, 0.4, 1.0, 0.5][i],
                        anchor: .center
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase.toggle()
            }
        }
    }
}
