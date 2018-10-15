//
//  SSDownloaderFileManager.h
//  VCoach
//
//  Created by y2ss on 2018/9/3.
//  Copyright © 2018年 c123. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SSDownloaderFileManager : NSObject

//task archive path
+ (NSString *)archiverPath;
//获取downloader默认保存路径
+ (NSString *)defaultSavePath;
//log path
+ (NSString *)loggerPath;
+ (NSString *)loggerDir;
//coral archive path
+ (NSString *)downloadCoralSavePath;
//获取视频文件路径+savename
+ (NSString *)savePathWithSaveName:(NSString *)saveName;
//创建目录
+ (void)createPathIfNotExist:(NSString *)path;

+ (void)writeFile:(NSString *)str toFilePath:(NSString *)filePath;

//获取文件夹下所有文件的大小
+ (long long)folderSizeAtPath:(NSString *)folderPath;
//获取文件的大小
+ (long long)fileSizeAtPath:(NSString *)filePath;
//获取该目录下的所有文件
+ (void)showAllFileWithPath:(NSString *)path actionWithFile:(void(^)(NSString *))action;

+ (void)deleteFile:(NSString *)path;

@end
