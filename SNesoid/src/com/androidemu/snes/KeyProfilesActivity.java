package com.androidemu.snes;

import android.app.AlertDialog;
import android.app.Dialog;
import android.app.ListActivity;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Xml;
import android.view.ContextMenu;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.Map;
import java.util.HashMap;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlSerializer;

public class KeyProfilesActivity extends ListActivity {

	public static final String EXTRA_TITLE = "title";

	private static final int DIALOG_EDIT_PROFILE = 1;
	private static final int MENU_ITEM_EDIT = Menu.FIRST;
	private static final int MENU_ITEM_DELETE = Menu.FIRST + 1;

	private static final String XML_ENCODING = "UTF-8";
	private static String currentProfile;
	private boolean isSaveMode;

	private static File getKeyProfilesDir(Context context) {
		return context.getDir("key-profiles", Context.MODE_PRIVATE);
	}

	private static String getProfileName(String file) {
		int dot = file.lastIndexOf('.');
		if (dot >= 0)
			file = file.substring(0, dot);
		return Uri.decode(file);
	}

	private static File getProfileFile(Context context, String name) {
		name = Uri.encode(name) + ".xml";
		return new File(getKeyProfilesDir(context), name);
	}

	public static Map<String, Integer>
			loadProfile(Context context, String name) {

		HashMap<String, Integer> mappings = new HashMap<String, Integer>();
		try {
			BufferedInputStream in = null;
			try {
				in = new BufferedInputStream(
						new FileInputStream(getProfileFile(context, name)));

				XmlPullParser parser = Xml.newPullParser();
				parser.setInput(in, XML_ENCODING);

				int event = parser.getEventType();
				while (event != XmlPullParser.END_DOCUMENT) {
					if (event == XmlPullParser.START_TAG &&
							parser.getName().equals("key")) {
						String keyName = parser.getAttributeValue(null, "name");
						try {
							mappings.put(keyName,
									new Integer(parser.nextText()));
						} catch (NumberFormatException e) {}
					}
					event = parser.next();
				}
			} finally {
				if (in != null)
					in.close();
			}
		} catch (Exception e) {} 

		return mappings;
	}

	public static void saveProfile(Context context, String name,
			Map<String, Integer> mappings) {
		try {
			BufferedOutputStream out = null;
			try {
				out = new BufferedOutputStream(
						new FileOutputStream(getProfileFile(context, name)));

				XmlSerializer serializer = Xml.newSerializer();
				serializer.setOutput(out, XML_ENCODING);
				serializer.startDocument(null, null);
				serializer.startTag(null, "key-profile");

				Iterator it = mappings.entrySet().iterator();
				while (it.hasNext()) {
					Map.Entry<String, Integer> pairs =
							(Map.Entry<String, Integer>) it.next();

					serializer.startTag(null, "key");
					serializer.attribute(null, "name", pairs.getKey());
					serializer.text(pairs.getValue().toString());
					serializer.endTag(null, "key");
				}
				serializer.endTag(null, "key-profile");
				serializer.endDocument();

			} finally {
				if (out != null)
					out.close();
			}
		} catch (Exception e) {
		}
	}

	private void refresh() {
		File dir = getKeyProfilesDir(this);
		String[] files = dir.list(new FilenameFilter() {
			public boolean accept(File dir, String filename) {
				return filename.endsWith(".xml");
			}
		});
		if (files == null)
			files = new String[0];

		ArrayList<String> items = new ArrayList<String>(files.length);
		for (String f : files)
			items.add(getProfileName(f));

		Collections.sort(items, String.CASE_INSENSITIVE_ORDER);
		setListAdapter(new ArrayAdapter(this,
				android.R.layout.simple_list_item_1, items));
	}

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		setTitle(getIntent().getStringExtra(EXTRA_TITLE));

		getListView().setOnCreateContextMenuListener(this);
		refresh();
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);

		getMenuInflater().inflate(R.menu.key_profiles, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case R.id.menu_new_profile:
			currentProfile = null;
			showDialog(DIALOG_EDIT_PROFILE);
			return true;
		}
		return super.onOptionsItemSelected(item);
	}

	@Override
	public void onCreateContextMenu(ContextMenu menu, View v,
			ContextMenu.ContextMenuInfo menuInfo) {

		menu.add(0, MENU_ITEM_EDIT, 0, R.string.menu_edit);
		menu.add(0, MENU_ITEM_DELETE, 0, R.string.menu_delete);
	}

	@Override
	public boolean onContextItemSelected(MenuItem item) {
		AdapterView.AdapterContextMenuInfo info =
				(AdapterView.AdapterContextMenuInfo) item.getMenuInfo();

		switch (item.getItemId()) {
		case MENU_ITEM_EDIT:
			currentProfile = (String) getListAdapter().getItem(info.position);
			showDialog(DIALOG_EDIT_PROFILE);
			return true;

		case MENU_ITEM_DELETE:
			String name = (String) getListAdapter().getItem(info.position);
			if (getProfileFile(this, name).delete())
				refresh();
			return true;
		}
		return super.onContextItemSelected(item);
	}

	@Override
	protected void onPrepareDialog(int id, Dialog dialog) {
		switch (id) {
		case DIALOG_EDIT_PROFILE:
			TextView nameView = (TextView)
					dialog.findViewById(R.id.profile_name);
			nameView.setText(currentProfile);
			break;
		}
	}

	@Override
	protected void onListItemClick(ListView l, View v, int position, long id) {
		String name = l.getItemAtPosition(position).toString();
		setResult(RESULT_OK, new Intent(name));
		finish();
	}

	private boolean createOrRenameProfile(String oldName, String newName) {
		if (newName.length() == 0)
			return false;

		File newFile = getProfileFile(this, newName);
		try {
			if (oldName == null)
				return newFile.createNewFile();

			if (oldName.equals(newName))
				return true;

			File oldFile = getProfileFile(this, oldName);
			return oldFile.renameTo(newFile);

		} catch (IOException e) {}

		return false;
	}

	@Override
	protected Dialog onCreateDialog(int id) {
		switch (id) {
		case DIALOG_EDIT_PROFILE:
			DialogInterface.OnClickListener l =
				new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						String oldName = currentProfile;
						currentProfile = null;

						final Dialog d = (Dialog) dialog;
						String newName = ((TextView) d.findViewById(
								R.id.profile_name)).getText().
										toString().trim();

						if (createOrRenameProfile(oldName, newName))
							refresh();
						else {
							Toast.makeText(KeyProfilesActivity.this,
									R.string.new_profile_error,
									Toast.LENGTH_SHORT).show();
						}
					}
				};
			return new AlertDialog.Builder(this).
					setTitle(R.string.new_profile_title).
					setView(getLayoutInflater().
							inflate(R.layout.new_profile, null)).
					setPositiveButton(android.R.string.ok, l).
					setNegativeButton(android.R.string.cancel, null).
					create();
		}
		return super.onCreateDialog(id);
	}
}
