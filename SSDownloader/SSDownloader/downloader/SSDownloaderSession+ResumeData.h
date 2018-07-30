//
//  SSDownloaderSession+ResumeData.h
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import "SSDownloaderSession.h"

/*
 https://blog.csdn.net/ly20091130/article/details/52680066
 https://stackoverflow.com/questions/39346231/resume-nsurlsession-on-ios10/39347461#39347461
 iOS10用backgroundSession进行下载时，请求暂停后再继续下载会出错
 iosBug 原因是resumeData中归档出来的数据currentRequest和originalRequest使用的是@"NSKeyedArchiveRootObjectKey"而不是NSKeyedArchiveRootObjectKey
 fix in ios11.2
 */

@interface SSDownloaderSession (ResumeData)

+ (NSURLSessionDownloadTask *)downloadTaskWithCorrectResumeData:(NSData *)resumeData urlSession:(NSURLSession *)urlSession;

/**
 @param resumeData 原始resumeData
 @return correct resumeData
 */
+ (NSData *)cleanResumeData:(NSData *)resumeData;

@end
