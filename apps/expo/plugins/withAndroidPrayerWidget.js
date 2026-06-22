const { AndroidConfig, withAndroidManifest, withDangerousMod, withMainApplication } = require('expo/config-plugins');
const fs = require('fs');
const path = require('path');

const pkg = 'com.mikhailspeaks.masjidly';
const javaDir = ['app', 'src', 'main', 'java', ...pkg.split('.')];

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}

function upsertBefore(text, marker, insert) {
  return text.includes(insert.trim()) ? text : text.replace(marker, `${insert}${marker}`);
}

function withAndroidPrayerWidget(config) {
  config = withAndroidManifest(config, (mod) => {
    const app = AndroidConfig.Manifest.getMainApplicationOrThrow(mod.modResults);
    app.receiver = (app.receiver || []).filter(
      (r) => r.$?.['android:name'] !== '.MasjidlyPrayerWidgetProvider'
    );
    app.receiver.push({
      $: { 'android:name': '.MasjidlyPrayerWidgetProvider', 'android:exported': 'false' },
      'intent-filter': [{ action: [{ $: { 'android:name': 'android.appwidget.action.APPWIDGET_UPDATE' } }] }],
      'meta-data': [{ $: { 'android:name': 'android.appwidget.provider', 'android:resource': '@xml/masjidly_prayer_widget_info' } }],
    });
    return mod;
  });

  config = withMainApplication(config, (mod) => {
    if (!mod.modResults.contents.includes('MasjidlyPrayerWidgetPackage()')) {
      mod.modResults.contents = mod.modResults.contents.replace(
        '// add(MyReactNativePackage())',
        '// add(MyReactNativePackage())\n          add(MasjidlyPrayerWidgetPackage())'
      );
    }
    return mod;
  });

  return withDangerousMod(config, ['android', (mod) => {
    const root = mod.modRequest.platformProjectRoot;
    const src = (...parts) => path.join(root, ...parts);
    const kt = (...parts) => src(...javaDir, ...parts);

    write(kt('MasjidlyPrayerWidgetModule.kt'), moduleKt);
    write(kt('MasjidlyPrayerWidgetPackage.kt'), packageKt);
    write(kt('MasjidlyPrayerWidgetProvider.kt'), providerKt);
    write(src('app', 'src', 'main', 'res', 'layout', 'masjidly_prayer_widget.xml'), layoutXml);
    write(src('app', 'src', 'main', 'res', 'drawable', 'masjidly_widget_background.xml'), backgroundXml);
    write(src('app', 'src', 'main', 'res', 'xml', 'masjidly_prayer_widget_info.xml'), widgetInfoXml);

    const strings = src('app', 'src', 'main', 'res', 'values', 'strings.xml');
    fs.writeFileSync(strings, upsertBefore(
      fs.readFileSync(strings, 'utf8'),
      '</resources>',
      '  <string name="masjidly_prayer_widget_description">Masjidly prayer times</string>\n'
    ));

    const styles = src('app', 'src', 'main', 'res', 'values', 'styles.xml');
    fs.writeFileSync(styles, upsertBefore(fs.readFileSync(styles, 'utf8'), '</resources>', stylesXml));

    return mod;
  }]);
}

const moduleKt = `package ${pkg}

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class MasjidlyPrayerWidgetModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName() = "MasjidlyPrayerWidget"

  @ReactMethod
  fun saveSnapshot(json: String, promise: Promise) {
    try {
      reactContext
        .getSharedPreferences(MasjidlyPrayerWidgetProvider.PREFS_NAME, 0)
        .edit()
        .putString(MasjidlyPrayerWidgetProvider.KEY_SNAPSHOT, json)
        .apply()

      MasjidlyPrayerWidgetProvider.updateAll(reactContext)
      promise.resolve(true)
    } catch (error: Exception) {
      promise.reject("ERR_WIDGET_SAVE", error)
    }
  }
}
`;

const packageKt = `package ${pkg}

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class MasjidlyPrayerWidgetPackage : ReactPackage {
  override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> =
    listOf(MasjidlyPrayerWidgetModule(reactContext))

  override fun createViewManagers(
    reactContext: ReactApplicationContext
  ): List<ViewManager<*, *>> = emptyList()
}
`;

const providerKt = `package ${pkg}

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

class MasjidlyPrayerWidgetProvider : AppWidgetProvider() {
  override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
    ids.forEach { updateWidget(context, manager, it) }
  }

  companion object {
    const val PREFS_NAME = "masjidly_prayer_widget"
    const val KEY_SNAPSHOT = "snapshot_json"

    private val prayers = listOf(
      "fajr" to "Fajr",
      "dhuhr" to "Dhuhr",
      "asr" to "Asr",
      "maghrib" to "Maghrib",
      "isha" to "Isha"
    )

    fun updateAll(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val component = ComponentName(context, MasjidlyPrayerWidgetProvider::class.java)
      manager.getAppWidgetIds(component).forEach { updateWidget(context, manager, it) }
    }

    private fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
      val views = RemoteViews(context.packageName, R.layout.masjidly_prayer_widget)
      views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context))

      val json = context
        .getSharedPreferences(PREFS_NAME, 0)
        .getString(KEY_SNAPSHOT, null)

      if (json.isNullOrBlank()) showEmpty(views) else renderSnapshot(views, json)
      manager.updateAppWidget(id, views)
    }

    private fun launchIntent(context: Context): PendingIntent {
      val intent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      }
      return PendingIntent.getActivity(
        context,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )
    }

    private fun showEmpty(views: RemoteViews) {
      views.setTextViewText(R.id.widget_title, "Masjidly")
      views.setTextViewText(R.id.widget_subtitle, "Open the app to load prayer times")
      listOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4).forEach {
        views.setViewVisibility(it, View.GONE)
      }
    }

    private fun renderSnapshot(views: RemoteViews, json: String) {
      try {
        val snapshot = JSONObject(json)
        val mosque = snapshot.getJSONObject("mosque").optString("name", "Masjidly")
        val today = snapshot.getJSONArray("days").getJSONObject(0)
        val prayerTimes = today.getJSONObject("prayers")
        val iqamahTimes = today.getJSONObject("iqamah")

        views.setTextViewText(R.id.widget_title, mosque)
        views.setTextViewText(R.id.widget_subtitle, "Today’s prayer times")

        val rowIds = listOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
        val nameIds = listOf(R.id.name_0, R.id.name_1, R.id.name_2, R.id.name_3, R.id.name_4)
        val timeIds = listOf(R.id.time_0, R.id.time_1, R.id.time_2, R.id.time_3, R.id.time_4)

        prayers.forEachIndexed { index, (key, label) ->
          views.setViewVisibility(rowIds[index], View.VISIBLE)
          views.setTextViewText(nameIds[index], label)
          views.setTextViewText(timeIds[index], "\${prayerTimes.optString(key, "—")}  •  \${iqamahTimes.optString(key, "—")}")
        }
      } catch (_: Exception) {
        showEmpty(views)
      }
    }
  }
}
`;

const layoutXml = `<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
  android:id="@+id/widget_root"
  android:layout_width="match_parent"
  android:layout_height="match_parent"
  android:background="@drawable/masjidly_widget_background"
  android:orientation="vertical"
  android:padding="14dp">
  <TextView android:id="@+id/widget_title" android:layout_width="match_parent" android:layout_height="wrap_content" android:ellipsize="end" android:singleLine="true" android:text="Masjidly" android:textColor="#123524" android:textSize="16sp" android:textStyle="bold" />
  <TextView android:id="@+id/widget_subtitle" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="2dp" android:text="Today’s prayer times" android:textColor="#557064" android:textSize="12sp" />
  <LinearLayout android:id="@+id/row_0" style="@style/MasjidlyWidgetRow"><TextView android:id="@+id/name_0" style="@style/MasjidlyWidgetName" /><TextView android:id="@+id/time_0" style="@style/MasjidlyWidgetTime" /></LinearLayout>
  <LinearLayout android:id="@+id/row_1" style="@style/MasjidlyWidgetRow"><TextView android:id="@+id/name_1" style="@style/MasjidlyWidgetName" /><TextView android:id="@+id/time_1" style="@style/MasjidlyWidgetTime" /></LinearLayout>
  <LinearLayout android:id="@+id/row_2" style="@style/MasjidlyWidgetRow"><TextView android:id="@+id/name_2" style="@style/MasjidlyWidgetName" /><TextView android:id="@+id/time_2" style="@style/MasjidlyWidgetTime" /></LinearLayout>
  <LinearLayout android:id="@+id/row_3" style="@style/MasjidlyWidgetRow"><TextView android:id="@+id/name_3" style="@style/MasjidlyWidgetName" /><TextView android:id="@+id/time_3" style="@style/MasjidlyWidgetTime" /></LinearLayout>
  <LinearLayout android:id="@+id/row_4" style="@style/MasjidlyWidgetRow"><TextView android:id="@+id/name_4" style="@style/MasjidlyWidgetName" /><TextView android:id="@+id/time_4" style="@style/MasjidlyWidgetTime" /></LinearLayout>
</LinearLayout>
`;

const backgroundXml = `<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
  <solid android:color="#F7FBF8" />
  <corners android:radius="22dp" />
</shape>
`;

const widgetInfoXml = `<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
  android:description="@string/masjidly_prayer_widget_description"
  android:initialLayout="@layout/masjidly_prayer_widget"
  android:minWidth="250dp"
  android:minHeight="140dp"
  android:previewImage="@mipmap/ic_launcher"
  android:resizeMode="horizontal|vertical"
  android:targetCellWidth="4"
  android:targetCellHeight="2"
  android:updatePeriodMillis="0"
  android:widgetCategory="home_screen" />
`;

const stylesXml = `  <style name="MasjidlyWidgetRow">
    <item name="android:layout_width">match_parent</item>
    <item name="android:layout_height">0dp</item>
    <item name="android:layout_weight">1</item>
    <item name="android:gravity">center_vertical</item>
    <item name="android:orientation">horizontal</item>
  </style>
  <style name="MasjidlyWidgetName">
    <item name="android:layout_width">0dp</item>
    <item name="android:layout_height">wrap_content</item>
    <item name="android:layout_weight">1</item>
    <item name="android:textColor">#123524</item>
    <item name="android:textSize">13sp</item>
    <item name="android:textStyle">bold</item>
  </style>
  <style name="MasjidlyWidgetTime">
    <item name="android:layout_width">wrap_content</item>
    <item name="android:layout_height">wrap_content</item>
    <item name="android:textColor">#284D3A</item>
    <item name="android:textSize">13sp</item>
  </style>
`;

module.exports = withAndroidPrayerWidget;
