//
//  NetworkingTool.h
//  RingSDK
//
//  Created by Kaoji on 2024/6/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NetworkingTool : NSObject
+ (instancetype)sharedInstance;
- (void)getRequestWithUrl:(NSString *)urlString parameters:(NSDictionary *)parameters completion:(void (^)(NSDictionary *jsonResponse, NSError *error))completion;
- (void)postRequestWithUrl:(NSString *)urlString parameters:(NSDictionary *)parameters completion:(void (^)(NSDictionary *jsonResponse, NSError *error))completion;
- (void)cancelAllRequests;
@end

NS_ASSUME_NONNULL_END
