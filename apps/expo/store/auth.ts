import { create } from 'zustand';
import { User, AuthState, UserSchema } from '@/types/user';

interface AuthStore extends AuthState {
  /**
   * Authenticates the user and stores their data in state.
   * Validates the user object against the UserSchema before storing.
   * @param user - The user object returned from the authentication provider.
   */
  login: (user: User) => void;
  /** Clears the authenticated user and resets auth state. */
  logout: () => void;
  /**
   * Sets the loading flag for async auth operations.
   * @param loading - True while an auth operation is in progress.
   */
  setLoading: (loading: boolean) => void;
}

/**
 * Global authentication store powered by Zustand.
 * Holds the current user, auth status, and loading state.
 */
export const useAuthStore = create<AuthStore>((set) => ({
  user: null,
  isAuthenticated: false,
  isLoading: false,

  login: (user: User) => {
    const parsed = UserSchema.safeParse(user);
    if (!parsed.success) {
      if (__DEV__) {
        console.error('Invalid user object passed to login:', parsed.error.flatten());
      }
      return;
    }
    set({ user: parsed.data, isAuthenticated: true, isLoading: false });
  },

  logout: () => set({ user: null, isAuthenticated: false, isLoading: false }),

  setLoading: (loading: boolean) => set({ isLoading: loading }),
}));
