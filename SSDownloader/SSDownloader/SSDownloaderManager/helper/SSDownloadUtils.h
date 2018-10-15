//
//  SSDownloadUtils.h
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SSDownloadUtils : NSObject

/**获取手机空闲磁盘空间*/
+ (NSUInteger)fileSystemFreeSize;

/**将文件的字节大小转换成KB，MB，GB*/
+ (NSString *)fileSizeStringFromBytes:(NSUInteger)byteSize;


+ (NSString *)md5ForString:(NSString *)string;

/**获取文件大小*/
+ (int64_t)fileSizeWithPath:(NSString *)path;

+ (NSString *)iphoneType;

@end
