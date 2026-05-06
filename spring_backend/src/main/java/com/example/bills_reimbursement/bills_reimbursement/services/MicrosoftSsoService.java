package com.example.bills_reimbursement.bills_reimbursement.services;

import com.example.bills_reimbursement.bills_reimbursement.configs.MicrosoftSsoProperties;
import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import com.nimbusds.jose.proc.SecurityContext;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.proc.ConfigurableJWTProcessor;
import com.nimbusds.jwt.proc.DefaultJWTClaimsVerifier;
import com.nimbusds.jwt.proc.DefaultJWTProcessor;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.jwk.source.JWKSourceBuilder;
import com.nimbusds.jose.proc.JWSKeySelector;
import com.nimbusds.jose.proc.JWSVerificationKeySelector;
import com.nimbusds.jose.JWSAlgorithm;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URL;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Validates Microsoft Azure AD ID tokens against the tenant's JWKS, links
 * them to a local {@link User}, and issues an opaque session string the
 * client can use as a Basic-Auth password from then on.
 */
@Service
@RequiredArgsConstructor
public class MicrosoftSsoService {

    private static final Logger log = LoggerFactory.getLogger(MicrosoftSsoService.class);

    private final MicrosoftSsoProperties properties;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    private volatile ConfigurableJWTProcessor<SecurityContext> jwtProcessor;

    public enum OutcomeKind { SUCCESS, NOT_OFFICIAL_ACCOUNT, NOT_REGISTERED, NOT_APPROVED, DISABLED }

    /**
     * Result of looking up the SSO user. Caller maps {@link OutcomeKind}
     * values to HTTP statuses (NOT_OFFICIAL_ACCOUNT → 403, NOT_REGISTERED →
     * 404, NOT_APPROVED → 403, DISABLED → 403). On SUCCESS the {@code user}
     * and {@code ssoCredential} fields are populated; otherwise only
     * {@code email} is populated.
     */
    public record SsoOutcome(OutcomeKind kind, User user, String ssoCredential, String email) {
        public static SsoOutcome success(User u, String cred) {
            return new SsoOutcome(OutcomeKind.SUCCESS, u, cred, u.getEmail());
        }
        public static SsoOutcome notOfficialAccount(String email) {
            return new SsoOutcome(OutcomeKind.NOT_OFFICIAL_ACCOUNT, null, null, email);
        }
        public static SsoOutcome notRegistered(String email) {
            return new SsoOutcome(OutcomeKind.NOT_REGISTERED, null, null, email);
        }
        public static SsoOutcome notApproved(String email) {
            return new SsoOutcome(OutcomeKind.NOT_APPROVED, null, null, email);
        }
        public static SsoOutcome disabled(String email) {
            return new SsoOutcome(OutcomeKind.DISABLED, null, null, email);
        }
    }

    @Transactional
    public SsoOutcome signIn(String idToken) throws Exception {
        JWTClaimsSet claims = validateAndExtractClaims(idToken);

        log.info(
                "SSO token validated: email={}, name={}, preferred_username={}, "
                        + "oid={}, tid={}, sub={}, iss={}, aud={}, "
                        + "issued_at={}, expires_at={}, "
                        + "groups={}, roles={}, wids={}",
                claims.getClaim("email"),
                claims.getClaim("name"),
                claims.getClaim("preferred_username"),
                claims.getClaim("oid"),
                claims.getClaim("tid"),
                claims.getSubject(),
                claims.getIssuer(),
                claims.getAudience(),
                claims.getIssueTime(),
                claims.getExpirationTime(),
                claims.getClaim("groups"),
                claims.getClaim("roles"),
                claims.getClaim("wids"));

        // Cross-validate iss vs tid so a token from a tenant we didn't expect
        // can't impersonate one we do — applies to both single- and
        // multi-tenant modes (defence in depth).
        String tid = (String) claims.getClaim("tid");
        String iss = claims.getIssuer();
        if (tid == null || iss == null
                || !iss.equals("https://login.microsoftonline.com/" + tid + "/v2.0")) {
            throw new IllegalArgumentException("Token issuer does not match its tenant claim.");
        }

        // Multi-tenant allowlist: when configured, only accept tokens whose
        // tid is in the list. In single-tenant mode the JWT processor
        // already enforces the issuer, so this list is optional but harmless.
        List<String> allowedTids = properties.getAllowedTenantIds();
        if (allowedTids != null && !allowedTids.isEmpty() && !allowedTids.contains(tid)) {
            // Token came from a tenant we don't accept — almost always a
            // personal Microsoft Account (MSA tenant 9188040d-…) or someone
            // signing in from another organisation.
            return SsoOutcome.notOfficialAccount(extractEmailOrEmpty(claims));
        }

        String email = extractEmail(claims);
        if (email == null || email.isBlank()) {
            throw new IllegalArgumentException("Token did not contain an email or preferred_username claim.");
        }

        if (properties.getAllowedEmailDomain() != null
                && !properties.getAllowedEmailDomain().isBlank()
                && !email.toLowerCase().endsWith("@" + properties.getAllowedEmailDomain().toLowerCase())) {
            return SsoOutcome.notOfficialAccount(email);
        }

        Optional<User> maybeUser = userRepository.findByEmailIgnoreCase(email.trim());
        if (maybeUser.isEmpty()) return SsoOutcome.notRegistered(email);

        User user = maybeUser.get();
        if (user.isDisabled()) return SsoOutcome.disabled(email);
        if (!user.isApproved()) return SsoOutcome.notApproved(email);

        warnIfAdminMismatch(claims, user);

        String credential = generateOpaqueCredential();
        user.setSsoToken(passwordEncoder.encode(credential));
        userRepository.save(user);

        return SsoOutcome.success(user, credential);
    }

    /**
     * Compares the token's admin signal (either an app role name or a group
     * object ID, whichever is configured) with the local user's
     * {@code is_admin} flag and logs a warning on mismatch. Observation
     * only — neither the response nor the DB row is changed. Skipped
     * silently when no admin signal is configured.
     */
    private void warnIfAdminMismatch(JWTClaimsSet claims, User user) {
        Boolean tokenSaysAdmin = null;

        String roleName = properties.getAdminRoleName();
        if (roleName != null && !roleName.isBlank()) {
            Object rolesClaim = claims.getClaim("roles");
            tokenSaysAdmin = rolesClaim instanceof List<?> list
                    && list.contains(roleName);
        }

        String groupId = properties.getAdminGroupId();
        if (tokenSaysAdmin == null && groupId != null && !groupId.isBlank()) {
            Object groupsClaim = claims.getClaim("groups");
            tokenSaysAdmin = groupsClaim instanceof List<?> list
                    && list.contains(groupId);
        }

        if (tokenSaysAdmin != null && tokenSaysAdmin != user.isAdmin()) {
            log.warn(
                    "Admin status mismatch for {}: token says admin={}, DB says admin={}",
                    user.getEmail(), tokenSaysAdmin, user.isAdmin());
        }
    }

    private JWTClaimsSet validateAndExtractClaims(String idToken) throws Exception {
        ConfigurableJWTProcessor<SecurityContext> processor = jwtProcessorOrInit();

        // Caller provides a JWT; processor validates signature against JWKS,
        // expiry, issuer, and audience.
        return processor.process(idToken, null);
    }

    private ConfigurableJWTProcessor<SecurityContext> jwtProcessorOrInit() throws Exception {
        ConfigurableJWTProcessor<SecurityContext> existing = this.jwtProcessor;
        if (existing != null) return existing;

        synchronized (this) {
            if (this.jwtProcessor != null) return this.jwtProcessor;

            String tenant = properties.getTenantId();
            String audience = properties.getClientId();
            if (tenant == null || tenant.isBlank() || audience == null || audience.isBlank()) {
                throw new IllegalStateException(
                        "microsoft.sso.tenant-id and microsoft.sso.client-id must be set in application.properties");
            }

            boolean multiTenant = "common".equalsIgnoreCase(tenant)
                    || "organizations".equalsIgnoreCase(tenant);

            ConfigurableJWTProcessor<SecurityContext> p = new DefaultJWTProcessor<>();
            // JWKS for "common" works for all tenants — Microsoft signs tokens
            // with the same key set across the v2.0 endpoint.
            URL jwks = new URL("https://login.microsoftonline.com/" + tenant + "/discovery/v2.0/keys");
            JWKSource<SecurityContext> keySource = JWKSourceBuilder
                    .<SecurityContext>create(jwks)
                    .build();
            JWSKeySelector<SecurityContext> keySelector = new JWSVerificationKeySelector<>(JWSAlgorithm.RS256, keySource);
            p.setJWSKeySelector(keySelector);

            Set<String> requiredClaims = new HashSet<>(Set.of("sub", "iss", "aud", "exp", "tid"));
            if (multiTenant) {
                // Issuer varies by tenant in this mode; cross-validate
                // post-hoc in signIn() instead.
                p.setJWTClaimsSetVerifier(new DefaultJWTClaimsVerifier<>(
                        audience, null, requiredClaims));
            } else {
                String expectedIssuer = "https://login.microsoftonline.com/" + tenant + "/v2.0";
                p.setJWTClaimsSetVerifier(new DefaultJWTClaimsVerifier<>(
                        audience,
                        new JWTClaimsSet.Builder().issuer(expectedIssuer).build(),
                        requiredClaims));
            }

            this.jwtProcessor = p;
            return p;
        }
    }

    private String extractEmailOrEmpty(JWTClaimsSet claims) {
        String email = extractEmail(claims);
        return email == null ? "" : email;
    }

    private String extractEmail(JWTClaimsSet claims) {
        // Azure AD typically populates "email" for personal accounts and
        // "preferred_username" for work/school accounts. Try both.
        String email = (String) claims.getClaim("email");
        if (email == null || email.isBlank()) {
            email = (String) claims.getClaim("preferred_username");
        }
        return email == null ? null : email.toLowerCase();
    }

    private String generateOpaqueCredential() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
