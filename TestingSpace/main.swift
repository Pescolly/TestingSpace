//
//  main.swift
//  TestingSpace
//
//  Created by armen karamian on 1/30/16.
//  Copyright © 2016 armen karamian. All rights reserved.
//

import AVFoundation
import Foundation

struct UNIVERSAL_AUDIO_SETTINGS
{
	static let SAMPLE_BYTE_SIZE = 2
	static let CHANNEL_COUNT = 1
	static let SAMPLE_RATE:Double = 48000.0
	
	static let AUDIO_PLAY_RECORD_SETTINGS = [
		AVFormatIDKey: Int(kAudioFormatLinearPCM),
		AVSampleRateKey: SAMPLE_RATE,
		AVNumberOfChannelsKey: CHANNEL_COUNT as NSNumber,
		AVLinearPCMBitDepthKey : SAMPLE_BYTE_SIZE * 8,
		AVLinearPCMIsBigEndianKey : false,
		AVLinearPCMIsFloatKey : false,
	]
	
	
	/*
	static let CHANNEL_LAYOUT:AudioChannelLayout = AudioChannelLayout(mChannelLayoutTag: kAudioChannelLayoutTag_Mono,
		mChannelBitmap: AudioChannelBitmap.Bit_Left,
		mNumberChannelDescriptions: UInt32(CHANNEL_COUNT),
		mChannelDescriptions: )

	static let CHANNEL_DESCRIPTION = AudioChannelDescription(mChannelLabel: kAudioChannelLabel_Mono, mChannelFlags: kAudioChannel, mCoordinates: <#T##(Float32, Float32, Float32)#>)
	//static let AV_AUDIO_CHANNEL_LAYOUT = AVAudioChannelLayout(layout: CHANNEL_LAYOUT)
*/
	static let AV_AUDIO_CHANNEL_LAYOUT = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Mono)
}

/*
func createAudioBufferFromNSData(inData:NSData) -> AVAudioPCMBuffer
{
	let framecount:AVAudioFrameCount = UInt32(inData.length) / UInt32(UNIVERSAL_AUDIO_SETTINGS.SAMPLE_BYTE_SIZE)
	let format = AVAudioFormat(standardFormatWithSampleRate: UNIVERSAL_AUDIO_SETTINGS.SAMPLE_RATE, channelLayout: UNIVERSAL_AUDIO_SETTINGS.AV_AUDIO_CHANNEL_LAYOUT)
	
	let outBuffer = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: framecount)
}
*/


func getSamplesFromAVAudioFile(url:NSURL) -> AVAudioPCMBuffer?
{
	let audioFile:AVAudioFile?
	let outSamples:AVAudioPCMBuffer?
	do
	{
		audioFile = try AVAudioFile(forReading: url, commonFormat: AVAudioCommonFormat.PCMFormatInt16, interleaved: false)
		outSamples = AVAudioPCMBuffer(PCMFormat: (audioFile?.processingFormat)!, frameCapacity: AVAudioFrameCount((audioFile?.length)!))
		try audioFile?.readIntoBuffer(outSamples!)
		
		return outSamples
	}
	catch
	{
		print("open failed")
		return nil
	}
}

func getSamplesFromAVAsset(url:NSURL) -> NSData?
{
	let audioAsset:AVURLAsset?
	let assetReader:AVAssetReader?
	let assetReaderOutput:AVAssetReaderTrackOutput?
	let sampleData:NSMutableData = NSMutableData()
	
	do
	{
		//create asset, reader and output
		audioAsset = AVURLAsset(URL: url)
		assetReader = try AVAssetReader(asset: audioAsset!)
	
		//pull tracks and assign to output
		let firstTrack = audioAsset?.tracksWithMediaType(AVMediaTypeAudio).first
		assetReaderOutput = AVAssetReaderTrackOutput(track: firstTrack!, outputSettings: nil)
		//add output and start reading
		assetReader!.addOutput(assetReaderOutput!)
		assetReader!.startReading()
		
		while(assetReader!.status == AVAssetReaderStatus.Reading)
		{
			//get buffer and block buffer
			let sampleBuffer = assetReaderOutput!.copyNextSampleBuffer()
			//check sample and block buffer
			if (sampleBuffer != nil)
			{
				let sampleBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer!)
				if (sampleBlockBuffer != nil)
				{
					let sampleBlockBufferLength = CMBlockBufferGetDataLength(sampleBlockBuffer!)
					var sampleBlockBufferData:UnsafeMutablePointer<Int8> = UnsafeMutablePointer<Int8>()
					let status = CMBlockBufferGetDataPointer(sampleBlockBuffer!, 0, nil, nil, &sampleBlockBufferData)
					//append block buffer data into nsdata if ok
					if (status == noErr)
					{
						if (sampleBlockBufferData != nil)
						{
							sampleData.appendBytes(sampleBlockBufferData, length: sampleBlockBufferLength)
						}
					}
					
				}
			}
		}
		return sampleData
	}
	catch let err as NSError
	{
		print("asset reader error")
		print(err)
		return nil
	}
}

func getPeakFromSamples(inputBuffer:AVAudioPCMBuffer) -> Int16
{
	var peakValue:Int16 = 0
	for var i = 0; i < Int(inputBuffer.frameLength); i++
	{
		let sample:Int16 = inputBuffer.int16ChannelData.memory[i]
		let absSampleValue:Int16 = abs(sample)
		if absSampleValue > peakValue
		{
			peakValue = absSampleValue
		}
	}
	return peakValue
}

func normalizeAudio(inputBuffer:AVAudioPCMBuffer) -> AVAudioPCMBuffer
{
	//get peak and set ratio using peak with headroom
	let peak:Int16 = getPeakFromSamples(inputBuffer)
	let paddedMax:Int16 = Int16.max - 3000
	let normalizationMax = Double(peak) / Double(paddedMax)
	let normalizationRatio = 1 + (1-normalizationMax) //get ratio for multiplication (normMax:1)
	
	let normalizedAudioBuffer:AVAudioPCMBuffer = AVAudioPCMBuffer(PCMFormat: inputBuffer.format, frameCapacity: inputBuffer.frameCapacity)
	normalizedAudioBuffer.frameLength = inputBuffer.frameCapacity
	for var i = 0; i < Int(inputBuffer.frameLength); i++
	{
		let sample:Int16 = inputBuffer.int16ChannelData.memory[i]
		let normalizedSample = Int16(Double(sample) * normalizationRatio)
		normalizedAudioBuffer.int16ChannelData.memory[i] = normalizedSample
	}
	
	return normalizedAudioBuffer
}

func compressAudio(inputBuffer:AVAudioPCMBuffer)
{
	
}

func beatDetection()
{
	
}


do
{
	let url = NSURL(fileURLWithPath: "/Users/armen/Documents/440hz.aiff")
	let samples:AVAudioPCMBuffer? = getSamplesFromAVAudioFile(url)
	let normalizedSamples = normalizeAudio(samples!)
	
	let audioDataPointer = normalizedSamples.int16ChannelData.memory
	let audioData = NSData(bytes: audioDataPointer, length: Int(normalizedSamples.frameLength))

	audioData.writeToFile("/Users/armen/Desktop/data", atomically: true)
	
	let player = try AVAudioPlayer(data: audioData, fileTypeHint: AVFileTypeWAVE)
	player.prepareToPlay()
	player.play()
}
catch
{
	print("Can't create player")
}
