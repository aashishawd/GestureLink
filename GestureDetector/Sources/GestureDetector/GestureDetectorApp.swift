import SwiftUI

/// GestureDetector - A macOS app for real-time Victory gesture detection
/// 
/// This app uses AVFoundation for camera capture at 30fps and Vision framework
/// for hand pose detection. When a Victory (peace sign) gesture is held for
/// 5 consecutive frames, it sends a UDP notification to a listener.
@main
struct GestureDetectorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 480)
        }
    }
}

