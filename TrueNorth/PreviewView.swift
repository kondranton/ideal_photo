//
//  PreviewView.swift
//  TrueNorth
//
//  Created by Anton Kondrashov on 31/08/2017.
//  Copyright © 2017 Anton. All rights reserved.
//

import UIKit
import AVFoundation

class PreviewView: UIView {

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError()
        }
        
        let bounds = self.bounds
        
        layer.bounds = bounds
        layer.videoGravity = .resizeAspectFill
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    // MARK: UIView
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
