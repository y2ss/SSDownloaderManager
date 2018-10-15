//
//  SSDownloaderManager+Push.m
//  VCoach
//
//  Created by y2ss on 2018/8/22.
//  Copyright © 2018年 c123. All rights reserved.
//

#import "SSDownloaderManager+Push.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UserNotifications/UserNotifications.h>

@implementation SSDownloaderManager (Push)

- (void)pushNotificationWithCourseName:(NSString *)courseName {
    if ([UIDevice currentDevice].systemVersion.floatValue < 10.0) {
        [self registeriOS8_9Notification:courseName];
    } else {
        [self registeriOS10Notification:courseName];
    }
}

- (void)registeriOS8_9Notification:(NSString *)courseName {
    UILocalNotification *localNotifi = [[UILocalNotification alloc]init];
    localNotifi.fireDate = [NSDate dateWithTimeIntervalSinceNow:3];
    localNotifi.timeZone = [NSTimeZone defaultTimeZone];
    localNotifi.alertTitle = @"视频下载完成";
    localNotifi.alertBody = [NSString stringWithFormat:@"%@已经下载完成了, 快来看看吧", courseName];;
    localNotifi.hasAction = YES;
    localNotifi.applicationIconBadgeNumber = 1;
    localNotifi.repeatInterval =  NSCalendarUnitMinute;
    localNotifi.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotifi];
}

- (void)registeriOS10Notification:(NSString *)courseName {
    if (@available(iOS 10.0, *)) {
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = @"视频下载完成";
        content.body = [NSString stringWithFormat:@"%@已经下载完成了, 快来看看吧", courseName];
        content.badge = @1;
        
        NSMutableDictionary *optionsDict = [NSMutableDictionary dictionary];
        optionsDict[UNNotificationAttachmentOptionsTypeHintKey] = (__bridge id _Nullable)(kUTTypeImage);
        // 是否隐藏缩略图
        optionsDict[UNNotificationAttachmentOptionsThumbnailHiddenKey] = @YES;
        //触发模式
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:5 repeats:NO];
        NSString *requestIdentifer = @"SSDownloader_push";
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:requestIdentifer content:content trigger:trigger];
        
        //把通知加到UNUserNotificationCenter, 到指定触发点会被触发
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
    }
}

@end
