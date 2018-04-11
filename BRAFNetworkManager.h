////
//  BRAFNetworkManager.h
//  forum
//
//  Created by YR on 2016/12/29.
//  Copyright © 2016年 mouluntan. All rights reserved.
//
//  QQ : 281644583
//  Email: duanyongrui@gmail.com
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^AFNSuccessBlock)(id _Nullable data,NSError * _Nullable error);

@interface BRAFNetworkManager : NSObject

singleton_h();

@property (nonatomic, strong, readonly) AFHTTPSessionManager *manager;

#pragma mark - app请求处理

/**
 上传文件

 @param files 文件
 @param params 其他参数
 @param superView 提示框父视图
 @param block 回调
 @param progress 上传进度
 */
- (void)uploadFile:(NSArray *)files
		 AndParams:(id)params
		 superView:(UIView *)superView
			 block:(AFNSuccessBlock)block
	 progerssBlock:(void (^)(CGFloat progressValue))progress;

/**
 取消所有的网络请求
 */
- (void)cancelAllTasks;

@end

NS_ASSUME_NONNULL_END
