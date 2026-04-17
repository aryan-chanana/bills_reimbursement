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
import java.util.Set;

/*
    Controller for bill-specific operations like adding, retrieving, updating, and deleting bills.
*/

@CrossOrigin(origins = "*")
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
                                     @RequestParam(value = "description", required = false) String description,
                                     @RequestParam("amount") Double amount,
                                     @RequestParam("date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                     @RequestParam(value = "approvalMail", required = false) MultipartFile approvalMail,
                                     @RequestParam("billImage") MultipartFile billImage,
                                     @RequestParam(value = "paymentProof", required = false) MultipartFile paymentProof,
                                     @PathVariable int employeeId, Authentication authentication) {

        boolean loggedInUser = authenticateUser(employeeId, authentication);

        if (!loggedInUser) {
            return ResponseEntity.status(403).build();
        }

        Optional<User> targetUser = userRepository.findByEmployeeId(employeeId);
        if (targetUser.isPresent() && !targetUser.get().isApproved()) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "User not approved yet"));
        }
        if (targetUser.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "User to associate bill with not found"));
        }
        if (targetUser.get().isDisabled()) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "User disabled. Contact administrator."));
        }

        if (!reimbursementFor.equalsIgnoreCase("Parking")) {
            if (approvalMail == null || paymentProof == null || description == null || description.isEmpty()) {
                return ResponseEntity.badRequest().body("Approval mail, Payment proof & Description are required for this category");
            }
        }

        Bill newBill = new Bill();
        newBill.setReimbursementFor(reimbursementFor);
        newBill.setBillDescription(description);
        newBill.setAmount(amount);
        newBill.setDate(date);
        newBill.setStatus("Pending");
        newBill.setUser(targetUser.get());
        newBill.setApprovalMailPath(approvalMail != null ? fileStorageService.storeFile(approvalMail, employeeId, "approval") : null);
        newBill.setBillImagePath(fileStorageService.storeFile(billImage, employeeId, "bill"));
        newBill.setPaymentProofPath(paymentProof != null ? fileStorageService.storeFile(paymentProof, employeeId, "payment") : null);
        newBill.setCreatedAt(LocalDate.now());
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
        if (targetBill.getUser().isDisabled()) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "User disabled. Contact administrator."));
        }
        if (targetBill.getUser().getEmployeeId().equals(employeeId)) {
            return ResponseEntity.ok(targetBill);
        }
        return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
    }

    @PutMapping("/{billId}")
    public ResponseEntity<?> editBill(@RequestParam("reimbursementFor") String reimbursementFor,
                                      @RequestParam(value = "description", required = false) String description,
                                      @RequestParam("amount") Double amount,
                                      @RequestParam("date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                      @RequestParam(value = "approvalMail", required = false) MultipartFile approvalMail,
                                      @RequestParam(value = "billImage", required = false) MultipartFile billImage,
                                      @RequestParam(value = "paymentProof", required = false) MultipartFile paymentProof,
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
        if (existingBill.getUser().isDisabled()) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "User disabled. Contact administrator."));
        }
        if (!reimbursementFor.equalsIgnoreCase("Parking")) {
            boolean hasApproval = (approvalMail != null && !approvalMail.isEmpty())
                    || (existingBill.getApprovalMailPath() != null && !existingBill.getApprovalMailPath().isEmpty());
            boolean hasPayment = (paymentProof != null && !paymentProof.isEmpty())
                    || (existingBill.getPaymentProofPath() != null && !existingBill.getPaymentProofPath().isEmpty());
            if (!hasApproval || !hasPayment) {
                return ResponseEntity.badRequest().body("Approval mail and Payment proof are required for this category");
            }
        }

        if ("PAID".equalsIgnoreCase(existingBill.getStatus()) || "APPROVED".equalsIgnoreCase(existingBill.getStatus())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "Cannot edit an approved bill."));
        }


        existingBill.setReimbursementFor(reimbursementFor);
        existingBill.setBillDescription(description);
        existingBill.setAmount(amount);
        existingBill.setDate(date);
        existingBill.setStatus("Pending");
        if (billImage != null && !billImage.isEmpty()) {
            fileStorageService.deleteFile(existingBill.getBillImagePath());
            existingBill.setBillImagePath(fileStorageService.storeFile(billImage, employeeId, "bill"));
        }
        if (approvalMail != null && !approvalMail.isEmpty()) {
            fileStorageService.deleteFile(existingBill.getApprovalMailPath());
            existingBill.setApprovalMailPath(fileStorageService.storeFile(approvalMail, employeeId, "approval"));
        }
        if (paymentProof != null && !paymentProof.isEmpty()) {
            fileStorageService.deleteFile(existingBill.getPaymentProofPath());
            existingBill.setPaymentProofPath(fileStorageService.storeFile(paymentProof, employeeId, "payment"));
        }

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
        if (bill.getUser().isDisabled()) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "User disabled. Contact administrator."));
        }

        String status = Optional.ofNullable(bill.getStatus()).map(String::toUpperCase).orElse("UNKNOWN");
        if (status.equals("PAID")) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "Cannot delete an approved bill."));
        }

        fileStorageService.deleteFile(bill.getBillImagePath());
        fileStorageService.deleteFile(bill.getApprovalMailPath());
        fileStorageService.deleteFile(bill.getPaymentProofPath());
        billRepository.delete(bill);
        return ResponseEntity.ok(Map.of("message", "Bill has been deleted successfully"));
    }

    private boolean authenticateUser(Integer employeeId, Authentication authentication) {
        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();
        return userDetails.isAdmin() || loggedInEmployeeId.equals(employeeId);
    }
}
