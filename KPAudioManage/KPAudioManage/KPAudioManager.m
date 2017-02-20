//
//  KPAudioManager.m
//  TRZX
//
//  Created by 移动微 on 17/1/4.
//  Copyright © 2017年 Tiancaila. All rights reserved.
//

#import "KPAudioManager.h"
#import "QuestionVoiceProgress.h"
#import <AVFoundation/AVFoundation.h>
#import "AFNetworking.h"

#define BeginIgnoreDeprecatedWarning _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
#define EndIgnoreDeprecatedWarning _Pragma("clang diagnostic pop")

//NSString *const KPlayerEnd = @"KPlayerEnd";
NSString *const KPAudioLocalURL = @"KPAudioLocalURL";
NSString *const kKPAudioStartPlay = @"kKPAudioStartPlay";
@interface KPAudioManager ()<AVAudioRecorderDelegate,AVAudioPlayerDelegate>
///  音频录音机
@property(nonatomic, strong)AVAudioRecorder *audioRecorder;
///  音频播放器
@property(nonatomic, strong)AVAudioPlayer *audioPlayer;
///  录音声波监控 (注意这里暂时不对播放进行监控)
@property(nonatomic, strong)NSTimer *timer;
///  记录时间字符串
@property(nonatomic, copy)NSString *recordTimeStr;
///  记录时间
@property(nonatomic, assign)int recordTime;
///  音频播放开始Block
@property(nonatomic, copy) PlayingBlock playingBlock;
///  音频播放结束Block
@property(nonatomic, copy) PlayEndBlock playEndBlock;
///  监测语音输入力度
@property(nonatomic, copy) AudioPowerBlock audioPowerBlock;
///  音频录制结束
@property(nonatomic, copy) RecordEndBlock recordEndBlock;

@property(nonatomic, assign) BOOL isPlay;

@end

@implementation KPAudioManager

/**
 单例
 */
+(KPAudioManager *) sharedInstance{
    static KPAudioManager *instane;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instane = [[KPAudioManager alloc] init];
    });
    return instane;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkIsRecording) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - audio Recorder
///  音频录制开始
+(void) recordingStartAudioPower:(AudioPowerBlock)audioPower RecordEnd:(RecordEndBlock)recordEnd{
    [self sharedInstance].audioPowerBlock = audioPower;
    [self sharedInstance].recordEndBlock = recordEnd;
    [[self sharedInstance] recordingStart];
}
///  音频录制开始
-(void) recordingStart{
    _audioPlayer = nil;
    if ([self canRecord]) {
        if (![self.audioRecorder isRecording]) {
            self.audioRecorder = nil;
            self.recordTime = 0;
            AVAudioSession *audioSession = [AVAudioSession sharedInstance];
            [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
            [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
            [audioSession setActive:YES error:nil];
            //首次使用应用实践如果调用record方法会询问用户是否允许使用麦克风
            [self.audioRecorder record];
            self.timer.fireDate = [NSDate distantPast];
        }
    }
}

-(void)checkIsRecording{
    if ([self.audioRecorder isRecording]) {
        [self recordingStop];
    }
}

///  音频录制停止
+(void) recordingStop{
    [[self sharedInstance] recordingStop];
}
-(void) recordingStop{
    [self.audioRecorder stop];
    self.timer.fireDate = [NSDate distantFuture];
    if (self.recordEndBlock) {
        self.recordEndBlock(self.recordTimeStr);
    }
    self.recordTime = 0;
    [self audioStop];
}

/**
 重新录制
 */
+(void) recordingAgain{
    [[self sharedInstance] recordingAgain];
}
-(void) recordingAgain{
    //音频
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[self getSavePath].absoluteString]) {
        [fileManager removeItemAtPath:[self getSavePath].absoluteString error:nil];
    }
    self.recordTime = 0;
    [self.audioPlayer stop];
    [[QuestionVoiceProgress sharedInstance] hide];
    self.audioRecorder = nil;
    self.audioPlayer = nil;
}

/**
 录制音频的本地地址
 
 @return 本地音频路径
 */
+(NSString *)recordingLocalURL{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *audioLocalURL = [[KPAudioManager sharedInstance]getSavePath].absoluteString;
    if ([fileManager fileExistsAtPath:audioLocalURL]){
        return audioLocalURL;
    }
    return [[KPAudioManager sharedInstance]getSavePath].absoluteString;
}


#pragma mark - audioPlay 播放
/**
 暂停语音
 */
+(void) audioPause{
    [[self sharedInstance].audioPlayer pause];
    [QuestionVoiceProgress sharedInstance].isPause = YES;
}

/**
 恢复语音播放
 */
+(void) audioResume{
    [[NSNotificationCenter defaultCenter] postNotificationName:kKPAudioStartPlay object:nil];
    [[self sharedInstance].audioPlayer play];
    if ([self sharedInstance].playingBlock) {
        [self sharedInstance].playingBlock();
    }
    [QuestionVoiceProgress sharedInstance].isPause = NO;
}
/**
 音频播放
 
 @param url          URL地址     如果需要播放录制好的本地音频请传入:KPAudioLocalURL
 @param playingBlock 播放中Block
 */
+(void) audioPlayWithURL:(NSString *)url PlayingBlock:(PlayingBlock)playingBlock PlayEndBlock:(PlayEndBlock)playEndBlock{
//    [LCProgressHUD showLoading:@"正在加载"];   // 显示等待
    [[self sharedInstance] audioStop];
    [self sharedInstance].isPlay = YES;
    [self sharedInstance].playingBlock = playingBlock;
    [self sharedInstance].playEndBlock = playEndBlock;
    [[self sharedInstance] audioPlayWithURL:url];
}

/// 录制的音频播放
-(void)recordAudioPlay{
    [self audioStop];
    if (self.playingBlock) {
        self.playingBlock();
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory :AVAudioSessionCategoryPlayback error:nil];
        [self.audioPlayer play];
    });
}

////  语音播放
-(void) audioPlayWithURL:(NSString *)url {

//    [self audioStop];
    if(0 == url.length){
        return;
    }
    
    if ([url isEqualToString:KPAudioLocalURL]) {
//        [LCProgressHUD hide];
        [self recordAudioPlay];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        AFHTTPSessionManager *manger = [AFHTTPSessionManager manager];
        NSURLRequest *request = [NSURLRequest requestWithURL:[[NSURL alloc]initWithString:url] cachePolicy:1 timeoutInterval:30];
        
        [[manger downloadTaskWithRequest:request progress:NULL destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            
            _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:targetPath error:nil];
            _audioPlayer.delegate = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                AVAudioSession *session = [AVAudioSession sharedInstance];
                [session setCategory:AVAudioSessionCategoryPlayback error:nil];
//                [LCProgressHUD hide];
                if (self.isPlay == NO) {
                    return;
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:kKPAudioStartPlay object:nil];
                if (self.playingBlock) {
                    self.playingBlock();
                }
                [_audioPlayer play];
            });
            
            return NULL;
        } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        }] resume];
    });
}

/**
 停止语音播放
 */
+(void)audioStop{
    [[NSNotificationCenter defaultCenter] postNotificationName:kKPAudioStartPlay object:nil];
    [self sharedInstance].isPlay = NO;
    [[self sharedInstance] audioStop];
//    [LCProgressHUD hide];
}

-(void)audioStop{

    if (self.playEndBlock) {
        self.playEndBlock();
    }
//    if ([self.audioPlayer isPlaying]) {
    
    
    [self.audioPlayer stop];
//    [[QuestionVoiceProgress sharedInstance] hide];
//    }
}

#pragma mark - Properties
//// 获取录音机对象
///  @return 录音机对象
-(AVAudioRecorder *)audioRecorder{
    if (!_audioRecorder) {
        //创建录音机文件保存路径
        NSURL *url = [self getSavePath];
        //创建录音文件格式设置
        NSDictionary *setting = [self getAudioSetting];
        //创建录音机
        NSError *error = nil;
        _audioRecorder = [[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate = self;
        _audioRecorder.meteringEnabled = YES; //如果要监控声波则必须设置为YES
        if (error) {
            return nil;
        }
    }
    return _audioRecorder;
}

///  创建播放器
///  @return 播放器
-(AVAudioPlayer *)audioPlayer{
    if (!_audioPlayer) {
        NSURL *url = [self getSavePath];
        NSError *error = nil;
        _audioPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:&error];
        //播放循环次数
        _audioPlayer.numberOfLoops = 0;
        //准备播放
        _audioPlayer.delegate = self;
        [_audioPlayer prepareToPlay];
        if (error) {
            return nil;
        }
    }
    return _audioPlayer;
}


//判断是否允许使用麦克风7.0新增的方法requestRecordPermission
-(BOOL)canRecord{
    __block BOOL bCanRecord = YES;
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending)
    {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
            [audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
                if (granted) {
                    bCanRecord = YES;
                }
                else {
                    bCanRecord = NO;
                    BeginIgnoreDeprecatedWarning
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[[UIAlertView alloc] initWithTitle:nil
                                                    message:@"app需要访问您的麦克风。\n请启用麦克风-设置/隐私/麦克风"
                                                   delegate:nil
                                          cancelButtonTitle:@"关闭"
                                          otherButtonTitles:nil] show];
                        EndIgnoreDeprecatedWarning
                    });
                }
            }];
        }
    }
    return bCanRecord;
}

///  获取录音文件设置
///  @return 录音设置
-(NSDictionary *)getAudioSetting{
    //    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    //    //设置录音格式
    //    [dict setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    //    //设置录音采样率 , 8000 是电话采样率 , 对于一般的录音已经足够了
    //    [dict setObject:@(22000) forKey:AVSampleRateKey];
    //    //设置通道 , 这里采用单声道
    //    [dict setObject:@(1) forKey:AVNumberOfChannelsKey];
    //    //每个采样点位数, 分别是8、16、24、32
    //    [dict setObject:@(8) forKey:AVLinearPCMBitDepthKey];
    //    //是否使用浮点数采样
    //    [dict setObject:@(YES) forKey:AVLinearPCMIsFloatKey];
    //    //其他设置等 ....
    NSMutableDictionary* recordSetting = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                          [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                          [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
                                          [NSNumber numberWithInt:AVAudioQualityMin], AVEncoderAudioQualityKey,
                                          [NSNumber numberWithInt:AVAudioQualityMin], AVSampleRateConverterAudioQualityKey,
                                          [NSNumber numberWithInt:8], AVLinearPCMBitDepthKey,
                                          nil];
    return recordSetting;
}

///  获取录音文件保存路径
///  @return 录音文件路径
-(NSURL *)getSavePath{
    
    NSString *urlStr = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    
    urlStr = [urlStr stringByAppendingPathComponent:kRecordAudioFile];
    
    return [NSURL URLWithString:urlStr];
}

////  录音声波状态设置
-(void)audioPowerChange{
    //更新测量值
    [self.audioRecorder updateMeters];
    //取得第一个通道的音频 , 注意音频强度范围值是 -160到0 (0是最大输出)
    float power = [self.audioRecorder averagePowerForChannel:0];
    CGFloat progerss = (1.0/160.0) * (power + 160.0);
    if (self.audioPowerBlock) {
        self.audioPowerBlock(progerss,self.recordTimeStr);
    }
    
    self.recordTime++;
    
    if (self.audioRecorder.currentTime >= 180.0f) {
        //停止
        self.recordTimeStr = @"03:00";
        [self recordingStop];
    }
}

-(void)setRecordTime:(int)recordTime{
    _recordTime = recordTime;
    if (recordTime > 0) {
        int minute = recordTime/600.0;
        int second = recordTime % 600 / 10;
        NSString *timeStr = [NSString stringWithFormat:@"%02d:%02d",minute,second];
        self.recordTimeStr = timeStr;
    }else{
        self.recordTimeStr = @"00:00";
    }

}
///  录音声波监控定时器
///  @return 定时器
-(NSTimer *)timer{
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(audioPowerChange) userInfo:nil repeats:YES];
    }
    return _timer;
}

#pragma mark - AVAudioRecorderDelegate 录音机代理方法
///  录音播放完成
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    [self audioStop];
}
@end
