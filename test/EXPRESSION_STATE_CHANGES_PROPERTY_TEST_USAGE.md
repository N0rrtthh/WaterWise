# Expression State Changes Property Test

## Overview

Property-based test for WaterDropletCharacter expression state changes.

**Feature**: animated-cutscenes, Property 9: Expression State Changes  
**Validates**: Requirements 4.2

## What It Tests

This property test verifies that for any valid expression (happy, sad, surprised, determined, worried, excited), setting the character's expression results in the character displaying that expression.

The test:
1. Runs 100 iterations with random expression selections
2. Tests all 6 valid expressions from the Expression enum
3. Verifies set_expression() correctly updates the character's expression
4. Verifies get_expression() returns the correct expression after setting

## Running the Test

### Option 1: Run from Godot Editor
1. Open the Godot project
2. Navigate to `test/ExpressionStateChangesPropertyTest.tscn`
3. Press **F6** (Run Current Scene)
4. View test results in the console output

### Option 2: Run as Script
1. Open the Godot project
2. Go to File > Run
3. Select `test/ExpressionStateChangesPropertyTest.gd`
4. View test results in the console output

## Expected Output

```
============================================================
EXPRESSION STATE CHANGES PROPERTY TEST
Feature: animated-cutscenes, Property 9
Random Seed: [seed number]
============================================================

PROPERTY TEST: Expression State Changes (100 iterations)
Testing that set_expression() correctly updates character expression

  ✓ Iteration 1: Expression should be HAPPY
  ✓ Iteration 2: Expression should be DETERMINED
  ✓ Iteration 3: Expression should be EXCITED
  ...
  ✓ Iteration 100: Expression should be SAD

Property test completed: 100 iterations

============================================================
TEST SUMMARY
  Passed: 100
  Failed: 0
  Random Seed: [seed number]
============================================================
```

## Test Properties

The test validates the following property:

**Property 9: Expression State Changes**  
*For any* valid expression, setting the character's expression should result in the character displaying that expression.

This is a universal property that must hold for all valid inputs across all executions.
