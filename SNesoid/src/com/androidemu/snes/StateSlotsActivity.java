package com.androidemu.snes;

import android.app.ListActivity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.text.format.DateFormat;
import android.view.ContextMenu;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.TextView;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public class StateSlotsActivity extends ListActivity {

	public static final String EXTRA_SAVE_MODE = "saveMode";

	private static final int MENU_ITEM_DELETE = Menu.FIRST;

	private LayoutInflater inflater;
	private SaveSlotAdapter adapter;
	private boolean isSaveMode;

	public static String getSlotFileName(String fileName, int slot) {
		int len = fileName.lastIndexOf('.');
		if (len < 0)
			len = fileName.length();

		return new StringBuffer(len + 4).
				append(fileName, 0, len).
				append(".ss").append(slot).toString();
	}

	private static Bitmap getScreenshot(File file) {
		ZipInputStream in = null;
		try {
			try {
				in = new ZipInputStream(new BufferedInputStream(
						new FileInputStream(file)));
				ZipEntry entry;
				while ((entry = in.getNextEntry()) != null) {
					if (entry.getName().equals("screenshot.png"))
						break;
				}
				if (entry != null)
					return BitmapFactory.decodeStream(in);

			} finally {
				if (in != null)
					in.close();
			}
		} catch (Exception e) {}

		return null;
	}

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		inflater = (LayoutInflater)
				getSystemService(Context.LAYOUT_INFLATER_SERVICE);

		final Intent intent = getIntent();
		isSaveMode = intent.getBooleanExtra(EXTRA_SAVE_MODE, false);
		setTitle(isSaveMode ?
				R.string.save_state_title : R.string.load_state_title);

		getListView().setOnCreateContextMenuListener(this);

		adapter = new SaveSlotAdapter(intent.getData().getPath());
		setListAdapter(adapter);
	}

	@Override
	public void onCreateContextMenu(ContextMenu menu, View v,
			ContextMenu.ContextMenuInfo menuInfo) {
		AdapterView.AdapterContextMenuInfo info =
				(AdapterView.AdapterContextMenuInfo) menuInfo;

		menu.setHeaderTitle(getSlotName(info.position));

		File file = (File) getListView().getItemAtPosition(info.position);
		if (file.exists())
			menu.add(0, MENU_ITEM_DELETE, 0, R.string.menu_delete);
	}

	@Override
	public boolean onContextItemSelected(MenuItem item) {
		AdapterView.AdapterContextMenuInfo info =
				(AdapterView.AdapterContextMenuInfo) item.getMenuInfo();

		switch (item.getItemId()) {
		case MENU_ITEM_DELETE:
			adapter.delete(info.position);
			return true;
		}
		return super.onContextItemSelected(item);
	}

	@Override
	protected void onListItemClick(ListView l, View v, int position, long id) {
		File file = (File) l.getItemAtPosition(position);
		if (!isSaveMode && !file.exists())
			return;

		Intent intent = new Intent();
		intent.setData(Uri.fromFile(file));
		setResult(RESULT_OK, intent);
		finish();
	}

	private String getSlotName(int slot) {
		if (slot == 0)
			return getString(R.string.slot_quick);
		else
			return getString(R.string.slot_nth, slot);
	}

	private class SaveSlotAdapter extends BaseAdapter {
		private File[] files = new File[10];

		public SaveSlotAdapter(String path) {
			for (int i = 0; i < files.length; i++)
				files[i] = new File(getSlotFileName(path, i));
		}

		public void delete(int position) {
			File file = (File) getItem(position);
			if (file.delete())
				notifyDataSetChanged();
		}

		public int getCount() {
			return files.length;
		}

		public long getItemId(int position) {
			return position;
		}

		public Object getItem(int position) {
			return files[position];
		}

		public View getView(int position, View convertView, ViewGroup parent) {
			if (convertView == null)
				convertView = inflater.inflate(R.layout.state_slot_item, null);

			TextView nameView = (TextView) convertView.findViewById(R.id.name);
			nameView.setText(getSlotName(position));

			TextView detailView = (TextView)
					convertView.findViewById(R.id.detail);
			ImageView imageView = (ImageView)
					convertView.findViewById(R.id.screenshot);

			File file = (File) getItem(position);
			if (file.exists()) {
				detailView.setText(DateFormat.format(
						"yyyy-MM-dd hh:mm:ss", file.lastModified()));
				imageView.setImageBitmap(getScreenshot(file));
			} else {
				detailView.setText(getString(R.string.slot_empty));
				imageView.setImageBitmap(null);
			}
			return convertView;
		}
	}
}
