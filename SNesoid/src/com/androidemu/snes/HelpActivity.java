package com.androidemu.snes;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebChromeClient;
import android.webkit.WebView;

public class HelpActivity extends Activity {

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		WebView view = new WebView(this);
		view.setWebChromeClient(new WebChromeClient() {
			public void onReceivedTitle(WebView view, String title) {
				HelpActivity.this.setTitle(title);
			}
		});
		setContentView(view);

		view.loadUrl(getIntent().getData().toString());
	}
}
