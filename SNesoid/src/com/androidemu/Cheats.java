package com.androidemu;

import android.util.Xml;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.List;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlSerializer;

public class Cheats {

	public class Item {
		public boolean enabled;
		public String code;
		public String name;

		public String toString() {
			if (name == null)
				return code;
			return name + "\n" + code;
		}
	}

	public native boolean nativeAdd(String code);
	public native void nativeRemove(String code);

	private static final String XML_ENCODING = "UTF-8";
	private File file;
	private ArrayList<Item> items = new ArrayList<Item>();
	private boolean modified;

	public Cheats(String romFile) {
		String path = romFile;
		int dot = path.lastIndexOf('.');
		if (dot >= 0)
			path = path.substring(0, dot);
		path += ".cht";

		file = new File(path);
		load();
	}

	public final List<Item> getAll() {
		return items;
	}

	public void setModified() {
		modified = true;
	}

	public Item add(String code, String name) {
		Item c = add(code, name, true);
		if (c != null)
			modified = true;
		return c;
	}

	private Item add(String code, String name, boolean enabled) {
		if (code == null || code.length() == 0)
			return null;

		if (enabled && !nativeAdd(code))
			return null;

		// normalize
		if ("".equals(name))
			name = null;

		Item c = new Item();
		c.enabled = enabled;
		c.code = code;
		c.name = name;
		items.add(c);
		return c;
	}

	public void remove(int i) {
		Item c = items.get(i);
		if (c.enabled)
			nativeRemove(c.code);
		items.remove(i);

		modified = true;
	}

	public void enable(int i, boolean enabled) {
		Item c = items.get(i);
		if (c.enabled == enabled)
			return;

		c.enabled = enabled;
		if (enabled)
			nativeAdd(c.code);
		else
			nativeRemove(c.code);

		modified = true;
	}

	private void load() {
		try {
			BufferedInputStream in = null;
			try {
				in = new BufferedInputStream(new FileInputStream(file));

				XmlPullParser parser = Xml.newPullParser();
				parser.setInput(in, XML_ENCODING);

				int event = parser.getEventType();
				while (event != XmlPullParser.END_DOCUMENT) {
					if (event == XmlPullParser.START_TAG &&
							parser.getName().equals("item")) {
						String code = parser.getAttributeValue(null, "code");
						String name = parser.getAttributeValue(null, "name");
						boolean enabled = !"true".equals(
								parser.getAttributeValue(null, "disabled"));
						add(code, name, enabled);
					}
					event = parser.next();
				}
			} finally {
				if (in != null)
					in.close();
			}
		} catch (FileNotFoundException fne) {
			// don't report error if file simply doesn't exist
		} catch (Exception e) {
			e.printStackTrace();
		} 

		modified = false;
	}

	public void save() {
		if (!modified)
			return;

		// delete file if no cheats
		if (items.size() == 0 && file.delete())
			return;

		try {
			BufferedOutputStream out = null;
			try {
				out = new BufferedOutputStream(new FileOutputStream(file));

				XmlSerializer serializer = Xml.newSerializer();
				serializer.setOutput(out, XML_ENCODING);
				serializer.startDocument(null, null);
				serializer.startTag(null, "cheats");
				for (Item c : items) {
					serializer.startTag(null, "item");

					if (!c.enabled)
						serializer.attribute(null, "disabled", "true");
					serializer.attribute(null, "code", c.code);
					if (c.name != null)
						serializer.attribute(null, "name", c.name);

					serializer.endTag(null, "item");
				}
				serializer.endTag(null, "cheats");
				serializer.endDocument();

			} finally {
				if (out != null)
					out.close();
			}
		} catch (Exception e) {
		}

		modified = false;
	}

	public void destroy() {
		save();

		for (int i = items.size(); --i >= 0; ) {
			Item c = items.get(i);
			if (c.enabled)
				nativeRemove(c.code);
		}
		items.clear();
	}
}
