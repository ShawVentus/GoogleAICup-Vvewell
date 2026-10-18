//
//  LogManager.h
//  RingSDK
//
//  Created by Kaoji on 2024/6/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Debug
#define DLog(fmt, ...) [LogManager.sharedManager logMessage:[NSString stringWithFormat:(fmt), ##__VA_ARGS__] level:LogLevelDebug]

// Warning Log
#define WLog(fmt, ...) [LogManager.sharedManager logMessage:[NSString stringWithFormat:(fmt), ##__VA_ARGS__] level:LogLevelWarning]

// Error Log
#define ELog(fmt, ...) [LogManager.sharedManager logMessage:[NSString stringWithFormat:(fmt), ##__VA_ARGS__] level:LogLevelError]

typedef NS_ENUM(NSUInteger, LogLevel) {
    LogLevelDebug,
    LogLevelWarning,
    LogLevelError
};

@interface LogManager : NSObject
@property (nonatomic, assign) BOOL isLoggingEnabled;

+ (instancetype)sharedManager;
- (void)enableLogging;
- (void)disableLogging;
- (void)logMessage:(NSString *)message level:(LogLevel)level;
- (NSString *)logPath;
- (void)clearLogs;
@end

NS_ASSUME_NONNULL_END
