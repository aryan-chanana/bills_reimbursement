package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.dtos.Bill;
import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.dtos.UserResponseDTO;
import com.example.bills_reimbursement.bills_reimbursement.repositories.BillRepository;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/*
    Controller for admin-specific operations like managing users and bills.
*/
@RestController
public class AdminController {

    @Autowired
    private BillRepository billRepository;

    @Autowired
    private UserRepository userRepository;

    @GetMapping("/users")
    public ResponseEntity<List<UserResponseDTO>> getAllUsers() {

        List<User> usersList = userRepository.findAllByOrderByNameAsc();
        if (usersList.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        return ResponseEntity.ok(usersList.stream()
                .map(User::toDto)
                .collect(Collectors.toList()));
    }

    @DeleteMapping("/users/{employeeId}")
    public ResponseEntity<?> deleteUser(@PathVariable Integer employeeId) {
        if (!userRepository.existsById(employeeId)) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "User not found"));
        }
        userRepository.deleteById(employeeId);
        return ResponseEntity.ok(Map.of("message", "User has been deleted"));
    }

    @PutMapping("/users/{employeeId}")
    public ResponseEntity<?> editUser(@RequestBody User updatedUserDetails,
                                      @PathVariable Integer employeeId) {
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
        return ResponseEntity.ok(User.toDto(savedUser));
    }

    @GetMapping("/bills")
    public ResponseEntity<List<Bill>> getAllBills() {
        List<Bill> bills = billRepository.findAllByOrderByDateDesc();
        return ResponseEntity.ok(bills);
    }

    @PutMapping("/bills/{billId}/status")
    public ResponseEntity<?> updateBillStatus(@PathVariable Integer billId,
                                              @RequestBody Map<String, String> statusUpdate) {
        Optional<Bill> billOpt = billRepository.findById(billId);
        if (billOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Bill not found"));
        }

        Bill bill = billOpt.get();

        if ("APPROVED".equalsIgnoreCase(bill.getStatus())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "Cannot change status of an already approved bill"));
        }

        String newStatus = statusUpdate.get("status");
        if (newStatus == null || newStatus.isEmpty()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "Status is required"));
        }

        bill.setStatus(newStatus.toUpperCase());
        billRepository.save(bill);

        return ResponseEntity.ok(Map.of(
                "message", "Bill status updated successfully",
                "billId", bill.getBillId(),
                "status", bill.getStatus()
        ));
    }
}
