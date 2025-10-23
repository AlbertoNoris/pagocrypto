# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**pagocrypto** is a Flutter application. The project is currently in its early stages with minimal code (mostly scaffold/boilerplate).

## Architecture

This project follows the **Feature-First architecture** pattern with strict separation of concerns. All Flutter code must adhere to the rules defined in `/Users/albertonoris/development/ssot/flutter/flutter_architecture.md`.

### Key Architectural Principles

1. **Feature-First Structure**: Code is organized by features, not by layers. Each feature lives in `lib/features/[feature_name]/` with `controller/`, `view/`, and `widgets/` subdirectories.

2. **Strict Separation of Concerns**:
   - **Controllers** (ChangeNotifier): Handle all business logic and state management
   - **Views** (Widgets): Handle only UI rendering and user input forwarding

3. **Shared Code**: Any code shared across features goes in `lib/core/` (models, services, widgets, utilities)

4. **State Management**: Uses Provider + ChangeNotifier pattern with these rules:
   - All state variables in controllers are private (`_`) with public getters
   - Controllers call `notifyListeners()` immediately after state changes
   - One-time events (side-effects like navigation) use nullable properties with reset methods
   - Views use `Consumer<T>` for state-dependent UI and `context.read<T>()` for triggering actions

5. **Golden Rule**: A feature module must NEVER directly import another feature module. All dependencies must flow through `lib/core/`.

6. **Navigation**: Uses GoRouter for all navigation with feature-scoped Provider definitions in route builders.

## Development Commands

### Setup
```bash
flutter pub get                    # Install dependencies
```

### Development
```bash
flutter run                        # Run the app (for development testing)
flutter run -d <device_id>        # Run on a specific device
```

### Linting & Analysis
```bash
dart analyze                       # Static analysis
flutter analyze                    # Flutter-specific analysis
```

### Code Quality
```bash
dart format lib/                   # Format Dart code
dart format lib/ --set-exit-if-changed  # Check formatting without changes
```

### Testing
```bash
flutter test                       # Run all tests
flutter test test/path/to/test.dart  # Run a specific test file
```

**Note**: Tests currently do not exist. Create them in a `test/` directory as the project grows.

## Important Notes for Claude Code

1. **Do not automatically run `flutter run`**: The project is typically already running in the simulator. After making changes, ask the user to verify the result or hot reload instead.

2. **Architecture Compliance**: Before implementing any new features, ensure they follow the Feature-First architecture and separation of concerns principles outlined above. Use the `flutter-architecture-linter` agent when checking new code.

3. **Feature Implementation Pattern**:
   - Create the feature directory structure under `lib/features/[feature_name]/`
   - Implement the Controller first (handles business logic)
   - Implement the View second (renders state, uses Consumer/context.read)
   - Keep Widgets isolated to the feature or move to `lib/core/widgets/` if shared
   - Never import other features directly

4. **State Management**:
   - All state mutations must trigger `notifyListeners()`
   - One-time events (navigation, dialogs, snackbars) should use nullable properties with reset methods
   - Stateful Views listening for events must add/remove listeners in initState/dispose

## Dependencies

Current main dependencies:
- `flutter`: Material Design framework
- `flutter_lints`: Linting rules

The project uses minimal dependencies intentionally. New dependencies should be discussed before adding.

## Minimal Project State

The `lib/` directory currently contains only `main.dart` with basic scaffolding. The project is ready for feature development following the architecture guidelines above.
