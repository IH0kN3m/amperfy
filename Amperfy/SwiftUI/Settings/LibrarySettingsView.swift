//
//  LibrarySettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import SwiftUI
import AmperfyKit

struct LibrarySettingsView: View {
    
    @EnvironmentObject private var settings: Settings
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let fileManager = CacheFileManager.shared
    
    @State var playlistCount = 0
    @State var artistCount = 0
    @State var albumCount = 0
    @State var songCount = 0
    @State var podcastCount = 0
    @State var podcastEpisodeCount = 0
    @State var albumWithSyncedSongsCount = 0
    @State var cachedSongCount = 0
    @State var cachedPodcastEpisodesCount = 0
    @State var completeCacheSize = ""
    @State var cacheSizeLimit = ""
    @State var cacheSelection = ["0", " MB"]
    @State var autoSyncProgressText = ""
    
    @State var isShowDeleteCacheAlert = false
    @State var isShowDownloadSongsAlert = false
    @State var isShowResyncLibraryAlert = false
    
    let byteValues = (stride(from: 0, through: 20, by: 1).map({$0.description}) +
                      stride(from: 25, through: 50, by: 5).map({$0.description}) +
                      stride(from: 60, through: 100, by: 10).map({$0.description}) +
                      stride(from: 110, through: 975, by: 25).map({$0.description}))
    
    private func updateValues() {
        appDelegate.storage.async.perform { asyncCompanion in
            self.playlistCount = asyncCompanion.library.playlistCount
            self.artistCount = asyncCompanion.library.artistCount
            self.albumCount = asyncCompanion.library.albumCount
            self.podcastCount = asyncCompanion.library.podcastCount
            self.podcastEpisodeCount = asyncCompanion.library.podcastEpisodeCount
            self.songCount = asyncCompanion.library.songCount
            self.albumWithSyncedSongsCount = asyncCompanion.library.albumWithSyncedSongsCount
            if albumCount < 1 {
                self.autoSyncProgressText = String(format: "%.1f", 0.0) + "%"
            } else {
                let progress = Float(albumWithSyncedSongsCount) * 100.0 / Float(albumCount)
                self.autoSyncProgressText = String(format: "%.1f", progress) + "%"
            }
            self.cachedSongCount = asyncCompanion.library.cachedSongCount
            self.cachedPodcastEpisodesCount = asyncCompanion.library.cachedPodcastEpisodeCount
            
            let playableByteSize = fileManager.playableCacheSize
            self.completeCacheSize = (playableByteSize > 1_000_000) ? playableByteSize.asByteString : Int64(0).asByteString
            
            let curCacheSizeLimit = Int64(settings.cacheSizeLimit)
            self.cacheSizeLimit = curCacheSizeLimit > 0 ? curCacheSizeLimit.asByteString : "No Limit"
            self.cacheSelection = curCacheSizeLimit > 0 ? [curCacheSizeLimit.asByteString.components(separatedBy: " ")[0], " " + curCacheSizeLimit.asByteString.components(separatedBy: " ")[1]] : ["0"," MB"]
        }.catch { error in }
    }
    
    private func resyncLibrary() {
        self.appDelegate.storage.settings.isOfflineMode = false
        // reset library sync flag -> rest library at new start and continue with sync
        self.appDelegate.storage.isLibrarySynced = false
        // reset quick actions
        self.appDelegate.quickActionsManager.configureQuickActions()
        self.appDelegate.restartByUser()
    }
    
    var body: some View {
        ZStack{
            List {
                SettingsSection(content: {
                    SettingsRow(title: "Playlists") {
                        SecondaryText(playlistCount.description)
                    }
                    SettingsRow(title: "Artists") {
                        SecondaryText(artistCount.description)
                    }
                    SettingsRow(title: "Albums") {
                        SecondaryText(albumCount.description)
                    }
                    SettingsRow(title: "Songs") {
                        SecondaryText(songCount.description)
                    }
                    SettingsRow(title: "Podcasts") {
                        SecondaryText(podcastCount.description)
                    }
                    SettingsRow(title: "Podcast Episodes") {
                        SecondaryText(podcastEpisodeCount.description)
                    }
                })


                #if targetEnvironment(macCatalyst)
                let progressTitle = "Background song sync progress"
                #else
                let progressTitle = "Progress"
                #endif

                SettingsSection(content: {
                    SettingsRow(title: progressTitle) {
                        SecondaryText(autoSyncProgressText)
                    }
                }, header: "Background song sync")


                SettingsSection(content: {
                    SettingsCheckBoxRow(
                        title: "Auto Cache",
                        label: "Newest Songs",
                        isOn: $settings.isAutoCacheLatestSongs
                    )
                    SettingsCheckBoxRow(
                        label: "Newest Podcast Episodes",
                        isOn: $settings.isAutoCacheLatestPodcastEpisodes
                    )
                }, header: "Auto Cache")
                

                SettingsSection(content: {
                    let changeHandler: ([String]) -> () = { cacheString in
                        if cacheString[1] == "" {
                            settings.cacheSizeLimit = 0
                            cacheSelection = ["0"," MB"]
                        }
                        if let cacheInByte = (cacheString[0] + cacheString[1]).asByteCount {
                            settings.cacheSizeLimit = cacheInByte
                        }
                    }

                    #if targetEnvironment(macCatalyst)
                    SettingsRow(title: "Cache") { SecondaryText("\(cachedSongCount.description) - Songs") }
                    SettingsRow() { SecondaryText("\(cachedPodcastEpisodesCount.description) - Podcast Episodes") }
                    SettingsRow() { SecondaryText("\(completeCacheSize.description) - Cache Size") }
                    SettingsRow(title: "Cache Size Limit") {
                        MultiPickerView(data: [("Size", byteValues),(" Bytes",[" MB"," GB"])], selection: $cacheSelection)
                            .frame(width: 250, height: 25)
                            .alignmentGuide(.top, computeValue: { _ in 0 })
                    }
                    .frame(height: 25)
                    .onChange(of: cacheSelection, perform: changeHandler)
                    .padding(.bottom, 10)
                    #else
                    SettingsRow(title: "Cached Songs") { SecondaryText(cachedSongCount.description) }
                    SettingsRow(title: "Cached Podcast Episodes") { SecondaryText(cachedPodcastEpisodesCount.description) }
                    SettingsRow(title: "Complete Cache Size") { SecondaryText(completeCacheSize.description) }

                    NavigationLink {
                        MultiPickerView(data: [("Size", byteValues),(" Bytes",[" MB"," GB"])], selection: $cacheSelection)
                        .navigationTitle("Cache Size Limit")
                    } label: {
                        SettingsRow(title: "Cache Size Limit") {
                            SecondaryText(cacheSizeLimit.description)
                        }
                    }
                    .onChange(of: cacheSelection, perform: changeHandler)
                    #endif


                    SettingsButtonRow(title: "Downloads", label: "Download all songs in library") {
                        isShowDownloadSongsAlert = true
                    }
                    .alert(isPresented: $isShowDownloadSongsAlert) {
                        Alert(title: Text("Download all songs in library"), message: Text("This action will add all uncached songs in \"Library -> Songs\" to the download queue. High network traffic can be generated and device storage capacity will be taken. Continue?"),
                        primaryButton: .default(Text("OK")) {
                            let allSongsToDownload = self.appDelegate.storage.main.library.getSongsForCompleteLibraryDownload()
                            self.appDelegate.playableDownloadManager.download(objects: allSongsToDownload)
                        }, secondaryButton: .cancel())
                    }

                    SettingsButtonRow(label: "Delete downloaded Songs and Podcast Episodes", actionType: .destructive) {
                            isShowDeleteCacheAlert = true
                    }.alert(isPresented: $isShowDeleteCacheAlert) {
                        Alert(
                            title: Text("Delete Cache"),
                            message: Text("Are you sure to delete all downloaded Songs and Podcast Episodes?"),
                            primaryButton: .destructive(Text("Delete"))
                            {
                                self.appDelegate.player.stop()
                                self.appDelegate.playableDownloadManager.stop()
                                self.appDelegate.storage.main.library.deletePlayableCachePaths()
                                self.appDelegate.storage.main.library.saveContext()
                                self.fileManager.deletePlayableCache()
                                self.appDelegate.playableDownloadManager.start()
                            }, secondaryButton: .cancel()
                        )
                    }
                }, header: "Cache")

                
                SettingsSection() {
                    SettingsButtonRow(title: "Sync", label: "Resync Library") {
                        isShowResyncLibraryAlert = true
                    }.alert(isPresented: $isShowResyncLibraryAlert) {
                        Alert(title: Text("Resync Library"), message: Text("This action resets your local library and starts the sync process from remote. Amperfy needs to restart to perform a resync.\n\nDo you want to resync your library and restart Amperfy?"),
                        primaryButton: .destructive(Text("Resync")) {
                            resyncLibrary()
                        }, secondaryButton: .cancel())
                    }

                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateValues()
            appDelegate.userStatistics.visited(.settingsLibrary)
        }
        .onReceive(timer) { _ in
            updateValues()
        }
        .onDisappear {
            self.timer.upstream.connect().cancel()
        }
    }
}

struct LibrarySettingsView_Previews: PreviewProvider {
    @State static var settings = Settings()
    
    static var previews: some View {
        LibrarySettingsView().environmentObject(settings)
    }
}
