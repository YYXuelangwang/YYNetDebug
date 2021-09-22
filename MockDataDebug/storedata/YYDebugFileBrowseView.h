//
//  YYDebugFileBrowseView.h
//  testdebug
//
//  Created by langwang on 2/5/2020.
//  Copyright © 2020 qufan. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The 'YYDebugFileBrowseView' class will display all the files in the specified file directory through 'tableView'.
 After clicking on cell, you can choose to view or share the selected files with yourself
 */
@interface YYDebugFileBrowseView : UIView
@property (strong, nonatomic) NSString  *fileDirectory;
@end

NS_ASSUME_NONNULL_END
