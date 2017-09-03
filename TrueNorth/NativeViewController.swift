//
//  ViewController.swift
//  TrueNorth
//
//  Created by Anton Kondrashov on 31/08/2017.
//  Copyright © 2017 Anton. All rights reserved.
//

import UIKit
import AVFoundation

/*
 Tried to use only native frameworks but they don't have pitch angle.
 And no easy way to get it. Also emotions range is very small.
 */

class ViewController: UIViewController {

    @IBOutlet weak var previewView: PreviewView!
    
    private let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private var setupResult: SessionSetupResult = .success
    
    private let sessionQueue = DispatchQueue(label: "session queue",
                                             attributes: [],
                                             target: nil)
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera],
                                                                               mediaType: AVMediaType.video, position: .unspecified)
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //setup
        previewView.session = session
        
        //permission handling
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            setupResult = .notAuthorized
        }
        
        sessionQueue.async { [unowned self] in
            self.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async { [unowned self] in
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async { [unowned self] in
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [unowned self] in
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    // MARK: Session Configuartion

    var videoDeviceInput: AVCaptureDeviceInput!
    private let metadataOutput = AVCaptureMetadataOutput()
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // Input
            if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                      for: AVMediaType.video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            } else if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera,
                                                                     for: AVMediaType.video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                     for: AVMediaType.video, position: .back) {
                defaultVideoDevice = backCameraDevice
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                
                DispatchQueue.main.async {
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = statusBarOrientation.videoOrientation {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    
                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                }
            } else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Output
        if session.canAddOutput(photoOutput) && session.canAddOutput(metadataOutput) {
            session.addOutput(photoOutput)
            session.addOutput(metadataOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: sessionQueue)
            metadataOutput.metadataObjectTypes = [.face]
        } else {
            print("Could not add output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    // MARK: Capturing Photos
    
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    func capturePhoto() {
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation
        
        sessionQueue.async {
            if let photoOutputConnection = self.photoOutput.connection(with: AVMediaType.video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
            }
            
            var photoSettings = AVCapturePhotoSettings()
            if  self.photoOutput.availablePhotoCodecTypes.contains(AVVideoCodecType(rawValue: AVVideoCodecType.hevc.rawValue)) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.videoDeviceInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }
            
            photoSettings.isHighResolutionPhotoEnabled = true
            if !photoSettings.availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.availablePreviewPhotoPixelFormatTypes.first!]
            }
            
            // Use a separate object for the photo capture delegate to isolate each capture life cycle.
            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, willCapturePhotoAnimation: {
                DispatchQueue.main.async { [unowned self] in
                    self.previewView.videoPreviewLayer.opacity = 0
                    UIView.animate(withDuration: 0.25) { [unowned self] in
                        self.previewView.videoPreviewLayer.opacity = 1
                    }
                }
            }, completionHandler: { [unowned self] photoCaptureProcessor in
                // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                self.sessionQueue.async { [unowned self] in
                    self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                }
                }
            )
            
            self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }
}

extension UIViewController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let face = metadataObjects.first as? AVMetadataFaceObject else { return }
        
        if face.hasYawAngle {
            print("Yaw \(face.yawAngle)")
        }
        
        if face.hasRollAngle {
            print("Roll \(face.rollAngle)")
        }
    }
}

