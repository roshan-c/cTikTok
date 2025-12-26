import { customAlphabet } from 'nanoid';

// URL-safe alphabet without ambiguous characters
const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

export const generateId = customAlphabet(alphabet, 12);
export const generateVideoId = customAlphabet(alphabet, 16);
