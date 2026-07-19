# Test Patterns, Coverage & Anti-patterns

Reference for [test-authoring](../SKILL.md). Mocking/fixtures/async patterns, incremental
token-efficient test writing, coverage targets, common anti-patterns to avoid, and JaCoCo setup.

## Common Patterns

### Testing with mocks (Mockito)
```java
@ExtendWith(MockitoExtension.class)
class PluginManagerTest {
    
    @Mock
    private PluginRepository repository;
    
    @Mock
    private PluginValidator validator;
    
    @InjectMocks
    private DefaultPluginManager manager;
    
    @Test
    @DisplayName("Should load plugins from repository")
    void shouldLoadPluginsFromRepository() {
        // Given
        List<PluginDescriptor> descriptors = List.of(
            createDescriptor("plugin1"),
            createDescriptor("plugin2")
        );
        when(repository.findAll()).thenReturn(descriptors);
        
        // When
        List<Plugin> plugins = manager.loadAll();
        
        // Then
        assertThat(plugins).hasSize(2);
        verify(repository).findAll();
        verify(validator, times(2)).validate(any(PluginDescriptor.class));
    }
}
```

### Test fixtures with @BeforeEach
```java
@BeforeEach
void setUp() throws IOException {
    // Create temporary directory for test plugins
    pluginDir = Files.createTempDirectory("test-plugins");
    
    // Initialize plugin manager with test config
    PluginConfig config = PluginConfig.builder()
        .pluginDirectory(pluginDir)
        .enableValidation(true)
        .build();
    
    pluginManager = new DefaultPluginManager(config);
}

@AfterEach
void tearDown() throws IOException {
    // Clean up test resources
    if (pluginManager != null) {
        pluginManager.stopAll();
    }
    if (pluginDir != null) {
        FileUtils.deleteDirectory(pluginDir.toFile());
    }
}
```

### Testing async operations
```java
@Test
@DisplayName("Should complete async plugin loading")
void shouldCompleteAsyncLoading() {
    CompletableFuture<Plugin> future = manager.loadAsync(pluginPath);
    
    assertThat(future)
        .succeedsWithin(Duration.ofSeconds(5))
        .satisfies(plugin -> {
            assertThat(plugin.getState()).isEqualTo(PluginState.STARTED);
            assertThat(plugin.getId()).isNotBlank();
        });
}
```


## Token Optimization

When writing tests:

### 1. Generate test skeleton first
```java
// Phase 1: List test cases as comments
// @Test void shouldLoadPlugin() { }
// @Test void shouldThrowExceptionForInvalidPlugin() { }
// @Test void shouldHandleMissingDependencies() { }
```

### 2. Implement incrementally
- One test at a time
- Verify compilation after each
- Run tests to validate
- Refactor if needed

### 3. Reuse patterns
```java
// Extract common setup to helper methods
private Plugin createTestPlugin(String id, String version) {
    return Plugin.builder()
        .id(id)
        .version(version)
        .build();
}
```


## Code Coverage Guidelines

- **Aim for**: 80%+ line coverage on core logic
- **Focus on**: Business logic, complex algorithms, edge cases
- **Skip**: Trivial getters/setters, POJOs, generated code
- **Test**: Happy paths + error conditions + boundary cases

### What to test
✅ **High priority**:
- Public APIs
- Complex business logic
- Error handling
- Edge cases and boundaries
- Integration points

❌ **Low priority**:
```java
// Simple getters/setters
public String getId() { return id; }
public void setId(String id) { this.id = id; }

// Simple POJOs with no logic
public class PluginInfo {
    private String id;
    private String version;
    // ... only getters/setters
}
```


## Anti-patterns

❌ **Avoid**:
```java
// 1. Generic test names
@Test void test1() { }
@Test void testPlugin() { }

// 2. Testing implementation details
assertThat(plugin.internalState.flag).isTrue(); // Couples to internals

// 3. Brittle assertions with timestamps
assertThat(message).isEqualTo("Error at 2024-01-26 10:30:15");

// 4. Multiple unrelated assertions
@Test void testEverything() {
    // 50 unrelated assertions
    assertThat(plugin.getId()).isNotNull();
    assertThat(manager.getCount()).isEqualTo(5);
    assertThat(config.isEnabled()).isTrue();
    // ... mixing multiple concerns
}

// 5. Ignoring exceptions
@Test void shouldFail() {
    try {
        loader.load(invalidPath);
        fail("Should have thrown exception");
    } catch (Exception e) {
        // Swallowing exception details
    }
}
```

✅ **Prefer**:
```java
@Test
@DisplayName("Should reject plugin with missing dependencies")
void shouldRejectPluginWithMissingDependencies() {
    PluginDescriptor descriptor = PluginDescriptor.builder()
        .id("test-plugin")
        .dependencies(List.of("missing-dep"))
        .build();
    
    assertThatThrownBy(() -> manager.load(descriptor))
        .isInstanceOf(PluginException.class)
        .hasMessageContaining("Missing dependencies: missing-dep");
}
```


## Integration with Coverage Tools

### Maven configuration
```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>test</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

### After test generation, suggest:
```bash
# Run tests with coverage
mvn clean test jacoco:report

# View coverage report
open target/site/jacoco/index.html

# Check coverage threshold
mvn verify # Fails if below configured threshold
```

