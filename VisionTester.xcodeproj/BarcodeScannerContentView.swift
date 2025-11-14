//
//  ContentView.swift
//  BarcodeScanner
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BarcodeScannerViewModel()
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Camera or scanning view
                if viewModel.showingCamera {
                    cameraViewSection
                } else {
                    // Main controls
                    controlsSection
                    
                    // Barcode list
                    barcodeListSection
                }
            }
            .navigationTitle("Barcode Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showingPhotoPicker) {
                PhotoPicker(selectedImage: $selectedImage)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    viewModel.scanBarcodeFromImage(image)
                    selectedImage = nil
                }
            }
        }
    }
    
    // MARK: - Camera View Section
    
    private var cameraViewSection: some View {
        ZStack {
            if let session = viewModel.setupCamera() {
                CameraView(session: session)
                    .onAppear {
                        viewModel.startScanning()
                    }
                    .onDisappear {
                        viewModel.stopScanning()
                    }
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    Button {
                        viewModel.showingCamera = false
                        viewModel.stopScanning()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.black.opacity(0.7))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 40)
                }
            } else {
                Text("Unable to access camera")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Controls Section
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            Text("Scan a barcode")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            
            HStack(spacing: 20) {
                Button {
                    viewModel.openCamera()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                        Text("Camera")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    viewModel.openPhotoPicker()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 40))
                        Text("Photos")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    // MARK: - Barcode List Section
    
    private var barcodeListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Scanned Barcodes")
                    .font(.headline)
                    .padding(.horizontal)
                
                Spacer()
                
                if !viewModel.scannedBarcodes.isEmpty {
                    Button {
                        withAnimation {
                            viewModel.clearBarcodes()
                        }
                    } label: {
                        Text("Clear All")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            if viewModel.scannedBarcodes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("No barcodes scanned yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.scannedBarcodes) { barcode in
                            BarcodeRow(barcode: barcode)
                            Divider()
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Barcode Row View

struct BarcodeRow: View {
    let barcode: BarcodeItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "barcode")
                    .foregroundStyle(.blue)
                
                Text(barcode.value)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack {
                Text("Type: \(barcode.type)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(barcode.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
}
