import SwiftUI
import AVFoundation

struct ScanView: View {
    @State private var showDetail = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("📷 Scan View")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("This is a placeholder for the Scan feature.")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Button(action: {
                    showDetail = true
                }) {
                    Text("Scan QR code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .navigationDestination(isPresented: $showDetail) {
                    ScanDetailView()
                }
            }
            .padding()
        }
    }
}

struct ScanDetailView: View {
    @Environment(\.dismiss) private var dismiss  // To navigate back
    @State private var cameraPermissionGranted = false
    
    var body: some View {
        ZStack {
            if cameraPermissionGranted {
                CameraPreview()
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack {
                    Text("Camera Access Needed")
                        .font(.title)
                        .foregroundColor(.red)
                        .padding()
                    
                    Button("Grant Access") {
                        requestCameraPermission()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            checkCameraPermission()
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            requestCameraPermission()
        default:
            cameraPermissionGranted = false
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermissionGranted = granted
            }
        }
    }
}

// Camera preview wrapper
struct CameraPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController {
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        captureSession.addInput(input)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.layer.bounds
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}
