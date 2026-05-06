import { z } from 'zod';

/** Zod schema for runtime validation of User objects from API responses. */
export const UserSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  email: z.string().email(),
  avatar: z.string().url().optional(),
});

/** Represents an authenticated user. */
export type User = z.infer<typeof UserSchema>;

/** Represents the shape of the authentication state. */
export interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}
