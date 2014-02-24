/**
 * LocationManager.js
 *
 * Phonegap LocationMonitor Plugin
 * Rewritten by Ryan Wheale - 2014
 * https://github.com/DesignByOnyx
 * ryan.wheale@gmail.com
 *
 * // ---------------------------------------------
 * // ---- Preserved for licensing reasons --------
 * Phonegap Geofencing Plugin
 * Copyright (c) Dov Goldberg 2012
 * http://www.ogonium.com
 * dov.goldberg@ogonium.com
 * // ---------------------------------------------
 */

var exec = require('cordova/exec'),
	pendingRegionUpdates = [],
	pendingLocationUpdates = [],
	regionCallbacks = [],
	locationCallbacks = [];


var LocationManager = {
/*
     Params:
     NONE
    */
/*
	initCallbackForRegionMonitoring: function(params, success, fail) {
		return exec(success, fail, "DGGeofencing", "initCallbackForRegionMonitoring", params);
	},
	*/
	
/*
     Params:
     #define KEY_REGION_ID       @"regionId"
     #define KEY_REGION_LAT      @"latitude"
     #define KEY_REGION_LNG      @"longitude"
     #define KEY_REGION_RADIUS   @"radius"
     #define KEY_REGION_ACCURACY @"accuracy"
     */
	startMonitoringRegion: function(params, success, fail) {
		return exec(success, fail, "LocationManager", "startMonitoringRegion", params);
	},

/*
	Params:
	#define KEY_REGION_ID      @"regionId"
	#define KEY_REGION_LAT     @"latitude"
    #define KEY_REGION_LNG     @"longitude"
	*/
	stopMonitoringRegion: function(params, success, fail) {
		return exec(success, fail, "LocationManager", "stopMonitoringRegion", params);
	},

/*
	Params:
	NONE
	*/
	startMonitoringSignificantLocationChanges: function(success, fail) {
		return exec(success, fail, "LocationManager", "startMonitoringSignificantLocationChanges", []);
	},

/*
	Params:
	NONE
	*/
	stopMonitoringSignificantLocationChanges: function(success, fail) {
		return exec(success, fail, "LocationManager", "stopMonitoringSignificantLocationChanges", []);
	},

/*
	Params:
	NONE
	*/
	getWatchedRegionIds: function(success, fail) {
		return exec(success, fail, "LocationManager", "getWatchedRegionIds", []);
	},

/*
	Params:
	NONE
	*/
	getPendingRegionUpdates: function(success, fail) {
		return pendingRegionUpdates;
	},

/*
	Params:
	NONE
	*/
	getPendingLocationUpdates: function(success, fail) {
		return pendingLocationUpdates;
	},
	
	onRegionUpdate: function(callback) {
		if( typeof callback === 'function' ) {
			// TODO: check if callback function already exists?
			regionCallbacks.push(callback);
		}
		
		if(pendingRegionUpdates.length) {
			for(var i = 0; i < pendingRegionUpdates.length; i++) {
				this.__regionMonitorUpdate( pendingRegionUpdates[i] );
			}
		}
	},
	
	onLocationUpdate: function(callback) {
		if( typeof callback === 'function' ) {
			// TODO: check if callback function already exists?
			locationCallbacks.push(callback);
		}
		
		if(pendingLocationUpdates.length) {
			for(var i = 0; i < pendingLocationUpdates.length; i++) {
				this.__locationMonitorUpdate( pendingLocationUpdates[i] );
			}
		}
	},
	
	
	/*
	
	Whenever the device receives a location update, the native code is going to call
	one of the below "protected" methods.  However, if the app is not running, the system
	will launch the app and call one of these methods once the device.ready event
	fires.  The problem with this is that the application code might not have
	initialized and the event handlers may not yet be bound. To fix this we put
	the region update into a list of "pending" updates.  As soon as the first
	event handler is bound (using onRegionUpdate/onLocationUpdate), the pending
	location updates will be flushed to that handler.
	  
	*/
	
	/* 
	This is called by native code whenever a region boundary is crossed.
	*/
	__regionMonitorUpdate: function(regionUpdate) {
		if( regionCallbacks.length ) {
			for(var i = 0; i < regionCallbacks.length; i++) {
				if( typeof regionCallbacks[i] === "function" ) {
					regionCallbacks[i]( regionUpdate );
				}
			}
		} else {
			pendingRegionUpdates.push(regionUpdate);
		}
	},
	
	/* 
	This is called by native code once a significant location change event happens
	*/
	__locationMonitorUpdate: function(locationUpdate) {
		if( locationCallbacks.length ) {
			for(var i = 0; i < locationCallbacks.length; i++) {
				if( typeof locationCallbacks[i] === "function" ) {
					locationCallbacks[i]( locationUpdate );
				}
			}
		} else {
			pendingLocationUpdates.push(locationUpdate);
		}
	}
};

if (typeof module != 'undefined' && module.exports) {
    module.exports = LocationManager;
}