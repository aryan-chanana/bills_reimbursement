package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.dtos.UserResponseDTO;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;

/*
    Controller for user-specific operations like retrieving and creating users.
*/
@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/users")
public class UserController {

    @Autowired
    private UserRepository userRepository;

    @GetMapping("/{employeeId}")
    public ResponseEntity<UserResponseDTO> getUser(@PathVariable Integer employeeId, Authentication authentication) {
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

    @PostMapping
    public ResponseEntity<?> createUser(@RequestBody User user) {
        if (userRepository.existsById(user.getEmployeeId())) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("error", "User with this Employee ID already exists."));
        }

        User savedUser = userRepository.save(user);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("message", "User created successfully", "id", savedUser.getEmployeeId()));
    }
}