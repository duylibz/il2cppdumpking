// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UDKGameEngineType) {
    UDKGameEngineUnknown = 0,
    UDKGameEngineUnity = 1,
    UDKGameEngineUnreal = 2
};

@interface UDKIPAInspectResult : NSObject
@property(nonatomic,assign) UDKGameEngineType engineType;
@property(nonatomic,copy,nullable) NSString *appName;
@property(nonatomic,copy,nullable) NSString *bundleIdentifier;
@property(nonatomic,copy,nullable) NSString *executableName;
@property(nonatomic,copy,nullable) NSString *binaryLocalPath;     // Extracted UnityFramework or UE Mach-O
@property(nonatomic,copy,nullable) NSString *metadataLocalPath;   // Extracted global-metadata.dat (if Unity)
@property(nonatomic,copy,nullable) NSString *engineVersion;
@property(nonatomic,copy,nullable) NSString *summary;
@end

@interface UDKIPAParser : NSObject

+ (void)processIPAAtURL:(NSURL *)ipaURL
               progress:(void (^ _Nullable)(NSString *status))progress
             completion:(void (^)(UDKIPAInspectResult * _Nullable result, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
