//
//  BarcodeScannerViewModel.swift
//  VisionTester
//

import Foundation
import AVFoundation
import UIKit
import Vision

@MainActor
class BarcodeScannerViewModel: NSObject, ObservableObject {
    @Published var scannedBarcodes: [BarcodeItem] = []
    @Published var showingCamera = false
    @Published var showingPhotoPicker = false
    @Published var errorMessage: String?
    
    // Camera session
    private var captureSession: AVCaptureSession?
    private let videoOutput = AVCaptureVideoDataOutput()
    
    // MARK: - Camera Setup
    
    func setupCamera() -> AVCaptureSession? {
        print("📷 Setting up camera...")
        
        // Return existing session if already set up
        if let existingSession = captureSession {
            print("📷 Returning existing camera session")
            return existingSession
        }
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ Unable to access camera device")
            errorMessage = "Unable to access camera"
            return nil
        }
        
        print("📷 Camera device found: \(videoCaptureDevice.localizedName)")
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            print("📷 Video input created successfully")
        } catch {
            print("❌ Unable to initialize camera: \(error.localizedDescription)")
            errorMessage = "Unable to initialize camera: \(error.localizedDescription)"
            return nil
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            print("📷 Video input added to session")
        } else {
            print("❌ Could not add video input to session")
            errorMessage = "Could not add video input to session"
            return nil
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            print("📷 Video output added to session")
        } else {
            print("❌ Could not add video output to session")
            errorMessage = "Could not add video output to session"
            return nil
        }
        
        captureSession = session
        print("✅ Camera setup complete")
        return session
    }
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 Camera authorization status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("📷 Camera already authorized")
            completion(true)
        case .notDetermined:
            print("📷 Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    print("📷 Camera permission granted: \(granted)")
                    completion(granted)
                }
            }
        case .denied, .restricted:
            print("📷 Camera access denied or restricted")
            completion(false)
        @unknown default:
            print("📷 Unknown camera authorization status")
            completion(false)
        }
    }
    
    func startScanning() {
        print("📷 Starting camera scanning...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            print("📷 Camera session started running")
        }
    }
    
    func stopScanning() {
        print("📷 Stopping camera scanning...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
            print("📷 Camera session stopped")
        }
    }
    
    // MARK: - Image Processing
    
    func scanBarcodeFromImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            errorMessage = "Unable to process image"
            return
        }
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.errorMessage = "Error scanning image: \(error.localizedDescription)"
                }
                return
            }
            
            guard let results = request.results as? [VNBarcodeObservation],
                  let firstBarcode = results.first else {
                Task { @MainActor in
                    self.errorMessage = "No barcode found in image"
                }
                return
            }
            
            Task { @MainActor in
                self.handleDetectedBarcode(firstBarcode)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                Task { @MainActor in
                    self.errorMessage = "Failed to perform barcode detection: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Barcode Handling
    
    private func handleDetectedBarcode(_ barcode: VNBarcodeObservation) {
        guard let payloadString = barcode.payloadStringValue else { return }
        
        let barcodeType = barcode.symbology.rawValue
        let barcodeItem = BarcodeItem(value: payloadString, type: barcodeType)
        
        scannedBarcodes.insert(barcodeItem, at: 0)
        
        // Close camera or photo picker after successful scan
        showingCamera = false
        showingPhotoPicker = false
        stopScanning()
    }
    
    func clearBarcodes() {
        scannedBarcodes.removeAll()
    }
    
    func openCamera() {
        requestCameraPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.showingCamera = true
            } else {
                self.errorMessage = "Camera access denied. Please enable camera access in Settings."
            }
        }
    }
    
    func openPhotoPicker() {
        showingPhotoPicker = true
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension BarcodeScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNBarcodeObservation],
                  let firstBarcode = results.first else { return }
            
            Task { @MainActor in
                self.handleDetectedBarcode(firstBarcode)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform barcode detection: \(error)")
        }
    }
}
