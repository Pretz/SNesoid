package com.androidemu.snes;

import android.content.Context;
import android.content.res.Configuration;
import android.view.KeyEvent;

public class DefaultPreferences {

	private static final int keymaps_qwerty[] = {
		KeyEvent.KEYCODE_1,
		KeyEvent.KEYCODE_A,
		KeyEvent.KEYCODE_Q,
		KeyEvent.KEYCODE_W,
		0, 0, 0, 0,
		KeyEvent.KEYCODE_DEL,
		KeyEvent.KEYCODE_ENTER,
		KeyEvent.KEYCODE_0,
		KeyEvent.KEYCODE_P,
		KeyEvent.KEYCODE_9,
		KeyEvent.KEYCODE_O,
		KeyEvent.KEYCODE_K,
		KeyEvent.KEYCODE_L,
	};

	private static final int keymaps_non_qwerty[] = {
		0, 0, 0, 0,
		0, 0, 0, 0,
		0,
		0,
		0,
		KeyEvent.KEYCODE_SEARCH,
		0,
		KeyEvent.KEYCODE_BACK,
		0, 0,
	};

	static {
		final int n = keymaps_qwerty.length;
		if (keymaps_non_qwerty.length != n)
			throw new AssertionError("Key configurations are not consistent");
	}


	private static boolean isKeyboardQwerty(Context context) {
		return (context.getResources().getConfiguration().keyboard ==
				Configuration.KEYBOARD_QWERTY);
	}

	private static boolean isNavigationDPad(Context context) {
		return (context.getResources().getConfiguration().navigation !=
				Configuration.NAVIGATION_TRACKBALL);
	}

	public static int[] getKeyMappings(Context context) {
		final int[] keymaps;

		if (isKeyboardQwerty(context))
			keymaps = keymaps_qwerty;
		else
			keymaps = keymaps_non_qwerty;

		if (isNavigationDPad(context)) {
			keymaps[0] = KeyEvent.KEYCODE_DPAD_UP;
			keymaps[1] = KeyEvent.KEYCODE_DPAD_DOWN;
			keymaps[2] = KeyEvent.KEYCODE_DPAD_LEFT;
			keymaps[3] = KeyEvent.KEYCODE_DPAD_RIGHT;
		}
		return keymaps;
	}
}
