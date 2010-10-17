package com.androidemu;

import android.content.Context;
import android.graphics.PixelFormat;
import android.util.AttributeSet;
import android.util.Log;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

public class EmulatorView extends SurfaceView {

	public interface OnTrackballListener {
		boolean onTrackball(MotionEvent event);
	}

	public static final int SCALING_ORIGINAL = 0;
	public static final int SCALING_2X = 1;
	public static final int SCALING_PROPORTIONAL = 2;
	public static final int SCALING_STRETCH = 3;

	private OnTrackballListener onTrackballListener;
	private int scalingMode = SCALING_PROPORTIONAL;
	private int actualWidth;
	private int actualHeight;
	private float aspectRatio;

	public EmulatorView(Context context, AttributeSet attrs) {
		super(context, attrs);

		final SurfaceHolder holder = getHolder();
		holder.setFormat(PixelFormat.RGB_565);
		holder.setKeepScreenOn(true);

		setFocusableInTouchMode(true);
	}

	public void setOnTrackballListener(OnTrackballListener l) {
		onTrackballListener = l;
	}

	public void setActualSize(int w, int h) {
		if (actualWidth != w || actualHeight != h) {
			actualWidth = w;
			actualHeight = h;
			updateSurfaceSize();
		}
	}

	public void setScalingMode(int mode) {
		if (scalingMode != mode) {
			scalingMode = mode;
			updateSurfaceSize();
		}
	}

	public void setAspectRatio(float ratio) {
		if (aspectRatio != ratio) {
			aspectRatio = ratio;
			updateSurfaceSize();
		}
	}

	private void updateSurfaceSize() {
		int viewWidth = getWidth();
		int viewHeight = getHeight();
		if (viewWidth == 0 || viewHeight == 0 ||
				actualWidth == 0 || actualHeight == 0)
			return;

		int w = 0;
		int h = 0;

		if (scalingMode != SCALING_STRETCH && aspectRatio != 0)
			viewWidth = (int) (viewWidth / aspectRatio);

		switch (scalingMode) {
		case SCALING_ORIGINAL:
			w = viewWidth;
			h = viewHeight;
			break;

		case SCALING_2X:
			w = viewWidth / 2;
			h = viewHeight / 2;
			break;

		case SCALING_STRETCH:
			if (viewWidth * actualHeight >= viewHeight * actualWidth) {
				w = actualWidth;
				h = actualHeight;
			}
			break;
		}

		if (w < actualWidth || h < actualHeight) {
			h = actualHeight;
			w = h * viewWidth / viewHeight;
			if (w < actualWidth) {
				w = actualWidth;
				h = w * viewHeight / viewWidth;
			}
		}
		getHolder().setFixedSize(w, h);
	}

	@Override
	protected void onSizeChanged(int w, int h, int oldw, int oldh) {
		updateSurfaceSize();
	}

	@Override
	public boolean onTrackballEvent(MotionEvent event) {
		if (onTrackballListener != null &&
				onTrackballListener.onTrackball(event))
			return true;

		return super.onTrackballEvent(event);
	}
}
