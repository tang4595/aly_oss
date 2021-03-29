#import <AliyunOSSiOS/OSSService.h>
#import "AesHelper.h"
#import "AlyOssPlugin.h"

NSObject<FlutterPluginRegistrar> *REGISTRAR;
FlutterMethodChannel *CHANNEL;
OSSClient *oss = nil;

@implementation AlyOssPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    CHANNEL = [FlutterMethodChannel
               methodChannelWithName:@"jitao.tech/aly_oss"
               binaryMessenger:[registrar messenger]];
    AlyOssPlugin* instance = [[AlyOssPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:CHANNEL];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"init" isEqualToString:call.method]) {
        [self init:call result:result];
        
        return;
    } else if ([@"upload" isEqualToString:call.method]) {
        [self upload:call result:result];
        
        return;
    } else if ([@"download" isEqualToString:call.method]) {
        [self download:call result:result];
        
        return;
    } else if ([@"exist" isEqualToString:call.method]) {
        [self exist:call result:result];
        
        return;
    } else if ([@"delete" isEqualToString:call.method]) {
        [self delete:call result:result];
        
        return;
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)init:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *instanceId = call.arguments[@"instanceId"];
    NSString *requestId = call.arguments[@"requestId"];
    NSString *endpoint = call.arguments[@"endpoint"];
    NSString *tokenJson = call.arguments[@"tokenJson"];
    
    id<OSSCredentialProvider> credentialProvider = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * {
        if (tokenJson == NULL) {
            NSLog(@"get token error: %@", instanceId);
            return nil;
        }
        if (tokenJson.length == 0) {
            NSLog(@"get token error(empty) %@", instanceId);
            return nil;
        }
        
        NSData *jsonText = [tokenJson dataUsingEncoding:NSUTF8StringEncoding];
        if (jsonText == nil) {
            NSLog(@"get token error(format) %@", instanceId);
            return nil;
        }
        
        NSDictionary *object = [NSJSONSerialization JSONObjectWithData: jsonText
                                                               options: kNilOptions
                                                                 error: nil];
        OSSFederationToken * token = [OSSFederationToken new];
        token.tAccessKey = [object objectForKey:@"accessKeyId"];
        token.tSecretKey = [object objectForKey:@"accessKeySecret"];
        token.tToken = [object objectForKey:@"securityToken"];
        token.expirationTimeInGMTFormat = [object objectForKey:@"expiration"];
        
        return token;
    }];
    
    oss = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credentialProvider];
    NSDictionary *arguments = @{
        @"instanceId": instanceId,
        @"requestId":requestId
    };
    
    result(arguments);
}

- (void)upload:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (![self checkOss:result]) {
        return;
    }
    
    NSString *instanceId = call.arguments[@"instanceId"];
    NSString *requestId = call.arguments[@"requestId"];
    NSString *bucket = call.arguments[@"bucket"];
    NSString *key = call.arguments[@"key"];
    NSString *file = call.arguments[@"file"];
    
    OSSPutObjectRequest *request = [OSSPutObjectRequest new];
    request.bucketName = bucket;
    request.objectKey = key;
    request.uploadingFileURL = [NSURL fileURLWithPath:file];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSDictionary *arguments = @{
            @"instanceId":instanceId,
            @"requestId":requestId,
            @"bucket":bucket,
            @"key":key,
            @"currentSize":  [NSString stringWithFormat:@"%lld",totalByteSent],
            @"totalSize": [NSString stringWithFormat:@"%lld",totalBytesExpectedToSend]
        };
        [CHANNEL invokeMethod:@"onProgress" arguments:arguments];
    };
    
    OSSTask *task = [oss putObject:request];
    [task continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSDictionary *arguments = @{
                @"success": @"true",
                @"instanceId":instanceId,
                @"requestId":requestId,
                @"bucket":bucket,
                @"key":key,
            };
            [CHANNEL invokeMethod:@"onUpload" arguments:arguments];
        } else {
            NSDictionary *arguments = @{
                @"success": @"false",
                @"instanceId":instanceId,
                @"requestId":requestId,
                @"bucket":bucket,
                @"key":key,
                @"message":task.error
            };
            [CHANNEL invokeMethod:@"onUpload" arguments:arguments];
        }
        return nil;
    }];
}

- (void)download:(FlutterMethodCall *)call result:(FlutterResult)result {
    if (![self checkOss:result]) {
        return;
    }
    
    NSString *instanceId = call.arguments[@"instanceId"];
    NSString *requestId = call.arguments[@"requestId"];
    NSString *bucket = call.arguments[@"bucket"];
    NSString *key = call.arguments[@"key"];

    OSSGetObjectRequest *request = [OSSGetObjectRequest new];
    request.bucketName = bucket;
    request.objectKey = key;
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSDictionary *arguments = @{
            @"instanceId":instanceId,
            @"requestId":requestId,
            @"bucket":bucket,
            @"key":key,
            @"currentSize":  [NSString stringWithFormat:@"%lld",totalBytesWritten],
            @"totalSize": [NSString stringWithFormat:@"%lld",totalBytesExpectedToWrite]
        };
        [CHANNEL invokeMethod:@"onDownloadProgress" arguments:arguments];
    };

    OSSTask *getTask = [oss getObject:request];
    [getTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            OSSGetObjectResult *getResult = task.result;
            NSDictionary *arguments = @{
                @"success": @"true",
                @"instanceId":instanceId,
                @"requestId":requestId,
                @"bucket":bucket,
                @"key":key,
                @"data":[getResult.downloadedData base64EncodedStringWithOptions: NSDataBase64Encoding64CharacterLineLength]
            };
            [CHANNEL invokeMethod:@"onDownload" arguments:arguments];
        } else {
            NSDictionary *arguments = @{
                @"success": @"false",
                @"instanceId":instanceId,
                @"requestId":requestId,
                @"bucket":bucket,
                @"key":key,
                @"message":task.error
            };
            [CHANNEL invokeMethod:@"onDownload" arguments:arguments];
        }
        return nil;
    }];
}

- (void)exist:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (![self checkOss:result]) {
        return;
    }
    
    NSString *instanceId = call.arguments[@"instanceId"];
    NSString *requestId = call.arguments[@"requestId"];
    NSString *bucket = call.arguments[@"bucket"];
    NSString *key = call.arguments[@"key"];
    
    NSError *error = nil;
    BOOL isExist = [oss doesObjectExistInBucket:bucket objectKey:key error:&error];
    
    if (!error) {
        NSDictionary *arguments = @{
            @"instanceId": instanceId,
            @"requestId":requestId,
            @"bucket":bucket,
            @"key":key,
            @"exist": isExist? @"true" : @"false"
        };
        
        
        result(arguments);
    } else {
        result([FlutterError errorWithCode:@"SERVICE_EXCEPTION"
                                   message:@"发生错误"
                                   details:nil]);
    }
}

- (void)delete:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (![self checkOss:result]) {
        return;
    }
    
    NSString *instanceId = call.arguments[@"instanceId"];
    NSString *requestId = call.arguments[@"requestId"];
    NSString *bucket = call.arguments[@"bucket"];
    NSString *key = call.arguments[@"key"];
    
    OSSDeleteObjectRequest *request = [OSSDeleteObjectRequest new];
    request.bucketName = bucket;
    request.objectKey = key;
    
    OSSTask *task = [oss deleteObject:request];
    
    [task continueWithBlock:^id(OSSTask *task) {
        return nil;
    }];
    
    [task waitUntilFinished];
    
    if (task.error) {
        result([FlutterError errorWithCode:@"SERVICE_EXCEPTION"
                                   message:@""
                                   details:nil]);
    } else {
        NSDictionary *arguments = @{
            @"instanceId": instanceId,
            @"requestId":requestId,
            @"bucket":bucket,
            @"key":key
        };
        
        result(arguments);
    }
}

- (BOOL)checkOss:(FlutterResult)result {
    if (oss == nil) {
        result([FlutterError errorWithCode:@"FAILED_PRECONDITION"
                                   message:@"not initialized"
                                   details:@"call init first"]);
        
        return FALSE;
    }
    
    return TRUE;
}

@end
