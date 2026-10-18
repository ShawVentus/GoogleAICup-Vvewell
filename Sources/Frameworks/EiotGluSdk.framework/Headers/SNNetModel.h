//
//  SNNetModel.h
//  AIZORing
//
//  Created by 黄建华 on 2025/2/5.
//

#import <Foundation/Foundation.h>
#import <EiotGluSdk/NetworkingTool.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^SNNetSuccessBlock)(id responseObject);
typedef void(^SNNetFailureBlock)(id error);




@interface SNNetModel : NSObject

@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *region;

/// 发送 POST 请求
+ (void)POST:(NSString *)URLString
  parameters:(nullable NSDictionary *)parameters
     success:(SNNetSuccessBlock)success
     failure:(SNNetFailureBlock)failure;
+ (void)POSTPPI:(NSString *)URLString parameters:(nullable NSDictionary *)parameters success:(SNNetSuccessBlock)success failure:(SNNetFailureBlock)failure;

/// 获取 SNNetModel 单例实例
/// Get the shared instance of SNNetModel
/// @param identifier 应用的标识（例如 APP 名称）
///        The identifier of the application (e.g., app name)
/// @param region 地区标识：国内传 1，国外传 2
///        The region flag: pass "1" for domestic, "2" for international
+ (instancetype)sharedInstanceWithIdentifier:(NSString *)identifier region:(NSString *)region;

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
