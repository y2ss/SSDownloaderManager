//
//  SSDownloaderSession.m
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import "SSDownloaderSession.h"
#import "SSDownloaderSession+ResumeData.h"
#import "SSDownloaderFileManager.h"
#import "SSDownloaderLog.h"
#import "SSDownloaderMacro.h"

#define __FUNCINFO__ [NSString stringWithFormat:@"[%s] %s [第%d行]", __TIME__, __FUNCTION__, __LINE__]

typedef void(^bgSessionRecreateHandler)(void);
typedef void(^bgCompleteHandler)(void);

static NSString * const kIsAllowCellar = @"kIsAllowCellar";
static NSString * const backgroundIdentifier = @"SS_Downloader_Background";

NSString * const kDownloadTaskPorgressChanged = @"kDownloadPorgressChanged";
NSString * const kDownloadTaskDidFinished = @"kDownloadTaskDidFinished";
NSString * const kDownloadAllTaskFinishedNoti = @"kAllDownloadTaskFinishedNoti";
NSString * const kDownloadStatusChangedNoti = @"kDownloadStatusChangedNoti";

@interface SSDownloaderSession ()<NSURLSessionDownloadDelegate> {

    dispatch_semaphore_t _lock;
    dispatch_queue_t _archieveQueue;
    dispatch_queue_t _speedQueue;
    
    NSTimer *_timer;
}

@property (nonatomic, strong) NSMutableDictionary *downloadTasks;
@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, copy) bgCompleteHandler completeHanlder;
@property (nonatomic, copy) bgSessionRecreateHandler sessionRecreateHanlder;

@property (nonatomic, strong) SSDownloaderLog *logger;

@end

@implementation SSDownloaderSession

static SSDownloaderSession *_instance;

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    if (self = [super init]) {
        //初始化
        _session = [self getDownloadURLSession];
        _maxTaskCount = 1;
        _lock = dispatch_semaphore_create(1);
        [self setupDownloadData];
        //获取背景session正在运行的(app闪退会有任务)
        NSMutableDictionary *dictM = [self.session valueForKey:@"tasks"];
        [dictM enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, NSURLSessionDownloadTask *obj, BOOL * _Nonnull stop) {
            SSDownloaderTask *task = [self getDownloadTaskWithUrl:[SSDownloaderTask getURLFromTask:obj]];
            if(!task){
                SSLog(@"not found task for url, error: %@", [SSDownloaderTask getURLFromTask:obj]);
                [obj cancel];
            } else {
                task.downloadTask = obj;
            }
        }];
        [self registerNotification];
        _logger = [[SSDownloaderLog alloc] init];
    }
    return self;
}

- (void)setupDownloadData {
    [SSDownloaderFileManager createPathIfNotExist:[SSDownloaderFileManager defaultSavePath]];
    //获取之前保存在本地的数据
    _downloadTasks = [NSKeyedUnarchiver unarchiveObjectWithFile:[SSDownloaderFileManager archiverPath]];
    if(!_downloadTasks) {
        _downloadTasks = @{}.mutableCopy;
    }
}

- (void)registerNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (NSURLSession *)getDownloadURLSession {
    NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:backgroundIdentifier];
    sessionConfig.allowsCellularAccess = YES;
    sessionConfig.timeoutIntervalForRequest = 1600;
    sessionConfig.timeoutIntervalForResource = 1600;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    return session;
}

//等session恢复后继续下载任务
- (void)recreateSession {
    _session = [self getDownloadURLSession];
    //恢复正在下载的task状态
    [self.downloadTasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderTask *task = obj;
        task.downloadTask = nil;
        [self resumeDownloadTask:task];
    }];
}

//先暂停所有任务
- (void)prepareRecreateSession {
    [self.downloadTasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderTask *task = obj;
        if (task.downloadTask.state == NSURLSessionTaskStateRunning) {
            [self pauseDownloadTask:task];
        }
    }];
    //该方法会调用didBecomeInvalidWithError
    [_session invalidateAndCancel];
}

-(void)setMaxTaskCount:(int)maxTaskCount {
    if (maxTaskCount>3) {
        _maxTaskCount = 3;
    } else if(maxTaskCount <= 0) {
        _maxTaskCount = 1;
    } else{
        _maxTaskCount = maxTaskCount;
    }
}

//获取现在下载的任务数
- (NSInteger)currentTaskCount {
    NSMutableDictionary *dictM = [self.session valueForKey:@"tasks"];
    __block NSInteger count = 0;
    [dictM enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSURLSessionTask *task = obj;
        if (task.state == NSURLSessionTaskStateRunning) {
            count++;
        }
    }];
    return count;
}

- (void)appWillBecomeActive {
    [self stopTimer];
}

- (void)appWillResignActive {
    [self saveDownloadStatus];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDownloadStatusChangedNoti object:nil];
}

- (void)appWillTerminate {
    [self saveDownloadStatus];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDownloadStatusChangedNoti object:nil];
}


#pragma mark - public
- (SSDownloaderTask *)downloadWithURL:(NSString *)url delegate:(id<SSDownloaderTaskDelegate>)delegate {
    return [self downloadWithURL:url fileID:nil fileName:@"" delegate:delegate];
}

- (SSDownloaderTask *)downloadWithURL:(NSString *)url
                               fileID:(NSString *)fileID
                             fileName:(NSString *)fileName
                             delegate:(id<SSDownloaderTaskDelegate>)delegate {
    if (!url || url.length == 0)  return nil;
    //判断是否是下载完成的任务
    SSDownloaderTask *task = [self.downloadTasks valueForKey:[SSDownloaderTask taskIDForUrl:url fileID:fileID]];
    if ([self isDownloadTaskCompleted:task]) {
        task.delegate = delegate;
        [self downloadStatusChanged:SSDownloaderStateSuccessed task:task];
        return task;
    }
    if (!task) {//文件不存在 新文件
        //判断任务的个数，如果达到最大值则返回，回调等待
        if ([self currentTaskCount] >= self.maxTaskCount) {
            //创建任务，让其处于等待状态
            task = [self createDownloadTaskItemWithUrl:url fileId:fileID fileName:fileName delegate:delegate];
            [self downloadStatusChanged:SSDownloaderStateWaiting task:task];
            
            [_logger logNewTaskAndWaittingWithTask:task waitNum:[self currentTaskCount] funcInfo:__FUNCINFO__];
            return task;
        } else {
            //开始下载
            SSDownloaderTask *task = [self startNewTaskWithUrl:url fileId:fileID fileName:fileName delegate:delegate];
            [_logger logNewTaskWithTask:task funcInfo:__FUNCINFO__];
            return task;
        }
    } else {//文件存在 下载到一半的文件
        task.delegate = delegate;
        [self resumeDownloadTask:task];
        return task;
    }
}

- (void)pauseDownloadWithTask:(SSDownloaderTask *)task {
    [self pauseDownloadTask:task];
}

- (void)resumeDownloadWithTask:(SSDownloaderTask *)task{
    [self resumeDownloadTask:task];
}

- (void)stopDownloadWithTask:(SSDownloaderTask *)task{
    [self stopDownloadWithTaskId:task.taskID];
}

- (void)pauseDownloadWithTaskId:(NSString *)taskId {
   SSDownloaderTask *task = [self.downloadTasks valueForKey:taskId];
    [self pauseDownloadTask:task];
}

- (void)resumeDownloadWithTaskId:(NSString *)taskId{
    SSDownloaderTask *task = [self.downloadTasks valueForKey:taskId];
    [self resumeDownloadTask:task];
}

- (void)stopDownloadWithTaskId:(NSString *)taskId {
    SSDownloaderTask *task = [self.downloadTasks valueForKey:taskId];
    if (task && [[NSFileManager defaultManager] fileExistsAtPath:task.savePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:task.savePath error:nil];
    }
    [task.downloadTask cancel];
    [task stopTimer];
    if (task.taskID.length>0) {
       [self.downloadTasks removeObjectForKey:task.taskID];
    }
    [self saveDownloadStatus];
    [self startNextDownloadTask];
}

- (void)pauseAllDownloadTask {
    [self.downloadTasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, SSDownloaderTask * _Nonnull obj, BOOL * _Nonnull stop) {
        if(obj.downloadStatus == SSDownloaderStateDownloading && obj.downloadTask.state != NSURLSessionTaskStateCompleted){
            [self pauseDownloadTask:obj];
        } else if (obj.downloadStatus == SSDownloaderStateWaiting){
            [self downloadStatusChanged:SSDownloaderStatePaused task:obj];
        }
    }];
}

- (void)removeAllCache {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self pauseAllDownloadTask];
        [self.downloadTasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, SSDownloaderTask *  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:obj.savePath]) {
                [[NSFileManager defaultManager] removeItemAtPath:obj.savePath error:nil];
            }
        }];
        [self.downloadTasks removeAllObjects];
        [self saveDownloadStatus];
    });
}

- (SSDownloaderTask *)taskForTaskId:(NSString *)taskId {
    SSDownloaderTask *task = [self.downloadTasks valueForKey:taskId];
    return task;
}

- (void)allowsCellularAccess:(BOOL)isAllow {
    [[NSUserDefaults standardUserDefaults] setBool:isAllow forKey:kIsAllowCellar];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self prepareRecreateSession];
}

-(void)addCompletionHandler:(void(^)(void))handler identifier:(NSString *)identifier {
    if ([identifier isEqualToString:backgroundIdentifier]) {
        self.completeHanlder = handler;
        [self startTimer];
    }
}

#pragma mark - 
//获取新的task
- (NSURLSessionDownloadTask *)downloadTaskWithUrl:(NSString *)url {
    NSURL *downloadURL = [NSURL URLWithString:url];
    NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL];
    return [self.session downloadTaskWithRequest:request];
}

//创建新的任务
- (SSDownloaderTask *)startNewTaskWithUrl:(NSString *)downloadURLString
                                   fileId:(NSString *)fileId
                                 fileName:(NSString *)fileName
                                 delegate:(id<SSDownloaderTaskDelegate>)delegate {
    
    NSURLSessionDownloadTask *downloadTask = [self downloadTaskWithUrl:downloadURLString];
    SSDownloaderTask *task = [self createDownloadTaskItemWithUrl:downloadURLString fileId:fileId fileName:fileName delegate:delegate];
    SSLog(@"%@", task);
    task.downloadTask = downloadTask;
    [downloadTask resume];
    [self downloadStatusChanged:SSDownloaderStateDownloading task:task];
    return task;
}

- (SSDownloaderTask *)createDownloadTaskItemWithUrl:(NSString *)downloadURLString
                                             fileId:(NSString *)fileId
                                           fileName:(NSString *)fileName
                                           delegate:(id<SSDownloaderTaskDelegate>)delegate {
    
    SSDownloaderTask *task = [SSDownloaderTask taskWithUrl:downloadURLString fileId:fileId fileName:fileName delegate:delegate];
    task.delegate = delegate;
    [self.downloadTasks setObject:task forKey:task.taskID];
    [self downloadStatusChanged:SSDownloaderStateWaiting task:task];
    return task;
}

- (void)pauseDownloadTask:(SSDownloaderTask *)task{
    //暂停逻辑在这里处理 - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
    if (task.downloadTask) {
        [task.downloadTask cancelByProducingResumeData:^(NSData * resumeData) { }];
    } else {
        task.downloadStatus = SSDownloaderStatePaused;
        [self downloadStatusChanged:SSDownloaderStatePaused task:task];
    }
}

//重新下载文件
- (void)resumeDownloadTask:(SSDownloaderTask *)task {
    if (!task) { return; }
    if ([self isDownloadTaskCompleted:task]) {
        [self downloadStatusChanged:SSDownloaderStateSuccessed task:task];
        return;
    }
    if (([self currentTaskCount] >= self.maxTaskCount) && task.downloadStatus != SSDownloaderStateDownloading) {
        [self downloadStatusChanged:SSDownloaderStateWaiting task:task];
        return;
    }
    
    NSData *data = task.resumeData;
    if (data.length > 0) {//下载到一半
        if(task.downloadTask && task.downloadTask.state == NSURLSessionTaskStateRunning){
            [self downloadStatusChanged:SSDownloaderStateDownloading task:task];
            return;
        }
        NSURLSessionDownloadTask *downloadTask = nil;
        @try {
            downloadTask = [SSDownloaderSession downloadTaskWithCorrectResumeData:data urlSession:self.session];
        } @catch (NSException *exception) {
            SSLog(@"%@", exception.reason);
            [_logger logResumeTaskFailedWithTask:task reason:exception.reason funcInfo:__FUNCINFO__];
            [self downloadStatusChanged:SSDownloaderStateFailured task:task];
            return;
        }
        task.downloadTask = downloadTask;
        [downloadTask resume];
        task.resumeData = nil;
        [_logger logResumeTaskWithTask:task funcInfo:__FUNCINFO__];
        [self downloadStatusChanged:SSDownloaderStateDownloading task:task];
    } else {//新任务
        if (!task.downloadTask || task.downloadTask.state == NSURLSessionTaskStateCompleted || task.downloadTask.state == NSURLSessionTaskStateCanceling) {
            [task.downloadTask cancel];
            NSURLSessionDownloadTask *downloadTask = [self downloadTaskWithUrl:task.downloadURL];
            task.downloadTask = downloadTask;
            [downloadTask resume];
        }
        [task.downloadTask resume];
        [_logger logNewTaskWithTask:task funcInfo:__FUNCINFO__];
        [self downloadStatusChanged:SSDownloaderStateDownloading task:task];
    }
}

- (void)startNextDownloadTask {
    if ([self currentTaskCount] < self.maxTaskCount) {
        [self.downloadTasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            SSDownloaderTask *task = obj;
            if ((!task.downloadTask || task.downloadTask.state != NSURLSessionTaskStateRunning) && task.downloadStatus == SSDownloaderStateWaiting) {
                [self resumeDownloadTask:task];
            }
        }];
    }
}

- (void)downloadStatusChanged:(SSDownloaderState)status task:(SSDownloaderTask *)task {
    task.downloadStatus = status;
    [self saveDownloadStatus];
    if ([task.delegate respondsToSelector:@selector(downloadStatusChanged:downloadTask:)]) {
        [task.delegate downloadStatusChanged:status downloadTask:task];
    }
    NSDictionary *info = task ? @{@"task":task} : @{};
    [[NSNotificationCenter defaultCenter] postNotificationName:kDownloadStatusChangedNoti object:info];
    if (status == SSDownloaderStateSuccessed) {
      [self startNextDownloadTask];
    }
}

- (BOOL)allTaskFinised {
    if (self.downloadTasks.count == 0) { return true; }
    __block BOOL isFinished = true;
    [self.downloadTasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderTask *task = obj;
        if (task.downloadStatus == SSDownloaderStateWaiting || task.downloadStatus == SSDownloaderStateDownloading) {
            isFinished = false;
            *stop = true;
        }
    }];
    return isFinished;
}

- (void)saveDownloadStatus {
    dispatch_async(self.archieveQueue, ^{
        Lock();
        [NSKeyedArchiver archiveRootObject:self.downloadTasks toFile:[SSDownloaderFileManager archiverPath]];
        Unlock();
    });
    //[_logger logDownloadStatus:__FUNCINFO__ downloadInfo:self.downloadTasks.description];
}

//判断是否下载完成
- (BOOL)isDownloadTaskCompleted:(SSDownloaderTask *)task {
    if (!task) { return false; }
    if (task.downloadFinished) { return true; }
    NSArray *tmpPaths = [self getTmpPathsWithTask:task];

    __block BOOL isFinished = false;
    [tmpPaths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *path = obj;
        int64_t fileSize = [SSDownloadUtils fileSizeWithPath:path];
        if (fileSize > 0 && fileSize == task.fileSize) {
            [[NSFileManager defaultManager] moveItemAtPath:path toPath:task.savePath error:nil];
            isFinished = true;
            task.downloadStatus = SSDownloaderStateSuccessed;
            *stop = true;
        }
    }];
    return isFinished;
}

- (NSArray *)getTmpPathsWithTask:(SSDownloaderTask *)task {
    if(!task) { return nil; }
    NSMutableArray *tmpPaths = [NSMutableArray array];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    //download finish callback -> locationString
    if (task.tempPath.length > 0 && [fileMgr fileExistsAtPath:task.tempPath]) {
        [tmpPaths addObject:task.tempPath];
    } else {
        task.tempPath = nil;
    }
    if (task.tmpName.length > 0) {
        NSString *downloadPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true).firstObject;
        NSString *bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        //系统正在下载的文件tmp文件存储路径和部分异常的tmp文件(回调失败)
        downloadPath = [downloadPath stringByAppendingPathComponent: [NSString stringWithFormat:@"/com.apple.nsurlsessiond/Downloads/%@/", bundleId]];
        downloadPath = [downloadPath stringByAppendingPathComponent:task.tmpName];
        if ([fileMgr fileExistsAtPath:downloadPath]) {
            [tmpPaths addObject:downloadPath];
        }
        //暂停下载后，系统从 downloadPath 目录移动到此
        NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:task.tmpName];
        if ([fileMgr fileExistsAtPath:tmpPath]) {
            [tmpPaths addObject:tmpPath];
        }
    }
    if (tmpPaths.count == 0) { task.tmpName = nil; }
    return tmpPaths;
}


- (SSDownloaderTask *)getDownloadTaskWithUrl:(NSString *)downloadUrl {
    NSMutableDictionary *tasks = self.downloadTasks;
    __block SSDownloaderTask *task = nil;
    [tasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderTask *dTask = obj;
        if ([dTask.downloadURL isEqualToString:downloadUrl]) {
            task = dTask;
            *stop = true;
        }
    }];
    return task;
}

- (SSDownloaderTask *)getDownloadTaskWithIdentifier:(NSInteger)identifier {
    NSMutableDictionary *tasks = self.downloadTasks;
    __block SSDownloaderTask *task = nil;
    [tasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderTask *dTask = obj;
        if (dTask.downloadTask.taskIdentifier == identifier) {
            task = dTask;
            *stop = YES;
        }
    }];
    return task;
}

#pragma mark - timer
- (void)startTimer {
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerRun) userInfo:nil repeats:true];
    } else {
        [_timer fire];
    }
}

- (void)stopTimer {
    [_timer invalidate];
    _timer = nil;
}

- (void)timerRun {
    //backgroundTimeRemaining: 还剩下多少后台时间
    if ([UIApplication sharedApplication].backgroundTimeRemaining < 15 && !self.sessionRecreateHanlder) {
        __weak typeof(self) weakSelf = self;
        _sessionRecreateHanlder = ^{
            __strong typeof(self) strongSelf = weakSelf;
            if ([strongSelf.delegate respondsToSelector:@selector(backgroundDidFinishedAllTask)]) {
                [strongSelf.delegate backgroundDidFinishedAllTask];
            }
            [weakSelf stopTimer];
        };
        [self prepareRecreateSession];
    }
}

//completionHandler:在后台下载任务完成后App被唤醒执行相关操作后，继续回归休眠状态，节约系统资源。
- (void)callBgCompletedHandler {
    if (self.completeHanlder) {
        self.completeHanlder();
        self.completeHanlder = nil;
    }
}

#pragma mark -  NSURLSessionDownloadDelegate
//session将要废弃
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    SSLog(@"session did beconmeInvalid")
    [self recreateSession];
    if (self.sessionRecreateHanlder) {
        self.sessionRecreateHanlder();
        self.sessionRecreateHanlder = nil;
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSString *locationString = [location path];
    NSError *error;

    NSString *downloadUrl = [SSDownloaderTask getURLFromTask:downloadTask];
    SSDownloaderTask *task = [self getDownloadTaskWithUrl:downloadUrl];
    if (!task) {
        SSLog(@"Download Finished task is null error! url: %@", downloadUrl);
        [_logger logDownloadErrorWithTask:task error:downloadTask.error otherReason:@"task is nill" funcInfo:__FUNCINFO__];
        return;
    }
    task.tempPath = locationString;
    int64_t fileSize = [SSDownloadUtils fileSizeWithPath:locationString];
    //校验文件大小
    if (task.fileSize == 0) {
        task.downloadTask = downloadTask;
        [task updateFileSize];
    }
    BOOL isCompltedFile = (fileSize > 0) && (fileSize == task.fileSize);
    //文件大小不对，回调失败
    if (!isCompltedFile) {
        [self downloadStatusChanged:SSDownloaderStateFailured task:task];
        //删除异常的缓存文件
        [[NSFileManager defaultManager] removeItemAtPath:locationString error:nil];
        SSLog(@"Download Finished Error: file size error");
        [_logger logDownloadErrorWithTask:task error:downloadTask.error otherReason:@"file size error" funcInfo:__FUNCINFO__];
        return;
    }
    task.downloadedSize = task.fileSize;
    task.downloadTask = nil;
    [[NSFileManager defaultManager] moveItemAtPath:locationString toPath:task.savePath error:&error];
    [self.downloadTasks setValue:task forKey:task.taskID];
    [self downloadStatusChanged:SSDownloaderStateSuccessed task:task];
    [_logger logDownloadSuccessWithTask:task funcInfo:__FUNCINFO__];
    //URLSessionDidFinishEventsForBackgroundURLSession 方法在后台执行一次，所以在此判断执行completedHandler
    if ([self allTaskFinised]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDownloadAllTaskFinishedNoti object:nil];
        //所有的任务执行结束之后调用completedHanlder
        [self callBgCompletedHandler];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
    /**这里获取task时不应该用url判断 因为有可能同时下载同一个url 应该用task identifier**/
    //SSDownloaderTask *task = [self getDownloadTaskWithUrl:[SSDownloaderTask getURLFromTask:downloadTask]];
    SSDownloaderTask *task = [self getDownloadTaskWithIdentifier:downloadTask.taskIdentifier];
    task.downloadedSize = (NSInteger)totalBytesWritten;
    if (task.fileSize == 0)  {//task第一次接受数据的时候
        [task updateFileSize];
        if ([task.delegate respondsToSelector:@selector(downloadCreated:)]) {
            [task.delegate downloadCreated:task];
        }
        [self saveDownloadStatus];
    }
    if([task.delegate respondsToSelector:@selector(downloadProgress:downloadedSize:fileSize:)]){
        [task.delegate downloadProgress:task downloadedSize:task.downloadedSize fileSize:task.fileSize];
    }
    if (task) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDownloadTaskPorgressChanged
                                                            object:@{
                                                                     @"task":task,
                                                                     @"downloadSize":@(task.downloadedSize),
                                                                     @"fileSize":@(task.fileSize)
                                                                     }];
        dispatch_async(self.speedQueue, ^{
            [task downloadedSize:task.downloadedSize fileSize:task.fileSize];
        });
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    SSDownloaderTask *yctask = [self getDownloadTaskWithUrl:[SSDownloaderTask getURLFromTask:task]];
    if (error) {
        NSData *resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
        if (resumeData) {
            if (DEVICE_VERSION >= 11.0f && DEVICE_VERSION < 11.2f) {
                resumeData = [SSDownloaderSession cleanResumeData:resumeData];
            }
            //通过之前保存的resumeData，获取断点的NSURLSessionTask，调用resume恢复下载
            yctask.resumeData = resumeData;
            id resumeDataObj = [NSPropertyListSerialization propertyListWithData:resumeData options:0 format:0 error:nil];
            if ([resumeDataObj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *resumeDict = resumeDataObj;
                yctask.tmpName = [resumeDict valueForKey:@"NSURLSessionResumeInfoTempFileName"];
            }
            yctask.resumeData = resumeData;
            yctask.downloadTask = nil;
            [self saveDownloadStatus];
            [self downloadStatusChanged:SSDownloaderStatePaused task:yctask];
            [_logger logPauseWithTask:yctask funcInfo:__FUNCINFO__];
        } else {
            SSLog(@"didCompleteWithError : %@",error);
            [_logger logDownloadErrorWithTask:yctask error:error otherReason:@"" funcInfo:__FUNCINFO__];
            [self downloadStatusChanged:SSDownloaderStateFailured task:yctask];
        }
    } else {
        NSNotification *noti = [NSNotification notificationWithName:kDownloadTaskDidFinished object:@{@"task":yctask}];
        [[NSNotificationCenter defaultCenter] postNotification:noti];
    }
    [_logger logDownloadSuccessWithTask:yctask funcInfo:__FUNCINFO__];
    [self startNextDownloadTask];
}

#pragma mark queue
- (dispatch_queue_t)archieveQueue {
    if (!_archieveQueue) {
        _archieveQueue = dispatch_queue_create("com.SSDownloaderManager.archieve.queue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _archieveQueue;
}

- (dispatch_queue_t)speedQueue {
    if (!_speedQueue) {
        _speedQueue = dispatch_queue_create("com.SSDownloaderManager.speed.queue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _speedQueue;
}


@end
