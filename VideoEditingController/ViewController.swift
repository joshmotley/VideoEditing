//
//  ViewController.swift
//  VideoEditingController
//
//  Created by Joshua Motley on 3/13/17.
//  Copyright © 2017 Josh Motley. All rights reserved.
//

import UIKit
import AssetsLibrary;
import jot
import AVFoundation
import MobileCoreServices
import Masonry
import Photos

class ViewController: UIViewController, JotViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var jotViewController: JotViewController = JotViewController()
    var saveButton: UIButton = UIButton()
    var clearButton: UIButton = UIButton()
    var toggleDrawingButton: UIButton = UIButton()
    var playerLayer = AVPlayerLayer()
    var asset: AVAsset!
    var didTakeVideo: Bool = false
    
    // MARK: Lifecycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        jotViewController = JotViewController()
        
        jotViewController.delegate = self
        jotViewController.state = .drawing
        jotViewController.textColor = UIColor.black
        jotViewController.font = UIFont(name: "", size: 64)
        jotViewController.fontSize = 64
        jotViewController.textEditingInsets = UIEdgeInsetsMake(12, 6, 0, 6)
        jotViewController.initialTextInsets = UIEdgeInsetsMake(6, 6, 6, 6)
        jotViewController.fitOriginalFontSizeToViewWidth = true
        jotViewController.textAlignment = .left
        jotViewController.drawingColor = UIColor.cyan
        
        saveButton.setTitle("save", for: .normal)
        saveButton.setTitleColor(UIColor.black, for: .normal)
        saveButton.addTarget(self, action: #selector(ViewController.saveAction), for: UIControlEvents.touchUpInside)
        
        clearButton.setTitle("clear", for: .normal)
        clearButton.setTitleColor(UIColor.black, for: .normal)
        clearButton.addTarget(self, action: #selector(ViewController.clearAction), for: UIControlEvents.touchUpInside)
        
        toggleDrawingButton.setTitle("toggle", for: .normal)
        toggleDrawingButton.setTitleColor(UIColor.black, for: .normal)
        toggleDrawingButton.addTarget(self, action: #selector(ViewController.toggleDrawingAction), for: UIControlEvents.touchUpInside)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.addChildViewController(jotViewController)
        self.view.addSubview(jotViewController.view)
        jotViewController.didMove(toParentViewController: self)
        
        self.view.addSubview(saveButton)
        saveButton.frame = CGRect(x: self.view.frame.size.width - 60, y: 10, width: 50, height: 50)
        
        self.view.addSubview(clearButton)
        clearButton.frame = CGRect(x: 10, y: 10, width: 50, height: 50)
        
        self.view.addSubview(toggleDrawingButton)
        toggleDrawingButton.frame = CGRect(x: self.view.frame.size.width - 60, y: self.view.frame.size.height - 60, width: 50, height: 50)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if didTakeVideo == false {
            let pickerController = UIImagePickerController()
            pickerController.delegate = self
            pickerController.sourceType = .photoLibrary
            pickerController.mediaTypes = [kUTTypeMovie as String, kUTTypeAVIMovie as String, kUTTypeVideo as String, kUTTypeMPEG4 as String]
            pickerController.videoQuality = .typeHigh
            didTakeVideo = true
            
            self.present(pickerController, animated: true, completion: nil)
        }
        
    }
    
    // MARK: Video Composition/Editing/Export Methods
    
    func output(image: UIImage){
        
        if asset == nil {
            print("NO ASSET")
            return;
        }
        
        let mixComposition = AVMutableComposition()
        
        let tracks = asset.tracks(withMediaType: AVMediaTypeVideo)
        let videoTrack: AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        try! videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: tracks[0], at: kCMTimeZero)
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration)
        
        let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let videoAssetTrack = tracks[0]
        var videoAssetOrientation = UIImageOrientation.up
        var isVideoAssetPortrait = false
        
        let videoTransform = videoAssetTrack.preferredTransform
        
        if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
            videoAssetOrientation = UIImageOrientation.right;
            isVideoAssetPortrait = true;
        }
        if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
            videoAssetOrientation =  UIImageOrientation.left;
            isVideoAssetPortrait = true;
        }
        if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
            videoAssetOrientation =  UIImageOrientation.up;
        }
        if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
            videoAssetOrientation = UIImageOrientation.down;
        }
        
        videoLayerInstruction.setTransform(videoAssetTrack.preferredTransform, at: kCMTimeZero)
        videoLayerInstruction.setOpacity(0, at: asset.duration)
        
        mainInstruction.layerInstructions = [videoLayerInstruction]
        
        let mainCompositionInst = AVMutableVideoComposition()
        let naturalSize: CGSize
        if isVideoAssetPortrait {
            naturalSize = CGSize(width: videoTrack.naturalSize.height, height: videoTrack.naturalSize.width)
        } else {
            naturalSize = videoAssetTrack.naturalSize;
        }
        
        var renderWidth: CGFloat
        var renderHeight: CGFloat
        renderWidth = naturalSize.width
        renderHeight = naturalSize.height
        mainCompositionInst.renderSize = CGSize(width: renderWidth, height: renderHeight)
        mainCompositionInst.instructions = [mainInstruction]
        mainCompositionInst.frameDuration = CMTimeMake(1, 30)
        
        applyVideoEffectsToComp(composition: mainCompositionInst, size: naturalSize, image:image)
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileURL = documentsURL?.appendingPathComponent("FinalVideo-\(arc4random()).mov")
        
        let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
        exporter.outputURL = fileURL;
        exporter.outputFileType = AVFileTypeQuickTimeMovie;
        exporter.shouldOptimizeForNetworkUse = true;
        exporter.videoComposition = mainCompositionInst;
        exporter.exportAsynchronously(completionHandler: {
            DispatchQueue.main.async {
                switch exporter.status {
                case .failed:
                    print("failed")
                    print(exporter.error!)
                default:
                    print("something else")
                    self.exportDidFinish(session: exporter)
                }

                self.exportDidFinish(session: exporter)
            }
        })
        
        jotViewController.clearAll()
        self.playerLayer.removeFromSuperlayer()
    }
    
    func applyVideoEffectsToComp(composition: AVMutableVideoComposition, size: CGSize, image: UIImage){
        
        let overlayLayer = CALayer()
        overlayLayer.contents = image.cgImage
        overlayLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        overlayLayer.masksToBounds = true
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        videoLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)
        
        parentLayer.removeFromSuperlayer()
        
        composition.animationTool = AVVideoCompositionCoreAnimationTool.init(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    }
    
    func exportDidFinish(session: AVAssetExportSession){
        
        print("Session Stuff \(session) and status \(session.status)")
        if session.status == .completed {
            
            let outputURL = session.outputURL
            
            let asset = AVAsset(url: outputURL!)
            let item = AVPlayerItem(asset: asset)
            
            let avPlayer = AVPlayer(playerItem: item)
            self.playerLayer = AVPlayerLayer(player: avPlayer)
            playerLayer.frame = self.view.bounds;
            self.view.layer.addSublayer(playerLayer)
            avPlayer.play()
        }
    }
    
    // MARK: Image Picker
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true, completion:{
            
            
            let videoNSURL = info[UIImagePickerControllerMediaURL] as! NSURL
            
            let videoURL = NSURL(fileURLWithPath: videoNSURL.path!)
            self.asset = AVAsset(url: videoURL as URL)
            let avPlayer = AVPlayer(url: videoURL as URL)
            self.playerLayer = AVPlayerLayer(player: avPlayer)
            self.playerLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            self.view.layer.insertSublayer(self.playerLayer, below: self.jotViewController.view.layer)
            avPlayer.play()
        })
    }
    
    // MARK: Button Actions
    
    func clearAction() {
        jotViewController.clearAll()
    }
    
    func saveAction() {
        
        let drawnImage = jotViewController.renderImage(withScale: 2, on: UIColor.clear)
        
        output(image: drawnImage!)
        
    }
    
    func toggleDrawingAction() {
        if jotViewController.state == JotViewState.drawing {
            if jotViewController.textString.characters.count == 0 {
                jotViewController.state = JotViewState.editingText;
            } else {
                jotViewController.state = JotViewState.text;
            }
        }else if (self.jotViewController.state == JotViewState.text) {
            jotViewController.state = JotViewState.drawing;
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

