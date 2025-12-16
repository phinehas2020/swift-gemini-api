// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import AudioToolbox
#if os(macOS)
import CoreAudio
#else
import AVFAudio
#endif

public final class AudioRecorder: ObservableObject, AudioRecorderProtocol {
    @Published private(set) public var isRecording: Bool = false
    @Published private(set) public var recordedFiles: [URL] = []
    public var onChunk: ((String) -> Void)?
    
    public var inputUnit: AudioUnit?
    public var streamFormat = AudioStreamBasicDescription()
    private var bufferSizeFrames: UInt32 = 4096  // Large enough for 48kHz callbacks
    public var inputBufferList: UnsafeMutablePointer<AudioBufferList>?
    
    public var audioFile: ExtAudioFileRef?
    private var fileURL: URL?
    private var audioFormat:AudioFormat = .wav
    
    private var audioConverter: AudioConverterRef?
	
	public init() {
		
	}

    deinit {
        stopRecording()
        if let buffer = inputBufferList {
            free(buffer.pointee.mBuffers.mData)
            buffer.deallocate()
        }
    }

	public func setOnChunk(_ onChunk: @escaping (String) -> Void) {
        self.onChunk = onChunk
    }

	public func startRecording() {
        guard !isRecording else { return }

        let status = createInputAudioUnit()
        guard status == noErr, let unit = inputUnit else {
            print("Failed to create input audio unit: \(status)")
            return
        }

        setupAudioFile()

        let startStatus = AudioOutputUnitStart(unit)
        guard startStatus == noErr else {
            print("Failed to start Audio Unit: \(startStatus)")
            return
        }

        isRecording = true
    }

	public func stopRecording() {
        guard isRecording, let unit = inputUnit else { return }

        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        inputUnit = nil

        if let file = audioFile {
            ExtAudioFileDispose(file)
            audioFile = nil
        }

        if let url = fileURL {
            recordedFiles.append(url)
        }

        isRecording = false
    }

    func getDestFormat() -> AudioStreamBasicDescription{
        let destFormat = AudioStreamBasicDescription(
            mSampleRate: 16000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        return destFormat
    }
    
    private func setupAudioFile() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("microphone_\(timestamp()).\(audioFormat.fileExtension)")
        self.fileURL = url
        
        print(url)

        var audioFileRef: ExtAudioFileRef?
        
        var destFormat = getDestFormat()

        let status = ExtAudioFileCreateWithURL(
            url as CFURL,
            audioFormat.fileTypeID,
            &destFormat,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &audioFileRef
        )

        guard status == noErr, let file = audioFileRef else {
            print("Failed to create audio file: \(status)")
            return
        }

        self.audioFile = file
        
        // Set the client format (actual input stream format)
        var clientFormat = streamFormat
        let clientStatus = ExtAudioFileSetProperty(
            file,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &clientFormat
        )

        if clientStatus != noErr {
            print("Failed to set client format: \(clientStatus)")
        }
    }
    
    #if os(macOS)
    func getDeviceSampleRate(deviceID: AudioDeviceID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var rate: Double = 0
        var size = UInt32(MemoryLayout.size(ofValue: rate))
        
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate)
        return status == noErr ? rate : nil
    }
    #endif

    private func createInputAudioUnit() -> OSStatus {
        var status: OSStatus = noErr

        var inputcd = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: {
                #if os(iOS)
                return kAudioUnitSubType_RemoteIO
                #else
                return kAudioUnitSubType_HALOutput
//                return kAudioUnitSubType_VoiceProcessingIO
                #endif
            }(),
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AudioComponentFindNext(nil, &inputcd) else {
            print("Error: can't find audio component")
            return -1
        }

        var unit: AudioUnit?
        status = AudioComponentInstanceNew(component, &unit)
        guard status == noErr, let inputUnit = unit else {
            print("Error: could not create AudioUnit instance")
            return status
        }

        self.inputUnit = inputUnit

        var enableIO: UInt32 = 1
        status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1,
            &enableIO,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard status == noErr else { return status }

        var disableIO: UInt32 = 0
        status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0,
            &disableIO,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard status == noErr else { return status }

        #if os(macOS)
        // Choose input device (default input) - macOS only
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        guard status == noErr else {
            print("Error getting default input device: \(status)")
            return status
        }

        status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            print("Error setting input device: \(status)")
            return status
        }
        
        let sampleRate = getDeviceSampleRate(deviceID: deviceID) ?? 44100
        #else
        // iOS: Configure AVAudioSession and get actual hardware sample rate
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            let sampleRate = audioSession.sampleRate
            print("📱 iOS Audio: Using hardware sample rate: \(sampleRate) Hz")
        } catch {
            print("❌ Failed to configure AVAudioSession: \(error)")
        }
        let sampleRate = AVAudioSession.sharedInstance().sampleRate
        #endif

        streamFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        status = AudioUnitSetProperty(
            inputUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1,
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        guard status == noErr else { return status }
        
        var sourceFormat = streamFormat
        var destFormat = getDestFormat()
        
        var converter: AudioConverterRef?
        let converterStatus = AudioConverterNew(&sourceFormat, &destFormat, &converter)
        if converterStatus == noErr, let converter = converter {
            self.audioConverter = converter
        } else {
            print("AudioConverter creation failed: \(converterStatus)")
        }
        
        // Allocate input buffer list
        inputBufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        inputBufferList?.pointee.mNumberBuffers = 1
        inputBufferList?.pointee.mBuffers.mNumberChannels = 1
        inputBufferList?.pointee.mBuffers.mDataByteSize = bufferSizeFrames * streamFormat.mBytesPerFrame
        inputBufferList?.pointee.mBuffers.mData = malloc(Int(inputBufferList!.pointee.mBuffers.mDataByteSize))

        // Set input callback
        var callbackStruct = AURenderCallbackStruct(
            inputProc: inputCallback,
            inputProcRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        status = AudioUnitSetProperty(
            inputUnit,
            kAudioOutputUnitProperty_SetInputCallback,
            kAudioUnitScope_Global,
            0,
            &callbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )
        guard status == noErr else { return status }

        return AudioUnitInitialize(inputUnit)
    }
    
    func convertTo16kHz(inputData: UnsafeRawPointer, inputFrames: UInt32) -> Data? {
        guard let converter = audioConverter else { return nil }

//        let convertedData = Data(count: Int(inputFrames * 2 * 2)) // Max size estimation

//        let inputBuffer = AudioBuffer(
//            mNumberChannels: 1,
//            mDataByteSize: inputFrames * streamFormat.mBytesPerFrame,
//            mData: UnsafeMutableRawPointer(mutating: inputData)
//        )

//        let inputBufferList = AudioBufferList(
//            mNumberBuffers: 1,
//            mBuffers: inputBuffer
//        )

        var ioOutputDataPacketSize: UInt32 = inputFrames

        let outputBuffer = UnsafeMutableRawPointer.allocate(byteCount: Int(inputFrames * 2), alignment: MemoryLayout<UInt8>.alignment)
        defer { outputBuffer.deallocate() }

        let convertedBuffer = AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: inputFrames, // * 2, this was giving a delay
            mData: outputBuffer
        )

        var convertedBufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: convertedBuffer
        )
        
        let status = AudioConverterFillComplexBuffer(
            converter,
            audioConverterInputProc, // <- this is now a function pointer, not a closure
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &ioOutputDataPacketSize,
            &convertedBufferList,
            nil
        )
        
//        AudioConverterDispose(converter!)

        if status != noErr {
            print("AudioConverterFillComplexBuffer failed: \(status)")
            return nil
        }

        return Data(bytes: convertedBufferList.mBuffers.mData!, count: Int(convertedBufferList.mBuffers.mDataByteSize))
    }

}

// MARK: - Input Callback

private func inputCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let recorder = Unmanaged<AudioRecorder>.fromOpaque(inRefCon).takeUnretainedValue()

    guard let inputUnit = recorder.inputUnit else {
        return -1
    }
    
    // Dynamically allocate buffer for the actual frame count
    let bytesNeeded = inNumberFrames * recorder.streamFormat.mBytesPerFrame
    let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
    bufferList.pointee.mNumberBuffers = 1
    bufferList.pointee.mBuffers.mNumberChannels = 1
    bufferList.pointee.mBuffers.mDataByteSize = bytesNeeded
    bufferList.pointee.mBuffers.mData = malloc(Int(bytesNeeded))
    
    defer {
        free(bufferList.pointee.mBuffers.mData)
        bufferList.deallocate()
    }

    let status = AudioUnitRender(
        inputUnit,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        inNumberFrames,
        bufferList
    )

    guard status == noErr else {
        print("AudioUnitRender failed: \(status)")
        return status
    }

    if let buffer = bufferList.pointee.mBuffers.mData {
        let audioBuffer = AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: bufferList.pointee.mBuffers.mDataByteSize,
            mData: buffer
        )

        var bufferListToWrite = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: audioBuffer
        )

        let writeStatus = ExtAudioFileWrite(recorder.audioFile!, inNumberFrames, &bufferListToWrite)
        if writeStatus != noErr {
            print("Failed to write audio data: \(writeStatus)")
        }

// 	      // converts existing format of 48kHz
//        let data = Data(bytes: buffer, count: Int(audioBuffer.mDataByteSize))
//        let base64String = data.base64EncodedString()
//        recorder.onChunk?(base64String)
        
        if let convertedData = recorder.convertTo16kHz(inputData: buffer, inputFrames: inNumberFrames) {
            let base64String = convertedData.base64EncodedString()
            recorder.onChunk?(base64String)
        }
    }


    return noErr
}

func audioConverterInputProc(
    inAudioConverter: AudioConverterRef,
    ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
    ioData: UnsafeMutablePointer<AudioBufferList>,
    outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
    inUserData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let inUserData = inUserData else {
        return kAudio_ParamError
    }

    let recorder = Unmanaged<AudioRecorder>.fromOpaque(inUserData).takeUnretainedValue()

    guard let inputBufferList = recorder.inputBufferList else {
        return kAudio_ParamError
    }

    ioData.pointee = inputBufferList.pointee
    ioNumberDataPackets.pointee = inputBufferList.pointee.mBuffers.mDataByteSize / recorder.streamFormat.mBytesPerFrame

    return noErr
}
