#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HikMicroSDKBridge;

@protocol HikMicroSDKBridgeDelegate <NSObject>
- (void)bridgeDidLoginWithDeviceName:(NSString *)deviceName
                          serialNumber:(NSString *)serialNumber
                       firmwareVersion:(NSString *)firmwareVersion;
- (void)bridgeDidLogout;
- (void)bridgeDidReceiveTemperatureMin:(float)tempMin
                                    max:(float)tempMax
                                    avg:(float)tempAvg
                              timestamp:(NSTimeInterval)timestamp;
- (void)bridgeDidFailWithError:(NSString *)error;
@end

@interface HikMicroSDKBridge : NSObject

@property (nonatomic, weak) id<HikMicroSDKBridgeDelegate> delegate;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL isLoggedIn;
@property (nonatomic, assign) BOOL isPreviewing;
@property (nonatomic, assign) BOOL isThermometryRunning;

+ (instancetype)shared;

- (BOOL)initialize;
- (void)cleanup;

- (void)loginWithIP:(NSString *)ip
               port:(int)port
               user:(NSString *)user
         password:(NSString *)password
         completion:(void (^)(BOOL success, NSString * _Nullable deviceName,
                              NSString * _Nullable serialNumber,
                              NSString * _Nullable firmwareVersion))completion;

- (void)logout;

- (BOOL)startPreviewInView:(UIView *)view;
- (void)stopPreview;

- (BOOL)startThermometry;
- (void)stopThermometry;

- (NSString *)sdkVersion;

@end

NS_ASSUME_NONNULL_END
