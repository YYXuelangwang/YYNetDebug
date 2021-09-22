# 简介

当你在开发某个需求，服务器慢于你的开发；
当你在调查某个功能访问了什么接口，而又不想再次运行debug；
当你在调试某个接口返回数据的所有情况；

那这个库或许对你有些帮助，他能帮你提前调试自定义需要的数据接口；他能帮你将你的网路请求打印出来，直接在手机上查看；他能帮你调试你接口的所有情况；而不需要你在原生代码中添加额外的代码（避免代码污染）；

没错，你需要做的是在你个人电脑上配置你需要监听的接口，数据(目前只实现了json)，而不用再再次编译debug；

# 原理

初始化(初始化对象)  ->  拉取本地server中配置的mock接口（你需要mock的接口） 

接口请求    ->  过滤出你需要mock的请求  ->  替换为访问本地server的请求  ->  获取到配置好后的json数据；

# 安装

简单安装
``` podfile
pod 'debugFileStore', '~>0.0.3', :configurations => 'Debug'
```

使用：

在你项目中合适位置（可以是applicationdidfinish，也可以是登录页，你第一个初始化vc），添加上代码

```objc
#ifdef DEBUG
#import "YYNetDebug.h"
#endif
```
```objc
#ifdef DEBUG
    // 配置悬浮按钮，并添加悬浮按钮的响应事件
    [[SuspendButton addDebugBtnWithTag:30001] setItemsData:[self testEvent]];
#endif
```

```objc
#ifdef DEBUG
// 配置悬浮按钮的点击事件
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
                    [NetMockManager sharedInstance].mockUrl = @"http://192.168.100.31:8085";
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
        @{@"other_logic":[^(UIButton *btn){
            // code
        } copy]},];
}
#endif
```

额外配置：如果你的接口使用的是加密数据，或者比较长，那这里提供了一个block，来让你解密或者裁剪你的访问数据；

```objc
#ifdef DEBUG
    //    以自己项目的方式来获取请求的明文
    // 将原始请求的接口和参数过滤出来，主要是为了解决加密，解密的问题；
    [NetMockManager sharedInstance].parseRequest = ^YYPackedMockData * _Nonnull(NSURLRequest * _Nonnull request, NSString * _Nonnull interface, NSString * _Nonnull param) {
        return YYReturnPackedData(interface, [param stringByRemovingPercentEncoding]);
    };
#endif
```

# 服务器 （使用的是mac自带的python2.7）

server是通过python写的一个脚本，需要先下载好`server_script`文件夹中所有文件，然后进入到cofig文件夹中配置好你需要请求的接口，和你需要返回的数据；

>注：配置好接口后，需要重新启动你的app（mock接口会存在内存中），重启服务器；配置好返回数据后，只需要重启服务器；

这里以demo中示例为例，
1. 配置接口文件，配置好你需要过滤出来的接口，或者带有指定参数的接口；

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- 尽可能使得每个都唯一性，接口，建议不要有重复的 -->
<resources
   version = "1.0">
   <!-- 以下这个示例都可以用来进行测试，都能匹配的上，
        1. 测试时，因为使用的是同一个接口，用不同方式的时候，
        将其他方式注释掉就可以了；
        2. 匹配成功后，会把匹配的字符串拼接起来作为key，去
        json文件中找到对应的json值并返回；
    -->
    <!-- 多个参数的话，使用’,‘隔开，不要有空格 -->
    <params>SRDFPhj16881566aa8ee0a2e4c000757acca3569c574337,深圳</params>

    <!-- 仅使用接口来进行匹配 -->
    <!-- <interface>common/weather/get15DaysWeatherByArea</interface> -->

    <!-- 使用接口，加过滤参数进行匹配， -->
    <!-- <interface filterParams = "深圳">common/weather/get15DaysWeatherByArea</interface> -->

    <!-- 仅使用单个参数来进行匹配 -->
    <!-- <param>深圳</param> -->
</resources>
```

2. 配置返回数据，json文件中的key，是接口文件中数据拼接后的结果，如下所示

```json
{
    "SRDFPhj16881566aa8ee0a2e4c000757acca3569c574337深圳":{
        "statusCode": "000000",
        "desc": "请求成功",
        "result": {
            "area": "深圳",
            "areaCode": "440300",
            "areaid": "101280601",
            "dayList": [
                {
                    "area": "老铁，赶紧改bug",
                    "day_wind_direction": "无持续风向",
                    "night_wind_direction": "我不会悄悄告诉你，你将会有桃花运",
                    "night_wind_power": "0-3级"
                }
            ],
            "ret_code": 0
        }
    },
    "common/weather/get15DaysWeatherByArea深圳": {
        "statusCode": "000000",
        "desc": "请求成功",
        "result": {
            "area": "什么，列表没了，怎么会",
            "areaCode": "440300",
            "areaid": "101280601",
            "ret_code": 0
        }
    }
}
```

3. 启动/重启，进入python脚本所在目录，在命令行中输入下面的命令

```shell
# 进入到你脚本所在目录中；
$ sh start_server.sh
```

4. 关闭服务器，进入python脚本所在目录，在命令行中输入下面的命令

```shell
# 进入到你脚本所在目录中
$ sh stop_server.sh
```

# 演示示例

1. 最后监听到的网络请求，左图是正常的网络请求后的结果，右图是替换到本地服务器访问后的结果
    <center>
    <img src="https://i.loli.net/2020/07/11/9nR2M8FIPa7bhoN.png" width="40%" />
    <img src="https://i.loli.net/2020/07/11/9nR2M8FIPa7bhoN.png" width="40%" />
    </center>

2. 运行效果展示
    <center>
    <img src="https://i.loli.net/2020/07/11/9nR2M8FIPa7bhoN.png" width="40%" />
    <img src="https://i.loli.net/2020/07/11/9nR2M8FIPa7bhoN.png" width="40%" />
    </center>

# 结语

至此，就结束了，如果您有什么问题欢迎你的留言，希望能帮助你提高你的效率，希望你能玩得开心，
