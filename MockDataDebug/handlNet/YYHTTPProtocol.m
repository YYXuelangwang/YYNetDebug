//
//  TestHTTPProtocol.m
//  testpod
//
//  Created by langwang on 1/4/2021.
//  Copyright © 2021 qufan. All rights reserved.
//

#import "YYHTTPProtocol.h"
#import "YYURLSessionDemux.h"
#import "CanonicalRequest.h"
#import "YYFileManager.h"
#import "NetMockManager.h"

extern NSURLCacheStoragePolicy CacheStoragePolicyForRequestAndResponse1(NSURLRequest * request, NSHTTPURLResponse * response)
    // See comment in header.
{
    BOOL                        cacheable;
    NSURLCacheStoragePolicy     result;

    assert(request != NULL);
    assert(response != NULL);

    // First determine if the request is cacheable based on its status code.
    
    switch ([response statusCode]) {
        case 200:
        case 203:
        case 206:
        case 301:
        case 304:
        case 404:
        case 410: {
            cacheable = YES;
        } break;
        default: {
            cacheable = NO;
        } break;
    }

    // If the response might be cacheable, look at the "Cache-Control" header in
    // the response.

    // IMPORTANT: We can't rely on -rangeOfString: returning valid results if the target
    // string is nil, so we have to explicitly test for nil in the following two cases.
    
    if (cacheable) {
        NSString *  responseHeader;
        
        responseHeader = [[response allHeaderFields][@"Cache-Control"] lowercaseString];
        if ( (responseHeader != nil) && [responseHeader rangeOfString:@"no-store"].location != NSNotFound) {
            cacheable = NO;
        }
    }

    // If we still think it might be cacheable, look at the "Cache-Control" header in
    // the request.

    if (cacheable) {
        NSString *  requestHeader;

        requestHeader = [[request allHTTPHeaderFields][@"Cache-Control"] lowercaseString];
        if ( (requestHeader != nil)
          && ([requestHeader rangeOfString:@"no-store"].location != NSNotFound)
          && ([requestHeader rangeOfString:@"no-cache"].location != NSNotFound) ) {
            cacheable = NO;
        }
    }

    // Use the cacheable flag to determine the result.
    
    if (cacheable) {
    
        // This code only caches HTTPS data in memory.  This is inline with earlier versions of
        // iOS.  Modern versions of iOS use file protection to protect the cache, and thus are
        // happy to cache HTTPS on disk.  I've not made the correspondencing change because
        // it's nice to see all three cache policies in action.
    
        if ([[[[request URL] scheme] lowercaseString] isEqual:@"https"]) {
            result = NSURLCacheStorageAllowedInMemoryOnly;
        } else {
            result = NSURLCacheStorageAllowed;
        }
    } else {
        result = NSURLCacheStorageNotAllowed;
    }

    return result;
}


@interface YYHTTPProtocol()<NSURLSessionDataDelegate>
@property (atomic, strong, readwrite) NSURLSessionDataTask  *task;
@end

@implementation YYHTTPProtocol

+ (void)start{
    [NSURLProtocol registerClass:self];
}

+ (YYURLSessionDemux*)sharedMux{
    static dispatch_once_t onceToken;
    static YYURLSessionDemux *demux;
    dispatch_once(&onceToken, ^{
        demux = [[YYURLSessionDemux alloc] init];
    });
    return demux;
}

static NSString * kRecursiveRequestFlagProperty = @"com.pokio.customProtocol";
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{
    BOOL shouldAccept;
    NSURL *url;
    NSString *scheme;
    shouldAccept = (request != nil);
    if (shouldAccept) {
        url = [request URL];
        shouldAccept = (url != nil);
    }
    
    if (shouldAccept) {
        shouldAccept = ([self propertyForKey:kRecursiveRequestFlagProperty inRequest:request] == nil);
    }
    
    if (shouldAccept) {
        scheme = [[url scheme] lowercaseString];
        shouldAccept = (scheme != nil);
    }
    
    return shouldAccept;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id <NSURLProtocolClient>)client
{
    assert(request != nil);
    // cachedResponse may be nil
    assert(client != nil);
    // can be called on any thread

    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    if (self != nil) {
        // All we do here is log the call.
    }
    return self;
}


+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{
    NSURLRequest * result;
    result = CanonicalRequestForRequest(request);
    NSURLRequest *r = [self _mockDataFromServer:result];
    return r?r:result;
}

- (void)dealloc{
    assert(self->_task == nil);
}

- (void)startLoading{
    NSMutableURLRequest * recursiveRequest = [[self request] mutableCopy];
    NSMutableArray *calcutatedModes = [NSMutableArray array];
    [calcutatedModes addObject:NSDefaultRunLoopMode];
    NSString *currentMode = [[NSRunLoop currentRunLoop] currentMode];
    if (currentMode && ![currentMode isEqual:NSDefaultRunLoopMode]) {
        [calcutatedModes addObject:currentMode];
    }
    
    [[self class] setProperty:@YES forKey:kRecursiveRequestFlagProperty inRequest:recursiveRequest];
    
    self.task = [[[self class] sharedMux] dataTaskWithRequest:recursiveRequest delegate:self modes:calcutatedModes];
    assert(self.task != nil);
    
    [self storeDebugDataWithDataTask:self.request Data:nil Req:YES];
    [self.task resume];
}

- (void)stopLoading{
    if (self.task != nil) {
        [self.task cancel];
        self.task = nil;
    }
}

//MARK: - URLSessionDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler{
    NSMutableURLRequest *redirectRequest = [request mutableCopy];
    [[self class] removePropertyForKey:kRecursiveRequestFlagProperty inRequest:redirectRequest];
    [[self client] URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
    [self.task cancel];
    [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler{
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    NSURLCacheStoragePolicy cacheStoragePolicy;
    NSInteger statusCode;
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        cacheStoragePolicy = CacheStoragePolicyForRequestAndResponse1(self.task.originalRequest, (NSHTTPURLResponse *) response);
        statusCode = [(NSHTTPURLResponse *)response statusCode];
    }else{
        cacheStoragePolicy = NSURLCacheStorageAllowed;
        statusCode = 42;
    }
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:cacheStoragePolicy];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self storeDebugDataWithDataTask:dataTask.originalRequest Data:data Req:NO];
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler{
    completionHandler(proposedResponse);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error == nil) {
        [[self client] URLProtocolDidFinishLoading:self];
    } else if ( [[error domain] isEqual:NSURLErrorDomain] && ([error code] == NSURLErrorCancelled) ) {
        // Do nothing.  This happens in two cases:
        //
        // o during a redirect, in which case the redirect code has already told the client about
        //   the failure
        //
        // o if the request is cancelled by a call to -stopLoading, in which case the client doesn't
        //   want to know about the failure
    } else {
        [[self client] URLProtocol:self didFailWithError:error];
    }
    [self storeDebugDataWithDataTask:task.originalRequest Data:[error.description dataUsingEncoding:NSUTF8StringEncoding] Req:NO];
}

//MARK: - debug file

- (void)storeDebugDataWithDataTask:(NSURLRequest *)request Data:(NSData *)data Req:(BOOL)req{
    NSURLRequest *newRequest = [request mutableCopy];
    dispatch_async([[self class] sharedMux].debug_queue, ^{
        NSMutableData *mData = [NSMutableData data];
        if (req) {
            if ([request.HTTPMethod isEqualToString:@"GET"]) {
                NSString *str = [NSString stringWithFormat:@"=======req:\n%@", request.URL];
                [[YYFileManager standardDefault] writeDebugString:str];
            }else{
                NSData *reqData = newRequest.HTTPBody;
                if (reqData) {
                    [mData appendData:[@"=======req:\n" dataUsingEncoding:NSUTF8StringEncoding]];
                    [mData appendData:reqData];
                    [[YYFileManager standardDefault] writeDebugData:mData];
                }else{
                    [[YYFileManager standardDefault] writeInputStream:newRequest.HTTPBodyStream];
                }
            }
        }else{
            [mData appendData:[@"\n======rep:\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [mData appendData:data];
            [mData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [[YYFileManager standardDefault] writeDebugData:mData];
        }
    });
}

+ (NSURLRequest *)_mockDataFromServer:(NSURLRequest *)request{
    if (![NetMockManager sharedInstance].mockUrl) {return nil;}
    
    BOOL ret;
    return [[NetMockManager sharedInstance] whetherMockRequest:request result:&ret];
    
}

@end
