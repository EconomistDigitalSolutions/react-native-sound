#import "RNSound.h"

#if __has_include("RCTUtils.h")
#import "RCTUtils.h"
#else
#import <React/RCTUtils.h>
#endif

static void * const PlayerItemKVOContext = (void*)&PlayerItemKVOContext;

@implementation RNSound {
    NSMutableDictionary* _playerPool;
    NSMutableDictionary* _callbackPool;
    NSMutableDictionary* _prepareCallbackPool;
}

@synthesize _key = _key;

- (void)audioSessionChangeObserver:(NSNotification *)notification{
    NSDictionary* userInfo = notification.userInfo;
    
    AVAudioSessionRouteChangeReason audioSessionRouteChangeReason = [userInfo[AVAudioSessionRouteChangeReasonKey] longValue];
    
    AVPlayer* player = [self playerForKey:self._key];
    if (audioSessionRouteChangeReason == AVAudioSessionRouteChangeReasonNewDeviceAvailable){
        if (player) {
            [player play];
        }
    }
    
    if (audioSessionRouteChangeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable){
        if (player) {
            [player pause];
        }
    }
}

- (void)handleInterruption:(NSNotification *)notification
{
    NSDictionary* userInfo = notification.userInfo;
    
    AVAudioSessionInterruptionType audioSessionInterruptionType   = [userInfo[AVAudioSessionInterruptionTypeKey] longValue];
    AVPlayer* player = [self playerForKey:self._key];
    
    if (audioSessionInterruptionType == AVAudioSessionInterruptionTypeEnded){
        NSUInteger option = [userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        
        if (player && (option == AVAudioSessionInterruptionOptionShouldResume)) {
            [player play];
        }
    }
    
    if (audioSessionInterruptionType == AVAudioSessionInterruptionTypeBegan){
        if (player) {
            [player pause];
        }
    }
}

-(NSMutableDictionary*) playerPool {
    if (!_playerPool) {
        _playerPool = [NSMutableDictionary new];
    }
    return _playerPool;
}

-(NSMutableDictionary*) callbackPool {
    if (!_callbackPool) {
        _callbackPool = [NSMutableDictionary new];
    }
    return _callbackPool;
}

-(NSMutableDictionary*) prepareCallbackPool {
    if (!_prepareCallbackPool) {
        _prepareCallbackPool = [NSMutableDictionary new];
    }
    return _prepareCallbackPool;
}

-(AVPlayer*) playerForKey:(nonnull NSNumber*)key {
    return [[self playerPool] objectForKey:key];
}

-(NSNumber*) keyForPlayer:(nonnull AVPlayer*)player {
    return [[[self playerPool] allKeysForObject:player] firstObject];
}

- (NSNumber *)keyForPlayerWithItem:(nonnull AVPlayerItem *)playerItem
{
    AVPlayer *player = nil;
    for (AVPlayer *p in [[self playerPool] allValues]) {
        if ([p.currentItem isEqual:playerItem]) {
            player = p;
            break;
        }
    }
    
    return [self keyForPlayer:player];
}

-(RCTResponseSenderBlock) callbackForKey:(nonnull NSNumber*)key {
    return [[self callbackPool] objectForKey:key];
}

- (RCTResponseSenderBlock)prepareCallbackForKey:( nonnull NSNumber *)key {
    return [[self prepareCallbackPool] objectForKey:key];
}

-(NSString *) getDirectory:(int)directory {
    return [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) firstObject];
}

-(void) audioPlayerDidFinishPlayingItem:(AVPlayerItem *)playerItem
                           successfully:(BOOL)flag {
    
    NSNumber* key = [self keyForPlayerWithItem:playerItem];
    if (key == nil) return;
    
    @synchronized(key) {
        [self setOnPlay:NO forPlayerKey:key];
        RCTResponseSenderBlock callback = [self callbackForKey:key];
        if (callback) {
            callback(@[@(flag)]);
            [[self callbackPool] removeObjectForKey:key];
        }
    }
}

- (void)audioPlayerItemDidFinishPlaying:(NSNotification *)notification
{
    [self audioPlayerDidFinishPlayingItem:notification.object successfully:YES];
}

- (void)audioPlayerItemFailedToPlayToEndTime:(NSNotification *)notification
{
    [self audioPlayerDidFinishPlayingItem:notification.object successfully:NO];
}

RCT_EXPORT_MODULE();

-(NSArray<NSString *> *)supportedEvents
{
    return @[@"onPlayChange"];
}

-(NSDictionary *)constantsToExport {
    return @{@"IsAndroid": [NSNumber numberWithBool:NO],
             @"MainBundlePath": [[NSBundle mainBundle] bundlePath],
             @"NSDocumentDirectory": [self getDirectory:NSDocumentDirectory],
             @"NSLibraryDirectory": [self getDirectory:NSLibraryDirectory],
             @"NSCachesDirectory": [self getDirectory:NSCachesDirectory],
             };
}

RCT_EXPORT_METHOD(enable:(BOOL)enabled) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory: AVAudioSessionCategoryAmbient error: nil];
    [session setActive: enabled error: nil];
}

RCT_EXPORT_METHOD(setActive:(BOOL)active) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive: active error: nil];
}

RCT_EXPORT_METHOD(setMode:(NSString *)modeName) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSString *mode = nil;
    
    if ([modeName isEqual: @"Default"]) {
        mode = AVAudioSessionModeDefault;
    } else if ([modeName isEqual: @"VoiceChat"]) {
        mode = AVAudioSessionModeVoiceChat;
    } else if ([modeName isEqual: @"VideoChat"]) {
        mode = AVAudioSessionModeVideoChat;
    } else if ([modeName isEqual: @"GameChat"]) {
        mode = AVAudioSessionModeGameChat;
    } else if ([modeName isEqual: @"VideoRecording"]) {
        mode = AVAudioSessionModeVideoRecording;
    } else if ([modeName isEqual: @"Measurement"]) {
        mode = AVAudioSessionModeMeasurement;
    } else if ([modeName isEqual: @"MoviePlayback"]) {
        mode = AVAudioSessionModeMoviePlayback;
    } else if ([modeName isEqual: @"SpokenAudio"]) {
        mode = AVAudioSessionModeSpokenAudio;
    }
    
    if (mode) {
        [session setMode: mode error: nil];
    }
}

RCT_EXPORT_METHOD(setCategory:(NSString *)categoryName
                  mixWithOthers:(BOOL)mixWithOthers) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSString *category = nil;
    
    if ([categoryName isEqual: @"Ambient"]) {
        category = AVAudioSessionCategoryAmbient;
    } else if ([categoryName isEqual: @"SoloAmbient"]) {
        category = AVAudioSessionCategorySoloAmbient;
    } else if ([categoryName isEqual: @"Playback"]) {
        category = AVAudioSessionCategoryPlayback;
    } else if ([categoryName isEqual: @"Record"]) {
        category = AVAudioSessionCategoryRecord;
    } else if ([categoryName isEqual: @"PlayAndRecord"]) {
        category = AVAudioSessionCategoryPlayAndRecord;
    }
#if TARGET_OS_IOS
    else if ([categoryName isEqual: @"AudioProcessing"]) {
        category = AVAudioSessionCategoryAudioProcessing;
    }
#endif
    else if ([categoryName isEqual: @"MultiRoute"]) {
        category = AVAudioSessionCategoryMultiRoute;
    }
    
    if (category) {
        if (mixWithOthers) {
            [session setCategory: category withOptions:AVAudioSessionCategoryOptionMixWithOthers error: nil];
        } else {
            [session setCategory: category error: nil];
        }
    }
}

RCT_EXPORT_METHOD(enableInSilenceMode:(BOOL)enabled) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory: AVAudioSessionCategoryPlayback error: nil];
    [session setActive: enabled error: nil];
}

RCT_EXPORT_METHOD(prepare:(NSString*)fileName
                  withKey:(nonnull NSNumber*)key
                  withOptions:(NSDictionary*)options
                  withCallback:(RCTResponseSenderBlock)callback) {
    NSError* error;
    NSURL* fileNameUrl = [NSURL URLWithString:fileName];
    AVAsset *asset = [AVAsset assetWithURL:fileNameUrl];
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:asset automaticallyLoadedAssetKeys:@[@"duration"]];
    
    NSKeyValueObservingOptions observingOptions = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
    [playerItem addObserver:self forKeyPath:@"status" options:options context:PlayerItemKVOContext];
    
    AVPlayer* player = nil;
    if (fileNameUrl) {
        player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
    }
    
    if (player) {
        [[self playerPool] setObject:player forKey:key];
        [[self prepareCallbackPool] setObject:[callback copy] forKey:@([playerItem hash])];
    } else {
        callback(@[RCTJSErrorFromNSError(error)]);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context != PlayerItemKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        AVPlayerItemStatus status = playerItem.status;
        
        NSNumber *key = @([playerItem hash]);
        RCTResponseSenderBlock callback = [self prepareCallbackForKey:key];
        
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:
            {
                NSDictionary *response = @{@"duration": [self dictionaryValueForCMTime:playerItem.duration],
                                           @"numberOfChannels": @(0)};
                
                if (callback) {
                    callback(@[[NSNull null], response]);
                }
                
                [[self prepareCallbackPool] removeObjectForKey:key];
                [playerItem removeObserver:self forKeyPath:@"status" context:PlayerItemKVOContext];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerItemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerItemFailedToPlayToEndTime:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
                
            }
                break;
            case AVPlayerItemStatusFailed:
            {
                NSError *itemError = playerItem.error;
                callback(@[RCTJSErrorFromNSError([NSError errorWithDomain:itemError.domain code:itemError.code userInfo:nil])]);
                [[self prepareCallbackPool] removeObjectForKey:key];
                [playerItem removeObserver:self forKeyPath:@"status" context:PlayerItemKVOContext];
            }
                break;
            case AVPlayerItemStatusUnknown:
                // not ready
                break;
        }
    }
}

RCT_EXPORT_METHOD(play:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionChangeObserver:) name:AVAudioSessionRouteChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
    self._key = key;
    AVPlayer* player = [self playerForKey:key];
    if (player) {
        [[self callbackPool] setObject:[callback copy] forKey:key];
        [player play];
        [self setOnPlay:YES forPlayerKey:key];
    }
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:key];
    if (player) {
        [player pause];
        callback(@[]);
    }
}

RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:key];
    if (player) {
        [player pause];
        [player seekToTime:CMTimeMakeWithSeconds(0, NSEC_PER_SEC)];
        callback(@[]);
    }
}

RCT_EXPORT_METHOD(release:(nonnull NSNumber*)key) {
    AVPlayer* player = [self playerForKey:key];
    if (player) {
        [player pause];
        [[self callbackPool] removeObjectForKey:player];
        [[self playerPool] removeObjectForKey:key];
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter removeObserver:self];
    }
}

RCT_EXPORT_METHOD(setVolume:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
    AVPlayer* player = [self playerForKey:key];
    if (player) {
        player.volume = [value floatValue];
    }
}

RCT_EXPORT_METHOD(setPan:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
    // TODO:
    //    AVPlayer* player = [self playerForKey:key];
    
    
}

RCT_EXPORT_METHOD(setNumberOfLoops:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
    // TODO:
    //  AVAudioPlayer* player = [self playerForKey:key];
}

RCT_EXPORT_METHOD(setSpeed:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
    AVPlayer* player = [self playerForKey:key];
    if (player) {
        player.rate = [value floatValue];
    }
}


RCT_EXPORT_METHOD(setCurrentTime:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
    AVPlayer* player = [self playerForKey:key];
    if (player) {
        [player seekToTime:CMTimeMakeWithSeconds([value floatValue], NSEC_PER_SEC)];
    }
}

RCT_EXPORT_METHOD(getCurrentTime:(nonnull NSNumber*)key
                  withCallback:(RCTResponseSenderBlock)callback) {
    AVPlayer* player = [self playerForKey:key];
    if (player) {
        callback(@[[self dictionaryValueForCMTime:player.currentItem.currentTime], @(player.timeControlStatus == AVPlayerTimeControlStatusPlaying)]);
    } else {
        callback(@[@(-1), @(false)]);
    }
}

- (id)dictionaryValueForCMTime:(CMTime)time
{
    Float64 seconds = CMTimeGetSeconds(time);
    
    if (isnan(seconds) || isinf(seconds)) {
        return [NSNull null];
    }
    
    return @(seconds);
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}
- (void)setOnPlay:(BOOL)isPlaying forPlayerKey:(nonnull NSNumber*)playerKey {
    [self sendEventWithName:@"onPlayChange" body:@{@"isPlaying": isPlaying ? @YES : @NO, @"playerKey": playerKey}];
}
@end
