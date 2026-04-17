package com.example.bills_reimbursement.bills_reimbursement.services;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class FCMService {

    private static final Logger log = LoggerFactory.getLogger(FCMService.class);

    public void sendNotification(String fcmToken, String title, String body) {
        if (fcmToken == null || fcmToken.isBlank()) {
            log.warn("FCM: skipped — token is null/blank");
            return;
        }
        if (FirebaseApp.getApps().isEmpty()) {
            log.warn("FCM: skipped — FirebaseApp not initialized");
            return;
        }
        try {
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .build();
            String response = FirebaseMessaging.getInstance().send(message);
            log.info("FCM: sent OK — messageId={} title=\"{}\"", response, title);
        } catch (FirebaseMessagingException e) {
            log.error("FCM: send failed — code={} message={}", e.getMessagingErrorCode(), e.getMessage());
        }
    }
}
