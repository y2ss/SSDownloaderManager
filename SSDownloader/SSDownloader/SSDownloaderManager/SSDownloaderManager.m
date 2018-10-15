//
//  SSDownloaderManager.m
//  VCoach
//
//  Created by y2ss on 2018/7/17.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import "SSDownloaderManager.h"
#import "SSDownloaderManager+Push.h"
#import "SSDownloaderFileManager.h"
#import "SSDownloaderMacro.h"

#define SSDownloaderMgr [SSDownloaderManager manager]

@interface SSDownloaderManager () {
    dispatch_semaphore_t _lock;
    dispatch_queue_t _dataQueue;
}

@property (nonatomic, strong) NSMutableDictionary<NSString *, SSDownloaderCoral *> *coralDicts;

@end

@implementation SSDownloaderManager

static id _instance;

#pragma mark - init
+ (instancetype)manager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _pushWhenDownloadSuccessed = NO;
        _lock = dispatch_semaphore_create(1);
        [self setupDownloadData];
        [self registerNotification];
    }
    return self;
}

- (void)setupDownloadData {
    [self getDownloadItems];
    if(!self.coralDicts) {
        self.coralDicts = @{}.mutableCopy;
    }
}

- (void)saveDownloadItems {
    dispatch_async(self.dataQueue, ^{
        Lock();
        [NSKeyedArchiver archiveRootObject:self.coralDicts toFile:[SSDownloaderFileManager downloadCoralSavePath]];
        Unlock();
    });
}

- (void)getDownloadItems {
    NSMutableDictionary *dicts = [NSKeyedUnarchiver unarchiveObjectWithFile:[SSDownloaderFileManager downloadCoralSavePath]];;
    self.coralDicts = dicts;
}

- (void)registerNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveDownloadItems) name:kDownloadStatusChangedNoti object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskFinishedNoti:) name:kDownloadTaskFinishedNoti object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveDownloadItems) name:kDownloadNeedSaveDataNoti object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskSuccessed:) name:kDownloadTaskDidFinished object:nil];
}

#pragma mark - SSDownloaderManager Action
+ (void)setMaxTaskCount:(NSInteger)count {
    [SSDownloaderMgr setMaxTaskCount: count];
}

+ (SSDownloaderTask *)startDownloadWithItem:(SSDownloaderCoral *)item {
    return [SSDownloaderMgr startDownloadWithItem:item];
}

+ (void)startDownloadWithUrl:(NSString *)url fileName:(NSString *)fileName imageUrl:(NSString *)imagUrl{
    [SSDownloaderMgr startDownloadWithUrl:url fileName:fileName imageUrl:imagUrl];
}

+ (void)startDownloadWithUrl:(NSString *)url fileName:(NSString *)fileName imageUrl:(NSString *)imagUrl fileId:(NSString *)fileId{
    [SSDownloaderMgr startDownloadWithUrl:url fileName:fileName imageUrl:imagUrl fileId:fileId];
}

+ (void)pauseDownloadWithItem:(SSDownloaderCoral *)item {
    [SSDownloaderMgr pauseDownloadWithItem:item];
}

+ (void)resumeDownloadWithItem:(SSDownloaderCoral *)item {
    [SSDownloaderMgr resumeDownloadWithItem:item];
}

+ (void)stopDownloadWithItem:(SSDownloaderCoral *)item {
    [SSDownloaderMgr stopDownloadWithItem:item];
}

/**暂停所有的下载*/
+ (void)pauseAllDownloadTask {
    [SSDownloaderMgr pauseAllDownloadTask];
}

+ (void)resumeAllDownloadTask {
    [SSDownloaderMgr resumeAllDownloadTask];
}

+ (void)removeAllCache {
    [SSDownloaderMgr removeAllCache];
}

#pragma mark - Manager Properties
+ (NSArray *)downloadList {
    return [SSDownloaderMgr downloadList];
}
+ (NSArray *)finishList {
    return [SSDownloaderMgr finishList];
}

+ (BOOL)isDownloadWithId:(NSString *)downloadId {
    return [SSDownloaderMgr isDownloadWithId:downloadId];
}

+ (SSDownloaderState)downloasStatusWithId:(NSString *)downloadId {
    return [SSDownloaderMgr downloasStatusWithId:downloadId];
}

+ (SSDownloaderCoral *)downloadItemWithId:(NSString *)downloadId {
    return [SSDownloaderMgr itemWithIdentifier:downloadId];
}

+(void)allowsCellularAccess:(BOOL)isAllow {
    [SSDownloaderMgr allowsCellularAccess:isAllow];
}

#pragma mark - assgin
- (void)setMaxTaskCount:(NSInteger)count {
    [SSDownloaderSession shared].maxTaskCount = (int)count;
}

+ (int64_t)usedVideoCache {
    int64_t size = 0;
    NSArray *downloadList = [self downloadList];
    NSArray *finishList = [self finishList];
    for (SSDownloaderTask *task in downloadList) {
        size += task.downloadedSize;
    }
    for (SSDownloaderTask *task in finishList) {
        size += task.fileSize;
    }
    return size;
}

+ (void)saveDownloadStatus {
    [[SSDownloaderManager manager] saveDownloadItems];
}

#pragma mark - private
- (void)downloadUserChanged {
    [self setupDownloadData];
}

- (SSDownloaderTask *)startDownloadWithItem:(SSDownloaderCoral *)item {
    if (!item) { return nil; }
    SSDownloaderCoral *oldItem = [self itemWithIdentifier:item.taskId];
    if (oldItem.downloadStatus == SSDownloaderStateSuccessed) { return nil; }
    [self.coralDicts setValue:item forKey:item.taskId];
    SSDownloaderTask *task = [[SSDownloaderSession shared] downloadWithURL:item.downloadUrl
                                                                    fileID:item.fileId
                                                                  fileName:item.fileName
                                                                  delegate:item];
    return task;
}

- (void)startDownloadWithUrl:(NSString *)downloadURLString fileName:(NSString *)fileName imageUrl:(NSString *)imagUrl {
    [self startDownloadWithUrl:downloadURLString fileName:fileName imageUrl:imagUrl fileId:nil];
}

//下载文件时候的保存名称，如果没有fileid那么必须 savename = nil
- (NSString *)saveNameForItem:(SSDownloaderCoral *)item {
    NSString *saveName = [item.downloadUrl isEqualToString:item.fileId] ? nil : item.fileId;
    return saveName;
}

- (void)startDownloadWithUrl:(NSString *)downloadURLString fileName:(NSString *)fileName imageUrl:(NSString *)imagUrl fileId:(NSString *)fileId {
    
    if (downloadURLString.length == 0 && fileId.length == 0) { return; }
    NSString *taskId = [SSDownloaderTask taskIDForUrl:downloadURLString fileID:fileId];
    SSDownloaderCoral *item = [self.coralDicts valueForKey:taskId];
    if (!item) {
        item = [[SSDownloaderCoral alloc] initWithUrl:downloadURLString fileId:fileId];
    }
    item.fileName = fileName;
    item.thumbImageUrl = imagUrl;
    //这里设置了delegate
    [self startDownloadWithItem:item];
}

- (void)resumeDownloadWithItem:(SSDownloaderCoral *)item {
    SSDownloaderTask *task = [[SSDownloaderSession shared] taskForTaskId:item.taskId];
    task.delegate = item;
    [[SSDownloaderSession shared] resumeDownloadWithTaskId:item.taskId];
    [self saveDownloadItems];
}

- (void)pauseDownloadWithItem:(SSDownloaderCoral *)item {
    [[SSDownloaderSession shared] pauseDownloadWithTaskId:item.taskId];
    [self saveDownloadItems];
}

- (void)stopDownloadWithItem:(SSDownloaderCoral *)item {
    if (!item)  { return; }
    [[SSDownloaderSession shared] stopDownloadWithTaskId: item.taskId];
    [self.coralDicts removeObjectForKey:item.taskId];
    [self saveDownloadItems];
}

- (void)pauseAllDownloadTask {
    [[SSDownloaderSession shared] pauseAllDownloadTask];
}

- (void)removeAllCache {
    [self.coralDicts.copy enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, SSDownloaderCoral *  _Nonnull obj, BOOL * _Nonnull stop) {
        [self stopDownloadWithItem:obj];
    }];
}

- (void)resumeAllDownloadTask {
    [self.coralDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderCoral *item = obj;
        if (item.downloadStatus == SSDownloaderStatePaused || item.downloadStatus == SSDownloaderStateFailured) {
            [self resumeDownloadWithItem:item];
        }
    }];
}

-(NSArray *)downloadList {
    NSMutableArray *arrM = [NSMutableArray array];
    [self.coralDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderCoral *item = obj;
        if(item.downloadStatus != SSDownloaderStateSuccessed){
            [arrM addObject:item];
        }
    }];
    return arrM;
}

- (NSArray *)finishList {
    NSMutableArray *arrM = [NSMutableArray array];
    [self.coralDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderCoral *item = obj;
        if(item.downloadStatus == SSDownloaderStateSuccessed){
            [arrM addObject:item];
        }
    }];
    return arrM;
}

/**id 可以是downloadUrl，也可以是fileId，首先从fileId开始找，然后downloadUrl*/
- (SSDownloaderCoral *)itemWithIdentifier:(NSString *)identifier {
    __block SSDownloaderCoral *item = [self.coralDicts valueForKey:identifier];
    if (item) { return item; }
    [self.coralDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderCoral *dItem = obj;
        if ([dItem.fileId isEqualToString:identifier]) {
            item = dItem;
            *stop = true;
        }
    }];
    
    if (item) { return item; }
    [self.coralDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        SSDownloaderCoral *dItem = obj;
        if ([dItem.downloadUrl isEqualToString:identifier]) {
            item = dItem;
            *stop = true;
        }
    }];
    return item;
}

-(void)allowsCellularAccess:(BOOL)isAllow {
    [[SSDownloaderSession shared] allowsCellularAccess:isAllow];
}

- (BOOL)isDownloadWithId:(NSString *)downloadId {
    SSDownloaderCoral *item = [self itemWithIdentifier:downloadId];
    return item != nil;
}

- (SSDownloaderState)downloasStatusWithId:(NSString *)downloadId {
    SSDownloaderCoral *item = [self itemWithIdentifier:downloadId];
    if (!item) { return -1; }
    return item.downloadStatus;
}

#pragma mark - notificaton
- (void)downloadTaskFinishedNoti:(NSNotification *)noti{
    [self saveDownloadItems];
}

- (void)downloadTaskSuccessed:(NSNotification *)noti {
    if (_pushWhenDownloadSuccessed) {
        SSDownloaderTask *task = noti.object[@"task"];
        [self pushNotificationWithCourseName:task.fileName];
    }
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - queue
- (dispatch_queue_t)dataQueue {
    if (!_dataQueue) {
        _dataQueue = dispatch_queue_create("com.SSDownloaderManager.data.queue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _dataQueue;
}


@end
