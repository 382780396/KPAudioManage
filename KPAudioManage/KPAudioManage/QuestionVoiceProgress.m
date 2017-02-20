//
//  WGradientProgress.m
//  WGradientProgressDemo
//
//  Created by zilin_weng on 15/7/19.
//  Copyright (c) 2015年 Weng-Zilin. All rights reserved.
//

#import "QuestionVoiceProgress.h"


@interface QuestionVoiceProgress ()

@property (nonatomic, strong) CAGradientLayer *gradLayer;

@property (nonatomic, strong) CAEmitterLayer *emitterLayer;

@property (nonatomic, strong) CALayer *mask;

@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, strong) UIView *parentView;

@end

@implementation QuestionVoiceProgress


#pragma mark -- public methods
-(void)startProgress{
    QuestionVoiceProgress *gradProg = [QuestionVoiceProgress sharedInstance];
    if (gradProg.progress == 0) {
        CGFloat progress  = 0;
        [gradProg setProgress:progress];
    }
    

    double delayInSeconds =  _timeLength / 100;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        CGFloat progress  = [gradProg progress] + (self.isPause?0:0.01f);
        [gradProg setProgress:progress];
        if (progress < 1.0) {
            [self startProgress];
        }
    });
}

-(void)setTimeLength:(CGFloat)timeLength{
    
    if (timeLength > 100) {
        _timeLength = (int)(timeLength / 100) * 60 + ((int)timeLength % 100);
    }else{
        _timeLength = timeLength;
    }
}

-(void)pause{
    self.hidden = YES;
}

-(void)resume{
    self.hidden = NO;

}

+ (QuestionVoiceProgress *)sharedInstance
{
    static QuestionVoiceProgress *s_instance  = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (s_instance == nil) {
            s_instance = [[QuestionVoiceProgress alloc] init];
            s_instance.progress = 0;
            s_instance.position = QuestionVoiceProgressPosDown;
//            [s_instance setupTimer];
            s_instance.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        }
    });
    return s_instance;
}

/**
 *  the main interface to show WGradientProgress obj, position is WProgressPosDown by default.
 *
 *  @param parentView which view to be attach
 */
- (void)showOnParent:(UIView *)parentView
{
    [self showOnParent:parentView position:QuestionVoiceProgressPosDown];
}

/**
 *  the main interface to show WGradientProgress obj
 *
 *  @param parentView which view to be attach
 *  @param pos        up or down
 */
- (void)showOnParent:(UIView *)parentView position:(QuestionVoiceProgressPos)pos
{
    self.position = pos;
    self.parentView = parentView;
    self.progress = 0.0f;
    self.isPause = NO;
    CGRect frame = [self decideTargetFrame:parentView];
    self.frame = frame;
    [parentView addSubview:self];
    self.userInteractionEnabled = NO;
    [self initBottomLayer];
//    [self startTimer];
}

/**
 *  the main interface to hide WGradientProgress obj
 */
- (void)hide
{
    [self pauseTimer];
    if ([self superview]) {
        [self removeFromSuperview];
    }
    self.progress = 1.0f;
    self.parentView = nil;
}

#pragma mark -- setter / getter
- (void)setProgress:(CGFloat)progress
{
    if (progress < 0) {
        progress = 0;
    }
    if (progress > 1) {
        progress = 1;
    }
    _progress = progress;
    CGFloat maskWidth = progress * self.frame.size.width;
    
    self.mask.frame = CGRectMake(0, 0, maskWidth, self.frame.size.height);
}


#pragma mark -- private methods

- (CGRect)decideTargetFrame:(UIView *)parentView
{
    CGRect frame = CGRectZero;
    //progress is on the down border of parentView
    if (self.position == QuestionVoiceProgressPosDown) {
        frame = CGRectMake(0, 0, parentView.frame.size.width, parentView.frame.size.height);
    } else if (self.position == QuestionVoiceProgressPosUp) {
        frame = CGRectMake(0, -1, parentView.frame.size.width, 1);
    }
    return frame;
}

- (void)initBottomLayer
{
    if (self.gradLayer == nil) {
        self.gradLayer = [CAGradientLayer layer];
        self.gradLayer.frame = self.bounds;
    }
    self.gradLayer.startPoint = CGPointMake(0, 1);
    self.gradLayer.endPoint = CGPointMake(1, 0.9);
    
    //create colors, important section
    NSMutableArray *colors = [NSMutableArray array];
    for (NSInteger deg = 0; deg < 10; deg ++) {
        UIColor *color;
        color = [UIColor colorWithWhite:1 alpha:deg * 0.07];
        [colors addObject:(id)[color CGColor]];
    }
    
    [self.gradLayer setColors:[NSArray arrayWithArray:colors]];
    self.mask = [CALayer layer];
    [self.mask setFrame:CGRectMake(-30, self.gradLayer.frame.origin.y,
                                   self.progress * self.frame.size.width, self.frame.size.height)];
    self.mask.borderColor = [[UIColor whiteColor] CGColor];
    self.mask.borderWidth = 30;
    [self.gradLayer setMask:self.mask];
    [self.layer addSublayer:self.gradLayer];
}

/**
 *  here I use timer to circularly move colors
 */
- (void)setupTimer
{
    CGFloat interval = 0.1;
    if (self.timer == nil) {
         self.timer = [NSTimer timerWithTimeInterval:interval target:self
                                            selector:@selector(timerFunc)
                                            userInfo:nil repeats:YES];
    }
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}


- (void)startTimer
{
    //start timer
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
    [self.timer setFireDate:[NSDate date]];
}

/**
 *  here we just pause timer, rather than stopping forever.
 *  NOTE: [timer invalidate] is not fit here.
 */
- (void)pauseTimer
{
    [self.timer setFireDate:[NSDate distantFuture]];
}

/**
 *  rearrange color array
 */
- (void)timerFunc
{
//    CAGradientLayer *gradLayer = self.gradLayer;
//    NSMutableArray *copyArray = [NSMutableArray arrayWithArray:[gradLayer colors]];
////    UIColor *lastColor = [copyArray lastObject];
////    [copyArray removeLastObject];
////    if (lastColor) {
////        [copyArray insertObject:lastColor atIndex:copyArray.count];
////    }
//    copyArray[0] = [UIColor whiteColor];
//    
//    [self.gradLayer setColors:copyArray];
}

@end
