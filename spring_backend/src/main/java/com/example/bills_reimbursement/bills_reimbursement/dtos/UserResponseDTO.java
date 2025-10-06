package com.example.bills_reimbursement.bills_reimbursement.dtos;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class UserResponseDTO {
    private Integer employeeId;

    private String name;

    private boolean isAdmin;
}