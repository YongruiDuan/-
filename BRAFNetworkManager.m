////
//  BRAFNetworkManager.m
//  forum
//
//  Created by YR on 2016/12/29.
//  Copyright © 2016年 mouluntan. All rights reserved.
//
//  QQ : 281644583
//  Email: duanyongrui@gmail.com
//

#import "BRAFNetworkManager.h"
#import "MBProgressHUD+GR.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum {
	Get = 0,
	Post,
	Put,
	Delete
} NetworkMethod;

@interface BRAFNetworkManager () {
	dispatch_semaphore_t _semaphore;
	NSString *_appsecret;
	NSString *_appid;
}

@property (nonatomic, strong) YYCache *cache;

@property (nonatomic, strong) NSMutableDictionary<NSString *,NSURLSessionDataTask *> *attentionTasks;

@property (nonatomic, strong) NSMutableDictionary<NSString *,NSURLSessionDataTask *> *praiseTasks;

@end

@implementation BRAFNetworkManager

@synthesize manager = _manager;

static id _instance = nil;
+ (id)allocWithZone:(struct _NSZone *)zone
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_instance = [super allocWithZone:zone];
		AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager managerForDomain:domain()];
		[reachabilityManager startMonitoring];
		[_instance manager].reachabilityManager = reachabilityManager;
	});
	return _instance;
}

+ (instancetype)shared
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_instance = [[self alloc] init];
	});
	return _instance;
}

+ (id)copyWithZone:(struct _NSZone *)zone
{
	return _instance;
}

static inline NSString * domain() {
	return @"com.xxx.www";
}

static inline NSString * appsecret() {
	return @"xxxxxxxxxx";
}

static inline NSString * appid() {
	return @"xxxxxxxxxx";
}

- (AFHTTPSessionManager *)manager {
	if (!_manager) {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			_manager = [[AFHTTPSessionManager alloc]initWithBaseURL:[NSURL URLWithString:BASEURL]];
			//		_manager.securityPolicy = [self policy];
			_manager.requestSerializer.timeoutInterval = 60;
			[_manager.requestSerializer setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-type"];
			_appid = appid();
			_appsecret = appsecret();
			_semaphore = dispatch_semaphore_create(1);
			_attentionTasks = [NSMutableDictionary dictionary];
			_praiseTasks = [NSMutableDictionary dictionary];
		});
	}
	return _manager;
}

/**
 https策略

 @return 策略对象
 */
- (AFSecurityPolicy *)policy {
	AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
	policy.pinnedCertificates = [self pinnedCertificates];
	return policy;
}

/**
 证书集合

 @return 证书集合
 */
- (NSSet<NSData *> *)pinnedCertificates {
	static NSSet *pinnedCertificates = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		// 获取证书
		NSArray *paths = [bundle pathsForResourcesOfType:@"cer" inDirectory:@".crt"];
		NSMutableSet *certificates = [NSMutableSet setWithCapacity:[paths count]];
		// 将证书文件转成data
		for (NSString *path in paths) {
			NSData *certificateData = [NSData dataWithContentsOfFile:path];
			[certificates addObject:certificateData];
		}
		pinnedCertificates = [NSSet setWithSet:certificates];
	});
	return pinnedCertificates;
}

#pragma mark - app请求处理


- (void)uploadFile:(NSArray *)files
		  AndParams:(id)params
		  superView:(UIView *)superView
			 block:(AFNSuccessBlock)block
	 progerssBlock:(void (^)(CGFloat progressValue))progress {
	[self uploadImage:files WithPath:@"" AndParams:params superView:superView successBlock:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
		NSLog(@"\n===========response===========\n%@%@:\n%@", self.manager.baseURL.absoluteString,kImageUploadUrl, responseObject);
		id error = [self handleResponse:responseObject autoShowError:YES superView:superView];
		if (error) {
			block(nil, error);
		}else{
			block(responseObject, nil);
		}
	} failureBlock:^(NSURLSessionDataTask * _Nonnull task, NSError * _Nonnull error) {
		NSLog(@"\n===========response===========\n%@%@:\n%@", self.manager.baseURL.absoluteString,kImageUploadUrl, error);
		block(nil, error);
	} progerssBlock:progress];
}


#pragma mark - 基础请求函数

/**
 发起http请求

 @param aPath 请求url地址
 @param params 参数
 @param method 请求类型
 @param autoShowError 是否自动提示错误
 @param autoShowIndicator 是否自动展示加载框
 @param superView 提示框的父视图
 @param block 请求回调
 */
- (NSURLSessionDataTask *)requestJsonDataWithPath:(NSString *)aPath
					 withParams:(id)params
				 withMethodType:(NetworkMethod)method
				  autoShowError:(BOOL)autoShowError
			  autoShowIndicator:(BOOL)autoShowIndicator
					  superView:(UIView *)superView
					   andBlock:(void (^)(id _Nullable, NSError *_Nullable))block {
	if (!aPath || aPath.length <= 0) {
		return nil;
	}
	//判断是否打开网络
	if (!self.manager.reachabilityManager.reachable) {
		[MBProgressHUD hideHUDForView:superView animated:NO];
		[MBProgressHUD showError:CustomLocalizedString(@"networkFailed", nil) toView:superView complication:nil];
		block(nil,[[NSError alloc] initWithDomain:domain() code:1004 userInfo:nil]);
		return nil;
	}
	if (![[aPath lowercaseString] containsString:kLoginUrl.lowercaseString] &&
		![[aPath lowercaseString] containsString:kQcloudSmsForRegistUrl.lowercaseString] &&
		![[aPath lowercaseString] containsString:kQcloudSmsForForgetPwsUrl.lowercaseString] &&
		![[aPath lowercaseString] containsString:kUpdatePwsByPhoneUrl.lowercaseString] &&
		![[aPath lowercaseString] containsString:kRegisterUrl.lowercaseString] &&
		![[aPath lowercaseString] containsString:kSmsCheckUrl.lowercaseString]) {
		if ([NSString isNULLString:[BRUserInfoManager shared].token] ||[NSString isNULLString:[BRUserInfoManager shared].ryToken]) {
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:CustomLocalizedString(@"LoginExpired", nil) preferredStyle:UIAlertControllerStyleAlert];
			[alertController addAction:[UIAlertAction actionWithTitle:CustomLocalizedString(@"confirmTitle", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
				[[BRUserInfoManager shared] setLoginState:BRUserOffLineByUnknown];
				[kAppDelegate setupWindow];
			}]];
			[kAppDelegate.window.rootViewController presentViewController:alertController animated:YES completion:nil];
			return nil;
		}
	}
	//对params做处理
	NSMutableDictionary *dic = [[NSMutableDictionary alloc]init];
	[dic setValue:_appid forKey:@"appId"];
	if ([params isKindOfClass:[NSDictionary classForCoder]]) {
		[dic setValue:params[@"pageNum"] forKey:@"pageNum"];
		[dic setValue:params[@"pageSize"] forKey:@"pageSize"];
		NSMutableDictionary *mutableParams = [NSMutableDictionary dictionaryWithDictionary:params];
		[mutableParams removeObjectForKey:@"pageNum"];
		[mutableParams removeObjectForKey:@"pageSize"];
		[dic setValue:mutableParams forKey:@"reqData"];
	} else {
		[dic setValue:params forKey:@"reqData"];
	}
	[dic setValue:[BRUserInfoManager shared].token forKey:@"token"];
	[dic setValue:[NSString stringWithFormat:@"%lld",(long long)([NSDate new].timeIntervalSince1970*1000)] forKey:@"timestamp"];
	NSString *jsonString = dic.jsonStringEncoded;
	NSString *sign = [[_appid stringByAppendingString:jsonString] stringByAppendingString:_appsecret].md5Str;
	[self.manager.requestSerializer setValue:sign forHTTPHeaderField:@"sign"];
	[self.manager.requestSerializer setQueryStringSerializationWithBlock:^NSString * _Nonnull(NSURLRequest * _Nonnull request, id  _Nonnull parameters, NSError * _Nullable __autoreleasing * _Nullable error) {
		return [Utils encryptUseDES:jsonString];
	}];
	NSLog(@"%@", self.manager.requestSerializer.HTTPRequestHeaders);
	NSLog(@"HTTPBody : %@", jsonString);
	if (autoShowIndicator) {
		[MBProgressHUD showIndicatorWithView:superView];
	}
	//发起请求
	switch (method) {
		case Get:{
			return [self.manager GET:aPath.stringByURLEncode parameters:dic progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
				NSLog(@"\n===========response===========\n%@%@:\n%@", self.manager.baseURL.absoluteString,aPath, responseObject);
				[MBProgressHUD hideHUDForView:superView animated:NO];
				id error = [self handleResponse:responseObject autoShowError:autoShowError superView:superView];
				if (error) {
					block(nil,error);
				}else {
					block([self checkNull:responseObject], nil);
				}
				
			} failure:^(NSURLSessionDataTask *task, NSError *error) {
				NSLog(@"\n===========response===========\n%@%@:\n%@", self.manager.baseURL.absoluteString,aPath, error);
				dispatch_async(dispatch_get_main_queue(), ^{
					NSString *description = nil;
					if (error.code == -1001) {
						description = CustomLocalizedString(@"timeOut", nil);;
					} else if (error.code == -1004){
						description = CustomLocalizedString(@"connectFailed", nil);
					} else {
						description = [error.userInfo objectForKey:@"NSLocalizedDescription"];
					}
					[MBProgressHUD hideHUDForView:superView animated:NO];
					autoShowError?[MBProgressHUD showError:description toView:superView complication:nil]:nil;
				});
				
				block(nil, error);
			}];
			break;}
		case Post:{
			NSLog(@"DES--------------%@",[Utils encryptUseDES:jsonString]);
			return [self.manager POST:aPath parameters:[Utils encryptUseDES:jsonString] progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
				NSLog(@"\n===========response===========\n%@%@:\n%@", self.manager.baseURL.absoluteString,aPath, responseObject);
				[MBProgressHUD hideHUDForView:superView animated:NO];
				id error = [self handleResponse:responseObject autoShowError:autoShowError superView:superView];
				if (error) {
					block(nil, error);
				}else{
					block([self checkNull:responseObject], nil);
				}
				
			} failure:^(NSURLSessionDataTask *task, NSError *error) {
				NSLog(@"\n===========response===========\n%@%@:\n%@", self.manager.baseURL.absoluteString,aPath, error);
				NSString *description = nil;
				if (error.code == -1001) {
					description = CustomLocalizedString(@"timeOut", nil);;
				}else if (error.code == -1004){
					description = CustomLocalizedString(@"connectFailed", nil);
				} else {
					description = [error.userInfo objectForKey:@"NSLocalizedDescription"];
				}
				if (error.code != -999) {
					[MBProgressHUD hideHUDForView:superView animated:NO];
					autoShowError?[MBProgressHUD showError:description toView:superView complication:nil]:nil;
				}
				block(nil, error);
			}];
			break;}
		case Put:{
			return [self.manager PUT:aPath parameters:dic success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
				NSLog(@"\n===========response===========\n%@%@:\n%@", self.manager.baseURL.absoluteString,aPath, responseObject);
				[MBProgressHUD hideHUDForView:superView animated:NO];
				id error = [self handleResponse:responseObject autoShowError:autoShowError superView:superView];
				if (error) {
					block(nil, error);
				}else{
					block([self checkNull:responseObject], nil);
				}
			} failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
				NSLog(@"\n===========response===========\n%@%@:\n%@", self.manager.baseURL.absoluteString,aPath, error);
				NSString *description = nil;
				if (error.code == -1001) {
					description = CustomLocalizedString(@"timeOut", nil);;
				} else if (error.code == -1004){
					description = CustomLocalizedString(@"connectFailed", nil);
				} else {
					description = [error.userInfo objectForKey:@"NSLocalizedDescription"];
				}
				[MBProgressHUD hideHUDForView:superView animated:NO];
				autoShowError?[MBProgressHUD showError:description toView:superView complication:nil]:nil;
				block(nil, error);
			}];
			break;}
		default:
			break;
	}
	return nil;
}

/**
 form表单形式上传文件至服务器

 @param files 文件
 @param path 服务器url
 @param Params 参数
 @param superView 提示展示的父视图
 @param success 成功回调
 @param failure 失败回答
 @param progress 上传过程回调
 */
- (void)uploadImage:(NSArray *)files
		   WithPath:(NSString *)path
		  AndParams:(id)Params
		  superView:(UIView *)superView
	   successBlock:(void (^)(NSURLSessionDataTask *task, id responseObject))success
	   failureBlock:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
	  progerssBlock:(void (^)(CGFloat progressValue))progress {
	NSLog(@"request:%@ \nparams:%@", path, Params);
	
	//判断是否打开网络
	if (!self.manager.reachabilityManager.reachable) {
		dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
		[MBProgressHUD hideHUDForView:superView animated:NO];
		[MBProgressHUD showError:CustomLocalizedString(@"networkFailed", nil) toView:superView complication:nil];
		dispatch_semaphore_signal(_semaphore);
		return;
	}
	[self.manager POST:path parameters:Params constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
		if (!files) {
			return;
		}
		for (int i = 0; i < files.count;i ++) {
			id file = files[i];
			if ([file isKindOfClass:[UIImage class]]) {
				NSData *data = UIImageJPEGRepresentation(file, 0.1);
				NSString *fileName = [NSString stringWithFormat:@"file%d.jpg", i];
				[formData appendPartWithFileData:data name:@"file" fileName:fileName mimeType:@"image/jpeg"];
			} else if ([file isKindOfClass:[NSData class]]) {
				NSString *fileName = [NSString stringWithFormat:@"file%d.mp4", i];
				[formData appendPartWithFileData:file name:fileName fileName:fileName mimeType:@"video/mpeg4"];
			}
		}
	} progress:^(NSProgress *uploadProgress) {
		progress(uploadProgress.fractionCompleted);
	} success:^(NSURLSessionDataTask *task, id responseObject) {
		NSLog(@"Success: %@\n%@", task, responseObject);
		id error = [self handleResponse:responseObject autoShowError:YES superView:superView];
		if (error && failure) {
			failure(task, error);
		}else{
			success(task, [self checkNull:responseObject]);
		}
	} failure:^(NSURLSessionDataTask *task, NSError *error) {
		NSLog(@"Error: %@\n%@", task, error);
		if (failure) {
			NSString *description = nil;
			if (error.code == -1001) {
				description = CustomLocalizedString(@"timeOut", nil);;
			} else if (error.code == -1004){
				description = CustomLocalizedString(@"connectFailed", nil);
			} else {
				description = [error.userInfo objectForKey:@"NSLocalizedDescription"];
			}
			dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
			[MBProgressHUD hideHUDForView:superView animated:NO];
			if (description && error.code != -999) [MBProgressHUD showError:description toView:superView complication:nil];
			dispatch_semaphore_signal(_semaphore);
			failure(task, error);
		}
	}];
}

/**
 取消所有的网络请求
 */
- (void)cancelAllTasks {
	[[AFHTTPSessionManager manager].tasks enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		[obj cancel];
	}];
}


/**
 此处根据返回码做一些业务逻辑判断

 @param responseJSON 返回的json
 @param autoShowError 是否自动提示错误
 @param superView 展示提示框的父视图
 @return 错误,若数据无误，返回为空
 */
- (NSError *)handleResponse:(id)responseJSON autoShowError:(BOOL)autoShowError superView:(UIView *)superView {
	NSError *error = nil;
	NSNumber *resultCode = [responseJSON valueForKeyPath:@"code"];
	NSString *msg = [responseJSON valueForKeyPath:@"msg"];
	if (resultCode.intValue == 200) { //正常返回
		
	}else { //-1:发生校验错误时返回 104:发生校验身份错误或者系统内部错误时返回
		error = [NSError errorWithDomain:self.manager.baseURL.absoluteString code:resultCode.intValue userInfo:responseJSON];
		if (autoShowError) {
			[MBProgressHUD hideHUDForView:superView animated:NO];
			[MBProgressHUD showMessage:msg toView:superView];
		} else {
			NSLog(@"%@", error.localizedDescription);
		}
	}
	return error;
}

/**
 递归转换空数据

 @param data 数据
 */
- (id)checkNull:(id)data {
	if ([data isKindOfClass:[NSArray classForCoder]]) {
		NSMutableArray *array = [NSMutableArray array];
		for (id subData in (NSArray *)data) {
			[array addObject:[self checkNull:subData]];
		}
		data = array;
	} else if ([data isKindOfClass:[NSDictionary classForCoder]]) {
		NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:data];
		NSArray *keys = ((NSDictionary *)dic).allKeys;
		for (id key in keys) {
			[dic setValue:[self checkNull:data[key]] forKey:key];
		}
		data = dic;
	} else if ([data isKindOfClass:[NSString classForCoder]]) {
		if ([NSString isNULLString:data]) {
			data = @"";
		}
	} else if ([data isKindOfClass:[NSNumber classForCoder]]) {
		
	} else {
		data = @"";
	}
	return data;
}

@end

NS_ASSUME_NONNULL_END
