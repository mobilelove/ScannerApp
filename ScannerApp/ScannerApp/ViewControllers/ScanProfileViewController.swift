//
//  ScanProfileViewController.swift
//  ScannerApp
//
//  Created by Lavanya on 6/29/18.
//

import UIKit
import Vision
import CoreML

class ScanProfileViewController: UIViewController {

    //HOLDS OUR INPUT
    var  inputImage:CIImage?
    var  selectedImage:UIImage?

    @IBOutlet var profileTableView:UITableView?
    
    //RESULT FROM OVERALL RECOGNITION
    var  recognizedWords:[String] = [String]()
    
    //RESULT FROM RECOGNITION
    var recognizedRegion:String = String()
    
    
    //OCR-REQUEST
    lazy var ocrRequest: VNCoreMLRequest = {
        do {
            //THIS MODEL IS TRAINED BY ME FOR FONT "Inconsolata" (Numbers 0...9 and UpperCase Characters A..Z)
            let model = try VNCoreMLModel(for:OCR().model)
            return VNCoreMLRequest(model: model, completionHandler: self.handleClassification)
        } catch {
            fatalError("cannot load model")
        }
    }()
    
    //OCR-HANDLER
    func handleClassification(request: VNRequest, error: Error?)
    {
        guard let observations = request.results as? [VNClassificationObservation]
            else {fatalError("unexpected result") }
        guard let best = observations.first
            else { fatalError("cant get best result")}
        
        self.recognizedRegion = self.recognizedRegion.appending(best.identifier)
    }
    
    //TEXT-DETECTION-REQUEST
    lazy var textDetectionRequest: VNDetectTextRectanglesRequest = {
        return VNDetectTextRectanglesRequest(completionHandler: self.handleDetection)
    }()
    
    //TEXT-DETECTION-HANDLER
    func handleDetection(request:VNRequest, error: Error?)
    {
        guard let observations = request.results as? [VNTextObservation]
            else {fatalError("unexpected result") }
        
        // EMPTY THE RESULTS
        self.recognizedWords = [String]()
        
        //NEEDED BECAUSE OF DIFFERENT SCALES
        let  transform = CGAffineTransform.identity.scaledBy(x: (self.inputImage?.extent.size.width)!, y:  (self.inputImage?.extent.size.height)!)
        
        //A REGION IS LIKE A "WORD"
        for region:VNTextObservation in observations
        {
            guard let boxesIn = region.characterBoxes else {
                continue
            }
            
            //EMPTY THE RESULT FOR REGION
            self.recognizedRegion = ""
            
            //A "BOX" IS THE POSITION IN THE ORIGINAL IMAGE (SCALED FROM 0... 1.0)
            for box in boxesIn
            {
                //SCALE THE BOUNDING BOX TO PIXELS
                let realBoundingBox = box.boundingBox.applying(transform)
                
                //TO BE SURE
                guard (inputImage?.extent.contains(realBoundingBox))!
                    else { print("invalid detected rectangle"); return}
                
                //SCALE THE POINTS TO PIXELS
                let topleft = box.topLeft.applying(transform)
                let topright = box.topRight.applying(transform)
                let bottomleft = box.bottomLeft.applying(transform)
                let bottomright = box.bottomRight.applying(transform)
                
                //LET'S CROP AND RECTIFY
                let charImage = inputImage?
                    .cropped(to: realBoundingBox)
                    .applyingFilter("CIPerspectiveCorrection", parameters: [
                        "inputTopLeft" : CIVector(cgPoint: topleft),
                        "inputTopRight" : CIVector(cgPoint: topright),
                        "inputBottomLeft" : CIVector(cgPoint: bottomleft),
                        "inputBottomRight" : CIVector(cgPoint: bottomright)
                        ])
                
                //PREPARE THE HANDLER
                let handler = VNImageRequestHandler(ciImage: charImage!, options: [:])
                
                //SOME OPTIONS (TO PLAY WITH..)
                self.ocrRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.scaleFill
                
                //FEED THE CHAR-IMAGE TO OUR OCR-REQUEST - NO NEED TO SCALE IT - VISION WILL DO IT FOR US !!
                do {
                    try handler.perform([self.ocrRequest])
                }  catch { print("Error")}
                
            }
            
            //APPEND RECOGNIZED CHARS FOR THAT REGION
            self.recognizedWords.append(recognizedRegion)
        }
        
        //THATS WHAT WE WANT - PRINT WORDS TO CONSOLE
        DispatchQueue.main.async {
            self.PrintWords(words: self.recognizedWords)
            self.profileTableView?.reloadData()
        }
    }
    
    func PrintWords(words:[String])
    {
        // VOILA'
        print(recognizedWords)
        
    }
    
    func doOCR(ciImage:CIImage)
    {
        //PREPARE THE HANDLER
        let handler = VNImageRequestHandler(ciImage: ciImage, options:[:])
        
        //WE NEED A BOX FOR EACH DETECTED CHARACTER
        self.textDetectionRequest.reportCharacterBoxes = true
        self.textDetectionRequest.preferBackgroundProcessing = false
        
        //FEED IT TO THE QUEUE FOR TEXT-DETECTION
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try  handler.perform([self.textDetectionRequest])
            } catch {
                print ("Error")
            }
        }
        
    }
    
    @IBAction func validateInformation(_ sender: Any) {
        
        let alert = UIAlertController(title: "Alert", message: "Validation matched!", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.navigationController?.popToRootViewController(animated: true)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(alert, animated: true)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Profile Information";
        
        self.navigationController?.navigationBar.topItem?.title = ""
        self.navigationController?.isNavigationBarHidden = false
        
        /**
         Remove this uncomment and comment below line to have image read from locally**/
        let loadedImage:UIImage = UIImage(named: "license.png")!
        inputImage = CIImage(image:loadedImage)!
 
        
       /**
          Remove this uncomment line to load from camera image
        inputImage = CIImage(image:selectedImage!)!
 
        **/
        
        //LET'S DO IT
        self.doOCR(ciImage: inputImage!)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ScanProfileViewController: UITabBarDelegate, UITableViewDataSource {
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recognizedWords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ScanCardInfoCell.self), for: indexPath) as? ScanCardInfoCell else {
            preconditionFailure("Unregistered table view cell")
        }
        
        cell.scanNameLbl?.text = recognizedWords[indexPath.row]
        
        return cell
        
    }
    
    

}
