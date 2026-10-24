-- 用户价值基础指标汇总
-- 目的：为后续用户分层准备 Recency、购买频次和活跃行为指标

WITH user_metrics AS (
    SELECT
        user_id,

        -- 浏览次数
        SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_count,

        -- 收藏次数
        SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS fav_count,

        -- 加购次数
        SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_count,

        -- 购买次数
        SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_count,

        -- 最近一次购买时间
        MAX(
            CASE
                WHEN behavior_type = 'buy' THEN datetime
            END
        ) AS last_buy_time

    FROM user_behavior

    GROUP BY user_id
)

SELECT
    user_id,
    pv_count,
    fav_count,
    cart_count,
    buy_count,
    last_buy_time,

    -- 距离观察期结束日的最近购买天数
    CASE
        WHEN last_buy_time IS NOT NULL
        THEN CAST(
            julianday('2017-12-04') - julianday(last_buy_time)
            AS INTEGER
        )
        ELSE NULL
    END AS recency_days

FROM user_metrics

ORDER BY buy_count DESC;



-- 查看用户购买次数的整体分布
-- 目的：了解大多数用户购买多少次，为后续用户价值分层确定合理阈值

WITH user_metrics AS (
    SELECT
        user_id,

        SUM(
            CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END
        ) AS buy_count

    FROM user_behavior

    GROUP BY user_id
)

SELECT
    buy_count,

    COUNT(*) AS user_count

FROM user_metrics

GROUP BY buy_count

ORDER BY buy_count;



-- 查看“已购买用户”的最近购买时间分布
-- 目的：了解有购买行为的用户距离观察期结束多久没有购买，
--      为后续 Recency 分层确定合理阈值

WITH user_metrics AS (
    SELECT
        user_id,

        SUM(
            CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END
        ) AS buy_count,

        MAX(
            CASE WHEN behavior_type = 'buy' THEN datetime
        END
        ) AS last_buy_time

    FROM user_behavior

    GROUP BY user_id
),

user_recency AS (
    SELECT
        user_id,
        buy_count,

        CASE
            WHEN last_buy_time IS NOT NULL
            THEN CAST(
                julianday('2017-12-04') - julianday(last_buy_time)
                AS INTEGER
            )
        END AS recency_days

    FROM user_metrics
)

SELECT
    recency_days,
    COUNT(*) AS user_count

FROM user_recency

-- 只看至少购买过一次的用户
WHERE buy_count > 0

GROUP BY recency_days

ORDER BY recency_days;



-- 对已购买用户进行 RF 用户价值分层
-- 目的：根据购买频次 Frequency 和最近购买时间 Recency，
--      区分核心用户、待唤回用户、潜力用户和低频沉默用户

WITH user_metrics AS (
    SELECT
        user_id,

        SUM(
            CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END
        ) AS buy_count,

        MAX(
            CASE WHEN behavior_type = 'buy' THEN datetime
        END
        ) AS last_buy_time

    FROM user_behavior

    GROUP BY user_id
),

user_rf AS (
    SELECT
        user_id,
        buy_count,

        CAST(
            julianday('2017-12-04') - julianday(last_buy_time)
            AS INTEGER
        ) AS recency_days

    FROM user_metrics

    -- RF只分析至少购买过一次的用户
    WHERE buy_count > 0
),

user_segment AS (
    SELECT
        user_id,
        buy_count,
        recency_days,

        CASE
            WHEN buy_count >= 5 AND recency_days <= 2
                THEN '核心购买用户'

            WHEN buy_count >= 5 AND recency_days >= 3
                THEN '高频待唤回用户'

            WHEN buy_count < 5 AND recency_days <= 2
                THEN '潜力购买用户'

            ELSE '低频沉默用户'
        END AS user_segment

    FROM user_rf
)

SELECT
    user_segment,
    COUNT(*) AS user_count,

    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM user_segment),
        2
    ) AS user_percentage

FROM user_segment

GROUP BY user_segment

ORDER BY user_count DESC;



-- 分析未购买用户的行为特征
-- 目的：从从未购买的用户中识别已经表现出加购/收藏意向的潜在转化用户

WITH user_metrics AS (
    SELECT
        user_id,

        SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_count,
        SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS fav_count,
        SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_count,
        SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_count

    FROM user_behavior

    GROUP BY user_id
)

SELECT
    CASE
        -- 已经加购，但最终没有购买：购买意向最强
        WHEN cart_count > 0
            THEN '高意向未购买用户'

        -- 没加购，但有收藏行为：有一定兴趣
        WHEN cart_count = 0 AND fav_count > 0
            THEN '兴趣未转化用户'

        -- 只有浏览，没有收藏/加购/购买
        ELSE '浏览型未购买用户'
    END AS user_segment,

    COUNT(*) AS user_count,

    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM user_metrics WHERE buy_count = 0),
        2
    ) AS user_percentage

FROM user_metrics

WHERE buy_count = 0

GROUP BY user_segment

ORDER BY user_count DESC;