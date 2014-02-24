package com.phonegap.plugins.locationmanager;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import static com.phonegap.plugins.locationmanager.PGLocationManagerService.TAG;

/**
 * @author edewit@redhat.com
 */
public class ProximityReceiver extends BroadcastReceiver {

  @Override
  public void onReceive(Context context, Intent intent) {
    String id = (String) intent.getExtras().get("id");
    Log.d(TAG, "received proximity alert for region " + id);

    PGLocationManager.getInstance().fireRegionChangedEvent(intent);
  }
}
