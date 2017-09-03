//
//  Extensions.swift
//  TrueNorth
//
//  Created by Anton Kondrashov on 31/08/2017.
//  Copyright © 2017 Anton. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Affdex

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}

extension AVCaptureDevice.DiscoverySession {
    func uniqueDevicePositionsCount() -> Int {
        var uniqueDevicePositions: [AVCaptureDevice.Position] = []
        
        for device in devices {
            if !uniqueDevicePositions.contains(device.position) {
                uniqueDevicePositions.append(device.position)
            }
        }
        
        return uniqueDevicePositions.count
    }
}


extension PHPhotoLibrary {
    
    typealias PhotoAsset = PHAsset
    typealias PhotoAlbum = PHAssetCollection
    
    static func save(image: UIImage, albumName: String, completion: @escaping (PHAsset?)->()) {
        if let album = self.findAlbum(albumName: albumName) {
            self.saveImage(image: image, album: album, completion: completion)
            return
        }
        createAlbum(albumName: albumName) { album in
            if let album = album {
                self.saveImage(image: image, album: album, completion: completion)
            }
            else {
                assert(false, "Album is nil")
            }
        }
    }
    
    static private func saveImage(image: UIImage, album: PhotoAlbum, completion: @escaping (PHAsset?)->()) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            // Request creating an asset from the image
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            // Request editing the album
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
                assert(false, "Album change request failed")
                return
            }
            // Get a placeholder for the new asset and add it to the album editing request
            guard let photoPlaceholder = createAssetRequest.placeholderForCreatedAsset else {
                assert(false, "Placeholder is nil")
                return
            }
            placeholder = photoPlaceholder
            albumChangeRequest.addAssets([photoPlaceholder] as NSArray)
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                assert(false, "Placeholder is nil")
                completion(nil)
                return
            }
            
            if success {
                completion(PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject)
            }
            else {
                print(error)
                completion(nil)
            }
        })
    }
    
    static func findAlbum(albumName: String) -> PhotoAlbum? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let fetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
        guard let photoAlbum = fetchResult.firstObject as? PHAssetCollection else {
            return nil
        }
        return photoAlbum
    }
    
    static func createAlbum(albumName: String, completion: @escaping (PhotoAlbum?)->()) {
        var albumPlaceholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            // Request creating an album with parameter name
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            // Get a placeholder for the new album
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }, completionHandler: { success, error in
            guard let placeholder = albumPlaceholder else {
                assert(false, "Album placeholder is nil")
                completion(nil)
                return
            }
            
            let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
            guard let album = fetchResult.firstObject as? PhotoAlbum else {
                assert(false, "FetchResult has no PHAssetCollection")
                completion(nil)
                return
            }
            
            if success {
                completion(album)
            }
            else {
                print(error)
                completion(nil)
            }
        })
    }
    
    static func loadThumbnailFromLocalIdentifier(localIdentifier: String, completion: @escaping (UIImage?)->()) {
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        loadThumbnailFromAsset(asset: asset.firstObject, completion: completion)
    }
    
    static func loadThumbnailFromAsset(asset: PhotoAsset?, completion: @escaping (UIImage?)->()) {
        PHImageManager.default().requestImage(for: asset!, targetSize: CGSize(width: 100.0, height: 100.0), contentMode: .aspectFit, options: PHImageRequestOptions(), resultHandler: { result, info in
            completion(result)
        })
    }
}

