// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import "RootViewController.h"
#import "IL2CPPDumper.h"
#import "UEDumper.h"
#import "UDKLiquidGlass.h"
#import "UDKIPAParser.h"
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <mach/machine.h>

typedef NS_ENUM(NSInteger, UDKPickerMode) {
    UDKPickerModeBinary = 0,
    UDKPickerModeMetadata = 1,
    UDKPickerModeIPA = 2
};

@interface RootViewController () <UIDocumentPickerDelegate, UITextFieldDelegate, UIScrollViewDelegate>
@property(nonatomic,strong) NSURL *binaryURL;
@property(nonatomic,strong) NSURL *metadataURL;
@property(nonatomic,strong) UITextField *ipaPathField;
@property(nonatomic,strong) UILabel *ipaStatusLabel;
@property(nonatomic,strong) UITextField *binaryPathField;
@property(nonatomic,strong) UITextField *metadataPathField;
@property(nonatomic,strong) UILabel *binaryLabel;
@property(nonatomic,strong) UILabel *metadataLabel;
@property(nonatomic,strong) UITextView *reportView;
@property(nonatomic,strong) UIButton *analyzeButton;
@property(nonatomic,strong) UIButton *dumpButton;
@property(nonatomic,strong) UIButton *shareDumpButton;
@property(nonatomic,strong) UIButton *dumpUEButton;
@property(nonatomic,strong) UIButton *shareUEDumpButton;
@property(nonatomic,strong) UIScrollView *scrollView;
@property(nonatomic,strong) UDKScrollToTopButton *scrollToTopButton;
@property(nonatomic,assign) UDKPickerMode pickerMode;
@property(nonatomic,copy) NSString *lastReport;
@property(nonatomic,strong) NSURL *lastDumpFileURL;
@property(nonatomic,strong) NSURL *lastUEDumpFileURL;
@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"il2cppdumpking";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self setupNavigationItem];
    [self buildUI];
}

- (void)setupNavigationItem {
    UIButton *tgButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        config.image = [UIImage systemImageNamed:@"paperplane.fill"];
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 5.0;
        config.title = @"@guest_zinO";
        config.buttonSize = UIButtonConfigurationSizeSmall;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        tgButton.configuration = config;
    } else {
        [tgButton setTitle:@"@guest_zinO" forState:UIControlStateNormal];
    }
    [tgButton addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];
    tgButton.accessibilityLabel = @"Telegram @guest_zinO";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:tgButton];
}

- (void)openTelegram {
    NSURL *tgAppURL = [NSURL URLWithString:@"tg://resolve?domain=guest_zinO"];
    NSURL *tgWebURL = [NSURL URLWithString:@"https://t.me/guest_zinO"];
    if ([[UIApplication sharedApplication] canOpenURL:tgAppURL]) {
        [[UIApplication sharedApplication] openURL:tgAppURL options:@{} completionHandler:nil];
    } else {
        [[UIApplication sharedApplication] openURL:tgWebURL options:@{} completionHandler:nil];
    }
}

- (UILabel *)labelWithText:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    label.textColor = [UIColor colorWithWhite:0.85 alpha:0.85];
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (UILabel *)sectionHeaderWithText:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    return label;
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UDKLiquidGlassButton *button = [UDKLiquidGlassButton buttonWithTitle:title primary:NO];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)primaryButtonWithTitle:(NSString *)title action:(SEL)action {
    UDKLiquidGlassButton *button = [UDKLiquidGlassButton buttonWithTitle:title primary:YES];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UITextField *)createPathFieldWithPlaceholder:(NSString *)placeholder action:(SEL)action {
    UDKLiquidGlassTextField *field = [UDKLiquidGlassTextField new];
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{
        NSForegroundColorAttributeName: [UIColor colorWithWhite:0.75 alpha:0.55]
    }];
    field.delegate = self;
    [field addTarget:self action:action forControlEvents:UIControlEventEditingChanged];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [field.heightAnchor constraintGreaterThanOrEqualToConstant:40.0].active = YES;
    return field;
}

- (UDKLiquidGlassCard *)cardWithSubviews:(NSArray<UIView *> *)subviews spacing:(CGFloat)spacing {
    UDKLiquidGlassCard *card = [UDKLiquidGlassCard new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIStackView *cardStack = [[UIStackView alloc] initWithArrangedSubviews:subviews];
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = spacing;
    cardStack.alignment = UIStackViewAlignmentFill;
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card.contentView addSubview:cardStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [cardStack.topAnchor constraintEqualToAnchor:card.contentView.topAnchor constant:14],
        [cardStack.bottomAnchor constraintEqualToAnchor:card.contentView.bottomAnchor constant:-14],
        [cardStack.leadingAnchor constraintEqualToAnchor:card.contentView.leadingAnchor constant:14],
        [cardStack.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor constant:-14],
    ]];
    return card;
}

- (void)buildUI {
    UIImage *themeImg = [UIImage imageNamed:@"Theme"] ?: [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Theme" ofType:@"jpg"]];
    if (!themeImg) {
        themeImg = [UIImage imageWithContentsOfFile:@"/var/mobile/Containers/Shared/AppGroup/A2A84D3D-BC30-4205-B168-1DAE579C6BC9/Documents/icon.png"];
    }

    if (themeImg) {
        UIImageView *bgImageView = [[UIImageView alloc] initWithImage:themeImg];
        bgImageView.contentMode = UIViewContentModeScaleAspectFill;
        bgImageView.clipsToBounds = YES;
        bgImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:bgImageView];

        [NSLayoutConstraint activateConstraints:@[
            [bgImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [bgImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [bgImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [bgImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        ]];
    }

    self.scrollView = [UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.delegate = self;
    [self.view addSubview:self.scrollView];

    UIView *contentView = [UIView new];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:contentView];

    // Card 1: Header banner with theme icon & liquid glass badge
    UIImageView *headerIconView = [[UIImageView alloc] initWithImage:themeImg];
    headerIconView.contentMode = UIViewContentModeScaleAspectFill;
    headerIconView.clipsToBounds = YES;
    headerIconView.layer.cornerRadius = 18.0;
    headerIconView.layer.cornerCurve = kCACornerCurveContinuous;
    headerIconView.layer.borderWidth = 1.5;
    headerIconView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.95 alpha:0.8].CGColor;
    headerIconView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [headerIconView.widthAnchor constraintEqualToConstant:56],
        [headerIconView.heightAnchor constraintEqualToConstant:56]
    ]];

#ifndef APELIN_VERSION
#define APELIN_VERSION "0.3.5"
#endif
    NSString *appVer = [NSString stringWithUTF8String:APELIN_VERSION];
    UILabel *titleBadge = [self labelWithText:[NSString stringWithFormat:@"il2cppdumpking v%@\nUnity & Unreal Engine Dumper", appVer]];
    titleBadge.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    titleBadge.textColor = [UIColor whiteColor];

    UIStackView *headerStack = [[UIStackView alloc] initWithArrangedSubviews:@[headerIconView, titleBadge]];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.alignment = UIStackViewAlignmentCenter;
    headerStack.spacing = 14;

    UILabel *heading = [self labelWithText:@"Phân tích offline Unity (IL2CPP) & Unreal Engine (UE4/UE5)\nTrích xuất cấu trúc class, method, field và ARM64 RVA / Offset."];
    heading.textColor = [UIColor colorWithWhite:0.85 alpha:0.85];

    UDKLiquidGlassBadge *glassBadge = [UDKLiquidGlassBadge badgeWithParamsText:@"✨ Liquid Glass: bilalgursen/liquid-glass • rounded-[28px]\nTINT 0.70 • BLUR 5px • Border 1.3px (25%) • Accent #3291FF"];

    UDKLiquidGlassCard *headerCard = [self cardWithSubviews:@[headerStack, heading, glassBadge] spacing:10];

    // Card 2: IPA / App Package Auto-Dumper Section (Primary 1-click feature)
    UILabel *ipaHeader = [self sectionHeaderWithText:@"📦 1. Tự động xử lý từ tệp Game (.ipa / .app)"];
    UIButton *ipaPickerButton = [self buttonWithTitle:@"Chọn tệp Game (.ipa)" action:@selector(selectIPA)];
    UIButton *pasteIPAButton = [self buttonWithTitle:@"Dán từ Clipboard" action:@selector(pasteIPA)];
    self.ipaPathField = [self createPathFieldWithPlaceholder:@"Hoặc dán đường dẫn tệp .ipa / .app..." action:@selector(ipaFieldChanged:)];
    self.ipaStatusLabel = [self labelWithText:@"Trạng thái: Chưa chọn tệp IPA (Tự động nhận diện Unity / UE)"];

    UIStackView *ipaActionStack = [[UIStackView alloc] initWithArrangedSubviews:@[ipaPickerButton, pasteIPAButton]];
    ipaActionStack.axis = UILayoutConstraintAxisHorizontal;
    ipaActionStack.distribution = UIStackViewDistributionFillEqually;
    ipaActionStack.spacing = 8;

    UDKLiquidGlassCard *ipaCard = [self cardWithSubviews:@[ipaHeader, ipaActionStack, self.ipaPathField, self.ipaStatusLabel] spacing:8];

    // Card 3: Binary section (Thủ công)
    UILabel *binaryHeader = [self sectionHeaderWithText:@"🎮 2. Game Executable Binary (Tùy chọn thủ công)"];
    UIButton *binaryPickerButton = [self buttonWithTitle:@"Chọn Binary từ Files" action:@selector(selectBinary)];
    UIButton *pasteBinaryButton = [self buttonWithTitle:@"Dán từ Clipboard" action:@selector(pasteBinary)];
    self.binaryPathField = [self createPathFieldWithPlaceholder:@"Hoặc dán đường dẫn Binary (Mach-O / .app)..." action:@selector(binaryFieldChanged:)];
    self.binaryLabel = [self labelWithText:@"Binary: chưa chọn"];

    UIStackView *binaryActionStack = [[UIStackView alloc] initWithArrangedSubviews:@[binaryPickerButton, pasteBinaryButton]];
    binaryActionStack.axis = UILayoutConstraintAxisHorizontal;
    binaryActionStack.distribution = UIStackViewDistributionFillEqually;
    binaryActionStack.spacing = 8;

    UDKLiquidGlassCard *binaryCard = [self cardWithSubviews:@[binaryHeader, binaryActionStack, self.binaryPathField, self.binaryLabel] spacing:8];

    // Card 4: Metadata section (Thủ công)
    UILabel *metadataHeader = [self sectionHeaderWithText:@"📄 3. Unity Metadata (Tùy chọn thủ công)"];
    UIButton *metadataPickerButton = [self buttonWithTitle:@"Chọn Metadata từ Files" action:@selector(selectMetadata)];
    UIButton *pasteMetadataButton = [self buttonWithTitle:@"Dán từ Clipboard" action:@selector(pasteMetadata)];
    self.metadataPathField = [self createPathFieldWithPlaceholder:@"Đường dẫn global-metadata.dat (Unreal không cần)..." action:@selector(metadataFieldChanged:)];
    self.metadataLabel = [self labelWithText:@"Metadata: chưa chọn (Unreal Engine không cần tệp này)"];

    UIStackView *metadataActionStack = [[UIStackView alloc] initWithArrangedSubviews:@[metadataPickerButton, pasteMetadataButton]];
    metadataActionStack.axis = UILayoutConstraintAxisHorizontal;
    metadataActionStack.distribution = UIStackViewDistributionFillEqually;
    metadataActionStack.spacing = 8;

    UDKLiquidGlassCard *metadataCard = [self cardWithSubviews:@[metadataHeader, metadataActionStack, self.metadataPathField, self.metadataLabel] spacing:8];

    // Card 5: Operations & Dumper
    UILabel *actionHeader = [self sectionHeaderWithText:@"⚡ 4. Thao tác phân tích & Trích xuất"];
    self.analyzeButton = [self primaryButtonWithTitle:@"⚡ Analyze / Phân tích ngay" action:@selector(analyze)];
    self.analyzeButton.enabled = NO;

    self.dumpButton = [self buttonWithTitle:@"Xuất dump.cs" action:@selector(exportDumpCS)];
    self.dumpButton.enabled = NO;
    self.shareDumpButton = [self buttonWithTitle:@"Chia sẻ dump.cs" action:@selector(shareDumpCS)];
    self.shareDumpButton.enabled = NO;
    UIStackView *dumpActionStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.dumpButton, self.shareDumpButton]];
    dumpActionStack.axis = UILayoutConstraintAxisHorizontal;
    dumpActionStack.distribution = UIStackViewDistributionFillEqually;
    dumpActionStack.spacing = 8;

    self.dumpUEButton = [self buttonWithTitle:@"Xuất UEDump (.h)" action:@selector(exportUEDump)];
    self.dumpUEButton.enabled = NO;
    self.shareUEDumpButton = [self buttonWithTitle:@"Chia sẻ UEDump" action:@selector(shareUEDump)];
    self.shareUEDumpButton.enabled = NO;
    UIStackView *ueActionStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.dumpUEButton, self.shareUEDumpButton]];
    ueActionStack.axis = UILayoutConstraintAxisHorizontal;
    ueActionStack.distribution = UIStackViewDistributionFillEqually;
    ueActionStack.spacing = 8;

    UIButton *exportButton = [self buttonWithTitle:@"Xuất báo cáo .txt" action:@selector(exportReport)];
    UIButton *shareButton = [self buttonWithTitle:@"Chia sẻ báo cáo" action:@selector(shareReport)];
    UIStackView *reportActionStack = [[UIStackView alloc] initWithArrangedSubviews:@[exportButton, shareButton]];
    reportActionStack.axis = UILayoutConstraintAxisHorizontal;
    reportActionStack.distribution = UIStackViewDistributionFillEqually;
    reportActionStack.spacing = 8;

    UDKLiquidGlassCard *actionCard = [self cardWithSubviews:@[actionHeader, self.analyzeButton, dumpActionStack, ueActionStack, reportActionStack] spacing:10];

    // Card 6: Console Report
    UILabel *consoleHeader = [self sectionHeaderWithText:@"📟 5. Nhật ký phân tích (Terminal Console)"];
    self.reportView = [UITextView new];
    self.reportView.editable = NO;
    self.reportView.scrollEnabled = NO;
    self.reportView.font = [UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular];
    self.reportView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
    self.reportView.textColor = [UIColor colorWithRed:0.25 green:0.95 blue:0.75 alpha:1.0];
    self.reportView.layer.cornerRadius = 14.0;
    self.reportView.layer.cornerCurve = kCACornerCurveContinuous;
    self.reportView.layer.borderWidth = 1.0;
    self.reportView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    self.reportView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.reportView.text = @"Chọn tệp hoặc dán đường dẫn rồi bấm Phân tích.";
    self.reportView.accessibilityLabel = @"Kết quả phân tích";

    UDKLiquidGlassCard *consoleCard = [self cardWithSubviews:@[consoleHeader, self.reportView] spacing:8];

    // Main Stack
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        headerCard,
        ipaCard,
        binaryCard,
        metadataCard,
        actionCard,
        consoleCard
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [stack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:contentView.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:contentView.layoutMarginsGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24],
        [self.reportView.heightAnchor constraintGreaterThanOrEqualToConstant:200]
    ]];

    // Floating "Lên đầu" button at bottom right (from attached screenshot)
    self.scrollToTopButton = [UDKScrollToTopButton buttonWithTarget:self action:@selector(scrollToTopTapped)];
    self.scrollToTopButton.alpha = 0.0;
    self.scrollToTopButton.transform = CGAffineTransformMakeTranslation(0, 20);
    [self.view addSubview:self.scrollToTopButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollToTopButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.scrollToTopButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
    ]];
}

- (void)scrollToTopTapped {
    [self.scrollView setContentOffset:CGPointZero animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    BOOL shouldShow = (scrollView.contentOffset.y > 80.0);
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;
    if (fabs(self.scrollToTopButton.alpha - targetAlpha) > 0.01) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.scrollToTopButton.alpha = targetAlpha;
            self.scrollToTopButton.transform = shouldShow ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 20);
        } completion:nil];
    }
}

- (void)selectIPA {
    [self.view endEditing:YES];
    self.pickerMode = UDKPickerModeIPA;
    [self presentPicker];
}

- (void)pasteIPA {
    [self.view endEditing:YES];
    NSString *pasted = [UIPasteboard generalPasteboard].string;
    if (pasted.length) {
        self.ipaPathField.text = [pasted stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self ipaFieldChanged:self.ipaPathField];
    } else {
        [self showMessage:@"Clipboard trống" message:@"Chưa có đường dẫn tệp .ipa nào trong bộ nhớ tạm để dán."];
    }
}

- (void)ipaFieldChanged:(UITextField *)sender {
    NSString *path = [sender.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (path.length) {
        NSURL *url = [self normalizePathToURL:path];
        if (url) {
            [self processIPAWithURL:url];
        }
    }
}

- (void)processIPAWithURL:(NSURL *)ipaURL {
    [self processIPAWithURL:ipaURL cleanupBlock:nil];
}

- (void)processIPAWithURL:(NSURL *)ipaURL cleanupBlock:(void (^ _Nullable)(void))cleanupBlock {
    [self.view endEditing:YES];
    self.ipaStatusLabel.text = [NSString stringWithFormat:@"Đang quét tệp: %@...", ipaURL.lastPathComponent];
    self.ipaStatusLabel.textColor = [UIColor colorWithRed:0x32/255.0 green:0x91/255.0 blue:1.0 alpha:1.0];
    self.reportView.text = [NSString stringWithFormat:@"[IPA Auto-Dumper] Đang kiểm tra: %@\n", ipaURL.path];

    [UDKIPAParser processIPAAtURL:ipaURL progress:^(NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.ipaStatusLabel.text = status;
            self.reportView.text = [self.reportView.text stringByAppendingFormat:@"• %@\n", status];
        });
    } completion:^(UDKIPAInspectResult *result, NSError *error) {
        if (cleanupBlock) {
            cleanupBlock();
        }

        if (error || !result) {
            self.ipaStatusLabel.text = [NSString stringWithFormat:@"Lỗi: %@", error.localizedDescription ?: @"Không thể xử lý IPA."];
            self.ipaStatusLabel.textColor = UIColor.systemRedColor;
            [self showMessage:@"Lỗi xử lý IPA" message:error.localizedDescription ?: @"Không tìm thấy cấu trúc hợp lệ trong IPA."];
            return;
        }

        self.ipaStatusLabel.text = [NSString stringWithFormat:@"Đã phân tích xong: %@", result.appName ?: ipaURL.lastPathComponent];
        self.ipaStatusLabel.textColor = UIColor.systemGreenColor;
        self.reportView.text = [self.reportView.text stringByAppendingFormat:@"\n%@\n\n", result.summary ?: @""];

        if (result.binaryLocalPath.length) {
            self.binaryURL = [NSURL fileURLWithPath:result.binaryLocalPath];
            self.binaryPathField.text = result.binaryLocalPath;
            self.binaryLabel.text = [NSString stringWithFormat:@"Binary: %@", result.binaryLocalPath.lastPathComponent];
            self.binaryLabel.textColor = UIColor.systemGreenColor;
        }

        if (result.engineType == UDKGameEngineUnity) {
            if (result.metadataLocalPath.length) {
                self.metadataURL = [NSURL fileURLWithPath:result.metadataLocalPath];
                self.metadataPathField.text = result.metadataLocalPath;
                self.metadataLabel.text = [NSString stringWithFormat:@"Metadata: %@", result.metadataLocalPath.lastPathComponent];
                self.metadataLabel.textColor = UIColor.systemGreenColor;
            }
            self.analyzeButton.enabled = YES;
            // TỰ ĐỘNG DUMP UNITY THEO YÊU CẦU:
            [self analyze];
        } else if (result.engineType == UDKGameEngineUnreal) {
            self.metadataURL = nil;
            self.metadataPathField.text = @"";
            self.metadataLabel.text = @"⚡ Unreal Engine: Không cần tệp metadata";
            self.metadataLabel.textColor = UIColor.systemGreenColor;
            self.analyzeButton.enabled = YES;
            // TỰ ĐỘNG DUMP UNREAL THEO YÊU CẦU:
            [self analyze];
        } else {
            [self showMessage:@"Chưa nhận diện được Engine" message:@"Không tìm thấy UnityFramework hoặc Unreal Engine trong gói IPA này."];
        }
    }];
}

- (void)selectBinary {
    [self.view endEditing:YES];
    self.pickerMode = UDKPickerModeBinary;
    [self presentPicker];
}

- (void)selectMetadata {
    [self.view endEditing:YES];
    self.pickerMode = UDKPickerModeMetadata;
    [self presentPicker];
}

- (void)pasteBinary {
    [self.view endEditing:YES];
    NSString *pasted = [UIPasteboard generalPasteboard].string;
    if (pasted.length) {
        self.binaryPathField.text = [pasted stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self binaryFieldChanged:self.binaryPathField];
    } else {
        [self showMessage:@"Clipboard trống" message:@"Chưa có đường dẫn nào trong bộ nhớ tạm để dán."];
    }
}

- (void)pasteMetadata {
    [self.view endEditing:YES];
    NSString *pasted = [UIPasteboard generalPasteboard].string;
    if (pasted.length) {
        self.metadataPathField.text = [pasted stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self metadataFieldChanged:self.metadataPathField];
    } else {
        [self showMessage:@"Clipboard trống" message:@"Chưa có đường dẫn nào trong bộ nhớ tạm để dán."];
    }
}

- (NSData *)readHeadDataFromURL:(NSURL *)rawURL length:(NSUInteger)maxLen {
    if (!rawURL) return nil;
    NSURL *targetURL = [self resolveExecutableURL:rawURL];
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL:targetURL error:nil];
    if (!fh) return nil;
    NSData *data = [fh readDataOfLength:maxLen];
    [fh closeFile];
    return data;
}

- (void)binaryFieldChanged:(UITextField *)sender {
    NSString *path = [sender.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (path.length) {
        NSURL *rawURL = [self normalizePathToURL:path];
        NSURL *resolved = [self resolveExecutableURL:rawURL];
        self.binaryURL = resolved ?: rawURL;
        self.binaryLabel.text = [NSString stringWithFormat:@"Binary: %@", self.binaryURL.lastPathComponent];

        // Tự động tìm global-metadata.dat nếu là app Unity
        if (!self.metadataURL) {
            NSString *appDir = nil;
            NSString *p = self.binaryURL.path;
            while (p.length > 1 && ![p isEqualToString:@"/"]) {
                if ([p.pathExtension isEqualToString:@"app"]) {
                    appDir = p;
                    break;
                }
                p = [p stringByDeletingLastPathComponent];
            }
            if (appDir) {
                NSString *autoMeta = [appDir stringByAppendingPathComponent:@"Data/Managed/Metadata/global-metadata.dat"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:autoMeta]) {
                    self.metadataURL = [NSURL fileURLWithPath:autoMeta];
                    self.metadataPathField.text = autoMeta;
                    self.metadataLabel.text = [NSString stringWithFormat:@"Metadata: %@ (tự động tìm thấy)", self.metadataURL.lastPathComponent];
                    self.metadataLabel.textColor = UIColor.systemGreenColor;
                }
            }
        }

        // Tự động kiểm tra nếu là game Unreal Engine
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSData *headData = [self readHeadDataFromURL:self.binaryURL length:32 * 1024 * 1024];
            NSString *ueVer = nil;
            if (headData && [UEDumper isUnrealEngineBinary:headData engineVersion:&ueVer]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.metadataLabel.text = [NSString stringWithFormat:@"⚡ Phát hiện %@: Không cần metadata, bấm Phân tích!", ueVer ?: @"Unreal Engine"];
                    self.metadataLabel.textColor = UIColor.systemGreenColor;
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!self.metadataURL) {
                        self.metadataLabel.text = @"Metadata: chưa chọn (Unreal Engine không cần tệp này)";
                        self.metadataLabel.textColor = UIColor.secondaryLabelColor;
                    }
                });
            }
        });
    } else {
        self.binaryURL = nil;
        self.binaryLabel.text = @"Binary: chưa chọn";
        self.metadataLabel.text = @"Metadata: chưa chọn (Unreal Engine không cần tệp này)";
        self.metadataLabel.textColor = UIColor.secondaryLabelColor;
    }
    self.analyzeButton.enabled = (self.binaryURL != nil);
}

- (void)metadataFieldChanged:(UITextField *)sender {
    NSString *path = [sender.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (path.length) {
        self.metadataURL = [self normalizePathToURL:path];
        self.metadataLabel.text = [NSString stringWithFormat:@"Metadata: %@", self.metadataURL.lastPathComponent];
    } else {
        self.metadataURL = nil;
        self.metadataLabel.text = @"Metadata: chưa chọn";
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)presentPicker {
    NSMutableArray<UTType *> *types = [NSMutableArray array];
    if (self.pickerMode == UDKPickerModeIPA) {
        UTType *ipaExt = [UTType typeWithFilenameExtension:@"ipa"];
        if (ipaExt) [types addObject:ipaExt];
        UTType *ipaId = [UTType typeWithIdentifier:@"com.apple.itunes.ipa"];
        if (ipaId && ![types containsObject:ipaId]) [types addObject:ipaId];
        [types addObject:UTTypeArchive];
        [types addObject:UTTypeZIP];
        [types addObject:UTTypeData];
        [types addObject:UTTypeItem];
    } else if (self.pickerMode == UDKPickerModeMetadata) {
        UTType *datExt = [UTType typeWithFilenameExtension:@"dat"];
        if (datExt) [types addObject:datExt];
        [types addObject:UTTypeData];
        [types addObject:UTTypeItem];
        [types addObject:UTTypeContent];
    } else { // Binary
        [types addObject:UTTypeItem];
        [types addObject:UTTypeData];
        [types addObject:UTTypeContent];
        [types addObject:UTTypeArchive];
    }

    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.shouldShowFileExtensions = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSString *fileName = url.lastPathComponent ?: @"file";
    NSLog(@"[UDK] Document picker picked URL: %@", url);

    BOOL isSecurityScoped = NO;
    @try {
        isSecurityScoped = [url startAccessingSecurityScopedResource];
    } @catch (NSException *e) {}

    // Kiểm tra xem file có đọc được trực tiếp tại url không
    BOOL directReadable = [[NSFileManager defaultManager] fileExistsAtPath:url.path];
    if (!directReadable) {
        FILE *tf = fopen([url.path UTF8String], "rb");
        if (tf) {
            directReadable = YES;
            fclose(tf);
        }
    }

    NSURL *usableURL = url;
    NSString *tmpDir = NSTemporaryDirectory();

    // Nếu tệp chưa đọc được hoặc nằm ngoài sandbox, sao chép an toàn vào thư mục Imports của app
    if (!directReadable || ![url.path hasPrefix:tmpDir]) {
        NSString *subDir = (self.pickerMode == UDKPickerModeIPA) ? @"ImportedIPA" : @"ImportedFiles";
        NSString *destFolder = [tmpDir stringByAppendingPathComponent:subDir];
        [[NSFileManager defaultManager] createDirectoryAtPath:destFolder withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *destPath = [destFolder stringByAppendingPathComponent:fileName];
        NSURL *destURL = [NSURL fileURLWithPath:destPath];

        if (![url.path isEqualToString:destPath]) {
            [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
            NSError *cpErr = nil;
            BOOL copied = [[NSFileManager defaultManager] copyItemAtURL:url toURL:destURL error:&cpErr];
            if (copied && [[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
                usableURL = destURL;
            }
        }
    }

    if (self.pickerMode == UDKPickerModeIPA) {
        self.ipaPathField.text = usableURL.path;
        [self processIPAWithURL:usableURL cleanupBlock:^{
            if (isSecurityScoped) {
                [url stopAccessingSecurityScopedResource];
            }
        }];
    } else if (self.pickerMode == UDKPickerModeMetadata) {
        self.metadataURL = usableURL;
        self.metadataPathField.text = usableURL.path;
        self.metadataLabel.text = [NSString stringWithFormat:@"Metadata: %@", usableURL.lastPathComponent];
        self.metadataLabel.textColor = UIColor.systemGreenColor;
        if (isSecurityScoped) [url stopAccessingSecurityScopedResource];
    } else {
        NSURL *sourceURL = [self resolveExecutableURL:usableURL] ?: usableURL;
        self.binaryURL = sourceURL;
        self.binaryPathField.text = sourceURL.path;
        self.binaryLabel.text = [NSString stringWithFormat:@"Binary: %@", sourceURL.lastPathComponent];
        self.binaryLabel.textColor = UIColor.systemGreenColor;
        self.analyzeButton.enabled = (self.binaryURL != nil);
        if (isSecurityScoped) [url stopAccessingSecurityScopedResource];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSLog(@"[UDK] Document picker cancelled by user.");
}

- (NSURL *)normalizePathToURL:(NSString *)rawString {
    if (!rawString.length) return nil;
    NSString *path = [rawString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([path hasPrefix:@"file://"]) {
        NSURL *u = [NSURL URLWithString:path];
        if (u && u.path.length) path = u.path;
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [NSURL fileURLWithPath:path];
    }

    // Roothide support: kiểm tra jbroot trong AppGroup
    NSString *appGroupDir = @"/private/var/mobile/Containers/Shared/AppGroup";
    NSArray<NSString *> *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appGroupDir error:nil];
    for (NSString *entry in entries) {
        if ([entry hasPrefix:@".jbroot-"]) {
            NSString *rel = [path hasPrefix:@"/"] ? [path substringFromIndex:1] : path;
            NSString *cand = [[appGroupDir stringByAppendingPathComponent:entry] stringByAppendingPathComponent:rel];
            if ([[NSFileManager defaultManager] fileExistsAtPath:cand]) {
                return [NSURL fileURLWithPath:cand];
            }
        }
    }

    // Roothide support: try with or without /rootfs prefix
    if (![path hasPrefix:@"/rootfs"]) {
        NSString *rPath = [@"/rootfs" stringByAppendingPathComponent:path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:rPath]) {
            return [NSURL fileURLWithPath:rPath];
        }
    } else {
        NSString *s = [path substringFromIndex:7];
        if ([[NSFileManager defaultManager] fileExistsAtPath:s]) {
            return [NSURL fileURLWithPath:s];
        }
    }

    // Check for iCloud dataless placeholder .name.icloud
    NSString *dir = [path stringByDeletingLastPathComponent];
    NSString *last = [path lastPathComponent];
    NSString *icloudName = [NSString stringWithFormat:@".%@.icloud", last];
    NSString *icloudPath = [dir stringByAppendingPathComponent:icloudName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:icloudPath]) {
        return [NSURL fileURLWithPath:icloudPath];
    }

    return [NSURL fileURLWithPath:path];
}

- (NSURL *)resolveExecutableURL:(NSURL *)url {
    if (!url) return nil;
    NSString *path = url.path;

    // 1. Nếu là launcher stub (ví dụ HuntRoyale 88KB trong HuntRoyale.app), tự động tìm UnityFramework
    NSString *appDir = nil;
    if ([path.pathExtension isEqualToString:@"app"]) {
        appDir = path;
    } else {
        NSString *parent = [path stringByDeletingLastPathComponent];
        if ([parent.pathExtension isEqualToString:@"app"]) {
            appDir = parent;
        }
    }

    if (appDir) {
        NSString *ufPath = [appDir stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:ufPath]) {
            return [NSURL fileURLWithPath:ufPath];
        }
    }

    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDir] && isDir) {
        NSString *baseName = url.URLByDeletingPathExtension.lastPathComponent;
        NSURL *candidate = [url URLByAppendingPathComponent:baseName];
        BOOL candIsDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:candidate.path isDirectory:&candIsDir] && !candIsDir) {
            return candidate;
        }
        NSURL *plistURL = [url URLByAppendingPathComponent:@"Info.plist"];
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:plistURL];
        NSString *execName = dict[@"CFBundleExecutable"];
        if (execName.length) {
            NSURL *execURL = [url URLByAppendingPathComponent:execName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:execURL.path]) {
                return execURL;
            }
        }
        NSArray<NSURL *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
        for (NSURL *fileURL in contents) {
            BOOL fDir = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path isDirectory:&fDir] && !fDir) {
                NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
                if (fh) {
                    NSData *hdr = [fh readDataOfLength:4];
                    [fh closeFile];
                    if (hdr.length >= 4) {
                        uint32_t magic = *(const uint32_t *)hdr.bytes;
                        if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64 ||
                            magic == MH_MAGIC || magic == MH_CIGAM ||
                            magic == FAT_MAGIC || magic == FAT_CIGAM ||
                            magic == FAT_MAGIC_64 || magic == FAT_CIGAM_64) {
                            return fileURL;
                        }
                    }
                }
            }
        }
    }
    return url;
}

- (NSData *)readDataFromURL:(NSURL *)rawURL error:(NSError **)outError {
    if (!rawURL) return nil;
    BOOL rawScoped = [rawURL startAccessingSecurityScopedResource];
    NSURL *targetURL = [self resolveExecutableURL:rawURL];
    BOOL targetScoped = NO;
    if (![targetURL isEqual:rawURL]) {
        targetScoped = [targetURL startAccessingSecurityScopedResource];
    }

    __block NSData *data = nil;
    __block NSError *readError = nil;

    // 1. Đọc trực tiếp
    data = [NSData dataWithContentsOfURL:targetURL options:0 error:&readError];

    // 2. Dự phòng roothide path translation nếu chưa có /rootfs
    if (!data && [targetURL isFileURL]) {
        NSString *p = targetURL.path;
        NSString *altPath = nil;
        if (![p hasPrefix:@"/rootfs"]) {
            altPath = [@"/rootfs" stringByAppendingPathComponent:p];
        } else {
            altPath = [p substringFromIndex:7];
        }
        if (altPath && [[NSFileManager defaultManager] fileExistsAtPath:altPath]) {
            NSURL *altURL = [NSURL fileURLWithPath:altPath];
            NSError *altErr = nil;
            data = [NSData dataWithContentsOfURL:altURL options:0 error:&altErr];
            if (data) {
                targetURL = altURL;
                readError = nil;
            }
        }
    }

    // 3. Dự phòng NSFileHandle
    if (!data) {
        NSError *fhError = nil;
        NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL:targetURL error:&fhError];
        if (fh) {
            data = [fh readDataToEndOfFile];
            [fh closeFile];
            if (data.length > 0) readError = nil;
        }
    }

    // 4. Dự phòng NSFileCoordinator với options:0
    if (!data) {
        __block NSData *coordData = nil;
        __block NSError *cErr = nil;
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        NSError *coordError = nil;
        [coordinator coordinateReadingItemAtURL:targetURL options:0 error:&coordError byAccessor:^(NSURL *newURL) {
            BOOL nScoped = [newURL startAccessingSecurityScopedResource];
            coordData = [NSData dataWithContentsOfURL:newURL options:0 error:&cErr];
            if (!coordData) {
                NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL:newURL error:nil];
                if (fh) {
                    coordData = [fh readDataToEndOfFile];
                    [fh closeFile];
                }
            }
            if (nScoped) [newURL stopAccessingSecurityScopedResource];
        }];
        if (coordData) {
            data = coordData;
            readError = nil;
        } else if (cErr) {
            readError = cErr;
        } else if (coordError) {
            readError = coordError;
        }
    }

    // 5. Nếu là ubiquitous item (iCloud), yêu cầu hệ thống tải về
    if (!data && [targetURL isFileURL]) {
        if ([[NSFileManager defaultManager] isUbiquitousItemAtURL:targetURL]) {
            [[NSFileManager defaultManager] startDownloadingUbiquitousItemAtURL:targetURL error:nil];
        }
    }

    if (targetScoped) [targetURL stopAccessingSecurityScopedResource];
    if (rawScoped) [rawURL stopAccessingSecurityScopedResource];

    if (!data && outError) {
        *outError = readError;
    }
    return data;
}

static NSString *UDKCPUName(cpu_type_t cpu) {
    switch (cpu) {
        case CPU_TYPE_ARM64: return @"arm64";
        case CPU_TYPE_X86_64: return @"x86_64";
        case CPU_TYPE_ARM: return @"arm";
        case CPU_TYPE_I386: return @"i386";
        default: return [NSString stringWithFormat:@"cpu 0x%x", cpu];
    }
}

static NSString *UDKHex(const unsigned char *bytes, NSUInteger length) {
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < length; i++) [s appendFormat:@"%02x", bytes[i]];
    return s;
}

- (NSArray<NSString *> *)interestingStringsInData:(NSData *)data {
    const unsigned char *b = data.bytes; NSUInteger n = data.length;
    NSArray *needles = @[@"global-metadata", @"il2cpp", @"Il2Cpp", @"UnityFramework", @"mono", @"MonoBleedingEdge", @"Assembly-CSharp", @"libunity", @"/Script/Engine", @"/Script/CoreUObject", @"FNamePool", @"GUObjectArray", @"ProcessEvent", @"++UE4+Release", @"++UE5+Release"];
    NSMutableArray *found = [NSMutableArray array];
    NSUInteger start = NSNotFound;
    NSUInteger scanLimit = MIN(n, (NSUInteger)64 * 1024 * 1024);
    for (NSUInteger i = 0; i < scanLimit; i++) {
        BOOL printable = (b[i] >= 0x20 && b[i] <= 0x7e);
        if (printable && start == NSNotFound) start = i;
        if ((!printable || i == scanLimit - 1) && start != NSNotFound) {
            NSUInteger end = (i == scanLimit - 1 && printable) ? i + 1 : i;
            if (end - start >= 4 && end - start <= 160) {
                NSString *s = [[NSString alloc] initWithBytes:b + start length:end - start encoding:NSASCIIStringEncoding];
                if (s) {
                    for (NSString *needle in needles) {
                        if ([s rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            [found addObject:s];
                            break;
                        }
                    }
                }
            }
            start = NSNotFound;
        }
        if (found.count >= 20) break;
    }
    return found;
}

- (NSString *)metadataSummary:(NSData *)metadata {
    if (metadata.length < 8) return @"Metadata: quá ngắn để đọc header.";
    uint32_t magic = 0, version = 0;
    [metadata getBytes:&magic length:4];
    [metadata getBytes:&version range:NSMakeRange(4, 4)];
    if (magic == 0xFAB11BAF) return [NSString stringWithFormat:@"Metadata header: hợp lệ (magic 0x%08x), version %u, %llu bytes", magic, version, (unsigned long long)metadata.length];
    return [NSString stringWithFormat:@"Metadata header: không khớp magic IL2CPP (0x%08x), %llu bytes", magic, (unsigned long long)metadata.length];
}

- (NSString *)findTargetAppDocumentsDirectoryFromBinaryURL:(NSURL *)binaryURL {
    if (!binaryURL) return nil;
    NSString *path = binaryURL.path;

    // Duyệt ngược lên để tìm thư mục .app
    NSString *current = path;
    NSString *appBundlePath = nil;
    while (current.length > 1 && ![current isEqualToString:@"/"]) {
        if ([current.pathExtension isEqualToString:@"app"]) {
            appBundlePath = current;
            break;
        }
        current = [current stringByDeletingLastPathComponent];
    }

    if (!appBundlePath) return nil;

    NSString *infoPlistPath = [appBundlePath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
    NSString *bundleID = infoDict[@"CFBundleIdentifier"];
    if (!bundleID.length) return nil;

    NSString *containersBase = @"/private/var/mobile/Containers/Data/Application";
    NSArray<NSString *> *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:containersBase error:nil];
    for (NSString *uuidEntry in entries) {
        NSString *metaPath = [[containersBase stringByAppendingPathComponent:uuidEntry] stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:metaPath]) {
            NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
            if ([meta[@"MCMMetadataIdentifier"] isEqualToString:bundleID]) {
                NSString *docDir = [[containersBase stringByAppendingPathComponent:uuidEntry] stringByAppendingPathComponent:@"Documents"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:docDir]) {
                    return docDir;
                }
            }
        }
    }
    return nil;
}

- (void)exportDumpCS {
    [self.view endEditing:YES];
    if (!self.lastDumpFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:self.lastDumpFileURL.path]) {
        [self showMessage:@"Chưa có dump.cs" message:@"Hãy chọn tệp global-metadata.dat và bấm Phân tích trước."];
        return;
    }
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[self.lastDumpFileURL]];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)shareDumpCS {
    [self.view endEditing:YES];
    if (!self.lastDumpFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:self.lastDumpFileURL.path]) {
        [self showMessage:@"Chưa có dump.cs" message:@"Hãy chọn tệp global-metadata.dat và bấm Phân tích trước."];
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[self.lastDumpFileURL] applicationActivities:nil];
    if (activity.popoverPresentationController) activity.popoverPresentationController.sourceView = self.view;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)exportUEDump {
    [self.view endEditing:YES];
    if (!self.lastUEDumpFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:self.lastUEDumpFileURL.path]) {
        [self showMessage:@"Chưa có UEDump" message:@"Hãy chọn binary Unreal Engine và bấm Phân tích trước."];
        return;
    }
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[self.lastUEDumpFileURL]];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)shareUEDump {
    [self.view endEditing:YES];
    if (!self.lastUEDumpFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:self.lastUEDumpFileURL.path]) {
        [self showMessage:@"Chưa có UEDump" message:@"Hãy chọn binary Unreal Engine và bấm Phân tích trước."];
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[self.lastUEDumpFileURL] applicationActivities:nil];
    if (activity.popoverPresentationController) activity.popoverPresentationController.sourceView = self.view;
    [self presentViewController:activity animated:YES completion:nil];
}
- (NSString *)analyzeData:(NSData *)data metadata:(NSData *)metadata {
    const unsigned char *b = data.bytes; NSUInteger n = data.length;
    BOOL macho64 = n >= 4 && (*(uint32_t *)b == MH_MAGIC_64 || *(uint32_t *)b == MH_CIGAM_64);
    BOOL macho32 = n >= 4 && (*(uint32_t *)b == MH_MAGIC || *(uint32_t *)b == MH_CIGAM);
    BOOL fat = n >= 4 && (*(uint32_t *)b == FAT_MAGIC || *(uint32_t *)b == FAT_CIGAM || *(uint32_t *)b == FAT_MAGIC_64 || *(uint32_t *)b == FAT_CIGAM_64);
    NSArray *strings = [self interestingStringsInData:data];
    NSString *ueVer = nil;
    BOOL isUE = [UEDumper isUnrealEngineBinary:data engineVersion:&ueVer];
    BOOL il2cpp = !isUE && (metadata != nil || strings.count > 0);
    NSMutableString *r = [NSMutableString stringWithFormat:@"il2cppdumpking report\n===================\nFile: %@\nSize: %llu bytes\n", self.binaryURL.lastPathComponent, (unsigned long long)n];
    [r appendFormat:@"Format: %@%@%@\n", macho64 ? @"Mach-O 64-bit" : @"", macho32 ? @"Mach-O 32-bit" : @"", fat ? @"Universal/FAT" : ((macho64 || macho32) ? @"" : @"unknown")];
    if (macho64 && n >= sizeof(struct mach_header_64)) {
        struct mach_header_64 h; memcpy(&h, b, sizeof(h));
        [r appendFormat:@"Architecture: %@\nLoad commands: %u\n", UDKCPUName(h.cputype), h.ncmds];
        uint32_t off = sizeof(h); NSMutableArray *sections = [NSMutableArray array];
        for (uint32_t i=0; i<h.ncmds && off+8<=n; i++) {
            struct load_command lc; memcpy(&lc,b+off,8);
            if (lc.cmdsize < 8 || off+lc.cmdsize>n) break;
            if (lc.cmd == LC_UUID && lc.cmdsize >= sizeof(struct uuid_command)) {
                struct uuid_command u; memcpy(&u,b+off,sizeof(u));
                [r appendFormat:@"UUID: %@\n", UDKHex(u.uuid,16)];
            }
            if (lc.cmd == LC_SEGMENT_64 && lc.cmdsize >= sizeof(struct segment_command_64)) {
                struct segment_command_64 sc; memcpy(&sc,b+off,sizeof(sc));
                uint32_t so=off+sizeof(sc);
                for (uint32_t j=0;j<sc.nsects && so+sizeof(struct section_64)<=off+lc.cmdsize;j++) {
                    struct section_64 sec; memcpy(&sec,b+so,sizeof(sec));
                    [sections addObject:[NSString stringWithFormat:@"%s (%.0llu bytes)",sec.sectname,(unsigned long long)sec.size]];
                    so += sizeof(sec);
                }
            }
            off += lc.cmdsize;
        }
        if (sections.count) [r appendFormat:@"Sections: %@\n", [sections componentsJoinedByString:@", "]];
    } else if (macho32) {
        struct mach_header h; memcpy(&h,b,sizeof(h));
        [r appendFormat:@"Architecture: %@\n", UDKCPUName(h.cputype)];
    }
    if (isUE) {
        [r appendFormat:@"\nClassification: Unreal Engine (%@ - phát hiện reflection /Script/)\n", ueVer ?: @"UE4 / UE5"];
    } else {
        [r appendFormat:@"\nClassification: %@\n", il2cpp ? @"IL2CPP (dấu hiệu metadata/chuỗi đặc trưng)" : @"Mono / Unknown"];
    }
    if (strings.count) [r appendFormat:@"Relevant strings: %@\n", [strings componentsJoinedByString:@", "]];
    if (metadata) [r appendFormat:@"%@\n", [self metadataSummary:metadata]];
    [r appendString:@"\nPhạm vi: báo cáo tĩnh, an toàn; không patch, injection, bypass DRM hoặc tải dữ liệu ngoài."];
    return r;
}

- (void)analyze {
    [self.view endEditing:YES];
    if (!self.binaryURL) return;
    self.analyzeButton.enabled = NO;
    self.reportView.text = @"Đang đọc và phân tích binary, vui lòng chờ...";

    __block NSURL *bURL = self.binaryURL;
    __block NSURL *mURL = self.metadataURL;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *bError = nil;
        NSData *binary = [self readDataFromURL:bURL error:&bError];
        if (!binary) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.analyzeButton.enabled = YES;
                NSString *errDesc = bError ? [NSString stringWithFormat:@"%@ (mã %ld, domain %@)", bError.localizedDescription, (long)bError.code, bError.domain] : @"không rõ nguyên nhân";
                NSMutableString *msg = [NSMutableString stringWithFormat:@"Không thể đọc binary được chọn.\nĐường dẫn: %@\nChi tiết lỗi: %@", bURL.path, errDesc];
                if ([bURL.path containsString:@".icloud"] || [bURL.path containsString:@"com~apple~CloudDocs"]) {
                    [msg appendString:@"\n\n[Gợi ý iCloud]: Tệp trên iCloud có thể chưa tải về bộ nhớ máy cục bộ. Bạn hãy vào app Tệp (Files) mở tệp để tải về máy, hoặc dùng Filza sao chép tệp vào thư mục máy (ví dụ /var/mobile/Documents) rồi dán đường dẫn trực tiếp vào ô nhập ở trên."];
                }
                self.reportView.text = msg;
            });
            return;
        }

        NSError *mError = nil;
        NSData *metadata = mURL ? [self readDataFromURL:mURL error:&mError] : nil;

        // Tự động phát hiện trường hợp người dùng chọn ngược Binary và Metadata
        uint32_t bMagic = 0, mMagic = 0;
        if (binary.length >= 4) [binary getBytes:&bMagic length:4];
        if (metadata.length >= 4) [metadata getBytes:&mMagic length:4];
        if (bMagic == 0xFAB11BAF && (mMagic == MH_MAGIC_64 || mMagic == MH_CIGAM_64 || mMagic == MH_MAGIC || mMagic == MH_CIGAM)) {
            NSData *tempD = binary; binary = metadata; metadata = tempD;
            NSURL *tempU = bURL; bURL = mURL; mURL = tempU;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.binaryURL = bURL;
                self.metadataURL = mURL;
                self.binaryPathField.text = bURL.path;
                self.metadataPathField.text = mURL.path;
                self.binaryLabel.text = [NSString stringWithFormat:@"Binary: %@", bURL.lastPathComponent];
                self.metadataLabel.text = [NSString stringWithFormat:@"Metadata: %@", mURL.lastPathComponent];
            });
        }

        NSString *report = [self analyzeData:binary metadata:metadata];

        // 1. Phân tích và dump nếu là Unreal Engine
        NSString *ueDetectedVer = nil;
        BOOL isUE = [UEDumper isUnrealEngineBinary:binary engineVersion:&ueDetectedVer];
        UEDumperResult *ueResult = nil;
        if (isUE) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.reportView.text = [NSString stringWithFormat:@"%@\n\n[Tiến trình]: Phát hiện Unreal Engine (%@). Đang trích xuất cấu trúc UEDump.h...", report, ueDetectedVer ?: @"UE4 / UE5"];
            });
            NSURL *ueDumpURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"UEDump.h"]];
            ueResult = [UEDumper dumpBinary:binary outputURL:ueDumpURL progressBlock:^(float progress, NSString *status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.reportView.text = [NSString stringWithFormat:@"%@\n\n[Tiến trình UEDump (%.0f%%)]: %@", report, progress * 100.0f, status];
                });
            }];
        }

        // 2. Phân tích và dump nếu là Unity IL2CPP
        IL2CPPDumperResult *dResult = nil;
        if (metadata != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.reportView.text = [NSString stringWithFormat:@"%@\n\n[Tiến trình]: Đang khởi tạo bộ phân tích IL2CPP và chuẩn bị dump.cs...", report];
            });
            NSURL *dumpOutputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"dump.cs"]];
            dResult = [IL2CPPDumper dumpMetadata:metadata binaryData:binary outputURL:dumpOutputURL progressBlock:^(float progress, NSString *status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.reportView.text = [NSString stringWithFormat:@"%@\n\n[Tiến trình dump.cs (%.0f%%)]: %@", report, progress * 100.0f, status];
                });
            }];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.analyzeButton.enabled = YES;
            NSMutableString *finalReport = [NSMutableString stringWithString:report];

            // Xử lý kết quả Unreal Engine Dump
            if (ueResult && ueResult.success) {
                self.lastUEDumpFileURL = ueResult.dumpFileURL;
                self.dumpUEButton.enabled = YES;
                self.shareUEDumpButton.enabled = YES;

                NSMutableArray<NSString *> *ueSavedLocations = [NSMutableArray array];
                NSString *sourceUEDumpPath = ueResult.dumpFileURL.path;

                NSString *targetDocDir = [self findTargetAppDocumentsDirectoryFromBinaryURL:bURL];
                if (targetDocDir.length > 0) {
                    NSString *targetUEDumpPath = [targetDocDir stringByAppendingPathComponent:@"UEDump.h"];
                    [[NSFileManager defaultManager] removeItemAtPath:targetUEDumpPath error:nil];
                    if ([[NSFileManager defaultManager] copyItemAtPath:sourceUEDumpPath toPath:targetUEDumpPath error:nil]) {
                        [ueSavedLocations addObject:[NSString stringWithFormat:@"Documents app mục tiêu:\n  %@", targetUEDumpPath]];
                    }
                }

                NSString *myDocDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                if (myDocDir.length > 0) {
                    NSString *myUEDumpPath = [myDocDir stringByAppendingPathComponent:@"UEDump.h"];
                    [[NSFileManager defaultManager] removeItemAtPath:myUEDumpPath error:nil];
                    if ([[NSFileManager defaultManager] copyItemAtPath:sourceUEDumpPath toPath:myUEDumpPath error:nil]) {
                        [ueSavedLocations addObject:[NSString stringWithFormat:@"Documents của il2cppdumpking (xem trong Files):\n  %@", myUEDumpPath]];
                    }
                }

                NSString *mobileDocDir = @"/var/mobile/Documents";
                if ([[NSFileManager defaultManager] isWritableFileAtPath:mobileDocDir]) {
                    NSString *mobileUEDumpPath = [mobileDocDir stringByAppendingPathComponent:@"UEDump.h"];
                    [[NSFileManager defaultManager] removeItemAtPath:mobileUEDumpPath error:nil];
                    if ([[NSFileManager defaultManager] copyItemAtPath:sourceUEDumpPath toPath:mobileUEDumpPath error:nil]) {
                        [ueSavedLocations addObject:[NSString stringWithFormat:@"Documents máy (/var/mobile/Documents):\n  %@", mobileUEDumpPath]];
                    }
                }

                [finalReport appendFormat:@"\n\n===================\n"
                                          "Unreal Engine Dump (UEDump.h): Đã xuất thành công!\n"
                                          "- Engine: %@ (%@)\n"
                                          "- GNames / FNamePool Offset: 0x%08llX\n"
                                          "- GUObjectArray Offset: 0x%08llX\n"
                                          "- ProcessEvent Offset: 0x%08llX\n"
                                          "- Kích thước tệp: %.2f KB (%llu bytes)\n\n"
                                          "📁 Đã tự động lưu tệp UEDump.h vào:\n",
                                          ueResult.engineType,
                                          ueResult.engineVersion,
                                          ueResult.gnamesOffset,
                                          ueResult.guobjectOffset,
                                          ueResult.processEventOffset,
                                          (double)ueResult.fileSize / 1024.0,
                                          ueResult.fileSize];

                for (NSString *loc in ueSavedLocations) {
                    [finalReport appendFormat:@"✓ %@\n\n", loc];
                }
                [finalReport appendString:@"👉 Bạn có thể bấm nút 'Xuất UEDump (.h)' hoặc 'Chia sẻ UEDump' ở trên để lưu tệp sang ứng dụng khác.\n\n"];
            } else if (isUE) {
                self.dumpUEButton.enabled = NO;
                self.shareUEDumpButton.enabled = NO;
                [finalReport appendFormat:@"\n\n[Lỗi tạo UEDump]: %@\n\n", ueResult.errorMessage ?: @"Không thể trích xuất cấu trúc Unreal Engine."];
            } else {
                self.dumpUEButton.enabled = NO;
                self.shareUEDumpButton.enabled = NO;
            }

            // Xử lý kết quả Unity IL2CPP Dump
            if (dResult && dResult.success) {
                self.lastDumpFileURL = dResult.dumpFileURL;
                self.dumpButton.enabled = YES;
                self.shareDumpButton.enabled = YES;

                NSMutableArray<NSString *> *savedLocations = [NSMutableArray array];
                NSString *sourceDumpPath = dResult.dumpFileURL.path;

                // 1. Lưu vào thư mục Documents của app mục tiêu (nếu xác định được)
                NSString *targetDocDir = [self findTargetAppDocumentsDirectoryFromBinaryURL:bURL];
                if (targetDocDir.length > 0) {
                    NSString *targetDumpPath = [targetDocDir stringByAppendingPathComponent:@"dump.cs"];
                    [[NSFileManager defaultManager] removeItemAtPath:targetDumpPath error:nil];
                    if ([[NSFileManager defaultManager] copyItemAtPath:sourceDumpPath toPath:targetDumpPath error:nil]) {
                        [savedLocations addObject:[NSString stringWithFormat:@"Documents của app mục tiêu:\n  %@", targetDumpPath]];
                    }
                }

                // 2. Lưu vào thư mục Documents của il2cppdumpking (xem trong app Tệp/Files)
                NSString *myDocDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                if (myDocDir.length > 0) {
                    NSString *myDumpPath = [myDocDir stringByAppendingPathComponent:@"dump.cs"];
                    [[NSFileManager defaultManager] removeItemAtPath:myDumpPath error:nil];
                    if ([[NSFileManager defaultManager] copyItemAtPath:sourceDumpPath toPath:myDumpPath error:nil]) {
                        [savedLocations addObject:[NSString stringWithFormat:@"Documents của il2cppdumpking (xem trong app Tệp/Files):\n  %@", myDumpPath]];
                    }
                }

                // 3. Lưu vào thư mục /var/mobile/Documents chung
                NSString *mobileDocDir = @"/var/mobile/Documents";
                if ([[NSFileManager defaultManager] isWritableFileAtPath:mobileDocDir]) {
                    NSString *mobileDumpPath = [mobileDocDir stringByAppendingPathComponent:@"dump.cs"];
                    [[NSFileManager defaultManager] removeItemAtPath:mobileDumpPath error:nil];
                    if ([[NSFileManager defaultManager] copyItemAtPath:sourceDumpPath toPath:mobileDumpPath error:nil]) {
                        [savedLocations addObject:[NSString stringWithFormat:@"Documents máy (/var/mobile/Documents):\n  %@", mobileDumpPath]];
                    }
                }

                [finalReport appendFormat:@"\n\n===================\n"
                                          "IL2CPP Dump.cs: Đã xuất thành công!\n"
                                          "- Tổng số lớp (Classes): %lu\n"
                                          "- Tổng số phương thức (Methods): %lu\n"
                                          "- Phương thức có ARM64 RVA / Offset: %lu\n"
                                          "- Kích thước tệp: %.2f MB (%llu bytes)\n\n"
                                          "📁 Đã tự động lưu tệp dump.cs vào:\n",
                                          (unsigned long)dResult.totalTypes,
                                          (unsigned long)dResult.totalMethods,
                                          (unsigned long)dResult.methodsWithRVA,
                                          (double)dResult.fileSize / (1024.0 * 1024.0),
                                          dResult.fileSize];

                for (NSString *loc in savedLocations) {
                    [finalReport appendFormat:@"✓ %@\n\n", loc];
                }

                [finalReport appendString:@"👉 Bạn cũng có thể bấm nút 'Xuất dump.cs' hoặc 'Chia sẻ dump.cs' ở trên để gửi tệp sang app khác bất cứ lúc nào."];
            } else if (metadata != nil) {
                self.dumpButton.enabled = NO;
                self.shareDumpButton.enabled = NO;
                [finalReport appendFormat:@"\n\n[Lỗi tạo dump.cs]: %@", dResult.errorMessage ?: @"Không thể tạo dump.cs."];
            } else {
                self.dumpButton.enabled = NO;
                self.shareDumpButton.enabled = NO;
                [finalReport appendString:@"\n\n[Gợi ý dump.cs]: Chưa chọn tệp global-metadata.dat. Hãy chọn hoặc dán đường dẫn metadata để tạo file dump.cs chứa class, methods, fields và ARM64 offsets."];
            }
            self.lastReport = finalReport;
            self.reportView.text = finalReport;
        });
    });
}

- (void)exportReport {
    [self.view endEditing:YES];
    if (!self.lastReport.length) { [self showMessage:@"Chưa có báo cáo" message:@"Hãy chạy Analyze trước."]; return; }
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"UnityDumpKit-report.txt"]];
    [self.lastReport writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[url]];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)shareReport {
    [self.view endEditing:YES];
    if (!self.lastReport.length) { [self showMessage:@"Chưa có báo cáo" message:@"Hãy chạy Analyze trước."]; return; }
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"UnityDumpKit-report.txt"]];
    [self.lastReport writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (activity.popoverPresentationController) activity.popoverPresentationController.sourceView = self.view;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)showMessage:(NSString *)title message:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
