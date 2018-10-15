//
//  SSDownloaderCoral.h
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SSDownloaderTask.h"
@class SSDownloaderCoral;

UIKIT_EXTERN NSString * const kDownloadTaskFinishedNoti;
UIKIT_EXTERN NSString * const kDownloadNeedSaveDataNoti;

@protocol SSDownloaderCoralDelegate <NSObject>

@optional
- (void)downloadItemStatusChanged:(SSDownloaderCoral *)item;
- (void)downloadItem:(SSDownloaderCoral *)item downloadedSize:(int64_t)downloadedSize totalSize:(int64_t)totalSize;
- (void)downloadItem:(SSDownloaderCoral *)item speed:(NSUInteger)speed speedDesc:(NSString *)speedDesc;
@end

@interface SSDownloaderCoral : NSObject<SSDownloaderTaskDelegate>

- (instancetype)initWithUrl:(NSString *)url fileId:(NSString *)fileId;
+ (instancetype)itemWithUrl:(NSString *)url fileId:(NSString *)fileId;

@property (nonatomic, strong) NSString *taskId;

#pragma mark - file properties
@property (nonatomic, strong) NSString *fileId;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *thumbImageUrl;
@property (nonatomic, assign) NSUInteger fileSize;
@property (nonatomic, strong) NSString *savePath;
@property (nonatomic, strong) NSString *saveName;
@property (nonatomic, strong) NSString *downloadUrl;
@property (nonatomic, assign) NSUInteger downloadedSize;
@property (nonatomic, assign) SSDownloaderState downloadStatus;

@property (nonatomic, weak) id <SSDownloaderCoralDelegate> delegate;



@end


