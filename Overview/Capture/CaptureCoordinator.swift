/*
 Capture/CaptureCoordinator.swift
 Overview

 Created by William Pierce on 9/15/24.

 Manages the lifecycle of each screen capture operation, coordinating source
 window selection, frame processing, and state synchronization.
*/

import Combine
import Defaults
import ScreenCaptureKit
import SwiftUI

@MainActor
final class CaptureCoordinator: ObservableObject {
    // Published State
    @Published private(set) var capturedFrame: CapturedFrame?
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var isSourceAppFocused: Bool = false
    @Published private(set) var isSourceWindowFocused: Bool = false
    @Published private(set) var sourceWindowTitle: String?
    @Published private(set) var sourceApplicationTitle: String?
    @Published var selectedSource: SCWindow? {
        didSet {
            sourceWindowTitle = selectedSource?.title
            sourceApplicationTitle = selectedSource?.owningApplication?.applicationName
            Task { await synchronizeFocusState() }
        }
    }

    // Dependencies
    private var sourceManager: SourceManager
    private var permissionManager: PermissionManager
    private let captureEngine: CaptureEngine
    private let captureServices: CaptureServices = CaptureServices.shared
    private let logger = AppLogger.capture

    // Private State
    private var hasPermission: Bool = false
    private var activeFrameProcessingTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var captureRequested: Bool = false
    private var captureGeneration: UInt = 0
    private var subscriptions = Set<AnyCancellable>()

    init(
        sourceManager: SourceManager,
        permissionManager: PermissionManager,
        captureEngine: CaptureEngine = CaptureEngine()
    ) {
        self.sourceManager = sourceManager
        self.permissionManager = permissionManager
        self.captureEngine = captureEngine
        setupSubscriptions()
    }

    // MARK: - Public Interface

    func requestPermission() async throws {
        guard !hasPermission else { return }
        logger.debug("Requesting screen recording permission")
        try await permissionManager.ensurePermission()
        hasPermission = true
        logger.info("Screen recording permission granted")
    }

    func startCapture() async throws {
        guard !captureRequested else { return }

        guard let source: SCWindow = selectedSource else {
            logger.error("Capture failed: No source window selected")
            throw CaptureError.noSourceSelected
        }

        captureRequested = true

        do {
            try await startCaptureStream(source: source)
        } catch {
            captureRequested = false
            isCapturing = false
            capturedFrame = nil
            throw error
        }
    }

    func stopCapture() async {
        guard captureRequested || isCapturing || captureEngine.stream != nil else { return }

        captureRequested = false
        captureGeneration &+= 1

        recoveryTask?.cancel()
        recoveryTask = nil

        activeFrameProcessingTask?.cancel()
        activeFrameProcessingTask = nil

        await captureEngine.stopCapture()

        isCapturing = false
        capturedFrame = nil
        logger.debug("Capture stopped")
    }

    func updateStreamConfiguration() async {
        guard isCapturing, let source: SCWindow = selectedSource else { return }
        logger.debug("Updating stream configuration: frameRate=\(Defaults[.captureFrameRate])")

        do {
            try await captureServices.updateStreamConfiguration(
                source: source,
                stream: captureEngine.stream,
                frameRate: Defaults[.captureFrameRate]
            )
            logger.info("Stream configuration updated successfully")
        } catch {
            logger.logError(error, context: "Failed to update stream configuration")
        }
    }

    func focusSource() {
        guard let source: SCWindow = selectedSource else { return }
        logger.debug("Focusing source window: '\(source.title ?? "Untitled")'")
        sourceManager.focusSource(source)
    }

    // MARK: - Frame Processing

    private func startCaptureStream(source: SCWindow) async throws {
        logger.debug("Starting capture for source window: '\(source.title ?? "Untitled")'")

        let stream = try await captureServices.startCapture(
            source: source,
            engine: captureEngine,
            frameRate: Defaults[.captureFrameRate]
        )

        captureGeneration &+= 1
        let generation = captureGeneration

        isCapturing = true
        processFrames(from: stream, generation: generation)
        logger.info("Capture started: '\(source.title ?? "Untitled")'")
    }

    private func processFrames(
        from stream: AsyncThrowingStream<CapturedFrame, Error>,
        generation: UInt
    ) {
        activeFrameProcessingTask?.cancel()

        activeFrameProcessingTask = Task { @MainActor in
            do {
                for try await frame in stream {
                    guard !Task.isCancelled, generation == captureGeneration else { return }

                    self.capturedFrame = frame
                }

                guard !Task.isCancelled, generation == captureGeneration, captureRequested else {
                    return
                }

                logger.warning("Capture stream ended unexpectedly")
                scheduleRecovery(reason: "stream ended")

            } catch let error as SCStreamError {
                guard !Task.isCancelled, generation == captureGeneration, captureRequested else {
                    return
                }
                await handleStreamError(error)

            } catch {
                guard !Task.isCancelled, generation == captureGeneration, captureRequested else {
                    return
                }

                logger.logError(error, context: "Capture stream ended unexpectedly")
                scheduleRecovery(reason: error.localizedDescription)
            }
        }
    }

    private func handleStreamError(_ error: SCStreamError) async {
        let errorDescription = error.localizedDescription

        // `systemStoppedStream` was added to the typed API in macOS 15, but
        // ScreenCaptureKit can report its stable raw code on earlier systems.
        if error.code.rawValue == -3821 {
            logger.logError(
                error,
                context: "System stopped capture stream (code=\(error.code.rawValue)); scheduling recovery"
            )
            scheduleRecovery(reason: "systemStoppedStream")
            return
        }

        if error.code.isFatal {
            logger.logError(
                error,
                context: "Fatal stream error: \(errorDescription) (code=\(error.code.rawValue))"
            )
            await stopCapture()
        } else {
            logger.logError(
                error,
                context: "Recoverable stream error: \(errorDescription) (code=\(error.code.rawValue))"
            )
            scheduleRecovery(reason: errorDescription)
        }
    }

    private func scheduleRecovery(reason: String) {
        guard captureRequested, recoveryTask == nil else { return }

        logger.info("Scheduling capture recovery: \(reason)")

        recoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.recoverCapture()
            self.recoveryTask = nil
        }
    }

    private func recoverCapture() async {
        guard captureRequested, let currentSource = selectedSource else { return }

        logger.debug("Attempting to recover from capture error")
        let snapshot = SourceSnapshot(source: currentSource)
        let retryDelays: [UInt64] = [1_000_000_000, 2_000_000_000, 5_000_000_000]

        // The system has already stopped the stream. This releases the old engine
        // state while deliberately retaining the last frame and public capture state,
        // so the preview does not jump back to the source picker during recovery.
        activeFrameProcessingTask = nil
        await captureEngine.stopCapture()

        for (index, delay) in retryDelays.enumerated() {
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            guard captureRequested, !Task.isCancelled else { return }

            do {
                let sources = try await sourceManager.getAvailableSources()
                guard let source = findMatchingSource(snapshot, in: sources) else {
                    logger.warning("Capture recovery attempt \(index + 1): source not found")
                    continue
                }

                selectedSource = source
                try await startCaptureStream(source: source)
                logger.info("Capture recovery succeeded on attempt \(index + 1)")
                return
            } catch {
                logger.logError(error, context: "Capture recovery attempt \(index + 1) failed")
            }
        }

        logger.error("Capture recovery failed after \(retryDelays.count) attempts")
        captureRequested = false
        isCapturing = false
        capturedFrame = nil
    }

    private func findMatchingSource(
        _ snapshot: SourceSnapshot,
        in sources: [SCWindow]
    ) -> SCWindow? {
        if let exactMatch = sources.first(where: { $0.windowID == snapshot.windowID }) {
            return exactMatch
        }

        if let bundleMatch = sources.first(where: {
            $0.owningApplication?.bundleIdentifier == snapshot.bundleIdentifier
                && $0.title == snapshot.title
        }) {
            return bundleMatch
        }

        return sources.first(where: {
            $0.owningApplication?.applicationName == snapshot.applicationName
                && $0.title == snapshot.title
        })
    }

    // MARK: - State Synchronization

    private func setupSubscriptions() {
        sourceManager.$focusedProcessId
            .sink { [weak self] _ in Task { await self?.synchronizeFocusState() } }
            .store(in: &subscriptions)

        sourceManager.$sourceTitles
            .sink { [weak self] titles in self?.synchronizeSourceTitle(from: titles) }
            .store(in: &subscriptions)
    }

    private func synchronizeFocusState() async {
        guard let selectedSource: SCWindow = selectedSource else {
            isSourceWindowFocused = false
            return
        }

        let selectedProcessId: pid_t? = selectedSource.owningApplication?.processID
        let selectedBundleId: String? = selectedSource.owningApplication?.bundleIdentifier

        isSourceWindowFocused = selectedProcessId == sourceManager.focusedProcessId
        isSourceAppFocused = selectedBundleId == sourceManager.focusedBundleId
    }

    private func synchronizeSourceTitle(from titles: [SourceManager.SourceID: String]) {
        guard let source: SCWindow = selectedSource,
            let processID: pid_t = source.owningApplication?.processID
        else { return }

        let sourceID = SourceManager.SourceID(processID: processID, windowID: source.windowID)
        sourceWindowTitle = titles[sourceID]
        sourceApplicationTitle = source.owningApplication?.applicationName
    }
}

// MARK - Support Types

enum CaptureError: LocalizedError {
    case noSourceSelected
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noSourceSelected:
            return "No source window is selected for capture"
        case .permissionDenied:
            return "Screen capture permission was denied"
        }
    }
}

private struct SourceSnapshot {
    let windowID: CGWindowID
    let title: String?
    let bundleIdentifier: String?
    let applicationName: String?

    init(source: SCWindow) {
        windowID = source.windowID
        title = source.title
        bundleIdentifier = source.owningApplication?.bundleIdentifier
        applicationName = source.owningApplication?.applicationName
    }
}

extension SCStreamError.Code {
    var isFatal: Bool {
        switch self {
        case .userDeclined, .missingEntitlements, .userStopped,
            .noCaptureSource, .noWindowList,
            .failedApplicationConnectionInvalid,
            .failedApplicationConnectionInterrupted,
            .failedNoMatchingApplicationContext, .internalError:
            return true
        default:
            return false
        }
    }
}
