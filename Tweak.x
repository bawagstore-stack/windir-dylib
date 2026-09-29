/*
 * KeyAuth iOS Integration Tweak (BAWA G STORE Custom UI - Fixed for iOS 9+)
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ── KeyAuth Credentials ──────────────────────────────────────────────────────
static NSString *const kName     = @"420euro's Application";
static NSString *const kOwnerID  = @"Z3NXQY2bdP";
static NSString *const kSecret   = @"34afdd8daf83695b2dc9dbc2f82d5d926bd64d509a569d219bbede8f685deebc";
static NSString *const kVersion  = @"1.0";

static NSString *const kImageURL  = @"https://i.ibb.co/zVX99kKn/IMG-0441.jpg";

static NSString *const kKeyStoreKey = @"KeyAuthActivatedKey";
static NSString *const kKeyExpiry   = @"KeyAuthKeyExpiry";
static NSString *const kDeviceIDKey = @"KeyAuthDeviceID";
// ─────────────────────────────────────────────────────────────────────────────

@interface BawaGHandler : NSObject
@property (nonatomic, strong) UITextField *keyInput;
@property (nonatomic, strong) UIViewController *topVC;
@property (nonatomic, strong) UIView *overlayView;
+ (instancetype)sharedInstance;
- (void)activatePressed;
- (void)quitPressed;
@end

static NSString *getDeviceID() {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *did = [ud stringForKey:kDeviceIDKey];
    if (!did) {
        did = [[[NSUUID UUID] UUIDString] lowercaseString];
        [ud setObject:did forKey:kDeviceIDKey];
        [ud synchronize];
    }
    return did;
}

static BOOL hasValidKey() {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *key = [ud stringForKey:kKeyStoreKey];
    NSDate   *exp = [ud objectForKey:kKeyExpiry];
    if (!key || !exp) return NO;
    return [exp timeIntervalSinceNow] > 0;
}

static UIViewController *getTopViewController() {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { window = w; break; }
        }
    }
    UIViewController *topController = window.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

@implementation BawaGHandler
+ (instancetype)sharedInstance {
    static BawaGHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BawaGHandler alloc] init];
    });
    return instance;
}

- (void)activatePressed {
    NSString *enteredKey = [self.keyInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (enteredKey.length == 0) return;

    UIViewController *vc = self.topVC;
    UIView *overlay = self.overlayView;

    // Step 1: Session Init
    NSURL *url = [NSURL URLWithString:@"https://keyauth.win/api/1.2/"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    NSString *initData = [NSString stringWithFormat:@"type=init&name=%@&ownerid=%@&secret=%@&ver=%@",
                          kName, kOwnerID, kSecret, kVersion];
    req.HTTPBody = [initData dataUsingEncoding:NSUTF8StringEncoding];
    req.timeoutInterval = 15;

    UIAlertController *loading = [UIAlertController
        alertControllerWithTitle:@"BAWA G STORE"
        message:@"Verifying License..."
        preferredStyle:UIAlertControllerStyleAlert];
    [vc presentViewController:loading animated:YES completion:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:NO completion:^{
                    UIAlertController *netErr = [UIAlertController alertControllerWithTitle:@"Error" message:@"Network connection failed." preferredStyle:UIAlertControllerStyleAlert];
                    [netErr addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [vc presentViewController:netErr animated:YES completion:nil];
                }];
            });
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *sessionID = json[@"sessionid"];
        BOOL initSuccess = [json[@"success"] boolValue];

        if (!initSuccess || !sessionID) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:NO completion:^{
                    NSString *msg = json[@"message"] ?: @"Session Init failed.";
                    UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Init Failed" message:msg preferredStyle:UIAlertControllerStyleAlert];
                    [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [vc presentViewController:errAlert animated:YES completion:nil];
                }];
            });
            return;
        }

        // Step 2: License Check
        NSMutableURLRequest *licReq = [NSMutableURLRequest requestWithURL:url];
        licReq.HTTPMethod = @"POST";
        [licReq setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSString *licData = [NSString stringWithFormat:@"type=license&key=%@&hwid=%@&sessionid=%@&name=%@&ownerid=%@",
                             enteredKey, getDeviceID(), sessionID, kName, kOwnerID];
        licReq.HTTPBody = [licData dataUsingEncoding:NSUTF8StringEncoding];
        licReq.timeoutInterval = 15;

        [[[NSURLSession sharedSession] dataTaskWithRequest:licReq completionHandler:^(NSData *lData, NSURLResponse *lResp, NSError *lErr) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:NO completion:^{
                    if (lErr || !lData) {
                        UIAlertController *netErr = [UIAlertController alertControllerWithTitle:@"Error" message:@"License check failed." preferredStyle:UIAlertControllerStyleAlert];
                        [netErr addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                        [vc presentViewController:netErr animated:YES completion:nil];
                        return;
                    }

                    NSDictionary *lJson = [NSJSONSerialization JSONObjectWithData:lData options:0 error:nil];
                    BOOL licSuccess = [lJson[@"success"] boolValue];

                    if (!licSuccess) {
                        NSString *msg = lJson[@"message"] ?: @"Invalid License Key!";
                        UIAlertController *invAlert = [UIAlertController alertControllerWithTitle:@"Activation Failed" message:msg preferredStyle:UIAlertControllerStyleAlert];
                        [invAlert addAction:[UIAlertAction actionWithTitle:@"Try Again" style:UIAlertActionStyleDefault handler:nil]];
                        [vc presentViewController:invAlert animated:YES completion:nil];
                        return;
                    }

                    // Save Validated State for 30 Days
                    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                    [ud setObject:enteredKey forKey:kKeyStoreKey];
                    NSDate *expDate = [NSDate dateWithTimeIntervalSinceNow:30 * 24 * 60 * 60];
                    [ud setObject:expDate forKey:kKeyExpiry];
                    [ud synchronize];

                    // Close Custom View
                    [overlay removeFromSuperview];

                    UIAlertController *succAlert = [UIAlertController alertControllerWithTitle:@"Success" message:@"Welcome to BAWA G STORE!" preferredStyle:UIAlertControllerStyleAlert];
                    [succAlert addAction:[UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDefault handler:nil]];
                    [vc presentViewController:succAlert animated:YES completion:nil];
                }];
            });
        }] resume];

    }] resume];
}

- (void)quitPressed {
    exit(0);
}
@end

static void showCustomBawaGPopup(void) {
    UIViewController *topVC = getTopViewController();
    if (!topVC) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showCustomBawaGPopup();
        });
        return;
    }

    // Overlay Screen Background
    UIView *overlayView = [[UIView alloc] initWithFrame:topVC.view.bounds];
    overlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.65];
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Card View Container
    CGFloat cardWidth = 320;
    CGFloat cardHeight = 260;
    UIView *cardView = [[UIView alloc] initWithFrame:CGRectMake((overlayView.frame.size.width - cardWidth)/2, (overlayView.frame.size.height - cardHeight)/2, cardWidth, cardHeight)];
    cardView.layer.cornerRadius = 20;
    cardView.layer.masksToBounds = YES;
    cardView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    cardView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

    // Background Image
    UIImageView *bgImageView = [[UIImageView alloc] initWithFrame:cardView.bounds];
    bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    bgImageView.alpha = 0.30;
    bgImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [cardView addSubview:bgImageView];

    // Download Image Asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imgData = [NSData dataWithContentsOfURL:[NSURL URLWithString:kImageURL]];
        if (imgData) {
            UIImage *img = [UIImage imageWithData:imgData];
            dispatch_async(dispatch_get_main_queue(), ^{
                bgImageView.image = img;
            });
        }
    });

    // Header Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, cardWidth - 20, 28)];
    titleLabel.text = @"WELCOME TO BAWA G STORE";
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [cardView addSubview:titleLabel];

    // Subtitle
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 52, cardWidth - 20, 36)];
    subLabel.text = @"Enter your VIP license key to activate session.";
    subLabel.font = [UIFont systemFontOfSize:12];
    subLabel.textColor = [UIColor lightGrayColor];
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.numberOfLines = 2;
    [cardView addSubview:subLabel];

    // Key Input
    UITextField *keyInput = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, cardWidth - 40, 42)];
    keyInput.placeholder = @"Paste License Key";
    keyInput.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    keyInput.textColor = [UIColor whiteColor];
    keyInput.font = [UIFont systemFontOfSize:14];
    keyInput.layer.cornerRadius = 10;
    keyInput.layer.borderWidth = 1;
    keyInput.layer.borderColor = [[[UIColor whiteColor] colorWithAlphaComponent:0.3] CGColor];
    keyInput.textAlignment = NSTextAlignmentCenter;
    keyInput.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    keyInput.autocorrectionType = UITextAutocorrectionTypeNo;
    [cardView addSubview:keyInput];

    // Save references to handler
    BawaGHandler *handler = [BawaGHandler sharedInstance];
    handler.keyInput = keyInput;
    handler.topVC = topVC;
    handler.overlayView = overlayView;

    // Activate Button
    UIButton *activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    activateBtn.frame = CGRectMake(20, 155, cardWidth - 40, 42);
    activateBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.50 blue:0.98 alpha:1.0];
    [activateBtn setTitle:@"Activate License" forState:UIControlStateNormal];
    [activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    activateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    activateBtn.layer.cornerRadius = 10;
    [activateBtn addTarget:handler action:@selector(activatePressed) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:activateBtn];

    // Quit Button
    UIButton *quitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    quitBtn.frame = CGRectMake(20, 205, cardWidth - 40, 35);
    [quitBtn setTitle:@"Quit App" forState:UIControlStateNormal];
    [quitBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    quitBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [quitBtn addTarget:handler action:@selector(quitPressed) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:quitBtn];

    [overlayView addSubview:cardView];
    [topVC.view addSubview:overlayView];
}

// ── Entry Point ──────────────────────────────────────────────────────────────
__attribute__((constructor))
static void init_bawa_g_store(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!hasValidKey()) {
            showCustomBawaGPopup();
        }
    });
}
