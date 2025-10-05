package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.models.Bill;
import com.example.bills_reimbursement.bills_reimbursement.models.User;
import com.example.bills_reimbursement.bills_reimbursement.repositories.BillRepository;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

@RestController
@RequestMapping("/users/{employeeId}/bills")
public class BillController {

    @Autowired
    private BillRepository billRepository;

    @Autowired
    private UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<Bill>> getAllBills(@PathVariable Integer employeeId, Authentication authentication) {
        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();

        if (!userDetails.isAdmin() && !loggedInEmployeeId.equals(employeeId)) {
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
    public ResponseEntity<?> addBill(@RequestBody Bill bill, @PathVariable int employeeId, Authentication authentication) {

        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();

        if (!userDetails.isAdmin() && !loggedInEmployeeId.equals(employeeId)) {
            return ResponseEntity.status(403).build();
        }

        Optional<User> targetUserOpt = userRepository.findByEmployeeId(employeeId);
        if (targetUserOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "User to associate bill with not found"));
        }
        bill.setUser(targetUserOpt.get());

        Bill savedBill = billRepository.save(bill);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("message", "User created successfully", "id", savedBill.getBillId()));
    }

    @GetMapping("/{bill_id}")
    public ResponseEntity<?> searchBill(@PathVariable Integer employeeId, @PathVariable Integer billId, Authentication authentication) {
        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();

        if (!userDetails.isAdmin() && !loggedInEmployeeId.equals(employeeId)) {
            return ResponseEntity.status(403).build();
        }

        Optional<User> targetUser = userRepository.findByEmployeeId(employeeId);
        if (targetUser.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Bill targetBill = billRepository.findById(billId).orElse(null);
        if (Objects.nonNull(targetBill) && targetBill.getUser().getEmployeeId().equals(employeeId)) {
            return ResponseEntity.ok(targetBill);
        }
        return ResponseEntity.notFound().build();
    }

    @PutMapping("/{billId}")
    public ResponseEntity<?> editBill(
                                @RequestBody Bill updatedBillDetails, @PathVariable Integer employeeId,
                                @PathVariable Integer billId, Authentication authentication) {
        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();

        if (!userDetails.isAdmin() && !loggedInEmployeeId.equals(employeeId)) {
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

        if ("APPROVED".equalsIgnoreCase(existingBill.getStatus())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "Cannot edit an approved bill."));
        }

        existingBill.setReimbursementFor(updatedBillDetails.getReimbursementFor());
        existingBill.setAmount(updatedBillDetails.getAmount());
        existingBill.setDate(updatedBillDetails.getDate());
        existingBill.setBillImagePath(updatedBillDetails.getBillImagePath());

        billRepository.save(existingBill);
        return ResponseEntity.ok(existingBill);
    }

    @DeleteMapping("/{billId}")
    public ResponseEntity<?> deleteBill(@PathVariable Integer employeeId, @PathVariable Integer billId, Authentication authentication) {
        User userDetails = (User) authentication.getPrincipal();
        Integer loggedInEmployeeId = userDetails.getEmployeeId();

        if (!userDetails.isAdmin() && !loggedInEmployeeId.equals(employeeId)) {
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

        if ("APPROVED".equalsIgnoreCase(bill.getStatus())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "Cannot delete an approved bill."));
        }

        billRepository.delete(bill);
        return ResponseEntity.ok(Map.of("message", "Bill has been deleted successfully"));
    }
}
