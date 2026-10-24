-- 查看用户行为表中的各类行为数量
-- 目的：了解浏览、收藏、加购、购买四类行为的整体分布

SELECT
    behavior_type,
    COUNT(*) AS behavior_count
FROM user_behavior
GROUP BY behavior_type
ORDER BY behavior_count DESC;





-- 统计每天的用户活跃情况
-- 目的：观察每天整体行为量、活跃用户数以及购买用户数的变化趋势

SELECT
    DATE(datetime) AS date,

    -- 当天所有用户行为次数
    COUNT(*) AS behavior_count,

    -- 当天发生过任意行为的独立用户数
    COUNT(DISTINCT user_id) AS dau,

    -- 当天购买行为发生次数
    SUM(
        CASE
            WHEN behavior_type = 'buy' THEN 1
            ELSE 0
        END
    ) AS buy_count,

    -- 当天至少购买过一次的独立用户数
    COUNT(
        DISTINCT CASE
            WHEN behavior_type = 'buy' THEN user_id
        END
    ) AS buy_users

FROM user_behavior

GROUP BY DATE(datetime)

ORDER BY date;





-- 计算每日购买用户率
-- 目的：判断每天的活跃用户中，有多少用户至少发生过一次购买

SELECT
    DATE(datetime) AS date,

    COUNT(DISTINCT user_id) AS dau,

    COUNT(
        DISTINCT CASE
            WHEN behavior_type = 'buy' THEN user_id
        END
    ) AS buy_users,

    ROUND(
        1.0 * COUNT(
            DISTINCT CASE
                WHEN behavior_type = 'buy' THEN user_id
            END
        ) / COUNT(DISTINCT user_id),
        4
    ) AS buy_user_rate

FROM user_behavior

GROUP BY DATE(datetime)

ORDER BY date;



-- 统计每天不同用户行为的次数
-- 目的：判断 12/2–12/3 的活跃增长主要来自哪一种行为

SELECT
    DATE(datetime) AS date,

    SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv_count,

    SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS fav_count,

    SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_count,

    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_count

FROM user_behavior

GROUP BY DATE(datetime)

ORDER BY date;




-- 统计每天“首次出现用户”和“已出现用户”
-- 目的：判断 12/2–12/3 的 DAU 增长，是否主要来自观察窗口内第一次出现的用户
-- 注意：由于数据从 2017-11-25 才开始，这里的“首次出现”不等于真实业务中的新增注册用户

WITH first_seen AS (
    SELECT
        user_id,
        MIN(DATE(datetime)) AS first_seen_date
    FROM user_behavior
    GROUP BY user_id
),

daily_users AS (
    SELECT DISTINCT
        DATE(datetime) AS date,
        user_id
    FROM user_behavior
)

SELECT
    d.date,

    COUNT(*) AS dau,

    SUM(
        CASE
            WHEN f.first_seen_date = d.date THEN 1
            ELSE 0
        END
    ) AS first_seen_users,

    SUM(
        CASE
            WHEN f.first_seen_date < d.date THEN 1
            ELSE 0
        END
    ) AS returning_users,

    ROUND(
        1.0 * SUM(
            CASE
                WHEN f.first_seen_date = d.date THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        4
    ) AS first_seen_rate

FROM daily_users d

JOIN first_seen f
    ON d.user_id = f.user_id

GROUP BY d.date

ORDER BY d.date;