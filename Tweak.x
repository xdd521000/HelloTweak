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
    [mgr registerControllerWithTitle:@"小叮当" version:@"0.0.11" controller:@"XDDSettingsViewController"];
    xddShelfRegistered = YES;
}

%ctor {
    xddRegisterShelf();
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
//  4. 小叮当设置页（深空蓝调：主菜单 + 常用功能 + 红包功能）
// ============================================================

// 长按换壁纸倒计时相关状态
static UILabel *xddWpOverlay = nil;
static NSTimer *xddWpTicker = nil;
static NSInteger xddWpRemain = 5;
static BOOL xddWpArmed = NO;


static UIColor *xddDeepSpaceColor(void) {
    return [UIColor colorWithRed:0.04 green:0.07 blue:0.13 alpha:1.0];
}

@interface XDDSettingsViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
- (UIButton *)xddMenuCellWithTitle:(NSString *)title y:(CGFloat)y tag:(NSInteger)tag;
- (void)menuTapped:(UIButton *)sender;
- (void)xddWallpaperLongPress:(UILongPressGestureRecognizer *)gr;
- (void)xddWpShowOverlay;
- (void)xddWpTick;
- (void)xddWpCancel;
- (void)xddOpenWallpaperPicker;
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
- (void)xddDevLabelLongPress:(UILongPressGestureRecognizer *)gr;
- (void)xddPromptNewDevName;
- (void)xddRefreshDevLabel;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface XDDCommonViewController : UIViewController
- (UIView *)xddCardWithFrame:(CGRect)frame;
- (UISwitch *)xddSwitchInCard:(UIView *)card on:(BOOL)on tag:(NSInteger)tag;
- (UILabel *)xddLabelInCard:(UIView *)card text:(NSString *)text;
- (void)switchChanged:(UISwitch *)sender;
- (void)noticeChanged:(UITextField *)sender;
@end

@interface XDDRedPacketViewController : UIViewController
- (UIView *)xddCardWithFrame:(CGRect)frame;
- (UISwitch *)xddSwitchInCard:(UIView *)card on:(BOOL)on tag:(NSInteger)tag;
- (UILabel *)xddLabelInCard:(UIView *)card text:(NSString *)text;
- (void)switchChanged:(UISwitch *)sender;
- (void)delayChanged:(UITextField *)sender;
@end

@implementation XDDSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小叮当";
    self.view.backgroundColor = xddDeepSpaceColor();

    // 自定义壁纸（如果之前保存过照片）
    NSData *wpData = xddWallpaperData();
    if (wpData) {
        UIImage *wpImg = [UIImage imageWithData:wpData];
        if (wpImg) {
            UIImageView *bg = [[UIImageView alloc] initWithFrame:self.view.bounds];
            bg.image = wpImg;
            bg.contentMode = UIViewContentModeScaleAspectFill;
            bg.clipsToBounds = YES;
            [self.view insertSubview:bg atIndex:0];
        }
    }

    // 顶部居中：插件名 + 开发者信息
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, self.view.bounds.size.width - 40, 36)];
    nameLabel.text = @"小叮当";
    nameLabel.font = [UIFont boldSystemFontOfSize:26];
    nameLabel.textColor = [UIColor colorWithRed:0.92 green:0.96 blue:1.0 alpha:1.0];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:nameLabel];

    UILabel *devLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, self.view.bounds.size.width - 40, 20)];
    devLabel.text = [NSString stringWithFormat:@"开发者：%@", xddDevName()];
    devLabel.font = [UIFont systemFontOfSize:13];
    devLabel.textColor = [UIColor colorWithRed:0.5 green:0.64 blue:0.8 alpha:1.0];
    devLabel.textAlignment = NSTextAlignmentCenter;
    devLabel.tag = 1001;
    devLabel.userInteractionEnabled = YES;
    [self.view addSubview:devLabel];

    // 长按开发者信息 → 弹窗修改开发者信息
    UILongPressGestureRecognizer *devLp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(xddDevLabelLongPress:)];
    devLp.minimumPressDuration = 0.5;
    [devLabel addGestureRecognizer:devLp];

    // 常用功能入口（无图标、无说明文字）
    UIButton *commonBtn = [self xddMenuCellWithTitle:@"常用功能" y:210 tag:1];
    [self.view addSubview:commonBtn];

    // 红包功能入口
    UIButton *redBtn = [self xddMenuCellWithTitle:@"红包功能" y:278 tag:2];
    [self.view addSubview:redBtn];

    // 长按背景 5 秒 → 弹出相册换壁纸（带倒计时提示，按满 5 秒自动打开相册）
    UILongPressGestureRecognizer *wpLp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(xddWallpaperLongPress:)];
    wpLp.minimumPressDuration = 0.5;
    wpLp.cancelsTouchesInView = NO;
    wpLp.allowableMovement = 80.0;
    [self.view addGestureRecognizer:wpLp];

    // 底部提示（长按玩法）
    UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 370, self.view.bounds.size.width - 40, 30)];
    hintLabel.text = @"长按背景 5 秒换壁纸 · 长按开发者信息改签名";
    hintLabel.font = [UIFont systemFontOfSize:11];
    hintLabel.textColor = [UIColor colorWithRed:0.35 green:0.48 blue:0.65 alpha:1.0];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:hintLabel];
}

- (UIButton *)xddMenuCellWithTitle:(NSString *)title y:(CGFloat)y tag:(NSInteger)tag {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(20, y, self.view.bounds.size.width - 40, 56);
    btn.backgroundColor = [UIColor colorWithRed:0.12 green:0.18 blue:0.29 alpha:0.55];
    btn.layer.cornerRadius = 18;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor colorWithRed:0.43 green:0.71 blue:1.0 alpha:0.22].CGColor;
    btn.tag = tag;
    [btn addTarget:self action:@selector(menuTapped:) forControlEvents:UIControlEventTouchUpInside];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 0, 180, 56)];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    titleLabel.textColor = [UIColor colorWithRed:0.91 green:0.95 blue:1.0 alpha:1.0];
    [btn addSubview:titleLabel];

    UILabel *chev = [[UILabel alloc] initWithFrame:CGRectMake(btn.bounds.size.width - 42, 11, 26, 34)];
    chev.text = @"›";
    chev.font = [UIFont systemFontOfSize:28];
    chev.textColor = [UIColor colorWithRed:0.4 green:0.78 blue:1.0 alpha:1.0];
    [btn addSubview:chev];

    return btn;
}

- (void)menuTapped:(UIButton *)sender {
    UIViewController *vc = nil;
    if (sender.tag == 1) {
        vc = [[XDDCommonViewController alloc] init];
    } else if (sender.tag == 2) {
        vc = [[XDDRedPacketViewController alloc] init];
    }
    if (vc) [self.navigationController pushViewController:vc animated:YES];
}

// 长按背景 5 秒 → 弹出相册选照片设为壁纸
- (void)xddWallpaperLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) {
        // 已有弹窗（比如正在改开发者信息）时，不启动换壁纸倒计时
        if (self.presentedViewController) return;
        xddWpRemain = 5;
        xddWpArmed = YES;
        [self xddWpShowOverlay];
        xddWpTicker = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(xddWpTick) userInfo:nil repeats:YES];
    } else if (gr.state == UIGestureRecognizerStateEnded ||
               gr.state == UIGestureRecognizerStateCancelled ||
               gr.state == UIGestureRecognizerStateFailed) {
        [self xddWpCancel];
    }
}

- (void)xddWpShowOverlay {
    if (xddWpOverlay) return;
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 250, 62)];
    l.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2 - 40);
    l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78];
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont boldSystemFontOfSize:15];
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = 2;
    l.layer.cornerRadius = 14;
    l.layer.masksToBounds = YES;
    l.text = [NSString stringWithFormat:@"继续按住 %ld 秒换壁纸\n松开可取消", (long)xddWpRemain];
    [self.view addSubview:l];
    xddWpOverlay = l;
}

- (void)xddWpTick {
    if (!xddWpArmed) { [self xddWpCancel]; return; }
    xddWpRemain--;
    if (xddWpRemain <= 0) {
        xddWpArmed = NO;
        [xddWpTicker invalidate];
        xddWpTicker = nil;
        [xddWpOverlay removeFromSuperview];
        xddWpOverlay = nil;
        [self xddOpenWallpaperPicker];
    } else if (xddWpOverlay) {
        xddWpOverlay.text = [NSString stringWithFormat:@"继续按住 %ld 秒换壁纸\n松开可取消", (long)xddWpRemain];
    }
}

- (void)xddWpCancel {
    xddWpArmed = NO;
    [xddWpTicker invalidate];
    xddWpTicker = nil;
    [xddWpOverlay removeFromSuperview];
    xddWpOverlay = nil;
}

- (void)xddOpenWallpaperPicker {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.delegate = self;
        picker.allowsEditing = YES;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage];
    if (!image) image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!image) return;
    UIImage *finalImage = xddResizedImage(image, 1280);
    NSData *data = UIImageJPEGRepresentation(finalImage, 0.85);
    setXddWallpaperData(data);
    UIImageView *bg = [[UIImageView alloc] initWithFrame:self.view.bounds];
    bg.image = finalImage;
    bg.contentMode = UIViewContentModeScaleAspectFill;
    bg.clipsToBounds = YES;
    [self.view insertSubview:bg atIndex:0];
    showRecallToast(@"✅ 壁纸已设置");
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// 长按开发者信息 → 输入暗号「我爱你」修改开发者信息，输错提示错误
- (void)xddDevLabelLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateBegan) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"开发者信息" message:@"请输入暗号来修改开发者信息" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"请输入暗号";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *input = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([input isEqualToString:@"我爱你"]) {
            [self xddPromptNewDevName];
        } else {
            UIAlertController *err = [UIAlertController alertControllerWithTitle:@"提示" message:@"暗号错误！" preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:err animated:YES completion:nil];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)xddPromptNewDevName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"修改开发者信息" message:@"请输入新的开发者信息" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = xddDevName();
        tf.placeholder = @"开发者信息";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newName = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newName.length > 0) {
            setXddDevName(newName);
            [self xddRefreshDevLabel];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)xddRefreshDevLabel {
    UILabel *devLabel = [self.view viewWithTag:1001];
    if (devLabel && [devLabel isKindOfClass:[UILabel class]]) {
        devLabel.text = [NSString stringWithFormat:@"开发者：%@", xddDevName()];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self xddWpCancel];
}

@end

@implementation XDDCommonViewController

- (UIView *)xddCardWithFrame:(CGRect)frame {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [UIColor colorWithRed:0.12 green:0.18 blue:0.29 alpha:0.55];
    card.layer.cornerRadius = 16;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithRed:0.43 green:0.71 blue:1.0 alpha:0.18].CGColor;
    [self.view addSubview:card];
    return card;
}

- (UISwitch *)xddSwitchInCard:(UIView *)card on:(BOOL)on tag:(NSInteger)tag {
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(card.bounds.size.width - 62, 13, 50, 30)];
    sw.on = on;
    sw.tag = tag;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:sw];
    return sw;
}

- (UILabel *)xddLabelInCard:(UIView *)card text:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, card.bounds.size.width - 100, 56)];
    label.text = text;
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor colorWithRed:0.9 green:0.95 blue:1.0 alpha:1.0];
    [card addSubview:label];
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"常用功能";
    self.view.backgroundColor = xddDeepSpaceColor();

    // 微信防撤回
    UIView *card1 = [self xddCardWithFrame:CGRectMake(20, 110, self.view.bounds.size.width - 40, 56)];
    [self xddLabelInCard:card1 text:@"微信防撤回"];
    [self xddSwitchInCard:card1 on:antiRevokeEnabled() tag:101];

    // 撤回提示
    UIView *card2 = [self xddCardWithFrame:CGRectMake(20, 176, self.view.bounds.size.width - 40, 56)];
    [self xddLabelInCard:card2 text:@"撤回提示"];
    [self xddSwitchInCard:card2 on:revokeToastEnabled() tag:102];

    // 撤回提示语
    UIView *card3 = [self xddCardWithFrame:CGRectMake(20, 242, self.view.bounds.size.width - 40, 56)];
    [self xddLabelInCard:card3 text:@"撤回提示语"];
    UITextField *noticeField = [[UITextField alloc] initWithFrame:CGRectMake(card3.bounds.size.width - 210, 10, 190, 36)];
    noticeField.borderStyle = UITextBorderStyleRoundedRect;
    noticeField.backgroundColor = [UIColor colorWithRed:0.05 green:0.09 blue:0.16 alpha:0.9];
    noticeField.textColor = [UIColor whiteColor];
    noticeField.font = [UIFont systemFontOfSize:13];
    noticeField.text = revokeNoticeText();
    noticeField.placeholder = @"输入提示语";
    [noticeField addTarget:self action:@selector(noticeChanged:) forControlEvents:UIControlEventEditingChanged];
    [card3 addSubview:noticeField];

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(20, 310, self.view.bounds.size.width - 40, 30)];
    hint.text = @"开启后，好友撤回的消息仍会保留在聊天记录里";
    hint.font = [UIFont systemFontOfSize:12];
    hint.textColor = [UIColor colorWithRed:0.5 green:0.62 blue:0.78 alpha:1.0];
    [self.view addSubview:hint];

    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(20, 520, self.view.bounds.size.width - 40, 30)];
    ver.text = @"小叮当 v0.0.11 ｜ 适配 iOS 16.2 / Dopamine";
    ver.font = [UIFont systemFontOfSize:12];
    ver.textColor = [UIColor colorWithRed:0.28 green:0.38 blue:0.52 alpha:1.0];
    ver.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:ver];
}

- (void)switchChanged:(UISwitch *)sender {
    switch (sender.tag) {
        case 101: setAntiRevokeEnabled(sender.isOn); break;
        case 102: setRevokeToastEnabled(sender.isOn); break;
        default: break;
    }
}

- (void)noticeChanged:(UITextField *)sender {
    setRevokeNoticeText(sender.text);
}

@end

@implementation XDDRedPacketViewController

- (UIView *)xddCardWithFrame:(CGRect)frame {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [UIColor colorWithRed:0.12 green:0.18 blue:0.29 alpha:0.55];
    card.layer.cornerRadius = 16;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithRed:0.43 green:0.71 blue:1.0 alpha:0.18].CGColor;
    [self.view addSubview:card];
    return card;
}

- (UISwitch *)xddSwitchInCard:(UIView *)card on:(BOOL)on tag:(NSInteger)tag {
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(card.bounds.size.width - 62, 13, 50, 30)];
    sw.on = on;
    sw.tag = tag;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:sw];
    return sw;
}

- (UILabel *)xddLabelInCard:(UIView *)card text:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, card.bounds.size.width - 100, 56)];
    label.text = text;
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor colorWithRed:0.9 green:0.95 blue:1.0 alpha:1.0];
    [card addSubview:label];
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"红包功能";
    self.view.backgroundColor = xddDeepSpaceColor();

    // 自动抢红包
    UIView *card1 = [self xddCardWithFrame:CGRectMake(20, 110, self.view.bounds.size.width - 40, 56)];
    [self xddLabelInCard:card1 text:@"自动抢红包"];
    [self xddSwitchInCard:card1 on:autoRedEnvelopEnabled() tag:103];

    // 几秒后抢
    UIView *card2 = [self xddCardWithFrame:CGRectMake(20, 176, self.view.bounds.size.width - 40, 56)];
    [self xddLabelInCard:card2 text:@"几秒后抢（0-10 秒）"];
    UITextField *delayField = [[UITextField alloc] initWithFrame:CGRectMake(card2.bounds.size.width - 85, 10, 65, 36)];
    delayField.borderStyle = UITextBorderStyleRoundedRect;
    delayField.keyboardType = UIKeyboardTypeNumberPad;
    delayField.backgroundColor = [UIColor colorWithRed:0.05 green:0.09 blue:0.16 alpha:0.9];
    delayField.textColor = [UIColor whiteColor];
    delayField.font = [UIFont systemFontOfSize:14];
    delayField.text = [NSString stringWithFormat:@"%ld", (long)grabDelaySeconds()];
    delayField.placeholder = @"1";
    [delayField addTarget:self action:@selector(delayChanged:) forControlEvents:UIControlEventEditingDidEnd];
    [card2 addSubview:delayField];

    // 只抢群聊红包
    UIView *card3 = [self xddCardWithFrame:CGRectMake(20, 242, self.view.bounds.size.width - 40, 56)];
    [self xddLabelInCard:card3 text:@"只抢群聊红包"];
    [self xddSwitchInCard:card3 on:grabGroupChatEnabled() tag:105];

    // 只抢单聊红包
    UIView *card4 = [self xddCardWithFrame:CGRectMake(20, 308, self.view.bounds.size.width - 40, 56)];
    [self xddLabelInCard:card4 text:@"只抢单聊红包"];
    [self xddSwitchInCard:card4 on:grabSingleChatEnabled() tag:106];

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(20, 376, self.view.bounds.size.width - 40, 30)];
    hint.text = @"⚠️ 提示：抢红包有封号风险，请谨慎使用";
    hint.font = [UIFont systemFontOfSize:12];
    hint.textColor = [UIColor colorWithRed:0.95 green:0.6 blue:0.3 alpha:1.0];
    [self.view addSubview:hint];

    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(20, 520, self.view.bounds.size.width - 40, 30)];
    ver.text = @"小叮当 v0.0.11 ｜ 适配 iOS 16.2 / Dopamine";
    ver.font = [UIFont systemFontOfSize:12];
    ver.textColor = [UIColor colorWithRed:0.28 green:0.38 blue:0.52 alpha:1.0];
    ver.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:ver];
}

- (void)switchChanged:(UISwitch *)sender {
    switch (sender.tag) {
        case 103: setAutoRedEnvelopEnabled(sender.isOn); break;
        case 105: setGrabGroupChatEnabled(sender.isOn); break;
        case 106: setGrabSingleChatEnabled(sender.isOn); break;
        default: break;
    }
}

- (void)delayChanged:(UITextField *)sender {
    NSInteger d = [sender.text integerValue];
    if (d < 0) d = 0;
    if (d > 10) d = 10;
    setGrabDelaySeconds(d);
    sender.text = [NSString stringWithFormat:@"%ld", (long)d];
}

@end


// ============================================================
//  5. 防撤回 + 自定义提示
// ============================================================

@interface CMessageMgr : NSObject
- (void)onRevokeMsg:(id)arg;
- (void)AsyncOnAddMsg:(id)msg MsgWrap:(id)wrap;
- (void)xddHandleRedEnvelopMessage:(id)wrap;
@end

%hook CMessageMgr

- (void)onRevokeMsg:(id)arg {
    if (antiRevokeEnabled()) {
        // 防撤回开启：拦截撤回；是否显示提示语由「撤回提示」开关控制
        if (revokeToastEnabled()) {
            showRecallToast(revokeNoticeText());
        }
    } else {
        %orig;
    }
}

// ============================================================
//  6. 自动抢红包
// ============================================================

- (void)AsyncOnAddMsg:(id)msg MsgWrap:(id)wrap {
    %orig;
    if (!autoRedEnvelopEnabled()) return;
    [self xddHandleRedEnvelopMessage:wrap];
}

%new
- (void)xddHandleRedEnvelopMessage:(id)wrap {
    @try {
        NSInteger msgType = [[wrap valueForKey:@"m_uiMessageType"] integerValue];
        NSString *content = [wrap valueForKey:@"m_nsContent"];
        if (msgType != 49 || !content || [content rangeOfString:@"wxpay://"].location == NSNotFound) return;

        id payInfo = [wrap valueForKey:@"m_oWCPayInfoItem"];
        NSString *nativeUrl = [payInfo valueForKey:@"m_c2cNativeUrl"];
        if (!nativeUrl || nativeUrl.length == 0) return;

        NSString *fromUsr = [wrap valueForKey:@"m_nsFromUsr"] ?: @"";
        NSString *toUsr = [wrap valueForKey:@"m_nsToUsr"] ?: @"";
        BOOL isGroup = [fromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
        BOOL isGroupSender = [toUsr rangeOfString:@"chatroom"].location != NSNotFound;

        // 过滤：群聊/单聊
        if (isGroup && !grabGroupChatEnabled()) return;
        if (!isGroup && !grabSingleChatEnabled()) return;
        if (isGroupSender) return; // 不抢自己发的

        // 解析 nativeUrl 里的参数
        NSString *query = nativeUrl;
        NSRange qRange = [nativeUrl rangeOfString:@"?"];
        if (qRange.location != NSNotFound) query = [nativeUrl substringFromIndex:qRange.location + 1];
        NSDictionary *urlDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:query separator:@"&"];
        NSString *sendId = [urlDict objectForKey:@"sendid"];
        if (!sendId) return;

        // 防重复
        if (isSendIdGrabbed(sendId)) return;

        // 组装抢红包请求参数（简化版，仿 WeChatRedEnvelop）
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setObject:sendId forKey:@"sendId"];
        [params setObject:([urlDict objectForKey:@"msgtype"] ?: @"1") forKey:@"msgType"];
        [params setObject:([urlDict objectForKey:@"channelid"] ?: @"1") forKey:@"channelId"];
        [params setObject:nativeUrl forKey:@"nativeUrl"];
        [params setObject:(isGroup ? fromUsr : toUsr) forKey:@"sessionUserName"];

        // 先查询红包状态（拿到 sign），再在响应里真正开抢
        [params setObject:@"0" forKey:@"agreeDuty"];
        [params setObject:@"0" forKey:@"inWay"];

        MMContext *context = [%c(MMContext) activeUserContext];
        WCRedEnvelopesLogicMgr *logicMgr = [context getService:NSClassFromString(@"WCRedEnvelopesLogicMgr")];
        if (!logicMgr) return;

        [logicMgr ReceiverQueryRedEnvelopesRequest:params];

        // 记住本次要抢的红包参数，等响应回来后开抢
        static NSMutableDictionary *pending = nil;
        if (!pending) pending = [NSMutableDictionary dictionary];
        [pending setObject:params forKey:sendId];

        // 标记已抢（防重复）
        markSendIdGrabbed(sendId);
    } @catch (NSException *e) {
        // 解析失败就跳过，绝不影响微信正常运行
    }
}

%end

%hook WCRedEnvelopesLogicMgr

// 红包查询响应回来 → 延迟后真正开抢
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    @try {
        if (!autoRedEnvelopEnabled()) return;
        int cgiCmdid = [[arg1 valueForKey:@"cgiCmdid"] intValue];
        if (cgiCmdid != 3) return; // 只处理参数查询响应

        id retText = [arg1 valueForKey:@"retText"];
        NSData *buffer = [retText valueForKey:@"buffer"];
        if (!buffer) return;
        NSString *responseString = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
        NSDictionary *responseDict = [self xddJsonToDict:responseString];

        NSInteger receiveStatus = [[responseDict objectForKey:@"receiveStatus"] integerValue];
        NSInteger hbStatus = [[responseDict objectForKey:@"hbStatus"] integerValue];
        if (receiveStatus == 2) return; // 已抢过
        if (hbStatus == 4) return;      // 已被抢完

        // 从请求里拿回之前存的参数
        id reqText = [arg2 valueForKey:@"reqText"];
        NSData *reqBuffer = [reqText valueForKey:@"buffer"];
        NSString *reqString = reqBuffer ? [[NSString alloc] initWithData:reqBuffer encoding:NSUTF8StringEncoding] : @"";
        NSDictionary *reqDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:reqString separator:@"&"];
        NSString *nativeUrl = [[reqDict objectForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        if (!nativeUrl) return;

        NSString *sendId = [reqDict objectForKey:@"sendid"];
        if (!sendId) return;

        // 延迟秒数（加一点随机，降低被判定外挂的概率）
        NSInteger delay = grabDelaySeconds();
        if (delay < 0) delay = 0;
        int jitter = arc4random_uniform(7); // 0~6
        double totalDelay = delay + jitter * 0.1;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(totalDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                MMContext *context = [%c(MMContext) activeUserContext];
                WCRedEnvelopesLogicMgr *logicMgr = [context getService:NSClassFromString(@"WCRedEnvelopesLogicMgr")];
                if (!logicMgr) return;

                // 组装开抢参数
                NSMutableDictionary *grabParams = [NSMutableDictionary dictionary];
                [grabParams setObject:sendId forKey:@"sendId"];
                [grabParams setObject:([reqDict objectForKey:@"msgtype"] ?: @"1") forKey:@"msgType"];
                [grabParams setObject:([reqDict objectForKey:@"channelid"] ?: @"1") forKey:@"channelId"];
                [grabParams setObject:nativeUrl forKey:@"nativeUrl"];
                if ([responseDict objectForKey:@"timingIdentifier"]) {
                    [grabParams setObject:[responseDict objectForKey:@"timingIdentifier"] forKey:@"timingIdentifier"];
                }
                [grabParams setObject:@"0" forKey:@"agreeDuty"];

                [logicMgr OpenRedEnvelopesRequest:grabParams];
            } @catch (NSException *e) {}
        });
    } @catch (NSException *e) {}
}

%new
- (NSDictionary *)xddJsonToDict:(NSString *)json {
    if (!json) return @{};
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : @{};
}

%end
