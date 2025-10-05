package com.example.bills_reimbursement.bills_reimbursement.repositories;

import com.example.bills_reimbursement.bills_reimbursement.models.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Integer> {
    List<User> findAllByOrderByNameAsc();
    Optional<User> findByEmployeeId(Integer employeeId);

}