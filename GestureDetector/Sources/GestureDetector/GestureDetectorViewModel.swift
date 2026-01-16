import Foundation
import Combine
import CoreMedia

/// GestureDetectorViewModel coordinates high-level app state and logic.
/// It bridges the gap between raw camera frames and processed gesture actions.
@MainActor
class GestureDetectorViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var detectedGesture: GestureProcessor.GestureType = .None
    @Published var isConnected = false
    @Published var debounceProgress: Float = 0.0
    @Published var lastTriggerTime: Date?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var hostIP: String = "127.0.0.1" {
        didSet {
            UserDefaults.standard.set(hostIP, forKey: "hostIP")
            reconnect()
        }
    }
    
    // MARK: - Components
    
    let cameraManager = CameraManager()
    nonisolated fileprivate let gestureProcessor = GestureProcessor()
    private let debounceController = DebounceController<GestureProcessor.GestureType>(requiredFrames: 5)
    private var udpSender: UDPSender
    
    // MARK: - Subscriptions
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        let initialIP = UserDefaults.standard.string(forKey: "hostIP") ?? "127.0.0.1"
        self.hostIP = initialIP
        self.udpSender = UDPSender(host: initialIP, port: 8080)
        setupBindings()
    }
    
    // MARK: - Lifecycle Setup
    
    private func setupBindings() {
        cameraManager.frameDelegate = self
        
        // Handle detected frame analyses
        gestureProcessor.onGestureDetected = { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handleGestureResult(result)
            }
        }
        
        // Handle stable gesture confirmation
        debounceController.onStableValueDetected = { [weak self] gesture in
            Task { @MainActor [weak self] in
                await self?.triggerGestureAction(gesture)
            }
        }
        
        // Error monitoring
        cameraManager.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.errorMessage = message
                self?.showError = true
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Operations
    
    /// Starts the detection pipeline
    func startDetection() {
        cameraManager.startSession()
        reconnect()
    }
    
    /// Stops the detection pipeline
    func stopDetection() {
        cameraManager.stopSession()
        udpSender.disconnect()
        isConnected = false
    }
    
    /// Reinstate UDP connection
    private func reconnect() {
        udpSender.disconnect()
        udpSender = UDPSender(host: hostIP, port: 8080)
        
        Task {
            do {
                try await udpSender.connect()
                isConnected = true
            } catch {
                isConnected = false
                print("⚠️ UDP Connection failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Gesture Handling Logic
    
    private func handleGestureResult(_ result: GestureProcessor.GestureResult) {
        // Update UI immediately (MainActor)
        detectedGesture = result.detectedGesture
        
        // Feed into stability mechanism
        debounceController.process(result.detectedGesture, isPositive: result.detectedGesture != .None)
        debounceProgress = debounceController.progress
    }
    
    private func triggerGestureAction(_ gesture: GestureProcessor.GestureType) async {
        lastTriggerTime = Date()
        
        do {
            // Dispatch the signal!
            try await udpSender.sendMessage("\(gesture.rawValue)_detected")
            print("✨ Signal Dispatched: \(gesture.rawValue)")
        } catch {
            print("❌ Failed to dispatch signal: \(error.localizedDescription)")
            errorMessage = "Signal failed: \(error.localizedDescription)"
        }
        
        // Grace period before allowing next trigger
        try? await Task.sleep(nanoseconds: 750_000_000) // 0.75s
        debounceController.reset()
        debounceProgress = 0
    }
}

// MARK: - CameraFrameDelegate

extension GestureDetectorViewModel: CameraFrameDelegate {
    /// Non-isolated delegate call to avoid blocking the main thread for every frame.
    /// The GestureProcessor handles its own internal queueing.
    nonisolated func cameraManager(_ manager: CameraManager, didCaptureFrame sampleBuffer: CMSampleBuffer) {
        // Direct handoff to processor (off-main-actor)
        gestureProcessor.processFrame(sampleBuffer)
    }
}

