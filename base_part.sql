SELECT 
    p.title,
    p.category,
    p.price,
    u.name as seller_name,
    (SELECT ROUND(AVG(price), 2) 
     FROM products 
     WHERE category = p.category) as avg_category_price
FROM products p
JOIN users u ON p.seller_id = u.user_id
WHERE p.status = 'active' 
  AND p.price > (SELECT AVG(price) FROM products WHERE category = p.category)
ORDER BY p.category, p.price DESC;



SELECT *
FROM (
    SELECT 
        u.user_id,
        u.name,
        u.email,
        u.rating,
        COUNT(DISTINCT prod.product_id) as products_for_sale,
        COUNT(DISTINCT pur.purchase_id) as purchases_made,
        COUNT(DISTINCT prod.product_id) + COUNT(DISTINCT pur.purchase_id) as total_activity
    FROM users u
    LEFT JOIN products prod ON u.user_id = prod.seller_id AND prod.status = 'active'
    LEFT JOIN purchases pur ON u.user_id = pur.buyer_id
    GROUP BY u.user_id, u.name, u.email, u.rating
    HAVING COUNT(DISTINCT prod.product_id) > 0 
       AND COUNT(DISTINCT pur.purchase_id) > 0
) as active_users
ORDER BY total_activity DESC;



SELECT 
    p.title,
    p.category,
    pur.amount as sold_price,
    u_seller.name as seller,
    u_buyer.name as buyer,
    pur.created_at as sold_date
FROM purchases pur
JOIN products p ON pur.product_id = p.product_id
JOIN users u_seller ON pur.seller_id = u_seller.user_id
JOIN users u_buyer ON pur.buyer_id = u_buyer.user_id
WHERE pur.status = 'delivered'
ORDER BY pur.amount DESC
LIMIT 5;



SELECT 
    u.user_id,
    u.name,
    u.rating,
    COUNT(p.product_id) as active_products,
    ROUND(AVG(p.price), 2) as avg_product_price,
    SUM(p.price) as total_inventory_value
FROM users u
LEFT JOIN products p ON u.user_id = p.seller_id AND p.status = 'active'
GROUP BY u.user_id, u.name, u.rating
HAVING COUNT(p.product_id) > 0
ORDER BY active_products DESC;



SELECT 
    pur.purchase_id,
    p.title as product_name,
    u_seller.name as seller,
    u_buyer.name as buyer,
    pur.amount,
    pur.paid_at,
    CURRENT_DATE - pur.paid_at::DATE as days_waiting
FROM purchases pur
JOIN products p ON pur.product_id = p.product_id
JOIN users u_seller ON pur.seller_id = u_seller.user_id
JOIN users u_buyer ON pur.buyer_id = u_buyer.user_id
WHERE pur.status = 'paid' 
   OR (pur.status = 'shipped' AND pur.delivered_at IS NULL)
ORDER BY days_waiting DESC;



SELECT 
    p.category,
    COUNT(pur.purchase_id) as total_sales,
    SUM(pur.amount) as total_revenue,
    ROUND(AVG(pur.amount), 2) as avg_sale_price,
    COUNT(DISTINCT p.product_id) as unique_products_sold
FROM products p
JOIN purchases pur ON p.product_id = pur.product_id
WHERE pur.status IN ('delivered', 'paid', 'shipped')
GROUP BY p.category
ORDER BY total_sales DESC;



SELECT 
    u.user_id,
    u.name,
    u.rating,
    COUNT(DISTINCT CASE WHEN p.status = 'active' THEN p.product_id END) as products_on_sale,
    COUNT(DISTINCT pur.purchase_id) as total_purchases,
    COUNT(DISTINCT r.rewiew_id) as reviews_written,
    ROUND(AVG(r.rating), 2) as avg_rating_given
FROM users u
LEFT JOIN products p ON u.user_id = p.seller_id
LEFT JOIN purchases pur ON u.user_id = pur.buyer_id
LEFT JOIN rewiews r ON u.user_id = r.rewiewer_id
WHERE u.rating >= 4.8
GROUP BY u.user_id, u.name, u.rating
ORDER BY u.rating DESC;



SELECT 
    p.title,
    p.price as listed_price,
    pur.amount as sold_price,
    ROUND((p.price - pur.amount) * 100.0 / p.price, 2) as discount_percent,
    u_seller.name as seller,
    u_buyer.name as buyer
FROM purchases pur
JOIN products p ON pur.product_id = p.product_id
JOIN users u_seller ON pur.seller_id = u_seller.user_id
JOIN users u_buyer ON pur.buyer_id = u_buyer.user_id
WHERE pur.amount < p.price 
  AND pur.status = 'delivered'
ORDER BY discount_percent DESC;



SELECT 
    r.rating,
    r.comment,
    u_reviewer.name as reviewer,
    u_reviewed.name as reviewed_user,
    p.title as product_name,
    r.created_at
FROM rewiews r
JOIN users u_reviewer ON r.rewiewer_id = u_reviewer.user_id
JOIN users u_reviewed ON r.rewiewed_id = u_reviewed.user_id
JOIN purchases pur ON r.purchase_id = pur.purchase_id
JOIN products p ON pur.product_id = p.product_id
WHERE r.rating <= 2
ORDER BY r.rating ASC, r.created_at DESC;



SELECT 
    TO_CHAR(DATE_TRUNC('month', pur.created_at), 'YYYY-MM') as month,
    COUNT(pur.purchase_id) as total_orders,
    SUM(pur.amount) as revenue,
    ROUND(AVG(pur.amount), 2) as avg_order_value,
    COUNT(DISTINCT pur.buyer_id) as unique_buyers,
    COUNT(DISTINCT pur.seller_id) as active_sellers
FROM purchases pur
WHERE pur.status IN ('delivered', 'paid', 'shipped')
GROUP BY DATE_TRUNC('month', pur.created_at)
ORDER BY month DESC;
