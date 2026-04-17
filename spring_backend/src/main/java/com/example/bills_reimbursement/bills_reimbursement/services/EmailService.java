package com.example.bills_reimbursement.bills_reimbursement.services;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@Service
public class EmailService {

    @Autowired
    private JavaMailSender mailSender;

    public void sendOtp(String toEmail, String otp) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("Password Reset OTP");
        message.setText("Your OTP is: " + otp + "\nValid for 5 minutes.");
        mailSender.send(message);
    }

    public void sendOldDataCleanupReminder(String toEmail, int billCount, LocalDate cutoff) {
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd MMM yyyy");
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("Annual Data Cleanup Reminder — ExpenZ");
        message.setText(
            "Hello Admin,\n\n" +
            "This is your annual data cleanup reminder.\n\n" +
            "There are currently " + billCount + " bill(s) submitted before " +
            cutoff.format(fmt) +
            " (older than 2 financial years) that are eligible for deletion.\n\n" +
            "Please log in to the admin dashboard and use the 'Delete Old Data' option " +
            "to permanently remove these records and their uploaded files.\n\n" +
            "Regards,\nExpenZ (Bills Reimbursement System)"
        );
        mailSender.send(message);
    }
}