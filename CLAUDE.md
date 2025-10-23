# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**pagocrypto** is a Flutter application for generating cryptocurrency payment QR codes. The app currently implements a payment generator feature with settings management using local storage.

**Dart/Flutter Requirements**: Dart 3.9.0+ and Flutter 3.24+

## Architecture

This project follows the **Feature-First architecture** pattern with strict separation of concerns. All Flutter code must adhere to the rules defined in `/Users/albertonoris/development/ssot/flutter/flutter_architecture.md`.

### Key Architectural Principles

1. **Feature-First Structure**: Code is organized by features, not by layers. Each feature lives in `lib/src/features/[feature_name]/` with `controllers/`, `views/`, and `widgets/` subdirectories.

2. **Strict Separation of Concerns**:
   - **Controllers** (ChangeNotifier): Handle all business logic, state management, and data validation
   - **Views** (Widgets): Handle only UI rendering and user input forwarding

3. **Shared Code**: Any code shared across features goes in `lib/src/core/` (models, services, navigation, widgets, utilities)

4. **State Management**: Uses Provider + ChangeNotifier pattern with these rules:
   - All state variables in controllers are private (`_`) with public getters
   - Controllers call `notifyListeners()` immediately after state changes
   - One-time events (side-effects like navigation) use boolean flags or nullable properties with reset methods
   - Views use `Consumer<T>` for state-dependent UI and `context.read<T>()` for triggering actions
   - StatefulWidgets listening to events add/remove listeners in initState/dispose

5. **Golden Rule**: A feature module must NEVER directly import another feature module. All dependencies must flow through `lib/src/core/`.

6. **Navigation**: Uses GoRouter with ShellRoute pattern to provide shared controllers across multiple routes. Feature-scoped Providers are defined within route builders.

## Current Project Structure

```
lib/src/
├── core/
│   └── navigation/
│       └── app_router.dart       # GoRouter configuration with ShellRoute
├── features/
│   └── payment_generator/
│       ├── controllers/
│       │   └── payment_generator_controller.dart
│       └── views/
│           ├── home_view.dart
│           ├── settings_view.dart
│           └── qr_display_view.dart
└── main.dart
```

## Dependencies

Core dependencies:
- **provider** ^6.0.0: State management using ChangeNotifier pattern
- **go_router** ^14.0.0: Navigation and routing
- **shared_preferences** ^2.0.0: Local persistent storage for user settings
- **qr_flutter** ^4.0.0: QR code generation and display
- **flutter_lints** ^5.0.0: Linting rules

New dependencies require discussion before adding.

## Development Commands

### Setup
```bash
flutter pub get                    # Install dependencies
```

### Development
```bash
flutter run                        # Run the app on the connected device/simulator
flutter run -d <device_id>        # Run on a specific device (get IDs with: flutter devices)
```

### Analysis & Linting
```bash
dart analyze                       # Static analysis on Dart code
flutter analyze                    # Flutter-specific analysis
dart format lib/                   # Format Dart code
dart format lib/ --set-exit-if-changed  # Check formatting without applying changes
```

### Testing
```bash
flutter test                       # Run all unit and widget tests
flutter test test/path/to/test.dart  # Run a specific test file
```

**Note**: Tests currently do not exist. Create them in a `test/` directory as the project grows.

## Important Notes for Claude Code

1. **Do not automatically run `flutter run`**: The app is typically already running in the simulator. After making changes, ask the user to hot reload (press 'r' in the terminal or use the IDE) or verify the changes manually.

2. **Architecture Compliance**: Before implementing any new features, ensure they follow the Feature-First architecture and separation of concerns principles. Use the `flutter-architecture-linter` agent to verify compliance when appropriate.

3. **Feature Implementation Pattern**:
   - Create the feature directory structure under `lib/src/features/[feature_name]/`
   - Implement the Controller first (handles business logic and validation)
   - Implement the Views second (renders state, handles user input via context.read/Consumer)
   - Keep feature-specific widgets in the feature's `widgets/` subdirectory
   - Move shared widgets to `lib/src/core/widgets/` if they're used across features
   - Never directly import another feature module

4. **State Management**:
   - All state mutations must immediately call `notifyListeners()`
   - One-time events (navigation, dialogs, snackbars) use nullable String properties or boolean flags with reset methods
   - Stateful Views handling one-time events add listeners in initState and remove them in dispose
   - Reset event properties after the view has handled them to prevent duplicate triggers

5. **Navigation and Provider Setup**:
   - Use ShellRoute in GoRouter to share a single controller instance across multiple routes
   - Feature-scoped Providers are created within route builders, not at the app root
   - Global Providers (at MaterialApp level) are only for cross-feature shared state (e.g., authentication)

6. **Hot Reload Workflow**:
   - After code changes, press 'r' in the Flutter terminal to hot reload
   - For changes to controllers or dependencies, a full app restart (Shift+R) may be needed
   - This is faster than manually re-running the app
