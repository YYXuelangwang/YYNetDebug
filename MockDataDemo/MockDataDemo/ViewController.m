//
//  ViewController.m
//  MockDataDemo
//
//  Created by langwang on 16/9/2021.
//

#import "ViewController.h"
#import <AFNetworking/AFNetworking.h>

#ifdef DEBUG
#import "YYNetDebug.h"
#endif

@interface ViewController ()
@property (strong, nonatomic) AFHTTPSessionManager  *manager;
@property (strong, nonatomic) NSDictionary  *params;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
#ifdef DEBUG
    // 配置悬浮按钮，并添加悬浮按钮的响应事件
    [[SuspendButton addDebugBtnWithTag:30001] setItemsData:[self testEvent]];
#endif
        
    [self createBtn:@"开始请求" frame:CGRectMake(50, 50, 150, 35) selector:@selector(clickTest:)];
    [self createBtn:@"使用自定义的方式获取明文" frame:CGRectMake(50, 90, 150, 35) selector:@selector(clickedInterfaceParam:)];
    [self createBtn:@"设置仅通过参数来匹配" frame:CGRectMake(50, 130, 150, 35) selector:@selector(clickedOnlyParam:)];
}

- (void)createBtn:(NSString*)title frame:(CGRect)frame selector:(SEL)selector{
    UIButton* btn = [[UIButton alloc] initWithFrame:frame];
    [self.view addSubview:btn];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.adjustsFontSizeToFitWidth = YES;
    btn.backgroundColor = [UIColor colorWithRed:(arc4random()%255)/255.0 green:(arc4random()%255)/255.0 blue:(arc4random()%255)/255.0 alpha:1.0];
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - 添加自定义事件
#ifdef DEBUG

- (NSArray*)testEvent{
    __weak __typeof(self)weakSelf = self;
    return  @[
        
        //        开始/关闭监听网路请求
        @{@"net_off":[^(UIButton *btn){
            btn.selected = !btn.selected;
            
            // 这里可以替换为你们项目中的网络请求，
            AFHTTPSessionManager *manager = weakSelf.manager;
            if (manager) {
                NSURLSessionConfiguration *config = [manager valueForKey:@"sessionConfiguration"];
                if (config) {
                    config.protocolClasses = btn.selected ? @[[YYHTTPProtocol class]] : @[];
                }
                [manager invalidateSessionCancelingTasks:YES resetSession:YES];
                if (btn.selected) {
                    // 这里配置好你本地servier的ip（你本地电脑的ip地址）和端口号，端口号默认是8085，可以修改
                    // 但端口号需要和server_script/httpserver.py中的端口号保持一致
                    [NetMockManager sharedInstance].mockUrl = @"http://192.168.100.32:8084";
                }
            }
            
            if (btn.selected) {
                [btn setTitle:@"net_on" forState:UIControlStateNormal];
            }else{
                [btn setTitle:@"net_off" forState:UIControlStateNormal];
            }
        } copy]},
        
        //        展示出监听的网络请求和返回数据
        @{@"show_debug":[^(UIButton *btn){
            yy_showDebugFileView();
        } copy]},
    
        //        你项目中额外的调试逻辑代码
//        @{@"other_logic":[^(UIButton *btn){
//            // code
//        } copy]},];
    ];
}
#endif

#pragma mark - 一些测试点击事件

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

- (void)clickTest:(UIButton*)btn{
    [self.manager POST:@"http://api.apishop.net/common/weather/get15DaysWeatherByArea" parameters:self.params headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSDictionary *dic = responseObject;
        [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingFragmentsAllowed error:nil];
        
        NSLog(@"%@", responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"%@", error);
    }];
}

/// 匹配接口（通过request.URL.path来获取），参数
- (void)clickedInterfaceParam:(UIButton*)btn{
    //    以自己项目的方式来获取请求的明文
    // 将原始请求的接口和参数过滤出来，主要是为了解决加密，解密的问题；
    [NetMockManager sharedInstance].parseRequest = ^YYPackedMockData * _Nonnull(NSURLRequest * _Nonnull request, NSString * _Nonnull interface, NSString * _Nonnull param) {
        return YYReturnPackedData(interface, [param stringByRemovingPercentEncoding]);
    };
}


/// 仅匹配参数
- (void)clickedOnlyParam:(UIButton*)btn{
    //    以自己项目的方式来获取请求的明文
    // 将原始请求的接口和参数过滤出来，主要是为了解决加密，解密的问题；
    [NetMockManager sharedInstance].parseRequest = ^YYPackedMockData * _Nonnull(NSURLRequest * _Nonnull request, NSString * _Nonnull interface, NSString * _Nonnull param) {
        return YYReturnPackedData(@"", [param stringByRemovingPercentEncoding]);
    };
}

- (AFHTTPSessionManager *)manager{
    if (!_manager) {
        _manager = [AFHTTPSessionManager manager];
        _manager.responseSerializer.acceptableContentTypes =  [NSSet setWithObjects:@"application/json", @"text/json", @"text/plain", @"text/javascript", nil];
    }
    return _manager;
}

- (NSDictionary *)params{
    if (!_params) {
        _params = @{
            @"apiKey":@"SRDFPhj16881566aa8ee0a2e4c000757acca3569c574337",
            @"area":@"深圳",
        };
    }
    return _params;
}


@end
