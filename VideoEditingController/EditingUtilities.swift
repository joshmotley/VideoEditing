//
//  EditingUtilities.swift
//  VideoEditingController
//
//  Created by Joshua Motley on 3/21/17.
//  Copyright © 2017 Josh Motley. All rights reserved.
//

import UIKit
import AVFoundation

class EditingUtilities: NSObject {
    
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
    
    func duplicateVideo(_ asset: AVAsset, completion: @escaping (AVPlayerItem) -> Void) {
        
        let mutableComposition = AVMutableComposition()
        let videoCompTrack: AVMutableCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioCompTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)

        let assetTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first

        do {
            try videoCompTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: assetTrack!, at: kCMTimeZero)
            try videoCompTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: assetTrack!, at: asset.duration)
        } catch {
            print("fail")
        }
        
        
        let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
        videoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(asset.duration, asset.duration))
        
        let videoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompTrack)
        let videotCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompTrack)
        

        var isVideoAssetPortrait = false
        
        let videoTransform = assetTrack!.preferredTransform
        
        if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
            isVideoAssetPortrait = true;
        }
        if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
            isVideoAssetPortrait = true;
        }

        
        videoCompositionLayerInstruction.setTransform(assetTrack!.preferredTransform, at: kCMTimeZero)
        videotCompositionLayerInstruction.setTransform(assetTrack!.preferredTransform, at: kCMTimeZero)

        let naturalSize: CGSize
        if isVideoAssetPortrait {
            naturalSize = CGSize(width: videoCompTrack.naturalSize.height, height: videoCompTrack.naturalSize.width)
        } else {
            naturalSize = assetTrack!.naturalSize;
        }

        videoCompositionInstruction.layerInstructions = [videoCompositionLayerInstruction, videotCompositionLayerInstruction]
        
        let mutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.instructions = [videoCompositionInstruction]
        
        mutableVideoComposition.frameDuration = CMTimeMake(1, 30)
        mutableVideoComposition.renderSize = naturalSize

        let pi = AVPlayerItem(asset: mutableComposition)
        pi.videoComposition = mutableVideoComposition
        
        completion(pi)

        
        
        
    }
}

