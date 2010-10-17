package com.androidemu.snes.input;

import android.content.Context;
import android.content.res.Configuration;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.util.Log;

public class SensorKeypad implements SensorEventListener {

	public static final int LEFT = (1 << 0);
	public static final int RIGHT = (1 << 1);
	public static final int UP = (1 << 2);
	public static final int DOWN = (1 << 3);

	private static final float THRESHOLD_VALUES[] = {
		30.0f, 20.0f, 15.0f, 10.0f, 8.0f,
		6.0f, 5.0f, 3.0f, 2.0f, 1.0f,
	};

	private Context context;
	private GameKeyListener gameKeyListener;
	private int keyStates;
	private float threshold = THRESHOLD_VALUES[7];

	public SensorKeypad(Context ctx) {
		context = ctx;
	}

	public final int getKeyStates() {
		return keyStates;
	}

	public final void setSensitivity(int value) {
		if (value < 0)
			value = 0;
		else if (value > 9)
			value = 9;

		threshold = THRESHOLD_VALUES[value];
	}

	public final void setGameKeyListener(GameKeyListener l) {
		if (gameKeyListener == l)
			return;

		SensorManager sensorManager = (SensorManager)
				context.getSystemService(Context.SENSOR_SERVICE);

		if (gameKeyListener != null)
			sensorManager.unregisterListener(this);

		gameKeyListener = l;
		if (gameKeyListener != null) {
			Sensor sensor = sensorManager.getDefaultSensor(
					Sensor.TYPE_ORIENTATION);
			sensorManager.registerListener(this,
					sensor, SensorManager.SENSOR_DELAY_GAME);
		}
	}

	public void onAccuracyChanged(Sensor sensor, int accuracy) {
	}

	public void onSensorChanged(SensorEvent event) {
		float leftRight, upDown;

		Configuration config = context.getResources().getConfiguration();
		if (config.orientation == Configuration.ORIENTATION_LANDSCAPE) {
			leftRight = -event.values[1];
			upDown = event.values[2];
		} else {
			leftRight = -event.values[2];
			upDown = -event.values[1];
		}

		int states = 0;
		if (leftRight < -threshold)
			states |= LEFT;
		else if (leftRight > threshold)
			states |= RIGHT;
/*
		if (upDown < -THRESHOLD)
			states |= Emulator.GAMEPAD_UP;
		else if (upDown > THRESHOLD)
			states |= Emulator.GAMEPAD_DOWN;
*/
		if (states != keyStates) {
			keyStates = states;
			if (gameKeyListener != null)
				gameKeyListener.onGameKeyChanged();
		}
	}
}
