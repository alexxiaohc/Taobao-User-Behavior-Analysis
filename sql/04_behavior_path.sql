-- 构建“用户-商品”层面的行为标记
-- 目的：避免把用户对不同商品的行为错误拼成同一个转化链路

WITH user_item_flags AS (
    SELECT
        user_id,
        item_id,

        MAX(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS has_pv,
        MAX(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS has_fav,
        MAX(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS has_buy

    FROM user_behavior

    GROUP BY
        user_id,
        item_id
)

SELECT
    COUNT(*) AS user_item_pairs,

    SUM(has_pv) AS pv_pairs,
    SUM(has_fav) AS fav_pairs,
    SUM(has_cart) AS cart_pairs,
    SUM(has_buy) AS buy_pairs,

    -- 同一个用户对同一个商品既加购过又购买过
    SUM(
        CASE
            WHEN has_cart = 1 AND has_buy = 1 THEN 1
            ELSE 0
        END
    ) AS cart_and_buy_pairs,

    -- 同一个用户对同一个商品既浏览过又购买过
    SUM(
        CASE
            WHEN has_pv = 1 AND has_buy = 1 THEN 1
            ELSE 0
        END
    ) AS pv_and_buy_pairs

FROM user_item_flags;