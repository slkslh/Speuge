import SwiftUI
import AppKit

public struct AboutView: View {
    public init() {}
    
    public var body: some View {
        Form {
            VStack(spacing: 12) {
                AppIconView(size: 64, showShadow: true)
                    .padding(.top, 4)
                
                Text("Network Speed")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("Version 1.0.0 (Build 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("Engineered for macOS with native SwiftUI and Darwin route sockets.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            Section("Specifications & Engine") {
                LabeledContent {
                    Text(systemArchitecture)
                        .font(.body)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Architecture", badge: "cpu", color: .purple)
                }
                
                LabeledContent {
                    Text("BSD Route Sockets")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Telemetry Core", badge: "bolt.fill", color: .blue)
                }
                
                LabeledContent {
                    Text("Nettop & Darwin Libproc")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Analytics Engine", badge: "waveform.path.ecg", color: .orange)
                }
                
                LabeledContent {
                    Text("SwiftUI & AppKit")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("User Interface", badge: "macwindow", color: .teal)
                }
            }
            
            Section {
                HStack {
                    Label("Documentation & Source", badge: "safari.fill", color: .blue)
                    Spacer()
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    Label("Reset Current Session", badge: "arrow.counterclockwise.circle.fill", color: .orange)
                    Spacer()
                    Button("Reset Session") {
                        NetworkStats.shared.resetSession()
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("Resources & Actions")
                    .font(.headline)
            } footer: {
                Text("Copyright © 2026. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
    }
    
    private var systemArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Universal Binary"
        #endif
    }
}
