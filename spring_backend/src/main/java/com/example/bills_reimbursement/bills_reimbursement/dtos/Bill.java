package com.example.bills_reimbursement.bills_reimbursement.dtos;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDate;

@Data
@Entity
@Table(name = "bills")
public class Bill {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Integer billId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    @JsonIgnore
    private User user;

    // Reads the FK column directly — no lazy load needed
    @Column(name = "employee_id", insertable = false, updatable = false)
    @JsonIgnore
    private Integer ownerId;

    @JsonProperty("employeeId")
    public Integer getEmployeeId() {
        return user != null ? user.getEmployeeId() : null;
    }

    @Column(name = "reimbursement_for", nullable = false)
    private String reimbursementFor;

    @Column(name = "bill_description")
    private String billDescription;

    @Column(nullable = false)
    private Double amount;

    @Column(nullable = false)
    private LocalDate date;

    @Column(name = "approval_mail_path")
    private String approvalMailPath;

    @Column(name = "bill_image_path", nullable = false)
    private String billImagePath;

    @Column(name = "payment_proof_path")
    private String paymentProofPath;

    @Column(nullable = false)
    private String status;

    @Column
    private String remarks;

    @Column(name = "created_at")
    private LocalDate createdAt;
}
