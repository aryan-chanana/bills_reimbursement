package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.dtos.Bill;
import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.dtos.UserResponseDTO;
import com.example.bills_reimbursement.bills_reimbursement.repositories.BillRepository;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import com.example.bills_reimbursement.bills_reimbursement.services.DataCleanupScheduler;
import com.example.bills_reimbursement.bills_reimbursement.services.EmailService;
import com.example.bills_reimbursement.bills_reimbursement.services.FCMService;
import com.example.bills_reimbursement.bills_reimbursement.services.FileStorageService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/admin")
public class AdminController {

    @Autowired
    private BillRepository billRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private FileStorageService fileStorageService;

    @Autowired
    private DataCleanupScheduler dataCleanupScheduler;

    @Autowired
    private EmailService emailService;

    @Autowired
    private FCMService fcmService;

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
        Optional<User> userOpt = userRepository.findByEmployeeId(employeeId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "User not found"));
        }

        // Delete all uploaded files for this user's bills
        List<Bill> bills = billRepository.findAllByUser_EmployeeIdOrderByDateDesc(employeeId);
        for (Bill bill : bills) {
            fileStorageService.deleteFile(bill.getBillImagePath());
            fileStorageService.deleteFile(bill.getApprovalMailPath());
            fileStorageService.deleteFile(bill.getPaymentProofPath());
        }

        // Delete bills then user
        billRepository.deleteAll(bills);
        userRepository.deleteById(employeeId);

        return ResponseEntity.ok(Map.of("message", "User and all associated data deleted"));
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

        String newStatus = statusUpdate.get("status");
        String remarks = statusUpdate.get("remarks");
        if (newStatus == null || newStatus.isEmpty()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "Status is required"));
        }

        Bill bill = billOpt.get();

        if (!bill.getStatus().equalsIgnoreCase("APPROVED") && newStatus.equalsIgnoreCase("PAID")) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "Cannot pay an unapproved bill"));
        }

        if ("PAID".equalsIgnoreCase(bill.getStatus())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "Cannot change status of an already paid bill"));
        }

        bill.setStatus(newStatus.toUpperCase());
        bill.setRemarks(remarks);
        billRepository.save(bill);

        String category = bill.getReimbursementFor();
        String amt = String.format("%.2f", bill.getAmount());

        userRepository.findByEmployeeId(bill.getOwnerId()).ifPresent(owner -> {
            if ("REJECTED".equalsIgnoreCase(newStatus)) {
                String remark = (remarks != null && !remarks.isBlank()) ? remarks : "No remarks provided";
                fcmService.sendNotification(owner.getFcmToken(), "Bill Rejected ❌",
                        "Your ₹" + amt + " " + category + " bill was rejected. Remarks: " + remark);
            } else if ("PAID".equalsIgnoreCase(newStatus)) {
                fcmService.sendNotification(owner.getFcmToken(), "Bill Paid ✅",
                        "Your ₹" + amt + " " + category + " bill has been marked as paid.");
            }
        });

        return ResponseEntity.ok(Map.of(
                "message", "Bill status updated successfully",
                "billId", bill.getBillId(),
                "status", bill.getStatus()
        ));
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

        if (!updatedUserDetails.getEmployeeId().equals(employeeId)) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "User id mismatch"));
        }

        boolean wasApproved = existingUser.isApproved();

        if (updatedUserDetails.getName() != null && !updatedUserDetails.getName().isEmpty())
            existingUser.setName(updatedUserDetails.getName());
        if (updatedUserDetails.getEmail() != null && !updatedUserDetails.getEmail().isEmpty()) {
            if (updatedUserDetails.getEmail().endsWith("@axeno.co"))
                existingUser.setEmail(updatedUserDetails.getEmail());
            else
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(Map.of("error", "Not a valid email address"));
        }
        existingUser.setApproved(updatedUserDetails.isApproved());

        User savedUser = userRepository.save(existingUser);

        if (!wasApproved && savedUser.isApproved()) {
            fcmService.sendNotification(savedUser.getFcmToken(), "Account Approved 🎉",
                    "Your account has been approved. You can now submit reimbursement bills.");
        }

        return ResponseEntity.ok(User.toDto(savedUser));
    }

    @PatchMapping("/users/{employeeId}/disable")
    public ResponseEntity<?> setUserDisabled(@PathVariable Integer employeeId,
                                             @RequestBody Map<String, Boolean> body) {
        Optional<User> userOpt = userRepository.findByEmployeeId(employeeId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "User not found"));
        }

        Boolean disabled = body.get("disabled");
        if (disabled == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "'disabled' field is required"));
        }

        User user = userOpt.get();
        user.setDisabled(disabled);
        userRepository.save(user);

        if (disabled) {
            fcmService.sendNotification(user.getFcmToken(), "Account Disabled",
                    "Your account has been disabled by the admin. Please contact your administrator.");
        }

        String action = disabled ? "disabled" : "enabled";
        return ResponseEntity.ok(Map.of("message", "User has been " + action));
    }

    @GetMapping("/bills/cleanup/count")
    public ResponseEntity<?> getOldBillsCount() {
        LocalDate cutoff = getCleanupCutoff();
        int count = billRepository.countByCreatedAtBefore(cutoff);
        return ResponseEntity.ok(Map.of("count", count, "cutoffDate", cutoff.toString()));
    }

    @DeleteMapping("/bills/cleanup")
    public ResponseEntity<?> deleteOldBills() {
        LocalDate cutoff = getCleanupCutoff();
        List<Bill> oldBills = billRepository.findAllByCreatedAtBefore(cutoff);

        for (Bill bill : oldBills) {
            fileStorageService.deleteFile(bill.getBillImagePath());
            fileStorageService.deleteFile(bill.getApprovalMailPath());
            fileStorageService.deleteFile(bill.getPaymentProofPath());
        }

        billRepository.deleteAll(oldBills);
        return ResponseEntity.ok(Map.of(
            "message", "Old bills deleted successfully",
            "count", oldBills.size(),
            "cutoffDate", cutoff.toString()
        ));
    }

    /**
     * Returns the cutoff date: April 1 of (currentFYStart - 2).
     * Bills BEFORE this date are eligible for deletion.
     * Financial year runs April 1 – March 31.
     * Example: called on 10 Apr 2026 → currentFYStart=2026 → cutoff=2024-04-01
     */
    private LocalDate getCleanupCutoff() {
        LocalDate today = LocalDate.now();
        int currentFYStart = today.getMonthValue() >= 4 ? today.getYear() : today.getYear() - 1;
        return LocalDate.of(currentFYStart - 2, 4, 1);
    }

    @PostMapping("/cleanup-reminder/trigger")
    public ResponseEntity<?> triggerCleanupReminder() {
        String result = dataCleanupScheduler.triggerCleanupReminder();
        return ResponseEntity.ok(Map.of("message", result));
    }

    // Test endpoint — sends email regardless of bill count (for verifying email config)
    @PostMapping("/cleanup-reminder/test")
    public ResponseEntity<?> testCleanupReminder() {
        String result = dataCleanupScheduler.triggerCleanupReminderTest();
        return ResponseEntity.ok(Map.of("message", result));
    }

    // Raw SMTP test — bypasses bill/admin logic, sends directly to given email
    @PostMapping("/cleanup-reminder/smtp-test")
    public ResponseEntity<?> smtpTest(@RequestBody Map<String, String> body) {
        String email = body.get("email");
        if (email == null || email.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "email is required"));
        }
        try {
            emailService.sendOldDataCleanupReminder(email, 0, getCleanupCutoff());
            return ResponseEntity.ok(Map.of("message", "Test email sent to " + email));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/ping")
    public ResponseEntity<?> getServerStatus() {
        return ResponseEntity.ok(Map.of("message", "Connected to backend service successfully"));
    }
}
