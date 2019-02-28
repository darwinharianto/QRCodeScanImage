//
//  ViewController.swift
//  QR Code scanner
//
//  Created by Darwin Harianto on 2019/02/28.
//  Copyright © 2019 Darwin Harianto. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var qrView: UIView!
    
    
    private var qrCodeScanFromImage = QRCodeScanFromImage()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.qrCodeScanFromImage.setupTakingImageForQRScan()
        qrCodeScanFromImage.delegate = self
        self.qrCodeScanFromImage.checkCameraAvailabilityForTakingImage()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.qrCodeScanFromImage.stopCameraFromTakingImage()
    }

    @IBAction func takePicture(_ sender: Any) {
        qrCodeScanFromImage.capturePhoto()
    }
    

}

extension ViewController: QRCodeScanImageDelegateProtocol{
    func CameraAccessGranted() {
        self.qrCodeScanFromImage.video = AVCaptureVideoPreviewLayer(session: self.qrCodeScanFromImage.session)
        self.qrCodeScanFromImage.video.frame = self.qrView.bounds
        self.qrView.layer.addSublayer(self.qrCodeScanFromImage.video)
        self.qrCodeScanFromImage.session.startRunning()
    }
    
    func didGetProcessedImage(image: UIImage, data: [String]) {
        imageView.image = image
    }
    
    
}

