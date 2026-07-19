# AssertJ Assertions

Reference for [test-authoring](../SKILL.md). AssertJ over plain JUnit assertions — collection,
exception, object, soft, and string assertion styles.

## AssertJ Power Features

### Collection assertions
```java
// Basic collection checks
assertThat(plugins)
    .isNotEmpty()
    .hasSize(2)
    .doesNotContainNull();

// Advanced filtering and extraction
assertThat(plugins)
    .filteredOn(p -> p.getState() == PluginState.STARTED)
    .extracting(Plugin::getId)
    .containsExactlyInAnyOrder("plugin-a", "plugin-b");

// All elements match condition
assertThat(plugins)
    .allMatch(p -> p.getVersion() != null, "All plugins have version");
```

### Exception assertions
```java
// Basic exception check
assertThatThrownBy(() -> loader.load(invalidPath))
    .isInstanceOf(PluginException.class)
    .hasMessageContaining("Invalid plugin descriptor");

// Detailed exception verification
assertThatThrownBy(() -> manager.startPlugin("missing-plugin"))
    .isInstanceOf(PluginException.class)
    .hasMessageContaining("Plugin not found")
    .hasCauseInstanceOf(IllegalArgumentException.class)
    .hasNoCause(); // or verify cause chain

// With assertThatExceptionOfType (more readable)
assertThatExceptionOfType(PluginException.class)
    .isThrownBy(() -> loader.load(invalidPath))
    .withMessageContaining("Invalid")
    .withMessageMatching("Invalid .* descriptor");
```

### Object assertions
```java
// Extract and verify multiple properties
assertThat(plugin)
    .isNotNull()
    .extracting("id", "version", "state")
    .containsExactly("my-plugin", "1.0", PluginState.STARTED);

// Using method references (type-safe)
assertThat(plugin)
    .extracting(Plugin::getId, Plugin::getVersion, Plugin::getState)
    .containsExactly("my-plugin", "1.0", PluginState.STARTED);

// Field by field comparison
assertThat(actualPlugin)
    .usingRecursiveComparison()
    .isEqualTo(expectedPlugin);
```

### Soft assertions (multiple checks)
```java
@Test
void shouldHaveValidPluginDescriptor() {
    SoftAssertions softly = new SoftAssertions();
    
    softly.assertThat(descriptor.getId())
        .as("Plugin ID")
        .isNotBlank()
        .matches("[a-z0-9-]+");
    
    softly.assertThat(descriptor.getVersion())
        .as("Plugin version")
        .matches("\\d+\\.\\d+\\.\\d+");
    
    softly.assertThat(descriptor.getDependencies())
        .as("Dependencies")
        .isNotNull()
        .doesNotContainNull();
    
    softly.assertAll(); // All assertions evaluated, even if some fail
}
```

### String assertions
```java
assertThat(errorMessage)
    .startsWith("Error:")
    .contains("plugin", "failed")
    .doesNotContain("success")
    .matches("Error: .* failed")
    .hasLineCount(3);
```

