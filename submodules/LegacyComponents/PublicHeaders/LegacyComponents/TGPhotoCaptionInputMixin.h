#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol TGPhotoPaintStickersContext;
@protocol TGCaptionPanelView;

@interface TGPhotoCaptionInputMixin : NSObject

@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;
@property (nonatomic, readonly) UIView *backgroundView;
@property (nonatomic, readonly) id<TGCaptionPanelView> inputPanel;
@property (nonatomic, readonly) UIView *inputPanelView;
@property (nonatomic, readonly) UIView *dismissView;

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, readonly) CGFloat keyboardHeight;
@property (nonatomic, assign) CGFloat contentAreaHeight;
@property (nonatomic, assign) UIEdgeInsets safeAreaInset;
@property (nonatomic, assign) bool allowEntities;

@property (nonatomic, copy) UIView *(^panelParentView)(void);

@property (nonatomic, copy) void (^panelFocused)(void);
@property (nonatomic, copy) void (^finishedWithCaption)(NSAttributedString *caption);
@property (nonatomic, copy) void (^keyboardHeightChanged)(CGFloat keyboardHeight, NSTimeInterval duration, NSInteger animationCurve);
@property (nonatomic, copy) void (^timerUpdated)(NSNumber *timeout);
@property (nonatomic, copy) void (^captionIsAboveUpdated)(bool captionIsAbove);

@property (nonatomic, readonly) bool editing;

- (void)createInputPanelIfNeeded;
- (void)beginEditing;
- (void)finishEditing;
- (void)enableDismissal;

- (void)onAnimateOut;
    
- (void)destroy;

@property (nonatomic, strong) NSAttributedString *caption;
- (void)setCaption:(NSAttributedString *)caption animated:(bool)animated;
- (void)setCaptionPanelHidden:(bool)hidden animated:(bool)animated;

- (void)setTimeout:(int32_t)timeout isVideo:(bool)isVideo isCaptionAbove:(bool)isCaptionAbove;

- (void)updateLayoutWithFrame:(CGRect)frame edgeInsets:(UIEdgeInsets)edgeInsets animated:(bool)animated;

@end
