// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UEDumperResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, copy, nullable) NSString *errorMessage;
@property (nonatomic, copy, nullable) NSURL *dumpFileURL;
@property (nonatomic, copy, nullable) NSString *engineType;
@property (nonatomic, copy, nullable) NSString *engineVersion;
@property (nonatomic, assign) uint64_t gnamesOffset;
@property (nonatomic, assign) uint64_t guobjectOffset;
@property (nonatomic, assign) uint64_t processEventOffset;
@property (nonatomic, assign) NSUInteger totalClasses;
@property (nonatomic, assign) NSUInteger totalFunctions;
@property (nonatomic, assign) NSUInteger totalProperties;
@property (nonatomic, assign) unsigned long long fileSize;
@end

@interface UEDumper : NSObject

+ (BOOL)isUnrealEngineBinary:(NSData *)binaryData engineVersion:(NSString * _Nullable * _Nullable)outVersion;

+ (UEDumperResult *)dumpBinary:(NSData *)binaryData
                     outputURL:(NSURL *)outputURL
                 progressBlock:(nullable void (^)(float progress, NSString *status))progressBlock;

@end

NS_ASSUME_NONNULL_END
