/**
 * studio/client/src/utils/array.ts -- Array Normalization & Defensive Helpers
 */

export function ensureArray<T>(val: T | T[] | undefined | null): T[] {
  if (val === undefined || val === null) {
    return [];
  }
  if (Array.isArray(val)) {
    return val;
  }
  return [val];
}
