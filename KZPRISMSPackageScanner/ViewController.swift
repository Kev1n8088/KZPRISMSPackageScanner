//
//  ViewController.swift
//  KZPRISMSPackageScanner
//
//  Created by Kevin Zheng on 4/21/23.
//

//Some future features that may be implemented: Manual entering of name and autofill email, selection between two different names in the same image
//Some more future feature suggestions: cue to show what text is detected, clientside method of updating firstnames
//Some future features that will probably be implemented: Error correction for text detection during email finding phase

import UIKit
import Vision
import MessageUI
import AVFoundation
import FirebaseDatabase
import AudioToolbox

class ViewController: UIViewController {
    //accessing database
    private let database = Database.database().reference()
    private var session: AVCaptureSession?
    private let output = AVCapturePhotoOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private var mode = 0
    private var sendQueue : [Int] = []
    private var sendQueueNames = ""
    
    private let cameraButton: UIButton = {
        let cameraButton = UIButton(frame: CGRect(x: 0, y:0, width: 40, height: 40))
        cameraButton.setImage(UIImage(systemName: "camera.viewfinder"), for: .normal)
        cameraButton.imageView?.contentMode = .scaleAspectFit;
        return cameraButton
    }()
    
    private let sendButton: UIButton = {
        let sendButton = UIButton(frame: CGRect(x: 0, y:0, width: 40, height: 40))
        sendButton.setImage(UIImage(systemName: "paperplane"), for: .normal)
        sendButton.imageView?.contentMode = .scaleAspectFit;
        return sendButton
    }()
    
    private let removeButton: UIButton = {
        let sendButton = UIButton(frame: CGRect(x: 0, y:0, width: 80, height: 80))
        sendButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        sendButton.imageView?.contentMode = .scaleAspectFit;
        return sendButton
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
    
    //Back removeAllButton
    private let removeAllButton: UIButton = {
        let removeAllButton = UIButton(frame: CGRect(x: 0, y:0, width: 40, height: 40))
        //removeAllButton.setTitle("<", for: .normal)
        removeAllButton.setImage(UIImage(systemName: "trash"), for: .normal)
        return removeAllButton
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
    private var timer = Timer()
    
    override func viewDidLoad() {
        //when view loads
        super.viewDidLoad()
        view.addSubview(label)
        view.addSubview(imageView)
        view.layer.addSublayer(previewLayer)
        view.addSubview(cameraButton)
        view.addSubview(removeAllButton)
        view.addSubview(removeButton)
        view.addSubview(sendButton)
        
        imageView.isHidden = true
        checkCameraPermissions()
        
        getDatabaseCount{result in
            //wait for database to load and get number of entries which are then used to get all data from database
            self.getDatabaseData(num: result)
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
            if self.mode == 0{
                self.takePhoto()
            }
        })
    }
    
    //configuring various UI features
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = CGRect(
            x: 0,
            y: 80 + view.safeAreaInsets.top,
            width: view.frame.size.width,
            height: view.frame.size.width + 120)
        imageView.frame = CGRect(
            x: 0,
            y: 80 + view.safeAreaInsets.top,
            width: view.frame.size.width,
            height: view.frame.size.width + 120)
        label.frame = CGRect(
            x: 20,
            y:  view.safeAreaInsets.top,
            width: view.frame.size.width - 40,
            height: 50)
        cameraButton.center = CGPoint(x: 20, y: view.frame.size.height - 80)
        cameraButton.addTarget(self, action: #selector(restartCamera), for: .touchUpInside)
        
        sendButton.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 80)
        sendButton.addTarget(self, action: #selector(sendEmail), for: .touchUpInside)
        
        removeButton.center = CGPoint(x: view.frame.size.width - 80, y: view.frame.size.height - 80)
        removeButton.addTarget(self, action: #selector(removeLastQueue), for: .touchUpInside)
        
        removeAllButton.center = CGPoint(x: view.frame.size.width - 20, y: view.frame.size.height - 80)
        removeAllButton.addTarget(self, action: #selector(removeQueue), for: .touchUpInside)
    }
    
    //Checks for camera permissions, boilerplate code
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
    
    //Sets up camera permissions and displays it on our preview layer, boilerplate code
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
                
                DispatchQueue.global(qos: .background).async {
                    session.startRunning()
                }
                self.session = session
                
            }
            catch{
                print(error)
            }
        }
    }
    
    
    //Command to take photo
    @objc private func takePhoto(){
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
    
    //Restarts camera after taking photo, deprecated
    @objc private func restartCamera(){
        if mode == 1{
            
            DispatchQueue.global(qos: .background).async {
                self.session?.startRunning()
            }
            mode = 0
        }
        else{
            mode = 1
            
            DispatchQueue.global(qos: .background).async {
                self.session?.stopRunning()
            }
        }
        //Changing some UI elements
        
    }
    
    //resets queue
    @objc private func removeQueue(){
        sendQueue = []
        sendQueueNames = ""
        self.label.text = sendQueueNames
    }
    
    @objc private func removeLastQueue(){
        if(sendQueue.count == 0){
            return
        }
        sendQueue.removeLast()
        sendQueueNames = ""
        for i in 0..<sendQueue.count{
            sendQueueNames += self.students.firstname1[sendQueue[i]] + " "
        }
        self.label.text = sendQueueNames
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
        
        for i in 0..<num{
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
    private func getEmail(arr: [String]) -> [Int]{
        //only functions if all data is in local struct
        
        if(students.complete){
            //TODO: error correction in finding algorithim, eg i to j, etc
        
            
            //first checks if last name is in detected words
            var ln: [Int]  = []
            for i in 0..<students.num{
                if (arr.contains(students.lastname[i])){
                    ln.append(i)
                }
            }
            
            //then checks if corresponding first name(s) is detected words
            var fn: [Int] = []
            if(ln) != []{
                for i in 0..<ln.count{
                    if(arr.contains(students.firstname1[ln[i]])){
                        fn.append(ln[i])
                    }else if(arr.contains(students.firstname2[ln[i]]) && students.firstname2[ln[i]] != "NOOTHERNAME"){
                        fn.append(ln[i])
                    }else if(arr.contains(students.firstname3[ln[i]]) && students.firstname3[ln[i]] != "NOOTHERNAME"){
                        fn.append(ln[i])
                    }
                }
                
                //currently just returns first found full name, perhaps future implementation could choose?
                //TODO: choose full name?
                if(fn != []){
                    return fn
                }
            }
            //returns -1 if no full name
            return []
        }else{
            return []
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
            //self?.label.text = String(processedArr.joined(separator: " "))
            
            
            DispatchQueue.main.async{
                //display result
                let index = finaltext!
                
                //error handling if no text is found
                if index == []{
                    return
                }
                
                
                //checks if name is already in queue, if not, adds to queue and vibrates
                
                for i in 0..<index.count{
                    if(!(self?.sendQueue.contains(index[i]))!){
                        self?.sendQueue.append(index[i])
                        self?.sendQueueNames += (self?.students.firstname1[index[i]])! + " "
                        self?.label.text = self?.sendQueueNames
                        AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
                        break
                    }
                }
            }
        }
        
        //Actually calling the function
        do{
            try handler.perform([request])
        }
        catch{
            //error handling
            label.text = "\(error)"
        }
    }
    
    //sends emails to all in queue
    @objc private func sendEmail(){
        showMailComposer(index: sendQueue)
    }
    
    //all below is for email composition
    @objc func showMailComposer(index: [Int]) {
        guard MFMailComposeViewController.canSendMail() else {
            return
        }
        
        if index.isEmpty{
            return
        }
        
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        
        var k : [String] = []
        for i in index{
            k.append(students.email[i])
        }
        
        composer.setToRecipients(k)
        composer.setSubject("You've got a package")
        composer.setMessageBody("Hello, You have a new package ready at the package area. Please pick it up", isHTML: false)
        present(composer, animated: true)
    }
}

//Mail composition handler, just boilerplate code
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

//Takes photo, displays it, stops camera feed, and feeds photo to text detection algorithm
extension ViewController: AVCapturePhotoCaptureDelegate{
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        AudioServicesDisposeSystemSoundID(1108)
        if mode != 0{
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            return
        }
        
        //Changing UI a bit
        
        let image = UIImage(data: data)
        //Feeding to text recognition
        self.recognizeText(image: image)
        
        //Stopping camera
        
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        AudioServicesDisposeSystemSoundID(1108)
    }
}
