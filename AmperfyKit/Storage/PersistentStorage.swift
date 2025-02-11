//
//  PersistentStorage.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

import Foundation
import UIKit
import CoreData

public enum ArtworkDownloadSetting: Int, CaseIterable, Sendable {
    case updateOncePerSession = 0
    case onlyOnce = 1
    case never = 2
    
    static let defaultValue: ArtworkDownloadSetting = .onlyOnce
    
    public var description: String {
        switch self {
        case .updateOncePerSession:
            return "Download once per session (change detection)"
        case .onlyOnce:
            return "Download only once"
        case .never:
            return "Never"
        }
    }
}

public enum ArtworkDisplayPreference: Int, CaseIterable, Sendable {
    case id3TagOnly = 0
    case serverArtworkOnly = 1
    case preferServerArtwork = 2
    case preferId3Tag = 3
    
    static let defaultValue: ArtworkDisplayPreference = .preferId3Tag
    
    public var description: String {
        switch self {
        case .id3TagOnly:
            return "Only ID3 tag artworks"
        case .serverArtworkOnly:
            return "Only server artworks"
        case .preferServerArtwork:
            return "Prefer server artwork over ID3 tag"
        case .preferId3Tag:
            return "Prefer ID3 tag over server artwork"
        }
    }
}

public enum ScreenLockPreventionPreference: Int, CaseIterable, Sendable {
    case always = 0
    case never = 1
    case onlyIfCharging = 2
    
    public static let defaultValue: ScreenLockPreventionPreference = .never
    
    public var description: String {
        switch self {
        case .always:
            return "Always"
        case .never:
            return "Never"
        case .onlyIfCharging:
            return "When connected to charger"
        }
    }
}

public enum StreamingMaxBitratePreference: Int, CaseIterable, Sendable {
    case noLimit = 0
    case limit32 = 32
    case limit64 = 64
    case limit96 = 96
    case limit128 = 128
    case limit192 = 192
    case limit256 = 256
    case limit320 = 320
    
    public static let defaultValue: StreamingMaxBitratePreference = .noLimit
    
    public var description: String {
        switch self {
        case .noLimit:
            return "No Limit (default)"
        default:
            return "\(self.rawValue) kbps"
        }
    }
    
    public var asBitsPerSecondAV: Double {
        return Double(self.rawValue * 1000)
    }
}

public enum StreamingFormatPreference: Int, CaseIterable, Sendable {
    case mp3 = 0
    case raw = 1
    case serverConfig = 2 // omit the format to let the server decide which codec should be used
    
    public static let defaultValue: StreamingFormatPreference = .mp3
    
    public var description: String {
        switch self {
        case .mp3:
            return "mp3 (default)"
        case .raw:
            return "Raw/Original"
        case .serverConfig:
            return "Server chooses Codec"
        }
    }
}

public enum SyncCompletionStatus: Int, CaseIterable, Sendable {
    case completed = 0
    case skipped = 1
    case aborded = 2

    public static let defaultValue: SyncCompletionStatus = .completed
    
    public var description: String {
        switch self {
        case .completed:
            return "Completed"
        case .skipped:
            return "Skipped"
        case .aborded:
            return "Aborded"
        }
    }
}


public enum ThemePreference: Int, CaseIterable, Sendable {
    case blue = 0
    case green = 1
    case red = 2
    case yellow = 3
    case orange = 4
    case purple = 5
    case pink = 6

    public static let defaultValue: ThemePreference = .blue
    
    public var description: String {
        switch self {
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        case .red:
            return "Red"
        case .yellow:
            return "Yellow"
        case .orange:
            return "Orange"
        case .purple:
            return "Purple"
        case .pink:
            return "Pink"
        }
    }
    
    public var asColor: UIColor {
        switch(self) {
        case .blue:
            return .systemBlue
        case .green:
            return .systemGreen
        case .red:
            return .systemRed
        case .yellow:
            return .systemYellow
        case .orange:
            return .systemOrange
        case .purple:
            return .systemPurple
        case .pink:
            return .systemPink
        }
    }
}

public enum CacheTranscodingFormatPreference: Int, CaseIterable, Sendable {
    case raw = 0
    case mp3 = 1
    case serverConfig = 2 // omit the format to let the server decide which codec should be used
    
    public static let defaultValue: CacheTranscodingFormatPreference = .mp3
    
    public var description: String {
        switch self {
        case .mp3:
            return "mp3 (default)"
        case .raw:
            return "Raw/Original"
        case .serverConfig:
            return "Server chooses Codec"
        }
    }
}

public class CoreDataCompanion {
    public let context: NSManagedObjectContext
    public let library: LibraryStorage
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.library = LibraryStorage(context: context)
    }
    
    public func saveContext() {
        library.saveContext()
    }
    
    public func perform(body: @escaping (_ asyncCompanion: CoreDataCompanion) -> Void) {
        self.context.performAndWait {
            body(self)
            library.saveContext()
        }
    }
}

public actor AsyncCoreDataAccessWrapper {
    let persistentContainer: NSPersistentContainer
    
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    public func perform(body: @escaping @Sendable (_ asyncCompanion: CoreDataCompanion) throws -> Void) async throws {
        let context = persistentContainer.newBackgroundContext()
        
        await context.perform {
            context.retainsRegisteredObjects = true
            let library = LibraryStorage(context: context)
            let asyncCompanion = CoreDataCompanion(context: context)
            do {
                try body(asyncCompanion)
                library.saveContext()
            } catch {
                library.saveContext()
            }
        }
    }

    public func performAndGet<T>(body: @escaping @Sendable (_ asyncCompanion: CoreDataCompanion) throws -> T) async throws -> T where T: Sendable {
        let context = persistentContainer.newBackgroundContext()
        
        let syncRequestedValue = try await context.perform {
            context.retainsRegisteredObjects = true
            let library = LibraryStorage(context: context)
            let asyncCompanion = CoreDataCompanion(context: context)
            do {
                let asyncRequestedValue = try body(asyncCompanion)
                library.saveContext()
                return asyncRequestedValue
            } catch {
                library.saveContext()
                throw error
            }
        }
        return syncRequestedValue
    }
}

public class PersistentStorage {

    private enum UserDefaultsKey: String {
        case ServerUrl = "serverUrl"
        case AlternativeServerUrls = "alternativeServerUrls"
        case Username = "username"
        case Password = "password"
        case BackendApi = "backendApi"
        case LibraryIsSynced = "libraryIsSynced"
        case InitialSyncCompletionStatus = "initialSyncCompletionStatus"
        case ArtworkDownloadSetting = "artworkDownloadSetting"
        case ArtworkDisplayPreference = "artworkDisplayPreference"
        case SleepTimerInterval = "sleepTimerInterval" // not used anymore !!! 
        case ScreenLockPreventionPreference = "screenLockPreventionPreference"
        case StreamingMaxBitrateWifiPreference = "streamingMaxBitrateWifiPreference"
        case StreamingMaxBitrateCellularPreference = "streamingMaxBitrateCellularPreference"
        case StreamingFormatPreference = "streamingFormatPreference"
        case CacheTranscodingFormatPreference = "cacheTranscodingFormatPreference"
        case CacheLimit = "cacheLimitInBytes" // limit in byte
        case PlayerVolume = "playerVolume"
        case ShowDetailedInfo = "showDetailedInfo"
        case ShowSongDuration = "showSongDuration"
        case ShowAlbumDuration = "showAlbumDuration"
        case ShowArtistDuration = "showArtistDuration"
        case PlayerShuffleButtonEnabled = "enablePlayerShuffleButton"
        case ShowMusicPlayerSkipButtons = "showMusicPlayerSkipButtons"
        case AlwaysHidePlayerLyricsButton = "alwaysHidePlayerLyricsButton"
        case IsLyricsSmoothScrolling = "isLyricsSmoothScrolling"

        case SongActionOnTab = "songActionOnTab"
        case LibraryDisplaySettings = "libraryDisplaySettings"
        case SwipeLeadingActionSettings = "swipeLeadingActionSettings"
        case SwipeTrailingActionSettings = "swipeTrailingActionSettings"
        case PlaylistsSortSetting = "playlistsSortSetting"
        case ArtistsSortSetting = "artistsSortSetting"
        case AlbumsSortSetting = "albumsSortSetting"
        case SongsSortSetting = "songsSortSetting"
        case FavoriteSongSortSetting = "favoriteSongSortSetting"
        case ArtistsFilterSetting = "artistsFilterSetting"
        case AlbumsDisplayStyleSetting = "albumsDisplayStyleSetting"
        case AlbumsGridSizeSetting = "albumsGridSizeSetting"
        case PodcastsShowSetting = "podcastsShowSetting"
        case PlayerDisplayStyle = "playerDisplayStyle"
        case IsPlayerLyricsDisplayed = "isPlayerLyricsDisplayed"
        case IsOfflineMode = "isOfflineMode"
        case IsAutoDownloadLatestSongsActive = "isAutoDownloadLatestSongsActive"
        case IsAutoDownloadLatestPodcastEpisodesActive = "isAutoDownloadLatestPodcastEpisodesActive"
        case IsScrobbleStreamedItems = "isScrobbleStreamedItems"
        case IsPlaybackStartOnlyOnPlay = "isPlaybackStartOnlyOnPlay"
        case LibrarySyncVersion = "librarySyncVersion"
        case IsHapticsEnabled = "isHapticsEnabled"
        
        case LibrarySyncInfoReadByUser = "librarySyncInfoReadByUser"
        case ThemePreference = "themePreference"
    }
    
    private var coreDataManager: CoreDataManagable
    
    init(coreDataManager: CoreDataManagable) {
        self.coreDataManager = coreDataManager
    }
    
    final public class Settings: Sendable {
        public var artworkDownloadSetting: ArtworkDownloadSetting {
            get {
                let artworkDownloadSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtworkDownloadSetting.rawValue) as? Int ?? ArtworkDownloadSetting.defaultValue.rawValue
                return ArtworkDownloadSetting(rawValue: artworkDownloadSettingRaw) ?? ArtworkDownloadSetting.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtworkDownloadSetting.rawValue) }
        }
        
        public var artworkDisplayPreference: ArtworkDisplayPreference {
            get {
                let artworkDisplayStyleRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtworkDisplayPreference.rawValue) as? Int ?? ArtworkDisplayPreference.defaultValue.rawValue
                return ArtworkDisplayPreference(rawValue: artworkDisplayStyleRaw) ?? ArtworkDisplayPreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtworkDisplayPreference.rawValue) }
        }
        
        public var screenLockPreventionPreference: ScreenLockPreventionPreference {
            get {
                let screenLockPreventionPreferenceRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ScreenLockPreventionPreference.rawValue) as? Int ?? ScreenLockPreventionPreference.defaultValue.rawValue
                return ScreenLockPreventionPreference(rawValue: screenLockPreventionPreferenceRaw) ?? ScreenLockPreventionPreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ScreenLockPreventionPreference.rawValue) }
        }

        public var themePreference: ThemePreference {
            get {
                let themePreferenceRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ThemePreference.rawValue) as? Int ??
                    ThemePreference.defaultValue.rawValue
                return ThemePreference(rawValue: themePreferenceRaw) ?? ThemePreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ThemePreference.rawValue) }
        }
        
        public var streamingMaxBitrateWifiPreference: StreamingMaxBitratePreference {
            get {
                let streamingMaxBitrateWifiPreferenceRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.StreamingMaxBitrateWifiPreference.rawValue) as? Int ?? StreamingMaxBitratePreference.defaultValue.rawValue
                return StreamingMaxBitratePreference(rawValue: streamingMaxBitrateWifiPreferenceRaw) ?? StreamingMaxBitratePreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.StreamingMaxBitrateWifiPreference.rawValue) }
        }
        
        public var streamingMaxBitrateCellularPreference: StreamingMaxBitratePreference {
            get {
                let streamingMaxBitrateCelluarPreferenceRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.StreamingMaxBitrateCellularPreference.rawValue) as? Int ?? StreamingMaxBitratePreference.defaultValue.rawValue
                return StreamingMaxBitratePreference(rawValue: streamingMaxBitrateCelluarPreferenceRaw) ?? StreamingMaxBitratePreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.StreamingMaxBitrateCellularPreference.rawValue) }
        }
         
        public var streamingFormatPreference: StreamingFormatPreference {
            get {
                let streamingFormatPreferenceRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.StreamingFormatPreference.rawValue) as? Int ?? StreamingFormatPreference.defaultValue.rawValue
                return StreamingFormatPreference(rawValue: streamingFormatPreferenceRaw) ?? StreamingFormatPreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.StreamingFormatPreference.rawValue) }
        }       
        
        public var cacheTranscodingFormatPreference: CacheTranscodingFormatPreference {
            get {
                let cacheTranscodingFormatPreferenceRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.CacheTranscodingFormatPreference.rawValue) as? Int ?? CacheTranscodingFormatPreference.defaultValue.rawValue
                return CacheTranscodingFormatPreference(rawValue: cacheTranscodingFormatPreferenceRaw) ?? CacheTranscodingFormatPreference.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.CacheTranscodingFormatPreference.rawValue) }
        }
        
        public var isShowDetailedInfo: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.ShowDetailedInfo.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowDetailedInfo.rawValue) }
        }
        
        public var isShowSongDuration: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.ShowSongDuration.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowSongDuration.rawValue) }
        }
        
        public var isShowAlbumDuration: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.ShowAlbumDuration.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowAlbumDuration.rawValue) }
        }
        
        public var isShowArtistDuration: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.ShowArtistDuration.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowArtistDuration.rawValue) }
        }
        
        public var isPlayerShuffleButtonEnabled: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.PlayerShuffleButtonEnabled.rawValue) as? Bool ?? true }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.PlayerShuffleButtonEnabled.rawValue) }
        }
        
        public var isShowMusicPlayerSkipButtons: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.ShowMusicPlayerSkipButtons.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.ShowMusicPlayerSkipButtons.rawValue) }
        }
        
        public var isAlwaysHidePlayerLyricsButton: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.AlwaysHidePlayerLyricsButton.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.AlwaysHidePlayerLyricsButton.rawValue) }
        }
        
        public var isLyricsSmoothScrolling: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsLyricsSmoothScrolling.rawValue) as? Bool ?? true }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsLyricsSmoothScrolling.rawValue) }
        }

        public var cacheLimit: Int {
            get {
                return UserDefaults.standard.object(forKey: UserDefaultsKey.CacheLimit.rawValue) as? Int ?? 0
            }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.CacheLimit.rawValue) }
        }
        
        public var playerVolume: Float {
            get {
                let volume = UserDefaults.standard.object(forKey: UserDefaultsKey.PlayerVolume.rawValue) as? Float ?? 1.0
                return (volume >= 0.0 && volume <= 1.0) ? volume : 1.0
            }
            set {
                guard newValue >= 0.0 && newValue <= 1.0 else { return }
                UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.PlayerVolume.rawValue)
            }
        }
        
        public var playlistsSortSetting: PlaylistSortType {
            get {
                let playlistsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PlaylistsSortSetting.rawValue) as? Int ?? PlaylistSortType.defaultValue.rawValue
                return PlaylistSortType(rawValue: playlistsSortSettingRaw) ?? PlaylistSortType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PlaylistsSortSetting.rawValue) }
        }
        
        public var artistsSortSetting: ArtistElementSortType {
            get {
                let artistsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtistsSortSetting.rawValue) as? Int ?? ArtistElementSortType.defaultValue.rawValue
                return ArtistElementSortType(rawValue: artistsSortSettingRaw) ?? ArtistElementSortType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtistsSortSetting.rawValue) }
        }
        
        public var albumsSortSetting: AlbumElementSortType {
            get {
                let albumsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.AlbumsSortSetting.rawValue) as? Int ?? AlbumElementSortType.defaultValue.rawValue
                return AlbumElementSortType(rawValue: albumsSortSettingRaw) ?? AlbumElementSortType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.AlbumsSortSetting.rawValue) }
        }
        
        public var songsSortSetting: SongElementSortType {
            get {
                let songsSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.SongsSortSetting.rawValue) as? Int ?? SongElementSortType.defaultValue.rawValue
                return SongElementSortType(rawValue: songsSortSettingRaw) ?? SongElementSortType.defaultValue
            }
            set {
                guard (newValue != SongElementSortType.starredDate) else {
                    UserDefaults.standard.set(SongElementSortType.defaultValue.rawValue, forKey: UserDefaultsKey.SongsSortSetting.rawValue)
                    return
                }
                UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.SongsSortSetting.rawValue) }
        }
        
        public var favoriteSongSortSetting: SongElementSortType {
            get {
                let favoriteSortSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.FavoriteSongSortSetting.rawValue) as? Int ?? SongElementSortType.defaultValueForFavorite.rawValue
                return SongElementSortType(rawValue: favoriteSortSettingRaw) ?? SongElementSortType.defaultValueForFavorite
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.FavoriteSongSortSetting.rawValue) }
        }
        
        public var artistsFilterSetting: ArtistCategoryFilter {
            get {
                let artistsFilterSettingRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.ArtistsFilterSetting.rawValue) as? Int ?? ArtistElementSortType.defaultValue.rawValue
                return ArtistCategoryFilter(rawValue: artistsFilterSettingRaw) ?? ArtistCategoryFilter.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.ArtistsFilterSetting.rawValue) }
        }
        
        public var albumsStyleSetting: AlbumsDisplayStyle {
            get {
                let albumsDisplayStyleRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.AlbumsDisplayStyleSetting.rawValue) as? Int ?? AlbumsDisplayStyle.defaultValue.rawValue
                return AlbumsDisplayStyle(rawValue: albumsDisplayStyleRaw) ?? AlbumsDisplayStyle.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.AlbumsDisplayStyleSetting.rawValue) }
        }
        
        @MainActor public var albumsGridSizeSetting: Int {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.AlbumsGridSizeSetting.rawValue) as? Int ?? 
                ((UIDevice.current.userInterfaceIdiom == .pad) ? 4 : 3) }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.AlbumsGridSizeSetting.rawValue) }
        }
        
        public var swipeActionSettings: SwipeActionSettings {
            get {
                guard let swipeLeadingActionsRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.SwipeLeadingActionSettings.rawValue) as? [Int],
                    let swipeTrailingActionsRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.SwipeTrailingActionSettings.rawValue) as? [Int]
                else {
                    return SwipeActionSettings.defaultSettings
                }
                let swipeLeadingActions = swipeLeadingActionsRaw.compactMap{ SwipeActionType(rawValue: $0) }
                let swipeTrailingActions = swipeTrailingActionsRaw.compactMap{ SwipeActionType(rawValue: $0) }
                return SwipeActionSettings(leading: swipeLeadingActions, trailing: swipeTrailingActions)
            }
            set {
                UserDefaults.standard.set(newValue.leading.compactMap{ $0.rawValue }, forKey: UserDefaultsKey.SwipeLeadingActionSettings.rawValue)
                UserDefaults.standard.set(newValue.trailing.compactMap{ $0.rawValue }, forKey: UserDefaultsKey.SwipeTrailingActionSettings.rawValue)
            }
        }
        
        public var libraryDisplaySettings: LibraryDisplaySettings {
            get {
                guard let libraryDisplaySettingsRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.LibraryDisplaySettings.rawValue) as? [Int]
                else {
                    return LibraryDisplaySettings.defaultSettings
                }
                let libraryDisplaySettings = libraryDisplaySettingsRaw.compactMap{ LibraryDisplayType(rawValue: $0) }
                return LibraryDisplaySettings(inUse: libraryDisplaySettings)
            }
            set {
                UserDefaults.standard.set(newValue.inUse.compactMap{ $0.rawValue }, forKey: UserDefaultsKey.LibraryDisplaySettings.rawValue)
            }
        }
        
        public var podcastsShowSetting: PodcastsShowType {
            get {
                let podcastSortRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PodcastsShowSetting.rawValue) as? Int ?? PodcastsShowType.defaultValue.rawValue
                return PodcastsShowType(rawValue: podcastSortRaw) ?? PodcastsShowType.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PodcastsShowSetting.rawValue) }
        }
        
        public var playerDisplayStyle: PlayerDisplayStyle {
            get {
                let playerDisplayStyleRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue) as? Int ?? PlayerDisplayStyle.defaultValue.rawValue
                return PlayerDisplayStyle(rawValue: playerDisplayStyleRaw) ?? PlayerDisplayStyle.defaultValue
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.PlayerDisplayStyle.rawValue) }
        }
        
        public var isPlayerLyricsDisplayed: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsPlayerLyricsDisplayed.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsPlayerLyricsDisplayed.rawValue) }
        }
        
        public var isOfflineMode: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsOfflineMode.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsOfflineMode.rawValue) }
        }
        
        public var isAutoDownloadLatestSongsActive: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsAutoDownloadLatestSongsActive.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsAutoDownloadLatestSongsActive.rawValue) }
        }
        
        public var isAutoDownloadLatestPodcastEpisodesActive: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsAutoDownloadLatestPodcastEpisodesActive.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsAutoDownloadLatestPodcastEpisodesActive.rawValue) }
        }
        
        public var isScrobbleStreamedItems: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsScrobbleStreamedItems.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsScrobbleStreamedItems.rawValue) }
        }
        
        public var isPlaybackStartOnlyOnPlay: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsPlaybackStartOnlyOnPlay.rawValue) as? Bool ?? false }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsPlaybackStartOnlyOnPlay.rawValue) }
        }
        
        public var isOnlineMode: Bool {
            return !isOfflineMode
        }
        
        public var isHapticsEnabled: Bool {
            get { return UserDefaults.standard.object(forKey: UserDefaultsKey.IsHapticsEnabled.rawValue) as? Bool ?? true }
            set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.IsHapticsEnabled.rawValue) }
        }
    }
    
    public var settings = Settings()

    public var loginCredentials: LoginCredentials? {
        get {
            if  let serverUrl = UserDefaults.standard.object(forKey: UserDefaultsKey.ServerUrl.rawValue) as? String,
                let username = UserDefaults.standard.object(forKey: UserDefaultsKey.Username.rawValue) as? String,
                let passwordHash = UserDefaults.standard.object(forKey: UserDefaultsKey.Password.rawValue) as? String,
                let backendApiRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.BackendApi.rawValue) as? Int,
                let backendApi = BackenApiType(rawValue: backendApiRaw) {
                    return LoginCredentials(serverUrl: serverUrl, username: username, password: passwordHash, backendApi: backendApi)
            }
            return nil
        }
        set {
            if let newCredentials = newValue {
                UserDefaults.standard.set(newCredentials.serverUrl, forKey: UserDefaultsKey.ServerUrl.rawValue)
                UserDefaults.standard.set(newCredentials.username, forKey: UserDefaultsKey.Username.rawValue)
                UserDefaults.standard.set(newCredentials.password, forKey: UserDefaultsKey.Password.rawValue)
                UserDefaults.standard.set(newCredentials.backendApi.rawValue, forKey: UserDefaultsKey.BackendApi.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.ServerUrl.rawValue)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Username.rawValue)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.Password.rawValue)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKey.BackendApi.rawValue)
            }
        }
    }
    
    public var alternativeServerURLs: [String] {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.AlternativeServerUrls.rawValue) as? [String] ?? [String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.AlternativeServerUrls.rawValue)
        }
    }
    
    public var isLibrarySyncInfoReadByUser: Bool {
        get { return UserDefaults.standard.object(forKey: UserDefaultsKey.LibrarySyncInfoReadByUser.rawValue) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.LibrarySyncInfoReadByUser.rawValue) }
    }

    public var isLibrarySynced: Bool {
        get { return UserDefaults.standard.object(forKey: UserDefaultsKey.LibraryIsSynced.rawValue) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.LibraryIsSynced.rawValue) }
    }
    
    public var initialSyncCompletionStatus: SyncCompletionStatus {
        get {
            let initialSyncCompletionStatusRaw = UserDefaults.standard.object(forKey: UserDefaultsKey.InitialSyncCompletionStatus.rawValue) as? Int ?? SyncCompletionStatus.defaultValue.rawValue
            return SyncCompletionStatus(rawValue: initialSyncCompletionStatusRaw) ?? SyncCompletionStatus.defaultValue
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.InitialSyncCompletionStatus.rawValue) }
    }
    
    public var librarySyncVersion: LibrarySyncVersion {
        get {
            if let raw = UserDefaults.standard.object(forKey: UserDefaultsKey.LibrarySyncVersion.rawValue) as? Int,
               let version = LibrarySyncVersion(rawValue: raw) {
                    return version
            }
            return LibrarySyncVersion.v6
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.LibrarySyncVersion.rawValue)
        }
    }

    @MainActor public lazy var main: CoreDataCompanion = {
        return CoreDataCompanion(context: coreDataManager.context)
    }()
    
    public var async: AsyncCoreDataAccessWrapper {
        return AsyncCoreDataAccessWrapper(persistentContainer: coreDataManager.persistentContainer)
    }

}

// MARK: - Core Data stack

protocol CoreDataManagable {
    var persistentContainer: NSPersistentContainer { get }
    @MainActor var context: NSManagedObjectContext { get }
}

public class CoreDataPersistentManager: CoreDataManagable {

    nonisolated(unsafe) public static let managedObjectModel: NSManagedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle.main])!

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Amperfy", managedObjectModel: Self.managedObjectModel)
        let description = container.persistentStoreDescriptions.first
        description?.shouldInferMappingModelAutomatically = false
        description?.shouldMigrateStoreAutomatically = false
        description?.type = NSSQLiteStoreType
        
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            fatalError("persistentContainer was not set up properly")
        }
        
        let migrator = CoreDataMigrator()
        if migrator.requiresMigration(at: storeURL, toVersion: CoreDataMigrationVersion.current) {
            migrator.migrateStore(at: storeURL, toVersion: CoreDataMigrationVersion.current)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        return container
    }()
    
    @MainActor lazy var context: NSManagedObjectContext = {
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.retainsRegisteredObjects = true
        return persistentContainer.viewContext
    }()

}
