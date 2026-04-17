package com.example.bills_reimbursement.bills_reimbursement;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class BillsReimbursementApplication {

	public static void main(String[] args) {
		SpringApplication.run(BillsReimbursementApplication.class, args);
	}

}
