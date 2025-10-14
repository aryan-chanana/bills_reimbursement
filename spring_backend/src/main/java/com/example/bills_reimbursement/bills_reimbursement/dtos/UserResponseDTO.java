package com.example.bills_reimbursement.bills_reimbursement.dtos;

import lombok.*;

@Data
public class UserResponseDTO {
    private Integer employeeId;

    private String name;

    private boolean isAdmin;
}