package com.example.bills_reimbursement.bills_reimbursement.services;

import com.example.bills_reimbursement.bills_reimbursement.dtos.User;
import com.example.bills_reimbursement.bills_reimbursement.repositories.BillRepository;
import com.example.bills_reimbursement.bills_reimbursement.repositories.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;

@Component
public class DataCleanupScheduler {

    @Autowired
    private BillRepository billRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EmailService emailService;

    // Runs at 9:00 AM on April 1st every year
    @Scheduled(cron = "0 0 9 1 4 *")
    public void sendAnnualCleanupReminder() {
        triggerCleanupReminder();
    }

    public String triggerCleanupReminder() {
        LocalDate cutoff = getCleanupCutoff();
        int count = billRepository.countByCreatedAtBefore(cutoff);
        if (count == 0) return "No bills older than 2 financial years found. No emails sent.";
        return sendReminderEmails(count, cutoff);
    }

    public String triggerCleanupReminderTest() {
        LocalDate cutoff = getCleanupCutoff();
        int count = billRepository.countByCreatedAtBefore(cutoff);
        return sendReminderEmails(count, cutoff);
    }

    private LocalDate getCleanupCutoff() {
        LocalDate today = LocalDate.now();
        int currentFYStart = today.getMonthValue() >= 4 ? today.getYear() : today.getYear() - 1;
        return LocalDate.of(currentFYStart - 2, 4, 1);
    }

    private String sendReminderEmails(int count, LocalDate cutoff) {
        List<User> admins = userRepository.findAllAdmins();
        if (admins.isEmpty()) return "No admin users found.";

        int sent = 0;
        StringBuilder errors = new StringBuilder();
        for (User admin : admins) {
            if (admin.getEmail() != null && !admin.getEmail().isBlank()) {
                try {
                    emailService.sendOldDataCleanupReminder(admin.getEmail(), count, cutoff);
                    sent++;
                    System.out.println("Cleanup reminder sent to: " + admin.getEmail());
                } catch (Exception e) {
                    String err = "Failed for " + admin.getEmail() + ": " + e.getMessage();
                    System.err.println(err);
                    errors.append(err).append("; ");
                }
            } else {
                System.out.println("Skipping admin " + admin.getEmployeeId() + " — no email set.");
            }
        }
        if (errors.length() > 0) return "Sent: " + sent + ", Errors: " + errors;
        return "Reminder sent to " + sent + " admin(s) for " + count + " old bill(s).";
    }
}
