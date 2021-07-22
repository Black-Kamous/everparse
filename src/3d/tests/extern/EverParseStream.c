#include "EverParseStream.h"
#include <stdlib.h>

BOOLEAN EverParseHas(EverParseInputStreamBase const x, uint32_t n) {
  if (n == 0)
    return TRUE;
  struct es_cell *head = *x;
  while (head != NULL) {
    uint32_t len = head->len;
    if (n <= len)
      return TRUE;
    n -= len;
    head = head->next;
  }
  return FALSE;
}

uint8_t *EverParseRead(EverParseInputStreamBase const x, uint32_t n, uint8_t * const dst) {
  /** assumes EverParseHas n */
  if (n == 0)
    return dst;
  struct es_cell *head = *x;
  uint32_t len = head->len;
  if (n <= len) {
    uint8_t *res = head->buf;
    head->buf += n;
    head->len -= n;
    return res;
  }
  uint8_t *write = dst;
  while (n > len) {
    memcpy(write, head->buf, len);
    write += len;
    n -= len;
    head = head->next;
    if (head == NULL) {
      /* here we know that n == 0 */
      *x = NULL;
      return dst;
    }
    len = head->len;
  }
  memcpy(write, head->buf, n);
  head->buf += n;
  head->len -= n;
  *x = head;
  return dst;
}

void EverParseSkip(EverParseInputStreamBase const x, uint32_t n) {
  /** assumes EverParseHas n */
  if (n == 0)
    return;
  {
    struct es_cell *head = *x;
    uint32_t len = head->len;
    while (n > len) {
      n -= len;
      head = head->next;
      if (head == NULL) {
	/* here we know that n == 0 */
	*x = NULL;
	return;
      }
      len = head->len;
    }
    head->buf += n;
    head->len -= n;
    *x = head;
    return;
  }
}

uint32_t EverParseEmpty(EverParseInputStreamBase const x) {
  uint32_t res = 0;
  struct es_cell *head = *x;
  while (head != NULL) {
    res += head->len;
    head = head->next;
  }
  *x = NULL;
  return res;
}

EverParseInputStreamBase * EverParseCreate() {
  EverParseInputStreamBase * res = malloc(sizeof(EverParseInputStreamBase));
  if (res != NULL) {
    *res = NULL;
  }
  return res;
}

BOOLEAN EverParsePush(EverParseInputStreamBase const x, uint8_t * const buf, uint32_t const len) {
  struct es_cell * cell = malloc(sizeof(struct es_cell));
  if (cell == NULL)
    return FALSE;
  cell->buf = buf;
  cell->len = len;
  cell->next = *x;
  *x = cell;
  return TRUE;
}
