//
//  SSDownloaderFileManager.m
//  VCoach
//
//  Created by y2ss on 2018/9/3.
//  Copyright © 2018年 c123. All rights reserved.
//

#import "SSDownloaderFileManager.h"
#import "SSDownloadUtils.h"
#import "SSDownloaderMacro.h"
#import <UIKit/UIKit.h>

@implementation SSDownloaderFileManager

//默认archive路径
+ (NSString *)archiverPath {
    NSString *saveDir = [self defaultSavePath];
    saveDir = [saveDir stringByAppendingPathComponent:@"SSCoral.db"];
    return saveDir;
}

//log path
+ (NSString *)loggerPath {
    
   
    NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    NSString *logDir = [self loggerDir];
    NSString *path = [NSString stringWithFormat:@"%@/%@.txt", logDir, [formatter stringFromDate:[NSDate date]]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createFileAtPath:path contents:nil attributes:nil];
        NSString *type = [NSString stringWithFormat:@"手机型号:%@,版本:%@\n", [SSDownloadUtils iphoneType], [UIDevice currentDevice].systemVersion];
        [self writeFile:type toFilePath:path];
    }
    return path;
}

//获取默认保存路径目录
+ (NSString *)defaultSavePath {
    NSString *saveDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    saveDir = [saveDir stringByAppendingPathComponent:@"SSDownload"];
    [self createPathIfNotExist:saveDir];
    return saveDir;
}

//coral archive path
+ (NSString *)downloadCoralSavePath {
    NSString *saveDir = [self defaultSavePath];
    return [saveDir stringByAppendingFormat:@"/video/_saveCorals.data"];
}

//logger dir
+ (NSString *)loggerDir {
    NSString *logDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    logDir = [logDir stringByAppendingPathComponent:@"SSDownloader"];
    [self createPathIfNotExist:logDir];
    
    logDir = [logDir stringByAppendingPathComponent:@"log"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:logDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return logDir;
}

+ (void)createPathIfNotExist:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

//获取保存文件夹路径
+ (NSString *)saveDir {
    NSString *saveDir = [self defaultSavePath];
    saveDir = [saveDir stringByAppendingPathComponent:@"video"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:saveDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:saveDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return saveDir;
}

//获取视频文件路径+savename
+ (NSString *)savePathWithSaveName:(NSString *)saveName {
    NSString *saveDir = [SSDownloaderFileManager saveDir];
    saveDir = [saveDir stringByAppendingPathComponent:saveName];
    return saveDir;
}

+ (void)writeFile:(NSString *)str toFilePath:(NSString *)filePath {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    [fileHandle seekToEndOfFile];  // 将节点跳到文件的末尾
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    [fileHandle writeData:data]; //追加写入数据
    [fileHandle closeFile];
}

//获取文件夹下所有文件的大小
+ (long long)folderSizeAtPath:(NSString *)folderPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:folderPath]) return 0;
    NSEnumerator *filesEnumerator = [[fileManager subpathsAtPath:folderPath] objectEnumerator];
    NSString *fileName;
    long long folerSize = 0;
    while ((fileName = [filesEnumerator nextObject]) != nil) {
        NSString *filePath = [folderPath stringByAppendingPathComponent:fileName];
        folerSize += [self fileSizeAtPath:filePath];
    }
    return folerSize;
}

//获取文件的大小
+ (long long)fileSizeAtPath:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        return 0;
    } else {
        return [[fileManager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
}

//获取目录下的所有文件
+ (void)showAllFileWithPath:(NSString *)path actionWithFile:(void(^)(NSString *))action {
    NSFileManager *fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        if (isDir) {
            NSArray *dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
            NSString *subPath = nil;
            for (NSString *str in dirArray) {
                subPath  = [path stringByAppendingPathComponent:str];
                BOOL issubDir = NO;
                [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                [self showAllFileWithPath:subPath actionWithFile:action];
            }
        } else {
            NSString *fileName = [[path componentsSeparatedByString:@"/"] lastObject];
            if (action) {
                action(fileName);
            }
        }
    }
}

+ (void)deleteFile:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:path error:nil];
}

@end
