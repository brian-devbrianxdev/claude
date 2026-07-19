---
name: test-authoring
description: Write high-quality JUnit 5 tests with AssertJ assertions. Use when user says "add tests", "write tests", "improve test coverage", or when reviewing/creating test classes for Java code.
---

# Test Quality Skill (JUnit 5 + AssertJ)

Write high-quality, maintainable tests for Java projects using modern best practices. Load only
the reference section relevant to what's being written — a single new test doesn't need the
coverage-tooling reference, and a coverage-config question doesn't need the assertion cheat sheet.

## When to Use
- Writing new test classes
- Reviewing/improving existing tests
- User asks to "add tests" / "improve test coverage"
- Code review mentions missing tests

## Framework Preferences

### JUnit 5 (Jupiter)
```java
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import static org.assertj.core.api.Assertions.*;
```

### AssertJ over standard assertions
✅ **Use AssertJ**:
```java
assertThat(plugin.getState())
    .as("Plugin should be started after initialization")
    .isEqualTo(PluginState.STARTED);

assertThat(plugins)
    .hasSize(3)
    .extracting(Plugin::getId)
    .containsExactly("plugin1", "plugin2", "plugin3");
```

❌ **Avoid JUnit assertions**:
```java
assertEquals(PluginState.STARTED, plugin.getState()); // Less readable
assertTrue(plugins.size() == 3); // Less descriptive failures
```

## Routing — which reference applies

| If the task is… | Read |
|-------------------|------|
| Naming a test class/method, structuring one with Arrange-Act-Assert, grouping with `@Nested`/`@ParameterizedTest` | [references/structure-naming-and-organization.md](references/structure-naming-and-organization.md) |
| Choosing the right AssertJ assertion style (collections, exceptions, objects, soft assertions, strings) | [references/assertj-assertions.md](references/assertj-assertions.md) |
| Mocking (Mockito), fixtures, async tests, token-efficient incremental authoring, coverage targets, anti-patterns, JaCoCo setup | [references/patterns-coverage-and-antipatterns.md](references/patterns-coverage-and-antipatterns.md) |

## Quick Reference

```java
// ===== Basic Assertions =====
assertThat(value).isEqualTo(expected);
assertThat(value).isNotNull();
assertThat(value).isInstanceOf(String.class);
assertThat(number).isPositive().isGreaterThan(5);

// ===== Collections =====
assertThat(list).hasSize(3);
assertThat(list).contains(item);
assertThat(list).containsExactly(item1, item2, item3);
assertThat(list).containsExactlyInAnyOrder(item2, item1, item3);
assertThat(list).doesNotContain(item);
assertThat(list).allMatch(predicate);

// ===== Strings =====
assertThat(str).isNotBlank();
assertThat(str).startsWith("prefix");
assertThat(str).endsWith("suffix");
assertThat(str).contains("substring");
assertThat(str).matches("regex\\d+");

// ===== Exceptions =====
assertThatThrownBy(() -> code())
    .isInstanceOf(PluginException.class)
    .hasMessageContaining("error");

assertThatNoException().isThrownBy(() -> code());

// ===== Custom Descriptions =====
assertThat(userId)
    .as("User ID should be positive")
    .isPositive();

// ===== Object Comparison =====
assertThat(actual)
    .usingRecursiveComparison()
    .ignoringFields("timestamp", "id")
    .isEqualTo(expected);
```

## Best Practices Summary

1. **Use AssertJ** for all assertions
2. **Follow AAA pattern** (Arrange-Act-Assert)
3. **Descriptive names** with @DisplayName
4. **One concept** per test
5. **Test behavior**, not implementation
6. **Extract helpers** for common setup
7. **Use @Nested** for logical grouping
8. **Parameterize** similar tests
9. **Soft assertions** for multiple checks
10. **Coverage** on business logic, not boilerplate

## References

- [AssertJ Documentation](https://assertj.github.io/doc/)
- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)
