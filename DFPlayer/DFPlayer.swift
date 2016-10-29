//
//  DFPlayer.swift
//  DFPlayer
//
//  Created by Difff on 16/10/14.
//  Copyright © 2016年 Difff. All rights reserved.
//

import UIKit
import AVFoundation
import NVActivityIndicatorView

enum DFPlayerState: String {
    case Init = "Init"
    case Stopped = "Stopped"
    case Starting = "Starting"
    case Failed = "Failed"
    case Playing = "Playing"
    case Paused = "Paused"
}

private let status = "status"
private let stateQueue = dispatch_queue_create("com.difff.stateQueue", nil)

class DFPlayer: NSObject {

    private(set) var playerItem: AVPlayerItem!
    internal let playerView: DFPlayerView!
    
    // configure
    
    internal var autoStart: Bool = false
    internal var shouldLog: Bool = true

    private let minimumBufferRemainToPlay: Double = 1
    
    private var _state: DFPlayerState = .Init
    private(set) var state: DFPlayerState {
        set {
            guard _state != newValue else { return }
            df_print("DFPlayer: #state# = \(newValue)")

            dispatch_sync(stateQueue) {
                self._state = newValue
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.controlable?.playButton.selected = (self.state == .Playing || self.state == .Starting)
                self.delegate?.playerStateDidChange(newValue)
            })
            
            self.isLoading = detectIsLoading(newValue, isWaitingBuffer: self.isWaitingBuffer)
        }
        get {
            var state: DFPlayerState = .Stopped
            dispatch_sync(stateQueue) {
                state = self._state
            }
            return state
        }
    }
    
    private(set) var isWaitingBuffer: Bool = false {
        willSet {
            guard isWaitingBuffer != newValue else { return }
            df_print("DFPlayer: isWaitingBuffer = \(newValue)")
            dispatch_async(dispatch_get_main_queue()) {
                if newValue {
                    self.df_print("DFPlayer: >>>>>> waiting buffer...")
                    self.playerView.player?.pause()
                } else {
                    self.df_print("DFPlayer: <<<<<< buffered, likely to play")
                    if self.state != .Paused {
                        self.play()
                    }
                }
                self.isLoading = self.detectIsLoading(self.state, isWaitingBuffer: newValue)
            }
        }
    }
    
    private(set) var isLoading: Bool = false {
        willSet {
            guard isLoading != newValue else { return }
            df_print("DFPlayer: isLoading = \(newValue)")
            dispatch_async(dispatch_get_main_queue()) {
                if newValue {
                    self.playerView.loadingView?.startAnimation()
                    self.delegate?.startLoading()
                } else {
                    self.playerView.loadingView?.stopAnimation()
                    self.delegate?.stopLoading()
                }
            }
        }
    }
    
    private(set) var isFinished: Bool = false {
        willSet {
            guard isFinished != newValue else { return }
            df_print("DFPlayer: isFinished = \(newValue)")
            self.isWaitingBuffer = false
            dispatch_async(dispatch_get_main_queue()) {
                if newValue {
                    self.delegate?.didFinished()
                }
            }
        }
    }
    
    private(set) var itemDurationSeconds: NSTimeInterval = 0 {
        willSet {
            guard itemCurrentSecond != newValue else { return }
            dispatch_async(dispatch_get_main_queue(), {
                let duration = self.itemDurationSeconds
                self.df_print("DFPlayer: duration = \(duration) seconds")
                self.controlable?.durationSecondsLabel.text = Int(duration).df_toHourFormat()
                self.delegate?.durationSeconds(duration)
            })
        }
    }
    
    private(set) var itemLoadedSeconds: NSTimeInterval = 0 {
        willSet {
            guard itemLoadedSeconds != newValue else { return }
            dispatch_async(dispatch_get_main_queue(), {
                let loaded = self.itemLoadedSeconds
                self.df_print("DFPlayer: loaded = \(loaded) seconds")
                let duration = self.itemDurationSeconds
                guard loaded >= 0 && duration > 0 else { return }
                let progress = Float(loaded)/Float(duration)
                self.controlable?.loadedProgress.setProgress(progress, animated: true)
                self.delegate?.loadedSecondsDidChange(loaded)
            })
        }
    }
    
    private(set) var itemCurrentSecond: NSTimeInterval = 0 {
        willSet {
            guard itemCurrentSecond != newValue else { return }
            dispatch_async(dispatch_get_main_queue(), {
                let current = self.itemCurrentSecond
                self.df_print("DFPlayer: current = \(current) second")
                if let ctrlPanel = self.controlable {
                    ctrlPanel.currentSecondLabel.text = Int(current).df_toHourFormat()
                    if !ctrlPanel.isSliderTouching && !self.seeking {
                        ctrlPanel.playingSlider.value = Float(current/self.itemDurationSeconds)
                    }
                }
                self.delegate?.currentSecondDidChange(self.itemCurrentSecond)
            })
        }
    }
    private(set) var itemBufferRemainSeconds: NSTimeInterval = 0 {
        willSet {
            guard itemBufferRemainSeconds != newValue else { return }
            df_print("DFPlayer: bufferRemain = \(self.itemBufferRemainSeconds) seconds")
        }
    }

    private(set) var seeking = false
    
    private weak var delegate: DFPlayerDelagate?
    
    weak var controlable: DFPlayerControlable? {
        willSet {
            controlable?.container.removeFromSuperview()
        }
        didSet {
            guard let container = controlable?.container else { return }
            playerView.df_addMaskView(container)
            playerView.bringSubviewToFront(container)
        }
    }
    weak var maskable: DFPlayerMaskable? {
        willSet {
            maskable?.container.removeFromSuperview()
        }
        didSet {
            guard let container = maskable?.container else { return }
            playerView.df_addMaskView(container)
            playerView.sendSubviewToBack(container)
        }
    }
    
    private var timer: NSTimer?

    override init() {
        fatalError("use init(:AVPlayerItem)")
    }
    
    deinit {
        print("deinit: - \(self)")
        removeObserverForPlayItemStatus()
        removeTimer()
    }

    init(playerItem: AVPlayerItem, delegate: DFPlayerDelagate? = nil, loadingView: NVActivityIndicatorView?) {
        
        self.playerItem = playerItem
        self.playerView = DFPlayerView(player: AVPlayer(playerItem: playerItem), loadingView: loadingView)
        
        
        super.init()
        
        addObserverForPlayItemStatus()
        self.delegate = delegate
        
        if autoStart {
            start()
        } else {
            stop()
        }

    }
    
    
    internal func stop() {
        dispatch_async(dispatch_get_main_queue()) {
            self.playerView.player?.replaceCurrentItemWithPlayerItem(nil)
        }
        state = .Stopped
    }
    
    internal func start() {
        dispatch_async(dispatch_get_main_queue()) {
            if self.playerView.player?.currentItem == nil {
                self.playerView.player?.replaceCurrentItemWithPlayerItem(self.playerItem)
            }
        }
        state = .Starting
    }
    
    internal func play() {
        dispatch_async(dispatch_get_main_queue()) { 
            self.playerView.player?.play()
        }
        state = .Playing
    }
    
    internal func pause() {
        dispatch_async(dispatch_get_main_queue()) {
            self.playerView.player?.pause()
        }
        state = .Paused
    }
    
    private func setFailed() {
        state = .Failed
    }
    
    internal func seek(seekSecond: Double) {
        guard itemDurationSeconds > 0 && seekSecond < itemDurationSeconds else { return }
        df_print("DFPlayer: >>>>>> seeking begin")
        
        seeking = true
        let time = CMTime(value: Int64(seekSecond), timescale: 1)
        dispatch_async(dispatch_get_main_queue()) {
            self.playerView.player?.seekToTime(time, completionHandler: { [weak self](_) in
                guard let _self = self else { return }
                _self.seeking = false
                _self.df_print("DFPlayer: <<<<<< seeking end")
            })
        }
    }
    
    private func addTimer() {
        timer = NSTimer.scheduledTimerWithTimeInterval(0.3, action: { [weak self](_) in
            guard let _self = self else { return }
                _self.track()
            }, repeats: true)
    }
    
    private func removeTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func addObserverForPlayItemStatus() {
        playerItem.addObserver(self, forKeyPath: status, options: [.Initial, .New], context: nil)
    }
    
    private func removeObserverForPlayItemStatus() {
        playerItem.removeObserver(self, forKeyPath: status)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        let playerItem = object as! AVPlayerItem
        if keyPath == status {
            switch playerItem.status {
            case .Unknown:
                break
            case .Failed:
                setFailed()
                break
            case .ReadyToPlay:
                countItemDurationSeconds()
                addTimer()
                play()
                break
            }
        }
    }
    
    private func track() {
        guard !isFinished else { return }
        countItemCurrentSecond()
        countItemLoadedSeconds()
        isWaitingBuffer =
            detectIsWaitingBuffer(currentSecond: itemCurrentSecond, loadedSeconds: itemLoadedSeconds)
        isFinished = detectIsFinished(currentSecond: itemCurrentSecond)
    }
    
    // {currentSecond} => isFinished
    private func detectIsFinished(currentSecond currentSecond: Double) -> Bool {
        guard itemDurationSeconds > 0 else { return false }
        return fabs(itemDurationSeconds-currentSecond) < 1
    }
    
    // {state, isWaitingBuffer} => isLoading
    private func detectIsLoading(state: DFPlayerState, isWaitingBuffer: Bool) -> Bool {
        if state == .Starting || (isWaitingBuffer && state == .Playing) {
            return true
        }
        return false
    }
    
    // {currentSecond, loadedSeconds} => isWaitingBuffer
    private func detectIsWaitingBuffer(currentSecond currentSecond: Double, loadedSeconds: Double) -> Bool {
        
        // for network throttling case
        if seeking {
            return true // else should not return false
        }
        
        guard itemLoadedSeconds > 0 else { return true }
        itemBufferRemainSeconds = itemLoadedSeconds - itemCurrentSecond
        return itemBufferRemainSeconds <= self.minimumBufferRemainToPlay ? true : false
    }
    
    private func countItemDurationSeconds() {
        itemDurationSeconds = Double(playerItem.duration.value) / Double(playerItem.duration.timescale)
    }
    
    private func countItemCurrentSecond() {
        let rawValue = Double(playerItem.currentTime().value) / Double(playerItem.currentTime().timescale)
        itemCurrentSecond = Double(round(1000*rawValue)/1000)
    }
    
    private func countItemLoadedSeconds() {
        let loadedTimeRanges = playerView.player?.currentItem?.loadedTimeRanges
        guard let timeRange = loadedTimeRanges?.first?.CMTimeRangeValue else { return }
        
        let startSecond = Double(CMTimeGetSeconds(timeRange.start))
        let durationSeconds = Double(CMTimeGetSeconds(timeRange.duration))
        let loadedSeconds = startSecond + durationSeconds
        
        // loadedSeconds may a little bit bigger than itemDurationSeconds
        itemLoadedSeconds = fmin(loadedSeconds, itemDurationSeconds)
    }
}

extension DFPlayer {
    func df_print(str: String) {
        if shouldLog {
            print(str)
        }
    }
}



