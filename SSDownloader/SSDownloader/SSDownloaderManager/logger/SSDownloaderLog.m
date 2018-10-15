//
//  SSDownloaderLog.m
//  VCoach
//
//  Created by y2ss on 2018/9/3.
//  Copyright © 2018年 c123. All rights reserved.
//

#import "SSDownloaderLog.h"
#import "SSDownloaderFileManager.h"
#import "SSDownloaderTask.h"

#define MAX_CACHE_SIZE (1024 * 1024 * 10)

@interface SSDownloaderLog() {
    dispatch_queue_t _loggerQueue;
}

@property (nonatomic, strong) NSString *filePath;

@end

@implementation SSDownloaderLog

- (instancetype)init {
    if (self = [super init]) {
        _filePath = [SSDownloaderFileManager loggerPath];
        [self clearCacheWithKeepLastTwoWeekIfNeeded];
    }
    return self;
}

//清除缓存只保留最近两周
- (void)clearCacheWithKeepLastTwoWeekIfNeeded {
    NSDate *now = [NSDate date];
    __weak typeof(self)weakself = self;
    if ([SSDownloaderFileManager fileSizeAtPath:[SSDownloaderFileManager loggerDir]] > MAX_CACHE_SIZE) {
        [SSDownloaderFileManager showAllFileWithPath:[SSDownloaderFileManager loggerDir] actionWithFile:^(NSString *fileName) {
            [weakself clearCache:fileName now:now day:14];
        }];
    }
}

- (void)clearCache:(NSString *)fileName now:(NSDate *)now day:(NSInteger)day {
    NSString *time = [fileName componentsSeparatedByString:@"."].firstObject;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    NSDate *date = [formatter dateFromString:time];
    if (!date) { return; }
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comps = [gregorian components:NSCalendarUnitDay fromDate:date toDate:now options:0];
    
    if (comps.day > day) {
        [SSDownloaderFileManager deleteFile:[NSString stringWithFormat:@"%@/%@", [SSDownloaderFileManager loggerPath], fileName]];
    }
}

- (void)logResumeTaskFailedWithTask:(SSDownloaderTask *)task reason:(NSString *)reason funcInfo:(NSString *)funcInfo {
    NSString *str = [NSString stringWithFormat:@"%@,resume task failed, task:%@ error:%@\n", funcInfo, task.description, reason];
    dispatch_async(self.loggerQueue, ^{
        [self writeLog:str];
    });
}

- (void)logResumeTaskWithTask:(SSDownloaderTask *)task funcInfo:(NSString *)funcInfo {
    NSString *str = [NSString stringWithFormat:@"%@,resume task success, task:%@\n", funcInfo, task.description];
    dispatch_async(self.loggerQueue, ^{
        [self writeLog:str];
    });
}

- (void)logNewTaskWithTask:(SSDownloaderTask *)task funcInfo:(NSString *)funcInfo {
    NSString *str = [NSString stringWithFormat:@"%@,create new task, task:%@\n", funcInfo, task.description];
    dispatch_async(self.loggerQueue, ^{
        [self writeLog:str];
    });
}

- (void)logNewTaskAndWaittingWithTask:(SSDownloaderTask *)task waitNum:(NSInteger)waitNum funcInfo:(NSString *)funcInfo {
    NSString *str = [NSString stringWithFormat:@"%@,create new task and waiting,task=%@,waitNum=%zi\n", funcInfo, task.description,  waitNum];
    dispatch_async(self.loggerQueue, ^{
        [self writeLog:str];
    });
}

- (void)logDownloadSuccessWithTask:(SSDownloaderTask *)task funcInfo:(NSString *)funcInfo {
    NSString *str = [NSString stringWithFormat:@"%@,download finish success,task=%@\n", funcInfo, task.description];
    dispatch_async(self.loggerQueue, ^{
        [self writeLog:str];
    });
}

- (void)logDownloadErrorWithTask:(SSDownloaderTask *)task error:(NSError *)error otherReason:(NSString *)reason funcInfo:(NSString *)funcInfo {
    NSString *str = [NSString stringWithFormat:@"%@,download finish error,task=%@ error:%@ reason:%@\n", funcInfo, task.description, error, reason];
    dispatch_async(self.loggerQueue, ^{
        [self writeLog:str];
    });
}

- (void)logPauseWithTask:(SSDownloaderTask *)task funcInfo:(NSString *)funcInfo {
    NSString *str = [NSString stringWithFormat:@"%@,download task pause,task=%@\n", funcInfo, task.description];
    dispatch_async(self.loggerQueue, ^{
        [self writeLog:str];
    });
}

- (void)logDownloadStatus:(NSString *)funcinfo downloadInfo:(NSString *)info {
    NSString *str = [NSString stringWithFormat:@"%@, downloadInfo:%@\n", funcinfo, info];
    dispatch_async(self.loggerQueue, ^{
        [self writeLog:str];
    });
}

- (void)writeLog:(NSString *)log {
    [SSDownloaderFileManager writeFile:log toFilePath:_filePath];
}

- (dispatch_queue_t)loggerQueue {
    if (!_loggerQueue){
        _loggerQueue = dispatch_queue_create("com.SSDownloaderManager.logger.queue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _loggerQueue;
}

@end
