//
//  SSDownloaderLog.h
//  VCoach
//
//  Created by y2ss on 2018/9/3.
//  Copyright © 2018年 c123. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SSDownloaderTask;

@interface SSDownloaderLog : NSObject

- (void)logResumeTaskFailedWithTask:(SSDownloaderTask *)task reason:(NSString *)reason funcInfo:(NSString *)funcInfo;
- (void)logResumeTaskWithTask:(SSDownloaderTask *)task funcInfo:(NSString *)funcInfo;

- (void)logNewTaskWithTask:(SSDownloaderTask *)task funcInfo:(NSString *)funInfo;
- (void)logNewTaskAndWaittingWithTask:(SSDownloaderTask *)task waitNum:(NSInteger)waitNum funcInfo:(NSString *)funcInfo;

- (void)logDownloadSuccessWithTask:(SSDownloaderTask *)task funcInfo:(NSString *)funcInfo;
- (void)logDownloadErrorWithTask:(SSDownloaderTask *)task error:(NSError *)error otherReason:(NSString *)reason funcInfo:(NSString *)funcInfo;

- (void)logPauseWithTask:(SSDownloaderTask *)task funcInfo:(NSString *)funcInfo;
- (void)logDownloadStatus:(NSString *)funcinfo downloadInfo:(NSString *)info;

@end
