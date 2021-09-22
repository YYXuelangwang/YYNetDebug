//
//  YYURLSessionDemux.h
//  testpod
//
//  Created by langwang on 2/4/2021.
//  Copyright © 2021 qufan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YYURLSessionDemux : NSObject
@property (strong, atomic) dispatch_queue_t  debug_queue;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes;
@end

NS_ASSUME_NONNULL_END
