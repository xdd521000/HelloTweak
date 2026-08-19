//
//  Tweak.x — 小叮当（微信增强插件）
//  功能：
//    1. 通过「插件收纳」(WCPluginsMgr) 注册到 微信→我→插件 页面
//    2. 主菜单分两类：常用功能（防撤回/撤回提示）、红包功能（自动抢红包）
//    3. 防撤回开关 + 自定义撤回提示语
//    4. 自动抢红包（延迟秒数 / 只抢群聊 / 只抢单聊 / 防重复）
//  说明：不弹窗，所有设置都在插件页面里操作。
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// 自适应防撤回安装函数（定义在文件下方，这里先声明）
static void xddScheduleAdaptiveRevokeInstall(void);

// ============================================================
//  1. 设置存取
// ============================================================

static NSString *const kPrefsSuite = @"com.yourname.hellotweak";
static NSString *const kAntiRevokeKey = @"AntiRevoke";
static NSString *const kRevokeNoticeKey = @"RevokeNoticeText";
static NSString *const kRevokeToastKey = @"RevokeToastEnabled";
static NSString *const kAutoRedEnvelopKey = @"AutoRedEnvelop";
static NSString *const kGrabDelayKey = @"GrabDelaySeconds";
static NSString *const kGrabGroupKey = @"GrabGroupChat";
static NSString *const kGrabSingleKey = @"GrabSingleChat";
static NSString *const kGrabbedSendIdsKey = @"GrabbedSendIds";
static NSString *const kWallpaperKey = @"WallpaperData";
static NSString *const kDevNameKey = @"DevName";

static NSUserDefaults *xddPrefs(void) {
    return [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
}

static BOOL antiRevokeEnabled(void) {
    return [xddPrefs() boolForKey:kAntiRevokeKey];
}
static void setAntiRevokeEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kAntiRevokeKey]; [p synchronize];
}

static NSString *revokeNoticeText(void) {
    NSString *t = [xddPrefs() stringForKey:kRevokeNoticeKey];
    return (t.length > 0) ? t : @"对方撤回了一条消息（已被小叮当拦截）";
}
static void setRevokeNoticeText(NSString *t) {
    NSUserDefaults *p = xddPrefs(); [p setObject:t forKey:kRevokeNoticeKey]; [p synchronize];
}

static BOOL revokeToastEnabled(void) {
    return [xddPrefs() boolForKey:kRevokeToastKey];
}
static void setRevokeToastEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kRevokeToastKey]; [p synchronize];
}

static BOOL autoRedEnvelopEnabled(void) {
    return [xddPrefs() boolForKey:kAutoRedEnvelopKey];
}
static void setAutoRedEnvelopEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kAutoRedEnvelopKey]; [p synchronize];
}

static NSInteger grabDelaySeconds(void) {
    NSInteger d = [xddPrefs() integerForKey:kGrabDelayKey];
    if (d < 0 || d > 60) d = 1;
    return d;
}
static void setGrabDelaySeconds(NSInteger d) {
    NSUserDefaults *p = xddPrefs(); [p setInteger:d forKey:kGrabDelayKey]; [p synchronize];
}

static BOOL grabGroupChatEnabled(void) {
    return [xddPrefs() boolForKey:kGrabGroupKey];
}
static void setGrabGroupChatEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kGrabGroupKey]; [p synchronize];
}

static BOOL grabSingleChatEnabled(void) {
    return [xddPrefs() boolForKey:kGrabSingleKey];
}
static void setGrabSingleChatEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kGrabSingleKey]; [p synchronize];
}

// 壁纸数据
static NSData *xddWallpaperData(void) {
    return [xddPrefs() dataForKey:kWallpaperKey];
}
static void setXddWallpaperData(NSData *d) {
    NSUserDefaults *p = xddPrefs();
    if (d) {
        [p setObject:d forKey:kWallpaperKey];
    } else {
        [p removeObjectForKey:kWallpaperKey];
    }
    [p synchronize];
}

// 压缩图片尺寸，防止保存太大
static UIImage *xddResizedImage(UIImage *image, CGFloat maxDim) {
    CGFloat w = image.size.width;
    CGFloat h = image.size.height;
    if (w <= maxDim && h <= maxDim) return image;
    CGFloat ratio = MIN(maxDim / w, maxDim / h);
    CGSize newSize = CGSizeMake(floorf(w * ratio), floorf(h * ratio));
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage ?: image;
}

// 开发者信息
static NSString *xddDevName(void) {
    NSString *n = [xddPrefs() stringForKey:kDevNameKey];
    return (n.length > 0) ? n : @"xdd521000";
}
static void setXddDevName(NSString *n) {
    NSUserDefaults *p = xddPrefs();
    [p setObject:n forKey:kDevNameKey];
    [p synchronize];
}

// 防重复：已经抢过的红包 sendId 集合
static BOOL isSendIdGrabbed(NSString *sendId) {
    if (!sendId) return NO;
    NSArray *list = [xddPrefs() arrayForKey:kGrabbedSendIdsKey];
    return [list containsObject:sendId];
}
static void markSendIdGrabbed(NSString *sendId) {
    if (!sendId) return;
    NSUserDefaults *p = xddPrefs();
    NSMutableArray *list = [[p arrayForKey:kGrabbedSendIdsKey] mutableCopy];
    if (!list) list = [NSMutableArray array];
    if (![list containsObject:sendId]) [list addObject:sendId];
    if (list.count > 500) [list removeObjectsInRange:NSMakeRange(0, list.count - 500)]; // 只留最近500个
    [p setObject:list forKey:kGrabbedSendIdsKey];
    [p synchronize];
}

// 插件收纳接入：让「小叮当」出现在 微信→我→插件 页面
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

static BOOL xddShelfRegistered = NO;
static void xddRegisterShelf(void) {
    if (xddShelfRegistered) return;
    Class cls = NSClassFromString(@"WCPluginsMgr");
    if (!cls) return;
    WCPluginsMgr *mgr = [cls sharedInstance];
    if (!mgr) return;
    if (![mgr respondsToSelector:@selector(registerControllerWithTitle:version:controller:)]) return;
    [mgr registerControllerWithTitle:@"小叮当" version:@"0.0.14" controller:@"XDDSettingsViewController"];
    xddShelfRegistered = YES;
}

%ctor {
    xddRegisterShelf();
    xddScheduleAdaptiveRevokeInstall();
    if (!xddShelfRegistered) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            xddRegisterShelf();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            xddRegisterShelf();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            xddRegisterShelf();
        });
    }
}

// ============================================================
//  2. 顶部提示条
// ============================================================

static void showRecallToast(NSString *text) {
    static NSDate *lastShown = nil;
    NSDate *now = [NSDate date];
    if (lastShown && [now timeIntervalSinceDate:lastShown] < 2.0) return;
    lastShown = now;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *toastWin = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        toastWin.windowLevel = 2001;
        toastWin.backgroundColor = [UIColor clearColor];
        toastWin.userInteractionEnabled = NO;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    toastWin.windowScene = (UIWindowScene *)scene;
                    break;
                }
            }
        }
        toastWin.hidden = NO;

        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectZero];
        toast.text = text;
        toast.textColor = [UIColor whiteColor];
        toast.font = [UIFont systemFontOfSize:13];
        toast.numberOfLines = 0;
        toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.layer.cornerRadius = 10;
        toast.layer.masksToBounds = YES;

        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGSize size = [toast sizeThatFits:CGSizeMake(screenW - 60, CGFLOAT_MAX)];
        toast.frame = CGRectMake((screenW - size.width - 24) / 2, 70, size.width + 24, size.height + 16);
        toast.alpha = 0;
        [toastWin addSubview:toast];

        [UIView animateWithDuration:0.25 animations:^{ toast.alpha = 1; }
            completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3 delay:1.8 options:0 animations:^{ toast.alpha = 0; }
                    completion:^(BOOL finished) { toastWin.hidden = YES; }];
            }];
    });
}

// ============================================================
//  3. 微信私有类声明
// ============================================================

@interface MMContext : NSObject
+ (id)activeUserContext;
- (id)getService:(Class)arg1;
@end

@interface CMessageWrap : NSObject
@property(retain, nonatomic) id m_oWCPayInfoItem;
@property(retain, nonatomic) NSString *m_nsContent;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(assign, nonatomic) NSUInteger m_uiMessageType;
@end

@interface WCPayInfoItem : NSObject
@property(retain, nonatomic) NSString *m_c2cNativeUrl;
@end

@interface WCBizUtil : NSObject
+ (id)dictionaryWithDecodedComponets:(id)arg1 separator:(id)arg2;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsHeadImgUrl;
- (id)getContactDisplayName;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)OpenRedEnvelopesRequest:(id)params;
- (void)ReceiverQueryRedEnvelopesRequest:(id)arg1;
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;
- (NSDictionary *)xddJsonToDict:(NSString *)json;
@end

@interface HongBaoRes : NSObject
@property(retain, nonatomic) id retText;
@property(nonatomic) int cgiCmdid;
@end

@interface HongBaoReq : NSObject
@property(retain, nonatomic) id reqText;
@end

@interface SKBuiltinBuffer_t : NSObject
@property(retain, nonatomic) NSData *buffer;
@end

// ============================================================
//  4. 小叮当设置页（深
