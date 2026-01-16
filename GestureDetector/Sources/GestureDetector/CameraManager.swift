import Foundation
import AVFoundation
import Combine

/// CameraFrameDelegate facilitates the transfer of video frames to the processor.
protocol CameraFrameDelegate: AnyObject {
    /// Called whenever a new video frame is captured.
    func cameraManager(_ manager: CameraManager, didCaptureFrame sampleBuffer: CMSampleBuffer)
}

/// CameraManager orchestrates AVFoundation video capture at a consistent 30fps.
/// It encapsulates session management, authorization, and frame dispatching.
class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthorized = false
    @Published var isRunning = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    /// The core capture session
    let captureSession = AVCaptureSession()
    
    /// Delegate for frame processing
    weak var frameDelegate: CameraFrameDelegate?
    
    /// Dedicated queue for session configuration and control
    private let sessionQueue = DispatchQueue(
        label: "com.gesturelink.camera.session",
        qos: .userInitiated
    )
    
    /// High-priority queue for video frame output
    private let videoOutputQueue = DispatchQueue(
        label: "com.gesturelink.camera.videoOutput",
        qos: .userInteractive
    )
    
    private var videoOutput: AVCaptureVideoDataOutput?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    // MARK: - Authorization Logic
    
    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.isAuthorized = true }
            setupSession()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
            
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.errorMessage = "Camera access denied. Please enable in System Preferences."
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Session Configuration
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Optimize for high-quality video processing
            if self.captureSession.canSetSessionPreset(.high) {
                self.captureSession.sessionPreset = .high
            }
            
            // Prefer Front Camera (FaceTime HD) for gestures
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? 
                    AVCaptureDevice.default(for: .video) else {
                self.fail(with: "No camera device available")
                return
            }
            
            do {
                try videoDevice.lockForConfiguration()
                
                // Enforce strictly defined 30fps for stable detection
                let targetFrameRate = CMTime(value: 1, timescale: 30)
                if let format = videoDevice.formats.first(where: { 
                    $0.videoSupportedFrameRateRanges.contains { $0.minFrameDuration <= targetFrameRate }
                }) {
                    videoDevice.activeFormat = format
                    videoDevice.activeVideoMinFrameDuration = targetFrameRate
                    videoDevice.activeVideoMaxFrameDuration = targetFrameRate
                }
                
                videoDevice.unlockForConfiguration()
                
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                } else {
                    self.fail(with: "Cannot add video input to session")
                    return
                }
                
            } catch {
                self.fail(with: "Configuration failed: \(error.localizedDescription)")
                return
            }
            
            // Configure Video Output
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
            output.alwaysDiscardsLateVideoFrames = true // Prioritize real-time over continuity
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)
                self.videoOutput = output
            } else {
                self.fail(with: "Cannot add video output to session")
                return
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    private func fail(with message: String) {
        DispatchQueue.main.async { self.errorMessage = message }
        self.captureSession.commitConfiguration()
    }
    
    // MARK: - Controls
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameDelegate?.cameraManager(self, didCaptureFrame: sampleBuffer)
    }
}

