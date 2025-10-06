package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.dtos.UserResponseDTO;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/users")
public class UserController {

    @Autowired
    private UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<UserResponseDTO>> getAllUsers() {
        List<UserResponseDTO> usersDto = userRepository.findAllByOrderByNameAsc()
                .stream()
                .map(this::toDto)
                .collect(Collectors.toList());
        return ResponseEntity.ok(usersDto);
    }

    @GetMapping("/{employeeId}")
    public ResponseEntity<UserResponseDTO> getUser(@PathVariable Integer employeeId, Authentication authentication) {
        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();

        if (!userDetails.isAdmin() && !loggedInEmployeeId.equals(employeeId)) {
            return ResponseEntity.status(403).build();
        }

        return userRepository.findByEmployeeId(employeeId)
                .map(this::toDto)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
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

    @PutMapping("/{employeeId}")
    public ResponseEntity<?> editUser(@RequestBody User updatedUserDetails, @PathVariable Integer employeeId) {
        Optional<User> existingUserOpt = userRepository.findByEmployeeId(employeeId);

        if (existingUserOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "User not found"));
        }

        User existingUser = existingUserOpt.get();
        existingUser.setName(updatedUserDetails.getName());
        existingUser.setPassword(updatedUserDetails.getPassword());

        if (!updatedUserDetails.getEmployeeId().equals(employeeId)) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "User id mismatch"));
        }

        User savedUser = userRepository.save(existingUser);
        return ResponseEntity.ok(toDto(savedUser));
    }

    @DeleteMapping("/{employeeId}")
    public ResponseEntity<?> deleteUser(@PathVariable Integer employeeId) {
        if (!userRepository.existsById(employeeId)) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "User not found"));
        }
        userRepository.deleteById(employeeId);
        return ResponseEntity.ok(Map.of("message", "User has been deleted"));
    }


    // use this for all
    public UserResponseDTO toDto(User user) {
        UserResponseDTO userResponseDTO = new UserResponseDTO();
        userResponseDTO.setEmployeeId(user.getEmployeeId());
        userResponseDTO.setName(user.getName());
        userResponseDTO.setAdmin(user.isAdmin());
        return userResponseDTO;
    }
}