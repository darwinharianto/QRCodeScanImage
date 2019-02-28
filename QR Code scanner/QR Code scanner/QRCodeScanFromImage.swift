//
//  QRCodeScanFromImage.swift
//  Reader
//
//  Created by Darwin Harianto on 2019/02/05.
//  Copyright © 2019 Darwin Harianto. All rights reserved.
//

import UIKit
import AVFoundation

protocol QRCodeScanImageDelegateProtocol{
    func CameraAccessGranted()
    func didGetProcessedImage(image: UIImage, data: [String])
}

class QRCodeScanFromImage: NSObject, AVCapturePhotoCaptureDelegate {
    
    
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let sessionQueue = DispatchQueue(label: "session queue",
                                     attributes: [],
                                     target: nil)
    
    var video : AVCaptureVideoPreviewLayer!
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    var setupResult: SessionSetupResult = .success
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    
    var delegate: QRCodeScanImageDelegateProtocol?
    
    func setupTakingImageForQRScan(){
        checkAuthorization()
        
        
        self.configureSession()
        
    }
    
    func checkCameraAvailabilityForTakingImage(){
        switch self.setupResult {
        case .success:
            // Only start the session running if setup succeeded.
            //                DispatchQueue.main.async { [unowned self] in
            //                    self.video = AVCaptureVideoPreviewLayer(session: self.session)
            //                    self.video.frame = self.previewView.bounds
            //                    self.previewView.layer.addSublayer(self.video)
            //                    self.session.startRunning()
            //                }
            self.delegate?.CameraAccessGranted()
            //Start rolling camera
            break;
            
        case .notAuthorized: break
            
        case .configurationFailed: break
            
            
        }
    }
    
    func capturePhoto(){
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = false
        if self.videoDeviceInput.device.isFlashAvailable {
            photoSettings.flashMode = .auto
        }
        
        if let firstAvailablePreviewPhotoPixelFormatTypes = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: firstAvailablePreviewPhotoPixelFormatTypes]
        }
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func deg2rad(_ number: CGFloat) -> CGFloat {
        return number * .pi / 180
    }
    
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)  else {
                return
        }
        
        let newImage = image.rotate(radians: deg2rad(0))
        let (a,b) = checkForQRCode(newImage: newImage)
        
        delegate?.didGetProcessedImage(image: b, data: a)
        
    }
    
    func stopCameraFromTakingImage(){
        
        if self.setupResult == .success {
            self.session.stopRunning()
        }
        
        
    }
    
    func checkAuthorization() {
        /*
         Check video authorization status. Video access is required and audio
         access is optional. If audio access is denied, audio is not recorded
         during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
    }
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            let dualCameraDeviceType: AVCaptureDevice.DeviceType
            if #available(iOS 11, *) {
                dualCameraDeviceType = .builtInDualCamera
            } else {
                dualCameraDeviceType = .builtInDuoCamera
            }
            
            if let dualCameraDevice = AVCaptureDevice.default(dualCameraDeviceType, for: AVMediaType.video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .back) {
                // If the back dual camera is not available, default to the back wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front) {
                /*
                 In some cases where users break their phones, the back wide angle camera is not available.
                 In this case, we should default to the front wide angle camera.
                 */
                defaultVideoDevice = frontCameraDevice
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
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
        
        // Add photo output.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    func checkForQRCode(newImage: UIImage) -> ([String], UIImage){
        var qrminimumSize:CGRect
        
        for i in 0 ..< 8{
            let g = newImage.cgImage!.cropping(to: CGRect(x: 0, y: CGFloat(i)*newImage.size.height/8, width: newImage.size.width, height: CGFloat(i+1)*newImage.size.height/8))!
            let h = self.isQRCodeAvailable(image: UIImage(cgImage: g))
            qrminimumSize = h.1
            if h.0 == true{
                return (scanQRCodeFromQRSize(selectedImage: newImage, a: qrminimumSize))
            }
        }
        
        for i in 0 ..< 4{
            let g = newImage.cgImage!.cropping(to: CGRect(x: 0, y: CGFloat(i)*newImage.size.height/4, width: newImage.size.width, height: CGFloat(i+1)*newImage.size.height/4))!
            let h = self.isQRCodeAvailable(image: UIImage(cgImage: g))
            qrminimumSize = h.1
            if h.0 == true{
                return (scanQRCodeFromQRSize(selectedImage: newImage, a: qrminimumSize))
            }
        }
        
        for i in 0 ..< 2{
            let g = newImage.cgImage!.cropping(to: CGRect(x: 0, y: CGFloat(i)*newImage.size.height/2, width: newImage.size.width, height: CGFloat(i+1)*newImage.size.height/2))!
            let h = self.isQRCodeAvailable(image: UIImage(cgImage: g))
            qrminimumSize = h.1
            if h.0 == true{
                return (scanQRCodeFromQRSize(selectedImage: newImage, a: qrminimumSize))
            }
        }
        
        let g = newImage.cgImage!.cropping(to: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))!
        let h = self.isQRCodeAvailable(image: UIImage(cgImage: g))
        qrminimumSize = h.1
        if h.0 == true{
            return (scanQRCodeFromQRSize(selectedImage: newImage, a: qrminimumSize))
        }
        return([], newImage)
    }
    
    func isQRCodeAvailable(image: UIImage) -> (Bool, CGRect){
        let features = detectQRCodeFromImage(image: image)!
        
        print("FEATURES::\(features.count)")
        if features.count==0 {
            return (false,CGRect(x: 0, y: 0, width: 0, height: 0))
        }
        
        return(true, features[0].bounds)
    }
    
    func scanQRCodeFromQRSize(selectedImage: UIImage, a:CGRect) -> ([String], UIImage){
        
        var arrayString:[String] = Array.init()
        var c: [Rectangle] = Array.init()
        
        let loopForRow = Int(selectedImage.size.width / (a.size.width))
        let loopForColumn = Int(selectedImage.size.height / (a.size.height))
        
        for i in 0 ..< loopForRow{
            for j in 0 ..< loopForColumn{
                if let croppedImage = selectedImage.cgImage?.cropping(to:CGRect(x: CGFloat(i) * a.size.width , y: CGFloat(j) * a.size.height , width: a.size.width*2, height: a.size.height*2)){
                    let newImage = UIImage(cgImage: croppedImage)
                    if let features = detectQRCodeFromImage(image: newImage), !features.isEmpty{
                        for case let row as CIQRCodeFeature in features{
                            let takenDataCount = arrayString.count
                            arrayString.append(row.messageString ?? "nil")
                            arrayString = Array(Set(arrayString))
                            if arrayString.count > takenDataCount{
                                
                                let threshold = selectedImage.size.height - CGFloat(j) * a.size.height - 2*a.size.height + row.bottomLeft.y
                                if threshold < 0{
                                }
                                
                                var x = row.bottomLeft.x + CGFloat(i) * a.size.width
                                
                                var y = selectedImage.size.height - CGFloat(j) * a.size.height - 2*a.size.height + row.bottomLeft.y
                                var xyLeftBot = CGPoint(x: x, y: y)
                                
                                x = row.bottomRight.x + CGFloat(i) * a.size.width
                                y = selectedImage.size.height - CGFloat(j) * a.size.height - 2*a.size.height + row.bottomRight.y
                                var xyRightBot = CGPoint(x: x, y: y)
                                
                                x = row.topLeft.x + CGFloat(i) * a.size.width
                                y = selectedImage.size.height - CGFloat(j) * a.size.height - 2*a.size.height + row.topLeft.y
                                var xyLeftUp = CGPoint(x: x, y: y)
                                
                                x = row.topRight.x + CGFloat(i) * a.size.width
                                y = selectedImage.size.height - CGFloat(j) * a.size.height - 2*a.size.height + row.topRight.y
                                var xyRightUp = CGPoint(x: x, y: y)
                                
                                if j == loopForColumn-1{
                                    xyLeftUp.y = row.topLeft.y; xyRightUp.y = row.topRight.y;
                                    xyLeftBot.y = row.bottomLeft.y; xyRightBot.y = row.bottomRight.y;
                                }
                                
                                let a:Rectangle = Rectangle.init(bottomLeft: xyLeftBot, bottomRight: xyRightBot, topLeft: xyLeftUp, topRight: xyRightUp)
                                c.append(a)
                            }
                        }
                    }
                }
            }
        }
        return (arrayString, drawMultipleBoxesInsideImageProto2(image: selectedImage, boxDimension: c))
    }
    
    func detectQRCodeFromImage(image: UIImage?) -> [CIQRCodeFeature]? {
        
        var f:[CIQRCodeFeature]?
        if let image = image, let ciImage = CIImage(image: image) {
            var options: [String: Any] = [:]
            options[CIDetectorAccuracy] = CIDetectorAccuracyHigh
            let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: options)
            
            f = qrDetector?.features(in: ciImage, options: options) as? [CIQRCodeFeature]
        }
        
        return f
    }
    
    
    
    func drawMultipleBoxesInsideImageProto2(image: UIImage, boxDimension:[Rectangle]) -> UIImage {
        
        var newImage = image
        let imageSize = image.size
        let scale: CGFloat = 1.0
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)
        let a = image.rotate(radians: deg2rad(180))
        let b = UIImage(cgImage: a.cgImage!, scale: 1.0, orientation: .upMirrored)
        b.draw(at: CGPoint.zero)
        for f in boxDimension {
            
            let rectanglePath = UIBezierPath()
            
            rectanglePath.move(to: f.bottomLeft)
            rectanglePath.addLine(to: f.topLeft)
            rectanglePath.addLine(to: f.topRight)
            rectanglePath.addLine(to: f.bottomRight)
            
            rectanglePath.close()
            
            UIColor(red: 0.0, green: 1.0, blue: 0, alpha: 1.0).setFill()
            
            rectanglePath.fill()
            print(f.bottomRight, f.bottomLeft)
        }
        
        newImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2.0,
                                 y: rotatedSize.height / 2.0)
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            draw(in: CGRect(x: -origin.x, y: -origin.y,
                            width: size.width, height: size.height))
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return rotatedImage ?? self
        }
        
        return self
    }
}


struct Rectangle{
    var bottomLeft: CGPoint
    var bottomRight: CGPoint
    var topLeft: CGPoint
    var topRight: CGPoint
}
