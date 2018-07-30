//
//  SSDownloaderCoral.h
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import "SSDownloaderCoral.h"
#import <objc/runtime.h>
#import "SSDownloaderSession.h"

NSString * const kDownloadTaskFinishedNoti = @"kDownloadTaskFinishedNoti";
NSString * const kDownloadNeedSaveDataNoti = @"kDownloadNeedSaveDataNoti";

@implementation SSDownloaderCoral

#pragma mark - init
-(instancetype)initWithUrl:(NSString *)url fileId:(NSString *)fileId {
    
    if (self = [super init]) {
        _downloadUrl = url;
        _fileId = fileId;
        _taskId = [SSDownloaderTask taskIDForUrl:url fileID:fileId];
    }
    return self;
}

+ (instancetype)itemWithUrl:(NSString *)url fileId:(NSString *)fileId {
    return [[SSDownloaderCoral alloc] initWithUrl:url fileId:fileId];
}

- (void)downloadProgress:(SSDownloaderTask *)task downloadedSize:(NSUInteger)downloadedSize fileSize:(NSUInteger)fileSize {
    if ([self.delegate respondsToSelector:@selector(downloadItem:downloadedSize:totalSize:)]) {
        [self.delegate downloadItem:self downloadedSize:downloadedSize totalSize:fileSize];
    }
}

- (void)downloadStatusChanged:(SSDownloaderState)status downloadTask:(SSDownloaderTask *)task {
    
    if ([self.delegate respondsToSelector:@selector(downloadItemStatusChanged:)]) {
        [self.delegate downloadItemStatusChanged:self];
    }
    //通知优先级最后，不与上面的finished重合
    if (status == SSDownloaderStateSuccessed) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDownloadTaskFinishedNoti object:self];
    }
}

- (void)downloadCreated:(SSDownloaderTask *)task {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDownloadNeedSaveDataNoti object:nil userInfo:nil];
}

- (void)downloadTask:(SSDownloaderTask *)task speed:(NSUInteger)speed speedDesc:(NSString *)speedDesc {
    if ([self.delegate respondsToSelector:@selector(downloadItem:speed:speedDesc:)]) {
        [self.delegate downloadItem:self speed:speed speedDesc:speedDesc];
    }
}

#pragma mark - public
- (NSString *)saveName {
    SSDownloaderTask *task = [[SSDownloaderSession shared] taskForTaskId:_taskId];
    return task.saveName;
}

- (NSString *)savePath {
    return [SSDownloaderTask savePathWithSaveName:self.saveName];
}

- (NSUInteger)downloadedSize {
    SSDownloaderTask *task = [[SSDownloaderSession shared] taskForTaskId:_taskId];
    return task.downloadedSize;
}

- (SSDownloaderState)downloadStatus {
    SSDownloaderTask *task = [[SSDownloaderSession shared] taskForTaskId:_taskId];
    return task.downloadStatus;
}

- (void)setDelegate:(id<SSDownloaderCoralDelegate>)delegate {
    _delegate = delegate;
    SSDownloaderTask *task = [[SSDownloaderSession shared] taskForTaskId:_taskId];
    task.delegate = self;
}

- (NSUInteger)fileSize {
    SSDownloaderTask *task = [[SSDownloaderSession shared] taskForTaskId:_taskId];
    return task.fileSize;
}

#pragma mark - private
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super init]) {
        [self decoderWithCoder:coder class:[self class]];
        if (![NSStringFromClass(self.superclass) isEqualToString:NSStringFromClass([NSObject class])]) {
            [self decoderWithCoder:coder class:self.superclass];
        }
    }
    return self;
}

- (void)decoderWithCoder:(NSCoder *)coder class:(Class)cls {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    for (NSInteger i=0; i<count; i++) {
        Ivar ivar = ivars[i];
        NSString *name = [[NSString alloc] initWithUTF8String:ivar_getName(ivar)];
        if([name isEqualToString:@"_delegate"]) continue;
        id value = [coder decodeObjectForKey:name];
        if(value) [self setValue:value forKey:name];
    }
    free(ivars);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [self encodeWithCoder:coder class:[self class]];
    if (![NSStringFromClass(self.superclass) isEqualToString:NSStringFromClass([NSObject class])]) {
        [self encodeWithCoder:coder class:self.superclass];
    }
}

- (void)encodeWithCoder:(NSCoder *)coder class:(Class)cls {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    for (NSInteger i=0; i<count; i++) {
        Ivar ivar = ivars[i];
        NSString *name = [[NSString alloc] initWithUTF8String:ivar_getName(ivar)];
        if([name isEqualToString:@"_delegate"]) continue;
        id value = [self valueForKey:name];
        if(value) [coder encodeObject:value forKey:name];
    }
    free(ivars);
}

@end
