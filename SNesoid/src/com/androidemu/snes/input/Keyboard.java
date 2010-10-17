package com.androidemu.snes.input;

import android.util.Log;
import android.view.KeyEvent;
import android.view.View;

public class Keyboard implements View.OnKeyListener {

	private static final String LOG_TAG = "Keyboard";

	private GameKeyListener gameKeyListener;
	private int[] keysMap = new int[128];
	private int keyStates;

	public Keyboard(View view, GameKeyListener listener) {
		gameKeyListener = listener;
		view.setOnKeyListener(this);
	}

	public final int getKeyStates() {
		return keyStates;
	}

	public void reset() {
		keyStates = 0;
	}

	public void clearKeyMap() {
		for (int i = 0; i < keysMap.length; i++)
			keysMap[i] = 0;
	}

	public void mapKey(int gameKey, int keyCode) {
		if (keyCode >= 0 && keyCode < keysMap.length)
			keysMap[keyCode] |= gameKey;
	}

	public boolean onKey(View v, int keyCode, KeyEvent event) {
		if (keyCode >= keysMap.length)
			return false;

		int gameKey = keysMap[keyCode];
		if (gameKey != 0) {
			if (event.getRepeatCount() == 0) {
				if (event.getAction() == KeyEvent.ACTION_DOWN)
					keyStates |= gameKey;
				else
					keyStates &= ~gameKey;

				gameKeyListener.onGameKeyChanged();
			}
			return true;
		}
		return false;
	}
}
