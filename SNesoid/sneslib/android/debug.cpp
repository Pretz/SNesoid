#define LOG_TAG "libsnes"
#include <utils/Log.h>

extern "C"
void S9xMessage(int type, int number, const char *message)
{
	LOGD(message);
}
