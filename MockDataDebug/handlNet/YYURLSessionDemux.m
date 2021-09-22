//
//  YYURLSessionDemux.m
//  testpod
//
//  Created by langwang on 2/4/2021.
//  Copyright © 2021 qufan. All rights reserved.
//

#import "YYURLSessionDemux.h"

@interface YYSessionTaskInfo : NSObject
@property (strong, atomic, readonly) NSURLSessionDataTask   *task;
@property (strong, atomic, readonly) id<NSURLSessionDataDelegate>  delegate;
@property (copy, atomic, readonly) NSArray  *modes;
@property (atomic, strong, readwrite) NSThread  *thread;

- (instancetype)initWithTask:(NSURLSessionDataTask *)task delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes;
- (void)performBlock:(dispatch_block_t)block;
- (void)invalidate;
@end

@implementation YYSessionTaskInfo

- (instancetype)initWithTask:(NSURLSessionDataTask *)task delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes{
    self = [super init];
    if (self) {
        self->_task = task;
        self->_delegate = delegate;
        self->_modes = [modes copy];
        self->_thread = [NSThread currentThread];
    }
    return self;
}

- (void)performBlock:(dispatch_block_t)block{
    assert(self.delegate != nil);
    assert(self.thread != nil);
    [self performSelector:@selector(performBlockOnClientThread:) onThread:self.thread withObject:[block copy] waitUntilDone:NO modes:self.modes];
}

- (void)performBlockOnClientThread:(dispatch_block_t)block{
    assert([NSThread currentThread] == self.thread);
    block();
}

- (void)invalidate{
    self->_delegate = nil;
    self->_task = nil;
}

@end

@interface YYURLSessionDemux() <NSURLSessionDataDelegate>
@property (atomic, strong, readonly) NSMutableDictionary  *taskInfoByTaskId;
@property (strong, atomic, readonly) NSURLSession  *session;
@end

@implementation YYURLSessionDemux

- (instancetype)init{
    self = [super init];
    if (self != nil) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:1];
        [queue setName:@"yy.debug.mux"];
        self->_session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:queue];
        self->_taskInfoByTaskId = [NSMutableDictionary dictionary];
        self->_debug_queue = dispatch_queue_create("debug_queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes{
    assert(request != nil);
    assert(delegate != nil);
    
    if ([modes count] == 0) {
        modes = @[NSDefaultRunLoopMode];
    }
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    assert(task != nil);
    YYSessionTaskInfo *taskInfo = [[YYSessionTaskInfo alloc] initWithTask:task delegate:delegate modes:modes];
    
    @synchronized (self) {
        self.taskInfoByTaskId[@(task.taskIdentifier)] = taskInfo;
    }
    
    return task;
}

- (YYSessionTaskInfo*)taskInfoForTask:(NSURLSessionTask*)task{
    YYSessionTaskInfo *info;
    @synchronized (self) {
        info = self.taskInfoByTaskId[@(task.taskIdentifier)];
    }
    assert(info != nil);
    return info;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)newRequest completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task willPerformHTTPRedirection:response newRequest:newRequest completionHandler:completionHandler];
        }];
    } else {
        completionHandler(newRequest);
    }
}


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
        }];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:needNewBodyStream:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task needNewBodyStream:completionHandler];
        }];
    } else {
        completionHandler(nil);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
        }];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:task];

    // This is our last delegate callback so we remove our task info record.
    
    @synchronized (self) {
        [self.taskInfoByTaskId removeObjectForKey:@(taskInfo.task.taskIdentifier)];
    }

    // Call the delegate if required.  In that case we invalidate the task info on the client thread
    // after calling the delegate, otherwise the client thread side of the -performBlock: code can
    // find itself with an invalidated task info.
    
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didCompleteWithError:error];
            [taskInfo invalidate];
        }];
    } else {
        [taskInfo invalidate];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
        }];
    } else {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didBecomeDownloadTask:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didBecomeDownloadTask:downloadTask];
        }];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didReceiveData:data];
        }];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler
{
    YYSessionTaskInfo *    taskInfo;
    
    taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:willCacheResponse:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
        }];
    } else {
        completionHandler(proposedResponse);
    }
}


@end
