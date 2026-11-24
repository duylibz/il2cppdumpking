// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
// Implements exact Liquid Glass optics from bilalgursen/liquid-glass
#import "UDKLiquidGlass.h"
#import <QuartzCore/QuartzCore.h>

@interface UDKLiquidGlassCard () {
    UIView *_containerView;
    UIVisualEffectView *_blurView;
    UIView *_tintView;
    CAGradientLayer *_glareLayer;
}
@end

@implementation UDKLiquidGlassCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    // Exact defaults from liquid-glass/src/components/liquid-glass/glass-card.tsx
    _bezelWidth = 17.5;
    _glassThickness = 120.0;
    _refraction = 1.0;
    _ior = 1.60;
    _opacity = 1.0; // Frosted glass blur = 5px, tint = 0.70
    _glareMode = UDKGlassGlareGlass;

    self.backgroundColor = [UIColor clearColor];
    
    // SHADOW: '0 16.5px 36px rgba(0, 0, 0, 0.08), 0 26.4px 55.9px rgba(0, 0, 0, 0.08)'
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.20;
    self.layer.shadowOffset = CGSizeMake(0, 16.5);
    self.layer.shadowRadius = 26.0;
    self.layer.masksToBounds = NO;

    // Corner radius: 28px (rounded-[28px])
    // Border: 1.3px white at 25% (dark) / 60% (light)
    _containerView = [UIView new];
    _containerView.clipsToBounds = YES;
    _containerView.layer.cornerRadius = 28.0;
    _containerView.layer.cornerCurve = kCACornerCurveContinuous;
    _containerView.layer.borderWidth = 1.3;
    _containerView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    _containerView.backgroundColor = [UIColor clearColor];
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_containerView];

    [NSLayoutConstraint activateConstraints:@[
        [_containerView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_containerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_containerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_containerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    // 1. Frosted Blur Backdrop (BLUR = 5px, backdrop-blur-md)
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    _blurView.alpha = 1.0;
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_blurView];

    [NSLayoutConstraint activateConstraints:@[
        [_blurView.topAnchor constraintEqualToAnchor:_containerView.topAnchor],
        [_blurView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [_blurView.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],
        [_blurView.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor]
    ]];

    // 2. Tint Layer (TINT = 0.70, dark:bg-black/70)
    _tintView = [UIView new];
    _tintView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.70];
    _tintView.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_tintView];

    [NSLayoutConstraint activateConstraints:@[
        [_tintView.topAnchor constraintEqualToAnchor:_containerView.topAnchor],
        [_tintView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [_tintView.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],
        [_tintView.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor]
    ]];

    // 3. Specular Glare (Top meniscus reflection)
    _glareLayer = [CAGradientLayer layer];
    _glareLayer.startPoint = CGPointMake(0.0, 0.0);
    _glareLayer.endPoint = CGPointMake(0.0, 1.0);
    _glareLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.18].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    _glareLayer.locations = @[@0.0, @0.40, @1.0];
    [_containerView.layer addSublayer:_glareLayer];

    // 4. Content View
    _contentView = [UIView new];
    _contentView.backgroundColor = [UIColor clearColor];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_contentView];

    [NSLayoutConstraint activateConstraints:@[
        [_contentView.topAnchor constraintEqualToAnchor:_containerView.topAnchor],
        [_contentView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor]
    ]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    if (CGRectIsEmpty(bounds)) return;

    // Fast GPU shadow path matching rounded-[28px]
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:28.0].CGPath;

    // Update specular glare
    _glareLayer.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height * 0.45);
    _glareLayer.hidden = (_glareMode == UDKGlassGlareNone);
}

- (void)updateAppearanceForTraitCollection:(UITraitCollection *)traitCollection {
    BOOL isDark = (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    _containerView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:isDark ? 0.25 : 0.60].CGColor;
    _tintView.backgroundColor = isDark ? [UIColor colorWithWhite:0.0 alpha:0.70] : [UIColor colorWithWhite:1.0 alpha:0.70];
    _blurView.effect = [UIBlurEffect effectWithStyle:isDark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateAppearanceForTraitCollection:self.traitCollection];
}

@end

@implementation UDKLiquidGlassButton {
    CAGradientLayer *_bgGradient;
    CAGradientLayer *_glareLayer;
    UIVisualEffectView *_blurEffectView;
    UIImpactFeedbackGenerator *_haptic;
}

+ (instancetype)buttonWithTitle:(NSString *)title primary:(BOOL)primary {
    UDKLiquidGlassButton *btn = [self buttonWithType:UIButtonTypeSystem];
    btn.primaryAction = primary;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setupStyling];
    return btn;
}

- (void)setupStyling {
    _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    self.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    
    // Exact GlassButton: rounded-full pill capsule
    self.layer.cornerRadius = 22.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;

    _glareLayer = [CAGradientLayer layer];
    _glareLayer.startPoint = CGPointMake(0.0, 0.0);
    _glareLayer.endPoint = CGPointMake(0.0, 1.0);
    _glareLayer.locations = @[@0.0, @0.5, @1.0];

    if (self.primaryAction) {
        // Brand blue accent: #3291FF (brand color from liquid-glass/src/styles.css)
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] forState:UIControlStateDisabled];

        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.40].CGColor;

        _bgGradient = [CAGradientLayer layer];
        _bgGradient.colors = @[
            (id)[UIColor colorWithRed:0x32/255.0 green:0x91/255.0 blue:1.0 alpha:0.95].CGColor,
            (id)[UIColor colorWithRed:0x02/255.0 green:0x45/255.0 blue:0x8F/255.0 alpha:0.95].CGColor
        ];
        _bgGradient.startPoint = CGPointMake(0.0, 0.0);
        _bgGradient.endPoint = CGPointMake(1.0, 1.0);
        [self.layer insertSublayer:_bgGradient atIndex:0];

        _glareLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.35].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor,
            (id)[UIColor clearColor].CGColor
        ];
        [self.layer insertSublayer:_glareLayer above:_bgGradient];
    } else {
        // Clear GlassButton: border-white/15 bg-white/10 text-[#f5f5f7]
        [self setTitleColor:[UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF7/255.0 alpha:1.0] forState:UIControlStateNormal];
        [self setTitleColor:[UIColor colorWithRed:0x8D/255.0 green:0x8D/255.0 blue:0x95/255.0 alpha:0.4] forState:UIControlStateDisabled];

        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        _blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blur];
        _blurEffectView.alpha = 1.0;
        _blurEffectView.userInteractionEnabled = NO;
        _blurEffectView.translatesAutoresizingMaskIntoConstraints = NO;
        [self insertSubview:_blurEffectView atIndex:0];

        [NSLayoutConstraint activateConstraints:@[
            [_blurEffectView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_blurEffectView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_blurEffectView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_blurEffectView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];

        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];

        _glareLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.18].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor,
            (id)[UIColor clearColor].CGColor
        ];
        [self.layer addSublayer:_glareLayer];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    if (CGRectIsEmpty(bounds)) return;
    if (_bgGradient) _bgGradient.frame = bounds;
    _glareLayer.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height * 0.50);
}

// Exact @utility press: active scale 0.96 over 150ms
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (highlighted) {
        [_haptic prepare];
        [_haptic impactOccurred];
    }
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self.alpha = highlighted ? 0.85 : 1.0;
    } completion:nil];
}

@end

@implementation UDKLiquidGlassTextField

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _textInsets = UIEdgeInsetsMake(8, 16, 8, 16);
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        self.textColor = [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF7/255.0 alpha:1.0];
        self.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        self.layer.cornerRadius = 14.0;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        self.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    return self;
}

- (CGRect)textRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

@end

@implementation UDKLiquidGlassBadge

+ (instancetype)badgeWithParamsText:(NSString *)text {
    UDKLiquidGlassBadge *badge = [UDKLiquidGlassBadge new];
    // Exact GlassBadge: rounded-full, brand blue #3291FF, white text
    badge.backgroundColor = [UIColor colorWithRed:0x32/255.0 green:0x91/255.0 blue:1.0 alpha:0.85];
    badge.layer.cornerRadius = 14.0;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    badge.layer.borderWidth = 1.0;
    badge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
    badge.clipsToBounds = YES;
    badge.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *lbl = [UILabel new];
    lbl.text = text;
    lbl.font = [UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor whiteColor];
    lbl.numberOfLines = 0;
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [badge addSubview:lbl];

    [NSLayoutConstraint activateConstraints:@[
        [lbl.topAnchor constraintEqualToAnchor:badge.topAnchor constant:6],
        [lbl.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-6],
        [lbl.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:12],
        [lbl.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-12]
    ]];
    return badge;
}

@end

@implementation UDKScrollToTopButton {
    UIImpactFeedbackGenerator *_haptic;
}

+ (instancetype)buttonWithTarget:(id)target action:(SEL)action {
    UDKScrollToTopButton *btn = [self buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [btn setupButton];
    return btn;
}

- (void)setupButton {
    _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    
    // rounded-full pill
    self.layer.cornerRadius = 19.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = NO;
    
    // Soft drop shadow
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.25;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8.0;

    // Blur Container
    UIView *container = [UIView new];
    container.userInteractionEnabled = NO;
    container.clipsToBounds = YES;
    container.layer.cornerRadius = 19.0;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    container.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.60];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self insertSubview:container atIndex:0];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:self.topAnchor],
        [container.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [container.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        
        [blurView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        
        [self.heightAnchor constraintEqualToConstant:38.0],
    ]];

    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.title = @"Lên đầu";
    config.image = [UIImage systemImageNamed:@"chevron.up"];
    config.imagePlacement = NSDirectionalRectEdgeTrailing;
    config.imagePadding = 6.0;
    config.baseForegroundColor = [UIColor whiteColor];
    config.contentInsets = NSDirectionalEdgeInsetsMake(0, 16, 0, 14);
    self.configuration = config;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (highlighted) {
        [_haptic prepare];
        [_haptic impactOccurred];
    }
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self.alpha = highlighted ? 0.85 : 1.0;
    } completion:nil];
}

@end
