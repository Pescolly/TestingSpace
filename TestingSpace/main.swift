//
//  main.swift
//  TestingSpace
//
//  Created by armen karamian on 1/30/16.
//  Copyright © 2016 armen karamian. All rights reserved.
//

import AVFoundation
import Foundation
import Accelerate

struct UNIVERSAL_AUDIO_SETTINGS
{
	static let SAMPLE_BYTE_SIZE = 2
	static let CHANNEL_COUNT = 1
	static let SAMPLE_RATE:Double = 44100
	
	static let AUDIO_PLAY_RECORD_SETTINGS = [
		AVFormatIDKey: Int(kAudioFormatLinearPCM),
		AVSampleRateKey: SAMPLE_RATE,
		AVNumberOfChannelsKey: CHANNEL_COUNT as NSNumber,
		AVLinearPCMBitDepthKey : 32,
		AVLinearPCMIsBigEndianKey : false,
		AVLinearPCMIsFloatKey : true,
	] as [String : Any]
	
	static let audioF = AVAudioFormat(settings: AUDIO_PLAY_RECORD_SETTINGS)
	
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


func getSamplesFromAVAudioFile(_ url:URL) -> AVAudioPCMBuffer?
{
	let audioFile:AVAudioFile?
	let outSamples:AVAudioPCMBuffer?
	do
	{
		audioFile = try AVAudioFile(forReading: url, commonFormat: AVAudioCommonFormat.pcmFormatInt16, interleaved: false)
		let audioFileLength = AVAudioFrameCount((audioFile?.length)!)
		outSamples = AVAudioPCMBuffer(pcmFormat: (audioFile?.processingFormat)!, frameCapacity: audioFileLength)
		try audioFile?.read(into: outSamples!)
		
		return outSamples
	}
	catch
	{
		print("open failed")
		return nil
	}
}

func getSamplesFromAVAsset(_ url:URL) -> Data?
{
	let audioAsset:AVURLAsset?
	let assetReader:AVAssetReader?
	let assetReaderOutput:AVAssetReaderTrackOutput?
	let sampleData:NSMutableData = NSMutableData()
	
	do
	{
		//create asset, reader and output
		audioAsset = AVURLAsset(url: url)
		assetReader = try AVAssetReader(asset: audioAsset!)
	
		//pull tracks and assign to output
		let firstTrack = audioAsset?.tracks(withMediaType: AVMediaTypeAudio).first
		assetReaderOutput = AVAssetReaderTrackOutput(track: firstTrack!, outputSettings: nil)
		//add output and start reading
		assetReader!.add(assetReaderOutput!)
		assetReader!.startReading()
		
		while(assetReader!.status == AVAssetReaderStatus.reading)
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
					var sampleBlockBufferData:UnsafeMutablePointer<Int8>? = nil
					let status = CMBlockBufferGetDataPointer(sampleBlockBuffer!, 0, nil, nil, &sampleBlockBufferData)
					//append block buffer data into nsdata if ok
					if (status == noErr)
					{
						if (sampleBlockBufferData != nil)
						{
							sampleData.append(sampleBlockBufferData!, length: sampleBlockBufferLength)
						}
					}
					
				}
			}
		}
		return sampleData as Data
	}
	catch let err as NSError
	{
		print("asset reader error")
		print(err)
		return nil
	}
}

func getPeakFromSamples(_ inputBuffer:AVAudioPCMBuffer) -> Int16
{
	print(INT16_MIN)
	print(INT16_MAX)
	var peakValue:Int16 = 0
	for i in 0 ..< Int(inputBuffer.frameLength)
	{
		var sample:Int16 = inputBuffer.int16ChannelData!.pointee[i]
		
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

func envelopeDetection(_ inputBuffer:AVAudioPCMBuffer, windowLength:Int)// -> AVAudioPCMBuffer
{
	//window length is in samples
	//add padding the size of window to beginning/end of buffer
	let inputBufferLength = inputBuffer.frameLength
	let newBufferFrameLength = (Int(inputBufferLength) + (windowLength * 2))
	let paddedBuffer = AVAudioPCMBuffer(pcmFormat: inputBuffer.format, frameCapacity: UInt32(newBufferFrameLength))
	let paddedBufferLength = Int(paddedBuffer.frameCapacity)
	
	//create a list of tuples for audio segments
	
	var audioSegments:[(start:Int, end:Int)] = []
//TODO change to memcpy
	//add padding to front
	for i in 0...windowLength//var i = 0; i < windowLength; i++
	{
		paddedBuffer.int16ChannelData?.pointee[i] = 0
	}
//TODO change to memcpy
	//add sample values
	for i in windowLength...Int(inputBufferLength)
	{
		paddedBuffer.int16ChannelData?.pointee[i] = (inputBuffer.int16ChannelData?.pointee[i-windowLength])!;
	}
	//TODO change to memcpy
	//add padding to back
	
	for i in (windowLength+Int(inputBufferLength))...paddedBufferLength
	{
		paddedBuffer.int16ChannelData?.pointee[i] = 0
	}
	
	//create initial values
	var rollingSum:Double = 0
	var sample0 = Double((paddedBuffer.int16ChannelData?.pointee[0])!)
	
	//set silence on/off
	var silence:Bool = true
	var audioStart = 0
	var audioEnd = 0
	
	//create a rolling RMS to find audio envelope use -70 dB as
	for i in 0...paddedBufferLength
	{
		//get sample value and subtract sample that falls out of scope of the summing window
		let sample:Int16 = paddedBuffer.int16ChannelData!.pointee[i]
		let doubleSample = Double(sample)
		if i > windowLength
		{
			rollingSum -= Double(sample0)
			sample0 = pow(Double((paddedBuffer.int16ChannelData?.pointee[i-windowLength])!),2)
		}
		//perform RMS
		rollingSum += pow(doubleSample, 2.0)
		let mean = rollingSum / Double(windowLength)
		let RMS = sqrt(mean)

		//convert rms to dB
		let RMSdB = 20 * log10(RMS/Double(INT16_MAX))
		
		//set silence to false if RMS > -70
		if RMSdB > -70
		{
			if silence == true
			{
				audioStart = i
			}
			silence = false
		}
		
		//set silence to true if RMS < -70
		if RMSdB < -70
		{
			//if end of current section of audio set create audio tuple
			if silence == false
			{
				audioEnd = i
				let audioStartStopTuple = (audioStart, audioEnd)
				audioSegments.append(audioStartStopTuple)
			}
			silence = true
		}
	}
	print(audioSegments)
}

func compressDownward(_ inputBuffer:AVAudioPCMBuffer, ratio:float_t, threshold:Int)
{
	
}

func compressUpward(_ inputBuffer:AVAudioPCMBuffer, ratio:float_t, threshold:Int)
{
	
}

func beatDetection(_ buffer : AVAudioPCMBuffer)
{
	let setup: FFTSetup? = nil
	//	vDSP_FFT16_copv(<#T##__Output: UnsafeMutablePointer<Float>##UnsafeMutablePointer<Float>#>, <#T##__Input: UnsafePointer<Float>##UnsafePointer<Float>#>, <#T##__Direction: FFTDirection##FFTDirection#>)
}

func multipointTimeStretching()
{
	
}

func create_fade_in_out(inputBuffer : AVAudioPCMBuffer) -> AVAudioPCMBuffer
{
	// y = 1 + 9x/480
	let FADE_Sec : Double = 0.003
	let fade_length : Double = inputBuffer.format.sampleRate * FADE_Sec
	
	for sample_index in 0 ... Int(fade_length)
	{
		let sample = inputBuffer.floatChannelData?.pointee[Int(sample_index)]
			//scale to fade into max value
		let scale = log10(1.0 + ((9.0 * Double(sample_index)) / fade_length))
		if scale > 1.0 { break }
		inputBuffer.floatChannelData?.pointee[Int(sample_index)] = Float(scale) * sample!
		if sample != 0 { inputBuffer.floatChannelData?.pointee[Int(sample_index)] = sample! * Float(scale) }
	}

	for sample_index in 0 ... Int(fade_length)
	{
		let new_index = Int(inputBuffer.frameLength) - Int(sample_index)
		let sample = inputBuffer.floatChannelData?.pointee[new_index]
		let scale = log10(1.0 + ((9.0 * Double(sample_index)) / fade_length))
		if scale > 1.0 { break }
		inputBuffer.floatChannelData?.pointee[new_index] = Float(scale) * sample!
		if sample != 0 { inputBuffer.floatChannelData?.pointee[Int(sample_index)] = sample! * Float(scale) }
	}
	
	return inputBuffer
}

func getFloatPeakFromSamples(_ inputBuffer:AVAudioPCMBuffer) -> Float
{
	var peak_value : Float = 0.0
	vDSP_maxmgv((inputBuffer.floatChannelData?.pointee)!, vDSP_Stride(inputBuffer.format.channelCount), &peak_value, vDSP_Length(inputBuffer.frameLength))
	return peak_value
}

func normalizeAudioSamples(_ inputBuffer:AVAudioPCMBuffer) -> AVAudioPCMBuffer
{
	//get peak and set ratio using peak with headroom
	let peak : Float = getFloatPeakFromSamples(inputBuffer)
	
	for i in 0...Int(inputBuffer.frameLength)
	{
		let sample : Float = inputBuffer.floatChannelData!.pointee[i]
		inputBuffer.floatChannelData?.pointee[i] = (sample / peak)
	}
	
	return inputBuffer
}


func convolution(inputBuffer_1 : AVAudioPCMBuffer, buffer_1_weight : Float, inputBuffer_2 : AVAudioPCMBuffer, buffer_2_weight : Float) -> AVAudioPCMBuffer
{
	//de-constantize the input weights
	let scalar_1 = [buffer_1_weight]
	let scalar_2 = [buffer_2_weight]
	
	//create x vector using input_buffer 1 and scale by weight
	let input_vector = inputBuffer_1.floatChannelData?.pointee
	var x_vector = [Float](repeating: 0.0, count: Int(inputBuffer_1.frameLength))
	vDSP_vsmul(input_vector!, 1, scalar_1, &x_vector, 1, vDSP_Length(inputBuffer_1.frameLength))
	
	
	//create h vector using input buffer 2  and scale
	let input_vector_2 = inputBuffer_2.floatChannelData?.pointee
	var h_vector = [Float](repeating: 0.0, count: Int(inputBuffer_2.frameLength))
	vDSP_vsmul(input_vector_2!, 1, scalar_2, &h_vector, 1, vDSP_Length(inputBuffer_2.frameLength))
	
	
	if h_vector.count > x_vector.count	//make sure x is longer than h
	{
		let temp = x_vector
		x_vector = h_vector
		h_vector = temp
	}
	
	//perform convolution of x and h
	let resultSize = x_vector.count + h_vector.count - 1
	var result = [Float](repeating: 0, count: resultSize)
	let kEnd = UnsafePointer<Float>(h_vector).advanced(by: h_vector.count - 1)
	let a1_pad = repeatElement(Float(0.0), count: h_vector.count-1)
	let sample_array_1_padded = a1_pad + x_vector + a1_pad
	vDSP_conv(sample_array_1_padded, 1, kEnd, -1, &result, 1, vDSP_Length(resultSize), vDSP_Length(h_vector.count))
	
	
	var newBuffer = AVAudioPCMBuffer(pcmFormat: inputBuffer_1.format, frameCapacity: AVAudioFrameCount(result.count))
	for sample_index in 0 ... resultSize-1
	{
		newBuffer.floatChannelData?.pointee[sample_index] = result[sample_index]
	}
	
	newBuffer.frameLength = inputBuffer_1.frameLength + inputBuffer_2.frameLength - 1
	newBuffer = normalizeAudioSamples(newBuffer)
	return newBuffer
	
}

//start
do
{
	
	let url1 = URL(fileURLWithPath: "/Users/armen/Desktop/AUDIOFILES/SadLull.wav")
	let audioFile_1 = try AVAudioFile(forReading: url1)	//getSamplesFromAVAudioFile(url)
	let inputBuffer_1 : AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat: audioFile_1.processingFormat,
													frameCapacity: AVAudioFrameCount(audioFile_1.length))
	try audioFile_1.read(into: inputBuffer_1)
	
	let url2 = URL(fileURLWithPath: "/Users/armen/Desktop/AUDIOFILES/Shaker.wav")
	let audioFile_2 = try AVAudioFile(forReading: url2)	//getSamplesFromAVAudioFile(url)
	let inputBuffer_2 : AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat: audioFile_2.processingFormat,
	                                                        frameCapacity: AVAudioFrameCount(audioFile_2.length))
	try audioFile_2.read(into: inputBuffer_2)

	let newBuffer = convolution(inputBuffer_1: inputBuffer_1, buffer_1_weight: 0.5, inputBuffer_2: inputBuffer_2, buffer_2_weight: 1.0)
	
	let peak = getFloatPeakFromSamples(newBuffer)
	
	let output_URL = URL(fileURLWithPath: "/Users/armen/Desktop/convolve.wav")
	let newAudioFile = try AVAudioFile(forWriting: output_URL, settings: newBuffer.format.settings)
	try newAudioFile.write(from: newBuffer)

	
	

}

catch { print("Can't create player") }

