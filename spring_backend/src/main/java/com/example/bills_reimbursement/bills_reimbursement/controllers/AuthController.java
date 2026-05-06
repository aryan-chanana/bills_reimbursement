package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.configs.MicrosoftSsoProperties;
import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.services.MicrosoftSsoService;
import com.example.bills_reimbursement.bills_reimbursement.services.MicrosoftSsoService.SsoOutcome;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private static final Logger log = LoggerFactory.getLogger(AuthController.class);

    private final MicrosoftSsoService microsoftSsoService;
    private final MicrosoftSsoProperties ssoProperties;

    public record MicrosoftSsoRequest(String idToken) {}

    /**
     * Validates a Microsoft Azure AD ID token and, if it maps to an approved
     * local user, returns the user's profile alongside an opaque session
     * credential the client can use as a Basic-Auth password from then on.
     */
    @PostMapping("/microsoft")
    public ResponseEntity<?> signInWithMicrosoft(@RequestBody MicrosoftSsoRequest body) {
        if (body == null || body.idToken() == null || body.idToken().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "idToken is required"));
        }

        SsoOutcome outcome;
        try {
            outcome = microsoftSsoService.signIn(body.idToken());
        } catch (IllegalStateException e) {
            log.error("Microsoft SSO is not configured: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(Map.of("error", "Microsoft sign-in is not configured on the server."));
        } catch (Exception e) {
            log.warn("Microsoft SSO token validation failed", e);
            String detail = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "Invalid or expired Microsoft sign-in token: " + detail));
        }

        return switch (outcome.kind()) {
            case SUCCESS -> {
                User user = outcome.user();
                yield ResponseEntity.ok(Map.of(
                        "user", User.toDto(user),
                        "ssoCredential", outcome.ssoCredential()
                ));
            }
            case NOT_OFFICIAL_ACCOUNT -> {
                String domain = ssoProperties.getAllowedEmailDomain();
                String hint = (domain != null && !domain.isBlank())
                        ? " Please sign in with your official @" + domain + " account."
                        : " Please sign in with your official work account.";
                yield ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(Map.of("error", "This account is not allowed." + hint));
            }
            case NOT_REGISTERED -> ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of(
                            "error",
                            "No account is linked to " + outcome.email() + ". Ask your admin to add you first."
                    ));
            case NOT_APPROVED -> ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "Your account is pending admin approval."));
            case DISABLED -> ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "Your account has been disabled. Please contact the administrator."));
        };
    }
}
