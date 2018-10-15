//
//  SSDownloaderSession.h
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import "SSDownloaderTask.h"
#import "SSDownloadUtils.h"

//all of this is not certain that the thread is main one
/*
 某个任务下载完成
 object: (SSDownloaderTask *)task
 */
UIKIT_EXTERN NSString * const kDownloadTaskDidFinished;
/*
 所有任务下载完成
 */
UIKIT_EXTERN NSString * const kDownloadAllTaskFinishedNoti;
/*
 下载任务状态变化
 object: (SSDownloaderTask *)task
 */
UIKIT_EXTERN NSString * const kDownloadStatusChangedNoti;

/*
 下载进度改变
 object: (SSDownloaderTask *)task
         (NSInteger)downloadSize
         (float)fileSize
*/
UIKIT_EXTERN NSString * const kDownloadTaskPorgressChanged;

@class SSDownloaderSession;

@protocol SSDownloaderSessionDelegate<NSObject>

- (void)backgroundDidFinishedAllTask;

@end

@interface SSDownloaderSession : NSObject

+ (instancetype)shared;
/**设置同时下载任务数,最多支持3个。*/
@property (nonatomic, assign) int maxTaskCount;

@property (nonatomic, weak) id<SSDownloaderSessionDelegate>delegate;

#pragma Download
- (SSDownloaderTask *)downloadWithURL:(NSString *)url delegate:(id<SSDownloaderTaskDelegate>)delegate;
/**
 开始下载
 @param fileID 文件id。可以为空。通过改变id可以使文件重复下载
 */
- (SSDownloaderTask *)downloadWithURL:(NSString *)url
                               fileID:(NSString *)fileID
                             fileName:(NSString *)fileName
                             delegate:(id<SSDownloaderTaskDelegate>)delegate;

#pragma Session Action
/**暂停一个后台下载任务 */
- (void)pauseDownloadWithTask:(SSDownloaderTask *)task;

/**继续开始一个后台下载任务*/
- (void)resumeDownloadWithTask:(SSDownloaderTask *)task;

/**删除一个后台下载任务数据*/
- (void)stopDownloadWithTask:(SSDownloaderTask *)task;

/**暂停任务*/
- (void)pauseDownloadWithTaskId:(NSString *)taskId;

/**继续任务*/
- (void)resumeDownloadWithTaskId:(NSString *)taskId;

/**删除任务数据*/
- (void)stopDownloadWithTaskId:(NSString *)taskId;

/**暂停所有的下载*/
- (void)pauseAllDownloadTask;

/**删除所有文件*/
- (void)removeAllCache;

/**根据taskid取task*/
- (SSDownloaderTask *)taskForTaskId:(NSString *)taskId;

/**
 是否允许蜂窝煤网络下载，以及网络状态变为蜂窝煤是否允许下载，必须把所有的downloadTask全部暂停，然后重新创建。否则，原先创建的
 下载task依旧在网络切换为蜂窝煤网络时会继续下载
 */
- (void)allowsCellularAccess:(BOOL)isAllow;

/**
 @param handler 后台任务结束后的调用的处理方法
 @param identifier background session 的标识
 */
-(void)addCompletionHandler:(void(^)(void))handler identifier:(NSString *)identifier;

/**保存下载数据*/
- (void)saveDownloadStatus;

@end
