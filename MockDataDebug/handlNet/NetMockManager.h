//
//  NetMockManager.h
//  Pokio
//
//  Created by langwang on 13/7/2021.
//  Copyright © 2021 深圳趣凡网络科技有限公司. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define YYReturnPackedData(a, b) [[YYPackedMockData alloc] initWithInterface:(a) param:(b)]

@interface YYPackedMockData : NSObject

/// 请求的接口，比如:htttp://www.baidu.com/mock_data中的mock_data
@property (strong, nonatomic) NSString  *port;

/// 请求的参数，访问本地服务器请求中携带的参数
@property (strong, nonatomic) NSString  *param;
- (instancetype)initWithInterface:(NSString*)port param:(NSString*)param;
@end

@interface NetMockManager : NSObject

/// mock的服务器地址，一般都是本地电脑的ip地址加脚本中的端口号，比如:http://192.168.100.31:8085
@property (strong, nonatomic) NSString  *mockUrl;

/// 自定义你的数据解析；
/// block中各参数释义：reqeust，访问的请求；interface，访问的接口，比如:htttp://www.baidu.com/mock_data中的mock_data；param，请求的参数，支持get和post，拿到对应的参数数据；
@property (copy, nonatomic) YYPackedMockData* (^parseRequest)(NSURLRequest* request, NSString* interface, NSString* param);

/// 是否是需要mock的接口请求，如果是，会替换为访问到mock服务器后的请求；如果不是，返回nil；
/// @param request 正在访问的请求
/// @param ret 结果
- (NSURLRequest*)whetherMockRequest:(NSURLRequest *)request result:(BOOL *)ret;
+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
