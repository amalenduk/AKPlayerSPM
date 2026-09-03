//
//  TestMediaListView.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 02/09/26.
//

import SwiftUI
import AKPlayer

public struct TestMediaListView: View {
    
    public var medias: [TestMedia]
    
    @State private var selectedMedia: TestMedia?
    @State private var playerMedia: TestMedia?
    
    public init(medias: [TestMedia] = sampleTestMedia) {
        self.medias = medias
    }
    
    public var body: some View {
        NavigationView {
            List(medias) { media in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(media.name)
                            .font(.headline)
                        if let url = media.url {
                            Text(url.host ?? url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button("Details") {
                            selectedMedia = media
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Test Media")
            .navigationBarTitleDisplayMode(.large)
            .listStyle(PlainListStyle())
            .sheet(item: $selectedMedia) { media in
                NavigationView {
                    VStack(alignment: .leading) {
                        Text(media.name)
                            .font(.title2)
                            .padding(.bottom, 8)
                        
                        ScrollView {
                            Text(media.note ?? "No notes available.")
                                .padding()
                        }
                        
                        if let langs = media.audioLanguages, !langs.isEmpty {
                            Text("Audio: " + langs.joined(separator: ", "))
                                .font(.footnote)
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Button("Play") {
                                selectedMedia = nil
                                
                                Task { @MainActor in
                                    await Task.yield()
                                    playerMedia = media
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                            
                            Button("Close") {
                                selectedMedia = nil
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .fullScreenCover(item: $playerMedia) { media in
                NavigationStack {
                    SimpleVideoPlayerView(
                        media: makeAKMedia(from: media),
                        autoPlay: false
                    )
                }
            }
        }
    }
}

struct TestMediaListView_Previews: PreviewProvider {
    static var previews: some View {
        TestMediaListView()
    }
}
