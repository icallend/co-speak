//
//  ViewController.swift
//  co-speak-app
//
//  Created by Ian Callender on 5/15/17.
//  Copyright © 2017 dancingpenguindesigns. All rights reserved.
//

import UIKit
import Speech


class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    let DEBUGGING = false;
    let SAYLABEL = true;
    
    var socket_isOpen = false;
    
    
    //MARK: Properties
    @IBOutlet weak var ddg_variable: UILabel!
    @IBOutlet weak var displaymessage_variable: UILabel!
    @IBOutlet weak var textinfo_variable: UILabel!
    
    @IBOutlet weak var ddg_static: UILabel!
    @IBOutlet weak var displaymessage_static: UILabel!
    @IBOutlet weak var textinfo_static: UILabel!
    @IBOutlet weak var say_static: UILabel!
    
    //MARK: Actions
    @IBOutlet weak var join_btn: UIButton!
    @IBOutlet weak var leave_btn: UIButton!
    @IBOutlet weak var advance_btn: UIButton!
    
    var entered = 0;
    var advancable = 0;
    
    let textinfo_blank = " ";//"-";
    
    var gooseTimer: Timer?
    
    
    //MARK: Speech shit
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    //@IBOutlet var textView : UITextView!
    //@IBOutlet var recordButton : UIButton!
    
    var haveItemsBeenSpoken = false;
    var passphrase = "cookies"
    
    
    let lightGreen = UIColor(red:0.54, green:1.00, blue:0.54, alpha:1.0);
    let lightYellow = UIColor(red:0.98, green:0.92, blue:0.49, alpha:1.0);
    let lightRed = UIColor(red:1.00, green:0.54, blue:0.54, alpha:1.0);
    
    
    let socket = SocketIOClient(socketURL: URL(string: "https://co-speak.herokuapp.com/")!, config: [.log(true), .forcePolling(true)])

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.closeSocket),
            name: NSNotification.Name.UIApplicationWillResignActive,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.closeSocket),
            name: NSNotification.Name.UIApplicationWillTerminate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.closeSocket),
            name: NSNotification.Name.UIApplicationDidEnterBackground,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.openSocket),
            name: NSNotification.Name.UIApplicationWillEnterForeground,
            object: nil
        )
        /*
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.reopenApplication),
            name: NSNotification.Name.UIApplicationDidBecomeActive,
            object: nil
        )
         */
        
        // Disable the record buttons until authorization has been granted.
        //recordButton.isEnabled = false
        
        join_btn.addTarget(self, action: #selector(join(button:)), for: .touchUpInside)
        leave_btn.addTarget(self, action: #selector(leave(button:)), for: .touchUpInside)
        advance_btn.addTarget(self, action: #selector(advance(button:)), for: .touchUpInside)
        
        self.openSocket();
        
        socket.on(clientEvent: .connect) {data, ack in
            print("-------socket connected-------")
        }
        
        socket.on("duckduckgoose") {data, ack in
            print("-------ddg-------")
            let ddg_in = self.stripData(inData:String(describing:data));
            self.ddg_variable.text = ddg_in;
            
            if(ddg_in == "goose") {
                self.advancable = 1;
                
                //self.advance_btn.isEnabled = true;
                //self.advance_btn.isHidden = false;
                self.gooseTimer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(self.gooseTimeoutHandler), userInfo: nil, repeats: false);

                self.toggleRecording();
                self.flashColor(color:self.lightYellow);
                
                if(self.SAYLABEL){self.say_static.isHidden = false;};

            } else { // if ddg = duck, inactive, or standby
                self.advancable = 0;
                self.advance_btn.isEnabled = false;
                self.advance_btn.isHidden = true;
                if(self.SAYLABEL){self.say_static.isHidden = true;};
                
            }
            
        }
        
        socket.on("displaymessage") {data, ack in
            print("-------displaymessage-------")
            let displaymessage_in = self.stripData(inData:String(describing:data));
            self.displaymessage_variable.text = displaymessage_in;
            if(self.advancable == 1){
                self.passphrase = displaymessage_in.lowercased();
            }
        }
        
        socket.on("textinfo") {data, ack in
            print("-------textinfo-------")
            print(data);
            //print("--------------")
            //print(String(describing:data))
            
            let textinfo_in = self.stripData(inData:String(describing:data));
            let textinfo_in_json = self.convertToDictionary(text: textinfo_in);
            
            /*
            print("--------------")
            print(textinfo_in)
            print("--------------")
            print(textinfo_in_json)
            print("--------------")
            */
            
            let textinfo_author = String(describing:textinfo_in_json!["author"]!)
            let textinfo_date = String(describing:textinfo_in_json!["date"]!)
            let textinfo_name = String(describing:textinfo_in_json!["name"]!)
            
            var textinfo_new_text = self.textinfo_blank;
            if( (textinfo_author != "-") && (textinfo_date != "-") && (textinfo_name != "-") ){
                textinfo_new_text = String(describing:textinfo_name) + " by " + String(describing:textinfo_author) + " on " + String(describing:textinfo_date);
            }
            
            self.textinfo_variable.text = textinfo_new_text;
        }
        
    } // end viewdidload
    
    
    override public func viewDidAppear(_ animated: Bool) {
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    //self.recordButton.isEnabled = true
                    print("-----authorized")
                    
                case .denied:
                    //self.recordButton.isEnabled = false
                    //self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    print("-----denied access")
                    
                case .restricted:
                    //self.recordButton.isEnabled = false
                    //self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    print("-----restricted")
                    
                case .notDetermined:
                    //self.recordButton.isEnabled = false
                    //self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                    print("-----not yet authorized")
                }
            }
        }
        
        //toggleRecording()
    } // end viewDidAppear
    
    
    //*
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    //*/
    
    
    func join(button: UIButton) {
        print("~~~~~~~JOINING~~~~~~~")
        if (self.entered == 0) {
            
            self.socket.emitWithAck("join", "join-2").timingOut(after: 0) {data in
                let strippedData = self.stripData(inData:String(describing:data));
                
                if(Int(strippedData)==1){
                    print("~~~~~~~JOIN SUCCESSFUL~~~~~~~")
                    self.entered = 1;
                    
                    self.join_btn.isEnabled = false;
                    self.join_btn.isHidden = true;
                    
                    self.leave_btn.isEnabled = true;
                    self.leave_btn.isHidden = false;
                }else{
                    print("~~~~~~~ERROR:join~~~~~~~")
                }
                
            }
            
        } else {
            print("~~~~~~~not joinable: already entered~~~~~~~")

        }
    }
    
    
    func leave(button: UIButton) {
        print("~~~~~~~LEAVING~~~~~~~")
        if (self.entered == 1) {
            
            self.socket.emitWithAck("leave", "leave-2").timingOut(after: 0) {data in
                let strippedData = self.stripData(inData:String(describing:data));
                
                if(Int(strippedData)==1){
                    print("~~~~~~~LEAVE SUCCESSFUL~~~~~~~")
                    self.entered = 0;
                    
                    self.join_btn.isEnabled = true;
                    self.join_btn.isHidden = false;
                    
                    self.leave_btn.isEnabled = false;
                    self.leave_btn.isHidden = true;
                    
                    self.advance_btn.isEnabled = false;
                    self.advance_btn.isHidden = true;
                    
                    self.textinfo_variable.text = self.textinfo_blank;
                    if(self.SAYLABEL){self.say_static.isHidden = true;};

                }else{
                    print("~~~~~~~ERROR:leave~~~~~~~")
                }
                
            }
            
        } else {
            print("~~~~~~~not leavable: not entered~~~~~~~")
        }
    }
    
    
    func advance(button: UIButton) {
        print("~~~~~~~ADVANCING~~~~~~~")
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            //recordButton.isEnabled = false
            print("-----stopped bc of advance call")
        }
        
        if (self.entered == 1) {
            if (advancable == 1) {
                self.socket.emitWithAck("advance", "advance-2").timingOut(after: 0) {data in
                    let strippedData = self.stripData(inData:String(describing:data));
                    
                    if(Int(strippedData)==1){
                        print("~~~~~~~ADVANCE SUCCESSFUL~~~~~~~")
                        
                        self.advance_btn.isEnabled = false;
                        self.advance_btn.isHidden = true;
                        
                        if self.gooseTimer != nil {
                            self.gooseTimer!.invalidate()
                            self.gooseTimer = nil
                        }

                        if(self.SAYLABEL){self.say_static.isHidden = true;};
                        
                    }else{
                        print("~~~~~~~ERROR:advance~~~~~~~")
                    }
                    
                }
                
            } else {
                print("~~~~~~~not advancable: not your turn~~~~~~~")
                
            }
            
        } else {
            print("~~~~~~~not advancable: not entered~~~~~~~")
            
        }
        
    }
    
    
    func stripData(inData:String) -> String {
        let outData1 = inData.replacingOccurrences(of:"[", with: "")
        let outData2 = outData1.replacingOccurrences(of:"]", with: "")
        return outData2
        
    }
    
    
    /* SPEECH RECOGNITION */
    
    func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        recognitionRequest.shouldReportPartialResults = true
        
        
        var isPassphrase = false
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if(!isPassphrase){
                if let result = result {
                    //self.textView.text = result.bestTranscription.formattedString
                    print("-----recognizing...")
                    self.haveItemsBeenSpoken = true;
                    print("passphrase:"+self.passphrase)
                    print(result.bestTranscription.formattedString)
                    print(result.bestTranscription.segments.last!.substring.lowercased())
                    isFinal = result.isFinal
                    
                    if(result.bestTranscription.segments.last?.substring.lowercased() == self.passphrase) {
                        print("-----PASSPHRASE-------")
                        isPassphrase = true;
                        self.flashColor(color:self.lightGreen);
                        self.toggleRecording();
                        self.advance(button:self.advance_btn);
                        self.haveItemsBeenSpoken = false;
                    } else {
                        self.flashColor(color:self.lightRed);
                        
                    }
                }
            }
            
            if error != nil || isFinal || isPassphrase {
                print("-------resetting")
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.haveItemsBeenSpoken = false;
                
                //self.recordButton.isEnabled = true
                
                print("-------stopped:recognitionTask")
                
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        print("-----started:startRecording")
        //textView.text = "(Go ahead, I'm listening)"
        
    }
    
    func flashColor(color:UIColor) {
        self.view.backgroundColor = color;
        _ = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(passphraseSuccessColorsTimeout), userInfo: nil, repeats: false);
    }
    
    func passphraseSuccessColorsTimeout() {
        self.view.backgroundColor = UIColor.white;
    }
    
    func gooseTimeoutHandler() {
        self.advance_btn.isEnabled = true;
        self.advance_btn.isHidden = false;
        
        if(self.haveItemsBeenSpoken == false){
            self.leave(button:self.leave_btn);
        }
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            //recordButton.isEnabled = true
            print("-----available")
        } else {
            //recordButton.isEnabled = false
            print("-----not available")
        }
    }
    
    
    func toggleRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            //recordButton.isEnabled = false
            print("-----stopped:toggleRecording")
        } else {
            try! startRecording()
            print("-----started:toggleRecording")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func closeSocket() {
        if(socket_isOpen == true){
            print("------- CLOSING SOCKET -------")
            
            self.leave(button:self.leave_btn);
            self.entered = 0;
            
            socket.disconnect();
            self.socket_isOpen = false;
            
            
            self.join_btn.isEnabled = false;
            self.join_btn.isHidden = true;
            
            self.leave_btn.isEnabled = false;
            self.leave_btn.isHidden = true;
            
            self.advance_btn.isEnabled = false;
            self.advance_btn.isHidden = true;
            
            self.textinfo_variable.text = self.textinfo_blank;
            if(self.SAYLABEL){self.say_static.isHidden = true;};
            
            UIApplication.shared.isIdleTimerDisabled = false;

        } else {
            print("--- socket already closed ---")
        }
    }
    
    func openSocket() {
        if(self.socket_isOpen == false){
            print("------- OPENING SOCKET -------")
            
            socket.connect();
            self.socket_isOpen = true;
            
            
            if(!DEBUGGING){
                self.ddg_static.isHidden = true;
                self.ddg_variable.isHidden = true;
                self.displaymessage_static.isHidden = true;
                self.textinfo_static.isHidden = true;
            }
            
            self.join_btn.isEnabled = true;
            self.join_btn.isHidden = false;
            
            self.leave_btn.isEnabled = false;
            self.leave_btn.isHidden = true;
            
            self.advance_btn.isEnabled = false;
            self.advance_btn.isHidden = true;

            self.textinfo_variable.text = self.textinfo_blank;
            if(self.SAYLABEL){self.say_static.isHidden = true;};
            
            UIApplication.shared.isIdleTimerDisabled = true;

        } else {
            print("--- socket already open ---")
            
        }
    }
    
}

