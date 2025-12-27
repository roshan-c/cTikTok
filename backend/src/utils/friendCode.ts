import { customAlphabet } from 'nanoid';

// Alphabet without ambiguous characters (0/O, 1/I/L removed)
// 22 letters + 8 numbers = 30 characters
const FRIEND_CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

// 6 characters = 30^6 = ~729 million possible codes
export const generateFriendCode = customAlphabet(FRIEND_CODE_ALPHABET, 6);
