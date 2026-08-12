import SwiftUI
import AVFoundation

// MARK: - Audio Delegate for auto-resetting play icon on finish
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinish?()
        }
    }
}

// MARK: - Sounds Screen
struct SoundsScreenView: View {
    @State private var selectedTrigger = "Connect"
    @State private var playingSound: String? = nil
    @State private var showFileImporter = false
    @State private var showTTSGeneratorSheet = false
    @State private var showMicRecorderSheet = false
    @State private var targetAssignSound: (name: String, url: URL?)? = nil
    @State private var showAssignActionSheet = false
    @State private var customSounds: [(name: String, duration: String, url: URL)] = []
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playerDelegate = AudioPlayerDelegate()

    private let triggers = ["Connect", "Disconnect", "Reminder"]
    @State private var triggerAssignments: [String: String] = [
        "Connect": UserDefaults(suiteName: "group.com.drivestudio.shared")?.string(forKey: "trigger_Connect") ?? "none",
        "Disconnect": UserDefaults(suiteName: "group.com.drivestudio.shared")?.string(forKey: "trigger_Disconnect") ?? "none",
        "Reminder": UserDefaults(suiteName: "group.com.drivestudio.shared")?.string(forKey: "trigger_Reminder") ?? "none"
    ]

    @State private var selectedCategory = "All"

    private let sounds: [(name: String, duration: String, isPremium: Bool, category: String)] = [
        ("Welcome Back", "0:02", false, "Connect"),
        ("Vehicle Connected", "0:03", false, "Connect"),
        ("Everything Ready", "0:02", false, "Connect"),
        ("System Online", "0:02", false, "Connect"),
        ("Dashboard Ready", "0:03", false, "Connect"),
        ("Buckle Up", "0:02", false, "Connect"),
        ("Adventure Begins", "0:03", false, "Connect"),
        ("Welcome Aboard", "0:02", false, "Connect"),
        ("Connection Successful", "0:03", false, "Connect"),
        ("Drive Mode", "0:02", false, "Connect"),
        ("Lock Vehicle", "0:02", false, "Disconnect"),
        ("Safe Arrival", "0:02", false, "Disconnect"),
        ("Goodbye", "0:01", false, "Disconnect"),
        ("Nice Parking", "0:02", false, "Disconnect"),
        ("Until Next Time", "0:02", false, "Disconnect"),
        ("Vehicle Secured", "0:02", false, "Disconnect"),
        ("Phone Reminder", "0:03", false, "Reminders"),
        ("Phone Keys Wallet", "0:03", false, "Reminders"),
        ("Check Windows", "0:02", false, "Reminders"),
        ("Check Back Seat", "0:02", false, "Reminders"),
        ("Acura Nsx", "0:04", false, "Engines"),
        ("Alfa Romeo Giulia", "0:04", false, "Engines"),
        ("Aston Martin Db12", "0:04", true, "Engines"),
        ("Audi Rs7", "0:04", false, "Engines"),
        ("Bentley Continental", "0:04", true, "Engines"),
        ("Byd Seal", "0:04", false, "Engines"),
        ("Cadillac Escalade", "0:04", false, "Engines"),
        ("Chery Tiggo 8", "0:04", false, "Engines"),
        ("Chrysler 300", "0:04", false, "Engines"),
        ("Citroen C5 Aircross", "0:04", false, "Engines"),
        ("Ferrari 296", "0:04", true, "Engines"),
        ("Genesis G80", "0:04", false, "Engines"),
        ("Gmc Hummer Ev", "0:04", false, "Engines"),
        ("Hyundai Ioniq 5", "0:04", false, "Engines"),
        ("Jaguar F Type", "0:04", false, "Engines"),
        ("Jeep Wrangler", "0:04", false, "Engines"),
        ("Kia Ev6", "0:04", false, "Engines"),
        ("Lamborghini Huracan", "0:04", true, "Engines"),
        ("Land Rover Defender", "0:04", false, "Engines"),
        ("Lexus Lc 500", "0:04", false, "Engines"),
        ("Lucid Air", "0:04", true, "Engines"),
        ("Maserati Granturismo", "0:04", false, "Engines"),
        ("Mazda Mx5", "0:04", false, "Engines"),
        ("Mclaren 750s", "0:04", true, "Engines"),
        ("Mini Cooper", "0:04", false, "Engines"),
        ("Nissan Gtr", "0:04", false, "Engines"),
        ("Peugeot 508", "0:04", false, "Engines"),
        ("Range Rover Sport", "0:04", false, "Engines"),
        ("Subaru Wrx", "0:04", false, "Engines"),
        ("Volvo Xc90", "0:04", false, "Engines"),
    ]

    var filteredSounds: [(name: String, duration: String, isPremium: Bool, category: String)] {
        if selectedCategory == "All" {
            return sounds
        } else if selectedCategory == "Custom" {
            return []
        } else {
            return sounds.filter { $0.category == selectedCategory }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sounds & Cues")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.5)
                        .foregroundColor(DriveColors.foreground)
                    Text("Pick a trigger, then tap a track to assign it.")
                        .font(.system(size: 14))
                        .lineSpacing(6)
                        .foregroundColor(DriveColors.mutedFg)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)

                // Triggers Card
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        MonoLabel(text: "Triggers")

                        Spacer().frame(height: 0)

                        ForEach(triggers, id: \.self) { trigger in
                            Button(action: {
                                selectedTrigger = trigger
                                if trigger == "Connect" { selectedCategory = "Connect" }
                                else if trigger == "Disconnect" { selectedCategory = "Disconnect" }
                                else if trigger == "Reminder" { selectedCategory = "Reminders" }
                            }) {
                                HStack {
                                    Text(trigger)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DriveColors.foreground)
                                    Spacer()
                                    Text(triggerAssignments[trigger] ?? "none")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(DriveColors.mutedFg)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(selectedTrigger == trigger ? DriveColors.primary.opacity(0.1) : DriveColors.secondary.opacity(0.6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTrigger == trigger ? DriveColors.primary.opacity(0.6) : DriveColors.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 24)

                // Sound Library Category Pills
                VStack(alignment: .leading, spacing: 12) {
                    MonoLabel(text: "Sound library")
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["All", "Connect", "Disconnect", "Reminders", "Engines", "Custom"], id: \.self) { cat in
                                Button(action: { selectedCategory = cat }) {
                                    Text(cat)
                                        .font(.system(size: 12, weight: selectedCategory == cat ? .bold : .semibold))
                                        .foregroundColor(selectedCategory == cat ? .black : DriveColors.foreground)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(selectedCategory == cat ? Color.white : DriveColors.secondary)
                                        .cornerRadius(999)
                                        .overlay(Capsule().stroke(selectedCategory == cat ? Color.white : DriveColors.border, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer().frame(height: 12)

                SurfaceCard(padding: .init(top: 0, leading: 0, bottom: 0, trailing: 0)) {
                    VStack(spacing: 0) {
                        
                        // ── 1. Record Voice via Mic Row ─────────────────────────
                        Button(action: { showMicRecorderSheet = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(DriveColors.primary.opacity(0.2))
                                        .overlay(Circle().stroke(DriveColors.primary.opacity(0.6), lineWidth: 1.5))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(DriveColors.primary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Record Voice via Mic")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(DriveColors.primary)
                                    Text("Speak & Record Direct Audio")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(DriveColors.primary.opacity(0.85))
                                }
                                Spacer()
                                Image(systemName: "record.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(DriveColors.primary)
                            }
                            .padding(.all, 14)
                            .background(DriveColors.primary.opacity(0.08))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DriveColors.primary.opacity(0.3), lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                        // ── 2. Create Text-to-Speech Voice Row ──────────────────
                        Button(action: { showTTSGeneratorSheet = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(DriveColors.primary.opacity(0.2))
                                        .overlay(Circle().stroke(DriveColors.primary.opacity(0.6), lineWidth: 1.5))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "waveform.and.mic")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(DriveColors.primary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Create Text-to-Speech Voice")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(DriveColors.primary)
                                    Text("Convert Text into Speech")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(DriveColors.primary.opacity(0.85))
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(DriveColors.primary)
                            }
                            .padding(.all, 14)
                            .background(DriveColors.primary.opacity(0.08))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DriveColors.primary.opacity(0.3), lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        Divider().background(DriveColors.border).padding(.horizontal, 16)

                        // Custom File Upload Row
                        Button(action: { showFileImporter = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(DriveColors.secondary)
                                        .overlay(Circle().stroke(DriveColors.border, lineWidth: 1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(DriveColors.foreground)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upload Custom Sound")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DriveColors.foreground)
                                    Text("MP3 or WAV File")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(DriveColors.mutedFg)
                                }
                                Spacer()
                            }
                            .padding(.all, 16)
                        }
                        
                        Divider().background(DriveColors.border).padding(.horizontal, 16)
                        
                        // User-Uploaded / Mic-Recorded / TTS Created Custom Sounds
                        if selectedCategory == "All" || selectedCategory == "Custom" {
                            ForEach(customSounds.indices, id: \.self) { i in
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        // Play button
                                        Button(action: {
                                            playSound(name: customSounds[i].name, url: customSounds[i].url)
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(DriveColors.secondary)
                                                    .overlay(Circle().stroke(DriveColors.border, lineWidth: 1))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: playingSound == customSounds[i].name ? "pause.fill" : "play.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(DriveColors.primary)
                                            }
                                        }

                                        // Tap sound title row to open Assign Action Sheet
                                        Button(action: {
                                            targetAssignSound = (name: customSounds[i].name, url: customSounds[i].url)
                                            showAssignActionSheet = true
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(customSounds[i].name)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(DriveColors.foreground)
                                                    Text(customSounds[i].duration)
                                                        .font(.system(size: 11, design: .monospaced))
                                                        .foregroundColor(DriveColors.mutedFg)
                                                }
                                                Spacer()
                                                
                                                HStack(spacing: 4) {
                                                    let assignedTriggers = triggerAssignments.filter({ $0.value == customSounds[i].name }).map({ $0.key })
                                                    ForEach(assignedTriggers, id: \.self) { trg in
                                                        Text(trg.uppercased())
                                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                                            .tracking(1.5)
                                                            .foregroundColor(DriveColors.primary)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(DriveColors.primary.opacity(0.1))
                                                            .cornerRadius(999)
                                                            .overlay(Capsule().stroke(DriveColors.primary.opacity(0.4), lineWidth: 1))
                                                    }
                                                }
                                            }
                                        }

                                        // Single Delete button (ONLY FOR USER UPLOADED / MIC RECORDED / TTS CREATED SOUNDS)
                                        Button(action: {
                                            deleteCustomSound(at: i)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(DriveColors.destructive.opacity(0.85))
                                                .frame(width: 32, height: 32)
                                                .background(DriveColors.destructive.opacity(0.12))
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding(.all, 16)

                                    Divider().background(DriveColors.border).padding(.horizontal, 16)
                                }
                            }
                        }

                        // Stock Library Sounds
                        ForEach(filteredSounds.indices, id: \.self) { i in
                            let snd = filteredSounds[i]
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    // Play button
                                    Button(action: {
                                        playSound(name: snd.name, url: nil)
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(DriveColors.secondary)
                                                .overlay(Circle().stroke(DriveColors.border, lineWidth: 1))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: playingSound == snd.name ? "pause.fill" : "play.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(DriveColors.primary)
                                        }
                                    }

                                    // Tap sound title row to open Assign Action Sheet
                                    Button(action: {
                                        targetAssignSound = (name: snd.name, url: nil)
                                        showAssignActionSheet = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 8) {
                                                    Text(snd.name)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(DriveColors.foreground)
                                                    if snd.isPremium {
                                                        Text("PRO")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(DriveColors.primary)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(DriveColors.primary.opacity(0.15))
                                                            .cornerRadius(4)
                                                    }
                                                }
                                                Text(snd.duration)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(DriveColors.mutedFg)
                                            }
                                            Spacer()
                                            
                                            HStack(spacing: 4) {
                                                let assignedTriggers = triggerAssignments.filter({ $0.value == snd.name }).map({ $0.key })
                                                ForEach(assignedTriggers, id: \.self) { trg in
                                                    Text(trg.uppercased())
                                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                                        .tracking(1.5)
                                                        .foregroundColor(DriveColors.primary)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(DriveColors.primary.opacity(0.1))
                                                        .cornerRadius(999)
                                                        .overlay(Capsule().stroke(DriveColors.primary.opacity(0.4), lineWidth: 1))
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.all, 16)

                                if i < filteredSounds.count - 1 {
                                    Divider().background(DriveColors.border).padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 104)
            }
        }
        .background(DriveColors.background)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile: URL = try result.get().first else { return }
                
                if selectedFile.startAccessingSecurityScopedResource() {
                    defer { selectedFile.stopAccessingSecurityScopedResource() }
                    
                    let fm = FileManager.default
                    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let destUrl = docs.appendingPathComponent(selectedFile.lastPathComponent)
                    
                    if fm.fileExists(atPath: destUrl.path) {
                        try? fm.removeItem(at: destUrl)
                    }
                    try fm.copyItem(at: selectedFile, to: destUrl)
                    
                    let asset = AVURLAsset(url: destUrl)
                    let durationSeconds = CMTimeGetSeconds(asset.duration)
                    let durationString = durationSeconds.isNaN ? "0:00" : String(format: "%d:%02d", Int(durationSeconds) / 60, Int(durationSeconds) % 60)
                    
                    let newSound = (name: destUrl.deletingPathExtension().lastPathComponent, duration: durationString, url: destUrl)
                    customSounds.append(newSound)
                }
            } catch {
                print("Failed to import audio: \(error)")
            }
        }
        .sheet(isPresented: $showTTSGeneratorSheet) {
            TTSVoiceGeneratorSheet { voiceName, voiceURL in
                let asset = AVURLAsset(url: voiceURL)
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                let durationString = durationSeconds.isNaN ? "0:02" : String(format: "%d:%02d", Int(durationSeconds) / 60, Int(durationSeconds) % 60)
                let newSound = (name: voiceName, duration: durationString, url: voiceURL)
                customSounds.append(newSound)
                assignSound(voiceName)
            }
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMicRecorderSheet) {
            MicRecorderSheet { recName, recURL in
                let asset = AVURLAsset(url: recURL)
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                let durationString = durationSeconds.isNaN ? "0:02" : String(format: "%d:%02d", Int(durationSeconds) / 60, Int(durationSeconds) % 60)
                let newSound = (name: recName, duration: durationString, url: recURL)
                customSounds.append(newSound)
                assignSound(recName)
            }
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Assign Sound", isPresented: $showAssignActionSheet, titleVisibility: .visible) {
            if let target = targetAssignSound {
                let isConnect = triggerAssignments["Connect"] == target.name
                let isDisconnect = triggerAssignments["Disconnect"] == target.name
                let isReminder = triggerAssignments["Reminder"] == target.name

                Button(isConnect ? "✓ Assigned to Connect" : "⚡ Assign to Connect") {
                    assignSoundToTrigger(target.name, trigger: "Connect")
                }
                Button(isDisconnect ? "✓ Assigned to Disconnect" : "🔌 Assign to Disconnect") {
                    assignSoundToTrigger(target.name, trigger: "Disconnect")
                }
                Button(isReminder ? "✓ Assigned to Reminder" : "⏰ Assign to Reminder") {
                    assignSoundToTrigger(target.name, trigger: "Reminder")
                }
                Button("▶ Play Sound Preview") {
                    playSound(name: target.name, url: target.url)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            loadCustomSounds()
        }
    }

    private func loadCustomSounds() {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let files = try fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)
            var loaded: [(String, String, URL)] = []
            for file in files {
                if ["mp3", "wav", "m4a", "caf"].contains(file.pathExtension.lowercased()) {
                    let asset = AVURLAsset(url: file)
                    let durationSeconds = CMTimeGetSeconds(asset.duration)
                    let durationString = durationSeconds.isNaN ? "0:00" : String(format: "%d:%02d", Int(durationSeconds) / 60, Int(durationSeconds) % 60)
                    loaded.append((file.deletingPathExtension().lastPathComponent, durationString, file))
                }
            }
            customSounds = loaded.sorted(by: { $0.0 < $1.0 })
        } catch {
            print("Could not load custom sounds: \(error)")
        }
    }
    
    private func assignSound(_ name: String) {
        assignSoundToTrigger(name, trigger: selectedTrigger)
    }

    private func assignSoundToTrigger(_ name: String, trigger: String) {
        // Override logic: Remove this sound from any other trigger first
        for key in ["Connect", "Disconnect", "Reminder"] {
            if triggerAssignments[key] == name {
                triggerAssignments[key] = nil
                UserDefaults(suiteName: "group.com.drivestudio.shared")?.removeObject(forKey: "trigger_\(key)")
            }
        }
        
        triggerAssignments[trigger] = name
        UserDefaults(suiteName: "group.com.drivestudio.shared")?.set(name, forKey: "trigger_\(trigger)")
    }

    private func playSound(name: String, url: URL?) {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            audioPlayer = nil
        }

        if playingSound == name {
            playingSound = nil
            return
        }
        
        var targetURL: URL? = url
        
        if targetURL == nil {
            let searchKey = name.lowercased().replacingOccurrences(of: " ", with: "_")
            if let urls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) {
                for u in urls {
                    if u.lastPathComponent.lowercased().contains(searchKey) {
                        targetURL = u
                        break
                    }
                }
            }
        }
        
        if let targetURL = targetURL {
            do {
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .default, options: [.duckOthers, .mixWithOthers])
                try? session.setActive(true)
                
                let player = try AVAudioPlayer(contentsOf: targetURL)
                player.volume = 1.0
                playerDelegate.onFinish = {
                    self.playingSound = nil
                }
                player.delegate = playerDelegate
                player.prepareToPlay()
                player.play()
                audioPlayer = player
                playingSound = name
            } catch {
                print("AVAudioPlayer error (\(error)), playing SystemSound fallback")
                var soundID: SystemSoundID = 0
                AudioServicesCreateSystemSoundID(targetURL as CFURL, &soundID)
                AudioServicesPlaySystemSound(soundID)
                playingSound = name
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if self.playingSound == name {
                        self.playingSound = nil
                    }
                }
            }
        } else {
            print("Sound file not found for \(name)")
        }
    }

    private func deleteCustomSound(at index: Int) {
        guard index >= 0 && index < customSounds.count else { return }
        let sound = customSounds[index]

        if playingSound == sound.name {
            audioPlayer?.stop()
            audioPlayer = nil
            playingSound = nil
        }

        for (trigger, assignedName) in triggerAssignments {
            if assignedName == sound.name {
                triggerAssignments[trigger] = "none"
                UserDefaults(suiteName: "group.com.drivestudio.shared")?.set("none", forKey: "trigger_\(trigger)")
            }
        }

        try? FileManager.default.removeItem(at: sound.url)
        customSounds.remove(at: index)
    }
}
