//
//  ViewController.swift
//  KZPRISMSPackageScanner
//
//  Created by Kevin Zheng on 4/21/23.
//

import UIKit
import Vision
import MessageUI
import AVFoundation
import FirebaseDatabase

class ViewController: UIViewController {
    
    //accessing database
    private let database = Database.database().reference()
    private var session: AVCaptureSession?
    private let output = AVCapturePhotoOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private var mode = 0
    
    private let shutterButton: UIButton = {
        let shutterButton = UIButton(frame: CGRect(x: 0, y:0, width: 80, height: 80))
        shutterButton.layer.cornerRadius = 40
        shutterButton.layer.borderWidth = 10
        shutterButton.layer.borderColor = UIColor.white.cgColor
        return shutterButton
    }()
    
    //test label
    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Waiting..."
        return label
    }()
    
    //test image
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "example1")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    //Back button
    private let button: UIButton = {
        let button = UIButton()
        button.setTitle("<", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        return button
    }()
    
    //stores all student info pulled from google firebase real time database
    struct studentInfo{
        var num = 0
        var firstname1: [String] = [] //primary first name
        var firstname2: [String] = [] //nickname 1, NOOTHERNAME if no other name
        var firstname3: [String] = [] //nickname 2, NOOTHERNAME if no other name
        var lastname: [String]  = []
        var email : [String] = []
        var complete = false //only flips to true once all data is added to local
    }
    private var students = studentInfo() //instance of studentinfo
    
    override func viewDidLoad() {
        //when view loads
        super.viewDidLoad()
        view.addSubview(label)
        view.addSubview(imageView)
        view.layer.addSublayer(previewLayer)
        view.addSubview(shutterButton)
        view.addSubview(button)
        
        imageView.isHidden = true
        button.isHidden = true
        
        checkCameraPermissions()
        
        getDatabaseCount{result in
            //wait for database to load and get number of entries which are then used to get all data from database
            self.getDatabaseData(num: result)
        }
        
        /*DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Change `2.0` to the desired number of seconds.
            
            self.recognizeText(image: self.imageView.image)
        }*/
    }
    
    //configuring various UI features
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = CGRect(
            x: 20,
            y: view.safeAreaInsets.top,
            width: view.frame.size.width - 40,
            height: view.frame.size.width + 80)
        imageView.frame = CGRect(
            x: 20,
            y: view.safeAreaInsets.top,
            width: view.frame.size.width - 40,
            height: view.frame.size.width + 80)
        label.frame = CGRect(
            x: 20,
            y:  view.frame.size.width + 60 + view.safeAreaInsets.top,
            width: view.frame.size.width - 40,
            height: 200)
        button.frame = CGRect(
            x: 20,
            y: view.frame.size.height - 100,
            width: 40,
            height: 40)
        shutterButton.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 80)
        shutterButton.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
        button.addTarget(self, action: #selector(restartCamera), for: .touchUpInside)
        button.titleLabel?.font =  .systemFont(ofSize: 36.0, weight: .bold)
    }
    
    
    private func checkCameraPermissions(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else{
                    return
                }
                DispatchQueue.main.async{
                    self?.setupCamera()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setupCamera()
        @unknown default:
            break
        }
    }
    
    
    private func setupCamera(){
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video){
            do{
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input){
                    session.addInput(input)
                }
                
                if session.canAddOutput(output){
                    session.addOutput(output)
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                
                //TODO: Run on background thread
                session.startRunning()
                self.session = session
                
            }
            catch{
                print(error)
            }
        }
    }
    
    @objc private func takePhoto(){
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
    
    @objc private func restartCamera(){
        if mode != 1{
            return
        }
        mode = 0
        imageView.isHidden = true
        button.isHidden = true
        previewLayer.isHidden = false
        shutterButton.isHidden = false
        //TODO: Run on background thread
        session?.startRunning()
        
    }
    
    //gets number of entries in the database
    private func getDatabaseCount(completionHandler: @escaping(_ result: Int) -> ()){
        database.observeSingleEvent(of: .value, with: {snapshot in
            let val = snapshot.children.allObjects.count
            completionHandler(val)
        })
    }
    
    //moves data from online database to local struct, also flags when complete
    private func getDatabaseData(num: Int){
        for i in 0...num{
            //iterating through each entry
            database.child(String(i)).observeSingleEvent(of: .value, with: {snapshot in
                guard let val = snapshot.value as? String else{
                    return
                }
                let splitInfo = val.split(separator:" ") //array of info split by spaces, 0: email, 1: last name, 2: first name, 3?: nickname 1, 4?: nickname 2
                
                //switch based on how many nicknames the entry has
                switch splitInfo.count{
                case 3:
                    self.students.firstname2.append("NOOTHERNAME")
                    self.students.firstname3.append("NOOTHERNAME")
                case 4:
                    self.students.firstname2.append(String(splitInfo[3]))
                    self.students.firstname3.append("NOOTHERNAME")
                case 5:
                    self.students.firstname2.append(String(splitInfo[3]))
                    self.students.firstname2.append(String(splitInfo[4]))
                default:
                    return
                }
                
                //adding email, firstname, lastname data
                self.students.email.append(String(splitInfo[0]))
                self.students.lastname.append(String(splitInfo[1]))
                self.students.firstname1.append(String(splitInfo[2]))
                self.students.num += 1
                
                //marking completion
                if(self.students.num == num){
                    self.students.complete = true
                }
            })
        }
    }
    
    //processing detected text to find if there is a combination of lastname + firstname/nickname, which is then associated with an email
    private func getEmail(arr: [String]) -> Int{
        //only functions if all data is in local struct
        if(students.complete){
            //TODO: finding algorithm
            
            return 0
        }else{
            return -1
        }
    }
    
    //text recognition algoprithim
    private func recognizeText(image: UIImage?) {
        guard let cgImage = image?.cgImage else {
            print("No image found")
            return}
        
        
        //Handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        //Requests text detection
        let request = VNRecognizeTextRequest{ [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else{
                return
            }
            
            //array of detected text
            let arr = observations.compactMap({
                $0.topCandidates(1).first?.string
            })
            
            //basic processing: joining, removing odd characters
            var text = arr.joined(separator: " ")
            text = text.replacingOccurrences(of: "[,.;@#?!&$]+\\ *{}/", with: " ", options: .regularExpression, range: nil)
            
            //change all to lowercase
            text = text.lowercased()
            
            //split again
            let processedArr = text.split(separator: " ").filter({!$0.isEmpty}).map{String($0)}
            
            //call getEmail to get email
            let finaltext = self?.getEmail(arr: processedArr)
            
            DispatchQueue.main.async{
                //display result
                self?.label.text = String(finaltext!)
            }
        }
        
        //Actually calling the function
        do{
            try handler.perform([request])
        }
        catch{
            label.text = "\(error)"
        }
        
        
    }
    
    
    //all below is for email composition
    @objc func showMailComposer(index: Int) {
        guard MFMailComposeViewController.canSendMail() else {
            return
        }
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients([students.email[index]])
        composer.setSubject("You've got a package")
        composer.setMessageBody("Hello " + students.firstname1[index] + " " + students.lastname[index] + ",\n\n" + "You have a new package ready at the package area. Please pick it up", isHTML: false)
        present(composer, animated: true)
    }
}

extension ViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        if let _ = error {
            controller.dismiss(animated: true, completion: nil)
            return
        }
        switch result {
        case .cancelled:
            break
        case .failed:
            break
        case .saved:
            break
        case .sent:
            break
        default:
            break
        }
        controller.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate{
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if mode != 0{
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            return
        }
        
        let image = UIImage(data: data)
        imageView.image = image
        mode = 1
        imageView.isHidden = false
        button.isHidden = false
        previewLayer.isHidden = true
        shutterButton.isHidden = true
        
        self.recognizeText(image: image)
        
        session?.stopRunning()
        
    }
}
