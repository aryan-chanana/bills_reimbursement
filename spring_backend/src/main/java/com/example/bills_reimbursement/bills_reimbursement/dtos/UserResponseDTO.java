package com.example.bills_reimbursement.bills_reimbursement.dtos;

import jakarta.persistence.Column;
import lombok.*;

@Data
public class UserResponseDTO {
    private Integer employeeId;

    private String name;

    private String email;

    private boolean isAdmin;

    private boolean isApproved;

    private boolean isDisabled;

}