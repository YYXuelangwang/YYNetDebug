//
//  YYDebugFileBrowseView.m
//  testdebug
//
//  Created by langwang on 2/5/2020.
//  Copyright © 2020 qufan. All rights reserved.
//

#import "YYDebugFileBrowseView.h"
#import "YYDebugFile.h"

static NSString * dirName = @"debug";

static CGFloat hspace = 20;
static CGFloat vspace = 50;

@interface YYMenuView : UIView
@property (strong, nonatomic) NSArray<YYItemData*> * itemsData;
- (instancetype)initWithItemsData:(NSArray<YYItemData*>*)itemsData;
@end

@implementation YYMenuView

- (instancetype)initWithItemsData:(NSArray<YYItemData *> *)itemsData{
    self = [super init];
    if (self) {
        self.itemsData = itemsData;
    }
    return self;
}

- (void)setItemsData:(NSArray<YYItemData *> *)itemsData{
    _itemsData = itemsData;
    if (!itemsData) {
        return;
    }
    NSInteger count = _itemsData.count;
    CGFloat itemWidth = 100.0;
    CGFloat itemHeight = 50.0;
    
    for (int i = 0; i < count; i ++) {
        UIButton *btn = (UIButton*)[self viewWithTag:i + 200];
        YYItemData * data = [_itemsData objectAtIndex:i];
        if (!btn) {
            btn = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn setTitle:data.allKeys.firstObject forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:12];
            btn.frame = CGRectMake(0, itemHeight * i, itemWidth, itemHeight);
            btn.tag = 200 + i;
            [self addSubview:btn];
            [btn addTarget:self action:@selector(clickedItem:) forControlEvents:UIControlEventTouchUpInside];
        }
    }
}

- (void)clickedItem:(UIButton*)btn{
    NSInteger index = btn.tag - 200;
    YYItemData *data = [self.itemsData objectAtIndex:index];
    yyItemClicked clickedBlock = data.allValues.firstObject;
    if (clickedBlock) {
        clickedBlock(btn);
    }
}

@end

/**
The 'YYDebugFileBrowseView' class will display all the files in the specified file directory through 'tableView'.
After clicking on cell, you can choose to view or share the selected files with yourself
*/
@interface YYDebugFileBrowseView()<UITableViewDataSource, UITableViewDelegate>
{
    NSString * _fileDirectory;
}
@property (strong, nonatomic) UITableView  *tableView;
@property (strong, nonatomic) UIButton  *closeBtn;
@property (strong, nonatomic) NSArray<NSString*>  *dataSource;
@property (strong, nonatomic) YYMenuView  *menuView;
@property (strong, nonatomic) UIView  *logShowView;
@property (strong, nonatomic) NSString  *selectedFilePath;
@end

@implementation YYDebugFileBrowseView

- (instancetype)init{
    if (self = [super init]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        if ([self isiPhoneX]) {
            vspace = 100;
        }
        self.closeBtn.hidden = NO;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        if ([self isiPhoneX]) {
            vspace = 100;
        }
        self.closeBtn.hidden = NO;
    }
    return self;
}

- (void)remove:(UIButton*)btn{
    [self removeFromSuperview];
}

- (void)back:(UIButton*)btn{
    self.logShowView.hidden = YES;
}

- (void)clear:(UIButton*)btn{
    if (!self.selectedFilePath) {
        return;
    }
    clearFileContent(self.selectedFilePath);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseIdentifier"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"reuseIdentifier"];
    }
    cell.textLabel.text = self.dataSource[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *fileName = self.dataSource[indexPath.row];
    CGRect rect = [tableView rectForRowAtIndexPath:indexPath];
    rect.origin.x += 20;
    rect.origin.y += 20;
    
    if (self.menuView.hidden == NO && self.menuView.frame.origin.y == rect.origin.y) {
        self.menuView.hidden = !self.menuView.hidden;
        return;
    }
    
    self.menuView.frame = CGRectMake(rect.origin.x, rect.origin.y, 100.0, 100.0);
    self.menuView.hidden = NO;
    __weak typeof(self) weakSelf = self;
    self.menuView.itemsData = @[
        @{@"showDebugFile": ^{
            NSLog(@"you will show the file: %@", fileName);
            UITextView *textView = [weakSelf.logShowView viewWithTag:20001];
            NSString *filepath = [weakSelf.fileDirectory stringByAppendingPathComponent:fileName];
            textView.text = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
            weakSelf.logShowView.hidden = NO;
            weakSelf.selectedFilePath = filepath;
        }},
        @{@"shareDebugFile": ^{
            NSLog(@"you will share the file: %@", fileName);
            NSString *filePath = [weakSelf.fileDirectory stringByAppendingPathComponent: fileName];
            NSURL *fileUrl = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", filePath]];
            NSArray *activityItemsArray = @[fileUrl];
            UIActivityViewController *activityViewController = [[UIActivityViewController alloc]initWithActivityItems:activityItemsArray applicationActivities:nil];
            [[UIApplication sharedApplication].delegate.window.rootViewController presentViewController:activityViewController animated:YES completion:nil];
            [weakSelf remove:nil];
        }}
    ];
}

#pragma mark - getter

#define kYYWinSize  [UIScreen mainScreen].bounds.size

- (UITableView *)tableView{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(hspace, vspace, kYYWinSize.width - 2 * hspace, kYYWinSize.height - 2 * vspace)];
        [self addSubview:_tableView];
        
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.layer.cornerRadius = 5.0;
        _tableView.layer.masksToBounds = YES;
    }
    return _tableView;
}

- (NSArray<NSString *> *)dataSource{
    if (!_dataSource) {
        NSString *dirPath = self.fileDirectory;
        NSArray * array = [[NSFileManager defaultManager] subpathsAtPath:dirPath];
        __block NSMutableArray * fileArray = [NSMutableArray array];
        [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dir = [[NSFileManager defaultManager] attributesOfItemAtPath:[dirPath stringByAppendingPathComponent:obj] error:nil];
            if (![dir.fileType isEqualToString:NSFileTypeDirectory] ) {
                [fileArray addObject:obj];
            }
        }];
        _dataSource = fileArray;
    }
    return _dataSource;
}

- (void)setFileDirectory:(NSString *)fileDirectory{
    _fileDirectory = fileDirectory;
    [self.tableView reloadData];
}

- (NSString *)fileDirectory{
    if (!_fileDirectory) {
        _fileDirectory = [KPATH_OF_DOCUMENT stringByAppendingPathComponent:dirName];
    }
    return _fileDirectory;
}

- (YYMenuView *)menuView{
    if (!_menuView) {
        _menuView = [[YYMenuView alloc] init];
        _menuView.backgroundColor = [UIColor whiteColor];
        _menuView.layer.cornerRadius = 5.0;
        _menuView.layer.masksToBounds = YES;
        _menuView.hidden = YES;
        _menuView.frame = CGRectMake(0, 0, 100.0, 100.0);
        [self.tableView addSubview:_menuView];
    }
    return _menuView;
}

- (UIButton *)closeBtn{
    if (!_closeBtn) {
        _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_closeBtn setTitle:@"close" forState:UIControlStateNormal];
        [_closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _closeBtn.frame = CGRectMake(20, 0, 150, vspace);
        [_closeBtn addTarget:self action:@selector(remove:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_closeBtn];
    }
    return _closeBtn;
}

- (UIView *)logShowView{
    if (!_logShowView) {
        _logShowView = [[UIView alloc] initWithFrame:self.bounds];
        _logShowView.backgroundColor = [UIColor lightGrayColor];
        [self addSubview:_logShowView];
        
        CGSize size = self.bounds.size;
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(20, 0, 150, vspace)];
        [btn setTitle:@"back" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
        [_logShowView addSubview:btn];
        
        btn = [[UIButton alloc] initWithFrame:CGRectMake(size.width - 170, 0, 150, vspace)];
        [btn setTitle:@"clear" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(clear:) forControlEvents:UIControlEventTouchUpInside];
        [_logShowView addSubview:btn];

        UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(5, vspace, size.width - 10, size.height - vspace)];
        textView.tag = 20001;
        [_logShowView addSubview:textView];
    }
    return _logShowView;
}

- (BOOL)isiPhoneX {
    if (@available(iOS 11.0, *)) {
        UIWindow *keyWindow = [[[UIApplication sharedApplication] delegate] window];
        CGFloat bottomSafeInset = keyWindow.safeAreaInsets.bottom;
        if (bottomSafeInset == 34.0f || bottomSafeInset == 21.0f) {
            return YES;
        }
    }
    return NO;
}

static void clearFileContent(NSString * filePath){
    NSString *tempStr = @"";
    [tempStr writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

@end

#ifdef kYYWinSize
#undef kYYWinSize
#endif
