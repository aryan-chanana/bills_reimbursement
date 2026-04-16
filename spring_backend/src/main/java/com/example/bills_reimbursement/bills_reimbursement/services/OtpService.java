package com.example.bills_reimbursement.bills_reimbursement.services;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.util.concurrent.TimeUnit;

@Service
public class OtpService {

    @Autowired
    private StringRedisTemplate redisTemplate;

    private static final String OTP_PREFIX = "OTP_";
    private static final String ATTEMPT_PREFIX = "ATTEMPT_";
    private static final String VERIFIED_PREFIX = "VERIFIED_";

    private static final String RATE_LIMIT_PREFIX = "RATE_";
    private static final String COOLDOWN_PREFIX = "COOLDOWN_";

    private static final int MAX_OTP_REQUESTS = 3;
    private static final int MAX_ATTEMPTS = 5;

    private final SecureRandom secureRandom = new SecureRandom();

    // Generate OTP
    public String generateOtp() {
        int otp = 100000 + secureRandom.nextInt(900000);
        return String.valueOf(otp);
    }

    // Save OTP (5 min TTL)
    public void saveOtp(String key, String otp) {
        redisTemplate.opsForValue().set(OTP_PREFIX + key, otp, 5, TimeUnit.MINUTES);
        redisTemplate.delete(ATTEMPT_PREFIX + key); // reset attempts
    }

    // Validate OTP (atomic + attempts limit)
    public boolean validateOtp(String key, String userOtp) {
        String otpKey = OTP_PREFIX + key;
        String attemptKey = ATTEMPT_PREFIX + key;

        String storedOtp = redisTemplate.opsForValue().get(otpKey);

        if (storedOtp == null) return false;

        // Increment attempts
        Long attempts = redisTemplate.opsForValue().increment(attemptKey);
        redisTemplate.expire(attemptKey, 5, TimeUnit.MINUTES);

        if (attempts != null && attempts > MAX_ATTEMPTS) {
            redisTemplate.delete(otpKey);
            return false;
        }

        if (storedOtp.equals(userOtp)) {
            // Atomic delete (simulate GETDEL)
            redisTemplate.delete(otpKey);

            // Mark verified
            redisTemplate.opsForValue().set(VERIFIED_PREFIX + key, "true", 5, TimeUnit.MINUTES);
            return true;
        }

        return false;
    }

    // Check if verified
    public boolean isVerified(String key) {
        return "true".equals(redisTemplate.opsForValue().get(VERIFIED_PREFIX + key));
    }

    // Clear verification after use
    public void clearVerification(String key) {
        redisTemplate.delete(VERIFIED_PREFIX + key);
    }

    public boolean canSendOtp(String key) {
        String rateKey = RATE_LIMIT_PREFIX + key;
        String cooldownKey = COOLDOWN_PREFIX + key;

        // Check cooldown (30 sec)
        if (Boolean.TRUE.equals(redisTemplate.hasKey(cooldownKey))) {
            return false;
        }

        // Increment request count
        Long count = redisTemplate.opsForValue().increment(rateKey);

        if (count != null && count == 1) {
            redisTemplate.expire(rateKey, 5, TimeUnit.MINUTES);
        }

        if (count != null && count > MAX_OTP_REQUESTS) {
            return false;
        }

        // Set cooldown (30 seconds)
        redisTemplate.opsForValue().set(cooldownKey, "1", 30, TimeUnit.SECONDS);

        return true;
    }
}