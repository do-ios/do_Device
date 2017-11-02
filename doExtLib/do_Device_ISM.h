//
//  Do_MyDevice_IMethod.h
//  DoExt_SM
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol do_Device_ISM <NSObject>

@required

//实现同步或异步方法，parms中包含了所需用的属性
- (void)getLocationPermission:(NSArray *)parms;
- (void)beep:(NSArray *)parms;
- (void)flash:(NSArray *)parms;
- (void)getInfo:(NSArray *)parms;
- (void)getLocale:(NSArray *)parms;
- (void)vibrate:(NSArray *)parms;
- (void)screenShot:(NSArray *)parms;
- (void)srceenShotAsBitmap:(NSArray *)parms;
- (void)getGPSInfo:(NSArray *)parms;
- (void)getBattery:(NSArray *)parms;
- (void)setScreenAutoDarken:(NSArray *)parms;
- (void)getRingerMode:(NSArray *)parms;

@end
