package com.example.bills_reimbursement.bills_reimbursement.configs;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import java.util.List;

/**
 * Reads Microsoft SSO configuration from application.properties:
 *
 * <pre>
 * microsoft.sso.tenant-id=common                  # or a specific tenant UUID
 * microsoft.sso.client-id=your-azure-ad-app-client-id
 * microsoft.sso.allowed-tenant-ids=uuid1,uuid2    # optional, multi-tenant allowlist
 * microsoft.sso.allowed-email-domain=axeno.co     # optional
 * </pre>
 *
 * <p>Set {@code tenant-id} to {@code common} (or {@code organizations}) when
 * the Azure AD app registration is multi-tenant. In that mode signed tokens
 * from any tenant pass signature validation, so set
 * {@code allowed-tenant-ids} to the tenants you actually trust (e.g. only
 * your company's tenant). When {@code tenant-id} is a specific UUID the
 * validator strictly accepts only tokens issued by that tenant.
 *
 * <p>{@code allowed-email-domain} is an extra layer — when set, only users
 * whose Azure AD account email ends with that domain may sign in.
 */
@Configuration
@ConfigurationProperties(prefix = "microsoft.sso")
@Data
public class MicrosoftSsoProperties {
    private String tenantId;
    private String clientId;
    private String allowedEmailDomain;
    private List<String> allowedTenantIds;

    /**
     * App role name (declared in Azure AD app registration → App roles)
     * that marks an admin. When set, the service compares it against the
     * token's {@code roles} claim and emits a WARN line whenever the
     * token's verdict disagrees with the local DB's {@code is_admin}.
     * Observation-only — no DB write happens.
     */
    private String adminRoleName;

    /**
     * Object ID of an Azure AD security group whose members should be
     * admins. When set (and {@link #adminRoleName} is not), compared
     * against the token's {@code groups} claim with the same
     * mismatch-warning behaviour.
     */
    private String adminGroupId;
}
