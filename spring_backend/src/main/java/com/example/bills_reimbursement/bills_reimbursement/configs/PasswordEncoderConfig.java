package com.example.bills_reimbursement.bills_reimbursement.configs;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Lives outside SecurityConfig so {@link CombinedAuthenticationProvider}
 * (which needs the encoder) doesn't form a circular dependency with the
 * security configuration that consumes it.
 */
@Configuration
public class PasswordEncoderConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
