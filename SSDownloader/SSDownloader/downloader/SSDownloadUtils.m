//
//  SSDownloadUtils.m
//  VCoach
//
//  Created by y2ss on 2018/7/16.
//  Copyright © 2018年 iwown. All rights reserved.
//

#import "SSDownloadUtils.h"
#import <CommonCrypto/CommonDigest.h>

#define GB (1024 * 1024 * 1024)
#define MB (1024 * 1024)
#define KB 1024

@implementation SSDownloadUtils

+ (NSUInteger)fileSystemFreeSize {
    NSUInteger totalFreeSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedIntegerValue];
    }
    return totalFreeSpace;
}
+ (NSString *)fileSizeStringFromBytes:(NSUInteger)byteSize {
    if (GB <= byteSize) {
        return [NSString stringWithFormat:@"%@GB", [self numberStringFromDouble:(double)byteSize / GB]];
    }
    if (MB <= byteSize) {
        return [NSString stringWithFormat:@"%@MB", [self numberStringFromDouble:(double)byteSize / MB]];
    }
    if (KB <= byteSize) {
        return [NSString stringWithFormat:@"%@KB", [self numberStringFromDouble:(double)byteSize / KB]];
    }
    return [NSString stringWithFormat:@"%luB", (unsigned long)byteSize];
}

+ (NSString *)numberStringFromDouble:(const double)num {
    NSInteger section = round((num - (NSInteger)num) * 100);
    if (section % 10) {
        return [NSString stringWithFormat:@"%.2f", num];
    }
    if (section > 0) {
        return [NSString stringWithFormat:@"%.1f", num];
    }
    return [NSString stringWithFormat:@"%.0f", num];
}

+ (NSString *)md5ForString:(NSString *)string {
    const char *str = [string UTF8String];
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *md5Result = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                           r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
    return md5Result;
}

+ (void)createPathIfNotExist:(NSString *)path {
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:true attributes:nil error:nil];
    }
}

+ (int64_t)fileSizeWithPath:(NSString *)path {
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return 0;
    }
    NSDictionary *dic = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return dic ? [dic fileSize] : 0;
}

@end
