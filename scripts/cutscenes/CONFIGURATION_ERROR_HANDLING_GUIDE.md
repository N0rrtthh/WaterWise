# Configuration Error Handling Guide

## Overview

The cutscene system includes robust error handling that ensures the game never blocks due to configuration issues. This guide explains how the system handles errors and what developers need to know.

## Error Handling Behavior

### Automatic Fallback Chain

1. **Custom Configuration** → 2. **Default Configuration** → 3. **Minimal Programmatic Config**

The system automatically tries each level if the previous one fails.

### Common Error Scenarios

#### Missing Configuration File
**What happens**: System logs a warning and uses default configuration
**Action needed**: None - game continues normally
**To fix**: Create the missing configuration file

#### Invalid JSON Syntax
**What happens**: System logs error with line number and uses default configuration
**Action needed**: None - game continues normally
**To fix**: Check JSON syntax at the reported line number

#### Validation Errors
**What happens**: System logs warning and applies default values for invalid fields
**Action needed**: None - game continues normally
**To fix**: Review validation error messages and correct the configuration

## Error Messages

All error messages follow this format:
```
[Component] Error description. Fallback action.
```

Example:
```
[CutsceneParser] Configuration file not found: res://data/cutscenes/MyGame/win.json. 
System will use default configuration.
```

## Best Practices

1. **Test configurations**: Use `test/ValidateDefaultCutscenes.gd` to validate your configs
2. **Check logs**: Review console output for warnings about configuration issues
3. **Use defaults**: Start with default configurations and customize as needed
4. **Validate early**: Run validation during development, not just at runtime

## Debugging Configuration Issues

1. Look for error messages in the console starting with `[CutsceneParser]` or `[AnimatedCutscenePlayer]`
2. Check the file path in the error message
3. Verify JSON syntax using a JSON validator
4. Run the validation test suite to catch issues early

## Configuration Validation

The system validates:
- Duration (1.5-4.0 seconds, type-specific bounds)
- Keyframes (chronological order, valid times, transforms)
- Particles (valid times, density values)
- Audio cues (valid times, non-empty sound names)
- Character configuration (valid expressions)

Invalid values are automatically corrected to sensible defaults.
