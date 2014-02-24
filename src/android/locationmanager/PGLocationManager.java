package com.phonegap.plugins.locationmanager;

import android.content.*;
import android.location.Location;
import android.location.LocationManager;
import android.util.Log;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

import static com.phonegap.plugins.locationmanager.PGLocationManagerService.TAG;

/**
 * @author edewit@redhat.com
 * @author ryan.wheale@gmail.com
 */
public class PGLocationManager extends CordovaPlugin {
  public static final String PREFS_NAME = "watchedRegionIds";

  public PGLocationManagerService service;
  private LocationChangedListener locationChangedListener;
  private Location oldLocation;
  private BroadcastReceiver receiver;
  private static PGLocationManager instance;
  private Set<String> regionIds;
  private String strRegionIds;

  public static PGLocationManager getInstance() {
    return instance;
  }

  public PGLocationManager() {
    instance = this;
  }

  @Override
  public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    super.initialize(cordova, webView);

    SharedPreferences settings = cordova.getActivity().getSharedPreferences(PREFS_NAME, 0);
    //regionIds = settings.getStringSet(PREFS_NAME, new HashSet<String>());
    
    // Support for < 4.0
    strRegionIds = settings.getString(PREFS_NAME, "");
    regionIds = new HashSet<String>( Arrays.asList(strRegionIds.split(",")) );

    service = new PGLocationManagerService(cordova.getActivity());
  }

  @Override
  public void onDestroy() {
    if (receiver != null) {
      cordova.getActivity().unregisterReceiver(receiver);
    }

    SharedPreferences settings = cordova.getActivity().getSharedPreferences(PREFS_NAME, 0);
    SharedPreferences.Editor editor = settings.edit();
    //editor.putStringSet(PREFS_NAME, regionIds);
    
    // Support for <4.0
    // TODO: rewrite this using best practices for converting HashSet<string> to String (JSON?)
    strRegionIds = arrayJoin( regionIds.toArray( new String[regionIds.size()] ), ",");
    editor.putString(PREFS_NAME, strRegionIds);
    
    editor.commit();
  }

  @Override
  public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {
	  try {
      if ("startMonitoringRegion".equals(action)) {
    	//data = [id, lat, lon, radius]
    	
    	/*JSONObject params = parseParameters(data);
        String id = params.getString("fid");
        Log.d(TAG, "adding region " + id);
        service.addRegion(id, params.getDouble("latitude"), params.getDouble("longitude"),
                (float) params.getInt("radius"));*/
    	 
	    String id = data.getString(0);
	    Double lat = data.getDouble(1);
	    Double lon = data.getDouble(2);
	    Float radius = (float) data.getInt(3);
        Log.d(TAG, "Adding region(" + id + ", " + lat + ", " + lon + ", " + radius +")");
        service.addRegion(id, lat, lon, radius);
        
        registerListener();
        regionIds.add(id);
        callbackContext.success();
        return true;
      }
      if ("stopMonitoringRegion".equals(action)) {
        /*JSONObject params = parseParameters(data);
        String id = params.getString("fid");*/
    	//data = [id]
    	String id = data.getString(0);
        service.removeRegion(id);
        regionIds.remove(id);
        
        if(regionIds.size() == 0 && receiver != null) {
            cordova.getActivity().unregisterReceiver(receiver);
        }
        
        callbackContext.success();
        return true;
      }
      if ("getWatchedRegionIds".equals(action)) {
        //callbackContext.success(new JSONArray(regionIds));
    	
    	// Support for <= 2.3
    	//TODO: use better method to convert HashSet<string> to String
    	strRegionIds = arrayJoin( regionIds.toArray( new String[regionIds.size()] ), ",");
        callbackContext.success( strRegionIds );
		return true;
      }

      if ("startMonitoringSignificantLocationChanges".equals(action)) {
        Log.d(TAG, "startMonitoringSignificantLocationChanges");
        if (locationChangedListener == null) {
          locationChangedListener = new LocationChangedListener() {
            @Override
            public void onLocationChanged(Location location) {
              fireLocationChangedEvent(location);
            }
          };
        }
        service.addLocationChangedListener(locationChangedListener);
        callbackContext.success();
		return true;
      }

      if ("stopMonitoringSignificantLocationChanges".equals(action)) {
        service.removeLocationChangedListener(locationChangedListener);
        callbackContext.success();
      }

    } catch (Exception e) {
      StringWriter writer = new StringWriter();
      PrintWriter err = new PrintWriter(writer);
      e.printStackTrace(err);
      callbackContext.error("EXCEPTION: " + writer.toString());
    }

    return false;
  }

  void fireLocationChangedEvent(final Location location) {
    Log.d(TAG, "fireLocationChangedEvent");
    cordova.getActivity().runOnUiThread(new Runnable() {
      @Override
      public void run() {
        webView.loadUrl("javascript:LocationManager.__locationMonitorUpdate(" + createLocationEvent(location) + ")");
        oldLocation = location;
      }
    });
  }

  private String createLocationEvent(Location location) {
    JSONObject object = new JSONObject();
    try {
      addLocation(location, object, "new");
      if (oldLocation != null) {
        addLocation(oldLocation, object, "old");
      }
    } catch (JSONException e) {
      throw new RuntimeException("location could not be serialized to json", e);
    }

    return object.toString();
  }

  private void addLocation(Location location, JSONObject object, String prefix) throws JSONException {
    object.put(prefix + "_timestamp", location.getTime());
    object.put(prefix + "_speed", location.getSpeed());
    object.put(prefix + "_course", location.getBearing());
    object.put(prefix + "_verticalAccuracy", location.getAccuracy());
    object.put(prefix + "_horizontalAccuracy", location.getAccuracy());
    object.put(prefix + "_altitude", location.getAltitude());
    object.put(prefix + "_latitude", location.getLatitude());
    object.put(prefix + "_longitude", location.getLongitude());
  }

  private void registerListener() {
    IntentFilter filter = new IntentFilter(PGLocationManagerService.PROXIMITY_ALERT_INTENT);
    receiver = new BroadcastReceiver() {
      @Override
      public void onReceive(Context context, final Intent intent) {
        fireRegionChangedEvent(intent);
      }
    };
    cordova.getActivity().registerReceiver(receiver, filter);
  }

  void fireRegionChangedEvent(final Intent intent) {
    cordova.getActivity().runOnUiThread(new Runnable() {
      @Override
      public void run() {
        String status = intent.getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, false) ? "enter" : "left";
        String id = (String) intent.getExtras().get("id");
        String timestamp = String.valueOf(System.currentTimeMillis() / 1000L);
	    Log.d(TAG, "javascript:LocationManager.__regionMonitorUpdate(" + createRegionEvent(id, status, timestamp) + ")");
        webView.loadUrl("javascript:LocationManager.__regionMonitorUpdate(" + createRegionEvent(id, status, timestamp) + ")");
      }
    });
  }

  private String createRegionEvent(String id, String status, String timestamp) {
    return "{fid:\"" + id + "\",status:\"" + status + "\",timestamp:\"" + timestamp + "\"}";
  }
/*
  private JSONObject parseParameters(JSONArray data) throws JSONException {
    if (data.length() == 1 && !data.isNull(0)) {
      return (JSONObject) data.get(0);
    } else {
      throw new IllegalArgumentException("Invalid arguments specified!");
    }
  }
 */ 
  private String arrayJoin(String[] strArray, String glue)
  {
    int len = strArray.length;
    if (len == 0)
      return null;
    StringBuilder out = new StringBuilder();
    out.append(strArray[0]);
    for (int x=1; x<len; ++x)
      out.append(glue).append(strArray[x]);
    return out.toString();
  }
}
