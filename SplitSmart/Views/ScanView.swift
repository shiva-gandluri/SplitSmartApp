import SwiftUI
import UIKit
import AVFoundation
import Photos

// MARK: - Camera Permission Manager
class CameraPermissionManager: ObservableObject {
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert = false
    @Published var permissionMessage = ""
    
    init() {
        checkCameraPermission()
        checkPhotoLibraryPermission()
    }
    
    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func checkPhotoLibraryPermission() {
        photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus()
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.cameraPermissionStatus = granted ? .authorized : .denied
                if !granted {
                    self?.showCameraPermissionDeniedAlert()
                }
            }
        }
    }
    
    func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.photoLibraryPermissionStatus = status
                if status != .authorized && status != .limited {
                    self?.showPhotoLibraryPermissionDeniedAlert()
                }
            }
        }
    }
    
    private func showCameraPermissionDeniedAlert() {
        permissionMessage = "Camera access is required to scan receipts. Please enable camera access in Settings > Privacy & Security > Camera > SplitSmart."
        showPermissionAlert = true
    }
    
    private func showPhotoLibraryPermissionDeniedAlert() {
        permissionMessage = "Photo library access is required to upload receipt images. Please enable photo access in Settings > Privacy & Security > Photos > SplitSmart."
        showPermissionAlert = true
    }
    
    var canUsePhotoLibrary: Bool {
        switch photoLibraryPermissionStatus {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return true
        default:
            return false
        }
    }
}

// MARK: - Camera Capture View
struct CameraCapture: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        
        // Configure media types for JPEG/PNG only
        picker.mediaTypes = ["public.image"]
        
        if sourceType == .camera {
            picker.cameraDevice = .rear
            picker.cameraCaptureMode = .photo
        } else if sourceType == .photoLibrary {
            // Additional configuration for photo library
            picker.modalPresentationStyle = .fullScreen
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCapture
        
        init(_ parent: CameraCapture) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Image Preview View
struct ImagePreview: View {
    let image: UIImage
    let onRetake: () -> Void
    let onConfirm: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with actions
            HStack {
                Button("Retake") {
                    onRetake()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Use Photo") {
                    onConfirm()
                }
                .foregroundColor(.blue)
                .fontWeight(.semibold)
            }
            .padding()
            
            // Image preview with zoom and pan
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 0.5), 3.0) // Limit zoom between 0.5x and 3x
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            scale = 1.0
                        }
                    }
            }
            .frame(height: 400)
            .padding(.horizontal)
            .clipped()
            
            // Zoom instructions
            Text("Double tap to reset • Pinch to zoom")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button(action: onConfirm) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Use This Photo")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: onRetake) {
                    HStack {
                        Image(systemName: "camera.rotate")
                        Text("Retake Photo")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Permission Alert Extension
extension View {
    func permissionAlert(isPresented: Binding<Bool>, message: String) -> some View {
        self.alert("Permission Required", isPresented: isPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        } message: {
            Text(message)
        }
    }
}

struct UIScanScreen: View {
    let onContinue: () -> Void
    
    @State private var scanComplete = false
    @State private var scanningStatus = ""
    @State private var capturedImage: UIImage?
    @State private var showingImagePreview = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @StateObject private var permissionManager = CameraPermissionManager()
    
    let mockReceiptItems = [
        ("Pasta Carbonara", 16.95),
        ("Caesar Salad", 12.50),
        ("Garlic Bread", 5.95),
        ("Tiramisu", 8.75)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Scan Receipt")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                if showingImagePreview, let image = capturedImage {
                    ImagePreview(
                        image: image,
                        onRetake: handleRetakePhoto,
                        onConfirm: handleImageConfirmed
                    )
                } else if !scanComplete {
                    ScanInputSection(
                        scanningStatus: scanningStatus,
                        onScan: handleScanReceipt,
                        onUpload: handlePhotoLibrary
                    )
                } else {
                    ReceiptResultSection(
                        mockReceiptItems: mockReceiptItems,
                        onContinue: onContinue
                    )
                }
            }
            .padding(.top)
        }
        .sheet(isPresented: $showingCamera) {
            CameraCapture(
                isPresented: $showingCamera,
                capturedImage: $capturedImage,
                sourceType: .camera
            )
            .onDisappear {
                if capturedImage != nil {
                    handleImageCaptured()
                }
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            CameraCapture(
                isPresented: $showingPhotoLibrary,
                capturedImage: $capturedImage,
                sourceType: .photoLibrary
            )
            .onDisappear {
                if capturedImage != nil {
                    handleImageCaptured()
                }
            }
        }
        .permissionAlert(
            isPresented: $permissionManager.showPermissionAlert,
            message: permissionManager.permissionMessage
        )
        .onAppear {
            permissionManager.checkCameraPermission()
            permissionManager.checkPhotoLibraryPermission()
        }
    }
    
    private func handleScanReceipt() {
        // Check camera permission before proceeding
        switch permissionManager.cameraPermissionStatus {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            permissionManager.requestCameraPermission()
            // Wait for permission result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if permissionManager.cameraPermissionStatus == .authorized {
                    showingCamera = true
                }
            }
        case .denied, .restricted:
            permissionManager.showPermissionAlert = true
        @unknown default:
            permissionManager.showPermissionAlert = true
        }
    }
    
    private func handlePhotoLibrary() {
        // Check photo library permission before proceeding
        switch permissionManager.photoLibraryPermissionStatus {
        case .authorized, .limited:
            showingPhotoLibrary = true
        case .notDetermined:
            permissionManager.requestPhotoLibraryPermission()
            // Wait for permission result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.permissionManager.canUsePhotoLibrary {
                    self.showingPhotoLibrary = true
                }
            }
        case .denied, .restricted:
            permissionManager.showPermissionAlert = true
        @unknown default:
            permissionManager.showPermissionAlert = true
        }
    }
    
    private func handleImageCaptured() {
        showingImagePreview = true
    }
    
    private func handleImageConfirmed() {
        showingImagePreview = false
        // Start processing the captured image
        scanningStatus = "processing"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            scanComplete = true
            scanningStatus = "complete"
        }
    }
    
    private func handleRetakePhoto() {
        capturedImage = nil
        showingImagePreview = false
        showingCamera = true
    }
}

// MARK: - Supporting Views

struct ScanInputSection: View {
    let scanningStatus: String
    let onScan: () -> Void
    let onUpload: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Camera area
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundColor(.gray)
                .background(Color.gray.opacity(0.05))
                .frame(height: 350)
                .overlay(
                    VStack(spacing: 16) {
                        if scanningStatus.isEmpty {
                            CameraInputView(onScan: onScan, onUpload: onUpload)
                        } else {
                            ScanningProgressView(status: scanningStatus)
                        }
                    }
                )
                .padding(.horizontal)
            
            ScanTipsView()
        }
    }
}

struct CameraInputView: View {
    let onScan: () -> Void
    let onUpload: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Take a photo of your receipt or upload from gallery")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Primary action: Take Photo
                Button(action: onScan) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                // Secondary action: Upload from Gallery
                Button(action: onUpload) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Upload from Gallery")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct ScanningProgressView: View {
    let status: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(2)
                .padding()
            
            Text(status == "scanning" ? "Scanning receipt..." : "Processing items...")
                .foregroundColor(.secondary)
        }
    }
}

struct ScanTipsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tips for best results:")
                .fontWeight(.medium)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Ensure good lighting")
                Text("• Place receipt on a flat surface")
                Text("• Make sure all items are visible")
                Text("• Hold the camera steady")
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ReceiptResultSection: View {
    let mockReceiptItems: [(String, Double)]
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            SuccessMessageView()
            ReceiptItemsView(items: mockReceiptItems)
            
            Button(action: onContinue) {
                HStack {
                    Text("Continue to Assign Items")
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

struct SuccessMessageView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Receipt Scanned Successfully!")
                .fontWeight(.medium)
                .foregroundColor(.green)
            
            Text("We've identified the following items:")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ReceiptItemsView: View {
    let items: [(String, Double)]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0)
                    Spacer()
                    Text("$\(item.1, specifier: "%.2f")")
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3)),
                    alignment: .bottom
                )
            }
            
            ReceiptTotalSection()
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct ReceiptTotalSection: View {
    var body: some View {
        VStack(spacing: 0) {
            ReceiptTotalRow(label: "Subtotal", amount: "$44.15")
            ReceiptTotalRow(label: "Tax", amount: "$3.53")
            ReceiptTotalRow(label: "Tip (18%)", amount: "$7.95")
            
            HStack {
                Text("Total")
                    .fontWeight(.bold)
                Spacer()
                Text("$55.63")
                    .fontWeight(.bold)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
        }
    }
}

struct ReceiptTotalRow: View {
    let label: String
    let amount: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(amount)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
}