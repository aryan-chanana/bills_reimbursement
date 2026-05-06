package com.example.bills_reimbursement.bills_reimbursement.repositories;

import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Integer> {
    List<User> findAllByOrderByNameAsc();

    Optional<User> findByEmployeeId(Integer employeeId);

    Optional<User> findByEmail(String email);

    /**
     * Case-insensitive email lookup used by the Microsoft SSO flow — the
     * email claim from Azure AD can come back lower-cased while the stored
     * user record may have mixed case (or vice versa).
     */
    Optional<User> findByEmailIgnoreCase(String email);

    @Query("SELECT u FROM User u WHERE u.isAdmin = true")
    List<User> findAllAdmins();
}