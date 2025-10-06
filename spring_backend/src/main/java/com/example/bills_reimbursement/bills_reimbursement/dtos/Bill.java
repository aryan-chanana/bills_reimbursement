package com.example.bills_reimbursement.bills_reimbursement.dtos;

import com.fasterxml.jackson.annotation.JsonBackReference;
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

    @JsonProperty("employeeId")
    public Integer getEmployeeId() {
        return user != null ? user.getEmployeeId() : null;
    }

    @Column(name = "reimbursement_for", nullable = false)
    private String reimbursementFor;

    @Column(nullable = false)
    private Double amount;

    @Column(nullable = false)
    private LocalDate date;

    @Column(name = "bill_image_path", nullable = false)
    private String billImagePath;

    @Column(nullable = false)
    private String status;
}
