package com.androidemu.snes;

import android.app.ListActivity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.Toast;
import java.io.File;
import java.io.FileFilter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class FileChooser extends ListActivity implements
		FileFilter, View.OnClickListener, View.OnKeyListener {

	public static final String EXTRA_TITLE = "title";
	public static final String EXTRA_FILTERS = "filters";

	private static final String LOG_TAG = "FileChooser";
	private final File sdcardDir = new File("/sdcard");
	private File currentDir;
	private String[] filters;
	private EditText pathEdit;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		setContentView(R.layout.file_chooser);
		getListView().setEmptyView(findViewById(R.id.empty));

		pathEdit = (EditText) findViewById(R.id.path);
		pathEdit.setOnKeyListener(this);
		findViewById(R.id.goto_sdcard).setOnClickListener(this);
		findViewById(R.id.goto_parent).setOnClickListener(this);

		String title = getIntent().getStringExtra(EXTRA_TITLE);
		if (title != null)
			setTitle(title);
		filters = getFileFilter();

		String path = null;
		if (savedInstanceState != null)
			path = savedInstanceState.getString("currentDir");
		else
			path = getInitialPath();

		File dir = null;
		if (path != null)
			dir = getDirectoryFromFile(path);
		if (dir == null)
			dir = sdcardDir;
		changeTo(dir);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);

		getMenuInflater().inflate(R.menu.file_chooser, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case R.id.menu_refresh:
			changeTo(currentDir);
			return true;
		}
		return super.onOptionsItemSelected(item);
	}
	
	@Override
	protected void onSaveInstanceState(Bundle outState) {
		super.onSaveInstanceState(outState);

		if (currentDir != null)
			outState.putString("currentDir", currentDir.getAbsolutePath());
	}

	@Override
	protected void onListItemClick(ListView l, View v, int position, long id) {
		String name = l.getItemAtPosition(position).toString();
		File f = new File(currentDir, name);
		if (f.isDirectory())
			changeTo(f);
		else
			onFileSelected(Uri.fromFile(f));
	}

	protected String[] getFileFilter() {
		return getIntent().getStringArrayExtra(EXTRA_FILTERS);
	}

	protected String getInitialPath() {
		Uri uri = getIntent().getData();
		if (uri == null)
			return null;
		return uri.getPath();
	}

	protected void onFileSelected(Uri uri) {
		setResult(RESULT_OK, new Intent().setData(uri));
		finish();
	}

	public boolean onKey(View v, int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_ENTER) {
			String name = pathEdit.getText().toString().trim();
			if (name.length() > 0) {
				File dir = new File(name);
				if (dir.isDirectory())
					changeTo(dir);
				else {
					Toast.makeText(this, R.string.invalid_dir,
							Toast.LENGTH_SHORT).show();
				}
				return true;
			}
		}
		return false;
	}

	public void onClick(View v) {
		switch (v.getId()) {
		case R.id.goto_sdcard:
			changeTo(sdcardDir);
			break;
		case R.id.goto_parent:
			File parent = currentDir.getParentFile();
			if (parent != null)
				changeTo(parent);
			break;
		}
	}

	public boolean accept(File file) {
		String name = file.getName();

		// Do not show hidden files
		if (name.startsWith("."))
			return false;

		// Always show directory
		if (file.isDirectory())
			return true;

		name = name.toLowerCase();
		for (String f : filters) {
			if (name.endsWith(f))
				return true;
		}
		return false;
	}

	private File getDirectoryFromFile(String path) {
		File dir = new File(path);
		if (!dir.isDirectory()) {
			dir = dir.getParentFile();
			if (dir != null && !dir.isDirectory())
				dir = null;
		}
		return dir;
	}

	private void changeTo(File dir) {
		File[] files = dir.listFiles(filters == null ? null : this);
		if (files == null)
			files = new File[0];

		currentDir = dir;
		pathEdit.setText(dir.getAbsolutePath());

		List<String> items = new ArrayList<String>(files.length);
		for (File f : files) {
			String name = f.getName();
			if (f.isDirectory())
				name += '/';
			items.add(name);
		}

		Collections.sort(items, String.CASE_INSENSITIVE_ORDER);
		setListAdapter(new ArrayAdapter(this,
				android.R.layout.simple_list_item_1, items));
	}
}
