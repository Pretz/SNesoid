package com.androidemu.snes;

import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.preference.CheckBoxPreference;
import android.preference.Preference;
import android.preference.PreferenceActivity;
import android.preference.PreferenceGroup;
import android.preference.PreferenceManager;
import android.preference.PreferenceScreen;
import android.widget.Toast;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.Map;
import java.util.TreeMap;

import com.androidemu.Emulator;
import com.androidemu.snes.wrapper.Wrapper;

public class EmulatorSettings extends PreferenceActivity
		implements Preference.OnPreferenceChangeListener {

	private static final String SEARCH_ROM_URI =
			"http://www.romfind.com/snes-roms.html?sid=YONG";
	private static final Uri ABOUT_URI = Uri.parse(
			"file:///android_asset/about.html");
	private static final String MARKET_URI = "market://details?id=";
	private static final String GAME_GRIPPER_URI = 
			"https://sites.google.com/site/gamegripper";

	private static final int REQUEST_LOAD_KEY_PROFILE = 1;
	private static final int REQUEST_SAVE_KEY_PROFILE = 2;

	public static final int[] gameKeys = {
		Emulator.GAMEPAD_UP,
		Emulator.GAMEPAD_DOWN,
		Emulator.GAMEPAD_LEFT,
		Emulator.GAMEPAD_RIGHT,
		Emulator.GAMEPAD_UP_LEFT,
		Emulator.GAMEPAD_UP_RIGHT,
		Emulator.GAMEPAD_DOWN_LEFT,
		Emulator.GAMEPAD_DOWN_RIGHT,
		Emulator.GAMEPAD_SELECT,
		Emulator.GAMEPAD_START,
		Emulator.GAMEPAD_A,
		Emulator.GAMEPAD_B,
		Emulator.GAMEPAD_X,
		Emulator.GAMEPAD_Y,
		Emulator.GAMEPAD_TL,
		Emulator.GAMEPAD_TR,
	};

	public static final String[] gameKeysPref = {
		"gamepad_up",
		"gamepad_down",
		"gamepad_left",
		"gamepad_right",
		"gamepad_up_left",
		"gamepad_up_right",
		"gamepad_down_left",
		"gamepad_down_right",
		"gamepad_select",
		"gamepad_start",
		"gamepad_A",
		"gamepad_B",
		"gamepad_X",
		"gamepad_Y",
		"gamepad_TL",
		"gamepad_TR",
	};

	public static final String[] gameKeysPref2 = {
		"gamepad2_up",
		"gamepad2_down",
		"gamepad2_left",
		"gamepad2_right",
		"gamepad2_up_left",
		"gamepad2_up_right",
		"gamepad2_down_left",
		"gamepad2_down_right",
		"gamepad2_select",
		"gamepad2_start",
		"gamepad2_A",
		"gamepad2_B",
		"gamepad2_X",
		"gamepad2_Y",
		"gamepad2_TL",
		"gamepad2_TR",
	};

	private static final int[] gameKeysName = {
		R.string.gamepad_up,
		R.string.gamepad_down,
		R.string.gamepad_left,
		R.string.gamepad_right,
		R.string.gamepad_up_left,
		R.string.gamepad_up_right,
		R.string.gamepad_down_left,
		R.string.gamepad_down_right,
		R.string.gamepad_select,
		R.string.gamepad_start,
		R.string.gamepad_A,
		R.string.gamepad_B,
		R.string.gamepad_X,
		R.string.gamepad_Y,
		R.string.gamepad_TL,
		R.string.gamepad_TR,
	};

	static {
		final int n = gameKeys.length;
		if (gameKeysPref.length != n ||
				gameKeysPref2.length != n ||
				gameKeysName.length != n)
			throw new AssertionError("Key configurations are not consistent");
	}

	public static Intent getSearchROMIntent() {
		return new Intent(Intent.ACTION_VIEW, Uri.parse(SEARCH_ROM_URI)).
				setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
	}

	// FIXME
	private static ArrayList<String> getAllKeyPrefs() {
		ArrayList<String> result = new ArrayList<String>();
		result.addAll(Arrays.asList(gameKeysPref));
		result.addAll(Arrays.asList(gameKeysPref2));
		result.add("gamepad_superscope_turbo");
		result.add("gamepad_superscope_pause");
		result.add("gamepad_superscope_cursor");
		return result;
	}

	private SharedPreferences settings;

	private Map<String, Integer> getKeyMappings() {
		TreeMap mappings = new TreeMap<String, Integer>();

		for (String key : getAllKeyPrefs()) {
			KeyPreference pref = (KeyPreference) findPreference(key);
			mappings.put(key, new Integer(pref.getKeyValue()));
		}
		return mappings;
	}

	private void setKeyMappings(Map<String, Integer> mappings) {
		SharedPreferences.Editor editor = settings.edit();

		for (String key : getAllKeyPrefs()) {
			Integer value = mappings.get(key);
			if (value != null) {
				KeyPreference pref = (KeyPreference) findPreference(key);
				pref.setKey(value.intValue());
				editor.putInt(key, value.intValue());
			}
		}
		editor.commit();
	}

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		setTitle(R.string.settings);
		addPreferencesFromResource(R.xml.preferences);

		settings = PreferenceManager.getDefaultSharedPreferences(this);

		final int[] defaultKeys = DefaultPreferences.getKeyMappings(this);

		// gamepad 1
		PreferenceGroup group = (PreferenceGroup) findPreference("gamepad1");
		for (int i = 0; i < gameKeysPref.length; i++) {
			KeyPreference pref = new KeyPreference(this);
			pref.setKey(gameKeysPref[i]);
			pref.setTitle(gameKeysName[i]);
			pref.setDefaultValue(defaultKeys[i]);
			group.addPreference(pref);
		}
		//  gamepad 2
		group = (PreferenceGroup) findPreference("gamepad2");
		for (int i = 0; i < gameKeysPref2.length; i++) {
			KeyPreference pref = new KeyPreference(this);
			pref.setKey(gameKeysPref2[i]);
			pref.setTitle(gameKeysName[i]);
			group.addPreference(pref);
		}
		// super scope
		group = (PreferenceGroup) findPreference("superScope");
		KeyPreference pref = new KeyPreference(this);
		pref.setKey("gamepad_superscope_turbo");
		pref.setTitle(R.string.gamepad_superscope_turbo);
		group.addPreference(pref);

		pref = new KeyPreference(this);
		pref.setKey("gamepad_superscope_pause");
		pref.setTitle(R.string.gamepad_superscope_pause);
		group.addPreference(pref);

		pref = new KeyPreference(this);
		pref.setKey("gamepad_superscope_cursor");
		pref.setTitle(R.string.gamepad_superscope_cursor);
		group.addPreference(pref);

		if (!Wrapper.supportsMultitouch(this)) {
			findPreference("enableVKeypad").
					setSummary(R.string.multitouch_unsupported);
		}

		findPreference("apuEnabled").setOnPreferenceChangeListener(this);
		findPreference("enableLightGun").setOnPreferenceChangeListener(this);
		findPreference("useCCore").setOnPreferenceChangeListener(this);

		findPreference("about").setIntent(new Intent(
				this, HelpActivity.class).setData(ABOUT_URI));
		findPreference("upgrade").setIntent(new Intent(
				Intent.ACTION_VIEW, Uri.parse(MARKET_URI + getPackageName())));
		findPreference("searchRoms").setIntent(getSearchROMIntent());

		findPreference("gameGripper").setIntent(new Intent(
				Intent.ACTION_VIEW, Uri.parse(GAME_GRIPPER_URI)));
	}

	@Override
	protected void onActivityResult(int request, int result, Intent data) {
		switch (request) {
		case REQUEST_LOAD_KEY_PROFILE:
			if (result == RESULT_OK) {
				setKeyMappings(KeyProfilesActivity.
						loadProfile(this, data.getAction()));
			}
			break;

		case REQUEST_SAVE_KEY_PROFILE:
			if (result == RESULT_OK) {
				KeyProfilesActivity.saveProfile(this, data.getAction(),
						getKeyMappings());
			}
			break;
		}
	}

	@Override
	public boolean onPreferenceTreeClick(PreferenceScreen preferenceScreen,
			Preference preference) {
		String key = preference.getKey();

		if ("loadKeyProfile".equals(key)) {
			Intent intent = new Intent(this, KeyProfilesActivity.class);
			intent.putExtra(KeyProfilesActivity.EXTRA_TITLE,
					getString(R.string.load_profile));
			startActivityForResult(intent, REQUEST_LOAD_KEY_PROFILE);
			return true;
		}
		if ("saveKeyProfile".equals(key)) {
			Intent intent = new Intent(this, KeyProfilesActivity.class);
			intent.putExtra(KeyProfilesActivity.EXTRA_TITLE,
					getString(R.string.save_profile));
			startActivityForResult(intent, REQUEST_SAVE_KEY_PROFILE);
			return true;
		}
		return super.onPreferenceTreeClick(preferenceScreen, preference);
	}

	public boolean onPreferenceChange(Preference preference, Object newValue) {
		Toast.makeText(this, R.string.game_reset_needed_prompt,
				Toast.LENGTH_SHORT).show();
		return true;
	}
}
