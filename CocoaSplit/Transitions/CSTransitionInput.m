//
//  CSTransitionInput.m
//  CocoaSplit
//
//  Created by Zakk on 3/27/18.
//

#import "CSTransitionInput.h"
#import "CSInputLayoutTransitionViewController.h"

@implementation CSTransitionInput
@synthesize holdDuration = _holdDuration;
    @synthesize inputSource = _inputSource;
    
    -(instancetype) init
    {
        if (self = [super init])
        {
            self.transitionAfterPre = YES;
        }
        return self;
    }
    
-(id)copyWithZone:(NSZone *)zone
{
    CSTransitionInput *newObj = [super copyWithZone:zone];
    if (newObj)
    {
        newObj.configuredInputSource = self.configuredInputSource;
        newObj.inputSourceSavedata = self.inputSourceSavedata;
        newObj.holdDuration = self.holdDuration;
        newObj.waitForMedia = self.waitForMedia;
        newObj.transitionAfterPre = self.transitionAfterPre;
    }
    return newObj;
}


-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    if (self.inputSource)
    {
        
        self.inputSourceSavedata = [NSKeyedArchiver archivedDataWithRootObject:self.inputSource];
        
        [aCoder encodeObject:self.inputSourceSavedata forKey:@"inputSourceSavedata"];
    }
    [aCoder encodeObject:self.holdDuration forKey:@"holdDuration"];
    [aCoder encodeBool:self.waitForMedia forKey:@"waitForMedia"];
    [aCoder encodeBool:self.transitionAfterPre forKey:@"transitionAfterPre"];
}


-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        self.inputSourceSavedata = [aDecoder decodeObjectForKey:@"inputSourceSavedata"];
        self.holdDuration = [aDecoder decodeObjectForKey:@"holdDuration"];
        if ([aDecoder containsValueForKey:@"waitForMedia"])
        {
            self.waitForMedia = [aDecoder decodeBoolForKey:@"waitForMedia"];
        }
        
        if ([aDecoder containsValueForKey:@"transitionAfterPre"])
        {
            self.transitionAfterPre = [aDecoder decodeBoolForKey:@"transitionAfterPre"];
        }
    }
    
    return self;
}

+(NSArray *)subTypes
{
    return @[];
}

-(bool)usesPreTransitions
{
    return YES;
}

-(bool)usesPostTransitions
{
    return YES;
}

+(NSString *)transitionCategory
{
    return @"Source";
}


-(NSString *)name
{
    
    NSString *ret = [super name];
    if (!ret && self.inputSource)
    {
        ret = self.inputSource.name;
    }
    return ret;
}

-(void)setInputSource:(NSObject<CSInputSourceProtocol> *)inputSource
{
    _inputSource = inputSource;
    if (inputSource && inputSource.isVideo)
    {
        [(InputSource *)inputSource frameTick];
        [(InputSource *)inputSource autoSize];

        
    }
}
    
    
    
-(NSObject<CSInputSourceProtocol> *)inputSource
{
    if (!_inputSource)
    {
        _inputSource = [self restoreInputSource];
        if (!_inputSource)
        {
            _inputSource = [self getInputSource];
        }
    }
    return _inputSource;
}
    
    
-(void)setHoldDuration:(NSNumber *)holdDuration
{
    _holdDuration = holdDuration;
}

    
    
-(NSObject <CSInputSourceProtocol> *)getInputSource
{
    return self.configuredInputSource;
}

    
-(NSNumber *)holdDuration
{
    if (_holdDuration)
    {
        return _holdDuration;
    }
    
    return self.duration;
}

-(NSString *)preChangeAction:(SourceLayout *)targetLayout
{

    if (!self.inputSource)
    {
        return nil;
    }
    
    self.inputSource.persistent = YES;
    if (self.inputSource.isVideo)
    {
        //[(InputSource *)self.inputSource autoCenter];
    }

    NSMutableString *scriptRet = [NSMutableString string];
    [scriptRet appendString:@"var usePreTrans = null;"];
    if (self.preTransition)
    {
        [scriptRet appendString:@"var actionScript = self.preTransition.preReplaceAction();"];
        [scriptRet appendString:@"if (actionScript) {var prelTrans = (new Function('self', actionScript))(self.preTransition); if (prelTrans) { usePreTrans = prelTrans.transition;} }"];
        [scriptRet appendString:@"self.realPreTransition = usePreTrans;"];
    }
    
    [scriptRet appendString:@"var transitionCSInput = addInputToLayoutForTransition(self.inputSource, self.realPreTransition);"];
    
    if (self.preTransition)
    {
        [scriptRet appendString:@"var postPreScript = self.preTransition.postReplaceAction();"];
        [scriptRet appendString:@"if (postPreScript) { (new Function('self', postPreScript))(self.preTransition);}"];
    }
    
    
    if (self.waitForMedia)
    {
        [scriptRet appendString:@"transitionCSInput.waitAnimation(self.inputSource.duration);"];
    }
    self.realHoldDuration = self.holdDuration.floatValue;
    
    if (self.realHoldDuration > 0.0f)
    {
        [scriptRet appendString:@"transitionCSInput.waitAnimation(self.realHoldDuration);"];
    }

    if (self.transitionAfterPre)
    {
        [scriptRet appendString:@"waitAnimation();"];
    }
    return scriptRet;
}


-(NSString *)postChangeAction:(SourceLayout *)targetLayout
{
    
    NSMutableString *scriptRet = [NSMutableString string];
    [scriptRet appendString:@"var usePostTrans = null;"];
    
    if (self.postTransition)
    {
        [scriptRet appendString:@"var actionScript = self.postTransition.preRemoveAction();"];
        [scriptRet appendString:@"if (actionScript) {var prerTrans = (new Function('self', actionScript))(self.postTransition); if (prerTrans) { usePostTrans = prerTrans.transition;} }"];
        [scriptRet appendString:@"self.realPostTransition = usePostTrans;"];
    }
    [scriptRet appendString:@"removeInputFromLayout(self.inputSource, self.realPostTransition);"];
    if (self.postTransition)
    {
        [scriptRet appendString:@"var postPostScript = self.postTransition.postRemoveAction();"];
        [scriptRet appendString:@"if (postPostScript) { (new Function('self', postPostScript))(self.postTransition);}"];
    }
    
    //[scriptRet appendString:@"self.inputSource = null;"];
    return scriptRet;
}

    -(NSObject<CSInputSourceProtocol> *)restoreInputSource
    {
        NSObject<CSInputSourceProtocol> *ret = nil;
        if (self.inputSourceSavedata)
        {
            ret = [NSKeyedUnarchiver unarchiveObjectWithData:self.inputSourceSavedata];
        }
        return ret;
    }

    -(NSViewController<CSLayoutTransitionViewProtocol> *)configurationViewController
    {
        CSInputLayoutTransitionViewController *vc = [[CSInputLayoutTransitionViewController alloc] init];
        vc.transition = self;
        return vc;
    }
@end
