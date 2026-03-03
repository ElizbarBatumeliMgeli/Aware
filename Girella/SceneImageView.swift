//
//  SceneImageView.swift
//  Girella
//
//

import SwiftUI

struct SceneImageBubble: View {
    let imageName: String
    @State private var isPresented = false
    
    var body: some View {
        Button {
            isPresented = true
        } label: {
            // The actual image
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .clipped()
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(G.dim.opacity(0.15), lineWidth: 1)
                )
        }
        .padding(.horizontal, 24) // Small spacing on left and right
        .padding(.vertical, 4)
        .fullScreenCover(isPresented: $isPresented) {
            ZoomableImageView(imageName: imageName) {
                isPresented = false
            }
        }
    }
}

// MARK: ─── Fullscreen Zoomable View ───

struct ZoomableImageView: View {
    let imageName: String
    let onClose: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // The Image inside the zoom viewer
            Image(imageName)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            let delta = val / lastScale
                            lastScale = val
                            scale = min(max(scale * delta, 1), 5) // Max zoom 5x
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1 {
                                withAnimation(.spring()) {
                                    scale = 1
                                    offset = .zero
                                }
                            }
                        }
                        .simultaneously(with: DragGesture()
                            .onChanged { val in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + val.translation.width,
                                        height: lastOffset.height + val.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                        )
                )
                .gesture(
                    TapGesture(count: 2).onEnded {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }
                )
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.white.opacity(0.8))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
    }
}
