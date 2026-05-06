import { act } from 'react';
import { useAuthStore } from '@/store/auth';

const validUser = {
  id: '1',
  name: 'Jane Doe',
  email: 'jane@example.com',
};

beforeEach(() => {
  // Reset store state between tests
  act(() => useAuthStore.setState({ user: null, isAuthenticated: false, isLoading: false }));
});

describe('useAuthStore', () => {
  describe('login', () => {
    it('sets the user and marks authenticated on valid input', () => {
      act(() => useAuthStore.getState().login(validUser));
      const { user, isAuthenticated } = useAuthStore.getState();
      expect(user).toMatchObject(validUser);
      expect(isAuthenticated).toBe(true);
    });

    it('does not update state when user has an invalid email', () => {
      act(() =>
        useAuthStore.getState().login({ ...validUser, email: 'not-an-email' })
      );
      const { user, isAuthenticated } = useAuthStore.getState();
      expect(user).toBeNull();
      expect(isAuthenticated).toBe(false);
    });

    it('clears isLoading after login', () => {
      act(() => {
        useAuthStore.getState().setLoading(true);
        useAuthStore.getState().login(validUser);
      });
      expect(useAuthStore.getState().isLoading).toBe(false);
    });
  });

  describe('logout', () => {
    it('clears user and auth state', () => {
      act(() => {
        useAuthStore.getState().login(validUser);
        useAuthStore.getState().logout();
      });
      const { user, isAuthenticated } = useAuthStore.getState();
      expect(user).toBeNull();
      expect(isAuthenticated).toBe(false);
    });
  });

  describe('setLoading', () => {
    it('updates the loading flag', () => {
      act(() => useAuthStore.getState().setLoading(true));
      expect(useAuthStore.getState().isLoading).toBe(true);

      act(() => useAuthStore.getState().setLoading(false));
      expect(useAuthStore.getState().isLoading).toBe(false);
    });
  });
});
