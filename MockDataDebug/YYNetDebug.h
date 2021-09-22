//
//  YYNetDebug.h
//  MockDataDemo
//
//  Created by langwang on 16/9/2021.
//

#ifndef YYNetDebug_h
#define YYNetDebug_h

#import "SuspendButton.h"
#import "YYHTTPProtocol.h"
#import "NetMockManager.h"
#import "YYDebugFileBrowseView.h"

// 获取到debug文件夹中存储的文件，并通过列表形式展示出来，点击后，展示其中详情；
static void yy_showDebugFileView(){
    UIWindow *window = [[UIApplication sharedApplication] windows].firstObject;
    if (window.windowLevel != UIWindowLevelNormal)
    {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(window in windows)
        {
            if (window.windowLevel == UIWindowLevelNormal)
            break;
        }
    }
    if ([window viewWithTag:1001]) {
        [[window viewWithTag:1001] removeFromSuperview];
    }
    YYDebugFileBrowseView *browseView = [[YYDebugFileBrowseView alloc] initWithFrame:window.bounds];
    browseView.tag = 1001;
    [window addSubview:browseView];
    NSString *debugDirPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"debug"];
    browseView.fileDirectory = debugDirPath;
}


#endif /* YYNetDebug_h */
