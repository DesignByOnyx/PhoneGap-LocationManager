
#import <CoreLocation/CoreLocation.h>
#import <Cordova/CDVPlugin.h>

enum PGLocationStatus {
    PERMISSIONDENIED = 1,
    POSITIONUNAVAILABLE,
    TIMEOUT
};
typedef NSUInteger PGLocationStatus;

enum PGGeofencingStatus {
    GEOFENCINGPERMISSIONDENIED = 4,
    GEOFENCINGUNAVAILABLE=5,
    GEOFENCINGTIMEOUT=6
};
typedef NSUInteger PGGeofencingStatus;


// simple object to keep track of location information
@interface PGLocationData : NSObject {
    PGLocationStatus locationStatus;
    PGGeofencingStatus geofencingStatus;
    CLLocation* locationInfo;
    NSMutableArray* locationCallbacks;
    NSMutableDictionary* geofencingCallbacks;
    NSMutableDictionary* lsNewGeofences;
}

@property (nonatomic, assign) PGLocationStatus locationStatus;
@property (nonatomic, assign) PGGeofencingStatus geofencingStatus;
@property (nonatomic, strong) CLLocation* locationInfo;
@property (nonatomic, strong) NSMutableArray* locationCallbacks;
@property (nonatomic, strong) NSMutableDictionary* geofencingCallbacks;
@property (nonatomic, strong) NSMutableDictionary* lsNewGeofences;

@end

//=====================================================
// PGLocationManager
//=====================================================

@interface PGLocationManager : CDVPlugin <CLLocationManagerDelegate> {
    @private BOOL __hasGeofence;
    @private BOOL __isUpdatingLocation;
    @private BOOL __isMonitoringSignificantLocation;
    PGLocationData* locationData;
}

@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic, strong) PGLocationData* locationData;
@property (nonatomic, assign) BOOL didLaunchForRegionUpdate;

+(PGLocationManager*)sharedGeofencingHelper;

- (BOOL) isLocationServicesEnabled;
- (BOOL) isAuthorized;
- (BOOL) isRegionMonitoringAvailable;
- (BOOL) isRegionMonitoringEnabled;
- (BOOL) isSignificantLocationChangeMonitoringAvailable;

#pragma mark Plugin Functions
- (void) initCallbackForRegionMonitoring:(CDVInvokedUrlCommand*)command forRegion:(CLRegion*)region;
- (void) startMonitoringRegion:(CDVInvokedUrlCommand*)command;
- (void) stopMonitoringRegion:(CDVInvokedUrlCommand*)command;
- (NSArray *) getMonitoredRegions;
- (void) startMonitoringSignificantLocationChanges:(CDVInvokedUrlCommand*)command;
- (void) stopMonitoringSignificantLocationChanges:(CDVInvokedUrlCommand*)command;

@end