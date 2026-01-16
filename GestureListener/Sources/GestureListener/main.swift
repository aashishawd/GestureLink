import Foundation

/// GestureListener - A high-performance macOS signal receiver.
/// 
/// This tool acts as a lightweight sink for gesture detection events.
/// It uses Network.framework to efficiently handle incoming UDP traffic.

print("""
──────────────────────────────────────────────────────────
           🌟 GestureLink Listener v1.1 🌟
──────────────────────────────────────────────────────────
📡 System: macOS
🔗 Protocol: UDP
🚪 Port: 8080
──────────────────────────────────────────────────────────
""")

// Graceful termination handler
signal(SIGINT) { _ in
    print("\n\n🛑 Shutting down listener. Goodbye!")
    exit(0)
}

do {
    let listener = try UDPListener(port: 8080)
    
    // Launch listener in a dedicated Task
    Task {
        do {
            try await listener.start()
        } catch {
            print("❌ Runtime Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    // Park the main thread in the RunLoop for event delivery
    RunLoop.main.run()
} catch {
    print("❌ Critical Initialization Error: \(error.localizedDescription)")
    exit(1)
}
