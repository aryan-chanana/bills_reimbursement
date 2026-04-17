package com.example.bills_reimbursement.bills_reimbursement.configs;

import com.example.bills_reimbursement.bills_reimbursement.services.CustomUserDetailsService;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final CustomUserDetailsService customUserDetailsService;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(HttpSecurity http) throws Exception {
        AuthenticationManagerBuilder authenticationManagerBuilder =
                http.getSharedObject(AuthenticationManagerBuilder.class);
        authenticationManagerBuilder
                .userDetailsService(customUserDetailsService)
                .passwordEncoder(passwordEncoder());
        return authenticationManagerBuilder.build();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(AbstractHttpConfigurer::disable)
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/users").permitAll() // registration
                        .requestMatchers(HttpMethod.POST, "/users/*/send-otp").permitAll()
                        .requestMatchers(HttpMethod.POST, "/users/*/verify-otp").permitAll()
                        .requestMatchers(HttpMethod.POST, "/users/*/update-password").permitAll()

                        // check server connection
                        .requestMatchers(HttpMethod.GET, "/admin/ping").permitAll()

                        // 👇 Authenticated users can manage their own bills
                        .requestMatchers("/users/*/bills/**").authenticated()

                        // 👇 Admin-only access for user management
                        .requestMatchers(HttpMethod.GET, "/admin/bills").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/admin/bills/*/status").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.GET, "/admin/users").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/admin/users/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.PATCH, "/admin/users/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.DELETE, "/admin/users/**").hasRole("ADMIN")

                        // 👇 Fallback
                        .anyRequest().authenticated()
                )
                .httpBasic(basic -> basic.authenticationEntryPoint((request, response, authException) -> {
                    response.setContentType("application/json");
                    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    String message = (authException.getCause() instanceof DisabledException || authException instanceof DisabledException)
                            ? "Your account has been disabled. Please contact the administrator."
                            : "Invalid credentials";
                    response.getWriter().write("{\"error\": \"" + message + "\"}");
                }));

        return http.build();
    }

    @Bean
    public org.springframework.web.cors.CorsConfigurationSource corsConfigurationSource() {
        org.springframework.web.cors.CorsConfiguration configuration = new org.springframework.web.cors.CorsConfiguration();

        configuration.setAllowedOriginPatterns(java.util.List.of("*"));
        configuration.setAllowedMethods(java.util.List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(java.util.List.of("*"));
        configuration.setAllowCredentials(false);

        org.springframework.web.cors.UrlBasedCorsConfigurationSource source =
                new org.springframework.web.cors.UrlBasedCorsConfigurationSource();

        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
