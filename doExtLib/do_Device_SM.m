//
//  Do_MyDevice_SM.m
//  DoExt_SM
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_Device_SM.h"

#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doInvokeResult.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import  <CoreTelephony/CTCarrier.h>
#import  <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <UIKit/UIKit.h>
#import "doJsonHelper.h"
#import "doIScriptEngine.h"
#import "doIPage.h"
#import "doIDataFS.h"
#import "doIOHelper.h"
#import <CoreLocation/CoreLocation.h>
#import "doServiceContainer.h"
#import "doILogEngine.h"
#import "doIBitmap.h"
#import "doUIModuleHelper.h"
#import <AudioToolbox/AudioToolbox.h>

@class RBDMuteSwitch;

@protocol RBDMuteSwitchDelegate
@required
- (void)isMuted:(BOOL)muted;
@end

@interface RBDMuteSwitch : NSObject {
@private
    NSObject<RBDMuteSwitchDelegate> *delegate;
    float soundDuration;
    NSTimer *playbackTimer;
}

@property (readwrite, retain) NSObject<RBDMuteSwitchDelegate> *delegate;

+ (RBDMuteSwitch *)sharedInstance;
- (void)detectMuteSwitch;

@end

@interface do_Device_SM()<RBDMuteSwitchDelegate>

@end

@implementation do_Device_SM
{
    BOOL isLigthOn;
    AVCaptureDevice *device;
    
    CGFloat XZoom;
    CGFloat YZoom;
    
    doInvokeResult *_invokeResultMute;
    id<doIScriptEngine> _scritEngineMute;
    NSString *_callbackNameMute;
    BOOL _isGetMutedStatus;
}
#pragma mark -
#pragma mark - 同步异步方法的实现
/*
 1.参数节点
     doJsonNode *_dictParas = [parms objectAtIndex:0];
     a.在节点中，获取对应的参数
     NSString *title = [_dictParas GetOneText:@"title" :@"" ];
     说明：第一个参数为对象名，第二为默认值
 
 2.脚本运行时的引擎
     id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
 
 同步：
 3.同步回调对象(有回调需要添加如下代码)
     doInvokeResult *_invokeResult = [parms objectAtIndex:2];
     回调信息
     如：（回调一个字符串信息）
     [_invokeResult SetResultText:((doUIModule *)_model).UniqueKey];
 异步：
 3.获取回调函数名(异步方法都有回调)
     NSString *_callbackName = [parms objectAtIndex:2];
     在合适的地方进行下面的代码，完成回调
     新建一个回调对象
     doInvokeResult *_invokeResult = [[doInvokeResult alloc] init];
     填入对应的信息
     如：（回调一个字符串）
     [_invokeResult SetResultText: @"异步方法完成"];
     [_scritEngine Callback:_callbackName :_invokeResult];
 */

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

//同步
- (void)getLocationPermission:(NSArray *)parms {
    doInvokeResult *_invokeResult = [parms objectAtIndex:2];
    BOOL isState = [CLLocationManager locationServicesEnabled];
    if (!isState) {  // 应用没有 使用位置的权限
        [_invokeResult SetResultInteger:-1];
        return;
    }else { // 应用有 使用位置的权限
        
        if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
            CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
            switch (authorizationStatus) {
                case kCLAuthorizationStatusAuthorizedWhenInUse: // 使用应用期间
                    [_invokeResult SetResultInteger:0];
                    
                    break;
                case kCLAuthorizationStatusAuthorizedAlways: // 始终
                    [_invokeResult SetResultInteger:1];
                    
                    break;
                case kCLAuthorizationStatusDenied: // 拒绝: 永不
                    [_invokeResult SetResultInteger:2];
                    
                    break;
                default:
                    break;
            }
            
        }else {
            [_invokeResult SetResultInteger:-2]; // 系统版本小于iOS8，方法不可用
            [[doServiceContainer Instance].LogEngine WriteError:nil :@"getLocationPermission方法 iOS8.0 之后的系统才可用"];
            return;
        }
        
    }
    
}

- (void)beep:(NSArray *)parms
{
    //自己的代码实现
    AudioServicesPlaySystemSound (1106);
}
- (void)getLocale:(NSArray *)parms
{
    NSLocale *currentLo = [NSLocale currentLocale];
    NSString *language = [currentLo objectForKey:NSLocaleLanguageCode];
    NSString *country = [currentLo objectForKey:NSLocaleCountryCode];
    
    NSDictionary *dict = @{@"country":country,@"language":language};
    
    doInvokeResult *_invokeResult = [parms objectAtIndex:2];
    [_invokeResult SetResultNode:dict];
}

- (void)flash:(NSArray *)parms
{
    NSDictionary *_dictParams = [parms objectAtIndex:0];
    NSString *_status = [doJsonHelper GetOneText:_dictParams :@"status" :@""];
    if([_status isEqualToString:@"on"])
    {
        if(device == nil)
        {
            device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        if(!isLigthOn)
        {
            [device lockForConfiguration:nil];
            [device setTorchMode:AVCaptureTorchModeOn];
            [device unlockForConfiguration];
            isLigthOn = YES;
        }
    }
    
    else if([_status isEqualToString:@"off"])
    {
        if(device != nil)
        {
            [device lockForConfiguration:nil];
            [device setTorchMode: AVCaptureTorchModeOff];
            [device unlockForConfiguration];
            isLigthOn = NO;
        }
    }
}
- (void)getInfo:(NSArray *)parms
{
    doInvokeResult *_invokeResult = [parms objectAtIndex:2];
    
    NSMutableDictionary *identifierDict;
    NSString * const KEY_USERNAME_PASSWORD = @"com.do.deviceone";
    NSString * const KEY_PASSWORD = @"com.do.deviceonepwd";
    if (![do_Device_SM load:KEY_USERNAME_PASSWORD]) { // 如果没有存储过
        //获取设备id
        NSString *identifierStr = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        NSMutableDictionary *deviceKVPairs = [NSMutableDictionary dictionary];
        [deviceKVPairs setObject:identifierStr forKey:KEY_PASSWORD];
        
        //存
        [do_Device_SM save:KEY_USERNAME_PASSWORD data:deviceKVPairs];
    }
    identifierDict = (NSMutableDictionary *)[do_Device_SM load:KEY_USERNAME_PASSWORD];

    NSString *deviceId =  [identifierDict objectForKey:KEY_PASSWORD];
    //获取设备名称
    NSString *deviceName = [UIDevice currentDevice].name;
    //获取设备操作系统
    NSString *OS = [UIDevice currentDevice].systemName;
    //获取设备操作系统版本号
    NSString *OSVersion = [UIDevice currentDevice].systemVersion;
    // 获取SDK版本号
    NSString *sdkVersion = OSVersion;
    
    //获取设备水平像素密度
    NSString *dpiH = [NSString stringWithFormat:@"%d", (int )[[UIScreen mainScreen] scale]];
    //获取设备垂直像素密度
    NSString *dpiV = [NSString stringWithFormat:@"%d", (int )[[UIScreen mainScreen] scale]];
    //获取设备水平屏幕宽度
    NSString *screenH =[NSString stringWithFormat:@"%d",(int )[UIScreen mainScreen].bounds.size.width];
    //获取设备垂直屏幕宽度
    NSString *screenV =[NSString stringWithFormat:@"%d",(int )[UIScreen mainScreen].bounds.size.height];
    //获取设备水平分辨率
    NSString *resolutionH = [NSString stringWithFormat:@"%d",(int)[[UIScreen mainScreen] scale] * (int)[UIScreen mainScreen].bounds.size.width];
    
    //获取设备垂直分辨率
    NSString *resolutionV = [NSString stringWithFormat:@"%d",(int)[[UIScreen mainScreen] scale] * (int)[UIScreen mainScreen].bounds.size.height];
    //获取设备手机机型
    
    NSString *phoneType = [doUIModuleHelper GetPlatformString];
    
//    UIApplication *app = [UIApplication sharedApplication];
//    NSArray *children = [[[app valueForKeyPath:@"statusBar"] valueForKeyPath:@"foregroundView"] subviews];
//    id type = @"";
//    for (id child in children) {
//        if ([child isKindOfClass:NSClassFromString(@"UIStatusBarServiceItemView")]) {
//            type = [child valueForKeyPath:@"serviceString"];
//            break;
//        }
//    }
    
    NSString *communicationType = @"无运营商信息";
    // 获取设备运营商信息
    CTCarrier *carrier = [[[CTTelephonyNetworkInfo alloc] init] subscriberCellularProvider];
    if ([self isSIMInstalled]) {
        if (carrier) {
            communicationType = carrier.carrierName;
        }
    }
    //获取内存情况
//    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//    NSFileManager *fileManager =[[NSFileManager alloc]init];
//    NSDictionary *fileSysAttributes = [fileManager attributesOfFileSystemForPath:path error:nil];
//    NSString *freeSpace = [fileSysAttributes objectForKey:NSFileSystemFreeSize];
//    NSString *totalSpace = [fileSysAttributes objectForKey:NSFileSystemSize];
//    NSString *sdkVersion = [NSString stringWithFormat:@"剩余%0.1fG/总共%0.1fG",[freeSpace longLongValue]/1024.0/1024.0/1024.0,[totalSpace longLongValue]/1024.0/1024.0/1024.0];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]initWithObjectsAndKeys:deviceId,@"deviceId", deviceName,@"deviceName",OS,@"OS",OSVersion,@"OSVersion",sdkVersion,@"sdkVersion",dpiH,@"dpiH",dpiV,@"dpiV",screenH,@"screenH",screenV,@"screenV",resolutionH,@"resolutionH",resolutionV,@"resolutionV",phoneType,@"phoneType",communicationType,@"communicationType",nil];
    
    
    [_invokeResult SetResultNode:dict];
}
/// 判断设备是否安装sim卡
-(BOOL)isSIMInstalled
{
    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    if (!carrier.isoCountryCode) {
        return NO;
    }
    return YES;
}

- (void)vibrate:(NSArray *)parms
{
    //震动，调用系统震动，每次调用都会实现1-2秒的震动
    AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
}

//异步
- (void)screenShot:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    //参数字典_dictParas
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
    XZoom = _scritEngine.CurrentPage.RootView.XZoom;
    YZoom = _scritEngine.CurrentPage.RootView.YZoom;

    NSString *rectStr = [doJsonHelper GetOneText:_dictParas :@"rect" :@""];
    //自己的代码实现
    id<doIPage>pageModel = _scritEngine.CurrentPage;
    UIViewController *currentVC = (UIViewController *)pageModel.PageView;

    NSString *_callbackName = [parms objectAtIndex:2];
    //回调函数名_callbackName
    doInvokeResult *_invokeResult = [[doInvokeResult alloc]init:self.UniqueKey];
    //_invokeResult设置返回值
    
    float screenW = [UIScreen mainScreen].bounds.size.width;
    float screenH = [UIScreen mainScreen].bounds.size.height;
    CGRect parmRect = [self rectWithrectStr:rectStr];
    if (CGRectEqualToRect(parmRect, CGRectZero)) {
        parmRect = CGRectMake(0, 0, screenW, screenH);
    }
    UIImage *sendImage = [self viewSnapshot:currentVC.view withInRect:parmRect];
    
//    UIImageWriteToSavedPhotosAlbum(sendImage, nil, nil, nil);//保存图片到照片库
    NSData *imageViewData = UIImagePNGRepresentation(sendImage);
    NSString *_fileFullName = [_scritEngine CurrentApp].DataFS.RootPath;
    NSDateFormatter *dateFromatter = [[NSDateFormatter alloc]init];
    dateFromatter.dateFormat = @"yyyyMMdd+HHmmss";
    NSString *fileName = [NSString stringWithFormat:@"%@.png",[dateFromatter stringFromDate:[NSDate date]]];
    NSString *filePath = [NSString stringWithFormat:@"%@/temp/do_Device/%@",_fileFullName,fileName];
    NSString *returnPath = [NSString stringWithFormat:@"data://temp/do_Device/%@",fileName];
    //    NSLog(@"截屏路径打印: %@", filePath);
    NSString *path = [NSString stringWithFormat:@"%@/temp/do_Device",_fileFullName];
    if(![doIOHelper ExistDirectory:path])
    {
        [doIOHelper CreateDirectory:path];
    }
    BOOL isSuccess = [imageViewData writeToFile:filePath atomically:YES];//保存照片到沙盒目录
    if (isSuccess) {

        [_invokeResult SetResultText:returnPath];
        [_scritEngine Callback:_callbackName :_invokeResult];
    }
}
- (void)srceenShotAsBitmap:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    //参数字典_dictParas
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
    XZoom = _scritEngine.CurrentPage.RootView.XZoom;
    YZoom = _scritEngine.CurrentPage.RootView.YZoom;
    NSString *_callbackName = [parms objectAtIndex:2];
    //自己的代码实现
    id<doIPage>pageModel = _scritEngine.CurrentPage;
    UIViewController *currentVC = (UIViewController *)pageModel.PageView;
    NSString *bitmapAddress = [doJsonHelper GetOneText:_dictParas :@"bitmap" :@""];
    NSString *rectStr = [doJsonHelper GetOneText:_dictParas :@"rect" :@""];
    CGRect parmRect = [self rectWithrectStr:rectStr];
    UIImage *bitmapImg;
    if (CGRectEqualToRect(parmRect, CGRectZero)) {
        bitmapImg = [self viewSnapshot:currentVC.view withInRect:currentVC.view.bounds];
    }
    else
    {
        bitmapImg = [self viewSnapshot:currentVC.view withInRect:parmRect];
    }
    doMultitonModule *_multitonModule = [doScriptEngineHelper ParseMultitonModule:_scritEngine :bitmapAddress];
    
    id<doIBitmap> bitmap = (id<doIBitmap>)_multitonModule;
    [bitmap setData:bitmapImg];
    doInvokeResult *_invokeResult = [[doInvokeResult alloc]init:self.UniqueKey];
    [_scritEngine Callback:_callbackName :_invokeResult];
}
- (void)getGPSInfo:(NSArray *)parms
{
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
    NSString *_callbackName = [parms objectAtIndex:2];
    BOOL isState = [CLLocationManager locationServicesEnabled];
    doInvokeResult *_invokeResult = [[doInvokeResult alloc]init];
    NSDictionary *dic = @{@"state":[@(isState) stringValue]};
    [_invokeResult SetResultNode:dic];
    [_scritEngine Callback:_callbackName :_invokeResult];
}


- (void)getBattery:(NSArray *)parms
{
    doInvokeResult *_invokeResult = [parms objectAtIndex:2];
    //_invokeResult设置返回值
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float batter =  [UIDevice currentDevice].batteryLevel;
    [_invokeResult SetResultInteger:batter * 100];
}

- (void)setScreenAutoDarken:(NSArray *)parms
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    //参数字典_dictParas
    BOOL isAuto = [doJsonHelper GetOneBoolean:_dictParas :@"isAuto" :YES];
    [UIApplication sharedApplication].idleTimerDisabled = !isAuto;
}
#pragma mark - 私有方法
//截取rect内的屏幕
- (UIImage *)viewSnapshot:(UIView *)theView withInRect:(CGRect)r
{
    UIGraphicsBeginImageContextWithOptions(r.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    [theView.layer renderInContext:context];
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return  theImage;
}

- (CGRect)rectWithrectStr:(NSString *)rect
{
    @try {
        if (rect.length <= 7) {
            return CGRectZero;
        }
        else
        {
            NSArray *frames = [rect componentsSeparatedByString:@","];
            if (frames.count < 4) {
                return CGRectZero;
            }
            return CGRectMake([frames[0] floatValue] * XZoom, [frames[1] floatValue] * YZoom, [frames[2] floatValue] * XZoom, [frames[3] floatValue]* YZoom);
        }
        return CGRectZero;
        
    } @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :@"deviceone的screenShot方法参数rect有误"];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
    }
    
}

+ (void)save:(NSString *)service data:(id)data {
    //Get search dictionary
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service];
    //Delete old item before add new item
    SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    //Add new object to search dictionary(Attention:the data format)
    [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:data] forKey:(__bridge id)kSecValueData];
    //Add item to keychain with the search dictionary
    SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);
}

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)service {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            (__bridge id)kSecClassGenericPassword,(__bridge id)kSecClass,
            service, (__bridge id)kSecAttrService,
            service, (__bridge id)kSecAttrAccount,
            (__bridge id)kSecAttrAccessibleAfterFirstUnlock,(__bridge id)kSecAttrAccessible,
            nil];
}

//取
+ (id)load:(NSString *)service {
    id ret = nil;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service];
    //Configure the search setting
    //Since in our simple case we are expecting only a single attribute to be returned (the password) we can set the attribute kSecReturnData to kCFBooleanTrue
    [keychainQuery setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [keychainQuery setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    CFDataRef keyData = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData) == noErr) {
        @try {
            ret = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)keyData];
        } @catch (NSException *e) {
            NSLog(@"Unarchive of %@ failed: %@", service, e);
        } @finally {
        }
    }
    if (keyData)
        CFRelease(keyData);
    return ret;
}
- (void)getRingerMode:(NSArray *)parms
{
    _scritEngineMute = [parms objectAtIndex:1];
    _callbackNameMute = [parms objectAtIndex:2];
    //必须放到主线程，否则在代理中无法正确获取返回值
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RBDMuteSwitch sharedInstance] setDelegate:self];
        [[RBDMuteSwitch sharedInstance] detectMuteSwitch];
    });
}
- (void)isMuted:(BOOL)muted {
    int isMuted1 = !muted;
    NSDictionary *node = [NSDictionary dictionaryWithObject:@(isMuted1) forKey:@"mode"];
    _invokeResultMute = [[doInvokeResult alloc]init];
    [_invokeResultMute SetResultNode:node];
    [_scritEngineMute Callback:_callbackNameMute :_invokeResultMute];
}

@end

static RBDMuteSwitch *_sharedInstance;

@implementation RBDMuteSwitch

@synthesize delegate;

+ (RBDMuteSwitch *)sharedInstance
{
    if (!_sharedInstance) {
        _sharedInstance = [[[self class] alloc] init];
    }
    return _sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
    }
    
    return self;
}

- (void)playbackComplete {
    if ([(id)self.delegate respondsToSelector:@selector(isMuted:)]) {
        if (soundDuration < 0.001) {
            [delegate isMuted:YES];
        }
        else {
            [delegate isMuted:NO];
        }
    }
    [playbackTimer invalidate];
    playbackTimer = nil;
}

static void soundCompletionCallback (SystemSoundID mySSID, void* myself) {
    AudioServicesRemoveSystemSoundCompletion (mySSID);
    [[RBDMuteSwitch sharedInstance] playbackComplete];
}

- (void)incrementTimer {
    soundDuration = soundDuration + 0.001;
}

- (void)detectMuteSwitch {
    soundDuration = 0.0;
    CFURLRef		soundFileURLRef;
    SystemSoundID	soundFileObject;
    
    // Get the main bundle for the app
    CFBundleRef mainBundle;
    mainBundle = CFBundleGetMainBundle();

    // Get the URL to the sound file to play
    soundFileURLRef  =	CFBundleCopyResourceURL(
                                                mainBundle,
                                                CFSTR ("DODevice.bundle/detection"),
                                                CFSTR ("aiff"),
                                                NULL
                                                );
    
    // Create a system sound object representing the sound file
    AudioServicesCreateSystemSoundID (
                                      soundFileURLRef,
                                      &soundFileObject
                                      );
    
    AudioServicesAddSystemSoundCompletion (soundFileObject,NULL,NULL,
                                           soundCompletionCallback,
                                           (void*) CFBridgingRetain(self));
    
    // Start the playback timer
    playbackTimer = [NSTimer scheduledTimerWithTimeInterval:0.010 target:self selector:@selector(incrementTimer) userInfo:nil repeats:YES];

    AudioServicesPlaySystemSound(soundFileObject);
    return;
}

@end
