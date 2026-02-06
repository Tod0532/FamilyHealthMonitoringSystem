package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Pattern;
import javax.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 加入家庭请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "加入家庭请求")
public class FamilyJoinRequest {

    /**
     * 家庭邀请码（6位）
     */
    @Schema(description = "家庭邀请码", required = true)
    @NotBlank(message = "邀请码不能为空")
    @Size(min = 6, max = 6, message = "邀请码为6位")
    @Pattern(regexp = "^[A-Z0-9]+$", message = "邀请码只能包含大写字母和数字")
    private String inviteCode;
}
