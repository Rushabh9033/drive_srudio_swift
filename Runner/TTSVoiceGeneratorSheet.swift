import SwiftUI
import AVFoundation

struct TTSVoiceGeneratorSheet: View {
    let onVoiceGenerated: (String, URL) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var voiceText: String = ""
    @State private var voiceTitle: String = ""
    @State private var isGenerating: Bool = false
    @State private var previewPlayer: AVSpeechSynthesizer? = nil
    @State private var speechSynthesizer: AVSpeechSynthesizer? = nil
    @State private var activeAudioFile: AVAudioFile? = nil

    private let samplePhrases = [
        "Welcome back Commander. Systems online.",
        "Tesla Model 3 Initialized. Ready for launch.",
        "Drive Mode Engaged. All systems nominal.",
        "Vehicle Secured. Have a great day!"
    ]

    var body: some View {
        ZStack {
            DriveColors.background.ignoresSafeArea()

            VStack(spacing: 20) {
                // ── Top Bar ─────────────────────────────────────────────
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DriveColors.mutedFg)

                    Spacer()

                    Text("Text-to-Speech Studio")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DriveColors.foreground)
                        .lineLimit(1)

                    Spacer()

                    Button(action: generateAndSave) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(voiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? DriveColors.mutedFg.opacity(0.5) : DriveColors.primary)
                        }
                    }
                    .disabled(voiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)

                // ── Input Fields ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SOUND NAME")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(DriveColors.mutedFg)

                        TextField("e.g. Welcome Phrase", text: $voiceTitle)
                            .font(.system(size: 14))
                            .foregroundColor(DriveColors.foreground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(DriveColors.carbon)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.border, lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("SPOKEN TEXT")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(DriveColors.mutedFg)

                        TextEditor(text: $voiceText)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(DriveColors.foreground)
                            .frame(height: 100)
                            .padding(8)
                            .background(DriveColors.carbon)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.border, lineWidth: 1))
                    }

                    // ── Quick Presets ───────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QUICK SUGGESTIONS")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(DriveColors.mutedFg)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(samplePhrases, id: \.self) { phrase in
                                    Button(action: {
                                        voiceText = phrase
                                        if voiceTitle.isEmpty {
                                            voiceTitle = String(phrase.prefix(16))
                                        }
                                    }) {
                                        Text(phrase)
                                            .font(.system(size: 12))
                                            .foregroundColor(DriveColors.foreground)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(DriveColors.secondary)
                                            .cornerRadius(999)
                                            .overlay(Capsule().stroke(DriveColors.border, lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }

                    // ── Preview Button ──────────────────────────────────
                    Button(action: previewSpeech) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2.fill")
                            Text("Preview Voice")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(DriveColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DriveColors.primary.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DriveColors.primary.opacity(0.3), lineWidth: 1))
                    }
                    .disabled(voiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func previewSpeech() {
        let text = voiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let synth = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utterance)
        previewPlayer = synth
    }

    private func generateAndSave() {
        let text = voiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isGenerating = true
        let name = voiceTitle.isEmpty ? String(text.prefix(18)) : voiceTitle
        let cleanName = name.trimmingCharacters(in: .punctuationCharacters)

        let filename = "tts_\(cleanName.replacingOccurrences(of: " ", with: "_"))_\(UUID().uuidString.prefix(4)).wav"
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("TTSVoiceGeneratorSheet: documents directory unavailable; cannot generate TTS")
            isGenerating = false
            return
        }
        let outputURL = docs.appendingPathComponent(filename)

        if fm.fileExists(atPath: outputURL.path) {
            try? fm.removeItem(at: outputURL)
        }

        self.activeAudioFile = nil
        let synth = AVSpeechSynthesizer()
        self.speechSynthesizer = synth

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        synth.write(utterance) { buffer in
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
            if pcmBuffer.frameLength > 0 {
                if self.activeAudioFile == nil {
                    do {
                        let outputSettings: [String: Any] = [
                            AVFormatIDKey: Int(kAudioFormatLinearPCM),
                            AVSampleRateKey: 22050.0,
                            AVNumberOfChannelsKey: 1,
                            AVLinearPCMBitDepthKey: 16,
                            AVLinearPCMIsFloatKey: false,
                            AVLinearPCMIsBigEndianKey: false,
                            AVLinearPCMIsNonInterleaved: false
                        ]
                        self.activeAudioFile = try AVAudioFile(
                            forWriting: outputURL,
                            settings: outputSettings,
                            commonFormat: .pcmFormatInt16,
                            interleaved: false
                        )
                    } catch {
                        print("[TTS] Error creating AVAudioFile: \(error)")
                    }
                }
                
                if let audioFile = self.activeAudioFile {
                    let targetFormat = audioFile.processingFormat
                    if let converter = AVAudioConverter(from: pcmBuffer.format, to: targetFormat) {
                        let convertedBuffer = AVAudioPCMBuffer(
                            pcmFormat: targetFormat,
                            frameCapacity: pcmBuffer.frameCapacity
                        )!
                        var error: NSError? = nil
                        var hasProvidedData = false
                        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                            if hasProvidedData {
                                outStatus.pointee = .noDataNow
                                return nil
                            }
                            hasProvidedData = true
                            outStatus.pointee = .haveData
                            return pcmBuffer
                        }
                        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                        if error == nil && convertedBuffer.frameLength > 0 {
                            try? audioFile.write(from: convertedBuffer)
                        } else {
                            try? audioFile.write(from: pcmBuffer)
                        }
                    } else {
                        try? audioFile.write(from: pcmBuffer)
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.activeAudioFile = nil // Flushes and closes WAV header cleanly
            self.speechSynthesizer = nil
            self.isGenerating = false

            // Copy to App Group Shared Container for background Shortcuts playback
            if let sharedDir = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.drivestudio.shared") {
                let sharedURL = sharedDir.appendingPathComponent(outputURL.lastPathComponent)
                try? fm.removeItem(at: sharedURL)
                try? fm.copyItem(at: outputURL, to: sharedURL)
            }

            self.onVoiceGenerated(name, outputURL)
            self.dismiss()
        }
    }
}
