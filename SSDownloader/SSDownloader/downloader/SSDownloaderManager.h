//
//  SSDownloaderManager.h
//  VCoach
//
//  Created by y2ss on 2018/7/17.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SSDownloaderCoral.h"
#import "SSDownloaderSession.h"
#import "SSDownloadUtils.h"

#define SSDownloaderMgr [SSDownloaderManager manager]

@interface SSDownloaderManager : NSObject

+ (instancetype)manager;

/**设置下载任务的个数，最多支持3个下载任务同时进行。*/
+ (void)setMaxTaskCount:(NSInteger)count;

+ (SSDownloaderTask *)startDownloadWithItem:(SSDownloaderCoral *)item;


/**
 url为下载任务的唯一标识。
 下载成功后用fileId来保存, 要确保fileId唯一
 文件后缀名取url的后缀名，[downloadURLString pathExtension]
 
 @param fileName 资源名称,可以为空
 @param imagUrl 资源的图片,可以为空
 @param fileId 非资源的标识,可以为空，用作下载文件保存的名称
 */
+ (void)startDownloadWithUrl:(NSString *)url fileName:(NSString *)fileName imageUrl:(NSString *)imagUrl fileId:(NSString *)fileId;

+ (void)startDownloadWithUrl:(NSString *)url fileName:(NSString *)fileName imageUrl:(NSString *)imagUrl;

/**暂停*/
+ (void)pauseDownloadWithItem:(SSDownloaderCoral *)item;

/**继续*/
+ (void)resumeDownloadWithItem:(SSDownloaderCoral *)item;

/**删除*/
+ (void)stopDownloadWithItem:(SSDownloaderCoral *)item;

/**暂停所有的下载*/
+ (void)pauseAllDownloadTask;

/**开始所有的下载*/
+ (void)resumeAllDownloadTask;

/**清空所有缓存*/
+ (void)removeAllCache;

/**判断该下载是否已经创建 可以是fileid 或 url */
+ (BOOL)isDownloadWithId:(NSString *)downloadId;

/**获取该资源的下载状态*/
+ (SSDownloaderState)downloasStatusWithId:(NSString *)downloadId;

/**获取该资源的下载详细信息*/
+ (SSDownloaderCoral *)downloadItemWithId:(NSString *)downloadId;

/**获取所有的未完成的下载任务*/
+ (NSArray *)downloadList;

/**获取所有已完成的下载任务*/
+ (NSArray *)finishList;

/**获取下载数据所占用磁盘空间*/
+ (int64_t)usedVideoCache;

+ (void)saveDownloadStatus;




@end
