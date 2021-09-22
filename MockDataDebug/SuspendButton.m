//
//  SuspendButton.m
//  webViewForHttps
//
//  Created by wujie on 16/6/12.
//  Copyright © 2016年 yinyong. All rights reserved.
//

#import "SuspendButton.h"
#include <sys/time.h>

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

static const NSInteger KPrefixItem_Tag = 200;

@interface SuspendButton()

@end

@implementation SuspendButton

- (instancetype)init{
    return [self initWithFrame:CGRectMake(0, 0, 30, 30)];
}

+ (instancetype)addDebugBtnWithTag:(NSUInteger)tag{
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    if (window.windowLevel != UIWindowLevelNormal)
    {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(window in windows)
        {
            if (window.windowLevel == UIWindowLevelNormal)
            break;
        }
    }
    UIView *view = [window viewWithTag:tag];
    if (view && [view isKindOfClass:[SuspendButton class]]) {
        [window bringSubviewToFront:view];
        return (SuspendButton*)view;
    }
    if (view) {return nil;}
    
    CGFloat kscreenWidth = [UIScreen mainScreen].bounds.size.width;
    CGRect frame = CGRectMake(kscreenWidth -110-100, 40, 30, 30);
    NSString *ptv = [[NSUserDefaults standardUserDefaults] objectForKey:@"suspend_last_pt"];
    if (ptv) {
        frame.origin = CGPointFromString(ptv);
    }
    SuspendButton *button = [[SuspendButton alloc] initWithFrame:frame];
    [button setTitle:@"debug" forState:UIControlStateNormal];
    button.backgroundColor = [UIColor greenColor];
    [window addSubview:button];
    button.tag = tag;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [window bringSubviewToFront:button];
    });
    return button;
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = frame.size.width * 0.5;
        self.alpha = 0.3;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveInTheScreen:)];
        [self addGestureRecognizer:pan];
        [self addTarget:self action:@selector(clicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)moveInTheScreen:(UIPanGestureRecognizer*)pan{
    
    NSAssert(self.superview, @"btn.superView cann't be nil");
    
    CGPoint pt = [pan locationInView:self.superview];
    self.center = pt;
    switch (pan.state) {
        case UIGestureRecognizerStateEnded:
            
            [self handleTheBtnToSideWith:pt];
            NSLog(@"pan end");
            break;
            
        case UIGestureRecognizerStateBegan:
            
            self.alpha = 1.0;
            break;
            
        default:
            break;
    }
}

- (void)handleTheBtnToSideWith:(CGPoint)lastPt{
    
    if (self.selected) {
        return;
    }
    
    CGPoint center = CGPointZero;
    
    if (CGRectContainsPoint(CGRectMake(0, 64, kScreenWidth * 0.5, kScreenHeight - 64 - 49), lastPt)) {
        center = CGPointMake(self.frame.size.width * 0.5, lastPt.y);
    }
    
    if (CGRectContainsPoint(CGRectMake(kScreenWidth * 0.5, 64, kScreenWidth * 0.5, kScreenHeight - 64 - 49), lastPt)) {
        center = CGPointMake(kScreenWidth - self.frame.size.width * 0.5, lastPt.y);
    }
    
    if (CGRectContainsPoint(CGRectMake(0, 0, kScreenWidth, 64), lastPt)) {
        center = CGPointMake(lastPt.x, self.frame.size.height * 0.5);
    }
    
    if (CGRectContainsPoint(CGRectMake(0, kScreenHeight - 49, kScreenWidth, 49), lastPt)) {
        center = CGPointMake(lastPt.x, kScreenHeight - self.frame.size.height * 0.5);
    }
    
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.center = center;
        self.alpha = 0.3;
    } completion:^(BOOL finished) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:NSStringFromCGPoint(self.frame.origin) forKey:@"suspend_last_pt"];
    }];
    
}

- (void)clicked:(UIButton*)btn{
    self.selected = !self.selected;
    if (self.selected) {
        [self configItems];
    }else{
        for (UIView *view in self.subviews) {
            view.hidden = YES;
        }
        [self handleTheBtnToSideWith:self.center];
    }
}

- (void)configItems{
    int count = 1;
    if (self.itemsData && self.itemsData.count > 0) {
        count = (int)self.itemsData.count + 1;
    }
    if (count == self.subviews.count) {
        for (UIView *view in self.subviews) {
            view.hidden = NO;
        }
        return;
    }
    
    float angle = 2 * M_PI / (count * 1.0);
    float radius = 100.0;
    CGFloat itemWidth = 50;
    for (int i = 0; i < count; i ++) {
        UIButton *btn = [self viewWithTag:KPrefixItem_Tag + i];
        if (!btn) {
            btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.tag = KPrefixItem_Tag + i;
            [self addSubview:btn];
            btn.layer.cornerRadius = itemWidth * 0.5;
            btn.layer.masksToBounds = YES;
            btn.backgroundColor = [UIColor colorWithRed:arc4random()%255 / 255.0 green:arc4random()%255/255.0 blue:arc4random()%255/255.0 alpha:arc4random()%255/255.0];
            btn.titleLabel.font = [UIFont systemFontOfSize:12];
            btn.titleLabel.numberOfLines = 0;
            btn.titleLabel.adjustsFontSizeToFitWidth = YES;
            [btn addTarget:self action:@selector(clickedItem:) forControlEvents:UIControlEventTouchUpInside];
            
            if (i == count - 1) {
                [btn setTitle:@"delete" forState:UIControlStateNormal];
            }else{
                YYItemData *data = [self.itemsData objectAtIndex:i];
                [btn setTitle:data.allKeys.firstObject forState:UIControlStateNormal];
            }
        }
        btn.frame = CGRectMake(radius * cos(angle * i) - itemWidth * 0.5 + self.bounds.size.width * 0.5, radius * sin(angle * i) - itemWidth * 0.5 + self.bounds.size.height * 0.5, itemWidth, itemWidth);
        btn.hidden = NO;
    }
}

- (void)clickedItem:(UIButton*)btn{
    NSInteger index = btn.tag - KPrefixItem_Tag;
    if (!self.itemsData || self.itemsData.count <= 0 || index >= self.itemsData.count) {
        [self removeFromSuperview];
        return;
    }
    YYItemData *data = [self.itemsData objectAtIndex:index];
    yyItemClicked block = data.allValues.firstObject;
    if (block) {
        block(btn);
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    UIView *view = [super hitTest:point withEvent:event];
    if (view == nil) {
        for (UIView *subView in self.subviews) {
            CGPoint pt = [subView convertPoint:point fromView:self];
            if (CGRectContainsPoint(subView.bounds, pt) && (!subView.hidden)) {
                view = subView;
                break;
            }
        }
    }
    return view;
}

@end

static uint64_t kTickTime = 0;
static uint64_t getCurrentTime(){
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000 + tv.tv_sec;
}
void startTickTime(void){
    kTickTime = getCurrentTime();
}

//char *cmd = (char*)malloc(sizeof(char) * (strlen(__func__) + 1));
//strcpy(cmd, __func__);
//stopTickTime(cmd);
//free(cmd);
void stopTickTime(char * cmd){
    uint64_t time = getCurrentTime();
    uint64_t costTime = time - kTickTime;
    NSLog(@"Statistical Time: %s cost : %lgms", cmd, costTime / 1000.0);
}
