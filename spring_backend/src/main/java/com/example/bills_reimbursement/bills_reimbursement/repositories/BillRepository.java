package com.example.bills_reimbursement.bills_reimbursement.repositories;

import com.example.bills_reimbursement.bills_reimbursement.dtos.Bill;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BillRepository extends JpaRepository<Bill, Integer> {
    List<Bill> findAllByUser_EmployeeIdOrderByDateDesc(Integer employeeId);

    List<Bill> findAllByOrderByDateDesc();
}
