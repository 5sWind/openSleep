//
//  Recordings.swift
//  openSleep
//
//  Created by Adam Haar Horowitz on 11/21/18.
//  Copyright © 2018 Tomas Vega. All rights reserved.
//

import Foundation
import AVFoundation

struct Recording : Codable {
  var path: String
  var time: Date
  var length: Int
}

class RecordingsManager : NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
  static let shared = RecordingsManager()
  
  
  var recordings = [String : [Recording]]()
  
  var recordingSession : AVAudioSession!
  var audioRecorder    :AVAudioRecorder!
  var audioRecorderSettings = [String : Int]()
  var audioPlayer : AVAudioPlayer!
  var audioURLs = [Int: URL]()
  
  var doOnPlayingEnd : (() -> ())? = nil
  
  private override init() {
    super.init()
    
    let defaults = UserDefaults.standard
    if let savedPerson = defaults.object(forKey: "recordings") as? Data {
      let decoder = JSONDecoder()
      if let loadedRecordings = try? decoder.decode(Dictionary<String, Array<Recording>>.self, from: savedPerson) {
        recordings = loadedRecordings
      }
    }
    
    /*
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
    recordings = [
      "Poetry" : [
        Recording(path: "", time: dateFormatter.date(from: "03/11/2018 14:00")!, length: 30),
        Recording(path: "", time: dateFormatter.date(from: "03/11/2018 14:12")!, length: 90)
      ],
      "Anomaly Detection" : [
        Recording(path: "", time: dateFormatter.date(from: "23/11/2018 07:30")!, length: 80)
      ],
      "Ph.D. Application" : [
        Recording(path: "", time: dateFormatter.date(from: "20/11/2018 07:10")!, length: 30),
        Recording(path: "", time: dateFormatter.date(from: "21/11/2018 07:12")!, length: 40),
        Recording(path: "", time: dateFormatter.date(from: "24/11/2018 07:45")!, length: 65),
      ],
      "Snowboard" : [
        Recording(path: "", time: dateFormatter.date(from: "17/03/2018 07:55")!, length: 100),
        Recording(path: "", time: dateFormatter.date(from: "19/03/2018 07:55")!, length: 105)
      ]
    ]
 */
    
    // Audio recording session
    recordingSession = AVAudioSession.sharedInstance()
    do {
      try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:AVAudioSessionCategoryOptions.defaultToSpeaker)
      try recordingSession.setActive(true)
      recordingSession.requestRecordPermission() { [unowned self] allowed in
        DispatchQueue.main.async {
          if allowed {
            print("Allow")
          } else {
            print("Dont Allow")
          }
        }
      }
    } catch {
      print("failed to record!")
    }
    
    // Audio Settings
    audioRecorderSettings = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
  }
  
  func addRecording(categoryName: String, path: String, length: Int) {
    let newRecording = Recording(path: path, time: Date(), length: length)
    if var r = recordings[categoryName] {
      r.append(newRecording)
      recordings[categoryName] = r
    } else {
      recordings[categoryName] = [newRecording]
    }
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(recordings) {
      let defaults = UserDefaults.standard
      defaults.set(encoded, forKey: "recordings")
    }
  }
  
  func numOfCategories() -> Int {
    return recordings.count
  }
  
  func numOfRecordings(category: Int) -> Int {
    let key = Array(recordings.keys)[category]
    if let r = recordings[key] {
      return r.count
    }
    return 0
  }
  
  func getCategories() -> [String] {
    return Array(recordings.keys)
  }
  
  func getRecording(category: Int, index: Int) -> Recording? {
    let key = Array(recordings.keys)[category]
    if let r = recordings[key] {
      return r[index]
    }
    return nil
  }
  
  func getCategoryTitle(category: Int) -> String? {
    let key = Array(recordings.keys)[category]
    return key
  }
  
  func audioDirectoryURL(_ number: Int) -> URL? {
    let id: String = String(number)
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    let documentDirectory = urls[0] as NSURL
    let soundURL = documentDirectory.appendingPathComponent("sound_\(id).m4a")
    print(soundURL!)
    return soundURL
  }
  
  func audioDirectoryURLwithTimestamp() -> URL? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmm"
    let now = formatter.string(from: Date())
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    let documentDirectory = urls[0] as NSURL
    let soundURL = documentDirectory.appendingPathComponent("record_\(now).m4a")
    print(soundURL!)
    return soundURL
  }
  
  // mode - 0: think of, 1: what are you dreamin
  func startRecording(mode: Int) {
    let audioSession = AVAudioSession.sharedInstance()
    do {
      if let url = self.audioDirectoryURL(mode) {
        //addRecording(categoryName: "Test", path: url!.absoluteString, length: 60)
        audioRecorder = try AVAudioRecorder(url: url as URL,
                                            settings: audioRecorderSettings)
        audioRecorder.delegate = self
        audioRecorder.prepareToRecord()
        
        audioURLs[mode] = url
        print("url = \(url)")
      }
    } catch {
      audioRecorder.stop()
    }
    do {
      try audioSession.setActive(true)
      audioRecorder.record()
    } catch {
    }
  }
  
  func startRecordingDream(dreamTitle: String) {
    let audioSession = AVAudioSession.sharedInstance()
    do {
      if let url = self.audioDirectoryURLwithTimestamp() {
        addRecording(categoryName: dreamTitle, path: url.absoluteString, length: 60)
        audioRecorder = try AVAudioRecorder(url: url as URL,
                                            settings: audioRecorderSettings)
        audioRecorder.delegate = self
        audioRecorder.prepareToRecord()
        
        print("url = \(url)")
      }
    } catch {
      audioRecorder.stop()
    }
    do {
      try audioSession.setActive(true)
      audioRecorder.record()
    } catch {
    }
  }
  
  func stopRecording() {
    audioRecorder.stop()
  }
  
  func startPlaying(mode: Int, onFinish: (() -> ())? = nil) {
    self.audioPlayer = try! AVAudioPlayer(contentsOf: audioURLs[mode]!)
    self.audioPlayer.prepareToPlay()
    self.audioPlayer.delegate = self
    //    self.audioPlayer.currentTime = max(0 as TimeInterval, self.audioPlayer.duration - audioPlaybackOffset)
    self.audioPlayer.play()
  }
  
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    //You can stop the audio
    player.stop()
    if let dope = doOnPlayingEnd {
      dope()
      doOnPlayingEnd = nil
    }
  }
}


