package com.androidemu.snes;

import android.content.Context;
import android.media.MediaScannerConnection;
import android.net.Uri;

public class MediaScanner implements
		MediaScannerConnection.MediaScannerConnectionClient {

	private MediaScannerConnection conn;
	private String filePath;
	private String mimeType;

	public MediaScanner(Context context) {
		conn = new MediaScannerConnection(context, this);
		conn.connect();
	}

	public void scanFile(String path, String mime) {
		if (conn.isConnected())
			conn.scanFile(path, mime);
		else {
			filePath = path;
			mimeType = mime;
		}
	}

	public void onMediaScannerConnected() {
		if (filePath != null)
			conn.scanFile(filePath, mimeType);

		filePath = null;
		mimeType = null;
	}

	public void onScanCompleted(String path, Uri uri) {
	}
}
