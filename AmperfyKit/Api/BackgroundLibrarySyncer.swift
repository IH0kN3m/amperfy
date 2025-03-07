//
//  BackgroundLibrarySyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 12.04.22.
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

import Foundation
import os.log

@MainActor
public class BackgroundLibrarySyncer: AbstractBackgroundLibrarySyncer {
  private let storage: PersistentStorage
  private let networkMonitor: NetworkMonitorFacade
  private let librarySyncer: LibrarySyncer
  private let playableDownloadManager: DownloadManageable
  private let eventLogger: EventLogger

  private let log = OSLog(subsystem: "Amperfy", category: "BackgroundLibrarySyncer")
  private let activeDispatchGroup = DispatchGroup()
  private var isRunning = false
  private var isCurrentlyActive = false

  init(
    storage: PersistentStorage,
    networkMonitor: NetworkMonitorFacade,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable,
    eventLogger: EventLogger
  ) {
    self.storage = storage
    self.networkMonitor = networkMonitor
    self.librarySyncer = librarySyncer
    self.playableDownloadManager = playableDownloadManager
    self.eventLogger = eventLogger
  }

  var isActive: Bool { isCurrentlyActive }

  public func start() {
    isRunning = true
    if !isCurrentlyActive {
      isCurrentlyActive = true
      syncAlbumSongsInBackground()
    }
  }

  public func stop() {
    isRunning = false
  }

  public func stopAndWait() {
    isRunning = false
    activeDispatchGroup.wait()
  }

  private func syncAlbumSongsInBackground() {
    Task { @MainActor in
      self.activeDispatchGroup.enter()
      os_log("start", log: self.log, type: .info)

      if self.isRunning, self.storage.settings.isOnlineMode,
         self.networkMonitor.isConnectedToNetwork {
        do {
          try await AutoDownloadLibrarySyncer(
            storage: self.storage,
            librarySyncer: self.librarySyncer,
            playableDownloadManager: self.playableDownloadManager
          )
          .syncNewestLibraryElements(offset: 0, count: AmperKit.newestElementsFetchCount)
        } catch {
          self.eventLogger.report(
            topic: "Latest Library Elements Background Sync",
            error: error,
            displayPopup: false
          )
        }
      }

      while self.isRunning, self.storage.settings.isOnlineMode,
            self.networkMonitor.isConnectedToNetwork {
        do {
          let albumToSync = self.storage.main.library.getAlbumWithoutSyncedSongs()
          guard let albumToSync = albumToSync else {
            self.isRunning = false
            break
          }
          try await albumToSync.fetchFromServer(
            storage: self.storage,
            librarySyncer: self.librarySyncer,
            playableDownloadManager: self.playableDownloadManager
          )
        } catch {
          self.eventLogger.report(topic: "Album Background Sync", error: error, displayPopup: false)
          self.isRunning = false
          break
        }
      }

      os_log("stopped", log: self.log, type: .info)
      self.isCurrentlyActive = false
      self.activeDispatchGroup.leave()
    }
  }
}
