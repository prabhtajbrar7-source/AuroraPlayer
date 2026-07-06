//
//  AudioPlayerManager.swift
//  AuroraPlayer
//
//  Built on AVAudioEngine (not the simpler AVAudioPlayer) so we can:
//   1. Tap the raw PCM stream for the FFT-driven wave visualizer.
//   2. Crossfade between two player nodes when a track ends.
//   3. Seek accurately by scheduling a segment from an arbitrary frame offset.
//
//  This is a genuinely working playback engine, not a mock — the only thing
//  it needs from you is real audio files (imported via LibraryManager).
//

import Foundation
import AVFoundation
import Accelerate
import Combine

@MainActor
final class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()

    // MARK: Published playback state

    @Published private(set) var currentSong: Song?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var volume: Float = 1.0 {
        didSet { mixerA.outputVolume = volume; mixerB.outputVolume = volume }
    }
    @Published var isShuffleEnabled: Bool = false
    @Published private(set) var repeatMode: RepeatMode = .off

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    /// Latest 32-band magnitude spectrum (0...1), refreshed ~30x/sec while playing.
    /// Feed this straight into `WaveVisualizerView`.
    @Published private(set) var spectrumBands: [Float] = Array(repeating: 0, count: 32)

    enum RepeatMode { case off, one, all }

    /// Called by QueueManager to know when to advance. AudioPlayerManager doesn't
    /// know about the queue itself — that's a deliberate separation of concerns.
    var onTrackFinished: (() -> Void)?

    // MARK: Engine internals

    private let engine = AVAudioEngine()
    private var playerA = AVAudioPlayerNode()
    private var playerB = AVAudioPlayerNode()
    private let mixerA = AVAudioMixerNode()
    private let mixerB = AVAudioMixerNode()
    private var activeIsA = true

    private var audioFile: AVAudioFile?
    private var sampleRate: Double = 44100
    private var seekOffsetFrames: AVAudioFramePosition = 0
    private var displayLink: CADisplayLink?
    private var progressTimer: Timer?

    private let fftSetup = vDSP_DFT_zop_CreateSetup(nil, 1024, .FORWARD)

    private init() {
        configureEngine()
        configureAudioSession()
    }

    private func configureEngine() {
        [playerA, playerB].forEach { engine.attach($0) }
        [mixerA, mixerB].forEach { engine.attach($0) }
        engine.connect(playerA, to: mixerA, format: nil)
        engine.connect(playerB, to: mixerB, format: nil)
        engine.connect(mixerA, to: engine.mainMixerNode, format: nil)
        engine.connect(mixerB, to: engine.mainMixerNode, format: nil)
        mixerB.outputVolume = 0 // B starts silent; used only during crossfade

        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.processSpectrum(buffer: buffer)
        }

        do {
            try engine.start()
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session config failed: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: Transport controls

    func play(song: Song) {
        stopProgressTimer()
        let player = activeIsA ? playerA : playerB
        player.stop()

        guard let file = try? AVAudioFile(forReading: song.fileURL) else {
            print("Could not open audio file for \(song.title)")
            return
        }
        audioFile = file
        sampleRate = file.fileFormat.sampleRate
        duration = Double(file.length) / sampleRate
        currentSong = song
        seekOffsetFrames = 0

        schedule(file: file, from: 0, on: player)
        player.play()
        isPlaying = true
        startProgressTimer()
    }

    func togglePlayPause() {
        let player = activeIsA ? playerA : playerB
        if isPlaying {
            player.pause()
            isPlaying = false
            stopProgressTimer()
        } else {
            player.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    func pause() {
        guard isPlaying else { return }
        (activeIsA ? playerA : playerB).pause()
        isPlaying = false
        stopProgressTimer()
    }

    func resume() {
        guard !isPlaying, currentSong != nil else { return }
        (activeIsA ? playerA : playerB).play()
        isPlaying = true
        startProgressTimer()
    }

    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        let player = activeIsA ? playerA : playerB
        let wasPlaying = isPlaying
        player.stop()

        let clamped = max(0, min(time, duration))
        seekOffsetFrames = AVAudioFramePosition(clamped * sampleRate)
        schedule(file: file, from: seekOffsetFrames, on: player)
        currentTime = clamped

        if wasPlaying {
            player.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    private func schedule(file: AVAudioFile, from frame: AVAudioFramePosition, on player: AVAudioPlayerNode) {
        let framesToPlay = AVAudioFrameCount(file.length - frame)
        guard framesToPlay > 0 else { return }
        file.framePosition = frame
        player.scheduleSegment(
            file,
            startingFrame: frame,
            frameCount: framesToPlay,
            at: nil
        ) { [weak self] in
            Task { @MainActor in
                self?.handleNaturalFinish()
            }
        }
    }

    private func handleNaturalFinish() {
        guard isPlaying else { return } // ignore completion fired by our own `.stop()` calls
        switch repeatMode {
        case .one:
            if let song = currentSong { play(song: song) }
        default:
            onTrackFinished?()
        }
    }

    /// Crossfades from the currently playing track directly into `nextSong`,
    /// using the idle player node so there's no gap or click — the Spotify/Apple
    /// Music "premium" feel the user asked for.
    func crossfade(to nextSong: Song, duration crossfadeDuration: TimeInterval) {
        guard let nextFile = try? AVAudioFile(forReading: nextSong.fileURL) else {
            play(song: nextSong)
            return
        }

        let outgoingPlayer = activeIsA ? playerA : playerB
        let outgoingMixer = activeIsA ? mixerA : mixerB
        let incomingPlayer = activeIsA ? playerB : playerA
        let incomingMixer = activeIsA ? mixerB : mixerA

        incomingPlayer.stop()
        incomingMixer.outputVolume = 0
        incomingPlayer.scheduleFile(nextFile, at: nil) { [weak self] in
            Task { @MainActor in self?.handleNaturalFinish() }
        }
        incomingPlayer.play()

        let steps = 30
        let stepDuration = crossfadeDuration / Double(steps)
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            Task { @MainActor in
                outgoingMixer.outputVolume = self.volume * (1 - progress)
                incomingMixer.outputVolume = self.volume * progress
            }
            if currentStep >= steps {
                timer.invalidate()
                Task { @MainActor in
                    outgoingPlayer.stop()
                    self.activeIsA.toggle()
                    self.audioFile = nextFile
                    self.sampleRate = nextFile.fileFormat.sampleRate
                    self.duration = Double(nextFile.length) / self.sampleRate
                    self.currentSong = nextSong
                    self.seekOffsetFrames = 0
                    self.isPlaying = true
                }
            }
        }
    }

    // MARK: Progress tracking

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshCurrentTime() }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func refreshCurrentTime() {
        let player = activeIsA ? playerA : playerB
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return }
        let elapsedFrames = Double(seekOffsetFrames) + Double(playerTime.sampleTime)
        currentTime = elapsedFrames / sampleRate
    }

    // MARK: Spectrum analysis (drives WaveVisualizerView)

    private func processSpectrum(buffer: AVAudioPCMBuffer) {
        guard isPlaying, let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= 1024, let fftSetup else { return }

        var realIn = [Float](repeating: 0, count: 1024)
        var imagIn = [Float](repeating: 0, count: 1024)
        var realOut = [Float](repeating: 0, count: 1024)
        var imagOut = [Float](repeating: 0, count: 1024)

        // Hann window to reduce spectral leakage
        var window = [Float](repeating: 0, count: 1024)
        vDSP_hann_window(&window, 1024, Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData, 1, window, 1, &realIn, 1, 1024)

        vDSP_DFT_Execute(fftSetup, realIn, imagIn, &realOut, &imagOut)

        var magnitudes = [Float](repeating: 0, count: 512)
        realOut.withUnsafeMutableBufferPointer { realPtr in
            imagOut.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, 512)
            }
        }

        // Collapse 512 bins down to 32 perceptual bands (log-ish grouping so bass
        // isn't just one giant spike compared to the highs).
        var bands = [Float](repeating: 0, count: 32)
        let binsPerBand = 512 / 32
        for i in 0..<32 {
            let start = i * binsPerBand
            let end = start + binsPerBand
            let slice = magnitudes[start..<end]
            let avg = slice.reduce(0, +) / Float(binsPerBand)
            bands[i] = min(1.0, sqrt(avg) / 12.0) // sqrt + scale = softer, more musical response
        }

        Task { @MainActor in
            // Light smoothing against the previous frame so bars don't jitter.
            for i in 0..<32 {
                self.spectrumBands[i] = self.spectrumBands[i] * 0.6 + bands[i] * 0.4
            }
        }
    }

    deinit {
        if let fftSetup { vDSP_DFT_DestroySetup(fftSetup) }
    }
}
