# Security Considerations for Peek

## Current Security Posture

Peek implements several security measures to protect users:

### ✅ Implemented Protections

1. **URL Validation & Whitelisting**
   - Only HTTPS URLs are allowed
   - Trusted domain allowlist for meeting platforms
   - Location: `MenuBarView.swift:379-409`

2. **Input Sanitization**
   - Dangerous characters removed from user input
   - Length limits prevent buffer overflows
   - Location: `MenuBarView.swift:472-482`

3. **ReDoS Protection**
   - Input length limits for regex operations
   - Uses efficient regex matching methods
   - Location: `MenuBarView.swift:340-344`

4. **Calendar Permissions**
   - Requests minimal required permissions
   - Uses EventKit framework (sandboxed by macOS)

## ⚠️ Known Security Issues

### 1. Notification URL Handling (Medium Priority)

**Issue**: NotificationManager opens URLs without validation when user clicks "Join Meeting" in notification.

**Location**: `NotificationManager.swift:191-195`

**Risk**: If calendar data is compromised, malicious URLs could be opened.

**Current Code**:
```swift
case "JOIN_MEETING":
    if let urlString = userInfo["meetingURL"] as? String,
       let url = URL(string: urlString) {
        NSWorkspace.shared.open(url)  // ⚠️ No validation!
    }
```

**Recommended Fix**:
```swift
case "JOIN_MEETING":
    if let urlString = userInfo["meetingURL"] as? String,
       let url = URL(string: urlString),
       isURLSafe(url) {  // Add validation
        NSWorkspace.shared.open(url)
    }
```

### 2. Calendar Data Trust (Low Priority)

**Issue**: App trusts all calendar data from macOS Calendar.

**Risk**: If user's calendar account is compromised, malicious data could be injected.

**Mitigation**: macOS Calendar is the source of truth - this is by design. Users should secure their calendar accounts with strong passwords and 2FA.

## 🔐 Security Best Practices (Already Followed)

1. **No Network Requests** - App doesn't make any network calls
2. **No Data Collection** - No analytics or telemetry
3. **Local-Only** - All data stays on user's device
4. **Sandboxed** - Uses macOS security frameworks
5. **No Root Access** - Runs with user permissions only
6. **No Keychain Access** - Doesn't store credentials

## 🛡️ Additional Recommendations

### For Users

1. **Calendar Account Security**
   - Use strong, unique passwords for calendar accounts
   - Enable 2FA on Google, Microsoft, iCloud accounts
   - Be cautious when accepting calendar invitations from unknown senders
   - Review calendar permissions regularly in System Settings

2. **First Installation**
   - Only download from trusted sources (your GitHub releases)
   - Verify the app is signed (if distributed with Developer ID)
   - Review calendar permissions when prompted

### For Distribution

1. **Code Signing** (Recommended)
   - Sign with Developer ID certificate
   - Enables Gatekeeper protection
   - Users see verified developer name

2. **Notarization** (Recommended)
   - Submit to Apple for automated security scan
   - Prevents malware distribution
   - No Gatekeeper warnings for users

3. **Hardened Runtime** (Optional)
   - Enable in Xcode build settings
   - Adds additional runtime protections
   - Required for notarization

## 🚨 What to Report

If you discover a security vulnerability:

1. **DO NOT** create a public GitHub issue
2. **DO** email security concerns privately to the maintainer
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## 📋 Security Checklist for Contributors

Before submitting code:

- [ ] No new network requests without explicit user consent
- [ ] All URLs validated against whitelist
- [ ] User input sanitized before use
- [ ] No storage of sensitive data
- [ ] Calendar permissions remain minimal
- [ ] No new dependencies without security review
- [ ] Error messages don't leak sensitive information
- [ ] Regex patterns protected against ReDoS

## 🔍 Security Audit Log

| Date | Issue | Severity | Status |
|------|-------|----------|--------|
| 2026-01-23 | Initial security review | - | Complete |
| 2026-01-23 | Notification URL validation missing | Medium | Identified |

## 📚 Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Apple Platform Security Guide](https://support.apple.com/guide/security/welcome/web)
- [Swift Security Best Practices](https://developer.apple.com/documentation/security)
