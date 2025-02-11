//
//  Download.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 21.07.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import CoreData

public enum DownloadableType: Sendable {
    case playable
    case artwork
    case unknown
}

public struct DownloadInfo: Sendable {
    let objectId: NSManagedObjectID
    let type: DownloadableType
}

public class Download: NSObject {
    
    public let managedObject: DownloadMO
    
    public init(managedObject: DownloadMO) {
        self.managedObject = managedObject
        super.init()
        if creationDate == nil {
            creationDate = Date()
        }
    }
    
    public var fileURL: URL? // Will not be saved in CoreData
    public var mimeType: String? // Will not be saved in CoreData

    public var title: String {
        return element?.displayString ?? ""
    }
    
    public var isFinishedSuccessfully: Bool {
        return finishDate != nil && errorDate == nil
    }
    
    public var isCanceled: Bool {
        get {
            guard let error = error else { return false }
            return error == .canceled
        }
        set { if newValue { error = .canceled } }
    }
    
    public func reset() {
        startDate = nil
        finishDate = nil
        error = nil
        errorDate = nil
        progress = 0.0
        totalSize = ""
    }

    public var id: String {
        get { return managedObject.id }
        set { if managedObject.id != newValue { managedObject.id = newValue } }
    }
    public var isDownloading: Bool {
        get { return startDate != nil && finishDate == nil && errorDate == nil}
        set { newValue ? (startDate = Date()) : (finishDate = Date()) }
    }
    public var url: URL? {
        return URL(string: urlString)
    }
    public func setURL(_ url: URL) {
        if managedObject.urlString != url.absoluteString {
            managedObject.urlString = url.absoluteString
        }
    }
    public var urlString: String {
        get { return managedObject.urlString }
        set { if managedObject.urlString != newValue { managedObject.urlString = newValue } }
    }
    public var creationDate: Date? {
        get { return managedObject.creationDate }
        set { if managedObject.creationDate != newValue { managedObject.creationDate = newValue } }
    }
    public var errorDate: Date? {
        get { return managedObject.errorDate }
        set { if managedObject.errorDate != newValue { managedObject.errorDate = newValue } }
    }
    private var errorType: Int? {
        get {
            guard errorDate != nil else { return nil }
            return Int(managedObject.errorType)
        }
        set {
            guard let newValue = newValue, Int16.isValid(value: newValue), managedObject.errorType != Int16(newValue) else { return }
            managedObject.errorType = Int16(newValue)
        }
    }
    public var error: DownloadError? {
        get {
            guard let errorType = errorType else { return nil }
            return DownloadError.create(rawValue: errorType)
        }
        set {
            if let newError = newValue {
                errorDate = Date()
                errorType = newError.rawValue
            } else {
                errorDate = nil
                errorType = 0
            }
        }
    }
    public var finishDate: Date? {
        get { return managedObject.finishDate }
        set { if managedObject.finishDate != newValue { managedObject.finishDate = newValue } }
    }
    public var progress: Float {
        get { return managedObject.progressPercent }
        set { if managedObject.progressPercent != newValue { managedObject.progressPercent = newValue } }
    }
    public var startDate: Date? {
        get { return managedObject.startDate }
        set { if managedObject.startDate != newValue { managedObject.startDate = newValue } }
    }
    public var totalSize: String {
        get { return managedObject.totalSize ?? "" }
        set { if managedObject.totalSize != newValue { managedObject.totalSize = totalSize } }
    }
    public var threadSafeInfo: DownloadInfo? {
        let type = baseType
        guard type != .unknown else { return nil }
        return DownloadInfo(objectId: self.managedObject.objectID, type: type)
    }
    public var baseType: DownloadableType {
        if artwork != nil {
            return .artwork
        } else if playable != nil {
            return .playable
        } else {
            return .unknown
        }
    }
    static public func createDownloadableObject(inContext context: NSManagedObjectContext, info: DownloadInfo) -> Downloadable {
        switch info.type {
        case .playable:
            let playableMO = context.object(with: info.objectId) as! AbstractPlayableMO
            let playable = AbstractPlayable(managedObject: playableMO)
            return playable
        case .artwork:
            let artworkMO = context.object(with: info.objectId) as! ArtworkMO
            let artwork = Artwork(managedObject: artworkMO)
            return artwork
        case .unknown:
            fatalError("Unknown is not available as Downloadable type")
        }
    }
    public var element: Downloadable? {
        get {
            if let artwork = artwork {
                return artwork
            } else if let playable = playable {
                return playable
            } else {
                return nil
            }
        }
        set {
            if let context = managedObject.managedObjectContext {
                if let downloadable = newValue as? AbstractPlayable {
                    playable = AbstractPlayable(managedObject: context.object(with: downloadable.objectID) as! AbstractPlayableMO)
                } else if let downloadable = newValue as? Artwork {
                    artwork = Artwork(managedObject: context.object(with: downloadable.objectID) as! ArtworkMO)
                }
            }
        }
    }
    private var artwork: Artwork? {
        get {
            guard let artworkMO = managedObject.artwork else { return nil }
            return Artwork(managedObject: artworkMO) }
        set {
            if managedObject.artwork != newValue?.managedObject { managedObject.artwork = newValue?.managedObject }
        }
    }
    private var playable: AbstractPlayable? {
        get {
            guard let playableMO = managedObject.playable else { return nil }
            return AbstractPlayable(managedObject: playableMO) }
        set {
            if managedObject.playable != newValue?.playableManagedObject { managedObject.playable = newValue?.playableManagedObject }
        }
    }
    
}
