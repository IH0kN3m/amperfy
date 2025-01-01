//
//  PlayerControlView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 07.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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
import MediaPlayer
import MarqueeLabel
import AmperfyKit
import PromiseKit

class PlayerControlView: UIView {
  
    static let frameHeight: CGFloat = 175
    static private let margin = UIEdgeInsets(top: 0, left: UIView.defaultMarginX, bottom: 20, right: UIView.defaultMarginX)
    
    private var player: PlayerFacade!
    private var rootView: PopupPlayerVC?

    #if targetEnvironment(macCatalyst)
    private var airplayVolume: MPVolumeView
    #endif

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var skipBackwardButton: UIButton!
    @IBOutlet weak var skipForwardButton: UIButton!
    
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var liveLabel: UILabel!
    
    @IBOutlet weak var optionsStackView: UIStackView!
    @IBOutlet weak var playerModeButton: UIButton!
    @IBOutlet weak var airplayButton: UIButton!
    @IBOutlet weak var displayPlaylistButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    
    required init?(coder aDecoder: NSCoder) {
        #if targetEnvironment(macCatalyst)
        airplayVolume = MPVolumeView(frame: .zero)
        airplayVolume.showsVolumeSlider = false
        airplayVolume.isHidden = true
        #endif

        super.init(coder: aDecoder)
        self.layoutMargins = Self.margin
        player = appDelegate.player
        player.addNotifier(notifier: self)

        #if targetEnvironment(macCatalyst)
        self.addSubview(airplayVolume)
        #endif
    }

    func prepare(toWorkOnRootView: PopupPlayerVC? ) {
        self.rootView = toWorkOnRootView
        playButton.imageView?.tintColor = .label
        previousButton.tintColor = .label
        nextButton.tintColor = .label
        skipBackwardButton.tintColor = .label
        skipForwardButton.tintColor = .label
        airplayButton.tintColor = .label
        playerModeButton.tintColor = .label
        optionsButton.imageView?.tintColor = .label
        refreshPlayer()
    }
    
    @IBAction func swipeHandler(_ gestureRecognizer : UISwipeGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            rootView?.closePopupPlayer()
        }
    }
    
    @IBAction func playButtonPushed(_ sender: Any) {
        player.togglePlayPause()
        refreshPlayButton()
        refreshPopupBarButtonItmes()
    }
    
    @IBAction func previousButtonPushed(_ sender: Any) {
        switch player.playerMode {
        case .music:
            player.playPreviousOrReplay()
        case .podcast:
            player.skipBackward(interval: player.skipBackwardPodcastInterval)
        }
    }
    
    @IBAction func nextButtonPushed(_ sender: Any) {
        switch player.playerMode {
        case .music:
            player.playNext()
        case .podcast:
            player.skipForward(interval: player.skipForwardPodcastInterval)
        }
    }
    
    @IBAction func skipBackwardButtonPushed(_ sender: Any) {
        player.skipBackward(interval: player.skipBackwardMusicInterval)
    }
    
    @IBAction func skipForwardButtonPushed(_ sender: Any) {
        player.skipForward(interval: player.skipForwardMusicInterval)
    }
    
    @IBAction func timeSliderChanged(_ sender: Any) {
        if let timeSliderValue = timeSlider?.value {
            player.seek(toSecond: Double(timeSliderValue))
        }
    }
    
    @IBAction func timeSliderIsChanging(_ sender: Any) {
        if let timeSliderValue = timeSlider?.value {
            let elapsedClockTime = ClockTime(timeInSeconds: Int(timeSliderValue))
            elapsedTimeLabel.text = elapsedClockTime.asShortString()
            let remainingTime = ClockTime(timeInSeconds: Int(Double(timeSliderValue) - ceil(player.duration)))
            remainingTimeLabel.text = remainingTime.asShortString()
        }
    }
    
    @IBAction func airplayButtonPushed(_ sender: UIButton) {
        appDelegate.userStatistics.usedAction(.airplay)

        #if targetEnvironment(macCatalyst)
        // Position the popup correctly on macOS
        if let buttonCenter = sender.superview?.convert(sender.center, to: self) {
            airplayVolume.center = buttonCenter
        }
        
        for view: UIView in airplayVolume.subviews {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
        #else
        let rect = CGRect(x: -100, y: 0, width: 0, height: 0)
        let airplayVolume = MPVolumeView(frame: rect)
        airplayVolume.showsVolumeSlider = false
        self.addSubview(airplayVolume)
        for view: UIView in airplayVolume.subviews {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
        airplayVolume.removeFromSuperview()
        #endif
    }
    
    @IBAction func displayPlaylistPressed() {
        rootView?.switchDisplayStyleOptionPersistent()
        refreshDisplayPlaylistButton()
        refreshPlayerOptions()
    }
    
    @IBAction func playerModeChangePressed(_ sender: Any) {
        switch player.playerMode {
        case .music:
            appDelegate.player.setPlayerMode(.podcast)
        case .podcast:
            appDelegate.player.setPlayerMode(.music)
        }
        refreshPlayerModeChangeButton()
    }
    
    func refreshView() {
        refreshPlayer()
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshTimeInfo()
        refreshPopupBarButtonItmes()
    }
    
    func refreshPlayButton() {
        var buttonImg = UIImage()
        if player.isPlaying {
            if player.isStopInsteadOfPause {
                buttonImg = UIImage.stop
            } else {
                buttonImg = UIImage.pause
            }
        } else {
            buttonImg = UIImage.play
        }
        playButton.setImage(buttonImg, for: UIControl.State.normal)
    }
    
    func refreshPopupBarButtonItmes() {
        var barButtonItems = [UIBarButtonItem]()
        if player.currentlyPlaying != nil {
            var buttonImg = UIImage()
            if traitCollection.horizontalSizeClass == .regular {
                switch player.playerMode {
                case .music:
                    let shuffleButton = UIBarButtonItem(image: .shuffle, style: .plain, target: rootView?.contextNextQueueSectionHeader, action: #selector(ContextQueueNextSectionHeader.pressedShuffle))
                    shuffleButton.isSelected = player.isShuffle
                    barButtonItems.append( shuffleButton )
                    barButtonItems.append( UIBarButtonItem(image: .backwardFill, style: .plain, target: self, action: #selector(PlayerControlView.previousButtonPushed)) )
                case .podcast:
                    barButtonItems.append( UIBarButtonItem(image: .goBackward15, style: .plain, target: self, action: #selector(PlayerControlView.previousButtonPushed)) )
                }
            }
            
            if player.isPlaying {
                if player.isStopInsteadOfPause {
                    buttonImg = .stop
                } else {
                    buttonImg = .pause
                }
            } else {
                buttonImg = .play
            }
            barButtonItems.append( UIBarButtonItem(image: buttonImg, style: .plain, target: self, action: #selector(PlayerControlView.playButtonPushed)) )
            
            switch player.playerMode {
            case .music:
                buttonImg = .forwardFill
            case .podcast:
                buttonImg = .goForward30
            }
            barButtonItems.append( UIBarButtonItem(image: buttonImg, style: .plain, target: self, action: #selector(PlayerControlView.nextButtonPushed)) )
            
            if traitCollection.horizontalSizeClass == .regular {
                switch player.playerMode {
                case .music:
                    switch player.repeatMode {
                    case .off:
                        buttonImg = .repeatOff
                    case .all:
                        buttonImg = .repeatAll
                    case .single:
                        buttonImg = .repeatOne
                    }
                    let repeatButton = UIBarButtonItem(image: buttonImg, style: .plain, target: rootView?.contextNextQueueSectionHeader, action: #selector(ContextQueueNextSectionHeader.pressedRepeat))
                    repeatButton.isSelected = player.repeatMode != .off
                    barButtonItems.append( repeatButton )
                case .podcast:
                    break
                }
            }
        }
        rootView?.popupItem.trailingBarButtonItems = barButtonItems
    }
    
    func refreshCurrentlyPlayingInfo() {
        switch player.playerMode {
        case .music:
            skipBackwardButton.isHidden = !appDelegate.storage.settings.isShowMusicPlayerSkipButtons
            skipBackwardButton.isEnabled = player.isSkipAvailable
            skipBackwardButton.alpha = !appDelegate.storage.settings.isShowMusicPlayerSkipButtons ? 0.0 : 1.0
            skipForwardButton.isHidden = !appDelegate.storage.settings.isShowMusicPlayerSkipButtons
            skipForwardButton.isEnabled = player.isSkipAvailable
            skipForwardButton.alpha = !appDelegate.storage.settings.isShowMusicPlayerSkipButtons ? 0.0 : 1.0
        case .podcast:
            skipBackwardButton.isHidden = true
            skipBackwardButton.isEnabled = true
            skipForwardButton.isHidden = true
            skipForwardButton.isEnabled = true
        }
    }
    
    private var remainingTime: Int? {
        let duration = player.duration
        if player.currentlyPlaying != nil, duration.isNormal, !duration.isZero {
            return Int(player.elapsedTime - ceil(player.duration))
        }
        return nil
    }

    func refreshTimeInfo() {
        if let currentlyPlaying = player.currentlyPlaying {
            let supportTimeInteraction = !currentlyPlaying.isRadio
            timeSlider.isEnabled = supportTimeInteraction
            timeSlider.minimumValue = 0.0
            timeSlider.maximumValue = Float(player.duration)
            if !timeSlider.isTracking, supportTimeInteraction {
                let elapsedClockTime = ClockTime(timeInSeconds: Int(player.elapsedTime))
                elapsedTimeLabel.text = elapsedClockTime.asShortString()
                if let remainingTime = remainingTime {
                    remainingTimeLabel.text = ClockTime(timeInSeconds: remainingTime).asShortString()
                } else {
                    remainingTimeLabel.text = "--:--"
                }
                timeSlider.value = Float(player.elapsedTime)
            }
                
            if !supportTimeInteraction {
                liveLabel.isHidden = false
                timeSlider.setThumbImage(UIImage(), for: .normal)
                timeSlider.setThumbImage(UIImage(), for: .highlighted)
                timeSlider.minimumValue = 0.0
                timeSlider.maximumValue = 1.0
                timeSlider.value = 0.0
                
                // make the middle part of the time slider transparent
                let mask = CAGradientLayer()
                mask.frame = timeSlider.bounds
                mask.colors = [
                    UIColor.white.cgColor,
                    UIColor.white.withAlphaComponent(0).cgColor,
                    UIColor.white.withAlphaComponent(0).cgColor,
                    UIColor.white.cgColor]
                mask.startPoint = CGPoint(x: 0.0, y: 0.0)
                mask.endPoint = CGPoint(x: 1.0, y: 0.0)
                mask.locations = [
                    0.0, 0.4, 0.6, 1.0]
                timeSlider.layer.mask = mask
                
                elapsedTimeLabel.text = ""
                remainingTimeLabel.text = ""
                rootView?.popupItem.progress = 0.0
            } else {
                liveLabel.isHidden = true
                timeSlider.layer.mask = nil
                timeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .labelColor, for: UIControl.State.normal)
                timeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .labelColor, for: UIControl.State.highlighted)
                let progress = Float(player.elapsedTime / player.duration)
                rootView?.popupItem.progress = progress.isNormal ? progress : 0.0
            }
        } else {
            liveLabel.isHidden = true
            timeSlider.layer.mask = nil
            timeSlider.setUnicolorThumbImage(thumbSize: 10.0, color: .labelColor, for: UIControl.State.normal)
            timeSlider.setUnicolorThumbImage(thumbSize: 30.0, color: .labelColor, for: UIControl.State.highlighted)
            elapsedTimeLabel.text = "--:--"
            remainingTimeLabel.text = "--:--"
            timeSlider.minimumValue = 0.0
            timeSlider.maximumValue = 1.0
            timeSlider.value = 0.0
            rootView?.popupItem.progress = 0.0
        }
    }
    
    func refreshPlayer() {
        refreshCurrentlyPlayingInfo()
        refreshPlayButton()
        refreshPopupBarButtonItmes()
        refreshTimeInfo()
        refreshPrevNextButtons()
        refreshDisplayPlaylistButton()
        refreshPlayerModeChangeButton()
        refreshPlayerOptions()
    }
    
    func refreshPrevNextButtons() {
        previousButton.imageView?.contentMode = .scaleAspectFit
        nextButton.imageView?.contentMode = .scaleAspectFit
        switch player.playerMode {
        case .music:
            previousButton.setImage(UIImage.backwardFill, for: .normal)
            nextButton.setImage(UIImage.forwardFill, for: .normal)
        case .podcast:
            previousButton.setImage(UIImage.goBackward15, for: .normal)
            nextButton.setImage(UIImage.goForward30, for: .normal)
        }
    }
    
    func createPlaybackRateMenu() -> UIMenuElement {
        let playerPlaybackRate = self.player.playbackRate
        let availablePlaybackRates: [UIAction] = PlaybackRate.allCases.compactMap { playbackRate in
            return UIAction(title: playbackRate.description, image: playbackRate == playerPlaybackRate ? .check : nil, handler: { _ in
                self.player.setPlaybackRate(playbackRate)
            })
        }
        return UIMenu(title: "Playback Rate", subtitle: playerPlaybackRate.description, children: availablePlaybackRates)
    }
    
    func createPlayerOptionsMenu() -> UIMenu {
        var menuActions = [UIMenuElement]()
        if player.currentlyPlaying != nil || player.prevQueue.count > 0 || player.userQueue.count > 0 || player.nextQueue.count > 0 {
            let clearPlayer = UIAction(title: "Clear Player", image: .clear, handler: { _ in
                self.player.clearQueues()
            })
            menuActions.append(clearPlayer)
        }
        if player.userQueue.count > 0 {
            let clearUserQueue = UIAction(title: "Clear User Queue", image: .playlistX, handler: { _ in
                self.rootView?.clearUserQueue()
            })
            menuActions.append(clearUserQueue)
        }
        
        menuActions.append(appDelegate.createSleepTimerMenu(refreshCB: nil))
        menuActions.append(createPlaybackRateMenu())
        
        if self.rootView?.largeCurrentlyPlayingView?.isLyricsButtonAllowedToDisplay ?? false {
            if !appDelegate.storage.settings.isPlayerLyricsDisplayed ||
                appDelegate.storage.settings.playerDisplayStyle != .large {
                let showLyricsAction = UIAction(title: "Show Lyrics", image: .lyrics, handler: { _ in
                    if !self.appDelegate.storage.settings.isPlayerLyricsDisplayed {
                        self.appDelegate.storage.settings.isPlayerLyricsDisplayed.toggle()
                        self.rootView?.largeCurrentlyPlayingView?.initializeLyrics()
                    }
                    if self.appDelegate.storage.settings.playerDisplayStyle != .large {
                        self.displayPlaylistPressed()
                    }
                })
                menuActions.append(showLyricsAction)
            } else {
                let hideLyricsAction = UIAction(title: "Hide Lyrics", image: .lyrics, handler: { _ in
                    self.appDelegate.storage.settings.isPlayerLyricsDisplayed.toggle()
                    self.rootView?.largeCurrentlyPlayingView?.initializeLyrics()
                })
                menuActions.append(hideLyricsAction)
            }
        }
        
        switch player.playerMode {
        case .music:
            if player.currentlyPlaying != nil || player.prevQueue.count > 0 || player.nextQueue.count > 0,
               self.appDelegate.storage.settings.isOnlineMode {
                let addContextToPlaylist = UIAction(title: "Add Context Queue to Playlist", image: .playlistPlus, handler: { _ in
                    let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                    var itemsToAdd = self.player.prevQueue.filterSongs()
                    if let currentlyPlaying = self.player.currentlyPlaying, let currentSong = currentlyPlaying.asSong {
                        itemsToAdd.append(currentSong)
                    }
                    itemsToAdd.append(contentsOf: self.player.nextQueue.filterSongs())
                    selectPlaylistVC.itemsToAdd = itemsToAdd
                    let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
                    self.rootView?.present(selectPlaylistNav, animated: true, completion: nil)
                })
                menuActions.append(addContextToPlaylist)
            }
        case .podcast: break
        }
        
        switch self.appDelegate.storage.settings.playerDisplayStyle {
        case .compact:
            let scrollToCurrentlyPlaying = UIAction(title: "Scroll to currently playing", image: .squareArrow, handler: { _ in
                self.rootView?.scrollToCurrentlyPlayingRow()
            })
            menuActions.append(scrollToCurrentlyPlaying)
        case .large: break
        }
        return UIMenu(options: .displayInline, children: menuActions)
    }
    
    func refreshPlayerOptions() {
        var menuTitle = ""
        var remainingTotalPlaytime = 0
        var totalPlaytime = 0
        remainingTotalPlaytime += player.userQueue.reduce(0, { $0 + $1.duration})
        remainingTotalPlaytime += player.nextQueue.reduce(0, { $0 + $1.duration})
        
        totalPlaytime += remainingTotalPlaytime
        totalPlaytime += player.prevQueue.reduce(0, { $0 + $1.duration})
        totalPlaytime += player.currentlyPlaying?.duration ?? 0
        if let remainingTime = self.remainingTime {
            remainingTotalPlaytime -= remainingTime
        } else if let currentlyPlaying = player.currentlyPlaying {
            remainingTotalPlaytime += currentlyPlaying.duration
        }
        
        if remainingTotalPlaytime > 0 {
            menuTitle += "\nRemaining Play Time: \(remainingTotalPlaytime.asDurationString)"
        }
        if totalPlaytime > 0 {
            menuTitle += "\nTotal Play Time: \(totalPlaytime.asDurationString)"
        }
        
        if menuTitle.isEmpty {
            menuTitle = "Player Options"
        } else {
            menuTitle = "Player Info:" + menuTitle
        }
        
        optionsButton.showsMenuAsPrimaryAction = true
        optionsButton.menu = UIMenu.lazyMenu(title: menuTitle) {
            return self.createPlayerOptionsMenu()
        }
    }
    
    func refreshDisplayPlaylistButton() {
        let isSelected = appDelegate.storage.settings.playerDisplayStyle == .compact
        var config = UIButton.Configuration.player(isSelected: isSelected)
        config.image = .playlistDisplayStyle
        displayPlaylistButton.isSelected = isSelected
        displayPlaylistButton.configuration = config
    }
    
    func refreshPlayerModeChangeButton() {
        playerModeButton.isHidden = !appDelegate.storage.settings.libraryDisplaySettings.isVisible(libraryType: .podcasts)
        switch player.playerMode {
        case .music:
            playerModeButton.setImage(UIImage.musicalNotes, for: .normal)
        case .podcast:
            playerModeButton.setImage(UIImage.podcast, for: .normal)
        }
        optionsStackView.layoutIfNeeded()
    }
    
}

extension PlayerControlView: MusicPlayable {

    func didStartPlayingFromBeginning() { }
    
    func didStartPlaying() {
        refreshPlayer()
    }
    
    func didPause() {
        refreshPlayer()
    }
    
    func didStopPlaying() {
        refreshPlayer()
        refreshCurrentlyPlayingInfo()
    }

    func didElapsedTimeChange() {
        refreshTimeInfo()
    }
    
    func didPlaylistChange() {
        refreshPlayer()
    }
    
    func didArtworkChange() {
    }
    
    func didShuffleChange() {
        refreshPopupBarButtonItmes()
    }
    
    func didRepeatChange() {
        refreshPopupBarButtonItmes()
    }
    
    func didPlaybackRateChange() { }

}
