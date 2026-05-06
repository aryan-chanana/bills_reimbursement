package com.example.bills_reimbursement.bills_reimbursement.configs;

import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Authenticates Basic-Auth credentials against either the user's password OR
 * the {@code sso_token} (the post-Microsoft-SSO session string). Lets the
 * Flutter client keep using the existing Basic-Auth pipeline for both flows;
 * after a successful SSO sign-in the client simply stores the SSO session
 * string where it would otherwise have stored the password.
 */
@Component
@RequiredArgsConstructor
public class CombinedAuthenticationProvider implements AuthenticationProvider {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public Authentication authenticate(Authentication authentication) throws AuthenticationException {
        String username = authentication.getName();
        String credential = authentication.getCredentials() == null
                ? ""
                : authentication.getCredentials().toString();

        Integer employeeId;
        try {
            employeeId = Integer.parseInt(username);
        } catch (NumberFormatException e) {
            throw new BadCredentialsException("Invalid credentials");
        }

        User user = userRepository.findByEmployeeId(employeeId)
                .orElseThrow(() -> new BadCredentialsException("Invalid credentials"));

        if (user.isDisabled()) {
            throw new DisabledException("Your account has been disabled. Please contact the administrator.");
        }

        boolean passwordMatches = user.getPassword() != null
                && passwordEncoder.matches(credential, user.getPassword());
        boolean ssoMatches = user.getSsoToken() != null
                && passwordEncoder.matches(credential, user.getSsoToken());

        if (!passwordMatches && !ssoMatches) {
            throw new BadCredentialsException("Invalid credentials");
        }

        return new UsernamePasswordAuthenticationToken(user, credential, user.getAuthorities());
    }

    @Override
    public boolean supports(Class<?> authentication) {
        return UsernamePasswordAuthenticationToken.class.isAssignableFrom(authentication);
    }
}
