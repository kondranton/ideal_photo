//
//  CameraViewController.swift
//  TrueNorth
//
//  Created by Anton Kondrashov on 31/08/2017.
//  Copyright © 2017 Anton. All rights reserved.
//

import UIKit
import AVFoundation
import Affdex
import Photos

class CameraViewController: UIViewController {
    let anglesLimit: CGFloat = 15
    let emotionsLimit: CGFloat = 0
    let albumName = "demo"
    
    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!{
        didSet{
            statusLabel.layer.cornerRadius = 10
            statusLabel.layer.masksToBounds = true
            statusLabel.layer.borderColor = UIColor.black.cgColor
            statusLabel.layer.borderWidth = 2
        }
    }
    var statusLabelTap: UITapGestureRecognizer?
    
    //MARK - Lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
            if !granted {
                self.update(status: .notAuthorizedCamera)
            } else {
                self.update(status: .processing(warning: nil))
                self.detector.start()
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.detector.stop()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        statusLabelTap = UITapGestureRecognizer(target: self, action: #selector(restart))
        self.view.addGestureRecognizer(statusLabelTap!)
    }
    
    //MARK - Detection
    
    var deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera],
                                                                  mediaType: AVMediaType.video, position: .front)
    lazy var detector: AFDXDetector = {
        return self.createDetector()
    }()
    
    func createDetector() -> AFDXDetector {
        guard let device = deviceDiscoverySession.devices.first else {
            return AFDXDetector()
        }
        
        let detector = AFDXDetector(delegate: self,
                                    using: device,
                                    maximumFaces: UInt(1),
                                    face: LARGE_FACES)!
        
        detector.setDetectAllEmotions(true)
        detector.setDetectAllAppearances(true)
        
        return detector
    }
    
    func destroyDetector() {
        self.detector.stop()
    }
    
    func unprocessedImageReady(from detector: AFDXDetector, image: UIImage, at time: Double){
        DispatchQueue.main.async { [unowned self] in
            self.cameraView.image = image.withHorizontallyFlippedOrientation()
        }
    }
    
    func processedImageReady(from detector: AFDXDetector, image: UIImage, at time: Double, face: AFDXFace){
        guard
            let angles = face.orientation,
            let emotions = face.emotions
            else { return }
        
        let emotionsLevel = abs(emotions.valence)
        let angleSum = abs(angles.yaw) + abs(angles.roll) + abs(angles.pitch)
        
        if (angleSum < anglesLimit && emotionsLevel <= emotionsLimit) {
            self.save(photo: image)
        } else {
            self.processWarning(angles: angleSum, emotions: emotionsLevel)
        }
    }
    
    func processWarning(angles: CGFloat, emotions: CGFloat) {
        switch currentStatus {
        case .processing(_):
            if angles >= anglesLimit {
                update(status: .processing(warning: "Face position is bad"))
            } else if emotions > emotionsLimit {
                update(status: .processing(warning: "Too much emotion"))
            }
        default:
            return
        }
    }
    
    // MARK - Savigng
    
    enum Status {
        case saved
        case processing(warning: String?)
        case notAuthorizedPhoto
        case notAuthorizedCamera
    }
    
    var currentStatus: Status = .notAuthorizedCamera
    
    func save(photo: UIImage) {
        switch currentStatus {
        case .notAuthorizedPhoto:
            fallthrough
        case .saved:
            return
        default:
            PHPhotoLibrary.requestAuthorization { [unowned self] status in
                if status == .authorized {
                    PHPhotoLibrary.save(image: photo, albumName: self.albumName, completion: { (asset) in
                        self.update(status: .saved)
                    })
                } else {
                    self.update(status: .notAuthorizedPhoto)
                }
            }
        }
    }
    
    func update(status: Status) {
        currentStatus = status
        
        DispatchQueue.main.async { [unowned self] in
            switch status {
            case .saved:
                self.statusLabel.text = "Saved. Tap make another photo."
            case .processing(let warning):
                self.statusLabel.text = warning ?? "Processing..."
            case .notAuthorizedPhoto:
                self.statusLabel.text = "Change photo auth settings"
            case .notAuthorizedCamera:
                self.statusLabel.text = "Change camera auth settings"
            }
        }
    }
    
    @objc func restart() {
        switch currentStatus {
        case .saved:
            update(status: .processing(warning: nil)) 
        default:
            return
        }
    }
}

extension CameraViewController: AFDXDetectorDelegate {
    func detectorDidFinishProcessing(_ detector: AFDXDetector!) {
        
    }
    
    func detector(_ detector: AFDXDetector!, didStopDetecting face: AFDXFace!) {
        
    }
    
    func detector(_ detector: AFDXDetector!, didStartDetecting face: AFDXFace!) {
       
    }
    
    func detector(_ detector: AFDXDetector!, hasResults faces: NSMutableDictionary!, for image: UIImage!, atTime time: TimeInterval) {
        if faces != nil, let face = faces.allValues.first as? AFDXFace {
            processedImageReady(from: detector, image: image, at: time, face: face)
        } else {
            unprocessedImageReady(from: detector, image: image, at: time)
        }
    }
}


