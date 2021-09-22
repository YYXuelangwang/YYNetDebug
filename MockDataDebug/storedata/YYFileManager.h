//
//  YYFileManager.h
//  testdebug
//
//  Created by langwang on 22/4/2020.
//  Copyright © 2020 qufan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 YYFileManager will help you write you debug string to your local file.
 By default this class creates the file 'debug_net_ios.txt' in the 'document/debug' directory.
 Of course, you can also specify the file storage address by calling the method '-initWithFilePath',
 */
@interface YYFileManager : NSObject
@property (strong, nonatomic, readonly) NSString  *filePath;
+ (instancetype)standardDefault;
- (instancetype)initWithFilePath:(NSString*)filePath;
+ (void)clearFileContentWithFilePath:(NSString *)filePath;
- (void)writeDebugString:(NSString*)content;
- (void)writeDebugData:(NSData*)data;
- (NSString *)readDebugString;
- (void)clearDebugString;
- (void)writeInputStream:(NSInputStream*)inputStream;
@end

NS_ASSUME_NONNULL_END
