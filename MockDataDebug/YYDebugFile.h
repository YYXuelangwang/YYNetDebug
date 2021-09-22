//
//  YYDebugFile.h
//  fmdb
//
//  Created by langwang on 2/5/2020.
//  Copyright © 2020 qufan. All rights reserved.
//

#ifndef YYDebugFile_h
#define YYDebugFile_h

#define KPATH_OF_DOCUMENT    [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]

#import <UIKit/UIKit.h>

typedef  void (^yyItemClicked)(UIButton*);
typedef NSDictionary<NSString*, yyItemClicked> YYItemData;

#endif /* YYDebugFile_h */
