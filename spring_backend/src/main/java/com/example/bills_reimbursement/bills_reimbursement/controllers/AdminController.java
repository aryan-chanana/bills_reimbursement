package com.example.bills_reimbursement.bills_reimbursement.controllers;

import com.example.bills_reimbursement.bills_reimbursement.dtos.Bill;
import com.example.bills_reimbursement.bills_reimbursement.repositories.BillRepository;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping({"/bills"})
public class AdminController {

    @Autowired
    private BillRepository billRepository;

    @Autowired
    private UserRepository userRepository;

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<Bill>> getAllBills() {
        List<Bill> bills = billRepository.findAllByOrderByDateDesc();
        return ResponseEntity.ok(bills);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PutMapping("/{billId}/status")
    public ResponseEntity<?> updateBillStatus(@PathVariable Integer billId, @RequestBody Map<String, String> statusUpdate) {
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
