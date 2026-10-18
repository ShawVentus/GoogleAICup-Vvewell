#import "HikMicroSDKBridge.h"
#import "HCNetSDK.h"

@interface HikMicroSDKBridge () {
    LONG _userID;
    LONG _previewHandle;
    LONG _realConfigHandle;
    int _playPort;
}
@end

@implementation HikMicroSDKBridge

+ (instancetype)shared {
    static HikMicroSDKBridge *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HikMicroSDKBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userID = -1;
        _previewHandle = -1;
        _realConfigHandle = -1;
        _playPort = -1;
        _isInitialized = NO;
        _isLoggedIn = NO;
        _isPreviewing = NO;
        _isThermometryRunning = NO;
    }
    return self;
}

#pragma mark - Lifecycle

- (BOOL)initialize {
    if (_isInitialized) return YES;

    BOOL ok = NET_DVR_Init();
    if (!ok) {
        NSLog(@"[HikMicro] NET_DVR_Init failed: %d", NET_DVR_GetLastError());
        return NO;
    }

    NET_DVR_SetConnectTime(5000, 3);
    NET_DVR_SetReconnect(10000, true);
    NET_DVR_SetRecvTimeOut(10000);

    NSString *logPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"hikmicro_sdk.log"];
    NET_DVR_SetLogToFile(3, (char *)[logPath UTF8String], false);

    _isInitialized = YES;
    NSLog(@"[HikMicro] SDK initialized. Version: %s", [[self sdkVersion] UTF8String]);
    return YES;
}

- (void)cleanup {
    [self stopPreview];
    [self stopThermometry];
    [self logout];
    if (_isInitialized) {
        NET_DVR_Cleanup();
        _isInitialized = NO;
    }
}

#pragma mark - Login / Logout

- (void)loginWithIP:(NSString *)ip
               port:(int)port
               user:(NSString *)user
         password:(NSString *)password
         completion:(void (^)(BOOL, NSString *, NSString *, NSString *))completion {

    if (!_isInitialized) {
        if (![self initialize]) {
            if (completion) completion(NO, nil, nil, nil);
            return;
        }
    }

    if (_isLoggedIn) {
        [self logout];
    }

    NET_DVR_USER_LOGIN_INFO loginInfo = {0};

    strncpy(loginInfo.sDeviceAddress, [ip UTF8String], sizeof(loginInfo.sDeviceAddress) - 1);
    loginInfo.wPort = port;
    strncpy(loginInfo.sUserName, [user UTF8String], sizeof(loginInfo.sUserName) - 1);
    strncpy(loginInfo.sPassword, [password UTF8String], sizeof(loginInfo.sPassword) - 1);
    loginInfo.cbLoginResult = NULL;
    loginInfo.bUseAsynLogin = 0;

    NET_DVR_DEVICEINFO_V40 deviceInfo = {0};

    _userID = NET_DVR_Login_V40(&loginInfo, &deviceInfo);

    if (_userID < 0) {
        DWORD err = NET_DVR_GetLastError();
        NSLog(@"[HikMicro] Login failed: %d", err);
        if (completion) completion(NO, nil, nil, nil);
        return;
    }

    _isLoggedIn = YES;

    NET_DVR_DEVICEINFO_V30 v30 = deviceInfo.struDeviceV30;

    NSString *deviceName = @"HikMicro Thermal Camera";
    NSString *serialNumber = [NSString stringWithFormat:@"%s", v30.sSerialNumber];
    NSString *firmwareVersion = @"Unknown";

    NSLog(@"[HikMicro] Login success: userID=%ld, name=%@", (long)_userID, deviceName);

    if ([self.delegate respondsToSelector:@selector(bridgeDidLoginWithDeviceName:serialNumber:firmwareVersion:)]) {
        [self.delegate bridgeDidLoginWithDeviceName:deviceName
                                      serialNumber:serialNumber
                                   firmwareVersion:firmwareVersion];
    }

    if (completion) completion(YES, deviceName, serialNumber, firmwareVersion);
}

- (void)logout {
    if (!_isLoggedIn || _userID < 0) return;

    [self stopPreview];
    [self stopThermometry];

    NET_DVR_Logout(_userID);
    _userID = -1;
    _isLoggedIn = NO;

    if ([self.delegate respondsToSelector:@selector(bridgeDidLogout)]) {
        [self.delegate bridgeDidLogout];
    }
    NSLog(@"[HikMicro] Logged out");
}

#pragma mark - Preview

- (BOOL)startPreviewInView:(UIView *)view {
    if (!_isLoggedIn || _userID < 0) {
        NSLog(@"[HikMicro] Cannot start preview: not logged in");
        return NO;
    }
    if (_isPreviewing) return YES;

    NET_DVR_PREVIEWINFO previewInfo = {0};
    previewInfo.hPlayWnd = (__bridge HWND)view;
    previewInfo.lChannel = 1;
    previewInfo.dwStreamType = 0;
    previewInfo.dwLinkMode = 0;
    previewInfo.bBlocked = 1;

    _previewHandle = NET_DVR_RealPlay_V40(_userID, &previewInfo, NULL, NULL);

    if (_previewHandle < 0) {
        DWORD err = NET_DVR_GetLastError();
        NSLog(@"[HikMicro] Start preview failed: %d", err);
        return NO;
    }

    _isPreviewing = YES;
    NSLog(@"[HikMicro] Preview started");
    return YES;
}

- (void)stopPreview {
    if (!_isPreviewing || _previewHandle < 0) return;

    NET_DVR_StopRealPlay(_previewHandle);
    _previewHandle = -1;
    _isPreviewing = NO;
    NSLog(@"[HikMicro] Preview stopped");
}

#pragma mark - Thermometry

- (BOOL)startThermometry {
    if (!_isLoggedIn || _userID < 0) {
        NSLog(@"[HikMicro] Cannot start thermometry: not logged in");
        return NO;
    }
    if (_isThermometryRunning) return YES;

    NET_DVR_REALTIME_THERMOMETRY_COND cond = {0};
    cond.dwSize = sizeof(cond);
    cond.dwChan = 1;
    cond.byRuleID = 0;
    cond.byMode = 0;
    cond.wInterval = 0;

    _realConfigHandle = NET_DVR_StartRemoteConfig(
        _userID,
        NET_DVR_GET_REALTIME_THERMOMETRY,
        &cond,
        sizeof(cond),
        thermoCallback,
        (__bridge void *)self
    );

    if (_realConfigHandle < 0) {
        DWORD err = NET_DVR_GetLastError();
        NSLog(@"[HikMicro] Start thermometry failed: %d", err);
        return NO;
    }

    _isThermometryRunning = YES;
    NSLog(@"[HikMicro] Thermometry started");
    return YES;
}

- (void)stopThermometry {
    if (!_isThermometryRunning || _realConfigHandle < 0) return;

    NET_DVR_StopRemoteConfig(_realConfigHandle);
    _realConfigHandle = -1;
    _isThermometryRunning = NO;
    NSLog(@"[HikMicro] Thermometry stopped");
}

static void thermoCallback(
    DWORD dwType,
    void *lpBuffer,
    DWORD dwBufLen,
    void *pUserData
) {
    if (dwType != NET_SDK_CALLBACK_TYPE_STATUS) return;
    if (!lpBuffer || dwBufLen == 0) return;

    HikMicroSDKBridge *bridge = (__bridge HikMicroSDKBridge *)pUserData;

    NET_DVR_THERMOMETRY_UPLOAD *upload = (NET_DVR_THERMOMETRY_UPLOAD *)lpBuffer;

    float tempMin = upload->fLowestPointTemperature;
    float tempMax = upload->fHighestPointTemperature;
    float tempAvg = upload->fCenterPointTemperature;
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([bridge.delegate respondsToSelector:@selector(bridgeDidReceiveTemperatureMin:max:avg:timestamp:)]) {
            [bridge.delegate bridgeDidReceiveTemperatureMin:tempMin max:tempMax avg:tempAvg timestamp:timestamp];
        }
    });
}

#pragma mark - Version

- (NSString *)sdkVersion {
    DWORD ver = NET_DVR_GetSDKVersion();
    DWORD build = NET_DVR_GetSDKBuildVersion();
    return [NSString stringWithFormat:@"V%d.%d.%d build %d",
            (ver >> 24) & 0xFF,
            (ver >> 16) & 0xFF,
            (ver >> 8) & 0xFF,
            build];
}

@end
