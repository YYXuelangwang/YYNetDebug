//
//  NetMockManager.m
//  Pokio
//
//  Created by langwang on 13/7/2021.
//  Copyright © 2021 深圳趣凡网络科技有限公司. All rights reserved.
//

#import "NetMockManager.h"

static BOOL stringNotNil(NSString* str){
    if (str && str.length > 0) {
        return YES;
    }
    return NO;
}

@implementation YYPackedMockData
- (instancetype)initWithInterface:(NSString *)port param:(NSString *)param{
    if (self = [super init]) {
        _port = port;
        _param = param;
    }
    return self;
}
@end

@interface YYMockData : NSObject

/// key is interface, value is filterparams
@property (strong, nonatomic) NSDictionary  *ports;

/// use to check request'data if contain one element
@property (strong, nonatomic) NSArray<NSString*>  *singleParams;

/// use to check request'data if contain one element (the element in subArray must contained in the request'data)
@property (strong, nonatomic) NSArray<NSArray<NSString*>*>  *multiParams;
@end

@implementation YYMockData
@end

@interface NetMockManager()<NSURLSessionDelegate, NSURLSessionDataDelegate>
@property (strong, nonatomic) YYMockData  *mockedData;
@property (strong, nonatomic) NSOperationQueue  *queue;
@property (strong, nonatomic) NSMutableData  *data;
@property (strong, nonatomic) NSURLSessionDataTask  *task;
@property (assign, nonatomic) NSUInteger  tryTimes;
@end

@implementation NetMockManager
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static NetMockManager *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
        instance.queue = [[NSOperationQueue alloc] init];
        instance.tryTimes = 2;
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (void)requestMockedData{
    if (self.tryTimes <= 0) {return;}
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/mock_data", self.mockUrl]]]];
    self.task = task;
    [task resume];
    self.tryTimes--;
}

- (NSURLRequest*)whetherMockRequest:(NSURLRequest *)request result:(BOOL *)ret{
    
    *ret = NO;
    if (!self.mockedData) {return nil;}
    
    NSString *body = [self getHttpBodyFromRequest:request];
    NSString *path = request.URL.path;
    if (stringNotNil(path)) {path = [path substringFromIndex:1];}
    
    YYPackedMockData *mData = self.parseRequest ? self.parseRequest(request, path, body) : YYReturnPackedData(path, body);
    
    if (!mData) {
        return nil;
    }
    
    // check port/interface
    for (NSString *port in self.mockedData.ports.allKeys) {
        if ([port isEqualToString:mData.port]) {
            NSString *param = self.mockedData.ports[port];
            if (stringNotNil(param)) {
                
                *ret = [mData.param containsString:param];
                return *ret ? [self reChangedRequest:request port:mData.port param:mData.param] : nil;
            }
            
            *ret = YES;
            return [self reChangedRequest:request port:mData.port param:mData.param];
        }
    }
    
    // check single param
    for (NSString *param in self.mockedData.singleParams) {
        if ([mData.param containsString:param]) {
            
            *ret = YES;
            return [self reChangedRequest:request port:mData.port param:mData.param];
        }
    }
    
    // check multi params
    for (NSArray* array in self.mockedData.multiParams) {
        BOOL rett = YES;
        for (NSString *param in array) {
            if (![mData.param containsString:param]) {
                rett = NO;
                break;
            }
        }
        if (rett) {
            *ret = YES;
            return [self reChangedRequest:request port: mData.port param:mData.param];
            
        }
    }
    
    return nil;
}

- (NSURLRequest*)reChangedRequest:(NSURLRequest*)request port:(NSString*)port param:(NSString*)param{
    NSMutableString *url = [self.mockUrl mutableCopy];
    if (stringNotNil(port)) {
        if ([port hasPrefix:@"/"]) {
            [url appendString:port];
        }else{
            [url appendFormat:@"/%@", port];
        }
    }
    
    if (stringNotNil(param)) {
        static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
        static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";

        NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];

        [url appendFormat:@"?%@", [param stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet]];
    }
    
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
}

- (NSString*)getHttpBodyFromRequest:(NSURLRequest*)request{
    if ([request.HTTPMethod isEqualToString:@"GET"]) {
        
        NSString *url = request.URL.absoluteString;
        NSArray *array = [url componentsSeparatedByString:@"?"];
        return array.count > 1 ? array.lastObject : nil;
        
    }else if ([request.HTTPMethod isEqualToString:@"POST"]){
        if (request.HTTPBody) {
            return [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        }
        
        NSInputStream *stream = request.HTTPBodyStream;
        uint8_t d[1024] = {0};
        NSMutableData *data = [NSMutableData data];
        [stream open];
        while ([stream hasBytesAvailable]) {
            NSInteger len = [stream read:d maxLength:1024];
            if (len > 0 && stream.streamError == nil) {
                [data appendBytes:(void *)d length:len];
            }
        }
        NSData* httpBody = [data copy];
        [stream close];
        
        return [[NSString alloc] initWithData:httpBody encoding:NSUTF8StringEncoding];
    }
    return nil;
}

//MARK: - urlsessiondelegate | urlsessiondatadelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.data appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    self.task = nil;
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    
    NSError *parseError;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:self.data options:NSJSONReadingMutableContainers error:&parseError];
    if (parseError || !dic) {
        NSLog(@"%@", parseError);
        return;
    }
    
    self.mockedData = [[YYMockData alloc] init];
    self.mockedData.ports = dic[@"interfaces"];
    self.mockedData.singleParams = dic[@"singleParam"];
    self.mockedData.multiParams = dic[@"multiParam"];
    self.data = nil;
}

- (void)setMockUrl:(NSString *)mockUrl{
    _mockUrl = mockUrl;
    if (!self.mockedData && !self.task) {
        [self requestMockedData];
    }
}

//MARK: - getter
- (NSMutableData *)data{
    if (!_data) {
        _data = [NSMutableData data];
    }
    return _data;
}

@end
