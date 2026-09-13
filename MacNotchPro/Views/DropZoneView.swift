//
//  DropZoneView.swift
//  MiniPad
//

import SwiftUI

struct DropZoneView: View {
    let urls: [URL]
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                )
            
            VStack(spacing: 4) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
                
                Text("Drop Zone")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        .frame(width: 160, height: 48)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct TextContentView: View {
    let text: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "text.quote")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
            
            Text(text)
                .font(.system(size: 10, weight: .regular))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(width: 160, height: 48)
    }
}

