import SwiftUI
import UIKit
import AVFoundation
import Photos
import Vision

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
    @State private var showingOCRResults = false
    @State private var ocrResult: OCRResult?
    @StateObject private var permissionManager = CameraPermissionManager()
    @StateObject private var ocrService = OCRService()
    
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
                
                if showingOCRResults, let result = ocrResult {
                    OCRResultsView(
                        items: result.parsedItems,
                        rawText: result.rawText,
                        confidence: result.confidence,
                        onContinue: { items in
                            // Convert OCR items to final receipt items and continue
                            onContinue()
                        },
                        onRetry: handleRetryOCR
                    )
                } else if showingImagePreview, let image = capturedImage {
                    ImagePreview(
                        image: image,
                        onRetake: handleRetakePhoto,
                        onConfirm: handleImageConfirmed
                    )
                } else if ocrService.isProcessing {
                    OCRProcessingView(
                        progress: ocrService.progress,
                        status: scanningStatus
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
        
        guard let image = capturedImage else { return }
        
        // Start OCR processing
        scanningStatus = "Processing image with OCR..."
        
        Task {
            let result = await ocrService.processImage(image)
            
            await MainActor.run {
                self.ocrResult = result
                self.showingOCRResults = true
                self.scanningStatus = ""
            }
        }
    }
    
    private func handleRetakePhoto() {
        capturedImage = nil
        showingImagePreview = false
        showingCamera = true
    }
    
    private func handleRetryOCR() {
        showingOCRResults = false
        ocrResult = nil
        showingImagePreview = false
        capturedImage = nil
        scanningStatus = ""
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

// MARK: - OCR Processing View
struct OCRProcessingView: View {
    let progress: Float
    let status: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                // OCR Icon with animation
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    Text("Processing Receipt")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(status.isEmpty ? "Extracting text from image..." : status)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Progress indicator
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(width: 200)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Processing tips
            VStack(alignment: .leading, spacing: 8) {
                Text("OCR Processing Tips:")
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Better lighting improves text recognition")
                    Text("• Clear, uncrumpled receipts work best")
                    Text("• Processing may take a few seconds")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - OCR Results View
struct OCRResultsView: View {
    @State var items: [ReceiptItem]
    let rawText: String
    let confidence: Float
    let onContinue: ([ReceiptItem]) -> Void
    let onRetry: () -> Void
    
    @State private var showRawText = false
    @State private var showingManualEntry = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with confidence indicator
            OCRHeaderView(
                confidence: confidence,
                itemCount: items.count,
                showRawText: $showRawText
            )
            
            if items.isEmpty {
                // No items found - show manual entry option
                OCREmptyStateView(
                    onManualEntry: { showingManualEntry = true },
                    onRetry: onRetry
                )
            } else {
                // Items found - show editable list
                OCRItemListView(
                    items: $items,
                    onContinue: { onContinue(items) }
                )
            }
        }
        .sheet(isPresented: $showRawText) {
            RawTextView(text: rawText)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualItemEntryView { newItem in
                items.append(newItem)
            }
        }
    }
}

// MARK: - OCR Header View
struct OCRHeaderView: View {
    let confidence: Float
    let itemCount: Int
    @Binding var showRawText: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan Results")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(itemCount) items found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    ConfidenceIndicator(confidence: confidence)
                    
                    Button("View Raw Text") {
                        showRawText = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            
            Divider()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Confidence Indicator
struct ConfidenceIndicator: View {
    let confidence: Float
    
    var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
    
    var confidenceText: String {
        switch confidence {
        case 0.8...1.0: return "High"
        case 0.5..<0.8: return "Medium"
        default: return "Low"
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text("\(confidenceText) Confidence")
                .font(.caption)
                .foregroundColor(confidenceColor)
        }
    }
}

// MARK: - OCR Item List View
struct OCRItemListView: View {
    @Binding var items: [ReceiptItem]
    let onContinue: () -> Void
    
    var totalAmount: Double {
        items.reduce(0) { $0 + $1.price }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Review and edit the detected items below. Tap to modify or swipe to delete.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGroupedBackground))
            
            List {
                ForEach(items.indices, id: \.self) { index in
                    EditableItemRow(
                        item: $items[index],
                        onDelete: {
                            items.remove(at: index)
                        }
                    )
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(PlainListStyle())
            
            VStack(spacing: 16) {
                HStack {
                    Text("Total")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("$\(totalAmount, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                Button(action: onContinue) {
                    HStack {
                        Text("Continue to Split")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(items.isEmpty)
            }
            .padding(.vertical)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

// MARK: - Editable Item Row
struct EditableItemRow: View {
    @Binding var item: ReceiptItem
    let onDelete: () -> Void
    
    @State private var isEditing = false
    @State private var editName = ""
    @State private var editPrice = ""
    
    var body: some View {
        HStack {
            if isEditing {
                VStack(spacing: 8) {
                    TextField("Item name", text: $editName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Text("$")
                        TextField("0.00", text: $editPrice)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                VStack(spacing: 8) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(.blue)
                    .font(.caption)
                    
                    Button("Cancel") {
                        cancelEditing()
                    }
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(2)
                    
                    Text("Tap to edit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("$\(item.price, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .onTapGesture {
            if !isEditing {
                startEditing()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
    
    private func startEditing() {
        editName = item.name
        editPrice = String(format: "%.2f", item.price)
        isEditing = true
    }
    
    private func saveChanges() {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty, let price = Double(editPrice), price > 0 {
            item.name = trimmedName
            item.price = price
        }
        isEditing = false
    }
    
    private func cancelEditing() {
        isEditing = false
    }
}

// MARK: - OCR Empty State View
struct OCREmptyStateView: View {
    let onManualEntry: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("No Items Detected")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("The OCR couldn't identify any items from the receipt. You can try taking another photo or add items manually.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button(action: onManualEntry) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Items Manually")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "camera.rotate")
                        Text("Try Another Photo")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Raw Text View
struct RawTextView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(text.isEmpty ? "No text was detected from the image." : text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Raw OCR Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Manual Item Entry View
struct ManualItemEntryView: View {
    let onAdd: (ReceiptItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemName = ""
    @State private var itemPrice = ""
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add New Item")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Item Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter item name", text: $itemName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isNameFieldFocused)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text("$")
                                .font(.body)
                            TextField("0.00", text: $itemPrice)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                Button(action: addItem) {
                    Text("Add Item")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canAddItem ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .padding()
                .disabled(!canAddItem)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
    }
    
    private var canAddItem: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(itemPrice) != nil &&
        Double(itemPrice)! > 0
    }
    
    private func addItem() {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let price = Double(itemPrice), price > 0 {
            let newItem = ReceiptItem(name: trimmedName, price: price)
            onAdd(newItem)
            dismiss()
        }
    }
}