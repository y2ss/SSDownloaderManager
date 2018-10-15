//
//  SSDownloaderMacro.h
//  SSDownloader
//
//  Created by y2ss on 2018/10/15.
//  Copyright © 2018年 y2ss. All rights reserved.
//

#ifndef SSDownloaderMacro_h
#define SSDownloaderMacro_h

#ifdef DEBUG
#define SSLog(format, ...) printf("[%s] %s [第%d行] %s\n", __TIME__, __FUNCTION__, __LINE__, [[NSString stringWithFormat:format, ## __VA_ARGS__] UTF8String]);
#else
#define SSLog(format, ...);
#endif

#define DEVICE_VERSION [[[UIDevice currentDevice] systemVersion] floatValue]

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)


#endif /* SSDownloaderMacro_h */
