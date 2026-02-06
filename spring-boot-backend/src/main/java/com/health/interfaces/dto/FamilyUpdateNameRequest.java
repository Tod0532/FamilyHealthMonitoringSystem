package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Size;

/**
 * 更新家庭名称请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "更新家庭名称请求")
public class FamilyUpdateNameRequest {

    /**
     * 家庭名称
     */
    @Schema(description = "家庭名称", required = true)
    @NotBlank(message = "家庭名称不能为空")
    @Size(max = 100, message = "家庭名称最多100个字符")
    private String familyName;
}
