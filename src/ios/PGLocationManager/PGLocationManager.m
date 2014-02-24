
#import "PGLocationManager.h"

static PGLocationManager *sharedGeofencingHelper = nil;

@implementation PGLocationData

@synthesize locationStatus, geofencingStatus, locationInfo, locationCallbacks, geofencingCallbacks, lsNewGeofences;
- (PGLocationData*)init
{
    self = (PGLocationData*)[super init];
    if (self) {
        self.locationInfo = nil;
        self.locationCallbacks = nil;
        self.geofencingCallbacks = nil;
        self.lsNewGeofences = nil;
    }
    return self;
}

@end

@implementation PGLocationManager

@synthesize locationData, locationManager, didLaunchForRegionUpdate;

- (CDVPlugin*)initWithWebView:(UIWebView*)theWebView
{
    self = (PGLocationManager*)[super initWithWebView:(UIWebView*)theWebView];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self; // Tells the location manager to send updates to this object
        __hasGeofence = NO;
        __isUpdatingLocation = NO;
        __isMonitoringSignificantLocation = NO;
        self.locationData = nil;
    }
    
    return self;
}

+(PGLocationManager *)sharedGeofencingHelper
{
    //objects using shard instance are responsible for retain/release count
    //retain count must remain 1 to stay in mem
    
    if (!sharedGeofencingHelper)
    {
        sharedGeofencingHelper = [[PGLocationManager alloc] init];
    }
    
    return sharedGeofencingHelper;
}

#pragma mark Location and Geofencing Permissions
- (BOOL) isSignificantLocationChangeMonitoringAvailable
{
	BOOL significantLocationChangeMonitoringAvailablelassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(significantLocationChangeMonitoringAvailable)];
    if (significantLocationChangeMonitoringAvailablelassPropertyAvailable)
    {
        BOOL significantLocationChangeMonitoringAvailable = [CLLocationManager significantLocationChangeMonitoringAvailable];
        return  (significantLocationChangeMonitoringAvailable);
    }
    
    // by default, assume NO
    return NO;
}

- (BOOL) isRegionMonitoringAvailable
{
	BOOL regionMonitoringAvailableClassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(regionMonitoringAvailable)];
    if (regionMonitoringAvailableClassPropertyAvailable)
    {
        BOOL regionMonitoringAvailable = [CLLocationManager regionMonitoringAvailable];
        return  (regionMonitoringAvailable);
    }
    
    // by default, assume NO
    return NO;
}

- (BOOL) isRegionMonitoringEnabled
{
	BOOL regionMonitoringEnabledClassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(regionMonitoringEnabled)];
    if (regionMonitoringEnabledClassPropertyAvailable)
    {
        BOOL regionMonitoringEnabled = [CLLocationManager regionMonitoringEnabled];
        return  (regionMonitoringEnabled);
    }
    
    // by default, assume NO
    return NO;
}

- (BOOL) isAuthorized
{
	BOOL authorizationStatusClassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(authorizationStatus)]; // iOS 4.2+
    if (authorizationStatusClassPropertyAvailable)
    {
        NSUInteger authStatus = [CLLocationManager authorizationStatus];
        return  (authStatus == kCLAuthorizationStatusAuthorized) || (authStatus == kCLAuthorizationStatusNotDetermined);
    }
    
    // by default, assume YES (for iOS < 4.2)
    return YES;
}

- (BOOL) isLocationServicesEnabled
{
	BOOL locationServicesEnabledInstancePropertyAvailable = [[self locationManager] respondsToSelector:@selector(locationServicesEnabled)]; // iOS 3.x
	BOOL locationServicesEnabledClassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(locationServicesEnabled)]; // iOS 4.x
    
	if (locationServicesEnabledClassPropertyAvailable)
	{ // iOS 4.x
		return [CLLocationManager locationServicesEnabled];
	}
	else if (locationServicesEnabledInstancePropertyAvailable)
	{ // iOS 2.x, iOS 3.x
		return [(id)[self locationManager] locationServicesEnabled];
	}
	else
	{
		return NO;
	}
}


#pragma mark Plugin Functions

// This method saves a reference to the command.callbackId for every registered region.
// This is only used to resolve calls to "startMonitoringRegion" (didStart or didFail handlers resolve the command)
- (void) initCallbackForRegionMonitoring:(CDVInvokedUrlCommand *)command forRegion:(CLRegion *)region {
    if (!self.locationData) {
        self.locationData = [[PGLocationData alloc] init];
    }
    PGLocationData* lData = self.locationData;
    
    if (!lData.geofencingCallbacks) {
        lData.geofencingCallbacks = [[NSMutableDictionary alloc] init];
    }
    
    if([lData.geofencingCallbacks objectForKey:region.identifier]) {
        [[self locationManager] stopMonitoringForRegion:region];
    }
    
    [lData.geofencingCallbacks setObject:command.callbackId forKey:region.identifier];
}
- (void) clearCallbackForRegionMonitoring:(NSString *)regionId {
    // Remove callback for region
    PGLocationData* lData = self.locationData;
    if(__hasGeofence && [lData.geofencingCallbacks objectForKey:regionId]) {
        [lData.geofencingCallbacks removeObjectForKey:regionId];
    }
    
    if([lData.geofencingCallbacks count] == 0) {
        lData.geofencingCallbacks = nil; // Does this free up memory?
    }
}
- (void) startMonitoringRegion:(CDVInvokedUrlCommand*)command {
    NSString* regionId = [command.arguments objectAtIndex:0];
    NSString *latitude = [command.arguments objectAtIndex:1];
    NSString *longitude = [command.arguments objectAtIndex:2];
    double radius = [[command.arguments objectAtIndex:3] doubleValue];
    //CLLocationAccuracy accuracy = [[command.arguments objectAtIndex:4] floatValue];
    
    PGLocationData* lData = self.locationData;
    NSString *callbackId = command.callbackId;
    
    if ([self isLocationServicesEnabled] == NO) {
        lData.locationStatus = PERMISSIONDENIED;
        NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
        [posError setObject:[NSNumber numberWithInt:PERMISSIONDENIED] forKey:@"code"];
        [posError setObject:@"Location services are disabled." forKey:@"message"];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    } if ([self isAuthorized] == NO) {
        lData.locationStatus = PERMISSIONDENIED;
        NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
        [posError setObject:[NSNumber numberWithInt:PERMISSIONDENIED] forKey:@"code"];
        [posError setObject:@"Location services are not authorized." forKey:@"message"];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    } if ([self isRegionMonitoringAvailable] == NO) {
        lData.geofencingStatus = GEOFENCINGUNAVAILABLE;
        NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
        [posError setObject:[NSNumber numberWithInt:GEOFENCINGUNAVAILABLE] forKey:@"code"];
        [posError setObject:@"Geofencing services are disabled." forKey:@"message"];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    } if ([self isRegionMonitoringEnabled] == NO) {
        lData.geofencingStatus = GEOFENCINGPERMISSIONDENIED;
        NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
        [posError setObject:[NSNumber numberWithInt:GEOFENCINGPERMISSIONDENIED] forKey:@"code"];
        [posError setObject:@"Geofencing services are not authorized." forKey:@"message"];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    } else {
        // Set up the region object
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);
        CLRegion *region = [[CLRegion alloc] initCircularRegionWithCenter:coord radius:radius identifier:regionId];
        
        // DO THIS BEFORE START MONITORING - Go ahead and register the callback commandId
        [self initCallbackForRegionMonitoring:command forRegion:region];
        
        // now start monitoring
        // desired accuracy is kind of moot.  The OS takes care of most of the grunt work and de-duping
        [self.locationManager  startMonitoringForRegion:region desiredAccuracy:kCLLocationAccuracyHundredMeters];
    }
}

- (void) stopMonitoringRegion:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    
    // Parse Incoming Params
    NSString *regionId = [command.arguments objectAtIndex:0];
    NSString *latitude = [command.arguments objectAtIndex:1];
    NSString *longitude = [command.arguments objectAtIndex:2];
    
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);
    CLRegion *region = [[CLRegion alloc] initCircularRegionWithCenter:coord radius:10.0 identifier:regionId];
    [[self locationManager] stopMonitoringForRegion:region];
    
    if([[self getMonitoredRegions] count] == 0) {
        __hasGeofence = NO;
    }
    
    // return success to callback
    NSMutableDictionary* returnInfo = [NSMutableDictionary dictionaryWithCapacity:2];
    NSNumber* timestamp = [NSNumber numberWithDouble:([[NSDate date] timeIntervalSince1970] * 1000)];
    [returnInfo setObject:timestamp forKey:@"timestamp"];
    [returnInfo setObject:@"Region was removed successfully" forKey:@"message"];
    [returnInfo setObject:regionId forKey:@"regionId"];
    [returnInfo setObject:@"monitorremoved" forKey:@"callbacktype"];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:returnInfo];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (NSArray *) getMonitoredRegions {
    NSArray *regions = [[self.locationManager monitoredRegions] allObjects];
    return regions;
}


- (void) startMonitoringSignificantLocationChanges:(CDVInvokedUrlCommand*)command {
    PGLocationData* lData = self.locationData;
    NSString *callbackId = command.callbackId;
    if (![self isLocationServicesEnabled])
	{
		BOOL forcePrompt = NO;
		if (!forcePrompt)
		{
            lData.locationStatus = GEOFENCINGPERMISSIONDENIED;
            NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
            [posError setObject:[NSNumber numberWithInt:GEOFENCINGPERMISSIONDENIED] forKey:@"code"];
            [posError setObject:@"Location services are not enabled." forKey:@"message"];
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
            [result setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
			return;
		}
    }
    
    if (![self isAuthorized])
    {
        NSString* message = nil;
        BOOL authStatusAvailable = [CLLocationManager respondsToSelector:@selector(authorizationStatus)]; // iOS 4.2+
        if (authStatusAvailable) {
            NSUInteger code = [CLLocationManager authorizationStatus];
            if (code == kCLAuthorizationStatusNotDetermined) {
                // could return POSITION_UNAVAILABLE but need to coordinate with other platforms
                message = @"User undecided on application's use of location services";
            } else if (code == kCLAuthorizationStatusRestricted) {
                message = @"application use of location services is restricted";
            }
        }
        //PERMISSIONDENIED is only PositionError that makes sense when authorization denied
        lData.locationStatus = GEOFENCINGPERMISSIONDENIED;
        NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
        [posError setObject:[NSNumber numberWithInt:GEOFENCINGPERMISSIONDENIED] forKey:@"code"];
        [posError setObject:message forKey:@"message"];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        
        return;
    }
    
    if (![self isSignificantLocationChangeMonitoringAvailable])
	{
        lData.locationStatus = GEOFENCINGUNAVAILABLE;
        NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
        [posError setObject:[NSNumber numberWithInt:GEOFENCINGPERMISSIONDENIED] forKey:@"code"];
        [posError setObject:@"Location services are not available." forKey:@"message"];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        return;
    }
    
    __isMonitoringSignificantLocation = YES;
    
    [[self locationManager] startMonitoringSignificantLocationChanges];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (void) stopMonitoringSignificantLocationChanges:(CDVInvokedUrlCommand*)command {
    PGLocationData* lData = self.locationData;
    NSString *callbackId = command.callbackId;
    if (![self isLocationServicesEnabled])
	{
		BOOL forcePrompt = NO;
		if (!forcePrompt)
		{
            lData.locationStatus = GEOFENCINGPERMISSIONDENIED;
            NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
            [posError setObject:[NSNumber numberWithInt:GEOFENCINGPERMISSIONDENIED] forKey:@"code"];
            [posError setObject:@"Location services are not enabled." forKey:@"message"];
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
            [result setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
			return;
		}
    }
    
    if (![self isAuthorized])
    {
        NSString* message = nil;
        BOOL authStatusAvailable = [CLLocationManager respondsToSelector:@selector(authorizationStatus)]; // iOS 4.2+
        if (authStatusAvailable) {
            NSUInteger code = [CLLocationManager authorizationStatus];
            if (code == kCLAuthorizationStatusNotDetermined) {
                // could return POSITION_UNAVAILABLE but need to coordinate with other platforms
                message = @"User undecided on application's use of location services";
            } else if (code == kCLAuthorizationStatusRestricted) {
                message = @"application use of location services is restricted";
            }
        }
        //PERMISSIONDENIED is only PositionError that makes sense when authorization denied
        lData.locationStatus = GEOFENCINGPERMISSIONDENIED;
        NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
        [posError setObject:[NSNumber numberWithInt:GEOFENCINGPERMISSIONDENIED] forKey:@"code"];
        [posError setObject:message forKey:@"message"];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        
        return;
    }
    
    if (![self isSignificantLocationChangeMonitoringAvailable])
	{
        lData.locationStatus = GEOFENCINGUNAVAILABLE;
        NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
        [posError setObject:[NSNumber numberWithInt:GEOFENCINGPERMISSIONDENIED] forKey:@"code"];
        [posError setObject:@"Location services are not available." forKey:@"message"];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        return;
    }
    
    __isMonitoringSignificantLocation = NO;
    
    [[self locationManager] stopMonitoringSignificantLocationChanges];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

#pragma mark Location Delegate Callbacks

/*
 *  locationManager:didStartMonitoringForRegion:
 *
 *  Discussion:
 *    Invoked when a monitoring for a region started successfully.
 */
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    NSString *regionId = region.identifier;
    PGLocationData* lData = self.locationData;
    
    // Get the commandId for this region so we can resolve it
    NSString* callbackId = [lData.geofencingCallbacks objectForKey:regionId];
    
    // return success to callback
    NSMutableDictionary* returnInfo = [NSMutableDictionary dictionaryWithCapacity:2];
    NSNumber* timestamp = [NSNumber numberWithDouble:([[NSDate date] timeIntervalSince1970] * 1000)];
    [returnInfo setObject:timestamp forKey:@"timestamp"];
    [returnInfo setObject:@"Region was successfully added for monitoring" forKey:@"message"];
    [returnInfo setObject:regionId forKey:@"regionId"];
    [returnInfo setObject:@"monitorstart" forKey:@"callbacktype"];
    
    // Save a reference to the new geofence and go ahead and check the current location.
    // If we are in a region, fire the "enter" event (see didUpdateToLocation)
    if(!lData.lsNewGeofences) {
        lData.lsNewGeofences = [[NSMutableDictionary alloc] init];
    }
    [lData.lsNewGeofences setObject:region forKey:regionId];
    if(!__isUpdatingLocation) {
        __isUpdatingLocation = YES;
        [self.locationManager startUpdatingLocation];
    }
    
    // Clear the callback... we no longer need it
    [self clearCallbackForRegionMonitoring:regionId];
    __hasGeofence = YES;
    
    // Resolve the startMonitoringRegion deferred with success
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:returnInfo];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}


/*
 *  locationManager:monitoringDidFailForRegion:withError:
 *
 *  Discussion:
 *    Invoked when a region monitoring error has occurred. Error types are defined in "CLError.h".
 */
- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSString *regionId = region.identifier;
    PGLocationData* lData = self.locationData;
    NSString* callbackId = [lData.geofencingCallbacks objectForKey:regionId];
    // return error to callback
    
    NSMutableDictionary* returnInfo = [NSMutableDictionary dictionaryWithCapacity:2];
    NSNumber* timestamp = [NSNumber numberWithDouble:([[NSDate date] timeIntervalSince1970] * 1000)];
    [returnInfo setObject:timestamp forKey:@"timestamp"];
    [returnInfo setObject:error.description forKey:@"message"];
    [returnInfo setObject:regionId forKey:@"regionId"];
    [returnInfo setObject:@"monitorfail" forKey:@"callbacktype"];
    
    // Clear the callback... we no longer need it
    [self clearCallbackForRegionMonitoring:regionId];
    
    // Reject the startMonitoringRegion deferred with failure
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:returnInfo];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

/*
 *  locationManager:didEnterRegion:
 *
 *  Discussion:
 *    Invoked when the user enters a monitored region.  This callback will be invoked for every allocated
 *    CLLocationManager instance with a non-nil delegate that implements this method.
 */
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    NSDictionary *dict = @{
        @"status": @"enter",
        @"fid": region.identifier
    };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options: 0 error: nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *jsStatement = [NSString stringWithFormat:@"PGLocationManager.regionMonitorUpdate(%@);", jsonString];
    [self.webView stringByEvaluatingJavaScriptFromString:jsStatement];
}

/*
 *  locationManager:didExitRegion:
 *
 *  Discussion:
 *    Invoked when the user exits a monitored region.  This callback will be invoked for every allocated
 *    CLLocationManager instance with a non-nil delegate that implements this method.
 */
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    NSLog(@"Did Exit Job Site");
    NSNumber* timestamp = [NSNumber numberWithLongLong:(long long)[[NSDate date] timeIntervalSince1970] * 1000];
    
    NSDictionary *dict = @{
                           @"status": @"left",
                           @"regionId": region.identifier,
                           @"timestamp": timestamp
                        };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options: 0 error: nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *jsStatement = [NSString stringWithFormat:@"PGLocationManager.regionMonitorUpdate(%@);", jsonString];
    [self.webView stringByEvaluatingJavaScriptFromString:jsStatement];
}

/*
-(void) locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    
    NSNumber *new_lat = [NSNumber numberWithDouble:newLocation.coordinate.latitude];
    NSNumber *new_lon = [NSNumber numberWithDouble:newLocation.coordinate.longitude];
    
    // For any new geofencing regions, check if we are currently inside and fire the didEnterRegion event
    PGLocationData* lData = self.locationData;
    if(lData.lsNewGeofences) {
        for(id key in lData.lsNewGeofences) {
            CLRegion *region = [lData.lsNewGeofences objectForKey:key];
            if([region containsCoordinate:newLocation.coordinate]) {
                [self locationManager:manager didEnterRegion:region];
            }
        }
        
        [lData.lsNewGeofences removeAllObjects];
        lData.lsNewGeofences = nil;
        
        if(__isUpdatingLocation) {
            __isUpdatingLocation = NO;
            [self.locationManager stopUpdatingLocation];
        }
    }
    
    if(__isMonitoringSignificantLocation) {
        NSDictionary *dict = @{
                               @"new_timestamp": [NSNumber numberWithDouble:[newLocation.timestamp timeIntervalSince1970]],
                               @"new_speed": [NSNumber numberWithDouble:newLocation.speed],
                               @"new_course": [NSNumber numberWithDouble:newLocation.course],
                               @"new_verticalAccuracy": [NSNumber numberWithDouble:newLocation.verticalAccuracy],
                               @"new_horizontalAccuracy": [NSNumber numberWithDouble:newLocation.horizontalAccuracy],
                               @"new_altitude": [NSNumber numberWithDouble:newLocation.altitude],
                               @"new_latitude": new_lat,
                               @"new_longitude": new_lon,
                               
                               @"old_timestamp": [NSNumber numberWithDouble:[oldLocation.timestamp timeIntervalSince1970]],
                               @"old_speed": [NSNumber numberWithDouble:oldLocation.speed],
                               @"old_course": [NSNumber numberWithDouble:oldLocation.course],
                               @"old_verticalAccuracy": [NSNumber numberWithDouble:oldLocation.verticalAccuracy],
                               @"old_horizontalAccuracy": [NSNumber numberWithDouble:oldLocation.horizontalAccuracy],
                               @"old_altitude": [NSNumber numberWithDouble:oldLocation.altitude],
                               @"old_latitude": [NSNumber numberWithDouble:oldLocation.coordinate.latitude],
                               @"old_longitude": [NSNumber numberWithDouble:oldLocation.coordinate.longitude]
                               };
        
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error: nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSString *jsStatement = [NSString stringWithFormat:@"PGLocationManager.locationMonitorUpdate(%@);", jsonString];
        [self.webView stringByEvaluatingJavaScriptFromString:jsStatement];
    }
}
 */

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    PGLocationData* lData = self.locationData;
    
    // Loop over the locations and perform necessary tasks
    for(CLLocation *newLocation in locations) {
        NSNumber *new_lat = [NSNumber numberWithDouble:newLocation.coordinate.latitude];
        NSNumber *new_lon = [NSNumber numberWithDouble:newLocation.coordinate.longitude];
        
        // For any new geofencing regions, check if we are currently inside and fire the didEnterRegion event
        if(lData.lsNewGeofences) {
            for(id key in lData.lsNewGeofences) {
                CLRegion *region = [lData.lsNewGeofences objectForKey:key];
                if([region containsCoordinate:newLocation.coordinate]) {
                    [self locationManager:manager didEnterRegion:region];
                }
            }
        }
        
        if(__isMonitoringSignificantLocation) {
            NSDictionary *dict = @{
                                   @"new_timestamp": [NSNumber numberWithDouble:[newLocation.timestamp timeIntervalSince1970]],
                                   @"new_speed": [NSNumber numberWithDouble:newLocation.speed],
                                   @"new_course": [NSNumber numberWithDouble:newLocation.course],
                                   @"new_verticalAccuracy": [NSNumber numberWithDouble:newLocation.verticalAccuracy],
                                   @"new_horizontalAccuracy": [NSNumber numberWithDouble:newLocation.horizontalAccuracy],
                                   @"new_altitude": [NSNumber numberWithDouble:newLocation.altitude],
                                   @"new_latitude": new_lat,
                                   @"new_longitude": new_lon
                                };
            
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error: nil];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSString *jsStatement = [NSString stringWithFormat:@"PGLocationManager.locationMonitorUpdate(%@);", jsonString];
            [self.webView stringByEvaluatingJavaScriptFromString:jsStatement];
        }
    }
    
    // clean up
    if(lData.lsNewGeofences) {
        [lData.lsNewGeofences removeAllObjects];
        lData.lsNewGeofences = nil;
        
        if(__isUpdatingLocation) {
            __isUpdatingLocation = NO;
            [self.locationManager stopUpdatingLocation];
        }
    }
}

@end