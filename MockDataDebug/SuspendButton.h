//
//  SuspendButton.h
//  webViewForHttps
//
//  Created by wujie on 16/6/12.
//  Copyright © 2016年 yinyong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "YYDebugFile.h"

@interface SuspendButton : UIButton
@property (strong, nonatomic) NSArray<YYItemData*> *itemsData;
+ (instancetype)addDebugBtnWithTag:(NSUInteger)tag;
@end

#ifdef __cplusplus
extern "C" {
#endif //__cplusplus
void startTickTime(void);
void stopTickTime(char * cmd);
#ifdef __cplusplus
}
#endif //__cplusplus
