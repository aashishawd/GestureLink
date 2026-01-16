import Foundation
import Vision
import CoreMedia

/// GestureProcessor handles Vision-based hand pose detection.
/// It processes CMSampleBuffer frames to detect multiple gestures using
/// VNDetectHumanHandPoseRequest with normalized coordinates (0.0 to 1.0).
class GestureProcessor {
    
    // MARK: - Types
    
    enum GestureType: String {
        case None = "none"
        case Victory = "victory"
        case ThumbsUp = "thumbs_up"
        case ThumbsDown = "thumbs_down"
        case OpenPalm = "open_palm"
        case Fist = "fist"
        
        var emoji: String {
            switch self {
            case .None: return ""
            case .Victory: return "✌️"
            case .ThumbsUp: return "👍"
            case .ThumbsDown: return "👎"
            case .OpenPalm: return "✋"
            case .Fist: return "✊"
            }
        }
    }
    
    /// Result of gesture processing
    struct GestureResult {
        let detectedGesture: GestureType
        let confidence: Float
        let debugInfo: String
    }
    
    // MARK: - Properties
    
    /// Serial queue for Vision processing to prevent concurrent access
    private let processingQueue = DispatchQueue(
        label: "com.gesturelink.gesture.processing",
        qos: .userInteractive
    )
    
    /// Vision request for hand pose detection
    private lazy var handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        // Use latest revision for better accuracy
        request.revision = VNDetectHumanHandPoseRequestRevision1
        // Detect only one hand for simplicity
        request.maximumHandCount = 1
        return request
    }()
    
    /// Callback for gesture detection results
    var onGestureDetected: ((GestureResult) -> Void)?
    
    // MARK: - Configuration
    
    /// Threshold for considering fingers as "spread" apart
    private let spreadThreshold: Float = 0.05
    
    /// Confidence threshold for finger detection
    private let confidenceThreshold: Float = 0.3
    
    // MARK: - Processing
    
    /// Process a video frame for hand gesture detection
    /// - Parameter sampleBuffer: The CMSampleBuffer from camera capture
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        processingQueue.async { [weak self] in
            self?.performVisionRequest(on: pixelBuffer)
        }
    }
    
    /// Performs the Vision hand pose request on the pixel buffer
    private func performVisionRequest(on pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        
        do {
            try handler.perform([handPoseRequest])
            
            guard let observation = handPoseRequest.results?.first else {
                onGestureDetected?(GestureResult(
                    detectedGesture: .None,
                    confidence: 0,
                    debugInfo: "No hand detected"
                ))
                return
            }
            
            let result = analyzeHandPose(observation)
            onGestureDetected?(result)
            
        } catch {
            onGestureDetected?(GestureResult(
                detectedGesture: .None,
                confidence: 0,
                debugInfo: "Vision error: \(error.localizedDescription)"
            ))
        }
    }
    
    /// Analyzes hand pose observation to detect various gestures
    private func analyzeHandPose(_ observation: VNHumanHandPoseObservation) -> GestureResult {
        do {
            // Fingertips
            let thumbTip = try observation.recognizedPoint(.thumbTip)
            let indexTip = try observation.recognizedPoint(.indexTip)
            let middleTip = try observation.recognizedPoint(.middleTip)
            let ringTip = try observation.recognizedPoint(.ringTip)
            let littleTip = try observation.recognizedPoint(.littleTip)
            
            // Knuckles (MCP joints)
            let thumbIP = try observation.recognizedPoint(.thumbIP)
            let indexMCP = try observation.recognizedPoint(.indexMCP)
            let middleMCP = try observation.recognizedPoint(.middleMCP)
            let ringMCP = try observation.recognizedPoint(.ringMCP)
            let littleMCP = try observation.recognizedPoint(.littleMCP)
            
            // Wrist
            let wrist = try observation.recognizedPoint(.wrist)
            
            // Extension checks (Tip above corresponding knuckle)
            // Note: Vision coordinates have (0,0) at bottom-left
            let thumbExtended = thumbTip.confidence > confidenceThreshold && 
                               (thumbTip.location.y > thumbIP.location.y || abs(thumbTip.location.x - wrist.location.x) > 0.1)
            let indexExtended = indexTip.confidence > confidenceThreshold && indexTip.location.y > indexMCP.location.y
            let middleExtended = middleTip.confidence > confidenceThreshold && middleTip.location.y > middleMCP.location.y
            let ringExtended = ringTip.confidence > confidenceThreshold && ringTip.location.y > ringMCP.location.y
            let littleExtended = littleTip.confidence > confidenceThreshold && littleTip.location.y > littleMCP.location.y
            
            // Special check for Thumbs Down
            let thumbDown = thumbTip.confidence > confidenceThreshold && thumbTip.location.y < thumbIP.location.y
            
            // Spread between index and middle (for Victory sign)
            let indexMiddleDistance = euclideanDistance(
                from: indexTip.location,
                to: middleTip.location
            )
            
            // Gesture logic
            var detected: GestureType = .None
            var confidence: Float = 0
            
            if indexExtended && middleExtended && !ringExtended && !littleExtended && Float(indexMiddleDistance) > spreadThreshold {
                detected = .Victory
                confidence = Float(indexTip.confidence + middleTip.confidence) / 2.0
            } else if thumbExtended && !indexExtended && !middleExtended && !ringExtended && !littleExtended {
                detected = .ThumbsUp
                confidence = Float(thumbTip.confidence)
            } else if thumbDown && !indexExtended && !middleExtended && !ringExtended && !littleExtended {
                detected = .ThumbsDown
                confidence = Float(thumbTip.confidence)
            } else if indexExtended && middleExtended && ringExtended && littleExtended {
                detected = .OpenPalm
                confidence = Float(indexTip.confidence + middleTip.confidence + ringTip.confidence + littleTip.confidence) / 4.0
            } else if !indexExtended && !middleExtended && !ringExtended && !littleExtended && !thumbExtended {
                detected = .Fist
                confidence = Float(indexTip.confidence + middleTip.confidence + ringTip.confidence + littleTip.confidence) / 4.0
            }
            
            let debugInfo = "Gesture: \(detected.rawValue), Conf: \(confidence)"
            
            return GestureResult(
                detectedGesture: detected,
                confidence: confidence,
                debugInfo: debugInfo
            )
            
        } catch {
            return GestureResult(
                detectedGesture: .None,
                confidence: 0,
                debugInfo: "Vision extraction error"
            )
        }
    }
    
    private func euclideanDistance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
}


