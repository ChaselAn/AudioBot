//
//  ViewController.swift
//  VoiceMemo
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import UIKit
import AudioBot
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var voiceMemosTableView: UITableView!
    @IBOutlet weak var recordButton: RecordButton!
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var waver: Waver!
    @IBOutlet weak var waverBottom: NSLayoutConstraint!
    @IBOutlet weak var buttonBottom: NSLayoutConstraint!

    var bottomConstrains: [NSLayoutConstraint] {
        return [self.buttonBottom, self.waverBottom]
    }

    var voiceMemos: [VoiceMemo] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        AudioBot.prepareForNormalRecord()
    }

    @IBAction func modeChangeAction(_ sender: Any) {
        let startConstant: CGFloat = 0
        let endConstant: CGFloat = -128.0
        let animationDuration: TimeInterval = 0.3
        let index  = modeSegmentedControl.selectedSegmentIndex
        self.bottomConstrains[1 - index].constant = endConstant
        UIView.animate(withDuration: animationDuration, animations: {
            self.view.layoutIfNeeded()
        }, completion: { (finished) in
            if finished {
                self.bottomConstrains[index].constant = startConstant
                UIView.animate(withDuration: animationDuration, animations: {
                    self.view.layoutIfNeeded()
                })
            }
        })
        if index == 1 {
            do {
                self.waver.waverCallback = { _ in }
                let decibelSamplePeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: 60, report: { decibelSample in
                    print("decibelSample: \(decibelSample)")
                    self.waver.level = CGFloat(decibelSample)
                })
                let vadSettings = VADSettings()
                vadSettings.silenceDuration = 0.75
                vadSettings.silenceVolume = 0.05
                let usage = AudioBot.Usage.custom(fileURL: nil, type: "wav", settings: AudioBot.Usage.wavSettings)
                try AudioBot.startAutomaticRecordAudio(forUsage: usage, withVADSettings: vadSettings, decibelSamplePeriodicReport: decibelSamplePeriodicReport) { [weak self] (fileURL, duration, decibelSamples) in
                    print("fileURL: \(fileURL)")
                    print("duration: \(duration)")
                    print("decibelSamples: \(decibelSamples)")
                    if duration < 2.5 { return }
                    guard let newFileURL = FileManager.voicememo_audioFileURLWithName(UUID().uuidString, "wav") else { return }
                    guard let _ = try? FileManager.default.copyItem(at: fileURL, to: newFileURL) else { return }
                    let voiceMemo = VoiceMemo(fileURL: newFileURL, duration: duration)
                    self?.voiceMemos.append(voiceMemo)
                    self?.voiceMemosTableView.reloadData()
                }
            } catch {
                print("record error: \(error)")
            }
        } else {
            AudioBot.stopAutomaticRecord()
        }
    }
    
    @IBAction func record(_ sender: UIButton) {
        if AudioBot.isRecording {
            AudioBot.stopRecord { [weak self] fileURL, duration, decibelSamples in
                print("fileURL: \(fileURL)")
                print("duration: \(duration)")
                print("decibelSamples: \(decibelSamples)")
                guard let newFileURL = FileManager.voicememo_audioFileURLWithName(UUID().uuidString, "m4a") else { return }
                guard let _ = try? FileManager.default.copyItem(at: fileURL, to: newFileURL) else { return }
                let voiceMemo = VoiceMemo(fileURL: newFileURL, duration: duration)
                self?.voiceMemos.append(voiceMemo)
                self?.voiceMemosTableView.reloadData()
            }
            recordButton.appearance = .default
        } else {
            do {
                let decibelSamplePeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: 10, report: { decibelSample in
                    print("decibelSample: \(decibelSample)")
                })
                try AudioBot.startRecordAudio(forUsage: .normal, withDecibelSamplePeriodicReport: decibelSamplePeriodicReport)
                recordButton.appearance = .recording
            } catch {
                print("record error: \(error)")
            }
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return voiceMemos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceMemoCell") as! VoiceMemoCell
        let voiceMemo = voiceMemos[indexPath.row]
        cell.configureWithVoiceMemo(voiceMemo)
        cell.playOrPauseAction = { [weak self] cell, progressView in
            func tryPlay() {
                do {
                    let progressPeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: 10, report: { progress in
                        print("progress: \(progress)")
                        voiceMemo.progress = CGFloat(progress)
                        progressView.progress = progress
                    })
                    let fromTime = TimeInterval(voiceMemo.progress) * voiceMemo.duration
                    try AudioBot.startPlayAudioAtFileURL(voiceMemo.fileURL, fromTime: fromTime, withProgressPeriodicReport: progressPeriodicReport, finish: { success in
                        voiceMemo.playing = false
                        cell.playing = false
                    })
                    voiceMemo.playing = true
                    cell.playing = true
                } catch {
                    print("play error: \(error)")
                }
            }
            if AudioBot.isPlaying {
                AudioBot.pausePlay()
                if let strongSelf = self {
                    for index in 0..<(strongSelf.voiceMemos).count {
                        let voiceMemo = strongSelf.voiceMemos[index]
                        if AudioBot.playingFileURL == voiceMemo.fileURL {
                            let indexPath = IndexPath(row: index, section: 0)
                            if let cell = tableView.cellForRow(at: indexPath) as? VoiceMemoCell {
                                voiceMemo.playing = false
                                cell.playing = false
                            }
                            break
                        }
                    }
                }
                if AudioBot.playingFileURL != voiceMemo.fileURL {
                    tryPlay()
                }
            } else {
                tryPlay()
            }
        }
        return cell
    }
}
