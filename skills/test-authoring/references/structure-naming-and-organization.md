# Test Structure, Naming & Organization

Reference for [test-authoring](../SKILL.md). How to shape and name a test: Arrange-Act-Assert,
class/method naming conventions, and grouping with @Nested / @ParameterizedTest.

## Test Structure (AAA Pattern)

Always use Arrange-Act-Assert pattern:

```java
@Test
@DisplayName("Should load plugin from valid directory")
void shouldLoadPluginFromValidDirectory() {
    // Arrange - Setup test data and dependencies
    Path pluginDir = Paths.get("test-plugins/valid-plugin");
    PluginLoader loader = new DefaultPluginLoader();
    
    // Act - Execute the behavior being tested
    Plugin plugin = loader.load(pluginDir);
    
    // Assert - Verify results
    assertThat(plugin)
        .isNotNull()
        .extracting(Plugin::getId, Plugin::getVersion)
        .containsExactly("test-plugin", "1.0.0");
}
```

## Naming Conventions

### Test class names
```java
// Class under test: PluginManager
PluginManagerTest           // ✅ Simple, standard
PluginManagerShould         // ✅ BDD style (if team prefers)
TestPluginManager           // ❌ Avoid
```

### Test method names

**Option 1: should_expectedBehavior_when_condition** (descriptive)
```java
@Test
void should_throwException_when_pluginDirectoryNotFound() { }

@Test  
void should_returnEmptyList_when_noPluginsAvailable() { }

@Test
void should_loadPluginsInDependencyOrder_when_multipleDependencies() { }
```

**Option 2: Natural language with @DisplayName** (cleaner code)
```java
@Test
@DisplayName("Should load all plugins from directory")
void loadAllPlugins() { }

@Test
@DisplayName("Should throw exception when plugin descriptor is invalid")
void invalidPluginDescriptor() { }
```


## Test Organization

### Nested tests for clarity
```java
@DisplayName("PluginManager")
class PluginManagerTest {
    
    private PluginManager manager;
    
    @BeforeEach
    void setUp() {
        manager = new DefaultPluginManager();
    }
    
    @Nested
    @DisplayName("when starting plugins")
    class WhenStartingPlugins {
        
        @Test
        @DisplayName("should start all plugins in dependency order")
        void shouldStartInDependencyOrder() {
            // Test implementation
        }
        
        @Test
        @DisplayName("should skip disabled plugins")
        void shouldSkipDisabledPlugins() {
            // Test implementation
        }
        
        @Test
        @DisplayName("should fail if circular dependency detected")
        void shouldFailOnCircularDependency() {
            // Test implementation
        }
    }
    
    @Nested
    @DisplayName("when stopping plugins")  
    class WhenStoppingPlugins {
        
        @Test
        @DisplayName("should stop plugins in reverse dependency order")
        void shouldStopInReverseOrder() {
            // Test implementation
        }
    }
}
```

### Parameterized tests
```java
@ParameterizedTest
@ValueSource(strings = {"1.0.0", "2.1.3", "10.0.0-SNAPSHOT"})
@DisplayName("Should accept valid semantic versions")
void shouldAcceptValidVersions(String version) {
    assertThat(VersionParser.parse(version))
        .isNotNull()
        .hasFieldOrPropertyWithValue("valid", true);
}

@ParameterizedTest
@CsvSource({
    "plugin-a, 1.0, STARTED",
    "plugin-b, 2.0, STOPPED",
    "plugin-c, 1.5, DISABLED"
})
@DisplayName("Should load plugin with expected state")
void shouldLoadPluginWithState(String id, String version, PluginState expectedState) {
    Plugin plugin = createPlugin(id, version);
    
    assertThat(plugin.getState()).isEqualTo(expectedState);
}

@ParameterizedTest
@MethodSource("invalidPluginDescriptors")
@DisplayName("Should reject invalid plugin descriptors")
void shouldRejectInvalidDescriptors(PluginDescriptor descriptor, String expectedError) {
    assertThatThrownBy(() -> validator.validate(descriptor))
        .hasMessageContaining(expectedError);
}

static Stream<Arguments> invalidPluginDescriptors() {
    return Stream.of(
        Arguments.of(descriptorWithoutId(), "Missing plugin ID"),
        Arguments.of(descriptorWithInvalidVersion(), "Invalid version format"),
        Arguments.of(descriptorWithEmptyId(), "Plugin ID cannot be empty")
    );
}
```

