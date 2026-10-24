-- 分析商品类目的流量和购买表现
-- 目的：识别高流量类目，以及购买表现较好的类目

SELECT
    category_id,

    -- 类目总行为量
    COUNT(*) AS behavior_count,

    -- 类目浏览次数
    SUM(
        CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END
    ) AS pv_count,

    -- 类目加购次数
    SUM(
        CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END
    ) AS cart_count,

    -- 类目购买次数
    SUM(
        CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END
    ) AS buy_count,

    -- 购买次数 / 浏览次数
    -- 这里作为类目购买表现的一个粗略指标，不代表严格因果转化率
    ROUND(
        1.0 * SUM(
            CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END
        ) /
        NULLIF(
            SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END),
            0
        ),
        4
    ) AS buy_pv_ratio

FROM user_behavior

GROUP BY category_id

-- 先过滤掉样本太小的类目，避免几十次浏览就出现很高比率
HAVING pv_count >= 1000

ORDER BY buy_count DESC

LIMIT 20;




-- 对类目进行“流量规模 × 购买效率”分层
-- 目的：识别高流量高效率、高流量低效率、低流量高效率等不同类型类目

WITH category_metrics AS (
    SELECT
        category_id,

        SUM(
            CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END
        ) AS pv_count,

        SUM(
            CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END
        ) AS buy_count,

        ROUND(
            1.0 * SUM(
                CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END
            ) /
            NULLIF(
                SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END),
                0
            ),
            4
        ) AS buy_pv_ratio

    FROM user_behavior

    GROUP BY category_id

    -- 排除流量太少的类目，避免小样本导致比例失真
    HAVING SUM(
        CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END
    ) >= 1000
),

category_rank AS (
    SELECT
        *,

        -- 按浏览量分成4档：4代表流量最高的25%
        NTILE(4) OVER (
            ORDER BY pv_count
        ) AS traffic_level,

        -- 按购买表现分成4档：4代表效率最高的25%
        NTILE(4) OVER (
            ORDER BY buy_pv_ratio
        ) AS efficiency_level

    FROM category_metrics
)

SELECT
    CASE
        WHEN traffic_level = 4 AND efficiency_level = 4
            THEN '高流量高效率'

        WHEN traffic_level = 4 AND efficiency_level <= 2
            THEN '高流量低效率'

        WHEN traffic_level <= 2 AND efficiency_level = 4
            THEN '低流量高效率'

        ELSE '普通类目'
    END AS category_segment,

    COUNT(*) AS category_count,

    SUM(pv_count) AS total_pv,

    SUM(buy_count) AS total_buy

FROM category_rank

GROUP BY category_segment

ORDER BY total_buy DESC;