# Coding Guidelines

## File Structure

### Class Separation
- One class per file
- File name: snake_case version of class name (e.g., `NavigationItem` → `navigation_item.dart`)
- Related helper classes may share the same file

### Directory Structure
```
lib/
├── colaxy_adaptive_scaffold.dart  # Main export file
└── src/                           # Implementation files
    ├── adaptive_scaffold.dart
    ├── navigation_item.dart
    └── ...
```

### Export Management
- Export all public classes from `lib/colaxy_adaptive_scaffold.dart`
- Keep implementation details in `src/` directory

## Documentation

### Class Documentation
```dart
/// Brief class description (one line)
///
/// Detailed explanation
///
/// ## Parameters
///
/// ### Required
/// - **[paramName]**: Description
///
/// ### Optional
/// - **[paramName]**: Description (default: value)
///
/// ## Example
///
/// ```dart
/// // Usage example
/// ```
class MyClass { }
```

### Parameter Documentation
```dart
/// Brief parameter description
///
/// Additional details if needed
final Type parameterName;
```

### README Updates
Update `README.md` when adding features:
- **Features**: List main capabilities
- **Usage**: Include basic and advanced examples
- **API Reference**: Document all public classes and parameters

## Coding Style

### Naming Conventions
- **Classes**: PascalCase (`AdaptiveScaffold`)
- **Files**: snake_case (`adaptive_scaffold.dart`)
- **Variables/Parameters**: camelCase (`selectedIndex`)
- **Constants**: lowerCamelCase (`defaultThreshold`)

### Code Organization
- Public members first, private members last
- Logical method order: lifecycle → build → helpers

## Design Principles

1. **Simplicity**: Keep API simple and intuitive with sensible defaults
2. **Flexibility**: Provide customizable parameters with reasonable defaults
3. **Documentation**: Fully document all public APIs with examples

## Change Management

- **Breaking Changes**: Deprecate first with `@deprecated`, provide alternatives
- **New Features**: Update README with examples
- **Bug Fixes**: Document in commit messages

## Checklist

Before committing new classes/features:
- [ ] Class in separate file
- [ ] Comprehensive documentation
- [ ] All parameters documented
- [ ] Usage examples included
- [ ] Exported from `lib/colaxy_adaptive_scaffold.dart`
- [ ] README.md updated
