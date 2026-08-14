import SwiftUI
import AVFoundation

struct MicRecorderSheet: View {
    let onRecordingFinished: (String, URL) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var soundTitle: String = ""
    @State private var isRecording: Bool = false
    @State private var isRecorded: Bool = false
    @State private var recordingTimer: Int = 0
    @State private var timer: Timer? = nil

    @State private var audioRecorder: AVAudioRecorder? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var audioPlayerDelegate: MicRecorderAudioDelegate? = nil
    @State private var recordedFileURL: URL? = nil
    @State private var isPlayingPreview: Bool = false

    var formattedTime: String {
        let mins = recordingTimer / 60
        let secs = recordingTimer % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        ZStack {
            DriveColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top Bar ─────────────────────────────────────────────
                HStack {
                    Button("Cancel") {
                        cancelRecordingAndReleaseSession()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DriveColors.mutedFg)

                    Spacer()

                    Text("Record Custom Voice")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DriveColors.foreground)
                        .lineLimit(1)

                    Spacer()

                    Button(action: saveRecording) {
                        Text("Save")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isRecorded ? DriveColors.primary : DriveColors.mutedFg.opacity(0.5))
                    }
                    .disabled(!isRecorded)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)
                // **Audio-session lifecycle.** A `.playAndRecord`
                // session that survives the sheet leaves the mic
                // channel hot. Cancel returns it to idle so other
                // apps (Music, Maps navigation) can resume using
                // audio immediately.
                .onAppear { /* see body.onDisappear */ }
                .onDisappear {
                    cancelRecordingAndReleaseSession()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // ── Title Input Field ───────────────────────────────────
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SOUND NAME")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(DriveColors.mutedFg)

                            TextField("e.g. My Vehicle Welcome", text: $soundTitle)
                                .font(.system(size: 15))
                                .foregroundColor(DriveColors.foreground)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(DriveColors.carbon)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.border, lineWidth: 1))
                        }
                        .padding(.horizontal, 20)

                        // ── Microphone Waveform & Timer Display ────────────────
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(isRecording ? Color.red.opacity(0.15) : DriveColors.primary.opacity(0.12))
                                    .frame(width: 115, height: 115)
                                    .scaleEffect(isRecording ? 1.1 : 1.0)
                                    .animation(isRecording ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isRecording)

                                Circle()
                                    .stroke(isRecording ? Color.red.opacity(0.6) : DriveColors.primary.opacity(0.4), lineWidth: 2)
                                    .frame(width: 115, height: 115)

                                Image(systemName: isRecording ? "mic.fill" : "mic")
                                    .font(.system(size: 42))
                                    .foregroundColor(isRecording ? Color.red : DriveColors.primary)
                            }
                            .onTapGesture {
                                if !isRecording {
                                    startRecording()
                                }
                            }

                            Text(isRecording ? "Recording Voice..." : (isRecorded ? "Recording Complete (\(formattedTime))" : "Tap Mic to Start Recording"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isRecording ? Color.red : DriveColors.foreground)

                            Text(formattedTime)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(DriveColors.foreground)
                        }
                        .padding(.vertical, 4)

                        // ── Recording Controls ──────────────────────────────────
                        VStack(spacing: 10) {
                            if !isRecording {
                                Button(action: startRecording) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red)
                                        Text(isRecorded ? "Record Again" : "Start Recording")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red.opacity(0.85))
                                    .cornerRadius(16)
                                }
                            } else {
                                Button(action: stopRecording) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "square.fill")
                                            .font(.system(size: 14))
                                        Text("Stop Recording")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(DriveColors.primary)
                                    .cornerRadius(16)
                                }
                            }

                            if isRecorded && !isRecording {
                                Button(action: togglePlayPreview) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isPlayingPreview ? "pause.fill" : "play.fill")
                                        Text(isPlayingPreview ? "Pause Preview" : "Play Recording Preview")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(DriveColors.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(DriveColors.primary.opacity(0.12))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.primary.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            cancelRecordingAndReleaseSession()
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        let recordBlock = {
            DispatchQueue.main.async {
                do {
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                    try session.setActive(true)

                    let fm = FileManager.default
                    guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        print("MicRecorderSheet: documents directory unavailable; cannot record")
                        return
                    }

                    let title = self.soundTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let safeTitle = title.isEmpty ? "Voice_Recording_\(Int(Date().timeIntervalSince1970))" : title.replacingOccurrences(of: " ", with: "_")
                    let filename = "\(safeTitle).wav"
                    let url = docs.appendingPathComponent(filename)

                    if fm.fileExists(atPath: url.path) {
                        try? fm.removeItem(at: url)
                    }
                    self.recordedFileURL = url

                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatLinearPCM),
                        AVSampleRateKey: 22050.0,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsFloatKey: false
                    ]

                    self.audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                    self.audioRecorder?.isMeteringEnabled = true
                    self.audioRecorder?.prepareToRecord()
                    self.audioRecorder?.record()

                    self.isRecording = true
                    self.isRecorded = false
                    self.recordingTimer = 0
                    self.timer?.invalidate()
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        self.recordingTimer += 1
                    }
                } catch {
                    print("Could not start recording: \(error)")
                }
            }
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if granted { recordBlock() }
            }
        } else {
            session.requestRecordPermission { granted in
                if granted { recordBlock() }
            }
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil

        if isRecording {
            audioRecorder?.stop()
            audioRecorder = nil
            isRecording = false
            isRecorded = true

            // **AVAudioSession lifecycle.** After recording finishes we
            // return the session to `.playback` so other apps (Music,
            // Maps navigation, CarPlay audio) can resume without the
            // mic channel holding the audio route. We don't deactivate
            // entirely because `togglePlayPreview` will immediately
            // reuse the session.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .mixWithOthers])
        }
    }

    /// Release the `.playAndRecord` session and stop any preview
    /// playback. Called from Cancel, Save, and `onDisappear` so the
    /// mic channel is never left hot when the sheet goes away.
    private func cancelRecordingAndReleaseSession() {
        // Stop any in-flight recording first; the recorder holds the
        // `.playAndRecord` session active.
        timer?.invalidate()
        timer = nil
        if isRecording {
            audioRecorder?.stop()
            audioRecorder = nil
            isRecording = false
        }
        // Stop and release the preview player too. If the preview
        // were still playing when we deactivate the session, the
        // route would flip mid-playback and the user would hear
        // a click.
        stopPreviewPlayback(deactivateSession: true)
    }

    /// Stop the in-app preview player and (optionally) deactivate
    /// the shared audio session. `deactivateSession: true` is the
    /// right call from Cancel / Save / sheet dismissal where we
    /// want to leave the system in an idle state; `false` keeps the
    /// session live for an immediate re-play (used internally).
    private func stopPreviewPlayback(deactivateSession: Bool) {
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        audioPlayerDelegate?.invalidate()
        audioPlayerDelegate = nil
        isPlayingPreview = false
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false,
                options: [.notifyOthersOnDeactivation])
        }
    }

    private func togglePlayPreview() {
        guard let url = recordedFileURL else { return }
        if isPlayingPreview {
            // Pausing: stop the player but keep the session live so
            // the user can hit Play again immediately.
            stopPreviewPlayback(deactivateSession: false)
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try? session.setActive(true)

            let delegate = MicRecorderAudioDelegate { [self] in
                self.stopPreviewPlayback(deactivateSession: true)
            }
            audioPlayerDelegate = delegate
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.delegate = delegate
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            isPlayingPreview = true

            // Safety net in case the delegate never fires (e.g. the
            // file is shorter than `audioPlayer.duration` reported
            // because of a corrupt header).
            let safetyDuration = player.duration > 0 ? player.duration : 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + safetyDuration + 0.5) {
                if self.isPlayingPreview, self.audioPlayer === player {
                    self.stopPreviewPlayback(deactivateSession: true)
                }
            }
        } catch {
            print("Could not play recording preview: \(error)")
        }
    }

    private func saveRecording() {
        stopRecording()
        guard let oldURL = recordedFileURL else { return }

        let fm = FileManager.default
        let rawTitle = soundTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = rawTitle.isEmpty ? "Voice Recording" : rawTitle
        let cleanName = displayTitle.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
        let finalFilename = "\(cleanName).wav"

        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("MicRecorderSheet: documents directory unavailable; cannot save recording")
            return
        }
        let finalDocsURL = docs.appendingPathComponent(finalFilename)

        if oldURL.path != finalDocsURL.path {
            try? fm.removeItem(at: finalDocsURL)
            try? fm.moveItem(at: oldURL, to: finalDocsURL)
        }

        // Copy to App Group Shared Container for background triggers
        if let sharedDir = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.drivestudio.shared") {
            let sharedURL = sharedDir.appendingPathComponent(finalFilename)
            try? fm.removeItem(at: sharedURL)
            try? fm.copyItem(at: finalDocsURL, to: sharedURL)
        }

        // **AVAudioSession lifecycle.** Release the mic channel so the
        // OS can hand the route to other apps and so a future
        // `setCategory(.playback)` call doesn't have to fight an
        // already-active `.playAndRecord` session.
        stopPreviewPlayback(deactivateSession: true)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        onRecordingFinished(displayTitle, finalDocsURL)
        dismiss()
    }
}

// MARK: - MicRecorderAudioDelegate
//
// `AVAudioPlayer` does NOT retain its delegate; without this proxy
// the finish callback would never reach the view and the session
// would stay active until the view itself is destroyed. We hold an
// unowned capture of the SwiftUI view (which is a struct with
// predictable lifetime — only valid while the sheet is on screen)
// and forward the finish notification to a closure so the view
// can release the audio session.
private final class MicRecorderAudioDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    private var invalidated = false

    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

    func invalidate() {
        invalidated = true
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard !invalidated else { return }
        onFinish()
    }
}
