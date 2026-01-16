import SwiftUI
import AVFoundation

/// Main content view displaying camera preview and gesture detection status
struct ContentView: View {
    @StateObject private var viewModel = GestureDetectorViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            // Camera preview layer
            CameraPreviewView(session: viewModel.cameraManager.captureSession)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.1))
            
            // Overlay UI
            VStack {
                // Status bar at top
                statusBar
                    .padding()
                
                Spacer()
                
                // Detection indicator at bottom
                detectionIndicator
                    .padding(.bottom, 40)
            }
            
            #if os(iOS)
            // Settings button for iOS
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding()
                }
                Spacer()
            }
            #endif
        }
        .onAppear {
            viewModel.startDetection()
        }
        .onDisappear {
            viewModel.stopDetection()
        }
        .sheet(isPresented: $showingSettings) {
            #if os(iOS)
            SettingsView(ipAddress: $viewModel.hostIP)
            #endif
        }
        .alert("Camera Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }
    
    // MARK: - UI Components
    
    private var statusBar: some View {
        HStack(spacing: 12) {
            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: (viewModel.isConnected ? Color.green : Color.red).opacity(0.5), radius: 4)
                
                Text(viewModel.isConnected ? "CONNECTED" : "DISCONNECTED")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            #if os(iOS)
            Text(viewModel.hostIP)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            #endif
            
            // Camera status
            Image(systemName: viewModel.cameraManager.isRunning ? "video.fill" : "video.slash.fill")
                .foregroundColor(viewModel.cameraManager.isRunning ? .green : .red)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 10)
    }
    
    private var detectionIndicator: some View {
        VStack(spacing: 20) {
            // Gesture icon
            ZStack {
                Circle()
                    .fill(viewModel.detectedGesture != .None ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(viewModel.detectedGesture != .None ? Color.green : Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 120, height: 120)
                
                Text(viewModel.detectedGesture.emoji.isEmpty ? "✋" : viewModel.detectedGesture.emoji)
                    .font(.system(size: 60))
                    .opacity(viewModel.detectedGesture == .None ? 0.3 : 1.0)
            }
            .scaleEffect(viewModel.detectedGesture != .None ? 1.1 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: viewModel.detectedGesture)
            
            VStack(spacing: 8) {
                Text(viewModel.detectedGesture == .None ? "READY" : viewModel.detectedGesture.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Progress bar for debounce
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 240, height: 6)
                    
                    Capsule()
                        .fill(LinearGradient(colors: [.green, .emerald], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 240 * CGFloat(viewModel.debounceProgress), height: 6)
                }
                
                Text(viewModel.debounceProgress > 0 ? "HOLDING: \(Int(viewModel.debounceProgress * 100))%" : "WAITING FOR GESTURE")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Last trigger time
            if let lastTrigger = viewModel.lastTriggerTime {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Sent at \(lastTrigger, formatter: timeFormatter)")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
            }
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SS"
        return formatter
    }
}

extension Color {
    static let emerald = Color(red: 0.1, green: 0.8, blue: 0.4)
}

// MARK: - Camera Preview Wrappers

#if os(macOS)
typealias PreviewRepresentable = NSViewRepresentable
#else
typealias PreviewRepresentable = UIViewRepresentable
#endif

struct CameraPreviewView: PreviewRepresentable {
    let session: AVCaptureSession
    
    #if os(macOS)
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.session = session
        return view
    }
    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}
    #else
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
    #endif
}

#if os(macOS)
class CameraPreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var session: AVCaptureSession? { didSet { setupPreviewLayer() } }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    private func setupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()
        guard let session = session else { return }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer?.addSublayer(layer)
        self.previewLayer = layer
    }
    
    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
#else
class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var session: AVCaptureSession? { didSet { setupPreviewLayer() } }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    private func setupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()
        guard let session = session else { return }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.previewLayer = layer
    }
}

struct SettingsView: View {
    @Binding var ipAddress: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Network Connection")) {
                    TextField("Mac IP Address", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif


