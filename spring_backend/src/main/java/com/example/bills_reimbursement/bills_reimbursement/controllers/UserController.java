package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.dtos.UserResponseDTO;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import com.example.bills_reimbursement.bills_reimbursement.services.EmailService;
import com.example.bills_reimbursement.bills_reimbursement.services.OtpService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;

@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/users")
public class UserController {

    @Autowired
    private OtpService otpService;

    @Autowired
    private EmailService emailService;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private UserRepository userRepository;

    @PostMapping
    public ResponseEntity<?> createUser(@RequestBody User user) {
        if (userRepository.existsById(user.getEmployeeId())) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("error", "User with this Employee ID already exists."));
        }

        if (!user.getEmail().endsWith("@axeno.co"))
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "Not a valid email address"));

        user.setPassword(passwordEncoder.encode(user.getPassword()));
        user.setApproved(false);
        User savedUser = userRepository.save(user);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("message", "User created successfully", "id", savedUser.getEmployeeId()));
    }

    @GetMapping("/{employeeId}")
    public ResponseEntity<UserResponseDTO> getUser(
            @PathVariable Integer employeeId,
            Authentication authentication) {
        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();
        if (!userDetails.isAdmin() && !loggedInEmployeeId.equals(employeeId)) {
            return ResponseEntity.status(403).build();
        }

        Optional<User> userOpt = userRepository.findByEmployeeId(employeeId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        User user = userOpt.get();
        return ResponseEntity.ok(User.toDto(user));
    }

    @PostMapping("/{employeeId}/send-otp")
    public ResponseEntity<?> sendOtp(
            @PathVariable Integer employeeId,
            @RequestParam String email,
            @RequestParam Boolean signUp) {
        if (signUp) {
            if (userRepository.findByEmail(email).isPresent()) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Email already in use.");
            }
        } else {
            Optional<User> userOpt = userRepository.findByEmployeeId(employeeId);

            if (userOpt.isEmpty()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Employee ID not found.");
            }
            User user = userOpt.get();
            email = user.getEmail();
        }

        String otp = otpService.generateOtp();
        String key = employeeId + (signUp ? "_SIGNUP" : "_RESET");

        // 🚨 RATE LIMIT CHECK
        if (!otpService.canSendOtp(key)) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body("Too many OTP requests. Please try again later.");
        }

        otpService.saveOtp(key, otp);
        emailService.sendOtp(email, otp);

        return ResponseEntity.ok("OTP sent.");
    }

    @PostMapping("/{employeeId}/verify-otp")
    public ResponseEntity<?> verifyOtp(
            @PathVariable Integer employeeId,
            @RequestParam String otp,
            @RequestParam Boolean signUp) {

        String key = employeeId + (signUp ? "_SIGNUP" : "_RESET");

        if (!signUp) {
            Optional<User> userOpt = userRepository.findByEmployeeId(employeeId);
            if (userOpt.isEmpty()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Employee ID not found.");
            }
        }

        if (otpService.validateOtp(key, otp)) {
            return ResponseEntity.ok("OTP Verified.");
        }

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Invalid or expired OTP.");
    }

    @PostMapping("/{employeeId}/update-password")
    public ResponseEntity<?> updatePassword(
            @PathVariable Integer employeeId,
            @RequestParam String newPassword) {

        String key = employeeId + "_RESET";

        if (!otpService.isVerified(key)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body("OTP verification required.");
        }

        Optional<User> userOpt = userRepository.findByEmployeeId(employeeId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Employee ID not found.");
        }

        User user = userOpt.get();
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        otpService.clearVerification(key);

        return ResponseEntity.ok("Password updated successfully.");
    }
}