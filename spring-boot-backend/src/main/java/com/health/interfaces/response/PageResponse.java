package com.health.interfaces.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.List;

/**
 * 分页响应数据
 *
 * @param <T> 数据类型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "分页响应数据")
public class PageResponse<T> implements Serializable {

    private static final long serialVersionUID = 1L;

    /**
     * 数据列表
     */
    @Schema(description = "数据列表")
    private List<T> items;

    /**
     * 总记录数
     */
    @Schema(description = "总记录数")
    private Long total;

    /**
     * 当前页码
     */
    @Schema(description = "当前页码")
    private Integer page;

    /**
     * 每页条数
     */
    @Schema(description = "每页条数")
    private Integer size;

    /**
     * 总页数
     */
    @Schema(description = "总页数")
    private Integer totalPages;

    /**
     * 是否有下一页
     */
    @Schema(description = "是否有下一页")
    private Boolean hasNext;

    /**
     * 是否有上一页
     */
    @Schema(description = "是否有上一页")
    private Boolean hasPrevious;

    /**
     * 构建分页响应
     */
    public static <T> PageResponse<T> of(List<T> items, long total, int page, int size) {
        int totalPages = (int) Math.ceil((double) total / size);
        return PageResponse.<T>builder()
                .items(items)
                .total(total)
                .page(page)
                .size(size)
                .totalPages(totalPages)
                .hasNext(page < totalPages)
                .hasPrevious(page > 1)
                .build();
    }
}
