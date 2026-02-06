package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 家庭二维码响应DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "家庭二维码响应")
public class FamilyQrCodeResponse {

    /**
     * 家庭邀请码
     */
    @Schema(description = "家庭邀请码")
    private String familyCode;

    /**
     * 二维码内容（格式：FAMILY_INVITE:ABC123）
     */
    @Schema(description = "二维码内容")
    private String qrContent;

    /**
     * 家庭名称
     */
    @Schema(description = "家庭名称")
    private String familyName;

    /**
     * 成员数量
     */
    @Schema(description = "成员数量")
    private Integer memberCount;
}
