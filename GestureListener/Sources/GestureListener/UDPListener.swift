import Foundation
import Network

/// UDPListener listens for incoming UDP packets on a specified port using Network.framework.
/// It uses NWListener to handle incoming connections and process data.
class UDPListener {
    
    // MARK: - Properties
    
    private let listener: NWListener
    private let port: NWEndpoint.Port
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.gesturelink.listener")
    
    // MARK: - Initialization
    
    /// Creates a new UDP listener on the specified port.
    /// - Parameter port: The port number to listen on (default: 8080)
    /// - Throws: An error if the listener cannot be created
    init(port: UInt16 = 8080) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ListenerError.invalidPort
        }
        self.port = nwPort
        
        // Configure UDP parameters
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        self.listener = try NWListener(using: parameters, on: nwPort)
    }
    
    // MARK: - Public Methods
    
    /// Starts listening for incoming UDP packets.
    /// This method sets up the listener and begins accepting connections.
    func start() async throws {
        guard !isRunning else { return }
        isRunning = true
        
        print("🎧 Listening for UDP packets on port \(port.rawValue)...")
        print("   Waiting for gesture detection signals...\n")
        
        // Set up state update handler
        listener.stateUpdateHandler = { [weak self] state in
            self?.handleStateUpdate(state)
        }
        
        // Set up new connection handler
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        
        // Start the listener on our dedicated queue
        listener.start(queue: queue)
        
        // Keep the listener running indefinitely
        await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in
            // This continuation is intentionally never resumed to keep the listener running
            // The listener will run until the process is terminated
        }
    }
    
    /// Stops the listener and releases resources.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        listener.cancel()
        print("\n🛑 Listener stopped.")
    }
    
    // MARK: - Private Methods
    
    private func handleStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("✅ Listener ready and accepting connections")
        case .failed(let error):
            print("❌ Listener failed with error: \(error.localizedDescription)")
        case .cancelled:
            print("⚠️  Listener cancelled")
        default:
            break
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(from: connection)
            case .failed(let error):
                print("❌ Connection failed: \(error.localizedDescription)")
                connection.cancel()
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("❌ Receive error: \(error.localizedDescription)")
                return
            }
            
            if let data = data, !data.isEmpty {
                self?.processReceivedData(data)
            }
            
            if isComplete {
                connection.cancel()
            } else {
                // Continue receiving data
                self?.receiveData(from: connection)
            }
        }
    }
    
    private func processReceivedData(_ data: Data) {
        guard let message = String(data: data, encoding: .utf8) else {
            print("⚠️  Received non-UTF8 data")
            return
        }
        
        let gestureName = message.replacingOccurrences(of: "_detected", with: "")
        
        // Format timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        // Map gesture to emoji for the console
        let emoji: String
        switch gestureName {
        case "victory": emoji = "✌️"
        case "thumbs_up": emoji = "👍"
        case "thumbs_down": emoji = "👎"
        case "open_palm": emoji = "✋"
        case "fist": emoji = "✊"
        default: emoji = "❓"
        }
        
        // Display formatted output
        print("[\(timestamp)] \(emoji) Gesture Received: \(gestureName.capitalized)")
        print("   Triggering System Reaction for \(gestureName)...")
        print("")
    }

}

// MARK: - Error Types

enum ListenerError: Error, LocalizedError {
    case invalidPort
    
    var errorDescription: String? {
        switch self {
        case .invalidPort:
            return "Invalid port number specified"
        }
    }
}

