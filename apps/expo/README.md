# Expo RN Template

A reusable React Native template using Expo with TypeScript, navigation, and best practices for quick project starts. This is a GitHub template repository that you can use to create new Expo projects.

## Features

- **Expo Router** for file-based routing
- **TypeScript** for type safety
- **Zustand** for state management
- **React Query** for data fetching
- **Expo Notifications** for push notifications
- **Reusable UI Components** (Button, etc.)
- **Scalable Folder Structure**
- **ESLint** configuration
- **Pre-configured** for development and production

## Quick Start

This project uses [Bun](https://bun.sh) as the package manager. Install Bun if needed: `curl -fsSL https://bun.sh/install | bash`

### Using GitHub Template

1. **Click "Use this template"** on GitHub to create a new repository
2. **Clone your new repository:**
   ```bash
   git clone https://github.com/mwijanarko1/Expo-RN-Template.git
   cd your-repo-name
   ```
3. **Install dependencies:**
   ```bash
   bun install
   ```
4. **Start the development server:**
   ```bash
   bun start
   ```

### Alternative: Manual Setup

```bash
bunx create-expo-app@latest MyApp --template blank-typescript
cd MyApp
bun install
# Copy the contents of this template over your new project
```

## Project Structure

```
my-app/
├── app/                    # Expo Router screens and layouts
│   ├── _layout.tsx        # Root layout
│   ├── (tabs)/           # Tab navigation
│   │   ├── _layout.tsx   # Tab layout
│   │   ├── index.tsx     # Home screen
│   │   └── profile.tsx   # Profile screen
│   └── modal.tsx         # Modal screen example
├── components/           # Reusable UI components
│   ├── ui/              # Basic UI components (Button)
│   └── forms/           # Form components
├── lib/                 # Utilities and services
│   └── hooks/           # Custom hooks (useNotifications)
├── store/               # State management (Zustand stores)
│   └── auth.ts          # Authentication store
├── types/               # TypeScript definitions
│   └── user.ts          # User-related types
├── constants/           # App-wide constants
│   └── index.ts         # Colors, spacing, API endpoints
├── assets/              # Images, fonts, icons
└── README.md
```

## Key Dependencies

- **Expo SDK**: 55 (React Native 0.83, React 19.2)
- **Navigation**: `expo-router`, `react-native-screens`, `expo-linking`
- **State Management**: `zustand`
- **Data Fetching**: `@tanstack/react-query`
- **Notifications**: `expo-notifications`
- **Development**: `eslint-config-expo`

### SDK 55 Migration Notes

This template uses **Expo SDK 55**, which includes:

- **New Architecture only** — Legacy Architecture support was removed
- **React Native 0.83** and **React 19.2**
- **Edge-to-edge** mandatory on Android 16+

**Push notifications**: Expo Go on Android will throw an error when using push notifications. Use a [development build](https://docs.expo.dev/develop/development-builds/introduction/) for push notification development.

## Usage Examples

### State Management

```typescript
import { useAuthStore } from '../store/auth';

// In your component
const { user, isAuthenticated, login, logout } = useAuthStore();

// Login user
login({
  id: '1',
  name: 'John Doe',
  email: 'john@example.com',
});
```

### Custom Hook

```typescript
import { useNotifications } from '../lib/hooks/useNotifications';

// In your component
const { scheduleNotification } = useNotifications();

// Schedule a notification
await scheduleNotification('Hello!', 'This is a test notification');
```

### UI Components

```typescript
import { Button } from '../components/ui/Button';

// In your component
<Button
  title="Press me"
  onPress={() => console.log('Pressed!')}
  variant="primary"
/>
```

### Navigation

```typescript
import { Link } from 'expo-router';

// In your component
<Link href="/profile">Go to Profile</Link>
```

## Development

### Environment

Store API keys and secrets in `.env` files (gitignored). Never commit sensitive data.

### Running the App

```bash
bun start          # Start Expo development server
bun run android   # Run on Android
bun run ios       # Run on iOS
bun run web       # Run on web
```

### Building

```bash
bun run build     # Build with EAS
eas build --profile preview  # Preview build
eas build --profile production  # Production build
```

### Linting

```bash
bunx eslint .     # Run ESLint
```

## Customization

### Adding New Screens

1. Create new file in `app/` directory
2. Use file-based routing (e.g., `app/settings.tsx` creates `/settings` route)

### Adding New Components

1. Create component in appropriate `components/` subdirectory
2. Export from `components/index.ts` if needed

### Adding New Stores

1. Create store file in `store/` directory
2. Follow Zustand patterns for state management

## Using as a GitHub Template

This repository is designed to be used as a GitHub template. To use it:

1. **Go to [this repository on GitHub](https://github.com/mwijanarko1/Expo-RN-Template)**
2. **Click the "Use this template" button**
3. **Create a new repository** from this template
4. **Clone and start developing!**

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
bun install
bun start
```

### Template Benefits

- **Clean commit history** - Start with a fresh repository
- **Proper .gitignore** - No unnecessary files committed
- **Ready-to-use structure** - All folders and files set up
- **Best practices included** - ESLint, TypeScript, state management
- **Documentation provided** - Clear setup and usage instructions

## Author

Created by [Mikhail Wijanarko](https://github.com/mwijanarko1)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
