package com.androidemu.snes;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.ProgressDialog;
import android.bluetooth.BluetoothAdapter;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Rect;
import android.media.AudioManager;
import android.net.wifi.WifiManager;
import android.net.wifi.WifiInfo;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.preference.PreferenceManager;
import android.util.Log;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.nio.ByteBuffer;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.apache.http.conn.util.InetAddressUtils;

import com.androidemu.Emulator;
import com.androidemu.EmulatorView;
import com.androidemu.EmuMedia;
import com.androidemu.snes.input.*;
import com.androidemu.snes.wrapper.Wrapper;

public class EmulatorActivity extends Activity implements
		Emulator.FrameUpdateListener,
		SharedPreferences.OnSharedPreferenceChangeListener,
		SurfaceHolder.Callback,
		View.OnTouchListener,
		EmulatorView.OnTrackballListener,
		Emulator.OnFrameDrawnListener,
		GameKeyListener {

	private static final String LOG_TAG = "SNesoid";

	private static final int REQUEST_LOAD_STATE = 1;
	private static final int REQUEST_SAVE_STATE = 2;
	private static final int REQUEST_ENABLE_BT_SERVER = 3;
	private static final int REQUEST_ENABLE_BT_CLIENT = 4;
	private static final int REQUEST_BT_DEVICE = 5;

	private static final int DIALOG_QUIT_GAME = 1;
	private static final int DIALOG_REPLACE_GAME = 2;
	private static final int DIALOG_WIFI_CONNECT = 3;

	private static final int NETPLAY_TCP_PORT = 5369;
	private static final int MESSAGE_SYNC_CLIENT = 1000;

	private static final int GAMEPAD_LEFT_RIGHT =
			(Emulator.GAMEPAD_LEFT | Emulator.GAMEPAD_RIGHT);
	private static final int GAMEPAD_UP_DOWN =
			(Emulator.GAMEPAD_UP | Emulator.GAMEPAD_DOWN);
	private static final int GAMEPAD_DIRECTION =
			(GAMEPAD_UP_DOWN | GAMEPAD_LEFT_RIGHT);

	private Emulator emulator;
	private EmulatorView emulatorView;
	private Rect surfaceRegion = new Rect();
	private int surfaceWidth;
	private int surfaceHeight;

	private Keyboard keyboard;
	private VirtualKeypad vkeypad;
	private SensorKeypad sensor;
	private int[] sensorMappings;
	private boolean lightGunEnabled;
	private boolean flipScreen;
	private boolean inFastForward;
	private float fastForwardSpeed;
	private int trackballSensitivity;

	private int quickLoadKey;
	private int quickSaveKey;
	private int fastForwardKey;
	private int screenshotKey;

	private SharedPreferences sharedPrefs;
	private Intent newIntent;
	private MediaScanner mediaScanner;
	private NetWaitDialog waitDialog;
	private NetPlayService netPlayService;
	private int autoSyncClientInterval;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		if (!Intent.ACTION_VIEW.equals(getIntent().getAction())) {
			finish();
			return;
		}
		requestWindowFeature(Window.FEATURE_NO_TITLE);
		setVolumeControlStream(AudioManager.STREAM_MUSIC);

		sharedPrefs = PreferenceManager.getDefaultSharedPreferences(this);
		final SharedPreferences prefs = sharedPrefs;
		prefs.registerOnSharedPreferenceChangeListener(this);

		emulator = Emulator.createInstance(getApplicationContext(),
				getEmulatorEngine(prefs));
		EmuMedia.setOnFrameDrawnListener(this);

		setContentView(R.layout.emulator);

		emulatorView = (EmulatorView) findViewById(R.id.emulator);
		emulatorView.getHolder().addCallback(this);
		emulatorView.setOnTouchListener(this);
		emulatorView.requestFocus();

		// keyboard is always present
		keyboard = new Keyboard(emulatorView, this);

		final String[] prefKeys = {
			"fullScreenMode",
			"flipScreen",
			"fastForwardSpeed",
			"frameSkipMode",
			"maxFrameSkips",
			"refreshRate",
			"enableLightGun",
			"enableGamepad2",
			"soundEnabled",
			"soundVolume",
			"transparencyEnabled",
			"enableHiRes",
			"enableTrackball",
			"trackballSensitivity",
			"useSensor",
			"sensorSensitivity",
			"enableVKeypad",
			"scalingMode",
			"aspectRatio",
			"enableCheats",
			"orientation",
			"useInputMethod",
			"quickLoad",
			"quickSave",
			"fastForward",
			"screenshot",
		};

		for (String key : prefKeys)
			onSharedPreferenceChanged(prefs, key);
		loadKeyBindings(prefs);

		emulator.setOption("enableSRAM", true);
		emulator.setOption("apuEnabled",
				prefs.getBoolean("apuEnabled", true));

		if (!loadROM()) {
			finish();
			return;
		}
		startService(new Intent(this, EmulatorService.class).
				setAction(EmulatorService.ACTION_FOREGROUND));
	}

	@Override
	protected void onDestroy() {
		super.onDestroy();

		if (emulator != null)
			emulator.unloadROM();
		onDisconnect();

		stopService(new Intent(this, EmulatorService.class));
	}

	@Override
	protected void onPause() {
		super.onPause();

		pauseEmulator();
		if (sensor != null)
			sensor.setGameKeyListener(null);
	}

	@Override
	protected void onResume() {
		super.onResume();

		if (sensor != null)
			sensor.setGameKeyListener(this);
	}

	@Override
	public void onConfigurationChanged(Configuration newConfig) {
		super.onConfigurationChanged(newConfig);

		setFlipScreen(sharedPrefs, newConfig);
	}

	@Override
	public void onWindowFocusChanged(boolean hasFocus) {
		super.onWindowFocusChanged(hasFocus);

		if (hasFocus) {
			// reset keys
			keyboard.reset();
			if (vkeypad != null)
				vkeypad.reset();
			emulator.setKeyStates(0);

			emulator.resume();
		} else
			emulator.pause();
	}

	@Override
	protected void onNewIntent(Intent intent) {
		if (!Intent.ACTION_VIEW.equals(intent.getAction()))
			return;

		newIntent = intent;

		pauseEmulator();
		showDialog(DIALOG_REPLACE_GAME);
	}

	@Override
	protected Dialog onCreateDialog(int id) {
		switch (id) {
		case DIALOG_QUIT_GAME:
			return createQuitGameDialog();
		case DIALOG_REPLACE_GAME:
			return createReplaceGameDialog();
		case DIALOG_WIFI_CONNECT:
			return createWifiConnectDialog();
		}
		return super.onCreateDialog(id);
	}

	@Override
	protected void onPrepareDialog(int id, Dialog dialog) {
		switch (id) {
		case DIALOG_WIFI_CONNECT:
			TextView v = (TextView) dialog.findViewById(R.id.port);
			if (v.getText().length() == 0)
				v.setText(Integer.toString(NETPLAY_TCP_PORT));
			break;
		}
	}

	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if (keyCode == quickLoadKey) {
			quickLoad();
			return true;
		}
		if (keyCode == quickSaveKey) {
			quickSave();
			return true;
		}
		if (keyCode == fastForwardKey) {
			onFastForward();
			return true;
		}
		if (keyCode == screenshotKey) {
			onScreenshot();
			return true;
		}
		// ignore keys that would annoy the user
		if (keyCode == KeyEvent.KEYCODE_CAMERA ||
				keyCode == KeyEvent.KEYCODE_SEARCH)
			return true;

		if (keyCode == KeyEvent.KEYCODE_BACK) {
			pauseEmulator();
			showDialog(DIALOG_QUIT_GAME);
			return true;
		}
		return super.onKeyDown(keyCode, event);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);

		getMenuInflater().inflate(R.menu.emulator, menu);

		if (!Wrapper.isBluetoothPresent()) {
			menu.findItem(R.id.menu_bluetooth_server).setVisible(false);
			menu.findItem(R.id.menu_bluetooth_client).setVisible(false);
		}
		return true;
	}

	@Override
	public boolean onPrepareOptionsMenu(Menu menu) {
		super.onPrepareOptionsMenu(menu);
		pauseEmulator();

		final boolean netplay = (netPlayService != null);
		menu.findItem(R.id.menu_netplay_connect).setVisible(!netplay);
		menu.findItem(R.id.menu_netplay_disconnect).setVisible(netplay);
		menu.findItem(R.id.menu_netplay_sync).setVisible(netplay);
		menu.findItem(R.id.menu_cheats).setVisible(!netplay);
		menu.findItem(R.id.menu_fast_forward).setVisible(!netplay);

		menu.findItem(R.id.menu_cheats).setEnabled(
				emulator.getCheats() != null);
		menu.findItem(R.id.menu_fast_forward).setTitle(
				inFastForward ? R.string.no_fast_forward :
						R.string.fast_forward);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case R.id.menu_settings:
			startActivity(new Intent(this, EmulatorSettings.class));
			return true;

		case R.id.menu_reset:
			try {
				if (netPlayService != null)
					netPlayService.sendResetROM();
				emulator.reset();
			} catch (IOException e) {}
			return true;

		case R.id.menu_fast_forward:
			onFastForward();
			return true;

		case R.id.menu_screenshot:
			onScreenshot();
			return true;

		case R.id.menu_cheats:
			startActivity(new Intent(this, CheatsActivity.class));
			return true;

		case R.id.menu_save_state:
			onSaveState();
			return true;

		case R.id.menu_load_state:
			onLoadState();
			return true;

		case R.id.menu_wifi_server:
			onWifiServer();
			return true;

		case R.id.menu_wifi_client:
			showDialog(DIALOG_WIFI_CONNECT);
			return true;

		case R.id.menu_bluetooth_server:
			if (checkBluetoothEnabled(REQUEST_ENABLE_BT_SERVER))
				onBluetoothServer();
			return true;

		case R.id.menu_bluetooth_client:
			if (checkBluetoothEnabled(REQUEST_ENABLE_BT_CLIENT))
				onBluetoothClient();
			return true;

		case R.id.menu_netplay_disconnect:
			onDisconnect();
			return true;

		case R.id.menu_netplay_sync:
			onNetPlaySync();
			return true;

		case R.id.menu_close:
			finish();
			return true;
		}
		return super.onOptionsItemSelected(item);
	}

	@Override
	protected void onActivityResult(int request, int result, Intent data) {
		switch (request) {
		case REQUEST_LOAD_STATE:
			if (result == RESULT_OK)
				loadState(data.getData().getPath());
			break;

		case REQUEST_SAVE_STATE:
			if (result == RESULT_OK)
				saveState(data.getData().getPath());
			break;

		case REQUEST_ENABLE_BT_SERVER:
			if (result == RESULT_OK)
				onBluetoothServer();
			break;

		case REQUEST_ENABLE_BT_CLIENT:
			if (result == RESULT_OK)
				onBluetoothClient();
			break;

		case REQUEST_BT_DEVICE:
			if (result == RESULT_OK) {
				String address = data.getExtras().
						getString(DeviceListActivity.EXTRA_DEVICE_ADDRESS);
				onBluetoothConnect(address);
			}
			break;
		}
	}

	private static int makeKeyStates(int p1, int p2) {
		return (p2 << 16) | (p1 & 0xffff);
	}

	public int onFrameUpdate(int keys)
			throws IOException, InterruptedException {

		final int remote = netPlayService.sendFrameUpdate(keys);
		if (netPlayService.isServer())
			return makeKeyStates(keys, remote);
		else
			return makeKeyStates(remote, keys);
	}

	public void onSharedPreferenceChanged(SharedPreferences prefs, String key) {
		if (key.startsWith("gamepad")) {
			loadKeyBindings(prefs);

		} else if ("fullScreenMode".equals(key)) {
			WindowManager.LayoutParams attrs = getWindow().getAttributes();
			if (prefs.getBoolean("fullScreenMode", true))
				attrs.flags |= WindowManager.LayoutParams.FLAG_FULLSCREEN;
			else
				attrs.flags &= ~WindowManager.LayoutParams.FLAG_FULLSCREEN;
			getWindow().setAttributes(attrs);

		} else if ("flipScreen".equals(key)) {
			setFlipScreen(prefs, getResources().getConfiguration());

		} else if ("fastForwardSpeed".equals(key)) {
			String value = prefs.getString(key, "2x");
			fastForwardSpeed = Float.parseFloat(
					value.substring(0, value.length() - 1));
			if (inFastForward)
				setGameSpeed(fastForwardSpeed);

		} else if ("frameSkipMode".equals(key)) {
			emulator.setOption(key, prefs.getString(key, "auto"));

		} else if ("maxFrameSkips".equals(key)) {
			emulator.setOption(key, Integer.toString(prefs.getInt(key, 2)));

		} else if ("maxFramesAhead".equals(key)) {
			if (netPlayService != null)
				netPlayService.setMaxFramesAhead(prefs.getInt(key, 0));

		} else if ("autoSyncClient".equals(key) ||
				"autoSyncClientInterval".equals(key)) {

			if (netPlayService != null && netPlayService.isServer()) {
				stopAutoSyncClient();
				if (sharedPrefs.getBoolean("autoSyncClient", false)) {
					autoSyncClientInterval = Integer.valueOf(sharedPrefs.
							getString("autoSyncClientInterval", "30"));
					autoSyncClientInterval *= 1000;
					startAutoSyncClient();
				}
			}
		} else if ("refreshRate".equals(key)) {
			emulator.setOption(key, prefs.getString(key, "default"));

		} else if ("enableLightGun".equals(key)) {
			lightGunEnabled = prefs.getBoolean(key, false);
			emulator.setOption(key, lightGunEnabled);

		} else if ("enableGamepad2".equals(key)) {
			emulator.setOption(key, prefs.getBoolean(key, false));

		} else if ("soundEnabled".equals(key)) {
			emulator.setOption(key, prefs.getBoolean(key, true));

		} else if ("soundVolume".equals(key)) {
			emulator.setOption(key, prefs.getInt(key, 100));

		} else if ("transparencyEnabled".equals(key)) {
			emulator.setOption(key, prefs.getBoolean(key, false));

		} else if ("enableHiRes".equals(key)) {
			emulator.setOption(key, prefs.getBoolean(key, true));

		} else if ("enableTrackball".equals(key)) {
			emulatorView.setOnTrackballListener(
					prefs.getBoolean(key, true) ?  this : null);

		} else if ("trackballSensitivity".equals(key)) {
			trackballSensitivity = prefs.getInt(key, 2) * 5 + 10;

		} else if ("useSensor".equals(key)) {
			sensorMappings = getSensorMappings(prefs.getString(key, null));
			if (sensorMappings == null)
				sensor = null;
			else if (sensor == null) {
				sensor = new SensorKeypad(this);
				sensor.setSensitivity(prefs.getInt("sensorSensitivity", 7));
			}
		} else if ("sensorSensitivity".equals(key)) {
			if (sensor != null)
				sensor.setSensitivity(prefs.getInt(key, 7));

		} else if ("enableVKeypad".equals(key)) {
			if (!prefs.getBoolean(key, true)) {
				if (vkeypad != null) {
					vkeypad.destroy();
					vkeypad = null;
				}
			} else if (vkeypad == null)
				vkeypad = new VirtualKeypad(emulatorView, this);

		} else if ("scalingMode".equals(key)) {
			emulatorView.setScalingMode(getScalingMode(
					prefs.getString(key, "proportional")));

		} else if ("aspectRatio".equals(key)) {
			float ratio = Float.parseFloat(prefs.getString(key, "1.3333"));
			emulatorView.setAspectRatio(ratio);

		} else if ("enableCheats".equals(key)) {
			emulator.enableCheats(prefs.getBoolean(key, true));

		} else if ("orientation".equals(key)) {
			setRequestedOrientation(getScreenOrientation(
					prefs.getString(key, "unspecified")));

		} else if ("useInputMethod".equals(key)) {
			getWindow().setFlags(prefs.getBoolean(key, false) ?
					0 : WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
					WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM);

		} else if ("quickLoad".equals(key)) {
			quickLoadKey = prefs.getInt(key, 0);

		} else if ("quickSave".equals(key)) {
			quickSaveKey = prefs.getInt(key, 0);

		} else if ("fastForward".equals(key)) {
			fastForwardKey = prefs.getInt(key, 0);

		} else if ("screenshot".equals(key)) {
			screenshotKey = prefs.getInt(key, 0);
		}
	}

	public void onGameKeyChanged() {
		int states = keyboard.getKeyStates();

		if (sensor != null) {
			int keys = sensor.getKeyStates();
			if ((keys & SensorKeypad.LEFT) != 0)
				states |= sensorMappings[0];
			if ((keys & SensorKeypad.RIGHT) != 0)
				states |= sensorMappings[1];
			if ((keys & SensorKeypad.UP) != 0)
				states |= sensorMappings[2];
			if ((keys & SensorKeypad.DOWN) != 0)
				states |= sensorMappings[3];
		}
		if (flipScreen)
			states = flipGameKeys(states);

		if (vkeypad != null)
			states |= vkeypad.getKeyStates();

		// resolve conflict keys
		if ((states & GAMEPAD_LEFT_RIGHT) == GAMEPAD_LEFT_RIGHT)
			states &= ~GAMEPAD_LEFT_RIGHT;
		if ((states & GAMEPAD_UP_DOWN) == GAMEPAD_UP_DOWN)
			states &= ~GAMEPAD_UP_DOWN;

		emulator.setKeyStates(states);
	}

	public boolean onTrackball(MotionEvent event) {
		float dx = event.getX();
		float dy = event.getY();
		if (flipScreen) {
			dx = -dx;
			dy = -dy;
		}

		int duration1 = (int) (dx * trackballSensitivity);
		int duration2 = (int) (dy * trackballSensitivity);
		int key1 = 0;
		int key2 = 0;

		if (duration1 < 0)
			key1 = Emulator.GAMEPAD_LEFT;
		else if (duration1 > 0)
			key1 = Emulator.GAMEPAD_RIGHT;

		if (duration2 < 0)
			key2 = Emulator.GAMEPAD_UP;
		else if (duration2 > 0)
			key2 = Emulator.GAMEPAD_DOWN;

		if (key1 == 0 && key2 == 0)
			return false;

		emulator.processTrackball(key1, Math.abs(duration1),
				key2, Math.abs(duration2));
		return true;
	}

	public void surfaceCreated(SurfaceHolder holder) {
		emulator.setSurface(holder);
	}

	public void surfaceDestroyed(SurfaceHolder holder) {
		if (vkeypad != null)
			vkeypad.destroy();

		emulator.setSurface(null);
	}

	public void surfaceChanged(SurfaceHolder holder,
			int format, int width, int height) {

		surfaceWidth = width;
		surfaceHeight = height;

		if (vkeypad != null)
			vkeypad.resize(width, height);

		final int w = emulator.getVideoWidth();
		final int h = emulator.getVideoHeight();
		surfaceRegion.left = (width - w) / 2;
		surfaceRegion.top = (height - h) / 2;
		surfaceRegion.right = surfaceRegion.left + w;
		surfaceRegion.bottom = surfaceRegion.top + h;

		emulator.setSurfaceRegion(
				surfaceRegion.left, surfaceRegion.top, w, h);
	}

	public void onFrameDrawn(Canvas canvas) {
		if (vkeypad != null)
			vkeypad.draw(canvas);
	}

	public boolean onTouch(View v, MotionEvent event) {
		if (vkeypad != null)
			return vkeypad.onTouch(event, flipScreen);

		if (lightGunEnabled &&
				event.getAction() == MotionEvent.ACTION_DOWN) {
			int x = (int) event.getX() *
					surfaceWidth / emulatorView.getWidth();
			int y = (int) event.getY() *
					surfaceHeight / emulatorView.getHeight();
			if (flipScreen) {
				x = surfaceWidth - x;
				y = surfaceHeight - y;
			}
			if (surfaceRegion.contains(x, y)) {
				x -= surfaceRegion.left;
				y -= surfaceRegion.top;
				emulator.fireLightGun(x, y);
				return true;
			}
		}
		return false;
	}

	private void pauseEmulator() {
		emulator.pause();
	}

	private void resumeEmulator() {
		if (hasWindowFocus())
			emulator.resume();
	}

	private boolean checkBluetoothEnabled(int request) {
		if (Wrapper.isBluetoothEnabled())
			return true;

		Intent intent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
		startActivityForResult(intent, request);
		return false;
	}

	private void setFlipScreen(SharedPreferences prefs, Configuration config) {
		if (config.orientation == Configuration.ORIENTATION_LANDSCAPE)
			flipScreen = prefs.getBoolean("flipScreen", false);
		else
			flipScreen = false;

		emulator.setOption("flipScreen", flipScreen);
	}

	private int flipGameKeys(int keys) {
		int newKeys = (keys & ~GAMEPAD_DIRECTION);
		if ((keys & Emulator.GAMEPAD_LEFT) != 0)
			newKeys |= Emulator.GAMEPAD_RIGHT;
		if ((keys & Emulator.GAMEPAD_RIGHT) != 0)
			newKeys |= Emulator.GAMEPAD_LEFT;
		if ((keys & Emulator.GAMEPAD_UP) != 0)
			newKeys |= Emulator.GAMEPAD_DOWN;
		if ((keys & Emulator.GAMEPAD_DOWN) != 0)
			newKeys |= Emulator.GAMEPAD_UP;

		return newKeys;
	}

	private static int getScalingMode(String mode) {
		if (mode.equals("original"))
			return EmulatorView.SCALING_ORIGINAL;
		if (mode.equals("2x"))
			return EmulatorView.SCALING_2X;
		if (mode.equals("proportional"))
			return EmulatorView.SCALING_PROPORTIONAL;
		return EmulatorView.SCALING_STRETCH;
	}

	private static int getScreenOrientation(String orientation) {
		if (orientation.equals("landscape"))
			return ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE;
		if (orientation.equals("portrait"))
			return ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
		return ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED;
	}

	private static final int[] SENSOR_MAP_DPAD = {
		Emulator.GAMEPAD_LEFT,
		Emulator.GAMEPAD_RIGHT,
		Emulator.GAMEPAD_UP,
		Emulator.GAMEPAD_DOWN,
	};

	private static final int[] SENSOR_MAP_TRIGGERS = {
		Emulator.GAMEPAD_TL,
		Emulator.GAMEPAD_TR,
		0,
		0
	};

	private static int[] getSensorMappings(String as) {
		if ("dpad".equals(as))
			return SENSOR_MAP_DPAD;
		if ("triggers".equals(as))
			return SENSOR_MAP_TRIGGERS;
		return null;
	}

	private String getEmulatorEngine(SharedPreferences prefs) {
		return (prefs.getBoolean("useCCore", false) ? "snes_comp" : "snes");
	}

	private void loadKeyBindings(SharedPreferences prefs) {
		final int[] gameKeys = EmulatorSettings.gameKeys;
		final int[] defaultKeys = DefaultPreferences.getKeyMappings(this);
		keyboard.clearKeyMap();

		String[] gameKeysPref = EmulatorSettings.gameKeysPref;
		for (int i = 0; i < gameKeysPref.length; i++) {
			keyboard.mapKey(gameKeys[i],
					prefs.getInt(gameKeysPref[i], defaultKeys[i]));
		}
		gameKeysPref = EmulatorSettings.gameKeysPref2;
		for (int i = 0; i < gameKeysPref.length; i++) {
			keyboard.mapKey(gameKeys[i] << 16,
					prefs.getInt(gameKeysPref[i], 0));
		}
		keyboard.mapKey(Emulator.GAMEPAD_SUPERSCOPE_TURBO,
				prefs.getInt("gamepad_superscope_turbo", 0));
		keyboard.mapKey(Emulator.GAMEPAD_SUPERSCOPE_PAUSE,
				prefs.getInt("gamepad_superscope_pause", 0));
		keyboard.mapKey(Emulator.GAMEPAD_SUPERSCOPE_CURSOR,
				prefs.getInt("gamepad_superscope_cursor", 0));
	}

	private Dialog createQuitGameDialog() {
		DialogInterface.OnClickListener l =
			new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						switch (which) {
						case 1:
							quickSave();
							// fall through
						case 2:
							finish();
							break;
						}
					}
			};

		return new AlertDialog.Builder(this).
				setTitle(R.string.quit_game_title).
				setItems(R.array.exit_game_options, l).
				create();
	}

	private Dialog createReplaceGameDialog() {
		DialogInterface.OnClickListener l =
			new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int which) {
					if (which == DialogInterface.BUTTON_POSITIVE) {
						setIntent(newIntent);
						loadROM();
					}
					newIntent = null;
				}
			};

		return new AlertDialog.Builder(this).
				setCancelable(false).
				setTitle(R.string.replace_game_title).
				setMessage(R.string.replace_game_message).
				setPositiveButton(android.R.string.yes, l).
				setNegativeButton(android.R.string.no, l).
				create();
	}

	private Dialog createWifiConnectDialog() {
		DialogInterface.OnClickListener l =
			new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int which) {
					final Dialog d = (Dialog) dialog;
					String ip = ((TextView) d.findViewById(
							R.id.ip_address)).getText().toString();
					String port = ((TextView) d.findViewById(
								R.id.port)).getText().toString();
					onWifiConnect(ip, port);
				}
			};

		return new AlertDialog.Builder(this).
				setTitle(R.string.wifi_client).
				setView(getLayoutInflater().
						inflate(R.layout.wifi_connect, null)).
				setPositiveButton(android.R.string.ok, l).
				setNegativeButton(android.R.string.cancel, null).
				create();
	}

	private String getROMFilePath() {
		return getIntent().getData().getPath();
	}

	private boolean isROMSupported(String file) {
		file = file.toLowerCase();

		String[] filters = getResources().
				getStringArray(R.array.file_chooser_filters);
		for (String f : filters) {
			if (file.endsWith(f))
				return true;
		}
		return false;
	}

	private boolean loadROM() {
		String path = getROMFilePath();

		if (!isROMSupported(path)) {
			Toast.makeText(this, R.string.rom_not_supported,
					Toast.LENGTH_SHORT).show();
			finish();
			return false;
		}
		if (!emulator.loadROM(path)) {
			Toast.makeText(this, R.string.load_rom_failed,
					Toast.LENGTH_SHORT).show();
			finish();
			return false;
		}
		// reset fast-forward on ROM load
		inFastForward = false;

		emulatorView.setActualSize(
				emulator.getVideoWidth(), emulator.getVideoHeight());

		if (sharedPrefs.getBoolean("quickLoadOnStart", true))
			quickLoad();
		return true;
	}

	private Dialog createNetWaitDialog(
			CharSequence title, CharSequence message) {
		if (waitDialog != null) {
			waitDialog.dismiss();
			waitDialog = null;
		}
		waitDialog = new NetWaitDialog();
		waitDialog.setTitle(title);
		waitDialog.setMessage(message);
		return waitDialog;
	}

	private Handler netPlayHandler = new Handler() {
		@Override
		public void handleMessage(Message msg) {
			if (netPlayService == null)
				return;

			switch (msg.what) {
			case NetPlayService.MESSAGE_CONNECTED:
				applyNetplaySettings();
				if (netPlayService.isServer())
					onNetPlaySync();

				emulator.setFrameUpdateListener(EmulatorActivity.this);
				netPlayService.sendMessageReply();

				if (waitDialog != null) {
					waitDialog.dismiss();
					waitDialog = null;
				}
				break;

			case NetPlayService.MESSAGE_DISCONNECTED:
				onDisconnect();

				if (waitDialog != null) {
					waitDialog.dismiss();
					waitDialog = null;
				}
				int error = R.string.connection_closed;
				switch (msg.arg1) {
				case NetPlayService.E_CONNECT_FAILED:
					error = R.string.connect_failed;
					break;
				case NetPlayService.E_PROTOCOL_INCOMPATIBLE:
					error = R.string.protocol_incompatible;
					break;
				}
				Toast.makeText(EmulatorActivity.this, error,
						Toast.LENGTH_LONG).show();
				break;

			case NetPlayService.MESSAGE_POWER_ROM:
				emulator.power();
				netPlayService.sendMessageReply();
				break;

			case NetPlayService.MESSAGE_RESET_ROM:
				emulator.reset();
				netPlayService.sendMessageReply();
				break;

			case NetPlayService.MESSAGE_SAVED_STATE:
				File file = getTempStateFile();
				try {
					writeFile(file, (byte[]) msg.obj);
					emulator.loadState(file.getAbsolutePath());
				} catch (IOException e) {
				} finally {
					file.delete();
				}
				netPlayService.sendMessageReply();
				break;

			case MESSAGE_SYNC_CLIENT:
				if (hasWindowFocus())
					onNetPlaySync();
				startAutoSyncClient();
				break;
			}
		}
	};

	private void ensureDiscoverable() {
		if (!Wrapper.isBluetoothDiscoverable()) {
			Intent intent = new Intent(
					BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE);
			startActivity(intent);
		}
	}

	private void onWifiServer() {
		WifiManager wifi = (WifiManager) getSystemService(WIFI_SERVICE);
		WifiInfo info = (wifi != null ? wifi.getConnectionInfo() : null);
		int ip = (info != null ? info.getIpAddress() : 0);
		if (ip == 0) {
			Toast.makeText(this, R.string.wifi_not_available,
					Toast.LENGTH_SHORT).show();
			return;
		}

		InetAddress addr = null;
		try {
			addr = InetAddress.getByAddress(new byte[] {
				(byte) ip,
				(byte) (ip >>> 8),
				(byte) (ip >>> 16),
				(byte) (ip >>> 24),
			});
		} catch (UnknownHostException e) {}

		int port = NETPLAY_TCP_PORT;
		try {
			final NetPlayService np = new NetPlayService(netPlayHandler);
			port = np.tcpListen(addr, port);
			netPlayService = np;
		} catch (IOException e) {
			return;
		}

		createNetWaitDialog(getText(R.string.wifi_server),
				getString(R.string.wifi_server_listening,
						addr.getHostAddress(), port)).show();
	}

	private void onWifiConnect(String ip, String portStr) {
		InetAddress addr = null;
		try {
			if (InetAddressUtils.isIPv4Address(ip))
				addr = InetAddress.getByName(ip);
		} catch (UnknownHostException e) {}
		if (addr == null) {
			Toast.makeText(this, R.string.invalid_ip_address,
					Toast.LENGTH_SHORT).show();
			return;
		}

		int port = 0;
		try {
			port = Integer.parseInt(portStr);
		} catch (NumberFormatException e) {}
		if (port <= 0) {
			Toast.makeText(this, R.string.invalid_port,
					Toast.LENGTH_SHORT).show();
			return;
		}
		netPlayService = new NetPlayService(netPlayHandler);
		netPlayService.tcpConnect(addr, port);

		createNetWaitDialog(getText(R.string.wifi_client),
				getString(R.string.client_connecting)).show();
	}

	private void onBluetoothServer() {
		try {
			final NetPlayService np = new NetPlayService(netPlayHandler);
			np.bluetoothListen();
			netPlayService = np;
		} catch (IOException e) {
			return;
		}

		createNetWaitDialog(getText(R.string.bluetooth_server),
				getString(R.string.bluetooth_server_listening));
		waitDialog.setOnClickListener(
			new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int button) {
					ensureDiscoverable();
				}
			});
		waitDialog.show();
	}

	private void onBluetoothConnect(String address) {
		try {
			final NetPlayService np = new NetPlayService(netPlayHandler);
			np.bluetoothConnect(address);
			netPlayService = np;
		} catch (IOException e) {
			return;
		}
		createNetWaitDialog(getText(R.string.bluetooth_client),
				getString(R.string.client_connecting)).show();
	}

	private void onBluetoothClient() {
		Intent intent = new Intent(this, DeviceListActivity.class);
		startActivityForResult(intent, REQUEST_BT_DEVICE);
	}

	private void onNetPlaySync() {
		File file = getTempStateFile();
		try {
			emulator.saveState(file.getAbsolutePath());
			netPlayService.sendSavedState(readFile(file));
		} catch (IOException e) {}
		file.delete();
	}

	private void onDisconnect() {
		if (netPlayService == null)
			return;

		onSharedPreferenceChanged(sharedPrefs, "enableCheats");
		onSharedPreferenceChanged(sharedPrefs, "enableGamepad2");
		stopAutoSyncClient();

		emulator.setFrameUpdateListener(null);
		netPlayService.disconnect();
		netPlayService = null;
	}

	private void onLoadState() {
		Intent intent = new Intent(this, StateSlotsActivity.class);
		intent.setData(getIntent().getData());
		startActivityForResult(intent, REQUEST_LOAD_STATE);
	}

	private void onSaveState() {
		Intent intent = new Intent(this, StateSlotsActivity.class);
		intent.setData(getIntent().getData());
		intent.putExtra(StateSlotsActivity.EXTRA_SAVE_MODE, true);
		startActivityForResult(intent, REQUEST_SAVE_STATE);
	}

	private void applyNetplaySettings() {
		emulator.setOption("enableGamepad2", true);
		emulator.setOption("enableCheats", false);
		onSharedPreferenceChanged(sharedPrefs, "maxFramesAhead");
		onSharedPreferenceChanged(sharedPrefs, "autoSyncClient");

		if (inFastForward) {
			inFastForward = false;
			setGameSpeed(1.0f);
		}
	}

	private void startAutoSyncClient() {
		netPlayHandler.sendMessageDelayed(
				netPlayHandler.obtainMessage(MESSAGE_SYNC_CLIENT),
				autoSyncClientInterval);
	}

	private void stopAutoSyncClient() {
		netPlayHandler.removeMessages(MESSAGE_SYNC_CLIENT);
	}

	private void setGameSpeed(float speed) {
		pauseEmulator();
		emulator.setOption("gameSpeed", Float.toString(speed));
		resumeEmulator();
	}

	private void onFastForward() {
		if (netPlayService != null)
			return;

		inFastForward = !inFastForward;
		setGameSpeed(inFastForward ? fastForwardSpeed : 1.0f);
	}

	private void onScreenshot() {
		File dir = new File("/sdcard/screenshot");
		if (!dir.exists() && !dir.mkdir()) {
			Log.w(LOG_TAG, "Could not create directory for screenshots");
			return;
		}
		String name = Long.toString(System.currentTimeMillis()) + ".png";
		File file = new File(dir, name);

		pauseEmulator();

		FileOutputStream out = null;
		try {
			try {
				out = new FileOutputStream(file);
				Bitmap bitmap = getScreenshot();
				bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
				bitmap.recycle();

				Toast.makeText(this, R.string.screenshot_saved,
						Toast.LENGTH_SHORT).show();

				if (mediaScanner == null)
					mediaScanner = new MediaScanner(this);
				mediaScanner.scanFile(file.getAbsolutePath(), "image/png");

			} finally {
				if (out != null)
					out.close();
			}
		} catch (IOException e) {}

		resumeEmulator();
	}

	private File getTempStateFile() {
		return new File(getCacheDir(), "saved_state");
	}

	private static byte[] readFile(File file)
			throws IOException {
		FileInputStream in = new FileInputStream(file);
		byte[] buffer = new byte[(int) file.length()];
		try {
			if (in.read(buffer) == -1)
				throw new IOException();
		} finally {
			in.close();
		}
		return buffer;
	}

	private static void writeFile(File file, byte[] buffer)
			throws IOException {
		FileOutputStream out = new FileOutputStream(file);
		try {
			out.write(buffer);
		} finally {
			out.close();
		}
	}

	private void saveState(String fileName) {
		pauseEmulator();

		ZipOutputStream out = null;
		try {
			try {
				out = new ZipOutputStream(new BufferedOutputStream(
						new FileOutputStream(fileName)));
				out.putNextEntry(new ZipEntry("screenshot.png"));

				Bitmap bitmap = getScreenshot();
				bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
				bitmap.recycle();
			} finally {
				if (out != null)
					out.close();
			}
		} catch (Exception e) {}

		emulator.saveState(fileName);
		resumeEmulator();
	}

	private void loadState(String fileName) {
		File file = new File(fileName);
		if (!file.exists())
			return;

		pauseEmulator();
		try {
			if (netPlayService != null)
				netPlayService.sendSavedState(readFile(file));
			emulator.loadState(fileName);

		} catch (IOException e) {}
		resumeEmulator();
	}

	private Bitmap getScreenshot() {
		final int w = emulator.getVideoWidth();
		final int h = emulator.getVideoHeight();

		ByteBuffer buffer = ByteBuffer.allocateDirect(w * h * 2);
		emulator.getScreenshot(buffer);

		Bitmap bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565);
		bitmap.copyPixelsFromBuffer(buffer);
		return bitmap;
	}

	private String getQuickSlotFileName() {
		return StateSlotsActivity.getSlotFileName(getROMFilePath(), 0);
	}

	private void quickSave() {
		saveState(getQuickSlotFileName());
	}

	private void quickLoad() {
		loadState(getQuickSlotFileName());
	}

	private class NetWaitDialog extends ProgressDialog implements
			DialogInterface.OnCancelListener {

		private OnClickListener onClickListener;

		public NetWaitDialog() {
			super(EmulatorActivity.this);

			setIndeterminate(true);
			setCancelable(true);
			setOnCancelListener(this);
		}

		public void setOnClickListener(OnClickListener l) {
			onClickListener = l;
		}

		@Override
		public boolean dispatchTouchEvent(MotionEvent event) {
			if (onClickListener != null &&
					event.getAction() == MotionEvent.ACTION_UP) {
				onClickListener.onClick(this, BUTTON_POSITIVE);
				return true;
			}
			return super.dispatchTouchEvent(event);
		}

		public void onCancel(DialogInterface dialog) {
			waitDialog = null;
			netPlayService.disconnect();
			netPlayService = null;
		}
	}
}
