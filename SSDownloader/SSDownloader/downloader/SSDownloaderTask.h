//
//  SSDownloaderTask.h
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SSDownloaderTask;

typedef NS_ENUM(NSUInteger, SSDownloaderState) {
    SSDownloaderStateNone,
    SSDownloaderStateDownloading,
    SSDownloaderStateSuccessed,
    SSDownloaderStateFailured,
    SSDownloaderStateWaiting,
    SSDownloaderStatePaused
};

/**某一任务下载的状态发生变化的通知*/
extern NSString * const kDownloadStatusChangedNoti;

@protocol SSDownloaderTaskDelegate <NSObject>
@optional

/**下载任务第一次创建的时候的回调*/
- (void)downloadCreated:(SSDownloaderTask *)task;

/**
 下载任务的进度回调方法
 @param downloadedSize 已经下载的文件大小
 @param fileSize 文件实际大小
 */
- (void)downloadProgress:(SSDownloaderTask *)task downloadedSize:(NSUInteger)downloadedSize fileSize:(NSUInteger)fileSize;

/**
 下载任务的网速回调
 @param speed float类型的速度
 @param speedDesc 附加单位的速度回调
 */
- (void)downloadTask:(SSDownloaderTask *)task speed:(NSUInteger)speed speedDesc:(NSString *)speedDesc;

/**下载的任务的状态发生改变的回调*/
- (void)downloadStatusChanged:(SSDownloaderState)status downloadTask:(SSDownloaderTask *)task;

@end


@interface SSDownloaderTask : NSObject

@property (nonatomic, copy, readonly) NSString *taskID;
@property (nonatomic, copy, readonly) NSString *downloadURL;
/**文件标识，可以为空。要想同- downloadURL文件重复下载，可以让fileId不同*/
@property (nonatomic, copy, readonly) NSString *fileId;
@property (nonatomic, strong) NSData *resumeData;
@property (nonatomic, assign) SSDownloaderState downloadStatus;
/**文件本地存储名称*/
@property (nonatomic, copy) NSString *saveName;
/**下载文件的存储路径，没有下载完成时，该路径下没有文件*/
@property (nonatomic, copy) NSString *savePath;
/**判断文件是否下载完成，savePath路径下存在该文件为true，否则为false*/
@property (nonatomic, assign, readonly) BOOL downloadFinished;
@property (nonatomic, assign, readonly) NSInteger fileSize;
@property (nonatomic, assign) NSInteger downloadedSize;

/** resumeData tmp name */
@property (nonatomic, copy) NSString *tmpName;
@property (nonatomic, copy) NSString *tempPath;
@property (nonatomic, weak) id <SSDownloaderTaskDelegate>delegate;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;

/**
 初始化一个下载任务
 @param fileId 下载文件的标识,可以为nil。可下载同一个url文件通过让fileId不同;下同
 */
- (instancetype)initWithUrl:(NSString *)url fileId:(NSString *)fileId delegate:(id<SSDownloaderTaskDelegate>)delegate;

+ (instancetype)taskWithUrl:(NSString *)url fileId:(NSString *)fileId delegate:(id<SSDownloaderTaskDelegate>)delegate;

/**保存文件大小*/
- (void)updateFileSize;

/**继续下载任务*/
- (void)resume;

/**暂停下载任务*/
- (void)pause;

/**删除下载任务*/
- (void)remove;

- (void)downloadedSize:(NSUInteger)downloadedSize fileSize:(NSUInteger)fileSize;

/**
 根据NSURLSessionTask获取下载的url
 */
+ (NSString *)getURLFromTask:(NSURLSessionTask *)task;

/**根据文件的名称获取文件的沙盒存储路径*/
+ (NSString *)savePathWithSaveName:(NSString *)saveName;

/**
 生成taskid
 @param fileId 资源标识，可以为空
 @return taskid
 */
+ (NSString *)taskIDForUrl:(NSString *)url fileID:(NSString *)fileId;


@end




