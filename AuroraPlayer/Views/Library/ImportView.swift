//
//  ImportView.swift
//  AuroraPlayer
//
//  "Local Import" — uses the system file importer so the user can pull audio
//  files in from Files.app, iCloud Drive, or any third-party file provider
//  (no special entitlement needed beyond the default file-picker access).
//

import SwiftUI

struct ImportView: View {
    @EnvironmentObject var library: LibraryManager
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Import Music")
                .font(.title2.bold())

            Text("Bring in MP3, M4A, WAV, or AIFF files from Files, iCloud Drive, or any connected file provider.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if library.isImporting {
                ProgressView(value: Double(library.importProgress.done), total: Double(max(library.importProgress.total, 1)))
                    .padding(.horizontal, 40)
                Text("Importing \(library.importProgress.done) of \(library.importProgress.total)…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Choose Files", systemImage: "folder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: LibraryManager.importableTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await library.importFiles(from: urls) }
            case .failure(let error):
                print("File import cancelled or failed: \(error.localizedDescription)")
            }
        }
    }
}
