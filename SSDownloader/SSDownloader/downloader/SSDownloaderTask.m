//
//  SSDownloaderTask.m
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import "SSDownloaderTask.h"
#import <objc/runtime.h>
#import "SSDownloaderSession.h"

NSString * const kDownloadStatusChangedNoti = @"kDownloadStatusChangedNoti";

@interface SSDownloaderTask()
{
    NSString *_saveName;
    NSUInteger _preDownloadedSize;
}

@property (nonatomic, strong) NSTimer *timer;
@end

@implementation SSDownloaderTask

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

- (instancetype)initWithUrl:(NSString *)url fileId:(NSString *)fileId delegate:(id<SSDownloaderTaskDelegate>)delegate {
    
    if(self = [super init]){
        _downloadURL = url;
        _fileId = fileId;
        _delegate = delegate;
    }
    return self;
}

+ (instancetype)taskWithUrl:(NSString *)url fileId:(NSString *)fileId delegate:(id<SSDownloaderTaskDelegate>)delegate {
    return [[SSDownloaderTask alloc] initWithUrl:url fileId:fileId delegate:delegate];
}

#pragma mark - public
//更新taskdata
- (void)updateFileSize {
    _fileSize = (NSInteger)[_downloadTask.response expectedContentLength];
}

- (void)resume {
    [[SSDownloaderSession shared] resumeDownloadWithTask:self];
}

- (void)pause {
    [[SSDownloaderSession shared] pauseDownloadWithTask:self];
    if (self.timer) {
        [self stopTimer];
    }
}

- (void)remove {
    [[SSDownloaderSession shared] stopDownloadWithTask:self];
    if (self.timer) {
        [self stopTimer];
    }
}

- (void)downloadedSize:(NSUInteger)downloadedSize fileSize:(NSUInteger)fileSize {
    _downloadedSize = downloadedSize;
    if (!self.timer && self.delegate) {
        [self startTimer];
    }
}

#pragma mark - setter
- (void)setDownloadTask:(NSURLSessionDownloadTask *)downloadTask {
    _downloadTask = downloadTask;
}

//保存task下载的state
-(void)setDownloadStatus:(SSDownloaderState)downloadStatus {
    _downloadStatus = downloadStatus;
    if(self.timer && (downloadStatus == SSDownloaderStatePaused || downloadStatus == SSDownloaderStateFailured || downloadStatus == SSDownloaderStateSuccessed)) {
        [self stopTimer];
    }
}

#pragma mark - getter
-(NSString *)taskID {
    return [SSDownloaderTask taskIDForUrl:self.downloadURL fileID:self.fileId];
}

- (NSString *)savePath {
    //有路径则使用路径
    if (_savePath.length>0) {
        return _savePath;
    }
    //没有路径返回默认路径
    return [SSDownloaderTask savePathWithSaveName:self.saveName];
}

-(BOOL)downloadFinished {
    NSDictionary *dic = [[NSFileManager defaultManager] attributesOfItemAtPath:self.savePath error:nil];
    NSInteger fileSize = dic ? (NSInteger)[dic fileSize] : 0;
    return [[NSFileManager defaultManager] fileExistsAtPath:self.savePath] && (fileSize == self.fileSize);
}

- (NSString *)saveName {
    if (_saveName.length==0) {
        NSString *name = [SSDownloaderTask taskIDForUrl:self.downloadURL fileID:self.fileId];
        NSString *pathExtension =  [SSDownloaderTask getPathExtensionWithUrl:self.downloadURL];
        name = pathExtension.length > 0 ? [name stringByAppendingPathExtension:pathExtension] : name;
        return name;
    }
    return _saveName;
}

- (void)setSaveName:(NSString *)saveName {
    _saveName = saveName;
    [[SSDownloaderSession shared] saveDownloadStatus];
}

//获取taskID的md5值
+ (NSString *)taskIDForUrl:(NSString *)url fileID:(NSString *)fileId {
    NSString *name = [SSDownloadUtils md5ForString:fileId.length > 0 ? [NSString stringWithFormat:@"%@_%@",url, fileId] : url];
    return name;
}

//获取保持文件路径
+ (NSString *)savePathWithSaveName:(NSString *)saveName {
    NSString *saveDir = [self saveDir];
    saveDir = [saveDir stringByAppendingPathComponent:saveName];
    return saveDir;
}

//获取保存文件夹路径
+ (NSString *)saveDir {
    NSString *saveDir = [SSDownloaderSession defaultSavePath];
    saveDir = [saveDir stringByAppendingPathComponent:@"video"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:saveDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:saveDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return saveDir;
}

//获取url地址
+ (NSString *)getURLFromTask:(NSURLSessionTask *)task {
    //301/302定向的originRequest和currentRequest的url不同
    NSString *url = nil;
    NSURLRequest *req = [task originalRequest];
    url = req.URL.absoluteString;
    url = [task currentRequest].URL.absoluteString;
    return url;
}

#pragma mark - private
- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerCall) userInfo:nil repeats:true];
    [self.timer fire];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] run];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)timerCall {
    NSUInteger speed = _downloadedSize - _preDownloadedSize;
    _preDownloadedSize = _downloadedSize;
    if ([self.delegate respondsToSelector:@selector(downloadTask:speed:speedDesc:)]) {
        [self.delegate downloadTask:self speed:speed speedDesc:[NSString stringWithFormat:@"%@/s",[SSDownloadUtils fileSizeStringFromBytes:speed]]];
    }
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super init]) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList([self class], &count);
        for (NSInteger i=0; i<count; i++) {
            Ivar ivar = ivars[i];
            NSString *name = [[NSString alloc] initWithUTF8String:ivar_getName(ivar)];
            if ([name isEqualToString:@"_downloadTask"] || [name isEqualToString:@"_delegate"] || [name isEqualToString:@"_timer"]) continue;
            id value = [coder decodeObjectForKey:name];
            if(value) [self setValue:value forKey:name];
        }
        free(ivars);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    for (NSInteger i=0; i<count; i++) {
        
        Ivar ivar = ivars[i];
        NSString *name = [[NSString alloc] initWithUTF8String:ivar_getName(ivar)];
        if ([name isEqualToString:@"_downloadTask"] || [name isEqualToString:@"_delegate"] || [name isEqualToString:@"_timer"]) continue;
        id value = [self valueForKey:name];
        if(value) [coder encodeObject:value forKey:name];
    }
    free(ivars);
}

//获取文件扩展名 eg: .mp4 .dmg
+ (NSString *)getPathExtensionWithUrl:(NSString *)url {
    //过滤url中的参数，取出单独文件名
    NSRange range = [url rangeOfString:@"?"];
    if (range.location != NSNotFound) {
        url = [url substringToIndex:range.location];
    }
    return url.pathExtension;
}

-(void)dealloc {
    [self stopTimer];
}

@end




