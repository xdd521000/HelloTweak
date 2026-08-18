//
//  Tweak.x — 微信版插件
//  打开微信后，弹出一个欢迎提示框
//
//  这次用 %ctor（插件加载时自动运行的代码）来弹窗，
//  不依赖微信内部的类名，更稳定
//

#import <UIKit/UIKit.h>

// 弹窗函数：保证只弹一次
static void showHelloPopup(void) {
    static BOOL shown = NO;
    if (shown) return;

    // 拿到微信的主窗口（注意：这里用了过时的 windows，已在 Makefile 里忽略警告）
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

// %ctor：插件被加载进微信时自动执行（相当于程序入口）
// 分 5 次尝试弹窗（2秒、4秒…10秒），确保微信窗口已就绪，弹一次就停
%ctor {
    for (NSInteger i = 0; i < 5; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * (i + 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showHelloPopup();
        });
    }
}
