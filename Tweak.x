/*
 * KeyAuth iOS Integration Tweak (Fixed Session Init)
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ── KeyAuth Credentials ──────────────────────────────────────────────────────
static NSString *const kName     = @"420euro's Application";
static NSString *const kOwnerID  = @"Z3NXQY2bdP";
static NSString *const kSecret   = @"34afdd8daf83695b2dc9dbc2f82d5d926bd64d509a569d219bbede8f685deebc";
static NSString *const kVersion  = @"1.0";

static NSString *const kKeyStoreKey = @"KeyAuthActivatedKey";
static NSString *const kKeyExpiry   = @"KeyAuthKeyExpiry";
static NSString *const kDeviceIDKey = @"KeyAuthDeviceID";
// ─────────────────────────────────────────────────────────────────────────────

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

static void showKeyAuthAlert(void);

static void validateLicenseWithSession(NSString *key, NSString *sessionID, UIViewController *topVC, UIAlertController *loading) {
    NSString *deviceID = getDeviceID();
    NSURL *url = [NSURL URLWithString:@"https://keyauth.win/api/1.2/"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    NSString *postData = [NSString stringWithFormat:@"type=license&key=%@&hwid=%@&sessionid=%@&name=%@&ownerid=%@",
                          key, deviceID, sessionID, kName, kOwnerID];
    req.HTTPBody = [postData dataUsingEncoding:NSUTF8StringEncoding];
    req.timeoutInterval = 15;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:NO completion:^{
                UIViewController *currentVC = getTopViewController();

                if (err || !data) {
                    UIAlertController *netErr = [UIAlertController
                        alertControllerWithTitle:@"Connection Error"
                        message:@"Network error. Check your connection."
                        preferredStyle:UIAlertControllerStyleAlert];
                    [netErr addAction:[UIAlertAction actionWithTitle:@"Retry"
                        style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *a) { showKeyAuthAlert(); }]];
                    [currentVC presentViewController:netErr animated:YES completion:nil];
                    return;
                }

                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                BOOL success = [json[@"success"] boolValue];

                if (!success) {
                    NSString *msg = json[@"message"] ?: @"Invalid key.";
                    UIAlertController *invalid = [UIAlertController
                        alertControllerWithTitle:@"Activation Failed"
                        message:msg
                        preferredStyle:UIAlertControllerStyleAlert];
                    [invalid addAction:[UIAlertAction actionWithTitle:@"Try Again"
                        style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *a) { showKeyAuthAlert(); }]];
                    [currentVC presentViewController:invalid animated:YES completion:nil];
                    return;
                }

                // Success! Save session locally for 30 days
                NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                [ud setObject:key forKey:kKeyStoreKey];
                NSDate *expDate = [NSDate dateWithTimeIntervalSinceNow:30 * 24 * 60 * 60];
                [ud setObject:expDate forKey:kKeyExpiry];
                [ud synchronize];

                UIAlertController *successAlert = [UIAlertController
                    alertControllerWithTitle:@"Success"
                    message:@"License activated successfully!"
                    preferredStyle:UIAlertControllerStyleAlert];
                [successAlert addAction:[UIAlertAction actionWithTitle:@"Enter App"
                    style:UIAlertActionStyleDefault handler:nil]];
                [currentVC presentViewController:successAlert animated:YES completion:nil];
            }];
        });
    }] resume];
}

static void showKeyAuthAlert(void) {
    UIViewController *vc = getTopViewController();
    if (!vc) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showKeyAuthAlert();
        });
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"License Verification"
        message:@"Enter your KeyAuth license key to continue."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Paste license key";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];

    UIAlertAction *activate = [UIAlertAction
        actionWithTitle:@"Activate"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {

        NSString *key = [[alert.textFields.firstObject.text
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];

        if (key.length == 0) {
            showKeyAuthAlert();
            return;
        }

        UIViewController *currentVC = getTopViewController();
        UIAlertController *loading = [UIAlertController
            alertControllerWithTitle:@"KeyAuth"
            message:@"Validating key…"
            preferredStyle:UIAlertControllerStyleAlert];
        [currentVC presentViewController:loading animated:YES completion:nil];

        // Step 1: Initialize Session
        NSURL *url = [NSURL URLWithString:@"https://keyauth.win/api/1.2/"];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSString *postData = [NSString stringWithFormat:@"type=init&name=%@&ownerid=%@&secret=%@&ver=%@",
                              kName, kOwnerID, kSecret, kVersion];
        req.HTTPBody = [postData dataUsingEncoding:NSUTF8StringEncoding];
        req.timeoutInterval = 15;

        [[[NSURLSession sharedSession] dataTaskWithRequest:req
            completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            if (err || !data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [loading dismissViewControllerAnimated:NO completion:^{
                        UIViewController *topVC = getTopViewController();
                        UIAlertController *netErr = [UIAlertController
                            alertControllerWithTitle:@"Connection Error"
                            message:@"Network error during initialization."
                            preferredStyle:UIAlertControllerStyleAlert];
                        [netErr addAction:[UIAlertAction actionWithTitle:@"Retry"
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *a) { showKeyAuthAlert(); }]];
                        [topVC presentViewController:netErr animated:YES completion:nil];
                    }];
                });
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL success = [json[@"success"] boolValue];
            NSString *sessionID = json[@"sessionid"];

            if (!success || !sessionID) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [loading dismissViewControllerAnimated:NO completion:^{
                        UIViewController *topVC = getTopViewController();
                        NSString *msg = json[@"message"] ?: @"Initialization failed.";
                        UIAlertController *initErr = [UIAlertController
                            alertControllerWithTitle:@"Init Error"
                            message:msg
                            preferredStyle:UIAlertControllerStyleAlert];
                        [initErr addAction:[UIAlertAction actionWithTitle:@"Try Again"
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *a) { showKeyAuthAlert(); }]];
                        [topVC presentViewController:initErr animated:YES completion:nil];
                    }];
                });
                return;
            }

            // Step 2: Session acquired, now validate License Key
            validateLicenseWithSession(key, sessionID, currentVC, loading);

        }] resume];
    }];

    UIAlertAction *quit = [UIAlertAction
        actionWithTitle:@"Quit"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            exit(0);
        }];

    [alert addAction:activate];
    [alert addAction:quit];
    [vc presentViewController:alert animated:YES completion:nil];
}

__attribute__((constructor))
static void initialize_keyauth(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!hasValidKey()) {
            showKeyAuthAlert();
        }
    });
}
