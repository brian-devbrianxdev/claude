# Auth, Secrets, Logging & Dependency Security

Reference for [security-review](../SKILL.md). Identity and operational-hygiene concerns:
who's allowed to do what, where secrets live, what never gets logged, and keeping
dependencies free of known CVEs.

## Authentication & Authorization

### Password Storage

```java
// ✅ GOOD: Use BCrypt or Argon2
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;

// BCrypt (widely supported)
PasswordEncoder encoder = new BCryptPasswordEncoder(12);  // strength 12
String hash = encoder.encode(rawPassword);
boolean matches = encoder.matches(rawPassword, hash);

// Argon2 (recommended for new projects)
PasswordEncoder encoder = Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
String hash = encoder.encode(rawPassword);

// ❌ BAD: MD5, SHA1, SHA256 without salt
String hash = DigestUtils.md5Hex(password);  // NEVER for passwords!
```

### Authorization Checks

```java
// ✅ GOOD: Check authorization at service layer
@Service
public class DocumentService {

    public Document getDocument(Long documentId, User currentUser) {
        Document doc = documentRepository.findById(documentId)
            .orElseThrow(() -> new NotFoundException("Document not found"));

        // Authorization check
        if (!doc.getOwnerId().equals(currentUser.getId()) &&
            !currentUser.hasRole("ADMIN")) {
            throw new AccessDeniedException("Not authorized to access this document");
        }

        return doc;
    }
}

// ❌ BAD: Only check at controller level, trust user input
@GetMapping("/documents/{id}")
public Document getDocument(@PathVariable Long id) {
    return documentRepository.findById(id).orElseThrow();  // No auth check!
}
```

### Spring Security Annotations

```java
@PreAuthorize("hasRole('ADMIN')")
public void adminOnly() { }

@PreAuthorize("hasRole('USER') and #userId == authentication.principal.id")
public void ownDataOnly(Long userId) { }

@PreAuthorize("@authService.canAccess(#documentId, authentication)")
public Document getDocument(Long documentId) { }
```

## Secrets Management

### Never Hardcode Secrets

```java
// ❌ BAD: Hardcoded secrets
private static final String API_KEY = "sk-1234567890abcdef";
private static final String DB_PASSWORD = "admin123";

// ✅ GOOD: Environment variables
String apiKey = System.getenv("API_KEY");

// ✅ GOOD: External configuration
@Value("${api.key}")
private String apiKey;

// ✅ GOOD: Secrets manager
@Autowired
private SecretsManager secretsManager;
String apiKey = secretsManager.getSecret("api-key");
```

### Configuration Files

```yaml
# ✅ GOOD: Reference environment variables
spring:
  datasource:
    password: ${DB_PASSWORD}

api:
  key: ${API_KEY}

# ❌ BAD: Hardcoded in application.yml
spring:
  datasource:
    password: admin123  # NEVER!
```

### .gitignore

```gitignore
# Never commit these
.env
*.pem
*.key
*credentials*
*secret*
application-local.yml
```

## Logging Security Events

```java
// ✅ Log security-relevant events
log.info("User login successful", kv("userId", userId), kv("ip", clientIp));
log.warn("Failed login attempt", kv("username", username), kv("ip", clientIp), kv("attempt", attemptCount));
log.warn("Access denied", kv("userId", userId), kv("resource", resourceId), kv("action", action));
log.error("Authentication failure", kv("reason", reason), kv("ip", clientIp));

// ❌ NEVER log sensitive data
log.info("Login: user={}, password={}", username, password);  // NEVER!
log.debug("Request body: {}", requestWithCreditCard);  // NEVER!
```

## Dependency Security

### OWASP Dependency Check

**Maven:**
```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>9.0.7</version>
    <executions>
        <execution>
            <goals>
                <goal>check</goal>
            </goals>
        </execution>
    </executions>
    <configuration>
        <failBuildOnCVSS>7</failBuildOnCVSS>  <!-- Fail on high severity -->
    </configuration>
</plugin>
```

**Run:**
```bash
mvn dependency-check:check
# Report: target/dependency-check-report.html
```

### Keep Dependencies Updated

```bash
# Check for updates
mvn versions:display-dependency-updates

# Update to latest
mvn versions:use-latest-releases
```
