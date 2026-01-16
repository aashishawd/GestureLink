import Foundation
import Network

/// UDPSender manages outbound UDP communication.
/// It uses Network.framework's high-performance NWConnection for low-latency messaging.
class UDPSender {
    
    // MARK: - Properties
    
    private var connection: NWConnection?
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "com.gesturelink.udp.sender", qos: .userInitiated)
    
    /// Reports whether the UDP connection is currently live.
    private(set) var isReady = false
    
    // MARK: - Initialization
    
    /// Initializes a sender for a specific target.
    /// - Parameters:
    ///   - host: Destination host (default: 127.0.0.1)
    ///   - port: Destination port (default: 8080)
    init(host: String = "127.0.0.1", port: UInt16 = 8080) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port) ?? 8080
    }
    
    // MARK: - Lifecycle Management
    
    /// Negotiates the UDP connection asynchronously.
    func connect() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(host: host, port: port, using: .udp)
            self.connection = connection
            
            // We use a shared state wrapper to ensure thread-safe one-time resumption
            class ContinuationState {
                var hasResumed = false
            }
            let state = ContinuationState()
            
            connection.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .ready:
                    self?.isReady = true
                    if !state.hasResumed {
                        state.hasResumed = true
                        continuation.resume()
                    }
                    
                case .failed(let error):
                    self?.isReady = false
                    if !state.hasResumed {
                        state.hasResumed = true
                        continuation.resume(throwing: error)
                    }
                    
                case .cancelled:
                    self?.isReady = false
                    
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
        }
    }
    
    /// Tears down the connection and releases resources.
    func disconnect() {
        connection?.cancel()
        connection = nil
        isReady = false
    }
    
    // MARK: - Transmission
    
    /// Sends a predefined victory signal.
    func sendVictoryDetected() async throws {
        try await sendMessage("victory_detected")
    }
    
    /// Sends an arbitrary UTF-8 encoded string over UDP.
    /// - Parameter message: The payload to transmit.
    func sendMessage(_ message: String) async throws {
        guard let connection = connection else {
            throw SenderError.notConnected
        }
        
        guard let data = message.data(using: .utf8) else {
            throw SenderError.encodingFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}

// MARK: - Errors

enum SenderError: Error, LocalizedError {
    case notConnected
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected: return "UDP connection not established"
        case .encodingFailed: return "Failed to encode message as UTF-8"
        }
    }
}
