//
//  ViewController.swift
//  VideoEditingController
//
//  Created by Joshua Motley on 3/17/17.
//  Copyright © 2017 Josh Motley. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, EditingViewControllerDelegate {
    
    var playerLayer = AVPlayerLayer()

    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()


    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        playerLayer.frame = self.view.frame

    }
    
    // MARK: Button Actions
    
    @IBAction func selectAVideo(_ sender: Any) {
        
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.sourceType = .photoLibrary
        pickerController.mediaTypes = [kUTTypeMovie as String, kUTTypeAVIMovie as String, kUTTypeVideo as String, kUTTypeMPEG4 as String]
        pickerController.videoQuality = .typeHigh
        
        self.present(pickerController, animated: true, completion: nil)
    }
    
    // MARK: Image Picker
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true, completion:{
            
            let videoNSURL = info[UIImagePickerControllerMediaURL] as! NSURL
//
            let videoURL = NSURL(fileURLWithPath: videoNSURL.path!)
            let asset = AVAsset(url: videoURL as URL)
//
            let edi = EditingViewController()
            edi.delegate = self
            edi.asset = asset
            self.present(edi, animated: true, completion: nil)
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let fileURL = documentsURL?.appendingPathComponent("ReversedVideo-\(arc4random()).mov")
            
//            EditingUtilities().reverseVid(asset, completion: { (reversedURL) in
//                let avPlayer = AVPlayer(url: reversedURL)
//                let playerLayer = AVPlayerLayer(player: avPlayer)
//                playerLayer.frame = self.view.bounds;
//                playerLayer.backgroundColor = UIColor.orange.cgColor
//                self.view.layer.addSublayer(playerLayer)
//                avPlayer.play()
//                
//                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main, using: { (_) in
//                    avPlayer.seek(to: kCMTimeZero)
//                    avPlayer.play()
//                })
//            })

//            EditingUtilities().duplicateVideo(asset, completion: { (duplicatedURL) in
//                let avPlayer = AVPlayer(playerItem: duplicatedURL)
//                let playerLayer = AVPlayerLayer(player: avPlayer)
//                playerLayer.frame = self.view.bounds;
//                playerLayer.backgroundColor = UIColor.orange.cgColor
//                self.view.layer.addSublayer(playerLayer)
//                avPlayer.play()
//                
//                
//            })

        })
        
        
    }
    
    // MARK: Editing Delegate
    
    func didFinishEditing(sender: EditingViewController, asset: AVAsset) {
        
        
        let item = AVPlayerItem(asset: asset)

        let avPlayer = AVPlayer(playerItem: item)
        playerLayer.player = avPlayer
        self.view.layer.addSublayer(playerLayer)
        avPlayer.play()

        
        print("Asset \(asset) Player \(avPlayer) Layer \(playerLayer)")
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main, using: { (_) in
            avPlayer.seek(to: kCMTimeZero)
            avPlayer.play()
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
