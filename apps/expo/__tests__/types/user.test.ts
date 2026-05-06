import { UserSchema } from '@/types/user';

describe('UserSchema', () => {
  it('accepts a valid user object', () => {
    const result = UserSchema.safeParse({
      id: '1',
      name: 'Alice',
      email: 'alice@example.com',
    });
    expect(result.success).toBe(true);
  });

  it('accepts a user with an optional avatar URL', () => {
    const result = UserSchema.safeParse({
      id: '1',
      name: 'Alice',
      email: 'alice@example.com',
      avatar: 'https://cdn.example.com/avatar.png',
    });
    expect(result.success).toBe(true);
  });

  it('rejects an invalid email', () => {
    const result = UserSchema.safeParse({
      id: '1',
      name: 'Alice',
      email: 'not-an-email',
    });
    expect(result.success).toBe(false);
  });

  it('rejects an empty id', () => {
    const result = UserSchema.safeParse({
      id: '',
      name: 'Alice',
      email: 'alice@example.com',
    });
    expect(result.success).toBe(false);
  });

  it('rejects a non-URL avatar value', () => {
    const result = UserSchema.safeParse({
      id: '1',
      name: 'Alice',
      email: 'alice@example.com',
      avatar: 'not-a-url',
    });
    expect(result.success).toBe(false);
  });
});
