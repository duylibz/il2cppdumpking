// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IL2CPPDumperResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, copy, nullable) NSString *errorMessage;
@property (nonatomic, copy, nullable) NSURL *dumpFileURL;
@property (nonatomic, assign) NSUInteger totalTypes;
@property (nonatomic, assign) NSUInteger totalMethods;
@property (nonatomic, assign) NSUInteger methodsWithRVA;
@property (nonatomic, assign) uint32_t metadataVersion;
@property (nonatomic, assign) unsigned long long fileSize;
@end

@interface IL2CPPDumper : NSObject

+ (IL2CPPDumperResult *)dumpMetadata:(NSData *)metadataData
                          binaryData:(nullable NSData *)binaryData
                           outputURL:(NSURL *)outputURL
                       progressBlock:(nullable void (^)(float progress, NSString *status))progressBlock;

@end

NS_ASSUME_NONNULL_END
