-- 更严谨的留存分析
-- 目的：对于观察窗口不足的 cohort，不把留存率错误显示为 0

WITH first_seen AS (
    SELECT
        user_id,
        MIN(DATE(datetime)) AS first_seen_date
    FROM user_behavior
    GROUP BY user_id
),

daily_users AS (
    SELECT DISTINCT
        user_id,
        DATE(datetime) AS active_date
    FROM user_behavior
)

SELECT
    f.first_seen_date AS cohort_date,
    COUNT(*) AS cohort_size,

    -- 次日留存：只有 first_seen_date <= 12/02 才有完整观察窗口
    CASE
        WHEN f.first_seen_date <= '2017-12-02'
        THEN ROUND(
            1.0 * SUM(
                CASE WHEN d1.user_id IS NOT NULL THEN 1 ELSE 0 END
            ) / COUNT(*),
            4
        )
        ELSE NULL
    END AS d1_retention,

    -- 3日留存：只有 first_seen_date <= 11/30 才有完整观察窗口
    CASE
        WHEN f.first_seen_date <= '2017-11-30'
        THEN ROUND(
            1.0 * SUM(
                CASE WHEN d3.user_id IS NOT NULL THEN 1 ELSE 0 END
            ) / COUNT(*),
            4
        )
        ELSE NULL
    END AS d3_retention,

    -- 7日留存：只有 first_seen_date <= 11/26 才有完整观察窗口
    CASE
        WHEN f.first_seen_date <= '2017-11-26'
        THEN ROUND(
            1.0 * SUM(
                CASE WHEN d7.user_id IS NOT NULL THEN 1 ELSE 0 END
            ) / COUNT(*),
            4
        )
        ELSE NULL
    END AS d7_retention

FROM first_seen f

LEFT JOIN daily_users d1
    ON f.user_id = d1.user_id
    AND d1.active_date = DATE(f.first_seen_date, '+1 day')

LEFT JOIN daily_users d3
    ON f.user_id = d3.user_id
    AND d3.active_date = DATE(f.first_seen_date, '+3 day')

LEFT JOIN daily_users d7
    ON f.user_id = d7.user_id
    AND d7.active_date = DATE(f.first_seen_date, '+7 day')

GROUP BY f.first_seen_date
ORDER BY cohort_date;




-- 计算用户层面的行为漏斗
-- 目的：观察发生过浏览、收藏、加购、购买行为的独立用户数量
-- 注意：这里统计的是“是否发生过该行为”，不要求行为严格按顺序发生

SELECT
    COUNT(DISTINCT CASE
        WHEN behavior_type = 'pv' THEN user_id
    END) AS pv_users,

    COUNT(DISTINCT CASE
        WHEN behavior_type = 'fav' THEN user_id
    END) AS fav_users,

    COUNT(DISTINCT CASE
        WHEN behavior_type = 'cart' THEN user_id
    END) AS cart_users,

    COUNT(DISTINCT CASE
        WHEN behavior_type = 'buy' THEN user_id
    END) AS buy_users

FROM user_behavior;



-- 计算用户层面的行为转化比例
-- 目的：观察浏览用户中有多少发生收藏、加购和购买，
--      并进一步看加购用户中有多少最终购买

WITH user_flags AS (
    SELECT
        user_id,

        MAX(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS has_pv,
        MAX(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS has_fav,
        MAX(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS has_buy

    FROM user_behavior

    GROUP BY user_id
)

SELECT
    SUM(has_pv) AS pv_users,
    SUM(has_fav) AS fav_users,
    SUM(has_cart) AS cart_users,
    SUM(has_buy) AS buy_users,

    ROUND(
        1.0 * SUM(has_fav) / SUM(has_pv),
        4
    ) AS pv_to_fav_rate,

    ROUND(
        1.0 * SUM(has_cart) / SUM(has_pv),
        4
    ) AS pv_to_cart_rate,

    ROUND(
        1.0 * SUM(has_buy) / SUM(has_pv),
        4
    ) AS pv_to_buy_rate,

    ROUND(
        1.0 * SUM(
            CASE
                WHEN has_cart = 1 AND has_buy = 1 THEN 1
                ELSE 0
            END
        ) / SUM(has_cart),
        4
    ) AS cart_to_buy_rate

FROM user_flags;



