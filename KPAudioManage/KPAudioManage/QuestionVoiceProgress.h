//
//  QuestionVoiceProgress.h
//  TRZX
//
//  Created by 移动微 on 16/7/27.
//  Copyright © 2016年 Tiancaila. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, QuestionVoiceProgressPos)
{
    QuestionVoiceProgressPosDown = 0,        //default, progress is on the down border of parent view
    QuestionVoiceProgressPosUp               //progress is on the up border of parent view
};

@interface QuestionVoiceProgress : UIView

@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, assign) QuestionVoiceProgressPos position;
@property (nonatomic, assign) CGFloat timeLength;
///  是否暂停 YES : 暂停  NO 恢复
@property (nonatomic, assign) BOOL isPause;

+ (QuestionVoiceProgress *)sharedInstance;

/**
 *  the main interface to show WGradientProgress obj, position is WProgressPosDown by default.
 *
 *  @param parentView which view to be attach
 */
- (void)showOnParent:(UIView *)parentView;

/**
 *  the main interface to show WGradientProgress obj
 *
 *  @param parentView which view to be attach
 *  @param pos        up or down
 */
- (void)showOnParent:(UIView *)parentView position:(QuestionVoiceProgressPos)pos;

/**
 *  the main interface to hide WGradientProgress obj
 */
- (void)hide;

-(void)startProgress;
//暂停显示
-(void)pause;
//恢复显示
-(void)resume;


@end
