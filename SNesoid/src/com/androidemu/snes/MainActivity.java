package com.androidemu.snes;

import android.app.AlertDialog;
import android.app.Dialog;
import android.content.ActivityNotFoundException;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Parcelable;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.EditText;
import java.io.File;

public class MainActivity extends FileChooser {

	private static final Uri HELP_URI = Uri.parse(
			"file:///android_asset/faq.html");

	private static final String ROM_BUDDY_PACKAGE = "com.momojo.rombud";
	private static final Uri ROM_BUDDY_URI = Uri.parse(
			"market://details?id=" + ROM_BUDDY_PACKAGE);

	private static final int DIALOG_SHORTCUT = 1;

	private static Intent emulatorIntent;
	private SharedPreferences settings;
	private boolean creatingShortcut;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		settings = getSharedPreferences("MainActivity", MODE_PRIVATE);

		super.onCreate(savedInstanceState);
		setVolumeControlStream(AudioManager.STREAM_MUSIC);
		setTitle(R.string.title_select_rom);

		creatingShortcut = getIntent().getAction().equals(
				Intent.ACTION_CREATE_SHORTCUT);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);

		if (!creatingShortcut)
			getMenuInflater().inflate(R.menu.main, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case R.id.menu_rom_buddy:
			Intent intent = getPackageManager().
					getLaunchIntentForPackage(ROM_BUDDY_PACKAGE);
			if (intent == null)
				intent = new Intent(Intent.ACTION_VIEW, ROM_BUDDY_URI);
			else
				intent.putExtra("com.momojo.rombud.system", 2);

			try {
				startActivity(intent);
			} catch (ActivityNotFoundException e) {}
			return true;

		case R.id.menu_search_roms:
			startActivity(EmulatorSettings.getSearchROMIntent());
			return true;

		case R.id.menu_help:
			startActivity(new Intent(this, HelpActivity.class).
					setData(HELP_URI));
			return true;

		case R.id.menu_settings:
			startActivity(new Intent(this, EmulatorSettings.class));
			return true;
		}
		return super.onOptionsItemSelected(item);
	}

	@Override
	protected Dialog onCreateDialog(int id) {
		switch (id) {
		case DIALOG_SHORTCUT:
			return createShortcutNameDialog();
		}
		return super.onCreateDialog(id);
	}

	@Override
	protected void onPrepareDialog(int id, Dialog dialog) {
		switch (id) {
		case DIALOG_SHORTCUT:
			String name = emulatorIntent.getData().getPath();
			name = new File(name).getName();
			int dot = name.lastIndexOf('.');
			if (dot > 0)
				name = name.substring(0, dot);

			EditText v = ((EditText) dialog.findViewById(R.id.name));
			v.setText(name);
			v.selectAll();
			break;
		}
	}

	@Override
	protected String getInitialPath() {
		return settings.getString("lastGame", null);
	}

	@Override
	protected String[] getFileFilter() {
		return getResources().getStringArray(R.array.file_chooser_filters);
	}

	@Override
	protected void onFileSelected(Uri uri) {
		// remember the last file
		settings.edit().
				putString("lastGame", uri.getPath()).commit();

		Intent intent = new Intent(Intent.ACTION_VIEW, uri,
				this, EmulatorActivity.class);
		if (!creatingShortcut)
			startActivity(intent);
		else {
			emulatorIntent = intent;
			showDialog(DIALOG_SHORTCUT);
		}
	}

	private Dialog createShortcutNameDialog() {
		DialogInterface.OnClickListener l =
			new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int which) {
					final Dialog d = (Dialog) dialog;
					String name = ((EditText) d.findViewById(R.id.name)).
							getText().toString();

					Intent intent = new Intent();
					intent.putExtra(Intent.EXTRA_SHORTCUT_INTENT,
							emulatorIntent);
					intent.putExtra(Intent.EXTRA_SHORTCUT_NAME, name);
					Parcelable icon = Intent.ShortcutIconResource.fromContext(
							MainActivity.this, R.drawable.app_icon);
					intent.putExtra(Intent.EXTRA_SHORTCUT_ICON_RESOURCE, icon);

					setResult(RESULT_OK, intent);
					finish();
				}
			};

		return new AlertDialog.Builder(this).
				setTitle(R.string.shortcut_name).
				setView(getLayoutInflater().inflate(R.layout.shortcut, null)).
				setPositiveButton(android.R.string.ok, l).
				setNegativeButton(android.R.string.cancel, null).
				create();
	}
}
