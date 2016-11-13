//
//  ViewController.swift
//  Matt
//
//  Created by Christian Raroque on 11/12/16.
//  Copyright © 2016 AloaLabs. All rights reserved.
//

import UIKit
import SwiftyJSON
import AVFoundation
import FastttCamera

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVSpeechSynthesizerDelegate, FastttCameraDelegate {
    let imagePicker = UIImagePickerController()
    let session = URLSession.shared
    
    @IBOutlet weak var picButton: UIButton!

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var resultsLabel: UILabel!
    
    
    
    var fastCamera = FastttCamera()
    
    var name = "Chris"
    
    let speechSynthesizer = AVSpeechSynthesizer()
    
    var googleAPIKey = "AIzaSyDqDonG_1oS4n0gMBdCKQ7uG5yQxLcrzbk"
    var googleURL: URL {
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    
    @IBAction func loadImageButtonTapped(_ sender: UIButton) {
      //  imagePicker.allowsEditing = false
      //  imagePicker.sourceType = .photoLibrary
        
      //  present(imagePicker, animated: true, completion: nil)
        spinner.startAnimating()
        self.cameraView.isHidden = true
        self.picButton.setTitle("Hold on", for: UIControlState.normal)
        self.fastCamera.takePicture()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        imagePicker.delegate = self

        
        speechSynthesizer.delegate = self
        fastCamera.delegate = self
        self.fastttAddChildViewController(self.fastCamera)
        self.fastCamera.view.frame = self.cameraView.frame;
        spinner.hidesWhenStopped = true
        self.cameraView.isHidden = false
    }
    
    func cameraController(_ cameraController: FastttCameraInterface!, didFinishCapturing capturedImage: FastttCapturedImage!) {
        let binaryImageData = base64EncodeImage(capturedImage.fullImage)
        createRequest(with: binaryImageData)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


/// Image processing

extension ViewController {
    
    func analyzeResults(_ dataToParse: Data) {
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        }
        catch {
            // report for an error
        }
        
        // Update UI on the main thread
        DispatchQueue.main.async(execute: {
            
            var analyzedObjects = [""]
            // Use SwiftyJSON to parse results
            let json = JSON(data: dataToParse)
            let errorObj: JSON = json["error"]
        
            self.spinner.stopAnimating()
            self.picButton.setTitle("Is someone there?", for: UIControlState.normal)
            // Check for errors
            if (errorObj.dictionaryValue != [:]) {
                NSLog("Error code \(errorObj["code"]): \(errorObj["message"])")
            } else {
                // Parse the response
                print(json)
                let responses: JSON = json["responses"][0]
                
                let labelAnnotations2: JSON = responses["labelAnnotations"]
                if labelAnnotations2 != nil {
                    let numAnnotations:Int = labelAnnotations2.count
                    for index in 0..<numAnnotations {
                        let personData:JSON = labelAnnotations2[index]
                        NSLog("person data is \(personData["description"])")
                        analyzedObjects.append("\(personData["description"])")
                    }
                }
                
                var personObjects = ["person", "people", "human", "human objects", "humans", "people objects", "persons", "man", "woman", "child", "human positions"]
                
                var itHappened = false
                
                for person in personObjects {
                    if analyzedObjects.contains(person) {
                        itHappened = true
                    }
                }
                
                NSLog("it happened \(itHappened)")
                
                // Get face annotations
                let faceAnnotations: JSON = responses["faceAnnotations"]
                if faceAnnotations != nil {
                    let emotions: Array<String> = ["joy", "sorrow", "surprise", "anger"]
                    
                    let numPeopleDetected:Int = faceAnnotations.count
                    NSLog("num people detected is \(numPeopleDetected)")
                    NSLog("People detected: \(numPeopleDetected)\n\nEmotions detected:\n")
                    
                    var utterance = AVSpeechUtterance(string: "I only see one person in front of you")
                    utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
                    utterance.rate = 0.5
                    
                    
                    if numPeopleDetected == 1 {
                        utterance = AVSpeechUtterance(string: "I only see one person in front of you")
                    } else if numPeopleDetected > 1 {
                        utterance = AVSpeechUtterance(string: "I see \(numPeopleDetected) people in front of you \(self.name)")
                    } else {
                        utterance = AVSpeechUtterance(string: "I don't see anyone in front of you")
                    }
                    
                    self.speechSynthesizer.speak(utterance)
                    
                    var emotionTotals: [String: Double] = ["sorrow": 0, "joy": 0, "surprise": 0, "anger": 0]
                    var emotionLikelihoods: [String: Double] = ["VERY_LIKELY": 0.9, "LIKELY": 0.75, "POSSIBLE": 0.5, "UNLIKELY":0.25, "VERY_UNLIKELY": 0.0]
                    
                    for index in 0..<numPeopleDetected {
                        let personData:JSON = faceAnnotations[index]
                        
                        // Sum all the detected emotions
                        for emotion in emotions {
                            let lookup = emotion + "Likelihood"
                            let result:String = personData[lookup].stringValue
                            emotionTotals[emotion]! += emotionLikelihoods[result]!
                        }
                    }
                    // Get emotion likelihood as a % and display in UI
                    for (emotion, total) in emotionTotals {
                        let likelihood:Double = total / Double(numPeopleDetected)
                        let percent: Int = Int(round(likelihood * 100))
                    //    self.faceResults.text! += "\(emotion): \(percent)%\n"
                    }
                } else {
           //         self.faceResults.text = "No faces found"
                    NSLog("No faces found")
                    var utterance = AVSpeechUtterance(string: "I don't see anyone in front of you")
                    utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
                    utterance.rate = 0.5
                    self.speechSynthesizer.speak(utterance)
                }
                
                
                // Get label annotations
                let labelAnnotations: JSON = responses["labelAnnotations"]
                let numLabels: Int = labelAnnotations.count
                var labels: Array<String> = []
                if numLabels > 0 {
                    var labelResultsText:String = "Labels found: "
                    for index in 0..<numLabels {
                        let label = labelAnnotations[index]["description"].stringValue
                        labels.append(label)
                    }
                    for label in labels {
                        // if it's not the last item add a comma
                        if labels[labels.count - 1] != label {
                            labelResultsText += "\(label), "
                        } else {
                            labelResultsText += "\(label)"
                        }
                    }
           //         self.labelResults.text = labelResultsText
                } else {
         //           self.labelResults.text = "No labels found"
                }
            }
        })
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
       //     imageView.contentMode = .scaleAspectFit
       //     imageView.isHidden = true // You could optionally display the image here by setting imageView.image = pickedImage
      
            
            // Base64 encode the image and create the request
            let binaryImageData = base64EncodeImage(pickedImage)
            createRequest(with: binaryImageData)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = UIImagePNGRepresentation(newImage!)
        UIGraphicsEndImageContext()
        return resizedImage!
    }
}


/// Networking

extension ViewController {
    func base64EncodeImage(_ image: UIImage) -> String {
        var imagedata = UIImagePNGRepresentation(image)
        
        // Resize the image if it exceeds the 2MB API limit
        if (imagedata?.count > 2097152) {
            let oldSize: CGSize = image.size
            let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
            imagedata = resizeImage(newSize, image: image)
        }
        
        return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
    }
    
    func createRequest(with imageBase64: String) {
        // Create our request URL
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        // Build our API request
        let jsonRequest = [
            "requests": [
                "image": [
                    "content": imageBase64
                ],
                "features": [
                    [
                        "type": "LABEL_DETECTION",
                        "maxResults": 10
                    ],
                    [
                        "type": "FACE_DETECTION",
                        "maxResults": 10
                    ]
                ]
            ]
        ]
        let jsonObject = JSON(jsonDictionary: jsonRequest)
        
        // Serialize the JSON
        guard let data = try? jsonObject.rawData() else {
            return
        }
        
        request.httpBody = data
        
        // Run the request on a background thread
        DispatchQueue.global().async { self.runRequestOnBackgroundThread(request) }
    }
    
    func runRequestOnBackgroundThread(_ request: URLRequest) {
        // run the request
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }
            
            self.analyzeResults(data)
        }
        
        task.resume()
    }
}


// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}
