//
//  DFPlayerStateEyeable.swift
//  DFPlayer
//
//  Created by Difff on 16/10/15.
//  Copyright © 2016年 Difff. All rights reserved.
//

import UIKit

protocol DFPlayerControlEyeable: class {
    // @required
    var cp_container: UIView { get }
    
    // @optional
    var playButton: UIButton { get }
    var backButton: UIButton { get }
    var titleLabel: UILabel { get }
    var currentSecondLabel: UILabel { get }
    var durationSecondsLabel: UILabel { get }
    var loadedProgress: UIProgressView { get }
    var playingSlider: UISlider { get }
    
    func didTapPlayButton()
    func didTapBackButton()
    func titleForVideo() -> String
    
    /* for layout & style */
    func setupPlayerControlPanel()
}

// DFPlayerStateEyeable: Default Implementaion
private class DFAssociation: NSObject {
    static let sharedInstance = DFAssociation()
    private override init() {}
    
    let playButton = UIButton()
    let backButton = UIButton()
    let titleLabel = UILabel()
    let currentSecondLabel = UILabel()
    let durationSecondsLabel = UILabel()
    let loadedProgress = UIProgressView()
    let playingSlider = DFTimeSlider()
    
}

extension DFPlayerControlEyeable {
    
    var playButton: UIButton {
        get {
            return DFAssociation.sharedInstance.playButton
        }
    }
    
    var backButton: UIButton {
        get {
            return DFAssociation.sharedInstance.backButton
        }
    }
    
    var titleLabel: UILabel {
        get {
            return DFAssociation.sharedInstance.titleLabel
        }
    }
    
    var currentSecondLabel: UILabel {
        get {
            return DFAssociation.sharedInstance.currentSecondLabel
        }
    }
    
    var durationSecondsLabel: UILabel {
        get {
            return DFAssociation.sharedInstance.durationSecondsLabel
        }
    }
    
    var loadedProgress: UIProgressView {
        get {
            return DFAssociation.sharedInstance.loadedProgress
        }
    }
    
    var playingSlider: UISlider {
        get {
            return DFAssociation.sharedInstance.playingSlider
        }
    }

    func didTapPlayButton() {}
    
    func didTapBackButton() {}
    
    func titleForVideo() -> String {
        return ""
    }
    
    func setupPlayerControlPanel() {
        
        cp_container.df_addSubviews([playButton, backButton, titleLabel, currentSecondLabel, durationSecondsLabel, loadedProgress, playingSlider])
        
        backButton.snp_makeConstraints { (make) in
            make.centerY.equalTo(cp_container.snp_top).offset(64/2)
            make.centerX.equalTo(cp_container.snp_left).offset(16+6)
            make.width.height.equalTo(64)
        }
        backButton.setImage(UIImage(named: "back"), forState: .Normal)
        backButton.addAction({ [weak self](_) in
            guard let _self = self else { return }
            _self.didTapBackButton()
            }, forControlEvents: .TouchUpInside)
        
        titleLabel.snp_makeConstraints { (make) in
            make.centerY.equalTo(backButton)
            make.left.equalTo(backButton.snp_centerX).offset(16)
        }
        titleLabel.textColor = UIColor.whiteColor()
        titleLabel.text = titleForVideo()
        
        playButton.snp_makeConstraints { (make) in
            make.left.equalTo(cp_container).offset(16)
            make.centerY.equalTo(cp_container.snp_bottom).offset(-20)
            make.width.height.equalTo(30)
        }
        playButton.setImage(UIImage(named: "to_play"), forState: .Normal)
        playButton.setImage(UIImage(named: "to_pause"), forState: .Selected)
        playButton.selected = false
        playButton.addAction({ [weak self](_) in
            guard let _self = self else { return }
            _self.didTapPlayButton()
            }, forControlEvents: .TouchUpInside)
        
        
        currentSecondLabel.snp_makeConstraints { (make) in
            make.left.equalTo(playButton.snp_right).offset(5)
            make.centerY.equalTo(playButton)
            make.width.equalTo(35) // must
        }
        currentSecondLabel.font = UIFont.systemFontOfSize(12)
        currentSecondLabel.textColor = UIColor.whiteColor()
        currentSecondLabel.text = "00:00"
        
        durationSecondsLabel.snp_makeConstraints { (make) in
            make.right.equalTo(cp_container).offset(-16)
            make.centerY.equalTo(playButton)
        }
        durationSecondsLabel.font = UIFont.systemFontOfSize(12)
        durationSecondsLabel.textColor = UIColor.whiteColor()
        durationSecondsLabel.text = "00:00"
        
        loadedProgress.snp_makeConstraints { (make) in
            make.left.equalTo(currentSecondLabel.snp_right).offset(5)
            make.right.equalTo(durationSecondsLabel.snp_left).offset(-5)
            make.centerY.equalTo(playButton)
            make.height.equalTo(2.5)
        }
        
        loadedProgress.trackTintColor = UIColor.whiteColor()
        loadedProgress.progressTintColor = UIColor.greenColor()
        loadedProgress.progress = 0
        
        playingSlider.snp_makeConstraints { (make) in
            make.edges.equalTo(loadedProgress)
        }
        
        playingSlider.value = 0
    }
}

private class DFTimeSlider: UISlider {
    override func trackRectForBounds(bounds: CGRect) -> CGRect {
        // change height
        let customBounds = CGRect(origin: bounds.origin, size: CGSize(width: bounds.size.width, height: 2.5))
        super.trackRectForBounds(customBounds)
        return customBounds
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setThumbImage(UIImage(named: "slider_thumb"), forState: .Normal)
        self.maximumTrackTintColor = UIColor.clearColor()
        self.minimumTrackTintColor = UIColor.orangeColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension UIView {
    func df_addSubviews(subviews: [UIView]) {
        for view in subviews {
            self.addSubview(view)
        }
    }
}



