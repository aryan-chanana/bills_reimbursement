package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.dtos.Bill;
import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.repositories.BillRepository;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import com.example.bills_reimbursement.bills_reimbursement.services.FileStorageService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/*
    Controller for bill-specific operations like adding, retrieving, updating, and deleting bills.
*/
@RestController
@RequestMapping({"/users/{employeeId}/bills"})
public class BillController {

    @Autowired
    private BillRepository billRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private FileStorageService fileStorageService;

    @GetMapping
    public ResponseEntity<List<Bill>> getAllBillsForUser(@PathVariable Integer employeeId, Authentication authentication) {

        boolean loggedInUser = authenticateUser(employeeId, authentication);

        if (!loggedInUser) {
            return ResponseEntity.status(403).build();
        }

        Optional<User> targetUser = userRepository.findByEmployeeId(employeeId);
        if (targetUser.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        List<Bill> bills = billRepository.findAllByUser_EmployeeIdOrderByDateDesc(employeeId);

        return ResponseEntity.ok(bills);
    }

    @PostMapping
    public ResponseEntity<?> addBill(@RequestParam("reimbursementFor") String reimbursementFor,
                                     @RequestParam("amount") Double amount,
                                     @RequestParam("date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                     @RequestParam("billImage") MultipartFile billImage,
                                     @PathVariable int employeeId, Authentication authentication) {

        boolean loggedInUser = authenticateUser(employeeId, authentication);

        if (!loggedInUser) {
            return ResponseEntity.status(403).build();
        }

        Optional<User> targetUser = userRepository.findByEmployeeId(employeeId);
        if (targetUser.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "User to associate bill with not found"));
        }

        String fileName = fileStorageService.storeFile(billImage);

        Bill newBill = new Bill();
        newBill.setReimbursementFor(reimbursementFor);
        newBill.setAmount(amount);
        newBill.setDate(date);
        newBill.setStatus("pending");
        newBill.setUser(targetUser.get());
        newBill.setBillImagePath(fileName);
        Bill savedBill = billRepository.save(newBill);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("message", "Bill added successfully", "id", savedBill.getBillId()));
    }

    @GetMapping("/{billId}")
    public ResponseEntity<?> searchBill(@PathVariable("employeeId") Integer employeeId,
                                        @PathVariable("billId") Integer billId, Authentication authentication) {
        boolean loggedInUser = authenticateUser(employeeId, authentication);
        if (!loggedInUser) {
            return ResponseEntity.status(403).build();
        }

        Bill targetBill = billRepository.findById(billId).orElse(null);
        if (targetBill == null) {
            return ResponseEntity.notFound().build();
        }
        if (targetBill.getUser().getEmployeeId().equals(employeeId)) {
            return ResponseEntity.ok(targetBill);
        }
        return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
    }

    @PutMapping("/{billId}")
    public ResponseEntity<?> editBill(@RequestBody Bill updatedBillDetails,
                                      @PathVariable("employeeId") Integer employeeId,
                                      @PathVariable("billId") Integer billId, Authentication authentication) {

        boolean loggedInUser = authenticateUser(employeeId, authentication);

        if (!loggedInUser) {
            return ResponseEntity.status(403).build();
        }

        Optional<Bill> existingBillOpt = billRepository.findById(billId);
        if (existingBillOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Bill existingBill = existingBillOpt.get();
        if (!existingBill.getUser().getEmployeeId().equals(employeeId)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "This bill does not belong to the specified user."));
        }

        if ("APPROVED".equalsIgnoreCase(existingBill.getStatus()) || "REJECTED".equalsIgnoreCase(existingBill.getStatus())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "Cannot edit an approved bill."));
        }

        existingBill.setReimbursementFor(updatedBillDetails.getReimbursementFor());
        existingBill.setAmount(updatedBillDetails.getAmount());
        existingBill.setDate(updatedBillDetails.getDate());
        existingBill.setBillImagePath(updatedBillDetails.getBillImagePath());
        existingBill.setStatus(updatedBillDetails.getStatus());

        billRepository.save(existingBill);
        return ResponseEntity.ok(existingBill);
    }

    @DeleteMapping("/{billId}")
    public ResponseEntity<?> deleteBill(@PathVariable Integer employeeId,
                                        @PathVariable Integer billId, Authentication authentication) {

        boolean loggedInUser = authenticateUser(employeeId, authentication);

        if (!loggedInUser) {
            return ResponseEntity.status(403).build();
        }

        Optional<Bill> billOpt = billRepository.findById(billId);
        if (billOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        Bill bill = billOpt.get();

        if (!bill.getUser().getEmployeeId().equals(employeeId)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "This bill does not belong to the specified user."));
        }

        if ("APPROVED".equalsIgnoreCase(bill.getStatus()) || "REJECTED".equalsIgnoreCase(bill.getStatus())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "Cannot delete an approved bill."));
        }

        billRepository.delete(bill);
        return ResponseEntity.ok(Map.of("message", "Bill has been deleted successfully"));
    }

    private boolean authenticateUser(Integer employeeId, Authentication authentication) {
        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();
        return userDetails.isAdmin() || loggedInEmployeeId.equals(employeeId);
    }
}
