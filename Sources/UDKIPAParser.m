// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import "UDKIPAParser.h"
#import <zlib.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

@implementation UDKIPAInspectResult
@end

typedef struct {
    char *filename;
    uint16_t compressionMethod;
    uint64_t compressedSize;
    uint64_t uncompressedSize;
    uint64_t localHeaderOffset;
} ZipEntryInfo;

static long findEOCD(FILE *f, long fileSize) {
    long maxSearch = 65535 + 22;
    if (maxSearch > fileSize) maxSearch = fileSize;
    long searchStart = fileSize - maxSearch;
    size_t searchLen = (size_t)(fileSize - searchStart);
    uint8_t *searchBuf = malloc(searchLen);
    if (!searchBuf) return -1;
    if (fseeko(f, (off_t)searchStart, SEEK_SET) != 0) {
        free(searchBuf);
        return -1;
    }
    if (fread(searchBuf, 1, searchLen, f) != searchLen) {
        free(searchBuf);
        return -1;
    }
    long found = -1;
    for (ssize_t i = (ssize_t)searchLen - 22; i >= 0; i--) {
        if (searchBuf[i] == 0x50 && searchBuf[i+1] == 0x4B && searchBuf[i+2] == 0x05 && searchBuf[i+3] == 0x06) {
            found = searchStart + (long)i;
            break;
        }
    }
    free(searchBuf);
    return found;
}

static BOOL extractZipEntry(FILE *f, uint64_t localHeaderOffset, uint16_t method, uint64_t compSize, const char *destPath) {
    if (fseeko(f, (off_t)localHeaderOffset, SEEK_SET) != 0) return NO;
    uint8_t localHdr[30];
    if (fread(localHdr, 1, 30, f) != 30) return NO;
    if (localHdr[0] != 0x50 || localHdr[1] != 0x4B || localHdr[2] != 0x03 || localHdr[3] != 0x04) return NO;
    uint16_t nameLen = (uint16_t)(localHdr[26] | (localHdr[27] << 8));
    uint16_t extraLen = (uint16_t)(localHdr[28] | (localHdr[29] << 8));
    if (fseeko(f, (off_t)(nameLen + extraLen), SEEK_CUR) != 0) return NO;

    FILE *out = fopen(destPath, "wb");
    if (!out) return NO;

    char *outBufPool = malloc(65536);
    if (outBufPool) setvbuf(out, outBufPool, _IOFBF, 65536);

    BOOL success = YES;
    if (method == 0) { // Stored (no compression)
        uint8_t buf[65536];
        uint64_t remaining = compSize;
        while (remaining > 0) {
            size_t toRead = (remaining > sizeof(buf)) ? sizeof(buf) : (size_t)remaining;
            size_t nRead = fread(buf, 1, toRead, f);
            if (nRead == 0) { success = NO; break; }
            if (fwrite(buf, 1, nRead, out) != nRead) { success = NO; break; }
            remaining -= nRead;
        }
    } else if (method == 8) { // Deflated
        z_stream strm;
        memset(&strm, 0, sizeof(strm));
        if (inflateInit2(&strm, -MAX_WBITS) != Z_OK) {
            fclose(out);
            if (outBufPool) free(outBufPool);
            return NO;
        }
        uint8_t inBuf[65536];
        uint8_t outBuf[65536];
        uint64_t remaining = compSize;
        int ret = Z_OK;
        while (remaining > 0 && ret != Z_STREAM_END) {
            size_t toRead = (remaining > sizeof(inBuf)) ? sizeof(inBuf) : (size_t)remaining;
            size_t nRead = fread(inBuf, 1, toRead, f);
            if (nRead == 0) { success = NO; break; }
            remaining -= nRead;
            strm.next_in = inBuf;
            strm.avail_in = (uInt)nRead;
            do {
                strm.next_out = outBuf;
                strm.avail_out = sizeof(outBuf);
                ret = inflate(&strm, Z_NO_FLUSH);
                if (ret != Z_OK && ret != Z_STREAM_END && ret != Z_BUF_ERROR) {
                    success = NO;
                    break;
                }
                size_t have = sizeof(outBuf) - strm.avail_out;
                if (have > 0) {
                    if (fwrite(outBuf, 1, have, out) != have) {
                        success = NO;
                        break;
                    }
                }
            } while (strm.avail_out == 0 && success);
        }
        inflateEnd(&strm);
    } else {
        success = NO;
    }

    fclose(out);
    if (outBufPool) free(outBufPool);
    return success;
}

@implementation UDKIPAParser

+ (void)processIPAAtURL:(NSURL *)ipaURL
               progress:(void (^ _Nullable)(NSString *status))progress
             completion:(void (^)(UDKIPAInspectResult * _Nullable result, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *path = ipaURL.path;
        if (!path.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UDKIPAParser" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Đường dẫn tệp rỗng."}]);
            });
            return;
        }

        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if (!exists) {
            // Kiểm tra xem có phải do fopen vẫn mở được dù NSFileManager báo NO (sandbox false negative)
            FILE *testF = fopen([path UTF8String], "rb");
            if (testF) {
                exists = YES;
                fclose(testF);
            } else {
                // Kiểm tra xem có tệp .<tên>.icloud trong thư mục không (tệp iCloud chưa tải về)
                NSString *dir = [path stringByDeletingLastPathComponent];
                NSString *fileName = [path lastPathComponent];
                NSString *icloudStub = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@".%@.icloud", fileName]];
                if ([[NSFileManager defaultManager] fileExistsAtPath:icloudStub]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil, [NSError errorWithDomain:@"UDKIPAParser" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Tệp này đang lưu trên iCloud và chưa tải về máy. Vui lòng mở ứng dụng Tệp (Files), chạm vào tệp để tải về iPhone trước khi chọn!"}]);
                    });
                    return;
                }
            }
        }

        if (!exists) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UDKIPAParser" code:1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Không thể đọc tệp %@ (Tệp không tồn tại hoặc bị giới hạn quyền).", path.lastPathComponent]}]);
            });
            return;
        }

        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];

        // 1. Trường hợp chọn thư mục .app trực tiếp
        if (isDir || [path.pathExtension isEqualToString:@"app"]) {
            if (progress) progress(@"Phân tích thư mục .app...");
            [self processAppBundleAtPath:path progress:progress completion:completion];
            return;
        }

        // 2. Trường hợp tệp nén .ipa hoặc .zip
        if (progress) progress(@"Mở tệp IPA và đọc cấu trúc Central Directory...");
        FILE *f = fopen([path UTF8String], "rb");
        if (!f) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UDKIPAParser" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Không thể mở tệp IPA (lỗi I/O)."}]);
            });
            return;
        }

        fseeko(f, 0, SEEK_END);
        off_t fileSize = ftello(f);
        if (fileSize < 22) {
            fclose(f);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UDKIPAParser" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Tệp IPA quá nhỏ hoặc bị lỗi."}]);
            });
            return;
        }

        long eocdPos = findEOCD(f, (long)fileSize);
        if (eocdPos < 0) {
            fclose(f);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UDKIPAParser" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Tệp không phải định dạng ZIP/IPA hợp lệ (không tìm thấy EOCD)."}]);
            });
            return;
        }

        fseeko(f, (off_t)eocdPos, SEEK_SET);
        uint8_t eocd[22];
        if (fread(eocd, 1, 22, f) != 22) {
            fclose(f);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UDKIPAParser" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Không thể đọc EOCD."}]);
            });
            return;
        }

        uint64_t totalEntries = (uint64_t)(eocd[10] | (eocd[11] << 8));
        uint64_t cdSize = (uint64_t)(eocd[12] | (eocd[13] << 8) | (eocd[14] << 16) | (eocd[15] << 24));
        uint64_t cdOffset = (uint64_t)(eocd[16] | (eocd[17] << 8) | (eocd[18] << 16) | (eocd[19] << 24));

        // Kiểm tra ZIP64 Locator nếu tệp lớn > 4GB hoặc > 65535 mục
        if (eocdPos >= 20) {
            fseeko(f, (off_t)(eocdPos - 20), SEEK_SET);
            uint8_t loc[20];
            if (fread(loc, 1, 20, f) == 20 && loc[0] == 0x50 && loc[1] == 0x4B && loc[2] == 0x06 && loc[3] == 0x07) {
                uint64_t zip64EOCDOffset = 0;
                memcpy(&zip64EOCDOffset, &loc[8], 8);
                fseeko(f, (off_t)zip64EOCDOffset, SEEK_SET);
                uint8_t z64[56];
                if (fread(z64, 1, 56, f) == 56 && z64[0] == 0x50 && z64[1] == 0x4B && z64[2] == 0x06 && z64[3] == 0x06) {
                    memcpy(&totalEntries, &z64[32], 8);
                    memcpy(&cdSize, &z64[40], 8);
                    memcpy(&cdOffset, &z64[48], 8);
                }
            }
        }

        if (fseeko(f, (off_t)cdOffset, SEEK_SET) != 0) {
            fclose(f);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UDKIPAParser" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Không thể định vị Central Directory."}]);
            });
            return;
        }

        if (progress) progress([NSString stringWithFormat:@"Quét %llu tệp trong kho lưu trữ IPA...", totalEntries]);

        ZipEntryInfo unityFwEntry = {0};
        ZipEntryInfo metadataEntry = {0};
        ZipEntryInfo infoPlistEntry = {0};
        NSMutableArray<NSString *> *allPayloadEntries = [NSMutableArray new];
        ZipEntryInfo *dynamicEntries = malloc(sizeof(ZipEntryInfo) * totalEntries);

        uint64_t validCount = 0;
        for (uint64_t i = 0; i < totalEntries; i++) {
            uint8_t cdh[46];
            if (fread(cdh, 1, 46, f) != 46) break;
            if (cdh[0] != 0x50 || cdh[1] != 0x4B || cdh[2] != 0x01 || cdh[3] != 0x02) break;

            uint16_t method = (uint16_t)(cdh[10] | (cdh[11] << 8));
            uint64_t compSize = (uint64_t)(cdh[20] | (cdh[21] << 8) | (cdh[22] << 16) | (cdh[23] << 24));
            uint64_t uncompSize = (uint64_t)(cdh[24] | (cdh[25] << 8) | (cdh[26] << 16) | (cdh[27] << 24));
            uint16_t nameLen = (uint16_t)(cdh[28] | (cdh[29] << 8));
            uint16_t extraLen = (uint16_t)(cdh[30] | (cdh[31] << 8));
            uint16_t commentLen = (uint16_t)(cdh[32] | (cdh[33] << 8));
            uint64_t localOffset = (uint64_t)(cdh[42] | (cdh[43] << 8) | (cdh[44] << 16) | (cdh[45] << 24));

            char *filename = malloc(nameLen + 1);
            if (fread(filename, 1, nameLen, f) != nameLen) {
                free(filename);
                break;
            }
            filename[nameLen] = '\0';

            // Đọc Extra fields nếu có ZIP64
            if (extraLen > 0) {
                uint8_t *extra = malloc(extraLen);
                if (fread(extra, 1, extraLen, f) == extraLen) {
                    size_t ep = 0;
                    while (ep + 4 <= extraLen) {
                        uint16_t headerId = (uint16_t)(extra[ep] | (extra[ep+1] << 8));
                        uint16_t dataSize = (uint16_t)(extra[ep+2] | (extra[ep+3] << 8));
                        ep += 4;
                        if (headerId == 0x0001 && ep + dataSize <= extraLen) {
                            size_t z64p = ep;
                            if (uncompSize == 0xFFFFFFFF && z64p + 8 <= ep + dataSize) {
                                memcpy(&uncompSize, &extra[z64p], 8);
                                z64p += 8;
                            }
                            if (compSize == 0xFFFFFFFF && z64p + 8 <= ep + dataSize) {
                                memcpy(&compSize, &extra[z64p], 8);
                                z64p += 8;
                            }
                            if (localOffset == 0xFFFFFFFF && z64p + 8 <= ep + dataSize) {
                                memcpy(&localOffset, &extra[z64p], 8);
                                z64p += 8;
                            }
                        }
                        ep += dataSize;
                    }
                }
                free(extra);
            }

            if (commentLen > 0) {
                fseeko(f, (off_t)commentLen, SEEK_CUR);
            }

            ZipEntryInfo entry;
            entry.filename = filename;
            entry.compressionMethod = method;
            entry.compressedSize = compSize;
            entry.uncompressedSize = uncompSize;
            entry.localHeaderOffset = localOffset;

            NSString *entryStr = [NSString stringWithUTF8String:filename];
            if (entryStr) {
                NSString *lower = entryStr.lowercaseString;
                if ([lower containsString:@"unityframework.framework/unityframework"] || [lower hasSuffix:@"/unityframework"]) {
                    unityFwEntry = entry;
                } else if ([lower containsString:@"data/managed/metadata/global-metadata.dat"] || [lower hasSuffix:@"/global-metadata.dat"]) {
                    metadataEntry = entry;
                } else if ([lower hasSuffix:@"/info.plist"] && [lower containsString:@"payload/"]) {
                    infoPlistEntry = entry;
                }
                if ([lower hasPrefix:@"payload/"] && [lower containsString:@".app/"]) {
                    [allPayloadEntries addObject:entryStr];
                }
            }

            dynamicEntries[validCount++] = entry;
        }

        NSString *extractDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"UnityDumpKit_IPA"];
        [[NSFileManager defaultManager] removeItemAtPath:extractDir error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:extractDir withIntermediateDirectories:YES attributes:nil error:nil];

        // Đọc Info.plist nếu có để lấy tên App và CFBundleExecutable
        NSString *appName = nil;
        NSString *bundleId = nil;
        NSString *executableName = nil;
        if (infoPlistEntry.filename) {
            NSString *plistPath = [extractDir stringByAppendingPathComponent:@"Info.plist"];
            if (extractZipEntry(f, infoPlistEntry.localHeaderOffset, infoPlistEntry.compressionMethod, infoPlistEntry.compressedSize, [plistPath UTF8String])) {
                NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                appName = plist[@"CFBundleDisplayName"] ?: plist[@"CFBundleName"];
                bundleId = plist[@"CFBundleIdentifier"];
                executableName = plist[@"CFBundleExecutable"];
            }
        }

        UDKIPAInspectResult *result = [UDKIPAInspectResult new];
        result.appName = appName ?: ipaURL.lastPathComponent.stringByDeletingPathExtension;
        result.bundleIdentifier = bundleId;
        result.executableName = executableName;

        // KIỂM TRA ĐIỀU KIỆN THEO YÊU CẦU:
        // "khi có đủ 2 file unityframework và metadata thì tự động dump unity, nếu không có file unityframework thì sẽ dump ue"
        if (unityFwEntry.filename && metadataEntry.filename) {
            // == UNITY GAME ==
            result.engineType = UDKGameEngineUnity;
            if (progress) progress(@"Phát hiện Unity: Đang trích xuất UnityFramework...");
            NSString *destUnityFw = [extractDir stringByAppendingPathComponent:@"UnityFramework"];
            extractZipEntry(f, unityFwEntry.localHeaderOffset, unityFwEntry.compressionMethod, unityFwEntry.compressedSize, [destUnityFw UTF8String]);

            if (progress) progress(@"Phát hiện Unity: Đang trích xuất global-metadata.dat...");
            NSString *destMeta = [extractDir stringByAppendingPathComponent:@"global-metadata.dat"];
            extractZipEntry(f, metadataEntry.localHeaderOffset, metadataEntry.compressionMethod, metadataEntry.compressedSize, [destMeta UTF8String]);

            result.binaryLocalPath = destUnityFw;
            result.metadataLocalPath = destMeta;
            result.summary = [NSString stringWithFormat:@"🎮 Unity (IL2CPP) — App: %@\n• Binary: UnityFramework (%.1f MB)\n• Metadata: global-metadata.dat (%.1f MB)",
                              result.appName,
                              (double)unityFwEntry.uncompressedSize / (1024.0 * 1024.0),
                              (double)metadataEntry.uncompressedSize / (1024.0 * 1024.0)];
        } else {
            // == UNREAL ENGINE (hoặc Unity không dùng framework) ==
            // Tìm file thực thi chính của App
            ZipEntryInfo targetExecEntry = {0};
            if (executableName.length) {
                NSString *targetSuffix = [NSString stringWithFormat:@"/%@", executableName.lowercaseString];
                for (uint64_t i = 0; i < validCount; i++) {
                    NSString *fn = [NSString stringWithUTF8String:dynamicEntries[i].filename].lowercaseString;
                    if ([fn hasSuffix:targetSuffix] && [fn containsString:@"payload/"]) {
                        targetExecEntry = dynamicEntries[i];
                        break;
                    }
                }
            }

            // Nếu chưa tìm ra theo Info.plist, quét file thực thi trong Payload/*.app/
            if (!targetExecEntry.filename) {
                for (uint64_t i = 0; i < validCount; i++) {
                    NSString *fn = [NSString stringWithUTF8String:dynamicEntries[i].filename];
                    NSArray *comps = [fn componentsSeparatedByString:@"/"];
                    if (comps.count == 3 && [comps[0] isEqualToString:@"Payload"] && [comps[1] hasSuffix:@".app"]) {
                        NSString *sub = comps[2];
                        if (sub.length > 0 && ![sub containsString:@"."] && ![sub isEqualToString:@"PkgInfo"]) {
                            targetExecEntry = dynamicEntries[i];
                            executableName = sub;
                            break;
                        }
                    }
                }
            }

            if (targetExecEntry.filename) {
                if (progress) progress([NSString stringWithFormat:@"Đang trích xuất nhị phân chính (%@)...", executableName ?: @"Executable"]);
                NSString *destExec = [extractDir stringByAppendingPathComponent:executableName ?: @"AppExecutable"];
                extractZipEntry(f, targetExecEntry.localHeaderOffset, targetExecEntry.compressionMethod, targetExecEntry.compressedSize, [destExec UTF8String]);

                // Nếu có metadata thì vẫn là Unity kiểu cũ, còn không có UnityFramework thì mặc định sang Unreal Engine
                if (metadataEntry.filename) {
                    result.engineType = UDKGameEngineUnity;
                    NSString *destMeta = [extractDir stringByAppendingPathComponent:@"global-metadata.dat"];
                    extractZipEntry(f, metadataEntry.localHeaderOffset, metadataEntry.compressionMethod, metadataEntry.compressedSize, [destMeta UTF8String]);
                    result.binaryLocalPath = destExec;
                    result.metadataLocalPath = destMeta;
                    result.summary = [NSString stringWithFormat:@"🎮 Unity (Mono/Single Binary) — App: %@\n• Binary: %@ (%.1f MB)\n• Metadata: global-metadata.dat (%.1f MB)",
                                      result.appName, executableName,
                                      (double)targetExecEntry.uncompressedSize / (1024.0 * 1024.0),
                                      (double)metadataEntry.uncompressedSize / (1024.0 * 1024.0)];
                } else {
                    result.engineType = UDKGameEngineUnreal;
                    result.binaryLocalPath = destExec;
                    result.metadataLocalPath = nil;
                    result.summary = [NSString stringWithFormat:@"⚡ Unreal Engine (UE4 / UE5) — App: %@\n• Binary: %@ (%.1f MB)\n• Tự động trích xuất cấu trúc reflection từ nhị phân Mach-O",
                                      result.appName, executableName,
                                      (double)targetExecEntry.uncompressedSize / (1024.0 * 1024.0)];
                }
            } else {
                result.engineType = UDKGameEngineUnknown;
                result.summary = @"Không thể tìm thấy file thực thi trong tệp IPA.";
            }
        }

        // Dọn dẹp bộ nhớ dynamicEntries
        for (uint64_t i = 0; i < validCount; i++) {
            if (dynamicEntries[i].filename) free(dynamicEntries[i].filename);
        }
        free(dynamicEntries);
        fclose(f);

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result, nil);
        });
    });
}

+ (void)processAppBundleAtPath:(NSString *)appPath
                      progress:(void (^ _Nullable)(NSString *status))progress
                    completion:(void (^)(UDKIPAInspectResult * _Nullable result, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *ufPath = [appPath stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
        NSString *metaPath = [appPath stringByAppendingPathComponent:@"Data/Managed/Metadata/global-metadata.dat"];

        NSString *plistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        NSString *appName = plist[@"CFBundleDisplayName"] ?: plist[@"CFBundleName"] ?: appPath.lastPathComponent.stringByDeletingPathExtension;
        NSString *bundleId = plist[@"CFBundleIdentifier"];
        NSString *execName = plist[@"CFBundleExecutable"];

        UDKIPAInspectResult *result = [UDKIPAInspectResult new];
        result.appName = appName;
        result.bundleIdentifier = bundleId;
        result.executableName = execName;

        if ([[NSFileManager defaultManager] fileExistsAtPath:ufPath] && [[NSFileManager defaultManager] fileExistsAtPath:metaPath]) {
            result.engineType = UDKGameEngineUnity;
            result.binaryLocalPath = ufPath;
            result.metadataLocalPath = metaPath;
            result.summary = [NSString stringWithFormat:@"🎮 Unity (IL2CPP) — App: %@\n• Binary: UnityFramework\n• Metadata: global-metadata.dat", appName];
        } else {
            NSString *mainExecPath = [appPath stringByAppendingPathComponent:execName ?: @""];
            if ([[NSFileManager defaultManager] fileExistsAtPath:mainExecPath]) {
                result.binaryLocalPath = mainExecPath;
                if ([[NSFileManager defaultManager] fileExistsAtPath:metaPath]) {
                    result.engineType = UDKGameEngineUnity;
                    result.metadataLocalPath = metaPath;
                    result.summary = [NSString stringWithFormat:@"🎮 Unity (Single Binary) — App: %@", appName];
                } else {
                    result.engineType = UDKGameEngineUnreal;
                    result.metadataLocalPath = nil;
                    result.summary = [NSString stringWithFormat:@"⚡ Unreal Engine (UE4 / UE5) — App: %@", appName];
                }
            } else {
                result.engineType = UDKGameEngineUnknown;
                result.summary = @"Không tìm thấy file thực thi hợp lệ trong thư mục .app.";
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result, nil);
        });
    });
}

@end
