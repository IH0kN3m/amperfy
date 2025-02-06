//
//  SyncVC.swift
//  Amperfy
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

import UIKit
import Foundation
import AmperfyKit
import PromiseKit

class SyncVC: UIViewController {

    var state: ParsedObjectType = .genre
    let syncSemaphore = DispatchSemaphore(value: 1)
    var parsedObjectCount: Int = 0
    var parsedObjectPercent: Float = 0.0
    var libObjectsToParseCount: Int = 1
    var syncFinished = false
    
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressInfo: UILabel!
    @IBOutlet weak var activitySpinner: UIActivityIndicatorView!
    @IBOutlet weak var skipButton: BasicButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        progressBar.setProgress(0.0, animated: true)
        progressInfo.text = ""
        progressLabel.text = String(format: "%.1f", 0.0) + "%"
        appDelegate.isKeepScreenAlive = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.appDelegate.eventLogger.supressAlerts = true
        self.appDelegate.scrobbleSyncer?.stopAndWait()
        self.appDelegate.backgroundLibrarySyncer.stopAndWait()
        self.appDelegate.artworkDownloadManager.stop()
        self.appDelegate.playableDownloadManager.stop()
        self.appDelegate.storage.isLibrarySynced = false
        self.appDelegate.storage.main.library.cleanStorage()
        self.appDelegate.reinit()
        
        Task { @MainActor in
            do {
                try await self.appDelegate.librarySyncer.syncInitial(statusNotifyier: self)
                self.appDelegate.storage.initialSyncCompletionStatus = .completed
            } catch {
                guard !self.syncFinished else { return }
                self.appDelegate.eventLogger.report(topic: "Initial Sync", error: error, displayPopup: false)
                self.appDelegate.storage.initialSyncCompletionStatus = .aborded
            }
            self.finishSync()
        }
    }
    
    private func finishSync() {
        guard !self.syncFinished else { return }

        self.syncFinished = true
        self.progressInfo.text = "Done"
        self.activitySpinner.stopAnimating()
        self.activitySpinner.isHidden = true
        self.progressLabel.isHidden = true
        
        self.appDelegate.storage.librarySyncVersion = .newestVersion
        self.appDelegate.storage.isLibrarySynced = true
        self.appDelegate.startManagerAfterSync()
        self.appDelegate.isKeepScreenAlive = false
        self.appDelegate.eventLogger.supressAlerts = false

        #if targetEnvironment(macCatalyst)
        AppDelegate.rootViewController()?.dismiss(animated: true) {
            guard let splitVC = AppDelegate.rootViewController() as? SplitVC else { return }
            splitVC.displayInfoPopups()
        }
        #else
        self.performSegue(withIdentifier: "toLibrary", sender: self)
        #endif
    }
    
    private func updateSyncInfo(infoText: String? = nil, percentParsed: Float = 0.0) {
        DispatchQueue.main.async {
            if let infoText = infoText {
                self.progressInfo.text = infoText
            }
            self.progressBar.setProgress(percentParsed, animated: percentParsed != 0.0)
            self.progressLabel.text = String(format: "%.1f", percentParsed * 100) + "%"
        }
    }

    @IBAction func skipPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Skip Sync", message: "Skipping initial sync results in an incomplete library. Missing library elements can later be synced via various search/update functionalities.", preferredStyle: .alert)
        let skip = UIAlertAction(title: "Skip", style: .destructive, handler: { (action) -> Void in
            self.appDelegate.storage.initialSyncCompletionStatus = .skipped
            self.finishSync()
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(skip)
        alert.addAction(cancel)
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension SyncVC: SyncCallbacks {
    
    func notifyParsedObject(ofType parsedObjectType: ParsedObjectType) {
        syncSemaphore.wait()
        guard parsedObjectType == state else {
            syncSemaphore.signal()
            return
        }
        self.parsedObjectCount += 1
        
        var parsePercent: Float = 0.0
        if self.libObjectsToParseCount > 0 {
            parsePercent = min(Float(self.parsedObjectCount) / Float(self.libObjectsToParseCount), 1.0)
        }
        let percentDiff = Int(parsePercent*1000)-Int(self.parsedObjectPercent*1000)
        if percentDiff > 0 {
            self.updateSyncInfo(percentParsed: parsePercent)
        }
        self.parsedObjectPercent = parsePercent
        syncSemaphore.signal()
    }
    
    func notifySyncStarted(ofType parsedObjectType: ParsedObjectType, totalCount: Int) {
        syncSemaphore.wait()
        self.parsedObjectCount = 0
        self.parsedObjectPercent = 0.0
        self.state = parsedObjectType
        self.libObjectsToParseCount = totalCount > 0 ? totalCount : 1
        
        if totalCount > 0 {
            activitySpinner.stopAnimating()
            activitySpinner.isHidden = true
        } else {
            activitySpinner.startAnimating()
            activitySpinner.isHidden = false
        }
        progressLabel.isHidden = totalCount <= 0
        
        switch parsedObjectType {
        case .artist:
            self.updateSyncInfo(infoText: "Syncing artists ...", percentParsed: 0.0)
        case .album:
            self.updateSyncInfo(infoText: "Syncing albums ...", percentParsed: 0.0)
        case .song:
            self.updateSyncInfo(infoText: "Syncing songs ...", percentParsed: 0.0)
        case .playlist:
            self.updateSyncInfo(infoText: "Syncing playlists ...", percentParsed: 0.0)
        case .genre:
            self.updateSyncInfo(infoText: "Syncing genres ...", percentParsed: 0.0)
        case .podcast:
            self.updateSyncInfo(infoText: "Syncing podcasts ...", percentParsed: 0.0)
        case .cache:
            self.updateSyncInfo(infoText: "Applying cache ...", percentParsed: 0.0)
        }
        syncSemaphore.signal()
    }

}
