//
//  CAMultiAudioDownmixer.m
//  CocoaSplit
//
//  Created by Zakk on 6/3/15.
//  Copyright (c) 2015 Zakk. All rights reserved.
//

#import "CAMultiAudioDownmixer.h"
#import "CAMultiAudioGraph.h"
#import "math.h"
@implementation CAMultiAudioDownmixer

-(instancetype)init
{
    if (self = [super initWithSubType:kAudioUnitSubType_MatrixMixer unitType:kAudioUnitType_Mixer])
    {
        
    }
    
    return self;
}

-(instancetype)initWithInputChannels:(int)channels
{
    if (self = [self init])
    {
        _inputChannels = channels;
        self.inputChannelCount = channels;
    }
    return self;
}




-(void)setOutputVolume
{
    AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Global, 0xFFFFFFFF, self.volume, 0);
}


-(void)setVolume:(float)volume
{
    super.volume = volume;
    
    
    [self setOutputVolume];
    
}

-(void)enableMeteringOnInputBus:(UInt32)bus
{
    if (self.audioUnit)
    {
        UInt32 enableVal = 1;
        OSStatus err;
        err = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Input, bus, &enableVal, sizeof(enableVal));
        //err = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Output, 0, &enableVal, sizeof(enableVal));
        
        if (err)
        {
            NSLog(@"SET METERING MODE FAILED FOR BUS %d ERR %d", bus, err);
        }
    }
}

-(Float32)powerForOutputBus:(UInt32)bus
{
    Float32 result = 0;
    OSStatus err;
    
    err = AudioUnitGetParameter(self.audioUnit, kStereoMixerParam_PostAveragePower, kAudioUnitScope_Output, bus, &result);
    //err = AudioUnitGetParameter(self.audioUnit, kStereoMixerParam_PostAveragePower, kAudioUnitScope_Output, 0, &result);
    
    
    if (err)
    {
        NSLog(@"GET POWER ERROR %d", err);
    }
    
    return result;
}

-(Float32)powerForInputBus:(UInt32)bus
{
    Float32 result = 0;
    OSStatus err;
    
    err = AudioUnitGetParameter(self.audioUnit, kStereoMixerParam_PostAveragePower, kAudioUnitScope_Input, bus, &result);
    //err = AudioUnitGetParameter(self.audioUnit, kStereoMixerParam_PostAveragePower, kAudioUnitScope_Output, 0, &result);
    
    
    if (err)
    {
        NSLog(@"GET POWER ERROR %d", err);
    }
    
    return result;
}


-(Float32)outputPower
{
    Float32 result = 0;
    OSStatus err;
    
    
    err = AudioUnitGetParameter(self.audioUnit, kStereoMixerParam_PostAveragePower, kAudioUnitScope_Output, 0, &result);
    
    
    if (err)
    {
        NSLog(@"GET POWER ERROR %d", err);
    }
    
    return result;
    
}



-(void)setVolumeForScope:(AudioUnitScope)scope onBus:(AudioUnitElement)onBus volume:(float)volume
{
    if (!self.audioUnit)
    {
        NSLog(@"SetVolumeForScope for %@ failed, no AudioUnit!?",self);
        return;
    }
    OSStatus err;
    
    
    err = AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Volume, scope, onBus, volume, 0);
    if (err)
    {
        NSLog(@"SetVolumeForScope for %@: AUSetParameter failed, err: %d", self, err);
        return;
    }
}


-(void)setVolumeOnInputBus:(UInt32)bus volume:(float)volume
{
    //Downmixers only have one input bus, so just set the global volume to whatever is requested instead of messing around with all the channels.
    
    [self setVolumeForScope:kAudioUnitScope_Global onBus:0xFFFFFFFF volume:volume];
}



-(bool)createNode:(CAMultiAudioGraph *)forGraph
{
    [super createNode:forGraph];
    
    //Create the input and output elements
    
    OSStatus err;
    UInt32 elementCount = 1;
    err = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &elementCount, sizeof(UInt32));
    if (err)
    {
        NSLog(@"Failed to set number of input elements on %@ with status %d", self, err);
    }
    
    err = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Output, 0, &elementCount, sizeof(UInt32));
    if (err)
    {
        NSLog(@"Failed to set number of output elements on %@ with status %d", self, err);
    }

    UInt32 enabled = 1;
    
    err = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0, &enabled, sizeof(enabled));
    
    return YES;
    
}


-(UInt32)inputElement
{
    return 0;
    //return [self getNextInputElement];
    
}


-(UInt32)outputElement
{
    return 0;
    //return [self getNextOutputElement];
}


/*
-(UInt32)getNextInputElement
{
    UInt32 elementCount = 0;
    UInt32 elementSize = sizeof(UInt32);
    
    UInt32 useElement = 0;
    
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &elementCount, &elementSize);
    
    UInt32 interactionCnt = 0;
    
    AUGraphCountNodeInteractions(self.graph.graphInst, self.node, &interactionCnt);
    AUNodeInteraction *interactions = malloc(sizeof(AUNodeInteraction)*interactionCnt);
    
    
    AUGraphGetNodeInteractions(self.graph.graphInst, self.node, &interactionCnt, interactions);
    
    useElement = 0;
    UInt32 seenIdx = 0;
    
    for (int i=0; i < interactionCnt; i++)
    {
        
        AUNodeInteraction iact = interactions[i];
        if (iact.nodeInteractionType == kAUNodeInteraction_Connection && iact.nodeInteraction.connection.destNode == self.node)
        {
            if (seenIdx != iact.nodeInteraction.connection.destInputNumber)
            {
                useElement = seenIdx;
                break;
            } else {
                seenIdx++;
                useElement = iact.nodeInteraction.connection.destInputNumber+1;
            }
            
        }
    }
    
    free(interactions);
    if (useElement >= elementCount)
    {
        elementCount += 64;
        NSDictionary *saveData = [self saveDataForPrivateRestore];
        AudioUnitUninitialize(self.audioUnit);
        [self setInputStreamFormat:self.graph.graphAsbd];
        [self setOutputStreamFormat:self.graph.graphAsbd];
        [self willInitializeNode];
        AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &elementCount, sizeof(elementCount));
        AudioUnitInitialize(self.audioUnit);
        [self didInitializeNode];
        [self restoreDataFromPrivateRestore:saveData];

    }
    
    [self setVolumeOnInputBus:useElement volume:1.0];
    return useElement;
}

-(UInt32)getNextOutputElement
{
    UInt32 elementCount = 0;
    UInt32 elementSize = sizeof(UInt32);
    
    UInt32 useElement = 0;
    
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Output, 0, &elementCount, &elementSize);
    
    UInt32 interactionCnt = 0;
    
    AUGraphCountNodeInteractions(self.graph.graphInst, self.node, &interactionCnt);
    AUNodeInteraction *interactions = malloc(sizeof(AUNodeInteraction)*interactionCnt);
    
    
    AUGraphGetNodeInteractions(self.graph.graphInst, self.node, &interactionCnt, interactions);
    
    useElement = 0;
    UInt32 seenIdx = 0;
    
    for (int i=0; i < interactionCnt; i++)
    {
        
        AUNodeInteraction iact = interactions[i];
        if (iact.nodeInteractionType == kAUNodeInteraction_Connection && iact.nodeInteraction.connection.sourceNode == self.node)
        {
            if (seenIdx != iact.nodeInteraction.connection.sourceOutputNumber)
            {
                useElement = seenIdx;
                break;
            } else {
                seenIdx++;
                useElement = iact.nodeInteraction.connection.sourceOutputNumber+1;
            }
            
        }
    }
    
    free(interactions);
    if (useElement >= elementCount)
    {
        elementCount += 64;
        NSDictionary *saveData = [self saveDataForPrivateRestore];
        AudioUnitUninitialize(self.audioUnit);
        [self setInputStreamFormat:self.graph.graphAsbd];
        [self setOutputStreamFormat:self.graph.graphAsbd];
        [self willInitializeNode];
        AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Output, 0, &elementCount, sizeof(elementCount));
        AudioUnitInitialize(self.audioUnit);
        [self didInitializeNode];
        [self restoreDataFromPrivateRestore:saveData];
    }
    
    [self setVolumeOnOutputBus:useElement volume:1.0];
    return useElement;
}

*/


-(void)willInitializeNode
{
    UInt32 elementCount = 65;
    
    OSStatus err = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,&elementCount, sizeof(UInt32));

    err = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Output, 0,&elementCount, sizeof(UInt32));
    
    err = AudioUnitSetParameter(self.audioUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, self.volume, 0);
    UInt32 enableVal = 1;
    
    
    AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0, &enableVal, sizeof(enableVal));
    
    
}


-(void)willConnectNode:(CAMultiAudioNode *)node inBus:(UInt32)inBus outBus:(UInt32)outBus
{
    AudioStreamBasicDescription nformat;
    AudioStreamBasicDescription sformat;
    UInt32 fsize = sizeof(nformat);
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, inBus, &sformat, &fsize);
    AudioUnitGetProperty(node.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, outBus, &nformat, &fsize);

}
-(void)setVolumeOnOutputBus:(UInt32)bus volume:(float)volume
{
    [self setVolumeForScope:kAudioUnitScope_Output onBus:bus volume:volume];
}

-(void)setVolumeOnOutput:(float)volume
{
    [self setVolumeForScope:kAudioUnitScope_Output onBus:0 volume:volume];
}


-(bool)setOutputStreamFormat:(AudioStreamBasicDescription *)format
{
    bool ret =     [super setOutputStreamFormat:format];

    self.outputChannelCount = format->mChannelsPerFrame;

    return ret;
}


-(bool)setInputStreamFormat:(AudioStreamBasicDescription *)format
{
    
    
    AudioStreamBasicDescription fCopy;
    
    
    memcpy(&fCopy, format, sizeof(fCopy));
    
    
    fCopy.mChannelsPerFrame = _inputChannels;
    
    
    return [super setInputStreamFormat:&fCopy];
}

-(void)setEnabled:(bool)enabled
{
    UInt32 elementCount = 0;
    UInt32 elementSize = sizeof(UInt32);
    
    
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Output, 0, &elementCount, &elementSize);
    
    for (UInt32 i = 0; i < elementCount; i++)
    {
        AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Enable, kAudioUnitScope_Output, i, enabled, 0);
    }
    
    [super setEnabled:enabled];
    
}


-(bool)enableInputBus:(UInt32)inputBus
{
    OSStatus err = AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Enable, kAudioUnitScope_Input, inputBus, 1, 0);
    if (err)
    {
        NSLog(@"Failed to enable input bus %d on %@ with status %d", inputBus, self, err);
        return NO;
    }
    
    return YES;
}

-(bool)enableOutputBus:(UInt32)outputBus
{
    OSStatus err = AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Enable, kAudioUnitScope_Output, outputBus, 1, 0);
    if (err)
    {
        NSLog(@"Failed to enable output bus %d on %@ with status %d", outputBus, self, err);
        return NO;
    }
    
    return YES;
}

-(bool)disableInputBus:(UInt32)inputBus
{
    OSStatus err = AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Enable, kAudioUnitScope_Input, inputBus, 0, 0);
    if (err)
    {
        NSLog(@"Failed to disable input bus %d on %@ with status %d", inputBus, self, err);
        return NO;
    }
    
    return YES;
}

-(bool)disableOutputBus:(UInt32)outputBus
{
    OSStatus err = AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Enable, kAudioUnitScope_Output, outputBus, 0, 0);
    if (err)
    {
        NSLog(@"Failed to disable output bus %d on %@ with status %d", outputBus, self, err);
        return NO;
    }
    
    return YES;
}

-(void)disconnectOutput:(CAMultiAudioNode *)outNode
{
    NSDictionary *outInfo = self.outputMap[outNode.nodeUID];
    if (outInfo)
    {
        NSNumber *outBus = outInfo[@"outBus"];
        for(NSString *inpUUID in self.inputMap)
        {
            NSDictionary *inpInfo = self.inputMap[inpUUID];
            NSNumber *inpBus = inpInfo[@"inBus"];
            [self disconnectInputBus:inpBus.unsignedIntValue fromOutputBus:outBus.unsignedIntValue];
            [self disableOutputBus:outBus.unsignedIntValue];
        }
    }
}


-(void)connectInputBus:(UInt32)inputBus toOutputBus:(UInt32)outputBus
{
    UInt32 inputChan = inputBus*_inputChannels;
    UInt32 outputChan = outputBus*_outputChannelCount;
    
    OSStatus err;
    
    for(UInt32 i = 0; i < _inputChannels; i++)
    {
        err = AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Input, inputChan+i, 1.0, 0);
        err = AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Output, outputChan+i, 1.0, 0);

        [self setVolume:1.0f forChannel:inputChan+i outChannel:outputChan+i];
    }
}


-(void)disconnectInputBus:(UInt32)inputBus fromOutputBus:(UInt32)outputBus
{
    UInt32 inputChan = inputBus*_inputChannels;
    UInt32 outputChan = outputBus*_outputChannelCount;
    
    for(UInt32 i = 0; i < _inputChannels; i++)
    {
        [self setVolume:0.0f forChannel:inputChan+i outChannel:outputChan+i];
    }
}


-(Float32)getVolumeforChannel:(UInt32)inChannel outChannel:(UInt32)outChannel
{
    UInt32 xElem = (inChannel << 16) | (outChannel & 0x0000FFFF);
    Float32 ret = 0.0f;
    
    OSStatus err = AudioUnitGetParameter(self.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Global, xElem, &ret);
    
    if (err)
    {
        NSLog(@"Failed to get crosspoint volume for channel %d -> %d  on %@ with status %d", inChannel, outChannel, self, err);
    }
 
    return ret;
    
}
-(void)setVolume:(float)volume forChannel:(UInt32)inChannel outChannel:(UInt32)outChannel
{
    UInt32 xElem = (inChannel << 16) | (outChannel);
    OSStatus err = AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Global, xElem, volume,0);
    if (err)
    {
        NSLog(@"Failed to set crosspoint volume for channel %d -> %d  on %@ with status %d", inChannel, outChannel, self, err);
    }
}


-(void)restoreData:(NSDictionary *)saveData
{
    UInt32 inputCount = [[saveData objectForKey:@"inputChannels"] unsignedIntValue];
    UInt32 outputCount = [[saveData objectForKey:@"outputChannels"] unsignedIntValue];
    NSData *data = [saveData objectForKey:@"data"];

    NSUInteger dataSize = data.length;
    
    if ((dataSize % sizeof(Float32)))
    {
        return;
    }
    
    
    Float32 *levels = malloc(dataSize);
    
    [data getBytes:levels length:dataSize];
    

    for (int ichan = 0; ichan < inputCount; ichan++)
    {
        if (ichan >= self.inputChannelCount)
        {
            break;
        }
        
        for (int ochan = 0; ochan < outputCount; ochan++)
        {

            if (ochan >= self.outputChannelCount)
            {
                break;
            }
            
            Float32 xpoint = levels[(ichan * (outputCount+1)) + ochan];
            [self setVolume:xpoint forChannel:ichan outChannel:ochan];
        }
    }
    if (levels)
    {
        free(levels);
    }
}

-(NSDictionary *)saveDataForPrivateRestore
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    UInt32 dimSize = sizeof(UInt32)*2;
    
    UInt32 matrixDims[2];
    
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_MatrixDimensions, kAudioUnitScope_Global, 0, matrixDims, &dimSize);
    
    
    UInt32 levelSize = ((matrixDims[0]+1)*(matrixDims[1]+1))*sizeof(Float32);
    
    
    Float32 *levelData = malloc(levelSize);
    
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_MatrixLevels, kAudioUnitScope_Global, 0, levelData, &levelSize);

    NSData *levels = [NSData dataWithBytesNoCopy:levelData length:levelSize freeWhenDone:YES];
    [ret setObject:levels forKey:@"data"];
    [ret setObject:@(matrixDims[0]) forKey:@"inputChannels"];
    [ret setObject:@(matrixDims[1]) forKey:@"outputChannels"];
    
    return ret;
}

-(void)restoreDataFromPrivateRestore:(NSDictionary *)saveData
{
    NSData *data = [saveData objectForKey:@"data"];
    NSNumber *inputChannels = [saveData objectForKey:@"inputChannels"];
    NSNumber *outputChannels = [saveData objectForKey:@"outputChannels"];
    NSUInteger dataSize = data.length;
    
    if ((dataSize % sizeof(Float32)))
    {
        return;
    }
    
    
    
    Float32 *levels = malloc(dataSize);

    [data getBytes:levels length:dataSize];

    //We have to manually set all the volumes because the input/output element count may have changed. If it did change, the matrix volume array from the old size doesn't work as a blob restore.
    
    UInt32 inpMax = inputChannels.unsignedIntValue+1;
    UInt32 outMax = outputChannels.unsignedIntValue+1;
    for (int inp = 0; inp < inpMax; inp++)
    {
        for (int outp = 0; outp < outMax; outp++)
        {
            Float32 level = *(levels+(inp*outMax)+outp);
            
            
            if (outp == outMax-1 && inp == inpMax-1)
            {
                //Global
                [self setVolume:level];
                
            } else if (outp == outMax-1) {
                AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Input, inp, level, 0);
            } else if (inp == inpMax-1) {
                AudioUnitSetParameter(self.audioUnit, kMatrixMixerParam_Volume, kAudioUnitScope_Output, outp, level, 0);
            } else {
                [self setVolume:level forChannel:inp outChannel:outp];
            }
        }
    }
    
    free(levels);
}


-(NSDictionary *)saveData
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    UInt32 levelSize = (self.inputChannelCount+1)*(self.outputChannelCount+1)*sizeof(Float32);

    Float32 *levelData = malloc(levelSize);
    
    //AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_MatrixLevels, kAudioUnitScope_Global, 0, levelData, &levelSize);
    
    for (int ichan = 0; ichan < self.inputChannelCount; ichan++)
    {
        for (int ochan = 0; ochan < self.outputChannelCount; ochan++)
        {
            levelData[(ichan * (self.outputChannelCount+1)) + ochan] = [self getVolumeforChannel:ichan outChannel:ochan];
        }
    }
    
    NSData *levels = [NSData dataWithBytesNoCopy:levelData length:levelSize freeWhenDone:YES];
    [ret setObject:@(self.inputChannelCount) forKey:@"inputChannels"];
    [ret setObject:@(self.outputChannelCount) forKey:@"outputChannels"];
    [ret setObject:levels forKey:@"data"];
    return ret;
}


-(Float32 *)getMixerVolumes
{
    
    Float32 *ret = malloc((self.inputChannelCount+1)*(self.outputChannelCount+1));
    UInt32 levelSize;
    
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_MatrixLevels, kAudioUnitScope_Global, 0, ret, &levelSize);
    
    return ret;
}



@end
