//
//  BTAudioManager.h
//  RingSDK
//
//  Created by 黄建华 on 2025/11/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//下载文件枚举
typedef NS_ENUM(NSInteger, BLEReceiveStatus) {
    BLEReceiveStatusStart = 1,         // 开始接收 可能文件可能有 单个 多个
    BLEReceiveStatusFailed = 2,        // 接收失败 某一次的请求失败或者堵塞
    BLEReceiveStatusSingleSuccess = 3, // 某个录音文件接收成功
    BLEReceiveStatusAllSuccess = 4,    // 所有录音文件接收成功,同步结束
    BLEReceiveStatusEnpty = 5          // 没有录音文件 如果没有文件
};

//全局监听枚举
typedef NS_ENUM(uint8_t, AudioRecordStatus) {
    AudioRecordStatusIdle        = 0x01, // 空闲状态，可启动录音/测量
    AudioRecordStatusRecording   = 0x02, // 正在录音或测量中
    AudioRecordStatusPaused      = 0x03, // 录音或测量暂停中
    AudioRecordStatusDataPending = 0x04, // 有录音或测量数据待上传
    AudioRecordStatusUploading   = 0x05, // 数据上传中
};

// 只代表发送成功 详细要监听receiveFileCompletion这个回调/有枚举说明
typedef void(^BLECompletionBlock)(BOOL status);
//MARK: -用来开启接受文件 可能会有多次回调因为是循环请求的 SDK里面如果有多文件的话
typedef void(^BLEFileReceiveFileCompletion)(BLEReceiveStatus status);
//MARK: -日志回调
typedef void(^BTLogHandler)(NSString *message);
//MARK: -全局的监听
typedef void(^AudioRecordStatusCompletion)(AudioRecordStatus status);

typedef void(^RecordParamsCallback)(uint16_t bitrate, uint8_t volume, NSArray<NSString *> *extraInfo);

@interface BTAudioManager : NSObject

@property (nonatomic, copy, nullable) BTLogHandler logHandler;

//MARK: -用来监听某个文件录音成功回调
@property (nonatomic, copy, nullable) BLEFileReceiveFileCompletion receiveFileCompletion;
//MARK: -全局的监听 连接上会回调 中途状态详见枚举说明~
@property (nonatomic, copy, nullable) AudioRecordStatusCompletion audioRecordStatusBlock;

+ (instancetype)sharedInstance;

//MARK: -录音过程中回调状态描述
+ (NSString *)descriptionForReceiveStatus:(BLEReceiveStatus)status;
//MARK: -开始下载录音文件
- (void)fetchLargeAudioFile:(BLECompletionBlock)completion;

//MARK: -日志
- (void)logMessage:(NSString *)message;

/// 获取设备当前录音参数（异步返回）
/// @param completion 回调：bitrate(录音码率 kbps6~510) + volume(音量 1~32)
- (BOOL)getCurrentRecordParamsWithCompletion:(RecordParamsCallback)completion;

/// 设置设备录音参数（异步回调成功/失败）
/// @param bitrate 录音码率：6~510 kbps 整数
/// @param volume 录音音量等级：1~32
/// @param completion 回调：YES=成功，NO=失败
- (BOOL)setRecordParamsWithBitrate:(uint16_t)bitrate
                            volume:(uint8_t)volume
                        completion:(BLECompletionBlock)completion;

//MARK: -设备向APP上报当前工作状态
- (void)processUncauchCommand:(NSData *)contentData;


@end

NS_ASSUME_NONNULL_END
