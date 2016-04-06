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
		let audioFileLength = AVAudioFrameCount((audioFile?.length)!)
		outSamples = AVAudioPCMBuffer(PCMFormat: (audioFile?.processingFormat)!, frameCapacity: audioFileLength)
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
	print(INT16_MIN)
	print(INT16_MAX)
	var peakValue:Int16 = 0
	for var i = 0; i < Int(inputBuffer.frameLength); i++
	{
		var sample:Int16 = inputBuffer.int16ChannelData.memory[i]
		
		if Int32(sample) >= INT16_MAX
		{
			sample = Int16(INT16_MAX - Int32(1))
		}
		if Int32(sample) <= INT16_MIN
		{
			sample = Int16(INT16_MIN + Int32(1))
		}
		
		
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
	for i in 0...Int(inputBuffer.frameLength)
	{
		let sample:Int16 = inputBuffer.int16ChannelData.memory[i]
		let normalizedSample = Int16(Double(sample) * normalizationRatio)
		normalizedAudioBuffer.int16ChannelData.memory[i] = normalizedSample
	}
	
	return normalizedAudioBuffer
}

func envelopeDetection(inputBuffer:AVAudioPCMBuffer, windowLength:Int)// -> AVAudioPCMBuffer
{
	//add padding the size of window to beginning/end of buffer
	let inputBufferLength = inputBuffer.frameLength
	let newBufferFrameLength = (Int(inputBufferLength) + (windowLength * 2))
	let paddedBuffer = AVAudioPCMBuffer(PCMFormat: inputBuffer.format, frameCapacity: UInt32(newBufferFrameLength))
	let paddedBufferLength = Int(paddedBuffer.frameCapacity)
	
	//create a list of tuples for audio segments
	
	var audioSegments:[(start:Int, end:Int)] = []
	
	//add padding to front
	for i in 0...windowLength//var i = 0; i < windowLength; i++
	{
		paddedBuffer.int16ChannelData.memory[i] = 0
	}

	//add sample values
	for i in windowLength...Int(inputBufferLength)
	{
		paddedBuffer.int16ChannelData.memory[i] = inputBuffer.int16ChannelData.memory[i-windowLength];
	}
	
	//add padding to back
	
	for i in (windowLength+Int(inputBufferLength))...paddedBufferLength
	{
		paddedBuffer.int16ChannelData.memory[i] = 0
	}
	
	//window length is in samples
	var rollingRMS:Int = 0

	//create a rolling RMS to find audio envelope use -70 dB as
	for i in 0...paddedBufferLength
	{
		let sample:Int16 = paddedBuffer.int16ChannelData.memory[i]
		rollingRMS += pow(sample, 2.0)
		rollingRMS /= windowLength
		rollingRMS = sqrt(rollingRMS)
	}
	
}

func compressDownward(inputBuffer:AVAudioPCMBuffer, ratio:float_t, threshold:Int)
{
	
}

func compressUpward(inputBuffer:AVAudioPCMBuffer, ratio:float_t, threshold:Int)
{
	
}

func beatDetection()
{
	
}


do
{
	let url = NSURL(fileURLWithPath: "/Users/armen/Music/loops/ACID_009.WAV")
	let samples:AVAudioPCMBuffer? = getSamplesFromAVAudioFile(url)
	let normalizedSamples = normalizeAudio(samples!)

	envelopeDetection(normalizedSamples, windowLength: 50)
	
	let audioDataPointer = normalizedSamples.int16ChannelData.memory
	let bufferSizeInBytes = Int(normalizedSamples.frameLength) * 2
	let audioData = NSData(bytes: audioDataPointer, length: bufferSizeInBytes)

	audioData.writeToFile("/Users/armen/Desktop/data", atomically: true)

}
catch
{
	print("Can't create player")
}
