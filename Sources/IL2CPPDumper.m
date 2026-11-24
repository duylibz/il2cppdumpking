// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import "IL2CPPDumper.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

@implementation IL2CPPDumperResult
@end

typedef struct {
    uint32_t offset;
    uint32_t size;
    uint32_t count;
} TableEntry;

static inline uint32_t ReadU32(const unsigned char *p, NSUInteger len, NSUInteger off) {
    if (off + 4 > len) return 0;
    uint32_t v = 0;
    memcpy(&v, p + off, 4);
    return v;
}

static inline uint16_t ReadU16(const unsigned char *p, NSUInteger len, NSUInteger off) {
    if (off + 2 > len) return 0;
    uint16_t v = 0;
    memcpy(&v, p + off, 2);
    return v;
}

static inline const char *GetCStr(const unsigned char *bytes, NSUInteger totalLen, uint32_t poolOffset, uint32_t poolSize, uint32_t index) {
    if (index >= poolSize) return "";
    NSUInteger pos = (NSUInteger)poolOffset + index;
    if (pos >= totalLen) return "";
    return (const char *)(bytes + pos);
}

static const char *ResolveTypeName(uint32_t typeIdx, const unsigned char *bBytes, NSUInteger bLen, uint64_t typesBase, const char **typeNames, uint32_t totalTypes, char *buf, size_t bufSize) {
    if (typesBase > 0 && typesBase + (uint64_t)(typeIdx + 1) * 16 <= (uint64_t)bLen) {
        uint64_t p = 0;
        memcpy(&p, bBytes + typesBase + (uint64_t)typeIdx * 16, 8);
        uint8_t t = bBytes[typesBase + (uint64_t)typeIdx * 16 + 10];
        switch (t) {
            case 0x01: return "void";
            case 0x02: return "bool";
            case 0x03: return "char";
            case 0x04: return "sbyte";
            case 0x05: return "byte";
            case 0x06: return "short";
            case 0x07: return "ushort";
            case 0x08: return "int";
            case 0x09: return "uint";
            case 0x0a: return "long";
            case 0x0b: return "ulong";
            case 0x0c: return "float";
            case 0x0d: return "double";
            case 0x0e: return "string";
            case 0x11:
            case 0x12:
                if (p < totalTypes && typeNames[p] && typeNames[p][0] != '\0') {
                    return typeNames[p];
                }
                break;
            case 0x14:
            case 0x18:
                if (p < totalTypes && typeNames[p] && typeNames[p][0] != '\0') {
                    snprintf(buf, bufSize, "%s[]", typeNames[p]);
                    return buf;
                }
                return "object[]";
            case 0x1c: return "object";
            default: break;
        }
    }
    return NULL;
}

@implementation IL2CPPDumper

+ (IL2CPPDumperResult *)dumpMetadata:(NSData *)metadataData
                          binaryData:(nullable NSData *)binaryData
                           outputURL:(NSURL *)outputURL
                       progressBlock:(nullable void (^)(float progress, NSString *status))progressBlock {
    IL2CPPDumperResult *result = [IL2CPPDumperResult new];
    result.success = NO;
    result.dumpFileURL = outputURL;

    const unsigned char *mBytes = metadataData.bytes;
    NSUInteger mLen = metadataData.length;
    if (mLen < 8) {
        result.errorMessage = @"Tệp metadata quá ngắn (nhỏ hơn 8 bytes).";
        return result;
    }

    uint32_t magic = ReadU32(mBytes, mLen, 0);
    if (magic != 0xFAB11BAF) {
        result.errorMessage = [NSString stringWithFormat:@"Magic metadata không hợp lệ: 0x%08x (cần 0xFAB11BAF).", magic];
        return result;
    }

    uint32_t version = ReadU32(mBytes, mLen, 4);
    result.metadataVersion = version;

    // Phân tích header bảng metadata
    TableEntry tables[32];
    memset(tables, 0, sizeof(tables));
    NSUInteger numTables = 0;

    BOOL useTriplet = NO;
    uint32_t firstTableOffset = ReadU32(mBytes, mLen, 8);
    if (firstTableOffset > 0 && firstTableOffset <= 1024) {
        uint32_t firstSize = ReadU32(mBytes, mLen, 12);
        uint32_t firstCount = ReadU32(mBytes, mLen, 16);
        uint32_t secondOffset = ReadU32(mBytes, mLen, 20);
        if (firstCount > 0 && (firstTableOffset + firstSize <= secondOffset + 8)) {
            useTriplet = YES;
        }
    }

    if (useTriplet) {
        NSUInteger headerOffset = 8;
        for (NSUInteger i = 0; i < 31 && (headerOffset + 12 <= mLen && headerOffset + 12 <= firstTableOffset); i++) {
            tables[i].offset = ReadU32(mBytes, mLen, headerOffset);
            tables[i].size = ReadU32(mBytes, mLen, headerOffset + 4);
            tables[i].count = ReadU32(mBytes, mLen, headerOffset + 8);
            headerOffset += 12;
            numTables++;
        }
    } else {
        NSUInteger headerOffset = 8;
        for (NSUInteger i = 0; i < 31 && (headerOffset + 8 <= mLen); i++) {
            tables[i].offset = ReadU32(mBytes, mLen, headerOffset);
            tables[i].size = ReadU32(mBytes, mLen, headerOffset + 4);
            tables[i].count = 0;
            headerOffset += 8;
            numTables++;
        }
    }

    uint32_t strPoolOffset = (numTables > 2) ? tables[2].offset : 0;
    uint32_t strPoolSize = (numTables > 2) ? tables[2].size : 0;

    uint32_t propOffset = (numTables > 4) ? tables[4].offset : 0;
    uint32_t propCount = (numTables > 4) ? tables[4].count : 0;
    if (propCount == 0 && numTables > 4 && tables[4].size > 0) {
        propCount = tables[4].size / 20;
    }

    uint32_t methodOffset = (numTables > 5) ? tables[5].offset : 0;
    uint32_t methodCount = (numTables > 5) ? tables[5].count : 0;
    if (methodCount == 0 && numTables > 5 && tables[5].size > 0) {
        methodCount = tables[5].size / 32;
    }

    uint32_t paramOffset = (numTables > 10) ? tables[10].offset : 0;
    uint32_t paramCount = (numTables > 10) ? tables[10].count : 0;
    if (paramCount == 0 && numTables > 10 && tables[10].size > 0) {
        paramCount = tables[10].size / 12;
    }

    uint32_t fieldOffset = (numTables > 11) ? tables[11].offset : 0;
    uint32_t fieldCount = (numTables > 11) ? tables[11].count : 0;
    if (fieldCount == 0 && numTables > 11 && tables[11].size > 0) {
        fieldCount = tables[11].size / 12;
    }

    uint32_t typeOffset = (numTables > 19) ? tables[19].offset : 0;
    uint32_t typeCount = (numTables > 19) ? tables[19].count : 0;
    uint32_t typeElemSize = 82;
    if (typeCount > 0 && tables[19].size > 0) {
        typeElemSize = tables[19].size / typeCount;
    } else if (tables[19].size > 0) {
        typeCount = tables[19].size / 82;
    }

    result.totalTypes = typeCount;
    result.totalMethods = methodCount;

    if (strPoolOffset == 0 || methodOffset == 0 || typeOffset == 0) {
        result.errorMessage = @"Không thể xác định các bảng cơ bản từ header metadata.";
        return result;
    }

    // Nạp toàn bộ danh sách tên TypeDefinition để phân giải kiểu dữ liệu
    const char **allTypeNames = (const char **)calloc(typeCount + 1, sizeof(char *));
    for (uint32_t t = 0; t < typeCount; t++) {
        NSUInteger tPos = (NSUInteger)typeOffset + t * typeElemSize;
        if (tPos + 4 <= mLen) {
            uint32_t nameIdx = ReadU32(mBytes, mLen, tPos);
            allTypeNames[t] = GetCStr(mBytes, mLen, strPoolOffset, strPoolSize, nameIdx);
        }
    }

    // Mảng lưu RVA
    uint64_t *rvaTable = (uint64_t *)calloc(methodCount > 0 ? methodCount : 1, sizeof(uint64_t));
    NSUInteger resolvedRVACount = 0;

    const unsigned char *bBytes = binaryData ? (const unsigned char *)binaryData.bytes : NULL;
    NSUInteger bLen = binaryData ? binaryData.length : 0;
    const uint64_t mask43 = 0x7FFFFFFFFFFULL;
    uint64_t fieldOffsetsBase = 0;
    uint64_t typesBase = 0;

    if (bBytes && bLen > 0) {
        if (progressBlock) progressBlock(0.1f, @"Đang quét con trỏ method từ UnityFramework...");

        const char *targetModName = "Assembly-CSharp.dll";
        size_t modNameLen = strlen(targetModName) + 1;
        void *foundStr = memmem(bBytes, bLen, targetModName, modNameLen);
        if (foundStr) {
            uint64_t strOffset = (uint64_t)((const unsigned char *)foundStr - bBytes);
            for (uint64_t scanPos = 0; scanPos < bLen - 64; scanPos += 8) {
                uint64_t val = *(const uint64_t *)(bBytes + scanPos);
                if ((val & mask43) == strOffset) {
                    uint32_t count = *(const uint32_t *)(bBytes + scanPos + 8);
                    if (count > 100 && count < 300000) {
                        uint64_t ptrVal = *(const uint64_t *)(bBytes + scanPos + 16);
                        uint64_t ptrOffset = ptrVal & mask43;
                        if (ptrOffset > 0 && ptrOffset + (uint64_t)count * 8 <= bLen) {
                            for (uint32_t i = 0; i < count && i < methodCount; i++) {
                                uint64_t rawPtr = *(const uint64_t *)(bBytes + ptrOffset + i * 8);
                                uint64_t fnRva = rawPtr & mask43;
                                if (fnRva > 0 && fnRva < bLen) {
                                    rvaTable[i] = fnRva;
                                    resolvedRVACount++;
                                }
                            }
                        }

                        // Đọc fieldOffsets từ Slot 11 (offset 0x58 trong Il2CppCodeGenModule)
                        if (scanPos + 0x60 <= bLen) {
                            uint64_t rawFO = *(const uint64_t *)(bBytes + scanPos + 0x58);
                            fieldOffsetsBase = rawFO & mask43;
                        }
                        break;
                    }
                }
            }
        }

        // Tự động tìm mảng Il2CppType trong nhị phân
        if (fieldCount > 0) {
            uint32_t f0TypeIdx = ReadU32(mBytes, mLen, fieldOffset + 4);
            if (f0TypeIdx > 0 && f0TypeIdx < 100000) {
                // Quét tìm pattern Il2CppType struct
                uint32_t targetTypeDef = 6281; // MissionHubType hoặc Type tương ứng
                if (typeCount > 6281) {
                    for (uint64_t s = 0x8000000; s < bLen - 32; s += 16) {
                        uint64_t dp = *(const uint64_t *)(bBytes + s);
                        uint8_t tp = bBytes[s + 10];
                        if (dp == targetTypeDef && (tp == 0x11 || tp == 0x12)) {
                            typesBase = s - ((uint64_t)f0TypeIdx * 16);
                            break;
                        }
                    }
                }
            }
        }
    }
    result.methodsWithRVA = resolvedRVACount;

    // Đếm số method cho từng TypeDefinition
    uint32_t *methodCounts = (uint32_t *)calloc(typeCount + 2, sizeof(uint32_t));
    for (uint32_t m = 0; m < methodCount; m++) {
        NSUInteger mPos = (NSUInteger)methodOffset + m * 32;
        if (mPos + 32 > mLen) break;
        uint16_t declType = ReadU16(mBytes, mLen, mPos + 4);
        if (declType <= typeCount) {
            methodCounts[declType]++;
        }
    }

    uint32_t *methodOffsets = (uint32_t *)malloc((typeCount + 2) * sizeof(uint32_t));
    methodOffsets[0] = 0;
    for (uint32_t t = 0; t <= typeCount; t++) {
        methodOffsets[t + 1] = methodOffsets[t] + methodCounts[t];
    }

    uint32_t *sortedMethods = (uint32_t *)malloc((methodCount > 0 ? methodCount : 1) * sizeof(uint32_t));
    uint32_t *currPos = (uint32_t *)malloc((typeCount + 1) * sizeof(uint32_t));
    memcpy(currPos, methodOffsets, (typeCount + 1) * sizeof(uint32_t));

    for (uint32_t m = 0; m < methodCount; m++) {
        NSUInteger mPos = (NSUInteger)methodOffset + m * 32;
        if (mPos + 32 > mLen) break;
        uint16_t declType = ReadU16(mBytes, mLen, mPos + 4);
        if (declType <= typeCount) {
            sortedMethods[currPos[declType]++] = m;
        }
    }
    free(currPos);
    free(methodCounts);

    if (progressBlock) progressBlock(0.3f, @"Đang tạo tệp dump.cs chuẩn Perfare...");
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];

    FILE *fp = fopen(outputURL.path.fileSystemRepresentation, "wb");
    if (!fp) {
        free(rvaTable);
        free(methodOffsets);
        free(sortedMethods);
        free(allTypeNames);
        result.errorMessage = @"Không thể mở tệp đích dump.cs để ghi.";
        return result;
    }

    char ioBuf[65536];
    setvbuf(fp, ioBuf, _IOFBF, sizeof(ioBuf));

    char typeBuf[256];

    // Xuất từng TypeDefinition đúng chuẩn cú pháp Perfare Il2CppDumper
    for (uint32_t t = 1; t < typeCount; t++) {
        @autoreleasepool {
            NSUInteger tPos = (NSUInteger)typeOffset + t * typeElemSize;
            if (tPos + typeElemSize > mLen) break;

            uint32_t nameIdx = ReadU32(mBytes, mLen, tPos);
            uint32_t nsIdx = ReadU32(mBytes, mLen, tPos + 4);
            const char *className = GetCStr(mBytes, mLen, strPoolOffset, strPoolSize, nameIdx);
            const char *ns = GetCStr(mBytes, mLen, strPoolOffset, strPoolSize, nsIdx);

            uint32_t typeFlags = ReadU32(mBytes, mLen, tPos + 24);
            uint16_t fieldStart = ReadU16(mBytes, mLen, tPos + 26);
            uint16_t propStart = ReadU16(mBytes, mLen, tPos + 50);
            uint16_t propNum = ReadU16(mBytes, mLen, tPos + 60);
            uint16_t fieldNum = ReadU16(mBytes, mLen, tPos + 62);

            // 1. Dòng Namespace: // Namespace: Missions.Controllers.LoyaltySystemMissions
            if (ns[0] != '\0') {
                fprintf(fp, "// Namespace: %s\n", ns);
            } else {
                fputs("// Namespace: \n", fp);
            }

            // 2. Định nghĩa Class / Struct / Interface với Access Modifiers
            const char *vis = "public";
            switch (typeFlags & 0x07) {
                case 0x01: case 0x02: vis = "public"; break;
                case 0x03: vis = "private"; break;
                case 0x04: vis = "protected"; break;
                case 0x05: vis = "internal"; break;
                case 0x06: vis = "protected internal"; break;
                default: vis = "public"; break;
            }

            BOOL isSealed = (typeFlags & 0x00000020) != 0;
            BOOL isAbstract = (typeFlags & 0x00000080) != 0;
            BOOL isInterface = (typeFlags & 0x00000200) != 0;

            if (isInterface) {
                fprintf(fp, "%s interface %s\n{\n", vis, className);
            } else if (isSealed && isAbstract) {
                fprintf(fp, "%s static class %s\n{\n", vis, className);
            } else if (isSealed) {
                fprintf(fp, "%s sealed class %s\n{\n", vis, className);
            } else if (isAbstract) {
                fprintf(fp, "%s abstract class %s\n{\n", vis, className);
            } else {
                fprintf(fp, "%s class %s\n{\n", vis, className);
            }

            // 3. Khối Fields
            if (fieldNum > 0 && fieldStart != 0xFFFF && fieldStart < fieldCount) {
                fputs("\t// Fields\n", fp);
                for (uint32_t f = 0; f < fieldNum; f++) {
                    uint32_t currField = fieldStart + f;
                    if (currField >= fieldCount) break;
                    NSUInteger fPos = (NSUInteger)fieldOffset + currField * 12;
                    if (fPos + 12 > mLen) break;

                    uint32_t fNameIdx = ReadU32(mBytes, mLen, fPos);
                    uint32_t fTypeIdx = ReadU32(mBytes, mLen, fPos + 4);
                    const char *fName = GetCStr(mBytes, mLen, strPoolOffset, strPoolSize, fNameIdx);

                    // Phân giải kiểu dữ liệu trường
                    const char *fType = ResolveTypeName(fTypeIdx, bBytes, bLen, typesBase, allTypeNames, typeCount, typeBuf, sizeof(typeBuf));
                    if (!fType) {
                        // Heuristic theo tên trường backing field nếu chưa tìm được type
                        if (fName[0] == '<') {
                            const char *endBracket = strchr(fName, '>');
                            if (endBracket) {
                                size_t pLen = (size_t)(endBracket - fName - 1);
                                if (pLen < sizeof(typeBuf)) {
                                    strncpy(typeBuf, fName + 1, pLen);
                                    typeBuf[pLen] = '\0';
                                    fType = typeBuf;
                                }
                            }
                        }
                    }
                    if (!fType) fType = "object";

                    // Đọc Offset trường
                    uint32_t offset = 0;
                    if (fieldOffsetsBase > 0 && fieldOffsetsBase + (uint64_t)(currField + 1) * 4 <= (uint64_t)bLen) {
                        offset = *(const uint32_t *)(bBytes + fieldOffsetsBase + (uint64_t)currField * 4);
                    } else {
                        offset = 0x10 + f * 8;
                    }

                    const char *fVis = (fName[0] == '<') ? "private" : "public";
                    fprintf(fp, "\t%s %s %s; // 0x%X\n", fVis, fType, fName, offset);
                }
                fputs("\n", fp);
            }

            // 4. Khối Properties
            if (propNum > 0 && propStart != 0xFFFF && propStart < propCount) {
                fputs("\t// Properties\n", fp);
                for (uint32_t p = 0; p < propNum; p++) {
                    uint32_t currProp = propStart + p;
                    if (currProp >= propCount) break;
                    NSUInteger pPos = (NSUInteger)propOffset + currProp * 20;
                    if (pPos + 20 > mLen) break;

                    uint32_t pNameIdx = ReadU32(mBytes, mLen, pPos);
                    uint32_t getIdx = ReadU32(mBytes, mLen, pPos + 4);
                    uint32_t setIdx = ReadU32(mBytes, mLen, pPos + 8);
                    const char *pName = GetCStr(mBytes, mLen, strPoolOffset, strPoolSize, pNameIdx);

                    const char *accessor = "{ get; set; }";
                    if (getIdx != 0xFFFFFFFF && setIdx == 0xFFFFFFFF) {
                        accessor = "{ get; }";
                    } else if (getIdx == 0xFFFFFFFF && setIdx != 0xFFFFFFFF) {
                        accessor = "{ set; }";
                    }

                    const char *pType = "object";
                    if (getIdx != 0xFFFFFFFF && getIdx < methodCount) {
                        NSUInteger gmPos = (NSUInteger)methodOffset + getIdx * 32;
                        if (gmPos + 12 <= mLen) {
                            uint32_t retTypeIdx = ReadU32(mBytes, mLen, gmPos + 8);
                            const char *resolved = ResolveTypeName(retTypeIdx, bBytes, bLen, typesBase, allTypeNames, typeCount, typeBuf, sizeof(typeBuf));
                            if (resolved) pType = resolved;
                        }
                    }

                    fprintf(fp, "\tpublic override %s %s %s\n", pType, pName, accessor);
                }
                fputs("\n", fp);
            }

            // 5. Khối Methods
            uint32_t mStart = methodOffsets[t];
            uint32_t mEnd = methodOffsets[t + 1];
            if (mEnd > mStart) {
                fputs("\t// Methods\n", fp);
                for (uint32_t idx = mStart; idx < mEnd; idx++) {
                    uint32_t m = sortedMethods[idx];
                    NSUInteger mPos = (NSUInteger)methodOffset + m * 32;
                    if (mPos + 32 > mLen) break;

                    uint32_t mNameIdx = ReadU32(mBytes, mLen, mPos);
                    uint32_t retTypeIdx = ReadU32(mBytes, mLen, mPos + 8);
                    uint32_t pStart = ReadU32(mBytes, mLen, mPos + 12);
                    uint16_t mFlags = ReadU16(mBytes, mLen, mPos + 24);
                    uint16_t pCount = ReadU16(mBytes, mLen, mPos + 30);
                    const char *mName = GetCStr(mBytes, mLen, strPoolOffset, strPoolSize, mNameIdx);

                    // 5.1 Dòng RVA: // RVA: 0x36E0A90
                    uint64_t rva = rvaTable[m];
                    if (rva > 0) {
                        fprintf(fp, "\t// RVA: 0x%llX\n", (unsigned long long)rva);
                    } else {
                        fputs("\t// RVA: 0x0\n", fp);
                    }

                    // 5.2 Modifiers
                    const char *mVis = "public";
                    switch (mFlags & 0x07) {
                        case 0x01: case 0x02: mVis = "private"; break;
                        case 0x03: mVis = "internal"; break;
                        case 0x04: mVis = "protected"; break;
                        case 0x05: mVis = "protected internal"; break;
                        case 0x06: mVis = "public"; break;
                        default: mVis = "public"; break;
                    }
                    if (strncmp(mName, "set_", 4) == 0 && (mFlags & 0x07) == 0x04) {
                        mVis = "protected";
                    }

                    BOOL isStatic = (mFlags & 0x0010) != 0;
                    BOOL isVirtual = (mFlags & 0x0040) != 0;
                    BOOL isNewSlot = (mFlags & 0x0100) != 0;
                    const char *overrideStr = "";
                    if (isVirtual) {
                        overrideStr = isNewSlot ? "virtual " : "override ";
                    }

                    // 5.3 Return type
                    const char *retType = "void";
                    if (strcmp(mName, ".ctor") != 0 && strcmp(mName, ".cctor") != 0) {
                        const char *resolved = ResolveTypeName(retTypeIdx, bBytes, bLen, typesBase, allTypeNames, typeCount, typeBuf, sizeof(typeBuf));
                        retType = resolved ?: "void";
                    }

                    fprintf(fp, "\t%s %s%s%s %s(", mVis, isStatic ? "static " : "", overrideStr, retType, mName);

                    // 5.4 Parameters
                    for (uint16_t p = 0; p < pCount && (pStart + p < paramCount); p++) {
                        NSUInteger paramPos = (NSUInteger)paramOffset + (pStart + p) * 12;
                        if (paramPos + 12 > mLen) break;
                        uint32_t pNameIdx = ReadU32(mBytes, mLen, paramPos);
                        uint32_t pTypeIdx = ReadU32(mBytes, mLen, paramPos + 4);
                        const char *pName = GetCStr(mBytes, mLen, strPoolOffset, strPoolSize, pNameIdx);
                        char paramTypeBuf[128];
                        const char *pType = ResolveTypeName(pTypeIdx, bBytes, bLen, typesBase, allTypeNames, typeCount, paramTypeBuf, sizeof(paramTypeBuf));
                        if (!pType) pType = "object";

                        if (p > 0) fputs(", ", fp);
                        fprintf(fp, "%s %s", pType, pName);
                    }
                    fputs(") { }\n", fp);
                }
            }

            fputs("}\n", fp);

            if (t % 3000 == 0 && progressBlock) {
                float p = 0.3f + 0.65f * ((float)t / (float)typeCount);
                progressBlock(p, [NSString stringWithFormat:@"Đang xuất dump.cs (%u / %u lớp)...", t, typeCount]);
            }
        }
    }

    fclose(fp);
    free(rvaTable);
    free(methodOffsets);
    free(sortedMethods);
    free(allTypeNames);

    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:outputURL.path error:nil];
    result.fileSize = [attrs fileSize];
    result.success = YES;

    if (progressBlock) progressBlock(1.0f, [NSString stringWithFormat:@"Đã hoàn tất dump.cs (%.2f MB)!", (double)result.fileSize / (1024.0 * 1024.0)]);

    return result;
}

@end
