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

protocol EditingViewControllerDelegate: class {
    func didFinishEditing(sender: EditingViewController, asset: AVAsset)
}

class EditingViewController: UIViewController, JotViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var jotViewController: JotViewController = JotViewController()
    
    var saveButton: UIButton = UIButton()
    var clearButton: UIButton = UIButton()
    var toggleDrawingButton: UIButton = UIButton()
    var reverseButton: UIButton = UIButton()
    var duplicateButton: UIButton = UIButton()
    
    var playerLayer = AVPlayerLayer()
    var avPlayer = AVPlayer()
    var asset: AVAsset!
    
    var didTakeVideo: Bool = false
    var shouldReverse: Bool = false
    var shouldDuplicate: Bool = false
    
    weak var delegate:EditingViewControllerDelegate?
    
    // MARK: Lifecycle
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
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
        
        view.backgroundColor = UIColor.white
        
        saveButton.setTitle("save", for: .normal)
        saveButton.setTitleColor(UIColor.black, for: .normal)
        saveButton.addTarget(self, action: #selector(EditingViewController.saveAction), for: UIControlEvents.touchUpInside)
        
        clearButton.setTitle("clear", for: .normal)
        clearButton.setTitleColor(UIColor.black, for: .normal)
        clearButton.addTarget(self, action: #selector(EditingViewController.clearAction), for: UIControlEvents.touchUpInside)
        
        toggleDrawingButton.setTitle("toggle", for: .normal)
        toggleDrawingButton.setTitleColor(UIColor.black, for: .normal)
        toggleDrawingButton.addTarget(self, action: #selector(EditingViewController.toggleDrawingAction), for: UIControlEvents.touchUpInside)
        
        reverseButton.setTitle("reverse", for: .normal)
        reverseButton.setTitleColor(UIColor.black, for: .normal)
        reverseButton.setTitleColor(UIColor.orange, for: .selected)
        reverseButton.addTarget(self, action: #selector(EditingViewController.reverseAction), for: UIControlEvents.touchUpInside)
        
        duplicateButton.setTitle("duplicate", for: .normal)
        duplicateButton.setTitleColor(UIColor.black, for: .normal)
        duplicateButton.setTitleColor(UIColor.orange, for: .selected)
        duplicateButton.addTarget(self, action: #selector(EditingViewController.duplicateAction), for: UIControlEvents.touchUpInside)
    }
    
    func reverseAction() {
        
        if shouldReverse == false{
            shouldReverse = true
            reverseButton.isSelected = true
        }else{
            shouldReverse = false
            reverseButton.isSelected = false
        }
    }
    
    func duplicateAction() {
        
        if shouldDuplicate == false{
            shouldDuplicate = true
            duplicateButton.isSelected = true
        }else{
            shouldDuplicate = false
            duplicateButton.isSelected = false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addChildViewController(jotViewController)
        self.view.addSubview(jotViewController.view)
        jotViewController.didMove(toParentViewController: self)
        
        self.view.addSubview(saveButton)
        saveButton.frame = CGRect(x: self.view.frame.size.width - 60, y: 10, width: 50, height: 50)
        
        self.view.addSubview(clearButton)
        clearButton.frame = CGRect(x: 10, y: 10, width: 50, height: 50)
        
        self.view.addSubview(reverseButton)
        reverseButton.frame = CGRect(x: 90, y: 10, width: 70, height: 50)
        
        self.view.addSubview(duplicateButton)
        duplicateButton.frame = CGRect(x: 10, y: self.view.frame.size.height - 60, width: 70, height: 50)
        
        self.view.addSubview(toggleDrawingButton)
        toggleDrawingButton.frame = CGRect(x: self.view.frame.size.width - 60, y: self.view.frame.size.height - 60, width: 75, height: 50)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let avItem = AVPlayerItem(asset: asset)
        avPlayer = AVPlayer(playerItem: avItem)
        self.playerLayer = AVPlayerLayer(player: avPlayer)
        self.playerLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        self.view.layer.insertSublayer(self.playerLayer, below: self.jotViewController.view.layer)
        avPlayer.play()
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main, using: { (_) in
            self.avPlayer.seek(to: kCMTimeZero)
            self.avPlayer.play()
        })
        
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
        var isVideoAssetPortrait = false
        
        var secondVideoLayerInstruction: AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction()
        
        if shouldDuplicate {
            try! videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: tracks[0], at: asset.duration)
            secondVideoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            secondVideoLayerInstruction.setTransform(videoAssetTrack.preferredTransform, at: kCMTimeZero)
            mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(asset.duration, asset.duration))
        }

        let videoTransform = videoAssetTrack.preferredTransform
        
        if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {

            isVideoAssetPortrait = true;
        }
        if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {

            isVideoAssetPortrait = true;
        }
        
        videoLayerInstruction.setTransform(videoAssetTrack.preferredTransform, at: kCMTimeZero)
        
        mainInstruction.layerInstructions = [videoLayerInstruction]
        
        if shouldDuplicate {
            mainInstruction.layerInstructions = [videoLayerInstruction, secondVideoLayerInstruction]
        }
        
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
        
        addImageToComposition(composition: mainCompositionInst, size: naturalSize, image:image)
        
        
        
        
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
            }
        })
        
        jotViewController.clearAll()
        self.avPlayer.pause()
        self.playerLayer.removeFromSuperlayer()
    }
    
    func addImageToComposition(composition: AVMutableVideoComposition, size: CGSize, image: UIImage){
        
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
        
        if session.status == .completed {
            
            let outputURL = session.outputURL
            
            let asset = AVAsset(url: outputURL!)
            
            if shouldReverse {
                
                EditingUtilities().reverseVid(asset, completion: { (outputU) in
                    self.dismiss(animated: true, completion: {
                        let outputURL = outputU
                        
                        let asset = AVAsset(url: outputURL)
                        
                        self.delegate?.didFinishEditing(sender: self, asset: asset)
                    })
                })
                
            }else{
                
                self.dismiss(animated: true, completion: {
                    
                    self.delegate?.didFinishEditing(sender: self, asset: AVAsset(url: session.outputURL!))
                })
            }
        }    }
    
    
    func reverseVid(_ asset: AVAsset, completion: @escaping (URL) -> Void) {
        
        var reader: AVAssetReader! = nil
        do{
            reader = try AVAssetReader(asset: asset)
        }catch{
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).last else {
            return
        }
        
        let outputSettings: NSDictionary = [kCVPixelBufferPixelFormatTypeKey : NSNumber(integerLiteral: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange))]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings as? [String : Any])
        reader.add(readerOutput)
        reader.startReading()
        
        var samples: [CMSampleBuffer] = []
        while let sample = readerOutput.copyNextSampleBuffer() {
            samples.append(sample)
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileURL = documentsURL?.appendingPathComponent("ReversedVideo-\(arc4random()).mov")
        
        let assetWriter: AVAssetWriter
        do {
            assetWriter = try AVAssetWriter(outputURL: fileURL!, fileType: AVFileTypeQuickTimeMovie)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        
        let videoCompositionProps = [AVVideoAverageBitRateKey: videoTrack.estimatedDataRate]
        let videoWriterSettings = [AVVideoCodecKey: AVVideoCodecH264,
                                   AVVideoWidthKey: videoTrack.naturalSize.width,
                                   AVVideoHeightKey: videoTrack.naturalSize.height,
                                   AVVideoCompressionPropertiesKey: videoCompositionProps] as [String : Any]
        
        let writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoWriterSettings)
        
        writerInput.expectsMediaDataInRealTime = false
        
        writerInput.transform = videoTrack.preferredTransform
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
        
        assetWriter.add(writerInput)
        
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(samples.first!))
        
        for (i, sample) in samples.enumerated() {
            
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample)
            let imageBufferRef = CMSampleBufferGetImageBuffer(samples[samples.count - 1 - i])
            
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            pixelBufferAdaptor.append(imageBufferRef!, withPresentationTime: presentationTime)
        }
        
        assetWriter.finishWriting {
            completion(fileURL!)
        }
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

