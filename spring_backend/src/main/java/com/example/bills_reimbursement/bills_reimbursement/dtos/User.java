package com.example.bills_reimbursement.bills_reimbursement.dtos;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

@Data
@Entity
@Table(name = "users")
public class User implements UserDetails {

    @Id
    @Column(name = "employee_id")
    private Integer employeeId;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String email;

    @Column(nullable = false)
    private String password;

    @JsonProperty("isAdmin")
    @Column(name = "is_admin", nullable = false)
    private boolean isAdmin;

    @JsonProperty("isApproved")
    @Column(name = "is_approved", nullable = false)
    private boolean isApproved;

    @JsonProperty("isDisabled")
    @Column(name = "is_disabled", nullable = false)
    private boolean isDisabled;


    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        if (this.isAdmin) {
            return List.of(new SimpleGrantedAuthority("ROLE_ADMIN"));
        }
        return List.of(new SimpleGrantedAuthority("ROLE_USER"));
    }

    @Override
    public String getUsername() {
        return String.valueOf(this.employeeId);
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return !isDisabled;
    }

    public static UserResponseDTO toDto(User user) {
        UserResponseDTO userResponseDTO = new UserResponseDTO();
        userResponseDTO.setEmployeeId(user.getEmployeeId());
        userResponseDTO.setName(user.getName());
        userResponseDTO.setEmail(user.getEmail());
        userResponseDTO.setAdmin(user.isAdmin());
        userResponseDTO.setApproved(user.isApproved());
        userResponseDTO.setDisabled(user.isDisabled());
        return userResponseDTO;
    }
}