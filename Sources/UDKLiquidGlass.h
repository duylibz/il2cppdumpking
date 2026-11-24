// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UDKGlassGlareMode) {
    UDKGlassGlareNone = 0,
    UDKGlassGlareBorder = 1,
    UDKGlassGlareGlass = 2
};

@interface UDKLiquidGlassCard : UIView

@property(nonatomic,readonly) UIView *contentView;
@property(nonatomic,assign) CGFloat bezelWidth;       // Default: 17.5
@property(nonatomic,assign) CGFloat glassThickness;   // Default: 120.0
@property(nonatomic,assign) CGFloat refraction;       // Default: 2.60
@property(nonatomic,assign) CGFloat ior;              // Index of Refraction (Default: 1.60)
@property(nonatomic,assign) CGFloat opacity;          // Độ mờ (Default: 0.0)
@property(nonatomic,assign) UDKGlassGlareMode glareMode; // Default: UDKGlassGlareGlass
@property(nonatomic,strong) UIColor *lightTintColor;
@property(nonatomic,strong) UIColor *darkTintColor;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)updateAppearanceForTraitCollection:(UITraitCollection *)traitCollection;

@end

@interface UDKLiquidGlassButton : UIButton

@property(nonatomic,assign) BOOL primaryAction;

+ (instancetype)buttonWithTitle:(NSString *)title primary:(BOOL)primary;

@end

@interface UDKLiquidGlassTextField : UITextField

@property(nonatomic,assign) UIEdgeInsets textInsets;

@end

@interface UDKLiquidGlassBadge : UIView

+ (instancetype)badgeWithParamsText:(NSString *)text;

@end

@interface UDKScrollToTopButton : UIButton

+ (instancetype)buttonWithTarget:(id)target action:(SEL)action;

@end

NS_ASSUME_NONNULL_END
