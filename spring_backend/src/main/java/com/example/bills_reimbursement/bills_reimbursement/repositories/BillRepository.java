package com.example.bills_reimbursement.bills_reimbursement.repositories;

import com.example.bills_reimbursement.bills_reimbursement.dtos.Bill;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface BillRepository extends JpaRepository<Bill, Integer> {
    List<Bill> findAllByUser_EmployeeIdOrderByDateDesc(Integer employeeId);

    List<Bill> findAllByOrderByDateDesc();

    List<Bill> findAllByCreatedAtBefore(LocalDate cutoffDate);

    int countByCreatedAtBefore(LocalDate cutoffDate);

    List<Bill> findAllByCreatedAtBetween(LocalDate from, LocalDate to);

    int countByCreatedAtBetween(LocalDate from, LocalDate to);
}
