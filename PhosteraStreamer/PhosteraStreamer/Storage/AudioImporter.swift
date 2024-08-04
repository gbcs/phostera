//
//  AudioImporter.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/14/23.
//

import UIKit
import AVFoundation
import PhosteraShared

class AudioImporter {
    static public func convertAACtoLPCM(inputURL: URL, outputURL: URL, externalStorage:Bool, completionHandler: @escaping (Result<Void, Error>) -> Void) {
       
        var storageURL:URL?
        
        if externalStorage {
            if let storageMedia = SettingsService.shared.currentStorageMedia {
                storageURL = ExternalStorageManager.loadExernalStorage(media: storageMedia)
                if let storageURL {
                    if storageURL.startAccessingSecurityScopedResource() {
                        Logger.shared.info("scr worked:\(storageURL)")

                    }
                }
            }
        }

        let url = URL(filePath: inputURL.path)
        Logger.shared.info("Importing audio from \(url)")
        let asset = AVAsset(url: url)
      
        // Load audio tracks asynchronously
        asset.loadTracks(withMediaType: .audio) { tracks, error in
            if let error = error {
                completionHandler(.failure(error))
                return
            }

            guard let assetTrack = tracks?.first else {
                completionHandler(.failure(NSError(domain: "com.phostera.streamer.AudioConversion", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio tracks found"])))
                return
            }

            do {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 2
                ]
                // Configure asset reader
                let assetReader = try AVAssetReader(asset: asset)
                let assetReaderOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: audioSettings) // nil for default settings
                assetReader.add(assetReaderOutput)

                //figure out sample rate from source video
                //If not set to project standard, we have to convert it
                
                // Configure asset writer for LPCM
                let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .caf)
              
                let assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                assetWriter.add(assetWriterInput)

                // Start reading and writing
                assetReader.startReading()
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: .zero)

                assetWriterInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audioQueue")) {
                    while assetWriterInput.isReadyForMoreMediaData {
                        if let sampleBuffer = assetReaderOutput.copyNextSampleBuffer() {
                            assetWriterInput.append(sampleBuffer)
                        } else {
                            assetWriterInput.markAsFinished()
                            assetWriter.finishWriting {
                                if assetReader.status == .completed {
                                    if externalStorage {
                                        storageURL?.stopAccessingSecurityScopedResource()
                                    }
                                    completionHandler(.success(()))
                                } else {
                                    completionHandler(.failure(assetReader.error ?? NSError(domain: "com.example.AudioConversion", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error in reading audio"])))
                                }
                            }
                            assetReader.cancelReading()
                            break
                        }
                    }
                }
            } catch {
                if externalStorage {
                    storageURL?.stopAccessingSecurityScopedResource()
                }
                completionHandler(.failure(error))
            }
        }
    }

}
