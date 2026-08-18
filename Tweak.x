//
//  Tweak.x — 微信版插件
//  功能1：打开微信时弹出欢迎提示
//  功能2：微信防撤回（好友撤回的消息仍然保留）
//

#import <UIKit/UIKit.h>

// ================= 功能1：欢迎弹窗 =================

static void showHelloPopup(void) {
    static BOOL shown = NO;
    if (shown) return;

    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (!window || !window.rootViewController) return;

    shown = YES;

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"🎉 微信插件已生效"
                         message:@"这是你的微信版越狱插件！\n\n设备：iPhone 14 Pro Max\n系统：iOS 16.2\n越狱：Dopamine"
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];

    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

// %ctor：插件加载时自动运行，分几次尝试弹窗确保窗口就绪
%ctor {
    for (NSInteger i = 0; i < 5; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * (i + 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showHelloPopup();
        });
    }
}

// ================= 功能2：防撤回 =================
//
// CMessageMgr 是微信的消息管理器（私有类，编译器不认识，手动声明）
// 微信收到"有人撤回消息"的通知时，会调用它的 onRevokeMsg: 方法
// 我们把这个方法拦下来、不执行原始逻辑，撤回就失效了
//

@interface CMessageMgr : NSObject
- (void)onRevokeMsg:(id)arg;
@end

%hook CMessageMgr

- (void)onRevokeMsg:(id)arg {
    // ★ 关键：不调用 %orig，撤回通知被拦截，消息原样保留
    // 注意：这个简单版连"你自己撤回"的消息也会保留（多数防撤回插件都是这样）
    // 想更精细（只拦别人、放行自己），需要解析 arg 里的发送者信息，后面可以进阶
}

%end
