#include <stdlib.h>
#include <string.h>

/* Read environment variable value into buf.
   Returns length of value (0 if not found or empty).
   name must be a null-terminated UTF-8 byte string.
   buf is filled with the UTF-8 value (null-terminated).
   LIMITATION: Values longer than buf_size-1 are silently truncated.
   The caller (MoonBit side) uses a fixed 4096-byte buffer. */
int moon_release_getenv(const unsigned char *name, unsigned char *buf,
                        int buf_size) {
  const char *value = getenv((const char *)name);
  if (value == NULL || buf_size <= 0) {
    return 0;
  }
  int len = (int)strlen(value);
  if (len >= buf_size) {
    len = buf_size - 1;
  }
  memcpy(buf, value, len);
  buf[len] = '\0';
  return len;
}
